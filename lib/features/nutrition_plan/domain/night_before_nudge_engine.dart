import '../../../shared/domain/activity_type.dart';

/// The night-before long-workout nudge — pure rules and copy.
///
/// RULED 2026-09-30 (Xuan). The durable parts, which do not change without a
/// re-ruling:
///   - LONG means planned/estimated duration **>= 90 minutes**.
///   - It fires at **19:00 local the evening before** the workout.
///   - It is **skipped entirely** when a fuelling plan already exists for that
///     workout. No variant, no nag.
///   - The tap payload carries the INTENT `plan_workout:[activityId]`, routed
///     through `notification_intent_routes.dart`.
///
/// The COPY is approved "for now" and is explicitly revisable without a
/// re-ratification — which is why it sits here as a named constant rather than
/// being spelled inline at the call site.
///
/// Why the numbers live in one place: the fire hour and the 90-minute
/// threshold are the two things a later ruling is most likely to move, and a
/// scheduled local notification carries whatever it was built with until it
/// fires. Anything read from here is at least readable in one place when the
/// ruling moves.
class NightBeforeNudgeEngine {
  const NightBeforeNudgeEngine._();

  /// A workout is LONG at or above this planned duration. Inclusive.
  static const int longThresholdMinutes = 90;

  /// Local fire hour, the evening before the workout.
  static const int fireHour = 19;

  /// Approved copy, 2026-09-30, cheerful register.
  ///
  /// The ruling approved one sentence: "Long run tomorrow — [duration]
  /// planned. Set your fueling plan tonight." A notification needs a title and
  /// a body, so the em-dash is the split: every word survives, and iOS renders
  /// the two lines the way the sentence reads.
  ///
  /// SPORT-AWARE, ruled 2026-09-30 (second pass): "long run / long ride /
  /// brick workout instead of a generic name". The trigger is DURATION, not
  /// sport, so a fixed "Long run" announced a 2-hour ride as a run — that was
  /// the bug this replaces. The neutral fallback is never wrong, which is why
  /// anything unmapped lands there rather than guessing a sport.
  static String titleFor(ActivityType? type) {
    switch (type) {
      case ActivityType.running:
        return 'Long run tomorrow';
      case ActivityType.cycling:
        return 'Long ride tomorrow';
      case ActivityType.swimming:
        return 'Long swim tomorrow';
      case ActivityType.brick:
      case ActivityType.multisport:
        return 'Brick workout tomorrow';
      // triathlon and duathlon are deliberately NOT called bricks: the ruling
      // named brick/multi-sport, and a race is not a brick workout. They take
      // the neutral title until someone rules otherwise.
      case ActivityType.triathlon:
      case ActivityType.duathlon:
      case ActivityType.other:
      case null:
        return 'Long workout tomorrow';
    }
  }

  /// Approved copy, 2026-09-30. [duration] is [formatDuration]'s output.
  static String body(String duration) =>
      '$duration planned. Set your fueling plan tonight.';

  /// `2 h 15 m`, per the ruling's example. A whole hour drops the empty
  /// minutes rather than reading "2 h 0 m".
  static String formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m m';
    if (m == 0) return '$h h';
    return '$h h $m m';
  }

  /// Is this workout long enough to nudge for?
  ///
  /// A missing duration is NOT long: an activity with no planned duration
  /// cannot be asserted to be over 90 minutes, and guessing here would nudge
  /// people about easy workouts, which is how a nudge gets muted.
  static bool isLong(int? durationMinutes) =>
      durationMinutes != null && durationMinutes >= longThresholdMinutes;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 19:00 local on the day BEFORE [workoutStart]'s local date.
  ///
  /// Derived from the workout's calendar date, not by subtracting 24h: a
  /// 06:00 workout and a 22:00 workout on the same day share one nudge the
  /// evening before, and a subtraction would put the first one's nudge at
  /// 06:00 the previous morning.
  static DateTime fireInstantFor(DateTime workoutStart) => _dateOnly(
    workoutStart,
  ).subtract(const Duration(days: 1)).add(const Duration(hours: fireHour));

  /// Whether the fire instant for [workoutStart] is still ahead of [now].
  /// A workout whose evening has already passed is never back-scheduled.
  static bool isFireAhead({
    required DateTime workoutStart,
    required DateTime now,
  }) => fireInstantFor(workoutStart).isAfter(now);

  /// The tap payload. `parseTypedNotificationPayload` splits it back into
  /// (type: plan_workout, activityId), and the intent table routes it.
  static String payload(String activityId) => 'plan_workout:$activityId';

  /// Stable per-activity id, so re-arming replaces rather than duplicates.
  /// Distinct from the carb nudge's ids by the prefix in the hashed string.
  static int notificationId(String activityId) =>
      ('night_before_nudge:$activityId').hashCode & 0x7fffffff;
}
