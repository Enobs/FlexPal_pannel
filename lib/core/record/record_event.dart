import '../models/parsed_packet.dart';

/// Event types for the recorder isolate
abstract class RecordEvent {}

class CommandEvent extends RecordEvent {
  final int seq;
  final DateTime timestamp;
  final int mode;
  final String address;
  final int port;
  final List<int> targets;

  CommandEvent({
    required this.seq,
    required this.timestamp,
    required this.mode,
    required this.address,
    required this.port,
    required this.targets,
  });
}

class TelemetryEvent extends RecordEvent {
  final ParsedPacket packet;

  TelemetryEvent(this.packet);
}

class FlushEvent extends RecordEvent {}

class StopEvent extends RecordEvent {}
