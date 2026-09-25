/// MealPlanController: the local-first vs remote-ack vs offline contract
/// (05 §3) through the real notifier over an in-memory Drift DB.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_plan_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_plan_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/user_memory_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_setting.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_action_client.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_exceptions.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/plan_rule.dart';
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
    'a Monday week start moves the week the controller binds to (mp-269)',
    () async {
      final memories = UserMemoryRepository(
        database: db,
        logger: FakeLogger(),
        remote: RecordingUserMemoryRemote(),
      );
      final c = controller();
      await c.future;
      expect(c.weekStart, weekStartFor());

      await memories.setSetting(_user, VanaSetting.weekStart, 'mon');
      await memories.setSetting(_user, VanaSetting.periodDays, 10);
      await settle(const Duration(milliseconds: 80));
      await c.future;

      expect(c.weekStart, weekStartFor(null, DateTime.monday));
      expect(DateTime.parse(c.weekStart).weekday, DateTime.monday);
      // The Sunday plan is not this week's any more.
      expect(c.state.value, isNull);
    },
  );

  test(
    'a plan read under a ten-day period counts coverage over ten days',
    () async {
      final memories = UserMemoryRepository(
        database: db,
        logger: FakeLogger(),
        remote: RecordingUserMemoryRemote(),
      );
      await memories.setSetting(_user, VanaSetting.periodDays, 10);
      final c = controller();
      final plan = await c.future;
      expect(plan!.coverage.periodDays, 10);
      expect(plan.coverage.lunchDinnerSlots, 20);
      expect(plan.coverage.covered, 8);
    },
  );

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

  /// Testing-wave 18-003 (ticket 34): "Browse meals" reads the
  /// conversation's own plan to tick what is already in it. Drift answers
  /// first; the server's copy is folded in behind it.
  group('conversationDraft', () {
    test('emits the conversation\'s local plan, null for a stranger', () async {
      remote.plans = [
        _planRow(weekStartFor()),
        {
          ..._planRow(weekStartFor()),
          'id': 'plan-2',
          'conversation_id': 'conv-1',
        },
      ];
      remote.meals = [
        _mealRow('pm-1'),
        {..._mealRow('pm-9'), 'plan_id': 'plan-2', 'library_meal_id': 'D-900'},
      ];
      await repo.syncFromRemote(_user);
      final container = testContainer([
        ...baseOverrides(connectivity: connectivity, sync: sync),
        appDatabaseProvider.overrideWithValue(db),
        mealPlanRepositoryProvider.overrideWithValue(repo),
        vanaActionClientProvider.overrideWithValue(actions),
      ]);

      // Held like a screen would hold them: an unwatched autodispose
      // provider is dropped before its first emission lands.
      container.listen(conversationDraftProvider('conv-1'), (_, __) {});
      container.listen(conversationDraftProvider('conv-none'), (_, __) {});

      final plan = await container.read(
        conversationDraftProvider('conv-1').future,
      );
      expect(plan!.id, 'plan-2');
      expect(plan.meals.map((m) => m.libraryMealId), ['D-900']);
      expect(
        await container.read(conversationDraftProvider('conv-none').future),
        isNull,
      );
    });

    test('folds the server\'s copy into Drift when nothing is local', () async {
      final serverPlan = VanaActionResult.fromJson(
        loadFixture('batch'),
      ).plan!.copyWith(weekStart: weekStartFor(), conversationId: 'conv-2');
      actions = _FakeActionClient(
        (action) => action is GetPlanAction && action.conversationId == 'conv-2'
            ? VanaActionResult(
                parts: [VanaBatchPart(plan: serverPlan)],
                extras: const {},
              )
            : const VanaActionResult(parts: [], extras: {}),
      );
      final container = testContainer([
        ...baseOverrides(connectivity: connectivity, sync: sync),
        appDatabaseProvider.overrideWithValue(db),
        mealPlanRepositoryProvider.overrideWithValue(repo),
        vanaActionClientProvider.overrideWithValue(actions),
      ]);

      final seen = <MealPlan?>[];
      container.listen(conversationDraftProvider('conv-2'), (_, next) {
        if (next.hasValue) seen.add(next.value);
      });
      await settle(const Duration(milliseconds: 120));

      expect(seen.last!.id, serverPlan.id);
      expect(await repo.getPlanById(serverPlan.id), isNotNull);
      expect(
        actions.calls.whereType<GetPlanAction>().single.conversationId,
        'conv-2',
      );
    });
  });

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

    /// Testing-wave 16-001 (ticket 34): an unscoped `confirm_plan` lands on
    /// the week's active plan, which puts an old confirmed plan before the
    /// Draft on screen. The wire must carry the conversation and its plan.
    test('confirmPlan carries the conversation and plan scope', () async {
      final c = controller();
      await c.future;

      await c.confirmPlan(conversationId: 'conv-1', planId: 'plan-1');

      final sent = actions.calls.whereType<ConfirmPlanAction>().single;
      expect(sent.toPayloadJson(), {
        'planId': 'plan-1',
        'conversationId': 'conv-1',
      });
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

    test(
      'acceptRule sends the rule back accepted and folds the plan',
      () async {
        final c = controller();
        await c.future;
        const rule = PlanRule(
          day: PlanRuleDay.fri,
          rule: "Mirinda Carfrae's race-eve plate",
          accepted: false,
        );
        await c.acceptRule(rule, conversationId: 'conv-1');

        final sent = actions.calls.whereType<AcceptRuleAction>().single;
        expect(
          sent.rule.accepted,
          isTrue,
          reason:
              'accept_rule must flip accepted:true — the server stores '
              'the payload as given.',
        );
        expect(sent.rule.rule, rule.rule);
        expect(sent.conversationId, 'conv-1');
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

    /// Lee's 09-16 demo: a plan could not be deleted by hand. The producer
    /// answers a `receipt` and no `batch` — the plan is gone — so nothing is
    /// applied and the local copy goes on the follow-up sync.
    test(
      'deletePlan sends delete_plan and returns the server receipt',
      () async {
        final result = VanaActionResult.fromJson({
          'parts': [loadFixture('receipt_delete_plan')],
        });
        actions = _FakeActionClient((_) => result);
        final c = controller();
        await c.future;

        final receipt = await c.deletePlan();

        final sent = actions.calls.whereType<DeletePlanAction>().single;
        expect(sent.type, 'delete_plan');
        expect(
          sent.toPayloadJson(),
          isEmpty,
          reason: 'no id → the active plan',
        );
        expect(receipt!.action, VanaReceiptAction.deletePlan);
        expect(receipt.entity, VanaReceiptEntity.plan);
        expect(receipt.undo!.params['action'], 'delete_plan');
        expect(sync.ensured, contains('force:meal_plans'));
      },
    );

    test('deletePlan names a plan when given one', () async {
      actions = _FakeActionClient(
        (_) => VanaActionResult.fromJson({
          'parts': [loadFixture('receipt_delete_plan')],
        }),
      );
      final c = controller();
      await c.future;
      await c.deletePlan(id: 'plan-1');
      expect(
        actions.calls.whereType<DeletePlanAction>().single.toPayloadJson(),
        {'id': 'plan-1'},
      );
    });

    test('undoDeletePlan sends the receipt undo params verbatim', () async {
      final receiptJson = loadFixture('receipt_delete_plan');
      actions = _FakeActionClient(
        (action) => action is UndoReceiptAction
            ? VanaActionResult.fromJson({
                'parts': [
                  {...receiptJson, 'action': 'undo', 'undo': null},
                ],
              })
            : VanaActionResult.fromJson({
                'parts': [receiptJson],
              }),
      );
      final c = controller();
      await c.future;

      final receipt = await c.deletePlan();
      await c.undoDeletePlan(receipt!);

      final undo = actions.calls.whereType<UndoReceiptAction>().single;
      expect(undo.toPayloadJson(), receiptJson['undo']['params']);
    });
  });
}
