import RPi.GPIO as GPIO
import time
import sys

# 使用GPIO 14（对应物理引脚是8，如果使用BOARD模式）
P_SERVO = 14  # GPIO 14（BCM编号）
fPWM = 50     # Hz (舵机标准频率)

# 舵机角度范围对应的占空比参数
MIN_DUTY = 2.5   # 0度对应的占空比
MAX_DUTY = 12.5  # 180度对应的占空比

def setup():
    global pwm
    GPIO.setmode(GPIO.BCM)  # 使用BCM编号方式
    GPIO.setup(P_SERVO, GPIO.OUT)
    
    pwm = GPIO.PWM(P_SERVO, fPWM)
    pwm.start(0)  # 初始占空比为0
    time.sleep(0.5)  # 给舵机初始化时间

def set_angle(angle):
    """设置舵机角度（0-180度），已修正方向"""
    # 确保角度在有效范围内
    angle = max(0, min(180, angle))
    
    # 反转角度：将角度映射反转，0度变成180度，180度变成0度
    reversed_angle = 180 - angle
    
    # 计算占空比：使用反转后的角度进行计算
    duty_cycle = MIN_DUTY + (reversed_angle / 180.0) * (MAX_DUTY - MIN_DUTY)
    
    # 设置占空比
    pwm.ChangeDutyCycle(duty_cycle)
    print(f"设置角度: {angle}° (实际使用反转角度: {reversed_angle}°)")
    time.sleep(0.5)  # 等待舵机转动

def cleanup():
    """清理GPIO资源"""
    pwm.stop()
    GPIO.cleanup()

def main():
    print("舵机控制程序启动...")
    print("注意：舵机方向已修正（原本反向了）")
    print("输入角度 (0-180度)，或输入 'exit' 退出")
    setup()
    
    try:
        # 如果命令行有参数，直接转动到指定角度
        if len(sys.argv) > 1:
            angle = float(sys.argv[1])
            set_angle(angle)
        else:
            # 交互模式
            while True:
                user_input = input("\n请输入角度 (0-180) 或 'exit': ").strip()
                
                if user_input.lower() in ['exit', 'quit', 'q']:
                    print("退出程序")
                    break
                
                try:
                    angle = float(user_input)
                    set_angle(angle)
                except ValueError:
                    print("错误：请输入一个有效的数字 (0-180)")
    
    except KeyboardInterrupt:
        print("\n程序被用户中断")
    
    finally:
        # 确保清理GPIO
        cleanup()
        print("GPIO已清理")
        print("程序结束")

if __name__ == "__main__":
    main()