// Ticket 46 (testing-wave; Findings 10-001, 26-001): meal logs and saved
// meals are synced where they are read.
//
// On a fresh sign-in nothing on the way to the timeline or to Log a Meal's
// Recent tab asked for a `meal_logs` / `saved_meals` sync; both were first
// pulled when the Food tab opened (its plan controller depends on them). So
// a returning athlete on a new phone saw an empty day and an empty Recent.
//
// Seam test (docs/test/README.md): the rows are the shape a `meal_logs` /
// `saved_meals` SELECT answers with on dev (ISO timestamps with an offset,
// `items` as the server's `carb_g` shape, `sodium_mg 0`), written through
// the repositories' real remote-apply path into a real in-memory Drift, and
// read through the real providers and the real [SyncCoordinator]. Only the
// Supabase round trip is faked.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:riverpod/riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/meal_logging/application/meal_logging_service.dart';
import 'package:mealvana_endurance/features/meal_logging/data/meal_log_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/data/saved_meals_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/saved_meal.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fakes/fake_supabase_client.dart';
import '../../helpers/fakes/recording_analytics_tracker.dart';

const _user = '607f9dd5-6fa7-48ee-a628-720d4a0506a1';
const _logDate = '2026-09-23';

/// One `meal_logs` row as dev answered it on 2026-09-25 (26-001's source
/// row), logged from another device, so the local table has never seen it.
Map<String, dynamic> _serverMealLog() => {
  'id': '9162543b-1022-4462-8c4b-00ef7cf926c4',
  'user_id': _user,
  'log_date': _logDate,
  'slot': 'snack',
  'name': 'Rice cake and Almond butter',
  'source': 'manual',
  'items': [
    {
      'name': 'Rice cake',
      'fat_g': 0.6,
      'carb_g': 15,
      'portion': '2 cakes',
      'calories': 70,
      'protein_g': 1.4,
    },
    {
      'name': 'Almond butter',
      'fat_g': 9,
      'carb_g': 3,
      'portion': '1 tbsp',
      'calories': 98,
      'protein_g': 3.4,
    },
  ],
  'calories': 168,
  'carbs_g': 18,
  'protein_g': 4.8,
  'fat_g': 9.6,
  'sodium_mg': 0,
  'photo_path': null,
  'recipe_id': null,
  'saved_meal_id': null,
  'notes': null,
  'eaten_at': '2026-09-23T13:46:00+00:00',
  'created_at': '2026-09-23T13:46:59.034208+00:00',
  'updated_at': '2026-09-23T13:46:59.034992+00:00',
  'is_deleted': false,
  'plan_meal_id': null,
};

/// One `saved_meals` row as dev answered it (the account's favourite).
Map<String, dynamic> _serverSavedMeal() => {
  'id': 'fd993bbb-a13a-43e7-a662-ea71ed2ae64a',
  'user_id': _user,
  'name': 'Egg & Veggie Scramble',
  'items': [
    {
      'name': 'Egg & Veggie Scramble',
      'fat_g': 18,
      'carb_g': 8,
      'portion': '1 serving',
      'calories': 280,
      'protein_g': 22,
    },
  ],
  'calories': 280,
  'carbs_g': 8,
  'protein_g': 22,
  'fat_g': 18,
  'sodium_mg': 0,
  'photo_path': null,
  'last_used_at': '2026-06-17T13:42:39.046288+00:00',
  'created_at': '2026-06-17T13:42:39.046288+00:00',
  'updated_at': '2026-09-16T14:48:39.909968+00:00',
  'is_deleted': false,
  'library_meal_id': null,
  'meal_types': const <String>[],
  'batch': null,
  'icon': 'egg',
  'notes': 'Low heat, butter, splash of cream. Two eggs per serving.',
};

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockAppLogger extends Mock implements AppLogger {}

class _MockSentryReporter extends Mock implements SentryReporter {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockUserProfile extends Mock implements UserProfile {}

class _MockPrefs extends Mock implements SharedPreferences {}

void _stubLogger(_MockAppLogger logger) {
  when(
    () => logger.info(
      any(),
      context: any(named: 'context'),
      data: any(named: 'data'),
    ),
  ).thenReturn(null);
  when(
    () => logger.debug(
      any(),
      context: any(named: 'context'),
      data: any(named: 'data'),
    ),
  ).thenReturn(null);
  when(
    () => logger.warning(
      any(),
      context: any(named: 'context'),
      error: any(named: 'error'),
      stackTrace: any(named: 'stackTrace'),
      data: any(named: 'data'),
    ),
  ).thenReturn(null);
  when(
    () => logger.error(
      any(),
      context: any(named: 'context'),
      error: any(named: 'error'),
      stackTrace: any(named: 'stackTrace'),
      data: any(named: 'data'),
    ),
  ).thenReturn(null);
}

/// The real repository with the Supabase round trip replaced by the rows
/// the server would answer; everything after the wire is the real code.
class _MealLogsFromServer extends MealLogRepository {
  _MealLogsFromServer({
    required super.supabase,
    required super.database,
    required super.logger,
    required super.sentry,
    required this.rows,
  });

  final List<Map<String, dynamic>> rows;
  int syncCalls = 0;
  Object? failWith;

  /// When set, the server does not answer until it completes.
  Completer<void>? gate;

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    syncCalls++;
    if (failWith != null) return SyncResult.failed(failWith.toString());
    if (gate != null) await gate!.future;
    final count = await applyRemoteRows(rows);
    await setLastSyncTime(DateTime.now());
    return SyncResult.successful(count);
  }

  /// The upload half of the wire: the server takes every write.
  @override
  Future<void> sendUpsert(
    List<Map<String, dynamic>> rows, {
    bool ignoreDuplicates = false,
  }) async {}
}

class _SavedMealsFromServer extends SavedMealsRepository {
  _SavedMealsFromServer({
    required super.supabase,
    required super.database,
    required super.logger,
    required super.sentry,
    required this.rows,
  });

  final List<Map<String, dynamic>> rows;
  int syncCalls = 0;

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    syncCalls++;
    final count = await applyRemoteRows(rows);
    await setLastSyncTime(DateTime.now());
    return SyncResult.successful(count);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _MealLogsFromServer logs;
  late _SavedMealsFromServer saved;
  late ProviderContainer container;

  setUp(() {
    // A fresh install: nothing has ever been synced on this device.
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final logger = _MockAppLogger();
    _stubLogger(logger);
    final sentry = _MockSentryReporter();
    logs = _MealLogsFromServer(
      supabase: _MockSupabaseClient(),
      database: db,
      logger: logger,
      sentry: sentry,
      rows: [_serverMealLog()],
    );
    saved = _SavedMealsFromServer(
      supabase: _MockSupabaseClient(),
      database: db,
      logger: logger,
      sentry: sentry,
      rows: [_serverSavedMeal()],
    );

    final profile = _MockUserProfile();
    when(() => profile.id).thenReturn(_user);
    final users = _MockUserRepository();
    when(() => users.getCurrentUser()).thenAnswer((_) async => profile);
    // The `users` dependency was synced at sign-in; the coordinator asks.
    when(() => users.isStale()).thenAnswer((_) async => false);

    container = ProviderContainer(
      overrides: [
        mealLogRepositoryProvider.overrideWithValue(logs),
        savedMealsRepositoryProvider.overrideWithValue(saved),
        userRepositoryProvider.overrideWith((_) async => users),
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
  });

  tearDown(() async {
    await Future<void>.delayed(Duration.zero);
    await db.close();
  });

  /// Waits for [provider] (an `AsyncValue<T>` provider; the listenable
  /// interface is not exported by riverpod 3) to emit a value [matches]
  /// accepts, or fails.
  Future<T> firstWhere<T>(
    ProviderContainer c,
    dynamic provider,
    bool Function(T value) matches,
  ) {
    final done = Completer<T>();
    final sub = c.listen<AsyncValue<T>>(provider, (_, next) {
      final v = next.value;
      if (v != null && matches(v) && !done.isCompleted) done.complete(v);
    }, fireImmediately: true);
    addTearDown(sub.close);
    return done.future.timeout(const Duration(seconds: 5));
  }

  group('10-001: the timeline day stream', () {
    test(
      'shows a meal logged on another device without Food being opened',
      () async {
        final logsOnDay = await firstWhere<List<MealLog>>(
          container,
          mealLogsForDateProvider(_logDate),
          (l) => l.isNotEmpty,
        );

        expect(logsOnDay.single.name, 'Rice cake and Almond butter');
        expect(logsOnDay.single.calories, 168);
        expect(
          logsOnDay.single.components.map((c) => c.name),
          ['Rice cake', 'Almond butter'],
          reason: 'the server item shape crosses the wire as components',
        );
        expect(logs.syncCalls, 1);
      },
    );

    test('a read is answered from Drift before the sync lands', () async {
      // The stream is local-first: the first emission is the local table,
      // empty on a fresh install, and the sync fills it in behind — the
      // screen never waits on the network.
      final server = logs.gate = Completer<void>();
      // Held for the test, as a screen would hold it (autoDispose).
      final held = container.listen(
        mealLogsForDateProvider(_logDate),
        (_, __) {},
      );
      addTearDown(held.close);
      final first = await container.read(
        mealLogsForDateProvider(_logDate).future,
      );
      expect(first, isEmpty);
      expect(logs.syncCalls, 1, reason: 'the sync was asked for on build');
      server.complete();
      final later = await firstWhere<List<MealLog>>(
        container,
        mealLogsForDateProvider(_logDate),
        (l) => l.isNotEmpty,
      );
      expect(later, hasLength(1));
    });
  });

  group('26-001: Log a Meal, Recent tab', () {
    // Recent streams from Drift (ticket 54) and is auto-dispose: held as the
    // Recent tab holds it, or a listener-less read disposes it mid-load.
    Future<List<MealLog>> readRecent() {
      final held = container.listen(recentMealsProvider, (_, __) {});
      addTearDown(held.close);
      return container.read(recentMealsProvider.future);
    }

    test('Recent lists an earlier meal on a fresh sign-in', () async {
      final recent = await readRecent();

      expect(recent.map((l) => l.name), ['Rice cake and Almond butter']);
      expect(logs.syncCalls, 1);
    });

    test('saved meals are pulled where they are read', () async {
      final favourites = await firstWhere<List<SavedMeal>>(
        container,
        savedMealsProvider,
        (l) => l.isNotEmpty,
      );

      expect(favourites.single.name, 'Egg & Veggie Scramble');
      expect(saved.syncCalls, 1);
    });

    test('one sync serves every reader of the same table', () async {
      // The timeline and Recent both ask; the coordinator dedupes in flight
      // and the freshness stamp answers the next ask without a round trip.
      container.listen(mealLogsForDateProvider(_logDate), (_, __) {});
      await readRecent();
      await firstWhere<List<MealLog>>(
        container,
        mealLogsForDateProvider(_logDate),
        (l) => l.isNotEmpty,
      );
      container.invalidate(recentMealsProvider);
      await readRecent();

      expect(logs.syncCalls, 1);
    });

    test(
      'a sync that fails still answers Recent from the local table',
      () async {
        logs.failWith = StateError('offline');

        final recent = await readRecent();

        expect(recent, isEmpty);
        expect(logs.syncCalls, 1);
      },
    );
  });

  group('26-005: Recent moves a meal just logged to the top', () {
    List<String> names(List<MealLog> l) => [for (final m in l) m.name];

    test('after logRecipe and a Recent re-log, Recent lists that meal first, '
        'with Log a Meal still open', () async {
      // Log a Meal is open on Recent: the tab watches the provider.
      final before = await firstWhere<List<MealLog>>(
        container,
        recentMealsProvider,
        (l) => l.isNotEmpty,
      );
      expect(names(before), ['Rice cake and Almond butter']);

      // The screens call the auto-dispose controller with a listener-less
      // read, so it is disposed while the write is in flight.
      await container
          .read(mealLogControllerProvider.notifier)
          .logRecipe(
            params: const RecipeLogParams(
              recipeId: 'b8f1c2d3-0000-4000-8000-000000000001',
              recipeName: 'Overnight Oats',
              servings: 1,
              caloriesPerServing: 350,
              carbsGPerServing: 55,
              proteinGPerServing: 12,
              fatGPerServing: 9,
            ),
            logDate: _logDate,
          );

      final afterRecipe = await firstWhere<List<MealLog>>(
        container,
        recentMealsProvider,
        (l) => l.isNotEmpty && l.first.name == 'Overnight Oats',
      );
      expect(names(afterRecipe), [
        'Overnight Oats',
        'Rice cake and Almond butter',
      ]);

      // Drift stores created_at to whole seconds; the re-log is a later tap.
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      // Tapping the Recent row re-logs its components (log_meal_screen
      // `_quickLogComponents` -> `logFromComponents`).
      final riceCake = before.single;
      await container
          .read(mealLogControllerProvider.notifier)
          .logFromComponents(
            name: riceCake.name,
            logDate: _logDate,
            source: MealLogSource.manual,
            components: riceCake.components,
          );

      final afterRelog = await firstWhere<List<MealLog>>(
        container,
        recentMealsProvider,
        (l) => l.isNotEmpty && l.first.name == 'Rice cake and Almond butter',
      );
      expect(names(afterRelog), [
        'Rice cake and Almond butter',
        'Overnight Oats',
      ]);
    });
  });
}
