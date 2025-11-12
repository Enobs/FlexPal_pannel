import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Slider tile with linked value input
class SliderTile extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final Function(double) onChanged;
  final int? divisions;

  const SliderTile({
    Key? key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
    this.divisions,
  }) : super(key: key);

  @override
  State<SliderTile> createState() => _SliderTileState();
}

class _SliderTileState extends State<SliderTile> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toStringAsFixed(2));
  }

  @override
  void didUpdateWidget(SliderTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && widget.value != oldWidget.value) {
      _controller.text = widget.value.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2A2A2A),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label and value input
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Color(0xFF3498DB), fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: const OutlineInputBorder(),
                      suffixText: widget.unit,
                      suffixStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                    ],
                    onTap: () {
                      _isEditing = true;
                    },
                    onSubmitted: (value) {
                      _isEditing = false;
                      final newValue = double.tryParse(value);
                      if (newValue != null) {
                        widget.onChanged(newValue.clamp(widget.min, widget.max));
                      }
                    },
                    onEditingComplete: () {
                      _isEditing = false;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Slider
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: const Color(0xFF3498DB),
                inactiveTrackColor: const Color(0xFF555555),
                thumbColor: const Color(0xFF3498DB),
                overlayColor: const Color(0xFF3498DB).withOpacity(0.2),
              ),
              child: Slider(
                value: widget.value.clamp(widget.min, widget.max),
                min: widget.min,
                max: widget.max,
                divisions: widget.divisions,
                onChanged: (value) {
                  widget.onChanged(value);
                  if (!_isEditing) {
                    _controller.text = value.toStringAsFixed(2);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
