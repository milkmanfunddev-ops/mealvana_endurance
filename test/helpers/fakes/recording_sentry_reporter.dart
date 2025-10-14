import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class RecordedException {
  RecordedException(this.error, this.stackTrace, this.tags);
  final dynamic error;
  final StackTrace? stackTrace;
  final Map<String, String>? tags;
}

class RecordedBreadcrumb {
  RecordedBreadcrumb(this.message, this.category, this.level, this.data);
  final String message;
  final String? category;
  final SentryLevel level;
  final Map<String, dynamic>? data;
}

class RecordingSentryReporter implements SentryReporter {
  final List<RecordedException> criticalErrors = [];
  final List<RecordedException> databaseErrors = [];
  final List<RecordedException> edgeFunctionErrors = [];
  final List<RecordedException> networkErrors = [];
  final List<RecordedBreadcrumb> breadcrumbs = [];
  final List<String> messages = [];
  Map<String, String>? lastUserContext;
  bool userCleared = false;

  @override
  Future<void> reportCriticalError(
    error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, String>? tags,
  }) async {
    criticalErrors.add(RecordedException(error, stackTrace, {
      if (context != null) 'context': context,
      ...?tags,
    }));
  }

  @override
  Future<void> reportEdgeFunctionError(
    String functionName,
    error, {
    Duration? responseTime,
    int? statusCode,
    StackTrace? stackTrace,
  }) async {
    edgeFunctionErrors.add(RecordedException(error, stackTrace, {
      'function_name': functionName,
      if (responseTime != null)
        'response_time_ms': responseTime.inMilliseconds.toString(),
      if (statusCode != null) 'status_code': statusCode.toString(),
    }));
  }

  @override
  Future<void> reportDatabaseError(
    error, {
    String? operation,
    String? table,
    StackTrace? stackTrace,
  }) async {
    databaseErrors.add(RecordedException(error, stackTrace, {
      if (operation != null) 'operation': operation,
      if (table != null) 'table': table,
    }));
  }

  @override
  Future<void> reportNetworkError(
    error, {
    String? url,
    String? method,
    int? statusCode,
    Duration? timeout,
    StackTrace? stackTrace,
  }) async {
    networkErrors.add(RecordedException(error, stackTrace, {
      if (url != null) 'url': url,
      if (method != null) 'method': method,
      if (statusCode != null) 'status_code': statusCode.toString(),
      if (timeout != null) 'timeout_ms': timeout.inMilliseconds.toString(),
    }));
  }

  @override
  Future<void> setUserContext({
    required String deviceId,
    String? appVersion,
    bool? onboardingCompleted,
    String? gutTrainingLevel,
  }) async {
    lastUserContext = {
      'device_id': deviceId,
      if (appVersion != null) 'app_version': appVersion,
      if (onboardingCompleted != null)
        'onboarding_completed': onboardingCompleted.toString(),
      if (gutTrainingLevel != null) 'gut_training': gutTrainingLevel,
    };
  }

  @override
  Future<void> clearUserContext() async {
    userCleared = true;
    lastUserContext = null;
  }

  @override
  void addBreadcrumb({
    required String message,
    String? category,
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? data,
  }) {
    breadcrumbs.add(RecordedBreadcrumb(message, category, level, data));
  }

  @override
  Future<void> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    Map<String, String>? tags,
  }) async {
    messages.add(message);
  }

  @override
  bool get isEnabled => true;
}
