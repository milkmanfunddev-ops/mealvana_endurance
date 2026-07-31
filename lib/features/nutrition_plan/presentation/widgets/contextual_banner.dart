import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/macro_targets.dart';

/// Contextual banner displaying guidance based on run duration
/// Shows different messages for short runs vs long runs regarding carb needs
class ContextualBanner extends StatelessWidget {
  const ContextualBanner({
    super.key,
    required this.macroTargets,
    required this.shortRunText,
    required this.longRunText,
    this.bodyWeightKg = 70.0,
  });

  final MacroTargets macroTargets;
  final String shortRunText;
  final String longRunText;
  final double bodyWeightKg;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Determine if this is a long run (> 75 minutes per ISSN guidelines)
    final isLongRun = macroTargets.metrics.durationMin > 75;
    final bannerText = isLongRun ? _formatLongRunText() : shortRunText;

    // Check if there are any validation issues to adjust banner priority
    final hasValidationIssues = _hasAnyValidationIssues();

    final bannerColor = hasValidationIssues
        ? colorScheme.error
        : (isLongRun ? colorScheme.primary : colorScheme.secondary);
    final backgroundColor = hasValidationIssues
        ? colorScheme.error.withValues(alpha: 0.1)
        : (isLongRun
              ? colorScheme.primary.withValues(alpha: 0.1)
              : colorScheme.secondary.withValues(alpha: 0.1));

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: bannerColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          // Icon
          Icon(
            hasValidationIssues
                ? Icons.warning_outlined
                : (isLongRun ? Icons.info : Icons.check_circle_outline),
            color: bannerColor,
            size: 20.sp,
          ),

          SizedBox(width: 12.w),

          // Text content
          Expanded(
            child: Text(
              bannerText,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Format the long run text by substituting the carb amount
  String _formatLongRunText() {
    // Get minimum recommended carbs (30g/h * duration)
    final durationH = macroTargets.metrics.durationH;
    final minCarbsRecommended = (30.0 * durationH).round();

    // Replace {amount} placeholder with actual value
    return longRunText.replaceAll('{amount}', minCarbsRecommended.toString());
  }

  /// Check if there are any validation issues across all macro fields
  bool _hasAnyValidationIssues() {
    final bodyWeightKg = this.bodyWeightKg;
    final durationH = macroTargets.metrics.durationH;

    // Check pre-run macros
    if (_validatePreRunMacro(
          MacroField.preRunCarbs,
          macroTargets.preRun.carbsG,
          bodyWeightKg,
        ) !=
        null)
      return true;
    if (_validatePreRunMacro(
          MacroField.preRunProtein,
          macroTargets.preRun.proteinG,
          bodyWeightKg,
        ) !=
        null)
      return true;
    if (_validatePreRunMacro(
          MacroField.preRunFatCap,
          macroTargets.preRun.fatCapG,
          bodyWeightKg,
        ) !=
        null)
      return true;
    if (_validatePreRunMacro(
          MacroField.preRunFluids,
          macroTargets.preRun.fluidsFlOz,
          bodyWeightKg,
        ) !=
        null)
      return true;
    if (_validatePreRunMacro(
          MacroField.preRunSodium,
          macroTargets.preRun.sodiumMg,
          bodyWeightKg,
        ) !=
        null)
      return true;

    // Check during-run macros
    if (_validateDuringRunMacro(
          MacroField.duringRunCarbTotal,
          macroTargets.duringRun.carbTotalG,
          bodyWeightKg,
          durationH,
        ) !=
        null)
      return true;
    if (_validateDuringRunMacro(
          MacroField.duringRunFluidTotal,
          macroTargets.duringRun.fluidTotalFlOz,
          bodyWeightKg,
          durationH,
        ) !=
        null)
      return true;
    if (_validateDuringRunMacro(
          MacroField.duringRunSodiumTotal,
          macroTargets.duringRun.sodiumTotalMg,
          bodyWeightKg,
          durationH,
        ) !=
        null)
      return true;

    // Check post-run macros
    if (_validatePostRunMacro(
          MacroField.postRunCarbs,
          macroTargets.postRun.carbsG,
          bodyWeightKg,
        ) !=
        null)
      return true;
    if (_validatePostRunMacro(
          MacroField.postRunProtein,
          macroTargets.postRun.proteinG,
          bodyWeightKg,
        ) !=
        null)
      return true;
    if (_validatePostRunMacro(
          MacroField.postRunFluids,
          macroTargets.postRun.fluidsFlOz,
          bodyWeightKg,
        ) !=
        null)
      return true;
    if (_validatePostRunMacro(
          MacroField.postRunSodium,
          macroTargets.postRun.sodiumMg,
          bodyWeightKg,
        ) !=
        null)
      return true;

    return false;
  }

  /// Validation methods (same logic as MacroSectionCard for consistency)
  String? _validatePreRunMacro(
    MacroField field,
    double value,
    double bodyWeightKg,
  ) {
    switch (field) {
      case MacroField.preRunCarbs:
        if (value < 1.0 * bodyWeightKg)
          return 'Below recommended range (1-4 g/kg)';
        if (value > 4.0 * bodyWeightKg)
          return 'Above recommended range (1-4 g/kg)';
        break;
      case MacroField.preRunProtein:
        if (value > 0.25 * bodyWeightKg) return 'Higher than typically needed';
        break;
      case MacroField.preRunFatCap:
        if (value > 0.2 * bodyWeightKg) return 'May slow digestion';
        break;
      case MacroField.preRunFluids:
        final valueML = value * 29.5735;
        if (valueML < 5.0 * bodyWeightKg) return 'May lead to dehydration';
        if (valueML > 7.0 * bodyWeightKg) return 'Risk of overhydration';
        break;
      case MacroField.preRunSodium:
        if (value < 200) return 'May be insufficient';
        if (value > 400) return 'Higher than typically needed';
        break;
      default:
        break;
    }
    return null;
  }

  String? _validateDuringRunMacro(
    MacroField field,
    double value,
    double bodyWeightKg,
    double durationH,
  ) {
    switch (field) {
      case MacroField.duringRunCarbTotal:
        final ratePerHour = durationH > 0 ? value / durationH : 0;
        if (ratePerHour < 20) return 'Below recommended minimum (30-60 g/h)';
        if (ratePerHour > 90) return 'Above typical absorption capacity';
        break;
      case MacroField.duringRunFluidTotal:
        final valueML = value * 29.5735;
        final ratePerHour = durationH > 0 ? valueML / durationH : 0;
        if (ratePerHour < 350) return 'May lead to dehydration';
        if (ratePerHour > 1200) return 'May cause GI distress';
        break;
      case MacroField.duringRunSodiumTotal:
        final ratePerHour = durationH > 0 ? value / durationH : 0;
        if (ratePerHour < 200) return 'Risk of cramping';
        if (ratePerHour > 800) return 'Excessive sodium';
        break;
      default:
        break;
    }
    return null;
  }

  String? _validatePostRunMacro(
    MacroField field,
    double value,
    double bodyWeightKg,
  ) {
    switch (field) {
      case MacroField.postRunCarbs:
        if (value < 1.0 * bodyWeightKg)
          return 'Below optimal recovery (1.0-1.2 g/kg)';
        if (value > 1.5 * bodyWeightKg) return 'More than typically needed';
        break;
      case MacroField.postRunProtein:
        if (value < 0.25 * bodyWeightKg)
          return 'Below optimal recovery (0.25-0.3 g/kg)';
        if (value > 0.5 * bodyWeightKg) return 'More than typically needed';
        break;
      case MacroField.postRunFluids:
        final valueML = value * 29.5735;
        if (valueML < 500) return 'May be insufficient for rehydration';
        if (valueML > 1500) return 'Risk of overhydration';
        break;
      case MacroField.postRunSodium:
        if (value < 300) return 'May be insufficient';
        if (value > 1000) return 'Higher than typically needed';
        break;
      default:
        break;
    }
    return null;
  }
}
