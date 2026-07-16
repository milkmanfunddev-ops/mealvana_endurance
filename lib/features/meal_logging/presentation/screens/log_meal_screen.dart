import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../shared/controllers/food_search_controller.dart';
import '../../../../shared/database/database_provider.dart';
import '../../../../shared/services/analytics/analytics_tracker.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/food_management/nutrition_product_search_service.dart';
import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/food_selection/food_search_bar.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../barcode_scanning/application/catalog_search_service.dart';
import '../../../barcode_scanning/application/food_mapping_service.dart';
import '../../../barcode_scanning/application/product_detail_service.dart';
import '../../../nutrition_plan/data/food_repository.dart';
import '../../../nutrition_plan/domain/food.dart';
import '../../../nutrition_plan/domain/food_item.dart';
import '../../../recipes/application/recipe_service.dart';
import '../../../recipes/domain/recipe.dart';
import '../../application/meal_ai_service.dart';
import '../../application/meal_logging_service.dart' show RecipeLogParams;
import '../../domain/consumed_totals.dart';
import '../../domain/meal_auto_name.dart';
import '../../domain/meal_log_source.dart';
import '../../domain/saved_meal.dart';
import '../providers/meal_log_providers.dart';
import '../widgets/common_ingredients_section.dart';
import '../widgets/log_sheet_helpers.dart';
import '../widgets/manual_log_form.dart';
import '../widgets/quick_log_confirm_sheet.dart';
import '../widgets/unified_meal_search_results.dart';
import 'build_meal_screen.dart';
import 'log_scanned_food_screen.dart';

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

/// Opens the full-screen "Log a Meal" experience.
///
/// Quick-log only (2026-07 two-surface split): every tab's item tap opens
/// [showQuickLogConfirmSheet] (servings + time + optional category) and, on
/// confirm, commits ONE terminal `meal_logs` row immediately — there is no
/// in-progress draft/accumulator on this screen anymore. Building a
/// multi-item meal from scratch lives on the separate [BuildMealScreen]
/// (`openBuildMealScreen`), reachable via the "Build a meal" app-bar action.
/// A unified search bar at the top searches foods, recipes, common
/// ingredients, and favorites/recents together.
/// [source] is required rather than defaulted: it used to default to
/// `today_log_section`, so the fuel-timeline entry point silently reported
/// itself as coming from the today-log section and the `diary_opened` source
/// breakdown was wrong. Making callers name themselves keeps that honest.
void openLogMealScreen(
  BuildContext context, {
  required String logDate,
  required String source,
}) {
  Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => LogMealScreen(logDate: logDate, source: source),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tab enum
// ---------------------------------------------------------------------------

enum _LogTab { recent, common, recipes, describe, manual }

extension _LogTabLabel on _LogTab {
  String get label {
    switch (this) {
      case _LogTab.recent:
        return 'Recent';
      case _LogTab.common:
        return 'Common';
      case _LogTab.recipes:
        return 'Recipes';
      case _LogTab.describe:
        return 'Describe';
      case _LogTab.manual:
        return 'Manual';
    }
  }
}

// ---------------------------------------------------------------------------
// LogMealScreen — full-screen "Log a Meal" experience
// ---------------------------------------------------------------------------

/// Full-screen page for QUICK-LOGGING a meal
/// (Recent · Favorites · Common · Recipes · Describe · Manual), plus a
/// unified search bar. Every tap commits a single `meal_logs` row right away
/// (via [showQuickLogConfirmSheet]) — there is no draft/accumulator here.
class LogMealScreen extends ConsumerStatefulWidget {
  const LogMealScreen({
    super.key,
    required this.logDate,
    this.source = 'unknown',
  });

  final String logDate;

  /// Entry-point label for the `log_meal_opened` analytics event.
  final String source;

  @override
  ConsumerState<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends ConsumerState<LogMealScreen> {
  _LogTab _activeTab = _LogTab.recent;

  /// Controller key for the shared [FoodSearchController] instance backing
  /// the unified search bar.
  static const _foodSearchControllerKey = 'meal_log_unified';

  final TextEditingController _searchCtrl = TextEditingController();

  /// Single scroll controller shared by whichever tab body / search-results
  /// list is currently mounted (only one is ever in the tree at a time).
  final ScrollController _scrollController = ScrollController();

  List<Recipe> _recipes = [];
  bool _recipesLoading = false;

  /// Resolved in [initState] — `ref` is not safe to touch from [dispose],
  /// where `diary_closed` fires.
  AnalyticsTracker? _analytics;

  /// Start of the dwell window for `diary_closed`.
  DateTime? _openedAt;

  /// Counts only *successful* quick-logs (see [_afterQuickLog]), so a failed
  /// log doesn't inflate the diary's productivity.
  int _itemsLogged = 0;

  @override
  void initState() {
    super.initState();
    _analytics = ref.read(appExternalDepsProvider).analytics;
    _openedAt = DateTime.now();

    _analytics?.track(
      'log_meal_opened',
      properties: {
        'source': widget.source,
        'log_date': widget.logDate,
        'is_today': _isToday(),
      },
    );

    // `diary_opened` is the funnel-spec name for the same moment. Fired
    // alongside `log_meal_opened` rather than replacing it, so the existing
    // Mixpanel reports built on `log_meal_opened` keep working; it pairs with
    // `diary_closed` to give dwell time.
    _analytics?.track(
      'diary_opened',
      properties: {
        'source': widget.source,
        'log_date': widget.logDate,
        'is_today': _isToday(),
      },
    );

    // The unified search bar is always visible, so seed its data eagerly
    // rather than gating behind a tab selection.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecipes();
      _seedFoodPool();
    });
  }

  bool _isToday() {
    try {
      final date = DateTime.parse(widget.logDate);
      final now = DateTime.now();
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    } catch (_) {
      return false;
    }
  }

  /// Fire the funnel's method-selection step. [method] is the clean method
  /// discriminator (recent/common/recipe/describe/manual/barcode/build).
  void _trackMethodSelected(String method) {
    ref.read(appExternalDepsProvider).analytics.track(
      'log_method_selected',
      properties: {'method': method},
    );
  }

  @override
  void dispose() {
    // Dwell time — how long the athlete actually spent in the diary, and
    // whether they logged anything while there. A high `duration_sec` with
    // `items_logged: 0` is the signal that the diary looked but didn't land.
    final openedAt = _openedAt;
    if (_analytics != null && openedAt != null) {
      try {
        _analytics!.track(
          'diary_closed',
          properties: {
            'duration_sec': DateTime.now().difference(openedAt).inSeconds,
            'items_logged': _itemsLogged,
            'log_date': widget.logDate,
          },
        );
      } catch (_) {}
    }

    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // -- keyboard dismissal ------------------------------------------------

  /// Dismisses the on-screen keyboard. Called whenever a search result or
  /// tab item is tapped/added so the keyboard doesn't linger after the user
  /// has moved on from typing (item 3).
  void _unfocus() {
    if (mounted) FocusScope.of(context).unfocus();
  }

  // -- quick-log helpers -------------------------------------------------

  /// Sums a component list into [ConsumedTotals] for a confirm-sheet preview.
  ConsumedTotals _totalsOf(List<MealComponent> components) {
    return components.fold(const ConsumedTotals(), (acc, c) {
      return ConsumedTotals(
        calories: acc.calories + (c.calories ?? 0),
        carbsG: acc.carbsG + (c.carbG ?? 0),
        proteinG: acc.proteinG + (c.proteinG ?? 0),
        fatG: acc.fatG + (c.fatG ?? 0),
        sodiumMg: acc.sodiumMg + (c.sodiumMg ?? 0),
      );
    });
  }

  /// Scales a single-food [MealComponent] (e.g. a common ingredient) by
  /// [servings].
  MealComponent _scale(MealComponent base, double servings) {
    return MealComponent(
      name: base.name,
      portion: servings == servings.truncateToDouble()
          ? '${servings.toInt()} ${servings == 1 ? 'serving' : 'servings'}'
          : '${servings.toStringAsFixed(1)} servings',
      calories:
          base.calories != null ? (base.calories! * servings).round() : null,
      carbG: base.carbG != null ? base.carbG! * servings : null,
      proteinG: base.proteinG != null ? base.proteinG! * servings : null,
      fatG: base.fatG != null ? base.fatG! * servings : null,
      sodiumMg: base.sodiumMg != null ? base.sodiumMg! * servings : null,
    );
  }

  /// Generic quick-log flow shared by food/ingredient/recent/common-assembly
  /// taps: shows [showQuickLogConfirmSheet], then writes ONE terminal
  /// `meal_logs` row via [MealLogController.logFromComponents]. The row's
  /// name is [deriveMealName] applied to the final component list (a single
  /// component collapses to that item's own name).
  Future<void> _quickLogComponents({
    required String title,
    required List<MealComponent> Function(double servings) buildComponents,
    bool showServingsStepper = true,
    double initialServings = 1.0,
    MealLogSource source = MealLogSource.manual,
    String? logMethod,
  }) async {
    _unfocus();
    final result = await showQuickLogConfirmSheet(
      context,
      title: title,
      showServingsStepper: showServingsStepper,
      initialServings: initialServings,
      previewTotals: (servings) => _totalsOf(buildComponents(servings)),
    );
    if (result == null || !mounted) return;

    final components = buildComponents(result.servings);
    await ref.read(mealLogControllerProvider.notifier).logFromComponents(
          name: deriveMealName(components),
          slot: result.slot,
          logDate: widget.logDate,
          source: source,
          components: components,
          eatenAt: result.eatenAt,
          logMethod: logMethod,
        );
    _afterQuickLog();
  }

  /// Quick-log a recipe at a chosen serving count via
  /// [MealLogController.logRecipe] (which builds its own single component
  /// from [RecipeLogParams] — the recipe stays a single line on this
  /// quick-log surface; only `BuildMealScreen`'s "+ Add food" explodes a
  /// recipe into per-ingredient lines).
  Future<void> _quickLogRecipe(Recipe recipe) async {
    _unfocus();
    final nutrition = recipe.nutrition;
    final result = await showQuickLogConfirmSheet(
      context,
      title: recipe.name,
      previewTotals: (servings) => ConsumedTotals(
        calories: (nutrition.calories * servings).round(),
        carbsG: nutrition.carbohydratesGrams * servings,
        proteinG: nutrition.proteinGrams * servings,
        fatG: nutrition.fatGrams * servings,
        sodiumMg: nutrition.sodiumMilligrams * servings,
      ),
    );
    if (result == null || !mounted) return;

    await ref.read(mealLogControllerProvider.notifier).logRecipe(
          params: RecipeLogParams(
            recipeId: recipe.id,
            recipeName: recipe.name,
            servings: result.servings,
            caloriesPerServing: nutrition.calories,
            carbsGPerServing: nutrition.carbohydratesGrams,
            proteinGPerServing: nutrition.proteinGrams,
            fatGPerServing: nutrition.fatGrams,
            sodiumMgPerServing: nutrition.sodiumMilligrams,
          ),
          slot: result.slot,
          logDate: widget.logDate,
          eatenAt: result.eatenAt,
        );
    _afterQuickLog();
  }

  /// Quick-log (re-log) a saved favorite — no servings stepper (a saved meal
  /// is an arbitrary multi-food combo with no single per-serving scale).
  Future<void> _quickLogSavedMeal(SavedMeal meal) async {
    _unfocus();
    final result = await showQuickLogConfirmSheet(
      context,
      title: meal.name,
      showServingsStepper: false,
      previewTotals: (_) => ConsumedTotals(
        calories: meal.calories ?? 0,
        carbsG: meal.carbsG ?? 0,
        proteinG: meal.proteinG ?? 0,
        fatG: meal.fatG ?? 0,
        sodiumMg: meal.sodiumMg ?? 0,
      ),
    );
    if (result == null || !mounted) return;

    await ref.read(mealLogControllerProvider.notifier).logSavedMeal(
          savedMeal: meal,
          slot: result.slot,
          logDate: widget.logDate,
          eatenAt: result.eatenAt,
        );
    _afterQuickLog();
  }

  /// After a successful quick-log: keyboard stays dismissed, show a success
  /// snackbar, and DO NOT re-focus the search field or the screen stays put
  /// so the user can log another item (matches the pre-redesign UX — the
  /// reported bug was the keyboard/cursor bouncing back, not the screen
  /// staying open).
  void _afterQuickLog() {
    _unfocus();
    if (!mounted) return;
    final state = ref.read(mealLogControllerProvider);
    if (state is AsyncData) {
      // Counted here, in the success branch only — `items_logged` on
      // `diary_closed` should reflect what actually landed, not what was
      // attempted.
      _itemsLogged++;
      MealvanaSnackbar.showSuccess(context, 'Meal logged!');
    } else if (state is AsyncError) {
      MealvanaSnackbar.showError(
        context,
        'Failed to log meal. Please try again.',
      );
    }
  }

  // -- recipes loading (shared by Recipes tab + unified search) --------------

  Future<void> _loadRecipes() async {
    if (!mounted || _recipesLoading) return;
    setState(() => _recipesLoading = true);
    try {
      final service = ref.read(recipeServiceProvider);
      final userId = ref
          .read(appExternalDepsProvider)
          .supabaseClient
          .auth
          .currentUser
          ?.id;
      if (userId != null) {
        await service.ensureSynced(userId);
      }
      final all = await service.getAllRecipes();
      if (!mounted) return;
      setState(() {
        _recipes = all;
        _recipesLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _recipesLoading = false);
    }
  }

  // -- Food search (unified search bar) --------------------------------------

  /// Seed the shared [FoodSearchController]'s local pool with curated + user
  /// foods so typed queries surface instant local matches alongside the
  /// debounced catalog/OpenFoodFacts results. Best-effort.
  Future<void> _seedFoodPool() async {
    try {
      final foodRepository = ref.read(foodRepositoryProvider);
      final database = ref.read(appDatabaseProvider);
      final userProfile = await database.userDao.getCurrentUserProfile();
      final deviceId = userProfile?.id ?? 'unknown';

      final results = await Future.wait([
        foodRepository.getPrimaryFoodsForPreferences(),
        foodRepository.getAdditionalFoodsForPreferences(),
        database.foodsDao.getUserFoods(deviceId),
      ]);

      final primary = (results[0] as List<FoodItem>).map(_foodItemToFood);
      final additional = (results[1] as List<FoodItem>).map(_foodItemToFood);
      final userFoods = (results[2] as List<dynamic>)
          .map((uf) => database.foodsDao.convertUserFoodToFoodItem(uf))
          .map(_foodItemToFood)
          .toList();

      if (!mounted) return;
      final searchNotifier = ref.read(
        foodSearchControllerProvider(_foodSearchControllerKey).notifier,
      );
      // Meal logging shows all foods but surfaces general food ahead of pure
      // fuel — someone logging breakfast shouldn't wade through gels first.
      searchNotifier.setFilter(FoodSearchFilter.generalFirst);
      searchNotifier.updateFoodPool(
        allFoods: [...primary, ...additional, ...userFoods],
        userFoods: userFoods,
      );
    } catch (_) {
      // Non-fatal — search bar still works via catalog + OpenFoodFacts.
    }
  }

  Food _foodItemToFood(FoodItem item) {
    return Food(
      id: item.id,
      name: item.name,
      imageAddress: item.imageAddress,
      description: item.description,
      displayName: item.displayName,
      displayNamePlural: item.displayNamePlural,
      servingSize: item.servingSize,
      servingAmount: item.servingAmount,
      servingUnit: item.servingUnit,
      servingQualifier: item.servingQualifier,
      carbsPerServing: item.carbsPerServing,
      proteinPerServing: item.proteinPerServing,
      fatPerServing: item.fatPerServing,
      sodiumMg: item.sodiumMg,
      caloriesPerServing: item.caloriesPerServing,
      fluidMlPerServing: item.fluidMlPerServing,
      productTypeId: item.productTypeId,
      caffeineMg: item.caffeineMg,
      potassiumMg: item.potassiumMg,
      categories: item.categories.map((c) {
        switch (c) {
          case FoodCategory.beforeRun:
            return 'before_run';
          case FoodCategory.duringRun:
            return 'during_run';
          case FoodCategory.afterRun:
            return 'after_run';
        }
      }).toList(),
    );
  }

  Food _catalogResultToFood(CatalogSearchResult result) {
    return Food(
      id: result.id,
      name: result.title,
      displayName: result.displayName,
      imageAddress: result.imageUrl,
      servingSize: result.servingSize,
      caloriesPerServing: result.caloriesPerServing,
      carbsPerServing: result.carbsG,
      proteinPerServing: result.proteinG,
      fatPerServing: result.fatG,
      sodiumMg: result.sodiumMg,
      productTypeId: result.productTypeId,
    );
  }

  void _onSearchChanged(String query) {
    ref
        .read(foodSearchControllerProvider(_foodSearchControllerKey).notifier)
        .updateSearch(query);
  }

  /// Clear the search field + query so switching to a browse tab (Recent,
  /// Describe, Manual, …) shows that tab's content instead of leaving stale
  /// search results (or an empty "no results") covering it.
  void _clearSearch() {
    _searchCtrl.clear();
    ref
        .read(foodSearchControllerProvider(_foodSearchControllerKey).notifier)
        .updateSearch('');
  }

  Future<void> _onBarcodeScan() async {
    _unfocus();
    _trackMethodSelected('barcode');
    final result = await context.pushNamed<dynamic>(
      'barcode-scanner',
      extra: {'category': 'add_food', 'context': 'meal_log_discover'},
    );
    if (result == null || !mounted) return;

    final food = result as Food;
    // LogScannedFoodScreen already collects its own servings + (required)
    // slot — reuse that sub-flow, then quick-log directly instead of
    // routing through the servings/time confirm sheet a second time.
    final logRequest = await Navigator.of(context).push<ScannedFoodLogRequest>(
      MaterialPageRoute(builder: (_) => LogScannedFoodScreen(food: food)),
    );
    if (logRequest == null || !mounted) return;

    final components = [_foodComponent(food, logRequest.servings)];
    await ref.read(mealLogControllerProvider.notifier).logFromComponents(
          name: deriveMealName(components),
          slot: logRequest.slot,
          logDate: widget.logDate,
          source: MealLogSource.manual,
          components: components,
          eatenAt: DateTime.now(),
          logMethod: 'barcode',
        );
    _afterQuickLog();
  }

  /// A `nutrition_products` (USDA / cached Open Food Facts) result.
  ///
  /// Same flow as [_handleOpenFoodFactsResultTap], but these rows are keyed by
  /// barcode rather than an Open Food Facts id, so the detail lookup differs.
  Future<void> _handleNutritionProductTap(
    NutritionProductSearchResult result,
  ) async {
    if (!result.hasValidId) {
      MealvanaSnackbar.showError(context, 'Cannot load details for this product');
      return;
    }

    _unfocus();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final productDetailService = ref.read(productDetailServiceProvider);
      final apiProduct = await productDetailService.getProductDetails(
        barcode: result.id,
      );

      if (mounted) Navigator.of(context).pop(); // close loading dialog

      if (apiProduct == null) {
        if (mounted) {
          MealvanaSnackbar.showError(context, 'Unable to load product details');
        }
        return;
      }

      final mappingService = ref.read(foodMappingServiceProvider);
      final food = await mappingService.mapToFood(apiProduct);
      if (!mounted) return;

      _quickLogComponents(
        title: food.displayName ?? food.name,
        buildComponents: (servings) => [_foodComponent(food, servings)],
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // close loading dialog
        MealvanaSnackbar.showError(context, 'Unable to load product details');
      }
    }
  }

  Future<void> _handleOpenFoodFactsResultTap(dynamic result) async {
    if (!(result.hasValidId as bool)) {
      MealvanaSnackbar.showError(context, 'Cannot load details for this product');
      return;
    }

    _unfocus();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final productDetailService = ref.read(productDetailServiceProvider);
      final apiProduct = await productDetailService.getProductDetails(
        openFoodFactsId: result.id as String,
      );

      if (mounted) Navigator.of(context).pop(); // close loading dialog

      if (apiProduct == null) {
        if (mounted) {
          MealvanaSnackbar.showError(context, 'Unable to load product details');
        }
        return;
      }

      final mappingService = ref.read(foodMappingServiceProvider);
      final food = await mappingService.mapToFood(apiProduct);

      if (!mounted) return;
      _onFoodTap(food);
    } catch (_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (mounted) {
        MealvanaSnackbar.showError(context, 'Failed to load product details');
      }
    }
  }

  MealComponent _foodComponent(Food food, double servings) {
    final name = food.displayName ?? food.name;
    return MealComponent(
      name: name,
      portion: servings == servings.truncateToDouble()
          ? '${servings.toInt()} ${servings == 1 ? 'serving' : 'servings'}'
          : '${servings.toStringAsFixed(1)} servings',
      calories: food.caloriesPerServing != null
          ? (food.caloriesPerServing! * servings).round()
          : null,
      carbG: food.carbsPerServing != null ? food.carbsPerServing! * servings : null,
      proteinG:
          food.proteinPerServing != null ? food.proteinPerServing! * servings : null,
      fatG: food.fatPerServing != null ? food.fatPerServing! * servings : null,
      sodiumMg: food.sodiumMg != null ? food.sodiumMg! * servings : null,
    );
  }

  void _onFoodTap(Food food) {
    _quickLogComponents(
      title: food.displayName ?? food.name,
      buildComponents: (servings) => [_foodComponent(food, servings)],
      logMethod: 'common',
    );
  }

  void _onCatalogTap(CatalogSearchResult result) {
    _onFoodTap(_catalogResultToFood(result));
  }

  void _onRecipeTap(Recipe recipe) {
    _quickLogRecipe(recipe);
  }

  // --------------------------------------------------------------------------

  String _screenTitle() {
    try {
      final date = DateTime.parse(widget.logDate);
      final today = DateTime.now();
      final isToday =
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      return isToday
          ? 'Log a Meal'
          : 'Log — ${DateFormat('MMM d').format(date)}';
    } catch (_) {
      return 'Log a Meal';
    }
  }

  /// Re-log a recent meal (single synthetic component reconstructed from the
  /// past log's totals) — quick-log with a servings stepper, matching the
  /// food/ingredient tap pattern. Mirrors the `.saved` source convention
  /// already used by [RecentSavedPickerScreen] for re-logged history items.
  void _onRecentTap(MealLog log) {
    final base = syntheticFromLog(log);
    _quickLogComponents(
      title: log.name,
      buildComponents: (servings) => [_scale(base, servings)],
      source: MealLogSource.saved,
    );
  }

  Future<void> _openBuildMealScreen() async {
    _unfocus();
    _trackMethodSelected('build');
    openBuildMealScreen(context, logDate: widget.logDate);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.blackberry : AppColors.cream;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final searchState = ref.watch(
      foodSearchControllerProvider(_foodSearchControllerKey),
    );
    final isSearching = searchState.searchQuery.isNotEmpty;

    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const CustomAppBarBackButton(
          key: ValueKey('log_meal.back_button'),
        ),
        title: Text(
          _screenTitle(),
          style: AppTextStyles.sectionTitle.copyWith(color: textColor),
        ),
        actions: [
          TextButton.icon(
            key: const ValueKey('log_meal.build_a_meal_button'),
            onPressed: _openBuildMealScreen,
            icon: Icon(Icons.restaurant_menu, size: 18, color: textColor),
            label: Text(
              'Build a meal',
              style: AppTextStyles.bodySmall.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Static header (search + tabs) ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: Column(
              children: [
                // Unified search bar — searches foods, recipes, common
                // ingredients, and favorites/recents together. USDA/Open
                // Food Facts already auto-fire on the catalog debounce
                // (search-nutrition-products), so the keyboard checkmark
                // just dismisses the keyboard rather than re-triggering a
                // search — that re-trigger was the reported keyboard-bounce
                // bug.
                FoodSearchBar(
                  controller: _searchCtrl,
                  hintText: 'Search anything to add...',
                  onChanged: _onSearchChanged,
                  onSearch: (_) => _unfocus(),
                  onBarcodeScan: _onBarcodeScan,
                  onTapOutside: (_) => _unfocus(),
                ),
                const SizedBox(height: AppSpacing.sm),
                _TabBar(
                  activeTab: _activeTab,
                  onTabSelected: (tab) {
                    _unfocus();
                    // Clear any in-progress search so the chosen tab actually
                    // shows (search results otherwise stay layered over it).
                    _clearSearch();
                    if (tab != _activeTab) {
                      _trackMethodSelected(
                        tab == _LogTab.recipes ? 'recipe' : tab.name,
                      );
                    }
                    setState(() => _activeTab = tab);
                  },
                  isDark: isDark,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
          // ── Scrollable content: search results or the active tab ────────
          Expanded(
            child: isSearching
                ? UnifiedMealSearchResults(
                    query: searchState.searchQuery,
                    recipes: _recipes,
                    controllerKey: _foodSearchControllerKey,
                    scrollController: _scrollController,
                    onAddRecipe: _onRecipeTap,
                    onAddFavorite: _quickLogSavedMeal,
                    onAddRecent: _onRecentTap,
                    onAddIngredient: (ingredient) => _quickLogComponents(
                      title: ingredient.name,
                      buildComponents: (servings) => [_scale(ingredient, servings)],
                    ),
                    onFoodTap: _onFoodTap,
                    onCatalogTap: _onCatalogTap,
                    onOpenFoodFactsResultTap: _handleOpenFoodFactsResultTap,
                    // USDA + cached Open Food Facts. Without this the shared
                    // widget hides the whole "More Results" block and the
                    // controller's already-fetched results are thrown away —
                    // the user got "No foods found" for a food we hold.
                    onNutritionProductResultTap: _handleNutritionProductTap,
                    // No manual OFF search trigger — the results above already
                    // include USDA + cached OFF automatically.
                    onSearchOpenFoodFacts: () {},
                    showOpenFoodFactsButton: false,
                  )
                : _buildTabBody(context, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBody(BuildContext context, bool isDark) {
    switch (_activeTab) {
      case _LogTab.recent:
        return _RecentAndSavedTab(
          scrollController: _scrollController,
          onRecentTap: _onRecentTap,
          onSavedTap: _quickLogSavedMeal,
        );
      case _LogTab.common:
        return CommonIngredientsSection(
          scrollController: _scrollController,
          onTapAssembly: (assembly) => _quickLogComponents(
            title: assembly.name,
            buildComponents: (_) => assembly.components,
            showServingsStepper: false,
          ),
          onTapIngredient: (ingredient) => _quickLogComponents(
            title: ingredient.name,
            buildComponents: (servings) => [_scale(ingredient, servings)],
          ),
        );
      case _LogTab.recipes:
        return _RecipesTab(
          scrollController: _scrollController,
          recipes: _recipes,
          isLoading: _recipesLoading,
          onRecipeTap: _onRecipeTap,
        );
      case _LogTab.describe:
        return _AiTab(
          logDate: widget.logDate,
          scrollController: _scrollController,
          onNavigateAway: () => Navigator.of(context).pop(),
        );
      case _LogTab.manual:
        return ManualLogForm(
          logDate: widget.logDate,
          scrollController: _scrollController,
          onLogged: () {
            _unfocus();
            if (mounted) MealvanaSnackbar.showSuccess(context, 'Meal logged!');
          },
          onLogError: () => MealvanaSnackbar.showError(
            context,
            'Failed to log meal. Please try again.',
          ),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Tab bar
// ---------------------------------------------------------------------------

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.activeTab,
    required this.onTabSelected,
    required this.isDark,
  });

  final _LogTab activeTab;
  final ValueChanged<_LogTab> onTabSelected;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: _LogTab.values.map((tab) {
          final isSelected = tab == activeTab;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTabSelected(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppColors.cream : AppColors.blackberry)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        tab.label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? (isDark
                                    ? AppColors.blackberry
                                    : AppColors.cream)
                              : (isDark
                                    ? AppColors.cream.withValues(alpha: 0.7)
                                    : AppColors.blackberry.withValues(
                                        alpha: 0.6,
                                      )),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent tab — add a recently logged meal to the draft
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Combined Recent + Saved ("My Meals") tab — quick-log a past meal or a saved
// favorite. Saved meals are listed first (curated), then recent history.
// ---------------------------------------------------------------------------

class _RecentAndSavedTab extends ConsumerWidget {
  const _RecentAndSavedTab({
    required this.scrollController,
    required this.onRecentTap,
    required this.onSavedTap,
  });

  final ScrollController scrollController;
  final ValueChanged<MealLog> onRecentTap;
  final ValueChanged<SavedMeal> onSavedTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentMealsProvider);
    final favoritesAsync = ref.watch(savedMealsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    final saved = favoritesAsync.value ?? const <SavedMeal>[];
    final recent = recentAsync.value ?? const <MealLog>[];

    if (saved.isEmpty && recent.isEmpty) {
      if (recentAsync.isLoading || favoritesAsync.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return _EmptyTabMessage(
        icon: Icons.history,
        message:
            'No saved or recent meals yet.\nMeals you log (and favorite) show up here.',
        textColor: textColor,
      );
    }

    return ListView(
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      children: [
        if (saved.isNotEmpty) ...[
          _TabSectionHeader(label: 'Saved meals', textColor: textColor),
          ...saved.map(
            (meal) => _SavedMealRow(
              meal: meal,
              onTap: () => onSavedTap(meal),
              onDelete: () => ref
                  .read(mealLogControllerProvider.notifier)
                  .deleteSavedMeal(meal.id),
              isDark: isDark,
            ),
          ),
        ],
        if (recent.isNotEmpty) ...[
          if (saved.isNotEmpty) const SizedBox(height: AppSpacing.md),
          _TabSectionHeader(label: 'Recent', textColor: textColor),
          ...recent.map(
            (log) => _RecentMealRow(
              log: log,
              onTap: () => onRecentTap(log),
              isDark: isDark,
            ),
          ),
        ],
      ],
    );
  }
}

/// Small section label used inside the combined Recent/Saved tab.
class _TabSectionHeader extends StatelessWidget {
  const _TabSectionHeader({required this.label, required this.textColor});

  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: textColor.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// Centered icon + message shown when a tab has no items to list.
class _EmptyTabMessage extends StatelessWidget {
  const _EmptyTabMessage({
    required this.icon,
    required this.message,
    required this.textColor,
  });

  final IconData icon;
  final String message;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: textColor.withValues(alpha: 0.3)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: textColor.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedMealRow extends StatelessWidget {
  const _SavedMealRow({
    required this.meal,
    required this.onTap,
    required this.onDelete,
    required this.isDark,
  });

  final SavedMeal meal;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          child: const Icon(Icons.star_outline, size: 16),
        ),
        title: Text(
          meal.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: _macroLine(
          context,
          meal.calories,
          meal.carbsG,
          meal.proteinG,
          meal.fatG,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: onDelete,
              child: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.add_circle_outline, size: 18),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _RecentMealRow extends StatelessWidget {
  const _RecentMealRow({
    required this.log,
    required this.onTap,
    required this.isDark,
  });

  final MealLog log;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          child: const Icon(Icons.history, size: 16),
        ),
        title: Text(
          log.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: _macroLine(
          context,
          log.calories,
          log.carbsG,
          log.proteinG,
          log.fatG,
        ),
        trailing: const Icon(Icons.add_circle_outline, size: 18),
        onTap: onTap,
      ),
    );
  }
}

/// Compact macro subtitle — null means ListTile omits the line.
Widget? _macroLine(
  BuildContext context,
  int? cal,
  double? carb,
  double? prot,
  double? fat,
) {
  final parts = [
    if (cal != null) '$cal kcal',
    if (carb != null) 'C ${carb.toStringAsFixed(0)}g',
    if (prot != null) 'P ${prot.toStringAsFixed(0)}g',
    if (fat != null) 'F ${fat.toStringAsFixed(0)}g',
  ];
  if (parts.isEmpty) return null;
  return Text(
    parts.join('  ·  '),
    maxLines: 1,
    style: Theme.of(context).textTheme.bodySmall,
    overflow: TextOverflow.ellipsis,
  );
}

// ---------------------------------------------------------------------------
// Recipes tab — pure recipe browser (quick-add assemblies moved to Common)
// ---------------------------------------------------------------------------

class _RecipesTab extends StatefulWidget {
  const _RecipesTab({
    required this.scrollController,
    required this.recipes,
    required this.isLoading,
    required this.onRecipeTap,
  });

  final ScrollController scrollController;
  final List<Recipe> recipes;
  final bool isLoading;
  final ValueChanged<Recipe> onRecipeTap;

  @override
  State<_RecipesTab> createState() => _RecipesTabState();
}

class _RecipesTabState extends State<_RecipesTab> {
  RecipeType? _selectedType;

  static const List<RecipeType> _chipOrder = [
    RecipeType.breakfast,
    RecipeType.mains,
    RecipeType.snacks,
    RecipeType.workoutFuel,
    RecipeType.recovery,
  ];

  List<Recipe> get _filtered {
    final type = _selectedType;
    return type == null
        ? widget.recipes
        : widget.recipes.where((r) => r.type == type).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.isLoading && widget.recipes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 2,
            ),
            children: [
              _TypeChip(
                label: 'All',
                selected: _selectedType == null,
                onTap: () => setState(() => _selectedType = null),
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              ..._chipOrder.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _TypeChip(
                    label: t.displayLabel,
                    selected: _selectedType == t,
                    onTap: () => setState(() => _selectedType = t),
                    isDark: isDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Text(
                    'No recipes found.',
                    style: AppTextStyles.bodyMedium,
                  ),
                )
              : ListView(
                  controller: widget.scrollController,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  children: _filtered.map((recipe) {
                    final cal = recipe.nutrition.calories.round();
                    final carb =
                        recipe.nutrition.carbohydratesGrams.toStringAsFixed(0);
                    final prot =
                        recipe.nutrition.proteinGrams.toStringAsFixed(0);
                    final fat = recipe.nutrition.fatGrams.toStringAsFixed(0);

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      child: ListTile(
                        dense: true,
                        leading: _RecipeThumbnail(
                          imageUrl: recipe.imageUrl,
                          type: recipe.type,
                          size: 40,
                        ),
                        title: Text(
                          recipe.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '$cal kcal  ·  C ${carb}g  P ${prot}g  F ${fat}g',
                          maxLines: 1,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.add_circle_outline, size: 18),
                        onTap: () => widget.onRecipeTap(recipe),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

/// Compact recipe thumbnail (40 px) with category color fallback.
class _RecipeThumbnail extends StatelessWidget {
  const _RecipeThumbnail({
    required this.imageUrl,
    required this.type,
    this.size = 40,
  });

  final String? imageUrl;
  final RecipeType type;
  final double size;

  Color _color() {
    switch (type) {
      case RecipeType.breakfast:
        return Colors.orange.shade300;
      case RecipeType.mains:
        return Colors.teal.shade300;
      case RecipeType.snacks:
        return Colors.amber.shade300;
      case RecipeType.workoutFuel:
        return Colors.blue.shade300;
      case RecipeType.recovery:
        return Colors.purple.shade300;
    }
  }

  IconData _icon() {
    switch (type) {
      case RecipeType.breakfast:
        return Icons.free_breakfast;
      case RecipeType.mains:
        return Icons.restaurant;
      case RecipeType.snacks:
        return Icons.cookie;
      case RecipeType.workoutFuel:
        return Icons.directions_run;
      case RecipeType.recovery:
        return Icons.restore;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(_icon(), color: color, size: size * 0.5),
    );
    if (imageUrl == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (_, child, p) {
          if (p == null) return child;
          return Container(
            width: size,
            height: size,
            color: color.withValues(alpha: 0.15),
          );
        },
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.electrolyte
              : (isDark
                    ? Colors.white12
                    : Colors.black.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected
                ? AppColors.blackberry
                : (isDark ? Colors.white : AppColors.blackberry),
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AI tab — unchanged terminal flow (photo/describe review screen owns its
// own name/slot/items confirmation).
// ---------------------------------------------------------------------------

class _AiTab extends ConsumerStatefulWidget {
  const _AiTab({
    required this.logDate,
    required this.scrollController,
    required this.onNavigateAway,
  });

  final String logDate;
  final ScrollController scrollController;
  final VoidCallback onNavigateAway;

  @override
  ConsumerState<_AiTab> createState() => _AiTabState();
}

class _AiTabState extends ConsumerState<_AiTab> {
  final _formKey = GlobalKey<FormState>();
  final _ctrl = TextEditingController();
  bool _isAnalyzing = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    // Captured before the async gap so it stays valid if the widget unmounts.
    final analytics = ref.read(appExternalDepsProvider).analytics;
    // 'text' keeps the typed-describe funnel distinct from the photo funnels.
    analytics.track('meal_ai_started', properties: {'method': 'text'});
    setState(() => _isAnalyzing = true);
    try {
      final service = ref.read(mealAiServiceProvider);
      final result = await service.describeMeal(_ctrl.text.trim());
      analytics.track('meal_ai_completed', properties: {'method': 'text'});
      if (!mounted) return;
      // Capture router before closing the screen.
      final router = GoRouter.of(context);
      widget.onNavigateAway();
      router.push(
        '/meal-log/review',
        extra: {
          'result': result,
          'source': 'describe',
          'logDate': widget.logDate,
          'photoPath': null,
        },
      );
    } on MealAiException catch (e) {
      analytics.track('meal_ai_failed',
          properties: {'method': 'text', 'error_type': 'ai_exception'});
      if (mounted) MealvanaSnackbar.showError(context, e.userMessage);
    } catch (_) {
      analytics.track('meal_ai_failed',
          properties: {'method': 'text', 'error_type': 'unknown'});
      if (mounted) {
        MealvanaSnackbar.showError(
          context,
          'Something went wrong. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    XFile? file;
    try {
      file = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
    } catch (_) {
      if (mounted) {
        MealvanaSnackbar.showError(
          context,
          'Could not access the camera or gallery.',
        );
      }
      return;
    }
    if (file == null || !mounted) return;

    // Distinguish camera vs gallery so the two photo funnels stay separate
    // from each other and from the typed-describe funnel.
    final method =
        source == ImageSource.camera ? 'photo_camera' : 'photo_gallery';
    final analytics = ref.read(appExternalDepsProvider).analytics;
    analytics.track('meal_ai_started', properties: {'method': method});
    setState(() => _isAnalyzing = true);
    try {
      final service = ref.read(mealAiServiceProvider);
      MealPhotoAnalysis analysis;
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        final parts = file.name.split('.');
        final ext = (parts.length > 1 ? parts.last : 'jpg').toLowerCase();
        analysis = await service.analyzePhotoBytes(bytes, extension: ext);
      } else {
        analysis = await service.analyzePhoto(File(file.path));
      }
      analytics.track('meal_ai_completed', properties: {'method': method});
      if (!mounted) return;
      // Capture router before closing the screen.
      final router = GoRouter.of(context);
      widget.onNavigateAway();
      router.push(
        '/meal-log/review',
        extra: {
          'result': analysis.result,
          'source': 'photo',
          'logDate': widget.logDate,
          'photoPath': analysis.storagePath,
        },
      );
    } on MealAiException catch (e) {
      analytics.track('meal_ai_failed',
          properties: {'method': method, 'error_type': 'ai_exception'});
      if (mounted) MealvanaSnackbar.showError(context, e.userMessage);
    } catch (_) {
      analytics.track('meal_ai_failed',
          properties: {'method': method, 'error_type': 'unknown'});
      if (mounted) {
        MealvanaSnackbar.showError(
          context,
          'Something went wrong. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return Stack(
      children: [
        ListView(
          controller: widget.scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          children: [
            Text(
              'Describe what you ate and Jade will estimate the macros.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: textColor.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _ctrl,
                maxLines: 4,
                minLines: 3,
                textCapitalization: TextCapitalization.sentences,
                enabled: !_isAnalyzing,
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                decoration: const InputDecoration(
                  labelText: 'What did you eat?',
                  hintText:
                      'e.g. Oatmeal with blueberries, a tablespoon of honey, large coffee with oat milk.',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().length < 5)
                    ? 'Please describe your meal'
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            KylePrimaryButton(
              text: 'Analyze',
              isLoading: _isAnalyzing,
              onPressed: _isAnalyzing ? null : _analyze,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!kIsWeb)
              Row(
                children: [
                  Expanded(
                    child: _OutlineButton(
                      label: 'Camera',
                      icon: Icons.photo_camera_outlined,
                      onTap: _isAnalyzing
                          ? null
                          : () => _pickPhoto(ImageSource.camera),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _OutlineButton(
                      label: 'Gallery',
                      icon: Icons.photo_library_outlined,
                      onTap: _isAnalyzing
                          ? null
                          : () => _pickPhoto(ImageSource.gallery),
                      isDark: isDark,
                    ),
                  ),
                ],
              )
            else
              _OutlineButton(
                label: 'Choose Photo',
                icon: Icons.photo_library_outlined,
                onTap: _isAnalyzing
                    ? null
                    : () => _pickPhoto(ImageSource.gallery),
                isDark: isDark,
              ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
        if (_isAnalyzing)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Jade is thinking...',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Side-by-side outline button for Camera / Gallery.
class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.black12,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: isDark ? AppColors.cream : AppColors.blackberry,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.cream : AppColors.blackberry,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
