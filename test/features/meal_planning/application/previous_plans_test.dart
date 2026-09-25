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
import 'package:mealvana_endurance/features/meal_planning/data/vana_exceptions.dart';
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

  /// When set, every call fails with it (the device offline).
  Object? failWith;

  @override
  Future<VanaActionResult> run(UiAction action) async {
    calls.add(action);
    if (failWith case final error?) throw error;
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

  /// Ticket 130 (Finding 89-013): a plan deleted elsewhere stayed in the
  /// Previous plans sheet after its view said "This plan is no longer
  /// here." The sheet stays open under the view (ticket 97), so a plan the
  /// view finds gone re-reads the list, which then lacks its row.
  test('a plan the view finds gone drops out of the open sheet', () async {
    server.rows.insert(0, {...rows.first, 'id': 'plan-gone'});
    final c = makeContainer(withPlan: current);
    c.listen(previousPlansProvider, (_, _) {});
    final before = await c.read(previousPlansProvider.future);
    expect(before.map((p) => p.id), contains('plan-gone'));

    // Deleted elsewhere (another device, a chat), then opened from the sheet.
    server.rows.removeWhere((r) => r['id'] == 'plan-gone');
    final plan = await c.read(earlierPlanProvider('plan-gone').future);
    expect(plan, isNull);
    await settle();

    expect(server.calls.whereType<ListPlansAction>().length, 2);
    final after = await c.read(previousPlansProvider.future);
    expect(after.map((p) => p.id), isNot(contains('plan-gone')));
  });

  // Findings 89-011 and 89-005: offline, the sheet spun 35-40 s while
  // Riverpod retried behind it, and the earlier plan view spun for good.
  // Both reads fail at once, and a re-read (the Retry) asks the server again.
  test('offline, the list and the plan view are errors at once, and a '
      'retry asks again', () async {
    server.failWith = const VanaOfflineException('socket');
    final c = makeContainer(withPlan: current);
    final list = c.listen(previousPlansProvider, (_, _) {});
    final view = c.listen(earlierPlanProvider('plan-prev-1'), (_, _) {});
    addTearDown(list.close);
    addTearDown(view.close);

    await settle(const Duration(milliseconds: 600));
    expect(c.read(previousPlansProvider), isA<AsyncError<Object?>>());
    expect(
      c.read(earlierPlanProvider('plan-prev-1')),
      isA<AsyncError<Object?>>(),
    );
    expect(server.calls, hasLength(2), reason: 'no silent retries');

    server.failWith = null;
    c.invalidate(previousPlansProvider);
    c.invalidate(earlierPlanProvider('plan-prev-1'));
    expect((await c.read(previousPlansProvider.future)).map((p) => p.id), [
      'plan-prev-1',
      'plan-prev-2',
    ]);
    expect(
      (await c.read(earlierPlanProvider('plan-prev-1').future))?.id,
      'plan-prev-1',
    );
    expect(server.calls, hasLength(4));
  });
}
