import 'package:flutter/material.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/workout_preset.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';

/// A grid of tappable workout-type chips for the intensity estimate mode.
///
/// Shows 6 preset workout types (Easy, Long, Tempo, Intervals, Race Pace,
/// Recovery) with sport-specific labels. Tapping a chip selects it and
/// triggers the [onSelected] callback.
class IntensityPresetChips extends StatelessWidget {
  const IntensityPresetChips({
    super.key,
    required this.sportType,
    required this.selectedPreset,
    required this.onSelected,
    this.enabled = true,
  });

  final ActivityType sportType;
  final WorkoutPreset? selectedPreset;
  final ValueChanged<WorkoutPreset> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: WorkoutPreset.values.map((preset) {
        final isSelected = preset == selectedPreset;
        final label = WorkoutPresetData.labelFor(sportType, preset);

        return GestureDetector(
          key: ValueKey('activity_create.intensity_${preset.name}_chip'),
          onTap: enabled ? () => onSelected(preset) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.orange.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _borderColor(isSelected, isDark),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: _textColor(isSelected, isDark),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _borderColor(bool isSelected, bool isDark) {
    if (!enabled) {
      return isDark
          ? AppColors.cream.withValues(alpha: 0.2)
          : AppColors.blackberry.withValues(alpha: 0.2);
    }
    if (isSelected) return AppColors.orange;
    return isDark
        ? AppColors.cream.withValues(alpha: 0.4)
        : AppColors.blackberry.withValues(alpha: 0.4);
  }

  Color _textColor(bool isSelected, bool isDark) {
    if (!enabled) {
      return isDark
          ? AppColors.cream.withValues(alpha: 0.3)
          : AppColors.blackberry.withValues(alpha: 0.3);
    }
    if (isSelected) return AppColors.orange;
    return isDark ? AppColors.cream : AppColors.blackberry;
  }
}
