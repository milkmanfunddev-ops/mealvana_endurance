import 'dart:async';

import '../../../shared/services/report/performance_telemetry.dart';
import '../../../shared/services/report/report.dart';

/// Records when the macro dashboard is shown WITHOUT targets — the
/// "transient disabled dashboard" (QA intake
/// 2026-09-15-dashboard-targets-empty-state). Until the 3-state design is
/// ratified, this state is visually indistinguishable from an error and was
/// previously recorded nowhere; this telemetry is the observability half of
/// that intake, shipped ahead of the design half.
///
/// An *episode* opens the first time a user+day assembles with no targets and
/// closes when the same user+day next assembles WITH targets. Two signals per
/// episode, both `Report.degraded` warning events (spec: these are real
/// findings and stay events, ticket 11):
///  - `Dashboard shown without targets` when it opens — countable
///    per-user frequency without waiting for a crash;
///  - `Dashboard targets transient resolved` when it closes — carries
///    `duration_ms`, i.e. how long the user could have been staring at the
///    placeholder. If the app dies while stuck, the open event still shipped.
///    Episodes live in process memory: a restart between open and close
///    loses the duration (the open event survives — it already shipped).
///
/// Pure Dart on plugins already in the shipped binary — Shorebird-patchable.
abstract final class DashboardTransientTelemetry {
  /// Open episodes keyed `userId:dateKey` → wall-clock start.
  static final Map<String, DateTime> _openEpisodes = {};

  /// Once-per-process guard so provider rebuilds (frequent by design) don't
  /// spam one event per frame. Keyed `userId:dateKey:reason`.
  static final Set<String> _reportedShown = {};

  /// Tests inject a `RecordingReport`; production reads the global.
  static Report? reportOverride;

  static Report get _report => reportOverride ?? SentryReport.global;

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
        _capture('Dashboard targets transient resolved', {
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
      _capture('Dashboard shown without targets', {
        'date_key': dateKey,
        'reason': reason,
        if (calculationError != null) 'calculation_error': calculationError,
      });
    }
  }

  static void _capture(String message, Map<String, Object?> data) {
    // Breadcrumb so any later crash carries the dashboard state trail…
    PerformanceTelemetry.record(
      message,
      category: 'macro_dashboard.targets',
      warning: true,
      data: data,
    );
    // …and a grouped warning event so frequency/duration are visible in
    // Sentry without waiting for a crash.
    final reason = data['reason'];
    unawaited(
      _report.degraded(
        DashboardTargetsAnomaly(message),
        area: 'macro_dashboard',
        message: message,
        tags: {
          'component': 'macro_dashboard',
          if (reason is String) 'reason': reason,
        },
        extra: data,
        fingerprint: ['dashboard-targets', message],
      ),
    );
  }

  /// Tests only.
  static void debugReset() {
    _openEpisodes.clear();
    _reportedShown.clear();
    reportOverride = null;
  }
}

/// The macro dashboard rendered without targets, or recovered from it.
class DashboardTargetsAnomaly implements Exception {
  const DashboardTargetsAnomaly(this.message);

  final String message;

  @override
  String toString() => message;
}
