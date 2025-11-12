# Installation & Verification Guide

## Prerequisites

### 1. Install Flutter

**Linux:**
```bash
# Download Flutter
cd ~
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.16.0-stable.tar.xz
tar xf flutter_linux_3.16.0-stable.tar.xz

# Add to PATH (add to ~/.bashrc for persistence)
export PATH="$PATH:$HOME/flutter/bin"

# Verify installation
flutter doctor
```

**Windows:**
1. Download Flutter SDK from https://flutter.dev/docs/get-started/install/windows
2. Extract to `C:\flutter`
3. Add `C:\flutter\bin` to PATH
4. Run `flutter doctor` in command prompt

**macOS:**
```bash
# Using Homebrew
brew install --cask flutter

# Or download from flutter.dev
```

### 2. Install Platform-Specific Tools

**For Linux Desktop:**
```bash
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev
```

**For Android:**
- Install Android Studio
- Install Android SDK (API 21+)
- Create virtual device or connect physical device

**For Windows Desktop:**
- Install Visual Studio 2022 with "Desktop development with C++"

## Project Setup

### 1. Navigate to Project
```bash
cd /home/yinan/Documents/FlexPal_pannel
```

### 2. Install Dependencies
```bash
flutter pub get
```

Expected output:
```
Running "flutter pub get" in FlexPal_pannel...
Resolving dependencies...
+ fl_chart 0.65.0
+ flutter_riverpod 2.4.0
+ path 1.8.3
+ path_provider 2.1.1
+ shared_preferences 2.2.2
+ uuid 4.0.0
...
Got dependencies!
```

### 3. Verify Configuration
```bash
flutter doctor -v
```

Check for:
- ✅ Flutter (Channel stable)
- ✅ At least one connected device
- ✅ No issues reported

### 4. Check Available Devices
```bash
flutter devices
```

You should see at least one device:
```
Linux (desktop) • linux • linux-x64 • Ubuntu 22.04
```

## Verification Steps

### Step 1: Run Tests
```bash
flutter test
```

Expected: All tests pass
```
00:02 +18: All tests passed!
```

### Step 2: Analyze Code
```bash
flutter analyze
```

Expected: No issues found
```
Analyzing FlexPal_pannel...
No issues found!
```

### Step 3: Test UDP Simulator

**Terminal 1:**
```bash
dart run tools/udp_simulator.dart 127.0.0.1 5006
```

Expected output:
```
FlexPAL UDP Simulator
=====================
Target: 127.0.0.1:5006
Frequency: 50Hz per chamber
Press Ctrl+C to stop

Sent 450 packets...
```

### Step 4: Run Application

**Terminal 2:**
```bash
flutter run -d linux
# or
flutter run -d android
```

Expected:
1. App builds successfully
2. Window/app opens
3. Overview page shows 9 chambers
4. Within 1-2 seconds, all chambers turn green "ONLINE"
5. Status bar shows "UDP" indicator

### Step 5: Test Controls

1. **Navigate to Remote page**
2. **Move slider for Chamber 1** - should update smoothly
3. **Click "Start Sending"** - button becomes disabled, "Stop" enabled
4. **Go to Monitor page**
5. **Select Chamber 1** - charts should show live data
6. **Verify charts update** - lines should move in real-time

### Step 6: Test Recording

1. **Go to Remote page**
2. **Enter episode name**: "Test_Recording"
3. **Click "Start Recording"** - "REC" indicator appears
4. **Wait 10 seconds**
5. **Click "Stop Recording"**
6. **Check logs page** - should show recording messages
7. **Verify files created**:
   ```bash
   ls -la ~/Documents/VLA_Records/
   ```
   Should see directory like: `2025-11-11T14-30-45_Test_Recording/`

8. **Check CSV files**:
   ```bash
   cat ~/Documents/VLA_Records/2025-*/commands.csv | head -3
   cat ~/Documents/VLA_Records/2025-*/telemetry.csv | head -3
   ```

## Troubleshooting

### Issue: "flutter: command not found"

**Solution:**
```bash
# Check Flutter installation
which flutter

# If not found, add to PATH
export PATH="$PATH:$HOME/flutter/bin"

# Make permanent
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
source ~/.bashrc
```

### Issue: "No devices found"

**Linux Desktop:**
```bash
flutter config --enable-linux-desktop
flutter devices
```

**Android:**
```bash
# Check USB debugging enabled on device
adb devices

# If empty, enable USB debugging in Android Developer Options
```

### Issue: Tests fail with "binding has not been initialized"

**Solution:**
Tests use `flutter_test` which handles initialization. If tests fail, check:
```bash
flutter test --verbose
```

### Issue: "Cannot find package:flexpal_control"

**Solution:**
```bash
# Clean and reinstall dependencies
flutter clean
flutter pub get
```

### Issue: UDP simulator not working

**Check Dart installation:**
```bash
dart --version
```

**Firewall on Linux:**
```bash
sudo ufw status
sudo ufw allow 5006/udp
```

**Firewall on Windows:**
- Windows Defender Firewall → Advanced Settings
- Inbound Rules → New Rule → UDP Port 5006

### Issue: Recording fails

**Check permissions (Android/iOS):**
- Grant storage permissions in app settings

**Check disk space:**
```bash
df -h ~/Documents/
```

**Check write permissions:**
```bash
ls -la ~/Documents/
mkdir ~/Documents/VLA_Records  # If doesn't exist
```

## Build Release Versions

### Linux Desktop
```bash
flutter build linux --release
# Output: build/linux/x64/release/bundle/
```

### Windows Desktop
```bash
flutter build windows --release
# Output: build\windows\runner\Release\
```

### Android APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (for Play Store)
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

## Performance Benchmarks

Expected performance on modern hardware:

| Metric | Expected Value |
|--------|---------------|
| UDP Send Rate | 10-50 Hz stable |
| UDP Recv Processing | 450 packets/sec (9×50Hz) |
| UI Frame Rate | 60 FPS |
| Memory Usage | < 200 MB |
| Recording Overhead | < 5% CPU |
| Packet Loss | < 1% |

## Next Steps After Installation

1. Read [QUICKSTART.md](QUICKSTART.md) for usage guide
2. Review [README.md](README.md) for full documentation
3. Check [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) for code overview
4. Explore source code in `lib/` directory

## Support

If you encounter issues not covered here:

1. **Check Flutter Doctor:**
   ```bash
   flutter doctor -v
   ```

2. **Check logs:**
   - App logs in Logs page
   - Terminal output when running

3. **Clean build:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

4. **Verify project integrity:**
   ```bash
   flutter analyze
   flutter test
   ```

---

**Installation Complete!** You're ready to use FlexPAL Control Suite. 🎉
