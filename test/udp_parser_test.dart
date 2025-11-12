import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flexpal_control/core/udp/packet_parser.dart';
import 'package:flexpal_control/core/udp/packet_builder.dart';

void main() {
  group('PacketParser', () {
    test('parses valid 37-byte packet correctly', () {
      // Create a valid 37-byte packet
      final buffer = ByteData(37);
      buffer.setUint8(0, 5); // Chamber ID = 5
      buffer.setFloat32(1, 23.5, Endian.little); // Length
      buffer.setFloat32(5, 1.2, Endian.little); // AccelX
      buffer.setFloat32(9, -0.3, Endian.little); // AccelY
      buffer.setFloat32(13, 9.8, Endian.little); // AccelZ
      buffer.setFloat32(17, 0.1, Endian.little); // GyroX
      buffer.setFloat32(21, -0.05, Endian.little); // GyroY
      buffer.setFloat32(25, 0.02, Endian.little); // GyroZ
      buffer.setFloat32(29, 5000.0, Endian.little); // Pressure
      buffer.setFloat32(33, 87.5, Endian.little); // Battery

      final packet = PacketParser.parse(
        buffer.buffer.asUint8List(),
        '192.168.1.100',
        5006,
      );

      expect(packet, isNotNull);
      expect(packet!.chamberId, 5);
      expect(packet.lengthMm, closeTo(23.5, 0.01));
      expect(packet.accelX, closeTo(1.2, 0.01));
      expect(packet.accelY, closeTo(-0.3, 0.01));
      expect(packet.accelZ, closeTo(9.8, 0.01));
      expect(packet.gyroX, closeTo(0.1, 0.01));
      expect(packet.gyroY, closeTo(-0.05, 0.01));
      expect(packet.gyroZ, closeTo(0.02, 0.01));
      expect(packet.pressure, closeTo(5000.0, 0.1));
      expect(packet.battery, closeTo(87.5, 0.1));
      expect(packet.sourceIp, '192.168.1.100');
      expect(packet.sourcePort, 5006);
    });

    test('rejects packet with wrong size', () {
      final buffer = Uint8List(36); // Wrong size
      final packet = PacketParser.parse(buffer, '127.0.0.1', 5006);
      expect(packet, isNull);
    });

    test('rejects packet with invalid chamber ID', () {
      final buffer = ByteData(37);
      buffer.setUint8(0, 0); // Invalid ID (must be 1-9)
      final packet = PacketParser.parse(buffer.buffer.asUint8List(), '127.0.0.1', 5006);
      expect(packet, isNull);
    });

    test('rejects packet with chamber ID > 9', () {
      final buffer = ByteData(37);
      buffer.setUint8(0, 10); // Invalid ID
      final packet = PacketParser.parse(buffer.buffer.asUint8List(), '127.0.0.1', 5006);
      expect(packet, isNull);
    });

    test('validates packet correctly', () {
      final validBuffer = ByteData(37);
      validBuffer.setUint8(0, 5);
      expect(PacketParser.isValid(validBuffer.buffer.asUint8List()), isTrue);

      final invalidBuffer = Uint8List(36);
      expect(PacketParser.isValid(invalidBuffer), isFalse);

      final invalidIdBuffer = ByteData(37);
      invalidIdBuffer.setUint8(0, 0);
      expect(PacketParser.isValid(invalidIdBuffer.buffer.asUint8List()), isFalse);
    });
  });

  group('PacketBuilder', () {
    test('builds 39-byte command packet correctly', () {
      final targets = [100, 200, 300, 400, 500, 600, 700, 800, 900];
      final packet = PacketBuilder.buildCommand(1, targets);

      expect(packet.length, 39);
      expect(packet[0], 1); // Mode
      expect(packet[37], 0x0D); // CR
      expect(packet[38], 0x0A); // LF

      // Verify target values (little endian)
      final data = ByteData.sublistView(packet);
      for (int i = 0; i < 9; i++) {
        expect(data.getInt32(1 + i * 4, Endian.little), targets[i]);
      }
    });

    test('clamps values based on mode', () {
      // Pressure mode
      expect(PacketBuilder.clampTarget(1, -200000), -100000);
      expect(PacketBuilder.clampTarget(1, 50000), 30000);
      expect(PacketBuilder.clampTarget(1, 0), 0);

      // PWM mode
      expect(PacketBuilder.clampTarget(2, -150), -100);
      expect(PacketBuilder.clampTarget(2, 150), 100);
      expect(PacketBuilder.clampTarget(2, 50), 50);

      // Length mode
      expect(PacketBuilder.clampTarget(3, 1000), 1500);
      expect(PacketBuilder.clampTarget(3, 5000), 3000);
      expect(PacketBuilder.clampTarget(3, 2000), 2000);
    });

    test('converts display values to Int32 correctly', () {
      // Pressure mode (direct)
      expect(PacketBuilder.convertToInt32(1, 5000.0), 5000);

      // PWM mode (direct)
      expect(PacketBuilder.convertToInt32(2, 50.0), 50);

      // Length mode (cm to 0.1mm)
      expect(PacketBuilder.convertToInt32(3, 25.5), 2550);
      expect(PacketBuilder.convertToInt32(3, 20.0), 2000);
    });

    test('converts Int32 to display values correctly', () {
      // Pressure mode
      expect(PacketBuilder.convertFromInt32(1, 5000), 5000.0);

      // PWM mode
      expect(PacketBuilder.convertFromInt32(2, -50), -50.0);

      // Length mode (0.1mm to cm)
      expect(PacketBuilder.convertFromInt32(3, 2550), 25.5);
      expect(PacketBuilder.convertFromInt32(3, 2000), 20.0);
    });

    test('provides correct display ranges', () {
      expect(PacketBuilder.getDisplayRange(1), (-100000.0, 30000.0));
      expect(PacketBuilder.getDisplayRange(2), (-100.0, 100.0));
      expect(PacketBuilder.getDisplayRange(3), (15.0, 30.0));
    });

    test('provides correct units', () {
      expect(PacketBuilder.getUnit(1), 'Pa');
      expect(PacketBuilder.getUnit(2), '%');
      expect(PacketBuilder.getUnit(3), 'cm');
    });

    test('provides correct mode names', () {
      expect(PacketBuilder.getModeName(1), 'Pressure');
      expect(PacketBuilder.getModeName(2), 'PWM');
      expect(PacketBuilder.getModeName(3), 'Length');
    });
  });
}
