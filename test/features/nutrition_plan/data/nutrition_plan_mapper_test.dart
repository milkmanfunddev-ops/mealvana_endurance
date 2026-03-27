import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/nutrition_plan_mapper.dart';

void main() {
  group('NutritionPlanMapper brick ranges', () {
    test('maps per-segment and transition low/high targets from phases', () {
      final plan = NutritionPlanMapper.fromSupabaseJson({
        'plan_id': 'plan_1',
        'plan_name': 'Brick Plan',
        'plan_data': {
          'plan': {
            'before': {
              'meal': {'sub_phase_type': 'meal', 'foods': []},
            },
            'during_segments': {'1': [], '2': [], '3': []},
            'transitions': {'T1': [], 'T2': []},
            'after': [],
          },
          'macro_targets': {
            'pre_run': {'carbs_g': 90, 'sodium_mg': 400, 'water_ml': 500},
            'during_run': {'carbs_g': 100, 'sodium_mg': 1000, 'water_ml': 1500},
            'post_run': {'carbs_g': 80, 'sodium_mg': 600, 'water_ml': 900},
            'phases': {
              'before': {
                'carbs_g': 90,
                'carbs_low_g': 80,
                'carbs_high_g': 100,
                'sodium_mg': 400,
                'sodium_low_mg': 340,
                'sodium_high_mg': 460,
                'water_ml': 500,
                'water_low_ml': 425,
                'water_high_ml': 575,
              },
              'during_segments': [
                {
                  'segment_order': 1,
                  'sport': 'swimming',
                  'carbs_g': 0,
                  'carbs_low_g': 0,
                  'carbs_high_g': 0,
                  'sodium_mg': 0,
                  'sodium_low_mg': 0,
                  'sodium_high_mg': 0,
                  'water_ml': 0,
                  'water_low_ml': 0,
                  'water_high_ml': 0,
                },
                {
                  'segment_order': 2,
                  'sport': 'cycling',
                  'carbs_g': 58,
                  'carbs_low_g': 52,
                  'carbs_high_g': 64,
                  'sodium_mg': 824,
                  'sodium_low_mg': 742,
                  'sodium_high_mg': 906,
                  'water_ml': 1124,
                  'water_low_ml': 955,
                  'water_high_ml': 1293,
                },
                {
                  'segment_order': 3,
                  'sport': 'running',
                  'carbs_g': 12,
                  'carbs_low_g': 10,
                  'carbs_high_g': 15,
                  'sodium_mg': 607,
                  'sodium_low_mg': 546,
                  'sodium_high_mg': 668,
                  'water_ml': 384,
                  'water_low_ml': 326,
                  'water_high_ml': 442,
                },
              ],
              'transitions': [
                {
                  'transition_name': 'T1',
                  'carbs_g': 0,
                  'carbs_low_g': 0,
                  'carbs_high_g': 0,
                  'sodium_mg': 0,
                  'sodium_low_mg': 0,
                  'sodium_high_mg': 0,
                  'water_ml': 50,
                  'water_low_ml': 45,
                  'water_high_ml': 55,
                },
                {
                  'transition_name': 'T2',
                  'carbs_g': 10,
                  'carbs_low_g': 9,
                  'carbs_high_g': 11,
                  'sodium_mg': 100,
                  'sodium_low_mg': 90,
                  'sodium_high_mg': 110,
                  'water_ml': 100,
                  'water_low_ml': 85,
                  'water_high_ml': 115,
                },
              ],
              'after': {
                'carbs_g': 80,
                'carbs_low_g': 64,
                'carbs_high_g': 96,
                'protein_g': 25,
                'protein_low_g': 20,
                'protein_high_g': 30,
                'sodium_mg': 600,
                'sodium_low_mg': 510,
                'sodium_high_mg': 690,
                'water_ml': 900,
                'water_low_ml': 765,
                'water_high_ml': 1035,
              },
            },
          },
        },
      });

      final runSection = plan.sections.firstWhere(
        (s) => s.id == 'during_segment_3',
      );
      expect(runSection.carbsTarget, 12);
      expect(runSection.carbsLowTarget, 10);
      expect(runSection.carbsHighTarget, 15);
      expect(runSection.sodiumTarget, 607);
      expect(runSection.sodiumLowTarget, 546);
      expect(runSection.sodiumHighTarget, 668);
      expect(runSection.fluidsTarget, 384);
      expect(runSection.fluidsLowTarget, 326);
      expect(runSection.fluidsHighTarget, 442);

      final t2Section = plan.sections.firstWhere((s) => s.id == 'T2');
      expect(t2Section.carbsTarget, 10);
      expect(t2Section.carbsLowTarget, 9);
      expect(t2Section.carbsHighTarget, 11);
      expect(t2Section.sodiumLowTarget, 90);
      expect(t2Section.sodiumHighTarget, 110);
      expect(t2Section.fluidsLowTarget, 85);
      expect(t2Section.fluidsHighTarget, 115);
    });
  });
}
