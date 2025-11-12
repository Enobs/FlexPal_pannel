import 'dart:convert';

/// Camera configuration settings for MJPEG streams
class CameraSettings {
  final String baseIp;
  final List<int> ports;
  final String path;
  final int maxViews;
  final int defaultSaveFps;
  final String outputRoot;

  const CameraSettings({
    required this.baseIp,
    required this.ports,
    required this.path,
    required this.maxViews,
    required this.defaultSaveFps,
    required this.outputRoot,
  });

  /// Default camera settings
  factory CameraSettings.defaults() {
    return const CameraSettings(
      baseIp: '172.31.243.152',
      ports: [8080, 8081, 8082],
      path: '/?action=stream',
      maxViews: 3,
      defaultSaveFps: 30,
      outputRoot: './VLA_Records',
    );
  }

  /// Create from JSON map
  factory CameraSettings.fromJson(Map<String, dynamic> json) {
    return CameraSettings(
      baseIp: json['baseIp'] as String? ?? '172.31.243.152',
      ports: (json['ports'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [8080, 8081, 8082],
      path: json['path'] as String? ?? '/?action=stream',
      maxViews: json['maxViews'] as int? ?? 3,
      defaultSaveFps: json['defaultSaveFps'] as int? ?? 30,
      outputRoot: json['outputRoot'] as String? ?? './VLA_Records',
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'baseIp': baseIp,
      'ports': ports,
      'path': path,
      'maxViews': maxViews,
      'defaultSaveFps': defaultSaveFps,
      'outputRoot': outputRoot,
    };
  }

  /// Create from JSON string
  factory CameraSettings.fromJsonString(String jsonString) {
    return CameraSettings.fromJson(json.decode(jsonString) as Map<String, dynamic>);
  }

  /// Convert to JSON string
  String toJsonString() {
    return json.encode(toJson());
  }

  /// Create a copy with modified fields
  CameraSettings copyWith({
    String? baseIp,
    List<int>? ports,
    String? path,
    int? maxViews,
    int? defaultSaveFps,
    String? outputRoot,
  }) {
    return CameraSettings(
      baseIp: baseIp ?? this.baseIp,
      ports: ports ?? this.ports,
      path: path ?? this.path,
      maxViews: maxViews ?? this.maxViews,
      defaultSaveFps: defaultSaveFps ?? this.defaultSaveFps,
      outputRoot: outputRoot ?? this.outputRoot,
    );
  }

  /// Get camera URLs for active views
  List<Uri> getCameraUrls() {
    final List<Uri> urls = [];
    final numCameras = maxViews.clamp(1, ports.length);

    for (int i = 0; i < numCameras; i++) {
      urls.add(Uri.parse('http://$baseIp:${ports[i]}$path'));
    }

    return urls;
  }

  @override
  String toString() {
    return 'CameraSettings(baseIp: $baseIp, ports: $ports, path: $path, maxViews: $maxViews, fps: $defaultSaveFps)';
  }
}
