/// MealPlanController: the local-first vs remote-ack vs offline contract
/// (05 §3) through the real notifier over an in-memory Drift DB.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_plan_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_plan_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_action_client.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_exceptions.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/week_start.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/fixture_helpers.dart';
import '../helpers/container.dart';
import '../helpers/fakes.dart';

class _FakeActionClient extends Fake implements VanaActionClient {
  _FakeActionClient(this.response);

  final VanaActionResult Function(UiAction action) response;
  final List<UiAction> calls = [];

  @override
  Future<VanaActionResult> run(UiAction action) async {
    calls.add(action);
    return response(action);
  }
}

const _user = 'user-1';
final _now = DateTime.utc(2026, 9, 1, 12);

Map<String, dynamic> _planRow(String weekStart) => {
  'id': 'plan-1',
  'user_id': _user,
  'week_start': weekStart,
  'status': 'draft',
  'batch_cooking': true,
  'rules': const [],
  'shopping': const [],
  'days': const {},
  'day_notes': const {},
  'day_notes_stale': false,
  'created_at': _now.toIso8601String(),
  'updated_at': _now.toIso8601String(),
  'is_deleted': false,
};

Map<String, dynamic> _mealRow(String id) => {
  'id': id,
  'plan_id': 'plan-1',
  'user_id': _user,
  'source': 'library',
  'library_meal_id': 'D-048',
  'name': 'Meal $id',
  'meal_type': 'dinner',
  'session': null,
  'servings': 4,
  'servings_left': 4,
  'kcal': 500,
  'carbs_g': 60,
  'protein_g': 30,
  'fat_g': 15,
  'swaps_applied': const [],
  'comments': const [],
  'position': 0,
  'created_at': _now.toIso8601String(),
  'updated_at': _now.toIso8601String(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late RecordingMealPlanRemote remote;
  late MealPlanRepository repo;
  late _FakeActionClient actions;
  late StubConnectivity connectivity;
  late NoopSyncCoordinator sync;

  /// The batch fixture, retargeted onto the current week so the test does
  /// not depend on the calendar. `get_plan` (the post-upload re-read)
  /// answers with no parts so it never swaps the active plan.
  VanaActionResult batchResult(UiAction action) {
    if (action is GetPlanAction) {
      return const VanaActionResult(parts: [], extras: {});
    }
    final plan = VanaActionResult.fromJson(
      loadFixture('batch'),
    ).plan!.copyWith(weekStart: weekStartFor());
    return VanaActionResult(
      parts: [VanaBatchPart(plan: plan)],
      extras: const {},
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.memory();
    remote = RecordingMealPlanRemote()
      ..plans = [_planRow(weekStartFor())]
      ..meals = [_mealRow('pm-1'), _mealRow('pm-2')];
    repo = MealPlanRepository(
      database: db,
      logger: FakeLogger(),
      remote: remote,
    );
    await repo.syncFromRemote(_user);
    remote.calls.clear();
    actions = _FakeActionClient(batchResult);
    connectivity = StubConnectivity();
    sync = NoopSyncCoordinator();
  });

  tearDown(() => db.close());

  MealPlanController controller() {
    final container = testContainer([
      ...baseOverrides(connectivity: connectivity, sync: sync),
      appDatabaseProvider.overrideWithValue(db),
      mealPlanRepositoryProvider.overrideWithValue(repo),
      vanaActionClientProvider.overrideWithValue(actions),
    ]);
    container.listen(mealPlanControllerProvider, (_, __) {});
    return container.read(mealPlanControllerProvider.notifier);
  }

  test(
    'build emits the local plan and asks the coordinator for meal_plans',
    () async {
      final c = controller();
      final plan = await c.future;
      expect(plan!.id, 'plan-1');
      expect(plan.meals.length, 2);
      await settle();
      expect(sync.ensured, contains('meal_plans'));
    },
  );

  group('local-first', () {
    test(
      'setServings updates state through the Drift watch and replays via RPC',
      () async {
        final c = controller();
        await c.future;

        await c.setServings('pm-1', 2);
        await settle(const Duration(milliseconds: 80));

        expect(
          c.state.value!.meals.firstWhere((m) => m.id == 'pm-1').servings,
          2,
        );
        expect(remote.calls, contains('plan_set_servings:pm-1:2'));
        // After a successful replay the plan is re-read from the server.
        expect(actions.calls.whereType<GetPlanAction>(), isNotEmpty);
      },
    );

    test(
      'removeMeal works offline and leaves the row dirty for later',
      () async {
        connectivity.online = false;
        remote.failWith = StateError('offline');
        final c = controller();
        await c.future;

        await c.removeMeal('pm-2');
        await settle(const Duration(milliseconds: 80));

        expect(c.state.value!.meals.map((m) => m.id), ['pm-1']);
        final row = await (db.select(
          db.planMealsTable,
        )..where((t) => t.id.equals('pm-2'))).getSingle();
        expect(row.isDeleted, isTrue);
        expect(row.needsUpload, isTrue);
        expect(
          actions.calls,
          isEmpty,
          reason: 'no remote-ack call for a local edit',
        );
      },
    );
  });

  group('remote-ack', () {
    test('pickMeals runs the action and folds the batch into Drift', () async {
      final c = controller();
      await c.future;

      final plan = await c.pickMeals(
        const [MealPick(source: MealSource.library, id: 'D-048')],
        servings: 4,
        conversationId: 'conv-1',
      );

      final action = actions.calls.single as PickMealsAction;
      expect(action.conversationId, 'conv-1');
      expect(action.meals.single.id, 'D-048');
      expect(plan!.id, '588c137e-826c-46d4-8a73-f57b1a3d4143');
      // Applied locally as truth: same week, newer draft → now the active one.
      expect(await repo.getPlanById(plan.id), isNotNull);
      expect(c.state.hasValue, isTrue);
      expect(c.state.value!.id, plan.id);
      expect(
        await repo.getPlanById('plan-1'),
        isNotNull,
        reason: 'siblings stay until confirm',
      );
    });

    test('offline → NeedsConnectionException before any request', () async {
      connectivity.online = false;
      final c = controller();
      await c.future;

      await expectLater(
        () => c.confirmPlan(),
        throwsA(
          isA<NeedsConnectionException>().having(
            (e) => e.operation,
            'op',
            'confirm_plan',
          ),
        ),
      );
      expect(actions.calls, isEmpty);
      expect(c.state.value!.id, 'plan-1');
    });

    test('a server error is rethrown and the previous plan is kept', () async {
      actions = _FakeActionClient(
        (_) => throw const VanaServerException(
          400,
          '{"error":"nope"}',
          error: 'nope',
        ),
      );
      final c = controller();
      await c.future;

      await expectLater(
        () => c.swapMeal('pm-1', source: MealSource.library, id: 'D-001'),
        throwsA(isA<VanaServerException>()),
      );
      expect(c.state.hasValue, isTrue);
      expect(c.state.value!.meals.length, 2);
    });

    test(
      'pending local edits are flushed before the remote-ack call',
      () async {
        final c = controller();
        await c.future;
        // Make the deferred upload fail so the row is still dirty when the
        // remote-ack op runs.
        remote.failWith = StateError('blip');
        await c.setServings('pm-1', 3);
        await settle(const Duration(milliseconds: 80));
        remote.failWith = null;
        remote.calls.clear();

        await c.newPlan();

        expect(remote.calls.first, 'plan_set_servings:pm-1:3');
        expect(actions.calls.whereType<NewPlanAction>(), hasLength(1));
      },
    );

    test('logFromPlan returns the logged part', () async {
      actions = _FakeActionClient(
        (_) => VanaActionResult.fromJson(
          jsonDecode(
                '{"parts":[{"kind":"logged","planMealId":"pm-1","name":"Meal pm-1","servingsLeft":3}],"logId":"log-1"}',
              )
              as Map<String, dynamic>,
        ),
      );
      final c = controller();
      await c.future;
      final logged = await c.logFromPlan('pm-1');
      expect(logged!.servingsLeft, 3);
    });
  });
}
