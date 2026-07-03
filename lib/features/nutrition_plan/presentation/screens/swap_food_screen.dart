import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/inputs/figma_search_bar.dart';
import '../../../../shared/screens/food_detail_screen.dart';
import '../../../../shared/controllers/food_search_controller.dart';
import '../../../../shared/widgets/food_search/unified_food_search_results.dart';
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
import '../widgets/swap_food/catalog_section_widget.dart';
import '../../../../shared/widgets/content_area.dart';

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

  /// When true, the screen does NOT write to an activity's nutrition plan on
  /// confirm. Instead it pops with a [SwapFoodSelection] (food + quantity) for
  /// the caller to consume — used by the personal-formula editor to reuse this
  /// full search/scan/import experience. [activityId] is unused in this mode.
  final bool returnSelection;

  const SwapFoodScreen({
    super.key,
    this.foodToSwapId,
    this.foodToSwapName,
    required this.category,
    required this.activityId,
    this.isNewActivity = false,
    this.isCoachView = false,
    this.returnSelection = false,
  });

  @override
  ConsumerState<SwapFoodScreen> createState() => _SwapFoodScreenState();
}

class _SwapFoodScreenState extends ConsumerState<SwapFoodScreen> {
  static const _searchControllerKey = 'swap_food';

  final TextEditingController _searchController = TextEditingController();
  double _selectedQuantity = 1.0;
  bool _isProcessing = false;
  bool _isSavingScannedFood =
      false; // Track when saving barcode/OpenFoodFacts result

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
      analytics.analytics.track(
        'swap_food_screen_viewed',
        properties: {
          'is_swapping': widget.foodToSwapId != null,
          'category': widget.category,
        },
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isSwapping => widget.foodToSwapId != null;

  String get _screenTitle =>
      _isSwapping ? 'Swap ${widget.foodToSwapName ?? 'Food'}' : 'Add Food';

  /// Seed the shared search controller with the food pool from swap controller
  void _seedSearchController(SwapFoodState state) {
    final searchNotifier = ref.read(
      foodSearchControllerProvider(_searchControllerKey).notifier,
    );
    // Endurance/general separation (audit §3): during-run swaps are pure
    // fueling — restrict search to fuel products so a potato salad can't be
    // planned mid-run. Before/after meals legitimately include real food, so
    // they keep the full pool.
    final baseCategory = widget.category.split(':').first;
    searchNotifier.setFilter(
      baseCategory == 'during_run'
          ? FoodSearchFilter.fuelOnly
          : FoodSearchFilter.all,
    );
    searchNotifier.updateFoodPool(
      allFoods: state.allFoodsForSearch ?? [],
      userFoods: state.allUserFoods,
    );
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

  /// Open create food screen with empty form
  Future<void> _openCreateFoodScreen() async {
    final uuid = DateTime.now().millisecondsSinceEpoch.toString();
    // Determine pre-selected categories based on current section
    final baseCategory = widget.category.split(':').first;
    final preSelectedCategories = <int>[
      if (baseCategory.startsWith('before')) 1,
      if (baseCategory.startsWith('during')) 2,
      if (baseCategory.startsWith('after')) 3,
      if (!baseCategory.startsWith('before') &&
          !baseCategory.startsWith('during') &&
          !baseCategory.startsWith('after')) ...[
        1,
        2,
        3,
      ],
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
      setState(() {
        _isSavingScannedFood = true;
      });

      try {
        final categoryStrings = result.categoryIds.map((id) {
          switch (id) {
            case 1:
              return 'before_run';
            case 2:
              return 'during_run';
            case 3:
              return 'after_run';
            default:
              return 'before_run'; // DB categories remain *_run
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
        await ref
            .read(swapFoodControllerProvider(_params).notifier)
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
          setState(() {
            _isSavingScannedFood = false;
          });
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
        await ref
            .read(swapFoodControllerProvider(_params).notifier)
            .refreshFoods(selectAfterRefresh: food, expandMyFoods: true);

        _searchController.clear();
        _onClearSearch();
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
    _onClearSearch();
    setState(() {
      _selectedQuantity = 1.0;
    });
  }

  Future<void> _handleConfirm() async {
    // Prevent double-tap
    if (_isProcessing) return;

    final controllerState = ref.read(swapFoodControllerProvider(_params));
    final state = controllerState.value;

    if (state?.selectedFood == null) return;

    final food = state!.selectedFood!;

    // Return-selection mode (e.g. personal-formula editor): pop with the
    // chosen food + quantity instead of mutating an activity's plan.
    if (widget.returnSelection) {
      Navigator.of(context).pop(
        SwapFoodSelection(
          food: food,
          quantity: _selectedQuantity,
          isUserFood: state.userFoodIds.contains(food.id),
          replacedFoodId: _isSwapping ? widget.foodToSwapId : null,
        ),
      );
      return;
    }

    // IMPORTANT: Capture references BEFORE async operation to avoid context issues
    // Capture the navigator with rootNavigator to ensure we pop from correct level
    final navigator = Navigator.of(context, rootNavigator: true);

    setState(() {
      _isProcessing = true;
    });

    try {
      if (_isSwapping) {
        await ref
            .read(swapFoodControllerProvider(_params).notifier)
            .swapFood(
              _params,
              widget.foodToSwapId!,
              food,
              widget.category,
              customAmount: _selectedQuantity,
            );
      } else {
        await ref
            .read(swapFoodControllerProvider(_params).notifier)
            .addFood(
              _params,
              food,
              widget.category,
              customAmount: _selectedQuantity,
            );
      }

      if (mounted) {
        MealvanaSnackbar.showSuccess(
          context,
          _isSwapping
              ? 'Food swapped successfully!'
              : 'Food added successfully!',
        );
        navigator.pop();
      }
    } catch (e, stackTrace) {
      debugPrint('SwapFoodScreen: confirm failed: $e\n$stackTrace');
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        MealvanaSnackbar.showError(
          context,
          'Failed to ${_isSwapping ? 'swap' : 'add'} food: $e',
        );
      }
    }
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
            productType: result.productTypeId,
          ),
          mode: FoodDetailMode.addFromSearch,
          screenContext: _isSwapping
              ? FoodDetailContext.swapFood
              : FoodDetailContext.addFood,
          preSelectedCategories: preCheckedCategories,
          showCategories: true,
          showProductType: true,
        ),
      ),
    );

    if (detailResult is FoodDetailResult && mounted) {
      setState(() {
        _isSavingScannedFood = true;
      });
      try {
        final categoryStrings = detailResult.categoryIds.map((id) {
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
        await ref
            .read(swapFoodControllerProvider(_params).notifier)
            .refreshFoods(selectAfterRefresh: food, expandMyFoods: true);

        _searchController.clear();
        _onClearSearch();
        if (mounted) {
          MealvanaSnackbar.showSuccess(context, '${result.title} added!');
        }
      } catch (e) {
        if (mounted) {
          MealvanaSnackbar.showError(context, 'Failed to save food: $e');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSavingScannedFood = false;
          });
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
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );
      }

      // Fetch product details
      final productDetailService = ref.read(productDetailServiceProvider);
      final apiProduct = await productDetailService.getProductDetails(
        openFoodFactsId: result.id,
      );

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
            'screenContext': _isSwapping
                ? FoodDetailContext.swapFood
                : FoodDetailContext.addFood,
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
      await ref
          .read(swapFoodControllerProvider(_params).notifier)
          .refreshFoods(selectAfterRefresh: food, expandMyFoods: true);

      // Reset quantity after selection
      setState(() {
        _selectedQuantity = 1.0;
      });

      // Clear search
      _searchController.clear();
      _onClearSearch();

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
    final controllerState = ref.watch(swapFoodControllerProvider(_params));
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
          _screenTitle,
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: ContentArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: controllerState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _buildErrorState(error),
            data: (state) {
              // Seed search controller whenever data loads/reloads
              _seedSearchController(state);
              return _buildContent(state, searchState);
            },
          ),
        ),
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
            FaIcon(
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
              onPressed: () =>
                  ref.invalidate(swapFoodControllerProvider(_params)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(SwapFoodState state, FoodSearchState searchState) {
    final hasSelectedFood =
        state.selectedFood != null &&
        searchState.searchQuery.isEmpty &&
        searchState.openFoodFactsResults.isEmpty;

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
                  triggerSearchOnKeyboardSubmit: false,
                  enableAutoSearch: false,
                  hintText: 'Search for food...',
                  useDarkStyle:
                      Theme.of(context).brightness == Brightness.dark,
                  fieldKey: const ValueKey('swap_food.search_field'),
                ),

                // Clear search button (when showing OpenFoodFacts results)
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

                // Create custom food button
                const SizedBox(height: AppSpacing.xs),
                Center(
                  child: TextButton.icon(
                    onPressed: _openCreateFoodScreen,
                    icon: const FaIcon(
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
                      : UnifiedFoodSearchResults(
                          controllerKey: _searchControllerKey,
                          userFoodItemBuilder: (food) => FoodCardWidget(
                            key: ValueKey('swap_food.food_tile_${food.id}'),
                            food: food,
                            isUserFood: _isUserFood(food, state),
                            onTap: () => _selectFood(food),
                            onLongPress: () => _showUserFoodEditSheet(food),
                            onEdit: () => _showUserFoodEditSheet(food),
                          ),
                          templateFoodItemBuilder: (food) => FoodCardWidget(
                            key: ValueKey('swap_food.food_tile_${food.id}'),
                            food: food,
                            isUserFood: false,
                            onTap: () => _selectFood(food),
                          ),
                          catalogItemBuilder: (result) => CatalogCard(
                            result: result,
                            onTap: () => _handleCatalogSelection(result),
                          ),
                          onSearchOpenFoodFacts: () =>
                              _onSearchButtonPressed(searchState.searchQuery),
                          onOpenFoodFactsResultTap:
                              _handleOpenFoodFactsSelection,
                          isMyFoodsExpanded: state.isMyFoodsExpanded,
                          onMyFoodsSectionToggle: () {
                            ref
                                .read(swapFoodControllerProvider(_params)
                                    .notifier)
                                .toggleMyFoodsExpanded();
                          },
                          emptyQueryContent: _buildDefaultView(state),
                        )),
          ),

          // Confirm button (only when food is selected and no active search)
          if (hasSelectedFood && !_isSavingScannedFood) ...[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: KylePrimaryButton(
                key: const ValueKey('swap_food.confirm_button'),
                text: _isSwapping ? 'SWAP FOOD' : 'ADD FOOD',
                isLoading: _isProcessing,
                onPressed: _handleConfirm,
                isFullWidth: true,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build scrollable content when a food is selected
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
          ref
              .read(swapFoodControllerProvider(_params).notifier)
              .clearSelection();
        },
      ),
    );
  }

  Widget _buildDefaultView(SwapFoodState state) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      children: [
        // My Foods section (only if user has foods for this category)
        if (state.userFoods.isNotEmpty) ...[
          _buildMyFoodsSectionHeader(state),
          if (state.isMyFoodsExpanded)
            ...state.userFoods.map(
              (food) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: FoodCardWidget(
                  food: food,
                  isUserFood: _isUserFood(food, state),
                  onTap: () => _selectFood(food),
                  onLongPress: () => _showUserFoodEditSheet(food),
                  onEdit: () => _showUserFoodEditSheet(food),
                ),
              ),
            ),
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
        ...state.recommendations.map(
          (food) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: FoodCardWidget(
              food: food,
              isUserFood: _isUserFood(food, state),
              onTap: () => _selectFood(food),
              onLongPress: () => _showUserFoodEditSheet(food),
              onEdit: () => _showUserFoodEditSheet(food),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMyFoodsSectionHeader(SwapFoodState state) {
    return InkWell(
      onTap: () => ref
          .read(swapFoodControllerProvider(_params).notifier)
          .toggleMyFoodsExpanded(),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(
              state.isMyFoodsExpanded
                  ? FontAwesomeIcons.chevronDown.data
                  : FontAwesomeIcons.chevronRight.data,
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
  bool _isUserFood(Food food, SwapFoodState state) {
    if (state.userFoodIds.isNotEmpty) {
      return state.userFoodIds.contains(food.id);
    }
    return false;
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
        await ref
            .read(swapFoodControllerProvider(_params).notifier)
            .refreshFoods();

        if (mounted) {
          MealvanaSnackbar.showSuccess(context, '${food.name} deleted');
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
          productTypeId: result.productType,
          categoryIds: result.categoryIds,
        );

        // Refresh foods to reflect changes
        await ref
            .read(swapFoodControllerProvider(_params).notifier)
            .refreshFoods();

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
