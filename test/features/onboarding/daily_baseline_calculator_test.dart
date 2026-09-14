import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/daily_baseline_calculator.dart';

/// Parity tests pinning DailyBaselineCalculator against the
/// calculate-daily-macros TS formulas via the shared fixture file. The same
/// JSON is run through the TS side by
/// `supabase/functions/calculate-daily-macros-v6/parity-fixtures.test.ts` —
/// a drift on either side breaks its test.
void main() {
  final fixtures =
      jsonDecode(
            File(
              'test/features/onboarding/fixtures/plan_preview_parity.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  group('RMR parity (rmr.ts)', () {
    for (final raw in fixtures['rmr'] as List) {
      final c = raw as Map<String, dynamic>;
      test(c['name'] as String, () {
        final result = DailyBaselineCalculator.calculateRmr(
          weightKg: (c['weight_kg'] as num).toDouble(),
          heightCm: (c['height_cm'] as num).toDouble(),
          age: c['age'] as int,
          isMale: c['sex'] == 'male',
          bodyFatPct: (c['body_fat_pct'] as num?)?.toDouble(),
        );
        expect(result, closeTo((c['expected'] as num).toDouble(), 1e-9));
      });
    }
  });

  group('baseline macros parity (baseline.ts)', () {
    for (final raw in fixtures['baseline'] as List) {
      final c = raw as Map<String, dynamic>;
      test(c['name'] as String, () {
        final result = DailyBaselineCalculator.baselineMacros(
          weightKg: (c['weight_kg'] as num).toDouble(),
          lbmKg: (c['lbm_kg'] as num?)?.toDouble(),
          age: c['age'] as int,
        );
        expect(
          result.carbG,
          closeTo((c['expected_carb_g'] as num).toDouble(), 1e-9),
        );
        expect(
          result.protG,
          closeTo((c['expected_prot_g'] as num).toDouble(), 1e-9),
        );
      });
    }
  });

  group('macro clamps parity (baseline.ts clampMacros)', () {
    for (final raw in fixtures['clamp'] as List) {
      final c = raw as Map<String, dynamic>;
      test(c['name'] as String, () {
        final result = DailyBaselineCalculator.clampMacros(
          carbG: (c['carb_g'] as num).toDouble(),
          protG: (c['prot_g'] as num).toDouble(),
          weightKg: (c['weight_kg'] as num).toDouble(),
        );
        expect(
          result.carbG,
          closeTo((c['expected_carb_g'] as num).toDouble(), 1e-9),
        );
        expect(
          result.protG,
          closeTo((c['expected_prot_g'] as num).toDouble(), 1e-9),
        );
      });
    }
  });

  group('session parity (session.ts)', () {
    for (final raw in fixtures['session'] as List) {
      final c = raw as Map<String, dynamic>;
      test(c['name'] as String, () {
        final intensityFactor = DailyBaselineCalculator.zoneDistributionToIf(
          pctConversational: (c['pct_conversational'] as num).toDouble(),
          pctTempo: (c['pct_tempo'] as num).toDouble(),
          pctAllout: (c['pct_allout'] as num).toDouble(),
        );
        expect(
          intensityFactor,
          closeTo(
            (c['expected_if'] as num).toDouble(),
            (c['if_tolerance'] as num).toDouble(),
          ),
        );

        final kcal = DailyBaselineCalculator.sessionCost(
          sport: c['sport'] as String,
          durationHr: (c['duration_hr'] as num).toDouble(),
          intensityFactor: intensityFactor,
          weightKg: (c['weight_kg'] as num).toDouble(),
        );
        expect(
          kcal,
          closeTo(
            (c['expected_kcal'] as num).toDouble(),
            (c['kcal_tolerance'] as num).toDouble(),
          ),
        );

        final carb = DailyBaselineCalculator.carbDemand(
          sport: c['sport'] as String,
          intensityFactor: intensityFactor,
          durationHr: (c['duration_hr'] as num).toDouble(),
          weightKg: (c['weight_kg'] as num).toDouble(),
        );
        expect(
          carb,
          closeTo(
            (c['expected_carb_g'] as num).toDouble(),
            (c['carb_tolerance'] as num).toDouble(),
          ),
        );
      });
    }
  });

  // F4a (session-demand.md, RULED Xuan 2026-09-10): resolves the 2026-08-20
  // unknown-sport intake. Vectored by the f4a-* rows of session-demand.json
  // (match the deno twin's index.test.ts F4a group).
  group('sessionCost F4a (unknown / mobility / composite)', () {
    List<String> captureDebugPrint(void Function() body) {
      final logs = <String>[];
      final previous = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        logs.add(message ?? '');
      };
      try {
        body();
      } finally {
        debugPrint = previous;
      }
      return logs;
    }

    test('unknown sports contribute exactly 0 with the estimate flag', () {
      const unknowns = ['other', 'zumba', 'esports'];
      final logs = captureDebugPrint(() {
        for (final sport in unknowns) {
          final r = DailyBaselineCalculator.sessionCostF4a(
            sport: sport,
            durationHr: 1.0,
            intensityFactor: 0.75,
            weightKg: 70,
          );
          expect(r.kcal, 0, reason: sport);
          expect(r.estimateFlag, isTrue, reason: sport);
        }
      });
      for (final sport in unknowns) {
        expect(logs.any((l) => l.contains('"$sport"')), isTrue, reason: sport);
      }
    });

    test('regression: 60-min foam roll prices at the MOBILITY rate — not '
        '~750 (running fallback), not ~345 (interim floor)', () {
      final r = DailyBaselineCalculator.sessionCostF4a(
        sport: 'foam_rolling',
        durationHr: 1.0,
        intensityFactor: 0.74,
        weightKg: 70,
      );
      expect(r.kcal, closeTo(2.5 * (0.74 / 0.75) * 1.0 * 70, 0.001)); // ≈172.7
      expect(r.estimateFlag, isFalse);
    });

    test('mobility scales linearly with IF, not quadratically', () {
      final low = DailyBaselineCalculator.sessionCost(
        sport: 'mobility',
        durationHr: 1.0,
        intensityFactor: 0.45,
        weightKg: 70,
      );
      final high = DailyBaselineCalculator.sessionCost(
        sport: 'mobility',
        durationHr: 1.0,
        intensityFactor: 0.90,
        weightKg: 70,
      );
      expect(high / low, closeTo(2.0, 1e-9)); // quadratic would give 4.0
    });

    test('composites decompose by legs; dominant leg when no legs; unknown '
        'rung with neither', () {
      // Brick 2-leg vector shape: bike 9·70·(0.85/0.75)² + run 11·70·(0.80/0.75)²·0.5
      final legs = DailyBaselineCalculator.sessionCostF4a(
        sport: 'brick',
        durationHr: 1.5,
        intensityFactor: 0.8,
        weightKg: 70,
        legs: const [
          (sport: 'cycling', durationHr: 1.0, intensityFactor: 0.85),
          (sport: 'running', durationHr: 0.5, intensityFactor: 0.8),
        ],
      );
      expect(legs.kcal, closeTo(1247.244, 0.01));
      expect(legs.estimateFlag, isFalse);

      final dominant = DailyBaselineCalculator.sessionCostF4a(
        sport: 'triathlon',
        durationHr: 2.0,
        intensityFactor: 0.75,
        weightKg: 75,
        dominantSport: 'cycling',
      );
      expect(dominant.kcal, closeTo(1350.0, 0.001));

      final bare = captureDebugPrint(() {
        for (final sport in const [
          'triathlon',
          'duathlon',
          'multisport',
          'brick',
        ]) {
          final r = DailyBaselineCalculator.sessionCostF4a(
            sport: sport,
            durationHr: 1.0,
            intensityFactor: 0.75,
            weightKg: 70,
          );
          expect(r.kcal, 0, reason: sport);
          expect(r.estimateFlag, isTrue, reason: sport);
        }
      });
      // Composite fall-through hits the unknown rung silently (the flag
      // carries the signal); no per-sport name logging is required.
      expect(bare, isA<List<String>>());
    });

    test('mapped sports are unchanged and not flagged', () {
      final logs = captureDebugPrint(() {
        expect(
          DailyBaselineCalculator.sessionCost(
            sport: 'running',
            durationHr: 1.5,
            intensityFactor: 0.74,
            weightKg: 75,
          ),
          closeTo(11 * math.pow(0.74 / 0.75, 2) * 1.5 * 75, 0.001),
        );
        expect(
          DailyBaselineCalculator.sessionCost(
            sport: 'cycling',
            durationHr: 1.25,
            intensityFactor: 0.93,
            weightKg: 75,
          ),
          closeTo(9 * math.pow(0.93 / 0.75, 2) * 1.25 * 75, 0.001),
        );
        expect(
          DailyBaselineCalculator.sessionCost(
            sport: 'swimming',
            durationHr: 1.0,
            intensityFactor: 0.80,
            weightKg: 75,
          ),
          closeTo(7 * math.pow(0.80 / 0.75, 2) * 1.0 * 75, 0.001),
        );
        expect(
          DailyBaselineCalculator.sessionCost(
            sport: 'strength',
            durationHr: 1.0,
            intensityFactor: 0.70,
            weightKg: 75,
          ),
          closeTo(5 * (0.70 / 0.75) * 1.0 * 75, 0.001),
        );
      });
      expect(logs, isEmpty);
    });
  });

  group('TDEE convergence parity (neat-tef.ts)', () {
    for (final raw in fixtures['tdee'] as List) {
      final c = raw as Map<String, dynamic>;
      test(c['name'] as String, () {
        final result = DailyBaselineCalculator.calculateTdee(
          rmr: (c['rmr'] as num).toDouble(),
          neat: (c['neat'] as num).toDouble(),
          sessionKcal: (c['session_kcal'] as num).toDouble(),
          carbG: (c['carb_g'] as num).toDouble(),
          protG: (c['prot_g'] as num).toDouble(),
          weightKg: (c['weight_kg'] as num).toDouble(),
        );
        final tol = (c['tolerance'] as num).toDouble();
        expect(
          result.tdee,
          closeTo((c['expected_tdee'] as num).toDouble(), tol),
        );
        expect(
          result.fatG,
          closeTo((c['expected_fat_g'] as num).toDouble(), tol),
        );
        expect(result.tef, closeTo((c['expected_tef'] as num).toDouble(), tol));
        expect(result.fatAtFloor, c['expected_fat_at_floor'] as bool);
      });
    }
  });

  group('fat cap parity (pipeline.ts applyFatCap, Q-014)', () {
    for (final raw in fixtures['fat_cap'] as List) {
      final c = raw as Map<String, dynamic>;
      test(c['name'] as String, () {
        final tdee = DailyBaselineCalculator.calculateTdee(
          rmr: (c['rmr'] as num).toDouble(),
          neat: (c['neat'] as num).toDouble(),
          sessionKcal: (c['session_kcal'] as num).toDouble(),
          carbG: (c['carb_g'] as num).toDouble(),
          protG: (c['prot_g'] as num).toDouble(),
          weightKg: (c['weight_kg'] as num).toDouble(),
        );
        final capped = DailyBaselineCalculator.applyFatCap(
          carbG: (c['carb_g'] as num).toDouble(),
          fatG: tdee.fatG,
          tdee: tdee.tdee,
          weightKg: (c['weight_kg'] as num).toDouble(),
        );
        final tol = (c['tolerance'] as num).toDouble();
        expect(
          capped.carbG,
          closeTo((c['expected_carb_g'] as num).toDouble(), tol),
        );
        expect(
          capped.fatG,
          closeTo((c['expected_fat_g'] as num).toDouble(), tol),
        );
        // Energy conservation (I10): intake identical across the cap.
        final before =
            (c['carb_g'] as num) * 4 + (c['prot_g'] as num) * 4 + tdee.fatG * 9;
        final after =
            capped.carbG * 4 + (c['prot_g'] as num) * 4 + capped.fatG * 9;
        expect(after, closeTo(before, 1e-6));
      });
    }
  });

  group('NEAT tiers (neat-tef.ts inferVolumeTier)', () {
    test('weekly-hours bands match the TS tiers', () {
      expect(DailyBaselineCalculator.baseNeatForWeeklyHours(null), 0.25);
      expect(DailyBaselineCalculator.baseNeatForWeeklyHours(4.9), 0.30);
      expect(DailyBaselineCalculator.baseNeatForWeeklyHours(5), 0.25);
      expect(DailyBaselineCalculator.baseNeatForWeeklyHours(8), 0.20);
      expect(DailyBaselineCalculator.baseNeatForWeeklyHours(12), 0.17);
      expect(DailyBaselineCalculator.baseNeatForWeeklyHours(18), 0.13);
    });
  });

  group('session-demand kcal vectors (twin parity with the deno runner)', () {
    // The deno comparator (vectors.conformance.test.ts) is the primary
    // runner for these rows, incl. the 9 f4a-* additions; this group runs
    // the SAME kcal rows through the Dart twin so the two implementations
    // cannot drift (D-005 discipline).
    final file = File('docs/ssot/vectors/daily-macros/session-demand.json');
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final vectors = (data['vectors'] as List).cast<Map<String, dynamic>>();
    final tol = ((data['tolerance'] as num?) ?? 0.5).toDouble();

    for (final v in vectors) {
      final e = v['expected'] as Map<String, dynamic>;
      if (!e.containsKey('kcal')) continue;
      test(v['id'] as String, () {
        final i = v['inputs'] as Map<String, dynamic>;
        final legsRaw = i['legs'] as List?;
        final r = DailyBaselineCalculator.sessionCostF4a(
          sport: (i['sport'] as String).toLowerCase(),
          durationHr: ((i['durationHr'] as num?) ?? 0).toDouble(),
          intensityFactor: ((i['IF'] as num?) ?? 0.75).toDouble(),
          weightKg: (i['weightKg'] as num).toDouble(),
          legs: legsRaw
              ?.map((l) => (
                    sport: ((l as Map)['sport'] as String).toLowerCase(),
                    durationHr: (l['durationHr'] as num).toDouble(),
                    intensityFactor: (l['IF'] as num).toDouble(),
                  ))
              .toList(),
          dominantSport: (i['dominantSport'] as String?)?.toLowerCase(),
        );
        expect(r.kcal, closeTo((e['kcal'] as num).toDouble(), tol));
        if (e.containsKey('estimateFlag')) {
          expect(r.estimateFlag, e['estimateFlag'] as bool);
        }
      });
    }
  });

}
