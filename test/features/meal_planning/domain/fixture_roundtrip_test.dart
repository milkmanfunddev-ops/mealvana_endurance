import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/home_payload.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_detail.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/plan_coverage.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_stream_event.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/wire_record.dart';

import 'fixture_helpers.dart';

void main() {
  group('VanaPart fixtures round-trip', () {
    for (final entry in {
      'choices': VanaChoicesPart,
      'meal_picker': VanaMealPickerPart,
      'staples': VanaStaplesPart,
      'day_guidance': VanaDayGuidancePart,
      'shopping_list': VanaShoppingListPart,
    }.entries) {
      test(entry.key, () {
        final json = loadFixture(entry.key);
        final part = VanaPart.fromJson(json);
        expect(part, isNotNull);
        expect(part.runtimeType, entry.value);
        expectRoundTrip(json, part!.toJson());
        // Equality is structural.
        expect(VanaPart.fromJson(json), equals(part));
        expect(VanaPart.fromJson(json).hashCode, part.hashCode);
      });
    }

    test('meal_picker carries every MealRef field', () {
      final part =
          VanaPart.fromJson(loadFixture('meal_picker')) as VanaMealPickerPart;
      expect(part.meals, isNotEmpty);
      expect(part.mealType, isNotNull);
      final m = part.meals.first;
      expect(m.source, isIn(MealSource.values));
      expect(m.icon, isNotNull, reason: 'fixture rows carry a stored icon');
      expect(m.myVote, isNotNull);
    });

    test('staples rows carry timesLogged + ticked', () {
      final part = VanaPart.fromJson(loadFixture('staples')) as VanaStaplesPart;
      expect(part.meals, isNotEmpty);
      expect(part.meals.every((s) => s.ticked), isTrue);
    });
  });

  group('action result fixtures round-trip', () {
    for (final name in ['batch', 'confirm_plan']) {
      test('$name → batch part', () {
        final json = loadFixture(name);
        final parts = VanaPart.listFromJson(json['parts']);
        expect(parts, hasLength((json['parts'] as List).length));
        expect(parts.first, isA<VanaBatchPart>());
        expectRoundTrip(json['parts'], parts.map((p) => p.toJson()).toList());
      });

      test('$name coverage matches PlanCoverageService port', () {
        final plan =
            (VanaPart.listFromJson(loadFixture(name)['parts']).first
                    as VanaBatchPart)
                .plan;
        expect(PlanCoverageService.compute(plan.meals), equals(plan.coverage));
      });
    }

    test('confirm_plan is confirmed, batch is a draft', () {
      MealPlan planOf(String name) =>
          (VanaPart.listFromJson(loadFixture(name)['parts']).first
                  as VanaBatchPart)
              .plan;
      expect(planOf('batch').isDraft, isTrue);
      expect(planOf('confirm_plan').isConfirmed, isTrue);
    });

    test('home → HomePayload', () {
      final json = loadFixture('home');
      final parts = VanaPart.listFromJson(json['parts']);
      expectRoundTrip(json['parts'], parts.map((p) => p.toJson()).toList());

      final home = HomePayload.fromJson(json['home'] as Map<String, dynamic>);
      expectRoundTrip(json['home'], home.toJson());
      expect(home.batch, isNotNull);
      expect(home.shopping, isNotNull);
      expect(home.staples, isNull, reason: 'plan exists → no staples');
      expect(home.context.budget.week, isNotEmpty);
      expect(home.vana.text, isNotNull);
      expect(home.weekTargets, isNotEmpty);
      expect(
        PlanCoverageService.compute(home.batch!.plan.meals),
        equals(home.batch!.plan.coverage),
      );
    });

    test('meal_detail → MealDetail (library, with steps)', () {
      final json = loadFixture('meal_detail');
      final detail = MealDetail.fromJson(json['meal'] as Map<String, dynamic>);
      expectRoundTrip(json['meal'], detail.toJson());
      expect(detail.meal.source, MealSource.library);
      expect(detail.hasSteps, isTrue);
      expect(detail.directions.origin, isNotNull);
      expect(detail.notes, isNull);
    });

    test('meal_detail_saved → MealDetail (saved, with notes)', () {
      final json = loadFixture('meal_detail_saved');
      final detail = MealDetail.fromJson(json['meal'] as Map<String, dynamic>);
      expectRoundTrip(json['meal'], detail.toJson());
      expect(detail.meal.source, MealSource.saved);
      expect(detail.hasSteps, isFalse);
      expect(detail.directions.origin, isNull);
      expect(detail.notes, isNotNull);
      expect(detail.ingredients.first.role, isNull);
    });

    test('recent_meals → RecentMeal list', () {
      final json = loadFixture('recent_meals');
      final meals = readRecordList(json, 'meals', RecentMeal.fromJson);
      expect(meals, hasLength((json['meals'] as List).length));
      expectRoundTrip(json['meals'], meals.map((m) => m.toJson()).toList());
      expect(meals.first.lastUsedAt, isNotEmpty);
    });
  });

  group('NDJSON chat fixtures round-trip', () {
    for (final name in ['opener', 'general_turn']) {
      test(name, () {
        final json = loadFixture(name);
        expect(json['status'], 200);
        final headers = json['headers'] as Map<String, dynamic>;
        expect(headers['x-conversation-id'], isNotEmpty);
        expect(headers['x-vana-kind'], isIn(['meal_planning', 'general']));

        final lines = (json['lines'] as List).cast<Map<String, dynamic>>();
        final events = lines.map(VanaStreamEvent.fromJson).toList();
        expect(
          events.every((e) => e != null),
          isTrue,
          reason: 'every fixture line is a known event type',
        );
        expectRoundTrip(lines, events.map((e) => e!.toJson()).toList());
        expect(events.last, isA<VanaDoneEvent>());
        expect((events.last as VanaDoneEvent).inputTokens, isPositive);
      });
    }

    test('opener streams a status then a meal_picker before its text', () {
      final lines = (loadFixture('opener')['lines'] as List)
          .cast<Map<String, dynamic>>();
      final events = lines.map(VanaStreamEvent.fromJson).toList();
      expect(events[0], isA<VanaStatusEvent>());
      expect((events[0] as VanaStatusEvent).tool, 'suggestMeals');
      expect(events[1], isA<VanaUiEvent>());
      expect((events[1] as VanaUiEvent).part, isA<VanaMealPickerPart>());
      expect(events.skip(2).take(1).first, isA<VanaTextEvent>());
    });

    test('general_turn separates text blocks with a "\\n" delta', () {
      final lines = (loadFixture('general_turn')['lines'] as List)
          .cast<Map<String, dynamic>>();
      final events = lines.map(VanaStreamEvent.fromJson).toList();
      expect(
        events.whereType<VanaTextEvent>().any((e) => e.isBlockSeparator),
        isTrue,
      );
      expect(events.whereType<VanaStatusEvent>(), hasLength(3));
    });
  });
}
