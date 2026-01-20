# FlexPAL UDP Command Packet Structure

## Overview
The Flutter app sends 39-byte UDP command packets to control 9 chambers. Each packet contains a mode byte, 9 signed 32-bit integer targets (little-endian), and a CRLF terminator.

## Packet Format (39 bytes total)

```
┌─────────┬──────────────────────────────────┬────────┐
│ Byte 0  │        Bytes 1-36                │ 37-38  │
│  Mode   │    9 × Int32LE Targets          │  CRLF  │
└─────────┴──────────────────────────────────┴────────┘
```

### Byte Layout
```
Offset | Size | Type      | Description
-------|------|-----------|----------------------------------
0      | 1    | uint8     | Mode (1=Pressure, 2=PWM, 3=Length)
1-4    | 4    | int32_le  | Chamber 1 target
5-8    | 4    | int32_le  | Chamber 2 target
9-12   | 4    | int32_le  | Chamber 3 target
13-16  | 4    | int32_le  | Chamber 4 target
17-20  | 4    | int32_le  | Chamber 5 target
21-24  | 4    | int32_le  | Chamber 6 target
25-28  | 4    | int32_le  | Chamber 7 target
29-32  | 4    | int32_le  | Chamber 8 target
33-36  | 4    | int32_le  | Chamber 9 target
37     | 1    | uint8     | CR (0x0D)
38     | 1    | uint8     | LF (0x0A)
```

## Mode Values

| Mode | Name     | Value Range        | Unit | Description |
|------|----------|--------------------|------|-------------|
| 1    | Pressure | -100000 to 30000   | Pa   | Pressure control in Pascals |
| 2    | PWM      | -100 to 100        | %    | PWM duty cycle percentage |
| 3    | Length   | 1500 to 3000       | 0.1mm| Length in 0.1mm units (15.0-30.0 cm) |

## Data Encoding Details

### Int32 Little-Endian (Int32LE)
- **Signed 32-bit integer** (range: -2,147,483,648 to 2,147,483,647)
- **Little-endian byte order** (least significant byte first)
- Uses **two's complement** for negative numbers

### Encoding Examples

#### Example 1: Zero
```
Value: 0
Bytes: [00 00 00 00]
       [b0 b1 b2 b3]
```

#### Example 2: Positive Number (30000)
```
Value: 30000 decimal = 0x00007530
Bytes: [30 75 00 00]
       [b0 b1 b2 b3]
```

#### Example 3: Negative Number (-50000)
```
Value: -50000 decimal
Two's complement: 0xFFFF3CB0
Bytes: [b0 3c ff ff]
       [b0 b1 b2 b3]

Verification:
  b0 = 0xB0 = 176
  b1 = 0x3C = 60
  b2 = 0xFF = 255
  b3 = 0xFF = 255

  Value = b0 + (b1 << 8) + (b2 << 16) + (b3 << 24)
        = 176 + (60 × 256) + (255 × 65536) + (255 × 16777216)
        = 176 + 15360 + 16711680 + 4278190080
        = 4294917296 (unsigned interpretation)

  As signed int32: 4294917296 - 4294967296 = -50000 ✓
```

#### Example 4: Large Negative (-100000)
```
Value: -100000 decimal
Two's complement: 0xFFFE7960
Bytes: [60 79 fe ff]
       [b0 b1 b2 b3]
```

### How to Identify Negative Numbers
Look at bytes b2 and b3 (the upper two bytes):
- If **b2 = 0xFF and b3 = 0xFF**: Number is negative
- If **b2 = 0x00 and b3 = 0x00**: Number is positive (or small negative)

## Complete Packet Examples

### Example 1: Pressure Mode - All Zeros
```
Mode: 1 (Pressure)
All targets: 0 Pa

Hex bytes (39 total):
01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 0d 0a

Breakdown:
  [01]           = Mode 1 (Pressure)
  [00 00 00 00]  = Chamber 1: 0
  [00 00 00 00]  = Chamber 2: 0
  [00 00 00 00]  = Chamber 3: 0
  [00 00 00 00]  = Chamber 4: 0
  [00 00 00 00]  = Chamber 5: 0
  [00 00 00 00]  = Chamber 6: 0
  [00 00 00 00]  = Chamber 7: 0
  [00 00 00 00]  = Chamber 8: 0
  [00 00 00 00]  = Chamber 9: 0
  [0d 0a]        = CRLF terminator
```

### Example 2: Pressure Mode - Chamber 6 at -50000 Pa
```
Mode: 1 (Pressure)
Chambers 1-5: 0 Pa
Chamber 6: -50000 Pa
Chambers 7-9: 0 Pa

Hex bytes (39 total):
01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 b0 3c ff ff 00 00 00 00 00 00 00 00 00
00 00 00 0d 0a

Breakdown:
  [01]           = Mode 1 (Pressure)
  [00 00 00 00]  = Chamber 1: 0
  [00 00 00 00]  = Chamber 2: 0
  [00 00 00 00]  = Chamber 3: 0
  [00 00 00 00]  = Chamber 4: 0
  [00 00 00 00]  = Chamber 5: 0
  [b0 3c ff ff]  = Chamber 6: -50000 ← NEGATIVE (note ff ff)
  [00 00 00 00]  = Chamber 7: 0
  [00 00 00 00]  = Chamber 8: 0
  [00 00 00 00]  = Chamber 9: 0
  [0d 0a]        = CRLF terminator
```

### Example 3: PWM Mode - Mixed Values
```
Mode: 2 (PWM)
Chamber 1: 50%
Chamber 2: -30%
Chambers 3-9: 0%

Hex bytes (39 total):
02 32 00 00 00 e2 ff ff ff 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 0d 0a

Breakdown:
  [02]           = Mode 2 (PWM)
  [32 00 00 00]  = Chamber 1: 50 (0x32 = 50)
  [e2 ff ff ff]  = Chamber 2: -30 (note ff ff)
  [00 00 00 00]  = Chamber 3: 0
  ... (remaining chambers at 0)
  [0d 0a]        = CRLF terminator
```

### Example 4: Length Mode
```
Mode: 3 (Length)
Chamber 1: 2550 (25.50 cm)
Chambers 2-9: 1500 (15.00 cm - minimum)

Hex bytes (39 total):
03 f6 09 00 00 dc 05 00 00 dc 05 00 00 dc 05 00 00
dc 05 00 00 dc 05 00 00 dc 05 00 00 dc 05 00 00 dc
05 00 00 0d 0a

Breakdown:
  [03]           = Mode 3 (Length)
  [f6 09 00 00]  = Chamber 1: 2550 (0x09F6 = 25.50 cm)
  [dc 05 00 00]  = Chamber 2: 1500 (0x05DC = 15.00 cm)
  [dc 05 00 00]  = Chamber 3: 1500
  ... (all at 1500)
  [0d 0a]        = CRLF terminator
```

## STM32 Zephyr Parsing Code (C)

### Correct Way - Using Signed Integers

```c
#include <stdint.h>
#include <string.h>

#define PACKET_SIZE 39
#define NUM_CHAMBERS 9

typedef struct {
    uint8_t mode;           // 1=Pressure, 2=PWM, 3=Length
    int32_t targets[NUM_CHAMBERS];  // IMPORTANT: int32_t, NOT uint32_t!
} command_packet_t;

// Parse incoming UDP packet
bool parse_command_packet(const uint8_t *buffer, size_t len, command_packet_t *cmd) {
    if (len != PACKET_SIZE) {
        printk("ERROR: Invalid packet size %d, expected %d\n", len, PACKET_SIZE);
        return false;
    }

    // Verify CRLF terminator
    if (buffer[37] != 0x0D || buffer[38] != 0x0A) {
        printk("ERROR: Missing CRLF terminator\n");
        return false;
    }

    // Parse mode
    cmd->mode = buffer[0];
    if (cmd->mode < 1 || cmd->mode > 3) {
        printk("ERROR: Invalid mode %d\n", cmd->mode);
        return false;
    }

    // Parse 9 int32 targets (little-endian)
    for (int i = 0; i < NUM_CHAMBERS; i++) {
        int offset = 1 + (i * 4);

        // Method 1: Using memcpy (recommended)
        memcpy(&cmd->targets[i], &buffer[offset], sizeof(int32_t));

        // Method 2: Manual little-endian assembly (if needed)
        // int32_t value = (int32_t)(
        //     buffer[offset + 0] |
        //     (buffer[offset + 1] << 8) |
        //     (buffer[offset + 2] << 16) |
        //     (buffer[offset + 3] << 24)
        // );
        // cmd->targets[i] = value;
    }

    return true;
}

// Example usage
void on_udp_receive(uint8_t *data, size_t len) {
    command_packet_t cmd;

    if (!parse_command_packet(data, len, &cmd)) {
        return;  // Parsing failed
    }

    printk("Received command - Mode: %d\n", cmd.mode);
    for (int i = 0; i < NUM_CHAMBERS; i++) {
        printk("  Chamber %d: %d\n", i + 1, cmd->targets[i]);
    }

    // Apply commands to chambers
    apply_chamber_commands(&cmd);
}
```

### Common Mistakes to Avoid

#### ❌ WRONG - Using unsigned integers
```c
// THIS WILL CAUSE NEGATIVE NUMBERS TO BE INTERPRETED AS LARGE POSITIVE!
uint32_t targets[9];  // ❌ WRONG!

// -50000 (0xFFFF3CB0) will be read as 4294917296
```

#### ✅ CORRECT - Using signed integers
```c
// This correctly interprets negative numbers
int32_t targets[9];  // ✅ CORRECT!

// -50000 (0xFFFF3CB0) will be read as -50000
```

#### ❌ WRONG - Big-endian byte order
```c
// Wrong byte order!
int32_t value = (buffer[0] << 24) | (buffer[1] << 16) |
                (buffer[2] << 8) | buffer[3];  // ❌ WRONG!
```

#### ✅ CORRECT - Little-endian byte order
```c
// Correct byte order (least significant byte first)
int32_t value = buffer[0] | (buffer[1] << 8) |
                (buffer[2] << 16) | (buffer[3] << 24);  // ✅ CORRECT!
```

## Verification Checklist

When debugging your STM32 firmware, verify:

1. **Packet size is exactly 39 bytes**
   - If not, packet may be fragmented or corrupted

2. **CRLF terminator is present** (bytes 37-38 = 0x0D 0x0A)
   - If not, packet may be truncated

3. **Mode byte is 1, 2, or 3**
   - If not, packet is invalid

4. **Use `int32_t` not `uint32_t`** for target values
   - Critical for negative number support

5. **Parse as little-endian**
   - Least significant byte first

6. **Test with known values:**
   - Send -50000 from Flutter app
   - Print raw bytes: should see `[b0 3c ff ff]`
   - Print parsed value: should see `-50000`, NOT `4294917296`

## Debug Logging Example

```c
void debug_print_packet(const uint8_t *buffer, size_t len) {
    printk("=== Received UDP Packet (%d bytes) ===\n", len);

    // Print mode
    printk("Mode: %d\n", buffer[0]);

    // Print raw hex
    printk("Raw hex: ");
    for (int i = 0; i < len; i++) {
        printk("%02x ", buffer[i]);
        if ((i + 1) % 16 == 0) printk("\n         ");
    }
    printk("\n");

    // Parse and print targets
    for (int i = 0; i < 9; i++) {
        int offset = 1 + (i * 4);
        int32_t target;
        memcpy(&target, &buffer[offset], sizeof(int32_t));

        printk("Chamber %d: %d [%02x %02x %02x %02x]\n",
               i + 1,
               target,
               buffer[offset],
               buffer[offset+1],
               buffer[offset+2],
               buffer[offset+3]);
    }

    printk("Terminator: [%02x %02x] %s\n",
           buffer[37], buffer[38],
           (buffer[37] == 0x0D && buffer[38] == 0x0A) ? "OK" : "ERROR");
}
```

## Expected Output for -50000 Test

When you set Chamber 6 to -50000 Pa in the Flutter app, your STM32 should print:

```
=== Received UDP Packet (39 bytes) ===
Mode: 1
Raw hex: 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
         00 00 00 00 00 b0 3c ff ff 00 00 00 00 00 00 00
         00 00 00 00 00 0d 0a
Chamber 1: 0 [00 00 00 00]
Chamber 2: 0 [00 00 00 00]
Chamber 3: 0 [00 00 00 00]
Chamber 4: 0 [00 00 00 00]
Chamber 5: 0 [00 00 00 00]
Chamber 6: -50000 [b0 3c ff ff]  ← Should be negative!
Chamber 7: 0 [00 00 00 00]
Chamber 8: 0 [00 00 00 00]
Chamber 9: 0 [00 00 00 00]
Terminator: [0d 0a] OK
```

**If Chamber 6 shows `4294917296` instead of `-50000`**, your firmware is using `uint32_t` instead of `int32_t`!

## Flutter App Packet Builder Code Reference

The Flutter app builds packets using this code (from `lib/core/udp/packet_builder.dart`):

```dart
static Uint8List buildCommand(int mode, List<int> targets) {
  assert(targets.length == 9, 'Must have exactly 9 target values');
  assert(mode >= 1 && mode <= 3, 'Mode must be 1, 2, or 3');

  final buffer = ByteData(39);

  // Byte 0: CommandType
  buffer.setUint8(0, mode);

  // Bytes 1-36: 9 × Int32LE targets
  for (int i = 0; i < 9; i++) {
    buffer.setInt32(1 + i * 4, targets[i], Endian.little);
  }

  // Bytes 37-38: CRLF
  buffer.setUint8(37, 0x0D);
  buffer.setUint8(38, 0x0A);

  return buffer.buffer.asUint8List();
}
```

Note: `buffer.setInt32(..., Endian.little)` writes a **signed** 32-bit integer in little-endian byte order.

## Summary

- **Packet size:** Always 39 bytes
- **Mode byte:** 1 byte at offset 0
- **Targets:** 9 × 4 bytes (int32_le) at offsets 1-36
- **Terminator:** 2 bytes (CR LF) at offsets 37-38
- **Critical:** Use `int32_t` (signed) not `uint32_t` (unsigned)
- **Critical:** Parse as little-endian byte order
- **Negative numbers:** Have `0xFF 0xFF` in upper two bytes

---

Generated for FlexPAL Multi-Platform Control Suite
Flutter App Version: 1.0.0
Document Date: 2025-11-14
