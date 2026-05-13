import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../activities/domain/activity.dart';
import '../../domain/event.dart';
import 'event_countdown_badge.dart';

/// Event header card showing event name, date, and countdown
class EventHeaderCard extends StatelessWidget {
  final Activity? activity;
  final Event event;

  const EventHeaderCard({
    super.key,
    required this.activity,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      margin: AppSpacing.screenPaddingHorizontal.copyWith(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event name/type
          Text(
            key: const ValueKey('event_details.event_name'),
            event.eventName ?? event.formattedEventType,
            style: AppTextStyles.pageTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Date (from activity if exists, otherwise parse from event.startTime)
          if (activity?.scheduledDateTime != null || event.startTime != null)
            Row(
              children: [
                Icon(
                  FontAwesomeIcons.calendar,
                  color: AppColors.electrolyte,
                  size: AppIconSizes.sm,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  key: const ValueKey('event_details.event_date'),
                  activity != null
                      ? DateFormat(
                          'EEEE, MMMM d, yyyy',
                        ).format(activity!.scheduledDateTime)
                      : event.startTime != null
                      ? DateFormat(
                          'EEEE, MMMM d, yyyy',
                        ).format(DateTime.parse(event.startTime!))
                      : 'Date TBD',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),

          const SizedBox(height: AppSpacing.sm),

          // Countdown (from activity if exists, otherwise parse from event.startTime)
          if (activity?.scheduledDateTime != null)
            EventCountdownBadge(
              key: const ValueKey('event_details.event_countdown'),
              eventDate: activity!.scheduledDateTime,
            )
          else if (event.startTime != null)
            EventCountdownBadge(
              key: const ValueKey('event_details.event_countdown'),
              eventDate: DateTime.parse(event.startTime!),
            ),
        ],
      ),
    );
  }
}
