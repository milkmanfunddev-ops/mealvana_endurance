import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Recording implementation of SentryReporter for testing
/// Records all Sentry calls for verification without hitting real services
class RecordingSentryReporter implements SentryReporter {
  RecordingSentryReporter();

  // Recorded calls storage
  final List<ErrorReport> criticalErrors = [];
  final List<EdgeFunctionError> edgeFunctionErrors = [];
  final List<DatabaseError> databaseErrors = [];
  final List<NetworkError> networkErrors = [];
  final List<UserContextCall> userContextCalls = [];
  final List<Breadcrumb> breadcrumbs = [];
  final List<MessageCapture> messages = [];
  int clearUserContextCallCount = 0;

  @override
  Future<void> reportCriticalError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, String>? tags,
  }) async {
    criticalErrors.add(
      ErrorReport(
        error: error,
        stackTrace: stackTrace,
        context: context,
        tags: tags,
      ),
    );
  }

  @override
  Future<void> reportEdgeFunctionError(
    String functionName,
    dynamic error, {
    Duration? responseTime,
    int? statusCode,
    StackTrace? stackTrace,
  }) async {
    edgeFunctionErrors.add(
      EdgeFunctionError(
        functionName: functionName,
        error: error,
        responseTime: responseTime,
        statusCode: statusCode,
        stackTrace: stackTrace,
      ),
    );
  }

  @override
  Future<void> reportDatabaseError(
    dynamic error, {
    String? operation,
    String? table,
    StackTrace? stackTrace,
  }) async {
    databaseErrors.add(
      DatabaseError(
        error: error,
        operation: operation,
        table: table,
        stackTrace: stackTrace,
      ),
    );
  }

  @override
  Future<void> reportNetworkError(
    dynamic error, {
    String? url,
    String? method,
    int? statusCode,
    Duration? timeout,
    StackTrace? stackTrace,
  }) async {
    networkErrors.add(
      NetworkError(
        error: error,
        url: url,
        method: method,
        statusCode: statusCode,
        timeout: timeout,
        stackTrace: stackTrace,
      ),
    );
  }

  @override
  Future<void> setUserContext({
    required String deviceId,
    String? appVersion,
    bool? onboardingCompleted,
    String? gutTrainingLevel,
  }) async {
    userContextCalls.add(
      UserContextCall(
        deviceId: deviceId,
        appVersion: appVersion,
        onboardingCompleted: onboardingCompleted,
        gutTrainingLevel: gutTrainingLevel,
      ),
    );
  }

  @override
  Future<void> clearUserContext() async {
    clearUserContextCallCount++;
  }

  @override
  void addBreadcrumb({
    required String message,
    String? category,
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? data,
  }) {
    breadcrumbs.add(
      Breadcrumb(
        message: message,
        category: category,
        level: level,
        data: data,
      ),
    );
  }

  @override
  Future<void> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
    List<String>? fingerprint,
  }) async {
    messages.add(
      MessageCapture(
        message: message,
        level: level,
        tags: tags,
        extra: extra,
        fingerprint: fingerprint,
      ),
    );
  }

  @override
  bool get isEnabled => true;

  // Helper methods for test assertions
  bool hasCriticalError(String errorPattern) {
    return criticalErrors.any(
      (error) => error.error.toString().contains(errorPattern),
    );
  }

  bool hasEdgeFunctionError(String functionName) {
    return edgeFunctionErrors.any(
      (error) => error.functionName == functionName,
    );
  }

  bool hasBreadcrumb(String message) {
    return breadcrumbs.any((crumb) => crumb.message == message);
  }

  void clear() {
    criticalErrors.clear();
    edgeFunctionErrors.clear();
    databaseErrors.clear();
    networkErrors.clear();
    userContextCalls.clear();
    breadcrumbs.clear();
    messages.clear();
    clearUserContextCallCount = 0;
  }
}

/// Data classes for recorded calls
class ErrorReport {
  const ErrorReport({
    required this.error,
    this.stackTrace,
    this.context,
    this.tags,
  });

  final dynamic error;
  final StackTrace? stackTrace;
  final String? context;
  final Map<String, String>? tags;
}

class EdgeFunctionError {
  const EdgeFunctionError({
    required this.functionName,
    required this.error,
    this.responseTime,
    this.statusCode,
    this.stackTrace,
  });

  final String functionName;
  final dynamic error;
  final Duration? responseTime;
  final int? statusCode;
  final StackTrace? stackTrace;
}

class DatabaseError {
  const DatabaseError({
    required this.error,
    this.operation,
    this.table,
    this.stackTrace,
  });

  final dynamic error;
  final String? operation;
  final String? table;
  final StackTrace? stackTrace;
}

class NetworkError {
  const NetworkError({
    required this.error,
    this.url,
    this.method,
    this.statusCode,
    this.timeout,
    this.stackTrace,
  });

  final dynamic error;
  final String? url;
  final String? method;
  final int? statusCode;
  final Duration? timeout;
  final StackTrace? stackTrace;
}

class UserContextCall {
  const UserContextCall({
    required this.deviceId,
    this.appVersion,
    this.onboardingCompleted,
    this.gutTrainingLevel,
  });

  final String deviceId;
  final String? appVersion;
  final bool? onboardingCompleted;
  final String? gutTrainingLevel;
}

class MessageCapture {
  const MessageCapture({
    required this.message,
    required this.level,
    this.tags,
    this.extra,
    this.fingerprint,
  });

  final String message;
  final SentryLevel level;
  final Map<String, String>? tags;
  final Map<String, dynamic>? extra;
  final List<String>? fingerprint;
}
