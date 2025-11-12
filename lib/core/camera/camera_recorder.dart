import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'camera_frame.dart';

/// Camera frame recorder with 30 FPS rate limiting (runs in Isolate)
class CameraRecorder {
  SendPort? _sendPort;
  Isolate? _isolate;
  ReceivePort? _receivePort;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// Start recording to episode directory
  Future<void> start({required String episodeDir, required int saveFps}) async {
    if (_isRecording) {
      await stop();
    }

    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _recorderIsolateEntry,
      _receivePort!.sendPort,
    );

    // Wait for isolate to be ready
    final completer = Completer<SendPort>();
    _receivePort!.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      } else if (message is String) {
        // Log messages from isolate
        print('[CameraRecorder] $message');
      }
    });

    _sendPort = await completer.future;

    // Send start command
    _sendPort!.send({
      'command': 'start',
      'episodeDir': episodeDir,
      'saveFps': saveFps,
    });

    _isRecording = true;
  }

  /// Stop recording
  Future<void> stop() async {
    if (!_isRecording) return;

    _sendPort?.send({'command': 'stop'});

    await Future.delayed(const Duration(milliseconds: 100));

    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receivePort?.close();
    _receivePort = null;
    _sendPort = null;

    _isRecording = false;
  }

  /// Send frame to recording isolate
  void onFrame(CameraFrame frame) {
    if (_isRecording && _sendPort != null) {
      _sendPort!.send({
        'command': 'frame',
        'camId': frame.camId,
        'jpegBytes': frame.jpegBytes,
        'tsMonoMs': frame.tsMonoMs,
        'wallIso': frame.wallIso,
        'width': frame.width,
        'height': frame.height,
      });
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stop();
  }
}

/// Isolate entry point for camera recording
void _recorderIsolateEntry(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  _RecorderIsolateState? state;

  receivePort.listen((message) {
    if (message is! Map<String, dynamic>) return;

    final command = message['command'] as String?;

    switch (command) {
      case 'start':
        final episodeDir = message['episodeDir'] as String;
        final saveFps = message['saveFps'] as int;
        state = _RecorderIsolateState(
          episodeDir: episodeDir,
          saveFps: saveFps,
          logCallback: (msg) => mainSendPort.send(msg),
        );
        state!.start();
        break;

      case 'stop':
        state?.stop();
        state = null;
        break;

      case 'frame':
        state?.onFrame(
          camId: message['camId'] as int,
          jpegBytes: message['jpegBytes'] as List<int>,
          tsMonoMs: message['tsMonoMs'] as int,
          wallIso: message['wallIso'] as String,
          width: message['width'] as int?,
          height: message['height'] as int?,
        );
        break;
    }
  });
}

/// Internal state for recorder isolate
class _RecorderIsolateState {
  final String episodeDir;
  final int saveFps;
  final void Function(String) logCallback;

  final Map<int, _CameraWriter> _writers = {};
  final int _frameIntervalMs;

  _RecorderIsolateState({
    required this.episodeDir,
    required this.saveFps,
    required this.logCallback,
  }) : _frameIntervalMs = (1000 / saveFps).round();

  void start() {
    logCallback('Camera recorder started: $episodeDir @ ${saveFps}fps');
  }

  void stop() {
    for (final writer in _writers.values) {
      writer.close();
    }
    _writers.clear();
    logCallback('Camera recorder stopped');
  }

  void onFrame({
    required int camId,
    required List<int> jpegBytes,
    required int tsMonoMs,
    required String wallIso,
    int? width,
    int? height,
  }) {
    // Get or create writer for this camera
    final writer = _writers.putIfAbsent(
      camId,
      () => _CameraWriter(
        episodeDir: episodeDir,
        camId: camId,
        frameIntervalMs: _frameIntervalMs,
        logCallback: logCallback,
      ),
    );

    writer.writeFrame(
      jpegBytes: jpegBytes,
      tsMonoMs: tsMonoMs,
      wallIso: wallIso,
      width: width,
      height: height,
    );
  }
}

/// Writer for individual camera stream
class _CameraWriter {
  final String episodeDir;
  final int camId;
  final int frameIntervalMs;
  final void Function(String) logCallback;

  late final String _camDir;
  late final String _framesDir;
  late final String _indexPath;
  late final IOSink _indexSink;

  int _seq = 0;
  int _lastSaveMs = 0;
  bool _indexHeaderWritten = false;

  _CameraWriter({
    required this.episodeDir,
    required this.camId,
    required this.frameIntervalMs,
    required this.logCallback,
  }) {
    _camDir = '$episodeDir/camera/cam$camId';
    _framesDir = '$_camDir/frames';
    _indexPath = '$_camDir/index.csv';

    // Create directories
    Directory(_framesDir).createSync(recursive: true);

    // Open index.csv
    _indexSink = File(_indexPath).openWrite();
    _indexSink.writeln('seq,ts_mono_ms,wall_time_iso,filename,w,h');
    _indexHeaderWritten = true;

    logCallback('Camera writer created: cam$camId');
  }

  void writeFrame({
    required List<int> jpegBytes,
    required int tsMonoMs,
    required String wallIso,
    int? width,
    int? height,
  }) {
    // Rate limiting: skip if too soon since last save
    if (tsMonoMs - _lastSaveMs < frameIntervalMs) {
      return;
    }

    _lastSaveMs = tsMonoMs;
    _seq++;

    // Generate safe filename (replace : with -)
    final safeIso = wallIso.replaceAll(':', '-');
    final filename = '${_seq.toString().padLeft(6, '0')}_mono${tsMonoMs}_$safeIso.jpg';
    final filepath = '$_framesDir/$filename';

    try {
      // Write JPEG file
      File(filepath).writeAsBytesSync(jpegBytes, flush: false);

      // Append to index.csv
      _indexSink.writeln('$_seq,$tsMonoMs,$wallIso,$filename,${width ?? ''},${height ?? ''}');

      // Log every 30 frames (1 second at 30fps)
      if (_seq % 30 == 0) {
        logCallback('Cam $camId: wrote frame #$_seq');
      }
    } catch (e) {
      logCallback('ERROR writing frame cam$camId #$_seq: $e');
    }
  }

  void close() {
    _indexSink.flush();
    _indexSink.close();
    logCallback('Camera writer closed: cam$camId (wrote $_seq frames)');
  }
}
