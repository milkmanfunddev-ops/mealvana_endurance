import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/inputs/figma_search_bar.dart';
import '../../../../shared/screens/food_detail_screen.dart';
import '../providers/swap_food_controller.dart';
import '../../domain/food.dart';
import '../../domain/food_item.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/food_management/user_food_crud_service.dart';
import '../../../barcode_scanning/application/product_detail_service.dart';
import '../../../barcode_scanning/application/food_mapping_service.dart';
import '../../../barcode_scanning/application/catalog_search_service.dart';
import '../widgets/swap_food/food_card_widget.dart';
import '../widgets/swap_food/selected_food_display_widget.dart';
import '../widgets/swap_food/food_search_results_widget.dart';

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
      : 'Add Food';

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

  /// Open create food screen with empty form
  Future<void> _openCreateFoodScreen() async {
    final uuid = DateTime.now().millisecondsSinceEpoch.toString();
    // Determine pre-selected categories based on current section
    final baseCategory = widget.category.split(':').first;
    final preSelectedCategories = <int>[
      if (baseCategory.startsWith('before')) 1,
      if (baseCategory.startsWith('during')) 2,
      if (baseCategory.startsWith('after')) 3,
      if (!baseCategory.startsWith('before') && !baseCategory.startsWith('during') && !baseCategory.startsWith('after')) ...[1, 2, 3],
    ];

    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (ctx) => FoodDetailScreen(
          foodData: FoodDetailData(
            id: uuid,
            name: '',
            categoryIds: preSelectedCategories,
          ),
          mode: FoodDetailMode.createNew,
          screenContext: FoodDetailContext.addFood,
          preSelectedCategories: preSelectedCategories,
          showCategories: true,
          showProductType: true,
        ),
      ),
    );

    if (result != null && result is FoodDetailResult && mounted) {
      setState(() { _isSavingScannedFood = true; });

      try {
        final categoryStrings = result.categoryIds.map((id) {
          switch (id) {
            case 1: return 'before_run';
            case 2: return 'during_run';
            case 3: return 'after_run';
            default: return 'before_run'; // DB categories remain *_run
          }
        }).toList();

        final food = Food(
          id: result.foodId.isEmpty ? uuid : result.foodId,
          name: result.name,
          categories: categoryStrings,
          servingSize: result.servingSize,
          servingAmount: result.servingAmount,
          servingUnit: result.servingUnit,
          carbsPerServing: result.carbsPerServing,
          proteinPerServing: result.proteinPerServing,
          fatPerServing: result.fatPerServing,
          sodiumMg: result.sodiumMg,
          caloriesPerServing: result.caloriesPerServing,
          fluidMlPerServing: result.fluidMlPerServing,
          productTypeId: result.productType,
          beforeRunSuitable: result.categoryIds.contains(1),
          duringRunSuitable: result.categoryIds.contains(2),
        );

        // Save to user_foods
        final userFoodCrudService = ref.read(userFoodCrudServiceProvider);
        await userFoodCrudService.saveUserFood(food, result.categoryIds);

        // Refresh foods and auto-expand My Foods section
        await ref.read(swapFoodControllerProvider(_params).notifier)
            .refreshFoods(expandMyFoods: true);

        if (mounted) {
          MealvanaSnackbar.showSuccess(context, 'Custom food created!');
        }
      } catch (e) {
        if (mounted) {
          MealvanaSnackbar.showError(context, 'Failed to save food: $e');
        }
      } finally {
        if (mounted) {
          setState(() { _isSavingScannedFood = false; });
        }
      }
    }
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
          if (cat.startsWith('before')) return 1;
          if (cat.startsWith('during')) return 2;
          if (cat.startsWith('after')) return 3;
          return 1;
        }).toList();

        // Save to user_foods table (offline-first) - same as Open Food Facts flow
        final userFoodCrudService = ref.read(userFoodCrudServiceProvider);
        await userFoodCrudService.saveUserFood(food, categoryIds);

        // Refresh controller state and auto-select the food after refresh completes
        // This prevents race condition where food disappears after being selected
        await ref.read(swapFoodControllerProvider(_params).notifier)
            .refreshFoods(selectAfterRefresh: food, expandMyFoods: true);

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
        MealvanaSnackbar.showSuccess(context, _isSwapping ? 'Food swapped successfully!' : 'Food added successfully!');

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
        MealvanaSnackbar.showError(context, 'Failed to ${_isSwapping ? 'swap' : 'add'} food: $e');
      }
    }
    debugPrint('🔵 _handleConfirm END');
  }

  Future<void> _handleCatalogSelection(CatalogSearchResult result) async {
    // Always open FoodDetailScreen for review, pre-populated with catalog data
    final preCheckedCategories = <int>[_categoryToId(widget.category)];
    final detailResult = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (ctx) => FoodDetailScreen(
          foodData: FoodDetailData(
            id: '',
            name: result.displayName,
            categoryIds: preCheckedCategories,
            imageUrl: result.imageUrl,
            carbsPerServing: result.carbsG,
            proteinPerServing: result.proteinG,
            fatPerServing: result.fatG,
            sodiumMg: result.sodiumMg,
            caloriesPerServing: result.caloriesPerServing,
            servingSize: result.servingSize,
            productType: result.productType,
          ),
          mode: FoodDetailMode.addFromSearch,
          screenContext: _isSwapping ? FoodDetailContext.swapFood : FoodDetailContext.addFood,
          preSelectedCategories: preCheckedCategories,
          showCategories: true,
          showProductType: true,
        ),
      ),
    );

    if (detailResult is FoodDetailResult && mounted) {
      setState(() { _isSavingScannedFood = true; });
      try {
        final categoryStrings = detailResult.categoryIds.map((id) {
          switch (id) {
            case 1: return 'before_run';
            case 2: return 'during_run';
            case 3: return 'after_run';
            default: return 'before_run';
          }
        }).toList();

        final food = Food(
          id: detailResult.foodId.isEmpty
              ? DateTime.now().millisecondsSinceEpoch.toString()
              : detailResult.foodId,
          name: detailResult.name,
          categories: categoryStrings,
          servingSize: detailResult.servingSize,
          servingAmount: detailResult.servingAmount,
          servingUnit: detailResult.servingUnit,
          carbsPerServing: detailResult.carbsPerServing,
          proteinPerServing: detailResult.proteinPerServing,
          fatPerServing: detailResult.fatPerServing,
          sodiumMg: detailResult.sodiumMg,
          caloriesPerServing: detailResult.caloriesPerServing,
          fluidMlPerServing: detailResult.fluidMlPerServing,
          productTypeId: detailResult.productType,
          imageAddress: result.imageUrl,
        );

        final userFoodCrudService = ref.read(userFoodCrudServiceProvider);
        await userFoodCrudService.saveUserFood(food, detailResult.categoryIds);
        await ref.read(swapFoodControllerProvider(_params).notifier)
            .refreshFoods(selectAfterRefresh: food, expandMyFoods: true);

        _searchController.clear();
        if (mounted) {
          MealvanaSnackbar.showSuccess(context, '${result.title} added!');
        }
      } catch (e) {
        if (mounted) {
          MealvanaSnackbar.showError(context, 'Failed to save food: $e');
        }
      } finally {
        if (mounted) {
          setState(() { _isSavingScannedFood = false; });
        }
      }
    }
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
    // Strip sub-phase suffix (e.g., 'before_run:snack' → 'before_run')
    final base = category.split(':').first;
    if (base.startsWith('before')) return 1;
    if (base.startsWith('during')) return 2;
    if (base.startsWith('after')) return 3;
    return 1;
  }

  FoodItem _convertFoodToFoodItem(Food food) {
    // Convert List<String> categories to List<FoodCategory>
    final foodCategories = food.categories.map((cat) {
      if (cat.startsWith('before')) return FoodCategory.beforeRun;
      if (cat.startsWith('during')) return FoodCategory.duringRun;
      if (cat.startsWith('after')) return FoodCategory.afterRun;
      return FoodCategory.beforeRun; // Default fallback
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
        servingSize: foodItem.servingSize,
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
          .refreshFoods(selectAfterRefresh: food, expandMyFoods: true);

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
        state.openFoodFactsResults.isEmpty &&
        state.catalogResults.isEmpty;

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

                // Create custom food button
                const SizedBox(height: AppSpacing.xs),
                Center(
                  child: TextButton.icon(
                    onPressed: _openCreateFoodScreen,
                    icon: const Icon(
                      FontAwesomeIcons.plus,
                      size: AppIconSizes.sm,
                      color: AppColors.orange,
                    ),
                    label: const Text(
                      'Create Custom Food',
                      style: TextStyle(
                        fontFamily: 'Apercu',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.orange,
                      ),
                    ),
                  ),
                ),
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
      child: SelectedFoodDisplayWidget(
        food: selectedFood,
        quantity: _selectedQuantity,
        onQuantityChanged: (value) {
          setState(() {
            _selectedQuantity = value;
          });
        },
        onClear: () {
          ref.read(swapFoodControllerProvider(_params).notifier).clearSelection();
        },
      ),
    );
  }

  Widget _buildContentArea(SwapFoodState state) {
    // Show searching indicator when searching Open Food Facts
    if (state.isSearchingOpenFoodFacts) {
      return _buildSearchingIndicator();
    }

    // OpenFoodFacts results take priority
    if (state.openFoodFactsResults.isNotEmpty) {
      return OpenFoodFactsResultsWidget(
        results: state.openFoodFactsResults,
        onResultTap: _handleOpenFoodFactsSelection,
      );
    }

    // Show recommendations or search results
    if (state.searchQuery.isEmpty) {
      return _buildDefaultView(state);
    } else {
      // Show search results
      return FoodSearchResultsWidget(
        searchResults: state.searchResults,
        userFoods: state.userFoods,
        catalogResults: state.catalogResults,
        openFoodFactsResults: state.openFoodFactsResults,
        isSearchingCatalog: state.isSearchingCatalog,
        isMyFoodsExpanded: state.isMyFoodsExpanded,
        searchQuery: state.searchQuery,
        onFoodTap: _selectFood,
        onFoodLongPress: (food) => _showUserFoodEditSheet(food),
        onFoodEdit: (food) => _showUserFoodEditSheet(food),
        onCatalogResultTap: _handleCatalogSelection,
        onOpenFoodFactsResultTap: _handleOpenFoodFactsSelection,
        onMyFoodsSectionToggle: () {
          ref.read(swapFoodControllerProvider(_params).notifier).toggleMyFoodsExpanded();
        },
        isUserFood: _isUserFood,
        showOpenFoodFactsButton: state.searchQuery.isNotEmpty &&
            state.openFoodFactsResults.isEmpty &&
            !state.isSearchingOpenFoodFacts,
        onSearchOpenFoodFacts: () => _onSearchButtonPressed(state.searchQuery),
      );
    }
  }

  Widget _buildDefaultView(SwapFoodState state) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      children: [
        // My Foods section (only if user has foods for this category)
        if (state.userFoods.isNotEmpty) ...[
          _buildMyFoodsSectionHeader(state),
          if (state.isMyFoodsExpanded)
            ...state.userFoods.map((food) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: FoodCardWidget(
                food: food,
                isUserFood: _isUserFood(food),
                onTap: () => _selectFood(food),
                onLongPress: () => _showUserFoodEditSheet(food),
                onEdit: () => _showUserFoodEditSheet(food),
              ),
            )),
          const SizedBox(height: AppSpacing.md),
        ],
        // Recommended Foods header
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            _isSwapping ? 'Recommended Alternatives' : 'Recommended Foods',
            style: AppTextStyles.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        // Recommended food items
        ...state.recommendations.map((food) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: FoodCardWidget(
            food: food,
            isUserFood: _isUserFood(food),
            onTap: () => _selectFood(food),
            onLongPress: () => _showUserFoodEditSheet(food),
            onEdit: () => _showUserFoodEditSheet(food),
          ),
        )),
      ],
    );
  }

  Widget _buildMyFoodsSectionHeader(SwapFoodState state) {
    return InkWell(
      onTap: () => ref.read(swapFoodControllerProvider(_params).notifier).toggleMyFoodsExpanded(),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(
              state.isMyFoodsExpanded
                  ? FontAwesomeIcons.chevronDown
                  : FontAwesomeIcons.chevronRight,
              size: AppIconSizes.sm,
              color: AppColors.orange,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'My Foods',
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
                '${state.userFoods.length}',
                style: AppTextStyles.smallLabel.copyWith(
                  color: AppColors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
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
          productTypeId: result.productType,
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


}
