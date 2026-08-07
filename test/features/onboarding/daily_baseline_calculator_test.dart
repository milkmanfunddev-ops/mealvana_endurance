import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/daily_baseline_calculator.dart';

/// Parity tests pinning DailyBaselineCalculator against the
/// calculate-daily-macros TS formulas via the shared fixture file. The same
/// JSON is run through the TS side by
/// `supabase/functions/calculate-daily-macros/parity-fixtures.test.ts` —
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
        expect(result.tdee, c['expected_tdee'] as int);
        expect(result.fatG, c['expected_fat_g'] as int);
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
