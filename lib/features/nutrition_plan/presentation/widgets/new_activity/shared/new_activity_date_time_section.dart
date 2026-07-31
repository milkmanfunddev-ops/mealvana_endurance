import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../../theme/kyle_design/app_colors.dart';
import '../../../../../../theme/kyle_design/app_spacing.dart';
import '../../../../../../theme/kyle_design/app_text_styles.dart';

/// Date and Time display section for the New Activity screen
///
/// Features:
/// - Side-by-side DATE and TIME labels with values
/// - Formatted date: "Nov 9, 2025"
/// - Formatted time: "12:00 pm"
/// - Tap the date or time value directly to edit (unified with Activity
///   Details' tap-the-value pattern). A small pencil glyph beside each value
///   is the only affordance — there is no separate "Edit" link anymore.
class NewActivityDateTimeSection extends StatelessWidget {
  const NewActivityDateTimeSection({
    super.key,
    required this.selectedDate,
    required this.selectedTime,
    required this.onEditTapped,
    required this.isDark,
  });

  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final VoidCallback onEditTapped;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // Date and Time side-by-side. FittedBox scales the pair down so a long
    // date string never overflows a narrow phone.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        key: const ValueKey('activity_create.datetime_labels'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTappableColumn(
            label: 'DATE',
            value: _formatDate(selectedDate),
            valueKey: const ValueKey('activity_create.datetime_display'),
            columnKey: const ValueKey('activity_create.edit_datetime_button'),
          ),
          const SizedBox(width: AppSpacing.xxl),
          _buildTappableColumn(label: 'TIME', value: _formatTime(selectedTime)),
        ],
      ),
    );
  }

  /// A DATE/TIME column that is itself the tap target for editing. A small
  /// pencil glyph beside the value is the subtle "this is tappable"
  /// affordance — replaces the old separate "Edit" link.
  Widget _buildTappableColumn({
    required String label,
    required String value,
    Key? valueKey,
    Key? columnKey,
  }) {
    final color = isDark ? AppColors.cream : AppColors.blackberry;
    return GestureDetector(
      key: columnKey,
      onTap: onEditTapped,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            label,
            style: AppTextStyles.smallLabel.copyWith(
              color: color,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                key: valueKey,
                value,
                style: AppTextStyles.dataNumber.copyWith(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              FaIcon(
                FontAwesomeIcons.penToSquare,
                size: 11,
                color: color.withValues(alpha: 0.45),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Format date as "Nov 9, 2025"
  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final monthName = months[date.month - 1];
    return '$monthName ${date.day}, ${date.year}';
  }

  /// Format time as "12:00 pm"
  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'am' : 'pm';
    return '$hour:$minute $period';
  }
}
