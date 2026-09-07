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
        // Sodium v3: no pre-workout sodium target, so no pre-workout sodium
        // badge. A badge here would read "310/450 mg" against a target that
        // does not exist. DURING is unchanged.
        return [MacroType.carbs, MacroType.fluids];
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
      (section) =>
          section.title.toLowerCase().contains(sectionTitle.toLowerCase()),
      orElse: () => PlanSection(id: '', title: '', subtitle: '', foodItems: []),
    );

    for (final foodItem in section.foodItems) {
      final nutrition = foodItem.nutritionalInfo;
      if (nutrition != null) {
        currentValues[MacroType.carbs] =
            (currentValues[MacroType.carbs]! + (nutrition.carbs ?? 0));
        currentValues[MacroType.fluids] =
            (currentValues[MacroType.fluids]! +
            (nutrition.fluids?.round() ?? 0));
        currentValues[MacroType.sodium] =
            (currentValues[MacroType.sodium]! + (nutrition.sodium ?? 0));
        currentValues[MacroType.protein] =
            (currentValues[MacroType.protein]! + (nutrition.protein ?? 0));
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
          // Gate path: this badge map predates fuel-stat F-1; the BEFORE
          // card renders "No fluid target" itself, this surface keeps 0.
          MacroType.fluids: (targets.preRun.fluidsMl ?? 0).round(),
          // Sodium v3: deliberately absent — there is no pre-workout target.
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
    final rangeText = _getRangeText(macroType);
    final ratioWithUnit = '$current/$target$unit';
    final label = rangeText != null
        ? '${_getMacroLabel(macroType)} ($rangeText)'
        : _getMacroLabel(macroType);
    final color = _getMacroColor(macroType);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
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

  /// Get range text for macro badges (all phases)
  String? _getRangeText(MacroType macroType) {
    switch (phase) {
      case RunPhase.beforeRun:
        return _getPreRunRange(macroType);
      case RunPhase.duringRun:
        return _getDuringRunRange(macroType);
      case RunPhase.afterRun:
        return _getPostRunRange(macroType);
    }
  }

  String? _getPreRunRange(MacroType macroType) {
    final pre = targets.preRun;
    switch (macroType) {
      case MacroType.carbs:
        if (pre.carbsLowG != null && pre.carbsHighG != null) {
          return '${pre.carbsLowG!.round()}-${pre.carbsHighG!.round()}';
        }
        return null;
      case MacroType.sodium:
        // Sodium v3: no pre-workout sodium band, ever.
        return null;
      case MacroType.fluids:
        if (pre.fluidsLowMl != null && pre.fluidsHighMl != null) {
          return '${pre.fluidsLowMl!.round()}-${pre.fluidsHighMl!.round()}';
        }
        return null;
      case MacroType.protein:
        if (pre.proteinLowG != null && pre.proteinHighG != null) {
          return '${pre.proteinLowG!.round()}-${pre.proteinHighG!.round()}';
        }
        return null;
    }
  }

  String? _getDuringRunRange(MacroType macroType) {
    final during = targets.duringRun;
    switch (macroType) {
      case MacroType.sodium:
        if (during.sodiumLowMg != null && during.sodiumHighMg != null) {
          return '${during.sodiumLowMg!.round()}-${during.sodiumHighMg!.round()}';
        }
        return null;
      case MacroType.fluids:
        if (during.fluidsLowMl != null && during.fluidsHighMl != null) {
          return '${during.fluidsLowMl!.round()}-${during.fluidsHighMl!.round()}';
        }
        return null;
      case MacroType.carbs:
      case MacroType.protein:
        return null; // During run doesn't have carbs/protein ranges
    }
  }

  String? _getPostRunRange(MacroType macroType) {
    final post = targets.postRun;
    switch (macroType) {
      case MacroType.carbs:
        if (post.carbsLowG != null && post.carbsHighG != null) {
          return '${post.carbsLowG!.round()}-${post.carbsHighG!.round()}';
        }
        return null;
      case MacroType.protein:
        if (post.proteinLowG != null && post.proteinHighG != null) {
          return '${post.proteinLowG!.round()}-${post.proteinHighG!.round()}';
        }
        return null;
      case MacroType.sodium:
        if (post.sodiumLowMg != null && post.sodiumHighMg != null) {
          return '${post.sodiumLowMg!.round()}-${post.sodiumHighMg!.round()}';
        }
        return null;
      case MacroType.fluids:
        if (post.fluidsLowMl != null && post.fluidsHighMl != null) {
          return '${post.fluidsLowMl!.round()}-${post.fluidsHighMl!.round()}';
        }
        return null;
    }
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
enum RunPhase { beforeRun, duringRun, afterRun }

/// Enum for macro types
enum MacroType { carbs, fluids, sodium, protein }
