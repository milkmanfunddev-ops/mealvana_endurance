import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/macro_targets.dart' as targets_model;
import '../../domain/nutrition_plan.dart';
import '../utils/activity_detail_helpers.dart';
import 'package:mealvana_endurance/shared/utils/unit_formatter.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';

/// Macro targets display widget with progress bars matching original design
/// Fixed to properly use detailed MacroTargets and correct unit conversions
class MacroTargetsWidget extends StatelessWidget {
  const MacroTargetsWidget({
    super.key,
    this.plan,
    this.targets,
    this.useMetric = false,
  });

  final NutritionPlan? plan;
  final targets_model.MacroTargets? targets;
  final bool useMetric;

  @override
  Widget build(BuildContext context) {
    if (targets == null) {
      return const SizedBox.shrink();
    }
    
    return _buildMacroTargetsWithProgressBars(targets!, plan);
  }

  Widget _buildMacroTargetsWithProgressBars(targets_model.MacroTargets detailedTargets, NutritionPlan? plan) {
    // Calculate current values from food items in ALL plan sections (NUMERATOR - actual consumption)
    // This sums nutrition from food items across all three phases: before + during + after
    int currentCarbs = 0;
    int currentSodium = 0;
    double currentFluids = 0.0; // in ml

    if (plan != null) {
      for (final section in plan.sections) {
        DebugLogger.info('🔍 MacroTargetsWidget: Processing ${section.title} section with ${section.foodItems.length} food items');
        for (final foodItem in section.foodItems) {
          final nutrition = foodItem.nutritionalInfo;
          if (nutrition != null) {
            final itemCarbs = nutrition.carbs ?? 0;
            final itemSodium = nutrition.sodium ?? 0;
            final itemFluids = nutrition.fluids ?? 0.0;

            DebugLogger.info('  📊 ${foodItem.name} (${foodItem.quantity}): ${itemSodium}mg sodium, ${itemFluids}ml fluids, ${itemCarbs}g carbs');

            currentCarbs += itemCarbs;
            currentSodium += itemSodium;
            currentFluids += itemFluids; // This is in ml from FoodItemData
          }
        }
      }
      DebugLogger.info('🎯 MacroTargetsWidget TOTALS: ${currentSodium}mg sodium, ${currentFluids.round()}ml fluids, ${currentCarbs}g carbs');
    }

    // Target values from detailed targets (DENOMINATOR - what should be consumed)
    // Sum ALL phases: pre-run + during-run + post-run
    final targetCarbs = (detailedTargets.preRun.carbsG +
                        detailedTargets.duringRun.carbTotalG +
                        detailedTargets.postRun.carbsG).round();

    final targetSodium = (detailedTargets.preRun.sodiumMg +
                         detailedTargets.duringRun.sodiumTotalMg +
                         detailedTargets.postRun.sodiumMg).round();

    final targetFluids = (detailedTargets.preRun.fluidsMl +
                         detailedTargets.duringRun.fluidTotalMl +
                         detailedTargets.postRun.fluidsMl).round(); // in ml

    // Widget now correctly calculates:
    // - NUMERATOR (current): Sum of actual food item nutrition across all phases (changes when user edits plan)
    // - DENOMINATOR (targets): Sum of ALL phases from generate-macros detailed macro targets (constant)
    // - Units: ml for fluids, mg for sodium, g for carbs

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(20.w),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Macro targets',
            style: AppTheme.subtitleStyle.copyWith(
              color: AppTheme.primary900,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 20.h),

          // Carbohydrates progress bar
          _buildProgressItem(
            'Carbohydrates',
            currentCarbs,
            targetCarbs,
            'g',
            AppTheme.carbsColor,
          ),
          SizedBox(height: 16.h),

          // Sodium progress bar (aggregate total — ratio-based coloring only)
          _buildProgressItem(
            'Sodium',
            currentSodium,
            targetSodium,
            'mg',
            AppTheme.primary600,
          ),
          SizedBox(height: 16.h),

          // Fluids progress bar (aggregate total — ratio-based coloring only)
          _buildProgressItem(
            'Fluids',
            currentFluids.round(),
            targetFluids,
            UnitFormatter.fluidUnitLabel(useMetric: useMetric),
            AppTheme.primary600,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(String label, int current, int target, String unit, Color color) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final dynamicColor = _getColorForProgress(current, target);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.textStyle.copyWith(
            color: AppTheme.primary900,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),

        // Progress bar
        Container(
          height: 8.h,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.baseGrey.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: dynamicColor,
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
          ),
        ),
        SizedBox(height: 4.h),

        // Current/Target text with dynamic color
        Text(
          '$current/$target $unit',
          style: AppTheme.noteStyle.copyWith(
            color: dynamicColor,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Delegates to the unified color utility for ratio-based coloring.
  /// Maps theme colors to the shared palette.
  Color _getColorForProgress(int current, int target) {
    if (target <= 0) return AppTheme.baseGrey;
    final ratio = current / target;
    if (ratio >= 0.8 && ratio <= 1.2) return AppTheme.primary600;
    if (ratio >= 0.6 && ratio <= 1.5) return AppTheme.warning500;
    return AppTheme.highlight400;
  }
}
