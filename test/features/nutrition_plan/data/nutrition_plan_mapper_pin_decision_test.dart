import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/pin_decision.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/nutrition_plan_mapper.dart';

/// Verifies that pin_decision telemetry emitted by plan-v3 / macros-v4 lands
/// on the right PlanSection / BeforeSubPhase after the Supabase-shaped JSON
/// is run through NutritionPlanMapper.fromSupabaseJson.
///
/// Formula Kit PR 2 substep 9.
void main() {
  group('NutritionPlanMapper.fromSupabaseJson pin_decision wiring', () {
    test('Before sub-phases carry their per-phase pin_decision', () {
      final plan = NutritionPlanMapper.fromSupabaseJson({
        'plan_id': 'plan_1',
        'plan_name': 'Test Plan',
        'plan_data': {
          'plan': {
            'before': {
              'meal': {
                'sub_phase_type': 'meal',
                'foods': <dynamic>[],
                'template_id': 'tpl-meal',
                'template_name': 'Bagel + Jam',
                'pin_decision': {
                  'used_pin': true,
                  'pinned_template_id': 'tpl-meal',
                  'pinned_template_name': 'Bagel + Jam',
                  'fallthrough_reason': null,
                },
              },
              'top_up': {
                'sub_phase_type': 'top_up',
                'foods': <dynamic>[],
                'pin_decision': {
                  'used_pin': false,
                  'pinned_template_id': null,
                  'pinned_template_name': null,
                  'fallthrough_reason': 'no_pin_for_scope',
                },
              },
            },
            'during': <dynamic>[],
            'after': <dynamic>[],
          },
        },
      });

      final beforeSection =
          plan.sections.firstWhere((s) => s.id == 'before_run');
      expect(beforeSection.subPhases, isNotNull);
      expect(beforeSection.subPhases!.length, 2);

      final meal = beforeSection.subPhases!
          .firstWhere((s) => s.subPhaseType == 'meal');
      expect(meal.pinDecision, isNotNull);
      expect(meal.pinDecision!.usedPin, isTrue);
      expect(meal.pinDecision!.pinnedTemplateName, 'Bagel + Jam');

      final topUp = beforeSection.subPhases!
          .firstWhere((s) => s.subPhaseType == 'top_up');
      expect(topUp.pinDecision, isNotNull);
      expect(topUp.pinDecision!.usedPin, isFalse);
      expect(
        topUp.pinDecision!.fallthroughReason,
        PinFallthroughReason.noPinForScope,
      );
    });

    test('During section pin_decision is extracted from the during Map '
        '(not the foods list)', () {
      final plan = NutritionPlanMapper.fromSupabaseJson({
        'plan_id': 'plan_1',
        'plan_name': 'Test Plan',
        'plan_data': {
          'plan': {
            'before': <String, dynamic>{},
            'during': {
              'foods': <dynamic>[],
              'pin_decision': {
                'used_pin': true,
                'pinned_template_id': 'tpl-chews',
                'pinned_template_name': 'Energy Chews',
                'fallthrough_reason': null,
              },
            },
            'after': <dynamic>[],
          },
        },
      });

      final duringSection =
          plan.sections.firstWhere((s) => s.id == 'during_run');
      expect(duringSection.pinDecision, isNotNull);
      expect(duringSection.pinDecision!.usedPin, isTrue);
      expect(
        duringSection.pinDecision!.pinnedTemplateName,
        'Energy Chews',
      );
    });

    test('Pre-pin plans (no pin_decision anywhere) parse with null '
        'pinDecision fields — byte-identical to pre-PR-2 behavior', () {
      final plan = NutritionPlanMapper.fromSupabaseJson({
        'plan_id': 'plan_1',
        'plan_name': 'Test Plan',
        'plan_data': {
          'plan': {
            'before': {
              'meal': {
                'sub_phase_type': 'meal',
                'foods': <dynamic>[],
              },
            },
            'during': {'foods': <dynamic>[]},
            'after': <dynamic>[],
          },
        },
      });

      final beforeSection =
          plan.sections.firstWhere((s) => s.id == 'before_run');
      final meal = beforeSection.subPhases!
          .firstWhere((s) => s.subPhaseType == 'meal');
      expect(meal.pinDecision, isNull);

      final duringSection =
          plan.sections.firstWhere((s) => s.id == 'during_run');
      expect(duringSection.pinDecision, isNull);
    });

    test('During pin_decision coexists with by_hour_data', () {
      // Regression guard: my edit changed from a single copyWith(byHourData:)
      // to a chained two-step copyWith. Make sure both fields survive.
      final plan = NutritionPlanMapper.fromSupabaseJson({
        'plan_id': 'plan_1',
        'plan_name': 'Test Plan',
        'plan_data': {
          'plan': {
            'before': <String, dynamic>{},
            'during': {
              'foods': <dynamic>[],
              'by_hour_data': {
                'durationMinutes': 90,
                'assignments': <dynamic>[],
              },
              'pin_decision': {
                'used_pin': true,
                'pinned_template_id': 'tpl-chews',
                'pinned_template_name': 'Energy Chews',
                'fallthrough_reason': null,
              },
            },
            'after': <dynamic>[],
          },
        },
      });

      final duringSection =
          plan.sections.firstWhere((s) => s.id == 'during_run');
      expect(duringSection.pinDecision, isNotNull);
      expect(
        duringSection.pinDecision!.pinnedTemplateName,
        'Energy Chews',
      );
      expect(duringSection.byHourData, isNotNull,
          reason: 'by_hour_data must survive the chained copyWith');
    });
  });
}
