import '../../activities/domain/activity.dart';
import '../../events/domain/event.dart';
import '../../meal_logging/domain/meal_log.dart';
import '../../../shared/database/app_database.dart' show CarbLoadingDay;

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

/// The race/event itself on the day it falls.
///
/// Surfaces the event on the fuel timeline so a race day isn't invisible on the
/// home screen. Ordered by its start time when known, else the start of the
/// event date (so an all-day event sorts to the top of its day rather than
/// "now").
class EventNode extends TimelineNode {
  const EventNode(this.event, this.date);

  final Event event;

  /// The event's date-time on the timeline. Resolved by the caller from
  /// [Event.startTime] (precise) or [Event.eventDate] (midnight).
  final DateTime date;

  @override
  DateTime get time => date;

  @override
  String get id => 'event_${event.id}';
}

/// A carb-loading day (one row of a plan) on its date.
///
/// A whole-day target, not a point in time, so it sorts to the start of its day
/// (like an all-day banner) rather than to a clock time.
class CarbLoadingNode extends TimelineNode {
  const CarbLoadingNode(this.day, {this.totalDays});

  final CarbLoadingDay day;

  /// Total days in the parent plan, for a "Day 2 of 3" label. Null if unknown.
  final int? totalDays;

  @override
  DateTime get time =>
      DateTime(day.planDate.year, day.planDate.month, day.planDate.day);

  @override
  String get id => 'carb_${day.id}';
}
