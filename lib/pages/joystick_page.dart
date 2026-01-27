import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/state/controller.dart';
import '../core/camera/camera_frame.dart';
import '../widgets/joystick.dart';

/// Joystick Control page - control chambers 1-8 with dual joysticks
/// Base joystick (1-4): Left=Ch1(-100),Ch3(60), Right=Ch1(60),Ch3(-100), Up=Ch2(-100),Ch4(60), Down=Ch2(60),Ch4(-100)
/// Upper joystick (5-8): Same pattern for chambers 5-8
class JoystickPage extends StatefulWidget {
  final AppController controller;

  const JoystickPage({Key? key, required this.controller}) : super(key: key);

  @override
  State<JoystickPage> createState() => _JoystickPageState();
}

class _JoystickPageState extends State<JoystickPage> {
  // Joystick state
  final GlobalKey<JoystickState> _baseJoystickKey = GlobalKey<JoystickState>();
  final GlobalKey<JoystickState> _upperJoystickKey = GlobalKey<JoystickState>();

  // PWM values for display
  List<double> _pwmValues = List.filled(9, 0.0);

  // Camera state
  final Map<int, CameraFrame?> _latestFrames = {};
  final Map<int, CameraStatus?> _latestStatus = {};
  StreamSubscription? _frameSubscription;
  StreamSubscription? _statusSubscription;
  bool _isCameraRunning = false;

  // Keyboard state
  final FocusNode _focusNode = FocusNode();
  final Set<LogicalKeyboardKey> _pressedKeys = {};

  // Gripper text controller
  final TextEditingController _gripperTextController = TextEditingController();
  double _gripperTarget = 0;
  bool _gripperOpen = false; // Track gripper state for spacebar toggle

  @override
  void initState() {
    super.initState();

    // Set mode to PWM
    widget.controller.setMode(2);

    // Initialize gripper target
    _gripperTarget = widget.controller.state.gripperAngle;
    _gripperTextController.text = _gripperTarget.toStringAsFixed(0);

    // Initialize targets to 0 (don't auto-start sending)
    _initTargets();

    // Start camera
    _startCamera();

    // Request focus for keyboard input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _stopCamera();
    _gripperTextController.dispose();
    // Reset all PWM values to 0 when leaving the page
    for (int i = 0; i < 9; i++) {
      widget.controller.setTarget(i, 0);
    }
    super.dispose();
  }

  void _initTargets() {
    for (int i = 0; i < 9; i++) {
      widget.controller.setTarget(i, 0);
    }
    setState(() {
      _pwmValues = List.filled(9, 0.0);
    });
  }

  void _startCamera() {
    if (_isCameraRunning) return;

    widget.controller.cameraService.start(widget.controller.state.settings.camera);

    _frameSubscription = widget.controller.cameraService.frames.listen((frame) {
      if (mounted) {
        setState(() {
          _latestFrames[frame.camId] = frame;
        });
      }
    });

    _statusSubscription = widget.controller.cameraService.status.listen((status) {
      if (mounted) {
        setState(() {
          _latestStatus[status.camId] = status;
        });
      }
    });

    setState(() {
      _isCameraRunning = true;
    });
  }

  void _stopCamera() {
    if (!_isCameraRunning) return;

    _frameSubscription?.cancel();
    _statusSubscription?.cancel();
    _frameSubscription = null;
    _statusSubscription = null;

    widget.controller.cameraService.stop();

    setState(() {
      _isCameraRunning = false;
      _latestFrames.clear();
      _latestStatus.clear();
    });
  }

  // Handle base joystick (chambers 1-4)
  void _onBaseJoystickChanged(double x, double y) {
    // X-axis: Left = Ch1(-100), Ch3(60); Right = Ch1(60), Ch3(-100)
    // Y-axis: Up = Ch2(-100), Ch4(60); Down = Ch2(60), Ch4(-100)

    double ch1, ch2, ch3, ch4;

    // X-axis control (left-right)
    if (x < -0.1) {
      // Left
      ch1 = -100 * x.abs();
      ch3 = 60 * x.abs();
    } else if (x > 0.1) {
      // Right
      ch1 = 60 * x.abs();
      ch3 = -100 * x.abs();
    } else {
      ch1 = 0;
      ch3 = 0;
    }

    // Y-axis control (up-down) - note: y is inverted (up is negative)
    if (y < -0.1) {
      // Up
      ch2 = -100 * y.abs();
      ch4 = 60 * y.abs();
    } else if (y > 0.1) {
      // Down
      ch2 = 60 * y.abs();
      ch4 = -100 * y.abs();
    } else {
      ch2 = 0;
      ch4 = 0;
    }

    _setBasePWM(ch1, ch2, ch3, ch4);
  }

  void _setBasePWM(double ch1, double ch2, double ch3, double ch4) {
    setState(() {
      _pwmValues[0] = ch1;
      _pwmValues[1] = ch2;
      _pwmValues[2] = ch3;
      _pwmValues[3] = ch4;
    });

    widget.controller.setTarget(0, ch1);
    widget.controller.setTarget(1, ch2);
    widget.controller.setTarget(2, ch3);
    widget.controller.setTarget(3, ch4);
  }

  // Handle upper joystick (chambers 5-8)
  void _onUpperJoystickChanged(double x, double y) {
    double ch5, ch6, ch7, ch8;

    // X-axis control (left-right)
    if (x < -0.1) {
      // Left
      ch5 = -100 * x.abs();
      ch7 = 60 * x.abs();
    } else if (x > 0.1) {
      // Right
      ch5 = 60 * x.abs();
      ch7 = -100 * x.abs();
    } else {
      ch5 = 0;
      ch7 = 0;
    }

    // Y-axis control (up-down)
    if (y < -0.1) {
      // Up
      ch6 = -100 * y.abs();
      ch8 = 60 * y.abs();
    } else if (y > 0.1) {
      // Down
      ch6 = 60 * y.abs();
      ch8 = -100 * y.abs();
    } else {
      ch6 = 0;
      ch8 = 0;
    }

    _setUpperPWM(ch5, ch6, ch7, ch8);
  }

  void _setUpperPWM(double ch5, double ch6, double ch7, double ch8) {
    setState(() {
      _pwmValues[4] = ch5;
      _pwmValues[5] = ch6;
      _pwmValues[6] = ch7;
      _pwmValues[7] = ch8;
    });

    widget.controller.setTarget(4, ch5);
    widget.controller.setTarget(5, ch6);
    widget.controller.setTarget(6, ch7);
    widget.controller.setTarget(7, ch8);
  }

  void _onBaseJoystickReleased() {
    _setBasePWM(0, 0, 0, 0);
    _baseJoystickKey.currentState?.reset();
  }

  void _onUpperJoystickReleased() {
    _setUpperPWM(0, 0, 0, 0);
    _upperJoystickKey.currentState?.reset();
  }

  // Keyboard handling
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      _pressedKeys.add(event.logicalKey);

      // Spacebar toggles gripper
      if (event.logicalKey == LogicalKeyboardKey.space) {
        _toggleGripper();
      }
    } else if (event is KeyUpEvent) {
      _pressedKeys.remove(event.logicalKey);
    }

    _updateFromKeyboard();
  }

  // Toggle gripper open/close with spacebar
  void _toggleGripper() {
    final maxAngle = widget.controller.state.settings.gripper.maxAngle.toDouble();

    setState(() {
      _gripperOpen = !_gripperOpen;
      if (_gripperOpen) {
        _gripperTarget = maxAngle;
        _gripperTextController.text = maxAngle.toStringAsFixed(0);
        widget.controller.openGripper();
      } else {
        _gripperTarget = 0;
        _gripperTextController.text = '0';
        widget.controller.closeGripper();
      }
    });
  }

  void _updateFromKeyboard() {
    // Base joystick: WASD
    double baseX = 0, baseY = 0;

    if (_pressedKeys.contains(LogicalKeyboardKey.keyA)) {
      baseX = -1.0; // Left
    } else if (_pressedKeys.contains(LogicalKeyboardKey.keyD)) {
      baseX = 1.0; // Right
    }

    if (_pressedKeys.contains(LogicalKeyboardKey.keyW)) {
      baseY = -1.0; // Up
    } else if (_pressedKeys.contains(LogicalKeyboardKey.keyS)) {
      baseY = 1.0; // Down
    }

    // Upper joystick: IJKL
    double upperX = 0, upperY = 0;

    if (_pressedKeys.contains(LogicalKeyboardKey.keyJ)) {
      upperX = -1.0; // Left
    } else if (_pressedKeys.contains(LogicalKeyboardKey.keyL)) {
      upperX = 1.0; // Right
    }

    if (_pressedKeys.contains(LogicalKeyboardKey.keyI)) {
      upperY = -1.0; // Up
    } else if (_pressedKeys.contains(LogicalKeyboardKey.keyK)) {
      upperY = 1.0; // Down
    }

    // Update joystick visuals
    _baseJoystickKey.currentState?.setPosition(baseX, baseY);
    _upperJoystickKey.currentState?.setPosition(upperX, upperY);

    // Update PWM values
    _onBaseJoystickChanged(baseX, baseY);
    _onUpperJoystickChanged(upperX, upperY);
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: ListenableBuilder(
          listenable: widget.controller.state,
          builder: (context, _) {
            final state = widget.controller.state;

            return Scaffold(
              backgroundColor: const Color(0xFF1E1E1E),
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final isPortrait = constraints.maxWidth < 700;

                  if (isPortrait) {
                    return _buildPortraitLayout(state);
                  } else {
                    return _buildLandscapeLayout(state);
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(dynamic state) {
    return Column(
      children: [
        // Top section: Cameras + PWM + Gripper (scrollable if needed)
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              children: [
                // Start/Stop control bar
                _buildControlBar(state),
                const SizedBox(height: 8),
                // Cameras side by side
                SizedBox(
                  height: 100,
                  child: Row(
                    children: [
                      Expanded(child: _buildCameraPreview(0)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildCameraPreview(1)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // PWM status display
                _buildPWMDisplay(),
                const SizedBox(height: 8),
                // Gripper control with status indicator
                if (state.settings.gripper.enabled) _buildGripperControlCompact(state),
              ],
            ),
          ),
        ),
        // Bottom section: Joysticks (fixed at bottom for easy thumb access)
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF252525),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Joysticks side by side
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Joystick(
                    key: _baseJoystickKey,
                    size: 140,
                    label: 'Base (1-4)',
                    color: const Color(0xFF3498DB),
                    onPositionChanged: _onBaseJoystickChanged,
                    onReleased: _onBaseJoystickReleased,
                  ),
                  Joystick(
                    key: _upperJoystickKey,
                    size: 140,
                    label: 'Upper (5-8)',
                    color: const Color(0xFF9B59B6),
                    onPositionChanged: _onUpperJoystickChanged,
                    onReleased: _onUpperJoystickReleased,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Keyboard hint
              _buildKeyboardHint(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(dynamic state) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          // Left column: Cameras
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(child: _buildCameraPreview(0)),
                const SizedBox(height: 8),
                Expanded(child: _buildCameraPreview(1)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Center: Joysticks
          Expanded(
            flex: 4,
            child: Column(
              children: [
                // Start/Stop control bar
                _buildControlBar(state),
                const SizedBox(height: 8),
                // PWM display
                _buildPWMDisplay(),
                const SizedBox(height: 8),
                // Joysticks
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Joystick(
                        key: _baseJoystickKey,
                        size: 150,
                        label: 'Base (1-4)',
                        color: const Color(0xFF3498DB),
                        onPositionChanged: _onBaseJoystickChanged,
                        onReleased: _onBaseJoystickReleased,
                      ),
                      Joystick(
                        key: _upperJoystickKey,
                        size: 150,
                        label: 'Upper (5-8)',
                        color: const Color(0xFF9B59B6),
                        onPositionChanged: _onUpperJoystickChanged,
                        onReleased: _onUpperJoystickReleased,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Keyboard hint
                _buildKeyboardHint(),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right column: Gripper
          if (state.settings.gripper.enabled)
            SizedBox(
              width: 120,
              child: _buildGripperControlVertical(state),
            ),
        ],
      ),
    );
  }

  // Start/Stop control bar
  Widget _buildControlBar(dynamic state) {
    // Joystick only works with PWM mode (mode 2)
    final isPwmMode = state.settings.mode == 2;
    final isSending = state.sending && isPwmMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSending
              ? const Color(0xFF2ECC71).withValues(alpha: 0.5)
              : const Color(0xFF555555),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSending
                  ? const Color(0xFF2ECC71).withValues(alpha: 0.2)
                  : const Color(0xFF555555).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSending ? const Color(0xFF2ECC71) : Colors.grey,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isSending ? 'SENDING' : 'STOPPED',
                  style: TextStyle(
                    color: isSending ? const Color(0xFF2ECC71) : Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Start button
          SizedBox(
            height: 32,
            child: ElevatedButton.icon(
              onPressed: isSending
                  ? null
                  : () {
                      // Set mode to PWM (mode 2) when starting from joystick
                      widget.controller.setMode(2);
                      widget.controller.startSending();
                    },
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('Start', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF2ECC71).withValues(alpha: 0.3),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Stop button
          SizedBox(
            height: 32,
            child: ElevatedButton.icon(
              onPressed: isSending
                  ? () {
                      widget.controller.stopSending();
                      // Reset all PWM values to 0
                      _initTargets();
                    }
                  : null,
              icon: const Icon(Icons.stop, size: 16),
              label: const Text('Stop', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE74C3C),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE74C3C).withValues(alpha: 0.3),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPWMDisplay() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          const Text(
            'PWM Values',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Base chambers (1-4)
              _buildPWMGroup('Base', [0, 1, 2, 3], const Color(0xFF3498DB)),
              // Upper chambers (5-8)
              _buildPWMGroup('Upper', [4, 5, 6, 7], const Color(0xFF9B59B6)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPWMGroup(String label, List<int> indices, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: indices.map((i) {
            final value = _pwmValues[i];
            Color valueColor;
            if (value > 0) {
              valueColor = const Color(0xFF2ECC71);
            } else if (value < 0) {
              valueColor = const Color(0xFFE74C3C);
            } else {
              valueColor = Colors.grey;
            }
            return Container(
              width: 45,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                children: [
                  Text(
                    'Ch${i + 1}',
                    style: TextStyle(
                      color: color.withValues(alpha: 0.7),
                      fontSize: 9,
                    ),
                  ),
                  Text(
                    value.toStringAsFixed(0),
                    style: TextStyle(
                      color: valueColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGripperControl(dynamic state) {
    final maxAngle = state.settings.gripper.maxAngle.toDouble();
    final isConnected = state.gripperConnected;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isConnected
              ? const Color(0xFF2ECC71).withValues(alpha: 0.5)
              : const Color(0xFFE74C3C).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.pan_tool,
                size: 16,
                color: isConnected
                    ? const Color(0xFF2ECC71)
                    : const Color(0xFFE74C3C),
              ),
              const SizedBox(width: 6),
              Text(
                'Gripper',
                style: TextStyle(
                  color: isConnected
                      ? const Color(0xFF2ECC71)
                      : const Color(0xFFE74C3C),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildGripperButton('Close', const Color(0xFFE74C3C), () {
                setState(() {
                  _gripperOpen = false;
                  _gripperTarget = 0;
                  _gripperTextController.text = '0';
                });
                widget.controller.closeGripper();
              }),
              _buildGripperButton('Half', const Color(0xFF9B59B6), () {
                final half = (maxAngle / 2).round();
                setState(() {
                  _gripperTarget = half.toDouble();
                  _gripperTextController.text = half.toString();
                });
                widget.controller.halfGripper();
              }),
              _buildGripperButton('Open', const Color(0xFF2ECC71), () {
                setState(() {
                  _gripperOpen = true;
                  _gripperTarget = maxAngle;
                  _gripperTextController.text = maxAngle.toStringAsFixed(0);
                });
                widget.controller.openGripper();
              }),
            ],
          ),
        ],
      ),
    );
  }

  // Compact gripper control for portrait mode with state indicator
  Widget _buildGripperControlCompact(dynamic state) {
    final maxAngle = state.settings.gripper.maxAngle.toDouble();
    final isConnected = state.gripperConnected;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isConnected
              ? const Color(0xFF2ECC71).withValues(alpha: 0.5)
              : const Color(0xFFE74C3C).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Gripper status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _gripperOpen
                  ? const Color(0xFF2ECC71).withValues(alpha: 0.2)
                  : const Color(0xFFE74C3C).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.pan_tool,
                  size: 14,
                  color: isConnected
                      ? (_gripperOpen ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C))
                      : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  _gripperOpen ? 'OPEN' : 'CLOSED',
                  style: TextStyle(
                    color: _gripperOpen ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Quick buttons
          _buildGripperButtonSmall('Close', const Color(0xFFE74C3C), () {
            setState(() {
              _gripperOpen = false;
              _gripperTarget = 0;
              _gripperTextController.text = '0';
            });
            widget.controller.closeGripper();
          }),
          const SizedBox(width: 6),
          _buildGripperButtonSmall('Half', const Color(0xFF9B59B6), () {
            final half = (maxAngle / 2).round();
            setState(() {
              _gripperTarget = half.toDouble();
              _gripperTextController.text = half.toString();
            });
            widget.controller.halfGripper();
          }),
          const SizedBox(width: 6),
          _buildGripperButtonSmall('Open', const Color(0xFF2ECC71), () {
            setState(() {
              _gripperOpen = true;
              _gripperTarget = maxAngle;
              _gripperTextController.text = maxAngle.toStringAsFixed(0);
            });
            widget.controller.openGripper();
          }),
        ],
      ),
    );
  }

  Widget _buildGripperButtonSmall(String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      height: 28,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: Size.zero,
        ),
        child: Text(label, style: const TextStyle(fontSize: 10)),
      ),
    );
  }

  Widget _buildGripperControlVertical(dynamic state) {
    final maxAngle = state.settings.gripper.maxAngle.toDouble();
    final isConnected = state.gripperConnected;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isConnected
              ? const Color(0xFF2ECC71).withValues(alpha: 0.5)
              : const Color(0xFFE74C3C).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pan_tool,
            size: 24,
            color: isConnected
                ? const Color(0xFF2ECC71)
                : const Color(0xFFE74C3C),
          ),
          const SizedBox(height: 4),
          Text(
            'Gripper',
            style: TextStyle(
              color: isConnected
                  ? const Color(0xFF2ECC71)
                  : const Color(0xFFE74C3C),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          // Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _gripperOpen
                  ? const Color(0xFF2ECC71).withValues(alpha: 0.2)
                  : const Color(0xFFE74C3C).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _gripperOpen ? 'OPEN' : 'CLOSED',
              style: TextStyle(
                color: _gripperOpen ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildGripperButtonVertical('Open', const Color(0xFF2ECC71), () {
            setState(() {
              _gripperOpen = true;
              _gripperTarget = maxAngle;
              _gripperTextController.text = maxAngle.toStringAsFixed(0);
            });
            widget.controller.openGripper();
          }),
          const SizedBox(height: 8),
          _buildGripperButtonVertical('Half', const Color(0xFF9B59B6), () {
            final half = (maxAngle / 2).round();
            setState(() {
              _gripperTarget = half.toDouble();
              _gripperTextController.text = half.toString();
            });
            widget.controller.halfGripper();
          }),
          const SizedBox(height: 8),
          _buildGripperButtonVertical('Close', const Color(0xFFE74C3C), () {
            setState(() {
              _gripperOpen = false;
              _gripperTarget = 0;
              _gripperTextController.text = '0';
            });
            widget.controller.closeGripper();
          }),
          const SizedBox(height: 12),
          // Spacebar hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF555555)),
            ),
            child: const Text(
              'SPACE',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGripperButton(String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildGripperButtonVertical(String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildKeyboardHint() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.keyboard, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          const Text(
            'Base:',
            style: TextStyle(color: Colors.grey, fontSize: 10),
          ),
          _buildKeyChip('W', const Color(0xFF3498DB)),
          _buildKeyChip('A', const Color(0xFF3498DB)),
          _buildKeyChip('S', const Color(0xFF3498DB)),
          _buildKeyChip('D', const Color(0xFF3498DB)),
          const SizedBox(width: 8),
          const Text(
            'Upper:',
            style: TextStyle(color: Colors.grey, fontSize: 10),
          ),
          _buildKeyChip('I', const Color(0xFF9B59B6)),
          _buildKeyChip('J', const Color(0xFF9B59B6)),
          _buildKeyChip('K', const Color(0xFF9B59B6)),
          _buildKeyChip('L', const Color(0xFF9B59B6)),
          const SizedBox(width: 8),
          const Text(
            'Grip:',
            style: TextStyle(color: Colors.grey, fontSize: 10),
          ),
          _buildKeyChip('SPACE', const Color(0xFF2ECC71)),
        ],
      ),
    );
  }

  Widget _buildKeyChip(String key, Color color) {
    final isPressed = _isKeyPressed(key);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isPressed ? color : color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color,
          width: 1,
        ),
      ),
      child: Text(
        key,
        style: TextStyle(
          color: isPressed ? Colors.white : color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  bool _isKeyPressed(String key) {
    switch (key.toUpperCase()) {
      case 'W': return _pressedKeys.contains(LogicalKeyboardKey.keyW);
      case 'A': return _pressedKeys.contains(LogicalKeyboardKey.keyA);
      case 'S': return _pressedKeys.contains(LogicalKeyboardKey.keyS);
      case 'D': return _pressedKeys.contains(LogicalKeyboardKey.keyD);
      case 'I': return _pressedKeys.contains(LogicalKeyboardKey.keyI);
      case 'J': return _pressedKeys.contains(LogicalKeyboardKey.keyJ);
      case 'K': return _pressedKeys.contains(LogicalKeyboardKey.keyK);
      case 'L': return _pressedKeys.contains(LogicalKeyboardKey.keyL);
      case 'SPACE': return _pressedKeys.contains(LogicalKeyboardKey.space);
      default: return false;
    }
  }

  Widget _buildCameraPreview(int camId) {
    final frame = _latestFrames[camId];
    final status = _latestStatus[camId];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: const Color(0xFF1E1E1E),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: status?.isOnline ?? false
                      ? const Color(0xFF2ECC71)
                      : const Color(0xFFE74C3C),
                ),
                const SizedBox(width: 4),
                Text(
                  'Cam $camId',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
                const Spacer(),
                if (status != null)
                  Text(
                    '${status.fps.toStringAsFixed(0)} fps',
                    style: const TextStyle(color: Color(0xFF3498DB), fontSize: 10),
                  ),
              ],
            ),
          ),
          // Preview
          Expanded(
            child: Container(
              color: Colors.black,
              child: frame != null
                  ? Image.memory(
                      frame.jpegBytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    )
                  : Center(
                      child: Icon(
                        status?.error != null
                            ? Icons.error_outline
                            : Icons.videocam_off,
                        size: 32,
                        color: Colors.grey,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
