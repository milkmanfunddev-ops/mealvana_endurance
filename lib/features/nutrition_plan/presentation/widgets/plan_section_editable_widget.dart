import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import '../../../../theme/app_theme.dart';
import 'swipeable_food_item.dart';
import 'add_food_button.dart';
import 'section_subtitle_widget.dart';

/// Widget for individual plan sections with swipe functionality
/// Each section (Before Run, During Run, After Run) now supports swipe to delete/swap
class PlanSectionEditableWidget extends StatefulWidget {
  const PlanSectionEditableWidget({
    super.key,
    required this.section,
    required this.plan,
    this.onFoodItemTap,
    this.onSwapFood,
    this.onDeleteFood,
    this.onUpdateQuantity,
  });

  final PlanSection section;
  final NutritionPlan plan;
  final Function(String foodItemId)? onFoodItemTap;
  final Function(String foodItemId, String foodName)? onSwapFood;
  final Function(String foodItemId)? onDeleteFood;
  final Function(String foodItemId, double newQuantity)? onUpdateQuantity;
  
  @override
  State<PlanSectionEditableWidget> createState() => _PlanSectionEditableWidgetState();
}

class _PlanSectionEditableWidgetState extends State<PlanSectionEditableWidget> {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header (removed edit button)
        Column(
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
            SectionSubtitleWidget(
              section: widget.section,
              plan: widget.plan,
            ),
          ],
        ),
        
        SizedBox(height: 12.h),
        
        // Food Items List with swipe functionality
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
            final isFirstInBeforeRun = _sectionCategory == 'before_run' && index == 0;
            
            return Column(
              children: [
                SwipeableFoodItem(
                  foodItem: foodItem,
                  category: _sectionCategory,
                  isFirstInBeforeRun: isFirstInBeforeRun,
                  onQuantityChanged: (newQuantity) => widget.onUpdateQuantity?.call(foodItem.id, newQuantity),
                  onTap: () => widget.onFoodItemTap?.call(foodItem.id),
                  onSwap: () => widget.onSwapFood?.call(foodItem.id, foodItem.name),
                  onDelete: () => widget.onDeleteFood?.call(foodItem.id),
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