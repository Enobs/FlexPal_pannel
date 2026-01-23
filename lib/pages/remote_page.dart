import 'package:flutter/material.dart';
import '../core/state/controller.dart';
import '../core/udp/packet_builder.dart';
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
          body: Column(
            children: [
              // Control panel
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mode switch
                      const Text(
                        'Control Mode',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ModeSwitch(
                        currentMode: mode,
                        onModeChanged: (newMode) {
                          final (newMin, newMax) = PacketBuilder.getDisplayRange(newMode);
                          setState(() {
                            _targets = List.filled(9, newMin);
                          });
                          widget.controller.setMode(newMode);
                        },
                      ),
                      const SizedBox(height: 16),
                      // Rate control
                      Row(
                        children: [
                          const Text(
                            'Send Rate:',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Slider(
                              value: _rateHz.toDouble(),
                              min: 10,
                              max: 50,
                              divisions: 40,
                              label: '$_rateHz Hz',
                              onChanged: (value) {
                                setState(() {
                                  _rateHz = value.toInt();
                                });
                                widget.controller.setRateHz(_rateHz);
                              },
                            ),
                          ),
                          Text(
                            '$_rateHz Hz',
                            style: const TextStyle(
                              color: Color(0xFF3498DB),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Control buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: state.sending
                                  ? null
                                  : () {
                                      // Update all targets before starting
                                      debugPrint('=== Start Sending - Setting Targets ===');
                                      for (int i = 0; i < 9; i++) {
                                        debugPrint('Chamber ${i + 1}: ${_targets[i]} $unit');
                                        widget.controller.setTarget(i, _targets[i]);
                                      }
                                      widget.controller.startSending();
                                    },
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Start Sending'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2ECC71),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: state.sending
                                  ? () => widget.controller.stopSending()
                                  : null,
                              icon: const Icon(Icons.stop),
                              label: const Text('Stop'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE74C3C),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _targets = List.filled(9, min);
                                });
                                widget.controller.setTargets(_targets);
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reset All'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF555555),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Sliders in compact 3x3 grid
                      const Text(
                        'Chamber Targets',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 2.5,
                            crossAxisSpacing: 8,
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
                        const SizedBox(height: 16),
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
        );
      },
    );
  }

  Widget _buildGripperControl(dynamic state) {
    final maxAngle = state.settings.gripper.maxAngle.toDouble();
    final isConnected = state.gripperConnected;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isConnected
              ? const Color(0xFF2ECC71).withOpacity(0.5)
              : const Color(0xFFE74C3C).withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Gripper Control',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isConnected
                          ? const Color(0xFF2ECC71).withOpacity(0.2)
                          : const Color(0xFFE74C3C).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isConnected ? 'Connected' : 'Offline',
                      style: TextStyle(
                        color: isConnected
                            ? const Color(0xFF2ECC71)
                            : const Color(0xFFE74C3C),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                '${_gripperTarget.toStringAsFixed(0)}° / ${maxAngle.toStringAsFixed(0)}°',
                style: const TextStyle(
                  color: Color(0xFF3498DB),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Slider
          Row(
            children: [
              const Text('0°', style: TextStyle(color: Colors.grey, fontSize: 11)),
              Expanded(
                child: Slider(
                  value: _gripperTarget.clamp(0.0, maxAngle).toDouble(),
                  min: 0,
                  max: maxAngle,
                  divisions: maxAngle.toInt(),
                  onChanged: (value) {
                    setState(() {
                      _gripperTarget = value;
                    });
                  },
                  onChangeEnd: (value) {
                    widget.controller.setGripperAngle(value);
                  },
                ),
              ),
              Text('${maxAngle.toStringAsFixed(0)}°',
                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          // Quick action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _gripperTarget = 0);
                    widget.controller.closeGripper();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE74C3C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _gripperTarget = maxAngle / 2);
                    widget.controller.halfGripper();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3498DB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Half'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _gripperTarget = maxAngle);
                    widget.controller.openGripper();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ],
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
