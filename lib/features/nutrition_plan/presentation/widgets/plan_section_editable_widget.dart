import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/macro_targets.dart' as targets_model;
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
    this.macroTargets,
    this.onFoodItemTap,
    this.onSwapFood,
    this.onDeleteFood,
    this.onUpdateQuantity,
    this.onAddFood,
  });

  final PlanSection section;
  final NutritionPlan plan;
  final targets_model.MacroTargets? macroTargets;
  final Function(String foodItemId)? onFoodItemTap;
  final Function(String foodItemId, String foodName)? onSwapFood;
  final Function(String foodItemId)? onDeleteFood;
  final Function(String foodItemId, double newQuantity)? onUpdateQuantity;

  /// Overrides the default "+ Add Food" action. When null, falls back to the
  /// activity-plan behavior (navigate to /swap-food with the plan's activityId).
  /// Callers without an activity (e.g. the personal-formula editor) inject their
  /// own add flow here.
  final VoidCallback? onAddFood;
  
  @override
  State<PlanSectionEditableWidget> createState() => _PlanSectionEditableWidgetState();
}

class _PlanSectionEditableWidgetState extends State<PlanSectionEditableWidget> {
  /// Get section category from section.id (sport-agnostic)
  String get _sectionCategory {
    // section.id is already the category: 'before_run', 'during_run', 'after_run'
    if (widget.section.id.contains('during')) return 'during_run';
    if (widget.section.id.contains('after')) return 'after_run';
    return 'before_run';
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
              macroTargets: widget.macroTargets,
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
              // Caller-provided add flow (e.g. personal-formula editor) wins.
              if (widget.onAddFood != null) {
                widget.onAddFood!();
                return;
              }
              final activityId = widget.plan.activityId;
              if (activityId == null) {
                return;
              }
              // Navigate to swap/add screen
              context.push('/swap-food', extra: {
                'category': _sectionCategory,
                'activityId': activityId,
              });
            },
          ),
        ),
      ],
    );
  }
}
