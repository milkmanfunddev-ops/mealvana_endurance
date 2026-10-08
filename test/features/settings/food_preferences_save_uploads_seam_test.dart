// develop-2026-10 ticket 58 (Finding 49-010): a Settings food-preferences
// save reaches `food_preferences`, keyed by `template_foods.name`, with a UTC
// `updated_at`, and the screen's load reads the server's rows.
//
// Seam test (docs/test/README.md): the real [FoodPreferencesController]
// through a ProviderContainer, the real [FoodPreferencesRepository] on
// in-memory Drift, the real [SyncCoordinator], and the real postgrest builder
// against [FakePostgrest]. The server rows are seeded the way the producer
// wrote them (snake_case keys, Postgres `+00` timestamps, one display-name row
// the old Settings wrote), never from this app's own save.
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/food_preferences/data/food_preferences_repository.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/food_preferences_controller.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/connectivity_checker.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_coordinator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes/fake_postgrest.dart';
import '../../helpers/fakes/recording_analytics_tracker.dart';
import '../../helpers/fakes/recording_report.dart';

const _user = '607f9dd5-1c2b-4e3d-8f4a-5b6c7d8e9f01';
const _serverStamp = '2026-10-08 14:02:11.123+00';

class _MockPrefs extends Mock implements SharedPreferences {}

class _StubConnectivity extends ConnectivityChecker {
  @override
  Future<bool> isOnline() async => true;

  @override
  Stream<bool> get onlineChanges => const Stream.empty();
}

/// Run 49's nine rows as the server holds them, plus the display-name row
/// the old Settings wrote for Energy Chews.
List<Map<String, dynamic>> _producerRows() {
  Map<String, dynamic> row(String food, int level) => {
    'id': 'fp-${food.hashCode.abs()}-0000-0000-0000-000000000000'.substring(
      0,
      36,
    ),
    'user_id': _user,
    'food_name': food,
    'preference': level <= 1
        ? 'dislike'
        : level >= 3
        ? 'like'
        : 'willing_to_try',
    'preference_level': level,
    'preference_source': 'manual',
    'created_at': _serverStamp,
    'updated_at': _serverStamp,
  };
  return [
    row('sports_drink', 4),
    for (final food in [
      'banana',
      'gel',
      'stroopwafel',
      'pretzels',
      'dates',
      'rice_cakes',
      'applesauce_pouch',
      'honey_stinger_waffle',
    ])
      row(food, 2),
    row('Energy Chews', 1),
  ];
}

FoodItem _catalog(String id, String name, String display) =>
    FoodItem(id: id, name: display, displayName: display, catalogName: name);

final _sportsDrink = _catalog('tf-1', 'sports_drink', 'Sports Drink');
final _energyChews = _catalog('tf-2', 'energy_chews', 'Energy Chews');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakePostgrest server;
  late RecordingReport report;
  late ProviderContainer container;

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        reportProvider.overrideWithValue(report),
        connectivityCheckerProvider.overrideWithValue(_StubConnectivity()),
        userRepositoryProvider.overrideWith(
          (ref) async => UserRepository(
            database: db,
            supabase: server.client,
            report: report,
          ),
        ),
        appExternalDepsProvider.overrideWithValue(
          AppExternalDeps(
            analytics: RecordingAnalyticsTracker(),
            supabaseClient: server.client,
            report: report,
            sharedPreferences: _MockPrefs(),
          ),
        ),
      ],
    );
    // Keep the autoDispose controller alive, as the screen does.
    c.listen(foodPreferencesControllerProvider, (_, _) {});
    return c;
  }

  setUp(() async {
    // `users` was pulled a moment ago, so the dependency walk skips it.
    SharedPreferences.setMockInitialValues({
      'users_last_sync': DateTime.now().toIso8601String(),
    });
    db = AppDatabase.memory();
    server = FakePostgrest();
    await server.signIn(_user);
    report = RecordingReport();
    server.tables['food_preferences'] = _producerRows();
    container = makeContainer();
    addTearDown(container.dispose);
  });

  tearDown(() async {
    await FoodPreferencesRepository.inFlightUploadFor(_user);
    await db.close();
  });

  FoodPreferencesController controller() =>
      container.read(foodPreferencesControllerProvider.notifier);

  Future<void> load() => controller().load(
    primary: [_sportsDrink, _energyChews],
    additional: const [],
    userFoods: const [],
  );

  List<Map<String, dynamic>> upserts() => server.writes
      .where((w) => w.table == 'food_preferences')
      .expand((w) => (w.body as List).cast<Map>())
      .map((m) => m.cast<String, dynamic>())
      .toList();

  Future<bool> pending() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(foodPreferencesUploadPendingKey(_user)) ?? false;
  }

  test('load reads the server levels by catalog key; save uploads the key '
      'with a UTC updated_at', () async {
    await load();
    final loaded = container.read(foodPreferencesControllerProvider);
    expect(loaded.value?['sports_drink'], 4, reason: 'server level, not 2');
    expect(
      loaded.value?['energy_chews'],
      1,
      reason: 'the old display-name row folds onto the key',
    );
    expect(upserts(), isEmpty, reason: 'nothing pending, nothing pushed');

    // Drift keeps whole seconds.
    final before = DateTime.now().subtract(const Duration(seconds: 1));
    await controller().save({'sports_drink': 4, 'energy_chews': 3});
    await pumpEventQueue();
    await FoodPreferencesRepository.inFlightUploadFor(_user);

    expect(container.read(foodPreferencesControllerProvider).hasError, isFalse);
    final rows = upserts();
    final chews = rows.lastWhere((r) => r['food_name'] == 'energy_chews');
    expect(chews['preference_level'], 3);
    final updatedAt = chews['updated_at'] as String;
    expect(updatedAt, endsWith('Z'));
    final at = DateTime.parse(updatedAt);
    expect(at.isBefore(before), isFalse, reason: 'stamped at the save');
    expect(at.isAfter(DateTime.now()), isFalse);
    expect(
      rows.where((r) => r['food_name'] == 'Energy Chews'),
      isEmpty,
      reason: 'no display-name row goes up',
    );
    expect(await pending(), isFalse);

    // onConflict is on the full (user_id, food_name) index.
    final i = server.writes.lastIndexWhere(
      (w) => w.table == 'food_preferences',
    );
    expect(
      server.writeUris[i].queryParameters['on_conflict'],
      'user_id,food_name',
    );

    final local = await db.foodPreferencesDao.getUserFoodPreferenceLevels(
      _user,
    );
    expect(local['energy_chews'], 3);
    expect(local.containsKey('Energy Chews'), isFalse);
    expect(local['banana'], 2, reason: 'merge: other rows stay');
  });

  test('a refused upload keeps the save, the flag and the local level; '
      'the plan reconcile leaves it; the next dirty walk sends it', () async {
    await load();
    server.rejectWrites.add('food_preferences');

    await controller().save({'sports_drink': 0, 'energy_chews': 2});
    await FoodPreferencesRepository.inFlightUploadFor(_user);

    expect(
      container.read(foodPreferencesControllerProvider).hasError,
      isFalse,
      reason: 'a failed upload is not a failed save (#118)',
    );
    expect(await pending(), isTrue);
    expect(report.degradeds, hasLength(1));

    final userRepo = UserRepository(
      database: db,
      supabase: server.client,
      report: report,
    );
    await userRepo.fetchAndCacheRemoteFoodPreferences(_user);
    final afterReconcile = await db.foodPreferencesDao
        .getUserFoodPreferenceLevels(_user);
    expect(afterReconcile['sports_drink'], 0, reason: 'not replaced by 4');
    expect(
      report.notes.map((n) => n.message),
      contains('Food preference reconcile skipped: local upload pending'),
    );

    server.rejectWrites.clear();
    final repo = await container.read(foodPreferencesRepositoryProvider.future);
    final result = await repo.uploadDirtyRecords(_user);
    expect(result.success, isTrue);
    expect(result.count, greaterThan(0));
    expect(
      upserts().lastWhere(
        (r) => r['food_name'] == 'sports_drink',
      )['preference_level'],
      0,
    );
    expect(await pending(), isFalse);
  });

  test('with nothing pending, uploadDirtyRecords sends nothing and says so; '
      'ensureSynced on a stale phone leaves the server rows alone', () async {
    // An older local copy: sports_drink at 1.
    await db
        .into(db.foodPreferencesTable)
        .insert(
          FoodPreferencesTableCompanion.insert(
            id: '11111111-2222-4333-8444-555555555555',
            userId: _user,
            foodName: 'sports_drink',
            preference: 'dislike',
            preferenceLevel: const Value(1),
            createdAt: Value(DateTime.utc(2026, 9, 1)),
            updatedAt: Value(DateTime.utc(2026, 9, 1)),
          ),
        );
    final repo = await container.read(foodPreferencesRepositoryProvider.future);

    final result = await repo.uploadDirtyRecords(_user);
    expect(result.success, isTrue);
    expect(result.count, 0);
    expect(upserts(), isEmpty);
    expect(
      report.calls.map((c) => c.message),
      contains('Food preferences upload skipped: nothing pending'),
    );

    await container
        .read(syncCoordinatorProvider.notifier)
        .ensureSynced('food_preferences', _user, repository: repo);

    expect(upserts(), isEmpty, reason: 'the stale phone pushed nothing');
    final local = await db.foodPreferencesDao.getUserFoodPreferenceLevels(
      _user,
    );
    expect(local['sports_drink'], 4, reason: 'the pull brought the server');
  });

  test(
    'save with no signed-in user is an error state, and saves nothing',
    () async {
      await server.client.auth.signOut();
      await controller().save({'sports_drink': 3});

      final state = container.read(foodPreferencesControllerProvider);
      expect(state.hasError, isTrue);
      expect(upserts(), isEmpty);
      expect(
        await db.foodPreferencesDao.getUserFoodPreferences(_user),
        isEmpty,
      );
      expect(
        report.notes.map((n) => n.message),
        contains('Food preferences save: no signed-in user; nothing saved'),
      );
    },
  );

  test('a load that finishes after a refresh does not write state', () async {
    final first = load();
    container.invalidate(foodPreferencesControllerProvider);
    await first;
    // The rebuilt controller holds build()'s empty map, not the stale load.
    expect(container.read(foodPreferencesControllerProvider).value, isEmpty);
  });
}
