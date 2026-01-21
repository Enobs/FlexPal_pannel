import RPi.GPIO as GPIO
import time
import sys

# 使用GPIO 14（对应物理引脚是8，如果使用BOARD模式）
P_SERVO = 14  # GPIO 14（BCM编号）
fPWM = 50     # Hz (舵机标准频率)

# 舵机角度范围对应的占空比参数
MIN_DUTY = 2.5   # 0度对应的占空比
MAX_DUTY = 12.5  # 180度对应的占空比

# 角度范围和速度设置
MAX_ANGLE = 80   # 最大角度
STEP_DELAY = 0.05  # 50ms每步，可调：0.02=快, 0.05=稳, 0.1=很慢

# 当前角度
current_angle = 0

def _set_pwm(angle):
    """内部函数：直接设置PWM"""
    reversed_angle = 180 - angle
    duty_cycle = MIN_DUTY + (reversed_angle / 180.0) * (MAX_DUTY - MIN_DUTY)
    pwm.ChangeDutyCycle(duty_cycle)

def setup():
    global pwm
    GPIO.setmode(GPIO.BCM)  # 使用BCM编号方式
    GPIO.setup(P_SERVO, GPIO.OUT)
    
    pwm = GPIO.PWM(P_SERVO, fPWM)
    pwm.start(0)  # 初始占空比为0
    time.sleep(0.5)  # 给舵机初始化时间

def set_angle(angle):
    """设置舵机角度（0-80度），平滑移动"""
    global current_angle

    # 确保角度在有效范围内 (0-80)
    angle = max(0, min(MAX_ANGLE, angle))

    # 平滑移动：每次移动1度，避免瞬时电流过大
    if abs(angle - current_angle) > 1:
        step = 1 if angle > current_angle else -1
        for pos in range(int(current_angle), int(angle), step):
            _set_pwm(pos)
            time.sleep(STEP_DELAY)

    # 最终位置
    _set_pwm(angle)
    current_angle = angle
    print(f"设置角度: {angle}°")

def cleanup():
    """清理GPIO资源"""
    pwm.stop()
    GPIO.cleanup()

def main():
    print("舵机控制程序启动...")
    print("输入角度 (0-80度)，或输入 'exit' 退出")
    setup()
    
    try:
        # 如果命令行有参数，直接转动到指定角度
        if len(sys.argv) > 1:
            angle = float(sys.argv[1])
            set_angle(angle)
        else:
            # 交互模式
            while True:
                user_input = input("\n请输入角度 (0-80) 或 'exit': ").strip()
                
                if user_input.lower() in ['exit', 'quit', 'q']:
                    print("退出程序")
                    break
                
                try:
                    angle = float(user_input)
                    set_angle(angle)
                except ValueError:
                    print("错误：请输入一个有效的数字 (0-80)")
    
    except KeyboardInterrupt:
        print("\n程序被用户中断")
    
    finally:
        # 确保清理GPIO
        cleanup()
        print("GPIO已清理")
        print("程序结束")

if __name__ == "__main__":
    main()