import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/macro_targets.dart' as targets_model;
import '../../domain/nutrition_plan.dart';

/// Reusable widget that displays macro targets as badges/pills with ratio format
/// Shows different macros based on the phase:
/// - Before Run: carbs, fluids, sodium
/// - During Run: carbs, fluids, sodium
/// - After Run: carbs, fluids, protein
class MacroTargetBadgesWidget extends StatelessWidget {
  const MacroTargetBadgesWidget({
    super.key,
    required this.phase,
    required this.targets,
    this.plan,
  });

  final RunPhase phase;
  final targets_model.MacroTargets targets;
  final NutritionPlan? plan;

  @override
  Widget build(BuildContext context) {
    final currentValues = _calculateCurrentValues();
    final targetValues = _getTargetValues();
    final macroTypes = _getMacroTypesForPhase();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: macroTypes.map((macroType) {
        final current = currentValues[macroType] ?? 0;
        final target = targetValues[macroType] ?? 0;
        return _buildMacroBadge(macroType, current, target);
      }).toList(),
    );
  }

  /// Get the macro types to display based on the phase
  List<MacroType> _getMacroTypesForPhase() {
    switch (phase) {
      case RunPhase.beforeRun:
      case RunPhase.duringRun:
        return [MacroType.carbs, MacroType.fluids, MacroType.sodium];
      case RunPhase.afterRun:
        return [MacroType.carbs, MacroType.fluids, MacroType.protein];
    }
  }

  /// Calculate current values from plan food items for the specific phase
  Map<MacroType, int> _calculateCurrentValues() {
    final currentValues = <MacroType, int>{
      MacroType.carbs: 0,
      MacroType.fluids: 0,
      MacroType.sodium: 0,
      MacroType.protein: 0,
    };

    if (plan == null) return currentValues;

    final sectionTitle = _getSectionTitleForPhase();
    final section = plan!.sections.firstWhere(
      (section) => section.title.toLowerCase().contains(sectionTitle.toLowerCase()),
      orElse: () => PlanSection(id: '', title: '', subtitle: '', foodItems: []),
    );

    for (final foodItem in section.foodItems) {
      final nutrition = foodItem.nutritionalInfo;
      if (nutrition != null) {
        currentValues[MacroType.carbs] = (currentValues[MacroType.carbs]! + (nutrition.carbs ?? 0));
        currentValues[MacroType.fluids] = (currentValues[MacroType.fluids]! + (nutrition.fluids?.round() ?? 0));
        currentValues[MacroType.sodium] = (currentValues[MacroType.sodium]! + (nutrition.sodium ?? 0));
        currentValues[MacroType.protein] = (currentValues[MacroType.protein]! + (nutrition.protein ?? 0));
      }
    }

    return currentValues;
  }

  /// Get target values for the specific phase
  Map<MacroType, int> _getTargetValues() {
    switch (phase) {
      case RunPhase.beforeRun:
        return {
          MacroType.carbs: targets.preRun.carbsG.round(),
          MacroType.fluids: targets.preRun.fluidsMl.round(),
          MacroType.sodium: targets.preRun.sodiumMg.round(),
          MacroType.protein: targets.preRun.proteinG.round(),
        };
      case RunPhase.duringRun:
        return {
          MacroType.carbs: targets.duringRun.carbTotalG.round(),
          MacroType.fluids: targets.duringRun.fluidTotalMl.round(),
          MacroType.sodium: targets.duringRun.sodiumTotalMg.round(),
          MacroType.protein: 0, // Not tracked during run
        };
      case RunPhase.afterRun:
        return {
          MacroType.carbs: targets.postRun.carbsG.round(),
          MacroType.fluids: targets.postRun.fluidsMl.round(),
          MacroType.sodium: targets.postRun.sodiumMg.round(),
          MacroType.protein: targets.postRun.proteinG.round(),
        };
    }
  }

  /// Get section title for phase matching
  String _getSectionTitleForPhase() {
    switch (phase) {
      case RunPhase.beforeRun:
        return 'before';
      case RunPhase.duringRun:
        return 'during';
      case RunPhase.afterRun:
        return 'after';
    }
  }

  /// Build individual macro badge
  Widget _buildMacroBadge(MacroType macroType, int current, int target) {
    final unit = _getMacroUnit(macroType);
    final ratioWithUnit = '$current/$target$unit';
    final label = _getMacroLabel(macroType);
    final color = _getMacroColor(macroType);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ratioWithUnit,
            style: AppTheme.textStyle.copyWith(
              color: color,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: AppTheme.noteStyle.copyWith(
              color: color,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Get label for macro type
  String _getMacroLabel(MacroType macroType) {
    switch (macroType) {
      case MacroType.carbs:
        return 'Carbs';
      case MacroType.fluids:
        return 'Fluids';
      case MacroType.sodium:
        return 'Sodium';
      case MacroType.protein:
        return 'Protein';
    }
  }

  /// Get unit for macro type
  String _getMacroUnit(MacroType macroType) {
    switch (macroType) {
      case MacroType.carbs:
      case MacroType.protein:
        return 'g';
      case MacroType.fluids:
        return 'ml';
      case MacroType.sodium:
        return 'mg';
    }
  }

  /// Get color for macro type
  Color _getMacroColor(MacroType macroType) {
    switch (macroType) {
      case MacroType.carbs:
        return AppTheme.carbsColor;
      case MacroType.fluids:
        return AppTheme.primary600;
      case MacroType.sodium:
        return AppTheme.warning500;
      case MacroType.protein:
        return AppTheme.highlight400;
    }
  }
}

/// Enum for run phases
enum RunPhase {
  beforeRun,
  duringRun,
  afterRun,
}

/// Enum for macro types
enum MacroType {
  carbs,
  fluids,
  sodium,
  protein,
}