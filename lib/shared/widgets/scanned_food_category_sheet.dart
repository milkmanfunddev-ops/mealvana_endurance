import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../features/nutrition_plan/domain/food_item.dart';
import '../../theme/app_theme.dart';
import '../widgets/primary_button.dart';

/// Shared full-screen bottom modal sheet for category selection
/// Used by both onboarding and swap food screens when scanning products
class ScannedFoodCategorySheet extends ConsumerStatefulWidget {
  const ScannedFoodCategorySheet({
    super.key,
    required this.scannedFood,
    required this.context,
    required this.onSave,
    this.fluidMlPerServing,
  });

  final FoodItem scannedFood;
  final String context; // 'onboarding' or 'swap_food'
  final Function(List<int> categoryIds, double? fluidMlPerServing, {
    double? carbsPerServing,
    double? proteinPerServing,
    double? fatPerServing,
    double? sodiumMg,
  }) onSave;
  final double? fluidMlPerServing;

  @override
  ConsumerState<ScannedFoodCategorySheet> createState() => _ScannedFoodCategorySheetState();
}

class _ScannedFoodCategorySheetState extends ConsumerState<ScannedFoodCategorySheet> {
  // Category selections - all checked by default as per requirements
  final Map<int, bool> _selectedCategories = {
    1: true, // Before Run
    2: true, // During Run
    3: true, // After Run
  };

  late TextEditingController _fluidController;
  late TextEditingController _carbsController;
  late TextEditingController _proteinController;
  late TextEditingController _fatController;
  late TextEditingController _sodiumController;
  bool _isBeverage = false;

  @override
  void initState() {
    super.initState();

    // Initialize fluid controller with provided value or 0
    _fluidController = TextEditingController(
      text: widget.fluidMlPerServing?.toStringAsFixed(0) ?? '0',
    );

    // Initialize nutrition controllers with pre-filled values from Open Food Facts
    _carbsController = TextEditingController(
      text: (widget.scannedFood.carbsPerServing ?? 0).toStringAsFixed(1),
    );
    _proteinController = TextEditingController(
      text: (widget.scannedFood.proteinPerServing ?? 0).toStringAsFixed(1),
    );
    _fatController = TextEditingController(
      text: (widget.scannedFood.fatPerServing ?? 0).toStringAsFixed(1),
    );
    _sodiumController = TextEditingController(
      text: (widget.scannedFood.sodiumMg ?? 0).toStringAsFixed(0),
    );

    // Check if this is a beverage based on fluid content
    _isBeverage = (widget.fluidMlPerServing ?? 0) > 0;
  }

  @override
  void dispose() {
    _fluidController.dispose();
    _carbsController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _sodiumController.dispose();
    super.dispose();
  }

  bool get _hasValidSelection => _selectedCategories.values.any((selected) => selected);

  double? get _fluidAmount {
    final text = _fluidController.text.trim();
    if (text.isEmpty || !_isBeverage) return null;
    return double.tryParse(text);
  }

  void _handleSave() {
    if (!_hasValidSelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selectedCategoryIds = _selectedCategories.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    // Parse edited nutrition values
    final carbs = double.tryParse(_carbsController.text) ?? 0.0;
    final protein = double.tryParse(_proteinController.text) ?? 0.0;
    final fat = double.tryParse(_fatController.text) ?? 0.0;
    final sodium = double.tryParse(_sodiumController.text) ?? 0.0;

    widget.onSave(
      selectedCategoryIds,
      _fluidAmount,
      carbsPerServing: carbs,
      proteinPerServing: protein,
      fatPerServing: fat,
      sodiumMg: sodium,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: AppTheme.baseCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 8.h),
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppTheme.baseGrey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.context == 'swap_food' ? 'Swap Food' : 'Add Food',
                    style: AppTheme.textStyle.copyWith(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.baseBlack,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: AppTheme.baseGrey,
                    size: 24.sp,
                  ),
                ),
              ],
            ),
          ),

          Divider(color: AppTheme.baseGrey.withValues(alpha: 0.2), height: 1),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Scanned food details
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppTheme.baseWhite,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppTheme.primary100.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Food name
                        Text(
                          widget.scannedFood.name,
                          style: AppTheme.textStyle.copyWith(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.baseBlack,
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // Editable nutrition fields
                        Text(
                          'Nutrition Information',
                          style: AppTheme.textStyle.copyWith(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.baseBlack,
                          ),
                        ),
                        SizedBox(height: 12.h),

                        // Carbs and Protein row
                        Row(
                          children: [
                            Expanded(
                              child: _buildNutritionField(
                                controller: _carbsController,
                                label: 'Carbs',
                                suffix: 'g',
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: _buildNutritionField(
                                controller: _proteinController,
                                label: 'Protein',
                                suffix: 'g',
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),

                        // Fat and Sodium row
                        Row(
                          children: [
                            Expanded(
                              child: _buildNutritionField(
                                controller: _fatController,
                                label: 'Fat',
                                suffix: 'g',
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: _buildNutritionField(
                                controller: _sodiumController,
                                label: 'Sodium',
                                suffix: 'mg',
                              ),
                            ),
                          ],
                        ),

                        // Fluid amount field for beverages
                        if (_isBeverage) ...[
                          SizedBox(height: 16.h),
                          Text(
                            'Fluid Amount (ml)',
                            style: AppTheme.textStyle.copyWith(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.baseBlack,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          TextFormField(
                            controller: _fluidController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'Enter fluid amount',
                              suffixText: 'ml',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                                borderSide: BorderSide(color: AppTheme.baseGrey.withValues(alpha: 0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                                borderSide: BorderSide(color: AppTheme.primary600),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                            ),
                            style: AppTheme.textStyle.copyWith(
                              fontSize: 16.sp,
                              color: AppTheme.baseBlack,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: 24.h),

                  // Category selection
                  Text(
                    'When would you eat this?',
                    style: AppTheme.textStyle.copyWith(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.baseBlack,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Select one or more categories (at least one required)',
                    style: AppTheme.textStyle.copyWith(
                      fontSize: 14.sp,
                      color: AppTheme.baseGrey,
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Category checkboxes
                  _buildCategoryCheckbox(1, 'Before Run', 'Fuel up before your workout'),
                  SizedBox(height: 12.h),
                  _buildCategoryCheckbox(2, 'During Run', 'Energy during long workouts'),
                  SizedBox(height: 12.h),
                  _buildCategoryCheckbox(3, 'After Run', 'Recovery after your workout'),
                ],
              ),
            ),
          ),

          // Bottom action area
          Container(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 34.h),
            decoration: BoxDecoration(
              color: AppTheme.baseWhite,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                onPressed: _hasValidSelection ? _handleSave : null,
                text: widget.context == 'onboarding'
                    ? 'Add to My Foods'
                    : widget.context == 'swap_food'
                        ? 'Swap Food'
                        : 'Add Food',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionField({
    required TextEditingController controller,
    required String label,
    required String suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.textStyle.copyWith(
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: AppTheme.baseGrey,
          ),
        ),
        SizedBox(height: 4.h),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: suffix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: AppTheme.baseGrey.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: AppTheme.primary600),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            isDense: true,
          ),
          style: AppTheme.textStyle.copyWith(
            fontSize: 14.sp,
            color: AppTheme.baseBlack,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCheckbox(int categoryId, String title, String subtitle) {
    final isSelected = _selectedCategories[categoryId] ?? false;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategories[categoryId] = !isSelected;
        });
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary50
              : AppTheme.baseWhite,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary600
                : AppTheme.baseGrey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24.w,
              height: 24.w,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary600 : Colors.transparent,
                borderRadius: BorderRadius.circular(4.r),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primary600
                      : AppTheme.baseGrey.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16.sp,
                    )
                  : null,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.textStyle.copyWith(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.baseBlack,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: AppTheme.textStyle.copyWith(
                      fontSize: 14.sp,
                      color: AppTheme.baseGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}