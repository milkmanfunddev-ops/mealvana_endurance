import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Abstraction over Sentry so callers can be tested without hitting the SDK directly.
abstract class SentryReporter {
  Future<void> reportCriticalError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, String>? tags,
  });

  Future<void> reportEdgeFunctionError(
    String functionName,
    dynamic error, {
    Duration? responseTime,
    int? statusCode,
    StackTrace? stackTrace,
  });

  Future<void> reportDatabaseError(
    dynamic error, {
    String? operation,
    String? table,
    StackTrace? stackTrace,
  });

  Future<void> reportNetworkError(
    dynamic error, {
    String? url,
    String? method,
    int? statusCode,
    Duration? timeout,
    StackTrace? stackTrace,
  });

  Future<void> setUserContext({
    required String deviceId,
    String? appVersion,
    bool? onboardingCompleted,
    String? gutTrainingLevel,
  });

  Future<void> clearUserContext();

  void addBreadcrumb({
    required String message,
    String? category,
    SentryLevel level,
    Map<String, dynamic>? data,
  });

  Future<void> captureMessage(
    String message, {
    SentryLevel level,
    Map<String, String>? tags,
  });

  bool get isEnabled;
}

class SentrySdkReporter implements SentryReporter {
  const SentrySdkReporter();

  @override
  Future<void> reportCriticalError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, String>? tags,
  }) async {
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.level = SentryLevel.error;
        if (context != null) scope.setTag('context', context);
        scope.setTag('severity', 'critical');
        tags?.forEach(scope.setTag);
      },
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
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.setTag('component', 'edge_function');
        scope.setTag('function_name', functionName);
        scope.level = SentryLevel.error;
        if (responseTime != null) {
          scope.setTag(
            'response_time_ms',
            responseTime.inMilliseconds.toString(),
          );
        }
        if (statusCode != null) {
          scope.setTag('status_code', statusCode.toString());
        }
      },
    );
  }

  @override
  Future<void> reportDatabaseError(
    dynamic error, {
    String? operation,
    String? table,
    StackTrace? stackTrace,
  }) async {
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.setTag('component', 'database');
        scope.setTag('operation', operation ?? 'unknown');
        scope.setTag('table', table ?? 'unknown');
        scope.level = SentryLevel.error;
      },
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
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.setTag('component', 'network');
        scope.level = SentryLevel.warning;
        if (url != null) scope.setTag('url', url);
        if (method != null) scope.setTag('method', method);
        if (statusCode != null)
          scope.setTag('status_code', statusCode.toString());
        if (timeout != null) {
          scope.setTag('timeout_ms', timeout.inMilliseconds.toString());
        }
      },
    );
  }

  @override
  Future<void> setUserContext({
    required String deviceId,
    String? appVersion,
    bool? onboardingCompleted,
    String? gutTrainingLevel,
  }) async {
    await Sentry.configureScope((scope) {
      scope.setUser(
        SentryUser(
          id: deviceId,
          data: {
            if (appVersion != null) 'app_version': appVersion,
            if (onboardingCompleted != null)
              'onboarding_completed': onboardingCompleted.toString(),
            if (gutTrainingLevel != null) 'gut_training': gutTrainingLevel,
          },
        ),
      );
    });
  }

  @override
  Future<void> clearUserContext() async {
    await Sentry.configureScope((scope) {
      scope.setUser(null);
    });
  }

  @override
  void addBreadcrumb({
    required String message,
    String? category,
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? data,
  }) {
    Sentry.addBreadcrumb(
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
  }) async {
    await Sentry.captureMessage(
      message,
      level: level,
      withScope: (scope) {
        tags?.forEach(scope.setTag);
      },
    );
  }

  @override
  bool get isEnabled => Sentry.isEnabled;
}

class NoopSentryReporter implements SentryReporter {
  const NoopSentryReporter();

  @override
  Future<void> reportCriticalError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, String>? tags,
  }) async {}

  @override
  Future<void> reportEdgeFunctionError(
    String functionName,
    dynamic error, {
    Duration? responseTime,
    int? statusCode,
    StackTrace? stackTrace,
  }) async {}

  @override
  Future<void> reportDatabaseError(
    dynamic error, {
    String? operation,
    String? table,
    StackTrace? stackTrace,
  }) async {}

  @override
  Future<void> reportNetworkError(
    dynamic error, {
    String? url,
    String? method,
    int? statusCode,
    Duration? timeout,
    StackTrace? stackTrace,
  }) async {}

  @override
  Future<void> setUserContext({
    required String deviceId,
    String? appVersion,
    bool? onboardingCompleted,
    String? gutTrainingLevel,
  }) async {}

  @override
  Future<void> clearUserContext() async {}

  @override
  void addBreadcrumb({
    required String message,
    String? category,
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? data,
  }) {}

  @override
  Future<void> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    Map<String, String>? tags,
  }) async {}

  @override
  bool get isEnabled => false;
}

final sentryReporterProvider = Provider<SentryReporter>((ref) {
  return const SentrySdkReporter();
});
