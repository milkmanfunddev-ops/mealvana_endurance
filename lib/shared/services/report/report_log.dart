import 'dart:collection';

/// The last 500 lines `Report` mirrored, for the dev debug screen. Every
/// fault, degraded, note, info and debug call lands here; nothing writes to
/// it but `Report`.
class ReportLog {
  static final ReportLog _instance = ReportLog._internal();
  factory ReportLog() => _instance;
  ReportLog._internal();

  final _logs = Queue<ReportLogEntry>();
  static const _maxLogs = 500;

  /// Add a log entry
  void addLog(ReportLogEntry entry) {
    _logs.add(entry);
    if (_logs.length > _maxLogs) {
      _logs.removeFirst();
    }
  }

  /// Get all logs (most recent first)
  List<ReportLogEntry> getLogs() {
    return _logs.toList().reversed.toList();
  }

  /// Clear all logs
  void clear() {
    _logs.clear();
  }

  /// Get logs filtered by level
  List<ReportLogEntry> getLogsByLevel(ReportLogLevel level) {
    return _logs.where((log) => log.level == level).toList().reversed.toList();
  }

  /// Get logs filtered by context
  List<ReportLogEntry> getLogsByContext(String context) {
    return _logs
        .where((log) => log.context?.contains(context) ?? false)
        .toList()
        .reversed
        .toList();
  }
}

/// Log entry for debug display
class ReportLogEntry {
  final DateTime timestamp;
  final ReportLogLevel level;
  final String message;
  final String? context;
  final Map<String, dynamic>? data;
  final Object? error;

  ReportLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.context,
    this.data,
    this.error,
  });

  String get levelEmoji {
    switch (level) {
      case ReportLogLevel.debug:
        return '🔍';
      case ReportLogLevel.info:
        return '💡';
      case ReportLogLevel.warning:
        return '⚠️';
      case ReportLogLevel.error:
        return '❌';
      case ReportLogLevel.fatal:
        return '💥';
    }
  }

  String get timeString {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }
}

enum ReportLogLevel { debug, info, warning, error, fatal }
