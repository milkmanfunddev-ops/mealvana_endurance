import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/buttons/search_openfoodfacts_button.dart';
import '../../../../shared/widgets/inputs/figma_search_bar.dart';
import '../../../../shared/widgets/food_selection/recommended_alternatives.dart';
import '../../../../shared/screens/food_detail_screen.dart';
import '../providers/swap_food_controller.dart';
import '../providers/activity_detail_controller.dart';
import '../../domain/food.dart';
import '../../domain/food_item.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/food_management/user_food_crud_service.dart';
import '../../../barcode_scanning/application/product_detail_service.dart';
import '../../../barcode_scanning/application/food_mapping_service.dart';

/// Swap/Add Food Screen - Kyle's Design System
/// Allows users to swap existing food or add new food to nutrition plan
/// Features: Smart recommendations, search, barcode scanning, OpenFoodFacts integration
///
/// SIMPLIFIED: Only needs activityId to match ActivityDetailController provider.
class SwapFoodScreen extends ConsumerStatefulWidget {
  final String? foodToSwapId;
  final String? foodToSwapName;
  final String category; // before_run, during_run, after_run
  final String activityId;
  final bool isNewActivity;
  final bool isCoachView;

  const SwapFoodScreen({
    super.key,
    this.foodToSwapId,
    this.foodToSwapName,
    required this.category,
    required this.activityId,
    this.isNewActivity = false,
    this.isCoachView = false,
  });

  @override
  ConsumerState<SwapFoodScreen> createState() => _SwapFoodScreenState();
}

class _SwapFoodScreenState extends ConsumerState<SwapFoodScreen> {
  final TextEditingController _searchController = TextEditingController();
  double _selectedQuantity = 1.0;
  bool _isProcessing = false;
  bool _isSavingScannedFood = false; // Track when saving barcode/OpenFoodFacts result

  late final SwapFoodParams _params;

  @override
  void initState() {
    super.initState();
    _params = SwapFoodParams(
      activityId: widget.activityId,
      category: widget.category,
      originalFoodId: widget.foodToSwapId,
      originalFoodName: widget.foodToSwapName,
      isNewActivity: widget.isNewActivity,
      isCoachView: widget.isCoachView,
    );

    // Track screen viewed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final analytics = ref.read(appExternalDepsProvider);
      analytics.analytics.track('swap_food_screen_viewed', properties: {
        'is_swapping': widget.foodToSwapId != null,
        'category': widget.category,
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
    // Get activity type from ActivityDetailController for sport-specific labels
    final activityDetailAsync = ref.read(
      activityDetailControllerProvider(
        activityId: widget.activityId,
        isNewActivity: widget.isNewActivity,
      ),
    );
    final activityType = activityDetailAsync.asData?.value.activity?.activityType ?? ActivityType.running;
    return activityType.getSectionTitle(widget.category);
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
      // Show loading state immediately to prevent showing recommendations
      setState(() {
        _isSavingScannedFood = true;
      });

      try {
        final food = result as Food;

        // Convert category strings to category IDs for saving
        final categoryIds = food.categories.map((cat) {
          switch (cat) {
            case 'before_run':
              return 1;
            case 'during_run':
              return 2;
            case 'after_run':
              return 3;
            default:
              return 1;
          }
        }).toList();

        // Save to user_foods table (offline-first) - same as Open Food Facts flow
        final userFoodCrudService = ref.read(userFoodCrudServiceProvider);
        await userFoodCrudService.saveUserFood(food, categoryIds);

        // Refresh controller state and auto-select the food after refresh completes
        // This prevents race condition where food disappears after being selected
        await ref.read(swapFoodControllerProvider(_params).notifier)
            .refreshFoods(selectAfterRefresh: food);

        _searchController.clear();
        _onSearchChanged('');
      } finally {
        if (mounted) {
          setState(() {
            _isSavingScannedFood = false;
          });
        }
      }
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
    debugPrint('🔵 _handleConfirm START');

    // Prevent double-tap
    if (_isProcessing) {
      debugPrint('🔴 _handleConfirm: already processing, ignoring');
      return;
    }

    final controllerState = ref.read(swapFoodControllerProvider(_params));
    final state = controllerState.value;

    if (state?.selectedFood == null) {
      debugPrint('🔴 _handleConfirm: selectedFood is null, returning early');
      return;
    }

    final food = state!.selectedFood!;
    debugPrint('🔵 _handleConfirm: food selected = ${food.name}, isSwapping = $_isSwapping');

    // IMPORTANT: Capture references BEFORE async operation to avoid context issues
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    // Capture the navigator with rootNavigator to ensure we pop from correct level
    final navigator = Navigator.of(context, rootNavigator: true);

    setState(() {
      _isProcessing = true;
    });

    try {
      if (_isSwapping) {
        debugPrint('🔵 _handleConfirm: calling swapFood...');
        await ref.read(swapFoodControllerProvider(_params).notifier)
          .swapFood(_params, widget.foodToSwapId!, food, widget.category, customAmount: _selectedQuantity);
        debugPrint('🔵 _handleConfirm: swapFood returned');
      } else {
        debugPrint('🔵 _handleConfirm: calling addFood...');
        await ref.read(swapFoodControllerProvider(_params).notifier)
          .addFood(_params, food, widget.category, customAmount: _selectedQuantity);
        debugPrint('🔵 _handleConfirm: addFood returned');
      }

      debugPrint('🔵 _handleConfirm: operation complete, mounted = $mounted');
      if (mounted) {
        debugPrint('🔵 _handleConfirm: showing snackbar');
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(_isSwapping ? 'Food swapped successfully!' : 'Food added successfully!'),
            backgroundColor: AppColors.electrolyte,
          ),
        );

        // Use Navigator.pop with rootNavigator to bypass go_router and pop directly
        debugPrint('🔵 _handleConfirm: navigator.canPop() = ${navigator.canPop()}');
        debugPrint('🔵 _handleConfirm: calling navigator.pop() with rootNavigator');
        navigator.pop();
        debugPrint('🔵 _handleConfirm: navigator.pop() completed');
      } else {
        debugPrint('🔴 _handleConfirm: NOT mounted, cannot pop');
      }
    } catch (e, stackTrace) {
      debugPrint('🔴 _handleConfirm: EXCEPTION caught: $e');
      debugPrint('🔴 Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to ${_isSwapping ? 'swap' : 'add'} food: $e'),
            backgroundColor: AppColors.dragonfruit,
          ),
        );
      }
    }
    debugPrint('🔵 _handleConfirm END');
  }

  Future<void> _handleOpenFoodFactsSelection(dynamic result) async {
    try {
      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      // Fetch product details
      final productDetailService = ref.read(productDetailServiceProvider);
      final apiProduct = await productDetailService.getProductDetails(openFoodFactsId: result.id);

      if (mounted) Navigator.of(context).pop(); // Close loading dialog

      if (apiProduct == null) {
        if (mounted) {
          MealvanaSnackbar.showError(context, 'Unable to load product details');
        }
        return;
      }

      // Map to Food domain object
      final mappingService = ref.read(foodMappingServiceProvider);
      final food = await mappingService.mapToFood(apiProduct);
      final foodItem = _convertFoodToFoodItem(food);

      // Determine pre-checked category based on current phase
      final preCheckedCategories = <int>[_categoryToId(widget.category)];

      // Navigate to food detail screen with current phase pre-checked
      if (mounted) {
        final result = await context.pushNamed<dynamic>(
          'food-detail',
          extra: {
            'foodData': FoodDetailData.fromFoodItem(foodItem),
            'mode': FoodDetailMode.addFromSearch,
            'screenContext': _isSwapping ? FoodDetailContext.swapFood : FoodDetailContext.addFood,
            'preSelectedCategories': preCheckedCategories,
            'showCategories': true,
            'showProductType': true,
            'allowDelete': false,
          },
        );

        if (result is FoodDetailResult && mounted) {
          // Show loading state while saving
          setState(() {
            _isSavingScannedFood = true;
          });

          try {
            await _saveOpenFoodFactsFood(
              foodItem,
              result.categoryIds,
              result.fluidMlPerServing,
              carbsPerServing: result.carbsPerServing,
              proteinPerServing: result.proteinPerServing,
              fatPerServing: result.fatPerServing,
              sodiumMg: result.sodiumMg.toDouble(),
              productType: result.productType,
            );
          } finally {
            if (mounted) {
              setState(() {
                _isSavingScannedFood = false;
              });
            }
          }
        }
      }
    } catch (e) {
      // Close loading dialog if still showing
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        MealvanaSnackbar.showError(context, 'Failed to import food: $e');
      }
    }
  }

  int _categoryToId(String category) {
    switch (category) {
      case 'before_run':
        return 1;
      case 'during_run':
        return 2;
      case 'after_run':
        return 3;
      default:
        return 1;
    }
  }

  FoodItem _convertFoodToFoodItem(Food food) {
    // Convert List<String> categories to List<FoodCategory>
    final foodCategories = food.categories.map((cat) {
      switch (cat) {
        case 'before_run':
          return FoodCategory.beforeRun;
        case 'during_run':
          return FoodCategory.duringRun;
        case 'after_run':
          return FoodCategory.afterRun;
        default:
          return FoodCategory.beforeRun; // Default fallback
      }
    }).toList();

    return FoodItem(
      id: food.id,
      name: food.name,
      imageAddress: food.imageAddress,
      description: food.description,
      instructions: food.instructions,
      categories: foodCategories,
      servingSize: food.servingSize,
      servingAmount: food.servingAmount,
      servingUnit: food.servingUnit,
      servingUnitPlural: food.servingUnitPlural,
      servingQualifier: food.servingQualifier,
      displayName: food.displayName,
      displayNamePlural: food.displayNamePlural,
      fluidMlPerServing: food.fluidMlPerServing,
      carbsPerServing: food.carbsPerServing,
      proteinPerServing: food.proteinPerServing,
      fatPerServing: food.fatPerServing,
      sodiumMg: food.sodiumMg,
      caloriesPerServing: food.caloriesPerServing,
      productTypeId: food.productTypeId,
      beforeRunSuitable: food.beforeRunSuitable,
      duringRunSuitable: food.duringRunSuitable,
      runPortable: food.runPortable,
      requiresPreparation: food.requiresPreparation,
      aidStationAvailable: food.aidStationAvailable,
      maxServingsBefore: food.maxServingsBefore,
      maxServingsDuring: food.maxServingsDuring,
      caffeineMg: food.caffeineMg,
      potassiumMg: food.potassiumMg,
    );
  }

  Future<void> _saveOpenFoodFactsFood(
    FoodItem foodItem,
    List<int> categoryIds,
    double? finalFluidAmount, {
    double? carbsPerServing,
    double? proteinPerServing,
    double? fatPerServing,
    double? sodiumMg,
    String? productType,
  }) async {
    try {
      final userFoodCrudService = ref.read(userFoodCrudServiceProvider);

      // Convert categoryIds to category strings for Food object
      final categoryStrings = categoryIds.map((id) {
        switch (id) {
          case 1:
            return 'before_run';
          case 2:
            return 'during_run';
          case 3:
            return 'after_run';
          default:
            return 'before_run';
        }
      }).toList();

      // Create Food object for the crud service
      // Use user-selected product type if provided, otherwise fall back to 'import'
      final food = Food(
        id: foodItem.id,
        name: foodItem.name,
        displayName: foodItem.displayName ?? foodItem.name,
        displayNamePlural: foodItem.displayNamePlural ?? '${foodItem.name}s',
        description: foodItem.description,
        imageAddress: foodItem.imageAddress,
        servingAmount: foodItem.servingAmount,
        servingUnit: foodItem.servingUnit,
        caloriesPerServing: foodItem.caloriesPerServing,
        carbsPerServing: carbsPerServing ?? foodItem.carbsPerServing,
        proteinPerServing: proteinPerServing ?? foodItem.proteinPerServing,
        fatPerServing: fatPerServing ?? foodItem.fatPerServing,
        sodiumMg: sodiumMg?.toInt() ?? foodItem.sodiumMg,
        fluidMlPerServing: finalFluidAmount ?? foodItem.fluidMlPerServing,
        productTypeId: productType ?? foodItem.productTypeId ?? 'import',
        categories: categoryStrings,
      );

      // Save via crud service (offline-first)
      await userFoodCrudService.saveUserFood(food, categoryIds);

      // Refresh controller state and auto-select the food after refresh completes
      // This prevents race condition where food disappears after being selected
      await ref.read(swapFoodControllerProvider(_params).notifier)
          .refreshFoods(selectAfterRefresh: food);

      // Reset quantity after selection
      setState(() {
        _selectedQuantity = 1.0;
      });

      if (mounted) {
        MealvanaSnackbar.showSuccess(context, '${foodItem.name} added!');
      }
    } catch (e) {
      if (mounted) {
        MealvanaSnackbar.showError(context, 'Failed to save food: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ SwapFoodScreen build() called - isProcessing: $_isProcessing');
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
    final hasSelectedFood = state.selectedFood != null &&
        state.searchQuery.isEmpty &&
        state.openFoodFactsResults.isEmpty;

    return SafeArea(
      child: Column(
        children: [
          // Search bar with barcode - always visible at top
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                FigmaSearchBar(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onBarcodeScan: _onBarcodeScan,
                  onSearchSubmit: _onSearchButtonPressed,
                  enableAutoSearch: false, // Disabled - now handled in controller based on results
                  hintText: 'Search for food...',
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
          ),

          // Main content area - uses Expanded to fill remaining space
          Expanded(
            child: _isSavingScannedFood
                ? _buildSavingIndicator()
                : (hasSelectedFood
                    ? _buildSelectedFoodContent(state.selectedFood!)
                    : _buildContentArea(state)),
          ),

          // Confirm button (only when food is selected and no active search)
          if (hasSelectedFood && !_isSavingScannedFood) ...[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: KylePrimaryButton(
                text: _isSwapping ? 'SWAP FOOD' : 'ADD FOOD',
                isLoading: _isProcessing,
                onPressed: () {
                  debugPrint('🟢 SWAP/ADD BUTTON PRESSED - about to call _handleConfirm');
                  _handleConfirm();
                },
                isFullWidth: true,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build scrollable content when a food is selected
  /// This prevents keyboard overflow by making the selected food card scrollable
  Widget _buildSelectedFoodContent(Food selectedFood) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: _buildSelectedFoodCard(selectedFood),
    );
  }

  Widget _buildContentArea(SwapFoodState state) {
    // Show searching indicator when searching Open Food Facts
    if (state.isSearchingOpenFoodFacts) {
      return _buildSearchingIndicator();
    }

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
        userFoodIds: state.userFoodIds,
        onEditUserFood: _showUserFoodEditSheet,
      );
    } else {
      // Show search results
      return _buildSearchResults(state);
    }
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

  Widget _buildSavingIndicator() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Adding food...',
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
    final isUserFood = _isUserFood(food);

    return BaseCard(
      child: InkWell(
        onTap: () => _selectFood(food),
        onLongPress: isUserFood ? () => _showUserFoodEditSheet(food) : null,
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
                    // Show category badges for user foods
                    if (isUserFood && food.categories.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      _buildCategoryBadges(food.categories),
                    ],
                  ],
                ),
              ),
              // Show edit button for user foods, plus for others
              if (isUserFood)
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
    );
  }

  /// Check if a food is a user-imported food (not a system food)
  /// Uses the userFoodIds set from the controller state for accurate detection
  bool _isUserFood(Food food) {
    // First try to use the userFoodIds from state for accurate detection
    final controllerState = ref.read(swapFoodControllerProvider(_params));
    if (controllerState.hasValue && controllerState.value!.userFoodIds.isNotEmpty) {
      return controllerState.value!.userFoodIds.contains(food.id);
    }

    // Fallback to name-based heuristic if state not available
    final name = food.name.toLowerCase();
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
    return !knownGenericFoods.any((keyword) => name.contains(keyword));
  }

  /// Build category badges for user foods
  Widget _buildCategoryBadges(List<String> categories) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: categories.map((category) {
        final label = _categoryToLabel(category);
        final color = _getCategoryColor(category);
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Text(
            label,
            style: AppTextStyles.smallLabel.copyWith(
              color: color,
              fontSize: 10,
            ),
          ),
        );
      }).toList(),
    );
  }

  String _categoryToLabel(String category) {
    switch (category) {
      case 'before_run':
        return 'Before';
      case 'during_run':
        return 'During';
      case 'after_run':
        return 'After';
      default:
        return category;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'before_run':
        return AppColors.electrolyte;
      case 'during_run':
        return AppColors.orange;
      case 'after_run':
        return AppColors.dragonfruit;
      default:
        return AppColors.cream;
    }
  }

  /// Show the edit screen for a user food
  Future<void> _showUserFoodEditSheet(Food food) async {
    final userFoodCrudService = ref.read(userFoodCrudServiceProvider);

    final result = await context.pushNamed<dynamic>(
      'food-detail',
      extra: {
        'foodData': FoodDetailData.fromFood(food),
        'mode': FoodDetailMode.editExisting,
        'screenContext': FoodDetailContext.swapFood,
        'showCategories': true,
        'showProductType': true,
        'allowDelete': true,
      },
    );

    if (!mounted) return;

    // Handle delete
    if (result is String && result.startsWith('DELETE:')) {
      final foodId = result.substring(7);
      try {
        await userFoodCrudService.deleteUserFood(foodId);
        await ref.read(swapFoodControllerProvider(_params).notifier).refreshFoods();

        if (mounted) {
          MealvanaSnackbar.showSuccess(context, '${food.name} deleted');
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
          categoryIds: result.categoryIds,
        );

        // Refresh foods to reflect changes
        await ref.read(swapFoodControllerProvider(_params).notifier).refreshFoods();

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
