import 'package:flutter/material.dart';
import '../core/state/app_state.dart';

/// Compact chamber status card
class ChamberCard extends StatelessWidget {
  final ChamberState chamber;

  const ChamberCard({Key? key, required this.chamber}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isOnline = chamber.isOnline;
    final packet = chamber.lastPacket;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isOnline
              ? const Color(0xFF2ECC71).withValues(alpha: 0.4)
              : const Color(0xFF555555).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: Chamber number + status dot
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isOnline ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Ch${chamber.id}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                isOnline ? 'ON' : 'OFF',
                style: TextStyle(
                  color: isOnline ? const Color(0xFF2ECC71) : const Color(0xFF888888),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Metrics - compact
          if (packet != null) ...[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMetricRow('L', '${packet.lengthMm.toStringAsFixed(1)}mm', const Color(0xFF3498DB)),
                  _buildMetricRow('P', '${packet.pressure.toStringAsFixed(0)}kPa', const Color(0xFFE67E22)),
                  _buildMetricRow('B', '${packet.battery.toStringAsFixed(0)}%', _getBatteryColor(packet.battery)),
                ],
              ),
            ),
          ] else ...[
            Expanded(
              child: Center(
                child: Text(
                  'No data',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Color _getBatteryColor(double battery) {
    if (battery > 60) return const Color(0xFF2ECC71);
    if (battery > 30) return const Color(0xFFE67E22);
    return const Color(0xFFE74C3C);
  }
}
