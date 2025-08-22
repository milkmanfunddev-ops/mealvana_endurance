import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import '../../../../theme/app_theme.dart';
import 'expandable_food_item.dart';

/// Widget for plan sections (Before Run, During Run, After Run)
class PlanSectionWidget extends StatelessWidget {
  const PlanSectionWidget({
    super.key,
    required this.section,
    this.onFoodItemTap,
  });

  final PlanSection section;
  final Function(String foodItemId)? onFoodItemTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: AppTheme.subtitleStyle.copyWith(
                      color: AppTheme.primary900,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (section.subtitle != null && section.subtitle!.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Text(
                      section.subtitle!,
                      style: AppTheme.noteStyle.copyWith(
                        color: AppTheme.primary600,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        
        SizedBox(height: 12.h),
        
        // Food Items List
        if (section.foodItems.isEmpty)
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
          ...section.foodItems.asMap().entries.map((entry) {
            final index = entry.key;
            final foodItem = entry.value;
            final isLastItem = index == section.foodItems.length - 1;
            
            return Column(
              children: [
                ExpandableFoodItem(
                  foodItem: foodItem,
                  onTap: () => onFoodItemTap?.call(foodItem.id),
                ),
                if (!isLastItem) SizedBox(height: 8.h),
              ],
            );
          }),
      ],
    );
  }
}