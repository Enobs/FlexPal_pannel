import 'dart:async';
import 'dart:collection';
import '../../models/camera_settings.dart';
import 'camera_frame.dart';
import 'mjpeg_client.dart';

/// Multi-camera stream manager
class CameraService {
  final List<MjpegClient> _clients = [];
  final StreamController<CameraFrame> _frameController = StreamController<CameraFrame>.broadcast();
  final StreamController<CameraStatus> _statusController = StreamController<CameraStatus>.broadcast();

  final Map<int, _CameraStats> _stats = {};
  Timer? _statsTimer;

  bool _isRunning = false;

  /// Stream of frames from all cameras
  Stream<CameraFrame> get frames => _frameController.stream;

  /// Stream of camera status updates
  Stream<CameraStatus> get status => _statusController.stream;

  /// Start camera streams with given settings
  Future<void> start(CameraSettings settings) async {
    if (_isRunning) {
      await stop();
    }

    _isRunning = true;
    final urls = settings.getCameraUrls();

    for (int i = 0; i < urls.length; i++) {
      final client = MjpegClient(
        url: urls[i],
        camId: i,
        timeout: const Duration(seconds: 10),
        reconnectDelay: const Duration(seconds: 3),
      );

      _clients.add(client);
      _stats[i] = _CameraStats(i);

      // Subscribe to frames
      client.frames().listen(
        (frame) {
          _stats[i]!.recordFrame();
          _frameController.add(frame);
        },
        onError: (error) {
          _stats[i]!.recordError(error.toString());
          _updateStatus(i);
        },
      );

      // Initial status
      _updateStatus(i);
    }

    // Start periodic status updates (every second)
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      for (final camId in _stats.keys) {
        _updateStatus(camId);
      }
    });
  }

  /// Stop all camera streams
  Future<void> stop() async {
    _isRunning = false;

    _statsTimer?.cancel();
    _statsTimer = null;

    for (final client in _clients) {
      await client.close();
    }
    _clients.clear();
    _stats.clear();
  }

  void _updateStatus(int camId) {
    final stats = _stats[camId];
    if (stats == null) return;

    final fps = stats.calculateFps();
    final isOnline = stats.isOnline();

    _statusController.add(CameraStatus(
      camId: camId,
      isOnline: isOnline,
      fps: fps,
      width: stats.width,
      height: stats.height,
      error: stats.lastError,
    ));
  }

  /// Update camera dimensions
  void updateDimensions(int camId, int width, int height) {
    _stats[camId]?.updateDimensions(width, height);
    _updateStatus(camId);
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stop();
    await _frameController.close();
    await _statusController.close();
  }
}

/// Internal statistics tracker for each camera
class _CameraStats {
  final int camId;
  final Queue<int> _frameTimes = Queue<int>();
  int? width;
  int? height;
  String? lastError;
  int _lastFrameTime = 0;

  _CameraStats(this.camId);

  void recordFrame() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastFrameTime = now;
    _frameTimes.add(now);

    // Keep only last second of timestamps
    while (_frameTimes.isNotEmpty && now - _frameTimes.first > 1000) {
      _frameTimes.removeFirst();
    }

    // Clear error on successful frame
    lastError = null;
  }

  void recordError(String error) {
    lastError = error;
  }

  double calculateFps() {
    if (_frameTimes.length < 2) return 0.0;

    final oldest = _frameTimes.first;
    final newest = _frameTimes.last;
    final deltaMs = newest - oldest;

    if (deltaMs <= 0) return 0.0;

    // FPS = (frame count - 1) / time_interval_in_seconds
    return (_frameTimes.length - 1) / (deltaMs / 1000.0);
  }

  bool isOnline() {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Consider online if received frame in last 5 seconds
    return (now - _lastFrameTime) < 5000;
  }

  void updateDimensions(int w, int h) {
    width = w;
    height = h;
  }
}
