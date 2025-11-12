import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/state/controller.dart';
import '../core/models/parsed_packet.dart';

/// Monitor page - real-time charts for selected chamber
class MonitorPage extends StatefulWidget {
  final AppController controller;

  const MonitorPage({Key? key, required this.controller}) : super(key: key);

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  int _selectedChamber = 1;
  final List<ParsedPacket> _chamberHistory = [];
  final int _maxHistory = 200;
  bool _isPaused = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller.state,
      builder: (context, _) {
        final state = widget.controller.state;

        // Update history
        if (!_isPaused) {
          for (final packet in state.recentPackets) {
            if (packet.chamberId == _selectedChamber) {
              if (_chamberHistory.isEmpty || packet.timestamp != _chamberHistory.last.timestamp) {
                _chamberHistory.add(packet);
                if (_chamberHistory.length > _maxHistory) {
                  _chamberHistory.removeAt(0);
                }
              }
            }
          }
        }

        return Scaffold(
          backgroundColor: const Color(0xFF1E1E1E),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chamber selector
                Row(
                  children: [
                    const Text(
                      'Select Chamber:',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: _selectedChamber,
                      dropdownColor: const Color(0xFF2A2A2A),
                      style: const TextStyle(color: Colors.white),
                      items: List.generate(9, (i) => i + 1).map((id) {
                        return DropdownMenuItem(
                          value: id,
                          child: Text('Chamber $id'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedChamber = value;
                            _chamberHistory.clear();
                          });
                        }
                      },
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isPaused = !_isPaused;
                        });
                      },
                      icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                      label: Text(_isPaused ? 'Resume' : 'Pause'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3498DB),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _chamberHistory.clear();
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF555555),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Charts
                Expanded(
                  child: _chamberHistory.isEmpty
                      ? const Center(
                          child: Text(
                            'No data yet. Start receiving to see charts.',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        )
                      : ListView(
                          children: [
                            _buildChartCard('Length (mm)', Colors.blue, (p) => p.lengthMm),
                            _buildChartCard('Pressure (kPa)', Colors.orange, (p) => p.pressure),
                            _buildChartCard('Battery (%)', Colors.green, (p) => p.battery),
                            _buildMultiChartCard(
                              'Accelerometer',
                              {
                                'X': (p) => p.accelX,
                                'Y': (p) => p.accelY,
                                'Z': (p) => p.accelZ,
                              },
                              [Colors.red, Colors.green, Colors.blue],
                            ),
                            _buildMultiChartCard(
                              'Gyroscope',
                              {
                                'X': (p) => p.gyroX,
                                'Y': (p) => p.gyroY,
                                'Z': (p) => p.gyroZ,
                              },
                              [Colors.red, Colors.green, Colors.blue],
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChartCard(String title, Color color, double Function(ParsedPacket) getValue) {
    final spots = <FlSpot>[];
    for (int i = 0; i < _chamberHistory.length; i++) {
      spots.add(FlSpot(i.toDouble(), getValue(_chamberHistory[i])));
    }

    return Card(
      color: const Color(0xFF2A2A2A),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(color: Colors.white10, strokeWidth: 1);
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(1),
                            style: const TextStyle(color: Colors.grey, fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiChartCard(
    String title,
    Map<String, double Function(ParsedPacket)> series,
    List<Color> colors,
  ) {
    final lines = <LineChartBarData>[];
    int idx = 0;

    for (final entry in series.entries) {
      final spots = <FlSpot>[];
      for (int i = 0; i < _chamberHistory.length; i++) {
        spots.add(FlSpot(i.toDouble(), entry.value(_chamberHistory[i])));
      }

      lines.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        color: colors[idx % colors.length],
        barWidth: 2,
        dotData: const FlDotData(show: false),
      ));

      idx++;
    }

    return Card(
      color: const Color(0xFF2A2A2A),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                ...series.keys.toList().asMap().entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          color: colors[e.key % colors.length],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          e.value,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(color: Colors.white10, strokeWidth: 1);
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(1),
                            style: const TextStyle(color: Colors.grey, fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: lines,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
