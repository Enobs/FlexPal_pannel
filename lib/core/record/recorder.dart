import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../models/settings.dart';
import '../models/parsed_packet.dart';
import '../models/episode_manifest.dart';
import 'record_event.dart';

/// VLA Episode Recorder
///
/// Records commands and telemetry to CSV files in separate isolate
class Recorder {
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;

  bool _isRecording = false;
  String? _currentEpisodeId;
  String? _currentEpisodePath;

  final String _baseRecordPath;
  final _logController = StreamController<String>.broadcast();

  Recorder(this._baseRecordPath);

  bool get isRecording => _isRecording;
  String? get currentEpisodeId => _currentEpisodeId;
  String? get currentEpisodePath => _currentEpisodePath;
  Stream<String> get logs => _logController.stream;

  /// Start recording a new episode
  Future<void> startEpisode({
    required String episodeName,
    String? notes,
    required Settings settings,
  }) async {
    if (_isRecording) {
      _log('ERROR: Already recording episode $_currentEpisodeId');
      return;
    }

    // Generate episode ID and path
    final episodeId = const Uuid().v4();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    final dirName = '${timestamp}_$episodeName';
    final episodePath = path.join(_baseRecordPath, dirName);

    // Create directory
    try {
      await Directory(episodePath).create(recursive: true);
    } catch (e) {
      _log('ERROR: Failed to create episode directory: $e');
      return;
    }

    // Create manifest
    final manifest = EpisodeManifest(
      episodeId: episodeId,
      episodeName: episodeName,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      platform: Platform.operatingSystem,
      settings: settings,
      notes: notes,
    );

    // Write manifest
    final manifestFile = File(path.join(episodePath, 'manifest.json'));
    try {
      await manifestFile.writeAsString(manifest.toJsonString());
    } catch (e) {
      _log('ERROR: Failed to write manifest: $e');
      return;
    }

    // Start isolate
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _recordingIsolate,
      _IsolateParams(
        sendPort: _receivePort!.sendPort,
        episodePath: episodePath,
        episodeId: episodeId,
      ),
    );

    // Wait for isolate to send back its SendPort
    final completer = Completer<SendPort>();
    _receivePort!.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      } else if (message is String) {
        _log(message);
      }
    });

    _sendPort = await completer.future;

    _isRecording = true;
    _currentEpisodeId = episodeId;
    _currentEpisodePath = episodePath;

    _log('Started recording episode: $episodeName ($episodeId)');
    _log('Recording to: $episodePath');
  }

  /// Stop recording current episode
  Future<void> stopEpisode() async {
    if (!_isRecording) {
      _log('WARN: Not currently recording');
      return;
    }

    _sendPort?.send(StopEvent());

    // Wait a bit for isolate to flush
    await Future.delayed(const Duration(milliseconds: 500));

    _isolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();

    _isolate = null;
    _sendPort = null;
    _receivePort = null;

    _log('Stopped recording episode: $_currentEpisodeId');
    _log('Files saved to: $_currentEpisodePath');

    _isRecording = false;
    _currentEpisodeId = null;
    _currentEpisodePath = null;
  }

  /// Record a command tick
  void onCommandTick(int seq, DateTime timestamp, int mode, String addr, int port, List<int> targets) {
    if (!_isRecording || _sendPort == null) return;

    _sendPort!.send(CommandEvent(
      seq: seq,
      timestamp: timestamp,
      mode: mode,
      address: addr,
      port: port,
      targets: targets,
    ));
  }

  /// Record a telemetry packet
  void onTelemetryPacket(ParsedPacket packet) {
    if (!_isRecording || _sendPort == null) return;

    _sendPort!.send(TelemetryEvent(packet));
  }

  /// Dispose recorder
  void dispose() {
    if (_isRecording) {
      stopEpisode();
    }
    _logController.close();
  }

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    _logController.add('[$timestamp] [Recorder] $message');
  }
}

/// Parameters for isolate
class _IsolateParams {
  final SendPort sendPort;
  final String episodePath;
  final String episodeId;

  _IsolateParams({
    required this.sendPort,
    required this.episodePath,
    required this.episodeId,
  });
}

/// Isolate entry point for recording
void _recordingIsolate(_IsolateParams params) {
  final receivePort = ReceivePort();
  params.sendPort.send(receivePort.sendPort);

  final commandsPath = path.join(params.episodePath, 'commands.csv');
  final telemetryPath = path.join(params.episodePath, 'telemetry.csv');

  IOSink? commandsSink;
  IOSink? telemetrySink;
  bool shouldStop = false;

  try {
    // Open files
    commandsSink = File(commandsPath).openWrite();
    telemetrySink = File(telemetryPath).openWrite();

    // Write headers
    commandsSink.writeln('version,episode_id,seq,ts_ms,wall_time_iso,mode,addr,port,ch1,ch2,ch3,ch4,ch5,ch6,ch7,ch8,ch9');
    telemetrySink.writeln('version,episode_id,ts_ms,wall_time_iso,chamber_id,length_mm,accel_x,accel_y,accel_z,gyro_x,gyro_y,gyro_z,pressure,battery,src_ip,src_port');

    params.sendPort.send('Recorder isolate started');

    // Listen for events
    receivePort.listen((message) {
      if (shouldStop) return;

      if (message is CommandEvent) {
        final tsMs = message.timestamp.millisecondsSinceEpoch;
        final isoTime = message.timestamp.toUtc().toIso8601String();
        final targetsStr = message.targets.join(',');

        commandsSink?.writeln('1,${params.episodeId},${message.seq},$tsMs,$isoTime,${message.mode},${message.address},${message.port},$targetsStr');
      } else if (message is TelemetryEvent) {
        final pkt = message.packet;
        final tsMs = pkt.timestamp.millisecondsSinceEpoch;
        final isoTime = pkt.timestamp.toUtc().toIso8601String();

        telemetrySink?.writeln('1,${params.episodeId},$tsMs,$isoTime,${pkt.chamberId},${pkt.lengthMm},${pkt.accelX},${pkt.accelY},${pkt.accelZ},${pkt.gyroX},${pkt.gyroY},${pkt.gyroZ},${pkt.pressure},${pkt.battery},${pkt.sourceIp},${pkt.sourcePort}');
      } else if (message is FlushEvent) {
        commandsSink?.flush();
        telemetrySink?.flush();
      } else if (message is StopEvent) {
        shouldStop = true;

        // Close files (close automatically flushes)
        try {
          commandsSink?.close();
          telemetrySink?.close();
        } catch (e) {
          params.sendPort.send('ERROR closing files: $e');
        }

        params.sendPort.send('Recorder isolate stopped');
        receivePort.close();
      }
    });
  } catch (e) {
    params.sendPort.send('ERROR in recorder isolate: $e');
    try {
      commandsSink?.close();
      telemetrySink?.close();
    } catch (_) {
      // Ignore close errors during exception handling
    }
    receivePort.close();
  }
}
