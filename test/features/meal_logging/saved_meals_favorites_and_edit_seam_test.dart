// Ticket 136 (testing-wave; Findings 112-005, 112-007, 112-008, 113-002,
// 113-003, 113-009): saved meals, favourites and Edit Meal write paths.
//
// Every write runs through the real notifiers ([MealLogController],
// [DraftMealController]), the real [MealLoggingService] and the real
// repositories on an in-memory Drift. Only the PostgREST upsert (the
// process boundary) is replaced, and the rows are read back from Drift, so
// the tests see what the app stores, not what the controller meant to store.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/src/internals.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/meal_logging/data/meal_log_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/data/saved_meals_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_component.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/saved_meal.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/draft_meal_controller.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/edit_meal_log_screen.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';

import '../../helpers/fakes/fake_supabase_client.dart';
import '../../helpers/fakes/recording_analytics_tracker.dart';

const _user = 'user-136';
const _logDate = '2026-09-26';

class _MockUserRepository extends Mock implements UserRepository {}

class _MockUserProfile extends Mock implements UserProfile {}

/// The real repository with the wire cut: the server takes every write.
class _MealLogsNoWire extends MealLogRepository {
  _MealLogsNoWire({required super.database})
    : super(
        supabase: fakeSupabaseClient(),
        logger: const NoopAppLogger(),
        sentry: const NoopSentryReporter(),
      );

  final List<Map<String, dynamic>> sent = [];

  @override
  Future<void> sendUpsert(
    List<Map<String, dynamic>> rows, {
    bool ignoreDuplicates = false,
  }) async {
    sent.addAll(rows);
  }
}

class _SavedMealsNoWire extends SavedMealsRepository {
  _SavedMealsNoWire({required super.database})
    : super(
        supabase: fakeSupabaseClient(),
        logger: const NoopAppLogger(),
        sentry: const NoopSentryReporter(),
      );

  final List<Map<String, dynamic>> sent = [];

  @override
  Future<void> sendUpsert(Map<String, dynamic> row) async {
    sent.add(row);
  }
}

/// Producer-shaped items: the Common "Oatmeal + raisins" assembly as stored,
/// with no fat on the raisins and no sodium anywhere (null ≠ 0).
List<MealComponent> _oatmealAndRaisins() => [
  MealComponent.fromJson(const {
    'name': 'Oatmeal',
    'portion': '1 cup',
    'calories': 150,
    'carb_g': 27,
    'protein_g': 5,
    'fat_g': 3,
  }),
  MealComponent.fromJson(const {
    'name': 'Raisins',
    'portion': '1 small box',
    'calories': 130,
    'carb_g': 34,
    'protein_g': 1,
  }),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _MealLogsNoWire logs;
  late _SavedMealsNoWire saved;
  late RecordingAnalyticsTracker analytics;
  late List<Override> overrides;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    logs = _MealLogsNoWire(database: db);
    saved = _SavedMealsNoWire(database: db);
    analytics = RecordingAnalyticsTracker();

    final profile = _MockUserProfile();
    when(() => profile.id).thenReturn(_user);
    final users = _MockUserRepository();
    when(() => users.getCurrentUser()).thenAnswer((_) async => profile);

    overrides = [
      mealLogRepositoryProvider.overrideWithValue(logs),
      savedMealsRepositoryProvider.overrideWithValue(saved),
      userRepositoryProvider.overrideWith((_) async => users),
      appConfigProvider.overrideWithValue(AppConfig.forTesting()),
      appExternalDepsProvider.overrideWithValue(
        AppExternalDeps(
          analytics: analytics,
          supabaseClient: fakeSupabaseClient(),
          sentry: const NoopSentryReporter(),
          logger: const NoopAppLogger(),
          sharedPreferences: _MockPrefs(),
        ),
      ),
    ];
  });

  tearDown(() async {
    // Let the unawaited immediate uploads settle before the table closes.
    await Future<void>.delayed(Duration.zero);
    await db.close();
  });

  Future<List<SavedMealEntry>> savedRows() =>
      db.select(db.savedMealsTable).get();
  Future<List<MealLogEntry>> logRows() => db.select(db.mealLogsTable).get();

  group('112-005: trash then Undo on a saved meal', () {
    test(
      'delete tombstones the row and Undo brings it back, both synced',
      () async {
        final container = ProviderContainer(overrides: overrides);
        addTearDown(container.dispose);
        final sub = container.listen(mealLogControllerProvider, (_, _) {});
        addTearDown(sub.close);

        final now = DateTime(2026, 9, 26, 8);
        final meal = await saved.saveMeal(
          SavedMeal(
            id: '',
            userId: _user,
            name: 'Egg & Veggie Scramble',
            components: _oatmealAndRaisins(),
            calories: 280,
            createdAt: now,
            updatedAt: now,
          ),
        );
        final notifier = container.read(mealLogControllerProvider.notifier);

        await notifier.deleteSavedMeal(meal.id);
        expect(container.read(mealLogControllerProvider), isA<AsyncData>());
        var row = (await savedRows()).single;
        expect(row.isDeleted, isTrue);

        await notifier.restoreSavedMeal(meal.id);
        expect(container.read(mealLogControllerProvider), isA<AsyncData>());
        row = (await savedRows()).single;
        expect(row.isDeleted, isFalse, reason: 'Undo restores the row');
        // Re-dirtied, then the immediate upload (taken at once by the cut
        // wire) cleared it again; the wire log below shows the restore.
        expect(row.needsUpload, isFalse);
        expect(row.calories, 280, reason: 'the row comes back whole');

        await Future<void>.delayed(Duration.zero);
        expect(
          saved.sent.map((r) => r['is_deleted']),
          [false, true, false],
          reason: 'save, tombstone, restore each reached the wire',
        );
        expect(
          analytics.events.map((e) => e.name),
          containsAllInOrder(['saved_meal_deleted', 'saved_meal_restored']),
        );
      },
    );

    test('a second Undo is a no-op', () async {
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);
      final sub = container.listen(mealLogControllerProvider, (_, _) {});
      addTearDown(sub.close);
      final now = DateTime(2026, 9, 26, 8);
      final meal = await saved.saveMeal(
        SavedMeal(
          id: '',
          userId: _user,
          name: 'Toast',
          components: const [],
          createdAt: now,
          updatedAt: now,
        ),
      );
      final notifier = container.read(mealLogControllerProvider.notifier);
      await notifier.deleteSavedMeal(meal.id);
      await notifier.restoreSavedMeal(meal.id);
      final after = (await savedRows()).single.updatedAt;
      await notifier.restoreSavedMeal(meal.id);
      expect(container.read(mealLogControllerProvider), isA<AsyncData>());
      expect((await savedRows()).single.updatedAt, after);
    });
  });

  group('112-007 / 113-009: a Build a Meal favourite', () {
    test(
      'carries the draft totals (a macro no item has stays null) and the new log id',
      () async {
        final container = ProviderContainer(overrides: overrides);
        addTearDown(container.dispose);
        final sub = container.listen(mealLogControllerProvider, (_, _) {});
        addTearDown(sub.close);
        final draftSub = container.listen(
          draftMealControllerProvider(_logDate),
          (_, _) {},
        );
        addTearDown(draftSub.close);

        final draft = container.read(
          draftMealControllerProvider(_logDate).notifier,
        );
        draft.addComponents(_oatmealAndRaisins());

        final ok = await draft.save(alsoSaveAsFavorite: true);
        expect(ok, isTrue);

        final log = (await logRows()).single;
        final favorite = (await savedRows()).single;

        expect(favorite.calories, 280);
        expect(favorite.carbsG, 61);
        expect(favorite.proteinG, 6);
        expect(favorite.fatG, 3, reason: 'one item carries fat: summed');
        expect(favorite.sodiumMg, isNull, reason: 'no item carries sodium');
        expect(favorite.name, log.name);

        expect(
          log.savedMealId,
          favorite.id,
          reason: 'the log row points at the favourite it made',
        );
        expect(log.calories, 280, reason: 'the provenance write keeps totals');

        final event = analytics.events.singleWhere(
          (e) => e.name == 'meal_saved_as_favorite',
        );
        expect(event.properties!['log_id'], log.id);
        expect(log.id, isNotEmpty);

        expect(
          container.read(draftMealControllerProvider(_logDate)).isEmpty,
          isTrue,
          reason: 'the draft clears after the save',
        );
      },
    );

    test(
      'without the checkbox no favourite is made and no pointer set',
      () async {
        final container = ProviderContainer(overrides: overrides);
        addTearDown(container.dispose);
        final sub = container.listen(mealLogControllerProvider, (_, _) {});
        addTearDown(sub.close);
        final draftSub = container.listen(
          draftMealControllerProvider(_logDate),
          (_, _) {},
        );
        addTearDown(draftSub.close);
        container
            .read(draftMealControllerProvider(_logDate).notifier)
            .addComponents(_oatmealAndRaisins());
        await container
            .read(draftMealControllerProvider(_logDate).notifier)
            .save();
        expect(await savedRows(), isEmpty);
        expect((await logRows()).single.savedMealId, isNull);
      },
    );
  });

  group('112-008: Save as favorite from a logged meal', () {
    test('writes the row\'s stored totals', () async {
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);
      final sub = container.listen(mealLogControllerProvider, (_, _) {});
      addTearDown(sub.close);

      // A quick manual log: totals only, no items.
      final now = DateTime(2026, 9, 26, 12, 30);
      final log = await logs.insertLog(
        MealLog(
          id: 'log-manual',
          userId: _user,
          logDate: _logDate,
          name: 'Lunch soup',
          source: MealLogSource.manual,
          components: const [],
          calories: 320,
          carbsG: 40.5,
          proteinG: 12.25,
          sodiumMg: 800,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final favorite = await container
          .read(mealLogControllerProvider.notifier)
          .saveLogAsFavorite(log);

      expect(favorite, isNotNull);
      final row = (await savedRows()).single;
      expect(row.id, favorite!.id);
      expect(row.name, 'Lunch soup');
      expect(row.calories, 320);
      expect(row.carbsG, 40.5);
      expect(row.proteinG, 12.25);
      expect(row.fatG, isNull);
      expect(row.sodiumMg, 800);
      final event = analytics.events.singleWhere(
        (e) => e.name == 'meal_saved_as_favorite',
      );
      expect(event.properties!['log_id'], 'log-manual');
    });
  });

  group('113-002 / 113-003: Edit Meal on a totals-only log', () {
    MealLog manualLog() {
      final now = DateTime(2026, 9, 26, 7, 15);
      return MealLog(
        id: 'log-edit',
        userId: _user,
        logDate: _logDate,
        name: 'Porridge',
        source: MealLogSource.manual,
        components: const [],
        calories: 200,
        carbsG: 30.2,
        proteinG: 12.25,
        fatG: 8.4,
        eatenAt: now,
        createdAt: now,
        updatedAt: now,
      );
    }

    Future<void> pumpEdit(WidgetTester tester, MealLog log) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => context.push('/edit', extra: {'log': log}),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          GoRoute(path: '/edit', builder: (_, _) => const EditMealLogScreen()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Edit Meal'), findsOneWidget);
    }

    Future<void> save(WidgetTester tester) async {
      final button = find.text('Save changes');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('"250.5" stores 251 and untouched macros keep their value', (
      tester,
    ) async {
      await logs.insertLog(manualLog());
      await pumpEdit(tester, manualLog());

      // The prefill shows one decimal: 12.25 reads "12.3". Left alone.
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('edit_meal.protein_field')),
            )
            .controller!
            .text,
        '12.3',
      );

      await tester.enterText(
        find.byKey(const ValueKey('edit_meal.calories_field')),
        '250.5',
      );
      await save(tester);

      final row = (await logRows()).single;
      expect(row.calories, 251);
      expect(
        row.proteinG,
        12.25,
        reason: 'an untouched field is not rewritten',
      );
      expect(row.carbsG, 30.2);
      expect(row.fatG, 8.4);
      expect(row.sodiumMg, isNull);
      expect(find.text('Edit Meal'), findsNothing, reason: 'saved and popped');
    });

    testWidgets('an emptied field stores unknown, not the old value', (
      tester,
    ) async {
      await logs.insertLog(manualLog());
      await pumpEdit(tester, manualLog());

      await tester.enterText(
        find.byKey(const ValueKey('edit_meal.calories_field')),
        '',
      );
      await tester.enterText(
        find.byKey(const ValueKey('edit_meal.fat_field')),
        '',
      );
      await save(tester);

      final row = (await logRows()).single;
      expect(row.calories, isNull);
      expect(row.fatG, isNull);
      expect(row.proteinG, 12.25);
      expect(row.carbsG, 30.2);
    });
  });
}

class _MockPrefs extends Mock implements SharedPreferences {}
