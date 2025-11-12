import 'dart:convert';
import 'settings.dart';

/// Manifest for a VLA recording episode
class EpisodeManifest {
  final int version;
  final String episodeId;
  final String episodeName;
  final String createdAt; // ISO 8601
  final String platform;
  final Settings settings;
  final String? notes;

  EpisodeManifest({
    this.version = 1,
    required this.episodeId,
    required this.episodeName,
    required this.createdAt,
    required this.platform,
    required this.settings,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'episode_id': episodeId,
      'episode_name': episodeName,
      'created_at': createdAt,
      'platform': platform,
      'settings': settings.toJson(),
      if (notes != null) 'notes': notes,
    };
  }

  factory EpisodeManifest.fromJson(Map<String, dynamic> json) {
    return EpisodeManifest(
      version: json['version'] as int? ?? 1,
      episodeId: json['episode_id'] as String,
      episodeName: json['episode_name'] as String,
      createdAt: json['created_at'] as String,
      platform: json['platform'] as String,
      settings: Settings.fromJson(json['settings'] as Map<String, dynamic>),
      notes: json['notes'] as String?,
    );
  }

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());
}
