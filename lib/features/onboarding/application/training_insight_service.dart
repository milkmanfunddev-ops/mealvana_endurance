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

  // Assumed paces for sessions a provider scheduled by DISTANCE alone.
  //
  // Final Surge deliberately writes `durationMinutes: null` whenever the
  // workout carries distance or pace (see
  // `FinalSurgeTransformer._getFallbackDurationMinutes`) and leaves the
  // estimate to the UI. A distance-prescribed plan ("8 mi easy") is the
  // normal shape of a running block, so treating those rows as zero-length
  // discarded entire imports: 21 synced workouts digested to nothing, and
  // the reveal claimed no sessions were found.
  //
  // These are coarse on purpose — they only need to rank days against each
  // other and clear the long-session bar, and the reveal's own copy quotes
  // distance ("your 15-mile long run"), never these minutes.
  static const double _runMinutesPerMile = 9.5;
  static const double _rideMinutesPerMile = 3.75; // ≈16 mph
  static const double _swimMinutesPerMile = 32.0; // ≈2:00 / 100 m

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

    if (usable.isEmpty) {
      // Still report what we were handed: "21 rows in, 0 usable" is a very
      // different bug from "0 rows in", and the reveal's diagnostic sheet
      // is where that gets told apart.
      return TrainingInsights(
        isReliable: false,
        windowDays: 0,
        sessionCount: 0,
        weeklyDurationHours: 0,
        rawActivityCount: activities.length,
      );
    }

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

    // Earliest first so the diagnostic sheet reads chronologically.
    final sessions = usable.map(_toSession).toList()
      ..sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));

    return TrainingInsights(
      isReliable: isReliable,
      windowDays: windowDays,
      windowStart: earliest,
      windowEnd: latest,
      sessionCount: usable.length,
      weeklyDurationHours: (weeklyDurationHours * 10).round() / 10.0,
      longestRun: longestRun == null ? null : _toSession(longestRun),
      longestRide: longestRide == null ? null : _toSession(longestRide),
      heavyDayCount: trainingDays.length,
      heavyWeekdays: pattern.heavy,
      lightWeekdays: pattern.light,
      sessions: sessions,
      rawActivityCount: activities.length,
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
  /// (Runna ICS and completed Garmin activities both stay usable); failing
  /// both, a distance-prescribed session is estimated from its distance so
  /// it still counts (see the pace constants above). 0 only when the row
  /// carries no usable signal at all.
  static int _durationOf(Activity a) {
    final explicit = a.durationMinutes ?? a.actualDurationMinutes;
    if (explicit != null && explicit > 0) return explicit;
    return _estimateMinutesFromDistance(a);
  }

  /// True when [_durationOf] had to fall back to a distance estimate —
  /// surfaced in the reveal's diagnostic sheet so an estimated minute count
  /// is never mistaken for one the provider actually sent.
  static bool _isEstimated(Activity a) {
    final explicit = a.durationMinutes ?? a.actualDurationMinutes;
    return (explicit == null || explicit <= 0) &&
        _estimateMinutesFromDistance(a) > 0;
  }

  static int _estimateMinutesFromDistance(Activity a) {
    final miles = a.distanceMiles ?? a.actualDistanceMiles;
    if (miles == null || miles <= 0) return 0;

    final double minutesPerMile;
    switch (a.activityType) {
      case ActivityType.cycling:
        minutesPerMile = _rideMinutesPerMile;
      case ActivityType.swimming:
        minutesPerMile = _swimMinutesPerMile;
      case ActivityType.running:
      case ActivityType.triathlon:
      case ActivityType.duathlon:
      case ActivityType.multisport:
      case ActivityType.brick:
      case ActivityType.other:
        // Mixed-discipline distances are dominated by their run/ride legs;
        // the run pace is the safer of the two (it never over-counts a
        // day's load the way a 16 mph assumption would).
        minutesPerMile = _runMinutesPerMile;
    }
    return (miles * minutesPerMile).round();
  }

  static bool _beats(Activity candidate, Activity? incumbent) =>
      incumbent == null || _durationOf(candidate) > _durationOf(incumbent);

  static InsightSession _toSession(Activity a) => InsightSession(
    activityType: a.activityType,
    durationMinutes: _durationOf(a),
    durationIsEstimated: _isEstimated(a),
    distanceMiles: a.distanceMiles ?? a.actualDistanceMiles,
    title: a.title,
    scheduledDateTime: a.scheduledDateTime,
  );
}
