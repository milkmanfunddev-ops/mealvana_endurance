import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/providers/user_id_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/connectivity_checker.dart';
import '../../../shared/services/logging_service.dart';
import '../../meal_logging/data/meal_log_repository.dart';
import '../../meal_logging/data/saved_meals_repository.dart';
import '../../meal_logging/domain/saved_meal.dart';
import '../data/meal_library_remote_data_source.dart';
import '../data/meal_plan_repository.dart';
import '../domain/meal_ref.dart';
import '../domain/meal_source.dart';
import '../domain/meal_type.dart';
import 'meal_ref_mapping.dart';

part 'meal_catalog_controller.g.dart';

/// Immutable state of the Meals tab catalog (rails + search).
class MealCatalogState {
  const MealCatalogState({
    this.query = '',
    this.mealType,
    this.kind,
    this.recents = const [],
    this.myFoods = const [],
    this.assemblies = const [],
    this.recipes = const [],
    this.results = const [],
    this.isSearching = false,
    this.railsFromServer = false,
    this.searchError,
  });

  final String query;

  /// Filter popover: meal type × assembly/recipe.
  final MealType? mealType;
  final MealKind? kind;

  /// Rails. Recents = local logs ∪ plan meals by recency (server-resolved
  /// when online); My Foods = saved meals; Assemblies / Recipes = the first
  /// page of `search_meals` by kind.
  final List<RecentMeal> recents;
  final List<MealRef> myFoods;
  final List<MealRef> assemblies;
  final List<MealRef> recipes;

  /// Flat results while a query or a filter is active.
  final List<MealRef> results;
  final bool isSearching;

  /// True once the online rails (assemblies/recipes, server recents) loaded.
  final bool railsFromServer;

  /// Last search failure (typed, for the UI to map to copy); null when fine.
  final Object? searchError;

  /// A query or a filter is active — show [results] instead of the rails.
  bool get isFiltering =>
      query.trim().isNotEmpty || mealType != null || kind != null;

  MealCatalogState copyWith({
    String? query,
    MealType? mealType,
    bool clearMealType = false,
    MealKind? kind,
    bool clearKind = false,
    List<RecentMeal>? recents,
    List<MealRef>? myFoods,
    List<MealRef>? assemblies,
    List<MealRef>? recipes,
    List<MealRef>? results,
    bool? isSearching,
    bool? railsFromServer,
    Object? searchError,
    bool clearSearchError = false,
  }) => MealCatalogState(
    query: query ?? this.query,
    mealType: clearMealType ? null : (mealType ?? this.mealType),
    kind: clearKind ? null : (kind ?? this.kind),
    recents: recents ?? this.recents,
    myFoods: myFoods ?? this.myFoods,
    assemblies: assemblies ?? this.assemblies,
    recipes: recipes ?? this.recipes,
    results: results ?? this.results,
    isSearching: isSearching ?? this.isSearching,
    railsFromServer: railsFromServer ?? this.railsFromServer,
    searchError: clearSearchError ? null : (searchError ?? this.searchError),
  );
}

/// Meals tab: rails (Recents / My Foods / Assemblies / Recipes) plus a
/// debounced (350 ms) search with meal-type × kind filters.
///
/// Local rails (Recents from Drift logs + plan meals, My Foods from saved
/// meals) load first so the tab renders offline; the online rails and the
/// server-resolved Recents replace them when reachable. Search is online
/// only (`meal_library` is not mirrored).
@riverpod
class MealCatalogController extends _$MealCatalogController {
  static const debounce = Duration(milliseconds: 350);
  static const railLimit = 12;
  static const searchLimit = 30;
  static const recentsLimit = 20;

  MealLibraryRemoteDataSource get _remote =>
      ref.read(mealLibraryRemoteDataSourceProvider);
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;

  Timer? _debounce;
  int _searchSeq = 0;

  @override
  FutureOr<MealCatalogState> build() async {
    ref.onDispose(() => _debounce?.cancel());

    final userId = await ref.watch(userIdProvider.future);
    final local = await _loadLocalRails(userId);

    // Online rails are a refinement, never a gate.
    unawaited(_loadServerRails());
    return local;
  }

  // ── Rails ──────────────────────────────────────────────────────────────────

  Future<MealCatalogState> _loadLocalRails(String userId) async {
    final saved = await ref
        .read(savedMealsRepositoryProvider)
        .watchSavedMeals(userId)
        .first;
    final recents = await _localRecents(userId, saved);
    return MealCatalogState(
      recents: recents,
      myFoods: saved.map(MealRefMapping.fromSavedMeal).toList(growable: false),
    );
  }

  /// Recents = local `meal_logs` ∪ `plan_meals`, keyed by source id, newest
  /// touch first (the prototype's `getRecentMeals`, minus the name-only
  /// library lookup the server does when online).
  Future<List<RecentMeal>> _localRecents(
    String userId,
    List<SavedMeal> saved,
  ) async {
    final planRepo = ref.read(mealPlanRepositoryProvider);
    final planMeals = await planRepo.getRecentPlanMeals(userId);
    final createdAt = await planRepo.planMealCreatedAt(userId);
    final logs = await ref
        .read(mealLogRepositoryProvider)
        .getRecentLogs(userId, limit: 60);

    final savedById = {for (final s in saved) s.id: s};
    final planById = {for (final p in planMeals) p.id: p};
    final touched = <String, (MealRef, DateTime)>{};

    void touch(MealRef ref, DateTime at) {
      final key = MealRefMapping.key(ref);
      final prev = touched[key];
      if (prev == null || at.isAfter(prev.$2)) touched[key] = (ref, at);
    }

    for (final pm in planMeals) {
      final ref = MealRefMapping.fromPlanMeal(pm);
      if (ref == null) continue;
      touch(ref, createdAt[pm.id] ?? DateTime.fromMillisecondsSinceEpoch(0));
    }
    for (final log in logs) {
      final at = log.eatenAt ?? log.createdAt;
      final savedMeal = log.savedMealId == null
          ? null
          : savedById[log.savedMealId!];
      if (savedMeal != null) {
        touch(MealRefMapping.fromSavedMeal(savedMeal), at);
        continue;
      }
      final planMeal = log.planMealId == null
          ? null
          : planById[log.planMealId!];
      if (planMeal != null) {
        final ref = MealRefMapping.fromPlanMeal(planMeal);
        if (ref != null) touch(ref, at);
      }
      // Name-only logs need the server's library lookup — skipped offline.
    }

    final entries = touched.values.toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return [
      for (final (ref, at) in entries.take(recentsLimit))
        RecentMeal(meal: ref, lastUsedAt: at.toUtc().toIso8601String()),
    ];
  }

  Future<void> _loadServerRails() async {
    if (!await ref.read(connectivityCheckerProvider).isOnline()) return;
    try {
      final results = await Future.wait([
        _remote.searchMeals(kind: MealKind.assembly, limit: railLimit),
        _remote.searchMeals(kind: MealKind.recipe, limit: railLimit),
        _remote.recentMeals(limit: recentsLimit),
      ]);
      if (!ref.mounted) return;
      final current = state.value;
      if (current == null) return;
      final serverRecents = results[2] as List<RecentMeal>;
      state = AsyncData(
        current.copyWith(
          assemblies: results[0] as List<MealRef>,
          recipes: results[1] as List<MealRef>,
          recents: serverRecents.isNotEmpty ? serverRecents : current.recents,
          railsFromServer: true,
        ),
      );
    } catch (e, st) {
      _logger.warning(
        'Catalog rails: server load failed (local rails kept)',
        context: 'MEAL_CATALOG_CONTROLLER',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Re-read the local rails (after a log or a plan change).
  Future<void> refreshRails() async {
    final current = state.value;
    if (current == null) return;
    final userId = await ref.read(userIdProvider.future);
    final local = await _loadLocalRails(userId);
    if (!ref.mounted) return;
    state = AsyncData(
      current.copyWith(
        recents: current.railsFromServer ? current.recents : local.recents,
        myFoods: local.myFoods,
      ),
    );
    unawaited(_loadServerRails());
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  /// Update the query; the search fires [debounce] after the last keystroke.
  void setQuery(String query) {
    final current = state.value ?? const MealCatalogState();
    state = AsyncData(current.copyWith(query: query, clearSearchError: true));
    _debounce?.cancel();
    if (!state.value!.isFiltering) {
      state = AsyncData(
        state.value!.copyWith(results: const [], isSearching: false),
      );
      return;
    }
    _debounce = Timer(debounce, _runSearch);
  }

  void setMealType(MealType? mealType) {
    final current = state.value ?? const MealCatalogState();
    state = AsyncData(
      current.copyWith(
        mealType: mealType,
        clearMealType: mealType == null,
        clearSearchError: true,
      ),
    );
    _debounce?.cancel();
    _searchOrClear();
  }

  void setKind(MealKind? kind) {
    final current = state.value ?? const MealCatalogState();
    state = AsyncData(
      current.copyWith(
        kind: kind,
        clearKind: kind == null,
        clearSearchError: true,
      ),
    );
    _debounce?.cancel();
    _searchOrClear();
  }

  void clearFilters() {
    final current = state.value ?? const MealCatalogState();
    _debounce?.cancel();
    state = AsyncData(
      current.copyWith(
        query: '',
        clearMealType: true,
        clearKind: true,
        results: const [],
        isSearching: false,
        clearSearchError: true,
      ),
    );
  }

  void _searchOrClear() {
    final current = state.value!;
    if (current.isFiltering) {
      unawaited(_runSearch());
    } else {
      state = AsyncData(
        current.copyWith(results: const [], isSearching: false),
      );
    }
  }

  Future<void> _runSearch() async {
    final current = state.value;
    if (current == null || !current.isFiltering) return;
    final seq = ++_searchSeq;
    state = AsyncData(
      current.copyWith(isSearching: true, clearSearchError: true),
    );
    try {
      final results = await _remote.searchMeals(
        query: current.query,
        mealType: current.mealType,
        kind: current.kind,
        includeDisliked: true,
        limit: searchLimit,
      );
      if (!ref.mounted || seq != _searchSeq) return;
      state = AsyncData(
        state.value!.copyWith(results: results, isSearching: false),
      );
    } catch (e, st) {
      if (!ref.mounted || seq != _searchSeq) return;
      _logger.warning(
        'Catalog search failed',
        context: 'MEAL_CATALOG_CONTROLLER',
        error: e,
        stackTrace: st,
      );
      state = AsyncData(
        state.value!.copyWith(isSearching: false, searchError: e),
      );
    }
  }
}
