import 'package:flutter/material.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../domain/carb_adjustment_level.dart';

/// Horizontal emoji selector for post-workout carb feedback.
///
/// Displays 5 tappable emoji circles. The selected level shows
/// its label and description below.
class CarbFeedbackSelector extends StatelessWidget {
  const CarbFeedbackSelector({
    super.key,
    required this.selectedLevel,
    required this.onLevelSelected,
  });

  final CarbAdjustmentLevel? selectedLevel;
  final ValueChanged<CarbAdjustmentLevel> onLevelSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: CarbAdjustmentLevel.values.map((level) {
            final isSelected = selectedLevel == level;
            return GestureDetector(
              onTap: () => onLevelSelected(level),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? AppColors.electrolyte.withValues(alpha: 0.2)
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.08),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.electrolyte
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(level.emoji, style: const TextStyle(fontSize: 24)),
              ),
            );
          }).toList(),
        ),
        if (selectedLevel != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            selectedLevel!.label,
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            selectedLevel!.description,
            style: AppTextStyles.smallLabel.copyWith(
              color: AppColors.electrolyte,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
