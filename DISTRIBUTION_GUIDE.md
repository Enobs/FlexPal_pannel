# Distribution Guide - FlexPAL Control Suite v1.1.2

This guide explains how to package and share your project with users.

---

## Quick Distribution (Automated)

### Use the Packaging Script

```bash
cd /home/yinan/Documents/FlexPal_pannel
./package_for_distribution.sh
```

This creates a `dist/` folder with:
- ✅ Source code archive (`.tar.gz`)
- ✅ Executable binary for your platform
- ✅ Distribution README

**Time**: ~2-5 minutes depending on platform

---

## What to Send to Users

### Recommended: Complete Package

Send **everything** in the `dist/` folder:

```
dist/
├── FlexPal_pannel_v1.1.2_source_TIMESTAMP.tar.gz  (Source code)
├── FlexPal_pannel_v1.1.2_linux_x64_TIMESTAMP.tar.gz (Binary - Linux)
└── README.txt (Instructions)
```

**Why both?**
- Source: For developers who want to modify/contribute
- Binary: For end-users who just want to run it

### Upload Options

**Option 1: Google Drive / Dropbox**
```bash
# Upload entire dist/ folder
# Share link with users
```

**Option 2: GitHub Release**
```bash
cd /home/yinan/Documents/FlexPal_pannel
git init
git add .
git commit -m "Release v1.1.2 - Camera integration"
git tag v1.1.2
git remote add origin <your-github-repo>
git push origin main --tags

# Then create GitHub Release and attach files from dist/
```

**Option 3: File Transfer**
```bash
# Via scp
scp dist/* user@server:/path/to/public/folder/

# Via rsync
rsync -avz dist/ user@server:/path/to/folder/
```

---

## Manual Packaging (If Script Fails)

### Source Code Archive

```bash
cd /home/yinan/Documents
tar -czf FlexPal_pannel_v1.1.2_source.tar.gz \
    --exclude="FlexPal_pannel/build" \
    --exclude="FlexPal_pannel/.dart_tool" \
    --exclude="FlexPal_pannel/.idea" \
    --exclude="FlexPal_pannel/dist" \
    FlexPal_pannel/
```

### Build Executable

**Linux:**
```bash
cd /home/yinan/Documents/FlexPal_pannel
flutter build linux --release
cd build/linux/x64/release
tar -czf ~/FlexPal_pannel_v1.1.2_linux_x64.tar.gz bundle/
```

**Windows (on Windows machine):**
```bash
flutter build windows --release
cd build/windows/x64/runner/Release
Compress-Archive -Path * -DestinationPath ~/FlexPal_pannel_v1.1.2_windows_x64.zip
```

**macOS (on Mac):**
```bash
flutter build macos --release
cd build/macos/Build/Products/Release
tar -czf ~/FlexPal_pannel_v1.1.2_macos.tar.gz *.app
```

---

## Pre-Distribution Checklist

### 1. Code Quality ✅

```bash
# Run analyzer
flutter analyze

# Should show: 0 errors
# Warnings are okay (mostly style suggestions)
```

### 2. Test Functionality ✅

**Basic Tests:**
- [ ] App launches without errors
- [ ] Settings page loads default values
- [ ] UDP connects (green badge)
- [ ] Remote control sliders work
- [ ] Camera page opens (even without cameras)
- [ ] Recording creates files in ~/Documents/VLA_Records/

**Advanced Tests:**
- [ ] Test with real STM32 device
- [ ] Test with MJPEG camera streams
- [ ] Record full episode and verify file structure
- [ ] Export logs to CSV

### 3. Documentation Complete ✅

Required files to include:
- [ ] README.md (updated with v1.1.2 info)
- [ ] SETUP_INSTRUCTIONS.md (complete setup guide)
- [ ] QUICK_START.md (2-minute quick start)
- [ ] CAMERA_INTEGRATION.md (camera features)
- [ ] TARGET_VALUES_BUG_FIX.md (bug fix details)
- [ ] CHANGELOG.md (version history)

### 4. Version Numbers Updated ✅

Check these files have correct version:
- [ ] README.md: Line 368 → "Version: 1.1.2"
- [ ] SETUP_INSTRUCTIONS.md: Line 3 → "Version: 1.1.2"
- [ ] package_for_distribution.sh: Line 3 → VERSION="1.1.2"
- [ ] pubspec.yaml: Line 3 → version: 1.1.2+1

```bash
# Quick check
grep -n "version\|Version" README.md SETUP_INSTRUCTIONS.md package_for_distribution.sh pubspec.yaml
```

### 5. Clean Build ✅

```bash
# Clean old builds
flutter clean

# Verify dependencies
flutter pub get

# Test build
flutter run
```

---

## User Support Preparation

### Create Support Email Template

Save this as `support_email_template.txt`:

```
Subject: FlexPAL Control Suite v1.1.2 - Support Request

Hi [User],

Thanks for using FlexPAL Control Suite! I need some info to help:

1. What operating system? (Linux/Windows/macOS)
2. Flutter version? (if using source): flutter --version
3. What's the issue? (brief description)
4. Any error messages? (copy from Logs tab)

Quick troubleshooting:
- UDP not connecting? Check firewall allows ports 5005/5006
- Sliders sending zeros? Set values BEFORE clicking "Start Sending"
- Camera issues? Verify server running at IP:Port

See troubleshooting guide: SETUP_INSTRUCTIONS.md#troubleshooting

Best,
[Your Name]
```

### Create FAQ Document

Common questions to prepare for:
1. "Can I use this without STM32 hardware?"
   - Yes! Use the UDP simulator: `dart run tools/udp_simulator.dart`

2. "Do I need cameras to use this?"
   - No, camera features are optional

3. "What video format do cameras need?"
   - MJPEG over HTTP (e.g., mjpg-streamer)

4. "Can I record without sending commands?"
   - Currently no, but you can set all targets to zero

5. "How do I change network settings?"
   - Settings tab → Network Configuration → Save → Apply

---

## Post-Distribution

### Collect Feedback

Ask users to test these scenarios:
1. **Basic connectivity**: UDP connects (5 minutes)
2. **Command sending**: Sliders control chambers (5 minutes)
3. **Recording**: Create episode and verify files (10 minutes)
4. **Camera preview**: If they have cameras (10 minutes)

### Track Issues

Create a simple issue tracking sheet:

| User | Issue | Status | Solution |
|------|-------|--------|----------|
| User1 | UDP won't connect | Fixed | Firewall blocking port 5006 |
| User2 | Camera lag | Pending | Investigating network bandwidth |

### Version Control (Optional but Recommended)

If using Git:
```bash
cd /home/yinan/Documents/FlexPal_pannel
git init
git add .
git commit -m "v1.1.2 Release - Camera integration"
git tag -a v1.1.2 -m "Version 1.1.2 - Camera streaming and recording"

# If you have a remote repo
git remote add origin <your-repo-url>
git push origin main --tags
```

---

## File Size Reference

Typical file sizes:
- **Source archive**: ~5-10 MB
- **Linux binary**: ~40-60 MB
- **Windows binary**: ~50-80 MB
- **macOS binary**: ~40-70 MB

**Total package**: ~100-200 MB

---

## Security Considerations

### What to EXCLUDE from distribution:

❌ Don't include:
- `/build/` - Build artifacts
- `/.dart_tool/` - Flutter cache
- `/.idea/` - IDE settings
- `/dist/` - Previous distributions
- Any `.env` or credential files
- Personal test data in `VLA_Records/`

✅ Safe to include:
- All `/lib/` source code
- Documentation (*.md files)
- `pubspec.yaml` and `pubspec.lock`
- `/test/` unit tests
- `/tools/` utilities

### Firewall/Network Warnings

Include this in your distribution README:

```
⚠️ NETWORK REQUIREMENTS:
This app requires UDP broadcast on ports 5005/5006.
Users may need to:
- Allow UDP traffic in firewall
- Configure router for UDP broadcast
- Disable VPN (may block broadcasts)
```

---

## Quick Commands Reference

```bash
# Clean everything
flutter clean

# Build for all platforms (run on each platform)
flutter build linux --release
flutter build windows --release
flutter build macos --release

# Create source archive
tar -czf FlexPal_v1.1.2_source.tar.gz FlexPal_pannel/ \
  --exclude="build" --exclude=".dart_tool"

# Test without hardware
dart run tools/udp_simulator.dart 127.0.0.1 5006 &
flutter run

# Package everything
./package_for_distribution.sh
```

---

## Success Metrics

Your distribution is successful if users can:
- ✅ Extract and run within 5 minutes
- ✅ Connect to UDP network within 2 minutes
- ✅ Send first command within 1 minute
- ✅ Record an episode within 5 minutes

**Target**: 90% of users complete setup in <15 minutes without contacting support.

---

## Need Help?

If the packaging script fails:
1. Check Flutter installation: `flutter doctor`
2. Verify all files exist: `ls -R lib/`
3. Try manual packaging steps above
4. Check disk space: `df -h`

---

**Ready to distribute?** Run `./package_for_distribution.sh` and send the `dist/` folder! 🚀
