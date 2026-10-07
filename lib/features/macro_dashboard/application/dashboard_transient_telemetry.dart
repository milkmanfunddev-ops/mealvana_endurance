import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

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
/// closes when the same user+day next assembles WITH targets. A wait is only
/// a finding once it outlasts [transientThreshold] (Lee's ruling 2026-10-07,
/// 01-006, superseding ticket 11's "both stay events"; after every signup the
/// dashboard waits under a second for its first targets):
///  - Opening with reason `computing` or `empty` is a breadcrumb, and starts
///    a timer. If the episode is still open when it fires, the warning event
///    `Dashboard shown without targets` goes out with `reason` and `open_ms`,
///    so a stuck dashboard ships while it is stuck.
///  - Opening with reason `error` is that warning event at once: a
///    calculation error is a finding, not a wait.
///  - Closing under the threshold is a breadcrumb with `duration_ms`; at or
///    over it, the warning event `Dashboard targets transient resolved`.
/// Episodes and timers live in process memory: if the app dies before the
/// threshold, only the breadcrumb is lost, and nothing was wrong long enough
/// to matter.
///
/// Pure Dart on plugins already in the shipped binary — Shorebird-patchable.
abstract final class DashboardTransientTelemetry {
  /// How long a dashboard may wait for targets before the wait is an event:
  /// the app's one bar for "a wait is an event".
  static const Duration transientThreshold = PerformanceTelemetry.slowCeiling;

  /// Open episodes keyed `userId:dateKey`.
  static final Map<String, _Episode> _openEpisodes = {};

  /// Once-per-process guard so provider rebuilds (frequent by design) don't
  /// spam one signal per frame, nor start one timer per frame. Keyed
  /// `userId:dateKey:reason`.
  static final Set<String> _reportedShown = {};

  /// Tests inject a `RecordingReport`; production reads the global.
  static Report? reportOverride;

  /// The clock episodes are timed with. Tests move it with their fake timers.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

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
      final episode = _openEpisodes.remove(key);
      if (episode == null) return;
      episode.timer?.cancel();
      final duration = now().difference(episode.startedAt);
      final data = <String, Object?>{
        'date_key': dateKey,
        'duration_ms': duration.inMilliseconds,
      };
      if (duration < transientThreshold) {
        _breadcrumb('Dashboard targets transient resolved', data);
      } else {
        _capture('Dashboard targets transient resolved', data);
      }
      return;
    }

    // No targets on screen. Why?
    final reason = calculationError != null
        ? 'error'
        : calculating
        ? 'computing'
        : 'empty';

    final episode = _openEpisodes.putIfAbsent(key, () => _Episode(now()));
    episode.reason = reason;
    if (!_reportedShown.add('$key:$reason')) return;

    final data = <String, Object?>{
      'date_key': dateKey,
      'reason': reason,
      if (calculationError != null) 'calculation_error': calculationError,
    };
    if (reason == 'error') {
      _capture('Dashboard shown without targets', data);
      return;
    }
    _breadcrumb('Dashboard shown without targets', data);
    episode.timer ??= Timer(transientThreshold, () {
      // Still the same open episode: it has waited past the threshold.
      if (!identical(_openEpisodes[key], episode)) return;
      _capture('Dashboard shown without targets', {
        'date_key': dateKey,
        'reason': episode.reason,
        'open_ms': now().difference(episode.startedAt).inMilliseconds,
      });
    });
  }

  static void _breadcrumb(String message, Map<String, Object?> data) {
    PerformanceTelemetry.record(
      message,
      category: 'macro_dashboard.targets',
      data: data,
    );
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
    for (final episode in _openEpisodes.values) {
      episode.timer?.cancel();
    }
    _openEpisodes.clear();
    _reportedShown.clear();
    reportOverride = null;
    now = DateTime.now;
  }
}

/// One open no-targets episode.
final class _Episode {
  _Episode(this.startedAt);

  final DateTime startedAt;

  /// The latest reason seen while open.
  String reason = 'empty';

  /// Fires the stuck event at [DashboardTransientTelemetry.transientThreshold].
  Timer? timer;
}

/// The macro dashboard rendered without targets, or recovered from it.
class DashboardTargetsAnomaly implements Exception {
  const DashboardTargetsAnomaly(this.message);

  final String message;

  @override
  String toString() => message;
}
