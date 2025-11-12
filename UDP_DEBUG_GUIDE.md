# UDP Communication Debugging Guide

## 🔍 Problem Analysis

Based on your tcpdump output, we identified:
- **STM32 IP**: 192.168.137.35
- **Computer IP**: 192.168.137.1
- **STM32 sending to port**: 5005
- **Packet size**: 40 bytes (not the expected 37 bytes)
- **Issue**: App was listening on port 5006, then changed to 5005 but still not detecting

## ✅ Changes Made

### 1. Enhanced UDP Service Logging
**File**: [lib/core/udp/udp_service.dart](lib/core/udp/udp_service.dart)

Added detailed logging to show:
- When packets are received (with size and source IP/port)
- First 8 bytes of each packet in hex format
- Whether parsing succeeded or failed
- Exact parse error messages

**Example log output**:
```
[12:34:56.789] Received 40 bytes from 192.168.137.35:5005
[12:34:56.789]   Packet preview (hex): 04 4e 1b bb 42...
[12:34:56.789]   ✓ Parsed: Chamber 4, Length=123.4mm
```

### 2. Updated Packet Parser
**File**: [lib/core/udp/packet_parser.dart](lib/core/udp/packet_parser.dart)

**Changes**:
- Now accepts **both 37-byte and 40-byte packets**
- Added sanity checks for NaN/Infinite values
- Added `PacketParser.lastError` to show exactly why parsing failed
- Validates chamber ID (1-9), length, pressure, and battery ranges

**Why 40 bytes?**
Your STM32 firmware is sending 40-byte packets instead of 37. The extra 3 bytes (at the end) are likely:
- Padding for alignment
- CRLF terminator (0x0D 0x0A) + 1 extra byte
- Or part of your firmware's packet format

The parser now accepts both formats and ignores the extra bytes.

### 3. Improved Error Messages

Instead of silent failures, you'll now see specific errors like:
- `Invalid packet size: 45 bytes (expected 37 or 40)`
- `Invalid chamber ID: 0 (expected 1-9)`
- `Invalid battery value: -5.0`
- `Invalid length value: NaN`

## 🧪 How to Debug

### Step 1: Check the Logs Page

1. Run your app: `flutter run -d linux`
2. Navigate to the **Logs** page (bottom navigation, 4th icon)
3. Look for log messages showing:
   - `UDP service started: recv on :5005, send to 192.168.137.255:5005`
   - `Received 40 bytes from 192.168.137.35:5005`
   - Either `✓ Parsed` or `✗ Parse failed: [reason]`

### Step 2: Verify Network Settings

In the **Settings** page:
1. Set **Receive Port**: `5005` (matches STM32)
2. Set **Send Port**: `5005` (or whatever your STM32 expects)
3. Set **Broadcast Address**: `192.168.137.255`
4. Click **"Apply Network Changes (Restart UDP)"**
5. Go to Logs page and verify you see "UDP service started"

### Step 3: Check Overview Page

If packets are being received and parsed correctly:
- The **Overview** page should show chambers going ONLINE
- You should see real-time data for Length, Pressure, Battery
- Chamber cards should have green borders when online

### Step 4: Analyze Packet Format

If parsing still fails, check the logs for the hex preview:
```
Packet preview (hex): 04 4e 1b bb 42...
```

**Decode manually**:
- Byte 0: `04` = Chamber ID 4 ✓
- Bytes 1-4: Length as Float32LE
- Bytes 5-28: IMU data (6 floats)
- Bytes 29-32: Pressure as Float32LE
- Bytes 33-36: Battery as Float32LE
- Bytes 37-39: Extra bytes (ignored)

## 🐛 Common Issues

### Issue 1: App Not Receiving Any Packets

**Symptoms**: No "Received X bytes" log messages

**Possible causes**:
1. App not actually listening on port 5005
   - **Solution**: Click "Apply Network Changes" button in Settings
2. Firewall blocking UDP port 5005
   - **Solution**: `sudo ufw allow 5005/udp` or disable firewall temporarily
3. STM32 sending to wrong IP
   - **Solution**: Verify STM32 is sending to your computer's IP (192.168.137.1)

### Issue 2: Packets Received But Parse Failed

**Symptoms**: Logs show "Received 40 bytes" but "✗ Parse failed"

**Check the error message**:
- `Invalid chamber ID: X` → STM32 sending wrong chamber ID (must be 1-9)
- `Invalid battery value: X` → Battery value is NaN, Infinite, or outside 0-100
- `Invalid length value: NaN` → Length value is corrupted

**Debug packet format**:
```python
# Use this Python script to decode the hex from tcpdump
import struct

# Example from your tcpdump: 044e 1bbb 42...
hex_string = "044e1bbb42..."  # Full 40 bytes
data = bytes.fromhex(hex_string)

chamber_id = data[0]
length_mm = struct.unpack('<f', data[1:5])[0]
pressure = struct.unpack('<f', data[29:33])[0]
battery = struct.unpack('<f', data[33:37])[0]

print(f"Chamber: {chamber_id}")
print(f"Length: {length_mm} mm")
print(f"Pressure: {pressure} kPa")
print(f"Battery: {battery} %")
```

### Issue 3: Battery Value Out of Range

**Symptoms**: `✗ Parse failed: Invalid battery value: 156.7`

**Cause**: STM32 sending battery as 0-100 but with wrong scaling

**Solution**: Modify the sanity check in [packet_parser.dart:63](lib/core/udp/packet_parser.dart#L63):
```dart
// If your battery is scaled 0-255 instead of 0-100:
if (battery.isNaN || battery.isInfinite || battery < 0 || battery > 255) {
  _lastError = 'Invalid battery value: $battery';
  return null;
}
```

## 📊 Expected Behavior

Once everything is working:

1. **Logs page** shows:
   ```
   [12:34:56.000] UDP service started: recv on :5005, send to 192.168.137.255:5005
   [12:34:56.100] Received 40 bytes from 192.168.137.35:5005
   [12:34:56.100]   Packet preview (hex): 04 3d 0a d7 43...
   [12:34:56.100]   ✓ Parsed: Chamber 4, Length=123.4mm
   [12:34:56.120] Received 40 bytes from 192.168.137.35:5005
   [12:34:56.120]   ✓ Parsed: Chamber 4, Length=123.5mm
   ```

2. **Overview page** shows:
   - Chamber 4 card with **green border** and "ONLINE" badge
   - Real-time data: Length, Pressure, Battery with correct values
   - Other chambers remain grey/offline if not sending

3. **Monitor page** shows:
   - Real-time charts updating with telemetry data

## 🔧 Advanced Debugging

### Enable More Verbose Logging

Edit [main.dart](lib/main.dart) to enable debug prints:
```dart
void main() {
  debugPrintRebuildDirtyWidgets = false;
  debugPrint('Starting FlexPAL Control Suite');
  runApp(const FlexPalApp());
}
```

### Packet Dump to File

Add this to [udp_service.dart](lib/core/udp/udp_service.dart) after line 208:
```dart
// Save raw packets to file for analysis
import 'dart:io';
final f = File('/tmp/packets.log');
f.writeAsBytesSync(datagram.data, mode: FileMode.append);
```

### Test with Python UDP Sender

Create `test_send.py`:
```python
#!/usr/bin/env python3
import socket
import struct
import time

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

while True:
    # Build 40-byte packet
    chamber_id = 4
    length_mm = 123.456
    imu = [0.0] * 6  # accel xyz, gyro xyz
    pressure = 100.5
    battery = 85.0

    packet = struct.pack('<B', chamber_id)  # Byte 0
    packet += struct.pack('<f', length_mm)  # Bytes 1-4
    for val in imu:  # Bytes 5-28
        packet += struct.pack('<f', val)
    packet += struct.pack('<f', pressure)  # Bytes 29-32
    packet += struct.pack('<f', battery)   # Bytes 33-36
    packet += b'\r\n\x00'  # Bytes 37-39

    sock.sendto(packet, ('192.168.137.1', 5005))
    print(f"Sent {len(packet)} bytes")
    time.sleep(0.02)  # 50Hz
```

Run: `python3 test_send.py`

If the app detects this test packet, the issue is with your STM32 packet format.

## 🚀 Troubleshooting Sending Commands

### Issue: STM32 Not Receiving Commands

**Symptoms**: App sends packets but STM32 doesn't respond

**Debugging steps**:

1. **Check Logs page** for send confirmations:
   ```
   [12:34:56.000] Started sending at 25Hz (mode: Length)
   [12:34:56.040] Sent packet #1: 39 bytes to 192.168.137.255:5005
   [12:34:56.040]   Packet preview (hex): 03 00 00 00 00... (mode=Length)
   ```

2. **Verify STM32 is listening on the correct port**:
   - Check your STM32 firmware - what port does it bind to for receiving commands?
   - Common ports: 5005, 5006, 8888
   - Update **Send Port** in Settings to match

3. **Check if STM32 needs unicast instead of broadcast**:
   - Try setting **Broadcast Address** to STM32's IP directly: `192.168.137.35`
   - Some devices don't handle broadcast properly

4. **Verify packet format**:
   - STM32 expects 39-byte packets: `[mode(1)] + [9×Int32LE targets] + [0x0D 0x0A]`
   - Mode: 1=Pressure, 2=PWM, 3=Length
   - Use tcpdump to verify packets are being sent:
   ```bash
   sudo tcpdump -i any -vv -X 'udp and dst port 5005'
   ```

5. **Check Remote Control page**:
   - Are you actually **starting** the sending?
   - Look for "TX: ON" or similar indicator
   - Try moving sliders to send different values

6. **Enable sending in Overview page**:
   - Sending might be OFF by default
   - Check Settings page for auto-start options

### Command Packet Format

The app sends 39-byte command packets:

```
Byte 0: Mode (1=Pressure, 2=PWM, 3=Length)
Bytes 1-36: 9 targets as Int32LE (4 bytes each)
Bytes 37-38: CRLF (0x0D 0x0A)
```

**Example for Length mode (mode=3)** with all chambers at 100mm:
```
03 64 00 00 00 64 00 00 00 64 00 00 00 64 00 00 00 64 00 00 00 64 00 00 00 64 00 00 00 64 00 00 00 64 00 00 00 0d 0a
```

Decoded:
- `03` = Mode 3 (Length)
- `64 00 00 00` = 100 (little-endian Int32) × 9 chambers
- `0d 0a` = CRLF

### Testing Send with tcpdump

On your computer, run:
```bash
# Listen for outgoing packets
sudo tcpdump -i any -vv -X 'udp and dst port 5005'
```

You should see packets like:
```
12:34:56.040 IP 192.168.137.1.54321 > 192.168.137.255.5005: UDP, length 39
0x0000:  03 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
0x0010:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
0x0020:  00 00 00 00 00 0d 0a
```

### Quick Test Script

Create `test_receive.py` to verify your computer can send to STM32:

```python
#!/usr/bin/env python3
import socket
import struct

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)

# Build 39-byte command packet
mode = 3  # Length mode
targets = [100] * 9  # 100mm for all chambers

packet = struct.pack('<B', mode)  # Byte 0: mode
for target in targets:
    packet += struct.pack('<i', target)  # 9×Int32LE
packet += b'\r\n'  # CRLF

print(f"Sending {len(packet)} bytes to 192.168.137.255:5005")
print(f"Hex: {packet.hex()}")

sock.sendto(packet, ('192.168.137.255', 5005))
# Or try unicast directly to STM32:
# sock.sendto(packet, ('192.168.137.35', 5005))

print("Sent! Check if STM32 responds...")
```

Run: `python3 test_receive.py`

If STM32 responds to this but not the app, compare the hex output.

## 📝 Next Steps

1. **Run the app** and check the Logs page
2. **Check if sending is started** - look for "Started sending at 25Hz" message
3. **Verify send port** matches what STM32 expects (check your STM32 firmware)
4. **Try unicast** instead of broadcast if needed
5. **Use tcpdump** to verify packets are actually being sent from your computer
6. **Share the log output** if sending still doesn't work

---

**Updated**: 2025-11-12
**Version**: 1.1.1 (Debug Edition)
