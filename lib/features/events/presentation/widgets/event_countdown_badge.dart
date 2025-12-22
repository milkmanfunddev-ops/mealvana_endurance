import 'package:flutter/material.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

/// Countdown badge widget showing time until event
class EventCountdownBadge extends StatelessWidget {
  final DateTime eventDate;

  const EventCountdownBadge({
    super.key,
    required this.eventDate,
  });

  @override
  Widget build(BuildContext context) {
    // Compare dates at day level only, ignoring time components
    final now = DateTime.now();
    final todayDateOnly = DateTime(now.year, now.month, now.day);
    final eventDateOnly = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final daysDifference = eventDateOnly.difference(todayDateOnly).inDays;

    String countdownText;
    if (daysDifference < 0) {
      countdownText = 'Event completed';
    } else if (daysDifference == 0) {
      countdownText = 'Today!';
    } else if (daysDifference == 1) {
      countdownText = '1 day away';
    } else if (daysDifference < 7) {
      countdownText = '$daysDifference days away';
    } else if (daysDifference < 30) {
      final weeks = (daysDifference / 7).floor();
      countdownText = '$weeks ${weeks == 1 ? 'week' : 'weeks'} away';
    } else {
      final months = (daysDifference / 30).floor();
      countdownText = '$months ${months == 1 ? 'month' : 'months'} away';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.electrolyte.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.electrolyte.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        countdownText,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.electrolyte,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
