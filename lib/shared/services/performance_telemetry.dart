import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

/// Lightweight timing telemetry for startup and first-interaction work.
///
/// Every measurement becomes a Sentry breadcrumb, so a later app-hang event
/// carries the exact work that preceded it. Operations over [slowThreshold]
/// also become grouped warning events that can be found without waiting for a
/// crash. This deliberately does not enable continuous profiling.
abstract final class PerformanceTelemetry {
  static const Duration slowThreshold = Duration(seconds: 2);

  static final Stopwatch _processUptime = Stopwatch()..start();
  static final Set<String> _reportedSlowOperations = {};

  static Future<T> measure<T>(
    String operation,
    Future<T> Function() action, {
    Map<String, dynamic> data = const {},
    Duration threshold = slowThreshold,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      stopwatch.stop();
      recordDuration(
        operation,
        stopwatch.elapsed,
        data: data,
        threshold: threshold,
      );
    }
  }

  static void recordDuration(
    String operation,
    Duration duration, {
    Map<String, dynamic> data = const {},
    Duration threshold = slowThreshold,
  }) {
    final payload = <String, dynamic>{
      'operation': operation,
      'duration_ms': duration.inMilliseconds,
      'process_uptime_ms': _processUptime.elapsedMilliseconds,
      ...data,
    };

    Sentry.addBreadcrumb(
      Breadcrumb(
        message: '$operation completed',
        category: 'performance',
        level: duration >= threshold ? SentryLevel.warning : SentryLevel.info,
        data: payload,
      ),
    );

    if (duration >= threshold && _reportedSlowOperations.add(operation)) {
      unawaited(
        Sentry.captureMessage(
          'Slow operation: $operation',
          level: SentryLevel.warning,
          withScope: (scope) {
            scope.setTag('component', 'startup_performance');
            scope.setTag('operation', operation);
            scope.setContexts('timing', payload);
          },
        ),
      );
    }
  }

  static void record(
    String message, {
    String category = 'performance',
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic> data = const {},
  }) {
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: category,
        level: level,
        data: <String, dynamic>{
          'process_uptime_ms': _processUptime.elapsedMilliseconds,
          ...data,
        },
      ),
    );
  }

  /// Database recreation is rare and materially important, so record it as a
  /// standalone warning in addition to a breadcrumb.
  static void recordDatabaseReset({
    required String reason,
    int? oldSchemaVersion,
    int? newSchemaVersion,
    String? context,
  }) {
    final data = <String, dynamic>{
      'reason': reason,
      if (oldSchemaVersion != null) 'old_schema_version': oldSchemaVersion,
      if (newSchemaVersion != null) 'new_schema_version': newSchemaVersion,
      if (context != null) 'context': context,
      'process_uptime_ms': _processUptime.elapsedMilliseconds,
    };

    record(
      'Local database reset requested',
      category: 'database.recovery',
      level: SentryLevel.warning,
      data: data,
    );
    unawaited(
      Sentry.captureMessage(
        'Local database reset: $reason',
        level: SentryLevel.warning,
        withScope: (scope) {
          scope.setTag('component', 'database');
          scope.setTag('database_reset_reason', reason);
          if (oldSchemaVersion != null) {
            scope.setTag('old_schema_version', '$oldSchemaVersion');
          }
          if (newSchemaVersion != null) {
            scope.setTag('new_schema_version', '$newSchemaVersion');
          }
          scope.setContexts('database_reset', data);
        },
      ),
    );
  }
}
