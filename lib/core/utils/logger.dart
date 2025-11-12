import 'dart:async';

/// Simple logger with levels
enum LogLevel { info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? source;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.source,
  });

  String get levelStr {
    switch (level) {
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  @override
  String toString() {
    final timeStr = timestamp.toIso8601String().substring(11, 23);
    final sourceStr = source != null ? '[$source] ' : '';
    return '[$timeStr] [$levelStr] $sourceStr$message';
  }
}

class Logger {
  final _controller = StreamController<LogEntry>.broadcast();
  final List<LogEntry> _history = [];
  final int _maxHistory = 1000;

  Stream<LogEntry> get stream => _controller.stream;
  List<LogEntry> get history => List.unmodifiable(_history);

  void info(String message, {String? source}) {
    _add(LogLevel.info, message, source);
  }

  void warning(String message, {String? source}) {
    _add(LogLevel.warning, message, source);
  }

  void error(String message, {String? source}) {
    _add(LogLevel.error, message, source);
  }

  void _add(LogLevel level, String message, String? source) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      source: source,
    );

    _history.add(entry);
    if (_history.length > _maxHistory) {
      _history.removeAt(0);
    }

    _controller.add(entry);
  }

  void clear() {
    _history.clear();
  }

  void dispose() {
    _controller.close();
  }
}
