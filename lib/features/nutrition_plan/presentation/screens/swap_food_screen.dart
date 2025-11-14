import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/food_selection/food_search_bar.dart';
import '../../../../shared/widgets/food_selection/recommended_alternatives.dart';
import '../providers/swap_food_controller.dart';
import '../../domain/food.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../domain/pending_activity_data.dart';
import '../../domain/macro_targets.dart';

/// Swap/Add Food Screen - Kyle's Design System
/// Allows users to swap existing food or add new food to nutrition plan
/// Features: Smart recommendations, search, barcode scanning, OpenFoodFacts integration
class SwapFoodScreen extends ConsumerStatefulWidget {
  final String? foodToSwapId;
  final String? foodToSwapName;
  final String category; // before_run, during_run, after_run
  final int activityId;
  final String mode; // 'create' or 'view' - must match ActivityDetailController mode
  final PendingActivityData? pendingActivityData; // Required to match ActivityDetailController instance
  final MacroTargets? macroTargets; // Required to match ActivityDetailController instance

  const SwapFoodScreen({
    super.key,
    this.foodToSwapId,
    this.foodToSwapName,
    required this.category,
    required this.activityId,
    this.mode = 'view', // Default to 'view' for backwards compatibility
    this.pendingActivityData,
    this.macroTargets,
  });

  @override
  ConsumerState<SwapFoodScreen> createState() => _SwapFoodScreenState();
}

class _SwapFoodScreenState extends ConsumerState<SwapFoodScreen> {
  final TextEditingController _searchController = TextEditingController();
  double _selectedQuantity = 1.0;

  late final SwapFoodParams _params;

  @override
  void initState() {
    super.initState();
    _params = SwapFoodParams(
      activityId: widget.activityId,
      category: widget.category,
      originalFoodId: widget.foodToSwapId,
      originalFoodName: widget.foodToSwapName,
      mode: widget.mode,
      pendingActivityData: widget.pendingActivityData,
      macroTargets: widget.macroTargets,
    );

    // Track screen viewed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final analytics = ref.read(appExternalDepsProvider);
      analytics.analytics.track('swap_food_screen_viewed', properties: {
        'is_swapping': widget.foodToSwapId != null,
        'category': widget.category,
        'mode': widget.mode,
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isSwapping => widget.foodToSwapId != null;

  String get _screenTitle => _isSwapping
      ? 'Swap ${widget.foodToSwapName ?? 'Food'}'
      : 'Add Food to ${_getCategoryDisplayName()}';

  String _getCategoryDisplayName() {
    switch (widget.category) {
      case 'before_run':
        return 'Before Run';
      case 'during_run':
        return 'During Run';
      case 'after_run':
        return 'After Run';
      default:
        return widget.category;
    }
  }

  void _onSearchChanged(String query) {
    ref.read(swapFoodControllerProvider(_params).notifier).updateSearch(query);
  }

  Future<void> _onSearchButtonPressed(String query) async {
    if (query.trim().isNotEmpty) {
      await ref.read(swapFoodControllerProvider(_params).notifier)
        .searchOpenFoodFacts(query.trim());
    }
  }

  void _onClearSearch() {
    _searchController.clear();
    ref.read(swapFoodControllerProvider(_params).notifier).updateSearch('');
    ref.read(swapFoodControllerProvider(_params).notifier).clearOpenFoodFactsResults();
  }

  Future<void> _onBarcodeScan() async {
    // Navigate to barcode scanner
    final result = await context.pushNamed<dynamic>(
      'barcode-scanner',
      extra: {
        'category': widget.category,
        'foodToSwapId': widget.foodToSwapId,
        'foodToSwapName': widget.foodToSwapName,
        'context': _isSwapping ? 'swap' : 'add',
      },
    );

    if (result != null && mounted) {
      final food = result as Food;
      ref.read(swapFoodControllerProvider(_params).notifier).selectFood(food);
      _searchController.clear();
      _onSearchChanged('');
    }
  }

  void _selectFood(Food food) {
    ref.read(swapFoodControllerProvider(_params).notifier).selectFood(food);
    _searchController.clear();
    _onSearchChanged('');
    setState(() {
      _selectedQuantity = 1.0;
    });
  }

  Future<void> _handleConfirm() async {
    final controllerState = ref.read(swapFoodControllerProvider(_params));
    final state = controllerState.value;

    if (state?.selectedFood == null) return;

    final food = state!.selectedFood!;

    try {
      if (_isSwapping) {
        await ref.read(swapFoodControllerProvider(_params).notifier)
          .swapFood(_params, widget.foodToSwapId!, food, widget.category, customAmount: _selectedQuantity);
      } else {
        await ref.read(swapFoodControllerProvider(_params).notifier)
          .addFood(_params, food, widget.category, customAmount: _selectedQuantity);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isSwapping ? 'Food swapped successfully!' : 'Food added successfully!'),
            backgroundColor: AppColors.electrolyte,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${_isSwapping ? 'swap' : 'add'} food: $e'),
            backgroundColor: AppColors.dragonfruit,
          ),
        );
      }
    }
  }

  Future<void> _handleOpenFoodFactsSelection(dynamic result) async {
    try {
      await ref.read(swapFoodControllerProvider(_params).notifier)
        .addOpenFoodFactsResult(result);

      // Reset quantity after selection
      setState(() {
        _selectedQuantity = 1.0;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import food: $e'),
            backgroundColor: AppColors.dragonfruit,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(swapFoodControllerProvider(_params));

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
          _screenTitle,
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: controllerState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorState(error),
        data: (state) => _buildContent(state),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.triangleExclamation,
              size: AppIconSizes.xl,
              color: AppColors.dragonfruit,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Error loading foods',
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error.toString(),
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            KylePrimaryButton(
              text: 'Retry',
              onPressed: () => ref.invalidate(swapFoodControllerProvider(_params)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(SwapFoodState state) {
    return SafeArea(
      child: Column(
        children: [
          // Search bar with barcode
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: FoodSearchBar(
              controller: _searchController,
              onSearch: _onSearchButtonPressed,
              onChanged: _onSearchChanged,
              onBarcodeScan: _onBarcodeScan,
              hintText: 'Search for food...',
              showClearButton: state.openFoodFactsResults.isNotEmpty,
              onClear: _onClearSearch,
            ),
          ),

          // Selected food card (when food is selected and no active search)
          if (state.selectedFood != null && state.searchQuery.isEmpty && state.openFoodFactsResults.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _buildSelectedFoodCard(state.selectedFood!),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Content area (recommendations, search results, or OpenFoodFacts results)
          Expanded(
            child: _buildContentArea(state),
          ),

          // Confirm button (only when food is selected and no active search)
          if (state.selectedFood != null && state.searchQuery.isEmpty && state.openFoodFactsResults.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: KylePrimaryButton(
                text: _isSwapping ? 'SWAP FOOD' : 'ADD FOOD',
                onPressed: _handleConfirm,
                isFullWidth: true,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContentArea(SwapFoodState state) {
    // OpenFoodFacts results take priority
    if (state.openFoodFactsResults.isNotEmpty) {
      return _buildOpenFoodFactsResults(state);
    }

    // Show recommendations or search results
    if (state.searchQuery.isEmpty) {
      // Show recommendations
      return RecommendedAlternatives(
        foods: state.recommendations,
        onFoodSelected: _selectFood,
        preferences: state.preferences,
        title: _isSwapping ? 'Recommended Alternatives' : 'Recommended Foods',
      );
    } else {
      // Show search results
      return _buildSearchResults(state);
    }
  }

  Widget _buildSearchResults(SwapFoodState state) {
    if (state.searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FontAwesomeIcons.magnifyingGlass,
                size: AppIconSizes.xl,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No foods found for "${state.searchQuery}"',
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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: state.searchResults.length,
      itemBuilder: (context, index) {
        final food = state.searchResults[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _buildFoodCard(food),
        );
      },
    );
  }

  Widget _buildOpenFoodFactsResults(SwapFoodState state) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: state.openFoodFactsResults.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final result = state.openFoodFactsResults[index];
        return _buildOpenFoodFactsCard(result);
      },
    );
  }

  Widget _buildFoodCard(Food food) {
    return BaseCard(
      child: InkWell(
        onTap: () => _selectFood(food),
        borderRadius: AppRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Food icon with colored circular background
              Container(
                width: AppIconSizes.foodIcon,
                height: AppIconSizes.foodIcon,
                decoration: BoxDecoration(
                  color: _getFoodIconColor(food.name),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getFoodIcon(food.name),
                  size: AppIconSizes.controlIcon,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.displayName ?? food.name,
                      style: AppTextStyles.foodTitle.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (food.carbsPerServing != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${food.carbsPerServing!.toInt()}g carbs per serving',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                FontAwesomeIcons.circlePlus,
                color: AppColors.orange,
                size: AppIconSizes.md,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpenFoodFactsCard(dynamic result) {
    return BaseCard(
      child: InkWell(
        onTap: () => _handleOpenFoodFactsSelection(result),
        borderRadius: AppRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Product image
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.displayName ?? 'Unknown Product',
                      style: AppTextStyles.foodTitle.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (result.categories?.isNotEmpty == true) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        result.categories!,
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

  Widget _buildSelectedFoodCard(Food food) {
    final totalCarbs = (food.carbsPerServing ?? 0) * _selectedQuantity;
    final totalProtein = (food.proteinPerServing ?? 0) * _selectedQuantity;
    final totalFat = (food.fatPerServing ?? 0) * _selectedQuantity;
    final totalCalories = ((food.caloriesPerServing ?? 0) * _selectedQuantity).toInt();

    return BaseCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Food header
            Row(
              children: [
                // Food icon with colored circular background
                Container(
                  width: AppIconSizes.foodIcon,
                  height: AppIconSizes.foodIcon,
                  decoration: BoxDecoration(
                    color: _getFoodIconColor(food.name),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getFoodIcon(food.name),
                    size: AppIconSizes.controlIcon,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.displayName ?? food.name,
                        style: AppTextStyles.foodTitle.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (food.description?.isNotEmpty == true) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          food.description!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    FontAwesomeIcons.xmark,
                    size: AppIconSizes.controlIcon,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    ref.read(swapFoodControllerProvider(_params).notifier).clearSelection();
                  },
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Quantity control
            KylePlusMinusDecimalControl(
              value: _selectedQuantity,
              onChanged: (value) {
                setState(() {
                  _selectedQuantity = value;
                });
              },
              min: 0.5,
              max: 10.0,
              step: 0.5,
              decimalPlaces: 1,
              label: 'QUANTITY',
            ),

            const SizedBox(height: AppSpacing.lg),

            // Nutrition info
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.electrolyte.withValues(alpha: 0.1),
                borderRadius: AppRadius.smRadius,
              ),
              child: Column(
                children: [
                  _buildNutrientRow('Carbohydrates', '${totalCarbs.toStringAsFixed(1)} g'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildNutrientRow('Protein', '${totalProtein.toStringAsFixed(1)} g'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildNutrientRow('Fat', '${totalFat.toStringAsFixed(1)} g'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildNutrientRow('Calories', '$totalCalories kcal'),
                ],
              ),
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

  /// Get the appropriate icon for a food based on its name
  IconData _getFoodIcon(String foodName) {
    final name = foodName.toLowerCase();

    // Map generic foods to specific icons
    if (name.contains('apple') && !name.contains('applesauce')) {
      return FontAwesomeIcons.appleWhole;
    } else if (name.contains('applesauce') || name.contains('purée')) {
      return FontAwesomeIcons.bottleDroplet;
    } else if (name.contains('bagel')) {
      return FontAwesomeIcons.breadSlice;
    } else if (name.contains('banana')) {
      return FontAwesomeIcons.appleWhole;
    } else if (name.contains('berr')) {
      return FontAwesomeIcons.bowlFood;
    } else if (name.contains('chocolate milk')) {
      return FontAwesomeIcons.bottleWater;
    } else if (name.contains('coconut water')) {
      return FontAwesomeIcons.bottleWater;
    } else if (name.contains('coffee')) {
      return FontAwesomeIcons.mugHot;
    } else if (name.contains('date')) {
      return FontAwesomeIcons.appleWhole;
    } else if (name.contains('electrolyte drink mix')) {
      return FontAwesomeIcons.flask;
    } else if (name.contains('electrolyte tablet')) {
      return FontAwesomeIcons.pills;
    } else if (name.contains('energy bar')) {
      return FontAwesomeIcons.bars;
    } else if (name.contains('energy chew')) {
      return FontAwesomeIcons.candyCane;
    } else if (name.contains('energy waffle') || name.contains('stroopwafel')) {
      return FontAwesomeIcons.cookie;
    } else if (name.contains('fig bar')) {
      return FontAwesomeIcons.bars;
    } else if (name.contains('gel')) {
      return FontAwesomeIcons.droplet;
    } else if (name.contains('oatmeal')) {
      return FontAwesomeIcons.bowlFood;
    } else if (name.contains('orange juice')) {
      return FontAwesomeIcons.glassWater;
    } else if (name.contains('peanut butter')) {
      return FontAwesomeIcons.jar;
    } else if (name.contains('pickle juice')) {
      return FontAwesomeIcons.vial;
    } else if (name.contains('pretzel')) {
      return FontAwesomeIcons.bowlFood;
    } else if (name.contains('protein bar')) {
      return FontAwesomeIcons.bars;
    } else if (name.contains('protein powder')) {
      return FontAwesomeIcons.jar;
    } else if (name.contains('protein shake')) {
      return FontAwesomeIcons.bottleWater;
    } else if (name.contains('salt packet')) {
      return FontAwesomeIcons.bagShopping;
    } else if (name.contains('sports drink mix')) {
      return FontAwesomeIcons.flask;
    } else if (name.contains('sports drink')) {
      return FontAwesomeIcons.bottleWater;
    } else if (name.contains('toast')) {
      return FontAwesomeIcons.breadSlice;
    } else if (name.contains('trail mix')) {
      return FontAwesomeIcons.bowlFood;
    } else if (name.contains('water')) {
      return FontAwesomeIcons.bottleWater;
    } else if (name.contains('yogurt')) {
      return FontAwesomeIcons.bowlFood;
    }

    // Check if this is likely a user-imported food
    final knownGenericFoods = [
      'apple', 'applesauce', 'purée', 'bagel', 'banana', 'berr',
      'chocolate milk', 'coconut water', 'coffee', 'date',
      'electrolyte drink', 'electrolyte tablet', 'energy bar',
      'energy chew', 'energy waffle', 'stroopwafel', 'fig bar',
      'gel', 'oatmeal', 'orange juice', 'peanut butter',
      'pickle juice', 'pretzel', 'protein bar', 'protein powder',
      'protein shake', 'salt packet', 'sports drink', 'toast',
      'trail mix', 'water', 'yogurt',
    ];

    // If none of the generic food keywords match, it's likely user-imported
    if (!knownGenericFoods.any((keyword) => name.contains(keyword))) {
      return FontAwesomeIcons.userPen;
    }

    // Default fallback icon
    return FontAwesomeIcons.utensils;
  }

  /// Get the background color for the food icon
  Color _getFoodIconColor(String foodName) {
    final name = foodName.toLowerCase();

    final knownGenericFoods = [
      'apple', 'applesauce', 'purée', 'bagel', 'banana', 'berr',
      'chocolate milk', 'coconut water', 'coffee', 'date',
      'electrolyte drink', 'electrolyte tablet', 'energy bar',
      'energy chew', 'energy waffle', 'stroopwafel', 'fig bar',
      'gel', 'oatmeal', 'orange juice', 'peanut butter',
      'pickle juice', 'pretzel', 'protein bar', 'protein powder',
      'protein shake', 'salt packet', 'sports drink', 'toast',
      'trail mix', 'water', 'yogurt',
    ];

    // User-imported foods get orange color
    if (!knownGenericFoods.any((keyword) => name.contains(keyword))) {
      return AppColors.orange;
    }

    // Generic foods get electrolyte color
    return AppColors.electrolyte;
  }
}
