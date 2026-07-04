import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../shared/controllers/food_search_controller.dart';
import '../../../../shared/database/database_provider.dart';
import '../../../../shared/services/app_external_deps.dart';
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
import '../../domain/saved_meal.dart';
import '../providers/draft_meal_controller.dart';
import '../providers/meal_log_providers.dart';
import '../widgets/common_ingredients_section.dart';
import '../widgets/draft_meal_bar.dart';
import '../widgets/log_sheet_helpers.dart';
import '../widgets/manual_component_form.dart';
import '../widgets/unified_meal_search_results.dart';
import 'log_scanned_food_screen.dart';

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

/// Opens the full-screen "Log a Meal" experience.
///
/// Build-a-meal redesign: every tab's item tap adds to an in-progress draft
/// ([draftMealControllerProvider], scoped to [logDate]) rather than writing a
/// terminal `meal_logs` row per tap. A persistent [DraftMealBar] pinned to the
/// bottom of the screen shows running totals and commits the whole draft as a
/// single log entry via "Save meal". A unified search bar at the top searches
/// foods, recipes, common ingredients, and favorites/recents together.
void openLogMealScreen(BuildContext context, {required String logDate}) {
  Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => LogMealScreen(logDate: logDate)),
  );
}

// ---------------------------------------------------------------------------
// Tab enum
// ---------------------------------------------------------------------------

enum _LogTab { recent, favorites, common, recipes, describe, manual }

extension _LogTabLabel on _LogTab {
  String get label {
    switch (this) {
      case _LogTab.recent:
        return 'Recent';
      case _LogTab.favorites:
        return 'Favorites';
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

/// Full-screen page for logging a meal
/// (Recent · Favorites · Common · Recipes · Describe · Manual), plus a
/// unified search bar and a persistent build-a-meal draft bar pinned to the
/// bottom of the screen.
class LogMealScreen extends ConsumerStatefulWidget {
  const LogMealScreen({super.key, required this.logDate});

  final String logDate;

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

  @override
  void initState() {
    super.initState();
    // The unified search bar is always visible, so seed its data eagerly
    // rather than gating behind a tab selection.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecipes();
      _seedFoodPool();
    });
  }

  @override
  void dispose() {
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

  // -- draft accumulator helpers ---------------------------------------------

  DraftMealController get _draft =>
      ref.read(draftMealControllerProvider(widget.logDate).notifier);

  void _addComponent(MealComponent component, {String? toastLabel}) {
    _unfocus();
    _draft.addComponent(component);
    if (mounted) {
      MealvanaSnackbar.showSuccess(
        context,
        'Added ${toastLabel ?? component.name}',
      );
    }
  }

  void _addComponents(Iterable<MealComponent> components, String toastLabel) {
    _unfocus();
    _draft.addComponents(components);
    if (mounted) MealvanaSnackbar.showSuccess(context, 'Added $toastLabel');
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
      displayName: result.variantTitle ?? result.title,
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

  Future<void> _onSearchButtonPressed(String query) async {
    if (query.trim().isNotEmpty) {
      await ref
          .read(foodSearchControllerProvider(_foodSearchControllerKey).notifier)
          .searchOpenFoodFacts(query.trim());
    }
  }

  Future<void> _onBarcodeScan() async {
    _unfocus();
    final result = await context.pushNamed<dynamic>(
      'barcode-scanner',
      extra: {'category': 'add_food', 'context': 'meal_log_discover'},
    );
    if (result == null || !mounted) return;

    final food = result as Food;
    final logRequest = await Navigator.of(context).push<ScannedFoodLogRequest>(
      MaterialPageRoute(builder: (_) => LogScannedFoodScreen(food: food)),
    );
    if (logRequest == null || !mounted) return;

    // The scanned-food screen still asks for a meal slot (unchanged legacy
    // UI) — honor it as the draft's slot only if the draft hasn't already
    // been given one, since slot now applies to the whole draft, not a
    // single component.
    final currentSlot = ref.read(
      draftMealControllerProvider(widget.logDate),
    ).slot;
    if (currentSlot == null) _draft.setSlot(logRequest.slot);
    _addFoodComponent(food, logRequest.servings);
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
      _showServingsSheet(
        title: food.displayName ?? food.name,
        component: (servings) => _foodComponent(food, servings),
        onConfirm: (servings) => _addFoodComponent(food, servings),
      );
    } catch (_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (mounted) {
        MealvanaSnackbar.showError(context, 'Failed to load product details');
      }
    }
  }

  // -- servings-only "add to meal" sheet (no per-item slot) -----------------

  /// Shows a servings stepper sheet for [title], previewing macros via
  /// [component] at the current servings value, and calling [onConfirm] with
  /// the chosen servings when the user taps "Add to meal".
  void _showServingsSheet({
    required String title,
    required MealComponent Function(double servings) component,
    required void Function(double servings) onConfirm,
  }) {
    double servings = 1.0;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final preview = component(servings);

          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.blackberry : AppColors.cream,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.md,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(title, style: AppTextStyles.subtitle, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${preview.calories ?? 0} kcal  ·  '
                    'C ${preview.carbG?.toStringAsFixed(0) ?? 0}g  '
                    'P ${preview.proteinG?.toStringAsFixed(0) ?? 0}g  '
                    'F ${preview.fatG?.toStringAsFixed(0) ?? 0}g',
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Servings', style: Theme.of(ctx).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: servings > 0.5
                            ? () => setModalState(
                                () => servings = (servings - 0.5).clamp(0.5, 10.0),
                              )
                            : null,
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          servings == servings.truncateToDouble()
                              ? servings.toInt().toString()
                              : servings.toStringAsFixed(1),
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 22,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: servings < 10
                            ? () => setModalState(
                                () => servings = (servings + 0.5).clamp(0.5, 10.0),
                              )
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  KylePrimaryButton(
                    text: 'Add to meal',
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onConfirm(servings);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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

  void _addFoodComponent(Food food, double servings) {
    _addComponent(_foodComponent(food, servings));
  }

  void _onFoodTap(Food food) {
    _unfocus();
    _showServingsSheet(
      title: food.displayName ?? food.name,
      component: (servings) => _foodComponent(food, servings),
      onConfirm: (servings) => _addFoodComponent(food, servings),
    );
  }

  void _onCatalogTap(CatalogSearchResult result) {
    _onFoodTap(_catalogResultToFood(result));
  }

  MealComponent _recipeComponent(Recipe recipe, double servings) {
    return MealComponent(
      name: recipe.name,
      portion: servings == servings.truncateToDouble()
          ? '${servings.toInt()} ${servings == 1 ? 'serving' : 'servings'}'
          : '${servings.toStringAsFixed(1)} servings',
      calories: (recipe.nutrition.calories * servings).round(),
      carbG: recipe.nutrition.carbohydratesGrams * servings,
      proteinG: recipe.nutrition.proteinGrams * servings,
      fatG: recipe.nutrition.fatGrams * servings,
      sodiumMg: recipe.nutrition.sodiumMilligrams * servings,
    );
  }

  void _onRecipeTap(Recipe recipe) {
    _unfocus();
    _showServingsSheet(
      title: recipe.name,
      component: (servings) => _recipeComponent(recipe, servings),
      onConfirm: (servings) =>
          _addComponent(_recipeComponent(recipe, servings), toastLabel: recipe.name),
    );
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
                // ingredients, and favorites/recents together.
                FoodSearchBar(
                  controller: _searchCtrl,
                  hintText: 'Search anything to add...',
                  onChanged: _onSearchChanged,
                  onSearch: _onSearchButtonPressed,
                  onBarcodeScan: _onBarcodeScan,
                  onTapOutside: (_) => _unfocus(),
                ),
                const SizedBox(height: AppSpacing.sm),
                _TabBar(
                  activeTab: _activeTab,
                  onTabSelected: (tab) {
                    _unfocus();
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
                    onAddFavorite: (meal) => _addComponents(
                      meal.components,
                      meal.name,
                    ),
                    onAddRecent: (log) =>
                        _addComponent(syntheticFromLog(log), toastLabel: log.name),
                    onAddIngredient: (ingredient) => _addComponent(ingredient),
                    onFoodTap: _onFoodTap,
                    onCatalogTap: _onCatalogTap,
                    onOpenFoodFactsResultTap: _handleOpenFoodFactsResultTap,
                    onSearchOpenFoodFacts: () =>
                        _onSearchButtonPressed(searchState.searchQuery),
                  )
                : _buildTabBody(context, isDark),
          ),
        ],
      ),
      // ── Persistent build-a-meal draft bar, pinned to the bottom ─────────
      bottomNavigationBar: SafeArea(
        top: false,
        child: DraftMealBar(
          logDate: widget.logDate,
          onSaved: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Widget _buildTabBody(BuildContext context, bool isDark) {
    switch (_activeTab) {
      case _LogTab.recent:
        return _RecentTab(
          scrollController: _scrollController,
          onTap: (log) => _addComponent(syntheticFromLog(log), toastLabel: log.name),
        );
      case _LogTab.favorites:
        return _FavoritesTab(
          scrollController: _scrollController,
          onTap: (meal) => _addComponents(meal.components, meal.name),
        );
      case _LogTab.common:
        return CommonIngredientsSection(
          logDate: widget.logDate,
          scrollController: _scrollController,
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
        return ManualComponentForm(
          logDate: widget.logDate,
          scrollController: _scrollController,
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

class _RecentTab extends ConsumerWidget {
  const _RecentTab({required this.scrollController, required this.onTap});

  final ScrollController scrollController;
  final ValueChanged<MealLog> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentMealsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return recentAsync.when(
      data: (logs) {
        if (logs.isEmpty) {
          return _EmptyTabMessage(
            icon: Icons.history,
            message: 'No recent meals yet.\nMeals you log will show up here.',
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
          children: logs
              .map(
                (log) => _RecentMealRow(
                  log: log,
                  onTap: () => onTap(log),
                  isDark: isDark,
                ),
              )
              .toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ---------------------------------------------------------------------------
// Favorites tab — add a saved meal's components to the draft
// ---------------------------------------------------------------------------

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab({required this.scrollController, required this.onTap});

  final ScrollController scrollController;
  final ValueChanged<SavedMeal> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(savedMealsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return favoritesAsync.when(
      data: (meals) {
        if (meals.isEmpty) {
          return _EmptyTabMessage(
            icon: Icons.star_outline,
            message:
                'No favorites yet.\nTap the ☆ on a logged meal to save it here.',
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
          children: meals
              .map(
                (meal) => _SavedMealRow(
                  meal: meal,
                  onTap: () => onTap(meal),
                  onDelete: () => ref
                      .read(mealLogControllerProvider.notifier)
                      .deleteSavedMeal(meal.id),
                  isDark: isDark,
                ),
              )
              .toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
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
    setState(() => _isAnalyzing = true);
    try {
      final service = ref.read(mealAiServiceProvider);
      final result = await service.describeMeal(_ctrl.text.trim());
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
      if (mounted) MealvanaSnackbar.showError(context, e.userMessage);
    } catch (_) {
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
      if (mounted) MealvanaSnackbar.showError(context, e.userMessage);
    } catch (_) {
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
