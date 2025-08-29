import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import '../../../../theme/app_theme.dart';
import 'expandable_food_item.dart';
import 'add_food_button.dart';

/// Widget for individual plan sections with its own edit state
/// Each section (Before Run, During Run, After Run) manages its own edit mode
class PlanSectionEditableWidget extends StatefulWidget {
  const PlanSectionEditableWidget({
    super.key,
    required this.section,
    this.onFoodItemTap,
    this.onSwapFood,
    this.onDeleteFood,
  });

  final PlanSection section;
  final Function(String foodItemId)? onFoodItemTap;
  final Function(String foodItemId, String foodName)? onSwapFood;
  final Function(String foodItemId)? onDeleteFood;
  
  @override
  State<PlanSectionEditableWidget> createState() => _PlanSectionEditableWidgetState();
}

class _PlanSectionEditableWidgetState extends State<PlanSectionEditableWidget> {
  bool _isEditMode = false;

  String get _sectionCategory {
    switch (widget.section.title) {
      case 'Before Run':
        return 'before_run';
      case 'During Run':
        return 'during_run';
      case 'After Run':
        return 'after_run';
      default:
        return 'before_run';
    }
  }

  /// Calculate totals for this section
  Map<String, int> _calculateSectionTotals() {
    int totalCarbs = 0;
    int totalProtein = 0;
    int totalCalories = 0;
    int totalSodium = 0;
    int totalFluids = 0;

    for (final foodItem in widget.section.foodItems) {
      final nutrition = foodItem.nutritionalInfo;
      if (nutrition != null) {
        totalCarbs += nutrition.carbs ?? 0;
        totalProtein += nutrition.protein ?? 0;
        totalCalories += nutrition.calories ?? 0;
        totalSodium += nutrition.sodium ?? 0;
        totalFluids += (nutrition.fluids ?? 0).toInt();
      }
    }

    return {
      'carbs': totalCarbs,
      'protein': totalProtein,
      'calories': totalCalories,
      'sodium': totalSodium,
      'fluids': totalFluids,
    };
  }

  /// Get the appropriate subtitle with calculated totals
  String _getDynamicSubtitle() {
    final totals = _calculateSectionTotals();
    final carbs = totals['carbs']!;
    final protein = totals['protein']!;
    final fluids = totals['fluids']!;

    switch (widget.section.title) {
      case 'Before Run':
        return 'Pre-run fueling (${carbs}g carbs, ${protein}g protein)';
      case 'During Run':
        return 'Total: ${carbs}g carbs, ${fluids}ml fluids';
      case 'After Run':
        return 'Recovery (${carbs}g carbs, ${protein}g protein)';
      default:
        return widget.section.subtitle ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with individual edit button
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.section.title,
                    style: AppTheme.subtitleStyle.copyWith(
                      color: AppTheme.primary900,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    _getDynamicSubtitle(),
                    style: AppTheme.noteStyle.copyWith(
                      color: AppTheme.primary600,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Individual edit button for this section
            IconButton(
              icon: Icon(
                _isEditMode ? Icons.done : Icons.edit,
                color: AppTheme.primary900, // Changed from primary600 to primary900
                size: 20.sp,
              ),
              onPressed: () {
                setState(() {
                  _isEditMode = !_isEditMode;
                });
              },
            ),
          ],
        ),
        
        SizedBox(height: 12.h),
        
        // Food Items List
        if (widget.section.foodItems.isEmpty)
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppTheme.baseCream.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: AppTheme.baseGrey.withValues(alpha: 0.2),
              ),
            ),
            child: Center(
              child: Text(
                'No items planned for this section',
                style: AppTheme.noteStyle.copyWith(
                  color: AppTheme.baseGrey,
                  fontSize: 14.sp,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          )
        else
          ...widget.section.foodItems.asMap().entries.map((entry) {
            final index = entry.key;
            final foodItem = entry.value;
            final isLastItem = index == widget.section.foodItems.length - 1;
            
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ExpandableFoodItem(
                        foodItem: foodItem,
                        onTap: () => widget.onFoodItemTap?.call(foodItem.id),
                      ),
                    ),
                    if (_isEditMode) ...[
                      // Minimal spacing between food item and swap button
                      SizedBox(width: 4.w),
                      // Circular swap button with primary900 background
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
                            Icons.swap_horiz,
                            color: Colors.white,
                            size: 18.sp,
                          ),
                          onPressed: () => widget.onSwapFood?.call(foodItem.id, foodItem.name),
                        ),
                      ),
                      // Minimal spacing between swap and trash button
                      SizedBox(width: 4.w),
                      // Trash button with highlight background
                      Container(
                        width: 36.w,
                        height: 36.w,
                        decoration: BoxDecoration(
                          color: AppTheme.highlight100,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.delete_outline,
                            color: AppTheme.primary900,
                            size: 18.sp,
                          ),
                          onPressed: () => widget.onDeleteFood?.call(foodItem.id),
                        ),
                      ),
                      // Minimal spacing from right edge
                      SizedBox(width: 4.w),
                    ],
                  ],
                ),
                if (!isLastItem) SizedBox(height: 8.h),
              ],
            );
          }),
        
        SizedBox(height: 12.h),
        
        // Add button aligned to the left
        Align(
          alignment: Alignment.centerLeft,
          child: AddFoodButton(
            onPressed: () {
              // Navigate to swap/add screen
              context.push('/swap-food', extra: {
                'category': _sectionCategory,
              });
            },
          ),
        ),
      ],
    );
  }
}