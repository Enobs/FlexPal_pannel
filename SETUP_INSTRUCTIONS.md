# FlexPAL Control Suite - Setup Instructions

**Version**: 1.1.2
**Last Updated**: 2025-11-12

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [First-Time Configuration](#first-time-configuration)
4. [Testing the System](#testing-the-system)
5. [Troubleshooting](#troubleshooting)
6. [Hardware Requirements](#hardware-requirements)

---

## Prerequisites

### Software Requirements
1. **Flutter SDK** (Latest stable version)
   - Download: https://docs.flutter.dev/get-started/install
   - Choose your platform: Linux / Windows / macOS

2. **Verify Flutter Installation**
   ```bash
   flutter doctor
   ```
   Make sure all checkmarks are green (except Android/iOS if you're only targeting desktop).

### Hardware Requirements
- **Development Machine**:
  - OS: Linux (primary), Windows, or macOS
  - RAM: 4GB minimum, 8GB recommended
  - Disk: 500MB for app + dependencies

- **STM32 Device** (for robot control):
  - Connected to same network
  - Broadcasting telemetry to UDP port 5006

- **Camera Server** (optional, for camera features):
  - MJPEG streaming server (e.g., mjpg-streamer)
  - Accessible via HTTP on local network

---

## Installation

### Step 1: Extract the Archive
```bash
# For .tar.gz
tar -xzf FlexPal_pannel.tar.gz
cd FlexPal_pannel

# For .zip
unzip FlexPal_pannel.zip
cd FlexPal_pannel
```

### Step 2: Install Dependencies
```bash
flutter pub get
```

This will download all required packages listed in `pubspec.yaml`.

### Step 3: Verify Build
```bash
flutter analyze
```

You should see: `No issues found!` or only warnings (which are okay).

### Step 4: Run the Application
```bash
flutter run
```

**Note**: First launch may take 1-2 minutes to compile.

---

## First-Time Configuration

### 1. Network Configuration (Required)

The app needs to communicate with your STM32 soft robotics controller.

1. Click the **Settings** tab (gear icon at bottom)
2. Scroll to **Network Configuration** section
3. Configure the following:

   | Field | Description | Example |
   |-------|-------------|---------|
   | **Broadcast Address** | Your network's broadcast IP | `192.168.137.255` |
   | **Send Port** | Port for sending commands to STM32 | `5005` |
   | **Receive Port** | Port for receiving telemetry from STM32 | `5006` |
   | **Default Send Rate (Hz)** | Command transmission rate | `25` (10-50) |
   | **Default Mode** | Control mode | `Length` / `PWM` / `Pressure` |

4. Click **Save Settings**
5. Click **Apply Network Changes (Restart UDP)** to activate

**Finding Your Broadcast Address**:
- Linux: `ip addr show` → Look for your network interface (e.g., `192.168.137.x/24` → broadcast is `192.168.137.255`)
- Windows: `ipconfig` → Calculate from IP and subnet mask
- macOS: `ifconfig` → Look for broadcast address

### 2. Camera Configuration (Optional)

If you have MJPEG camera streams for visual feedback:

1. Still in **Settings** tab, scroll to **Camera Configuration**
2. Configure:

   | Field | Description | Example |
   |-------|-------------|---------|
   | **Base IP Address** | Camera server IP | `172.31.243.152` |
   | **Camera Ports** | Comma-separated ports | `8080, 8081, 8082` |
   | **MJPEG Stream Path** | URL path | `/?action=stream` |
   | **Max Camera Views** | Number of cameras to show | `1`, `2`, or `3` |
   | **Default Save FPS** | Recording frame rate | `30` (10/15/20/30) |

3. Click **Save Settings**

**Camera URL Format**: `http://<Base IP>:<Port><Path>`
Example: `http://172.31.243.152:8080/?action=stream`

### 3. Verify Connection

After configuring, check the top bar:
- **Green "UDP" badge**: Network connected ✅
- **Red "DISCONNECTED"**: Check network settings ❌

---

## Testing the System

### Test 1: Overview Page (Chamber Monitoring)
1. Click **Overview** tab (grid icon)
2. You should see 9 chamber cards
3. **If STM32 is online**: Cards show green, with real-time data (length, accel, gyro, pressure)
4. **If offline**: Cards show gray with "No data"

**Expected Telemetry Rate**: 10-50 Hz (shown in top logs)

### Test 2: Remote Control Page (Command Sending)
1. Click **Remote** tab (gamepad icon)
2. You'll see:
   - Mode switch: **Pressure** / **PWM** / **Length**
   - 9 chamber sliders (-100 to +100)
   - Episode recording controls

3. **Test PWM Mode**:
   ```
   a. Select "PWM" mode
   b. Move Chamber 4 slider to 50%
   c. Click "Start Sending"
   d. Check Logs tab → Should see: "Target values (Int32): 0, 0, 0, 50, 0, 0, 0, 0, 0"
   e. STM32 should respond (motor runs at 50% PWM)
   ```

4. **Test Negative PWM** (reverse):
   ```
   a. Move Chamber 4 slider to -50%
   b. Check Logs → Should see: "Target values (Int32): 0, 0, 0, -50, 0, 0, 0, 0, 0"
   c. STM32 motor should reverse
   ```

5. **Stop Sending**: Click "Stop Sending" to halt commands

### Test 3: Camera Preview (If Configured)
1. Click **Camera** tab (video icon)
2. Click **Start Preview**
3. You should see 1-3 camera streams with:
   - Online indicator (green circle)
   - FPS counter
   - Resolution (e.g., 1920×1080)
   - Timestamp overlay on video

4. **If cameras don't appear**:
   - Check camera server is running
   - Verify IP/ports in Settings
   - Check Logs tab for errors

### Test 4: Episode Recording
1. Go to **Remote** tab
2. Enter episode name (e.g., "test_recording_001")
3. Click **Start Recording**
4. Move sliders to generate commands
5. Top bar shows **red "REC" badge**
6. Click **Stop Recording** after 10 seconds
7. Check output:
   ```bash
   ls ~/Documents/VLA_Records/
   # Should see: 2025-11-12T10-30-45_test_recording_001/
   ```

**Recorded Files**:
```
2025-11-12T10-30-45_test_recording_001/
├── manifest.json          # Episode metadata
├── commands.csv           # Command history
├── telemetry.csv          # STM32 telemetry
└── camera/                # Camera recordings (if enabled)
    ├── cam0/
    │   ├── frames/*.jpg   # JPEG frames
    │   └── index.csv      # Frame timestamps
    └── ...
```

---

## Troubleshooting

### Problem: UDP Not Connecting (Red "DISCONNECTED")

**Symptoms**: Top bar shows red "DISCONNECTED", no telemetry received

**Solutions**:
1. **Check Network Settings**:
   ```bash
   # Linux: Verify your IP
   ip addr show
   # Ensure STM32 is on same network
   ```

2. **Check Firewall**:
   ```bash
   # Linux: Allow UDP ports
   sudo ufw allow 5005/udp
   sudo ufw allow 5006/udp
   ```

3. **Verify STM32 is Broadcasting**:
   ```bash
   # Listen for UDP packets
   sudo tcpdump -i any -n udp port 5006
   # Should see packets from STM32 IP
   ```

4. **Check Logs Tab**: Look for error messages like "bind failed"

5. **Try Different Ports**: Some systems block 5005/5006
   - Settings → Change to 6005/6006 → Save → Apply

### Problem: Slider Values Not Being Sent (All Zeros)

**Symptoms**: Logs show "Target values: 0, 0, 0, 0, 0, 0, 0, 0, 0"

**Solutions**:
1. **Set Sliders BEFORE Starting Sending**:
   ```
   ✅ Correct: Set slider → Click "Start Sending"
   ❌ Wrong: Click "Start Sending" → Set slider
   ```

2. **Check Mode**: Ensure mode is set (Pressure/PWM/Length)

3. **See Bug Fix**: Read [TARGET_VALUES_BUG_FIX.md](TARGET_VALUES_BUG_FIX.md) for details

### Problem: Cameras Not Showing (Black Screen or "No Signal")

**Symptoms**: Camera tab shows "No signal" or error icon

**Solutions**:
1. **Verify Camera Server is Running**:
   ```bash
   # Test camera URL manually
   curl -I http://172.31.243.152:8080/?action=stream
   # Should return: HTTP/1.0 200 OK
   ```

2. **Check Firewall**: Allow camera ports (8080, 8081, 8082)

3. **Test in Browser**: Open `http://<camera_ip>:<port>/?action=stream`
   - Should see MJPEG stream

4. **Check Settings**: Verify Base IP, Ports, and Path are correct

5. **Check Logs Tab**: Look for errors like "Connection refused"

6. **Restart Preview**: Stop → Wait 5 seconds → Start again

### Problem: Recording Files Not Saved

**Symptoms**: After stopping recording, no files in `~/Documents/VLA_Records/`

**Solutions**:
1. **Check Permissions**:
   ```bash
   # Ensure directory is writable
   ls -ld ~/Documents/VLA_Records/
   ```

2. **Check Disk Space**:
   ```bash
   df -h ~/Documents/
   ```

3. **Check Logs Tab**: Look for "ERROR writing" messages

4. **Verify Episode Started**: Top bar should show red "REC" badge

### Problem: App Crashes on Startup

**Symptoms**: Flutter app exits immediately after launch

**Solutions**:
1. **Check Flutter Installation**:
   ```bash
   flutter doctor -v
   ```

2. **Clean and Rebuild**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

3. **Check Dependencies**:
   ```bash
   flutter pub outdated
   # Update if needed: flutter pub upgrade
   ```

4. **Run with Debug Info**:
   ```bash
   flutter run -v
   # Check console for error messages
   ```

---

## Hardware Requirements

### STM32 Soft Robotics Controller
- **Telemetry Packet Format** (40 bytes):
  ```
  [0]      = Chamber ID (0-8)
  [1-4]    = Length (Int32LE, mm)
  [5-8]    = Accel X (Int32LE)
  [9-12]   = Accel Y (Int32LE)
  [13-16]  = Accel Z (Int32LE)
  [17-20]  = Gyro X (Int32LE)
  [21-24]  = Gyro Y (Int32LE)
  [25-28]  = Gyro Z (Int32LE)
  [29-32]  = Pressure (Int32LE)
  [33-36]  = Battery (Int32LE)
  [37-38]  = CRLF (0x0D 0x0A)
  ```

- **Command Packet Format** (39 bytes):
  ```
  [0]      = Mode (1=Pressure, 2=PWM, 3=Length)
  [1-36]   = 9×Int32LE targets (4 bytes each)
  [37-38]  = CRLF (0x0D 0x0A)
  ```

- **Network**: UDP broadcast on port 5005 (commands), listen on port 5006 (telemetry)

### MJPEG Camera Server
- **Protocol**: HTTP MJPEG (multipart/x-mixed-replace)
- **Format**: JPEG frames with 0xFFD8 (SOI) to 0xFFD9 (EOI) markers
- **Recommended Software**:
  - `mjpg-streamer` (Linux)
  - `yawcam` (Windows)
  - `ffmpeg` (cross-platform)

**Example mjpg-streamer Setup**:
```bash
mjpg_streamer -i "input_uvc.so -r 1920x1080 -f 30 -d /dev/video0" \
              -o "output_http.so -p 8080 -w /usr/share/mjpg-streamer/www"
# Access at: http://<ip>:8080/?action=stream
```

---

## Additional Resources

- **Bug Fix Documentation**: [TARGET_VALUES_BUG_FIX.md](TARGET_VALUES_BUG_FIX.md)
- **Camera Integration Guide**: [CAMERA_INTEGRATION.md](CAMERA_INTEGRATION.md)
- **UI Improvements**: [UI_IMPROVEMENTS.md](UI_IMPROVEMENTS.md)
- **Changelog**: [CHANGELOG.md](CHANGELOG.md)

---

## Getting Help

If you encounter issues not covered here:

1. **Check Logs Tab**: Most errors are logged with timestamps
2. **Run with Verbose Output**:
   ```bash
   flutter run -v 2>&1 | tee debug.log
   ```
3. **Check Network with tcpdump**:
   ```bash
   sudo tcpdump -i any -n udp port 5005 or udp port 5006
   ```
4. **Contact Developer**: Provide `debug.log` and description of issue

---

**Enjoy using FlexPAL Control Suite!** 🤖📹
