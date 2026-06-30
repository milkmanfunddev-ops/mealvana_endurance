import '../../activities/domain/activity.dart';
import '../../meal_logging/domain/meal_log.dart';

/// A single entry on the unified Fuel Timeline — either a logged meal or a
/// scheduled workout — placed on one chronological axis.
///
/// The screen is a flat, time-ordered feed (no fixed meal "slots"): the user
/// can log anything any number of times, and each entry sorts by [time].
sealed class TimelineNode {
  const TimelineNode();

  /// The instant this node occupies on the timeline, used for ordering and the
  /// left time-rail label.
  DateTime get time;

  /// Stable identity (the underlying meal/activity id) for keys + diffing.
  String get id;
}

/// A logged meal on the timeline.
///
/// Ordered by [MealLog.eatenAt] when present, falling back to
/// [MealLog.createdAt] so entries without an explicit eat-time still sort
/// sensibly.
class MealNode extends TimelineNode {
  const MealNode(this.meal);

  final MealLog meal;

  @override
  DateTime get time => meal.eatenAt ?? meal.createdAt;

  @override
  String get id => meal.id;
}

/// A scheduled workout on the timeline (the "ride" card in the prototype).
///
/// [burnKcal] is the session energy expenditure for this activity, supplied by
/// the caller (sourced from per-activity macro targets) — null when not yet
/// available, in which case no burn figure is shown.
class WorkoutNode extends TimelineNode {
  const WorkoutNode(this.activity, {this.burnKcal});

  final Activity activity;

  /// Session kcal for this workout, if known.
  final double? burnKcal;

  @override
  DateTime get time => activity.scheduledDateTime;

  @override
  String get id => activity.id;
}
