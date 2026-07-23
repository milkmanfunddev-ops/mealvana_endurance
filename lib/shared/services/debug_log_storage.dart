import 'dart:collection';

/// In-memory log storage for debugging
/// Stores the last 500 log entries for display in debug screen
class DebugLogStorage {
  static final DebugLogStorage _instance = DebugLogStorage._internal();
  factory DebugLogStorage() => _instance;
  DebugLogStorage._internal();

  final _logs = Queue<DebugLogEntry>();
  static const _maxLogs = 500;

  /// Add a log entry
  void addLog(DebugLogEntry entry) {
    _logs.add(entry);
    if (_logs.length > _maxLogs) {
      _logs.removeFirst();
    }
  }

  /// Get all logs (most recent first)
  List<DebugLogEntry> getLogs() {
    return _logs.toList().reversed.toList();
  }

  /// Clear all logs
  void clear() {
    _logs.clear();
  }

  /// Get logs filtered by level
  List<DebugLogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((log) => log.level == level).toList().reversed.toList();
  }

  /// Get logs filtered by context
  List<DebugLogEntry> getLogsByContext(String context) {
    return _logs
        .where((log) => log.context?.contains(context) ?? false)
        .toList()
        .reversed
        .toList();
  }
}

/// Log entry for debug display
class DebugLogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? context;
  final Map<String, dynamic>? data;
  final Object? error;

  DebugLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.context,
    this.data,
    this.error,
  });

  String get levelEmoji {
    switch (level) {
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return '💡';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.fatal:
        return '💥';
    }
  }

  String get timeString {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }
}

enum LogLevel { debug, info, warning, error, fatal }
