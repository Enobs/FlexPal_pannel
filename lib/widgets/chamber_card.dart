import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../core/state/app_state.dart';

/// Modern chamber status card with glassmorphism design
class ChamberCard extends StatefulWidget {
  final ChamberState chamber;

  const ChamberCard({Key? key, required this.chamber}) : super(key: key);

  @override
  State<ChamberCard> createState() => _ChamberCardState();
}

class _ChamberCardState extends State<ChamberCard> with SingleTickerProviderStateMixin {
  late bool _wasOnline;

  @override
  void initState() {
    super.initState();
    _wasOnline = widget.chamber.isOnline;
  }

  @override
  void didUpdateWidget(ChamberCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only trigger rebuild if online status actually changed
    if (oldWidget.chamber.isOnline != widget.chamber.isOnline) {
      _wasOnline = widget.chamber.isOnline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = widget.chamber.isOnline;
    final packet = widget.chamber.lastPacket;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2A2A2A),
            const Color(0xFF1E1E1E),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline ? const Color(0xFF2ECC71).withOpacity(0.3) : const Color(0xFF555555).withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isOnline ? const Color(0xFF2ECC71).withOpacity(0.1) : Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with chamber icon and status
                  Row(
                    children: [
                      // Chamber icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isOnline ? const Color(0xFF2ECC71).withOpacity(0.15) : const Color(0xFF555555).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: FaIcon(
                          FontAwesomeIcons.microchip,
                          color: isOnline ? const Color(0xFF2ECC71) : const Color(0xFF888888),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Chamber number
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chamber ${widget.chamber.id}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'CH-00${widget.chamber.id}',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status indicator
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isOnline ? const Color(0xFF2ECC71).withOpacity(0.2) : const Color(0xFFE74C3C).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isOnline ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isOnline ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: isOnline ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isOnline ? 'ONLINE' : 'OFFLINE',
                              style: TextStyle(
                                color: isOnline ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF333333), height: 1),
                  const SizedBox(height: 16),

                  // Data metrics
                  if (packet != null) ...[
                    _buildMetric(
                      icon: FontAwesomeIcons.arrowsUpDown,
                      label: 'Length',
                      value: '${packet.lengthMm.toStringAsFixed(1)} mm',
                      color: const Color(0xFF3498DB),
                    ),
                    const SizedBox(height: 10),
                    _buildMetric(
                      icon: FontAwesomeIcons.gaugeHigh,
                      label: 'Pressure',
                      value: '${packet.pressure.toStringAsFixed(1)} kPa',
                      color: const Color(0xFFE67E22),
                    ),
                    const SizedBox(height: 10),
                    _buildMetric(
                      icon: FontAwesomeIcons.batteryHalf,
                      label: 'Battery',
                      value: '${packet.battery.toStringAsFixed(0)}%',
                      color: _getBatteryColor(packet.battery),
                    ),
                  ] else ...[
                    Center(
                      child: Column(
                        children: [
                          FaIcon(
                            FontAwesomeIcons.circleExclamation,
                            color: Colors.grey[600],
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No data',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: FaIcon(
            icon,
            color: color,
            size: 14,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ],
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
