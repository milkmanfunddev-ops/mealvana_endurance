import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/food_icon.dart';
import '../../../../shared/widgets/inputs/figma_search_bar.dart';
import '../../../../shared/screens/food_detail_screen.dart';
import '../../../../shared/widgets/content_area.dart';
import '../../../../shared/controllers/food_search_controller.dart';
import '../../../../shared/widgets/food_search/unified_food_search_results.dart';
import '../providers/carb_loading_food_selection_controller.dart';
import '../../application/carb_loading_food_service.dart';
import '../../data/carb_loading_day_meal_repository.dart';
import '../../domain/meal_type.dart';
import '../../domain/carb_loading_food.dart';
import '../../domain/carb_loading_user_food.dart';
import '../../../nutrition_plan/domain/food.dart';
import '../../../barcode_scanning/application/catalog_search_service.dart';
import '../../../nutrition_plan/presentation/widgets/swap_food/catalog_section_widget.dart';
import '../../../../shared/database/app_database.dart' as db;
import '../../../../shared/database/database_provider.dart';
import '../../../../shared/providers/user_id_provider.dart';
import '../../../../shared/services/food_management/user_food_crud_service.dart';
import '../../../../../../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Screen for selecting foods to add to a carb loading meal
/// Searches across all food sources and handles importing from nutrition plan
class CarbLoadingFoodSelectionScreen extends ConsumerStatefulWidget {
  final String dayId;
  final MealType mealType;

  const CarbLoadingFoodSelectionScreen({
    super.key,
    required this.dayId,
    required this.mealType,
  });

  @override
  ConsumerState<CarbLoadingFoodSelectionScreen> createState() =>
      _CarbLoadingFoodSelectionScreenState();
}

class _CarbLoadingFoodSelectionScreenState
    extends ConsumerState<CarbLoadingFoodSelectionScreen> {
  static const _searchControllerKey = 'carb_loading_food_selection';

  final TextEditingController _searchController = TextEditingController();
  final Map<String, dynamic> _searchSourceById = {};

  double _selectedQuantity = 1.0;
  bool _isMyFoodsExpanded = true;
  bool _isNutritionPlanFoodsExpanded = false;
  bool _isNutritionPlanUserFoodsExpanded = false;

  late final CarbLoadingFoodSelectionParams _params;

  @override
  void initState() {
    super.initState();
    _params = CarbLoadingFoodSelectionParams(
      carbLoadingDayId: widget.dayId,
      mealType: widget.mealType,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _mealTypeName {
    switch (widget.mealType) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
      case MealType.snacks:
        return 'Snack';
      case MealType.morningSnack:
        return 'Morning Snack';
      case MealType.afternoonSnack:
        return 'Afternoon Snack';
      case MealType.eveningSnack:
        return 'Evening Snack';
    }
  }

  void _onSearchChanged(String query) {
    ref
        .read(foodSearchControllerProvider(_searchControllerKey).notifier)
        .updateSearch(query);
  }

  Future<void> _onSearchButtonPressed(String query) async {
    if (query.trim().isNotEmpty) {
      await ref
          .read(foodSearchControllerProvider(_searchControllerKey).notifier)
          .searchOpenFoodFacts(query.trim());
    }
  }

  void _onClearSearch() {
    _searchController.clear();
    ref
        .read(foodSearchControllerProvider(_searchControllerKey).notifier)
        .clearSearch();
  }

  Future<void> _onBarcodeScan() async {
    // Navigate to barcode scanner
    final result = await context.pushNamed<dynamic>(
      'barcode-scanner',
      extra: {
        'context': 'carb_loading',
        'dayId': widget.dayId,
        'mealType': widget.mealType.name,
      },
    );

    if (result != null) {
      // Handle scanned result - the barcode scanner should return a food
      _selectFood(result);
    }
  }

  void _selectFood(dynamic food) {
    ref
        .read(carbLoadingFoodSelectionControllerProvider(_params).notifier)
        .selectFood(food);

    // Clear search
    _onClearSearch();

    // Reset quantity
    setState(() {
      _selectedQuantity = 1.0;
    });
  }

  /// Minimum number of carb-loading-curated matches (template + user foods)
  /// for the current query below which the generic nutrition-plan pool is
  /// mixed into the search pool as a fallback. Keeps curated carb foods from
  /// being crowded out when they already answer the query well.
  static const int _fallbackPoolThreshold = 4;

  void _seedSearchController(CarbLoadingFoodSelectionState state) {
    final userFoods = <Food>[];
    // Carb-loading's own curated pool (its dedicated catalog + the user's
    // custom carb foods). Always ranked first.
    final ownFoods = <Food>[];
    // Generic nutrition-plan pool (imported foods). Lower priority than
    // carb-loading's own pool, and only surfaced as a fallback when the
    // carb-specific pool is thin for the current query (ITEM 18).
    final fallbackFoods = <Food>[];
    _searchSourceById.clear();

    for (final food in state.carbLoadingUserFoods) {
      if (food.isDeleted) continue;
      final mapped = _mapCarbLoadingUserFoodToSearchFood(food);
      userFoods.add(mapped);
      ownFoods.add(mapped);
      _searchSourceById[mapped.id] = food;
    }

    for (final food in state.carbLoadingFoods) {
      final mapped = _mapCarbLoadingTemplateFoodToSearchFood(food);
      ownFoods.add(mapped);
      _searchSourceById[mapped.id] = food;
    }

    // Nutrition plan user foods (fallback pool)
    for (final food in state.nutritionPlanUserFoods) {
      final mapped = Food(
        id: 'nutrition_plan_user_${food.id}',
        name: food.name,
        displayName: food.displayName,
        displayNamePlural: food.displayNamePlural,
        imageAddress: food.imageAddress,
        carbsPerServing: food.carbsPerServing,
        categories: const [],
      );
      fallbackFoods.add(mapped);
      _searchSourceById[mapped.id] = food;
    }

    // Nutrition plan foods (fallback pool)
    for (final food in state.nutritionPlanFoods) {
      final mapped = Food(
        id: 'nutrition_plan_${food.id}',
        name: food.name,
        displayName: food.displayName,
        displayNamePlural: food.displayNamePlural,
        imageAddress: food.imageUrl,
        carbsPerServing: food.carbsPerServing,
        categories: const [],
      );
      fallbackFoods.add(mapped);
      _searchSourceById[mapped.id] = food;
    }

    // Only mix the fallback (nutrition-plan) pool in when carb-loading's own
    // pool is thin for the current query. The shared FoodSearchController
    // already renders `templateFoodResults` above its remote catalog/OFF/USDA
    // cascade, so keeping `ownFoods` first here + gating the fallback pool
    // ensures carb-loading-curated foods surface first end-to-end.
    final query = _searchController.text.trim();
    final includeFallbackPool =
        query.isEmpty ||
        _ownFoodMatchCount(state, query) < _fallbackPoolThreshold;

    final notifier = ref.read(
      foodSearchControllerProvider(_searchControllerKey).notifier,
    );

    // Carb loading wants real food — pasta, rice, bagels, potatoes — not gels
    // and chews. This screen was the only search surface that never called
    // setFilter, so it ran on the default `all` and ranked a caffeinated gel
    // level with a bowl of pasta.
    //
    // `generalFirst` ranks rather than hides (see FoodSearchController), so a
    // gel is still reachable — some people do carb-load with sports drinks and
    // energy gels; the seeded carb_loading_foods list includes both. It just
    // stops them crowding out the foods this screen is actually for.
    //
    // Note this is the fuel/general axis, which is NOT carb loading's real axis
    // (that is meal_types: breakfast/lunch/dinner/snack). Filtering by meal type
    // needs the recommendation rail — see the audit doc §10 Phase 4.
    notifier.setFilter(FoodSearchFilter.generalFirst);

    notifier.updateFoodPool(
      allFoods: [...ownFoods, if (includeFallbackPool) ...fallbackFoods],
      userFoods: userFoods,
    );
  }

  /// Count carb-loading's own curated foods (template + user, undeleted)
  /// that match [query] by name/display name. Used to decide whether the
  /// generic nutrition-plan pool should be mixed in as a fallback.
  int _ownFoodMatchCount(CarbLoadingFoodSelectionState state, String query) {
    final lowerQuery = query.toLowerCase();
    bool matches(String name, String displayName) =>
        name.toLowerCase().contains(lowerQuery) ||
        displayName.toLowerCase().contains(lowerQuery);

    final templateMatches = state.carbLoadingFoods
        .where((f) => matches(f.name, f.displayName))
        .length;
    final userMatches = state.carbLoadingUserFoods
        .where((f) => !f.isDeleted && matches(f.name, f.displayName))
        .length;
    return templateMatches + userMatches;
  }

  Food _mapCarbLoadingTemplateFoodToSearchFood(CarbLoadingFood food) {
    return Food(
      id: 'carb_template_${food.id}',
      name: food.name,
      displayName: food.displayName,
      displayNamePlural: food.displayNamePlural,
      imageAddress: food.imageAddress,
      carbsPerServing: food.carbsPerServing,
      categories: const [],
    );
  }

  Food _mapCarbLoadingUserFoodToSearchFood(CarbLoadingUserFood food) {
    return Food(
      id: 'carb_user_${food.id}',
      name: food.name,
      displayName: food.displayName,
      displayNamePlural: food.displayNamePlural,
      imageAddress: food.imageAddress,
      carbsPerServing: food.carbsPerServing,
      categories: const [],
    );
  }

  Widget _buildDefaultView(CarbLoadingFoodSelectionState state) {
    final userFoods = state.carbLoadingUserFoods
        .where((food) => !food.isDeleted)
        .toList();

    // Show only the curated carb foods that suit the meal you're adding to.
    // Every seeded food carries meal_types (breakfast / lunch+dinner / snacks),
    // and CarbLoadingFood.isSuitableForMeal already reads it — but the browse
    // list ignored both and rendered all 27, so the Breakfast screen offered
    // pizza and the Dinner screen offered orange juice.
    //
    // Browse only. Search is deliberately left unfiltered: typing "pizza" at
    // breakfast is an explicit ask and should still find it.
    final suitable = state.carbLoadingFoods
        .where((f) => f.isSuitableForMeal(state.mealType))
        .toList();
    // Never show an empty rail — if a meal type has no curated matches (or the
    // seed data changes), fall back to the full list rather than a blank page.
    final templateFoods = suitable.isNotEmpty
        ? suitable
        : state.carbLoadingFoods;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      children: [
        if (userFoods.isNotEmpty) ...[
          InkWell(
            onTap: () {
              setState(() {
                _isMyFoodsExpanded = !_isMyFoodsExpanded;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  FaIcon(
                    FontAwesomeIcons.solidHeart,
                    size: AppIconSizes.sm,
                    color: AppColors.dragonfruit,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'My Carb Foods',
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.dragonfruit.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${userFoods.length}',
                      style: AppTextStyles.smallLabel.copyWith(
                        color: AppColors.dragonfruit,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isMyFoodsExpanded
                        ? FontAwesomeIcons.chevronUp.data
                        : FontAwesomeIcons.chevronDown.data,
                    size: AppIconSizes.sm,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_isMyFoodsExpanded)
            ...userFoods.map((food) => _buildFoodCard(food)),
          const SizedBox(height: AppSpacing.md),
        ],
        if (templateFoods.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              // Was "Template Foods" — meaningless to an athlete, and
              // "template" already means four unrelated things in this codebase
              // (see the 2026-07-03 architecture audit §1). The list is now
              // filtered to this meal, so say so.
              '${state.mealType.displayName} Carb Foods',
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          ...templateFoods.map((food) => _buildFoodCard(food)),
          const SizedBox(height: AppSpacing.md),
        ],
        if (state.nutritionPlanUserFoods.isNotEmpty) ...[
          InkWell(
            onTap: () {
              setState(() {
                _isNutritionPlanUserFoodsExpanded =
                    !_isNutritionPlanUserFoodsExpanded;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  FaIcon(
                    FontAwesomeIcons.solidHeart,
                    size: AppIconSizes.sm,
                    color: AppColors.orange,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'My Nutrition Foods',
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${state.nutritionPlanUserFoods.length}',
                      style: AppTextStyles.smallLabel.copyWith(
                        color: AppColors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isNutritionPlanUserFoodsExpanded
                        ? FontAwesomeIcons.chevronUp.data
                        : FontAwesomeIcons.chevronDown.data,
                    size: AppIconSizes.sm,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_isNutritionPlanUserFoodsExpanded)
            ...state.nutritionPlanUserFoods.map((food) => _buildFoodCard(food)),
          const SizedBox(height: AppSpacing.md),
        ],
        if (state.nutritionPlanFoods.isNotEmpty) ...[
          InkWell(
            onTap: () {
              setState(() {
                _isNutritionPlanFoodsExpanded = !_isNutritionPlanFoodsExpanded;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  FaIcon(
                    FontAwesomeIcons.utensils,
                    size: AppIconSizes.sm,
                    color: AppColors.electrolyte,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Nutrition Plan Foods',
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.electrolyte.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${state.nutritionPlanFoods.length}',
                      style: AppTextStyles.smallLabel.copyWith(
                        color: AppColors.electrolyte,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isNutritionPlanFoodsExpanded
                        ? FontAwesomeIcons.chevronUp.data
                        : FontAwesomeIcons.chevronDown.data,
                    size: AppIconSizes.sm,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_isNutritionPlanFoodsExpanded)
            ...state.nutritionPlanFoods.map((food) => _buildFoodCard(food)),
        ],
      ],
    );
  }

  Future<void> _handleAddFood() async {
    await ref
        .read(carbLoadingFoodSelectionControllerProvider(_params).notifier)
        .addFoodToMeal();

    if (mounted) {
      _safePop();
    }
  }

  /// Guarded pop for this GoRoute-registered screen (ITEM 19 audit). This
  /// screen is only ever reached via `context.push('/carb-loading-select-food')`
  /// so it IS on the GoRouter stack, but every reachable pop is still guarded
  /// against an empty stack (e.g. deep link / hot restart edge cases) rather
  /// than assuming there is always something to pop.
  void _safePop() {
    if (context.canPop()) {
      context.pop();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _navigateToCustomFoodEntry() async {
    final result = await context.pushNamed<dynamic>(
      'create-custom-carb-loading-food',
      extra: {'dayId': widget.dayId, 'mealType': widget.mealType},
    );

    if (result != null && mounted) {
      // Food was created, refresh the list and select it
      ref.invalidate(carbLoadingFoodSelectionControllerProvider(_params));

      // Wait for controller to reload, then select the newly created food
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted && result is CarbLoadingUserFood) {
        _selectFood(result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(
      carbLoadingFoodSelectionControllerProvider(_params),
    );
    final searchState = ref.watch(
      foodSearchControllerProvider(_searchControllerKey),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: CustomAppBarBackButton(onPressed: _safePop),
        title: Text(
          'Add Food to $_mealTypeName',
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: controllerState.when(
        data: (state) {
          // Only show FAB when no food is selected
          if (state.selectedFood != null) return null;

          return FloatingActionButton.extended(
            onPressed: _navigateToCustomFoodEntry,
            backgroundColor: AppColors.orange,
            icon: const FaIcon(
              FontAwesomeIcons.plus,
              color: AppColors.textLight,
              size: AppIconSizes.controlIcon,
            ),
            label: Text(
              'Create Custom Food',
              style: AppTextStyles.buttonPrimary.copyWith(
                color: AppColors.textLight,
              ),
            ),
          );
        },
        loading: () => null,
        error: (_, __) => null,
      ),
      body: ContentArea(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: controllerState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error loading foods: $error'),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(
                        carbLoadingFoodSelectionControllerProvider(_params),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (state) {
                _seedSearchController(state);
                final hasSelectedFood =
                    state.selectedFood != null &&
                    searchState.searchQuery.isEmpty &&
                    searchState.openFoodFactsResults.isEmpty;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        FigmaSearchBar(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          onBarcodeScan: _onBarcodeScan,
                          onSearchSubmit: _onSearchButtonPressed,
                          triggerSearchOnKeyboardSubmit: false,
                          enableAutoSearch: false,
                          hintText: 'Search foods...',
                          useDarkStyle:
                              Theme.of(context).brightness == Brightness.dark,
                        ),
                        if (searchState.openFoodFactsResults.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Center(
                            child: TextButton.icon(
                              onPressed: _onClearSearch,
                              icon: const FaIcon(
                                FontAwesomeIcons.xmark,
                                size: AppIconSizes.sm,
                                color: AppColors.orange,
                              ),
                              label: const Text(
                                'Clear Search',
                                style: TextStyle(
                                  fontFamily: 'Apercu',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.orange,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (hasSelectedFood) ...[
                      _buildSelectedFoodCard(state),
                      const SizedBox(height: AppSpacing.md),
                      KylePrimaryButton(
                        text: 'Add to $_mealTypeName',
                        onPressed: _handleAddFood,
                        isFullWidth: true,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ] else
                      Expanded(
                        child: UnifiedFoodSearchResults(
                          controllerKey: _searchControllerKey,
                          userFoodItemBuilder: (food) {
                            final source = _searchSourceById[food.id];
                            if (source == null) return const SizedBox.shrink();
                            return _buildFoodCard(source);
                          },
                          templateFoodItemBuilder: (food) {
                            final source = _searchSourceById[food.id];
                            if (source == null) return const SizedBox.shrink();
                            return _buildFoodCard(source);
                          },
                          catalogItemBuilder: (result) => CatalogCard(
                            result: result,
                            onTap: () => _handleCatalogSelection(result),
                          ),
                          onSearchOpenFoodFacts: () =>
                              _onSearchButtonPressed(searchState.searchQuery),
                          onOpenFoodFactsResultTap:
                              _handleOpenFoodFactsSelection,
                          emptyQueryContent: _buildDefaultView(state),
                          isMyFoodsExpanded: _isMyFoodsExpanded,
                          onMyFoodsSectionToggle: () {
                            setState(() {
                              _isMyFoodsExpanded = !_isMyFoodsExpanded;
                            });
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedFoodCard(CarbLoadingFoodSelectionState state) {
    final food = state.selectedFood;
    String displayName = '';
    String? imageUrl;
    double carbsPerServing = 0.0;

    // Extract info based on food type
    if (food is CarbLoadingFood) {
      displayName = food.displayName;
      imageUrl = food.imageAddress;
      carbsPerServing = food.carbsPerServing;
    } else if (food is CarbLoadingUserFood) {
      displayName = food.displayName;
      imageUrl = food.imageAddress;
      carbsPerServing = food.carbsPerServing;
    } else if (food is Food) {
      displayName = food.displayName ?? food.name;
      imageUrl = food.imageUrl;
      carbsPerServing = food.carbsPerServing ?? 0.0;
    } else if (food is db.UserFood) {
      displayName = food.displayName ?? food.name;
      imageUrl = food.imageAddress;
      carbsPerServing = food.carbsPerServing ?? 0.0;
    }

    final totalCarbs = carbsPerServing * _selectedQuantity;

    return BaseCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Food header
            Row(
              children: [
                FoodIcon(imageUrl: imageUrl, size: AppIconSizes.foodIcon),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    displayName,
                    style: AppTextStyles.foodTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Quantity control using Kyle's design
            KylePlusMinusDecimalControl(
              value: _selectedQuantity,
              onChanged: (value) {
                setState(() {
                  _selectedQuantity = value;
                });
                ref
                    .read(
                      carbLoadingFoodSelectionControllerProvider(
                        _params,
                      ).notifier,
                    )
                    .updateQuantity(value);
              },
              min: 0.5,
              max: 10.0,
              step: 0.5,
              decimalPlaces: 1,
              label: 'QUANTITY',
            ),

            const SizedBox(height: AppSpacing.md),

            // Nutrition facts
            _buildNutrientRow(
              'Carbohydrates',
              '${totalCarbs.toStringAsFixed(0)} g',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.dataNumber.copyWith(
            color: AppColors.electrolyte,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Future<void> _handleOpenFoodFactsSelection(dynamic result) async {
    // Create a carb loading user food from OFF result
    try {
      final importedFood = await ref
          .read(carbLoadingFoodSelectionControllerProvider(_params).notifier)
          .addFromOpenFoodFacts(result);

      // Select the imported food
      if (mounted) {
        _selectFood(importedFood);
        ref.invalidate(carbLoadingFoodSelectionControllerProvider(_params));
      }
    } catch (e) {
      if (mounted) {
        MealvanaSnackbar.showError(context, 'Failed to import food: $e');
      }
    }
  }

  Future<void> _handleCatalogSelection(CatalogSearchResult result) async {
    try {
      final deviceId = await ref.read(userIdProvider.future);
      final foodService = ref.read(carbLoadingFoodServiceProvider);
      final allUserFoods = await foodService.getAllUserFoods(deviceId);

      CarbLoadingUserFood? existingMatch;
      for (final food in allUserFoods) {
        if (food.isDeleted) continue;

        final barcodeMatches =
            result.barcode != null &&
            result.barcode!.isNotEmpty &&
            food.barcode == result.barcode;
        final nameMatches =
            food.displayName.toLowerCase() == result.displayName.toLowerCase();

        if (barcodeMatches || nameMatches) {
          existingMatch = food;
          break;
        }
      }

      CarbLoadingUserFood selectedFood;
      if (existingMatch != null) {
        if (!existingMatch.mealTypes.contains(widget.mealType)) {
          selectedFood = await foodService.updateUserFood(
            id: existingMatch.id,
            mealTypes: [...existingMatch.mealTypes, widget.mealType],
          );
        } else {
          selectedFood = existingMatch;
        }
      } else {
        selectedFood = await foodService.createUserFood(
          deviceId: deviceId,
          userId: deviceId,
          name: _toInternalFoodName(result.displayName),
          displayName: result.displayName,
          displayNamePlural: '${result.displayName}s',
          carbsPerServing: result.carbsG ?? 0.0,
          imageAddress: result.imageUrl,
          mealTypes: [widget.mealType],
        );
      }

      if (!mounted) return;

      ref.invalidate(carbLoadingFoodSelectionControllerProvider(_params));
      _selectFood(selectedFood);
      MealvanaSnackbar.showSuccess(context, '${result.displayName} added');
    } catch (e) {
      if (mounted) {
        MealvanaSnackbar.showError(context, 'Failed to import food: $e');
      }
    }
  }

  String _toInternalFoodName(String displayName) {
    final normalized = displayName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return normalized.isEmpty ? 'custom_food' : normalized;
  }

  Widget _buildFoodCard(dynamic food) {
    String displayName = '';
    String? imageUrl;
    double carbsPerServing = 0.0;
    bool isCustom = false;
    String? badge;

    // Extract info based on food type
    if (food is CarbLoadingFood) {
      displayName = food.displayName;
      imageUrl = food.imageAddress;
      carbsPerServing = food.carbsPerServing;
      badge = 'Carb Loading';
    } else if (food is CarbLoadingUserFood) {
      displayName = food.displayName;
      imageUrl = food.imageAddress;
      carbsPerServing = food.carbsPerServing;
      isCustom = true;
      badge = 'Custom';
    } else if (food is Food) {
      displayName = food.displayName ?? food.name;
      imageUrl = food.imageUrl;
      carbsPerServing = food.carbsPerServing ?? 0.0;
      badge = 'From Nutrition Plan';
    } else if (food is db.UserFood) {
      displayName = food.displayName ?? food.name;
      imageUrl = food.imageAddress;
      carbsPerServing = food.carbsPerServing ?? 0.0;
      isCustom = true;
      badge = 'Custom Food';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: BaseCard(
        child: InkWell(
          onTap: () => _selectFood(food),
          onLongPress: isCustom ? () => _showUserFoodEditSheet(food) : null,
          borderRadius: AppRadius.cardRadius,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                // Food icon
                FoodIcon(imageUrl: imageUrl, size: AppIconSizes.foodIcon),

                const SizedBox(width: AppSpacing.md),

                // Food details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: AppTextStyles.foodTitle.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${carbsPerServing.toInt()}g carbs per serving',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: isCustom
                                ? AppColors.orange.withValues(alpha: 0.2)
                                : AppColors.electrolyte.withValues(alpha: 0.2),
                            borderRadius: AppRadius.xsRadius,
                          ),
                          child: Text(
                            badge,
                            style: AppTextStyles.smallLabel.copyWith(
                              color: isCustom
                                  ? AppColors.orange
                                  : AppColors.electrolyte,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Show edit button for custom foods, customize button for templates
                if (isCustom)
                  IconButton(
                    icon: FaIcon(
                      FontAwesomeIcons.penToSquare,
                      color: AppColors.electrolyte.withValues(alpha: 0.7),
                      size: AppIconSizes.sm,
                    ),
                    onPressed: () => _showUserFoodEditSheet(food),
                    tooltip: 'Edit food',
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: FaIcon(
                          FontAwesomeIcons.copy,
                          color: AppColors.electrolyte.withValues(alpha: 0.7),
                          size: AppIconSizes.sm,
                        ),
                        onPressed: () =>
                            _duplicateAndCustomizeTemplateFood(food),
                        tooltip: 'Duplicate & customize',
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      FaIcon(
                        FontAwesomeIcons.circlePlus,
                        color: AppColors.orange,
                        size: AppIconSizes.md,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Duplicate a template food and open edit screen to customize
  Future<void> _duplicateAndCustomizeTemplateFood(dynamic food) async {
    if (food is! CarbLoadingFood) return;

    final carbLoadingFoodService = ref.read(carbLoadingFoodServiceProvider);
    final deviceId = await ref.read(userIdProvider.future);

    try {
      // Create custom food with "(customized)" suffix
      final customizedName = '${food.displayName} (customized)';

      debugPrint('📋 Duplicating template food: ${food.displayName}');

      final customFood = await carbLoadingFoodService.createUserFood(
        deviceId: deviceId,
        userId: deviceId,
        name: _toInternalFoodName(customizedName),
        displayName: customizedName,
        displayNamePlural: '${customizedName}s',
        carbsPerServing: food.carbsPerServing,
        mealTypes: [_params.mealType],
      );

      debugPrint(
        '✅ Created custom food: ${customFood.displayName} (ID: ${customFood.id})',
      );

      // Refresh the food list to show the new custom food
      ref.invalidate(carbLoadingFoodSelectionControllerProvider(_params));

      // Open edit screen so user can customize carbs and name
      if (mounted) {
        await _showUserFoodEditSheet(customFood);
      }
    } catch (e) {
      debugPrint('❌ Error duplicating food: $e');
      if (mounted) {
        MealvanaSnackbar.showError(
          context,
          'Failed to duplicate food. Please try again.',
        );
      }
    }
  }

  /// Show the edit screen for a user food (no categories for carb loading)
  Future<void> _showUserFoodEditSheet(dynamic food) async {
    final userFoodCrudService = ref.read(userFoodCrudServiceProvider);
    final carbLoadingFoodService = ref.read(carbLoadingFoodServiceProvider);
    final database = ref.read(appDatabaseProvider);
    final deviceId = await ref.read(userIdProvider.future);

    String foodId = '';
    String foodName = '';
    double? servingAmount;
    String? servingUnit;
    double? carbsPerServing;
    double? proteinPerServing;
    double? fatPerServing;
    int? sodiumMg;
    double? fluidMlPerServing;
    int? caloriesPerServing;

    // Extract food ID first to fetch fresh data
    if (food is CarbLoadingUserFood) {
      foodId = food.id;
    } else if (food is db.UserFood) {
      foodId = food.id;
    } else {
      return; // Not an editable food type
    }

    // **CRITICAL FIX**: Fetch FRESH data from database instead of using cached food object
    // This ensures we always see the latest carbs value after edits
    if (food is CarbLoadingUserFood) {
      debugPrint('🔍 Fetching fresh data for CarbLoadingUserFood: $foodId');
      final freshFood = await carbLoadingFoodService.getUserFoodById(foodId);
      if (freshFood == null) {
        debugPrint('❌ Food not found: $foodId');
        return;
      }

      // Use displayName (user-facing) not name (internal identifier)
      foodName = freshFood.displayName;
      servingAmount = null;
      servingUnit = null;
      carbsPerServing = freshFood.carbsPerServing;
      proteinPerServing = null;
      fatPerServing = null;
      sodiumMg = null;
      fluidMlPerServing = null;
      caloriesPerServing = null;

      debugPrint(
        '✅ Fresh data loaded: ${freshFood.displayName} with ${freshFood.carbsPerServing}g carbs',
      );
    } else if (food is db.UserFood) {
      debugPrint('🔍 Fetching fresh data for UserFood: $foodId');
      final freshFoodQuery = database.select(database.userFoodsTable)
        ..where((tbl) => tbl.id.equals(foodId));
      final freshFoodList = await freshFoodQuery.get();

      if (freshFoodList.isEmpty) {
        debugPrint('❌ Food not found: $foodId');
        return;
      }

      final freshFood = freshFoodList.first;
      foodName = freshFood.name;
      servingAmount = freshFood.servingAmount;
      servingUnit = freshFood.servingUnit;
      carbsPerServing = freshFood.carbsPerServing;
      proteinPerServing = freshFood.proteinPerServing;
      fatPerServing = freshFood.fatPerServing;
      sodiumMg = freshFood.sodiumMg;
      fluidMlPerServing = freshFood.fluidMlPerServing;
      caloriesPerServing = freshFood.caloriesPerServing;

      debugPrint(
        '✅ Fresh data loaded: ${freshFood.name} with ${freshFood.carbsPerServing}g carbs',
      );
    } else {
      return; // Not an editable food type
    }

    final foodData = FoodDetailData(
      id: foodId,
      name: foodName,
      servingAmount: servingAmount,
      servingUnit: servingUnit,
      carbsPerServing: carbsPerServing,
      proteinPerServing: proteinPerServing,
      fatPerServing: fatPerServing,
      sodiumMg: sodiumMg,
      fluidMlPerServing: fluidMlPerServing,
      caloriesPerServing: caloriesPerServing,
      categoryIds: [], // No categories for carb loading
    );

    final result = await context.pushNamed<dynamic>(
      'food-detail',
      extra: {
        'foodData': foodData,
        'mode': FoodDetailMode.editExisting,
        'screenContext': FoodDetailContext.carbLoading,
        'showCategories': false, // Hide category checkboxes for carb loading
        'showProductType': false,
        'allowDelete': true,
      },
    );

    if (!mounted) return;

    debugPrint('📥 Result handler received result: ${result.runtimeType}');

    // Handle delete
    if (result is String && result.startsWith('DELETE:')) {
      final deletedFoodId = result.substring(7);
      try {
        await userFoodCrudService.deleteUserFood(deletedFoodId);
        ref.invalidate(carbLoadingFoodSelectionControllerProvider(_params));

        if (mounted) {
          MealvanaSnackbar.showSuccess(context, '$foodName deleted');
        }
      } catch (e) {
        debugPrint('Error deleting user food: $e');
        if (mounted) {
          MealvanaSnackbar.showError(
            context,
            'Failed to delete food. Please try again.',
          );
        }
      }
    }
    // Handle update
    else if (result is FoodDetailResult) {
      debugPrint(
        '📦 FoodDetailResult received: ${result.name} with ${result.carbsPerServing}g carbs (ID: ${result.foodId})',
      );

      try {
        debugPrint(
          '🔧 Updating food: ${result.name} with ${result.carbsPerServing}g carbs',
        );
        debugPrint('🔧 Food ID: ${result.foodId}');

        // CRITICAL FIX: Use carbLoadingFoodService for carb loading foods, not userFoodCrudService
        // userFoodCrudService updates user_foods table (nutrition plan)
        // carbLoadingFoodService updates carb_loading_user_foods table
        // result.name from FoodDetailScreen maps to displayName (user-facing name)
        await carbLoadingFoodService.updateUserFood(
          id: result.foodId,
          displayName:
              result.name, // FoodDetailScreen's name field = displayName
          carbsPerServing: result.carbsPerServing,
        );

        debugPrint(
          '🔧 Carb loading user food updated successfully in correct table',
        );

        // Update carbs in all existing meal entries that use this food
        final dayMealRepo = ref.read(carbLoadingDayMealRepositoryProvider);
        debugPrint('🔧 Updating meal entries with food ID: ${result.foodId}');

        final mealsUpdated = await dayMealRepo.updateCarbsForUserFood(
          carbLoadingUserFoodId: result.foodId,
          newCarbsPerServing: result.carbsPerServing,
        );

        debugPrint('🔧 Updated $mealsUpdated meal entries');

        // Refresh foods to reflect changes
        ref.invalidate(carbLoadingFoodSelectionControllerProvider(_params));

        if (mounted) {
          final message = mealsUpdated > 0
              ? '${result.name} updated! ($mealsUpdated meal${mealsUpdated > 1 ? 's' : ''} updated)'
              : '${result.name} updated!';
          MealvanaSnackbar.showSuccess(context, message);
        }
      } catch (e, stackTrace) {
        debugPrint('❌ Error updating user food: $e');
        debugPrint('Stack trace: $stackTrace');
        if (mounted) {
          MealvanaSnackbar.showError(
            context,
            'Failed to update food. Please try again.',
          );
        }
      }
    }
  }
}
