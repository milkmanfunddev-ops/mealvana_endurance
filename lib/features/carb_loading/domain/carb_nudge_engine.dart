/// G27 — the race-window carb-load nudge (carb-loading@v1.1 rider, CE-11;
/// qa 9b15fcc). Pure math and register copy for the scheduled local
/// notification: DAILY at 06:00 local, raceDate−3 through raceDate−1
/// inclusive — at most three fires, NEVER race day (nothing is choosable
/// there per CE-8). 06:00 aligns the nudge with the ruled breakfast window
/// opening — the same instant a loading day starts owing carbs (rev. 2,
/// qa 61c881c). A conscious partial reversal of Q-CE6's exclusion: this
/// one nudge exists; the broader reminder system stays deferred.
class CarbNudgeEngine {
  const CarbNudgeEngine._();

  /// Local fire hour (06:00 — the breakfast window's opening tick).
  static const int fireHour = 6;

  /// Days before race day that carry a fire: −3 … −1. Race day itself is
  /// excluded BY CONSTRUCTION — never add 0 to this list.
  static const List<int> windowDaysBefore = [3, 2, 1];

  /// CE-11 register copy, VERBATIM. No edits without a register change.
  static const String title = 'Fuel up for race day';

  /// CE-11 register copy, VERBATIM ({event} substituted).
  static String body(String eventName) =>
      'Your carb load for $eventName can start now — set up your plan.';

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Every fire instant for [raceDate]: 06:00 local on race−3 … race−1.
  static List<DateTime> allFires(DateTime raceDate) {
    final race = _dateOnly(raceDate);
    return [
      for (final daysBefore in windowDaysBefore)
        race
            .subtract(Duration(days: daysBefore))
            .add(const Duration(hours: fireHour)),
    ];
  }

  /// The fires still ahead of [now] — a mid-window arrival (app installed or
  /// event synced after the window opened) schedules ONLY these.
  static List<DateTime> remainingFires({
    required DateTime raceDate,
    required DateTime now,
  }) => allFires(raceDate).where((t) => t.isAfter(now)).toList();

  /// Whether [now]'s date sits inside the nudge window [race−3, race−1].
  /// False on race day and after.
  static bool inWindow({required DateTime raceDate, required DateTime now}) {
    final today = _dateOnly(now);
    final race = _dateOnly(raceDate);
    final daysUntil = race.difference(today).inDays;
    return daysUntil >= 1 && daysUntil <= windowDaysBefore.length;
  }

  /// Today's scheduled fire instant, or null when today is outside the
  /// window (used by the on-open catch-up's same-day dedupe).
  static DateTime? todayFire({
    required DateTime raceDate,
    required DateTime now,
  }) {
    if (!inWindow(raceDate: raceDate, now: now)) return null;
    return _dateOnly(now).add(const Duration(hours: fireHour));
  }

  /// Stable per-event-per-slot notification id (positive 31-bit).
  static int notificationId(String eventId, int daysBefore) =>
      ('carb_nudge:$eventId:$daysBefore').hashCode & 0x7fffffff;

  /// All ids for [eventId] — cancel this set to disarm the event.
  static List<int> allNotificationIds(String eventId) => [
    for (final daysBefore in windowDaysBefore)
      notificationId(eventId, daysBefore),
  ];

  /// The tap payload; parseTypedNotificationPayload splits it back into
  /// (type: carb_event, activityId: eventId) and the root widget routes to
  /// the event details screen.
  static String payload(String eventId) => 'carb_event:$eventId';

  /// Days-before slot for a fire instant (inverse of [allFires]).
  static int daysBeforeFor({
    required DateTime raceDate,
    required DateTime fireAt,
  }) => _dateOnly(raceDate).difference(_dateOnly(fireAt)).inDays;
}
