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
/// - Edit link with icon that triggers date/time picker
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
    return Column(
      children: [
        // Date and Time side-by-side
        Row(
          key: const ValueKey('activity_create.datetime_labels'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // DATE section
            Column(
              children: [
                Text(
                  'DATE',
                  style: AppTextStyles.smallLabel.copyWith(
                    color: isDark ? AppColors.cream : AppColors.blackberry,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  key: const ValueKey('activity_create.datetime_display'),
                  _formatDate(selectedDate),
                  style: AppTextStyles.dataNumber.copyWith(
                    color: isDark ? AppColors.cream : AppColors.blackberry,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            const SizedBox(width: AppSpacing.xxl),

            // TIME section
            Column(
              children: [
                Text(
                  'TIME',
                  style: AppTextStyles.smallLabel.copyWith(
                    color: isDark ? AppColors.cream : AppColors.blackberry,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _formatTime(selectedTime),
                  style: AppTextStyles.dataNumber.copyWith(
                    color: isDark ? AppColors.cream : AppColors.blackberry,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.sm),

        // Edit link (centered)
        GestureDetector(
          key: const ValueKey('activity_create.edit_datetime_button'),
          onTap: onEditTapped,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FontAwesomeIcons.penToSquare,
                size: 14,
                color: AppColors.dragonfruit,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Edit',
                style: AppTextStyles.smallLabel.copyWith(
                  color: AppColors.dragonfruit,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
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
