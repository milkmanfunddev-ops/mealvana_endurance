import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Centralized logging service for the Mealvana Endurance app
/// 
/// Provides structured logging with different levels and contexts
/// Integrates with Sentry for production error tracking
class LoggingService {
  LoggingService._internal();
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  
  late final Logger _logger;
  
  /// Initialize the logging service
  /// Should be called early in app startup
  void initialize({
    Level logLevel = Level.debug,
    bool enableFileOutput = false,
  }) {
    _logger = Logger(
      level: kDebugMode ? logLevel : Level.info,
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
      filter: ProductionFilter(),
    );
  }
  
  /// Log debug information - only shown in debug mode
  void debug(String message, {
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
  
  /// Log general information
  void info(String message, {
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
  
  /// Log warnings
  void warning(String message, {
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
  
  /// Log errors
  void error(String message, {
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
  
  /// Log fatal errors
  void fatal(String message, {
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
  
  /// Log with structured context
  void _logWithContext(
    Level level,
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    final contextualMessage = context != null ? '[$context] $message' : message;
    
    if (data != null) {
      _logger.log(level, '$contextualMessage\nData: $data', error: error, stackTrace: stackTrace);
    } else {
      _logger.log(level, contextualMessage, error: error, stackTrace: stackTrace);
    }
  }
  
  // Convenience methods for common contexts
  
  /// Log API-related events
  void api(String message, {
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
      this.error(message, context: 'API', data: data, error: error);
    } else if (statusCode != null && statusCode >= 400) {
      warning(message, context: 'API', data: data);
    } else {
      debug(message, context: 'API', data: data);
    }
  }
  
  /// Log database-related events
  void database(String message, {
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
      this.error(message, context: 'DATABASE', data: logData, error: error);
    } else {
      debug(message, context: 'DATABASE', data: logData);
    }
  }
  
  /// Log navigation events
  void navigation(String message, {
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
  
  /// Log user interaction events
  void userAction(String message, {
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
  
  /// Log nutrition plan related events
  void nutritionPlan(String message, {
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
      this.error(message, context: 'NUTRITION_PLAN', data: logData, error: error);
    } else {
      debug(message, context: 'NUTRITION_PLAN', data: logData);
    }
  }
  
  /// Log analytics events
  void analytics(String message, {
    String? event,
    Map<String, dynamic>? properties,
  }) {
    final data = <String, dynamic>{};
    if (event != null) data['event'] = event;
    if (properties != null) data['properties'] = properties;
    
    debug(message, context: 'ANALYTICS', data: data);
  }
}

/// Filter to reduce logs in production
class ProductionFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (kReleaseMode) {
      return event.level.index >= Level.info.index;
    }
    return true;
  }
}

/// Global logger instance for static access
/// Can be called from anywhere without dependency injection
class AppLogger {
  static LoggingService get instance => LoggingService();
}