import 'dart:convert';

/// Individual camera configuration
class CameraConfig {
  final String ip;
  final int port;
  final bool enabled;

  const CameraConfig({
    required this.ip,
    required this.port,
    this.enabled = true,
  });

  factory CameraConfig.fromJson(Map<String, dynamic> json) {
    return CameraConfig(
      ip: json['ip'] as String? ?? '',
      port: json['port'] as int? ?? 8081,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ip': ip,
      'port': port,
      'enabled': enabled,
    };
  }

  CameraConfig copyWith({
    String? ip,
    int? port,
    bool? enabled,
  }) {
    return CameraConfig(
      ip: ip ?? this.ip,
      port: port ?? this.port,
      enabled: enabled ?? this.enabled,
    );
  }

  /// Get camera URL
  Uri? getUrl(String path) {
    if (ip.isEmpty || !enabled) return null;
    return Uri.parse('http://$ip:$port$path');
  }

  @override
  String toString() {
    return 'CameraConfig(ip: $ip, port: $port, enabled: $enabled)';
  }
}

/// Camera configuration settings for MJPEG streams
class CameraSettings {
  final CameraConfig camera1;
  final CameraConfig camera2;
  final CameraConfig camera3;
  final String path;
  final int maxViews;
  final int defaultSaveFps;
  final String outputRoot;

  // Legacy fields for backwards compatibility
  final String? baseIp;
  final List<int>? ports;

  const CameraSettings({
    required this.camera1,
    required this.camera2,
    required this.camera3,
    required this.path,
    required this.maxViews,
    required this.defaultSaveFps,
    required this.outputRoot,
    this.baseIp,
    this.ports,
  });

  /// Default camera settings
  factory CameraSettings.defaults() {
    return const CameraSettings(
      camera1: CameraConfig(ip: '192.168.137.124', port: 8081, enabled: true),
      camera2: CameraConfig(ip: '192.168.137.125', port: 8081, enabled: true),
      camera3: CameraConfig(ip: '', port: 8081, enabled: false),
      path: '/?action=stream',
      maxViews: 3,
      defaultSaveFps: 30,
      outputRoot: './VLA_Records',
    );
  }

  /// Create from JSON map (with backwards compatibility)
  factory CameraSettings.fromJson(Map<String, dynamic> json) {
    // Check for new format first
    if (json.containsKey('camera1')) {
      return CameraSettings(
        camera1: CameraConfig.fromJson(json['camera1'] as Map<String, dynamic>? ?? {}),
        camera2: CameraConfig.fromJson(json['camera2'] as Map<String, dynamic>? ?? {}),
        camera3: CameraConfig.fromJson(json['camera3'] as Map<String, dynamic>? ?? {}),
        path: json['path'] as String? ?? '/?action=stream',
        maxViews: json['maxViews'] as int? ?? 3,
        defaultSaveFps: json['defaultSaveFps'] as int? ?? 30,
        outputRoot: json['outputRoot'] as String? ?? './VLA_Records',
      );
    }

    // Legacy format: convert baseIp + ports to individual cameras
    final baseIp = json['baseIp'] as String? ?? '192.168.137.124';
    final ports = (json['ports'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [8081, 8081, 8081];

    return CameraSettings(
      camera1: CameraConfig(ip: baseIp, port: ports.isNotEmpty ? ports[0] : 8081, enabled: true),
      camera2: CameraConfig(ip: '', port: ports.length > 1 ? ports[1] : 8081, enabled: false),
      camera3: CameraConfig(ip: '', port: ports.length > 2 ? ports[2] : 8081, enabled: false),
      path: json['path'] as String? ?? '/?action=stream',
      maxViews: json['maxViews'] as int? ?? 3,
      defaultSaveFps: json['defaultSaveFps'] as int? ?? 30,
      outputRoot: json['outputRoot'] as String? ?? './VLA_Records',
      baseIp: baseIp,
      ports: ports,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'camera1': camera1.toJson(),
      'camera2': camera2.toJson(),
      'camera3': camera3.toJson(),
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
    CameraConfig? camera1,
    CameraConfig? camera2,
    CameraConfig? camera3,
    String? path,
    int? maxViews,
    int? defaultSaveFps,
    String? outputRoot,
  }) {
    return CameraSettings(
      camera1: camera1 ?? this.camera1,
      camera2: camera2 ?? this.camera2,
      camera3: camera3 ?? this.camera3,
      path: path ?? this.path,
      maxViews: maxViews ?? this.maxViews,
      defaultSaveFps: defaultSaveFps ?? this.defaultSaveFps,
      outputRoot: outputRoot ?? this.outputRoot,
    );
  }

  /// Get camera config by index (0-2)
  CameraConfig getCamera(int index) {
    switch (index) {
      case 0:
        return camera1;
      case 1:
        return camera2;
      case 2:
        return camera3;
      default:
        return camera1;
    }
  }

  /// Get camera URLs for active views
  List<Uri> getCameraUrls() {
    final List<Uri> urls = [];
    final cameras = [camera1, camera2, camera3];
    final numCameras = maxViews.clamp(1, 3);

    for (int i = 0; i < numCameras; i++) {
      final url = cameras[i].getUrl(path);
      if (url != null) {
        urls.add(url);
      }
    }

    return urls;
  }

  /// Get URL for specific camera index
  Uri? getCameraUrl(int index) {
    return getCamera(index).getUrl(path);
  }

  @override
  String toString() {
    return 'CameraSettings(cam1: ${camera1.ip}:${camera1.port}, cam2: ${camera2.ip}:${camera2.port}, cam3: ${camera3.ip}:${camera3.port}, path: $path, maxViews: $maxViews, fps: $defaultSaveFps)';
  }
}
