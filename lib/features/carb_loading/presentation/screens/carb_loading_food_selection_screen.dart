import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:mealvana_endurance/shared/widgets/primary_button.dart';
import 'package:mealvana_endurance/theme/app_theme.dart';
import '../../../../shared/widgets/food_icon.dart';
import '../../../../shared/widgets/food_selection/food_search_bar.dart';
import '../providers/carb_loading_food_selection_controller.dart';
import '../../domain/meal_type.dart';
import '../../domain/carb_loading_food.dart';
import '../../domain/carb_loading_user_food.dart';
import '../../../nutrition_plan/domain/food.dart';
import '../../../../shared/database/app_database.dart' as db;

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

  void _incrementQuantity() {
    setState(() {
      _selectedQuantity += 0.5;
    });
    ref.read(carbLoadingFoodSelectionControllerProvider(_params).notifier)
      .updateQuantity(_selectedQuantity);
  }

  void _decrementQuantity() {
    if (_selectedQuantity > 0.5) {
      setState(() {
        _selectedQuantity -= 0.5;
      });
      ref.read(carbLoadingFoodSelectionControllerProvider(_params).notifier)
        .updateQuantity(_selectedQuantity);
    }
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
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        backgroundColor: AppTheme.baseCream,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: CustomAppBarBackButton(
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Add Food to $_mealTypeName',
          style: AppTheme.titleStyle.copyWith(
            color: AppTheme.primary900,
            fontSize: 18.sp,
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
            backgroundColor: AppTheme.primary600,
            icon: const Icon(Icons.add, color: AppTheme.baseWhite),
            label: Text(
              'Create Custom Food',
              style: AppTheme.textStyle.copyWith(
                color: AppTheme.baseWhite,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
        loading: () => null,
        error: (_, __) => null,
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
                FoodSearchBar(
                  controller: _searchController,
                  onSearch: _onSearchButtonPressed,
                  onChanged: _onSearchChanged,
                  onBarcodeScan: _onBarcodeScan,
                  hintText: 'Search foods...',
                  showClearButton: state.openFoodFactsResults.isNotEmpty,
                  onClear: _onClearSearch,
                ),

                SizedBox(height: 16.h),

                // Selected food details
                if (state.selectedFood != null && state.searchQuery.isEmpty) ...[
                  _buildSelectedFoodCard(state),
                  SizedBox(height: 24.h),
                ],

                // Open Food Facts search results
                if (state.openFoodFactsResults.isNotEmpty) ...[
                  Expanded(
                    child: _buildOpenFoodFactsResults(state),
                  ),
                  SizedBox(height: 16.h),
                ] else
                  // Local search results
                  Expanded(
                    child: _buildLocalSearchResults(state),
                  ),

                // Add button - only show when food is selected
                if (state.selectedFood != null && state.searchQuery.isEmpty) ...[
                  SizedBox(height: 16.h),
                  PrimaryButton(
                    text: 'Add to $_mealTypeName',
                    onPressed: _handleAddFood,
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

    return Container(
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
                imageUrl: imageUrl,
                size: 40.w,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  displayName,
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
              const Spacer(),
              // Decrement button
              Container(
                width: 36.w,
                height: 36.w,
                decoration: const BoxDecoration(
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
                decoration: const BoxDecoration(
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
          _buildNutrientRow('Carbohydrates', '${totalCarbs.toStringAsFixed(0)} g'),
        ],
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

  Widget _buildOpenFoodFactsResults(CarbLoadingFoodSelectionState state) {
    return ListView.separated(
      padding: EdgeInsets.all(16.w),
      itemCount: state.openFoodFactsResults.length,
      separatorBuilder: (context, index) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final result = state.openFoodFactsResults[index];
        return _buildSearchResultItem(result);
      },
    );
  }

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
              // Product image
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

              // Right chevron icon
              GestureDetector(
                onTap: () => _handleOpenFoodFactsSelection(result),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import food: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildLocalSearchResults(CarbLoadingFoodSelectionState state) {
    if (state.searchResults.isEmpty) {
      return Center(
        child: Text(
          state.searchQuery.isEmpty
              ? 'No foods available'
              : 'No foods found for "${state.searchQuery}"',
          style: TextStyle(
            fontSize: 16.sp,
            color: AppTheme.baseGrey,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      itemCount: state.searchResults.length,
      itemBuilder: (context, index) {
        final food = state.searchResults[index];
        return _buildFoodCard(food);
      },
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

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () => _selectFood(food),
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              // Food icon
              FoodIcon(
                imageUrl: imageUrl,
                size: 48.w,
              ),

              SizedBox(width: 16.w),

              // Food details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.baseBlack,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${carbsPerServing.toInt()}g carbs per serving',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppTheme.baseGrey,
                      ),
                    ),
                    if (badge != null) ...[
                      SizedBox(height: 4.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: isCustom ? AppTheme.highlight100 : AppTheme.primary100,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.primary900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Add icon
              Icon(
                Icons.add_circle,
                color: AppTheme.primary600,
                size: 28.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
