import 'package:flutter/material.dart';

/// Recording control toolbar
class RecordToolbar extends StatefulWidget {
  final bool isRecording;
  final Function(String episodeName, String? notes) onStart;
  final VoidCallback onStop;

  const RecordToolbar({
    Key? key,
    required this.isRecording,
    required this.onStart,
    required this.onStop,
  }) : super(key: key);

  @override
  State<RecordToolbar> createState() => _RecordToolbarState();
}

class _RecordToolbarState extends State<RecordToolbar> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A2A),
        border: Border(top: BorderSide(color: Color(0xFF555555))),
      ),
      child: widget.isRecording ? _buildRecordingView() : _buildIdleView(),
    );
  }

  Widget _buildIdleView() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Episode Name',
              labelStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: TextField(
            controller: _notesController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              labelStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter episode name')),
              );
              return;
            }

            widget.onStart(name, _notesController.text.trim().isEmpty ? null : _notesController.text.trim());
          },
          icon: const Icon(Icons.fiber_manual_record),
          label: const Text('Start Recording'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE74C3C),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingView() {
    return Row(
      children: [
        const Icon(Icons.fiber_manual_record, color: Color(0xFFE74C3C), size: 24),
        const SizedBox(width: 12),
        const Text(
          'RECORDING',
          style: TextStyle(
            color: Color(0xFFE74C3C),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: widget.onStop,
          icon: const Icon(Icons.stop),
          label: const Text('Stop Recording'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF555555),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
      ],
    );
  }
}
