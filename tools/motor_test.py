import RPi.GPIO as GPIO
import time
import sys
import socket
import argparse

# =========================
# Config
# =========================
P_SERVO = 14     # BCM pin
fPWM = 50        # 50Hz servo PWM

# Typical servo duty range (for RPi.GPIO at 50Hz):
# 2.5% ~ 12.5% corresponds roughly to 0° ~ 180°
MIN_DUTY = 2.5
MAX_DUTY = 12.5

MAX_ANGLE = 80           # clamp to 0~80
STEP_DEG = 1             # step size in degree
STEP_DELAY = 0.06        # per step delay (s). 0.05~0.12 recommended
DEADBAND_DEG = 1.0       # do nothing if change < 1 degree
SETTLE_TIME = 0.20       # after final set, allow to settle while holding torque
HOLD_REFRESH = 0.00      # optional: extra wait after "hold". keep 0 usually

DEFAULT_UDP_PORT = 5010

# =========================
# State
# =========================
current_angle = 0.0
pwm = None
running = True


def angle_to_duty(angle_deg: float) -> float:
    """
    Convert angle (0~180) to duty cycle (MIN_DUTY~MAX_DUTY).
    Your code reverses direction: reversed_angle = 180 - angle
    """
    reversed_angle = 180.0 - angle_deg
    duty = MIN_DUTY + (reversed_angle / 180.0) * (MAX_DUTY - MIN_DUTY)
    return max(0.0, min(100.0, duty))


def _set_pwm(angle_deg: float):
    """Set PWM duty cycle for the given angle."""
    duty = angle_to_duty(angle_deg)
    pwm.ChangeDutyCycle(duty)


def setup():
    global pwm, current_angle
    GPIO.setmode(GPIO.BCM)
    GPIO.setup(P_SERVO, GPIO.OUT)

    pwm = GPIO.PWM(P_SERVO, fPWM)
    pwm.start(0)                 # start with 0 duty
    time.sleep(0.5)              # let servo & PWM init

    # Initialize to 0 deg smoothly to avoid a sudden kick (optional)
    current_angle = 0.0
    _set_pwm(current_angle)
    time.sleep(0.2)


def set_angle(target_angle: float):
    """
    Smoothly move servo to target angle (0~MAX_ANGLE) and keep PWM ON to maintain torque.
    """
    global current_angle

    # clamp
    target_angle = max(0.0, min(float(MAX_ANGLE), float(target_angle)))

    # deadband: avoid micro-changes that cause jitter & current spikes
    if abs(target_angle - current_angle) < DEADBAND_DEG:
        # still "hold" current position (keep torque)
        _set_pwm(current_angle)
        return

    start = int(round(current_angle))
    end = int(round(target_angle))

    step = STEP_DEG if end > start else -STEP_DEG

    # print only once (avoid heavy IO during motion)
    print(f"Move: {current_angle:.1f}° -> {target_angle:.1f}° (step={STEP_DEG}°, delay={STEP_DELAY}s)")

    # smooth stepping
    for pos in range(start, end, step):
        _set_pwm(pos)
        current_angle = float(pos)
        time.sleep(STEP_DELAY)

    # final position set + settle (keep holding torque)
    _set_pwm(target_angle)
    current_angle = float(target_angle)

    # "stabilize": repeat once after a short settle; sometimes reduces final jitter
    time.sleep(SETTLE_TIME)
    _set_pwm(current_angle)
    if HOLD_REFRESH > 0:
        time.sleep(HOLD_REFRESH)

    print(f"Holding at: {current_angle:.1f}°")


def cleanup():
    global pwm
    try:
        if pwm is not None:
            pwm.ChangeDutyCycle(0)
            time.sleep(0.1)
            pwm.stop()
    finally:
        GPIO.cleanup()


def handle_command(cmd):
    """Process a command string, return response."""
    cmd = cmd.strip().upper()

    if cmd.startswith("ANGLE:"):
        try:
            angle = float(cmd.split(":")[1])
            set_angle(angle)
            return f"OK:ANGLE:{current_angle}"
        except (ValueError, IndexError):
            return "ERROR:Invalid angle value"

    elif cmd == "OPEN":
        set_angle(MAX_ANGLE)
        return f"OK:OPEN:{current_angle}"

    elif cmd == "CLOSE":
        set_angle(0)
        return f"OK:CLOSE:{current_angle}"

    elif cmd == "HALF":
        set_angle(MAX_ANGLE / 2)
        return f"OK:HALF:{current_angle}"

    elif cmd == "STATUS":
        return f"OK:STATUS:{current_angle}"

    elif cmd == "STOP":
        return "OK:STOPPING"

    else:
        return f"ERROR:Unknown command: {cmd}"


def udp_server(port):
    """Run UDP server to receive commands."""
    global running

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(('0.0.0.0', port))
    sock.settimeout(1.0)

    # Get local IP for display
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
    except:
        local_ip = "unknown"

    print(f"\n{'='*50}")
    print(f"UDP Gripper Server Started")
    print(f"{'='*50}")
    print(f"Listening on: 0.0.0.0:{port}")
    print(f"Local IP: {local_ip}")
    print(f"\nCommands:")
    print(f"  ANGLE:<0-{MAX_ANGLE}>  Set angle")
    print(f"  OPEN            Open gripper ({MAX_ANGLE}°)")
    print(f"  CLOSE           Close gripper (0°)")
    print(f"  HALF            Half position ({MAX_ANGLE/2}°)")
    print(f"  STATUS          Get current angle")
    print(f"  STOP            Stop server")
    print(f"\nTest from PC:")
    print(f"  echo 'ANGLE:40' | nc -u {local_ip} {port}")
    print(f"{'='*50}\n")

    print(f"Ready (current angle: {current_angle}°)")

    while running:
        try:
            data, addr = sock.recvfrom(1024)
            cmd = data.decode('utf-8').strip()
            if not cmd:
                continue
            print(f"[{addr[0]}:{addr[1]}] Received: {cmd}")

            response = handle_command(cmd)
            sock.sendto(response.encode('utf-8'), addr)
            print(f"[{addr[0]}:{addr[1]}] Response: {response}")

            if cmd.upper() == "STOP":
                running = False
                break

        except socket.timeout:
            continue
        except Exception as e:
            print(f"Error: {e}")

    sock.close()
    print("UDP server stopped")


def interactive_mode():
    """Run in interactive terminal mode."""
    print("Servo control started.")
    print(f"Input angle (0-{MAX_ANGLE}) or 'exit' to quit.")

    while True:
        s = input("\nAngle (0-80) or 'exit': ").strip()
        if s.lower() in ("exit", "quit", "q"):
            break
        try:
            set_angle(float(s))
        except ValueError:
            print("Invalid input. Please enter a number.")


def main():
    parser = argparse.ArgumentParser(description='Raspberry Pi Gripper Controller')
    parser.add_argument('angle', nargs='?', type=float, help='Set angle directly (0-80)')
    parser.add_argument('--udp', action='store_true', help='Run as UDP server')
    parser.add_argument('--port', type=int, default=DEFAULT_UDP_PORT, help=f'UDP port (default: {DEFAULT_UDP_PORT})')
    args = parser.parse_args()

    setup()

    try:
        if args.angle is not None:
            set_angle(args.angle)
            print("Done")
        elif args.udp:
            udp_server(args.port)
        else:
            interactive_mode()

    except KeyboardInterrupt:
        print("\nInterrupted by user.")
    finally:
        cleanup()
        print("GPIO cleaned up. Bye.")


if __name__ == "__main__":
    main()
