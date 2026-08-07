import 'dart:math' as math;

import '../../../shared/domain/activity_type.dart';
import '../../activities/domain/activity.dart';
import '../domain/training_insights.dart';

/// Digests the workouts imported during onboarding into [TrainingInsights]
/// for the plan reveal.
///
/// Pure over its inputs — no repository or clock access — so reliability
/// rules and edge cases are pinned by fixtures in
/// `test/features/onboarding/training_insight_service_test.dart`.
///
/// Intake reliability gate: personalized insights require an imported window
/// spanning at least [minWindowDays] AND either [minSessionCount] sessions or
/// one qualifying long session. Below that bar the preview must fall back to
/// generic targets ("we'll refine once a full week syncs") — never to
/// insights extrapolated from a thin sample. FinalSurge's ~7-day history is
/// exactly the minimum; TrainingPeaks (~30d), Garmin, and Runna ICS clear it
/// comfortably when the athlete trains at all.
class TrainingInsightService {
  TrainingInsightService._();

  /// Minimum imported window span, in days, for reliable insights.
  static const int minWindowDays = 7;

  /// Minimum session count for reliability without a qualifying long session.
  static const int minSessionCount = 3;

  /// A run at least this long counts as a qualifying long session.
  static const int longRunMinMinutes = 90;

  /// A ride at least this long counts as a qualifying long session.
  static const int longRideMinMinutes = 120;

  /// Minimum distinct weekdays with training before we'll claim a
  /// heavy/light pattern on the reveal card — below this a single sample
  /// (e.g. one Tuesday) looks arbitrary rather than a real pattern.
  static const int minWeekdaysForPattern = 4;

  /// Digest [activities] (typically everything the onboarding auto-import
  /// wrote) into insights. Soft-deleted, skipped, and import-only "other"
  /// activities are ignored; brick/multisport count toward load but not
  /// toward the longest-run/ride cards.
  static TrainingInsights digest(List<Activity> activities) {
    final usable = activities
        .where(
          (a) =>
              a.deletedAt == null &&
              a.status != ActivityStatus.skipped &&
              a.activityType != ActivityType.other &&
              _durationOf(a) > 0,
        )
        .toList();

    if (usable.isEmpty) return TrainingInsights.none;

    var earliest = usable.first.scheduledDateTime;
    var latest = usable.first.scheduledDateTime;
    var totalMinutes = 0;
    final trainingDays = <DateTime>{};
    final minutesByWeekday = <int, int>{};
    Activity? longestRun;
    Activity? longestRide;

    for (final activity in usable) {
      final when = activity.scheduledDateTime;
      if (when.isBefore(earliest)) earliest = when;
      if (when.isAfter(latest)) latest = when;
      final minutes = _durationOf(activity);
      totalMinutes += minutes;
      trainingDays.add(DateTime(when.year, when.month, when.day));
      minutesByWeekday.update(
        when.weekday,
        (total) => total + minutes,
        ifAbsent: () => minutes,
      );

      if (activity.activityType == ActivityType.running &&
          _beats(activity, longestRun)) {
        longestRun = activity;
      }
      if (activity.activityType == ActivityType.cycling &&
          _beats(activity, longestRide)) {
        longestRide = activity;
      }
    }

    final windowDays = latest.difference(earliest).inDays + 1;
    final hasQualifyingLongSession =
        (longestRun != null && _durationOf(longestRun) >= longRunMinMinutes) ||
        (longestRide != null && _durationOf(longestRide) >= longRideMinMinutes);
    final isReliable =
        windowDays >= minWindowDays &&
        (usable.length >= minSessionCount || hasQualifyingLongSession);

    // Normalize load to a 7-day week so short-but-dense and long-but-sparse
    // windows compare on the same scale.
    final weeklyDurationHours =
        (totalMinutes / 60.0) * (7.0 / math.max(windowDays, 1));

    final pattern = _weekdayPattern(minutesByWeekday);

    return TrainingInsights(
      isReliable: isReliable,
      windowDays: windowDays,
      sessionCount: usable.length,
      weeklyDurationHours: (weeklyDurationHours * 10).round() / 10.0,
      longestRun: longestRun == null ? null : _toSession(longestRun),
      longestRide: longestRide == null ? null : _toSession(longestRide),
      heavyDayCount: trainingDays.length,
      heavyWeekdays: pattern.heavy,
      lightWeekdays: pattern.light,
    );
  }

  /// The two most- and two least-loaded weekdays by total imported minutes,
  /// each returned in weekday order (Monday-first). Needs at least
  /// [minWeekdaysForPattern] distinct weekdays represented — with fewer,
  /// "heavy" vs "light" is just noise — and with exactly that minimum the
  /// two groups are disjoint by construction (top 2 / bottom 2 of ≥4).
  static ({List<int> heavy, List<int> light}) _weekdayPattern(
    Map<int, int> minutesByWeekday,
  ) {
    if (minutesByWeekday.length < minWeekdaysForPattern) {
      return (heavy: const [], light: const []);
    }
    final byLoad = minutesByWeekday.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final heavy = byLoad.take(2).map((e) => e.key).toList()..sort();
    final light = byLoad.reversed.take(2).map((e) => e.key).toList()..sort();
    return (heavy: heavy, light: light);
  }

  /// Planned duration wins; completed actuals fill in when the plan had none
  /// (Runna ICS and completed Garmin activities both stay usable).
  static int _durationOf(Activity a) =>
      a.durationMinutes ?? a.actualDurationMinutes ?? 0;

  static bool _beats(Activity candidate, Activity? incumbent) =>
      incumbent == null || _durationOf(candidate) > _durationOf(incumbent);

  static InsightSession _toSession(Activity a) => InsightSession(
    activityType: a.activityType,
    durationMinutes: _durationOf(a),
    distanceMiles: a.distanceMiles ?? a.actualDistanceMiles,
    title: a.title,
    scheduledDateTime: a.scheduledDateTime,
  );
}
