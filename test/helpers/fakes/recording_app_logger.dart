import 'package:mealvana_endurance/shared/services/logging_service.dart';

/// Recording logger that captures log events for assertions in tests.
class RecordingAppLogger implements AppLogger {
  final List<LogRecord> records = [];

  void _record(String level, String message,
      {String? context, Map<String, dynamic>? data, dynamic error, StackTrace? stackTrace}) {
    records.add(LogRecord(
      level: level,
      message: message,
      context: context,
      data: data,
      error: error,
      stackTrace: stackTrace,
    ));
  }

  @override
  void analytics(String message, {String? event, Map<String, dynamic>? properties}) =>
      _record('analytics', message, data: {
        if (event != null) 'event': event,
        if (properties != null) 'properties': properties,
      });

  @override
  void api(String message,
          {String? endpoint,
          int? statusCode,
          Map<String, dynamic>? requestData,
          Map<String, dynamic>? responseData,
          Duration? duration,
          dynamic error}) =>
      _record('api', message, data: {
        if (endpoint != null) 'endpoint': endpoint,
        if (statusCode != null) 'statusCode': statusCode,
        if (requestData != null) 'request': requestData,
        if (responseData != null) 'response': responseData,
        if (duration != null) 'durationMs': duration.inMilliseconds,
      }, error: error);

  @override
  void database(String message,
          {String? operation,
          String? table,
          Map<String, dynamic>? data,
          Duration? duration,
          dynamic error}) =>
      _record('database', message, data: {
        if (operation != null) 'operation': operation,
        if (table != null) 'table': table,
        if (data != null) ...data,
        if (duration != null) 'durationMs': duration.inMilliseconds,
      }, error: error);

  @override
  void debug(String message,
          {String? context,
          Map<String, dynamic>? data,
          dynamic error,
          StackTrace? stackTrace}) =>
      _record('debug', message, context: context, data: data, error: error, stackTrace: stackTrace);

  @override
  void error(String message,
          {String? context,
          Map<String, dynamic>? data,
          dynamic error,
          StackTrace? stackTrace}) =>
      _record('error', message, context: context, data: data, error: error, stackTrace: stackTrace);

  @override
  void fatal(String message,
          {String? context,
          Map<String, dynamic>? data,
          dynamic error,
          StackTrace? stackTrace}) =>
      _record('fatal', message, context: context, data: data, error: error, stackTrace: stackTrace);

  @override
  void info(String message, {String? context, Map<String, dynamic>? data}) =>
      _record('info', message, context: context, data: data);

  @override
  void navigation(String message,
          {String? from, String? to, Map<String, dynamic>? parameters}) =>
      _record('navigation', message, data: {
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        if (parameters != null) 'parameters': parameters,
      });

  @override
  void nutritionPlan(String message,
          {String? planId,
          String? phase,
          Map<String, dynamic>? data,
          dynamic error}) =>
      _record('nutritionPlan', message, data: {
        if (planId != null) 'planId': planId,
        if (phase != null) 'phase': phase,
        if (data != null) ...data,
      }, error: error);

  @override
  void userAction(String message,
          {String? action, String? screen, Map<String, dynamic>? data}) =>
      _record('userAction', message, data: {
        if (action != null) 'action': action,
        if (screen != null) 'screen': screen,
        if (data != null) ...data,
      });

  @override
  void warning(String message,
          {String? context,
          Map<String, dynamic>? data,
          dynamic error,
          StackTrace? stackTrace}) =>
      _record('warning', message, context: context, data: data, error: error, stackTrace: stackTrace);
}

class LogRecord {
  LogRecord({
    required this.level,
    required this.message,
    this.context,
    this.data,
    this.error,
    this.stackTrace,
  });

  final String level;
  final String message;
  final String? context;
  final Map<String, dynamic>? data;
  final dynamic error;
  final StackTrace? stackTrace;
}
