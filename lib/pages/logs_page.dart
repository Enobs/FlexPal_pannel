import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../core/state/controller.dart';
import '../core/utils/logger.dart';

/// Logs page - display real-time event logs
class LogsPage extends StatefulWidget {
  final AppController controller;

  const LogsPage({Key? key, required this.controller}) : super(key: key);

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text(
                  'System Logs',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () async {
                    await _exportLogs();
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Export CSV'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3498DB),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    widget.controller.logger.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF555555),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _autoScroll,
                  onChanged: (value) {
                    setState(() {
                      _autoScroll = value ?? true;
                    });
                  },
                ),
                const Text(
                  'Auto-scroll',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Log list
            Expanded(
              child: StreamBuilder<LogEntry>(
                stream: widget.controller.logger.stream,
                builder: (context, snapshot) {
                  final logs = widget.controller.logger.history;

                  if (_autoScroll && _scrollController.hasClients) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 100),
                        curve: Curves.easeOut,
                      );
                    });
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0A0A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF555555)),
                    ),
                    child: logs.isEmpty
                        ? const Center(
                            child: Text(
                              'No logs yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount: logs.length,
                            itemBuilder: (context, index) {
                              final log = logs[index];
                              return _buildLogEntry(log);
                            },
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogEntry(LogEntry log) {
    Color levelColor;
    switch (log.level) {
      case LogLevel.info:
        levelColor = const Color(0xFF3498DB);
        break;
      case LogLevel.warning:
        levelColor = const Color(0xFFE67E22);
        break;
      case LogLevel.error:
        levelColor = const Color(0xFFE74C3C);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF333333))),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          children: [
            TextSpan(
              text: log.timestamp.toIso8601String().substring(11, 23),
              style: const TextStyle(color: Colors.grey),
            ),
            const TextSpan(text: ' '),
            TextSpan(
              text: '[${log.levelStr}]',
              style: TextStyle(color: levelColor, fontWeight: FontWeight.bold),
            ),
            if (log.source != null) ...[
              const TextSpan(text: ' '),
              TextSpan(
                text: '[${log.source}]',
                style: const TextStyle(color: Color(0xFF9B59B6)),
              ),
            ],
            const TextSpan(text: ' '),
            TextSpan(
              text: log.message,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final file = File('${directory.path}/logs_$timestamp.csv');

      final buffer = StringBuffer();
      buffer.writeln('timestamp,level,source,message');

      for (final log in widget.controller.logger.history) {
        buffer.writeln('${log.timestamp.toIso8601String()},${log.levelStr},${log.source ?? ""},\"${log.message}\"');
      }

      await file.writeAsString(buffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logs exported to: ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export logs: $e')),
        );
      }
    }
  }
}
