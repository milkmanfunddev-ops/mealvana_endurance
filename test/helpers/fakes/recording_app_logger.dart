/// Recording app logger for testing
/// Captures all log calls for verification in tests
library;

import 'package:mealvana_endurance/shared/services/logging_service.dart';

/// Log record
class LogRecord {
  const LogRecord({
    required this.level,
    required this.message,
    this.context,
    this.data,
    this.error,
    this.stackTrace,
    this.endpoint,
    this.statusCode,
    this.requestData,
    this.responseData,
    this.duration,
    this.operation,
    this.table,
    this.from,
    this.to,
    this.parameters,
    this.action,
    this.screen,
    this.planId,
    this.phase,
    this.event,
    this.properties,
  });

  final String level;
  final String message;
  final String? context;
  final Map<String, dynamic>? data;
  final dynamic error;
  final StackTrace? stackTrace;
  final String? endpoint;
  final int? statusCode;
  final Map<String, dynamic>? requestData;
  final Map<String, dynamic>? responseData;
  final Duration? duration;
  final String? operation;
  final String? table;
  final String? from;
  final String? to;
  final Map<String, dynamic>? parameters;
  final String? action;
  final String? screen;
  final String? planId;
  final String? phase;
  final String? event;
  final Map<String, dynamic>? properties;

  @override
  String toString() => 'LogRecord($level: $message, context: $context)';
}

/// Recording implementation of AppLogger for testing
class RecordingAppLogger implements AppLogger {
  final List<LogRecord> records = [];

  @override
  void debug(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    records.add(
      LogRecord(
        level: 'debug',
        message: message,
        context: context,
        data: data,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  @override
  void info(String message, {String? context, Map<String, dynamic>? data}) {
    records.add(
      LogRecord(level: 'info', message: message, context: context, data: data),
    );
  }

  @override
  void warning(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    records.add(
      LogRecord(
        level: 'warning',
        message: message,
        context: context,
        data: data,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  @override
  void error(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    records.add(
      LogRecord(
        level: 'error',
        message: message,
        context: context,
        data: data,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  @override
  void fatal(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    records.add(
      LogRecord(
        level: 'fatal',
        message: message,
        context: context,
        data: data,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  @override
  void api(
    String message, {
    String? endpoint,
    int? statusCode,
    Map<String, dynamic>? requestData,
    Map<String, dynamic>? responseData,
    Duration? duration,
    dynamic error,
  }) {
    records.add(
      LogRecord(
        level: 'api',
        message: message,
        endpoint: endpoint,
        statusCode: statusCode,
        requestData: requestData,
        responseData: responseData,
        duration: duration,
        error: error,
      ),
    );
  }

  @override
  void database(
    String message, {
    String? operation,
    String? table,
    Map<String, dynamic>? data,
    Duration? duration,
    dynamic error,
  }) {
    records.add(
      LogRecord(
        level: 'database',
        message: message,
        operation: operation,
        table: table,
        data: data,
        duration: duration,
        error: error,
      ),
    );
  }

  @override
  void navigation(
    String message, {
    String? from,
    String? to,
    Map<String, dynamic>? parameters,
  }) {
    records.add(
      LogRecord(
        level: 'navigation',
        message: message,
        from: from,
        to: to,
        parameters: parameters,
      ),
    );
  }

  @override
  void userAction(
    String message, {
    String? action,
    String? screen,
    Map<String, dynamic>? data,
  }) {
    records.add(
      LogRecord(
        level: 'user_action',
        message: message,
        action: action,
        screen: screen,
        data: data,
      ),
    );
  }

  @override
  void nutritionPlan(
    String message, {
    String? planId,
    String? phase,
    Map<String, dynamic>? data,
    dynamic error,
  }) {
    records.add(
      LogRecord(
        level: 'nutrition_plan',
        message: message,
        planId: planId,
        phase: phase,
        data: data,
        error: error,
      ),
    );
  }

  @override
  void analytics(
    String message, {
    String? event,
    Map<String, dynamic>? properties,
  }) {
    records.add(
      LogRecord(
        level: 'analytics',
        message: message,
        event: event,
        properties: properties,
      ),
    );
  }

  // Test helpers
  LogRecord? get lastRecord => records.isNotEmpty ? records.last : null;

  /// Find records by level
  List<LogRecord> findByLevel(String level) {
    return records.where((r) => r.level == level).toList();
  }

  /// Find records by context
  List<LogRecord> findByContext(String context) {
    return records.where((r) => r.context == context).toList();
  }

  /// Check if any error was logged
  bool get hasErrors =>
      records.any((r) => r.level == 'error' || r.level == 'fatal');

  /// Get all error messages
  List<String> get errorMessages => records
      .where((r) => r.level == 'error' || r.level == 'fatal')
      .map((r) => r.message)
      .toList();

  /// Clear all recorded data (for test cleanup)
  void clear() {
    records.clear();
  }
}
