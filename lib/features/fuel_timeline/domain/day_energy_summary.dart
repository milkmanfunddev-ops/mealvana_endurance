import '../../daily_macros/domain/daily_macro_targets.dart';
import '../../meal_logging/domain/consumed_totals.dart';

/// Where the selected day sits relative to "now", which governs how burned
/// energy is computed (see [DayEnergySummary]).
enum DayKind {
  past,
  today,
  future;

  /// Classify [selectedDate] against [now] by calendar day (time-of-day
  /// ignored for the comparison).
  static DayKind of(DateTime selectedDate, DateTime now) {
    final d = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final n = DateTime(now.year, now.month, now.day);
    if (d.isBefore(n)) return DayKind.past;
    if (d.isAfter(n)) return DayKind.future;
    return DayKind.today;
  }
}

/// The energy-balance summary that drives the Fuel Timeline dashboard
/// (intake vs target, burned breakdown, net intake).
///
/// **Burn proration (Lee, 2026-06-25).** Resting + daily-activity energy is
/// prorated by how far into the day we are:
/// - **Past days** → full day (fraction = 1.0).
/// - **Today** → fraction = elapsed minutes / 1440.
/// - **Future days** → targets only; no burn is shown ([hasBurnData] = false).
///
/// Workout energy is *not* prorated by clock — it counts once the workout is
/// "done" (the assembler decides which workouts count and passes the summed
/// [workoutKcal] in).
class DayEnergySummary {
  const DayEnergySummary({
    required this.dayKind,
    required this.targetCalories,
    required this.eatenCalories,
    required this.carbsTarget,
    required this.carbsEaten,
    required this.proteinTarget,
    required this.proteinEaten,
    required this.fatTarget,
    required this.fatEaten,
    required this.restingKcal,
    required this.dailyActivityKcal,
    required this.workoutKcal,
    required this.plannedWorkoutKcal,
    required this.burnedCalories,
    required this.netCalories,
    required this.hasBurnData,
  });

  final DayKind dayKind;

  // Intake budget (from the day's macro targets) vs what's been eaten.
  final double targetCalories;
  final int eatenCalories;
  final double carbsTarget;
  final double carbsEaten;
  final double proteinTarget;
  final double proteinEaten;
  final double fatTarget;
  final double fatEaten;

  // Burned breakdown (resting + daily-activity prorated; workout once done).
  final double restingKcal;
  final double dailyActivityKcal;
  final double workoutKcal;

  /// Total *planned* workout energy for the day (all sessions), independent of
  /// whether they're done yet. Drives the Workout dashboard's "kcal planned".
  final double plannedWorkoutKcal;

  /// Total burned = [restingKcal] + [dailyActivityKcal] + [workoutKcal]
  /// (0 when [hasBurnData] is false).
  final double burnedCalories;

  /// Net intake = eaten − burned (equals eaten when there's no burn data).
  final double netCalories;

  /// False for future days, where no energy has been burned yet.
  final bool hasBurnData;

  /// Eaten/target ratio, clamped to 0..1 (0 when there's no target).
  double get caloriesPct => targetCalories <= 0
      ? 0
      : (eatenCalories / targetCalories).clamp(0.0, 1.0);

  double _pct(double eaten, double target) =>
      target <= 0 ? 0 : (eaten / target).clamp(0.0, 1.0);

  double get carbsPct => _pct(carbsEaten, carbsTarget);
  double get proteinPct => _pct(proteinEaten, proteinTarget);
  double get fatPct => _pct(fatEaten, fatTarget);

  /// Compute the summary for a day.
  ///
  /// [workoutBurnedKcal] is the already-summed session energy for the workouts
  /// the caller considers "done" (the assembler applies the day-kind rule).
  factory DayEnergySummary.compute({
    required DateTime selectedDate,
    required DateTime now,
    required DailyMacroTargets? targets,
    required ConsumedTotals consumed,
    required double workoutBurnedKcal,
  }) {
    final kind = DayKind.of(selectedDate, now);
    final fraction = switch (kind) {
      DayKind.past => 1.0,
      DayKind.today => _elapsedDayFraction(now),
      DayKind.future => 0.0,
    };

    final hasBurn = kind != DayKind.future;

    final resting = (targets?.rmr ?? 0) * fraction;
    final daily = (targets?.neatKcal ?? 0) * fraction;
    // Zeroed on a future day alongside resting/NEAT, so the rendered breakdown
    // always sums to [burnedCalories]. The assembler already passes 0 here for
    // future days, but this is a public factory: leaving the caller's value in
    // the breakdown while the headline reads 0 would put two contradictory
    // numbers on the same dashboard.
    final workout = hasBurn ? workoutBurnedKcal : 0.0;
    final burned = resting + daily + workout;
    final eaten = consumed.calories;

    return DayEnergySummary(
      dayKind: kind,
      targetCalories: targets?.totalCalories ?? 0,
      eatenCalories: eaten,
      carbsTarget: targets?.carbG ?? 0,
      carbsEaten: consumed.carbsG,
      proteinTarget: targets?.protG ?? 0,
      proteinEaten: consumed.proteinG,
      fatTarget: targets?.fatG ?? 0,
      fatEaten: consumed.fatG,
      restingKcal: resting,
      dailyActivityKcal: daily,
      workoutKcal: workout,
      plannedWorkoutKcal: targets?.sessionKcal ?? 0,
      burnedCalories: hasBurn ? burned : 0,
      netCalories: hasBurn ? eaten - burned : eaten.toDouble(),
      hasBurnData: hasBurn,
    );
  }

  /// Fraction of the day elapsed at [now], in 0..1 (minutes since midnight /
  /// 1440).
  static double _elapsedDayFraction(DateTime now) {
    final minutes = now.hour * 60 + now.minute;
    return (minutes / 1440).clamp(0.0, 1.0);
  }
}
