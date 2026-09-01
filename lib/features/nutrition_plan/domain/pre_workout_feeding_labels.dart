/// Display labels for the pre-workout (BEFORE) feeding cards.
///
/// Pure functions, spec-settled — not a product decision. The ratified design
/// (docs/pre-workout-macro.html, digest §5) names the three feedings and gives
/// each a window line; the SSOT reference implementation
/// (docs/ssot/spec/fueling/pre-workout-ui.html, `whens=`) derives the same
/// windows client-side from the tier alone plus whether a meal tier exists:
///
/// * meal    → "FINISH BY 2H OUT" (ratified mockup copy)
/// * snack   → "2H TO 30 MIN OUT" when a meal tier exists,
///             "NOW – 30 MIN OUT" when it doesn't
/// * top_up  → "LAST 30 MIN"
///
/// The engine emits no window strings (and no `renderAs`) — deriving them here
/// is the consumer's job.
library;

import 'package:mealvana_endurance/shared/domain/activity_type.dart';

/// Title for a feeding card, sport-aware where the sport is cheaply available.
///
/// The ratified design says "Pre-Run Meal" for running; cycling reads
/// "Pre-Ride Meal"; every other sport (and an unknown sport — pass `null`)
/// falls back to the generic "Pre-Workout Meal".
String preWorkoutFeedingTitle(String subPhaseType, {ActivityType? sport}) {
  switch (subPhaseType) {
    case 'meal':
      switch (sport) {
        case ActivityType.running:
          return 'Pre-Run Meal';
        case ActivityType.cycling:
          return 'Pre-Ride Meal';
        default:
          return 'Pre-Workout Meal';
      }
    case 'snack':
      return 'Pre-Workout Snack';
    case 'top_up':
      return 'Top-Off';
    default:
      return subPhaseType;
  }
}

/// The small uppercase window line under a feeding-card title, or `null` for
/// an unrecognised sub-phase type (render no line rather than a wrong one).
///
/// [hasMealTier] — whether the plan carries a meal tier at all; it moves the
/// snack window's near edge from "2h out" to "now".
String? preWorkoutWindowLabel(
  String subPhaseType, {
  required bool hasMealTier,
}) {
  switch (subPhaseType) {
    case 'meal':
      return 'FINISH BY 2H OUT';
    case 'snack':
      return hasMealTier ? '2H TO 30 MIN OUT' : 'NOW – 30 MIN OUT';
    case 'top_up':
      return 'LAST 30 MIN';
    default:
      return null;
  }
}
