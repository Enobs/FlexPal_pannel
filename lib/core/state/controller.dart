import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings.dart';
import '../udp/udp_service.dart';
import '../record/recorder.dart';
import '../camera/camera_service.dart';
import '../camera/camera_recorder.dart';
import '../utils/logger.dart';
import 'app_state.dart';

/// Main application controller
class AppController {
  final AppState state;
  final UdpService udpService;
  final Recorder recorder;
  final CameraService cameraService;
  final CameraRecorder cameraRecorder;
  final Logger logger;

  Timer? _timeoutCheckTimer;
  StreamSubscription? _packetSubscription;
  StreamSubscription? _udpLogSubscription;
  StreamSubscription? _recorderLogSubscription;
  StreamSubscription? _cameraFrameSubscription;

  AppController({
    required this.state,
    required this.udpService,
    required this.recorder,
    required this.cameraService,
    required this.cameraRecorder,
    required this.logger,
  });

  /// Initialize controller
  Future<void> init() async {
    await loadSettings();

    // Start timeout checker
    _timeoutCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      state.checkChamberTimeouts();
    });

    logger.info('Controller initialized');
  }

  /// Load settings from persistent storage
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('settings');

      if (jsonStr != null) {
        final settings = Settings.fromJsonString(jsonStr);
        state.updateSettings(settings);
        logger.info('Loaded settings from storage');
      } else {
        logger.info('Using default settings');
      }
    } catch (e) {
      logger.error('Failed to load settings: $e');
    }
  }

  /// Save settings to persistent storage
  Future<void> saveSettings(Settings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('settings', settings.toJsonString());
      state.updateSettings(settings);
      logger.info('Saved settings');
    } catch (e) {
      logger.error('Failed to save settings: $e');
    }
  }

  /// Start UDP service
  Future<void> startUdp() async {
    if (state.udpRunning) {
      logger.warning('UDP already running');
      return;
    }

    try {
      await udpService.start(
        state.settings.broadcastAddress,
        state.settings.sendPort,
        state.settings.recvPort,
      );

      // Initialize mode and rate from settings
      udpService.setMode(state.settings.mode);
      udpService.setRateHz(state.settings.sendRateHz);

      // Subscribe to packets
      _packetSubscription = udpService.packets.listen((packet) {
        state.onPacketReceived(packet);
        if (recorder.isRecording) {
          recorder.onTelemetryPacket(packet);
        }
      });

      // Subscribe to UDP logs
      _udpLogSubscription = udpService.logs.listen((log) {
        if (log.contains('ERROR')) {
          logger.error(log, source: 'UDP');
        } else if (log.contains('WARN')) {
          logger.warning(log, source: 'UDP');
        } else {
          logger.info(log, source: 'UDP');
        }
      });

      state.setUdpRunning(true);
      logger.info('UDP service started');
    } catch (e) {
      logger.error('Failed to start UDP: $e');
      rethrow;
    }
  }

  /// Stop UDP service
  Future<void> stopUdp() async {
    await udpService.stop();
    await _packetSubscription?.cancel();
    await _udpLogSubscription?.cancel();
    _packetSubscription = null;
    _udpLogSubscription = null;

    state.setUdpRunning(false);
    state.setSending(false);
    logger.info('UDP service stopped');
  }

  /// Start sending commands
  void startSending() {
    if (!state.udpRunning) {
      logger.error('Cannot start sending - UDP not running');
      return;
    }

    // Don't call setMode() here - it resets targets to zero!
    // Mode should already be set via setMode() when user changes mode
    udpService.setRateHz(state.settings.sendRateHz);
    udpService.startSending();

    state.setSending(true);
    logger.info('Started sending commands');

    // Start recording command ticks if recording
    if (recorder.isRecording) {
      _startCommandRecording();
    }
  }

  /// Stop sending commands
  Future<void> stopSending() async {
    await udpService.stopSending();
    state.setSending(false);
    logger.info('Stopped sending commands');
  }

  /// Set control mode
  void setMode(int mode) {
    udpService.setMode(mode);
    final newSettings = state.settings.copyWith(mode: mode);
    state.updateSettings(newSettings);
    logger.info('Mode changed to: $mode');
  }

  /// Set target values
  void setTargets(List<double> values) {
    udpService.setTargets(values);
  }

  /// Set single target
  void setTarget(int chamberIndex, double value) {
    udpService.setTarget(chamberIndex, value);
  }

  /// Set send rate
  void setRateHz(int hz) {
    udpService.setRateHz(hz);
    final newSettings = state.settings.copyWith(sendRateHz: hz);
    state.updateSettings(newSettings);
  }

  /// Start recording episode
  Future<void> startRecording(String episodeName, {String? notes}) async {
    if (recorder.isRecording) {
      logger.warning('Already recording');
      return;
    }

    // Get documents directory
    final docsDir = await getApplicationDocumentsDirectory();
    final recordPath = '${docsDir.path}/VLA_Records';

    try {
      await recorder.startEpisode(
        episodeName: episodeName,
        notes: notes,
        settings: state.settings,
      );

      // Subscribe to recorder logs
      _recorderLogSubscription = recorder.logs.listen((log) {
        if (log.contains('ERROR')) {
          logger.error(log);
        } else {
          logger.info(log);
        }
      });

      state.setRecording(true, episodeId: recorder.currentEpisodeId);

      if (state.sending) {
        _startCommandRecording();
      }

      // Start camera recording if episode path is available
      if (recorder.currentEpisodePath != null) {
        await _startCameraRecording(recorder.currentEpisodePath!);
      }

      logger.info('Started recording: $episodeName');
    } catch (e) {
      logger.error('Failed to start recording: $e');
      rethrow;
    }
  }

  /// Stop recording episode
  Future<void> stopRecording() async {
    if (!recorder.isRecording) {
      logger.warning('Not currently recording');
      return;
    }

    // Stop camera recording first
    await _stopCameraRecording();

    await recorder.stopEpisode();
    await _recorderLogSubscription?.cancel();
    _recorderLogSubscription = null;

    state.setRecording(false);
    logger.info('Stopped recording');
  }

  Timer? _commandRecordTimer;

  void _startCommandRecording() {
    _commandRecordTimer?.cancel();

    final intervalMs = (1000 / state.settings.sendRateHz).round();
    _commandRecordTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      final lastSent = udpService.getLastSent();
      if (lastSent != null && recorder.isRecording) {
        final (mode, addr, port, targets) = lastSent;
        recorder.onCommandTick(
          udpService.sendSeq,
          DateTime.now(),
          mode,
          addr,
          port,
          targets,
        );
      }
    });
  }

  /// Start camera recording
  Future<void> _startCameraRecording(String episodePath) async {
    try {
      await cameraRecorder.start(
        episodeDir: episodePath,
        saveFps: state.settings.camera.defaultSaveFps,
      );

      // Subscribe to camera frames and forward to recorder
      _cameraFrameSubscription = cameraService.frames.listen((frame) {
        cameraRecorder.onFrame(frame);
      });

      logger.info('Camera recording started');
    } catch (e) {
      logger.error('Failed to start camera recording: $e');
    }
  }

  /// Stop camera recording
  Future<void> _stopCameraRecording() async {
    try {
      await _cameraFrameSubscription?.cancel();
      _cameraFrameSubscription = null;

      await cameraRecorder.stop();
      logger.info('Camera recording stopped');
    } catch (e) {
      logger.error('Failed to stop camera recording: $e');
    }
  }

  /// Dispose controller
  Future<void> dispose() async {
    _timeoutCheckTimer?.cancel();
    _commandRecordTimer?.cancel();
    await stopRecording();
    await stopUdp();
    await _packetSubscription?.cancel();
    await _udpLogSubscription?.cancel();
    await _recorderLogSubscription?.cancel();
    await _cameraFrameSubscription?.cancel();
    udpService.dispose();
    recorder.dispose();
    await cameraService.dispose();
    await cameraRecorder.dispose();
    logger.dispose();
  }
}
