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

  // INTERIM behavior pending the SSOT ruling in
  // qa/intake/2026-08-20-session-cost-unknown-activity-types.md — see
  // ops/data/bug-reports/2026-08-20-session-cost-unknown-sport-priced-as-running.md.
  // Deliberately un-vectored: session-demand.json pins no unmapped-sport case.
  group('sessionCost unmapped sports (INTERIM, bug 2026-08-20)', () {
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

    test('unmapped sports use the conservative linear strength rate (5) '
        'and are flagged by name', () {
      const unmapped = ['other', 'triathlon', 'duathlon', 'multisport', 'brick'];
      final logs = captureDebugPrint(() {
        for (final sport in unmapped) {
          final kcal = DailyBaselineCalculator.sessionCost(
            sport: sport,
            durationHr: 1.0,
            intensityFactor: 0.75,
            weightKg: 70,
          );
          // 5 kcal/kg/hr, linear, IF at reference 0.75: 5 × 1 × 1 × 70.
          expect(kcal, closeTo(350, 0.001), reason: sport);
        }
      });
      expect(logs, hasLength(unmapped.length));
      for (final sport in unmapped) {
        expect(logs.any((l) => l.contains('"$sport"')), isTrue, reason: sport);
      }
    });

    test('regression: 60-min foam roll (other, IF 0.74, 70 kg) is no longer '
        '~750 kcal', () {
      late final double kcal;
      captureDebugPrint(() {
        kcal = DailyBaselineCalculator.sessionCost(
          sport: 'other',
          durationHr: 1.0,
          intensityFactor: 0.74,
          weightKg: 70,
        );
      });
      expect(kcal, closeTo(5 * (0.74 / 0.75) * 1.0 * 70, 0.001)); // ≈345.3
      expect(kcal, lessThan(400));
    });

    test('unmapped sport scales linearly with IF, not quadratically', () {
      late final double low;
      late final double high;
      captureDebugPrint(() {
        low = DailyBaselineCalculator.sessionCost(
          sport: 'other',
          durationHr: 1.0,
          intensityFactor: 0.45,
          weightKg: 70,
        );
        high = DailyBaselineCalculator.sessionCost(
          sport: 'other',
          durationHr: 1.0,
          intensityFactor: 0.90,
          weightKg: 70,
        );
      });
      expect(high / low, closeTo(2.0, 1e-9)); // quadratic would give 4.0
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
        expect(result.tdee, closeTo((c['expected_tdee'] as num).toDouble(), tol));
        expect(result.fatG, closeTo((c['expected_fat_g'] as num).toDouble(), tol));
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
        final before = (c['carb_g'] as num) * 4 +
            (c['prot_g'] as num) * 4 +
            tdee.fatG * 9;
        final after = capped.carbG * 4 +
            (c['prot_g'] as num) * 4 +
            capped.fatG * 9;
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
}
