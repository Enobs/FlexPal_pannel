import 'dart:typed_data';

/// Represents a single camera frame with metadata
class CameraFrame {
  final int camId;
  final Uint8List jpegBytes;
  final int tsMonoMs;       // Monotonic timestamp in milliseconds
  final String wallIso;     // ISO8601 UTC wall-clock time
  final int? width;
  final int? height;

  const CameraFrame({
    required this.camId,
    required this.jpegBytes,
    required this.tsMonoMs,
    required this.wallIso,
    this.width,
    this.height,
  });

  /// Create a copy with updated dimensions
  CameraFrame copyWithDimensions(int w, int h) {
    return CameraFrame(
      camId: camId,
      jpegBytes: jpegBytes,
      tsMonoMs: tsMonoMs,
      wallIso: wallIso,
      width: w,
      height: h,
    );
  }

  @override
  String toString() {
    return 'CameraFrame(cam: $camId, size: ${jpegBytes.length} bytes, ${width ?? '?'}x${height ?? '?'}, mono: $tsMonoMs, wall: $wallIso)';
  }
}

/// Camera status information
class CameraStatus {
  final int camId;
  final bool isOnline;
  final double fps;
  final int? width;
  final int? height;
  final String? error;

  const CameraStatus({
    required this.camId,
    required this.isOnline,
    this.fps = 0.0,
    this.width,
    this.height,
    this.error,
  });

  CameraStatus copyWith({
    bool? isOnline,
    double? fps,
    int? width,
    int? height,
    String? error,
  }) {
    return CameraStatus(
      camId: camId,
      isOnline: isOnline ?? this.isOnline,
      fps: fps ?? this.fps,
      width: width ?? this.width,
      height: height ?? this.height,
      error: error ?? this.error,
    );
  }

  @override
  String toString() {
    return 'CameraStatus(cam: $camId, online: $isOnline, fps: ${fps.toStringAsFixed(1)}, ${width ?? '?'}x${height ?? '?'})';
  }
}
