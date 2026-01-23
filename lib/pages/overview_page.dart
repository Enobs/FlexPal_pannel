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
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // System summary - compact row
            ListenableBuilder(
              listenable: controller.state,
              builder: (context, _) => _buildSummaryCard(controller.state),
            ),
            const SizedBox(height: 8),
            // Chamber grid - static title
            const Text(
              'Chambers',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            // Grid with individual chamber updates
            Expanded(
              child: ListenableBuilder(
                listenable: controller.state,
                builder: (context, _) {
                  final state = controller.state;
                  return GridView.builder(
                    physics: const ClampingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.8,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          _buildSummaryChip(
            '${state.onlineChamberCount}/9',
            state.onlineChamberCount == 9 ? const Color(0xFF2ECC71) : const Color(0xFFE67E22),
          ),
          const SizedBox(width: 8),
          _buildSummaryChip(
            _getModeName(state.settings.mode),
            const Color(0xFF3498DB),
          ),
          const SizedBox(width: 8),
          _buildSummaryChip(
            '${state.settings.sendRateHz}Hz',
            const Color(0xFF9B59B6),
          ),
          const SizedBox(width: 8),
          _buildSummaryChip(
            state.sending ? 'SEND' : (state.udpRunning ? 'READY' : 'STOP'),
            state.sending ? const Color(0xFF2ECC71) : const Color(0xFF555555),
          ),
          const SizedBox(width: 8),
          _buildSummaryChip(
            state.recording ? 'REC' : 'IDLE',
            state.recording ? const Color(0xFFE74C3C) : const Color(0xFF555555),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
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
