import 'dart:typed_data';
import '../models/parsed_packet.dart';

/// Telemetry header byte - distinguishes board telemetry from app commands
const int kTelemetryHeader = 0xBB;

/// Parses telemetry packets from STM32
class PacketParser {
  static String? _lastError;

  /// Get last parse error for debugging
  static String? get lastError => _lastError;

  /// Parse incoming telemetry packet
  ///
  /// Supports both legacy and new packet formats:
  ///
  /// Legacy format (37+ bytes) - no header:
  /// - Byte 0: Chamber ID (1-9)
  /// - Bytes 1-4: Length (Float32LE) mm
  /// - Bytes 5-28: IMU data (6×Float32LE)
  /// - Bytes 29-32: Pressure (Float32LE) kPa
  /// - Bytes 33-36: Battery (Float32LE) 0-100%
  ///
  /// New format (38+ bytes) - with 0xBB header:
  /// - Byte 0: Telemetry header (0xBB)
  /// - Byte 1: Chamber ID (1-8)
  /// - Bytes 2-5: Length (Float32LE) mm
  /// - Bytes 6-29: IMU data (6×Float32LE)
  /// - Bytes 30-33: Pressure (Float32LE) kPa
  /// - Bytes 34-37: Battery (Float32LE) 0-100%
  /// - Bytes 38-39: unused (zeros)
  ///
  /// Returns ParsedPacket or null if invalid
  static ParsedPacket? parse(Uint8List buffer, String sourceIp, int sourcePort) {
    _lastError = null;

    // Determine packet format based on first byte (header check)
    final int offset;

    if (buffer[0] == kTelemetryHeader) {
      // New format with 0xBB header (38, 40, or 41 bytes)
      offset = 1;
    } else if (buffer[0] >= 1 && buffer[0] <= 9) {
      // Legacy format without header - first byte is chamber ID (37 or 40 bytes)
      offset = 0;
    } else {
      _lastError = 'Invalid first byte: 0x${buffer[0].toRadixString(16)} (expected 0xBB or chamber ID 1-9)';
      return null;
    }

    // Minimum size check: need at least 37 bytes of data + offset
    if (buffer.length < 37 + offset) {
      _lastError = 'Packet too small: ${buffer.length} bytes (need at least ${37 + offset})';
      return null;
    }

    try {
      final data = ByteData.sublistView(buffer);

      // Chamber ID position depends on format
      final chamberId = data.getUint8(offset);
      if (chamberId < 1 || chamberId > 9) {
        _lastError = 'Invalid chamber ID: $chamberId (expected 1-9)';
        return null;
      }

      // Data offsets adjusted by format offset
      final lengthMm = data.getFloat32(offset + 1, Endian.little);
      final accelX = data.getFloat32(offset + 5, Endian.little);
      final accelY = data.getFloat32(offset + 9, Endian.little);
      final accelZ = data.getFloat32(offset + 13, Endian.little);
      final gyroX = data.getFloat32(offset + 17, Endian.little);
      final gyroY = data.getFloat32(offset + 21, Endian.little);
      final gyroZ = data.getFloat32(offset + 25, Endian.little);
      final pressure = data.getFloat32(offset + 29, Endian.little);
      final battery = data.getFloat32(offset + 33, Endian.little);

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

  /// Validate packet buffer (supports both legacy and new formats)
  static bool isValid(Uint8List buffer) {
    if (buffer.isEmpty) return false;

    // New format with 0xBB header
    if (buffer[0] == kTelemetryHeader && buffer.length >= 38) {
      final chamberId = buffer[1];
      return chamberId >= 1 && chamberId <= 9;
    }
    // Legacy format without header - first byte is chamber ID
    if (buffer[0] >= 1 && buffer[0] <= 9 && buffer.length >= 37) {
      return true;
    }
    return false;
  }
}
