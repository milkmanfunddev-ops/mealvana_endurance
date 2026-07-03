import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/nutrition_plan/domain/food.dart';
import '../../features/barcode_scanning/application/catalog_search_service.dart';
import '../services/food_management/fuel_predicate.dart';
import '../services/food_management/shared_food_search_service.dart';
import '../services/logging_service.dart';
import '../services/app_external_deps.dart';

part 'food_search_controller.g.dart';

/// How a search surface filters results by endurance-fuel vs general food.
///
/// The separation is display/search-layer only (one scanner, one pool) —
/// audit §3. Plan add/swap uses [fuelOnly] (no potato salad in a fuel plan);
/// meal-logging Discover uses [generalFirst] (everything, fuel deprioritized).
enum FoodSearchFilter {
  /// No fuel/general filtering — legacy behavior (default).
  all,

  /// Only endurance-fuel products. General foods are hidden.
  fuelOnly,

  /// All foods, but general food is surfaced ahead of pure fuel.
  generalFirst,
}

/// Unified search state shared by Swap Food and Food Preferences screens.
class FoodSearchState {
  const FoodSearchState({
    this.searchQuery = '',
    this.userFoodResults = const [],
    this.templateFoodResults = const [],
    this.catalogResults = const [],
    this.openFoodFactsResults = const [],
    this.isSearchingCatalog = false,
    this.isSearchingOpenFoodFacts = false,
    this.totalCatalogCount = 0,
    this.isCatalogExpanded = false,
  });

  final String searchQuery;
  final List<Food> userFoodResults;
  final List<Food> templateFoodResults;
  final List<CatalogSearchResult> catalogResults;
  final List<dynamic> openFoodFactsResults;
  final bool isSearchingCatalog;
  final bool isSearchingOpenFoodFacts;
  final int totalCatalogCount;
  final bool isCatalogExpanded;

  FoodSearchState copyWith({
    String? searchQuery,
    List<Food>? userFoodResults,
    List<Food>? templateFoodResults,
    List<CatalogSearchResult>? catalogResults,
    List<dynamic>? openFoodFactsResults,
    bool? isSearchingCatalog,
    bool? isSearchingOpenFoodFacts,
    int? totalCatalogCount,
    bool? isCatalogExpanded,
  }) {
    return FoodSearchState(
      searchQuery: searchQuery ?? this.searchQuery,
      userFoodResults: userFoodResults ?? this.userFoodResults,
      templateFoodResults: templateFoodResults ?? this.templateFoodResults,
      catalogResults: catalogResults ?? this.catalogResults,
      openFoodFactsResults: openFoodFactsResults ?? this.openFoodFactsResults,
      isSearchingCatalog: isSearchingCatalog ?? this.isSearchingCatalog,
      isSearchingOpenFoodFacts:
          isSearchingOpenFoodFacts ?? this.isSearchingOpenFoodFacts,
      totalCatalogCount: totalCatalogCount ?? this.totalCatalogCount,
      isCatalogExpanded: isCatalogExpanded ?? this.isCatalogExpanded,
    );
  }
}

/// Shared food search controller keyed by screen name.
///
/// Each screen gets its own instance via the [key] parameter
/// (e.g. "swap_food" or "food_preferences").
@riverpod
class FoodSearchController extends _$FoodSearchController {
  late AppLogger _logger;
  Timer? _catalogDebounceTimer;

  /// All user foods (unfiltered) for search
  List<Food> _allUserFoods = [];

  /// All template/system foods for search
  List<Food> _allTemplateFoods = [];

  /// Fuel/general filter for this surface. Set once per screen via
  /// [setFilter]; defaults to [FoodSearchFilter.all] so untouched surfaces
  /// keep their legacy behavior.
  FoodSearchFilter _filter = FoodSearchFilter.all;

  bool get _isMounted {
    try {
      state;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  FoodSearchState build(String key) {
    _logger = ref.read(appExternalDepsProvider).logger;
    ref.onDispose(() {
      _catalogDebounceTimer?.cancel();
    });
    return const FoodSearchState();
  }

  /// Set the fuel/general filter for this surface. Call once after obtaining
  /// the notifier (e.g. in the screen's seed step). Re-filters the current
  /// results if a query is already active.
  void setFilter(FoodSearchFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    if (state.searchQuery.isNotEmpty) {
      updateSearch(state.searchQuery);
    }
  }

  /// Apply the active fuel/general filter to a local food list.
  List<Food> _applyLocalFilter(List<Food> foods) {
    switch (_filter) {
      case FoodSearchFilter.all:
        return foods;
      case FoodSearchFilter.fuelOnly:
        return foods
            .where((f) => isFuelProductType(f.productTypeId))
            .toList();
      case FoodSearchFilter.generalFirst:
        final general = <Food>[];
        final fuel = <Food>[];
        for (final f in foods) {
          (isFuelProductType(f.productTypeId) ? fuel : general).add(f);
        }
        return [...general, ...fuel];
    }
  }

  /// Apply the active fuel/general filter to catalog (The Feed) results.
  /// The Feed is a curated endurance catalog, so unclassified results
  /// (`productTypeId == null`) are kept under [FoodSearchFilter.fuelOnly].
  List<CatalogSearchResult> _applyCatalogFilter(
    List<CatalogSearchResult> results,
  ) {
    switch (_filter) {
      case FoodSearchFilter.all:
        return results;
      case FoodSearchFilter.fuelOnly:
        return results
            .where((c) =>
                c.productTypeId == null || isFuelProductType(c.productTypeId))
            .toList();
      case FoodSearchFilter.generalFirst:
        final general = <CatalogSearchResult>[];
        final fuel = <CatalogSearchResult>[];
        for (final c in results) {
          (isFuelProductType(c.productTypeId) ? fuel : general).add(c);
        }
        return [...general, ...fuel];
    }
  }

  /// Seed or update the searchable food pools.
  /// Called by each screen after it loads its data.
  void updateFoodPool({
    required List<Food> allFoods,
    required List<Food> userFoods,
  }) {
    // Separate user foods from template foods
    final userFoodIds = userFoods.map((f) => f.id).toSet();
    _allUserFoods = userFoods;
    _allTemplateFoods =
        allFoods.where((f) => !userFoodIds.contains(f.id)).toList();
  }

  /// Update the search query and filter local foods + trigger catalog search.
  void updateSearch(String query) {
    if (query.isEmpty) {
      _catalogDebounceTimer?.cancel();
      state = const FoodSearchState();
      return;
    }

    final normalizedQuery = _normalizeSearchText(query);
    final queryTokens = normalizedQuery
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList();

    // Filter user foods
    final filteredUserFoods = _allUserFoods.where((food) {
      final searchText = _buildSearchText(food);
      return _matchesSearchTokens(searchText, queryTokens);
    }).toList();

    // Filter template foods (already deduped from user foods in updateFoodPool)
    final filteredTemplateFoods = _allTemplateFoods.where((food) {
      final searchText = _buildSearchText(food);
      return _matchesSearchTokens(searchText, queryTokens);
    }).toList();

    state = state.copyWith(
      searchQuery: query,
      userFoodResults: _applyLocalFilter(filteredUserFoods),
      templateFoodResults: _applyLocalFilter(filteredTemplateFoods),
      // Reset catalog expansion when query changes
      isCatalogExpanded: false,
    );

    // Trigger debounced catalog search
    _catalogDebounceTimer?.cancel();
    if (query.trim().length >= 2) {
      _catalogDebounceTimer = Timer(const Duration(milliseconds: 300), () {
        _searchCatalog(query.trim());
      });
    }
  }

  /// Manually trigger Open Food Facts search (always user-initiated).
  Future<void> searchOpenFoodFacts(String query) async {
    if (query.isEmpty) return;

    final searchService = ref.read(sharedFoodSearchServiceProvider);

    state = state.copyWith(isSearchingOpenFoodFacts: true);

    try {
      final results = await searchService.searchProducts(query);

      if (!_isMounted) return;

      state = state.copyWith(
        openFoodFactsResults: results,
        isSearchingOpenFoodFacts: false,
      );
    } catch (e) {
      if (!_isMounted) return;

      _logger.warning(
        'Open Food Facts search failed',
        context: 'FoodSearchController',
        data: {'query': query, 'error': e.toString()},
      );

      state = state.copyWith(isSearchingOpenFoodFacts: false);
    }
  }

  /// Clear Open Food Facts results.
  void clearOpenFoodFactsResults() {
    state = state.copyWith(
      openFoodFactsResults: [],
      isSearchingOpenFoodFacts: false,
    );
  }

  /// Expand catalog results to show more (up to 50).
  Future<void> expandCatalogResults() async {
    state = state.copyWith(isCatalogExpanded: true);
  }

  /// Reset all search state.
  void clearSearch() {
    _catalogDebounceTimer?.cancel();
    state = const FoodSearchState();
  }

  /// Internal: search the product catalog.
  Future<void> _searchCatalog(String query) async {
    final searchService = ref.read(sharedFoodSearchServiceProvider);

    if (_isMounted) {
      state = state.copyWith(isSearchingCatalog: true);
    }

    try {
      final results = await searchService.searchCatalog(query);

      if (!_isMounted) return;

      // Only update if query is still current
      if (state.searchQuery.trim() == query.trim()) {
        final filtered = _applyCatalogFilter(results);
        state = state.copyWith(
          catalogResults: filtered,
          isSearchingCatalog: false,
          totalCatalogCount: filtered.length,
        );
      }
    } catch (e) {
      if (!_isMounted) return;

      _logger.warning(
        'Catalog search failed',
        context: 'FoodSearchController',
        data: {'query': query, 'error': e.toString()},
      );

      state = state.copyWith(isSearchingCatalog: false);
    }
  }

  String _normalizeSearchText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _buildSearchText(Food food) {
    return _normalizeSearchText(
      [
        food.name,
        food.displayName,
        food.displayNamePlural,
        food.description,
        food.productTypeId,
      ].whereType<String>().join(' '),
    );
  }

  bool _matchesSearchTokens(String haystack, List<String> queryTokens) {
    if (queryTokens.isEmpty) return true;
    for (final token in queryTokens) {
      final singular = token.endsWith('s') && token.length > 3
          ? token.substring(0, token.length - 1)
          : token;
      if (!haystack.contains(token) && !haystack.contains(singular)) {
        return false;
      }
    }
    return true;
  }
}
