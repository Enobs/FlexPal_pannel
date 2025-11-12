import 'package:flutter/material.dart';

/// Mode switch widget (Pressure / PWM / Length)
class ModeSwitch extends StatelessWidget {
  final int currentMode;
  final Function(int) onModeChanged;

  const ModeSwitch({
    Key? key,
    required this.currentMode,
    required this.onModeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildModeButton(1, 'Pressure'),
        const SizedBox(width: 8),
        _buildModeButton(2, 'PWM'),
        const SizedBox(width: 8),
        _buildModeButton(3, 'Length'),
      ],
    );
  }

  Widget _buildModeButton(int mode, String label) {
    final isSelected = currentMode == mode;

    return Expanded(
      child: ElevatedButton(
        onPressed: () => onModeChanged(mode),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? const Color(0xFF3498DB) : const Color(0xFF2A2A2A),
          foregroundColor: Colors.white,
          elevation: isSelected ? 8 : 2,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
