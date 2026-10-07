import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

import 'report.dart';

/// Lightweight timing telemetry for startup and first-interaction work
/// (spec: `.scratch/sentry/spec.md` § Telemetry that is not an error;
/// ticket 11).
///
/// Every measurement becomes a Sentry breadcrumb, so a later app-hang event
/// carries the exact work that preceded it, and a `perf.step` span so the
/// duration is queryable (p95 per step on the startup-performance dashboard).
/// The span is a child of whatever transaction is bound to the scope — the
/// SDK's route transaction during startup, the dashboard's route transaction
/// later — and a standalone one-span transaction when nothing is bound, so a
/// step is never lost. The step's duration is also set as a measurement on
/// that transaction.
///
/// A step at or over [slowCeiling] is the one warning event that remains:
/// one per step per process, fingerprinted by step name so they group. A
/// step between [slowThreshold] and the ceiling is a warning breadcrumb and a
/// span, never an event. This file lives in the Report layer because it is
/// the only place outside the bootstrap allowed to touch the Sentry SDK.
abstract final class PerformanceTelemetry {
  /// Marks the breadcrumb as a warning; no event below the ceiling.
  static const Duration slowThreshold = Duration(seconds: 2);

  /// At or over this a step is a `Report.degraded` warning event.
  static const Duration slowCeiling = Duration(seconds: 10);

  /// Span operation for every step span and fallback transaction.
  static const String spanOperation = 'perf.step';

  static final Stopwatch _processUptime = Stopwatch()..start();
  static final Set<String> _reportedCeilingBreaches = {};

  /// Tests inject a `RecordingReport`; production reads the global.
  static Report? reportOverride;

  static Report get _report => reportOverride ?? SentryReport.global;

  /// Times [action] as [operation].
  ///
  /// [userWait] is time inside the step spent waiting on the athlete, not
  /// the app: the iOS notification prompt in `deferred.notifications`
  /// (develop-2026-10 ticket 22, 08-009). The slow and ceiling checks use the
  /// wall time minus it, floored at zero; the breadcrumb and span carry
  /// `duration_ms` (net), `user_wait_ms` and `wall_ms`, so nothing is hidden.
  /// Read once, when the step ends.
  static Future<T> measure<T>(
    String operation,
    Future<T> Function() action, {
    Map<String, dynamic> data = const {},
    Duration threshold = slowThreshold,
    Duration Function()? userWait,
  }) async {
    // Opened before the work so the span's own clock is honest; the SDK
    // refuses a child that starts before its parent, which a back-dated
    // span could.
    final span = _startSpan(operation);
    final stopwatch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      stopwatch.stop();
      _recordDuration(
        operation,
        stopwatch.elapsed,
        data: data,
        threshold: threshold,
        openSpan: span,
        userWait: userWait,
      );
    }
  }

  /// For a duration measured elsewhere. The span is back-dated, clamped to
  /// the bound transaction's start; `duration_ms` carries the true value.
  /// [userWait] as in [measure].
  static void recordDuration(
    String operation,
    Duration duration, {
    Map<String, dynamic> data = const {},
    Duration threshold = slowThreshold,
    Duration Function()? userWait,
  }) => _recordDuration(
    operation,
    duration,
    data: data,
    threshold: threshold,
    userWait: userWait,
  );

  static void _recordDuration(
    String operation,
    Duration wall, {
    required Map<String, dynamic> data,
    required Duration threshold,
    ISentrySpan? openSpan,
    Duration Function()? userWait,
  }) {
    final waited = userWait?.call() ?? Duration.zero;
    final net = wall - waited;
    // What the app itself took: the slow and ceiling checks read this.
    final duration = net.isNegative ? Duration.zero : net;
    final payload = <String, dynamic>{
      'operation': operation,
      'duration_ms': duration.inMilliseconds,
      if (userWait != null) 'user_wait_ms': waited.inMilliseconds,
      if (userWait != null) 'wall_ms': wall.inMilliseconds,
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

    _finishSpan(
      openSpan ?? _startSpan(operation, startedAt: _now().subtract(wall)),
      operation,
      duration,
      payload,
    );

    if (duration > slowCeiling && _reportedCeilingBreaches.add(operation)) {
      unawaited(
        _report.degraded(
          SlowOperation(operation, duration),
          area: 'performance',
          message: 'Slow operation: $operation',
          tags: {'component': 'startup_performance', 'operation': operation},
          extra: payload,
          fingerprint: ['slow-operation', operation],
        ),
      );
    }
  }

  static DateTime _now() => DateTime.now().toUtc();

  /// A `perf.step` span: a child of the transaction bound to the scope when
  /// there is one, else a standalone one-span transaction named for the step.
  /// `null` only when the SDK itself failed.
  static ISentrySpan? _startSpan(String operation, {DateTime? startedAt}) {
    try {
      final parent = Sentry.getSpan();
      if (parent == null) {
        return Sentry.startTransaction(
          operation,
          spanOperation,
          startTimestamp: startedAt,
        );
      }
      // The SDK refuses a child that starts before its parent.
      final start = startedAt != null && startedAt.isBefore(parent.startTimestamp)
          ? parent.startTimestamp
          : startedAt;
      return parent.startChild(
        spanOperation,
        description: operation,
        startTimestamp: start,
      );
    } catch (_) {
      // Spans are performance narrative inside the Report layer; a Fault
      // from here would recurse into Report over a lost span.
      return null;
    }
  }

  /// Finishes the step span with its measurement and payload.
  static void _finishSpan(
    ISentrySpan? span,
    String operation,
    Duration duration,
    Map<String, dynamic> payload,
  ) {
    if (span == null) return;
    try {
      span.setMeasurement(
        measurementName(operation),
        duration.inMilliseconds,
        unit: DurationSentryMeasurementUnit.milliSecond,
      );
      for (final entry in payload.entries) {
        span.setData(entry.key, entry.value);
      }
      span.status = const SpanStatus.ok();
      unawaited(span.finish(endTimestamp: _now()));
    } catch (_) {
      // Same ruling as `_startSpan`: never a Fault over a lost span.
    }
  }

  /// Sentry measurement names allow letters, digits, `_` and `.`; everything
  /// else in a step name collapses to `_`.
  static String measurementName(String operation) =>
      operation.replaceAll(RegExp(r'[^A-Za-z0-9_.]'), '_');

  static void record(
    String message, {
    String category = 'performance',
    bool warning = false,
    Map<String, dynamic> data = const {},
  }) {
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: category,
        level: warning ? SentryLevel.warning : SentryLevel.info,
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
      warning: true,
      data: data,
    );
    unawaited(
      _report.degraded(
        DatabaseReset(reason),
        area: 'database',
        message: 'Local database reset: $reason',
        tags: {
          'component': 'database',
          'database_reset_reason': reason,
          if (oldSchemaVersion != null)
            'old_schema_version': '$oldSchemaVersion',
          if (newSchemaVersion != null)
            'new_schema_version': '$newSchemaVersion',
        },
        extra: data,
        fingerprint: ['database-reset', reason],
      ),
    );
  }

  /// Tests only.
  static void debugReset() {
    _reportedCeilingBreaches.clear();
    reportOverride = null;
  }
}

/// A step that ran past [PerformanceTelemetry.slowCeiling].
class SlowOperation implements Exception {
  const SlowOperation(this.operation, this.duration);

  final String operation;
  final Duration duration;

  @override
  String toString() =>
      'Slow operation: $operation took ${duration.inMilliseconds} ms';
}

/// The local database was recreated.
class DatabaseReset implements Exception {
  const DatabaseReset(this.reason);

  final String reason;

  @override
  String toString() => 'Local database reset: $reason';
}
