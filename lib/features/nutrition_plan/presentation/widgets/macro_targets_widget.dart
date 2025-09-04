import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/macro_targets.dart' as targets_model;
import '../../domain/nutrition_plan.dart';

/// Macro targets display widget with progress bars matching original design
/// Now stateless and takes parameters to avoid controller watching and rebuilds
class MacroTargetsWidget extends StatelessWidget {
  const MacroTargetsWidget({
    super.key,
    this.plan,
    this.targets,
  });

  final NutritionPlan? plan;
  final targets_model.MacroTargets? targets;

  @override
  Widget build(BuildContext context) {
    if (targets == null && plan?.macroTargets == null) {
      return const SizedBox.shrink();
    }
    
    // Use passed targets or convert from plan
    final macroTargets = targets != null 
        ? _convertToSimpleMacroTargets(targets!)
        : plan!.macroTargets!;
    
    return _buildMacroTargetsWithProgressBars(macroTargets, plan);
  }

  /// Convert detailed macro targets to simple macro targets by summing all sections
  MacroTargets _convertToSimpleMacroTargets(targets_model.MacroTargets detailedTargets) {
    final totalCarbs = detailedTargets.preRun.carbsG + 
                      detailedTargets.duringRun.carbTotalG + 
                      detailedTargets.postRun.carbsG;
    
    // During run doesn't have protein, so just pre + post run
    final totalProtein = detailedTargets.preRun.proteinG + 
                        detailedTargets.postRun.proteinG;
    
    final totalFat = detailedTargets.preRun.fatCapG;
    
    final totalCalories = detailedTargets.metrics.caloriesGrossKcal;
    
    return MacroTargets(
      calories: totalCalories.round(),
      carbs: totalCarbs.round(),
      protein: totalProtein.round(),
      fat: totalFat.round(),
    );
  }

  Widget _buildMacroTargetsWithProgressBars(MacroTargets macroTargets, NutritionPlan? plan) {
    // Calculate current values from plan sections if available
    int currentCarbs = 0;
    int currentSodium = 0;
    double currentFluids = 0.0;
    
    if (plan != null) {
      for (final section in plan.sections) {
        for (final foodItem in section.foodItems) {
          final nutrition = foodItem.nutritionalInfo;
          if (nutrition != null) {
            currentCarbs += nutrition.carbs ?? 0;
            currentSodium += nutrition.sodium ?? 0;
            currentFluids += nutrition.fluids ?? 0.0;
          }
        }
      }
    }
    
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
            macroTargets.carbs,
            'g',
            AppTheme.carbsColor,
          ),
          SizedBox(height: 16.h),
          
          // Sodium progress bar
          _buildProgressItem(
            'Sodium',
            currentSodium,
            macroTargets.sodium ?? 2245, // Default from image - sodium is nullable
            'mg',
            AppTheme.primary600,
          ),
          SizedBox(height: 16.h),
          
          // Fluids progress bar
          _buildProgressItem(
            'Fluids',
            (currentFluids / 1000).round(), // Convert ml to L
            ((macroTargets.fluids ?? 630) / 1000).round(), // Default from image - fluids is nullable
            'L',
            AppTheme.primary600,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(String label, int current, int target, String unit, Color color) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    
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
                color: color,
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
          ),
        ),
        SizedBox(height: 4.h),
        
        // Current/Target text
        Text(
          '$current/$target $unit',
          style: AppTheme.noteStyle.copyWith(
            color: AppTheme.baseGrey,
            fontSize: 14.sp,
          ),
        ),
      ],
    );
  }
}