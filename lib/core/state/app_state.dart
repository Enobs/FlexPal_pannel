import 'package:flutter/foundation.dart';
import '../models/settings.dart';
import '../models/parsed_packet.dart';

/// Chamber state (tracks online status and latest telemetry)
class ChamberState {
  final int id;
  final bool isOnline;
  final DateTime? lastSeen;
  final ParsedPacket? lastPacket;

  ChamberState({
    required this.id,
    this.isOnline = false,
    this.lastSeen,
    this.lastPacket,
  });

  ChamberState copyWith({
    bool? isOnline,
    DateTime? lastSeen,
    ParsedPacket? lastPacket,
  }) {
    return ChamberState(
      id: id,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      lastPacket: lastPacket ?? this.lastPacket,
    );
  }
}

/// Application state
class AppState extends ChangeNotifier {
  Settings _settings = Settings();
  final Map<int, ChamberState> _chambers = {};
  final List<ParsedPacket> _recentPackets = [];

  bool _udpRunning = false;
  bool _sending = false;
  bool _recording = false;
  String? _recordingEpisodeId;

  int _sendCount = 0;
  int _recvCount = 0;

  AppState() {
    // Initialize 9 chambers
    for (int i = 1; i <= 9; i++) {
      _chambers[i] = ChamberState(id: i);
    }
  }

  // Getters
  Settings get settings => _settings;
  Map<int, ChamberState> get chambers => Map.unmodifiable(_chambers);
  List<ParsedPacket> get recentPackets => List.unmodifiable(_recentPackets);
  bool get udpRunning => _udpRunning;
  bool get sending => _sending;
  bool get recording => _recording;
  String? get recordingEpisodeId => _recordingEpisodeId;
  int get sendCount => _sendCount;
  int get recvCount => _recvCount;

  int get onlineChamberCount => _chambers.values.where((c) => c.isOnline).length;

  // Setters

  void updateSettings(Settings settings) {
    _settings = settings;
    notifyListeners();
  }

  void setUdpRunning(bool running) {
    _udpRunning = running;
    notifyListeners();
  }

  void setSending(bool sending) {
    _sending = sending;
    notifyListeners();
  }

  void setRecording(bool recording, {String? episodeId}) {
    _recording = recording;
    _recordingEpisodeId = episodeId;
    notifyListeners();
  }

  void updateSendCount(int count) {
    _sendCount = count;
    notifyListeners();
  }

  void updateRecvCount(int count) {
    _recvCount = count;
    notifyListeners();
  }

  void onPacketReceived(ParsedPacket packet) {
    // Update chamber state
    final chamber = _chambers[packet.chamberId];
    if (chamber != null) {
      _chambers[packet.chamberId] = chamber.copyWith(
        isOnline: true,
        lastSeen: packet.timestamp,
        lastPacket: packet,
      );
    }

    // Add to recent packets (keep last 1000)
    _recentPackets.add(packet);
    if (_recentPackets.length > 1000) {
      _recentPackets.removeAt(0);
    }

    _recvCount++;
    notifyListeners();
  }

  void checkChamberTimeouts() {
    // Mark chambers offline if no packet in 1 second
    final now = DateTime.now();
    bool changed = false;

    for (final chamber in _chambers.values) {
      if (chamber.isOnline && chamber.lastSeen != null) {
        if (now.difference(chamber.lastSeen!).inSeconds > 1) {
          _chambers[chamber.id] = chamber.copyWith(isOnline: false);
          changed = true;
        }
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  void reset() {
    _sendCount = 0;
    _recvCount = 0;
    for (int i = 1; i <= 9; i++) {
      _chambers[i] = ChamberState(id: i);
    }
    _recentPackets.clear();
    notifyListeners();
  }
}
