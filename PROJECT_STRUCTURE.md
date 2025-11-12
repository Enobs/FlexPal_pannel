# FlexPAL Control Suite - Project Structure

## Complete File Tree

```
FlexPal_pannel/
├── lib/
│   ├── main.dart                           # App entry point & navigation
│   ├── core/                               # Core business logic
│   │   ├── udp/                           # UDP communication layer
│   │   │   ├── udp_service.dart           # Main UDP service (send/recv)
│   │   │   ├── packet_builder.dart        # Build 39-byte command packets
│   │   │   └── packet_parser.dart         # Parse 37-byte telemetry packets
│   │   ├── record/                        # VLA recording system
│   │   │   ├── recorder.dart              # Isolate-based CSV writer
│   │   │   └── record_event.dart          # Recording event types
│   │   ├── models/                        # Data models
│   │   │   ├── settings.dart              # App settings model
│   │   │   ├── parsed_packet.dart         # Telemetry packet model
│   │   │   └── episode_manifest.dart      # Recording manifest model
│   │   ├── state/                         # State management
│   │   │   ├── app_state.dart             # Global app state (ChangeNotifier)
│   │   │   └── controller.dart            # Main app controller
│   │   └── utils/                         # Utilities
│   │       └── logger.dart                # Event logging system
│   ├── pages/                             # UI pages
│   │   ├── overview_page.dart             # System overview & chamber cards
│   │   ├── remote_page.dart               # Control panel with sliders
│   │   ├── monitor_page.dart              # Real-time charts (fl_chart)
│   │   ├── logs_page.dart                 # Event log viewer
│   │   └── settings_page.dart             # Configuration page
│   └── widgets/                           # Reusable UI components
│       ├── chamber_card.dart              # Chamber status card
│       ├── mode_switch.dart               # Mode selector (Pressure/PWM/Length)
│       ├── slider_tile.dart               # Slider with text input
│       └── record_toolbar.dart            # Recording control bar
├── test/                                  # Unit tests
│   ├── udp_parser_test.dart              # Packet parser tests
│   └── recorder_test.dart                # Recording system tests
├── tools/                                 # Development tools
│   └── udp_simulator.dart                # UDP packet simulator for testing
├── assets/                                # Assets (empty, for future use)
├── pubspec.yaml                          # Flutter dependencies
├── analysis_options.yaml                 # Dart linter configuration
├── .gitignore                            # Git ignore rules
├── README.md                             # Full documentation
├── QUICKSTART.md                         # Quick start guide
├── PROJECT_STRUCTURE.md                  # This file
├── run_with_simulator.sh                 # Linux/macOS quick start script
└── run_with_simulator.bat                # Windows quick start script
```

## Module Descriptions

### Core Modules

#### 1. UDP Communication Layer (`lib/core/udp/`)

**udp_service.dart** (325 lines)
- Manages UDP socket lifecycle
- Sends 39-byte command packets at configurable rate (10-50Hz)
- Receives 37-byte telemetry packets
- Provides packet stream for UI consumption
- Handles connection state

**packet_builder.dart** (126 lines)
- Builds little-endian command packets
- Converts display values to Int32 based on mode
- Clamps values to safe ranges
- Provides mode metadata (names, units, ranges)

**packet_parser.dart** (72 lines)
- Parses little-endian telemetry packets
- Validates packet size and chamber ID
- Extracts 37 bytes: ID, Length, IMU (6 floats), Pressure, Battery
- Returns null for invalid packets

#### 2. Recording System (`lib/core/record/`)

**recorder.dart** (184 lines)
- Manages VLA episode recording
- Spawns isolate for non-blocking file I/O
- Creates episode directories with timestamp
- Writes commands.csv and telemetry.csv
- Generates manifest.json with episode metadata

**record_event.dart** (25 lines)
- Event types for isolate communication
- CommandEvent, TelemetryEvent, FlushEvent, StopEvent

#### 3. State Management (`lib/core/state/`)

**app_state.dart** (155 lines)
- ChangeNotifier-based state management
- Tracks 9 chamber states (online/offline, last packet)
- Maintains recent packet history (max 1000)
- Timeout detection (1 second threshold)

**controller.dart** (214 lines)
- Main application controller
- Coordinates UDP service, recorder, logger
- Handles settings persistence (SharedPreferences)
- Manages lifecycle (init, dispose)

#### 4. Data Models (`lib/core/models/`)

**settings.dart** (54 lines)
- Configuration model (address, ports, rate, mode)
- JSON serialization/deserialization
- Default values

**parsed_packet.dart** (32 lines)
- Telemetry packet data model
- Contains all 37-byte packet fields

**episode_manifest.dart** (47 lines)
- Recording manifest model
- Includes episode metadata and settings snapshot

### UI Layer

#### Pages (`lib/pages/`)

**overview_page.dart** (138 lines)
- System summary card
- 3×3 grid of chamber status cards
- Real-time online/offline indicators

**remote_page.dart** (195 lines)
- Mode selection (Pressure/PWM/Length)
- 9 chamber sliders with linked text inputs
- Send rate control
- Start/Stop sending buttons
- Recording toolbar integration

**monitor_page.dart** (240 lines)
- Chamber selection dropdown
- 5 real-time charts using fl_chart:
  - Length, Pressure, Battery (single line)
  - Accelerometer, Gyroscope (3-line XYZ)
- Pause/Resume and Reset functionality
- Maintains 200-point history per chart

**logs_page.dart** (157 lines)
- Real-time log viewer with color-coded levels
- Auto-scroll option
- Export to CSV functionality
- Monospace font for readability

**settings_page.dart** (226 lines)
- Network configuration inputs
- Control mode and rate settings
- Storage path display
- Save/Restore defaults

#### Widgets (`lib/widgets/`)

**chamber_card.dart** (82 lines)
- Displays chamber ID, online status, Length, Pressure, Battery
- Animated color transitions for status changes

**mode_switch.dart** (49 lines)
- Three-button mode selector
- Highlighted active mode

**slider_tile.dart** (134 lines)
- Slider + text input synchronization
- Value validation and clamping
- Unit display

**record_toolbar.dart** (101 lines)
- Episode name and notes input
- Start/Stop recording buttons
- Visual recording indicator

### Testing & Tools

**test/udp_parser_test.dart** (157 lines)
- Tests packet parsing (valid, invalid size, invalid ID)
- Tests packet building (command structure, CRLF)
- Tests value conversion and clamping
- Tests mode utilities (names, units, ranges)

**test/recorder_test.dart** (177 lines)
- Tests episode start/stop
- Tests directory and file creation
- Tests CSV header format
- Tests command and telemetry recording
- Tests concurrent recording prevention

**tools/udp_simulator.dart** (133 lines)
- Generates realistic telemetry for 9 chambers
- Simulates sinusoidal motion (18-26mm range)
- Adds IMU noise and battery drain
- 50Hz per chamber output

## Data Flow

```
STM32 Hardware → UDP Port 5006 → PacketParser → AppState → UI (Overview/Monitor)
                                                   ↓
                                                Recorder → CSV Files

User Input → UI (Remote) → AppController → UdpService → UDP Broadcast → STM32 Hardware
                                              ↓
                                           Recorder → CSV Files
```

## Key Design Patterns

1. **State Management**: ChangeNotifier pattern for reactive UI
2. **Service Layer**: UdpService encapsulates all socket I/O
3. **Isolate Pattern**: Recorder uses separate isolate for file I/O
4. **Stream Pattern**: Packet and log streams for real-time updates
5. **Builder Pattern**: PacketBuilder for command generation
6. **Parser Pattern**: PacketParser for telemetry extraction

## Performance Considerations

- **Non-blocking I/O**: All file operations in separate isolate
- **Efficient State Updates**: Minimal widget rebuilds with ListenableBuilder
- **Packet Throttling**: Configurable send rates (10-50Hz)
- **Memory Management**: Limited packet history (1000 packets)
- **Chart Optimization**: Limited data points per chart (200 max)

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Linux | ✅ Fully Supported | Primary development platform |
| Windows | ✅ Fully Supported | Tested on Windows 10/11 |
| macOS | ✅ Fully Supported | Requires macOS 10.14+ |
| Android | ✅ Fully Supported | Requires Android 5.0+ (API 21) |
| iOS | ✅ Fully Supported | Requires iOS 11+ |

## Dependencies

```yaml
Core:
  - flutter (3.0+)
  - flutter_riverpod: ^2.4.0

UI:
  - fl_chart: ^0.65.0

Storage:
  - path_provider: ^2.1.1
  - path: ^1.8.3
  - shared_preferences: ^2.2.2

Utilities:
  - uuid: ^4.0.0
  - cupertino_icons: ^1.0.2
```

## Lines of Code

| Category | Files | Lines |
|----------|-------|-------|
| Core Logic | 11 | ~1,850 |
| UI (Pages) | 5 | ~956 |
| UI (Widgets) | 4 | ~366 |
| Tests | 2 | ~334 |
| Tools | 1 | ~133 |
| **Total** | **23** | **~3,639** |

## Next Steps for Extension

1. **Add Bluetooth Support**: Alternative to UDP for mobile
2. **Cloud Sync**: Upload recordings to cloud storage
3. **Data Visualization**: Post-processing tools for recorded data
4. **ML Integration**: Real-time model inference
5. **Multi-Device Control**: Control multiple FlexPAL systems
6. **Custom Profiles**: Save/load control presets

---

**Last Updated:** 2025-11-11
