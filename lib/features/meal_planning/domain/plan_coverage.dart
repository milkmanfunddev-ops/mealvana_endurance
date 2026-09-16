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
    this.mealTypes = const [],
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

  /// The meal types the athlete plans, in their order (mp-231 clause 1) — one
  /// slot per day of the period each. Empty from a server that predates the
  /// walk; then the denominator alone says whether lunches count.
  final List<MealType> mealTypes;
  final PlanCoveragePerDay perDay;

  bool get isComplete => covered >= lunchDinnerSlots;

  factory PlanCoverage.fromJson(Map<String, dynamic> json) => PlanCoverage(
    lunchDinnerSlots:
        readInt(json, 'lunchDinnerSlots') ??
        PlanCoverageService.lunchDinnerSlots,
    covered: readInt(json, 'covered') ?? 0,
    periodDays:
        readInt(json, 'periodDays') ?? PlanCoverageService.defaultPeriodDays,
    mealTypes: [
      for (final wire in readStringList(json, 'mealTypes'))
        if (MealType.fromWire(wire) case final type?) type,
    ],
    perDay: PlanCoveragePerDay.fromJson(
      asJsonMap(json['perDay']) ?? const <String, dynamic>{},
    ),
  );

  @override
  Map<String, dynamic> toJson() => {
    'lunchDinnerSlots': lunchDinnerSlots,
    'covered': covered,
    'periodDays': periodDays,
    // Absent rather than empty: a plan read from a server without the walk
    // round-trips unchanged.
    if (mealTypes.isNotEmpty)
      'mealTypes': [for (final type in mealTypes) type.wire],
    'perDay': perDay.toJson(),
  };

  PlanCoverage copyWith({
    int? lunchDinnerSlots,
    int? covered,
    int? periodDays,
    List<MealType>? mealTypes,
    PlanCoveragePerDay? perDay,
  }) => PlanCoverage(
    lunchDinnerSlots: lunchDinnerSlots ?? this.lunchDinnerSlots,
    covered: covered ?? this.covered,
    periodDays: periodDays ?? this.periodDays,
    mealTypes: mealTypes ?? this.mealTypes,
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

  /// The types counted when the server sent no walk: a dinner a day when the
  /// denominator is one slot per day, else a lunch and a dinner.
  static List<MealType> _inferredTypes(int? lunchDinnerSlots, int periodDays) =>
      lunchDinnerSlots != null && lunchDinnerSlots == periodDays
      ? const [MealType.dinner]
      : const [MealType.dinner, MealType.lunch];

  /// [lunchDinnerSlots] defaults to one slot per day of [periodDays] for each
  /// type the athlete plans ([countedTypes], the server's `coverage.mealTypes`).
  ///
  /// [batchCooking] is the plan's mode (mp-231 clauses 3–4): a batch is cooked
  /// once and eaten across the period, so its SERVINGS fill the slots; an
  /// athlete who cooks the night of fills one night per meal, so the MEALS are
  /// counted instead. Types outside the walk still weigh on `perDay`.
  ///
  /// The result carries [countedTypes] only when the caller had one: a plan
  /// from a server that predates the walk keeps an empty `mealTypes`, so it
  /// round-trips to the wire it came from.
  static PlanCoverage compute(
    List<PlanMeal> meals, {
    int? lunchDinnerSlots,
    int periodDays = defaultPeriodDays,
    bool batchCooking = true,
    List<MealType>? countedTypes,
  }) {
    final types = (countedTypes == null || countedTypes.isEmpty)
        ? _inferredTypes(lunchDinnerSlots, periodDays)
        : countedTypes;
    final slots = lunchDinnerSlots ?? periodDays * types.length;
    var filled = 0;
    var kcal = 0.0;
    var carbs = 0.0;
    var protein = 0.0;
    for (final m in meals) {
      if (types.contains(m.mealType)) filled += batchCooking ? m.servings : 1;
      kcal += (m.kcal ?? 0) * m.servings;
      carbs += (m.carbsG ?? 0) * m.servings;
      protein += (m.proteinG ?? 0) * m.servings;
    }
    return PlanCoverage(
      lunchDinnerSlots: slots,
      covered: filled < slots ? filled : slots,
      periodDays: periodDays,
      // Only a walk the caller actually had: a plan from a server that predates
      // `coverage.mealTypes` round-trips to the wire it came from.
      mealTypes: countedTypes == null || countedTypes.isEmpty
          ? const []
          : List.unmodifiable(types),
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
