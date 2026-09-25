/// The detail's heart through the real MealDetailController and the real
/// SavedMealsRepository over Drift (testing-wave 89-009): a save lands in My
/// Foods, a reopened detail reads it as saved, and a second tap soft-deletes
/// it. The server's side is producer-shaped: `save_meal` answers with the
/// saved meal, and the pull after it returns the `saved_meals` row the edge
/// function inserted (`saveLibraryMeal` in `_shared/vana/meals.ts`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_logging/data/saved_meals_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_detail_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_library_remote_data_source.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_action_client.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_detail.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_type.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/container.dart';

const _user = 'user-1';
const _libraryId = 'AD-015';
const _savedId = '09f59fb0-0000-4000-8000-000000000001';

class _MockSupabase extends Mock implements SupabaseClient {}

/// The real repository; only the network pull is replaced by the rows the
/// server would answer with.
class _ServerBackedSavedMeals extends SavedMealsRepository {
  _ServerBackedSavedMeals(AppDatabase db)
    : super(
        supabase: _MockSupabase(),
        database: db,
        logger: const NoopAppLogger(),
        sentry: const NoopSentryReporter(),
      );

  final List<Map<String, dynamic>> serverRows = [];

  @override
  Future<SyncResult> syncFromRemote(String userId) async =>
      SyncResult.successful(await applyRemoteRows(serverRows));
}

/// `save_meal`: inserts the saved_meals row server-side and answers with it.
class _SaveMealServer extends Fake implements VanaActionClient {
  _SaveMealServer(this.repo);
  final _ServerBackedSavedMeals repo;
  final List<UiAction> calls = [];

  @override
  Future<VanaActionResult> run(UiAction action) async {
    calls.add(action);
    if (action is! SaveMealAction) throw UnsupportedError(action.type);
    final now = DateTime.utc(2026, 9, 25, 20).toIso8601String();
    repo.serverRows.add({
      'id': _savedId,
      'user_id': _user,
      'name': 'Quinoa, mixed veg & walnuts',
      'items': [
        {'name': 'quinoa, cooked', 'portion': '220 g', 'role': null},
        {'name': 'walnuts', 'portion': '20 g', 'role': null},
      ],
      'calories': 560,
      'carbs_g': 62,
      'protein_g': 17,
      'fat_g': 26,
      'library_meal_id': action.libraryMealId,
      'meal_types': ['dinner'],
      'batch': true,
      'icon': null,
      'last_used_at': now,
      'created_at': now,
      'updated_at': now,
      'is_deleted': false,
    });
    return VanaActionResult(
      parts: const [],
      extras: {
        'meal': const MealRef(
          source: MealSource.saved,
          id: _savedId,
          name: 'Quinoa, mixed veg & walnuts',
          mealType: MealType.dinner,
          libraryMealId: _libraryId,
        ).toJson(),
      },
    );
  }
}

class _Library extends Fake implements MealLibraryRemoteDataSource {
  @override
  Future<MealDetail> getMeal(String id) async => MealDetail(
    meal: MealRef(
      source: MealSource.library,
      id: id,
      name: 'Quinoa, mixed veg & walnuts',
      mealType: MealType.dinner,
      kcal: 560,
    ),
    directions: const MealDirections(),
    servings: 1,
  );
}

void main() {
  late AppDatabase db;
  late _ServerBackedSavedMeals repo;
  late _SaveMealServer server;

  setUp(() {
    db = AppDatabase.memory();
    repo = _ServerBackedSavedMeals(db);
    server = _SaveMealServer(repo);
  });

  tearDown(() => db.close());

  ProviderContainer container() => testContainer([
    ...baseOverrides(userId: _user),
    savedMealsRepositoryProvider.overrideWithValue(repo),
    vanaActionClientProvider.overrideWithValue(server),
    mealLibraryRemoteDataSourceProvider.overrideWithValue(_Library()),
  ]);

  Future<bool> isSaved(ProviderContainer c) async {
    final sub = c.listen(savedCopyOfLibraryMealProvider(_libraryId), (_, __) {});
    await settle();
    final saved = c.read(savedCopyOfLibraryMealProvider(_libraryId)).value;
    sub.close();
    return saved != null;
  }

  test('save, reopen reads it as saved, then unsave soft-deletes it', () async {
    final first = container();
    await first.read(mealDetailControllerProvider(_libraryId).future);
    expect(await isSaved(first), isFalse);

    final ref = await first
        .read(mealDetailControllerProvider(_libraryId).notifier)
        .saveToMine();
    expect(ref?.id, _savedId);
    expect(server.calls.single, isA<SaveMealAction>());
    await settle();

    // Reopen: a fresh container reads My Foods from Drift.
    final reopened = container();
    await reopened.read(mealDetailControllerProvider(_libraryId).future);
    expect(await isSaved(reopened), isTrue);

    final removed = await reopened
        .read(mealDetailControllerProvider(_libraryId).notifier)
        .removeFromMine();
    expect(removed, isTrue);

    final row = await (db.select(
      db.savedMealsTable,
    )..where((t) => t.id.equals(_savedId))).getSingle();
    expect(row.isDeleted, isTrue);
    expect(await isSaved(reopened), isFalse);
    // Unsave is local-first: no second server action.
    expect(server.calls, hasLength(1));
  });

  test('an unsave right after a save pulls the copy before deleting it', () async {
    final c = container();
    await c.read(mealDetailControllerProvider(_libraryId).future);
    // The server has the row, Drift does not yet (the resync has not run).
    await server.run(const SaveMealAction(libraryMealId: _libraryId));

    final removed = await c
        .read(mealDetailControllerProvider(_libraryId).notifier)
        .removeFromMine();

    expect(removed, isTrue);
    final row = await (db.select(
      db.savedMealsTable,
    )..where((t) => t.id.equals(_savedId))).getSingle();
    expect(row.isDeleted, isTrue);
  });

  test('nothing saved: unsave removes nothing', () async {
    final c = container();
    await c.read(mealDetailControllerProvider(_libraryId).future);
    final removed = await c
        .read(mealDetailControllerProvider(_libraryId).notifier)
        .removeFromMine();
    expect(removed, isFalse);
  });
}
