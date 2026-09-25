/// MealPlanController: the local-first vs remote-ack vs offline contract
/// (05 §3) through the real notifier over an in-memory Drift DB.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/application/home_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_plan_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/youre_set_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_plan_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/user_memory_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_setting.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_action_client.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_exceptions.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/home_payload.dart';
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

/// The Plan tab's home payload, standing in for `get_home`: counts how
/// often a plan write asks it to read again (ticket 130, Finding 88-023).
class _RecordingHomeController extends HomeController {
  int builds = 0;
  int planChanges = 0;

  @override
  Future<HomePayload?> build([String? date]) async {
    builds++;
    return null;
  }

  @override
  Future<void> planChanged() async => planChanges++;
}

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

/// A `vana-action` that holds each answer until the test releases it, so a
/// test can look at the row while the write is on the wire.
class _GatedActionClient extends Fake implements VanaActionClient {
  _GatedActionClient(this.answer);

  final Future<VanaActionResult> Function(UiAction action) answer;
  final List<UiAction> calls = [];

  @override
  Future<VanaActionResult> run(UiAction action) {
    calls.add(action);
    return answer(action);
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
  late _RecordingHomeController home;
  late ProviderContainer container;

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
    home = _RecordingHomeController();
  });

  tearDown(() => db.close());

  MealPlanController controller({FakeLogger? logger}) {
    container = testContainer([
      ...baseOverrides(connectivity: connectivity, sync: sync, logger: logger),
      appDatabaseProvider.overrideWithValue(db),
      mealPlanRepositoryProvider.overrideWithValue(repo),
      vanaActionClientProvider.overrideWithValue(actions),
      homeControllerProvider.overrideWith(() => home),
    ]);
    container.listen(mealPlanControllerProvider, (_, __) {});
    return container.read(mealPlanControllerProvider.notifier);
  }

  /// The Plan tab is open: its day note is on screen and watching.
  void openPlanTab() => container.listen(homeControllerProvider(), (_, _) {});

  /// Ticket 130 (Finding 88-023): after a confirm the Plan tab's Vana note
  /// kept naming the old plan's meal until a relaunch, because the home
  /// payload was never read again. Every plan write that lands asks the
  /// note to read again — and only while the tab is there to show it.
  group('home payload follows the plan', () {
    test(
      'a remote-ack write (confirmPlan) re-reads the home payload',
      () async {
        final c = controller();
        await c.future;
        openPlanTab();
        await settle();
        expect(home.planChanges, 0);

        await c.confirmPlan(planId: 'plan-1');
        await settle();

        expect(home.planChanges, 1);
      },
    );

    test(
      'a local-first write re-reads it once the replay has landed',
      () async {
        final c = controller();
        await c.future;
        openPlanTab();
        await settle();

        await c.setServings('pm-1', 2);
        await settle(const Duration(milliseconds: 80));

        expect(home.planChanges, 1);
      },
    );

    test('a refused remote-ack write leaves the note alone', () async {
      actions = _FakeActionClient(
        (_) => throw const VanaServerException(400, '{"error":"nope"}'),
      );
      final c = controller();
      await c.future;
      openPlanTab();
      await settle();

      await expectLater(c.confirmPlan(planId: 'plan-1'), throwsA(anything));
      await settle();

      expect(home.planChanges, 0);
    });

    test('with the Plan tab closed nothing is read: no get_home for a tab '
        'nobody is looking at', () async {
      final c = controller();
      await c.future;

      await c.confirmPlan(planId: 'plan-1');
      await settle();

      expect(home.builds, 0);
      expect(home.planChanges, 0);
    });
  });

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
        // The post-replay list rebuild answers without a batch here, so the
        // fixture plan never replaces plan-1.
        actions = _FakeActionClient(
          (a) => a is RebuildShoppingListAction
              ? const VanaActionResult(parts: [], extras: {})
              : batchResult(a),
        );
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

  /// Testing-wave 88-003 (ticket 127, mp-244: "the list is rebuilt after
  /// every plan edit"). The stepper and Remove replay through SQL RPCs that
  /// touch plan_meals only, so once the replay lands the controller asks the
  /// server to rebuild each touched plan's list.
  group('list rebuild after a replayed edit', () {
    setUp(() {
      remote.plans = [
        {..._planRow(weekStartFor()), 'status': 'confirmed'},
      ];
    });

    /// Records what the remote had replayed when each rebuild was asked.
    List<List<String>> rebuildsSeen() {
      final seen = <List<String>>[];
      actions = _FakeActionClient((action) {
        if (action is RebuildShoppingListAction) {
          seen.add(List.of(remote.calls));
          return const VanaActionResult(parts: [], extras: {});
        }
        return batchResult(action);
      });
      return seen;
    }

    test(
      'a servings change asks for the plan\'s list after the replay',
      () async {
        await repo.syncFromRemote(_user);
        final seen = rebuildsSeen();
        final c = controller();
        await c.future;

        await c.setServings('pm-1', 5);
        await settle(const Duration(milliseconds: 80));

        final rebuilds = actions.calls.whereType<RebuildShoppingListAction>();
        expect(rebuilds.map((a) => a.planId), ['plan-1']);
        expect(seen.single, contains('plan_set_servings:pm-1:5'));
      },
    );

    test('a remove asks for the plan\'s list after the replay', () async {
      await repo.syncFromRemote(_user);
      final seen = rebuildsSeen();
      final c = controller();
      await c.future;

      await c.removeMeal('pm-2');
      await settle(const Duration(milliseconds: 80));

      final rebuilds = actions.calls.whereType<RebuildShoppingListAction>();
      expect(rebuilds.map((a) => a.planId), ['plan-1']);
      expect(seen.single, contains('plan_remove_meal:pm-2'));
    });

    test('a failed upload asks for no rebuild and says so', () async {
      await repo.syncFromRemote(_user);
      rebuildsSeen();
      remote.failWith = StateError('network down');
      final logger = FakeLogger();
      final c = controller(logger: logger);
      await c.future;

      await c.setServings('pm-1', 5);
      await settle(const Duration(milliseconds: 80));

      expect(actions.calls.whereType<RebuildShoppingListAction>(), isEmpty);
      expect(logger.warnings, contains(contains('shopping list not rebuilt')));
    });

    test(
      'a rebuild missed by a failed upload is asked by the next one',
      () async {
        await repo.syncFromRemote(_user);
        rebuildsSeen();
        remote.failWith = StateError('network down');
        final c = controller();
        await c.future;

        await c.setServings('pm-1', 5);
        await settle(const Duration(milliseconds: 80));
        expect(actions.calls.whereType<RebuildShoppingListAction>(), isEmpty);

        remote.failWith = null;
        await c.removeMeal('pm-2');
        await settle(const Duration(milliseconds: 80));

        final rebuilds = actions.calls.whereType<RebuildShoppingListAction>();
        expect(rebuilds.map((a) => a.planId), ['plan-1']);
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

    /// Testing-wave 15-001 (ticket 71, mp-676): "Use this plan instead" on a
    /// conversation whose draft another confirm archived copies it into this
    /// week as a new draft (`use_plan_again`, mp-675). The copy lands in
    /// Drift; the tab keeps showing the plan it had until the copy is
    /// confirmed.
    test(
      'usePlanAgain copies the plan into a new draft and keeps the tab\'s plan',
      () async {
        // The week already has a confirmed plan: that is what archived the
        // conversation's draft.
        remote.plans = [
          {..._planRow(weekStartFor()), 'status': 'confirmed'},
        ];
        await repo.syncFromRemote(_user);
        final c = controller();
        await c.future;

        final copy = await c.usePlanAgain('archived-draft');

        final sent = actions.calls.whereType<UsePlanAgainAction>().single;
        expect(sent.toJson(), {
          'type': 'use_plan_again',
          'payload': {'id': 'archived-draft'},
        });
        expect(copy, isNotNull);
        expect(await repo.getPlanById(copy!.id), isNotNull);
        expect(copy.meals, hasLength(2));
        expect(c.state.value!.id, 'plan-1');
      },
    );

    test('usePlanAgain offline sends nothing', () async {
      connectivity.online = false;
      final c = controller();
      await c.future;

      await expectLater(
        () => c.usePlanAgain('archived-draft'),
        throwsA(
          isA<NeedsConnectionException>().having(
            (e) => e.operation,
            'op',
            'use_plan_again',
          ),
        ),
      );
      expect(actions.calls, isEmpty);
    });

    /// Testing-wave 19-002 (ticket 96): Rebuild shopping list sends the
    /// plan on the tab and folds the answered plan, its `shopping` mirror
    /// refilled, into Drift.
    test(
      'rebuildShoppingList sends the tab\'s plan and folds the answer',
      () async {
        final c = controller();
        await c.future;

        final plan = await c.rebuildShoppingList();

        final sent = actions.calls.whereType<RebuildShoppingListAction>();
        expect(sent.single.toJson(), {
          'type': 'rebuild_shopping_list',
          'payload': {'planId': 'plan-1'},
        });
        expect(plan, isNotNull);
        final stored = await repo.getPlanById(plan!.id);
        expect(stored, isNotNull);
        expect(
          stored!.shopping.map((i) => i.name),
          plan.shopping.map((i) => i.name),
        );
        expect(plan.shopping, isNotEmpty);
      },
    );

    test('rebuildShoppingList offline sends nothing', () async {
      connectivity.online = false;
      final c = controller();
      await c.future;

      await expectLater(
        () => c.rebuildShoppingList(),
        throwsA(
          isA<NeedsConnectionException>().having(
            (e) => e.operation,
            'op',
            'rebuild_shopping_list',
          ),
        ),
      );
      expect(actions.calls, isEmpty);
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

  /// Ticket 131 (Finding 88-016, mp-235): a confirm owes the "you're set"
  /// card on Food > Shopping. The card reads [youreSetControllerProvider];
  /// the confirm writes it through the real notifier from the producer's
  /// own `confirm_plan` answer (fixture), never from a plan built here.
  group("you're set card (mp-235)", () {
    VanaActionResult confirmAnswer(UiAction action) {
      if (action is GetPlanAction) {
        return const VanaActionResult(parts: [], extras: {});
      }
      if (action is PlanWeekAction) {
        return VanaActionResult.fromJson({
          'parts': [loadFixture('week')],
        });
      }
      return VanaActionResult.fromJson(loadFixture('confirm_plan'));
    }

    YoureSet? card() => container.read(youreSetControllerProvider).value;

    test(
      'a confirm the server acknowledged owes the card for its plan',
      () async {
        actions = _FakeActionClient(confirmAnswer);
        final c = controller();
        await c.future;
        expect(card(), isNull);

        final confirmed = await c.confirmPlan(planId: 'plan-1');

        expect(confirmed!.id, '588c137e-826c-46d4-8a73-f57b1a3d4143');
        expect(card()!.planId, confirmed.id);
        expect(card()!.week, isNull);
      },
    );

    test('a refused confirm owes no card', () async {
      actions = _FakeActionClient(
        (_) => throw const VanaServerException(500, '{}'),
      );
      final c = controller();
      await c.future;

      await expectLater(c.confirmPlan(), throwsA(isA<VanaServerException>()));
      expect(card(), isNull);
    });

    test('offline, a confirm sends nothing and owes no card', () async {
      connectivity.online = false;
      final c = controller();
      await c.future;

      await expectLater(
        c.confirmPlan(),
        throwsA(isA<NeedsConnectionException>()),
      );
      expect(card(), isNull);
    });

    test('dismissed, the card stays gone', () async {
      actions = _FakeActionClient(confirmAnswer);
      final c = controller();
      await c.future;
      await c.confirmPlan(planId: 'plan-1');

      container.read(youreSetControllerProvider.notifier).dismiss();

      expect(card(), isNull);
    });

    test('Lay it across the week sends plan_week and keeps the days', () async {
      actions = _FakeActionClient(confirmAnswer);
      final c = controller();
      await c.future;
      await c.confirmPlan(planId: 'plan-1');

      final week = await container
          .read(youreSetControllerProvider.notifier)
          .layAcrossWeek();

      final sent = actions.calls.whereType<PlanWeekAction>().single;
      expect(sent.toJson(), {
        'type': 'plan_week',
        'payload': <String, Object?>{},
      });
      expect(week!.days, hasLength(2));
      expect(card()!.week!.days.map((d) => d.date), [
        '2026-09-07',
        '2026-09-08',
      ]);
      expect(card()!.planId, '588c137e-826c-46d4-8a73-f57b1a3d4143');
    });

    test('a second tap while one is on the wire joins it', () async {
      final gate = Completer<void>();
      final gatedActions = _GatedActionClient((action) async {
        if (action is PlanWeekAction) await gate.future;
        return confirmAnswer(action);
      });
      container = testContainer([
        ...baseOverrides(connectivity: connectivity, sync: sync),
        appDatabaseProvider.overrideWithValue(db),
        mealPlanRepositoryProvider.overrideWithValue(repo),
        vanaActionClientProvider.overrideWithValue(gatedActions),
        homeControllerProvider.overrideWith(() => home),
      ]);
      container.listen(mealPlanControllerProvider, (_, __) {});
      final c = container.read(mealPlanControllerProvider.notifier);
      await c.future;
      await c.confirmPlan(planId: 'plan-1');

      final notifier = container.read(youreSetControllerProvider.notifier);
      final first = notifier.layAcrossWeek();
      final second = notifier.layAcrossWeek();
      gate.complete();
      await Future.wait([first, second]);

      expect(gatedActions.calls.whereType<PlanWeekAction>(), hasLength(1));
      expect(card()!.week, isNotNull);
    });

    test('offline, Lay it across rethrows and the card stays', () async {
      actions = _FakeActionClient(confirmAnswer);
      final c = controller();
      await c.future;
      await c.confirmPlan(planId: 'plan-1');
      connectivity.online = false;

      await expectLater(
        container.read(youreSetControllerProvider.notifier).layAcrossWeek(),
        throwsA(isA<NeedsConnectionException>()),
      );
      expect(actions.calls.whereType<PlanWeekAction>(), isEmpty);
      expect(card()!.planId, '588c137e-826c-46d4-8a73-f57b1a3d4143');
      expect(card()!.week, isNull);
    });

    test(
      'an answer that lands after the card was dismissed is dropped',
      () async {
        final gate = Completer<void>();
        final gatedActions = _GatedActionClient((action) async {
          if (action is PlanWeekAction) await gate.future;
          return confirmAnswer(action);
        });
        container = testContainer([
          ...baseOverrides(connectivity: connectivity, sync: sync),
          appDatabaseProvider.overrideWithValue(db),
          mealPlanRepositoryProvider.overrideWithValue(repo),
          vanaActionClientProvider.overrideWithValue(gatedActions),
          homeControllerProvider.overrideWith(() => home),
        ]);
        container.listen(mealPlanControllerProvider, (_, __) {});
        final c = container.read(mealPlanControllerProvider.notifier);
        await c.future;
        await c.confirmPlan(planId: 'plan-1');

        final notifier = container.read(youreSetControllerProvider.notifier);
        final laying = notifier.layAcrossWeek();
        notifier.dismiss();
        gate.complete();
        await laying;

        expect(card(), isNull);
      },
    );
  });

  /// Ticket 132 (Finding 88-017, mp-239 detail 4): "Ate it" waits for the
  /// server, which writes the meal log (source plan, the plan meal's id) and
  /// takes one serving off; the answer's `batch` is what lowers the row.
  group('Ate it (logFromPlan)', () {
    late Completer<VanaActionResult> ack;
    late _GatedActionClient gated;

    /// What `vana-action` answers for `log_from_plan` (`_shared/vana/
    /// actions.ts`): the `logged` part, then the whole plan as a `batch`
    /// with the row's servings left one lower.
    Future<VanaActionResult> producerAnswer() async {
      final local = (await repo.getPlanById('plan-1'))!;
      final served = local.copyWith(
        meals: [
          for (final m in local.meals)
            m.id == 'pm-1' ? m.copyWith(servingsLeft: m.servingsLeft - 1) : m,
        ],
      );
      return VanaActionResult.fromJson({
        'parts': [
          {
            'kind': 'logged',
            'planMealId': 'pm-1',
            'name': 'Meal pm-1',
            'servingsLeft': 3,
          },
          {'kind': 'batch', 'plan': served.toJson()},
        ],
        'logId': 'log-1',
      });
    }

    MealPlanController gatedController() {
      container = testContainer([
        ...baseOverrides(connectivity: connectivity, sync: sync),
        appDatabaseProvider.overrideWithValue(db),
        mealPlanRepositoryProvider.overrideWithValue(repo),
        vanaActionClientProvider.overrideWithValue(gated),
        homeControllerProvider.overrideWith(() => home),
      ]);
      container.listen(mealPlanControllerProvider, (_, __) {});
      return container.read(mealPlanControllerProvider.notifier);
    }

    int? leftOf(MealPlan? plan) =>
        plan?.meals.firstWhere((m) => m.id == 'pm-1').servingsLeft;

    setUp(() {
      ack = Completer<VanaActionResult>();
      gated = _GatedActionClient((_) => ack.future);
    });

    test(
      'sends log_from_plan for the row and drops a serving only on the ack',
      () async {
        final c = gatedController();
        await c.future;

        final logging = c.logFromPlan('pm-1');
        await pumpEventQueue();

        final sent = gated.calls.whereType<LogFromPlanAction>().single;
        expect(sent.toJson(), {
          'type': 'log_from_plan',
          'payload': {'planMealId': 'pm-1'},
        });
        // Nothing moves before the server answers: no optimistic decrement.
        expect(leftOf(await repo.getPlanById('plan-1')), 4);
        expect(leftOf(c.state.value), 4);

        ack.complete(await producerAnswer());
        final logged = await logging;

        expect(logged!.planMealId, 'pm-1');
        expect(logged.servingsLeft, 3);
        expect(leftOf(await repo.getPlanById('plan-1')), 3);
        await pumpEventQueue();
        expect(leftOf(c.state.value), 3);
      },
    );

    test('a failed ack rethrows and leaves the row as it was', () async {
      final c = gatedController();
      await c.future;
      final before = c.state.value;

      final logging = c.logFromPlan('pm-1');
      await pumpEventQueue();
      ack.completeError(const VanaServerException(500, 'boom'));

      await expectLater(logging, throwsA(isA<VanaServerException>()));
      expect(leftOf(await repo.getPlanById('plan-1')), 4);
      expect(c.state.hasError, isFalse);
      expect(c.state.value, before);
    });

    test('a timed-out ack pulls the plan before rethrowing, since the write '
        'may have landed; a refused one does not', () async {
      final c = gatedController();
      await c.future;

      final refused = c.logFromPlan('pm-1');
      await pumpEventQueue();
      ack.completeError(const VanaServerException(500, 'boom'));
      await expectLater(refused, throwsA(isA<VanaServerException>()));
      expect(sync.ensured, isNot(contains('force:meal_plans')));

      ack = Completer<VanaActionResult>();
      final timedOut = c.logFromPlan('pm-1');
      await pumpEventQueue();
      ack.completeError(VanaOfflineException(TimeoutException('slow')));
      await expectLater(timedOut, throwsA(isA<VanaOfflineException>()));
      expect(sync.ensured, contains('force:meal_plans'));
    });

    test('offline sends nothing and says it needs a connection', () async {
      connectivity.online = false;
      final c = gatedController();
      await c.future;

      await expectLater(
        () => c.logFromPlan('pm-1'),
        throwsA(
          isA<NeedsConnectionException>().having(
            (e) => e.operation,
            'op',
            'log_from_plan',
          ),
        ),
      );
      expect(gated.calls, isEmpty);
      expect(leftOf(await repo.getPlanById('plan-1')), 4);
    });

    test('a double tap logs once: the second call joins the first', () async {
      final c = gatedController();
      await c.future;

      final first = c.logFromPlan('pm-1');
      final second = c.logFromPlan('pm-1');
      await pumpEventQueue();
      expect(gated.calls.whereType<LogFromPlanAction>(), hasLength(1));

      ack.complete(await producerAnswer());
      expect((await first)!.servingsLeft, 3);
      expect((await second)!.servingsLeft, 3);
    });

    test('after the first answers, another tap sends again', () async {
      final c = gatedController();
      await c.future;

      final first = c.logFromPlan('pm-1');
      ack.complete(await producerAnswer());
      await first;
      ack = Completer<VanaActionResult>()..complete(producerAnswer());
      await c.logFromPlan('pm-1');

      expect(gated.calls.whereType<LogFromPlanAction>(), hasLength(2));
    });
  });
}
