import 'package:flutter/material.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';

/// Mode for workout input: by duration or by pace/speed
enum DurationPaceMode {
  byDuration,
  byPace,
}

/// Toggle control for switching between duration and pace input modes
///
/// Sport-aware: Shows "By Speed" for cycling, "By Pace" for running/swimming
///
/// Usage:
/// ```dart
/// DurationPaceToggle(
///   value: DurationPaceMode.byDuration,
///   onChanged: (mode) => print(mode),
///   sport: ActivityType.cycling, // Optional - changes "By Pace" to "By Speed"
/// )
/// ```
class DurationPaceToggle extends StatelessWidget {
  const DurationPaceToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.sport,
    this.enabled = true,
  });

  final DurationPaceMode value;
  final ValueChanged<DurationPaceMode> onChanged;
  final ActivityType? sport;
  final bool enabled;

  String _getByPaceLabel() {
    if (sport == ActivityType.cycling) {
      return 'By Speed';
    }
    return 'By Pace';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final semanticLabel = value == DurationPaceMode.byDuration
        ? 'Workout input mode: By Duration'
        : 'Workout input mode: ${_getByPaceLabel()}';

    return Semantics(
      label: semanticLabel,
      container: true,
      child: Row(
        children: [
          Expanded(
            child: _ToggleButton(
              label: 'By Duration',
              isSelected: value == DurationPaceMode.byDuration,
              onTap: enabled ? () => onChanged(DurationPaceMode.byDuration) : null,
              isDark: isDark,
              isLeft: true,
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Expanded(
            child: _ToggleButton(
              label: _getByPaceLabel(),
              isSelected: value == DurationPaceMode.byPace,
              onTap: enabled ? () => onChanged(DurationPaceMode.byPace) : null,
              isDark: isDark,
              isLeft: false,
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual toggle button
class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
    required this.isLeft,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isDark;
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;

    // Colors based on design image
    final Color backgroundColor;
    final Color textColor;

    if (isDisabled) {
      backgroundColor = isDark
          ? AppColors.disabled.withValues(alpha: 0.3)
          : AppColors.disabled.withValues(alpha: 0.2);
      textColor = AppColors.disabled;
    } else if (isSelected) {
      // Orange background for selected (from design)
      backgroundColor = AppColors.orange;
      textColor = Colors.white;
    } else {
      // Dark/muted background for unselected (from design)
      backgroundColor = isDark
          ? AppColors.blackberryLight
          : AppColors.inactive.withValues(alpha: 0.2);
      textColor = isDark ? AppColors.textDark : AppColors.textLight;
    }

    return Semantics(
      button: true,
      label: label,
      selected: isSelected,
      enabled: !isDisabled,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.buttonTertiary.copyWith(
                color: textColor,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
