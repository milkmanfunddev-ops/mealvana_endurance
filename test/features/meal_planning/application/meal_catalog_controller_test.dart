/// MealCatalogController: local rails offline, Recents union + recency, the
/// 350 ms debounce and the filter → search wiring.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_logging/data/meal_log_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/data/saved_meals_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/saved_meal.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_catalog_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_library_remote_data_source.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_plan_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_context.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_type.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/plan_meal.dart';

import '../helpers/container.dart';
import '../helpers/fakes.dart';

class _FakeRemote extends Fake implements MealLibraryRemoteDataSource {
  final List<Map<String, Object?>> searches = [];

  @override
  Future<List<MealRef>> searchMeals({
    String? query,
    MealType? mealType,
    List<MealContext>? contexts,
    bool? batch,
    bool includeSaved = true,
    int limit = 12,
    List<String>? excludeAllergens,
    String? requireDiet,
    MealKind? kind,
    bool includeDisliked = false,
    Set<String> excludeIds = const {},
  }) async {
    searches.add({
      'query': query,
      'mealType': mealType,
      'kind': kind,
      'includeDisliked': includeDisliked,
    });
    return [
      MealRef(
        source: MealSource.library,
        id: 'D-${searches.length}',
        name: 'Result for ${query ?? kind?.wire ?? mealType?.wire}',
        mealType: mealType ?? MealType.dinner,
      ),
    ];
  }

  @override
  Future<List<RecentMeal>> recentMeals({int limit = 20}) async => const [];
}

class _FakeSavedMeals extends Fake implements SavedMealsRepository {
  _FakeSavedMeals(this.meals);
  final List<SavedMeal> meals;

  @override
  Stream<List<SavedMeal>> watchSavedMeals(String userId) => Stream.value(meals);
}

class _FakeMealLogs extends Fake implements MealLogRepository {
  _FakeMealLogs(this.logs);
  final List<MealLog> logs;

  @override
  Future<List<MealLog>> getRecentLogs(String userId, {int limit = 25}) async =>
      logs;
}

class _FakePlanRepo extends Fake implements MealPlanRepository {
  _FakePlanRepo(this.meals, this.createdAt);
  final List<PlanMeal> meals;
  final Map<String, DateTime> createdAt;

  @override
  Future<List<PlanMeal>> getRecentPlanMeals(
    String userId, {
    int limit = 60,
  }) async => meals;

  @override
  Future<Map<String, DateTime>> planMealCreatedAt(String userId) async =>
      createdAt;
}

final _t0 = DateTime.utc(2026, 9, 1, 8);

SavedMeal _saved(String id, String name) => SavedMeal(
  id: id,
  userId: 'user-1',
  name: name,
  components: const [],
  mealTypes: const ['lunch'],
  icon: 'salad',
  createdAt: _t0,
  updatedAt: _t0,
);

MealLog _log({
  required String id,
  String? savedMealId,
  String? planMealId,
  required DateTime at,
}) => MealLog(
  id: id,
  userId: 'user-1',
  logDate: '2026-09-01',
  name: 'log $id',
  source: savedMealId != null ? MealLogSource.saved : MealLogSource.plan,
  components: const [],
  savedMealId: savedMealId,
  planMealId: planMealId,
  eatenAt: at,
  createdAt: at,
  updatedAt: at,
);

void main() {
  late _FakeRemote remote;

  setUp(() => remote = _FakeRemote());

  MealCatalogController make({
    List<SavedMeal> saved = const [],
    List<MealLog> logs = const [],
    List<PlanMeal> planMeals = const [],
    Map<String, DateTime> planCreatedAt = const {},
    bool online = false,
  }) {
    final container = testContainer([
      ...baseOverrides(connectivity: StubConnectivity(online: online)),
      mealLibraryRemoteDataSourceProvider.overrideWithValue(remote),
      savedMealsRepositoryProvider.overrideWithValue(_FakeSavedMeals(saved)),
      mealLogRepositoryProvider.overrideWithValue(_FakeMealLogs(logs)),
      mealPlanRepositoryProvider.overrideWithValue(
        _FakePlanRepo(planMeals, planCreatedAt),
      ),
    ]);
    container.listen(mealCatalogControllerProvider, (_, __) {});
    return container.read(mealCatalogControllerProvider.notifier);
  }

  test(
    'offline: My Foods from saved meals; Recents = logs ∪ plan meals by recency, deduped',
    () async {
      final saved = [_saved('s-1', 'Big salad'), _saved('s-2', 'Oats')];
      const pm = PlanMeal(
        id: 'pm-1',
        planId: 'plan-1',
        source: MealSource.library,
        libraryMealId: 'D-048',
        name: 'Bolognese',
        mealType: MealType.dinner,
        servings: 4,
        servingsLeft: 4,
      );
      final c = make(
        saved: saved,
        logs: [
          _log(
            id: 'l-1',
            savedMealId: 's-2',
            at: _t0.add(const Duration(hours: 3)),
          ),
          _log(
            id: 'l-2',
            savedMealId: 's-2',
            at: _t0.add(const Duration(hours: 1)),
          ), // dup, older
          _log(
            id: 'l-3',
            planMealId: 'pm-1',
            at: _t0.add(const Duration(hours: 2)),
          ),
        ],
        planMeals: const [pm],
        planCreatedAt: {'pm-1': _t0},
      );
      final s = await c.future;

      expect(s.myFoods.map((m) => m.name), ['Big salad', 'Oats']);
      expect(s.myFoods.first.mealType, MealType.lunch);
      expect(s.recents.map((r) => r.meal.id), ['s-2', 'D-048']);
      expect(
        s.recents.first.lastUsedAtDateTime,
        _t0.add(const Duration(hours: 3)),
      );
      expect(s.railsFromServer, isFalse);
      expect(remote.searches, isEmpty, reason: 'no server rails offline');
    },
  );

  test(
    'online: assemblies/recipes rails come from search_meals by kind',
    () async {
      final c = make(online: true);
      await c.future;
      await settle(const Duration(milliseconds: 50));
      final s = c.state.value!;
      expect(s.railsFromServer, isTrue);
      expect(s.assemblies.single.name, 'Result for assembly');
      expect(s.recipes.single.name, 'Result for recipe');
    },
  );

  test(
    'setQuery debounces 350 ms and searches once with the final text',
    () async {
      final c = make();
      await c.future;

      c.setQuery('c');
      c.setQuery('ch');
      c.setQuery('chi');
      await settle(const Duration(milliseconds: 200));
      expect(remote.searches, isEmpty);
      expect(c.state.value!.isFiltering, isTrue);
      await settle(const Duration(milliseconds: 250));

      expect(remote.searches, hasLength(1));
      expect(remote.searches.single['query'], 'chi');
      expect(remote.searches.single['includeDisliked'], isTrue);
      expect(c.state.value!.results.single.name, 'Result for chi');
      expect(c.state.value!.isSearching, isFalse);
    },
  );

  test('filters search immediately; clearFilters drops results', () async {
    final c = make();
    await c.future;

    c.setMealType(MealType.lunch);
    await settle();
    expect(remote.searches.single['mealType'], MealType.lunch);
    expect(c.state.value!.results, hasLength(1));

    c.setKind(MealKind.recipe);
    await settle();
    expect(remote.searches.last['kind'], MealKind.recipe);
    expect(remote.searches.last['mealType'], MealType.lunch);

    c.clearFilters();
    expect(c.state.value!.isFiltering, isFalse);
    expect(c.state.value!.results, isEmpty);
  });

  test('clearing the query cancels a pending search', () async {
    final c = make();
    await c.future;
    c.setQuery('ric');
    c.setQuery('');
    await settle(const Duration(milliseconds: 450));
    expect(remote.searches, isEmpty);
  });
}
