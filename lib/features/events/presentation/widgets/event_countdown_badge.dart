import 'package:flutter/material.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../domain/event_countdown.dart';

/// Countdown badge widget showing time until event
class EventCountdownBadge extends StatelessWidget {
  final DateTime eventDate;

  const EventCountdownBadge({super.key, required this.eventDate});

  @override
  Widget build(BuildContext context) {
    // One formula for every countdown surface (117-007).
    final countdownText = eventCountdownText(
      eventDate,
      today: DateTime.now(),
      pastLabel: 'Event completed',
      oneDayLabel: '1 day away',
    );

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
