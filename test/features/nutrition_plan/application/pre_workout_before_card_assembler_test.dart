// Ticket 62 (testing-wave findings 30-004): each BEFORE feeding card shows the
// fluid its own foods hold, so the cards add up to the BEFORE header.
//
// Contract: feeding-card v1 FC-2 (the card header shows DELIVERED only) and
// surface pre-workout-before-card v1 B-1 (delivered = Σ rows).
//
// Seam rule (docs/test/README.md): the targets and rows below are the STORED
// shapes the server wrote for the two sessions the run found the bug on
// (runs/30/db-fuel-plans-summary.txt), not the local engine's output. The
// server's per-tier fluid targets (snack 477.6 ml, top-off 0 ml) deliberately
// differ from what the foods hold.

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/pre_workout_before_card_assembler.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/plan_section.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/pre_workout_before_card_model.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/pre_workout_feeding_labels.dart';

FoodItemData _food(
  String id,
  String name, {
  required int carbs,
  required double fluidMl,
  required int sodium,
  bool drink = false,
}) => FoodItemData(
  id: id,
  name: name,
  quantity: '1 $name',
  isDrink: drink,
  nutritionalInfo: NutritionalInfo(
    calories: 0,
    carbs: carbs,
    protein: 0,
    fat: 0,
    sodium: sodium,
    fluids: fluidMl,
  ),
);

/// "12 mi Run", 2026-09-21 — stored preRun (server wire values).
const _twelveMilePreRun = PreRunMacros(
  carbsG: 101,
  proteinG: 13,
  fatCapG: 5,
  carbsLowG: 88,
  carbsHighG: 113,
  fluidsMl: 478,
  fluidsLowMl: 0,
  fluidsHighMl: 839,
  hydrationRegime: 'extrapolated',
  carbTiers: [
    PreRunCarbTier(
      tier: 'snack',
      carbsG: 75.523068,
      rangeLowG: 66.0826845,
      rangeHighG: 84.96345149999999,
      composition: 'snack',
    ),
    PreRunCarbTier(
      tier: 'top_off',
      carbsG: 25.174356,
      rangeLowG: 22.0275615,
      rangeHighG: 28.321150499999998,
      composition: 'top_off',
    ),
  ],
  fluidTiers: [
    PreRunFluidTier(tier: 'snack', fluidMl: 477.61533999999995),
    PreRunFluidTier(tier: 'top_off', fluidMl: 0),
  ],
);

final _twelveMileSubPhases = [
  BeforeSubPhase(
    subPhaseType: 'snack',
    foodItems: [
      _food('bagel', 'Bagel', carbs: 44, fluidMl: 0, sodium: 602),
      _food('jam', 'Jam / Jelly', carbs: 11, fluidMl: 6, sodium: 7),
      _food('banana', 'Banana', carbs: 27, fluidMl: 0, sodium: 1),
    ],
  ),
  BeforeSubPhase(
    subPhaseType: 'top_up',
    foodItems: [
      _food('gel', 'Energy Gel', carbs: 25, fluidMl: 20, sodium: 50),
      _food(
        'water',
        'Water (cups)',
        carbs: 0,
        fluidMl: 480,
        sodium: 0,
        drink: true,
      ),
    ],
  ),
];

/// "Patrol H5", 2026-09-24 — a top-off-only plan.
const _patrolH5PreRun = PreRunMacros(
  carbsG: 21,
  proteinG: 0,
  fatCapG: 0,
  carbsLowG: 18,
  carbsHighG: 24,
  fluidsMl: 297,
  fluidsLowMl: 0,
  fluidsHighMl: 839,
  hydrationRegime: 'extrapolated',
  carbTiers: [
    PreRunCarbTier(
      tier: 'top_off',
      carbsG: 20.97863,
      rangeLowG: 18.356301249999998,
      rangeHighG: 23.60095875,
      composition: 'top_off',
    ),
  ],
  fluidTiers: [PreRunFluidTier(tier: 'top_off', fluidMl: 297.4198625)],
);

final _patrolH5SubPhases = [
  BeforeSubPhase(
    subPhaseType: 'top_up',
    foodItems: [
      _food('apple', 'Applesauce', carbs: 22, fluidMl: 154, sodium: 6),
      _food(
        'water',
        'Water (cups)',
        carbs: 0,
        fluidMl: 120,
        sodium: 0,
        drink: true,
      ),
    ],
  ),
];

PreWorkoutBeforeCardData _assemble(
  PreRunMacros preRun,
  List<BeforeSubPhase> subPhases,
  double t,
) => PreWorkoutBeforeCardAssembler.assemble(
  preRun: preRun,
  subPhases: subPhases,
  timeBeforeWorkoutMin: t,
  bodyWeightKg: 70,
  hydrationCheck: null,
);

int _cardFluidSum(PreWorkoutBeforeCardData d) =>
    d.feedings.fold(0, (sum, f) => sum + (f.fluidOz ?? 0));

void main() {
  group('feeding card fluid = the fluid its own foods hold (30-004)', () {
    test(
      '12 mi Run: the Top-Off card with 2 cups of water shows its fluid',
      () {
        final d = _assemble(_twelveMilePreRun, _twelveMileSubPhases, 72);
        final snack = d.feedings.firstWhere(
          (f) => f.tier == PreWorkoutFeedingTier.snack,
        );
        final topOff = d.feedings.firstWhere(
          (f) => f.tier == PreWorkoutFeedingTier.topOff,
        );

        // Gel 20 ml + water 480 ml = 500 ml → round(500 / 29.5735) = 17 oz.
        expect(topOff.fluidOz, 17);
        // Bagel, jam, banana hold 6 ml → 0 oz: the card shows no fluid, not
        // the stored snack tier target (477.6 ml → 16 oz).
        expect(snack.fluidOz, isNull);
      },
    );

    test('12 mi Run: card fluids sum to the BEFORE header', () {
      final d = _assemble(_twelveMilePreRun, _twelveMileSubPhases, 72);
      expect(d.fluids.delivered, 17); // 506 ml
      expect(_cardFluidSum(d), d.fluids.delivered);
    });

    test('Patrol H5: the only card reads the header, not the 10 oz target', () {
      final d = _assemble(_patrolH5PreRun, _patrolH5SubPhases, 20);
      expect(d.fluids.delivered, 9); // 274 ml
      expect(d.feedings.single.fluidOz, 9);
      expect(_cardFluidSum(d), d.fluids.delivered);
    });

    test('a stepped row moves its card fluid with the header (B-1)', () {
      final stepped = [
        _twelveMileSubPhases.first,
        BeforeSubPhase(
          subPhaseType: 'top_up',
          foodItems: [
            _food('gel', 'Energy Gel', carbs: 25, fluidMl: 20, sodium: 50),
            _food(
              'water',
              'Water (cups)',
              carbs: 0,
              fluidMl: 240,
              sodium: 0,
              drink: true,
            ),
          ],
        ),
      ];
      final d = _assemble(_twelveMilePreRun, stepped, 72);
      // 260 ml → 9 oz on the card; 266 ml → 9 oz in the header.
      expect(d.feedings.last.fluidOz, 9);
      expect(_cardFluidSum(d), d.fluids.delivered);
    });
  });
}
