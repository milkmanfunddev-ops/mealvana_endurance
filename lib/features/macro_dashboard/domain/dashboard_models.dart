/// Presentation models for the macro dashboard surface.
///
/// Design SSOT: docs/ssot/spec/design/ (tokens.md, components/workout-card.md,
/// components/energy-card.md, surfaces/macro-dashboard.md). Numbers authority:
/// docs/ssot/spec/daily-macros/intraday-display.md — these models carry
/// already-derived quantities; they invent no arithmetic (P-3/S-3).
library;

/// The workout card's state machine — exactly one state at a time
/// (workout-card.md, states table).
enum WorkoutCardState {
  /// Dashed outline, dimmed fill, no solid border. Chip: `Planned`.
  planned,

  /// Solid fill, solid border. Chip: `self-reported`.
  doneConfirmed,

  /// Solid fill, solid border, icon disc in electrolyte.
  /// Chip: `✓ verified · <platform>`. The done gesture is SUPPRESSED (G3).
  doneVerified,

  /// Planned treatment DRAINED TO NEUTRAL (dotted outline, dimmed fill,
  /// icon/chip/kcal in dimmed cream — no electrolyte, no orange anywhere).
  /// Chip: `Skipped`. Two triggers (Q-D6): PASSIVE — the day is past and the
  /// workout has neither sync nor confirmation (derived, never written);
  /// ACTIVE — the athlete pressed Skip (status = 'skipped'). The card is
  /// identical either way; only [WorkoutCardData.skipActive] differs.
  skipped,
}

/// One workout card's render data.
class WorkoutCardData {
  const WorkoutCardData({
    required this.activityId,
    required this.name,
    required this.timeLabel,
    required this.metaLabel,
    required this.kcal,
    required this.state,
    required this.sport,
    this.verifiedSourceName = 'Garmin',
    this.skipActive = false,
    this.markDoneAllowed = true,
  });

  final String activityId;
  final String name;

  /// Displayed time — `actual_time ?? planned_time` (two-time model).
  final String timeLabel;

  /// e.g. "2,000 yd · 40 min" or "90 min".
  final String metaLabel;
  final double kcal;
  final WorkoutCardState state;

  /// 'running' | 'cycling' | 'swimming' | 'strength' — picks the icon.
  final String sport;

  /// Platform that verified the workout ("Garmin", "TrainingPeaks").
  final String verifiedSourceName;

  /// True when [state] is [WorkoutCardState.skipped] because the athlete
  /// pressed Skip (`status = 'skipped'` on the row) — the left-swipe reveal
  /// then offers Unskip. A PASSIVE skip (past day, unresolved) is derived and
  /// has nothing to un-skip: its reveal carries no button (G4).
  final bool skipActive;

  /// False when the card's day is in the FUTURE: a workout that hasn't
  /// happened yet cannot be confirmed done (ruled 2026-08-18 — the athlete
  /// who does tomorrow's session today creates today's workout and skips
  /// tomorrow's). G1 is suppressed like G3: no reveal, token nudge only.
  /// Skip (G4/G5) stays available on any non-verified card.
  final bool markDoneAllowed;

  bool get isVerified => state == WorkoutCardState.doneVerified;
  bool get isDone =>
      state == WorkoutCardState.doneConfirmed ||
      state == WorkoutCardState.doneVerified;
  bool get isSkipped => state == WorkoutCardState.skipped;

  /// A SKIPPED workout's kcal and fuel appear in NO surface figure for its
  /// day (Q-D5/Q-D6, surface S-2) — passive and active alike.
  bool get counts => !isSkipped;

  String get chipLabel => switch (state) {
        WorkoutCardState.doneVerified => 'verified · $verifiedSourceName',
        WorkoutCardState.doneConfirmed => 'self-reported',
        WorkoutCardState.planned => 'Planned',
        WorkoutCardState.skipped => 'Skipped',
      };
}

/// One logged (or suggested) meal item.
class MealItemData {
  const MealItemData({
    required this.id,
    required this.name,
    required this.kcal,
    required this.carbsG,
    required this.proteinG,
    required this.fatG,
    this.suggested = false,
    this.planned = false,
  });

  final String id;
  final String name;
  final double kcal;
  final double carbsG;
  final double proteinG;
  final double fatG;
  final bool suggested;

  /// Scheduled but not yet eaten (§3: reduces nothing until eaten; feeds
  /// only the "+ planned" arc and copy).
  final bool planned;
}

/// Provenance mark for a burn-side receipt row (Today's Energy sheet legend:
/// solid = verified by device, half = self-reported, hollow = estimated).
enum BurnMark { verified, selfReported, estimated }

/// Everything the Breakdown Pager's three pages need beyond [EnergyCardData]
/// — all derived per intraday-display.md §§1–3 (S-3: no invented arithmetic).
class BreakdownData {
  const BreakdownData({
    required this.minutesSinceMidnight,
    required this.restingSoFar,
    required this.movementSoFar,
    required this.workoutSoFar,
    required this.digestionSoFar,
    required this.restingByEnd,
    required this.movementByEnd,
    required this.workoutByEnd,
    required this.digestionByEnd,
    required this.workoutMark,
    required this.movementMark,
    required this.mealRows,
    required this.plannedCarbsG,
    required this.plannedProteinG,
    required this.plannedFatG,
    required this.weeklyCarbTargets,
    required this.weeklyLoad,
  });

  final int minutesSinceMidnight;

  // §1 accrual components (unrounded; display truncates accruals and
  // rounds session values — see the assembler's display convention).
  final double restingSoFar;
  final double movementSoFar;
  final double workoutSoFar;
  final double digestionSoFar;

  /// By-day's-end values: the engine's returned plan, verbatim (rmr, neat,
  /// projected workouts, 10% of target intake).
  final double restingByEnd;
  final double movementByEnd;
  final double workoutByEnd;
  final double digestionByEnd;

  final BurnMark workoutMark;
  final BurnMark movementMark;

  /// Per-meal rows for "Where it came from" (logged first, planned dimmed).
  final List<BreakdownMealRow> mealRows;

  /// Planned-but-uneaten macro contribution (drives the "+ planned" ring
  /// arcs and copy ONLY — never remaining/EA/net, §3).
  final double plannedCarbsG;
  final double plannedProteinG;
  final double plannedFatG;

  /// This week's carb targets (g) by day (Sun..Sat), null where uncached —
  /// the Weekly carb-periodization chart.
  final List<double?> weeklyCarbTargets;

  /// This week's session kcal by day normalized 0..1 — the training-load
  /// bars behind the carb line.
  final List<double> weeklyLoad;

  double get burnedSoFar =>
      restingSoFar + movementSoFar + workoutSoFar + digestionSoFar;
  double get burnedByEnd =>
      restingByEnd + movementByEnd + workoutByEnd + digestionByEnd;
}

class BreakdownMealRow {
  const BreakdownMealRow({
    required this.name,
    required this.timeLabel,
    required this.kcal,
    required this.carbsG,
    required this.proteinG,
    required this.fatG,
    required this.planned,
  });

  final String name;
  final String timeLabel;
  final double kcal;
  final double carbsG;
  final double proteinG;
  final double fatG;
  final bool planned;
}

/// The filter lens driving the energy card's face and the timeline filter.
enum DashboardFilter { all, workout, meals }

/// One timeline row: a time label + rail dot + either a workout card or a
/// meal group.
class DashboardNode {
  const DashboardNode.workout({
    required this.timeLabel,
    required WorkoutCardData this.workout,
  }) : mealGroupLabel = null,
       meals = const [];

  const DashboardNode.meals({
    required this.timeLabel,
    required String this.mealGroupLabel,
    required this.meals,
  }) : workout = null;

  final String timeLabel;
  final WorkoutCardData? workout;
  final String? mealGroupLabel;
  final List<MealItemData> meals;

  bool get isWorkout => workout != null;

  /// S-7: a SKIPPED card has lost its timeline slot — it renders with no
  /// timestamp ([timeLabel] is empty), tucked after every timed card of its
  /// day, and its rail ink is neutral (dimmed cream), not electrolyte.
  bool get isSkippedWorkout => isWorkout && workout!.isSkipped;

  /// Rail treatment: solid dot for logged/done, dashed/dotted for planned
  /// and skipped.
  bool get railDashed =>
      isWorkout && !(workout!.isDone) ||
      (!isWorkout && meals.isNotEmpty && meals.every((m) => m.suggested));
}

/// The energy summary card's numbers — one component, three faces
/// (energy-card.md). Collapsed and expanded may show DIFFERENT quantities by
/// design (P-2): collapsed is the single most decision-relevant number for
/// the lens, expanded is the progress detail. All values arrive pre-derived
/// per intraday-display.md §§1–3 (P-3).
class EnergyCardData {
  const EnergyCardData({
    required this.netKcal,
    required this.bandCopy,
    required this.eatenKcal,
    required this.burnedKcal,
    required this.targetKcal,
    required this.remainingKcal,
    required this.workoutDoneKcal,
    required this.workoutPlannedKcal,
    required this.workoutProjectedKcal,
    required this.workoutRows,
    required this.carbTargetG,
    required this.proteinTargetG,
    required this.fatTargetG,
    required this.carbEatenG,
    required this.proteinEatenG,
    required this.fatEatenG,
  });

  final double netKcal;

  /// Band copy string from the §2 register, or null when suppressed
  /// (surplus under pre_override).
  final String? bandCopy;
  final double eatenKcal;
  final double burnedKcal;
  final double targetKcal;
  final double remainingKcal;
  final double workoutDoneKcal;
  final double workoutPlannedKcal;
  final double workoutProjectedKcal;
  final List<EnergyWorkoutRow> workoutRows;
  final double carbTargetG;
  final double proteinTargetG;
  final double fatTargetG;
  final double carbEatenG;
  final double proteinEatenG;
  final double fatEatenG;
}

/// One per-session row in the WORKOUT face's expanded detail.
class EnergyWorkoutRow {
  const EnergyWorkoutRow({
    required this.name,
    required this.note,
    required this.kcal,
    required this.planned,
    this.activityId = '',
    this.sport = 'running',
    this.verified = false,
    this.timeLabel = '',
    this.metaLabel = '',
  });

  final String name;
  final String activityId;
  final String sport;
  final bool verified;
  final String timeLabel;
  final String metaLabel;

  /// "8:00 AM · 2,000 yd · 40 min", prefixed "planned · " when planned.
  final String note;
  final double kcal;
  final bool planned;
}

/// Locale-stable thousands formatting matching the reference rendering
/// (1,205 / 4,152).
String kcalStr(num v) {
  final s = v.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// Signed net string: "−133" / "+220" (U+2212 minus, per the reference).
String netStr(double net) => (net < 0 ? '−' : '+') + kcalStr(net.abs());
