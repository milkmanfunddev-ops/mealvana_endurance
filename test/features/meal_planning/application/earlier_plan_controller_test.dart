/// Ticket 73 (testing-wave, Finding 17-002; mp-675): an earlier plan opened
/// from Previous plans is edited, renamed, deleted or used again through the
/// real [EarlierPlan] notifier.
///
/// The stand-in for `vana-action` answers in the server's own shape: every
/// plan edit a `batch` part whose plan is what `hydrate` in `plan.ts` emits
/// (the contract fixture's plan, re-stamped as an archived plan with a
/// `name`), `delete_plan` a receipt and no batch, and `use_plan_again` a
/// fresh draft for this week with the same meals under new row ids.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_plan_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/previous_plans.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_action_client.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_exceptions.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan_status.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';

import '../domain/fixture_helpers.dart';
import '../helpers/container.dart';
import '../helpers/fakes.dart';

/// This week's plan on the tab, and a record of what was folded into Drift.
class _TabController extends MealPlanController {
  final List<MealPlan> applied = [];
  final List<String?> confirmed = [];
  int refreshed = 0;

  @override
  FutureOr<MealPlan?> build() => null;

  @override
  Future<void> applyServerPlan(MealPlan plan) async => applied.add(plan);

  @override
  Future<void> refresh() async => refreshed++;

  @override
  Future<MealPlan?> confirmPlan({
    String? date,
    String? conversationId,
    String? planId,
  }) async {
    confirmed.add(planId);
    return null;
  }
}

class _Server extends Fake implements VanaActionClient {
  _Server(this.plans);

  /// Plan id → the plan JSON the server holds, edited in place by the calls.
  final Map<String, Map<String, dynamic>> plans;
  final List<UiAction> calls = [];
  Object? failWith;

  Map<String, dynamic> _batch(Map<String, dynamic> plan) => {
    'parts': [
      {'kind': 'batch', 'plan': plan},
    ],
  };

  Map<String, dynamic> _planOfMeal(String planMealId) =>
      plans.values.firstWhere(
        (p) => (p['meals'] as List).any((m) => m['id'] == planMealId),
      );

  @override
  Future<VanaActionResult> run(UiAction action) async {
    calls.add(action);
    final fail = failWith;
    if (fail != null) throw fail;
    switch (action) {
      case GetPlanAction(:final id):
        final plan = plans[id];
        return VanaActionResult.fromJson({
          'parts': [
            if (plan != null) {'kind': 'batch', 'plan': plan},
          ],
        });
      case SetServingsAction(:final planMealId, :final servings):
        final plan = _planOfMeal(planMealId);
        for (final m in (plan['meals'] as List).cast<Map<String, dynamic>>()) {
          if (m['id'] == planMealId) m['servings'] = servings;
        }
        return VanaActionResult.fromJson(_batch(plan));
      case RemoveMealAction(:final planMealId):
        final plan = _planOfMeal(planMealId);
        (plan['meals'] as List).removeWhere((m) => m['id'] == planMealId);
        return VanaActionResult.fromJson(_batch(plan));
      case RenamePlanAction(:final id, :final name):
        final plan = plans[id]!;
        final clean = name.trim();
        plan['name'] = clean.isEmpty ? null : clean;
        return VanaActionResult.fromJson(_batch(plan));
      case DeletePlanAction(:final id):
        plans.remove(id);
        return VanaActionResult.fromJson({
          'parts': [
            {
              'kind': 'receipt',
              'action': 'delete_plan',
              'entity': 'plan',
              'summary': 'Deleted the plan for Sep 14 – Sep 20',
              'entityId': id,
              'undo': {
                'action': 'undo_receipt',
                'params': {'action': 'delete_plan', 'id': id},
              },
            },
          ],
        });
      case UsePlanAgainAction(:final id):
        final source = plans[id]!;
        final copy = {
          ...source,
          'id': 'plan-copy',
          'weekStart': '2026-10-04',
          'status': 'draft',
          'conversationId': null,
          'meals': [
            for (final (i, m)
                in (source['meals'] as List)
                    .cast<Map<String, dynamic>>()
                    .indexed)
              {
                ...m,
                'id': 'copy-meal-$i',
                'planId': 'plan-copy',
                'servingsLeft': m['servings'],
              },
          ],
        };
        plans['plan-copy'] = copy;
        return VanaActionResult.fromJson(_batch(copy));
      default:
        throw UnimplementedError(action.type);
    }
  }
}

void main() {
  const earlierId = 'plan-sep14';
  late Map<String, dynamic> earlierJson;
  late _Server server;
  late _TabController tab;
  late StubConnectivity connectivity;

  setUp(() {
    final fixturePlan =
        (loadFixture('confirm_plan')['parts'] as List).firstWhere(
              (p) => (p as Map)['kind'] == 'batch',
            )['plan']
            as Map<String, dynamic>;
    // A deep copy the server can edit in place, re-stamped as a plan a
    // later plan replaced, with the athlete's own name on it.
    earlierJson = (jsonDecode(jsonEncode(fixturePlan)) as Map<String, dynamic>)
      ..['id'] = earlierId
      ..['weekStart'] = '2026-09-14'
      ..['status'] = 'archived'
      ..['name'] = 'Race block';
    for (final m in (earlierJson['meals'] as List).cast<Map>()) {
      m['planId'] = earlierId;
    }
    server = _Server({earlierId: earlierJson});
    tab = _TabController();
    connectivity = StubConnectivity();
  });

  ProviderContainer makeContainer() => testContainer([
    ...baseOverrides(connectivity: connectivity),
    mealPlanControllerProvider.overrideWith(() => tab),
    vanaActionClientProvider.overrideWithValue(server),
  ]);

  Future<(ProviderContainer, EarlierPlan)> opened() async {
    final c = makeContainer();
    final sub = c.listen(earlierPlanProvider(earlierId), (_, _) {});
    addTearDown(sub.close);
    await c.read(earlierPlanProvider(earlierId).future);
    return (c, c.read(earlierPlanProvider(earlierId).notifier));
  }

  test('opens the plan the server answers, name and all', () async {
    final (c, _) = await opened();
    final plan = c.read(earlierPlanProvider(earlierId)).value!;

    expect(plan.id, earlierId);
    expect(plan.name, 'Race block');
    expect(plan.status, MealPlanStatus.archived);
    expect((server.calls.single as GetPlanAction).id, earlierId);
  });

  test('edit: servings change on the earlier plan itself', () async {
    final (c, notifier) = await opened();
    final meal = c.read(earlierPlanProvider(earlierId)).value!.meals.first;

    await notifier.setServings(meal.id, meal.servings + 2);

    final call = server.calls.last as SetServingsAction;
    expect(call.toJson(), {
      'type': 'set_servings',
      'payload': {'planMealId': meal.id, 'servings': meal.servings + 2},
    });
    final after = c.read(earlierPlanProvider(earlierId)).value!;
    expect(after.meals.first.servings, meal.servings + 2);
    // An archived plan is history, not this week's: nothing goes to Drift.
    expect(tab.applied, isEmpty);
  });

  test('edit: a meal removed leaves the earlier plan without it', () async {
    final (c, notifier) = await opened();
    final meals = c.read(earlierPlanProvider(earlierId)).value!.meals;

    await notifier.removeMeal(meals.first.id);

    expect(server.calls.last, isA<RemoveMealAction>());
    expect(
      c.read(earlierPlanProvider(earlierId)).value!.meals.map((m) => m.id),
      meals.skip(1).map((m) => m.id),
    );
  });

  test('rename: sends the name and shows the one the server kept', () async {
    final (c, notifier) = await opened();

    await notifier.rename('  Taper week ');

    expect(server.calls.last.toJson(), {
      'type': 'rename_plan',
      'payload': {'id': earlierId, 'name': '  Taper week '},
    });
    expect(c.read(earlierPlanProvider(earlierId)).value!.name, 'Taper week');
  });

  test(
    'delete: the plan is gone and the tab is not re-read for history',
    () async {
      final (c, notifier) = await opened();

      await notifier.delete();

      expect((server.calls.last as DeletePlanAction).id, earlierId);
      expect(c.read(earlierPlanProvider(earlierId)).value, isNull);
      expect(tab.refreshed, 0);
    },
  );

  test('use again: a new draft for this week goes to the Plan tab, and the '
      'earlier plan stays as it was', () async {
    final (c, notifier) = await opened();
    final before = c.read(earlierPlanProvider(earlierId)).value!;

    final copy = await notifier.useAgain();

    expect((server.calls.last as UsePlanAgainAction).toJson(), {
      'type': 'use_plan_again',
      'payload': {'id': earlierId},
    });
    expect(copy, isNotNull);
    expect(copy!.id, 'plan-copy');
    expect(copy.status, MealPlanStatus.draft);
    expect(copy.weekStart, '2026-10-04');
    expect(
      copy.meals.map((m) => (m.name, m.servings)),
      before.meals.map((m) => (m.name, m.servings)),
    );
    expect(tab.applied.single.id, 'plan-copy');
    final after = c.read(earlierPlanProvider(earlierId)).value!;
    expect(after.id, earlierId);
    expect(after.status, MealPlanStatus.archived);
  });

  test(
    'confirm: a draft opened here is confirmed as this week\'s plan',
    () async {
      server.plans['plan-copy'] = {
        ...earlierJson,
        'id': 'plan-copy',
        'status': 'draft',
      };
      final c = makeContainer();
      final sub = c.listen(earlierPlanProvider('plan-copy'), (_, _) {});
      addTearDown(sub.close);
      await c.read(earlierPlanProvider('plan-copy').future);

      await c.read(earlierPlanProvider('plan-copy').notifier).confirm();

      expect(tab.confirmed, ['plan-copy']);
    },
  );

  test('offline: nothing is sent and the plan on screen stays', () async {
    final (c, notifier) = await opened();
    connectivity.online = false;
    final calls = server.calls.length;

    await expectLater(
      notifier.rename('Anything'),
      throwsA(isA<NeedsConnectionException>()),
    );

    expect(server.calls.length, calls);
    expect(c.read(earlierPlanProvider(earlierId)).value!.name, 'Race block');
  });

  test('a failed write keeps the plan on screen and rethrows', () async {
    final (c, notifier) = await opened();
    server.failWith = const VanaServerException(500, '{"error":"boom"}');

    await expectLater(notifier.useAgain(), throwsA(isA<VanaException>()));

    final state = c.read(earlierPlanProvider(earlierId));
    expect(state.hasError, isFalse);
    expect(state.value!.id, earlierId);
    expect(tab.applied, isEmpty);
  });
}
