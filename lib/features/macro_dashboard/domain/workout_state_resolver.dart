/// The workout-card state derivation, extracted from
/// [MacroDashboardAssembler._workoutCard] so surfaces that need a state per
/// activity per arbitrary day (the home-shell calendar sheet's dot channel)
/// call the ONE derivation instead of copying it — the bug class the
/// home-shell handoff's producer/consumer inventory exists to stop.
///
/// Contract source: workout-card.md v3 states via the dashboard's two-time
/// model (the workout-card component spec under docs/ssot/spec/design/;
/// assembler header for the Q-D5/Q-D6/G6 rulings). Behavior is verbatim
/// from the assembler:
///  * done = status `completed` OR `actual_time` stamped; verified when a
///    platform summary id is present. Sync beats skip (G6).
///  * ACTIVE skip = status `skipped` (and not done).
///  * PASSIVE skip is DERIVED, never written: the day is past and the
///    workout has neither sync nor confirmation. The CURRENT day never
///    shows a passive skip (Q-D5).
library;

import '../../activities/domain/activity.dart';
import 'dashboard_models.dart';

/// Resolve the workout-card state of [a] as it reads on [day] (the day the
/// consuming surface renders it under — the dashboard's selected day, or a
/// calendar cell's own date), given the current wall clock [now].
WorkoutCardState resolveWorkoutCardState(
  Activity a, {
  required DateTime day,
  required DateTime now,
}) {
  // Two-time model: a card is done when the athlete confirmed it or a
  // sync stamped actual_time; verified when a platform stamped it. Sync
  // beats skip (G6): a matching sync writes actual_time + the summary id,
  // so a skipped row that syncs reads as DONE_VERIFIED here regardless of
  // what `status` says.
  final done = a.status == ActivityStatus.completed || a.actualTime != null;
  final verified = done && a.garminSummaryId != null;

  // SKIPPED — two triggers (Q-D6):
  //  ACTIVE  — status = 'skipped', written by the Skip press (allowed on
  //            the current day). Unskip / mark-done clear it.
  //  PASSIVE — the workout's day is past and it has neither sync nor
  //            confirmation. Derived, never written; the CURRENT day never
  //            shows a passive SKIPPED (the rejected same-day-22:00
  //            trigger must not exist — Q-D5).
  final skipActive = !done && a.status == ActivityStatus.skipped;
  final cellDay = DateTime(day.year, day.month, day.day);
  final today = DateTime(now.year, now.month, now.day);
  final dayPast = cellDay.isBefore(today);
  final skipPassive = !done && !skipActive && dayPast;

  return verified
      ? WorkoutCardState.doneVerified
      : done
      ? WorkoutCardState.doneConfirmed
      : (skipActive || skipPassive)
      ? WorkoutCardState.skipped
      : WorkoutCardState.planned;
}
