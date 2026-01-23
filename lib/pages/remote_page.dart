import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/state/controller.dart';
import '../core/udp/packet_builder.dart';
import '../core/camera/camera_frame.dart';
import '../widgets/mode_switch.dart';
import '../widgets/record_toolbar.dart';

/// Remote Control page - control 9 chambers with sliders
class RemotePage extends StatefulWidget {
  final AppController controller;

  const RemotePage({Key? key, required this.controller}) : super(key: key);

  @override
  State<RemotePage> createState() => _RemotePageState();
}

class _RemotePageState extends State<RemotePage> {
  List<double> _targets = List.filled(9, 0.0);
  int _rateHz = 25;
  double _gripperTarget = 0;

  // Camera state
  final Map<int, CameraFrame?> _latestFrames = {};
  final Map<int, CameraStatus?> _latestStatus = {};
  StreamSubscription? _frameSubscription;
  StreamSubscription? _statusSubscription;
  bool _isCameraRunning = false;

  // Gripper text controller
  final TextEditingController _gripperTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _rateHz = widget.controller.state.settings.sendRateHz;

    // Initialize targets to the minimum value of the current mode's range
    final mode = widget.controller.state.settings.mode;
    final (min, max) = PacketBuilder.getDisplayRange(mode);
    _targets = List.filled(9, min);

    // Initialize gripper target
    _gripperTarget = widget.controller.state.gripperAngle;
    _gripperTextController.text = _gripperTarget.toStringAsFixed(0);

    // Auto-start camera preview
    _startCamera();
  }

  @override
  void dispose() {
    _stopCamera();
    _gripperTextController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller.state,
      builder: (context, _) {
        final state = widget.controller.state;
        final mode = state.settings.mode;
        final (min, max) = PacketBuilder.getDisplayRange(mode);
        final unit = PacketBuilder.getUnit(mode);

        return Scaffold(
          backgroundColor: const Color(0xFF1E1E1E),
          body: Row(
            children: [
              // Left side: Camera views
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      // Camera 0
                      Expanded(
                        child: _buildCameraPreview(0),
                      ),
                      const SizedBox(height: 8),
                      // Camera 1
                      Expanded(
                        child: _buildCameraPreview(1),
                      ),
                    ],
                  ),
                ),
              ),
              // Right side: Controls
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Mode switch row
                            Row(
                              children: [
                                const Text(
                                  'Mode:',
                                  style: TextStyle(color: Colors.white, fontSize: 14),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ModeSwitch(
                                    currentMode: mode,
                                    onModeChanged: (newMode) {
                                      final (newMin, newMax) = PacketBuilder.getDisplayRange(newMode);
                                      setState(() {
                                        _targets = List.filled(9, newMin);
                                      });
                                      widget.controller.setMode(newMode);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Rate control - compact
                            Row(
                              children: [
                                const Text(
                                  'Rate:',
                                  style: TextStyle(color: Colors.white, fontSize: 14),
                                ),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 2,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    ),
                                    child: Slider(
                                      value: _rateHz.toDouble(),
                                      min: 10,
                                      max: 50,
                                      divisions: 40,
                                      onChanged: (value) {
                                        setState(() {
                                          _rateHz = value.toInt();
                                        });
                                        widget.controller.setRateHz(_rateHz);
                                      },
                                    ),
                                  ),
                                ),
                                Text(
                                  '$_rateHz Hz',
                                  style: const TextStyle(
                                    color: Color(0xFF3498DB),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Control buttons - smaller
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 36,
                                    child: ElevatedButton.icon(
                                      onPressed: state.sending
                                          ? null
                                          : () {
                                              for (int i = 0; i < 9; i++) {
                                                widget.controller.setTarget(i, _targets[i]);
                                              }
                                              widget.controller.startSending();
                                            },
                                      icon: const Icon(Icons.play_arrow, size: 16),
                                      label: const Text('Start', style: TextStyle(fontSize: 12)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2ECC71),
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SizedBox(
                                    height: 36,
                                    child: ElevatedButton.icon(
                                      onPressed: state.sending
                                          ? () => widget.controller.stopSending()
                                          : null,
                                      icon: const Icon(Icons.stop, size: 16),
                                      label: const Text('Stop', style: TextStyle(fontSize: 12)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFE74C3C),
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SizedBox(
                                    height: 36,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _targets = List.filled(9, min);
                                        });
                                        widget.controller.setTargets(_targets);
                                      },
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text('Reset', style: TextStyle(fontSize: 12)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF555555),
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Chamber Targets label
                            const Text(
                              'Chamber Targets',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Sliders in compact 3x3 grid
                            Expanded(
                              child: GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 2.2,
                                  crossAxisSpacing: 6,
                                  mainAxisSpacing: 4,
                                ),
                                itemCount: 9,
                                physics: const NeverScrollableScrollPhysics(),
                                itemBuilder: (context, index) {
                                  return _buildCompactSlider(
                                    index: index,
                                    value: _targets[index],
                                    min: min,
                                    max: max,
                                    unit: unit,
                                    sending: state.sending,
                                  );
                                },
                              ),
                            ),
                            // Gripper control section
                            if (state.settings.gripper.enabled) ...[
                              const SizedBox(height: 8),
                              _buildGripperControl(state),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // Recording toolbar
                    RecordToolbar(
                      isRecording: state.recording,
                      onStart: (episodeName, notes) async {
                        try {
                          await widget.controller.startRecording(episodeName, notes: notes);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Started recording: $episodeName')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to start recording: $e')),
                            );
                          }
                        }
                      },
                      onStop: () async {
                        await widget.controller.stopRecording();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Recording stopped')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
      child: Row(
        children: [
          // Gripper label with status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isConnected
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
                      ? const Color(0xFF2ECC71)
                      : const Color(0xFFE74C3C),
                ),
                const SizedBox(width: 4),
                Text(
                  'Gripper',
                  style: TextStyle(
                    color: isConnected
                        ? const Color(0xFF2ECC71)
                        : const Color(0xFFE74C3C),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Text input for angle
          SizedBox(
            width: 60,
            height: 32,
            child: TextField(
              controller: _gripperTextController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFF555555)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFF555555)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFF3498DB)),
                ),
                suffixText: '°',
                suffixStyle: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              onSubmitted: (value) {
                _applyGripperAngle(maxAngle);
              },
            ),
          ),
          const SizedBox(width: 4),
          // Set button
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: () => _applyGripperAngle(maxAngle),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3498DB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
              ),
              child: const Text('Set', style: TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(width: 8),
          // Quick action buttons
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _gripperTarget = 0;
                  _gripperTextController.text = '0';
                });
                widget.controller.closeGripper();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE74C3C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
              ),
              child: const Text('Close', style: TextStyle(fontSize: 11)),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: () {
                final half = (maxAngle / 2).round();
                setState(() {
                  _gripperTarget = half.toDouble();
                  _gripperTextController.text = half.toString();
                });
                widget.controller.halfGripper();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B59B6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
              ),
              child: const Text('Half', style: TextStyle(fontSize: 11)),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _gripperTarget = maxAngle;
                  _gripperTextController.text = maxAngle.toStringAsFixed(0);
                });
                widget.controller.openGripper();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
              ),
              child: const Text('Open', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  void _applyGripperAngle(double maxAngle) {
    final text = _gripperTextController.text;
    if (text.isEmpty) return;

    double value = double.tryParse(text) ?? 0;
    // Clamp to valid range
    value = value.clamp(0, maxAngle);

    setState(() {
      _gripperTarget = value;
      _gripperTextController.text = value.toStringAsFixed(0);
    });
    widget.controller.setGripperAngle(value);
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
          // Header - compact
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

  Widget _buildCompactSlider({
    required int index,
    required double value,
    required double min,
    required double max,
    required String unit,
    required bool sending,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF3498DB).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Chamber number and value
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ch${index + 1}',
                style: const TextStyle(
                  color: Color(0xFF3498DB),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${value.toStringAsFixed(0)} $unit',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          // Slider
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: const Color(0xFF3498DB),
                inactiveTrackColor: const Color(0xFF555555),
                thumbColor: const Color(0xFF3498DB),
                overlayColor: const Color(0xFF3498DB).withOpacity(0.2),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: (newValue) {
                  setState(() {
                    _targets[index] = newValue;
                  });
                  if (sending) {
                    widget.controller.setTarget(index, newValue);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
