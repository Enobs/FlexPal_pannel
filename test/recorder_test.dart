import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flexpal_control/core/record/recorder.dart';
import 'package:flexpal_control/core/models/settings.dart';
import 'package:flexpal_control/core/models/parsed_packet.dart';

void main() {
  group('Recorder', () {
    late Directory tempDir;
    late Recorder recorder;

    setUp(() async {
      // Create temporary directory for tests
      tempDir = await Directory.systemTemp.createTemp('flexpal_test_');
      recorder = Recorder(tempDir.path);
    });

    tearDown(() async {
      // Clean up
      if (recorder.isRecording) {
        await recorder.stopEpisode();
      }
      recorder.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('starts and stops recording episode', () async {
      expect(recorder.isRecording, isFalse);
      expect(recorder.currentEpisodeId, isNull);

      await recorder.startEpisode(
        episodeName: 'test_episode',
        settings: Settings(),
      );

      expect(recorder.isRecording, isTrue);
      expect(recorder.currentEpisodeId, isNotNull);

      // Wait a bit for isolate to initialize
      await Future.delayed(const Duration(milliseconds: 500));

      await recorder.stopEpisode();

      expect(recorder.isRecording, isFalse);
      expect(recorder.currentEpisodeId, isNull);
    });

    test('creates episode directory and files', () async {
      await recorder.startEpisode(
        episodeName: 'test_episode',
        settings: Settings(),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      // Check directory was created
      expect(recorder.currentEpisodePath, isNotNull);
      final episodeDir = Directory(recorder.currentEpisodePath!);
      expect(await episodeDir.exists(), isTrue);

      // Check manifest exists
      final manifestFile = File('${recorder.currentEpisodePath}/manifest.json');
      expect(await manifestFile.exists(), isTrue);

      await recorder.stopEpisode();

      // Check CSV files were created
      final commandsFile = File('${episodeDir.path}/commands.csv');
      final telemetryFile = File('${episodeDir.path}/telemetry.csv');

      expect(await commandsFile.exists(), isTrue);
      expect(await telemetryFile.exists(), isTrue);

      // Verify CSV headers
      final commandsContent = await commandsFile.readAsString();
      expect(commandsContent, contains('version,episode_id,seq,ts_ms,wall_time_iso'));

      final telemetryContent = await telemetryFile.readAsString();
      expect(telemetryContent, contains('version,episode_id,ts_ms,wall_time_iso,chamber_id'));
    });

    test('records command events', () async {
      await recorder.startEpisode(
        episodeName: 'test_commands',
        settings: Settings(),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      // Save path before stopping
      final episodePath = recorder.currentEpisodePath!;

      // Send some commands
      for (int i = 0; i < 5; i++) {
        recorder.onCommandTick(
          i,
          DateTime.now(),
          3,
          '192.168.137.255',
          5005,
          List.filled(9, i * 100),
        );
        await Future.delayed(const Duration(milliseconds: 50));
      }

      await recorder.stopEpisode();

      // Check commands were recorded
      final commandsFile = File('$episodePath/commands.csv');
      final lines = await commandsFile.readAsLines();

      expect(lines.length, greaterThan(1)); // Header + data
      expect(lines.length, 6); // Header + 5 commands
    });

    test('records telemetry events', () async {
      await recorder.startEpisode(
        episodeName: 'test_telemetry',
        settings: Settings(),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      // Save path before stopping
      final episodePath = recorder.currentEpisodePath!;

      // Send some telemetry packets
      for (int i = 1; i <= 9; i++) {
        final packet = ParsedPacket(
          chamberId: i,
          lengthMm: 20.0 + i,
          accelX: 0.1 * i,
          accelY: 0.2 * i,
          accelZ: 9.8,
          gyroX: 0.01 * i,
          gyroY: 0.02 * i,
          gyroZ: 0.0,
          pressure: 1000.0 * i,
          battery: 80.0 + i,
          timestamp: DateTime.now(),
          sourceIp: '192.168.1.100',
          sourcePort: 5006,
        );
        recorder.onTelemetryPacket(packet);
        await Future.delayed(const Duration(milliseconds: 20));
      }

      await recorder.stopEpisode();

      // Check telemetry was recorded
      final telemetryFile = File('$episodePath/telemetry.csv');
      final lines = await telemetryFile.readAsLines();

      expect(lines.length, greaterThan(1)); // Header + data
      expect(lines.length, 10); // Header + 9 packets
    });

    test('prevents starting recording when already recording', () async {
      await recorder.startEpisode(
        episodeName: 'first_episode',
        settings: Settings(),
      );

      await Future.delayed(const Duration(milliseconds: 300));

      final firstId = recorder.currentEpisodeId;

      // Try to start another recording
      await recorder.startEpisode(
        episodeName: 'second_episode',
        settings: Settings(),
      );

      // Should still be on first episode
      expect(recorder.currentEpisodeId, firstId);

      await recorder.stopEpisode();
      await Future.delayed(const Duration(milliseconds: 300));
    });

    test('handles episode with notes', () async {
      await recorder.startEpisode(
        episodeName: 'episode_with_notes',
        notes: 'This is a test episode',
        settings: Settings(),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      final manifestFile = File('${recorder.currentEpisodePath}/manifest.json');
      final content = await manifestFile.readAsString();

      expect(content, contains('This is a test episode'));

      await recorder.stopEpisode();
      await Future.delayed(const Duration(milliseconds: 300));
    });
  });
}
