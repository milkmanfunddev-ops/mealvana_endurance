// Ticket 58 (testing-wave; Finding 26-002): re-logging a Recent meal saves a
// copy of the original.
//
// Before: Log a Meal → Recent → tap collapsed the source's items into one
// synthetic "1 serving" line named after the meal, and persisted
// `source = saved` with no `saved_meal_id`, whatever the source had been.
//
// Seam test (docs/test/README.md): the write runs through the real
// [MealLogController] and the real [MealLoggingService]; only the repository
// and the user lookup are faked. The original is producer-shaped: a Drift row
// as sync writes it (items JSON with integer macros from Postgres, stored
// totals the server computed), decoded by [MealLog.fromDriftEntry] the way
// the Recent tab reads it — never a MealLog the local code built.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/meal_logging/data/meal_log_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/data/saved_meals_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes/fake_supabase_client.dart';
import '../../helpers/fakes/recording_analytics_tracker.dart';

const _user = '607f9dd5-6fa7-48ee-a628-720d4a0506a1';
const _logDate = '2026-09-24';

class _MockUserRepo extends Mock implements UserRepository {}

class _MockMealLogRepo extends Mock implements MealLogRepository {}

class _MockSavedRepo extends Mock implements SavedMealsRepository {}

class _MockPrefs extends Mock implements SharedPreferences {}

class _MockUser extends Mock implements UserProfile {}

/// The dev row 9162543b from Finding 26-002, as the Drift mirror holds it.
MealLogEntry _driftRow({
  String source = 'manual',
  String items =
      '[{"name":"Rice cake","portion":"2 cakes","calories":70,"carb_g":15,'
      '"protein_g":1.4,"fat_g":0.6},'
      '{"name":"Almond butter","portion":"1 tbsp","calories":98,"carb_g":3,'
      '"protein_g":3.4,"fat_g":9}]',
  int? calories = 168,
  double? carbsG = 18.0,
  double? proteinG = 4.8,
  double? fatG = 9.6,
  double? sodiumMg = 0.0,
  String? savedMealId,
  String? planMealId,
  String? photoPath,
}) {
  final created = DateTime.utc(2026, 9, 23, 15, 2);
  return MealLogEntry(
    id: '9162543b-6a51-4c1e-8f0e-2f4f3a2b9d11',
    userId: _user,
    logDate: '2026-09-23',
    slot: 'snack',
    name: 'Rice cake and Almond butter',
    source: source,
    items: items,
    calories: calories,
    carbsG: carbsG,
    proteinG: proteinG,
    fatG: fatG,
    sodiumMg: sodiumMg,
    photoPath: photoPath,
    savedMealId: savedMealId,
    planMealId: planMealId,
    notes: 'after the long run',
    eatenAt: created,
    createdAt: created,
    updatedAt: created,
    isDeleted: false,
    needsUpload: false,
  );
}

MealLog _original(MealLogEntry row) => MealLog.fromDriftEntry(row)!;

void main() {
  late _MockMealLogRepo repo;
  late RecordingAnalyticsTracker analytics;
  late ProviderContainer container;
  late List<MealLog> inserted;

  setUpAll(() {
    registerFallbackValue(_original(_driftRow()));
  });

  setUp(() {
    inserted = [];
    analytics = RecordingAnalyticsTracker();
    repo = _MockMealLogRepo();
    when(() => repo.insertLog(any())).thenAnswer((inv) async {
      await Future<void>.delayed(Duration.zero);
      final log = inv.positionalArguments.single as MealLog;
      inserted.add(log);
      return log;
    });

    final user = _MockUser();
    when(() => user.id).thenReturn(_user);
    final userRepo = _MockUserRepo();
    when(() => userRepo.getCurrentUser()).thenAnswer((_) async => user);

    container = ProviderContainer(
      overrides: [
        appExternalDepsProvider.overrideWithValue(
          AppExternalDeps(
            analytics: analytics,
            supabaseClient: fakeSupabaseClient(),
            sentry: const NoopSentryReporter(),
            logger: const NoopAppLogger(),
            sharedPreferences: _MockPrefs(),
          ),
        ),
        userRepositoryProvider.overrideWith((ref) async => userRepo),
        mealLogRepositoryProvider.overrideWithValue(repo),
        savedMealsRepositoryProvider.overrideWithValue(_MockSavedRepo()),
      ],
    );
    addTearDown(container.dispose);
  });

  MealLogController controller() =>
      container.read(mealLogControllerProvider.notifier);

  Future<MealLog> relog(
    MealLogEntry row, {
    double servings = 1,
    MealSlot? slot = MealSlot.snack,
  }) async {
    await controller().relogMeal(
      original: _original(row),
      servings: servings,
      slot: slot,
      logDate: _logDate,
      eatenAt: DateTime(2026, 9, 24, 15, 8),
    );
    expect(container.read(mealLogControllerProvider).hasError, isFalse);
    expect(inserted, hasLength(1));
    return inserted.single;
  }

  test('a two-item Recent meal re-logs with both items, the same totals and '
      'the original source', () async {
    final row = _driftRow();
    final saved = await relog(row);

    final itemsJson = saved.components.map((c) => c.toJson()).toList();
    expect(itemsJson, jsonDecode(row.items));
    expect(saved.name, 'Rice cake and Almond butter');
    expect(saved.source, MealLogSource.manual);
    expect(saved.savedMealId, isNull);
    expect(saved.calories, 168);
    expect(saved.carbsG, 18.0);
    expect(saved.proteinG, 4.8);
    expect(saved.fatG, 9.6);
    expect(saved.sodiumMg, 0.0);

    // A new row on the new day, not the original.
    expect(saved.id, isNot(row.id));
    expect(saved.logDate, _logDate);
    expect(saved.slot, MealSlot.snack);
    expect(saved.eatenAt, DateTime(2026, 9, 24, 15, 8));
    expect(saved.notes, isNull);

    final logged = analytics.findEvents('meal_logged').single.properties!;
    expect(logged['source'], 'manual');
    expect(logged['method'], 'recent');
  });

  test('a re-log of a saved-meal log keeps its saved meal id; nothing is '
      'invented for other sources', () async {
    final fromSaved = await relog(
      _driftRow(
        source: 'saved',
        savedMealId: 'b7a0c9e2-1111-4222-8333-944455556666',
      ),
    );
    expect(fromSaved.source, MealLogSource.saved);
    expect(fromSaved.savedMealId, 'b7a0c9e2-1111-4222-8333-944455556666');

    inserted.clear();
    final fromPhoto = await relog(
      _driftRow(source: 'photo', photoPath: '$_user/meal.jpg'),
    );
    expect(fromPhoto.source, MealLogSource.photo);
    expect(fromPhoto.savedMealId, isNull);
    expect(fromPhoto.photoPath, '$_user/meal.jpg');
  });

  test(
    'a plan log re-logs as plan but does not claim the plan serving',
    () async {
      final saved = await relog(
        _driftRow(
          source: 'plan',
          planMealId: '0d1e2f30-aaaa-4bbb-8ccc-dddd00001111',
        ),
      );
      expect(saved.source, MealLogSource.plan);
      expect(saved.planMealId, isNull);
    },
  );

  test('two servings double every item and the totals', () async {
    final saved = await relog(_driftRow(), servings: 2);

    expect(saved.components.map((c) => c.portion), ['4 cakes', '2 tbsp']);
    expect(saved.components.map((c) => c.calories), [140, 196]);
    expect(saved.components.first.carbG, 30);
    expect(saved.calories, 336);
    expect(saved.carbsG, 36.0);
    expect(saved.fatG, closeTo(19.2, 1e-9));
    expect(saved.sodiumMg, 0.0);
  });

  test(
    'a portion with no leading number is prefixed with the servings',
    () async {
      final saved = await relog(
        _driftRow(
          items: '[{"name":"Trail mix","portion":"a handful","calories":170}]',
          calories: 170,
          carbsG: null,
          proteinG: null,
          fatG: null,
          sodiumMg: null,
        ),
        servings: 1.5,
      );
      expect(saved.components.single.portion, '1.5 × a handful');
      expect(saved.components.single.carbG, isNull);
    },
  );

  test('a meal logged with totals only re-logs with no items and its totals '
      '(no synthetic line; unknown stays unknown)', () async {
    final saved = await relog(_driftRow(items: '[]', sodiumMg: null));
    expect(saved.components, isEmpty);
    expect(saved.calories, 168);
    expect(saved.carbsG, 18.0);
    expect(saved.sodiumMg, isNull);
  });
}
