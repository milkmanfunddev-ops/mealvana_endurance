// QA conformance — pre-workout sodium, SSOT v3 (ratified 2026-08-03).
//
// v3 says there is NO pre-workout sodium target. The three sodium fields of
// PreWorkoutHydrationResult are `null` in every tier and on the gate path, and NO
// input — body weight, duration, temperature, lead time, hydrationCheck — perturbs them.
//
// `null` and `0` are DIFFERENT answers. `null` means "no statement is made"; `0` means
// "the target is zero milligrams", which would be a claim v3 does not make and which a
// consumer would render as a real target. **A 0 here is a FAILURE**, so every assertion
// below is `isNull`, never an integer comparison.
//
// The retired integer `tier` field is not read.
//
// Copied into <app>/test/ by run_dart.sh; run with --dart-define=QA_VECTORS=<path>.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/offline_macro_calculator.dart';

const List<double> kLeadGrid = <double>[
  0,
  15,
  30,
  45,
  60,
  75,
  90,
  105,
  120,
  135,
  150,
  165,
  180,
  195,
  210,
  225,
  240,
];

const List<HydrationCheck> kAllChecks = <HydrationCheck>[
  HydrationCheck.pale,
  HydrationCheck.dark,
  HydrationCheck.unknown,
];

Iterable<double> get kBodyWeights sync* {
  for (var bw = 30.0; bw <= 160.0; bw += 5.0) {
    yield bw;
  }
}

HydrationCheck parseCheck(Object? raw) {
  switch (raw as String?) {
    case 'pale':
      return HydrationCheck.pale;
    case 'dark':
      return HydrationCheck.dark;
    case 'unknown':
    case null:
      return HydrationCheck.unknown;
    default:
      throw ArgumentError('unknown hydrationCheck in vectors: $raw');
  }
}

void main() {
  // App-side adaptation of the QA conformance harness (2026-08-07). The QA
  // repo's checked-in harness is stale against its own regenerated vectors and
  // the implemented engine API, so the runnable copy lives here; docs/ssot is
  // a VERBATIM mirror of the QA repo and is never edited. Vectors are read
  // from the mirror by default; --dart-define=QA_VECTORS overrides (so the QA
  // repo's run_dart.sh can still point this at its own checkout).
  const overridePath = String.fromEnvironment('QA_VECTORS');
  final vectorsPath = overridePath.isNotEmpty
      ? overridePath
      : 'docs/ssot/vectors/fueling/pre-workout-sodium.json';

  final doc =
      jsonDecode(File(vectorsPath).readAsStringSync()) as Map<String, dynamic>;
  final vectors = (doc['vectors'] as List).cast<Map<String, dynamic>>();

  // =========================================================================
  // Layer 1 — golden vectors
  // =========================================================================
  group('pre-workout sodium conformance (${vectors.length} vectors)', () {
    for (final v in vectors) {
      final id = v['id'] as String;
      final status = (v['status'] as String?) ?? 'ratified';
      final i = v['inputs'] as Map<String, dynamic>;
      final e = v['expected'] as Map<String, dynamic>;
      final why = v['why'];

      test('[$status] $id', () {
        final out = OfflineMacroCalculator.calculatePreWorkoutHydration(
          bodyWeightKg: (i['bodyWeightKg'] as num).toDouble(),
          workoutDurationMin: (i['workoutDurationMin'] as num).toDouble(),
          timeBeforeWorkoutMin: (i['timeBeforeWorkoutMin'] as num).toDouble(),
          tempC: (i['tempC'] as num?)?.toDouble(),
          hydrationCheck: parseCheck(i['hydrationCheck']),
        );

        // Every v3 vector expects null. If a vector ever carried a number, that vector
        // contradicts the ratified spec — fail loudly rather than quietly assert it.
        void chkNull(String key, int? actual) {
          if (!e.containsKey(key)) return;
          expect(
            e[key],
            isNull,
            reason:
                '$id: the vector file expects a NUMBER for $key, but SSOT v3 ratifies '
                'null. Fix the vector, not this assertion.',
          );
          expect(
            actual,
            isNull,
            reason:
                '$id: $key must be strictly null, got $actual. '
                'A 0 is a FAILURE — it reads as a real 0 mg target. $why',
          );
        }

        chkNull('sodiumMg', out.sodiumMg);
        chkNull('sodiumLowMg', out.sodiumLowMg);
        chkNull('sodiumHighMg', out.sodiumHighMg);

        if (e.containsKey('gateTriggered')) {
          expect(
            out.gateTriggered,
            e['gateTriggered'],
            reason: '$id: gateTriggered',
          );
        }
      });
    }
  });

  // =========================================================================
  // Layer 2 — property: no input combination yields a sodium number
  // =========================================================================
  group('pre-workout sodium invariants (property)', () {
    test(
      'all three sodium fields are strictly null across the whole input domain',
      () {
        for (final bw in kBodyWeights) {
          for (final t in kLeadGrid) {
            for (final check in kAllChecks) {
              // durations/temps chosen to cover both sides of the hydration gate
              // (`workoutDurationMin < 60 AND tempC < 30`) — sodium is null on both.
              for (final dur in <double>[45, 60, 90, 180]) {
                for (final temp in <double?>[null, 5, 22, 32]) {
                  final o = OfflineMacroCalculator.calculatePreWorkoutHydration(
                    bodyWeightKg: bw,
                    workoutDurationMin: dur,
                    timeBeforeWorkoutMin: t,
                    tempC: temp,
                    hydrationCheck: check,
                  );
                  final where =
                      'BW=$bw t=$t dur=$dur temp=$temp check=$check '
                      '(gate=${o.gateTriggered})';
                  expect(
                    o.sodiumMg,
                    isNull,
                    reason: '$where: sodiumMg must be null, not 0',
                  );
                  expect(
                    o.sodiumLowMg,
                    isNull,
                    reason: '$where: sodiumLowMg must be null, not 0',
                  );
                  expect(
                    o.sodiumHighMg,
                    isNull,
                    reason: '$where: sodiumHighMg must be null, not 0',
                  );
                }
              }
            }
          }
        }
      },
    );

    test(
      'sodium is null in every tier of every plan, not just at the plan level',
      () {
        // v3: "null in EVERY tier". The tier type carries no sodium field at all, which is
        // the strongest possible form of that guarantee — assert the plan emits tiers and
        // that none of them reintroduces a sodium number at the plan level.
        for (final bw in kBodyWeights) {
          for (final t in kLeadGrid) {
            for (final check in kAllChecks) {
              final o = OfflineMacroCalculator.calculatePreWorkoutHydration(
                bodyWeightKg: bw,
                workoutDurationMin: 90,
                timeBeforeWorkoutMin: t,
                tempC: 22,
                hydrationCheck: check,
              );
              expect(
                o.tiers,
                isNotEmpty,
                reason:
                    'BW=$bw t=$t check=$check: a non-gated plan always has tiers',
              );
              expect(o.sodiumMg, isNull);
              expect(o.sodiumLowMg, isNull);
              expect(o.sodiumHighMg, isNull);
            }
          }
        }
      },
    );
  });
}
