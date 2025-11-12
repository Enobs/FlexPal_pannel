# Camera Recording Guide

## Quick Answer: Where Are My Camera Recordings?

**Location**: `~/Documents/VLA_Records/<episode_name>/camera/`

Example:
```
~/Documents/VLA_Records/2025-11-12T06-26-50_check/camera/
├── cam0/
│   ├── frames/
│   │   ├── 000001_mono1762928810658_2025-11-12T06-26-50.658483Z.jpg
│   │   ├── 000002_mono1762928810697_2025-11-12T06-26-50.697282Z.jpg
│   │   └── ... (293 frames total)
│   └── index.csv
└── ...
```

---

## How Camera Recording Works

### Important: Camera Recording is Episode-Based

Camera recordings are **NOT standalone**. They are **synchronized with VLA Episode recordings**.

This means:
- ✅ Camera frames are saved when you start an Episode recording
- ❌ Camera page "Start Recording" button is currently a placeholder
- ✅ Recording automatically includes cameras if preview is running

---

## Step-by-Step: Record Camera Footage

### Step 1: Start Camera Preview
1. Go to **Camera** tab (📹 video icon)
2. Click **"Start Preview"**
3. Verify cameras are streaming (green online indicators)

### Step 2: Start Episode Recording
1. Go to **Remote** tab (🎮 gamepad icon)
2. Enter episode name (e.g., "camera_test_001")
3. Click **"🔴 Start Recording"**
4. **Camera recording starts automatically**
5. Top bar shows red "REC" badge

### Step 3: Do Your Recording
- Move robot sliders
- Camera frames are captured at configured FPS (default: 30 FPS)
- Logs tab shows: "Camera recording started"

### Step 4: Stop Recording
1. Click **"⏹ Stop Recording"** in Remote tab
2. Camera recording stops automatically
3. Check Logs tab for: "Camera recording stopped"

### Step 5: Find Your Files
```bash
cd ~/Documents/VLA_Records/
ls -lh  # Shows all episodes

# Or use the viewer script:
./view_camera_recordings.sh
```

---

## File Structure

### Episode Directory
```
VLA_Records/
└── 2025-11-12T06-26-50_episode_name/
    ├── manifest.json           # Episode metadata
    ├── commands.csv            # Robot commands
    ├── telemetry.csv          # Robot telemetry
    └── camera/                # ← Camera recordings HERE
        ├── cam0/
        │   ├── frames/        # JPEG files
        │   │   ├── 000001_mono1762928810658_2025-11-12T06-26-50.658483Z.jpg
        │   │   ├── 000002_...jpg
        │   │   └── ...
        │   └── index.csv      # Frame metadata
        ├── cam1/              # (if multiple cameras)
        └── cam2/
```

### Filename Format
```
000001_mono1762928810658_2025-11-12T06-26-50.658483Z.jpg
│      │                 │
│      │                 └─ ISO 8601 wall-clock time (: replaced with -)
│      └─ Monotonic timestamp in milliseconds
└─ Sequential frame number (6 digits, zero-padded)
```

### Index CSV Format
```csv
seq,ts_mono_ms,wall_time_iso,filename,w,h
1,1762928810658,2025-11-12T06-26-50.658483Z,000001_mono1762928810658_2025-11-12T06-26-50.658483Z.jpg,,
2,1762928810697,2025-11-12T06-26-50.697282Z,000002_mono1762928810697_2025-11-12T06-26-50.697282Z.jpg,,
...
```

**Note**: Width (w) and Height (h) are currently empty - frame dimensions not extracted yet.

---

## Viewing Your Recordings

### Option 1: Use the Viewer Script (Recommended)

```bash
cd /home/yinan/Documents/FlexPal_pannel
./view_camera_recordings.sh
```

This script:
- Lists all episodes with camera recordings
- Shows frame counts and sizes
- Opens file manager
- Views individual frames
- Creates video with ffmpeg (optional)
- Displays index.csv

### Option 2: Manual Viewing

**View frames:**
```bash
cd ~/Documents/VLA_Records/<episode_name>/camera/cam0/frames
eog *.jpg  # Eye of GNOME (Linux)
# or
xdg-open 000001*.jpg  # Opens default viewer
```

**Check statistics:**
```bash
cd ~/Documents/VLA_Records/<episode_name>/camera/cam0

# Count frames
ls frames/*.jpg | wc -l

# Total size
du -sh frames/

# View index
cat index.csv | column -t -s,
```

### Option 3: Create Video (requires ffmpeg)

```bash
cd ~/Documents/VLA_Records/<episode_name>/camera/cam0/frames

# Install ffmpeg if needed
sudo apt install ffmpeg

# Create 30 FPS video
ls -1 *.jpg | sort -t_ -k1 -n > /tmp/frames.txt
cat /tmp/frames.txt | sed "s|^|file '|; s|$|'|" > /tmp/frames_list.txt

ffmpeg -y -r 30 -f concat -safe 0 \
    -i /tmp/frames_list.txt \
    -c:v libx264 -pix_fmt yuv420p -crf 23 \
    ../video_output.mp4

# Play video
vlc ../video_output.mp4
```

---

## Troubleshooting

### Problem: No camera/ directory in episode

**Cause**: Camera preview was not running when episode started

**Solution**:
1. Start Camera preview FIRST
2. Then start Episode recording

### Problem: Empty camera/cam0/frames/ directory

**Cause**: Cameras not streaming (offline)

**Check**:
1. Camera preview shows green online indicators?
2. Settings → Camera Configuration correct?
3. Camera server running?

**Test camera URL manually**:
```bash
curl -I http://172.31.243.152:8080/?action=stream
# Should return: HTTP/1.0 200 OK
```

### Problem: Only a few frames recorded

**Cause**: Short recording duration or low FPS setting

**Check**:
- Settings → Camera Configuration → Default Save FPS
- Recording duration (each frame ~33ms at 30 FPS)
- Logs tab for "Cam 0: wrote frame #30" messages

### Problem: "ERROR closing files" in logs

**Status**: Fixed in latest version

**Details**:
- This error appeared when stopping recording
- Files were still saved correctly
- Fixed by removing redundant flush() before close()

### Problem: Large file sizes

**Normal**:
- 30 FPS × 14 seconds = ~420 frames
- Each JPEG ~100-200 KB
- Total: ~40-80 MB per camera per minute

**Reduce size**:
1. Lower FPS in Settings (30 → 15 or 10)
2. Configure camera server for lower quality
3. Record shorter episodes

---

## Configuration

### Camera Settings Location
**Settings** tab → **Camera Configuration** section

| Setting | Default | Description |
|---------|---------|-------------|
| Base IP | 172.31.243.152 | Camera server IP address |
| Ports | 8080, 8081, 8082 | Comma-separated ports for each camera |
| Path | /?action=stream | MJPEG URL path |
| Max Views | 3 | Number of cameras (1-3) |
| Default Save FPS | 30 | Recording frame rate |
| Output Root | ./VLA_Records | Base recording directory |

### Changing Recording FPS

**Temporary** (current session only):
1. Camera page → Save FPS dropdown
2. Select 10, 15, 20, or 30 FPS

**Permanent** (default for new episodes):
1. Settings → Camera Configuration → Default Save FPS
2. Save Settings

---

## Advanced: Processing Recordings

### Extract Frame at Specific Time

```bash
# Find frame closest to timestamp
cd ~/Documents/VLA_Records/<episode>/camera/cam0

# Search by monotonic time
grep "1762928815000" index.csv

# Or by wall-clock time
grep "2025-11-12T06-26-55" index.csv
```

### Synchronize with Robot Commands

```python
import pandas as pd

# Load camera frames
camera = pd.read_csv('camera/cam0/index.csv')

# Load robot commands
commands = pd.read_csv('commands.csv')

# Merge by monotonic timestamp (within 50ms tolerance)
merged = pd.merge_asof(
    camera.sort_values('ts_mono_ms'),
    commands.sort_values('ts_ms'),
    left_on='ts_mono_ms',
    right_on='ts_ms',
    direction='nearest',
    tolerance=50
)

print(merged)
```

### Batch Process Multiple Episodes

```bash
# Find all episodes with cameras
find ~/Documents/VLA_Records -name "camera" -type d

# Count total frames across all episodes
find ~/Documents/VLA_Records -name "*.jpg" | wc -l

# Total camera recording size
du -sh ~/Documents/VLA_Records/*/camera
```

---

## FAQ

**Q: Can I record cameras without starting an episode?**
A: Not currently. Camera recording is tied to episode recording. This may be added in a future update.

**Q: Why are width and height empty in index.csv?**
A: Frame dimensions are not extracted to avoid decoding overhead. You can extract dimensions with:
```bash
identify -format "%w×%h\n" frames/000001*.jpg
```

**Q: Can I record at higher than 30 FPS?**
A: Currently limited to 10/15/20/30 FPS. Higher rates may be added if needed.

**Q: What happens if cameras go offline during recording?**
A: Recording continues for online cameras. Offline cameras simply don't write frames.

**Q: Can I use this with other video sources besides MJPEG?**
A: Currently only MJPEG over HTTP is supported.

---

## Summary

**To record camera footage:**
1. Settings → Configure cameras
2. Camera tab → Start Preview
3. Remote tab → Start Recording
4. Find files in `~/Documents/VLA_Records/<episode>/camera/`

**Quick view:**
```bash
./view_camera_recordings.sh
```

**Your test recording worked!**
- Episode: `2025-11-12T06-26-50_check`
- Frames: 293
- Size: 38 MB
- Location: `~/Documents/VLA_Records/2025-11-12T06-26-50_check/camera/cam0/`

---

For more details, see:
- [CAMERA_INTEGRATION.md](CAMERA_INTEGRATION.md) - Technical documentation
- [SETUP_INSTRUCTIONS.md](SETUP_INSTRUCTIONS.md) - Complete setup guide
