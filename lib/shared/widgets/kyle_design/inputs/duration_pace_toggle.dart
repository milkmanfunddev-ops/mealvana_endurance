import 'package:flutter/material.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/inputs/two_option_pill_slider.dart';

/// Mode for workout input: by duration or by pace/speed
enum DurationPaceMode { byDuration, byPace }

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
    final byPaceLabel = _getByPaceLabel();

    final semanticLabel = value == DurationPaceMode.byDuration
        ? 'Workout input mode: By Duration'
        : 'Workout input mode: $byPaceLabel';

    return Semantics(
      label: semanticLabel,
      container: true,
      child: TwoOptionPillSlider(
        leftLabel: 'By Duration',
        rightLabel: byPaceLabel,
        isLeftSelected: value == DurationPaceMode.byDuration,
        onLeftTap: () => onChanged(DurationPaceMode.byDuration),
        onRightTap: () => onChanged(DurationPaceMode.byPace),
        textStyle: AppTextStyles.buttonTertiary,
        selectedTextColor: Colors.white,
        unselectedTextColor: isDark ? AppColors.textDark : AppColors.textLight,
        trackColor: isDark
            ? AppColors.blackberryLight
            : AppColors.inactive.withValues(alpha: 0.2),
        thumbColor: AppColors.orange,
        enabled: enabled,
        leftKey: const ValueKey('activity_create.by_duration_toggle'),
        rightKey: const ValueKey('activity_create.by_pace_toggle'),
      ),
    );
  }
}
