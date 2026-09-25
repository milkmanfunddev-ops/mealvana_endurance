/// `previousPlansProvider` / `earlierPlanProvider` against a stand-in for
/// `vana-action` answering in the server's own shape: `listPlans` in
/// `plan.ts` emits `{id, weekStart, status, batchCooking, mealCount}` rows
/// newest week first with deleted plans already left out; `get_plan` answers
/// a `batch` part, or no parts when the plan is gone.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_plan_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/previous_plans.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_action_client.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan_status.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';

import '../domain/fixture_helpers.dart';
import '../helpers/container.dart';

class _FixedPlanController extends MealPlanController {
  _FixedPlanController(this.plan);

  final MealPlan? plan;

  @override
  FutureOr<MealPlan?> build() => plan;
}

/// The rows `list_plans` answers, verbatim in the server's shape, and the
/// plans `get_plan` knows by id.
class _PlansServer extends Fake implements VanaActionClient {
  _PlansServer({required this.rows, required this.byId});

  final List<Map<String, dynamic>> rows;
  final Map<String, Map<String, dynamic>> byId;
  final List<UiAction> calls = [];

  @override
  Future<VanaActionResult> run(UiAction action) async {
    calls.add(action);
    switch (action) {
      case ListPlansAction():
        return VanaActionResult(parts: const [], extras: {'plans': rows});
      case GetPlanAction(:final id):
        final plan = byId[id];
        return VanaActionResult.fromJson({
          'parts': [
            if (plan != null) {'kind': 'batch', 'plan': plan},
          ],
        });
      default:
        throw UnimplementedError(action.type);
    }
  }
}

void main() {
  // The current plan on the tab is the confirmed plan the contract fixture
  // recorded; the two earlier rows are what the server would list under it.
  final currentJson =
      (loadFixture('confirm_plan')['parts'] as List).firstWhere(
            (p) => (p as Map)['kind'] == 'batch',
          )['plan']
          as Map<String, dynamic>;
  final current = MealPlan.fromJson(currentJson);

  final rows = <Map<String, dynamic>>[
    {
      'id': current.id,
      'weekStart': current.weekStart,
      'status': 'confirmed',
      'batchCooking': true,
      'mealCount': current.meals.length,
    },
    {
      'id': 'plan-prev-1',
      'weekStart': '2026-08-23',
      'status': 'archived',
      'batchCooking': false,
      'mealCount': 4,
    },
    {
      'id': 'plan-empty',
      'weekStart': '2026-08-23',
      'status': 'archived',
      'batchCooking': true,
      'mealCount': 0,
    },
    {
      'id': 'plan-prev-2',
      'weekStart': '2026-08-16',
      'status': 'confirmed',
      'batchCooking': true,
      'mealCount': 1,
    },
  ];

  late _PlansServer server;

  setUp(() {
    server = _PlansServer(
      rows: rows,
      byId: {
        current.id: currentJson,
        'plan-prev-1': {
          ...currentJson,
          'id': 'plan-prev-1',
          'status': 'archived',
        },
      },
    );
  });

  ProviderContainer makeContainer({MealPlan? withPlan}) => testContainer([
    ...baseOverrides(),
    mealPlanControllerProvider.overrideWith(
      () => _FixedPlanController(withPlan),
    ),
    vanaActionClientProvider.overrideWithValue(server),
  ]);

  test(
    'lists the earlier plans in server order, without this week or the empty ones',
    () async {
      final c = makeContainer(withPlan: current);
      final plans = await c.read(previousPlansProvider.future);

      expect(plans.map((p) => p.id), ['plan-prev-1', 'plan-prev-2']);
      expect(plans.first.weekStart, '2026-08-23');
      expect(plans.first.status, MealPlanStatus.archived);
      expect(plans.first.batchCooking, isFalse);
      expect(plans.first.mealCount, 4);
      expect(server.calls.single, isA<ListPlansAction>());
    },
  );

  test('with no plan on the tab, every listed plan with meals shows', () async {
    final c = makeContainer();
    final plans = await c.read(previousPlansProvider.future);

    expect(plans.map((p) => p.id), [current.id, 'plan-prev-1', 'plan-prev-2']);
  });

  test('a row the parser cannot read is skipped, not fatal', () async {
    server.rows.add({'id': 'broken'});
    final c = makeContainer(withPlan: current);
    final plans = await c.read(previousPlansProvider.future);

    expect(plans.map((p) => p.id), ['plan-prev-1', 'plan-prev-2']);
  });

  test('earlierPlan reads the plan the server answers with', () async {
    final c = makeContainer(withPlan: current);
    final plan = await c.read(earlierPlanProvider('plan-prev-1').future);

    expect(plan, isNotNull);
    expect(plan!.id, 'plan-prev-1');
    expect(plan.status, MealPlanStatus.archived);
    expect(plan.meals.map((m) => m.id), current.meals.map((m) => m.id));
    final call = server.calls.single as GetPlanAction;
    expect(call.id, 'plan-prev-1');
  });

  test('earlierPlan is null when the server no longer has the plan', () async {
    final c = makeContainer(withPlan: current);
    final plan = await c.read(earlierPlanProvider('plan-deleted').future);

    expect(plan, isNull);
  });
}
