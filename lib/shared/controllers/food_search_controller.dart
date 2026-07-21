import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/nutrition_plan/domain/food.dart';
import '../../features/barcode_scanning/application/catalog_search_service.dart';
import '../services/food_management/fuel_predicate.dart';
import '../services/food_management/nutrition_product_search_service.dart';
import '../services/food_management/shared_food_search_service.dart';
import '../services/logging_service.dart';
import '../services/app_external_deps.dart';
import '../utils/search_token_matcher.dart';

part 'food_search_controller.g.dart';

/// When the combined user + template + catalog hit count for a query is
/// below this, we automatically supplement with a `search-nutrition-products`
/// call (USDA + cached Open Food Facts) so a thin catalog result set doesn't
/// leave the user without options. See ITEM 7 (auto OFF+USDA, no button).
const int _kFewLocalResultsThreshold = 5;

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
    this.nutritionProductResults = const [],
    this.isSearchingNutritionProducts = false,
    this.openFoodFactsError,
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

  /// Auto-fetched USDA + cached-OpenFoodFacts results from
  /// `search-nutrition-products`, triggered automatically when local +
  /// catalog hits are thin (ITEM 7) — not gated behind a manual button.
  final List<NutritionProductSearchResult> nutritionProductResults;
  final bool isSearchingNutritionProducts;

  /// Set when an Open Food Facts search failed after retries. Distinguishes
  /// "we couldn't reach OFF" from "OFF has no such food" — without it, a rate-
  /// limit 503 renders identically to a genuine miss.
  final String? openFoodFactsError;

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
    List<NutritionProductSearchResult>? nutritionProductResults,
    bool? isSearchingNutritionProducts,
    String? openFoodFactsError,
    bool clearOpenFoodFactsError = false,
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
      nutritionProductResults:
          nutritionProductResults ?? this.nutritionProductResults,
      isSearchingNutritionProducts:
          isSearchingNutritionProducts ?? this.isSearchingNutritionProducts,
      openFoodFactsError: clearOpenFoodFactsError
          ? null
          : (openFoodFactsError ?? this.openFoodFactsError),
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
        return foods.where((f) => isFuelProductType(f.productTypeId)).toList();
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
            .where(
              (c) =>
                  c.productTypeId == null || isFuelProductType(c.productTypeId),
            )
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

  /// Apply the active fuel/general filter to `search-nutrition-products`
  /// results. Unlike The Feed catalog (curated, so unclassified defaults to
  /// fuel-visible), `nutrition_products` is a general USDA/OFF cache, so an
  /// unclassified result is treated as **general** — same rule as local
  /// foods — so a fuel-only surface never shows an unclassified grocery item
  /// by accident.
  List<NutritionProductSearchResult> _applyNutritionProductFilter(
    List<NutritionProductSearchResult> results,
  ) {
    switch (_filter) {
      case FoodSearchFilter.all:
        return results;
      case FoodSearchFilter.fuelOnly:
        return results
            .where((r) => isFuelProductType(r.suggestedProductType))
            .toList();
      case FoodSearchFilter.generalFirst:
        final general = <NutritionProductSearchResult>[];
        final fuel = <NutritionProductSearchResult>[];
        for (final r in results) {
          (isFuelProductType(r.suggestedProductType) ? fuel : general).add(r);
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
    _allTemplateFoods = allFoods
        .where((f) => !userFoodIds.contains(f.id))
        .toList();
  }

  /// Update the search query and filter local foods + trigger catalog search.
  void updateSearch(String query) {
    if (query.isEmpty) {
      _catalogDebounceTimer?.cancel();
      state = const FoodSearchState();
      return;
    }

    final queryTokens = tokenizeSearchQuery(query);

    // Filter user foods
    final filteredUserFoods = _allUserFoods.where((food) {
      final searchText = _buildSearchText(food);
      return matchesSearchTokens(searchText, queryTokens);
    }).toList();

    // Filter template foods (already deduped from user foods in updateFoodPool)
    final filteredTemplateFoods = _allTemplateFoods.where((food) {
      final searchText = _buildSearchText(food);
      return matchesSearchTokens(searchText, queryTokens);
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
  ///
  /// Open Food Facts sheds load as HTTP 503 rather than 429 once you go over
  /// its ~10 req/min limit — measured at roughly a 50% failure rate at 20/min,
  /// and reproduced in-app as "first tap returns nothing, second tap works".
  /// So: retry a couple of times with backoff, and on final failure record the
  /// error rather than silently leaving an empty result set, which the UI
  /// renders as "No foods found" — indistinguishable from the food genuinely
  /// not existing.
  Future<void> searchOpenFoodFacts(String query) async {
    if (query.isEmpty) return;

    final searchService = ref.read(sharedFoodSearchServiceProvider);

    state = state.copyWith(
      isSearchingOpenFoodFacts: true,
      clearOpenFoodFactsError: true,
    );

    const attempts = 3;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        final results = await searchService.searchProducts(query);

        if (!_isMounted) return;
        // A newer query superseded this one while we were retrying.
        if (state.searchQuery.trim() != query.trim()) return;

        state = state.copyWith(
          openFoodFactsResults: results,
          isSearchingOpenFoodFacts: false,
          clearOpenFoodFactsError: true,
        );
        return;
      } catch (e) {
        if (!_isMounted) return;

        final isLast = attempt == attempts;
        _logger.warning(
          'Open Food Facts search failed (attempt $attempt/$attempts)',
          context: 'FoodSearchController',
          data: {'query': query, 'error': e.toString()},
        );

        if (!isLast) {
          // 400ms, 800ms — enough to ride out a rate-limit blip without
          // making the user wait long for a genuine outage.
          await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
          if (!_isMounted) return;
          if (state.searchQuery.trim() != query.trim()) return;
          continue;
        }

        state = state.copyWith(
          isSearchingOpenFoodFacts: false,
          openFoodFactsError:
              "Couldn't reach Open Food Facts. Tap to try again.",
        );
      }
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

  /// Internal: search the product catalog. When the combined local +
  /// catalog hit count comes back thin, automatically supplements with
  /// `search-nutrition-products` (USDA + cached Open Food Facts) — see
  /// [_maybeAutoSearchNutritionProducts]. No manual button (ITEM 7).
  Future<void> _searchCatalog(String query) async {
    final searchService = ref.read(sharedFoodSearchServiceProvider);

    if (_isMounted) {
      state = state.copyWith(isSearchingCatalog: true);
    }

    var catalogHitCount = 0;
    try {
      final results = await searchService.searchCatalog(query);

      if (!_isMounted) return;

      // Only update if query is still current
      if (state.searchQuery.trim() != query.trim()) return;

      final filtered = _applyCatalogFilter(results);
      catalogHitCount = filtered.length;
      state = state.copyWith(
        catalogResults: filtered,
        isSearchingCatalog: false,
        totalCatalogCount: filtered.length,
      );
    } catch (e) {
      if (!_isMounted) return;

      _logger.warning(
        'Catalog search failed',
        context: 'FoodSearchController',
        data: {'query': query, 'error': e.toString()},
      );

      state = state.copyWith(isSearchingCatalog: false);
    }

    _maybeAutoSearchNutritionProducts(query, catalogHitCount);
  }

  /// Fires the `search-nutrition-products` (USDA + cached OpenFoodFacts)
  /// lookup automatically when local + catalog results are thin, instead of
  /// requiring a manual "Search Open Food Facts" button tap (ITEM 7).
  void _maybeAutoSearchNutritionProducts(String query, int catalogHitCount) {
    if (!_isMounted) return;
    if (state.searchQuery.trim() != query.trim()) return;

    final localHitCount =
        state.userFoodResults.length + state.templateFoodResults.length;
    if (localHitCount + catalogHitCount >= _kFewLocalResultsThreshold) return;

    unawaited(_searchNutritionProducts(query));
  }

  /// Internal: search `nutrition_products` (USDA FoodData Central + cached
  /// Open Food Facts) via the `search-nutrition-products` edge function.
  /// Server-side, so it works reliably on Flutter web (the direct-to-OFF CGI
  /// call `searchOpenFoodFacts` uses is CORS-blocked there).
  Future<void> _searchNutritionProducts(String query) async {
    final searchService = ref.read(nutritionProductSearchServiceProvider);

    if (_isMounted) {
      state = state.copyWith(isSearchingNutritionProducts: true);
    }

    try {
      final results = await searchService.search(query);

      if (!_isMounted) return;

      if (state.searchQuery.trim() == query.trim()) {
        state = state.copyWith(
          nutritionProductResults: _applyNutritionProductFilter(results),
          isSearchingNutritionProducts: false,
        );
      }
    } catch (e) {
      if (!_isMounted) return;

      _logger.warning(
        'Nutrition product search failed',
        context: 'FoodSearchController',
        data: {'query': query, 'error': e.toString()},
      );

      state = state.copyWith(isSearchingNutritionProducts: false);
    }
  }

  String _buildSearchText(Food food) {
    return normalizeSearchText(
      [
        food.name,
        food.displayName,
        food.displayNamePlural,
        food.description,
        food.productTypeId,
      ].whereType<String>().join(' '),
    );
  }
}
