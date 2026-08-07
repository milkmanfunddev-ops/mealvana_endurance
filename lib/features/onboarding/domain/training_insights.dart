import '../../../shared/domain/activity_type.dart';

/// One notable session surfaced by the insight engine (e.g. the athlete's
/// longest run), used to personalize the plan reveal.
class InsightSession {
  const InsightSession({
    required this.activityType,
    required this.durationMinutes,
    this.distanceMiles,
    this.title,
    required this.scheduledDateTime,
  });

  final ActivityType activityType;
  final int durationMinutes;
  final double? distanceMiles;
  final String? title;
  final DateTime scheduledDateTime;

  /// Human line for the reveal/daily screens, e.g.
  /// "your 15-mile long run" / "your 2 h 30 m long ride".
  String get descriptor {
    final noun = activityType == ActivityType.cycling
        ? 'long ride'
        : 'long run';
    final miles = distanceMiles;
    if (miles != null && miles >= 1) {
      final rounded = miles.round();
      return 'your $rounded-mile $noun';
    }
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    final duration = h > 0 ? (m > 0 ? '$h h $m m' : '$h-hour') : '$m-minute';
    return 'your $duration $noun';
  }
}

/// Digest of the workouts imported during onboarding, produced by
/// TrainingInsightService. Feeds PlanPreviewService when [isReliable].
class TrainingInsights {
  const TrainingInsights({
    required this.isReliable,
    required this.windowDays,
    required this.sessionCount,
    required this.weeklyDurationHours,
    this.longestRun,
    this.longestRide,
    this.heavyDayCount = 0,
    this.heavyWeekdays = const [],
    this.lightWeekdays = const [],
  });

  /// An empty, unreliable digest (no import / nothing usable).
  static const none = TrainingInsights(
    isReliable: false,
    windowDays: 0,
    sessionCount: 0,
    weeklyDurationHours: 0,
  );

  /// True when the imported window passes the intake reliability gate
  /// (≥7-day span and enough sessions) — only then may the preview
  /// personalize from this data.
  final bool isReliable;

  /// Span in whole days between the earliest and latest imported session.
  final int windowDays;

  final int sessionCount;

  /// Total training hours normalized to a 7-day week (drives NEAT tiering).
  final double weeklyDurationHours;

  final InsightSession? longestRun;
  final InsightSession? longestRide;

  /// Days in the window with ≥1 qualifying session (the workout-day pattern).
  final int heavyDayCount;

  /// The most- and least-loaded weekdays in the imported window
  /// ([DateTime.monday]..[DateTime.sunday], ascending), surfaced on the
  /// plan-reveal "we read your plan" card. Empty when the window doesn't
  /// cover enough distinct weekdays to say anything meaningful — see
  /// `TrainingInsightService.minWeekdaysForPattern`.
  final List<int> heavyWeekdays;
  final List<int> lightWeekdays;

  static const _weekdayNames = {
    DateTime.monday: 'Monday',
    DateTime.tuesday: 'Tuesday',
    DateTime.wednesday: 'Wednesday',
    DateTime.thursday: 'Thursday',
    DateTime.friday: 'Friday',
    DateTime.saturday: 'Saturday',
    DateTime.sunday: 'Sunday',
  };

  static String _names(List<int> weekdays) =>
      weekdays.map((d) => _weekdayNames[d]!).join(', ');

  /// "Saturday, Sunday" — null when [heavyWeekdays] is empty.
  String? get heavyDayNames =>
      heavyWeekdays.isEmpty ? null : _names(heavyWeekdays);

  /// "Monday, Friday" — null when [lightWeekdays] is empty.
  String? get lightDayNames =>
      lightWeekdays.isEmpty ? null : _names(lightWeekdays);

  /// Whether there's a heavy/light weekday pattern to show at all.
  bool get hasWeekdayPattern => heavyWeekdays.isNotEmpty && lightWeekdays.isNotEmpty;
}
