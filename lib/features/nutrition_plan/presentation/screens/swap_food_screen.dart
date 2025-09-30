import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/food_icon.dart';
import '../../../../shared/widgets/food_selection/food_search_bar.dart';
import '../../../../shared/widgets/food_selection/recommended_alternatives.dart';
import '../providers/swap_food_controller.dart';
import '../../domain/food.dart';
import '../../domain/food_item.dart';
import '../../../../shared/services/food_management/shared_food_search_service.dart';
import '../../../auth/application/auth_service.dart';
import '../../../../shared/widgets/scanned_food_category_sheet.dart';

class SwapFoodScreen extends ConsumerStatefulWidget {
  final String? foodToSwapId;
  final String? foodToSwapName;
  final String category; // 'before_run', 'during_run', 'after_run'
  
  const SwapFoodScreen({
    super.key,
    this.foodToSwapId,
    this.foodToSwapName,
    required this.category,
  });

  @override
  ConsumerState<SwapFoodScreen> createState() => _SwapFoodScreenState();
}

class _SwapFoodScreenState extends ConsumerState<SwapFoodScreen> {
  final _searchController = TextEditingController();
  double _selectedQuantity = 1.0;
  late final SwapFoodParams _params;

  @override
  void initState() {
    super.initState();
    _params = SwapFoodParams(
      category: widget.category,
      originalFoodId: widget.foodToSwapId,
      originalFoodName: widget.foodToSwapName,
    );
    // No need to manually load foods - controller auto-initializes
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // For real-time filtering (as user types)
    ref.read(swapFoodControllerProvider(_params).notifier)
      .updateSearch(query);
  }

  Future<void> _onSearchButtonPressed(String query) async {
    // When "Search" button is pressed - search Open Food Facts
    if (query.trim().isNotEmpty) {
      await ref.read(swapFoodControllerProvider(_params).notifier)
        .searchOpenFoodFacts(query.trim());
    }
  }

  void _onClearSearch() {
    _searchController.clear();
    ref.read(swapFoodControllerProvider(_params).notifier)
      .updateSearch('');
    ref.read(swapFoodControllerProvider(_params).notifier)
      .clearOpenFoodFactsResults();
  }

  Future<void> _onBarcodeScan() async {
    final result = await context.pushNamed<Food>(
      'barcode-scanner',
      extra: {
        'category': widget.category,
        'foodToSwapId': widget.foodToSwapId,
        'foodToSwapName': widget.foodToSwapName,
      },
    );

    // If a food was successfully scanned, select it with quantity 1
    if (result != null) {
      _selectFood(result);
      setState(() {
        _selectedQuantity = 1.0;
      });
    }
  }

  void _selectFood(Food food) {
    ref.read(swapFoodControllerProvider(_params).notifier)
      .selectFood(food);

    // Clear the search field when a food is selected
    _searchController.clear();
    // Update search to show recommended alternatives again
    _onSearchChanged('');

    // Reset quantity when selecting a new food
    setState(() {
      _selectedQuantity = food.servingAmount ?? 1.0;
    });
  }

  void _incrementQuantity() {
    setState(() {
      _selectedQuantity += 0.5;
    });
  }

  void _decrementQuantity() {
    if (_selectedQuantity > 0.5) {
      setState(() {
        _selectedQuantity -= 0.5;
      });
    }
  }

  Future<void> _handleAction() async {
    final controllerState = ref.read(swapFoodControllerProvider(_params));
    final selectedFood = controllerState.valueOrNull?.selectedFood;

    if (selectedFood == null) return;

    final controller = ref.read(swapFoodControllerProvider(_params).notifier);
    
    if (widget.foodToSwapId != null) {
      // Swap existing food
      await controller.swapFood(
        widget.foodToSwapId!,
        selectedFood,
        widget.category,
        customAmount: _selectedQuantity,
      );
    } else {
      // Add new food
      await controller.addFood(
        selectedFood,
        widget.category,
        customAmount: _selectedQuantity,
      );
    }

    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(swapFoodControllerProvider(_params));
    final isSwapping = widget.foodToSwapId != null;
    final title = isSwapping ? 'Swap ${widget.foodToSwapName ?? 'Food'}' : 'Add Food';
    final buttonText = isSwapping ? 'Swap food' : 'Add food';

    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        backgroundColor: AppTheme.baseCream,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: CustomAppBarBackButton(
          onPressed: () => context.pop(),
        ),
        title: Text(
          title,
          style: AppTheme.titleStyle.copyWith(
            color: AppTheme.primary900,
            fontSize: 18.sp,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 0.h),
          child: controllerState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error loading foods: $error'),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(swapFoodControllerProvider(_params)),
                    child: Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (state) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search bar with barcode scanner
                FoodSearchBar(
                  controller: _searchController,
                  onSearch: _onSearchButtonPressed, // Open Food Facts search when button pressed
                  onChanged: _onSearchChanged, // Real-time local filtering as user types
                  onBarcodeScan: _onBarcodeScan,
                  hintText: 'Search foods...',
                  showClearButton: state.openFoodFactsResults.isNotEmpty,
                  onClear: _onClearSearch,
                ),

                SizedBox(height: 16.h),

                // Selected food details - only show when not actively searching
                if (state.selectedFood != null && state.searchQuery.isEmpty) ...[
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppTheme.primary50.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            FoodIcon(
                              imageUrl: state.selectedFood!.imageUrl,
                              size: 40.w,
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text(
                                state.selectedFood!.generateQuantityDisplay(customAmount: _selectedQuantity),
                                style: AppTheme.textStyle.copyWith(
                                  color: AppTheme.baseBlack,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        // Quantity adjustment controls
                        Row(
                          children: [
                            Text(
                              'Quantity:',
                              style: AppTheme.textStyle.copyWith(
                                color: AppTheme.primary900,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Spacer(),
                            // Decrement button
                            Container(
                              width: 36.w,
                              height: 36.w,
                              decoration: BoxDecoration(
                                color: AppTheme.primary900,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.remove,
                                  color: Colors.white,
                                  size: 18.sp,
                                ),
                                onPressed: _decrementQuantity,
                              ),
                            ),
                            SizedBox(width: 16.w),
                            // Quantity display
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.primary100),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                _selectedQuantity == _selectedQuantity.toInt() 
                                    ? _selectedQuantity.toInt().toString()
                                    : _selectedQuantity.toStringAsFixed(1),
                                style: AppTheme.textStyle.copyWith(
                                  color: AppTheme.baseBlack,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            SizedBox(width: 16.w),
                            // Increment button
                            Container(
                              width: 36.w,
                              height: 36.w,
                              decoration: BoxDecoration(
                                color: AppTheme.primary900,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 18.sp,
                                ),
                                onPressed: _incrementQuantity,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        _buildNutrientRow('Carbohydrates', 
                          '${((state.selectedFood!.carbsPerServing ?? 0) * _selectedQuantity).toStringAsFixed(0)} g'),
                        SizedBox(height: 8.h),
                        _buildNutrientRow('Sodium', 
                          '${((state.selectedFood!.sodiumMg ?? 0) * _selectedQuantity).toStringAsFixed(0)} mg'),
                        SizedBox(height: 8.h),
                        _buildNutrientRow('Fluids', 
                          '${(((state.selectedFood!.fluidMlPerServing ?? 0) * _selectedQuantity) / 1000).toStringAsFixed(1)} L'),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                ],

                // Open Food Facts search results - show when available (no header, like food preferences)
                if (state.openFoodFactsResults.isNotEmpty) ...[
                  SizedBox(
                    height: 200.h, // Fixed height for Open Food Facts results
                    child: ListView.separated(
                      padding: EdgeInsets.all(16.w),
                      itemCount: state.openFoodFactsResults.length,
                      separatorBuilder: (context, index) => SizedBox(height: 12.h),
                      itemBuilder: (context, index) {
                        final result = state.openFoodFactsResults[index];
                        return _buildSearchResultItem(result);
                      },
                    ),
                  ),
                  SizedBox(height: 24.h),
                ],

                // Show filtered recommendations only when NOT showing Open Food Facts results
                if (state.openFoodFactsResults.isEmpty)
                  Expanded(
                    child: RecommendedAlternatives(
                      foods: state.searchResults, // This contains filtered results when searching, or recommendations when not
                      onFoodSelected: _selectFood,
                      preferences: state.preferences,
                      title: 'Recommended Alternatives',
                    ),
                  ),

                // Action button - only show when food is selected and not actively searching
                if (state.selectedFood != null && state.searchQuery.isEmpty) ...[
                  SizedBox(height: 16.h),
                  PrimaryButton(
                    text: buttonText,
                    onPressed: _handleAction,
                    width: double.infinity,
                  ),
                  SizedBox(height: 16.h),
                ],
              ],
            ),
          ),
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
          style: AppTheme.textStyle.copyWith(
            color: AppTheme.primary900,
            fontSize: 14.sp,
          ),
        ),
        Text(
          value,
          style: AppTheme.textStyle.copyWith(
            color: AppTheme.baseBlack,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Build search result item matching food preferences pattern
  Widget _buildSearchResultItem(dynamic result) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.baseWhite,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.primary100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Product image (if available)
              if (result.imageUrl?.isNotEmpty == true)
                Container(
                  width: 50.w,
                  height: 50.w,
                  margin: EdgeInsets.only(right: 12.w),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.r),
                    image: DecorationImage(
                      image: NetworkImage(result.imageUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.name.isNotEmpty ? result.name : 'Unknown Product',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.baseBlack,
                      ),
                    ),
                    if (result.brand?.isNotEmpty == true) ...[
                      SizedBox(height: 4.h),
                      Text(
                        result.brand!,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppTheme.primary100,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Right chevron icon for Open Food Facts results
              GestureDetector(
                onTap: () => _handleSearchResultTap(result),
                child: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppTheme.primary600,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    color: AppTheme.baseWhite,
                    size: 20.sp,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Handle search result tap - shows bottom sheet for nutritional verification
  Future<void> _handleSearchResultTap(dynamic result) async {
    if (!result.hasValidId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot load details for this product'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get product details using shared service
      final searchService = ref.read(sharedFoodSearchServiceProvider);

      // Get current user's device ID
      final authService = ref.read(authServiceProvider);
      final currentUser = await authService.getCurrentUser();
      final deviceId = currentUser?.id ?? 'unknown';

      // Add search result to user foods and get Food object
      final food = await searchService.addSearchResultToUserFoods(result, deviceId);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (food == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to load product details'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Convert Food to FoodItem for ScannedFoodCategorySheet
      final foodItem = _convertFoodToFoodItem(food);

      // Show category selection sheet
      if (mounted) {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => ScannedFoodCategorySheet(
            scannedFood: foodItem,
            context: widget.foodToSwapId != null ? 'swap_food' : 'add_food',
            fluidMlPerServing: foodItem.fluidMlPerServing,
            onSave: (categoryIds, finalFluidAmount, {carbsPerServing, proteinPerServing, fatPerServing, sodiumMg}) async {
              // The food is already saved by SharedFoodSearchService
              // Create updated food with verified nutrition values if provided
              final updatedFood = Food(
                id: food.id,
                name: food.name,
                imageAddress: food.imageAddress,
                description: food.description,
                instructions: food.instructions,
                servingAmount: food.servingAmount,
                displayName: food.displayName,
                displayNamePlural: food.displayNamePlural,
                servingUnit: food.servingUnit,
                servingUnitPlural: food.servingUnitPlural,
                servingQualifier: food.servingQualifier,
                beforeRunSuitable: food.beforeRunSuitable,
                duringRunSuitable: food.duringRunSuitable,
                carbsPerServing: carbsPerServing ?? food.carbsPerServing,
                proteinPerServing: proteinPerServing ?? food.proteinPerServing,
                fatPerServing: fatPerServing ?? food.fatPerServing,
                caloriesPerServing: food.caloriesPerServing,
                fluidMlPerServing: finalFluidAmount ?? food.fluidMlPerServing,
                sodiumMg: sodiumMg?.toInt() ?? food.sodiumMg,
                productTypeId: food.productTypeId,
                runPortable: food.runPortable,
                requiresPreparation: food.requiresPreparation,
                aidStationAvailable: food.aidStationAvailable,
                maxServingsBefore: food.maxServingsBefore,
                maxServingsDuring: food.maxServingsDuring,
                caffeineMg: food.caffeineMg,
                potassiumMg: food.potassiumMg,
                servingSize: food.servingSize,
              );

              // Select the food and clear Open Food Facts results
              if (mounted) {
                _selectFood(updatedFood);
                ref.read(swapFoodControllerProvider(_params).notifier).clearOpenFoodFactsResults();
                // Note: ScannedFoodCategorySheet handles closing itself via _handleSave()
              }
            },
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load product details'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Convert Food to FoodItem for compatibility with ScannedFoodCategorySheet
  FoodItem _convertFoodToFoodItem(Food food) {
    return FoodItem(
      id: food.id,
      name: food.name,
      imageAddress: food.imageAddress,
      description: food.description,
      instructions: food.instructions,
      categories: [],
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

}

