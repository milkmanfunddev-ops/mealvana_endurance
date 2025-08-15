import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/nutrition_plan.dart';
import 'plan_section_widget.dart';

/// Main container for nutrition plan display
/// White container with blue border matching Alex's design
class PlanContainer extends StatelessWidget {
  const PlanContainer({
    super.key,
    required this.plan,
    this.onFoodItemTap,
    this.showMacroTargets = true,
  });

  final NutritionPlan plan;
  final Function(String foodItemId)? onFoodItemTap;
  final bool showMacroTargets;

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
            // Plan Sections (no title or calories as per Alex's design)
            ...plan.sections.map((section) {
              final isLastSection = section == plan.sections.last;
              return Column(
                children: [
                  PlanSectionWidget(
                    section: section,
                    onFoodItemTap: onFoodItemTap,
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