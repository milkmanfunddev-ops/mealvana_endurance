import 'package:mealvana_endurance/shared/services/logging_service.dart';

/// Recording implementation of AppLogger for testing
/// Records all log calls for verification without hitting real logging services
class RecordingAppLogger implements AppLogger {
  RecordingAppLogger();

  // Recorded log entries by level
  final List<LogEntry> debugLogs = [];
  final List<LogEntry> infoLogs = [];
  final List<LogEntry> warningLogs = [];
  final List<LogEntry> errorLogs = [];
  final List<LogEntry> fatalLogs = [];
  final List<ApiLog> apiLogs = [];
  final List<DatabaseLog> databaseLogs = [];
  final List<NavigationLog> navigationLogs = [];
  final List<UserActionLog> userActionLogs = [];
  final List<NutritionPlanLog> nutritionPlanLogs = [];
  final List<AnalyticsLog> analyticsLogs = [];

  @override
  void debug(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    debugLogs.add(
      LogEntry(
        message: message,
        context: context,
        data: data,
        error: error,
        stackTrace: stackTrace,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void info(String message, {String? context, Map<String, dynamic>? data}) {
    infoLogs.add(
      LogEntry(
        message: message,
        context: context,
        data: data,
        timestamp: DateTime.now(),
      ),
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
    warningLogs.add(
      LogEntry(
        message: message,
        context: context,
        data: data,
        error: error,
        stackTrace: stackTrace,
        timestamp: DateTime.now(),
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
    errorLogs.add(
      LogEntry(
        message: message,
        context: context,
        data: data,
        error: error,
        stackTrace: stackTrace,
        timestamp: DateTime.now(),
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
    fatalLogs.add(
      LogEntry(
        message: message,
        context: context,
        data: data,
        error: error,
        stackTrace: stackTrace,
        timestamp: DateTime.now(),
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
    apiLogs.add(
      ApiLog(
        message: message,
        endpoint: endpoint,
        statusCode: statusCode,
        requestData: requestData,
        responseData: responseData,
        duration: duration,
        error: error,
        timestamp: DateTime.now(),
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
    databaseLogs.add(
      DatabaseLog(
        message: message,
        operation: operation,
        table: table,
        data: data,
        duration: duration,
        error: error,
        timestamp: DateTime.now(),
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
    navigationLogs.add(
      NavigationLog(
        message: message,
        from: from,
        to: to,
        parameters: parameters,
        timestamp: DateTime.now(),
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
    userActionLogs.add(
      UserActionLog(
        message: message,
        action: action,
        screen: screen,
        data: data,
        timestamp: DateTime.now(),
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
    nutritionPlanLogs.add(
      NutritionPlanLog(
        message: message,
        planId: planId,
        phase: phase,
        data: data,
        error: error,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void analytics(
    String message, {
    String? event,
    Map<String, dynamic>? properties,
  }) {
    analyticsLogs.add(
      AnalyticsLog(
        message: message,
        event: event,
        properties: properties,
        timestamp: DateTime.now(),
      ),
    );
  }

  // Helper methods for test assertions
  bool hasDebugLog(String messagePattern) {
    return debugLogs.any((log) => log.message.contains(messagePattern));
  }

  bool hasErrorLog(String messagePattern) {
    return errorLogs.any((log) => log.message.contains(messagePattern));
  }

  bool hasApiLog(String endpoint) {
    return apiLogs.any((log) => log.endpoint == endpoint);
  }

  int get totalLogCount =>
      debugLogs.length +
      infoLogs.length +
      warningLogs.length +
      errorLogs.length +
      fatalLogs.length;

  void clear() {
    debugLogs.clear();
    infoLogs.clear();
    warningLogs.clear();
    errorLogs.clear();
    fatalLogs.clear();
    apiLogs.clear();
    databaseLogs.clear();
    navigationLogs.clear();
    userActionLogs.clear();
    nutritionPlanLogs.clear();
    analyticsLogs.clear();
  }
}

/// Data classes for recorded log entries
class LogEntry {
  const LogEntry({
    required this.message,
    this.context,
    this.data,
    this.error,
    this.stackTrace,
    required this.timestamp,
  });

  final String message;
  final String? context;
  final Map<String, dynamic>? data;
  final dynamic error;
  final StackTrace? stackTrace;
  final DateTime timestamp;
}

class ApiLog {
  const ApiLog({
    required this.message,
    this.endpoint,
    this.statusCode,
    this.requestData,
    this.responseData,
    this.duration,
    this.error,
    required this.timestamp,
  });

  final String message;
  final String? endpoint;
  final int? statusCode;
  final Map<String, dynamic>? requestData;
  final Map<String, dynamic>? responseData;
  final Duration? duration;
  final dynamic error;
  final DateTime timestamp;
}

class DatabaseLog {
  const DatabaseLog({
    required this.message,
    this.operation,
    this.table,
    this.data,
    this.duration,
    this.error,
    required this.timestamp,
  });

  final String message;
  final String? operation;
  final String? table;
  final Map<String, dynamic>? data;
  final Duration? duration;
  final dynamic error;
  final DateTime timestamp;
}

class NavigationLog {
  const NavigationLog({
    required this.message,
    this.from,
    this.to,
    this.parameters,
    required this.timestamp,
  });

  final String message;
  final String? from;
  final String? to;
  final Map<String, dynamic>? parameters;
  final DateTime timestamp;
}

class UserActionLog {
  const UserActionLog({
    required this.message,
    this.action,
    this.screen,
    this.data,
    required this.timestamp,
  });

  final String message;
  final String? action;
  final String? screen;
  final Map<String, dynamic>? data;
  final DateTime timestamp;
}

class NutritionPlanLog {
  const NutritionPlanLog({
    required this.message,
    this.planId,
    this.phase,
    this.data,
    this.error,
    required this.timestamp,
  });

  final String message;
  final String? planId;
  final String? phase;
  final Map<String, dynamic>? data;
  final dynamic error;
  final DateTime timestamp;
}

class AnalyticsLog {
  const AnalyticsLog({
    required this.message,
    this.event,
    this.properties,
    required this.timestamp,
  });

  final String message;
  final String? event;
  final Map<String, dynamic>? properties;
  final DateTime timestamp;
}
