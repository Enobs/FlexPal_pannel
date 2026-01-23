import 'dart:convert';

/// Gripper configuration settings for UDP control
class GripperSettings {
  final String ip;
  final int port;
  final int maxAngle;
  final bool enabled;

  const GripperSettings({
    required this.ip,
    required this.port,
    required this.maxAngle,
    required this.enabled,
  });

  /// Default gripper settings
  factory GripperSettings.defaults() {
    return const GripperSettings(
      ip: '192.168.137.124',
      port: 5010,
      maxAngle: 80,
      enabled: true,
    );
  }

  /// Create from JSON map
  factory GripperSettings.fromJson(Map<String, dynamic> json) {
    return GripperSettings(
      ip: json['ip'] as String? ?? '192.168.137.124',
      port: json['port'] as int? ?? 5010,
      maxAngle: json['maxAngle'] as int? ?? 80,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'ip': ip,
      'port': port,
      'maxAngle': maxAngle,
      'enabled': enabled,
    };
  }

  /// Create from JSON string
  factory GripperSettings.fromJsonString(String jsonString) {
    return GripperSettings.fromJson(json.decode(jsonString) as Map<String, dynamic>);
  }

  /// Convert to JSON string
  String toJsonString() {
    return json.encode(toJson());
  }

  /// Create a copy with modified fields
  GripperSettings copyWith({
    String? ip,
    int? port,
    int? maxAngle,
    bool? enabled,
  }) {
    return GripperSettings(
      ip: ip ?? this.ip,
      port: port ?? this.port,
      maxAngle: maxAngle ?? this.maxAngle,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  String toString() {
    return 'GripperSettings(ip: $ip, port: $port, maxAngle: $maxAngle, enabled: $enabled)';
  }
}
