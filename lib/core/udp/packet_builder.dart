import 'dart:typed_data';

/// Builds 39-byte command packets for STM32
class PacketBuilder {
  /// Build command buffer: 1 byte mode + 9×4 bytes targets + 2 bytes CRLF
  ///
  /// [mode] - 1=Pressure, 2=PWM, 3=Length
  /// [targets] - 9 Int32 values (little endian)
  ///
  /// Returns 39-byte Uint8List
  static Uint8List buildCommand(int mode, List<int> targets) {
    assert(targets.length == 9, 'Must have exactly 9 target values');
    assert(mode >= 1 && mode <= 3, 'Mode must be 1, 2, or 3');

    final buffer = ByteData(39);

    // Byte 0: CommandType
    buffer.setUint8(0, mode);

    // Bytes 1-36: 9 × Int32LE targets
    for (int i = 0; i < 9; i++) {
      buffer.setInt32(1 + i * 4, targets[i], Endian.little);
    }

    // Bytes 37-38: CRLF
    buffer.setUint8(37, 0x0D);
    buffer.setUint8(38, 0x0A);

    return buffer.buffer.asUint8List();
  }

  /// Clamp target value based on mode
  ///
  /// Mode 1 (Pressure): -100000 to 30000
  /// Mode 2 (PWM): -100 to 100
  /// Mode 3 (Length): 1500 to 3000 (representing 15.00 to 30.00 cm)
  static int clampTarget(int mode, int value) {
    switch (mode) {
      case 1: // Pressure
        return value.clamp(-100000, 30000);
      case 2: // PWM
        return value.clamp(-100, 100);
      case 3: // Length (0.1mm precision)
        return value.clamp(1500, 3000);
      default:
        return value;
    }
  }

  /// Convert user-friendly double to Int32 based on mode
  ///
  /// Mode 1 (Pressure): direct conversion
  /// Mode 2 (PWM): direct conversion (-100 to 100)
  /// Mode 3 (Length): cm * 100 (e.g., 25.50 cm -> 2550)
  static int convertToInt32(int mode, double value) {
    switch (mode) {
      case 1: // Pressure
        return value.toInt();
      case 2: // PWM
        return value.toInt();
      case 3: // Length: cm to 0.1mm
        return (value * 100).toInt();
      default:
        return value.toInt();
    }
  }

  /// Convert Int32 to user-friendly double for display
  static double convertFromInt32(int mode, int value) {
    switch (mode) {
      case 1: // Pressure
        return value.toDouble();
      case 2: // PWM
        return value.toDouble();
      case 3: // Length: 0.1mm to cm
        return value / 100.0;
      default:
        return value.toDouble();
    }
  }

  /// Get display range for mode
  static (double min, double max) getDisplayRange(int mode) {
    switch (mode) {
      case 1: // Pressure
        return (-100000.0, 30000.0);
      case 2: // PWM
        return (-100.0, 100.0);
      case 3: // Length (cm)
        return (15.0, 30.0);
      default:
        return (0.0, 100.0);
    }
  }

  /// Get unit string for mode
  static String getUnit(int mode) {
    switch (mode) {
      case 1:
        return 'Pa';
      case 2:
        return '%';
      case 3:
        return 'cm';
      default:
        return '';
    }
  }

  /// Get mode name
  static String getModeName(int mode) {
    switch (mode) {
      case 1:
        return 'Pressure';
      case 2:
        return 'PWM';
      case 3:
        return 'Length';
      default:
        return 'Unknown';
    }
  }
}
