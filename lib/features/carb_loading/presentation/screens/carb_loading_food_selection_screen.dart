import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/food_icon.dart';
import '../../../../shared/widgets/buttons/search_openfoodfacts_button.dart';
import '../../../../shared/widgets/inputs/figma_search_bar.dart';
import '../../../../shared/screens/food_detail_screen.dart';
import '../../../../shared/widgets/content_area.dart';
import '../providers/carb_loading_food_selection_controller.dart';
import '../../domain/meal_type.dart';
import '../../domain/carb_loading_food.dart';
import '../../domain/carb_loading_user_food.dart';
import '../../../nutrition_plan/domain/food.dart';
import '../../../../shared/database/app_database.dart' as db;
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
  final TextEditingController _searchController = TextEditingController();
  double _selectedQuantity = 1.0;

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
    ref.read(carbLoadingFoodSelectionControllerProvider(_params).notifier)
      .updateSearch(query);
  }

  Future<void> _onSearchButtonPressed(String query) async {
    if (query.trim().isNotEmpty) {
      await ref.read(carbLoadingFoodSelectionControllerProvider(_params).notifier)
        .searchOpenFoodFacts(query.trim());
    }
  }

  void _onClearSearch() {
    _searchController.clear();
    ref.read(carbLoadingFoodSelectionControllerProvider(_params).notifier)
      .updateSearch('');
    ref.read(carbLoadingFoodSelectionControllerProvider(_params).notifier)
      .clearOpenFoodFactsResults();
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
    ref.read(carbLoadingFoodSelectionControllerProvider(_params).notifier)
      .selectFood(food);

    // Clear search
    _searchController.clear();
    _onSearchChanged('');

    // Reset quantity
    setState(() {
      _selectedQuantity = 1.0;
    });
  }

  Future<void> _handleAddFood() async {
    await ref.read(carbLoadingFoodSelectionControllerProvider(_params).notifier)
      .addFoodToMeal();

    if (mounted) {
      context.pop();
    }
  }

  Future<void> _navigateToCustomFoodEntry() async {
    final result = await context.pushNamed<dynamic>(
      'create-custom-carb-loading-food',
      extra: {
        'dayId': widget.dayId,
        'mealType': widget.mealType,
      },
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
    final controllerState = ref.watch(carbLoadingFoodSelectionControllerProvider(_params));

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: CustomAppBarBackButton(
          onPressed: () => context.pop(),
        ),
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
            icon: const Icon(FontAwesomeIcons.plus, color: AppColors.textLight, size: AppIconSizes.controlIcon),
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
                    onPressed: () => ref.invalidate(carbLoadingFoodSelectionControllerProvider(_params)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (state) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search bar with barcode scanner
                Column(
                  children: [
                    FigmaSearchBar(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      onBarcodeScan: _onBarcodeScan,
                      onSearchSubmit: _onSearchButtonPressed,
                      enableAutoSearch: false, // Disabled - now handled in controller based on results
                      hintText: 'Search foods...',
                    ),

                    // "Search OpenFoodFacts" button (when 1-3 local results)
                    if (state.searchQuery.isNotEmpty &&
                        state.searchResults.isNotEmpty &&
                        state.searchResults.length < 4 &&
                        state.openFoodFactsResults.isEmpty &&
                        !state.isSearchingOpenFoodFacts)
                      SearchOpenFoodFactsButton(
                        onPressed: () => _onSearchButtonPressed(state.searchQuery),
                      ),

                    // Clear search button (when showing OpenFoodFacts results)
                    if (state.openFoodFactsResults.isNotEmpty) ...[
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

                // Selected food details
                if (state.selectedFood != null && state.searchQuery.isEmpty) ...[
                  _buildSelectedFoodCard(state),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Show searching indicator when searching Open Food Facts
                if (state.isSearchingOpenFoodFacts) ...[
                  Expanded(
                    child: _buildSearchingIndicator(),
                  ),
                ] else if (state.openFoodFactsResults.isNotEmpty) ...[
                  // Open Food Facts search results
                  Expanded(
                    child: _buildOpenFoodFactsResults(state),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ] else
                  // Local search results
                  Expanded(
                    child: _buildLocalSearchResults(state),
                  ),

                // Add button - only show when food is selected
                if (state.selectedFood != null && state.searchQuery.isEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  KylePrimaryButton(
                    text: 'Add to $_mealTypeName',
                    onPressed: _handleAddFood,
                    isFullWidth: true,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
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
                FoodIcon(
                  imageUrl: imageUrl,
                  size: AppIconSizes.foodIcon,
                ),
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
                ref.read(carbLoadingFoodSelectionControllerProvider(_params).notifier)
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
            _buildNutrientRow('Carbohydrates', '${totalCarbs.toStringAsFixed(0)} g'),
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

  Widget _buildOpenFoodFactsResults(CarbLoadingFoodSelectionState state) {
    return ListView.separated(
      itemCount: state.openFoodFactsResults.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final result = state.openFoodFactsResults[index];
        return _buildSearchResultItem(result);
      },
    );
  }

  Widget _buildSearchResultItem(dynamic result) {
    return BaseCard(
      child: InkWell(
        onTap: () => _handleOpenFoodFactsSelection(result),
        borderRadius: AppRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Product image with Electrolyte background
              Container(
                width: AppIconSizes.foodIcon,
                height: AppIconSizes.foodIcon,
                decoration: BoxDecoration(
                  color: AppColors.electrolyte.withValues(alpha: 0.2),
                  borderRadius: AppRadius.smRadius,
                ),
                child: result.imageUrl?.isNotEmpty == true
                    ? ClipRRect(
                        borderRadius: AppRadius.smRadius,
                        child: Image.network(
                          result.imageUrl!,
                          width: AppIconSizes.foodIcon,
                          height: AppIconSizes.foodIcon,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            FontAwesomeIcons.utensils,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            size: AppIconSizes.controlIcon,
                          ),
                        ),
                      )
                    : Icon(
                        FontAwesomeIcons.utensils,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: AppIconSizes.controlIcon,
                      ),
              ),

              const SizedBox(width: AppSpacing.md),

              // Product details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.name.isNotEmpty ? result.name : 'Unknown Product',
                      style: AppTextStyles.foodTitle.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (result.brand?.isNotEmpty == true) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        result.brand!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              Icon(
                FontAwesomeIcons.chevronRight,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: AppIconSizes.chevron,
              ),
            ],
          ),
        ),
      ),
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
        ref.read(carbLoadingFoodSelectionControllerProvider(_params).notifier)
          .clearOpenFoodFactsResults();
      }
    } catch (e) {
      if (mounted) {
        MealvanaSnackbar.showError(context, 'Failed to import food: $e');
      }
    }
  }

  Widget _buildLocalSearchResults(CarbLoadingFoodSelectionState state) {
    if (state.searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.magnifyingGlass,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              state.searchQuery.isEmpty
                  ? 'No foods available'
                  : 'No foods found for "${state.searchQuery}"',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: state.searchResults.length,
      itemBuilder: (context, index) {
        final food = state.searchResults[index];
        return _buildFoodCard(food);
      },
    );
  }

  Widget _buildSearchingIndicator() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Searching food database...',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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
                FoodIcon(
                  imageUrl: imageUrl,
                  size: AppIconSizes.foodIcon,
                ),

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
                              color: isCustom ? AppColors.orange : AppColors.electrolyte,
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
    String? displayName;
    String? displayNamePlural;
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
      displayName = food.displayName;
      displayNamePlural = food.displayNamePlural;
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
      displayName = food.displayName;
      displayNamePlural = food.displayNamePlural;
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
          MealvanaSnackbar.showError(context, 'Failed to delete food. Please try again.');
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
          MealvanaSnackbar.showError(context, 'Failed to update food. Please try again.');
        }
      }
    }
  }
}
