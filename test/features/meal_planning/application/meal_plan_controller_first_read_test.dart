/// Ticket 46 (testing-wave; Finding 19-004): the Plan tab's first read.
///
/// On a fresh install the plan controller answered `null` the moment Drift
/// did, while the `meal_plans` sync it had kicked was still on the wire, so
/// the Plan tab said "No plan yet" for about 6 s over a plan the athlete had
/// confirmed. The contract now: with nothing local and the network up, the
/// first read waits for the sync's answer (the tab shows loading); with a
/// local plan, or offline, the local table answers at once and the sync
/// runs behind.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_plan_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_plan_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_action_client.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/week_start.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/container.dart';
import '../helpers/fakes.dart';

class _NoActions extends Fake implements VanaActionClient {
  @override
  Future<VanaActionResult> run(UiAction action) async =>
      const VanaActionResult(parts: [], extras: {});
}

/// A coordinator whose `meal_plans` sync is the repository's real one,
/// answered when [gate] completes (at once when there is no gate).
class _ServerBackedSync extends NoopSyncCoordinator {
  Completer<void>? gate;

  @override
  Future<void> ensureSynced(
    String repoKey,
    String userId, {
    SyncableRepository? repository,
  }) async {
    ensured.add(repoKey);
    if (repoKey != 'meal_plans' || repository == null) return;
    if (gate != null) await gate!.future;
    await repository.syncFromRemote(userId);
  }
}

const _user = 'user-1';
final _now = DateTime.utc(2026, 9, 1, 12);

Map<String, dynamic> _planRow(String weekStart) => {
  'id': 'plan-1',
  'user_id': _user,
  'week_start': weekStart,
  'status': 'confirmed',
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
  late StubConnectivity connectivity;
  late _ServerBackedSync sync;

  setUp(() {
    // A fresh install: nothing local, nothing ever synced on this device.
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
    connectivity = StubConnectivity();
    sync = _ServerBackedSync();
  });

  tearDown(() => db.close());

  MealPlanController controller() {
    final container = testContainer([
      ...baseOverrides(connectivity: connectivity, sync: sync),
      appDatabaseProvider.overrideWithValue(db),
      mealPlanRepositoryProvider.overrideWithValue(repo),
      vanaActionClientProvider.overrideWithValue(_NoActions()),
    ]);
    container.listen(mealPlanControllerProvider, (_, __) {});
    return container.read(mealPlanControllerProvider.notifier);
  }

  test('with nothing local, the first read is loading until the server '
      'answers, then it is the confirmed plan', () async {
    final server = sync.gate = Completer<void>();
    final c = controller();
    await settle();

    expect(c.state.isLoading, isTrue);
    expect(c.state.value, isNull, reason: 'never an empty answer mid-read');

    server.complete();
    final plan = await c.future;
    expect(plan!.id, 'plan-1');
    expect(plan.meals.length, 2);
    expect(sync.ensured, contains('meal_plans'));
  });

  test('with nothing on the server either, the first read answers empty '
      'once the sync has', () async {
    remote.plans = [];
    remote.meals = [];
    final c = controller();

    final plan = await c.future;
    expect(plan, isNull);
    expect(sync.ensured, contains('meal_plans'));
    expect(remote.calls, isNotEmpty, reason: 'the server was asked first');
  });

  test('offline, the local table answers at once', () async {
    connectivity.online = false;
    sync.gate = Completer<void>(); // never answered: the wire is down
    final c = controller();

    final plan = await c.future.timeout(const Duration(seconds: 2));
    expect(plan, isNull);
  });

  test('a plan already local answers at once; the sync runs behind', () async {
    await repo.syncFromRemote(_user);
    remote.calls.clear();
    sync.gate = Completer<void>(); // the wire is slow; nobody waits for it
    final c = controller();

    final plan = await c.future.timeout(const Duration(seconds: 2));
    expect(plan!.id, 'plan-1');
    expect(sync.ensured, contains('meal_plans'));
  });
}
