import 'meal_type.dart';
import 'plan_meal.dart';
import 'wire_record.dart';

/// `MealPlan.coverage` — how much of the week's lunch + dinner slots the plan
/// fills, and the per-day macro contribution.
class PlanCoverage extends WireRecord {
  const PlanCoverage({
    required this.lunchDinnerSlots,
    required this.covered,
    required this.perDay,
  });

  /// Always 14 (7 lunches + 7 dinners).
  final int lunchDinnerSlots;

  /// Σ servings of lunch/dinner meals, capped at [lunchDinnerSlots].
  final int covered;
  final PlanCoveragePerDay perDay;

  bool get isComplete => covered >= lunchDinnerSlots;

  factory PlanCoverage.fromJson(Map<String, dynamic> json) => PlanCoverage(
    lunchDinnerSlots:
        readInt(json, 'lunchDinnerSlots') ??
        PlanCoverageService.lunchDinnerSlots,
    covered: readInt(json, 'covered') ?? 0,
    perDay: PlanCoveragePerDay.fromJson(
      asJsonMap(json['perDay']) ?? const <String, dynamic>{},
    ),
  );

  @override
  Map<String, dynamic> toJson() => {
    'lunchDinnerSlots': lunchDinnerSlots,
    'covered': covered,
    'perDay': perDay.toJson(),
  };

  PlanCoverage copyWith({
    int? lunchDinnerSlots,
    int? covered,
    PlanCoveragePerDay? perDay,
  }) => PlanCoverage(
    lunchDinnerSlots: lunchDinnerSlots ?? this.lunchDinnerSlots,
    covered: covered ?? this.covered,
    perDay: perDay ?? this.perDay,
  );
}

/// `coverage.perDay` — weekly totals ÷ 7, rounded.
class PlanCoveragePerDay extends WireRecord {
  const PlanCoveragePerDay({
    required this.kcal,
    required this.carbsG,
    required this.proteinG,
  });

  final int kcal;
  final int carbsG;
  final int proteinG;

  factory PlanCoveragePerDay.fromJson(Map<String, dynamic> json) =>
      PlanCoveragePerDay(
        kcal: readInt(json, 'kcal') ?? 0,
        carbsG: readInt(json, 'carbsG') ?? 0,
        proteinG: readInt(json, 'proteinG') ?? 0,
      );

  @override
  Map<String, dynamic> toJson() => {
    'kcal': kcal,
    'carbsG': carbsG,
    'proteinG': proteinG,
  };

  PlanCoveragePerDay copyWith({int? kcal, int? carbsG, int? proteinG}) =>
      PlanCoveragePerDay(
        kcal: kcal ?? this.kcal,
        carbsG: carbsG ?? this.carbsG,
        proteinG: proteinG ?? this.proteinG,
      );
}

/// Port of `coverageOf()` in the prototype's `server/vana/plan.ts`.
///
/// The server sends `coverage` on every plan; this exists for the local-first
/// path (servings/remove edits applied to Drift before the round trip) so the
/// Plan bar never shows a stale number.
class PlanCoverageService {
  const PlanCoverageService._();

  static const int lunchDinnerSlots = 14;

  static PlanCoverage compute(List<PlanMeal> meals) {
    var lunchDinnerServings = 0;
    var kcal = 0.0;
    var carbs = 0.0;
    var protein = 0.0;
    for (final m in meals) {
      if (m.mealType == MealType.lunch || m.mealType == MealType.dinner) {
        lunchDinnerServings += m.servings;
      }
      kcal += (m.kcal ?? 0) * m.servings;
      carbs += (m.carbsG ?? 0) * m.servings;
      protein += (m.proteinG ?? 0) * m.servings;
    }
    return PlanCoverage(
      lunchDinnerSlots: lunchDinnerSlots,
      covered: lunchDinnerServings < lunchDinnerSlots
          ? lunchDinnerServings
          : lunchDinnerSlots,
      perDay: PlanCoveragePerDay(
        kcal: _jsRound(kcal / 7),
        carbsG: _jsRound(carbs / 7),
        proteinG: _jsRound(protein / 7),
      ),
    );
  }

  /// `Math.round` semantics (halves round toward +∞), unlike Dart's
  /// `round()` which rounds halves away from zero. Values here are ≥ 0 so
  /// they agree in practice; kept explicit so the port stays exact.
  static int _jsRound(double v) => (v + 0.5).floor();
}
