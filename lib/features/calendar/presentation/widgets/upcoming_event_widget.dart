import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../events/domain/event.dart';
import '../../../events/presentation/screens/events_list_screen.dart';
import '../../../events/presentation/screens/event_detail_screen.dart';

/// Widget that displays the next upcoming event with countdown.
///
/// Shows event name, date, and time until event. Tapping navigates to
/// the Event Detail Screen for the upcoming event.
class UpcomingEventWidget extends ConsumerWidget {
  final Event? upcomingEvent;

  const UpcomingEventWidget({
    super.key,
    required this.upcomingEvent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Show "No upcoming events" card if no event exists
    if (upcomingEvent == null) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const EventsListScreen(),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Event icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.event,
                    color: Colors.grey[600],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Event details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No upcoming events',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to add a race event',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
                // Chevron
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EventDetailScreen(
                eventId: upcomingEvent!.id,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Event icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event,
                  color: Color(0xFF9C27B0),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Event details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upcoming Event',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      upcomingEvent!.eventName ?? upcomingEvent!.formattedEventType,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    // TODO: Add date to Event model or fetch activity for date
                    Text(
                      'Upcoming Event',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF9C27B0),
                          ),
                    ),
                  ],
                ),
              ),
              // Chevron
              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

