/// What Vana has to say before she is asked (vana-moment spec, PROPOSED v1).
///
/// The trigger set is fuelling windows only, decided on the device from rows
/// it already holds. This file is the pre-workout moment (M-1); the recovery
/// moment (M-2) and the two-a-day cap follow.
library;

import '../../../shared/domain/activity_type.dart';
import '../../activities/domain/activity.dart';
import '../../meal_logging/domain/meal_log.dart';
import '../../nutrition_plan/domain/fueling_window_authority.dart';
import '../../nutrition_plan/domain/intensity_distribution.dart';
import 'vana_exchange.dart';

/// Which moment. Each is a to-do or news (its tone), and has a topic the
/// sheet's chip names.
enum VanaMomentKind {
  /// M-1: a workout's pre-workout window has opened and nothing is logged.
  preWorkout('pre_workout', toDo: true, topic: VanaExchangeTopic.fuelPlan);

  const VanaMomentKind(this.wire, {required this.toDo, required this.topic});

  /// The name the chat body carries.
  final String wire;

  /// A to-do (`orange`, with a pill) rather than news (`electrolyte`).
  final bool toDo;

  /// What the exchange the moment opens is about.
  final VanaExchangeTopic topic;
}

/// When in the day a session starts, for the words that name it ("this
/// morning's run", "tonight's run").
enum VanaMomentPartOfDay { morning, afternoon, evening }

/// How the launcher shows a live moment, in order: it rings once, a to-do
/// shows its pill, then the launcher stays tinted until the moment retires.
enum VanaMomentPhase {
  /// Raised, and waiting for a launcher on screen to ring on.
  waiting,
  ring,
  pill,
  tinted,
}

/// The export's timings: the ring runs about 2 s, the pill about 4 s.
const vanaMomentRingDuration = Duration(seconds: 2);
const vanaMomentPillDuration = Duration(seconds: 4);

/// One live moment: the workout it is about and its window.
class VanaMoment {
  const VanaMoment({
    required this.kind,
    required this.activityId,
    required this.title,
    required this.activityType,
    required this.startsAt,
    required this.windowOpensAt,
    required this.rings,
  });

  final VanaMomentKind kind;
  final String activityId;
  final String title;
  final ActivityType activityType;

  /// The workout's start, local wall clock.
  final DateTime startsAt;

  /// When the pre-workout window opened, local wall clock.
  final DateTime windowOpensAt;

  /// Whether this moment has yet to ring: each workout and window speaks once.
  final bool rings;

  /// The window, in minutes before the start.
  int get windowMinutes => startsAt.difference(windowOpensAt).inMinutes;

  /// Before noon is the morning; from 17:00 it is the evening.
  VanaMomentPartOfDay get partOfDay => startsAt.hour < 12
      ? VanaMomentPartOfDay.morning
      : startsAt.hour < 17
      ? VanaMomentPartOfDay.afternoon
      : VanaMomentPartOfDay.evening;

  /// When the moment's window closes. Of two live moments, the one that
  /// closes sooner wins.
  DateTime get closesAt => startsAt;

  /// One workout and one window. Moving the workout makes a new key, which
  /// rings again.
  String get key =>
      '${kind.wire}:$activityId:${windowOpensAt.toIso8601String()}';

  VanaMoment _rung() => VanaMoment(
    kind: kind,
    activityId: activityId,
    title: title,
    activityType: activityType,
    startsAt: startsAt,
    windowOpensAt: windowOpensAt,
    rings: false,
  );

  /// What the chat body carries to name the moment.
  Map<String, Object?> toWire() => {
    'kind': kind.wire,
    'activity_id': activityId,
    'window_minutes': windowMinutes,
  };
}

/// The pre-workout window of [activity], in minutes: the window stored on it
/// (the create flow's default from the fuelling-window authority, or the
/// athlete's own adjustment), else the authority's default for the session,
/// given the gap between when it was planned and its start, as the create
/// flow gives it.
int preWorkoutWindowMinutes(Activity activity) {
  final stored = activity.timeBeforeMinutes;
  if (stored != null && stored > 0) return stored;
  final start = activity.scheduledDateTime;
  final gap = start.difference(activity.createdAt).inMinutes;
  return defaultFuelingWindowMinutes(
    // An unknown duration takes the table's shortest row.
    durationMinutes: activity.durationMinutes ?? 0,
    intensity:
        activity.intensityDistribution ??
        IntensityDistribution.defaultDistribution(),
    startHour: start.hour,
    minutesUntilStart: gap < 0 ? 0 : gap,
  );
}

/// At most one live moment at [now], from today's [activities] and
/// [mealLogs]. [rung] and [answered] are the keys of moments that have rung
/// or been answered today.
///
/// M-1 is raised by a planned workout today whose window has opened and
/// which has not started, when no meal log was eaten (or, with no eaten
/// time, written) at or after the window opened. It retires when the
/// workout starts, something is logged in the window, or it is answered.
VanaMoment? resolveVanaMoment({
  required DateTime now,
  required List<Activity> activities,
  required List<MealLog> mealLogs,
  Set<String> rung = const {},
  Set<String> answered = const {},
}) {
  final live = <VanaMoment>[];
  for (final activity in activities) {
    if (activity.status != ActivityStatus.planned) continue;
    if (activity.deletedAt != null || activity.activityType.isImportOnly) {
      continue;
    }
    final startsAt = activity.scheduledDateTime;
    if (!_sameDay(startsAt, now) || !now.isBefore(startsAt)) continue;
    final opensAt = startsAt.subtract(
      Duration(minutes: preWorkoutWindowMinutes(activity)),
    );
    if (now.isBefore(opensAt)) continue;
    final fed = mealLogs.any(
      (log) =>
          !log.isDeleted && !(log.eatenAt ?? log.createdAt).isBefore(opensAt),
    );
    if (fed) continue;
    final moment = VanaMoment(
      kind: VanaMomentKind.preWorkout,
      activityId: activity.id,
      title: activity.title,
      activityType: activity.activityType,
      startsAt: startsAt,
      windowOpensAt: opensAt,
      rings: true,
    );
    if (answered.contains(moment.key)) continue;
    live.add(rung.contains(moment.key) ? moment._rung() : moment);
  }
  if (live.isEmpty) return null;
  live.sort((a, b) => a.closesAt.compareTo(b.closesAt));
  return live.first;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
