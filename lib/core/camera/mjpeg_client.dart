import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'camera_frame.dart';

/// MJPEG HTTP stream client with automatic reconnection.
/// Emits every complete JPEG frame. Display-side consumers are responsible
/// for dropping stale frames (e.g. via a periodic timer that only reads
/// the latest).
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
    this.timeout = const Duration(seconds: 5),
    this.reconnectDelay = const Duration(seconds: 2),
  });

  /// Stream of all complete frames.
  Stream<CameraFrame> frames() {
    if (_frameController == null || _frameController!.isClosed) {
      _frameController = StreamController<CameraFrame>.broadcast(
        onListen: _start,
        onCancel: () {},
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

    // Clean up any previous connection before creating a new one
    _cleanup();

    try {
      _httpClient = HttpClient()
        ..connectionTimeout = timeout
        ..idleTimeout = const Duration(seconds: 15)
        ..autoUncompress = false;

      final request = await _httpClient!.getUrl(url);
      request.headers.add('User-Agent', 'FlexPAL-Camera/1.0');
      request.headers.add('Connection', 'keep-alive');

      final response = await request.close();

      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }

      _parseMjpegDirect(response);
    } on SocketException catch (e) {
      _handleError(e);
    } on HttpException catch (e) {
      _handleError(e);
    } catch (e) {
      _handleError(e);
    }
  }

  void _parseMjpegDirect(HttpClientResponse response) {
    Uint8List _buf = Uint8List(512 * 1024);
    int _len = 0;
    int _frameCount = 0;
    int _lastLogTime = DateTime.now().millisecondsSinceEpoch;

    void _ensureCapacity(int needed) {
      if (_len + needed > _buf.length) {
        final newBuf = Uint8List((_len + needed) * 2);
        newBuf.setRange(0, _len, _buf);
        _buf = newBuf;
      }
    }

    _responseSubscription = response.listen(
      (List<int> chunk) {
        _ensureCapacity(chunk.length);
        if (chunk is Uint8List) {
          _buf.setRange(_len, _len + chunk.length, chunk);
        } else {
          for (int i = 0; i < chunk.length; i++) {
            _buf[_len + i] = chunk[i];
          }
        }
        _len += chunk.length;

        while (_len >= 4) {
          // Find SOI (0xFF 0xD8)
          int startIdx = -1;
          for (int i = 0; i <= _len - 2; i++) {
            if (_buf[i] == 0xFF && _buf[i + 1] == 0xD8) {
              startIdx = i;
              break;
            }
          }
          if (startIdx == -1) {
            _len = 0;
            break;
          }

          // Find EOI (0xFF 0xD9) after SOI
          int endIdx = -1;
          for (int i = startIdx + 2; i <= _len - 2; i++) {
            if (_buf[i] == 0xFF && _buf[i + 1] == 0xD9) {
              endIdx = i;
              break;
            }
          }
          if (endIdx == -1) {
            if (startIdx > 0) {
              final remaining = _len - startIdx;
              _buf.setRange(0, remaining, _buf, startIdx);
              _len = remaining;
            }
            break;
          }

          // Complete frame
          final frameLen = endIdx + 2 - startIdx;
          final jpegBytes = Uint8List.fromList(
            _buf.buffer.asUint8List(_buf.offsetInBytes + startIdx, frameLen),
          );

          // Compact buffer
          final consumed = endIdx + 2;
          final remaining = _len - consumed;
          if (remaining > 0) {
            _buf.setRange(0, remaining, _buf, consumed);
          }
          _len = remaining;

          // Emit frame
          if (_frameController != null && !_frameController!.isClosed) {
            final now = DateTime.now().toUtc();
            _frameController!.add(CameraFrame(
              camId: camId,
              jpegBytes: jpegBytes,
              tsMonoMs: now.millisecondsSinceEpoch,
              wallIso: now.toIso8601String().replaceAll(':', '-'),
            ));

            _frameCount++;
            final nowMs = now.millisecondsSinceEpoch;
            if (nowMs - _lastLogTime >= 1000) {
              print('[MjpegClient] cam$camId: $_frameCount frames/sec from network');
              _frameCount = 0;
              _lastLogTime = nowMs;
            }
          }
        }

        if (_len > 10 * 1024 * 1024) {
          _len = 0;
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
    try {
      _httpClient?.close(force: true);
    } catch (_) {}
    _httpClient = null;
  }

  Future<void> close() async {
    _isRunning = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cleanup();
    await _frameController?.close();
    _frameController = null;
  }
}
