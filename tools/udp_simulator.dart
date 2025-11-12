import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

/// UDP Simulator for testing FlexPAL Control Suite
///
/// Simulates 9 STM32 chambers sending telemetry packets at 50Hz
/// Usage: dart run tools/udp_simulator.dart [target_address] [target_port]
void main(List<String> args) async {
  final targetAddress = args.isNotEmpty ? args[0] : '127.0.0.1';
  final targetPort = args.length > 1 ? int.parse(args[1]) : 5006;

  print('FlexPAL UDP Simulator');
  print('=====================');
  print('Target: $targetAddress:$targetPort');
  print('Frequency: 50Hz per chamber');
  print('Press Ctrl+C to stop\n');

  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  final random = Random();
  final address = InternetAddress(targetAddress);

  // State for each chamber
  final List<ChamberState> chambers = List.generate(9, (i) => ChamberState(i + 1));

  // Send packets at 50Hz per chamber
  // To simulate realistic behavior, we stagger the chambers
  var packetCount = 0;

  while (true) {
    for (final chamber in chambers) {
      // Update chamber state
      chamber.update(random);

      // Build and send packet
      final packet = chamber.buildPacket();
      socket.send(packet, address, targetPort);

      packetCount++;
      if (packetCount % 450 == 0) {
        print('Sent $packetCount packets...');
      }

      // Wait ~2ms between chambers (9 chambers = ~20ms total, ~50Hz)
      await Future.delayed(const Duration(milliseconds: 2));
    }
  }
}

class ChamberState {
  final int id;
  double length;
  double accelX, accelY, accelZ;
  double gyroX, gyroY, gyroZ;
  double pressure;
  double battery;

  // Animation parameters
  double phase = 0;
  double lengthTarget = 22.0;
  double pressureTarget = 0.0;

  ChamberState(this.id)
      : length = 20.0 + Random().nextDouble() * 5,
        accelX = 0,
        accelY = 0,
        accelZ = 9.8,
        gyroX = 0,
        gyroY = 0,
        gyroZ = 0,
        pressure = 0,
        battery = 85 + Random().nextDouble() * 15;

  void update(Random random) {
    // Simulate smooth sinusoidal motion
    phase += 0.05;

    // Length oscillates between 18-26mm
    lengthTarget = 22.0 + 4.0 * sin(phase + id * 0.5);
    length += (lengthTarget - length) * 0.1;

    // Pressure follows length
    pressureTarget = (length - 20.0) * 2000; // -4kPa to +12kPa range
    pressure += (pressureTarget - pressure) * 0.1;

    // IMU: slight random noise + response to movement
    final accel = (lengthTarget - length) * 2;
    accelX = accel * cos(phase) + (random.nextDouble() - 0.5) * 0.2;
    accelY = accel * sin(phase) + (random.nextDouble() - 0.5) * 0.2;
    accelZ = 9.8 + (random.nextDouble() - 0.5) * 0.1;

    gyroX = sin(phase * 2) * 0.5 + (random.nextDouble() - 0.5) * 0.1;
    gyroY = cos(phase * 2) * 0.5 + (random.nextDouble() - 0.5) * 0.1;
    gyroZ = (random.nextDouble() - 0.5) * 0.05;

    // Battery slowly drains
    battery = max(20, battery - 0.0001);
  }

  Uint8List buildPacket() {
    // 37-byte packet (Little Endian)
    final buffer = ByteData(37);

    // Byte 0: Chamber ID
    buffer.setUint8(0, id);

    // Bytes 1-4: Length (mm)
    buffer.setFloat32(1, length, Endian.little);

    // Bytes 5-28: IMU (6 × Float32)
    buffer.setFloat32(5, accelX, Endian.little);
    buffer.setFloat32(9, accelY, Endian.little);
    buffer.setFloat32(13, accelZ, Endian.little);
    buffer.setFloat32(17, gyroX, Endian.little);
    buffer.setFloat32(21, gyroY, Endian.little);
    buffer.setFloat32(25, gyroZ, Endian.little);

    // Bytes 29-32: Pressure (kPa)
    buffer.setFloat32(29, pressure, Endian.little);

    // Bytes 33-36: Battery (%)
    buffer.setFloat32(33, battery, Endian.little);

    return buffer.buffer.asUint8List();
  }
}
