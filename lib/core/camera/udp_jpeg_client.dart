import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'camera_frame.dart';

/// UDP JPEG stream client - receives RTP-wrapped JPEG frames over UDP.
/// Much lower latency and more consistent timing than MJPEG over HTTP.
class UdpJpegClient {
  final String host;
  final int port;
  final int camId;

  RawDatagramSocket? _socket;
  StreamController<CameraFrame>? _frameController;
  bool _isRunning = false;

  // RTP packet reassembly
  final Map<int, _RtpFrame> _pendingFrames = {};
  int _lastEmittedTimestamp = 0;

  // Stats
  int _frameCount = 0;
  int _lastLogTime = 0;

  UdpJpegClient({
    required this.host,
    required this.port,
    required this.camId,
  });

  /// Stream of complete JPEG frames
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

    try {
      // Bind to receive UDP packets on any interface
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
      _socket!.broadcastEnabled = true;

      print('[UdpJpegClient] cam$camId listening on port $port');

      _lastLogTime = DateTime.now().millisecondsSinceEpoch;

      _socket!.listen(
        (RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            final datagram = _socket!.receive();
            if (datagram != null) {
              _processRtpPacket(datagram.data);
            }
          }
        },
        onError: (error) {
          print('[UdpJpegClient] cam$camId error: $error');
          if (_frameController != null && !_frameController!.isClosed) {
            _frameController!.addError(error);
          }
        },
        onDone: () {
          print('[UdpJpegClient] cam$camId socket closed');
        },
      );
    } catch (e) {
      print('[UdpJpegClient] cam$camId failed to start: $e');
      if (_frameController != null && !_frameController!.isClosed) {
        _frameController!.addError(e);
      }
    }
  }

  /// Process incoming RTP packet
  void _processRtpPacket(Uint8List data) {
    if (data.length < 12) return; // RTP header minimum

    // Parse RTP header
    // final version = (data[0] >> 6) & 0x03;
    // final padding = (data[0] >> 5) & 0x01;
    // final extension = (data[0] >> 4) & 0x01;
    // final csrcCount = data[0] & 0x0F;
    final marker = (data[1] >> 7) & 0x01; // Last packet of frame
    // final payloadType = data[1] & 0x7F;
    final seqNum = (data[2] << 8) | data[3];
    final timestamp = (data[4] << 24) | (data[5] << 16) | (data[6] << 8) | data[7];
    // final ssrc = (data[8] << 24) | (data[9] << 16) | (data[10] << 8) | data[11];

    // RTP JPEG header starts at byte 12
    // Skip RTP JPEG header (8 bytes minimum)
    if (data.length < 20) return;

    final jpegHeaderOffset = 12;
    // final typeSpecific = data[jpegHeaderOffset];
    final fragmentOffset = (data[jpegHeaderOffset + 1] << 16) |
        (data[jpegHeaderOffset + 2] << 8) |
        data[jpegHeaderOffset + 3];
    // final type = data[jpegHeaderOffset + 4];
    // final q = data[jpegHeaderOffset + 5];
    // final width = data[jpegHeaderOffset + 6] * 8;
    // final height = data[jpegHeaderOffset + 7] * 8;

    // Payload starts after RTP JPEG header (usually 8 bytes, but can vary)
    int payloadStart = jpegHeaderOffset + 8;

    // Check for quantization tables (q >= 128)
    final q = data[jpegHeaderOffset + 5];
    if (q >= 128 && fragmentOffset == 0) {
      // Quantization header present
      if (data.length > payloadStart + 4) {
        final qtLength = (data[payloadStart + 2] << 8) | data[payloadStart + 3];
        payloadStart += 4 + qtLength;
      }
    }

    if (payloadStart >= data.length) return;

    final payload = data.sublist(payloadStart);

    // Get or create pending frame
    var frame = _pendingFrames[timestamp];
    if (frame == null) {
      frame = _RtpFrame(timestamp);
      _pendingFrames[timestamp] = frame;
    }

    // Add fragment
    frame.addFragment(fragmentOffset, seqNum, payload);

    // Check if frame is complete (marker bit set)
    if (marker == 1) {
      frame.markerReceived = true;
    }

    // Try to emit complete frame
    if (frame.markerReceived && frame.isComplete()) {
      _emitFrame(timestamp, frame);
    }

    // Cleanup old pending frames (older than 100ms worth of timestamps)
    _cleanupOldFrames(timestamp);
  }

  void _emitFrame(int rtpTimestamp, _RtpFrame frame) {
    if (rtpTimestamp <= _lastEmittedTimestamp) return; // Already emitted or old

    final jpegData = frame.assemble();
    if (jpegData == null) return;

    _lastEmittedTimestamp = rtpTimestamp;
    _pendingFrames.remove(rtpTimestamp);

    // Emit frame
    if (_frameController != null && !_frameController!.isClosed) {
      final now = DateTime.now().toUtc();
      _frameController!.add(CameraFrame(
        camId: camId,
        jpegBytes: jpegData,
        tsMonoMs: now.millisecondsSinceEpoch,
        wallIso: now.toIso8601String().replaceAll(':', '-'),
      ));

      _frameCount++;
      final nowMs = now.millisecondsSinceEpoch;
      if (nowMs - _lastLogTime >= 1000) {
        print('[UdpJpegClient] cam$camId: $_frameCount frames/sec');
        _frameCount = 0;
        _lastLogTime = nowMs;
      }
    }
  }

  void _cleanupOldFrames(int currentTimestamp) {
    // RTP timestamp is 90kHz clock, so 9000 = 100ms
    const maxAge = 9000;
    _pendingFrames.removeWhere((ts, _) =>
        (currentTimestamp - ts).abs() > maxAge && ts != currentTimestamp);
  }

  Future<void> close() async {
    _isRunning = false;
    _socket?.close();
    _socket = null;
    _pendingFrames.clear();
    await _frameController?.close();
    _frameController = null;
    print('[UdpJpegClient] cam$camId closed');
  }
}

/// Reassembles RTP fragments into complete JPEG frame
class _RtpFrame {
  final int timestamp;
  final Map<int, _Fragment> _fragments = {};
  bool markerReceived = false;

  _RtpFrame(this.timestamp);

  void addFragment(int offset, int seqNum, Uint8List data) {
    _fragments[offset] = _Fragment(offset, seqNum, data);
  }

  bool isComplete() {
    if (!markerReceived) return false;
    if (_fragments.isEmpty) return false;

    // Check if we have fragment at offset 0
    if (!_fragments.containsKey(0)) return false;

    // Simple check: we have the first and marker bit is set
    // More robust check would verify no gaps
    return true;
  }

  Uint8List? assemble() {
    if (_fragments.isEmpty) return null;

    // Sort fragments by offset
    final sorted = _fragments.values.toList()
      ..sort((a, b) => a.offset.compareTo(b.offset));

    // Calculate total size
    int totalSize = 0;
    for (final frag in sorted) {
      final end = frag.offset + frag.data.length;
      if (end > totalSize) totalSize = end;
    }

    // Build JPEG with proper header
    // RTP JPEG doesn't include SOI/EOI markers, we need to add them
    final jpegData = Uint8List(totalSize + 2 + 2); // SOI + data + EOI

    // SOI marker
    jpegData[0] = 0xFF;
    jpegData[1] = 0xD8;

    // Copy fragments
    for (final frag in sorted) {
      jpegData.setRange(2 + frag.offset, 2 + frag.offset + frag.data.length, frag.data);
    }

    // EOI marker
    jpegData[jpegData.length - 2] = 0xFF;
    jpegData[jpegData.length - 1] = 0xD9;

    return jpegData;
  }
}

class _Fragment {
  final int offset;
  final int seqNum;
  final Uint8List data;

  _Fragment(this.offset, this.seqNum, this.data);
}
