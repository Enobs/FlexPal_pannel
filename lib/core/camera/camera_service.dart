import 'dart:async';
import 'dart:collection';
import '../../models/camera_settings.dart';
import 'camera_frame.dart';
import 'mjpeg_client.dart';
import 'udp_jpeg_client.dart';

/// Stream protocol type
enum StreamProtocol { mjpeg, udp }

/// Multi-camera stream manager - supports both MJPEG/HTTP and UDP/RTP
class CameraService {
  final List<dynamic> _clients = []; // MjpegClient or UdpJpegClient
  final List<StreamSubscription> _subscriptions = [];
  final StreamController<CameraFrame> _frameController = StreamController<CameraFrame>.broadcast();
  final StreamController<CameraStatus> _statusController = StreamController<CameraStatus>.broadcast();

  final Map<int, _CameraStats> _stats = {};
  Timer? _statsTimer;

  bool _isRunning = false;
  StreamProtocol _protocol = StreamProtocol.mjpeg;

  /// Stream of frames from all cameras
  Stream<CameraFrame> get frames => _frameController.stream;

  /// Stream of camera status updates
  Stream<CameraStatus> get status => _statusController.stream;

  /// Current protocol
  StreamProtocol get protocol => _protocol;

  /// Start camera streams with given settings (MJPEG mode)
  Future<void> start(CameraSettings settings) async {
    await startWithProtocol(settings, StreamProtocol.mjpeg);
  }

  /// Start camera streams with specified protocol
  Future<void> startWithProtocol(CameraSettings settings, StreamProtocol protocol) async {
    if (_isRunning) {
      await stop();
    }

    _isRunning = true;
    _protocol = protocol;

    if (protocol == StreamProtocol.mjpeg) {
      await _startMjpeg(settings);
    } else {
      await _startUdp(settings);
    }

    // Start periodic status updates (every second)
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      for (final camId in _stats.keys) {
        _updateStatus(camId);
      }
    });
  }

  Future<void> _startMjpeg(CameraSettings settings) async {
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
      final sub = client.frames().listen(
        (frame) {
          _stats[i]!.recordFrame();
          _frameController.add(frame);
        },
        onError: (error) {
          _stats[i]!.recordError(error.toString());
          _updateStatus(i);
        },
      );
      _subscriptions.add(sub);

      // Initial status
      _updateStatus(i);
    }
  }

  Future<void> _startUdp(CameraSettings settings) async {
    // For UDP, we use the camera IP but different ports
    // Port 5000 for cam0, 5001 for cam1, etc.
    final configs = [settings.camera1, settings.camera2, settings.camera3];
    int camIndex = 0;

    for (int i = 0; i < configs.length; i++) {
      if (!configs[i].enabled || configs[i].ip.isEmpty) continue;

      final client = UdpJpegClient(
        host: configs[i].ip,
        port: 5000 + camIndex, // UDP ports start at 5000
        camId: camIndex,
      );

      _clients.add(client);
      _stats[camIndex] = _CameraStats(camIndex);

      // Subscribe to frames
      final sub = client.frames().listen(
        (frame) {
          _stats[camIndex]!.recordFrame();
          _frameController.add(frame);
        },
        onError: (error) {
          _stats[camIndex]!.recordError(error.toString());
          _updateStatus(camIndex);
        },
      );
      _subscriptions.add(sub);

      // Initial status
      _updateStatus(camIndex);
      camIndex++;
    }
  }

  /// Stop all camera streams
  Future<void> stop() async {
    _isRunning = false;

    _statsTimer?.cancel();
    _statsTimer = null;

    // Cancel subscriptions first
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    // Close clients
    for (final client in _clients) {
      if (client is MjpegClient) {
        await client.close();
      } else if (client is UdpJpegClient) {
        await client.close();
      }
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

    return (_frameTimes.length - 1) / (deltaMs / 1000.0);
  }

  bool isOnline() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - _lastFrameTime) < 5000;
  }

  void updateDimensions(int w, int h) {
    width = w;
    height = h;
  }
}
