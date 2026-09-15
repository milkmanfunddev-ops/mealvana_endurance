import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../shared/services/performance_telemetry.dart';

/// Records when the macro dashboard is shown WITHOUT targets — the
/// "transient disabled dashboard" (QA intake
/// 2026-09-15-dashboard-targets-empty-state). Until the 3-state design is
/// ratified, this state is visually indistinguishable from an error and was
/// previously recorded nowhere; this telemetry is the observability half of
/// that intake, shipped ahead of the design half.
///
/// An *episode* opens the first time a user+day assembles with no targets and
/// closes when the same user+day next assembles WITH targets. Two Sentry
/// signals per episode:
///  - `Dashboard shown without targets` (warning) when it opens — countable
///    per-user frequency without waiting for a crash;
///  - `Dashboard targets transient resolved` (info) when it closes — carries
///    `duration_ms`, i.e. how long the user could have been staring at the
///    placeholder. If the app dies while stuck, the open event still shipped.
///
/// Pure Dart on plugins already in the shipped binary — Shorebird-patchable.
abstract final class DashboardTransientTelemetry {
  /// Open episodes keyed `userId:dateKey` → wall-clock start.
  static final Map<String, DateTime> _openEpisodes = {};

  /// Once-per-process guard so provider rebuilds (frequent by design) don't
  /// spam one event per frame. Keyed `userId:dateKey:reason`.
  static final Set<String> _reportedShown = {};

  /// Test seam: capture calls instead of sending to Sentry.
  static void Function(
    String message,
    SentryLevel level,
    Map<String, Object?> data,
  )?
  debugCaptureOverride;

  /// Call on every dashboard-day assembly with what the surface will render.
  static void observe({
    required String userId,
    required String dateKey,
    required bool hasTargets,
    required bool calculating,
    String? calculationError,
  }) {
    final key = '$userId:$dateKey';

    if (hasTargets) {
      final startedAt = _openEpisodes.remove(key);
      if (startedAt != null) {
        final duration = DateTime.now().difference(startedAt);
        _capture('Dashboard targets transient resolved', SentryLevel.info, {
          'date_key': dateKey,
          'duration_ms': duration.inMilliseconds,
        });
      }
      return;
    }

    // No targets on screen. Why?
    final reason = calculationError != null
        ? 'error'
        : calculating
        ? 'computing'
        : 'empty';

    _openEpisodes.putIfAbsent(key, DateTime.now);
    if (_reportedShown.add('$key:$reason')) {
      _capture('Dashboard shown without targets', SentryLevel.warning, {
        'date_key': dateKey,
        'reason': reason,
        if (calculationError != null) 'calculation_error': calculationError,
      });
    }
  }

  static void _capture(
    String message,
    SentryLevel level,
    Map<String, Object?> data,
  ) {
    final override = debugCaptureOverride;
    if (override != null) {
      override(message, level, data);
      return;
    }
    // Breadcrumb so any later crash carries the dashboard state trail…
    PerformanceTelemetry.record(
      message,
      category: 'macro_dashboard.targets',
      level: level,
      data: data,
    );
    // …and a standalone grouped event so frequency/duration are visible in
    // Sentry without waiting for a crash (same pattern as the slow-operation
    // events in PerformanceTelemetry).
    unawaited(
      Sentry.captureMessage(
        message,
        level: level,
        withScope: (scope) {
          scope.setTag('component', 'macro_dashboard');
          final reason = data['reason'];
          if (reason is String) scope.setTag('reason', reason);
          scope.setContexts('dashboard_targets', data);
        },
      ),
    );
  }

  /// Tests only.
  static void debugReset() {
    _openEpisodes.clear();
    _reportedShown.clear();
    debugCaptureOverride = null;
  }
}
