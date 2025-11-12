import 'dart:typed_data';
import '../models/parsed_packet.dart';

/// Parses telemetry packets from STM32
class PacketParser {
  static String? _lastError;

  /// Get last parse error for debugging
  static String? get lastError => _lastError;

  /// Parse incoming telemetry packet
  ///
  /// Supports both:
  /// - 37-byte packets: Chamber ID + Length + 6×IMU + Pressure + Battery
  /// - 40-byte packets: Same as above + 3 extra bytes (possibly padding or CRLF)
  ///
  /// Packet structure (Little Endian):
  /// - Byte 0: Chamber ID (1-9)
  /// - Bytes 1-4: Length (Float32LE) mm
  /// - Bytes 5-28: IMU data (6×Float32LE): AccelX/Y/Z, GyroX/Y/Z
  /// - Bytes 29-32: Pressure (Float32LE) kPa
  /// - Bytes 33-36: Battery (Float32LE) 0-100%
  /// - Bytes 37-39: Optional padding/CRLF (ignored)
  ///
  /// Returns ParsedPacket or null if invalid
  static ParsedPacket? parse(Uint8List buffer, String sourceIp, int sourcePort) {
    _lastError = null;

    // Accept 37-byte or 40-byte packets
    if (buffer.length != 37 && buffer.length != 40) {
      _lastError = 'Invalid packet size: ${buffer.length} bytes (expected 37 or 40)';
      return null;
    }

    try {
      final data = ByteData.sublistView(buffer);

      final chamberId = data.getUint8(0);
      if (chamberId < 1 || chamberId > 9) {
        _lastError = 'Invalid chamber ID: $chamberId (expected 1-9)';
        return null;
      }

      final lengthMm = data.getFloat32(1, Endian.little);
      final accelX = data.getFloat32(5, Endian.little);
      final accelY = data.getFloat32(9, Endian.little);
      final accelZ = data.getFloat32(13, Endian.little);
      final gyroX = data.getFloat32(17, Endian.little);
      final gyroY = data.getFloat32(21, Endian.little);
      final gyroZ = data.getFloat32(25, Endian.little);
      final pressure = data.getFloat32(29, Endian.little);
      final battery = data.getFloat32(33, Endian.little);

      // Sanity check values
      if (lengthMm.isNaN || lengthMm.isInfinite) {
        _lastError = 'Invalid length value: $lengthMm';
        return null;
      }
      if (pressure.isNaN || pressure.isInfinite) {
        _lastError = 'Invalid pressure value: $pressure';
        return null;
      }
      if (battery.isNaN || battery.isInfinite || battery < 0 || battery > 100) {
        _lastError = 'Invalid battery value: $battery';
        return null;
      }

      return ParsedPacket(
        chamberId: chamberId,
        lengthMm: lengthMm,
        accelX: accelX,
        accelY: accelY,
        accelZ: accelZ,
        gyroX: gyroX,
        gyroY: gyroY,
        gyroZ: gyroZ,
        pressure: pressure,
        battery: battery,
        timestamp: DateTime.now(),
        sourceIp: sourceIp,
        sourcePort: sourcePort,
      );
    } catch (e) {
      _lastError = 'Parse exception: $e';
      return null;
    }
  }

  /// Validate packet buffer
  static bool isValid(Uint8List buffer) {
    if (buffer.length != 37) return false;
    final chamberId = buffer[0];
    return chamberId >= 1 && chamberId <= 9;
  }
}
