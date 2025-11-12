import 'package:flutter/material.dart';
import '../core/state/controller.dart';
import '../core/udp/packet_builder.dart';
import '../widgets/mode_switch.dart';
import '../widgets/slider_tile.dart';
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

  @override
  void initState() {
    super.initState();
    _rateHz = widget.controller.state.settings.sendRateHz;
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
                          setState(() {
                            _targets = List.filled(9, 0.0);
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
                                  _targets = List.filled(9, 0.0);
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
                      const SizedBox(height: 16),
                      // Sliders
                      const Text(
                        'Chamber Targets',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: 9,
                          itemBuilder: (context, index) {
                            return SliderTile(
                              label: 'Chamber ${index + 1}',
                              value: _targets[index],
                              min: min,
                              max: max,
                              unit: unit,
                              onChanged: (value) {
                                setState(() {
                                  _targets[index] = value;
                                });
                                if (state.sending) {
                                  widget.controller.setTarget(index, value);
                                }
                              },
                            );
                          },
                        ),
                      ),
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
}
