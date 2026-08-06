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
}
