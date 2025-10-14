import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/activity.dart';
import '../../domain/event.dart';
import '../screens/events_list_screen.dart';

/// Widget that displays the next upcoming event with countdown.
///
/// Shows event name, date, and time until event. Tapping navigates to
/// the Events List Screen where users can view all events and create new ones.
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

  String _formatCountdown(DateTime eventDate) {
    final now = DateTime.now();
    final difference = eventDate.difference(now);

    if (difference.isNegative) {
      return 'Event passed';
    }

    if (difference.inDays == 0) {
      return 'Today!';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days away';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} away';
    } else {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} away';
    }
  }
}

extension EventTypeExtension on EventType {
  String get displayName {
    switch (this) {
      case EventType.marathon:
        return 'Marathon';
      case EventType.halfMarathon:
        return 'Half Marathon';
      case EventType.tenK:
        return '10K';
      case EventType.fiveK:
        return '5K';
      case EventType.ultra50K:
        return 'Ultra 50K';
      case EventType.ultra50M:
        return 'Ultra 50M';
      case EventType.ultra100K:
        return 'Ultra 100K';
      case EventType.ultra100M:
        return 'Ultra 100M';
      case EventType.custom:
        return 'Custom Event';
    }
  }
}
