import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/nutrition_plan.dart';
import '../../domain/macro_targets.dart' as targets_model;
import 'plan_section_editable_widget.dart';

/// Standalone plan sections widget that takes plan as parameter
/// This prevents rebuilding when unrelated parts of the plan change
class PlanSectionsWidget extends StatelessWidget {
  const PlanSectionsWidget({
    super.key,
    required this.plan,
    this.macroTargets,
    this.onFoodItemTap,
    this.onSwapFood,
    this.onDeleteFood,
    this.onUpdateQuantity,
  });

  final NutritionPlan plan;
  final targets_model.MacroTargets? macroTargets;
  final Function(String foodItemId)? onFoodItemTap;
  final Function(String foodItemId, String foodName, String category)?
  onSwapFood;
  final Function(String foodItemId, String category)? onDeleteFood;
  final Function(String foodItemId, String category, double newQuantity)?
  onUpdateQuantity;

  @override
  Widget build(BuildContext context) {
    if (plan.sections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Plan Sections with individual edit states
        ...plan.sections.map((section) {
          final isLastSection = section == plan.sections.last;
          final category = _getSectionCategory(section.id);
          return Column(
            children: [
              PlanSectionEditableWidget(
                section: section,
                plan: plan,
                macroTargets: macroTargets,
                onFoodItemTap: onFoodItemTap,
                onSwapFood: (foodId, foodName) =>
                    onSwapFood?.call(foodId, foodName, category),
                onDeleteFood: (foodId) => onDeleteFood?.call(foodId, category),
                onUpdateQuantity: (foodId, newQuantity) =>
                    onUpdateQuantity?.call(foodId, category, newQuantity),
              ),
              if (!isLastSection) SizedBox(height: 24.h),
            ],
          );
        }),
      ],
    );
  }

  /// Get section category from section id (sport-agnostic)
  String _getSectionCategory(String sectionId) {
    // section.id is already the category: 'before_run', 'during_run', 'after_run'
    if (sectionId.contains('during')) return 'during_run';
    if (sectionId.contains('after')) return 'after_run';
    return 'before_run';
  }
}
