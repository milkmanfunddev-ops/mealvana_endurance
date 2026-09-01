// The canonical 63-kg mock for the pre-workout BEFORE card — the persona of
// docs/ssot/conformance/design/pre-workout-before-card.goldens.yaml
// (`mock_athlete: bodyWeightKg: 63`) with the reference rendering's food rows
// (spec/design/renderings/pre-workout@v2.html, scenario table `SC`).
//
// NUMBERS COME FROM THE ENGINE. Every target and band here is produced by
// `OfflineMacroCalculator` (carbs v2 / hydration v6 / sodium v3) for the
// scenario's lead time — the rendering's illustrative values (16 oz, 50–140 g)
// are never hard-coded (surface B-5; handoff §3 "Numbers come from the
// engine per the traceability rows").
//
// Food rows are the rendering's: Oatmeal with banana (52 g · 120 mg), Water
// (cups) at 8 oz = 236.588 ml per cup, RXBAR Blueberry (24 g · 150 mg), Energy
// Chews (packets) at 26 g · 80 mg per packet, stepped by 0.5.

import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/offline_macro_calculator.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/plan_section.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/pre_workout_hydration_check.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

const double kMockBodyWeightKg = 63;
const double kMockDurationMin = 90;
const double kCupMl = 236.588;

/// Engine-derived pre-run targets for the 63-kg persona at lead time [t].
///
/// [gated] uses a 45-minute session at 22 °C — hydration v6's gate
/// (`< 60 min AND < 30 °C`) — so `fluidMl` is `null`, `regime: gated`.
/// [fasted] takes carbs v2's D-001 path (`tiers: []`, `targetBasis: none`).
PreRunMacros mockPreRun({
  required double t,
  bool gated = false,
  bool fasted = false,
  double bodyWeightKg = kMockBodyWeightKg,
  HydrationCheck hydrationCheck = HydrationCheck.unknown,
}) {
  final durationMin = gated ? 45.0 : kMockDurationMin;
  final carbs = OfflineMacroCalculator.calculatePreWorkoutCarbs(
    bodyWeightKg: bodyWeightKg,
    timeBeforeWorkoutMin: t,
    workoutDurationMin: durationMin,
    isFasted: fasted,
  );
  final hydration = OfflineMacroCalculator.calculatePreWorkoutHydration(
    bodyWeightKg: bodyWeightKg,
    workoutDurationMin: durationMin,
    timeBeforeWorkoutMin: t,
    tempC: 22,
    hydrationCheck: hydrationCheck,
  );
  return PreRunMacros(
    carbsG: carbs.carbsG,
    proteinG: 10,
    fatCapG: 10,
    carbsLowG: carbs.carbsLowG,
    carbsHighG: carbs.carbsHighG,
    carbTargetBasis: carbs.targetBasis,
    carbTiers: carbs.tiers
        .map(
          (tier) => PreRunCarbTier(
            tier: tier.tier,
            carbsG: tier.carbsG,
            rangeLowG: tier.rangeLowG,
            rangeHighG: tier.rangeHighG,
            composition: tier.composition,
          ),
        )
        .toList(),
    fluidsMl: hydration.fluidMl,
    fluidsLowMl: hydration.fluidLowMl,
    fluidsHighMl: hydration.fluidHighMl,
    hydrationRegime: hydration.regime,
    fluidTargetBasis: hydration.targetBasis,
    hydrationCheckUsed: hydration.hydrationCheckUsed,
    fluidTiers: hydration.tiers
        .map((tier) => PreRunFluidTier(tier: tier.tier, fluidMl: tier.fluidMl))
        .toList(),
  );
}

MacroTargets mockMacroTargets(PreRunMacros preRun, {bool gated = false}) =>
    MacroTargets(
      id: 'mt-63kg',
      activityType: ActivityType.running,
      preRun: preRun,
      duringRun: const DuringRunMacros(
        carbRateGPerH: 60,
        carbTotalG: 90,
        fluidRateMlPerH: 500,
        fluidTotalMl: 750,
        sodiumRateMgPerH: 300,
        sodiumTotalMg: 450,
        massNormRateGPerH: 0.8,
        tempC: 22,
      ),
      postRun: const PostRunMacros(
        carbsG: 60,
        proteinG: 20,
        fluidsMl: 500,
        sodiumMg: 300,
      ),
      metrics: RunMetrics(
        distanceMi: 9,
        distanceKm: 14.5,
        durationH: gated ? 0.75 : 1.5,
        durationMin: gated ? 45 : kMockDurationMin,
        paceMinPerMile: 10,
        speedMph: 6,
        caloriesGrossKcal: 900,
        caloriesNetKcal: 800,
        met: 9,
      ),
      calculationRule: 'test',
      timestamp: DateTime(2026, 8, 26),
      isUserModified: false,
      modifiedFields: const [],
    );

FoodItemData oatmeal({double qty = 1}) => FoodItemData(
  id: 'oat',
  name: 'Oatmeal with banana',
  quantity: '${_q(qty)} bowl Oatmeal with banana',
  isIndivisible: true,
  nutritionalInfo: NutritionalInfo(
    calories: (300 * qty).round(),
    carbs: (52 * qty).round(),
    protein: 8,
    fat: 5,
    sodium: (120 * qty).round(),
    fluids: 0,
  ),
);

FoodItemData water({required String id, double cups = 1}) => FoodItemData(
  id: id,
  name: 'Water (cups)',
  quantity: '${_q(cups)} cups Water',
  isDrink: true,
  isIndivisible: true,
  nutritionalInfo: NutritionalInfo(
    calories: 0,
    carbs: 0,
    protein: 0,
    fat: 0,
    sodium: 0,
    fluids: kCupMl * cups,
  ),
);

FoodItemData rxbar({double qty = 1}) => FoodItemData(
  id: 'rx',
  name: 'RXBAR Blueberry',
  quantity: '${_q(qty)} bar RXBAR Blueberry',
  isIndivisible: true,
  nutritionalInfo: NutritionalInfo(
    calories: (210 * qty).round(),
    carbs: (24 * qty).round(),
    protein: 12,
    fat: 7,
    sodium: (150 * qty).round(),
    fluids: 0,
  ),
);

FoodItemData chews({double qty = 0.5}) => FoodItemData(
  id: 'chew',
  name: 'Energy Chews (packets)',
  quantity: '${_q(qty)} packet Energy Chews',
  isIndivisible: false,
  nutritionalInfo: NutritionalInfo(
    calories: (160 * qty).round(),
    carbs: (26 * qty).round(),
    protein: 0,
    fat: 0,
    sodium: (80 * qty).round(),
    fluids: 0,
  ),
);

String _q(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

/// The rendering's feeding membership + rows for lead time [t]
/// (`SC[...]`.feedings). [mealWaterCups] lets the "already covered" tests put
/// enough fluid in the meal.
List<BeforeSubPhase> mockSubPhases(double t, {double mealWaterCups = 2}) {
  if (t >= 120) {
    return [
      BeforeSubPhase(
        subPhaseType: 'meal',
        foodItems: [
          oatmeal(),
          water(id: 'wat', cups: mealWaterCups),
        ],
        carbsTarget: 60,
      ),
      BeforeSubPhase(subPhaseType: 'snack', foodItems: [rxbar()]),
      BeforeSubPhase(subPhaseType: 'top_up', foodItems: [chews()]),
    ];
  }
  if (t >= 30) {
    return [
      BeforeSubPhase(
        subPhaseType: 'snack',
        foodItems: [
          rxbar(),
          water(id: 'wat'),
        ],
      ),
      BeforeSubPhase(subPhaseType: 'top_up', foodItems: [chews()]),
    ];
  }
  if (t > 0) {
    return [
      BeforeSubPhase(
        subPhaseType: 'top_up',
        foodItems: [
          chews(),
          water(id: 'wat'),
        ],
      ),
    ];
  }
  return [
    BeforeSubPhase(
      subPhaseType: 'top_up',
      foodItems: [water(id: 'wat')],
    ),
  ];
}

NutritionPlan mockPlan(
  List<BeforeSubPhase> subPhases, {
  PreWorkoutHydrationCheckRecord? hydrationCheck,
  String activityId = 'act-63kg',
}) => NutritionPlan(
  id: 'plan-63kg',
  name: 'Long Run Nutrition Plan',
  activityId: activityId,
  sections: [
    PlanSection(
      id: 'before_run',
      title: 'Before Run',
      foodItems: const [],
      subPhases: subPhases,
    ),
    const PlanSection(id: 'during_run', title: 'During Run', foodItems: []),
    const PlanSection(id: 'after_run', title: 'After Run', foodItems: []),
  ],
  preWorkoutHydrationCheck: hydrationCheck,
);

Activity mockActivity({
  required int timeBeforeMinutes,
  String id = 'act-63kg',
  String userId = 'user-63kg',
  Map<String, dynamic>? nutritionPlanData,
}) => Activity(
  id: id,
  userId: userId,
  activityType: ActivityType.running,
  title: 'Long Run',
  scheduledDateTime: DateTime(2026, 8, 27, 7),
  durationMinutes: kMockDurationMin.toInt(),
  distanceMiles: 9,
  timeBeforeMinutes: timeBeforeMinutes,
  nutritionPlanData: nutritionPlanData,
  createdAt: DateTime(2026, 8, 26),
  updatedAt: DateTime(2026, 8, 26),
);

/// The server twin's lb→kg factor (`_getUserMetrics`: `weightPounds * 0.453592`).
const double kServerKgPerLb = 0.453592;

/// The device's lb→kg factor (`UnitFormatter.kKgPerLb` / macro_repository).
const double kDeviceKgPerLb = 0.45359237;

/// STORED targets as the SERVER produces them — the shape every seam test
/// must feed, not `mockPreRun()`.
///
/// Why this exists (2026-08-26): the hydration-check service compared the
/// stored band to its own recompute with a 1e-3 ml assert; every test built
/// both sides from the same `mockPreRun()` call so they were byte-identical
/// by construction, and the first real device (server band at 0.453592,
/// device recompute at 0.45359237 — ~0.1 ml apart) threw inside the tap and
/// wrote nothing. Data that crossed a process boundary is never bit-equal to
/// a local recompute: build the stored side from the producer's factor and
/// the wire's rounding, so "stored ≠ recomputed" is the DEFAULT in tests.
PreRunMacros serverPreRun({
  required double t,
  required double weightLb,
  double durationMin = kMockDurationMin,
  bool gated = false,
  bool fasted = false,
}) {
  final pre = mockPreRun(
    t: t,
    gated: gated,
    fasted: fasted,
    bodyWeightKg: weightLb * kServerKgPerLb,
  );
  // The wire rounds to 3 decimals (generate-macros-v4 `round3`); mirror it.
  double? r3(double? v) => v == null ? null : (v * 1000).round() / 1000;
  return PreRunMacros(
    carbsG: r3(pre.carbsG)!,
    proteinG: pre.proteinG,
    fatCapG: pre.fatCapG,
    carbsLowG: r3(pre.carbsLowG),
    carbsHighG: r3(pre.carbsHighG),
    carbTargetBasis: pre.carbTargetBasis,
    carbTiers: pre.carbTiers,
    fluidsMl: r3(pre.fluidsMl),
    fluidsLowMl: r3(pre.fluidsLowMl),
    fluidsHighMl: r3(pre.fluidsHighMl),
    hydrationRegime: pre.hydrationRegime,
    fluidTargetBasis: pre.fluidTargetBasis,
    hydrationCheckUsed: pre.hydrationCheckUsed,
    fluidTiers: pre.fluidTiers
        ?.map((x) => PreRunFluidTier(tier: x.tier, fluidMl: r3(x.fluidMl)!))
        .toList(),
  );
}
