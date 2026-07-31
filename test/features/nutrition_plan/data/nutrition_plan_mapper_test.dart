import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/nutrition_plan_mapper.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_shortfall.dart';

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

  group('NutritionPlanMapper during-phase shortfalls', () {
    Map<String, dynamic> planJson({List<dynamic>? shortfalls}) {
      return {
        'plan_id': 'plan_1',
        'plan_name': 'Run Plan',
        'plan_data': {
          'plan': {
            'before': <dynamic>[],
            'during': {
              'foods': <dynamic>[],
              if (shortfalls != null) 'shortfalls': shortfalls,
            },
            'after': <dynamic>[],
          },
        },
      };
    }

    test('parses during-phase shortfalls into the domain model', () {
      final plan = NutritionPlanMapper.fromSupabaseJson(
        planJson(
          shortfalls: [
            {
              'macro': 'carbs',
              'delivered': 45,
              'target': 60,
              'unit': 'g',
              'reason': 'all_disliked',
            },
            {
              'macro': 'sodium',
              'delivered': 350.5,
              'target': 500,
              'unit': 'mg',
              'reason': 'template_constraint',
            },
          ],
        ),
      );

      final during = plan.sections.firstWhere((s) => s.id == 'during_run');
      expect(during.shortfalls, hasLength(2));

      final carbs = during.shortfalls.first;
      expect(carbs.macro, ShortfallMacro.carbs);
      expect(carbs.delivered, 45);
      expect(carbs.target, 60);
      expect(carbs.unit, 'g');
      expect(carbs.reason, ShortfallReason.allDisliked);

      final sodium = during.shortfalls[1];
      expect(sodium.macro, ShortfallMacro.sodium);
      expect(sodium.delivered, 350.5);
      expect(sodium.reason, ShortfallReason.templateConstraint);
    });

    test('absent shortfalls key parses to empty without crashing', () {
      final plan = NutritionPlanMapper.fromSupabaseJson(planJson());

      final during = plan.sections.firstWhere((s) => s.id == 'during_run');
      expect(during.shortfalls, isEmpty);
    });

    test('malformed shortfall entries are skipped without crashing', () {
      final plan = NutritionPlanMapper.fromSupabaseJson(
        planJson(shortfalls: ['not-a-map', 42]),
      );

      final during = plan.sections.firstWhere((s) => s.id == 'during_run');
      expect(during.shortfalls, isEmpty);
    });

    test('shortfalls survive a local persistence round-trip', () {
      // Local Drift persistence stores plan.toJson() and rehydrates via
      // NutritionPlanMapper.fromJson -> PlanSection.fromJson, so shortfalls
      // must round-trip through section JSON to survive reload — the same
      // convention BeforeSubPhase.shortfalls already follows.
      final plan = NutritionPlanMapper.fromSupabaseJson(
        planJson(
          shortfalls: [
            {
              'macro': 'fluid',
              'delivered': 400,
              'target': 750,
              'unit': 'ml',
              'reason': 'no_diet_match',
            },
          ],
        ),
      );

      final rehydrated = NutritionPlanMapper.fromJson(
        NutritionPlanMapper.toJson(plan),
      );

      final during = rehydrated.sections.firstWhere(
        (s) => s.id == 'during_run',
      );
      expect(during.shortfalls.single.macro, ShortfallMacro.fluid);
      expect(during.shortfalls.single.delivered, 400);
      expect(during.shortfalls.single.target, 750);
      expect(during.shortfalls.single.unit, 'ml');
      expect(during.shortfalls.single.reason, ShortfallReason.noDietMatch);
    });
  });

  test('maps brick segment shortfalls onto their section', () {
    final plan = NutritionPlanMapper.fromSupabaseJson({
      'plan_id': 'brick_plan',
      'plan_name': 'Brick Plan',
      'plan_data': {
        'plan': {
          'before': <String, dynamic>{},
          'during_segments': {'1': <dynamic>[]},
          'during_segment_shortfalls': {
            '1': [
              {
                'macro': 'carbs',
                'delivered': 40,
                'target': 80,
                'unit': 'g',
                'reason': 'template_constraint',
              },
            ],
          },
          'transitions': <String, dynamic>{},
          'after': <dynamic>[],
        },
        'macro_targets': {
          'pre_run': <String, dynamic>{},
          'during_run': <String, dynamic>{},
          'post_run': <String, dynamic>{},
          'phases': {
            'during_segments': [
              {
                'segment_order': 1,
                'sport': 'cycling',
                'carbs_g': 80,
                'sodium_mg': 0,
                'water_ml': 0,
              },
            ],
            'transitions': <dynamic>[],
          },
        },
      },
    });

    final segment = plan.sections.singleWhere(
      (section) => section.id == 'during_segment_1',
    );
    expect(segment.shortfalls, hasLength(1));
    expect(segment.shortfalls.single.macro, ShortfallMacro.carbs);
    expect(
      segment.shortfalls.single.reason,
      ShortfallReason.templateConstraint,
    );
  });
}
