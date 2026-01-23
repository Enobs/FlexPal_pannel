import 'dart:convert';
import '../../models/camera_settings.dart';
import '../../models/gripper_settings.dart';

/// Application settings model
class Settings {
  final String broadcastAddress;
  final int sendPort;
  final int recvPort;
  final int sendRateHz;
  final int mode; // 1=Pressure, 2=PWM, 3=Length
  final CameraSettings camera;
  final GripperSettings gripper;

  Settings({
    this.broadcastAddress = '192.168.137.255',
    this.sendPort = 5005,
    this.recvPort = 5006,
    this.sendRateHz = 25,
    this.mode = 3,
    CameraSettings? camera,
    GripperSettings? gripper,
  }) : camera = camera ?? CameraSettings.defaults(),
       gripper = gripper ?? GripperSettings.defaults();

  Settings copyWith({
    String? broadcastAddress,
    int? sendPort,
    int? recvPort,
    int? sendRateHz,
    int? mode,
    CameraSettings? camera,
    GripperSettings? gripper,
  }) {
    return Settings(
      broadcastAddress: broadcastAddress ?? this.broadcastAddress,
      sendPort: sendPort ?? this.sendPort,
      recvPort: recvPort ?? this.recvPort,
      sendRateHz: sendRateHz ?? this.sendRateHz,
      mode: mode ?? this.mode,
      camera: camera ?? this.camera,
      gripper: gripper ?? this.gripper,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'broadcastAddress': broadcastAddress,
      'sendPort': sendPort,
      'recvPort': recvPort,
      'sendRateHz': sendRateHz,
      'mode': mode,
      'camera': camera.toJson(),
      'gripper': gripper.toJson(),
    };
  }

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      broadcastAddress: json['broadcastAddress'] as String? ?? '192.168.137.255',
      sendPort: json['sendPort'] as int? ?? 5005,
      recvPort: json['recvPort'] as int? ?? 5006,
      sendRateHz: json['sendRateHz'] as int? ?? 25,
      mode: json['mode'] as int? ?? 3,
      camera: json['camera'] != null
          ? CameraSettings.fromJson(json['camera'] as Map<String, dynamic>)
          : CameraSettings.defaults(),
      gripper: json['gripper'] != null
          ? GripperSettings.fromJson(json['gripper'] as Map<String, dynamic>)
          : GripperSettings.defaults(),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory Settings.fromJsonString(String str) => Settings.fromJson(jsonDecode(str));
}
