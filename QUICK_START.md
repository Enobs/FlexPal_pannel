# FlexPAL Control Suite - Quick Start Guide

**Version 1.1.2** | 2-Minute Setup

---

## Step 1: Install & Run (Choose One)

### Option A: From Source (Requires Flutter SDK)
```bash
# Extract
tar -xzf FlexPal_pannel_v1.1.2_source.tar.gz
cd FlexPal_pannel

# Install & Run
flutter pub get
flutter run
```

### Option B: Pre-built Executable (No SDK Required)
```bash
# Linux
tar -xzf FlexPal_pannel_v1.1.2_linux_x64.tar.gz
cd bundle && ./flexpal_pannel

# Windows
Extract FlexPal_pannel_v1.1.2_windows_x64.zip
Run flexpal_pannel.exe

# macOS
tar -xzf FlexPal_pannel_v1.1.2_macos.tar.gz
open FlexPAL\ Control.app
```

---

## Step 2: Configure Network (2 minutes)

1. Click **⚙ Settings** tab (bottom right)
2. **Network Configuration** section:
   - **Broadcast Address**: Your network's broadcast IP
     ```
     Example: 192.168.137.255
     (If your IP is 192.168.137.x, use .255 at end)
     ```
   - **Send Port**: `5005` (default)
   - **Receive Port**: `5006` (default)
3. Click **💾 Save Settings**
4. Click **🔄 Apply Network Changes**
5. Top bar should show green **UDP** badge ✅

**Stuck?** → See [SETUP_INSTRUCTIONS.md](SETUP_INSTRUCTIONS.md#finding-your-broadcast-address)

---

## Step 3: Test Control (1 minute)

1. Click **🎮 Remote** tab
2. Select mode: **PWM** (easiest to test)
3. Move **Chamber 4** slider to **50%**
4. Click **▶ Start Sending**
5. Check **📋 Logs** tab → Should see:
   ```
   Target values (Int32): 0, 0, 0, 50, 0, 0, 0, 0, 0
   ```
6. STM32 should respond (if connected)

---

## Step 4: Camera Setup (Optional, 2 minutes)

1. Still in **⚙ Settings** tab
2. **Camera Configuration** section:
   - **Base IP**: Your camera server IP (e.g., `172.31.243.152`)
   - **Ports**: `8080, 8081, 8082` (comma-separated)
   - **Path**: `/?action=stream` (default)
   - **Max Views**: `1`, `2`, or `3`
   - **Save FPS**: `30` (recommended)
3. Click **💾 Save Settings**
4. Go to **📹 Camera** tab
5. Click **▶ Start Preview**
6. Should see live camera feeds! 🎥

**No cameras?** That's okay! Skip this step for now.

---

## Step 5: Record Episode (1 minute)

1. Go to **🎮 Remote** tab
2. Enter episode name: `test_001`
3. Click **🔴 Start Recording**
4. Move sliders, generate commands
5. Top bar shows red **REC** badge
6. Click **⏹ Stop Recording**
7. Files saved to: `~/Documents/VLA_Records/`

**Camera enabled?** → Frames saved in `camera/cam*/frames/` ✅

---

## Troubleshooting (30 seconds)

| Problem | Solution |
|---------|----------|
| Red "DISCONNECTED" badge | Check firewall allows UDP 5005/5006 |
| Sliders send all zeros | Set sliders **before** clicking "Start Sending" |
| Camera shows "No signal" | Verify camera server running at IP:Port |
| App won't start | Run: `flutter clean && flutter pub get` |

**Full troubleshooting** → [SETUP_INSTRUCTIONS.md#troubleshooting](SETUP_INSTRUCTIONS.md#troubleshooting)

---

## What's New in v1.1.2? 🎉

✨ **Camera Integration**
- 1-3 MJPEG stream preview
- 30 FPS recording synced with episodes
- Auto-reconnect + timestamp overlay

🐛 **Bug Fixes**
- Fixed slider values being reset to zero ([details](TARGET_VALUES_BUG_FIX.md))
- Negative PWM support (-100 to +100)

---

## Next Steps

📚 **Full Documentation**:
- [SETUP_INSTRUCTIONS.md](SETUP_INSTRUCTIONS.md) - Complete setup guide
- [CAMERA_INTEGRATION.md](CAMERA_INTEGRATION.md) - Camera details
- [README.md](README.md) - Full feature list

🎯 **Usage Tips**:
- Use **📊 Monitor** tab for real-time charts
- **📋 Logs** tab shows all system events
- **📺 Overview** tab shows all 9 chambers at once

🚀 **Advanced**:
- Record episodes for ML training datasets
- Export logs to CSV for analysis
- Use UDP simulator for offline testing

---

**Need Help?** Check logs tab first - most issues are logged with solutions.

**Enjoy controlling your soft robots!** 🤖
