import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'debug_log_storage.dart';

/// Abstraction for logging so we can swap implementations in tests.
abstract class AppLogger {
  void debug(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  });

  void info(
    String message, {
    String? context,
    Map<String, dynamic>? data,
  });

  void warning(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  });

  void error(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  });

  void fatal(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  });

  void api(
    String message, {
    String? endpoint,
    int? statusCode,
    Map<String, dynamic>? requestData,
    Map<String, dynamic>? responseData,
    Duration? duration,
    dynamic error,
  });

  void database(
    String message, {
    String? operation,
    String? table,
    Map<String, dynamic>? data,
    Duration? duration,
    dynamic error,
  });

  void navigation(
    String message, {
    String? from,
    String? to,
    Map<String, dynamic>? parameters,
  });

  void userAction(
    String message, {
    String? action,
    String? screen,
    Map<String, dynamic>? data,
  });

  void nutritionPlan(
    String message, {
    String? planId,
    String? phase,
    Map<String, dynamic>? data,
    dynamic error,
  });

  void analytics(
    String message, {
    String? event,
    Map<String, dynamic>? properties,
  });
}

/// Default logger backed by package:logger with structured helpers.
class PrettyAppLogger implements AppLogger {
  PrettyAppLogger({
    Level? baseLevel,
    bool enableFileOutput = false,
    Logger? logger,
  })  : _logger = logger ??
            Logger(
              level: _resolveLevel(baseLevel),
              printer: PrettyPrinter(
                methodCount: 2,
                errorMethodCount: 8,
                lineLength: 120,
                colors: true,
                printEmojis: true,
                dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
              ),
              filter: ProductionLogFilter(),
            ),
        _enableFileOutput = enableFileOutput;

  final Logger _logger;
  final bool _enableFileOutput;

  static Level _resolveLevel(Level? baseLevel) {
    if (kDebugMode) {
      return baseLevel ?? Level.debug;
    }
    return baseLevel != null && baseLevel.index > Level.info.index
        ? baseLevel
        : Level.info;
  }

  @override
  void debug(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _logWithContext(
      Level.debug,
      message,
      context: context,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void info(
    String message, {
    String? context,
    Map<String, dynamic>? data,
  }) {
    _logWithContext(
      Level.info,
      message,
      context: context,
      data: data,
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
    _logWithContext(
      Level.warning,
      message,
      context: context,
      data: data,
      error: error,
      stackTrace: stackTrace,
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
    _logWithContext(
      Level.error,
      message,
      context: context,
      data: data,
      error: error,
      stackTrace: stackTrace,
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
    _logWithContext(
      Level.fatal,
      message,
      context: context,
      data: data,
      error: error,
      stackTrace: stackTrace,
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
    final data = <String, dynamic>{};
    if (endpoint != null) data['endpoint'] = endpoint;
    if (statusCode != null) data['status_code'] = statusCode;
    if (requestData != null) data['request'] = requestData;
    if (responseData != null) data['response'] = responseData;
    if (duration != null) data['duration_ms'] = duration.inMilliseconds;

    if (error != null) {
      this.error(
        message,
        context: 'API',
        data: data,
        error: error,
      );
    } else if (statusCode != null && statusCode >= 400) {
      warning(message, context: 'API', data: data);
    } else {
      debug(message, context: 'API', data: data);
    }
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
    final logData = <String, dynamic>{};
    if (operation != null) logData['operation'] = operation;
    if (table != null) logData['table'] = table;
    if (data != null) logData['data'] = data;
    if (duration != null) logData['duration_ms'] = duration.inMilliseconds;

    if (error != null) {
      this.error(
        message,
        context: 'DATABASE',
        data: logData,
        error: error,
      );
    } else {
      debug(message, context: 'DATABASE', data: logData);
    }
  }

  @override
  void navigation(
    String message, {
    String? from,
    String? to,
    Map<String, dynamic>? parameters,
  }) {
    final data = <String, dynamic>{};
    if (from != null) data['from'] = from;
    if (to != null) data['to'] = to;
    if (parameters != null) data['parameters'] = parameters;

    debug(message, context: 'NAVIGATION', data: data);
  }

  @override
  void userAction(
    String message, {
    String? action,
    String? screen,
    Map<String, dynamic>? data,
  }) {
    final logData = <String, dynamic>{};
    if (action != null) logData['action'] = action;
    if (screen != null) logData['screen'] = screen;
    if (data != null) logData.addAll(data);

    info(message, context: 'USER_ACTION', data: logData);
  }

  @override
  void nutritionPlan(
    String message, {
    String? planId,
    String? phase,
    Map<String, dynamic>? data,
    dynamic error,
  }) {
    final logData = <String, dynamic>{};
    if (planId != null) logData['plan_id'] = planId;
    if (phase != null) logData['phase'] = phase;
    if (data != null) logData.addAll(data);

    if (error != null) {
      this.error(
        message,
        context: 'NUTRITION_PLAN',
        data: logData,
        error: error,
      );
    } else {
      debug(message, context: 'NUTRITION_PLAN', data: logData);
    }
  }

  @override
  void analytics(
    String message, {
    String? event,
    Map<String, dynamic>? properties,
  }) {
    final data = <String, dynamic>{};
    if (event != null) data['event'] = event;
    if (properties != null) data['properties'] = properties;

    debug(message, context: 'ANALYTICS', data: data);
  }

  void _logWithContext(
    Level level,
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    final contextualMessage = context != null ? '[$context] $message' : message;
    final payload = data == null || data.isEmpty
        ? contextualMessage
        : '$contextualMessage\nData: $data';

    // Only include stack traces for warning, error, and fatal logs
    // Debug and info logs should not have stack traces as they create excessive noise
    final shouldIncludeStackTrace = level.index >= Level.warning.index;
    final effectiveStackTrace = shouldIncludeStackTrace ? stackTrace : null;

    try {
      _logger.log(level, payload, error: error, stackTrace: effectiveStackTrace);
    } catch (e) {
      // Fallback if logger itself fails - silently ignore to avoid infinite recursion
    }

    // Capture to debug log storage for in-app viewing
    try {
      DebugLogStorage().addLog(DebugLogEntry(
        timestamp: DateTime.now(),
        level: _convertLevel(level),
        message: message,
        context: context,
        data: data,
        error: error,
      ));
    } catch (e) {
      // Don't let debug logging break the app - silently ignore
    }

    if (_enableFileOutput) {
      // Placeholder for future file output support.
    }
  }

  /// Convert logger Level to LogLevel enum
  LogLevel _convertLevel(Level level) {
    switch (level) {
      case Level.debug:
        return LogLevel.debug;
      case Level.info:
        return LogLevel.info;
      case Level.warning:
        return LogLevel.warning;
      case Level.error:
        return LogLevel.error;
      case Level.fatal:
        return LogLevel.fatal;
      default:
        return LogLevel.info;
    }
  }
}

/// Logger implementation that swallows all messages.
class NoopAppLogger implements AppLogger {
  const NoopAppLogger();

  @override
  void analytics(String message, {String? event, Map<String, dynamic>? properties}) {}

  @override
  void api(String message,
      {String? endpoint,
      int? statusCode,
      Map<String, dynamic>? requestData,
      Map<String, dynamic>? responseData,
      Duration? duration,
      dynamic error}) {}

  @override
  void database(String message,
      {String? operation,
      String? table,
      Map<String, dynamic>? data,
      Duration? duration,
      dynamic error}) {}

  @override
  void debug(String message,
      {String? context,
      Map<String, dynamic>? data,
      dynamic error,
      StackTrace? stackTrace}) {}

  @override
  void error(String message,
      {String? context,
      Map<String, dynamic>? data,
      dynamic error,
      StackTrace? stackTrace}) {}

  @override
  void fatal(String message,
      {String? context,
      Map<String, dynamic>? data,
      dynamic error,
      StackTrace? stackTrace}) {}

  @override
  void info(String message, {String? context, Map<String, dynamic>? data}) {}

  @override
  void navigation(String message,
      {String? from, String? to, Map<String, dynamic>? parameters}) {}

  @override
  void nutritionPlan(String message,
      {String? planId,
      String? phase,
      Map<String, dynamic>? data,
      dynamic error}) {}

  @override
  void userAction(String message,
      {String? action, String? screen, Map<String, dynamic>? data}) {}

  @override
  void warning(String message,
      {String? context,
      Map<String, dynamic>? data,
      dynamic error,
      StackTrace? stackTrace}) {}
}

/// Filter to reduce logs in production builds.
class ProductionLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (kReleaseMode) {
      return event.level.index >= Level.info.index;
    }
    return true;
  }
}

/// Provider exposing the default logger implementation.
final appLoggerProvider = Provider<AppLogger>((ref) {
  return PrettyAppLogger();
});
