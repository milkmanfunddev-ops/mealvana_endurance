/// What Vana has to say before she is asked (vana-moment spec, PROPOSED v1).
///
/// The trigger set is fuelling windows only, decided on the device from rows
/// it already holds: the pre-workout moment (M-1), the recovery moment (M-2),
/// and the Cadence (one at a time, at most two rings a day).
library;

import '../../../shared/domain/activity_type.dart';
import '../../activities/domain/activity.dart';
import '../../meal_logging/domain/meal_log.dart';
import '../../nutrition_plan/domain/fueling_window_authority.dart';
import '../../nutrition_plan/domain/intensity_distribution.dart';
import '../../nutrition_plan/domain/recovery_window_authority.dart';
import 'vana_exchange.dart';

/// Which moment. Each is a to-do or news (its tone), and has a topic the
/// sheet's chip names.
enum VanaMomentKind {
  /// M-1: a workout's pre-workout window has opened and nothing is logged.
  preWorkout('pre_workout', toDo: true, topic: VanaExchangeTopic.fuelPlan),

  /// M-2: a session has finished, its recovery window is open and nothing is
  /// logged since it ended.
  recovery('recovery', toDo: true, topic: VanaExchangeTopic.fuelPlan);

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

/// Cadence: at most this many rings a day. A moment that would be the next
/// one is not raised at all.
const vanaMomentRingsPerDay = 2;

/// One live moment: the workout it is about and its window.
class VanaMoment {
  const VanaMoment({
    required this.kind,
    required this.activityId,
    required this.title,
    required this.activityType,
    required this.startsAt,
    required this.windowOpensAt,
    required this.closesAt,
    required this.rings,
    this.recovery,
  });

  final VanaMomentKind kind;
  final String activityId;
  final String title;
  final ActivityType activityType;

  /// The workout's start, local wall clock.
  final DateTime startsAt;

  /// When the moment's window opened, local wall clock: before the start for
  /// M-1, the session's end for M-2.
  final DateTime windowOpensAt;

  /// When the moment's window closes: the start for M-1, the end of the
  /// recovery window for M-2. Of two live moments, the one that closes
  /// sooner wins.
  final DateTime closesAt;

  /// Whether this moment has yet to ring: each workout and window speaks once.
  final bool rings;

  /// M-2 only: how urgent the recovery is, and the next session behind it.
  final VanaRecovery? recovery;

  /// The window's length in minutes: before the start for M-1, after the end
  /// for M-2.
  int get windowMinutes => closesAt.difference(windowOpensAt).inMinutes;

  /// Before noon is the morning; from 17:00 it is the evening.
  VanaMomentPartOfDay get partOfDay => startsAt.hour < 12
      ? VanaMomentPartOfDay.morning
      : startsAt.hour < 17
      ? VanaMomentPartOfDay.afternoon
      : VanaMomentPartOfDay.evening;

  /// One workout and one window. Moving a planned workout makes a new
  /// pre-workout key, which rings again. A finished session has one recovery,
  /// whatever its measured end: Garmin refining a marked-done session keeps
  /// the key.
  String get key => switch (kind) {
    VanaMomentKind.preWorkout =>
      '${kind.wire}:$activityId:${windowOpensAt.toIso8601String()}',
    VanaMomentKind.recovery => '${kind.wire}:$activityId',
  };

  VanaMoment _rung() => VanaMoment(
    kind: kind,
    activityId: activityId,
    title: title,
    activityType: activityType,
    startsAt: startsAt,
    windowOpensAt: windowOpensAt,
    closesAt: closesAt,
    rings: false,
    recovery: recovery,
  );

  /// What the chat body carries to name the moment.
  Map<String, Object?> toWire() => {
    'kind': kind.wire,
    'activity_id': activityId,
    'window_minutes': windowMinutes,
    ...?recovery?.toWire(),
  };
}

/// What an M-2 moment says about urgency (post-workout.md): its branch, and
/// the next fuel-demanding session when it is close enough to name. That is
/// under 8 h for an urgent recovery, and 8 to under 24 h for a relaxed one,
/// whose copy leans toward "earlier rather than later today".
class VanaRecovery {
  const VanaRecovery({required this.branch, this.nextActivityId});

  final RecoveryBranch branch;
  final String? nextActivityId;

  Map<String, Object?> toWire() => {
    'branch': branch.name,
    if (nextActivityId != null) 'next_activity_id': nextActivityId,
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

/// When a finished session ended, local wall clock: its start (the measured
/// one, else the planned slot mark-done confirms) plus its length (measured,
/// else planned). Null with no length.
DateTime? sessionEndedAt(Activity activity) {
  final minutes = _sessionMinutes(activity);
  if (minutes == null) return null;
  return _sessionStart(activity).add(Duration(minutes: minutes));
}

/// A finished session's start: measured, else the planned slot mark-done
/// confirms.
DateTime _sessionStart(Activity activity) =>
    activity.actualTime ?? activity.scheduledDateTime;

/// A finished session's length: measured, else planned.
int? _sessionMinutes(Activity activity) =>
    activity.actualDurationMinutes ?? activity.durationMinutes;

/// At most one live moment at [now], from today's [activities] and
/// [mealLogs]. [rung] and [answered] are the keys of moments that have rung
/// or been answered today.
///
/// M-1 is raised by a planned workout today whose window has opened and
/// which has not started, when no meal log was eaten (or, with no eaten
/// time, written) at or after the window opened. It retires when the
/// workout starts, something is logged in the window, or it is answered.
///
/// M-2 is raised by a fuel-demanding session today that is completed (marked
/// done, or matched from Garmin or an import) while its recovery window is
/// open and nothing is logged since it ended. The window is the recovery
/// authority's: 4 h when a fuel-demanding session starts under 8 h after the
/// end, else 2 h. It retires when the window closes, something is logged, or
/// it is answered.
///
/// One at a time: the live moment whose window closes sooner. A moment that
/// has not rung is not raised once [vanaMomentRingsPerDay] have rung today.
VanaMoment? resolveVanaMoment({
  required DateTime now,
  required List<Activity> activities,
  required List<MealLog> mealLogs,
  Set<String> rung = const {},
  Set<String> answered = const {},
}) {
  bool fedSince(DateTime from) => mealLogs.any(
    (log) => !log.isDeleted && !(log.eatenAt ?? log.createdAt).isBefore(from),
  );
  final live = <VanaMoment>[];
  for (final activity in activities) {
    if (activity.deletedAt != null || activity.activityType.isImportOnly) {
      continue;
    }
    final moment = switch (activity.status) {
      ActivityStatus.planned => _preWorkout(activity, now),
      ActivityStatus.completed => _recovery(activity, activities, now),
      _ => null,
    };
    if (moment == null || fedSince(moment.windowOpensAt)) continue;
    if (answered.contains(moment.key)) continue;
    if (rung.contains(moment.key)) {
      live.add(moment._rung());
    } else if (rung.length < vanaMomentRingsPerDay) {
      live.add(moment);
    }
  }
  if (live.isEmpty) return null;
  live.sort((a, b) => a.closesAt.compareTo(b.closesAt));
  return live.first;
}

/// Whether a moment could still be raised or retire today by the clock
/// alone: a planned workout today has yet to start, or a finished one's
/// recovery window has yet to close. While one can, the clock is worth
/// watching.
bool vanaMomentClockMatters({
  required DateTime now,
  required List<Activity> activities,
}) => activities.any((a) {
  if (a.deletedAt != null || a.activityType.isImportOnly) return false;
  return switch (a.status) {
    ActivityStatus.planned =>
      _sameDay(a.scheduledDateTime, now) && now.isBefore(a.scheduledDateTime),
    ActivityStatus.completed =>
      _sameDay(_sessionStart(a), now) &&
          (_recoveryAfter(a, activities)?.closesAt.isAfter(now) ?? false),
    _ => false,
  };
});

VanaMoment? _preWorkout(Activity activity, DateTime now) {
  final startsAt = activity.scheduledDateTime;
  if (!_sameDay(startsAt, now) || !now.isBefore(startsAt)) return null;
  final opensAt = startsAt.subtract(
    Duration(minutes: preWorkoutWindowMinutes(activity)),
  );
  if (now.isBefore(opensAt)) return null;
  return VanaMoment(
    kind: VanaMomentKind.preWorkout,
    activityId: activity.id,
    title: activity.title,
    activityType: activity.activityType,
    startsAt: startsAt,
    windowOpensAt: opensAt,
    closesAt: startsAt,
    rings: true,
  );
}

VanaMoment? _recovery(
  Activity activity,
  List<Activity> activities,
  DateTime now,
) {
  final startsAt = _sessionStart(activity);
  if (!_sameDay(startsAt, now)) return null;
  final window = _recoveryAfter(activity, activities);
  if (window == null) return null;
  if (now.isBefore(window.opensAt) || !now.isBefore(window.closesAt)) {
    return null;
  }
  return VanaMoment(
    kind: VanaMomentKind.recovery,
    activityId: activity.id,
    title: activity.title,
    activityType: activity.activityType,
    startsAt: startsAt,
    windowOpensAt: window.opensAt,
    closesAt: window.closesAt,
    rings: true,
    recovery: window.recovery,
  );
}

/// The recovery window after a finished, fuel-demanding [activity], from the
/// recovery authority; null for any other session.
({DateTime opensAt, DateTime closesAt, VanaRecovery recovery})? _recoveryAfter(
  Activity activity,
  List<Activity> activities,
) {
  final minutes = _sessionMinutes(activity);
  if (minutes == null ||
      !isFuelDemandingSession(
        type: activity.activityType,
        durationMinutes: minutes,
      )) {
    return null;
  }
  final endedAt = _sessionStart(activity).add(Duration(minutes: minutes));
  Activity? next;
  for (final a in activities) {
    if (a.status != ActivityStatus.planned || a.deletedAt != null) continue;
    if (a.scheduledDateTime.isBefore(endedAt)) continue;
    if (!isFuelDemandingSession(
      type: a.activityType,
      durationMinutes: a.durationMinutes,
    )) {
      continue;
    }
    if (next == null || a.scheduledDateTime.isBefore(next.scheduledDateTime)) {
      next = a;
    }
  }
  final toNext = next?.scheduledDateTime.difference(endedAt);
  final branch = recoveryBranch(toNext);
  final named = branch == RecoveryBranch.urgent || recoveryCopySoftened(toNext);
  return (
    opensAt: endedAt,
    closesAt: endedAt.add(recoveryWindow(branch)),
    recovery: VanaRecovery(
      branch: branch,
      nextActivityId: named ? next!.id : null,
    ),
  );
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
