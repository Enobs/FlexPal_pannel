#!/usr/bin/env python3
"""
Test script to send negative PWM values to STM32
Helps verify if the issue is with packet format or STM32 firmware
"""
import socket
import struct
import time

# Network configuration
BROADCAST_ADDRESS = '192.168.137.255'
PORT = 5005

# Create UDP socket
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)

def send_pwm_command(pwm_values):
    """
    Send PWM command packet
    Args:
        pwm_values: List of 9 PWM values (-100 to 100)
    """
    mode = 2  # PWM mode
    packet = struct.pack('<B', mode)  # Byte 0: mode

    for pwm in pwm_values:
        # Pack as signed int32 little-endian
        packet += struct.pack('<i', pwm)

    packet += b'\r\n'  # CRLF terminator

    # Print debug info
    hex_dump = ' '.join(f'{b:02x}' for b in packet)
    print(f"\nSending PWM values: {pwm_values}")
    print(f"Packet ({len(packet)} bytes): {hex_dump}")

    # Show how negative values are encoded
    for i, pwm in enumerate(pwm_values):
        offset = 1 + i * 4
        bytes_hex = ' '.join(f'{packet[offset+j]:02x}' for j in range(4))
        print(f"  Chamber {i+1}: {pwm:4d} -> {bytes_hex}")

    sock.sendto(packet, (BROADCAST_ADDRESS, PORT))
    print(f"✓ Sent to {BROADCAST_ADDRESS}:{PORT}")

def main():
    print("=" * 60)
    print("FlexPAL Negative PWM Test")
    print("=" * 60)

    # Test 1: All chambers at +50%
    print("\n[Test 1] All chambers: +50% PWM")
    send_pwm_command([50] * 9)
    time.sleep(2)

    # Test 2: All chambers at -50%
    print("\n[Test 2] All chambers: -50% PWM")
    send_pwm_command([-50] * 9)
    time.sleep(2)

    # Test 3: Gradual transition from +100 to -100
    print("\n[Test 3] Chamber 1: Ramp from +100 to -100")
    for pwm in range(100, -101, -20):
        values = [pwm, 0, 0, 0, 0, 0, 0, 0, 0]
        send_pwm_command(values)
        print(f"  PWM = {pwm}%")
        time.sleep(0.5)

    # Test 4: Alternating positive and negative
    print("\n[Test 4] Alternating: +100, -100, +100, ...")
    send_pwm_command([100, -100, 100, -100, 100, -100, 100, -100, 100])
    time.sleep(2)

    # Test 5: Edge cases
    print("\n[Test 5] Edge cases: -100, -1, 0, +1, +100")
    send_pwm_command([-100, -1, 0, 1, 100, 0, 0, 0, 0])
    time.sleep(2)

    # Test 6: Verify negative value encoding
    print("\n[Test 6] Single chamber with -1")
    print("Expected encoding for -1 as Int32LE:")
    print("  -1 in binary: 0xFFFFFFFF")
    print("  Little-endian bytes: ff ff ff ff")
    send_pwm_command([-1, 0, 0, 0, 0, 0, 0, 0, 0])
    time.sleep(2)

    print("\n" + "=" * 60)
    print("Test complete!")
    print("\nIf negative values don't work, possible causes:")
    print("1. STM32 firmware reads as UInt32 instead of Int32")
    print("2. STM32 firmware doesn't handle sign bit correctly")
    print("3. STM32 motor driver rejects negative values")
    print("\nCheck STM32 firmware code for how it parses PWM values.")
    print("=" * 60)

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nTest interrupted by user")
    except Exception as e:
        print(f"\nError: {e}")
    finally:
        sock.close()
