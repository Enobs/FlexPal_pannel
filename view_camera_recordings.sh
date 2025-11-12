#!/bin/bash
# View Camera Recordings - Quick Browser Script

VLA_DIR="$HOME/Documents/VLA_Records"

echo "=========================================="
echo "FlexPAL Camera Recordings Viewer"
echo "=========================================="
echo ""

if [ ! -d "$VLA_DIR" ]; then
    echo "❌ No recordings found at: $VLA_DIR"
    exit 1
fi

# List all episodes with camera recordings
echo "📁 Episodes with camera recordings:"
echo ""

episodes=$(find "$VLA_DIR" -type d -name "camera" | sed 's|/camera$||' | sort -r)

if [ -z "$episodes" ]; then
    echo "❌ No camera recordings found"
    echo ""
    echo "To create camera recordings:"
    echo "1. Start camera preview in Camera tab"
    echo "2. Go to Remote tab"
    echo "3. Click 'Start Recording'"
    exit 0
fi

count=1
declare -a episode_list

while IFS= read -r ep; do
    episode_name=$(basename "$ep")
    cam_dir="$ep/camera"

    # Count frames
    total_frames=$(find "$cam_dir" -name "*.jpg" 2>/dev/null | wc -l)

    # Count cameras
    num_cams=$(find "$cam_dir" -mindepth 1 -maxdepth 1 -type d -name "cam*" 2>/dev/null | wc -l)

    # Calculate size
    size=$(du -sh "$cam_dir" 2>/dev/null | cut -f1)

    echo "[$count] $episode_name"
    echo "    Cameras: $num_cams | Frames: $total_frames | Size: $size"
    echo "    Path: $ep"

    episode_list[$count]="$ep"
    ((count++))
    echo ""
done <<< "$episodes"

echo "=========================================="
echo ""
read -p "Enter episode number to view (or 'q' to quit): " choice

if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
    exit 0
fi

if [ -z "${episode_list[$choice]}" ]; then
    echo "❌ Invalid choice"
    exit 1
fi

selected_ep="${episode_list[$choice]}"
cam_dir="$selected_ep/camera"

echo ""
echo "=========================================="
echo "Episode: $(basename "$selected_ep")"
echo "=========================================="
echo ""

# Show camera details
for camdir in "$cam_dir"/cam*/; do
    if [ -d "$camdir" ]; then
        cam_name=$(basename "$camdir")
        frame_count=$(find "$camdir/frames" -name "*.jpg" 2>/dev/null | wc -l)
        first_frame=$(find "$camdir/frames" -name "*.jpg" 2>/dev/null | sort | head -1)
        last_frame=$(find "$camdir/frames" -name "*.jpg" 2>/dev/null | sort | tail -1)

        echo "📹 $cam_name: $frame_count frames"

        if [ -f "$camdir/index.csv" ]; then
            echo "   Index: $camdir/index.csv"
            echo "   First 3 entries:"
            head -4 "$camdir/index.csv" | tail -3 | sed 's/^/     /'
        fi

        echo ""
    fi
done

echo "=========================================="
echo "Actions:"
echo "=========================================="
echo ""
echo "1. Open camera directory in file manager"
echo "2. View first frame (requires display)"
echo "3. Create video from frames (requires ffmpeg)"
echo "4. Show index.csv for camera 0"
echo "q. Quit"
echo ""
read -p "Choose action: " action

case $action in
    1)
        xdg-open "$cam_dir" 2>/dev/null || nautilus "$cam_dir" 2>/dev/null || echo "❌ Could not open file manager"
        ;;
    2)
        first=$(find "$cam_dir/cam0/frames" -name "*.jpg" 2>/dev/null | sort | head -1)
        if [ -f "$first" ]; then
            xdg-open "$first" 2>/dev/null || eog "$first" 2>/dev/null || echo "❌ Could not open image viewer"
        else
            echo "❌ No frames found"
        fi
        ;;
    3)
        if ! command -v ffmpeg &> /dev/null; then
            echo "❌ ffmpeg not installed. Install with: sudo apt install ffmpeg"
            exit 1
        fi

        output="$selected_ep/camera_cam0_video.mp4"
        echo "Creating video..."

        cd "$cam_dir/cam0/frames" || exit 1

        # Create temporary file list sorted by sequence number
        find . -name "*.jpg" | sed 's|^\./||' | sort -t_ -k1 -n > /tmp/frame_list.txt

        # Create video at 30 fps
        ffmpeg -y -r 30 -f concat -safe 0 \
            -i <(sed "s|^|file '|; s|$|'|" /tmp/frame_list.txt) \
            -c:v libx264 -pix_fmt yuv420p -crf 23 \
            "$output" 2>&1 | grep -E "frame=|error"

        if [ -f "$output" ]; then
            echo "✅ Video created: $output"
            echo "   Playing video..."
            xdg-open "$output" 2>/dev/null || vlc "$output" 2>/dev/null || mpv "$output" 2>/dev/null
        else
            echo "❌ Video creation failed"
        fi
        ;;
    4)
        if [ -f "$cam_dir/cam0/index.csv" ]; then
            echo ""
            echo "First 10 entries from cam0 index.csv:"
            echo ""
            head -11 "$cam_dir/cam0/index.csv" | column -t -s,
            echo ""
            echo "Total entries: $(wc -l < "$cam_dir/cam0/index.csv")"
        else
            echo "❌ index.csv not found"
        fi
        ;;
    q|Q)
        exit 0
        ;;
    *)
        echo "❌ Invalid choice"
        ;;
esac

echo ""
echo "Done!"
