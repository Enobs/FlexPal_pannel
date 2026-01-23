# FlexPAL Control Suite

Cross-platform Flutter app for controlling 9-chamber soft robotics system via UDP with VLA recording.

## Quick Start

```bash
# Install & run
flutter pub get
flutter run

# Test without hardware
dart run tools/udp_simulator.dart 127.0.0.1 5006
```

## Features

- **3 Control Modes**: Pressure (-100k~30k Pa), PWM (-100~100%), Length (15~30cm)
- **Real-time Monitoring**: Charts for Length, Pressure, Battery, 6-axis IMU
- **VLA Recording**: Timestamped CSV for ML training
- **Camera Integration**: 1-3 MJPEG streams at 30 FPS
- **Gripper Control**: UDP-based servo gripper control (0-80°)
- **Cross-platform**: Linux, Windows, macOS, Android, iOS

## Configuration

### Network (Settings Tab)
| Setting | Default | Description |
|---------|---------|-------------|
| Broadcast Address | 192.168.137.255 | Network broadcast IP |
| Send Port | 5005 | Command port |
| Receive Port | 5006 | Telemetry port |
| Send Rate | 25 Hz | Command frequency |

### Camera (Optional)
| Setting | Default | Description |
|---------|---------|-------------|
| Base IP | 172.31.243.152 | Camera server IP |
| Ports | 8080, 8081, 8082 | Camera ports |
| Path | /?action=stream | MJPEG URL path |
| Save FPS | 30 | Recording frame rate |

### Gripper (Optional)
| Setting | Default | Description |
|---------|---------|-------------|
| IP Address | 192.168.137.244 | Raspberry Pi IP |
| Port | 5010 | UDP port |
| Max Angle | 80 | Maximum servo angle (degrees) |

## UDP Protocol

### Command Packet (39 bytes, Little Endian)
```
[0]     Mode (1=Pressure, 2=PWM, 3=Length)
[1-36]  9×Int32LE targets
[37-38] CRLF (0x0D 0x0A)
```

### Telemetry Packet (37-40 bytes, Little Endian)
```
[0]     Chamber ID (1-9)
[1-4]   Length (Float32LE, mm)
[5-28]  IMU (Float32LE × 6: AccelXYZ, GyroXYZ)
[29-32] Pressure (Float32LE, kPa)
[33-36] Battery (Float32LE, %)
```

### Gripper UDP Protocol (Port 5010)
| Command | Description | Response |
|---------|-------------|----------|
| `ANGLE:<0-80>` | Set servo angle | `OK:ANGLE:<angle>` |
| `OPEN` | Open gripper (80°) | `OK:OPEN:<angle>` |
| `CLOSE` | Close gripper (0°) | `OK:CLOSE:<angle>` |
| `HALF` | Half position (40°) | `OK:HALF:<angle>` |
| `STATUS` | Get current angle | `OK:STATUS:<angle>` |

Test from terminal:
```bash
echo "STATUS" | nc -u -w 2 192.168.137.244 5010
```

## Recording

Recordings saved to `~/Documents/VLA_Records/<timestamp>_<name>/`:
```
├── manifest.json    # Episode metadata
├── commands.csv     # Sent commands
├── telemetry.csv    # Received telemetry
└── camera/          # Camera frames (if enabled)
    └── cam0/
        ├── frames/  # JPEG files
        └── index.csv
```

### To Record:
1. (Optional) Camera tab → Start Preview
2. Remote tab → Enter episode name → Start Recording
3. Control robot with sliders
4. Stop Recording

## Troubleshooting

### No UDP Connection
```bash
# Check firewall
sudo ufw allow 5005/udp
sudo ufw allow 5006/udp

# Monitor packets
sudo tcpdump -i any -n udp port 5005 or udp port 5006
```

### Sliders Send All Zeros
Set slider values **before** clicking "Start Sending"

### Camera Not Working
```bash
# Test camera URL
curl -I http://<ip>:<port>/?action=stream
```

### App Won't Start
```bash
flutter clean && flutter pub get && flutter run
```

## Raspberry Pi Gripper Setup

### Hardware
- Raspberry Pi (any model with GPIO)
- Servo motor connected to GPIO 14 (BCM)
- 5V power supply for servo

### Software Setup
1. Copy `tools/motor_test.py` to Pi:
```bash
scp tools/motor_test.py flexpal@192.168.137.244:~/motor_test.py
```

2. Create systemd service for auto-start:
```bash
sudo nano /etc/systemd/system/gripper.service
```

Add content:
```ini
[Unit]
Description=Gripper UDP Server
After=network.target

[Service]
ExecStart=/usr/bin/python3 /home/flexpal/motor_test.py --udp
WorkingDirectory=/home/flexpal
User=root
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

3. Enable and start service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable gripper.service
sudo systemctl start gripper.service
```

4. Check status:
```bash
sudo systemctl status gripper.service
```

## Project Structure

```
lib/
├── main.dart
├── core/
│   ├── udp/           # UDP communication
│   ├── camera/        # MJPEG streaming
│   ├── record/        # VLA recording
│   ├── models/        # Data models
│   └── state/         # App state
├── pages/             # UI screens
└── widgets/           # Reusable components
```

## Changelog

### v1.2.0 (Latest)
- Gripper control via UDP (servo on Raspberry Pi GPIO 14)
- Remote page redesign: camera views + text input controls
- Compact overview page with chip-style summary
- Systemd service setup for auto-start gripper on Pi

### v1.1.2
- Camera integration (1-3 MJPEG streams, 30 FPS recording)
- Fixed slider values reset bug
- Negative PWM support

### v1.1.1
- 40-byte packet support
- Enhanced UDP debugging

### v1.1.0
- Modern UI redesign
- Apply Network Changes button

### v1.0.0
- Initial release

---

**Version**: 1.2.0 | **Platform**: Flutter 3.0+ | **License**: MIT
