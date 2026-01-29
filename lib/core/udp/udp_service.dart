import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../models/parsed_packet.dart';
import 'packet_builder.dart';
import 'packet_parser.dart';

/// UDP communication service for FlexPAL system
class UdpService {
  RawDatagramSocket? _sendSocket;  // Send commands on port 5005
  RawDatagramSocket? _recvSocket;  // Receive telemetry on port 5006
  Timer? _sendTimer;

  final _packetController = StreamController<ParsedPacket>.broadcast();
  final _logController = StreamController<String>.broadcast();

  String _broadcastAddress = '192.168.137.255';
  int _sendPort = 5005;  // Commands: App -> Boards
  int _recvPort = 5006;  // Telemetry: Boards -> App
  int _sendRateHz = 25;
  int _mode = 3;
  List<int> _targets = List.filled(9, 0);

  bool _isRunning = false;
  bool _isSending = false;
  int _sendSeq = 0;
  int _recvCount = 0;
  int _parseErrorCount = 0;

  // Getters
  Stream<ParsedPacket> get packets => _packetController.stream;
  Stream<String> get logs => _logController.stream;
  bool get isRunning => _isRunning;
  bool get isSending => _isSending;
  int get sendSeq => _sendSeq;
  int get recvCount => _recvCount;
  int get parseErrorCount => _parseErrorCount;

  /// Start UDP service
  /// - Send commands to broadcastAddress:sendPort (5005)
  /// - Receive telemetry on recvPort (5006)
  Future<void> start(String broadcastAddress, int sendPort, int recvPort) async {
    if (_isRunning) {
      _log('UDP service already running');
      return;
    }

    _broadcastAddress = broadcastAddress;
    _sendPort = sendPort;
    _recvPort = recvPort;

    try {
      // Create send socket (any port, broadcast enabled)
      _sendSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _sendSocket!.broadcastEnabled = true;

      // Create receive socket on port 5006 for telemetry
      _recvSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _recvPort);
      _recvSocket!.listen(_handleIncomingPacket);

      _isRunning = true;
      _log('UDP service started: send to $_broadcastAddress:$_sendPort, recv on :$_recvPort');
    } catch (e) {
      _log('ERROR: Failed to start UDP service: $e');
      await stop();
      rethrow;
    }
  }

  /// Stop UDP service and cleanup
  Future<void> stop() async {
    await stopSending();

    _sendSocket?.close();
    _recvSocket?.close();
    _sendSocket = null;
    _recvSocket = null;

    _isRunning = false;
    _sendSeq = 0;
    _recvCount = 0;
    _parseErrorCount = 0;

    _log('UDP service stopped');
  }

  /// Start sending command packets at configured rate
  void startSending() {
    if (_isSending) return;
    if (!_isRunning) {
      _log('ERROR: Cannot start sending - UDP service not running');
      return;
    }

    _sendSeq = 0;
    _isSending = true;

    final intervalMs = (1000 / _sendRateHz).round();
    _sendTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      _sendCommandPacket();
    });

    _log('Started sending at ${_sendRateHz}Hz (mode: ${PacketBuilder.getModeName(_mode)})');
  }

  /// Stop sending command packets
  Future<void> stopSending() async {
    if (!_isSending) return;

    _sendTimer?.cancel();
    _sendTimer = null;
    _isSending = false;

    _log('Stopped sending (sent $_sendSeq packets)');
  }

  /// Set control mode (1=Pressure, 2=PWM, 3=Length)
  void setMode(int mode) {
    if (mode < 1 || mode > 3) {
      _log('ERROR: Invalid mode $mode');
      return;
    }

    final wasRunning = _isSending;
    if (wasRunning) {
      stopSending();
    }

    _mode = mode;
    _targets = List.filled(9, 0); // Reset targets on mode change

    _log('Mode changed to: ${PacketBuilder.getModeName(_mode)}');

    if (wasRunning) {
      startSending();
    }
  }

  /// Set target values (9 values as display doubles)
  void setTargets(List<double> values) {
    if (values.length != 9) {
      _log('ERROR: Must provide exactly 9 target values');
      return;
    }

    for (int i = 0; i < 9; i++) {
      final int32Val = PacketBuilder.convertToInt32(_mode, values[i]);
      _targets[i] = PacketBuilder.clampTarget(_mode, int32Val);
    }
  }

  /// Set single chamber target
  void setTarget(int chamberIndex, double value) {
    if (chamberIndex < 0 || chamberIndex >= 9) return;

    final int32Val = PacketBuilder.convertToInt32(_mode, value);
    final clamped = PacketBuilder.clampTarget(_mode, int32Val);
    _targets[chamberIndex] = clamped;

    // Debug log to verify negative values are set correctly
    _log('SET TARGET: Chamber ${chamberIndex + 1} = $value (display) -> $int32Val (int32) -> $clamped (clamped) [Mode: ${PacketBuilder.getModeName(_mode)}]');
  }

  /// Set send rate in Hz (10-50)
  void setRateHz(int hz) {
    if (hz < 10 || hz > 50) {
      _log('WARN: Rate $hz Hz out of range (10-50), clamping');
    }

    _sendRateHz = hz.clamp(10, 50);

    if (_isSending) {
      stopSending();
      startSending();
    }
  }

  /// Get current targets as display values
  List<double> getTargets() {
    return _targets.map((val) => PacketBuilder.convertFromInt32(_mode, val)).toList();
  }

  /// Get current mode
  int getMode() => _mode;

  /// Get last sent packet info
  (int mode, String addr, int port, List<int> targets)? getLastSent() {
    if (_sendSeq == 0) return null;
    return (_mode, _broadcastAddress, _sendPort, List.from(_targets));
  }

  // Private methods

  void _sendCommandPacket() {
    if (_sendSocket == null) return;

    final buffer = PacketBuilder.buildCommand(_mode, _targets);
    final address = InternetAddress(_broadcastAddress);

    try {
      final bytesSent = _sendSocket!.send(buffer, address, _sendPort);
      _sendSeq++;

      // Log every 25th packet to avoid spam (1 second at 25Hz)
      if (_sendSeq % 25 == 1) {
        final hexPreview = buffer.take(8).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
        final fullHex = buffer.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
        _log('Sent packet #$_sendSeq: $bytesSent bytes to $_broadcastAddress:$_sendPort');
        _log('  Full packet (hex): $fullHex');
        _log('  Target values (Int32): ${_targets.map((t) => t.toString()).join(', ')}');
        _log('  Target values (Display): ${_targets.map((t) => PacketBuilder.convertFromInt32(_mode, t).toStringAsFixed(1)).join(', ')}');
        _log('  Mode: ${PacketBuilder.getModeName(_mode)}');
      }
    } catch (e) {
      _log('ERROR: Failed to send packet: $e');
    }
  }

  void _handleIncomingPacket(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final datagram = _recvSocket!.receive();
      if (datagram == null) return;

      // Ignore command packets (shouldn't arrive on recv port, but just in case)
      if (datagram.data.length == 40 && datagram.data[0] == 0xAA) {
        return;
      }

      final packet = PacketParser.parse(
        datagram.data,
        datagram.address.address,
        datagram.port,
      );

      if (packet != null) {
        _recvCount++;
        _packetController.add(packet);
      } else {
        _parseErrorCount++;
      }
    }
  }

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    _logController.add('[$timestamp] $message');
  }

  /// Dispose resources
  void dispose() {
    stop();
    _packetController.close();
    _logController.close();
  }
}
