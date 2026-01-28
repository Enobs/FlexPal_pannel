import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'camera_frame.dart';

/// Camera frame recorder - writes frames directly using async I/O.
/// No isolate overhead, relies on Dart's async file I/O being non-blocking.
class CameraRecorder {
  bool _isRecording = false;
  final Map<int, _CameraWriter> _writers = {};
  int _frameIntervalMs = 17;
  int _framesSent = 0;

  bool get isRecording => _isRecording;

  /// Start recording to episode directory
  Future<void> start({required String episodeDir, required int saveFps}) async {
    if (_isRecording) {
      await stop();
    }

    _frameIntervalMs = (1000 / saveFps).round();
    _writers.clear();
    _framesSent = 0;
    _isRecording = true;

    print('[CameraRecorder] Recording started: $episodeDir @ ${saveFps}fps (interval: ${_frameIntervalMs}ms)');

    // Pre-create the camera directory
    await Directory('$episodeDir/camera').create(recursive: true);

    // Store episode dir for writer creation
    _writers[-1] = _CameraWriter._placeholder(episodeDir);
  }

  /// Stop recording and wait for all pending writes to finish
  Future<void> stop() async {
    if (!_isRecording) return;
    _isRecording = false;

    print('[CameraRecorder] Stopping... (sent $_framesSent frames)');

    // Close all writers (waits for pending writes)
    for (final entry in _writers.entries) {
      if (entry.key >= 0) {
        await entry.value.close();
      }
    }
    _writers.clear();

    print('[CameraRecorder] Recording stopped');
  }

  /// Record a frame - writes asynchronously
  void onFrame(CameraFrame frame) {
    if (!_isRecording) return;

    _framesSent++;

    // Get or create writer for this camera
    var writer = _writers[frame.camId];
    if (writer == null) {
      final placeholder = _writers[-1]!;
      writer = _CameraWriter(
        episodeDir: placeholder._episodeDir,
        camId: frame.camId,
        frameIntervalMs: _frameIntervalMs,
      );
      _writers[frame.camId] = writer;
    }

    writer.writeFrame(
      jpegBytes: frame.jpegBytes,
      tsMonoMs: frame.tsMonoMs,
      wallIso: frame.wallIso,
    );

    if (_framesSent % 30 == 0) {
      final writer = _writers[frame.camId];
      final saved = writer?._seq ?? 0;
      final dropped = writer?._droppedFrames ?? 0;
      print('[CameraRecorder] Received: $_framesSent, Saved: $saved, Dropped by rate limit: $dropped');
    }
  }

  Future<void> dispose() async {
    await stop();
  }
}

/// Writer for individual camera stream
class _CameraWriter {
  final String _episodeDir;
  final int camId;
  final int frameIntervalMs;

  String? _framesDir;
  IOSink? _indexSink;

  int _seq = 0;
  int _lastSaveMs = 0;
  int _pendingWrites = 0;
  int _droppedFrames = 0;

  // Placeholder constructor for storing episodeDir
  _CameraWriter._placeholder(this._episodeDir) : camId = -1, frameIntervalMs = 0;

  _CameraWriter({
    required String episodeDir,
    required this.camId,
    required this.frameIntervalMs,
  }) : _episodeDir = episodeDir {
    final camDir = '$_episodeDir/camera/cam$camId';
    _framesDir = '$camDir/frames';

    // Create directories synchronously (only happens once per camera)
    Directory(_framesDir!).createSync(recursive: true);

    // Open index.csv
    _indexSink = File('$camDir/index.csv').openWrite();
    _indexSink!.writeln('seq,ts_mono_ms,wall_time_iso,filename');

    print('[CameraRecorder] Camera writer created: cam$camId (frameIntervalMs: $frameIntervalMs)');
  }

  void writeFrame({
    required Uint8List jpegBytes,
    required int tsMonoMs,
    required String wallIso,
  }) {
    if (_framesDir == null) return;

    // Rate limiting using wall clock time (skip for 60fps - save every frame)
    final now = DateTime.now().millisecondsSinceEpoch;
    if (frameIntervalMs > 17) {
      // Only rate limit if target is below 60fps
      if (now - _lastSaveMs < frameIntervalMs) {
        _droppedFrames++;
        return;
      }
      _lastSaveMs = now;
    }
    _seq++;

    final safeIso = wallIso.replaceAll(':', '-');
    final filename = '${_seq.toString().padLeft(6, '0')}_mono${tsMonoMs}_$safeIso.jpg';
    final filepath = '$_framesDir/$filename';

    _pendingWrites++;

    // Async write - doesn't block the event loop
    File(filepath).writeAsBytes(jpegBytes, flush: false).then((_) {
      _pendingWrites--;
    }).catchError((e) {
      _pendingWrites--;
      print('[CameraRecorder] ERROR writing frame cam$camId #$_seq: $e');
    });

    // Write to index (buffered by IOSink)
    _indexSink?.writeln('$_seq,$tsMonoMs,$wallIso,$filename');

    if (_seq % 60 == 0) {
      print('[CameraRecorder] Cam $camId: frame #$_seq (pending: $_pendingWrites, dropped: $_droppedFrames)');
    }
  }

  Future<void> close() async {
    if (_framesDir == null) return;

    // Wait for pending writes with timeout
    int waited = 0;
    while (_pendingWrites > 0 && waited < 5000) {
      await Future.delayed(const Duration(milliseconds: 10));
      waited += 10;
    }
    if (_pendingWrites > 0) {
      print('[CameraRecorder] WARNING: cam$camId still has $_pendingWrites pending writes');
    }

    await _indexSink?.flush();
    await _indexSink?.close();
    print('[CameraRecorder] Camera writer closed: cam$camId (saved: $_seq, dropped: $_droppedFrames)');
  }
}
