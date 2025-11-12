# Changelog

All notable changes to the FlexPAL Control Suite will be documented in this file.

## [1.1.1] - 2025-11-12

### Added
- **Enhanced UDP Debugging**: Comprehensive logging for packet reception and transmission
- **Packet Preview in Logs**: Shows first 8 bytes of each packet in hex format for debugging
- **Parse Error Details**: Specific error messages when packet parsing fails (invalid size, chamber ID, values)
- **40-byte Packet Support**: Parser now accepts both 37-byte and 40-byte telemetry packets
- **Send Confirmation Logs**: Logs every 25th sent packet to verify transmission
- **UDP Debug Guide**: Complete troubleshooting documentation in [UDP_DEBUG_GUIDE.md](UDP_DEBUG_GUIDE.md)
- **Negative PWM Test Script**: Python test script ([tools/test_negative_pwm.py](tools/test_negative_pwm.py)) to verify negative PWM value handling

### Changed
- **PacketParser**: Now accepts 37-byte or 40-byte telemetry packets (was 37-byte only)
- **PacketParser**: Added sanity checks for NaN/Infinite values in length, pressure, battery
- **PacketParser**: Added `static String? lastError` to show exact parse failure reasons
- **UdpService**: Enhanced logging with packet size, source IP/port, and hex preview
- **UdpService**: Logs show exact parse failure reasons and total error count

### Fixed
- **Packet Size Mismatch**: STM32 sends 40-byte packets, app now accepts them correctly
- **Silent Parse Failures**: Parser now reports specific errors via `PacketParser.lastError`
- **Loopback Packet Spam**: App correctly rejects its own 39-byte command packets received via loopback

### Known Issues
- **Negative PWM Values**: Positive PWM (0-100) works, but negative PWM (-100 to 0) may not work. This is likely a **STM32 firmware issue** - the firmware may be:
  - Reading PWM values as unsigned int instead of signed int
  - Not handling the sign bit correctly
  - Rejecting negative values in motor driver logic

  Use `python3 tools/test_negative_pwm.py` to verify packet format is correct. The app sends negative values as signed Int32LE (e.g., -1 = 0xFFFFFFFF in little-endian).

### Technical Details
- Modified [packet_parser.dart](lib/core/udp/packet_parser.dart) to accept 37 or 40-byte packets
- Enhanced [udp_service.dart](lib/core/udp/udp_service.dart) with detailed debug logging
- Created [UDP_DEBUG_GUIDE.md](UDP_DEBUG_GUIDE.md) with troubleshooting steps

## [1.1.0] - 2025-11-11

### Added
- **Modern UI Design**: Complete visual redesign with glassmorphism effects and Font Awesome icons
- **Enhanced Chamber Cards**: New card design with gradient backgrounds, glow effects, and improved typography
- **Better Icons**: Integrated Font Awesome for professional iconography throughout the app
- **Improved Visual Hierarchy**: Better spacing, typography, and color coding for metrics
- **Battery Color Coding**: Dynamic battery colors (green > 60%, orange 30-60%, red < 30%)
- **Apply Network Changes Button**: New button in Settings to restart UDP without restarting the app

### Changed
- **Chamber Cards**: Redesigned with modern glassmorphism style, microchip icons, and animated status indicators
- **Navigation Icons**: Updated bottom navigation with Font Awesome icons (grip, gamepad, chart-line, rectangle-list, gear)
- **Metric Display**: Icons for each metric (arrows for length, gauge for pressure, battery for charge)
- **Status Indicators**: Glowing pulse effect for online chambers
- **Settings Page**: Added "Apply Network Changes (Restart UDP)" button to immediately apply new network configuration

## [1.0.1] - 2025-11-11

### Fixed
- **Recorder Isolate Cleanup**: Fixed issue where IOSink would throw "StreamSink is bound to a stream" error when stopping recording. The isolate now properly closes the receive port after flushing and closing file sinks.
- **Test Stability**: Added proper delays in recorder tests to allow isolate cleanup to complete before test teardown.
- **Test Path Handling**: Fixed tests to save `currentEpisodePath` before calling `stopEpisode()` since the path is cleared on stop. This prevents "Cannot open file, path = 'null/commands.csv'" errors.

### Technical Details
- Modified `_recordingIsolate` in [recorder.dart](lib/core/record/recorder.dart:184-254) to add a `shouldStop` flag
- Added `receivePort.close()` after handling `StopEvent` to prevent double-close errors
- Enhanced error handling in isolate cleanup with try-catch blocks
- Updated tests in [recorder_test.dart](test/recorder_test.dart) to capture episode path before stopping

## [1.0.0] - 2025-11-11

### Added
- **Initial Release**: Complete FlexPAL Multi-Platform Control Suite
- **UDP Communication**: Bidirectional UDP for commands and telemetry
- **Three Control Modes**: Pressure, PWM, and Length (Spring) control
- **9-Chamber Support**: Independent control and monitoring of 9 chambers
- **VLA Recording**: Episode-based CSV recording with manifest
- **Real-Time Monitoring**: Live charts for Length, Pressure, Battery, and 6-axis IMU
- **Cross-Platform**: Support for Android, iOS, Windows, Ubuntu, macOS
- **UI Pages**: Overview, Remote Control, Monitor, Logs, Settings
- **Testing Tools**: UDP simulator and comprehensive unit tests
- **Documentation**: Complete user guides and API documentation

### Features
- Real-time UDP packet transmission (10-50Hz configurable)
- Telemetry reception at ~50Hz per chamber (450 packets/sec)
- Isolate-based non-blocking file recording
- Automatic chamber online/offline detection (1s timeout)
- Value clamping and validation for all control modes
- Settings persistence using SharedPreferences
- Event logging with export to CSV
- Industrial dark theme UI (Tesla/DJI inspired)

### Technical
- 23 Dart source files (~3,600 lines of code)
- 2 test suites (26 unit tests)
- 6 comprehensive documentation files
- Clean architecture with separation of concerns
- ChangeNotifier-based state management
- Stream-based reactive updates

---

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 1.0.1 | 2025-11-11 | Fixed recorder isolate cleanup issue |
| 1.0.0 | 2025-11-11 | Initial production release |

---

**Note**: This project follows [Semantic Versioning](https://semver.org/):
- MAJOR version for incompatible API changes
- MINOR version for added functionality (backwards compatible)
- PATCH version for backwards compatible bug fixes
