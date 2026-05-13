import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../shared/utils/location_formatter.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../activities/domain/activity.dart';
import '../../domain/event.dart';
import '../screens/event_detail_screen.dart';

/// A card displaying an event in the events list.
///
/// Features:
/// - Swipe to delete (with confirmation dialog)
/// - Visual indication for past vs upcoming events
/// - Shows event name, location, goal time, and date
/// - Tappable to navigate to event details
class EventListCard extends StatelessWidget {
  final Event event;
  final Activity? activity;
  final DateTime eventDate;
  final VoidCallback onDismissed;

  const EventListCard({
    required this.event,
    required this.activity,
    required this.eventDate,
    required this.onDismissed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Determine if past/upcoming based on provided eventDate
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDateOnly = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
    );
    final isPast = eventDateOnly.isBefore(today);

    return Dismissible(
      key: ValueKey(event.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.dragonfruit,
          borderRadius: AppRadius.cardRadius,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        child: const Icon(
          FontAwesomeIcons.trash,
          color: Colors.white,
          size: AppIconSizes.md,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Text(
                'Delete Event',
                style: AppTextStyles.subtitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              content: Text(
                'Are you sure you want to delete "${event.eventName ?? event.formattedEventType}"?',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(
                    'Cancel',
                    style: AppTextStyles.buttonTertiary.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    'Delete',
                    style: AppTextStyles.buttonTertiary.copyWith(
                      color: AppColors.dragonfruit,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        // Notify parent to handle dismissal (optimistic UI update)
        onDismissed();
      },
      child: BaseCard(
        key: ValueKey('my_events.event_card_${event.id}'),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EventDetailScreen(eventId: event.id),
            ),
          );
        },
        child: Row(
          children: [
            // Event icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.electrolyte.withValues(
                  alpha: isPast ? 0.2 : 0.3,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                FontAwesomeIcons.calendarDay,
                color: AppColors.electrolyte.withValues(
                  alpha: isPast ? 0.5 : 1.0,
                ),
                size: AppIconSizes.md,
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Event details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.eventName ?? event.formattedEventType,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isPast
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  if (event.location != null) ...[
                    Row(
                      children: [
                        Icon(
                          FontAwesomeIcons.locationDot,
                          size: AppIconSizes.xs,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Expanded(
                          child: Text(
                            LocationFormatter.parseAndFormatCityState(
                              event.location,
                            ),
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                  ],
                  if (event.formattedGoalTime != null) ...[
                    Row(
                      children: [
                        Icon(
                          FontAwesomeIcons.clock,
                          size: AppIconSizes.xs,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          'Goal: ${event.formattedGoalTime}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Date display on the right
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateFormat('MMM').format(eventDate).toUpperCase(),
                  style: AppTextStyles.smallLabel.copyWith(
                    color: isPast
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : AppColors.electrolyte,
                  ),
                ),
                Text(
                  DateFormat('d').format(eventDate),
                  style: AppTextStyles.dateTime.copyWith(
                    color: isPast
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : AppColors.electrolyte,
                    height: 1.0,
                  ),
                ),
                Text(
                  DateFormat('yyyy').format(eventDate),
                  style: AppTextStyles.smallLabel.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
