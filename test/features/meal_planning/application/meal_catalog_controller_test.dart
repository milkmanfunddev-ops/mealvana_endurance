/// MealCatalogController: local rails offline, Recents union + recency, the
/// 350 ms debounce and the filter → search wiring.
library;

import 'dart:async';

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
  _FakeRemote({this.pool});

  /// What `recent_meals` answers, and a gate that holds the answer back the
  /// way the edge function's 1.8-5.2 s did (testing-wave 88-006).
  List<RecentMeal> serverRecents = const [];
  Completer<void>? recentsGate;

  final List<Map<String, Object?>> searches = [];

  /// When set, the fake behaves like a library of this many meals and honours
  /// limit/offset, so paging can be exercised. Null keeps the one-row default
  /// the older tests assert against.
  final int? pool;

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
    int offset = 0,
    bool requireNutritionNumbers = false,
  }) async {
    searches.add({
      'query': query,
      'mealType': mealType,
      'kind': kind,
      'includeDisliked': includeDisliked,
      'includeSaved': includeSaved,
      'limit': limit,
      'offset': offset,
    });
    if (pool != null) {
      final end = (offset + limit).clamp(0, pool!);
      return [
        for (var i = offset; i < end; i++)
          MealRef(
            source: MealSource.library,
            id: 'L-$i',
            name: 'Library meal $i',
            mealType: mealType ?? MealType.dinner,
          ),
      ];
    }
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
  Future<List<RecentMeal>> recentMeals({int limit = 20}) async {
    await recentsGate?.future;
    return serverRecents;
  }
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

  late ProviderContainer container;

  MealCatalogController make({
    List<SavedMeal> saved = const [],
    List<MealLog> logs = const [],
    List<PlanMeal> planMeals = const [],
    Map<String, DateTime> planCreatedAt = const {},
    bool online = false,
  }) {
    container = testContainer([
      ...baseOverrides(connectivity: StubConnectivity(online: online)),
      mealLibraryRemoteDataSourceProvider.overrideWithValue(remote),
      savedMealsRepositoryProvider.overrideWithValue(_FakeSavedMeals(saved)),
      mealLogRepositoryProvider.overrideWithValue(_FakeMealLogs(logs)),
      mealPlanRepositoryProvider.overrideWithValue(
        _FakePlanRepo(planMeals, planCreatedAt),
      ),
    ]);
    container.listen(mealCatalogControllerProvider(CatalogSurface.mealsTab), (_, __) {});
    return container.read(mealCatalogControllerProvider(CatalogSurface.mealsTab).notifier);
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

  // ── The Meals tab showed ~20 of ~1,900 meals ───────────────────────────────

  test('kind rails exclude saved meals, which used to crowd them out', () async {
    final c = make(online: true);
    await c.future;
    await settle();

    final railCalls = remote.searches
        .where((s) => s['kind'] != null && s['query'] == null)
        .toList();
    expect(railCalls, hasLength(2));
    for (final call in railCalls) {
      // Saved meals score 0.65 against a library row's ~0.5; left in, twelve of
      // them filled both rails and no library meal appeared.
      expect(call['includeSaved'], isFalse);
      expect(call['limit'], MealCatalogController.railLimit);
    }
    expect(
      railCalls.map((s) => s['kind']),
      containsAll(<MealKind>[MealKind.assembly, MealKind.recipe]),
    );
  });

  test(
    'loadMore pages the flat list by offset until the library runs out',
    () async {
      remote = _FakeRemote(pool: 95);
      final c = make();
      await c.future;

      c.setKind(MealKind.assembly);
      await settle();

      const page = MealCatalogController.searchLimit;
      expect(c.state.value!.results, hasLength(page));
      expect(c.state.value!.hasMore, isTrue);

      await c.loadMore();
      expect(c.state.value!.results, hasLength(page * 2));
      expect(remote.searches.last['offset'], page);
      expect(c.state.value!.hasMore, isTrue);

      // 95 meals: the third page is short, so paging stops.
      await c.loadMore();
      expect(c.state.value!.results, hasLength(95));
      expect(c.state.value!.hasMore, isFalse);

      // Every meal is distinct — the RPC's (score, id) ordering is what makes
      // offset paging safe; ties alone would repeat rows across pages.
      final ids = c.state.value!.results.map((m) => m.id).toSet();
      expect(ids, hasLength(95));

      // Exhausted: further calls are no-ops.
      final before = remote.searches.length;
      await c.loadMore();
      expect(remote.searches, hasLength(before));
    },
  );

  test('loadMore is a no-op while no filter is active', () async {
    remote = _FakeRemote(pool: 95);
    final c = make();
    await c.future;

    await c.loadMore();
    expect(remote.searches, isEmpty);
    expect(c.state.value!.results, isEmpty);
  });

  // ── Recents holds still once shown (testing-wave 88-006) ───────────────────

  RecentMeal recent(MealSource source, String id, String name) => RecentMeal(
    meal: MealRef(
      source: source,
      id: id,
      name: name,
      mealType: MealType.dinner,
    ),
    lastUsedAt: _t0.toIso8601String(),
  );

  test(
    'a server Recents answer after the first paint does not reorder the shown rail',
    () async {
      remote.recentsGate = Completer<void>();
      remote.serverRecents = [
        recent(MealSource.library, 'AD-900', 'Rice, black beans & plantain'),
        recent(MealSource.library, 'D-048', 'Bolognese (server row)'),
        recent(MealSource.saved, 's-2', 'Oats'),
      ];
      final c = make(
        online: true,
        saved: [_saved('s-2', 'Oats')],
        logs: [
          _log(
            id: 'l-1',
            savedMealId: 's-2',
            at: _t0.add(const Duration(hours: 3)),
          ),
        ],
        planMeals: const [
          PlanMeal(
            id: 'pm-1',
            planId: 'plan-1',
            source: MealSource.library,
            libraryMealId: 'D-048',
            name: 'Bolognese',
            mealType: MealType.dinner,
            servings: 4,
            servingsLeft: 4,
          ),
        ],
        planCreatedAt: {'pm-1': _t0},
      );

      final painted = await c.future;
      expect(painted.recents.map((r) => r.meal.id), ['s-2', 'D-048']);

      remote.recentsGate!.complete();
      await settle(const Duration(milliseconds: 50));

      final s = c.state.value!;
      expect(s.railsFromServer, isTrue);
      // Shown meals keep their places; the server's own rows go after them.
      expect(s.recents.map((r) => r.meal.id), ['s-2', 'D-048', 'AD-900']);
      // A shown meal takes the server's row in place.
      expect(s.recents[1].meal.name, 'Bolognese (server row)');
    },
  );

  test('with nothing shown, the server Recents are taken as they come', () {
    final server = [
      recent(MealSource.library, 'A', 'a'),
      recent(MealSource.library, 'B', 'b'),
    ];
    expect(
      MealCatalogController.mergeRecents(const [], server).map((r) => r.meal.id),
      ['A', 'B'],
    );
  });

  // ── One catalog per surface (testing-wave 89-008) ──────────────────────────

  test('Browse opens on its rails while the Meals tab holds a query', () async {
    final c = make();
    await c.future;
    c.setQuery('spinach');
    expect(c.state.value!.isFiltering, isTrue);

    container.listen(
      mealCatalogControllerProvider(CatalogSurface.browse),
      (_, __) {},
    );
    final browse = await container.read(
      mealCatalogControllerProvider(CatalogSurface.browse).future,
    );
    expect(browse.query, isEmpty);
    expect(browse.isFiltering, isFalse);
    expect(c.state.value!.query, 'spinach');
  });
}
