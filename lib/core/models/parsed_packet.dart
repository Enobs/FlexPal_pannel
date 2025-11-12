/// Parsed telemetry packet from STM32 (37 bytes)
class ParsedPacket {
  final int chamberId; // 1-9
  final double lengthMm;
  final double accelX;
  final double accelY;
  final double accelZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  final double pressure; // kPa
  final double battery; // 0-100%
  final DateTime timestamp;
  final String sourceIp;
  final int sourcePort;

  ParsedPacket({
    required this.chamberId,
    required this.lengthMm,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.pressure,
    required this.battery,
    required this.timestamp,
    required this.sourceIp,
    required this.sourcePort,
  });

  @override
  String toString() {
    return 'Chamber[$chamberId] L:${lengthMm.toStringAsFixed(1)}mm P:${pressure.toStringAsFixed(1)}kPa B:${battery.toStringAsFixed(0)}%';
  }
}
