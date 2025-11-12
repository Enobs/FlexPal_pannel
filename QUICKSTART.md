# FlexPAL Control Suite - Quick Start Guide

## 5-Minute Setup

### 1. Install Dependencies (First Time Only)

```bash
cd /home/yinan/Documents/FlexPal_pannel
flutter pub get
```

### 2. Test Without Hardware

**Terminal 1 - Start UDP Simulator:**
```bash
dart run tools/udp_simulator.dart 127.0.0.1 5006
```

You should see:
```
FlexPAL UDP Simulator
=====================
Target: 127.0.0.1:5006
Frequency: 50Hz per chamber
Press Ctrl+C to stop

Sent 450 packets...
Sent 900 packets...
```

**Terminal 2 - Run App:**
```bash
flutter run -d linux
# or flutter run -d windows
# or flutter run -d android
```

### 3. Verify Connection

In the app, you should see:
- **Overview Page**: All 9 chambers showing "ONLINE" with green badges
- Real-time data updating for Length, Pressure, Battery
- Status bar showing "UDP" and "SENDING" indicators

### 4. Try the Controls

1. **Go to Remote Page** (gamepad icon)
2. **Set targets** using sliders (default mode: Length, 15-30 cm)
3. **Click "Start Sending"** - app begins broadcasting commands
4. **Monitor Page** - Watch live charts update in real-time

### 5. Record an Episode

1. **On Remote Page**, scroll to bottom
2. **Enter episode name**: e.g., "Test_Run_1"
3. **Add notes** (optional): "First test recording"
4. **Click "Start Recording"** - Red REC indicator appears
5. Control the chambers with sliders
6. **Click "Stop Recording"** when done

Files saved to: `~/Documents/VLA_Records/2025-11-11_..._Test_Run_1/`

## With Real Hardware

### Network Setup

1. Connect to WiFi network with STM32 devices
2. Go to **Settings Page**
3. Update network configuration:
   - **Broadcast Address**: Your network broadcast (e.g., `192.168.1.255`)
   - **Send Port**: `5005` (default)
   - **Receive Port**: `5006` (default)
4. Click **Save Settings**

### Firewall (Linux/Windows)

**Linux:**
```bash
sudo ufw allow 5006/udp
```

**Windows:**
- Open Windows Defender Firewall
- Allow inbound UDP on port 5006

### Verify STM32 Connection

1. Check **Overview Page**
2. Chambers should turn green when receiving packets
3. If offline after 1 second, check:
   - STM32 is powered on
   - Network connectivity
   - Broadcast address is correct
   - Firewall allows UDP

## Common Commands

```bash
# Run on specific device
flutter devices                    # List available devices
flutter run -d linux              # Desktop Linux
flutter run -d android            # Android device/emulator

# Build release
flutter build linux --release
flutter build apk --release
flutter build windows --release

# Run tests
flutter test

# Format code
flutter format lib/

# Analyze code
flutter analyze
```

## Troubleshooting

### "No chambers online"
- ✅ Run UDP simulator first: `dart run tools/udp_simulator.dart 127.0.0.1 5006`
- ✅ Check firewall allows UDP port 5006
- ✅ Verify app shows "UDP" indicator (green)

### "Recording failed"
- ✅ Check storage permissions (Android/iOS)
- ✅ Verify disk space available
- ✅ Check app has write access to Documents folder

### "UI is slow"
- ✅ Reduce send rate (10-25 Hz instead of 50 Hz)
- ✅ Pause monitoring charts
- ✅ Close and reopen app

### "Sliders not responding"
- ✅ Click "Start Sending" first
- ✅ Check mode is set correctly
- ✅ Verify UDP service is running (Overview page)

## Next Steps

- Read full [README.md](README.md) for detailed documentation
- Explore [test/](test/) folder for code examples
- Check [tools/udp_simulator.dart](tools/udp_simulator.dart) for packet format reference

## Key Files Reference

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry point |
| `lib/core/udp/udp_service.dart` | UDP communication |
| `lib/core/record/recorder.dart` | VLA recording |
| `lib/pages/remote_page.dart` | Control interface |
| `tools/udp_simulator.dart` | Test data generator |

---

**Ready to control your FlexPAL system!** 🚀
