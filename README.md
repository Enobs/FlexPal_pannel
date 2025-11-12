# FlexPAL Multi-Platform Control Suite

A cross-platform Flutter application for controlling and monitoring the FlexPAL Modular Soft Robotics System with real-time UDP communication and VLA (Vision-Language-Action) data recording capabilities.

## Features

- **Real-time Control**: Control 9 soft robotic chambers via UDP at 25-50Hz
- **Three Control Modes**:
  - Pressure Mode (-100,000 to 30,000 Pa)
  - PWM Mode (-100% to 100%)
  - Length Mode (15.0 to 30.0 cm)
- **Live Monitoring**: Real-time charts for Length, Pressure, Battery, IMU data
- **VLA Recording**: Timestamped CSV recording of commands and telemetry for ML training
- **Camera Integration** (NEW v1.1.2):
  - 1-3 MJPEG camera stream preview
  - 30 FPS synchronized recording with episodes
  - Auto-reconnect and timestamp overlay
- **Multi-Platform**: Runs on Android, iOS, Windows, Ubuntu, and macOS

## System Architecture

```
lib/
├── main.dart                    # Application entry point
├── core/
│   ├── udp/                     # UDP communication layer
│   │   ├── udp_service.dart     # UDP socket management
│   │   ├── packet_builder.dart  # Command packet builder (39 bytes)
│   │   └── packet_parser.dart   # Telemetry packet parser (37 bytes)
│   ├── camera/                  # Camera streaming & recording (NEW v1.1.2)
│   │   ├── camera_service.dart  # Multi-camera stream manager
│   │   ├── camera_recorder.dart # Isolate-based 30 FPS recorder
│   │   ├── mjpeg_client.dart    # MJPEG HTTP parser
│   │   └── camera_frame.dart    # Frame/status data models
│   ├── record/                  # VLA recording system
│   │   ├── recorder.dart        # Isolate-based file writer
│   │   └── record_event.dart    # Recording event types
│   ├── models/                  # Data models
│   │   ├── settings.dart
│   │   ├── camera_settings.dart # Camera configuration (NEW)
│   │   ├── parsed_packet.dart
│   │   └── episode_manifest.dart
│   ├── state/                   # State management
│   │   ├── app_state.dart       # Application state
│   │   └── controller.dart      # Main controller
│   └── utils/
│       └── logger.dart          # Event logging
├── pages/                       # UI pages
│   ├── overview_page.dart       # System overview & chamber status
│   ├── remote_page.dart         # Control panel with sliders
│   ├── monitor_page.dart        # Real-time charts
│   ├── camera_page.dart         # Camera preview & recording (NEW)
│   ├── logs_page.dart           # Event logs
│   └── settings_page.dart       # Configuration
└── widgets/                     # Reusable UI components
    ├── chamber_card.dart
    ├── mode_switch.dart
    ├── slider_tile.dart
    └── record_toolbar.dart
```

## Communication Protocol

### Command Packet (Send: 39 bytes, Little Endian)

| Byte | Content | Type | Description |
|------|---------|------|-------------|
| 0 | CommandType | UInt8 | 1=Pressure, 2=PWM, 3=Length |
| 1-36 | Targets | Int32LE × 9 | Target values for 9 chambers |
| 37 | 0x0D | UInt8 | Carriage return |
| 38 | 0x0A | UInt8 | Line feed |

**Default:** Broadcast to `192.168.137.255:5005` at 25Hz

### Telemetry Packet (Receive: 37 bytes, Little Endian)

| Byte | Content | Type | Description |
|------|---------|------|-------------|
| 0 | Chamber ID | UInt8 | 1-9 |
| 1-4 | Length | Float32LE | mm |
| 5-28 | IMU | Float32LE × 6 | AccelX/Y/Z, GyroX/Y/Z |
| 29-32 | Pressure | Float32LE | kPa |
| 33-36 | Battery | Float32LE | 0-100% |

**Expected:** From STM32 devices at ~50Hz on port `5006`

## Getting Started

### Prerequisites

- Flutter SDK 3.0 or higher
- Dart SDK 3.0 or higher

### Quick Start

**For detailed setup instructions, see [SETUP_INSTRUCTIONS.md](SETUP_INSTRUCTIONS.md)**

1. **Extract and navigate to project:**
   ```bash
   tar -xzf FlexPal_pannel_v1.1.2.tar.gz
   cd FlexPal_pannel
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run on your platform:**
   ```bash
   # Desktop (recommended)
   flutter run -d linux
   flutter run -d windows
   flutter run -d macos

   # Mobile
   flutter run -d android
   flutter run -d ios

   # Check available devices
   flutter devices
   ```

4. **Configure network settings:**
   - Open Settings tab in the app
   - Set your network's broadcast address
   - Click "Apply Network Changes"

### Testing Without Hardware

Use the included UDP simulator to generate test data:

```bash
# In terminal 1: Run the simulator
dart run tools/udp_simulator.dart 127.0.0.1 5006

# In terminal 2: Run the app
flutter run
```

The simulator generates realistic telemetry data for all 9 chambers at 50Hz.

## Usage Guide

### 1. Overview Page
- View system status (UDP connection, sending state, recording state)
- Monitor online/offline status of all 9 chambers
- See latest Length, Pressure, and Battery readings

### 2. Remote Control Page
- Select control mode (Pressure/PWM/Length)
- Adjust send rate (10-50 Hz)
- Control each chamber individually with sliders
- Start/Stop sending commands
- Start/Stop VLA episode recording

### 3. Monitor Page
- Select a chamber (1-9)
- View real-time charts:
  - Length (mm)
  - Pressure (kPa)
  - Battery (%)
  - Accelerometer (X/Y/Z)
  - Gyroscope (X/Y/Z)
- Pause/Resume and Reset charts

### 4. Logs Page
- View real-time system logs (INFO/WARN/ERROR)
- Export logs to CSV
- Auto-scroll option

### 5. Camera Page (NEW v1.1.2)
- Start/Stop camera preview (1-3 streams)
- View live MJPEG streams with:
  - Real-time FPS counter
  - Online/offline indicators
  - Timestamp overlay
- Recording automatically syncs with episodes

### 6. Settings Page
- Configure network parameters:
  - Broadcast address
  - Send port
  - Receive port
- Configure camera streams (NEW):
  - Base IP address
  - Camera ports
  - MJPEG path
  - Max views (1-3)
  - Recording FPS (10/15/20/30)
- Set default control mode
- Set default send rate
- Save/Restore settings

## VLA Recording Format

When you start recording, an episode directory is created:

```
Documents/VLA_Records/
└── 2025-11-11T14-30-45_MyEpisode/
    ├── manifest.json      # Episode metadata
    ├── commands.csv       # All sent commands
    ├── telemetry.csv      # All received telemetry
    └── camera/            # Camera recordings (NEW v1.1.2)
        ├── cam0/
        │   ├── frames/    # JPEG files at 30 FPS
        │   │   ├── 000001_mono1699876245123_2025-11-11T14-30-45.123Z.jpg
        │   │   └── ...
        │   └── index.csv  # Frame timestamps & metadata
        ├── cam1/
        └── cam2/
```

### commands.csv
```csv
version,episode_id,seq,ts_ms,wall_time_iso,mode,addr,port,ch1,ch2,ch3,ch4,ch5,ch6,ch7,ch8,ch9
1,uuid-v4,1,1699876245123,2025-11-11T14:30:45.123Z,3,192.168.137.255,5005,2000,2100,...
```

### telemetry.csv
```csv
version,episode_id,ts_ms,wall_time_iso,chamber_id,length_mm,accel_x,accel_y,accel_z,gyro_x,gyro_y,gyro_z,pressure,battery,src_ip,src_port
1,uuid-v4,1699876245145,2025-11-11T14:30:45.145Z,1,22.5,0.1,0.2,9.8,0.01,0.02,0.0,5000.0,85.0,192.168.1.100,5006
```

### manifest.json
```json
{
  "version": 1,
  "episode_id": "uuid-v4",
  "episode_name": "MyEpisode",
  "created_at": "2025-11-11T14:30:45Z",
  "platform": "linux",
  "settings": {
    "broadcastAddress": "192.168.137.255",
    "sendPort": 5005,
    "recvPort": 5006,
    "sendRateHz": 25,
    "mode": 3
  },
  "notes": "Optional notes about this recording"
}
```

## Testing

Run unit tests:

```bash
flutter test
```

Tests include:
- **UDP Packet Parser**: Validates 37-byte telemetry parsing
- **UDP Packet Builder**: Validates 39-byte command generation
- **Recorder**: Tests episode creation, file writing, and CSV format

## Design Philosophy

### Industrial UI Design
- **Color Scheme**:
  - Background: `#1E1E1E` (Dark)
  - Primary: `#3498DB` (Blue)
  - Success: `#2ECC71` (Green)
  - Warning: `#E67E22` (Orange)
  - Error: `#E74C3C` (Red)
- **Typography**: Inter/Roboto
- **Style**: Tesla UI + DJI Controller inspired

### Performance Optimizations
- **Isolate-based Recording**: File I/O in separate isolate prevents UI blocking
- **Efficient State Management**: ChangeNotifier with minimal rebuilds
- **Timeout Detection**: Automatic chamber offline detection (1s threshold)
- **Packet Throttling**: Configurable send rates to prevent network congestion

### Safety Features
- Automatic value clamping based on control mode
- UDP packet validation (size, chamber ID range)
- Graceful handling of malformed packets
- Recording fails safely without crashing app

## Network Configuration

### Default Settings
- **Broadcast Address**: `192.168.137.255`
- **Send Port**: `5005`
- **Receive Port**: `5006`
- **Send Rate**: `25 Hz`
- **Default Mode**: `Length (Mode 3)`

### Troubleshooting

**No telemetry received:**
1. Check firewall allows UDP on port 5006
2. Verify STM32 devices are sending to correct port
3. Check network connectivity
4. Try the UDP simulator to verify app functionality

**Recording not working:**
1. Check app has storage permissions
2. Verify write access to Documents directory
3. Check available disk space

**UI lagging:**
1. Reduce send rate
2. Pause monitoring charts
3. Clear old logs

## Development

### Adding New Features

1. **New Control Mode:**
   - Update `PacketBuilder.clampTarget()`
   - Add mode in `PacketBuilder.getModeName()`
   - Update `ModeSwitch` widget

2. **New Telemetry Field:**
   - Modify `ParsedPacket` model
   - Update `PacketParser.parse()`
   - Add to recording CSV headers
   - Update Monitor page charts

### Code Style
- Follow official [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Use `flutter format` before committing
- Maintain comprehensive inline documentation

## License

MIT License - See LICENSE file for details

## Support

For issues and questions:
- GitHub Issues: [Create an issue](https://github.com/yourusername/flexpal-control/issues)
- Email: support@flexpal.com

## Acknowledgments

Built for the FlexPAL Modular Soft Robotics System research project.

---

## Documentation

- **[SETUP_INSTRUCTIONS.md](SETUP_INSTRUCTIONS.md)** - Complete setup and configuration guide
- **[CAMERA_INTEGRATION.md](CAMERA_INTEGRATION.md)** - Camera feature documentation
- **[TARGET_VALUES_BUG_FIX.md](TARGET_VALUES_BUG_FIX.md)** - Bug fix details for v1.1.2
- **[CHANGELOG.md](CHANGELOG.md)** - Version history

## Distribution

To package this project for distribution:

```bash
./package_for_distribution.sh
```

This creates:
- Source code archive (requires Flutter SDK)
- Executable binary (no Flutter SDK required)
- Distribution README with instructions

---

**Version:** 1.1.2
**Last Updated:** 2025-11-12
**Platform Requirements:** Flutter 3.0+, Dart 3.0+
