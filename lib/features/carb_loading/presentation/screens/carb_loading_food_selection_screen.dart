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
import '../../domain/meal_type.dart';
import '../../domain/carb_loading_food.dart';
import '../../domain/carb_loading_user_food.dart';
import '../../../nutrition_plan/domain/food.dart';
import '../../../barcode_scanning/application/catalog_search_service.dart';
import '../../../nutrition_plan/presentation/widgets/swap_food/catalog_section_widget.dart';
import '../../../../shared/database/app_database.dart' as db;
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

  void _seedSearchController(CarbLoadingFoodSelectionState state) {
    final userFoods = <Food>[];
    final templateFoods = <Food>[];
    _searchSourceById.clear();

    for (final food in state.carbLoadingUserFoods) {
      if (food.isDeleted) continue;
      final mapped = _mapCarbLoadingUserFoodToSearchFood(food);
      userFoods.add(mapped);
      _searchSourceById[mapped.id] = food;
    }

    for (final food in state.carbLoadingFoods) {
      final mapped = _mapCarbLoadingTemplateFoodToSearchFood(food);
      templateFoods.add(mapped);
      _searchSourceById[mapped.id] = food;
    }

    ref
        .read(foodSearchControllerProvider(_searchControllerKey).notifier)
        .updateFoodPool(
          allFoods: [...templateFoods, ...userFoods],
          userFoods: userFoods,
        );
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
    final templateFoods = state.carbLoadingFoods;

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
                  Icon(
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
                        ? FontAwesomeIcons.chevronUp
                        : FontAwesomeIcons.chevronDown,
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
              'Template Foods',
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          ...templateFoods.map((food) => _buildFoodCard(food)),
        ],
      ],
    );
  }

  Future<void> _handleAddFood() async {
    await ref
        .read(carbLoadingFoodSelectionControllerProvider(_params).notifier)
        .addFoodToMeal();

    if (mounted) {
      context.pop();
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
        leading: CustomAppBarBackButton(onPressed: () => context.pop()),
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
            icon: const Icon(
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
                              icon: const Icon(
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

                // Show edit button for custom foods, plus for others
                if (isCustom)
                  IconButton(
                    icon: Icon(
                      FontAwesomeIcons.penToSquare,
                      color: AppColors.electrolyte.withValues(alpha: 0.7),
                      size: AppIconSizes.sm,
                    ),
                    onPressed: () => _showUserFoodEditSheet(food),
                    tooltip: 'Edit food',
                  )
                else
                  Icon(
                    FontAwesomeIcons.circlePlus,
                    color: AppColors.orange,
                    size: AppIconSizes.md,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Show the edit screen for a user food (no categories for carb loading)
  Future<void> _showUserFoodEditSheet(dynamic food) async {
    final userFoodCrudService = ref.read(userFoodCrudServiceProvider);

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

    // Extract data based on food type
    if (food is CarbLoadingUserFood) {
      foodId = food.id;
      foodName = food.name;
      servingAmount = null;
      servingUnit = null;
      carbsPerServing = food.carbsPerServing;
      proteinPerServing = null;
      fatPerServing = null;
      sodiumMg = null;
      fluidMlPerServing = null;
      caloriesPerServing = null;
    } else if (food is db.UserFood) {
      foodId = food.id;
      foodName = food.name;
      servingAmount = food.servingAmount;
      servingUnit = food.servingUnit;
      carbsPerServing = food.carbsPerServing;
      proteinPerServing = food.proteinPerServing;
      fatPerServing = food.fatPerServing;
      sodiumMg = food.sodiumMg;
      fluidMlPerServing = food.fluidMlPerServing;
      caloriesPerServing = food.caloriesPerServing;
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
      try {
        await userFoodCrudService.updateUserFood(
          foodId: result.foodId,
          name: result.name,
          displayName: result.name,
          displayNamePlural: '${result.name}s',
          servingAmount: result.servingAmount,
          servingUnit: result.servingUnit,
          carbsPerServing: result.carbsPerServing,
          proteinPerServing: result.proteinPerServing,
          fatPerServing: result.fatPerServing,
          sodiumMg: result.sodiumMg,
          fluidMlPerServing: result.fluidMlPerServing,
          // Don't update categories for carb loading foods
        );

        // Refresh foods to reflect changes
        ref.invalidate(carbLoadingFoodSelectionControllerProvider(_params));

        if (mounted) {
          MealvanaSnackbar.showSuccess(context, '${result.name} updated!');
        }
      } catch (e) {
        debugPrint('Error updating user food: $e');
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
