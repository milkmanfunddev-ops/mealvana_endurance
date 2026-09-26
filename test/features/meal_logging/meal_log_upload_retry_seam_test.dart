// Ticket 135 (testing-wave; Finding 112-001): a meal whose first upload
// fails is retried.
//
// Before: the repository's immediate upload failed (offline, or an insert
// that timed out online), logged "stays dirty for retry", and nothing
// retried it. `SyncCoordinator.ensureSynced` skipped `meal_logs` while the
// table was fresh (< 1 h since the last pull) and only marked a retry owed
// when its own upload failed, so two offline meals and one online soup never
// reached dev through two relaunches, a pull and a reopened Log a Meal.
//
// Seam test (docs/test/README.md): the write runs through the real
// [MealLogController], the real [MealLoggingService], the real
// [MealLogRepository] into a real in-memory Drift, and the retry through the
// real [SyncCoordinator]. Only the wire ([MealLogRepository.sendUpsert]) and
// the connectivity plugin are faked. `meal_logs` is stamped fresh before
// every test, the state the finding reproduced under.

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/meal_logging/data/meal_log_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/data/saved_meals_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_component.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/connectivity_checker.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_coordinator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fakes/fake_supabase_client.dart';
import '../../helpers/fakes/recording_analytics_tracker.dart';

const _user = '607f9dd5-6fa7-48ee-a628-720d4a0506a1';
const _logDate = '2026-09-25';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockUserProfile extends Mock implements UserProfile {}

class _MockSavedMeals extends Mock implements SavedMealsRepository {}

class _MockPrefs extends Mock implements SharedPreferences {}

/// The real repository; the wire fails while [offline] (errno 51, as the
/// console showed for the two offline meals) and records what lands.
class _FlakyWire extends MealLogRepository {
  _FlakyWire({required super.database, super.onUploadFailed})
    : super(
        supabase: _MockSupabaseClient(),
        logger: const NoopAppLogger(),
        sentry: const NoopSentryReporter(),
      );

  bool offline = false;
  int attempts = 0;
  final landed = <Map<String, dynamic>>[];

  @override
  Future<void> sendUpsert(
    List<Map<String, dynamic>> rows, {
    bool ignoreDuplicates = false,
  }) async {
    attempts++;
    if (offline) {
      throw const SocketException(
        'Network is unreachable',
        osError: OSError('', 51),
      );
    }
    landed.addAll(rows);
  }

  /// The pull half: the server holds nothing this test needs.
  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    if (offline) return SyncResult.failed('offline');
    await setLastSyncTime(DateTime.now());
    return SyncResult.successful(0);
  }
}

class _StubConnectivity extends ConnectivityChecker {
  final changes = StreamController<bool>.broadcast();

  @override
  Future<bool> isOnline() async => true;

  @override
  Stream<bool> get onlineChanges => changes.stream;
}

/// The immediate upload is fire-and-forget; let it run.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _FlakyWire wire;
  late _StubConnectivity network;
  late ProviderContainer container;

  setUp(() async {
    // The table was pulled a moment ago: fresh, so a plain ensureSynced
    // would skip it for the next hour.
    SharedPreferences.setMockInitialValues({
      'meal_logs_last_sync': DateTime.now().toIso8601String(),
    });
    db = AppDatabase.forTesting(NativeDatabase.memory());
    network = _StubConnectivity();

    final profile = _MockUserProfile();
    when(() => profile.id).thenReturn(_user);
    final users = _MockUserRepository();
    when(() => users.getCurrentUser()).thenAnswer((_) async => profile);
    when(() => users.isStale()).thenAnswer((_) async => false);

    container = ProviderContainer(
      overrides: [
        // The same wiring the real provider does: a failed immediate upload
        // tells the coordinator `meal_logs` is owed a retry.
        mealLogRepositoryProvider.overrideWith((ref) {
          final sync = ref.read(syncCoordinatorProvider.notifier);
          return wire = _FlakyWire(
            database: db,
            onUploadFailed: () => sync.markUploadRetryOwed('meal_logs'),
          );
        }),
        savedMealsRepositoryProvider.overrideWithValue(_MockSavedMeals()),
        userRepositoryProvider.overrideWith((_) async => users),
        userIdProvider.overrideWith((_) async => _user),
        connectivityCheckerProvider.overrideWithValue(network),
        appExternalDepsProvider.overrideWithValue(
          AppExternalDeps(
            analytics: RecordingAnalyticsTracker(),
            supabaseClient: fakeSupabaseClient(),
            sentry: const NoopSentryReporter(),
            logger: const NoopAppLogger(),
            sharedPreferences: _MockPrefs(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Hold the auto-dispose repository as the app's readers do, so every
    // path (the controller, the coordinator's resolver) sees this one wire.
    final held = container.listen(mealLogRepositoryProvider, (_, __) {});
    addTearDown(held.close);
  });

  tearDown(() async {
    await _settle();
    await network.changes.close();
    await db.close();
  });

  SyncCoordinator sync() => container.read(syncCoordinatorProvider.notifier);

  /// Common -> "Apple + cheese" -> Log it, as the screen calls it.
  Future<void> logAppleAndCheese() => container
      .read(mealLogControllerProvider.notifier)
      .logFromComponents(
        name: 'Apple + cheese',
        logDate: _logDate,
        source: MealLogSource.manual,
        components: const [
          MealComponent(name: 'Apple', portion: '1 medium', calories: 95),
          MealComponent(
            name: 'Cheddar cheese',
            portion: '1 oz (28 g)',
            calories: 113,
          ),
        ],
        logMethod: 'common',
      );

  Future<MealLogEntry> theRow() async =>
      (await db.select(db.mealLogsTable).get()).single;

  /// What opening Log a Meal or the timeline does for `meal_logs`.
  Future<void> openLogAMeal() =>
      sync().ensureSynced('meal_logs', _user, repository: wire);

  test(
    'an offline log shows at once, stays dirty, and is owed a retry',
    () async {
      wire.offline = true;

      await logAppleAndCheese();
      await _settle();

      final row = await theRow();
      expect(row.name, 'Apple + cheese');
      expect(row.needsUpload, isTrue);
      expect(wire.landed, isEmpty);
      expect(wire.attempts, 1, reason: 'the immediate upload was tried once');
      expect(sync().uploadRetryOwedForTesting, contains('meal_logs'));
    },
  );

  test(
    'the next ensureSynced uploads it although meal_logs is fresh',
    () async {
      wire.offline = true;
      await logAppleAndCheese();
      await _settle();
      expect(await wire.isStale(), isFalse, reason: 'the table is fresh');

      // The network is back; the athlete opens Log a Meal.
      wire.offline = false;
      await openLogAMeal();

      expect(wire.landed.map((r) => r['name']), contains('Apple + cheese'));
      expect((await theRow()).needsUpload, isFalse);
      expect(sync().uploadRetryOwedForTesting, isNot(contains('meal_logs')));

      // Nothing left to retry: the next open is the plain fresh no-op.
      final before = wire.attempts;
      await openLogAMeal();
      expect(wire.attempts, before);
    },
  );

  test('an ensureSynced that still fails offline keeps the retry owed '
      '(UploadResult.failed), and the online event then uploads it', () async {
    wire.offline = true;
    await logAppleAndCheese();
    await _settle();

    // Still offline: Log a Meal opened, pull-to-refresh, both fail.
    await openLogAMeal();
    expect(wire.landed, isEmpty);
    expect(sync().uploadRetryOwedForTesting, contains('meal_logs'));

    // The network comes back.
    wire.offline = false;
    network.changes.add(true);
    await _settle();

    expect(wire.landed.map((r) => r['name']), contains('Apple + cheese'));
    expect((await theRow()).needsUpload, isFalse);
    expect(sync().uploadRetryOwedForTesting, isEmpty);
  });

  test(
    'an offline-to-online change alone uploads it, with no screen open',
    () async {
      wire.offline = true;
      await logAppleAndCheese();
      await _settle();

      wire.offline = false;
      network.changes.add(false);
      network.changes.add(true);
      await _settle();

      expect(wire.landed.map((r) => r['name']), contains('Apple + cheese'));
      expect((await theRow()).needsUpload, isFalse);
    },
  );

  test('opening Recent (recentMeals) uploads the owed log', () async {
    wire.offline = true;
    await logAppleAndCheese();
    await _settle();
    wire.offline = false;

    final held = container.listen(recentMealsProvider, (_, __) {});
    addTearDown(held.close);
    final recent = await container.read(recentMealsProvider.future);

    expect(recent.map((l) => l.name), ['Apple + cheese']);
    expect(wire.landed.map((r) => r['name']), contains('Apple + cheese'));
    expect((await theRow()).needsUpload, isFalse);
  });

  test('a retry that lands while another is in flight sends the rows once '
      'per attempt and never doubles the row', () async {
    wire.offline = true;
    await logAppleAndCheese();
    await _settle();
    wire.offline = false;

    await Future.wait([
      sync().retryOwedUploads(),
      sync().retryOwedUploads(),
      openLogAMeal(),
    ]);

    expect((await db.select(db.mealLogsTable).get()), hasLength(1));
    expect((await theRow()).needsUpload, isFalse);
    // One upload (two upserts: insert-if-missing, then the overwrite).
    expect(
      wire.landed.where((r) => r['name'] == 'Apple + cheese'),
      hasLength(2),
    );
  });
}
