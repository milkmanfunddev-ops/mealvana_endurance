import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/nutrition_plan.dart';
import 'plan_sections_widget.dart';

/// Main container for nutrition plan display
/// White container with blue border matching Alex's design
/// Note: plan parameter is now ignored as child widgets watch the controller directly
class PlanContainer extends StatefulWidget {
  const PlanContainer({
    super.key,
    this.plan, // Made optional and ignored - child widgets watch controller
    this.onFoodItemTap,
    this.showMacroTargets = true,
    this.onSwapFood,
    this.onDeleteFood,
    this.onUpdateQuantity,
  });

  final NutritionPlan? plan; // Now optional and ignored
  final Function(String foodItemId)? onFoodItemTap;
  final bool showMacroTargets;
  final Function(String foodItemId, String foodName, String category)? onSwapFood;
  final Function(String foodItemId, String category)? onDeleteFood;
  final Function(String foodItemId, String category, double newQuantity)? onUpdateQuantity;
  
  @override
  State<PlanContainer> createState() => _PlanContainerState();
}

class _PlanContainerState extends State<PlanContainer> {
  
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
            // Plan sections - separate widget with plan parameter
            if (widget.plan != null)
              PlanSectionsWidget(
                plan: widget.plan!,
                onFoodItemTap: widget.onFoodItemTap,
                onSwapFood: widget.onSwapFood,
                onDeleteFood: widget.onDeleteFood,
                onUpdateQuantity: widget.onUpdateQuantity,
              ),
          ],
        ),
      ),
    );
  }
}