import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/food_icon.dart';
import '../providers/swap_food_controller.dart';
import '../../domain/food.dart';

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
    ref.read(swapFoodControllerProvider(_params).notifier)
      .updateSearch(query);
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
          padding: EdgeInsets.all(16.w),
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
                // Search field
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.baseWhite,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppTheme.primary100,
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'search',
                      hintStyle: AppTheme.textStyle.copyWith(
                        color: AppTheme.baseGrey,
                        fontSize: 16.sp,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppTheme.baseGrey,
                        size: 20.sp,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 16.h),

                // Scan Barcode Button
                Container(
                  width: double.infinity,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: AppTheme.primary900,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: InkWell(
                    onTap: () async {
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
                    },
                    borderRadius: BorderRadius.circular(12.r),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          color: AppTheme.baseWhite,
                          size: 20.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Scan Barcode',
                          style: AppTheme.textStyle.copyWith(
                            color: AppTheme.baseWhite,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
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

                // Search results or recommended alternatives
                if (state.searchQuery.isNotEmpty) ...[
                  Text(
                    'Search Results',
                    style: AppTheme.subtitleStyle.copyWith(
                      color: AppTheme.primary900,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Expanded(
                    child: ListView.separated(
                      itemCount: state.searchResults.length,
                      separatorBuilder: (context, index) => SizedBox(height: 8.h),
                      itemBuilder: (context, index) {
                        final food = state.searchResults[index];
                        return _buildFoodItem(food);
                      },
                    ),
                  ),
                ] else ...[
                  Text(
                    'Recommended Alternatives',
                    style: AppTheme.subtitleStyle.copyWith(
                      color: AppTheme.primary900,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Expanded(
                    child: ListView.separated(
                      itemCount: state.availableFoods.length,
                      separatorBuilder: (context, index) => SizedBox(height: 8.h),
                      itemBuilder: (context, index) {
                        final food = state.availableFoods[index];
                        return _buildFoodItem(food);
                      },
                    ),
                  ),
                ],

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

  Widget _buildFoodItem(Food food) {
    return InkWell(
      onTap: () => _selectFood(food),
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppTheme.primary50.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            FoodIcon(
              imageUrl: food.imageUrl,
              size: 40.w,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                food.name,
                style: AppTheme.textStyle.copyWith(
                  color: AppTheme.baseBlack,
                  fontSize: 14.sp,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.primary900,
              size: 24.sp,
            ),
          ],
        ),
      ),
    );
  }
}