import 'package:flutter/material.dart';
import '../core/state/app_state.dart';
import '../core/state/controller.dart';
import '../widgets/chamber_card.dart';

/// Overview page - shows system summary and chamber status
class OverviewPage extends StatelessWidget {
  final AppController controller;

  const OverviewPage({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // System summary - only rebuild this when state changes
            ListenableBuilder(
              listenable: controller.state,
              builder: (context, _) => _buildSummaryCard(controller.state),
            ),
            const SizedBox(height: 16),
            // Chamber grid - static title
            const Text(
              'Chamber Status',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            // Grid with individual chamber updates
            Expanded(
              child: ListenableBuilder(
                listenable: controller.state,
                builder: (context, _) {
                  final state = controller.state;
                  return GridView.builder(
                    physics: const ClampingScrollPhysics(), // Smooth scrolling without bounce
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.5,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: 9,
                    itemBuilder: (context, index) {
                      final chamber = state.chambers[index + 1]!;
                      return ChamberCard(
                        key: ValueKey('chamber_${chamber.id}'),
                        chamber: chamber,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(AppState state) {
    return Card(
      color: const Color(0xFF2A2A2A),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: _buildSummaryItem(
                'Online Chambers',
                '${state.onlineChamberCount} / 9',
                state.onlineChamberCount == 9 ? const Color(0xFF2ECC71) : const Color(0xFFE67E22),
              ),
            ),
            Expanded(
              child: _buildSummaryItem(
                'Mode',
                _getModeName(state.settings.mode),
                const Color(0xFF3498DB),
              ),
            ),
            Expanded(
              child: _buildSummaryItem(
                'Send Rate',
                '${state.settings.sendRateHz} Hz',
                const Color(0xFF3498DB),
              ),
            ),
            Expanded(
              child: _buildSummaryItem(
                'Status',
                state.sending ? 'SENDING' : (state.udpRunning ? 'READY' : 'STOPPED'),
                state.sending ? const Color(0xFF2ECC71) : const Color(0xFF555555),
              ),
            ),
            Expanded(
              child: _buildSummaryItem(
                'Recording',
                state.recording ? 'REC' : 'IDLE',
                state.recording ? const Color(0xFFE74C3C) : const Color(0xFF555555),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _getModeName(int mode) {
    switch (mode) {
      case 1:
        return 'Pressure';
      case 2:
        return 'PWM';
      case 3:
        return 'Length';
      default:
        return 'Unknown';
    }
  }
}
