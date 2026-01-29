# GStreamer UDP Streaming Setup

This provides lower latency and more consistent frame timing than MJPEG/HTTP streaming.

## Prerequisites (Raspberry Pi)

```bash
sudo apt-get update
sudo apt-get install gstreamer1.0-tools gstreamer1.0-plugins-base \
     gstreamer1.0-plugins-good gstreamer1.0-plugins-bad v4l-utils
```

## Usage

1. **Copy the script to Pi:**
   ```bash
   scp start_udp_stream.sh pi@<pi-ip>:~/
   ```

2. **Edit configuration in `start_udp_stream.sh`:**
   - `TARGET_IP`: IP address of your computer/phone running the Flutter app
   - `CAMERA_NAME`: Camera identifier (run `v4l2-ctl --list-devices` to find it)
   - `BASE_PORT`: Starting UDP port (default 5000)

3. **Run on Pi:**
   ```bash
   ./start_udp_stream.sh
   ```

4. **Enable UDP in Flutter app:**
   - Go to Settings → Camera Configuration
   - Enable "Use UDP/RTP (GStreamer)"
   - Save settings
   - Start camera preview

## Ports

- Camera 0: UDP port 5000
- Camera 1: UDP port 5001
- Camera 2: UDP port 5002

## Troubleshooting

**No video in app:**
- Check TARGET_IP is correct (your computer's IP, not Pi's)
- Ensure firewall allows UDP on ports 5000-5002
- Try `nc -ul 5000` on your computer to see if packets arrive

**GStreamer errors:**
- Check camera is detected: `v4l2-ctl --list-devices`
- Try lower resolution: change `WIDTH=320` and `HEIGHT=240`
- Check USB bandwidth: only use one camera initially

## Reverting to MJPEG

If UDP doesn't work:
1. Kill GStreamer on Pi: `pkill gst-launch`
2. Start mjpg-streamer instead
3. Disable "Use UDP/RTP" in Flutter settings

## Performance Comparison

| Metric          | MJPEG/HTTP | UDP/RTP |
|-----------------|------------|---------|
| Latency         | 50-150ms   | 10-30ms |
| Frame jitter    | ±30ms      | ±5ms    |
| Reliability     | 100%       | ~99%    |
| Setup           | Easy       | Moderate|
