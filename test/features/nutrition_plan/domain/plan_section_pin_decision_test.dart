import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/pin_decision.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/plan_section.dart';

void main() {
  group('BeforeSubPhase pin_decision plumbing', () {
    test('fromJson parses snake_case pin_decision (edge fn shape)', () {
      final sub = BeforeSubPhase.fromJson({
        'sub_phase_type': 'meal',
        'foods': <dynamic>[],
        'template_id': 'tpl-1',
        'template_name': 'Bagel + Jam',
        'pin_decision': {
          'used_pin': true,
          'pinned_template_id': 'tpl-1',
          'pinned_template_name': 'Bagel + Jam',
          'fallthrough_reason': null,
        },
      });
      expect(sub.pinDecision, isNotNull);
      expect(sub.pinDecision!.usedPin, isTrue);
      expect(sub.pinDecision!.pinnedTemplateName, 'Bagel + Jam');
    });

    test('fromJson parses camelCase pinDecision (round-tripped shape)', () {
      final sub = BeforeSubPhase.fromJson({
        'subPhaseType': 'snack',
        'foodItems': <dynamic>[],
        'pinDecision': {
          'used_pin': false,
          'pinned_template_id': null,
          'pinned_template_name': null,
          'fallthrough_reason': 'no_pin_for_scope',
        },
      });
      expect(sub.pinDecision, isNotNull);
      expect(sub.pinDecision!.usedPin, isFalse);
      expect(
        sub.pinDecision!.fallthroughReason,
        PinFallthroughReason.noPinForScope,
      );
    });

    test('fromJson with no pin_decision leaves field null', () {
      final sub = BeforeSubPhase.fromJson({
        'sub_phase_type': 'top_up',
        'foods': <dynamic>[],
      });
      expect(sub.pinDecision, isNull);
    });

    test('toJson omits pinDecision when null (no behavior change for '
        'pre-pin plans)', () {
      const sub = BeforeSubPhase(
        subPhaseType: 'meal',
        foodItems: <FoodItemData>[],
      );
      expect(sub.toJson().containsKey('pinDecision'), isFalse);
    });

    test('toJson includes pinDecision when set', () {
      const sub = BeforeSubPhase(
        subPhaseType: 'meal',
        foodItems: <FoodItemData>[],
        pinDecision: PinDecision(
          usedPin: true,
          pinnedTemplateId: 'tpl-1',
          pinnedTemplateName: 'Bagel + Jam',
          fallthroughReason: null,
        ),
      );
      final json = sub.toJson();
      expect(json['pinDecision'], isA<Map<String, dynamic>>());
      expect(json['pinDecision']['used_pin'], isTrue);
      expect(json['pinDecision']['pinned_template_name'], 'Bagel + Jam');
    });

    test('toJson → fromJson round-trip preserves pinDecision', () {
      const original = BeforeSubPhase(
        subPhaseType: 'top_up',
        foodItems: <FoodItemData>[],
        pinDecision: PinDecision(
          usedPin: false,
          pinnedTemplateId: null,
          pinnedTemplateName: null,
          fallthroughReason: PinFallthroughReason.noPinForScope,
        ),
      );
      final round = BeforeSubPhase.fromJson(original.toJson());
      expect(round.pinDecision, isNotNull);
      expect(round.pinDecision!.usedPin, isFalse);
      expect(
        round.pinDecision!.fallthroughReason,
        PinFallthroughReason.noPinForScope,
      );
    });

    test('copyWith updates pinDecision', () {
      const original = BeforeSubPhase(
        subPhaseType: 'meal',
        foodItems: <FoodItemData>[],
      );
      final updated = original.copyWith(
        pinDecision: const PinDecision(
          usedPin: true,
          pinnedTemplateId: 'tpl-1',
          pinnedTemplateName: 'Bagel + Jam',
          fallthroughReason: null,
        ),
      );
      expect(original.pinDecision, isNull);
      expect(updated.pinDecision, isNotNull);
      expect(updated.pinDecision!.pinnedTemplateName, 'Bagel + Jam');
    });
  });

  group('PlanSection pin_decision plumbing (during section)', () {
    test('fromJson parses snake_case pin_decision', () {
      final section = PlanSection.fromJson({
        'id': 'during_run',
        'title': 'During Run',
        'foodItems': <dynamic>[],
        'pin_decision': {
          'used_pin': true,
          'pinned_template_id': 'tpl-energy-chews',
          'pinned_template_name': 'Energy Chews',
          'fallthrough_reason': null,
        },
      });
      expect(section.pinDecision, isNotNull);
      expect(section.pinDecision!.pinnedTemplateName, 'Energy Chews');
    });

    test('fromJson with no pin_decision leaves field null '
        '(pre-pin parity)', () {
      final section = PlanSection.fromJson({
        'id': 'during_run',
        'title': 'During Run',
        'foodItems': <dynamic>[],
      });
      expect(section.pinDecision, isNull);
    });

    test('toJson → fromJson round-trip preserves pinDecision on '
        'during section', () {
      const original = PlanSection(
        id: 'during_run',
        title: 'During Run',
        foodItems: <FoodItemData>[],
        pinDecision: PinDecision(
          usedPin: true,
          pinnedTemplateId: 'tpl-energy-chews',
          pinnedTemplateName: 'Energy Chews',
          fallthroughReason: null,
        ),
      );
      final round = PlanSection.fromJson(original.toJson());
      expect(round.pinDecision, isNotNull);
      expect(round.pinDecision!.usedPin, isTrue);
      expect(round.pinDecision!.pinnedTemplateName, 'Energy Chews');
    });

    test('copyWith updates pinDecision', () {
      const original = PlanSection(
        id: 'during_run',
        title: 'During Run',
        foodItems: <FoodItemData>[],
      );
      final updated = original.copyWith(
        pinDecision: const PinDecision(
          usedPin: false,
          pinnedTemplateId: null,
          pinnedTemplateName: null,
          fallthroughReason: PinFallthroughReason.noPinForScope,
        ),
      );
      expect(updated.pinDecision, isNotNull);
      expect(updated.pinDecision!.usedPin, isFalse);
    });
  });
}
