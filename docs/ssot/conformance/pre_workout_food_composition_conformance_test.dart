// QA conformance — pre-workout-food-composition v3 (87 vectors)
//
// Runs via:  qa/conformance/run_dart.sh pre-workout-food-composition
// (copied into the app checkout as test/_qa_conformance_tmp_test.dart and run
// with --dart-define=QA_VECTORS=<abs path to the ratified vector file>).
//
// Engine under test: the published suitability entry point built by the
// food-recommendation@v1 bundle (deferred item P10) —
// `package:mealvana_endurance/features/nutrition_plan/domain/pre_workout_food_composition.dart`.
//
// Vector families and how each maps onto the engine:
//   * feeding vectors ({verdict, failedGate, knownException[, failedRule]}) →
//     assessFeeding() over the summed feeding (check 4: never per item).
//     failedRule 'matrix' is a §3.10 Layer A rejection and has no H-number.
//   * matrix vectors ({available, rating}) → matrixRating()/matrixAvailable().
//   * matrix-coverage-complete → the groups/tiers enumerations + the
//     every-group-rated property.
//   * matrix-groups-are-disjoint [characterization] → groupsForFood(): §11
//     check 9's "exactly one group" is unsatisfiable as written (G9 overlaps
//     G3/G8 deliberately); the vector records the defect and this harness
//     asserts the truthful overlap, never the unsatisfiable check.
//
// knownException convention (§11 check 1): the two documented exceptions are
// the t−25 banana (passes only via H4's soft-solid allowance over H2's 2 g
// line — the engine must FLAG that pass, `fibreWaivedBySoftSolidAllowance`)
// and the 3 oz chicken meal (a canonical §3.11 feeding that fails H3 — the
// fail itself is the documented exception; the vector's flag records it, and
// this harness asserts the engine's fail matches gate-for-gate). Concretely:
//   expected pass + knownException  → engine passes AND flags the waiver;
//   expected pass + !knownException → engine passes and does NOT flag it;
//   expected fail                   → engine fails on exactly expected.failedGate
//                                     (or the matrix), knownException being the
//                                     vector file's documentation of check 1.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/pre_workout_food_composition.dart';

// ---------------------------------------------------------------------------
// Wire → domain adapters
// ---------------------------------------------------------------------------

FeedingInput _feedingFromWire(Map<String, dynamic> i) {
  double d(String k, [double fallback = 0]) =>
      (i[k] as num?)?.toDouble() ?? fallback;
  return FeedingInput(
    tier: FeedingTier.fromWire(i['tier'] as String),
    bodyWeightKg: d('bodyWeightKg', 65),
    gutTolerance: GutTolerance.fromWire(i['gutTolerance'] as String),
    fatG: d('fatG'),
    fibreG: d('fibreG'),
    proteinG: d('proteinG'),
    carbG: d('carbG'),
    foodGroup: i['foodGroup'] == null
        ? null
        : FoodGroup.fromWire(i['foodGroup'] as String),
    form: FeedingForm.fromWire(i['form'] as String? ?? 'solid'),
    drinkCarbPct: (i['drinkCarbPct'] as num?)?.toDouble(),
    practised: i['practised'] as bool? ?? true,
    isBolus: i['isBolus'] as bool? ?? false,
    withChaseWater: i['withChaseWater'] as bool? ?? false,
    volumeMl: (i['volumeMl'] as num?)?.toDouble(),
    softLowResidue: i['softLowResidue'] as bool? ?? false,
    leadTimeMin: (i['leadTimeMin'] as num?)?.toDouble(),
  );
}

HardGate _gateFromWire(String wire) => switch (wire) {
      'H1' => HardGate.h1,
      'H2' => HardGate.h2,
      'H3' => HardGate.h3,
      'H4' => HardGate.h4,
      'H5' => HardGate.h5,
      'H6' => HardGate.h6,
      'H7' => HardGate.h7,
      _ => throw ArgumentError.value(wire, 'wire', 'unknown hard gate'),
    };

void main() {
  const vectorsPath = String.fromEnvironment('QA_VECTORS');
  if (vectorsPath.isEmpty) {
    throw StateError(
      'QA_VECTORS not set — run via qa/conformance/run_dart.sh '
      'pre-workout-food-composition',
    );
  }
  final file = File(vectorsPath);
  if (!file.existsSync()) {
    throw StateError('QA_VECTORS file missing: $vectorsPath');
  }
  final doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final vectors = (doc['vectors'] as List).cast<Map<String, dynamic>>();

  test('vector count sanity', () {
    // 87 at ratification; a lower count means the wrong file is wired in.
    expect(vectors.length, greaterThanOrEqualTo(87),
        reason: 'expected the full ratified vector set');
  });

  for (final v in vectors) {
    final id = v['id'] as String;
    final status = v['status'] as String? ?? 'ratified';
    final inputs = v['inputs'] as Map<String, dynamic>;
    final expected = v['expected'] as Map<String, dynamic>;
    final why = v['why'] as String? ?? '';

    test('[$status] $id', () {
      // --- pure matrix-coverage vector ------------------------------------
      if (expected.containsKey('everyGroupRatedInEveryTier')) {
        expect(
          FoodGroup.values.map((g) => g.wireName).toList(),
          (expected['groups'] as List).cast<String>(),
          reason: why,
        );
        expect(
          FeedingTier.values.map((t) => t.wireName).toList(),
          (expected['tiers'] as List).cast<String>(),
          reason: why,
        );
        expect(everyGroupRatedInEveryTier,
            expected['everyGroupRatedInEveryTier'] as bool,
            reason: why);
        return;
      }

      // --- named-food group membership (characterization tripwire) --------
      if (inputs.containsKey('food')) {
        final groups = groupsForFood(inputs['food'] as String);
        expect(groups.length == 1, expected['belongsToExactlyOneGroup'] as bool,
            reason: why);
        expect(
          groups.map((g) => g.wireName).toList()..sort(),
          (expected['groups'] as List).cast<String>()..sort(),
          reason: why,
        );
        return;
      }

      // --- matrix rating vector -------------------------------------------
      if (expected.containsKey('rating')) {
        final group = FoodGroup.fromWire(inputs['foodGroup'] as String);
        final tier = FeedingTier.fromWire(inputs['tier'] as String);
        final gut = GutTolerance.fromWire(inputs['gutTolerance'] as String);
        expect(matrixAvailable(group, tier, gut), expected['available'] as bool,
            reason: why);
        expect(
          matrixRating(group, tier, gut).name.toUpperCase(),
          expected['rating'] as String,
          reason: why,
        );
        return;
      }

      // --- full feeding assessment ----------------------------------------
      final assessment = assessFeeding(_feedingFromWire(inputs));
      final expectPass = (expected['verdict'] as String) == 'pass';
      final knownException = expected['knownException'] as bool? ?? false;

      expect(assessment.passes, expectPass, reason: why);

      if (expectPass) {
        expect(assessment.failedGate, isNull, reason: why);
        expect(assessment.failedMatrix, isFalse, reason: why);
        // §11 check 1: a pass that rides the soft-solid allowance must be
        // flagged, and an ordinary pass must not be.
        expect(assessment.fibreWaivedBySoftSolidAllowance, knownException,
            reason: 'documented-exception flag must match — $why');
      } else if (expected['failedRule'] == 'matrix') {
        expect(assessment.failedMatrix, isTrue, reason: why);
        expect(assessment.failedGate, isNull, reason: why);
      } else {
        expect(assessment.failedMatrix, isFalse, reason: why);
        expect(assessment.failedGate,
            _gateFromWire(expected['failedGate'] as String),
            reason: 'gate identity is contractual — $why');
      }
    });
  }
}
