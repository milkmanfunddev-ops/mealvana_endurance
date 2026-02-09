import 'package:flutter/material.dart';
import '../../../../../../theme/kyle_design/app_spacing.dart';
import '../../../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../../../theme/kyle_design/app_colors.dart';

/// Fasted workout toggle widget.
///
/// Displays a row with "Fasted Workout" label and a toggle switch.
/// Only visible when eligible (easy intensity, <= 75 min, not swimming).
///
/// When toggled on, pre-workout macros = 0 and post-workout is boosted
/// (1.2x carbs, 0.35 g/kg protein).
class FastedToggle extends StatelessWidget {
  const FastedToggle({
    super.key,
    required this.isFasted,
    required this.onChanged,
    this.showWarning = false,
    this.warningText,
    this.infoText,
  });

  final bool isFasted;
  final ValueChanged<bool> onChanged;
  final bool showWarning;
  final String? warningText;
  final String? infoText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fasted Workout',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Switch.adaptive(
                value: isFasted,
                onChanged: onChanged,
                activeColor: AppColors.electrolyte,
              ),
            ],
          ),
          if (isFasted)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(
                showWarning
                    ? (warningText ??
                        'Fasted training is not recommended for longer or harder workouts. Consider fueling before.')
                    : (infoText ??
                        'Fasted training can support metabolic adaptations for easy, short workouts. Post-workout nutrition will be prioritized.'),
                style: AppTextStyles.smallLabel.copyWith(
                  color: showWarning ? AppColors.orange : AppColors.textLightSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Check if a fasted workout is suitable based on intensity and duration.
  ///
  /// Suitable when:
  /// - Easy intensity (conversational >= 70%)
  /// - Duration <= 75 minutes
  /// - Not swimming
  static bool isSuitable({
    required int conversationalPct,
    required int estimatedDurationMinutes,
    required bool isSwimming,
  }) {
    if (isSwimming) return false;
    if (conversationalPct < 70) return false;
    if (estimatedDurationMinutes > 75) return false;
    return true;
  }
}
