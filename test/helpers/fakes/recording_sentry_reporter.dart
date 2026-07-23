/// Recording Sentry reporter for testing
/// Captures all Sentry calls for verification in tests
library;

import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';

/// Exception record
class ExceptionRecord {
  const ExceptionRecord({
    required this.error,
    this.stackTrace,
    this.context,
    this.tags,
  });

  final dynamic error;
  final StackTrace? stackTrace;
  final String? context;
  final Map<String, String>? tags;

  @override
  String toString() => 'ExceptionRecord($error, context: $context)';
}

/// Breadcrumb record
class BreadcrumbRecord {
  const BreadcrumbRecord({
    required this.message,
    this.category,
    this.level,
    this.data,
  });

  final String message;
  final String? category;
  final SentryLevel? level;
  final Map<String, dynamic>? data;

  @override
  String toString() => 'BreadcrumbRecord($message, category: $category)';
}

/// User context record
class UserContextRecord {
  const UserContextRecord({
    required this.deviceId,
    this.appVersion,
    this.onboardingCompleted,
    this.gutTrainingLevel,
  });

  final String deviceId;
  final String? appVersion;
  final bool? onboardingCompleted;
  final String? gutTrainingLevel;

  @override
  String toString() => 'UserContextRecord($deviceId)';
}

/// Message record
class MessageRecord {
  const MessageRecord({required this.message, this.level, this.tags});

  final String message;
  final SentryLevel? level;
  final Map<String, String>? tags;

  @override
  String toString() => 'MessageRecord($message, level: $level)';
}

/// Recording implementation of SentryReporter for testing
class RecordingSentryReporter implements SentryReporter {
  final List<ExceptionRecord> capturedExceptions = [];
  final List<BreadcrumbRecord> breadcrumbs = [];
  final List<UserContextRecord> userContexts = [];
  final List<MessageRecord> messages = [];

  bool _userContextCleared = false;
  final bool _enabled = true;

  @override
  Future<void> reportCriticalError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, String>? tags,
  }) async {
    capturedExceptions.add(
      ExceptionRecord(
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
    capturedExceptions.add(
      ExceptionRecord(
        error: error,
        stackTrace: stackTrace,
        context: 'edge_function',
        tags: {
          'function_name': functionName,
          if (statusCode != null) 'status_code': statusCode.toString(),
          if (responseTime != null)
            'response_time_ms': responseTime.inMilliseconds.toString(),
        },
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
    capturedExceptions.add(
      ExceptionRecord(
        error: error,
        stackTrace: stackTrace,
        context: 'database',
        tags: {
          if (operation != null) 'operation': operation,
          if (table != null) 'table': table,
        },
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
    capturedExceptions.add(
      ExceptionRecord(
        error: error,
        stackTrace: stackTrace,
        context: 'network',
        tags: {
          if (url != null) 'url': url,
          if (method != null) 'method': method,
          if (statusCode != null) 'status_code': statusCode.toString(),
        },
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
    userContexts.add(
      UserContextRecord(
        deviceId: deviceId,
        appVersion: appVersion,
        onboardingCompleted: onboardingCompleted,
        gutTrainingLevel: gutTrainingLevel,
      ),
    );
  }

  @override
  Future<void> clearUserContext() async {
    _userContextCleared = true;
  }

  @override
  void addBreadcrumb({
    required String message,
    String? category,
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? data,
  }) {
    breadcrumbs.add(
      BreadcrumbRecord(
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
  }) async {
    messages.add(MessageRecord(message: message, level: level, tags: tags));
  }

  @override
  bool get isEnabled => _enabled;

  // Test helpers
  bool get wasUserContextCleared => _userContextCleared;

  ExceptionRecord? get lastException =>
      capturedExceptions.isNotEmpty ? capturedExceptions.last : null;

  BreadcrumbRecord? get lastBreadcrumb =>
      breadcrumbs.isNotEmpty ? breadcrumbs.last : null;

  UserContextRecord? get lastUserContext =>
      userContexts.isNotEmpty ? userContexts.last : null;

  /// Find breadcrumbs by category
  List<BreadcrumbRecord> findBreadcrumbs(String category) {
    return breadcrumbs.where((b) => b.category == category).toList();
  }

  /// Check if a breadcrumb was added
  bool hasBreadcrumb(String message) {
    return breadcrumbs.any((b) => b.message == message);
  }

  /// Clear all recorded data (for test cleanup)
  void clear() {
    capturedExceptions.clear();
    breadcrumbs.clear();
    userContexts.clear();
    messages.clear();
    _userContextCleared = false;
  }
}
