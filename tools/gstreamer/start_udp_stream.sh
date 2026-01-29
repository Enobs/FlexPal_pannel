#!/bin/bash

# === UDP JPEG Streaming with GStreamer ===
# Streams camera frames over UDP with RTP timestamps for accurate timing
#
# Prerequisites on Pi:
#   sudo apt-get install gstreamer1.0-tools gstreamer1.0-plugins-base \
#        gstreamer1.0-plugins-good gstreamer1.0-plugins-bad v4l-utils

# === Configuration ===
CAMERA_NAME="DECXIN"           # Camera identifier from v4l2-ctl --list-devices
TARGET_IP="192.168.137.255"    # Broadcast address (255) - all devices on network receive
BASE_PORT=5000                 # Starting UDP port (cam0=5000, cam1=5001, etc.)
WIDTH=320
HEIGHT=240
FPS=60
BROADCAST=true                 # Enable broadcast mode

# === Script ===
echo "=== UDP JPEG Streamer ==="
echo "Target: $TARGET_IP"
echo "Resolution: ${WIDTH}x${HEIGHT} @ ${FPS}fps"
echo ""

# Find camera devices
CAM_DEVICES=($(v4l2-ctl --list-devices 2>/dev/null | grep -A1 "$CAMERA_NAME" | grep "/dev/video" | awk '{print $1}'))

if [ ${#CAM_DEVICES[@]} -eq 0 ]; then
  echo "No $CAMERA_NAME cameras found!"
  echo "Available devices:"
  v4l2-ctl --list-devices
  exit 1
fi

echo "Found ${#CAM_DEVICES[@]} camera(s): ${CAM_DEVICES[*]}"
echo ""

# Kill any existing streams
pkill -f "gst-launch.*udpsink" 2>/dev/null

CURRENT_PORT=$BASE_PORT

for i in "${!CAM_DEVICES[@]}"; do
  DEVICE="${CAM_DEVICES[$i]}"
  PORT=$CURRENT_PORT

  echo "Starting cam$i: $DEVICE -> udp://$TARGET_IP:$PORT"

  # GStreamer pipeline:
  # - v4l2src: capture from camera
  # - video/x-raw: set format/resolution/fps
  # - jpegenc: encode to JPEG
  # - rtpjpegpay: wrap in RTP packets (includes timestamps)
  # - udpsink: send over UDP

  # GStreamer pipeline - broadcast works by just sending to .255 address
  # Let v4l2src negotiate the best MJPEG format, then scale if needed
  gst-launch-1.0 -v \
    v4l2src device="$DEVICE" do-timestamp=true \
    ! image/jpeg \
    ! jpegdec \
    ! videoscale \
    ! "video/x-raw,width=$WIDTH,height=$HEIGHT" \
    ! videorate \
    ! "video/x-raw,framerate=$FPS/1" \
    ! jpegenc quality=85 \
    ! rtpjpegpay \
    ! udpsink host="$TARGET_IP" port="$PORT" sync=false async=false \
    2>&1 | while read line; do echo "[cam$i] $line"; done &

  ((CURRENT_PORT++))
  sleep 0.5
done

echo ""
echo "=== Streams started ==="
echo "Press Ctrl+C to stop all streams"
echo ""

# Wait for interrupt
trap "echo 'Stopping...'; pkill -f 'gst-launch.*udpsink'; exit 0" INT TERM
wait
