import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/cooking_session.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_type.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/plan_meal.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/plan_rule.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_setting.dart';

/// Payload keys are what the prototype's `server/vana/actions.ts` reads.
void main() {
  void check(UiAction a, String type, Map<String, Object?> payload) {
    expect(a.type, type);
    expect(a.toPayloadJson(), payload);
    expect(a.toJson(), {'type': type, 'payload': payload});
  }

  group('UiAction.toPayloadJson', () {
    test('pick_meals', () {
      check(
        const PickMealsAction(
          meals: [
            MealPick(source: MealSource.library, id: 'D-048'),
            MealPick(source: MealSource.saved, id: 'uuid'),
          ],
          servings: 4,
          session: CookingSession.cookSun,
          conversationId: 'c1',
        ),
        'pick_meals',
        {
          'conversationId': 'c1',
          'meals': [
            {'source': 'library', 'id': 'D-048'},
            {'source': 'saved', 'id': 'uuid'},
          ],
          'servings': 4,
          'session': 'cook-sun',
        },
      );
    });

    test('pick_meals minimal omits optional keys', () {
      check(
        const PickMealsAction(
          meals: [MealPick(source: MealSource.library, id: 'D-1')],
        ),
        'pick_meals',
        {
          'meals': [
            {'source': 'library', 'id': 'D-1'},
          ],
        },
      );
    });

    test('pick_meals sendSession emits an explicit null', () {
      expect(
        const PickMealsAction(meals: [], sendSession: true).toPayloadJson(),
        {'meals': [], 'session': null},
      );
    });

    test('unpick_meal', () {
      check(
        const UnpickMealAction(
          source: MealSource.saved,
          id: 'u1',
          planId: 'p1',
        ),
        'unpick_meal',
        {'planId': 'p1', 'source': 'saved', 'id': 'u1'},
      );
    });

    test('swap_meal', () {
      check(
        const SwapMealAction(
          planMealId: 'pm1',
          source: MealSource.library,
          id: 'D-2',
        ),
        'swap_meal',
        {'planMealId': 'pm1', 'source': 'library', 'id': 'D-2'},
      );
    });

    test('remove_meal', () {
      check(const RemoveMealAction(planMealId: 'pm1'), 'remove_meal', {
        'planMealId': 'pm1',
      });
    });

    test('set_servings', () {
      check(
        const SetServingsAction(planMealId: 'pm1', servings: 6),
        'set_servings',
        {'planMealId': 'pm1', 'servings': 6},
      );
    });

    test('set_session (null clears)', () {
      check(
        const SetSessionAction(
          planMealId: 'pm1',
          session: CookingSession.topupWed,
        ),
        'set_session',
        {'planMealId': 'pm1', 'session': 'topup-wed'},
      );
      check(const SetSessionAction(planMealId: 'pm1'), 'set_session', {
        'planMealId': 'pm1',
        'session': null,
      });
    });

    test('apply_swap', () {
      check(
        const ApplySwapAction(
          planMealId: 'pm1',
          swap: SwapApplied(from: 'water', to: 'milk', effect: '+10g protein'),
        ),
        'apply_swap',
        {
          'planMealId': 'pm1',
          'from': 'water',
          'to': 'milk',
          'effect': '+10g protein',
        },
      );
      expect(
        const ApplySwapAction(
          planMealId: 'pm1',
          swap: SwapApplied(from: 'a', to: 'b'),
        ).toPayloadJson().containsKey('effect'),
        isFalse,
      );
    });

    test('add_comment', () {
      check(
        const AddCommentAction(planMealId: 'pm1', text: 'less salt'),
        'add_comment',
        {'planMealId': 'pm1', 'role': 'user', 'text': 'less salt'},
      );
      expect(
        const AddCommentAction(
          planMealId: 'pm1',
          role: PlanCommentRole.vana,
          text: 'x',
        ).toPayloadJson()['role'],
        'vana',
      );
    });

    test('accept_rule always sends accepted', () {
      check(
        const AcceptRuleAction(
          rule: PlanRule(
            day: PlanRuleDay.wed,
            rule: 'Pasta night',
            mealId: 'D-9',
            accepted: true,
          ),
        ),
        'accept_rule',
        {
          'day': 'wed',
          'rule': 'Pasta night',
          'mealId': 'D-9',
          'accepted': true,
        },
      );
      expect(
        const AcceptRuleAction(
          rule: PlanRule(day: PlanRuleDay.mon, rule: 'r', accepted: false),
        ).toPayloadJson(),
        {'day': 'mon', 'rule': 'r', 'accepted': false},
      );
    });

    test('confirm_plan', () {
      check(const ConfirmPlanAction(), 'confirm_plan', {});
      check(
        const ConfirmPlanAction(date: '2026-09-01', conversationId: 'c1'),
        'confirm_plan',
        {'conversationId': 'c1', 'date': '2026-09-01'},
      );
    });

    test('toggle_shopping', () {
      check(
        const ToggleShoppingAction(
          name: 'Eggs',
          field: ShoppingField.have,
          value: true,
        ),
        'toggle_shopping',
        {'name': 'Eggs', 'field': 'have', 'value': true},
      );
      expect(
        const ToggleShoppingAction(
          name: 'Eggs',
          field: ShoppingField.checked,
          value: false,
        ).toPayloadJson()['field'],
        'checked',
      );
    });

    test('log_from_plan', () {
      check(const LogFromPlanAction(planMealId: 'pm1'), 'log_from_plan', {
        'planMealId': 'pm1',
      });
      check(
        const LogFromPlanAction(planMealId: 'pm1', mealType: MealType.lunch),
        'log_from_plan',
        {'planMealId': 'pm1', 'mealType': 'lunch'},
      );
    });

    test('set_setting', () {
      check(
        const SetSettingAction(key: VanaSetting.batchCooking, value: true),
        'set_setting',
        {'key': 'batch_cooking', 'value': true},
      );
      check(
        const SetSettingAction(key: VanaSetting.showMacros, value: false),
        'set_setting',
        {'key': 'show_macros', 'value': false},
      );
    });

    test('delete_memory', () {
      check(const DeleteMemoryAction(id: 'm1'), 'delete_memory', {'id': 'm1'});
    });

    test('list_memories', () {
      check(const ListMemoriesAction(), 'list_memories', {});
    });

    test('set_day_slot', () {
      check(
        const SetDaySlotAction(
          date: '2026-09-02',
          slot: MealType.dinner,
          source: DaySlotSource.plan,
          id: 'pm1',
          name: 'Chili',
        ),
        'set_day_slot',
        {
          'date': '2026-09-02',
          'slot': 'dinner',
          'source': 'plan',
          'id': 'pm1',
          'name': 'Chili',
        },
      );
      check(
        const SetDaySlotAction(
          slot: MealType.lunch,
          source: DaySlotSource.library,
          id: 'D-1',
        ),
        'set_day_slot',
        {'slot': 'lunch', 'source': 'library', 'id': 'D-1'},
      );
    });

    test('clear_day_slot', () {
      check(const ClearDaySlotAction(slot: MealType.snack), 'clear_day_slot', {
        'slot': 'snack',
      });
      check(
        const ClearDaySlotAction(date: '2026-09-02', slot: MealType.breakfast),
        'clear_day_slot',
        {'date': '2026-09-02', 'slot': 'breakfast'},
      );
    });

    test('plan_day', () {
      check(const PlanDayAction(), 'plan_day', {});
      check(const PlanDayAction(date: '2026-09-03'), 'plan_day', {
        'date': '2026-09-03',
      });
    });

    test('new_plan', () {
      check(const NewPlanAction(), 'new_plan', {});
      check(const NewPlanAction(conversationId: 'c1'), 'new_plan', {
        'conversationId': 'c1',
      });
    });

    test('get_plan', () {
      check(const GetPlanAction(), 'get_plan', {});
      check(const GetPlanAction(id: 'p1'), 'get_plan', {'id': 'p1'});
    });

    test('list_plans', () {
      check(const ListPlansAction(), 'list_plans', {});
    });

    test('save_meal', () {
      check(const SaveMealAction(libraryMealId: 'D-048'), 'save_meal', {
        'libraryMealId': 'D-048',
      });
    });

    test('get_home', () {
      check(const GetHomeAction(), 'get_home', {});
      check(const GetHomeAction(date: '2026-09-01'), 'get_home', {
        'date': '2026-09-01',
      });
    });

    test('get_meal', () {
      check(const GetMealAction(id: 'D-048'), 'get_meal', {'id': 'D-048'});
    });

    test('recent_meals', () {
      check(const RecentMealsAction(), 'recent_meals', {});
      check(const RecentMealsAction(limit: 50), 'recent_meals', {'limit': 50});
    });

    test('set_saved_meal_notes', () {
      check(
        const SetSavedMealNotesAction(savedMealId: 'u1', notes: 'Add chili'),
        'set_saved_meal_notes',
        {'savedMealId': 'u1', 'notes': 'Add chili'},
      );
    });

    test('set_meal_feedback', () {
      check(
        const SetMealFeedbackAction(
          libraryMealId: 'D-1',
          vote: -1,
          reason: 'too spicy',
        ),
        'set_meal_feedback',
        {'libraryMealId': 'D-1', 'vote': -1, 'reason': 'too spicy'},
      );
      check(
        const SetMealFeedbackAction(savedMealId: 'u1', vote: 1),
        'set_meal_feedback',
        {'savedMealId': 'u1', 'vote': 1},
      );
    });

    test('rewind / pantry_photo / set_pantry (plan Phases 6.1, 7.3)', () {
      check(
        const RewindAction(conversationId: 'c1', messageId: 'm-7'),
        'rewind',
        {'conversationId': 'c1', 'messageId': 'm-7'},
      );
      check(
        const PantryPhotoAction(
          conversationId: 'c1',
          photoPath: 'user-1/abc.jpg',
        ),
        'pantry_photo',
        {'conversationId': 'c1', 'photoPath': 'user-1/abc.jpg'},
      );
      check(
        const SetPantryAction(conversationId: 'c1', items: ['eggs', 'rice']),
        'set_pantry',
        {
          'conversationId': 'c1',
          'items': ['eggs', 'rice'],
        },
      );
    });

    test('scope keys come first and never leak when unset', () {
      final payload = const RemoveMealAction(
        planMealId: 'pm1',
        planId: 'p1',
        conversationId: 'c1',
      ).toPayloadJson();
      expect(payload.keys.toList(), ['planId', 'conversationId', 'planMealId']);
      expect(const RemoveMealAction(planMealId: 'pm1').toPayloadJson().keys, [
        'planMealId',
      ]);
    });
  });
}
