import 'package:flutter/material.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../../shared/domain/activity_type.dart';
import '../../utils/activity_detail_helpers.dart';

/// Displays scheduled date and time for an activity
class ActivityScheduleInfo extends StatelessWidget {
  const ActivityScheduleInfo({
    super.key,
    required this.scheduledDateTime,
    required this.activityType,
  });

  final DateTime scheduledDateTime;
  final ActivityType activityType;

  @override
  Widget build(BuildContext context) {
    String activityLabel;
    switch (activityType) {
      case ActivityType.running:
        activityLabel = 'RUN';
        break;
      case ActivityType.cycling:
        activityLabel = 'BIKE';
        break;
      case ActivityType.swimming:
        activityLabel = 'SWIM';
        break;
      default:
        activityLabel = 'ACTIVITY';
    }

    return Column(
      children: [
        Text(
          '$activityLabel SCHEDULED FOR',
          style: AppTextStyles.smallLabel.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: [
                Text(
                  'DATE',
                  style: AppTextStyles.smallLabel.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  ActivityDetailHelpers.formatDateShort(scheduledDateTime),
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.xxl),
            Column(
              children: [
                Text(
                  'TIME',
                  style: AppTextStyles.smallLabel.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  ActivityDetailHelpers.formatTime(scheduledDateTime),
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
