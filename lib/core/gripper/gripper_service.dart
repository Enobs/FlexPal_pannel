import 'dart:async';
import 'dart:io';

/// UDP service for controlling the gripper on Raspberry Pi
class GripperService {
  RawDatagramSocket? _socket;
  String _ip = '192.168.137.124';
  int _port = 5010;
  int _maxAngle = 80;
  bool _enabled = true;

  double _currentAngle = 0;
  bool _isConnected = false;

  final _statusController = StreamController<GripperStatus>.broadcast();
  final _logController = StreamController<String>.broadcast();

  // Getters
  Stream<GripperStatus> get status => _statusController.stream;
  Stream<String> get logs => _logController.stream;
  double get currentAngle => _currentAngle;
  bool get isConnected => _isConnected;
  int get maxAngle => _maxAngle;
  bool get enabled => _enabled;

  /// Initialize the gripper service
  Future<void> init(String ip, int port, int maxAngle, bool enabled) async {
    _ip = ip;
    _port = port;
    _maxAngle = maxAngle;
    _enabled = enabled;

    if (!_enabled) {
      _log('Gripper service disabled');
      return;
    }

    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket!.listen(_handleResponse);
      _isConnected = true;
      _log('Gripper service initialized: $_ip:$_port');

      // Request initial status
      await getStatus();
    } catch (e) {
      _log('ERROR: Failed to initialize gripper service: $e');
      _isConnected = false;
    }
  }

  /// Update settings
  void updateSettings(String ip, int port, int maxAngle, bool enabled) {
    _ip = ip;
    _port = port;
    _maxAngle = maxAngle;
    _enabled = enabled;
  }

  /// Send a command to the gripper
  Future<String?> _sendCommand(String command) async {
    if (!_enabled || _socket == null) {
      _log('Gripper disabled or not initialized');
      return null;
    }

    try {
      final data = command.codeUnits;
      _socket!.send(data, InternetAddress(_ip), _port);
      _log('Sent: $command');
      return command;
    } catch (e) {
      _log('ERROR: Failed to send command: $e');
      return null;
    }
  }

  /// Handle incoming response
  void _handleResponse(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final datagram = _socket?.receive();
      if (datagram != null) {
        final response = String.fromCharCodes(datagram.data);
        _log('Received: $response');
        _parseResponse(response);
      }
    }
  }

  /// Parse response from gripper
  void _parseResponse(String response) {
    // Format: OK:COMMAND:ANGLE or ERROR:message
    final parts = response.split(':');
    if (parts.length >= 3 && parts[0] == 'OK') {
      final angle = double.tryParse(parts[2]);
      if (angle != null) {
        _currentAngle = angle;
        _isConnected = true;
        _statusController.add(GripperStatus(
          angle: _currentAngle,
          isConnected: true,
          command: parts[1],
        ));
      }
    } else if (parts[0] == 'ERROR') {
      _log('Gripper error: ${parts.skip(1).join(':')}');
    }
  }

  /// Set gripper angle (0 to maxAngle)
  Future<void> setAngle(double angle) async {
    angle = angle.clamp(0, _maxAngle.toDouble());
    await _sendCommand('ANGLE:${angle.toStringAsFixed(1)}');
  }

  /// Open gripper fully
  Future<void> open() async {
    await _sendCommand('OPEN');
  }

  /// Close gripper fully
  Future<void> close() async {
    await _sendCommand('CLOSE');
  }

  /// Set gripper to half position
  Future<void> half() async {
    await _sendCommand('HALF');
  }

  /// Get current status
  Future<void> getStatus() async {
    await _sendCommand('STATUS');
  }

  /// Dispose resources
  void dispose() {
    _socket?.close();
    _socket = null;
    _statusController.close();
    _logController.close();
    _isConnected = false;
    _log('Gripper service disposed');
  }

  void _log(String message) {
    print('[GripperService] $message');
    if (!_logController.isClosed) {
      _logController.add(message);
    }
  }
}

/// Gripper status data
class GripperStatus {
  final double angle;
  final bool isConnected;
  final String command;

  GripperStatus({
    required this.angle,
    required this.isConnected,
    required this.command,
  });
}
