import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/nutrition_plan.dart';
import 'plan_section_editable_widget.dart';

/// Main container for nutrition plan display
/// White container with blue border matching Alex's design
class PlanContainer extends StatefulWidget {
  const PlanContainer({
    super.key,
    required this.plan,
    this.onFoodItemTap,
    this.showMacroTargets = true,
    this.onSwapFood,
    this.onDeleteFood,
  });

  final NutritionPlan plan;
  final Function(String foodItemId)? onFoodItemTap;
  final bool showMacroTargets;
  final Function(String foodItemId, String foodName, String category)? onSwapFood;
  final Function(String foodItemId, String category)? onDeleteFood;
  
  @override
  State<PlanContainer> createState() => _PlanContainerState();
}

class _PlanContainerState extends State<PlanContainer> {
  String _getSectionCategory(String sectionTitle) {
    switch (sectionTitle) {
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
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppTheme.baseWhite,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppTheme.primary900,
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary600.withValues(alpha: 0.1),
            blurRadius: 16.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan Sections with individual edit states
            ...widget.plan.sections.map((section) {
              final isLastSection = section == widget.plan.sections.last;
              final category = _getSectionCategory(section.title);
              return Column(
                children: [
                  PlanSectionEditableWidget(
                    section: section,
                    onFoodItemTap: widget.onFoodItemTap,
                    onSwapFood: (foodId, foodName) => 
                      widget.onSwapFood?.call(foodId, foodName, category),
                    onDeleteFood: (foodId) => 
                      widget.onDeleteFood?.call(foodId, category),
                  ),
                  if (!isLastSection) SizedBox(height: 24.h),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}