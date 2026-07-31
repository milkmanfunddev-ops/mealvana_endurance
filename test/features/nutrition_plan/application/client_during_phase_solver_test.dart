// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/client_plan/client_during_phase_solver.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/solver_food.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/solver_types.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Build a minimal [SolverFood] for testing.
SolverFood _makeFood({
  required String id,
  required String productType,
  double carbsG = 0,
  double proteinG = 0,
  double fatG = 0,
  double sodiumMg = 0,
  double fluidMl = 0,
  int calories = 0,
  int maxServings = 6,
  int preferenceScore = 20,
  bool isLiquid = false,
  bool isElectrolyte = false,
  bool isIndivisible = false,
}) {
  return SolverFood(
    id: id,
    name: id,
    carbsG: carbsG,
    proteinG: proteinG,
    fatG: fatG,
    sodiumMg: sodiumMg,
    fluidMl: fluidMl,
    calories: calories,
    maxServings: maxServings,
    preferenceScore: preferenceScore,
    isLiquid: isLiquid,
    isElectrolyte: isElectrolyte,
    isIndivisible: isIndivisible,
    productType: productType,
  );
}

const _defaultTargets = SolverTargets(carbsG: 60, sodiumMg: 800, fluidMl: 700);

const _solver = ClientDuringPhaseSolver();

// ---------------------------------------------------------------------------
// Helper queries
// ---------------------------------------------------------------------------

/// Collect all product types from primary-carb selections (gel/chew/drink_mix)
/// in the solver output, looking them up from [foods].
Set<String> _primaryCarbProductTypes(
  List<SolverSelection> selections,
  List<SolverFood> foods,
) {
  final types = <String>{};
  for (final sel in selections) {
    final food = foods.firstWhere((f) => f.id == sel.foodId);
    final pt = food.productType ?? '';
    if (pt == 'gel' || pt == 'chew' || pt == 'drink_mix') {
      types.add(pt);
    }
  }
  return types;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ClientDuringPhaseSolver', () {
    // -----------------------------------------------------------------------
    // Running — single primary carb type
    // -----------------------------------------------------------------------
    group('running — primary carb mixing constraint', () {
      test(
        'picks exactly one primary carb type when multiple are available',
        () {
          final foods = [
            _makeFood(
              id: 'gel-a',
              productType: 'gel',
              carbsG: 25,
              sodiumMg: 50,
              isIndivisible: true,
            ),
            _makeFood(
              id: 'chew-a',
              productType: 'chew',
              carbsG: 10,
              sodiumMg: 80,
              isIndivisible: false,
              maxServings: 4,
            ),
            _makeFood(
              id: 'drink-mix-a',
              productType: 'drink_mix',
              carbsG: 20,
              sodiumMg: 100,
              isLiquid: true,
            ),
            _makeFood(
              id: 'water',
              productType: 'beverage',
              fluidMl: 500,
              isLiquid: true,
            ),
          ];

          final result = _solver.solve(
            foods: foods,
            targets: _defaultTargets,
            activityType: ActivityType.running,
          );

          final types = _primaryCarbProductTypes(result, foods);
          expect(
            types.length,
            equals(1),
            reason:
                'running must use exactly one primary carb product type, '
                'got: $types',
          );
        },
      );

      test('running with single product type is untouched', () {
        final foods = [
          _makeFood(
            id: 'gel-a',
            productType: 'gel',
            carbsG: 25,
            sodiumMg: 50,
            isIndivisible: true,
            maxServings: 4,
          ),
          _makeFood(
            id: 'water',
            productType: 'beverage',
            fluidMl: 500,
            isLiquid: true,
          ),
        ];

        final result = _solver.solve(
          foods: foods,
          targets: _defaultTargets,
          activityType: ActivityType.running,
        );

        final types = _primaryCarbProductTypes(result, foods);
        expect(types, equals({'gel'}));
      });

      test(
        'running with no primary carb foods returns empty primary carbs',
        () {
          final foods = [
            _makeFood(
              id: 'sports-drink',
              productType: 'sports_drink',
              carbsG: 30,
              sodiumMg: 200,
              fluidMl: 500,
              isLiquid: true,
            ),
            _makeFood(
              id: 'water',
              productType: 'beverage',
              fluidMl: 500,
              isLiquid: true,
            ),
          ];

          final result = _solver.solve(
            foods: foods,
            targets: _defaultTargets,
            activityType: ActivityType.running,
          );

          final types = _primaryCarbProductTypes(result, foods);
          expect(
            types,
            isEmpty,
            reason: 'No gel/chew/drink_mix in pool → no primary carb type',
          );
        },
      );
    });

    // -----------------------------------------------------------------------
    // Cycling — can combine primary carb types
    // -----------------------------------------------------------------------
    group('cycling — can combine primary carb types', () {
      test('cycling selects bike solids in addition to primary carb', () {
        final foods = [
          _makeFood(
            id: 'gel-a',
            productType: 'gel',
            carbsG: 22,
            sodiumMg: 50,
            isIndivisible: true,
            maxServings: 3,
          ),
          _makeFood(
            id: 'bar-a',
            productType: 'bar',
            carbsG: 30,
            sodiumMg: 100,
            isIndivisible: true,
            maxServings: 2,
          ),
          _makeFood(
            id: 'water',
            productType: 'beverage',
            fluidMl: 500,
            isLiquid: true,
          ),
        ];

        final result = _solver.solve(
          foods: foods,
          targets: const SolverTargets(carbsG: 80, sodiumMg: 500, fluidMl: 700),
          activityType: ActivityType.cycling,
        );

        final ids = result.map((s) => s.foodId).toSet();
        // Bar (bike solid) should appear — cycling allows it
        expect(
          ids.contains('bar-a'),
          isTrue,
          reason: 'cycling should include bike solid (bar)',
        );
      });

      test('cycling allows gel and drink_mix together if needed', () {
        final foods = [
          _makeFood(
            id: 'gel-a',
            productType: 'gel',
            carbsG: 25,
            sodiumMg: 50,
            isIndivisible: true,
            maxServings: 2,
          ),
          _makeFood(
            id: 'drink-mix-a',
            productType: 'drink_mix',
            carbsG: 20,
            sodiumMg: 80,
            isLiquid: false,
            maxServings: 4,
          ),
          _makeFood(
            id: 'water',
            productType: 'beverage',
            fluidMl: 500,
            isLiquid: true,
          ),
        ];

        final result = _solver.solve(
          foods: foods,
          targets: const SolverTargets(
            carbsG: 100,
            sodiumMg: 400,
            fluidMl: 600,
          ),
          activityType: ActivityType.cycling,
        );

        // Cycling does NOT enforce the single-type constraint,
        // so multiple primary-carb types may appear.
        final types = _primaryCarbProductTypes(result, foods);
        // At least one primary carb type should be selected
        expect(
          types,
          isNotEmpty,
          reason: 'cycling: at least one primary carb type should appear',
        );
        // Both types may appear — that's the cycling behaviour.
        // No assertion that types.length == 1.
      });
    });

    // -----------------------------------------------------------------------
    // Gut training level — changes serving counts
    // -----------------------------------------------------------------------
    group('gut training level changes serving counts', () {
      test('low gut training selects fewer servings than high', () {
        final foods = [
          _makeFood(
            id: 'gel-a',
            productType: 'gel',
            carbsG: 25,
            sodiumMg: 50,
            isIndivisible: true,
            maxServings: 8,
          ),
          _makeFood(
            id: 'water',
            productType: 'beverage',
            fluidMl: 500,
            isLiquid: true,
            maxServings: 10,
          ),
        ];

        final targets = const SolverTargets(
          carbsG: 150, // Large target to drive servings high
          sodiumMg: 100,
          fluidMl: 300,
        );

        final lowResult = _solver.solve(
          foods: foods,
          targets: targets,
          activityType: ActivityType.running,
          gutTrainingLevel: 'low',
        );

        final highResult = _solver.solve(
          foods: foods,
          targets: targets,
          activityType: ActivityType.running,
          gutTrainingLevel: 'high',
        );

        final lowGelServings = lowResult
            .where((s) => s.foodId == 'gel-a')
            .fold(0.0, (sum, s) => sum + s.quantity);
        final highGelServings = highResult
            .where((s) => s.foodId == 'gel-a')
            .fold(0.0, (sum, s) => sum + s.quantity);

        expect(
          lowGelServings,
          lessThanOrEqualTo(highGelServings),
          reason: 'low gut training should allow fewer servings than high',
        );
      });

      test('moderate gut training uses food maxServings verbatim', () {
        final foods = [
          _makeFood(
            id: 'gel-a',
            productType: 'gel',
            carbsG: 25,
            sodiumMg: 50,
            isIndivisible: true,
            maxServings: 4,
          ),
          _makeFood(
            id: 'water',
            productType: 'beverage',
            fluidMl: 500,
            isLiquid: true,
          ),
        ];

        final result = _solver.solve(
          foods: foods,
          targets: const SolverTargets(
            carbsG: 200, // Far exceeds max cap
            sodiumMg: 100,
            fluidMl: 200,
          ),
          activityType: ActivityType.running,
          gutTrainingLevel: 'moderate',
        );

        final gelServings = result
            .where((s) => s.foodId == 'gel-a')
            .fold(0.0, (sum, s) => sum + s.quantity);

        // moderate: multiplier = 1.0 → maxServings cap = 4
        expect(
          gelServings,
          lessThanOrEqualTo(4.0),
          reason: 'moderate gut training caps at maxServings (4)',
        );
      });

      test('low gut training caps servings at 0.5× maxServings', () {
        final foods = [
          _makeFood(
            id: 'gel-a',
            productType: 'gel',
            carbsG: 25,
            sodiumMg: 50,
            isIndivisible: true,
            maxServings: 8,
          ),
          _makeFood(
            id: 'water',
            productType: 'beverage',
            fluidMl: 500,
            isLiquid: true,
          ),
        ];

        final result = _solver.solve(
          foods: foods,
          targets: const SolverTargets(
            carbsG: 500, // Far exceeds even high cap
            sodiumMg: 100,
            fluidMl: 200,
          ),
          activityType: ActivityType.running,
          gutTrainingLevel: 'low',
        );

        final gelServings = result
            .where((s) => s.foodId == 'gel-a')
            .fold(0.0, (sum, s) => sum + s.quantity);

        // low: multiplier = 0.5 → cap = max(1, 8 * 0.5) = 4
        expect(
          gelServings,
          lessThanOrEqualTo(4.0),
          reason: 'low gut training caps gel at 0.5 × maxServings(8) = 4',
        );
      });
    });

    // -----------------------------------------------------------------------
    // Duration threading
    // -----------------------------------------------------------------------
    group('duration parameter is accepted without error', () {
      test('solver runs without error when durationMinutes is provided', () {
        final foods = [
          _makeFood(
            id: 'gel-a',
            productType: 'gel',
            carbsG: 25,
            sodiumMg: 50,
            isIndivisible: true,
          ),
          _makeFood(
            id: 'water',
            productType: 'beverage',
            fluidMl: 500,
            isLiquid: true,
          ),
        ];

        expect(
          () => _solver.solve(
            foods: foods,
            targets: _defaultTargets,
            activityType: ActivityType.running,
            durationMinutes: 120,
          ),
          returnsNormally,
        );
      });

      test('solver runs without error when durationMinutes is null', () {
        final foods = [
          _makeFood(
            id: 'gel-a',
            productType: 'gel',
            carbsG: 25,
            sodiumMg: 50,
            isIndivisible: true,
          ),
        ];

        expect(
          () => _solver.solve(
            foods: foods,
            targets: _defaultTargets,
            activityType: ActivityType.running,
            durationMinutes: null,
          ),
          returnsNormally,
        );
      });
    });

    // -----------------------------------------------------------------------
    // Empty pool
    // -----------------------------------------------------------------------
    test('returns empty list when food pool is empty', () {
      final result = _solver.solve(
        foods: [],
        targets: _defaultTargets,
        activityType: ActivityType.running,
      );
      expect(result, isEmpty);
    });

    // -----------------------------------------------------------------------
    // 5-step algorithm structure
    // -----------------------------------------------------------------------
    group('5-step algorithm', () {
      test('step 4: adds water when fluid target is unmet', () {
        final foods = [
          _makeFood(
            id: 'gel-a',
            productType: 'gel',
            carbsG: 25,
            sodiumMg: 50,
            isIndivisible: true,
          ),
          _makeFood(
            id: 'water',
            productType: 'beverage',
            fluidMl: 500,
            isLiquid: true,
          ),
        ];

        final result = _solver.solve(
          foods: foods,
          targets: const SolverTargets(carbsG: 25, sodiumMg: 0, fluidMl: 700),
          activityType: ActivityType.running,
        );

        final waterServings = result
            .where((s) => s.foodId == 'water')
            .fold(0.0, (sum, s) => sum + s.quantity);
        expect(
          waterServings,
          greaterThan(0),
          reason: 'water should be added to fill fluid target',
        );
      });

      test('step 5: adds electrolyte when sodium target is unmet', () {
        // Use fluidMl: 0 target so the water step is skipped. This avoids
        // a rounding edge case where water adds 1 full serving (500ml) that
        // pushes fluidAssigned over fluidUpper, which would cause the
        // electrolyte scorer to reject the supplement (same behavior as
        // the server's fillElectrolytes when currentFluid > fluidUpper).
        final foods = [
          _makeFood(
            id: 'gel-a',
            productType: 'gel',
            carbsG: 25,
            sodiumMg: 0,
            isIndivisible: true,
          ),
          _makeFood(
            id: 'electrolyte',
            productType: 'supplement',
            sodiumMg: 300,
            fluidMl: 0,
            carbsG: 0,
            isElectrolyte: true,
            isIndivisible: true,
          ),
        ];

        final result = _solver.solve(
          foods: foods,
          targets: const SolverTargets(
            carbsG: 25,
            sodiumMg: 600,
            fluidMl: 0, // No fluid target so water step is skipped
          ),
          activityType: ActivityType.running,
        );

        final elecServings = result
            .where((s) => s.foodId == 'electrolyte')
            .fold(0.0, (sum, s) => sum + s.quantity);
        expect(
          elecServings,
          greaterThan(0),
          reason: 'electrolyte should be added to fill sodium target',
        );
      });

      test('step 3 not triggered for running', () {
        final foods = [
          _makeFood(
            id: 'gel-a',
            productType: 'gel',
            carbsG: 25,
            sodiumMg: 50,
            isIndivisible: true,
          ),
          _makeFood(
            id: 'bar-a',
            productType: 'bar',
            carbsG: 30,
            sodiumMg: 80,
            isIndivisible: true,
          ),
          _makeFood(
            id: 'water',
            productType: 'beverage',
            fluidMl: 500,
            isLiquid: true,
          ),
        ];

        final result = _solver.solve(
          foods: foods,
          targets: const SolverTargets(carbsG: 80, sodiumMg: 200, fluidMl: 400),
          activityType: ActivityType.running,
        );

        // Bar (bike solid) should NOT appear for running
        final barSelected = result.any((s) => s.foodId == 'bar-a');
        expect(
          barSelected,
          isFalse,
          reason: 'bike solids (bar) should not be selected for running',
        );
      });
    });

    // -----------------------------------------------------------------------
    // Low carb target (<15g) skips primary carb
    // -----------------------------------------------------------------------
    test('skips primary carb when carb target is below 15g', () {
      final foods = [
        _makeFood(
          id: 'gel-a',
          productType: 'gel',
          carbsG: 25,
          sodiumMg: 50,
          isIndivisible: true,
        ),
        _makeFood(
          id: 'water',
          productType: 'beverage',
          fluidMl: 500,
          isLiquid: true,
        ),
      ];

      final result = _solver.solve(
        foods: foods,
        targets: const SolverTargets(
          carbsG: 10, // below 15g threshold
          sodiumMg: 0,
          fluidMl: 500,
        ),
        activityType: ActivityType.running,
      );

      final gelSelected = result.any((s) => s.foodId == 'gel-a');
      expect(
        gelSelected,
        isFalse,
        reason:
            'gel should be skipped when carb target < 15g (would overshoot)',
      );
    });

    // -----------------------------------------------------------------------
    // Sodium top-up reaches target, not just "sufficient"
    // (regression: https://app.notion.com/p/3abe3fdb754c814eacd8fcee2c62582a)
    // -----------------------------------------------------------------------
    group('sodium top-up drives toward target', () {
      test(
        'electrolyte capsules close the sodium gap to within one capsule of target',
        () {
          final foods = [
            _makeFood(
              id: 'gel-a',
              productType: 'gel',
              carbsG: 25,
              sodiumMg: 50,
              isIndivisible: true,
              maxServings: 6,
            ),
            _makeFood(
              id: 'sports-drink',
              productType: 'sports_drink',
              carbsG: 20,
              sodiumMg: 120,
              fluidMl: 500,
              isLiquid: true,
              maxServings: 6,
            ),
            _makeFood(
              id: 'water',
              productType: 'beverage',
              fluidMl: 500,
              sodiumMg: 0,
              isLiquid: true,
              maxServings: 10,
            ),
            _makeFood(
              id: 'elec-capsule',
              productType: 'supplement',
              sodiumMg: 250,
              carbsG: 0,
              fluidMl: 0,
              isElectrolyte: true,
              isIndivisible: true,
              maxServings: 6,
            ),
          ];

          const targets = SolverTargets(
            carbsG: 184,
            sodiumMg: 2272,
            fluidMl: 2800,
            sodiumLowMg: 1818,
            sodiumHighMg: 2726,
          );

          final result = _solver.solve(
            foods: foods,
            targets: targets,
            activityType: ActivityType.cycling,
          );

          final totalSodium = result.fold(0.0, (sum, s) => sum + s.sodiumMg);

          expect(
            totalSodium,
            greaterThanOrEqualTo(1818),
            reason:
                'total sodium must not fall below the range floor (1818 mg)',
          );
          // The capsule is 250 mg and indivisible, so the closest the solver
          // can land is within one capsule of the point target.
          expect(
            totalSodium,
            greaterThanOrEqualTo(targets.sodiumMg - 250),
            reason:
                'total sodium should reach within one capsule (250 mg) of '
                'target (2272 mg), got $totalSodium mg',
          );
        },
      );

      test(
        'electrolyte top-up stops at upper bound when target would overshoot',
        () {
          final foods = [
            _makeFood(
              id: 'gel-a',
              productType: 'gel',
              carbsG: 25,
              sodiumMg: 200,
              isIndivisible: true,
              maxServings: 6,
            ),
            _makeFood(
              id: 'water',
              productType: 'beverage',
              fluidMl: 500,
              sodiumMg: 0,
              isLiquid: true,
              maxServings: 10,
            ),
            _makeFood(
              id: 'elec-capsule',
              productType: 'supplement',
              sodiumMg: 500,
              carbsG: 0,
              fluidMl: 0,
              isElectrolyte: true,
              isIndivisible: true,
              maxServings: 6,
            ),
          ];

          // Sodium target = 800, upper = 800 * 1.1 = 880.
          // Gel will contribute significant sodium; capsules should not
          // push total above upper bound.
          const targets = SolverTargets(
            carbsG: 60,
            sodiumMg: 800,
            fluidMl: 700,
            sodiumLowMg: 640,
            sodiumHighMg: 960,
          );

          final result = _solver.solve(
            foods: foods,
            targets: targets,
            activityType: ActivityType.cycling,
          );

          final totalSodium = result.fold(0.0, (sum, s) => sum + s.sodiumMg);
          // The pass/fail bound is the real range ceiling, not a synthetic
          // target × 1.1 band.
          final sodiumUpper = targets.sodiumHighMg!;

          expect(
            totalSodium,
            lessThanOrEqualTo(sodiumUpper + 1),
            reason:
                'total sodium must not exceed upper bound ($sodiumUpper mg), '
                'got $totalSodium mg',
          );
        },
      );
    });
  });
}
