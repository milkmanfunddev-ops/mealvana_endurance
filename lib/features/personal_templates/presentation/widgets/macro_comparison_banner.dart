import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';

/// Data class holding template vs recommended macro comparison values
class TemplateComparisonData {
  const TemplateComparisonData({
    required this.templateCarbsG,
    required this.targetCarbsG,
    this.templateProteinG,
    this.targetProteinG,
    this.templateSodiumMg,
    this.targetSodiumMg,
  });

  final int templateCarbsG;
  final int targetCarbsG;
  final int? templateProteinG;
  final int? targetProteinG;
  final int? templateSodiumMg;
  final int? targetSodiumMg;
}

/// Informational banner comparing template macros against recommended targets
///
/// Displayed at top of activity detail screen when a template-based plan
/// is applied (not AI-generated). Shows per-macro comparison and guidance.
class MacroComparisonBanner extends StatelessWidget {
  const MacroComparisonBanner({
    super.key,
    required this.templateCarbsG,
    required this.targetCarbsG,
    this.templateProteinG,
    this.targetProteinG,
    this.templateSodiumMg,
    this.targetSodiumMg,
    this.onDismiss,
  });

  final int templateCarbsG;
  final int targetCarbsG;
  final int? templateProteinG;
  final int? targetProteinG;
  final int? templateSodiumMg;
  final int? targetSodiumMg;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.electrolyte.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.electrolyte.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.compare_arrows,
                color: AppColors.electrolyte,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Routine vs. Recommended',
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onDismiss != null)
                GestureDetector(
                  onTap: onDismiss,
                  child: Icon(
                    Icons.close,
                    color: AppColors.textDarkSecondary,
                    size: 18,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Macro rows
          _buildMacroRow('Carbs', '${templateCarbsG}g', '${targetCarbsG}g'),
          if (templateProteinG != null && targetProteinG != null)
            _buildMacroRow(
                'Protein', '${templateProteinG}g', '${targetProteinG}g'),
          if (templateSodiumMg != null && targetSodiumMg != null)
            _buildMacroRow(
                'Sodium', '${templateSodiumMg}mg', '${targetSodiumMg}mg'),

          // Guidance text
          const SizedBox(height: AppSpacing.sm),
          Text(
            _buildGuidanceText(),
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textDarkSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroRow(String label, String templateVal, String targetVal) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '$label:',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textDarkSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '$templateVal routine  ·  $targetVal target',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildGuidanceText() {
    final carbDiff = templateCarbsG - targetCarbsG;
    final pct = targetCarbsG > 0 ? (carbDiff.abs() / targetCarbsG * 100) : 0;

    if (pct < 10) {
      return 'Your routine closely matches the recommended targets.';
    } else if (carbDiff > 0) {
      return 'Your routine has more carbs than recommended for this activity. Consider scaling or adjusting.';
    } else {
      return 'Your routine has fewer carbs than recommended for this activity. Consider scaling or adjusting.';
    }
  }
}
