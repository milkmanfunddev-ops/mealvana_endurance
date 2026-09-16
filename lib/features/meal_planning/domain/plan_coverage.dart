import 'meal_type.dart';
import 'plan_meal.dart';
import 'wire_record.dart';

/// `MealPlan.coverage` — how much of the period's main-meal slots the plan
/// fills, and the per-day macro contribution. The slot count follows the
/// athlete's coverage scope (plan §5 Phase 1.6) and period length (mp-269).
class PlanCoverage extends WireRecord {
  const PlanCoverage({
    required this.lunchDinnerSlots,
    required this.covered,
    required this.perDay,
    this.periodDays = PlanCoverageService.defaultPeriodDays,
  });

  /// A lunch and a dinner per day of the period (14 over seven days); one
  /// dinner per day when the athlete chose "dinners only".
  final int lunchDinnerSlots;

  /// Σ servings of the counted meal types, capped at [lunchDinnerSlots].
  final int covered;

  /// The period the slots and [perDay] are counted over — the athlete's
  /// `period_days` setting when the plan was read (7 from a server that
  /// predates it).
  final int periodDays;
  final PlanCoveragePerDay perDay;

  bool get isComplete => covered >= lunchDinnerSlots;

  factory PlanCoverage.fromJson(Map<String, dynamic> json) => PlanCoverage(
    lunchDinnerSlots:
        readInt(json, 'lunchDinnerSlots') ??
        PlanCoverageService.lunchDinnerSlots,
    covered: readInt(json, 'covered') ?? 0,
    periodDays:
        readInt(json, 'periodDays') ?? PlanCoverageService.defaultPeriodDays,
    perDay: PlanCoveragePerDay.fromJson(
      asJsonMap(json['perDay']) ?? const <String, dynamic>{},
    ),
  );

  @override
  Map<String, dynamic> toJson() => {
    'lunchDinnerSlots': lunchDinnerSlots,
    'covered': covered,
    'periodDays': periodDays,
    'perDay': perDay.toJson(),
  };

  PlanCoverage copyWith({
    int? lunchDinnerSlots,
    int? covered,
    int? periodDays,
    PlanCoveragePerDay? perDay,
  }) => PlanCoverage(
    lunchDinnerSlots: lunchDinnerSlots ?? this.lunchDinnerSlots,
    covered: covered ?? this.covered,
    periodDays: periodDays ?? this.periodDays,
    perDay: perDay ?? this.perDay,
  );
}

/// `coverage.perDay` — the plan's totals ÷ the period's days, rounded.
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
/// Plan bar never shows a stale number. Callers pass the server's
/// `lunchDinnerSlots` back in so a local recompute keeps the denominator the
/// athlete's coverage scope chose, and the plan's `periodDays` so the
/// dinners-only signal (slots == days) and the per-day average hold for any
/// period length (mp-269).
class PlanCoverageService {
  const PlanCoverageService._();

  /// The default period: seven days.
  static const int defaultPeriodDays = 7;

  /// The default denominator: 7 lunches + 7 dinners.
  static const int lunchDinnerSlots = 14;

  /// The seven-day "dinners only" denominator — the server's signal that
  /// only dinner servings count is `lunchDinnerSlots == periodDays`.
  static const int dinnerOnlySlots = 7;

  /// [lunchDinnerSlots] defaults to a lunch and a dinner per day of
  /// [periodDays].
  static PlanCoverage compute(
    List<PlanMeal> meals, {
    int? lunchDinnerSlots,
    int periodDays = defaultPeriodDays,
  }) {
    final slots = lunchDinnerSlots ?? periodDays * 2;
    final dinnersOnly = slots == periodDays;
    var slotServings = 0;
    var kcal = 0.0;
    var carbs = 0.0;
    var protein = 0.0;
    for (final m in meals) {
      final counts =
          m.mealType == MealType.dinner ||
          (!dinnersOnly && m.mealType == MealType.lunch);
      if (counts) slotServings += m.servings;
      kcal += (m.kcal ?? 0) * m.servings;
      carbs += (m.carbsG ?? 0) * m.servings;
      protein += (m.proteinG ?? 0) * m.servings;
    }
    return PlanCoverage(
      lunchDinnerSlots: slots,
      covered: slotServings < slots ? slotServings : slots,
      periodDays: periodDays,
      perDay: PlanCoveragePerDay(
        kcal: _jsRound(kcal / periodDays),
        carbsG: _jsRound(carbs / periodDays),
        proteinG: _jsRound(protein / periodDays),
      ),
    );
  }

  /// `Math.round` semantics (halves round toward +∞), unlike Dart's
  /// `round()` which rounds halves away from zero. Values here are ≥ 0 so
  /// they agree in practice; kept explicit so the port stays exact.
  static int _jsRound(double v) => (v + 0.5).floor();
}
