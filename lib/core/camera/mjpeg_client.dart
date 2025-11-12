import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'camera_frame.dart';

/// MJPEG HTTP stream client with automatic reconnection
class MjpegClient {
  final Uri url;
  final int camId;
  final Duration timeout;
  final Duration reconnectDelay;

  HttpClient? _httpClient;
  StreamController<CameraFrame>? _frameController;
  StreamSubscription? _responseSubscription;
  bool _isRunning = false;
  Timer? _reconnectTimer;

  MjpegClient({
    required this.url,
    required this.camId,
    this.timeout = const Duration(seconds: 10),
    this.reconnectDelay = const Duration(seconds: 3),
  });

  /// Get stream of camera frames
  Stream<CameraFrame> frames() {
    if (_frameController == null || _frameController!.isClosed) {
      _frameController = StreamController<CameraFrame>.broadcast(
        onListen: _start,
        onCancel: () {
          // Keep running even if no listeners
        },
      );
    }
    return _frameController!.stream;
  }

  Future<void> _start() async {
    if (_isRunning) return;
    _isRunning = true;
    await _connect();
  }

  Future<void> _connect() async {
    if (!_isRunning) return;

    try {
      _httpClient = HttpClient()
        ..connectionTimeout = timeout
        ..idleTimeout = const Duration(minutes: 5);

      final request = await _httpClient!.getUrl(url);
      request.headers.add('User-Agent', 'FlexPAL-Camera/1.0');

      final response = await request.close();

      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }

      // Parse MJPEG stream
      _responseSubscription = _parseMjpegStream(response).listen(
        (frame) {
          if (_frameController != null && !_frameController!.isClosed) {
            _frameController!.add(frame);
          }
        },
        onError: (error) {
          _handleError(error);
        },
        onDone: () {
          _handleDisconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      _handleError(e);
    }
  }

  /// Parse MJPEG multipart stream into individual JPEG frames
  Stream<CameraFrame> _parseMjpegStream(HttpClientResponse response) async* {
    final List<int> buffer = [];
    const jpegStart = [0xFF, 0xD8]; // JPEG SOI marker
    const jpegEnd = [0xFF, 0xD9];   // JPEG EOI marker

    await for (final chunk in response) {
      buffer.addAll(chunk);

      // Search for complete JPEG frames
      while (true) {
        final startIdx = _findSequence(buffer, jpegStart);
        if (startIdx == -1) break;

        final endIdx = _findSequence(buffer, jpegEnd, startIdx + 2);
        if (endIdx == -1) break;

        // Extract JPEG frame
        final jpegBytes = Uint8List.fromList(
          buffer.sublist(startIdx, endIdx + 2),
        );

        // Remove extracted frame from buffer
        buffer.removeRange(0, endIdx + 2);

        // Generate timestamps
        final now = DateTime.now().toUtc();
        final tsMonoMs = now.millisecondsSinceEpoch;
        final wallIso = now.toIso8601String().replaceAll(':', '-');

        yield CameraFrame(
          camId: camId,
          jpegBytes: jpegBytes,
          tsMonoMs: tsMonoMs,
          wallIso: wallIso,
        );
      }

      // Prevent buffer from growing too large
      if (buffer.length > 10 * 1024 * 1024) { // 10MB limit
        buffer.clear();
      }
    }
  }

  /// Find byte sequence in buffer
  int _findSequence(List<int> buffer, List<int> sequence, [int start = 0]) {
    for (int i = start; i <= buffer.length - sequence.length; i++) {
      bool found = true;
      for (int j = 0; j < sequence.length; j++) {
        if (buffer[i + j] != sequence[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }

  void _handleError(dynamic error) {
    if (_frameController != null && !_frameController!.isClosed) {
      _frameController!.addError(error);
    }
    _scheduleReconnect();
  }

  void _handleDisconnect() {
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_isRunning) return;

    _cleanup();

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay, () {
      if (_isRunning) {
        _connect();
      }
    });
  }

  void _cleanup() {
    _responseSubscription?.cancel();
    _responseSubscription = null;
    _httpClient?.close(force: true);
    _httpClient = null;
  }

  /// Close the client and stop streaming
  Future<void> close() async {
    _isRunning = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cleanup();
    await _frameController?.close();
    _frameController = null;
  }
}
