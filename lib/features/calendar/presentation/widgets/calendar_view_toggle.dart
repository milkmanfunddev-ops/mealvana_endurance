import 'package:flutter/material.dart';
import '../../../../theme/kyle_design/app_colors.dart';

/// Enum for calendar view modes
/// Week is first as it's the default view
enum CalendarViewMode { week, month }

/// Calendar view mode toggle (BY MONTH / BY WEEK)
///
/// A toggle control that allows switching between month and week calendar views.
/// Selected option is indicated by an underline.
///
/// Matches Kyle's design specifications:
/// - Font: Compadre Regular, 8px
/// - Underline: 1px solid, 40px wide
/// - Spacing: centered, 20px apart
///
/// Example:
/// ```dart
/// CalendarViewToggle(
///   selectedMode: CalendarViewMode.week,
///   onModeChanged: (mode) {
///     setState(() {
///       _calendarMode = mode;
///     });
///   },
/// )
/// ```
class CalendarViewToggle extends StatelessWidget {
  const CalendarViewToggle({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
  });

  final CalendarViewMode selectedMode;
  final ValueChanged<CalendarViewMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildToggleOption(
          context,
          'BY WEEK',
          CalendarViewMode.week,
          textColor,
        ),
        const SizedBox(width: 20),
        _buildToggleOption(
          context,
          'BY MONTH',
          CalendarViewMode.month,
          textColor,
        ),
      ],
    );
  }

  Widget _buildToggleOption(
    BuildContext context,
    String label,
    CalendarViewMode mode,
    Color textColor,
  ) {
    final isSelected = selectedMode == mode;

    return GestureDetector(
      onTap: () => onModeChanged(mode),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Compadre',
                fontSize: 8,
                color: textColor,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 2),
            if (isSelected)
              Container(
                height: 1,
                width: double.infinity,
                color: textColor,
              ),
          ],
        ),
      ),
    );
  }
}
