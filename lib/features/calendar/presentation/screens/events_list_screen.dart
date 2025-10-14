import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:mealvana_endurance/shared/widgets/primary_button.dart';
import 'package:mealvana_endurance/theme/app_theme.dart';
import '../../domain/activity.dart';
import '../../domain/event.dart';
import '../providers/calendar_controller.dart';
import 'event_creation_screen.dart';
import 'event_detail_screen.dart';

/// Events List Screen showing all user events (past and upcoming).
///
/// Accessed via the "Upcoming Event" widget on the Activities List screen.
/// Shows:
/// - All events sorted by date
/// - Past events grayed out
/// - Upcoming events highlighted
/// - FAB to create new events
class EventsListScreen extends ConsumerWidget {
  const EventsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarState = ref.watch(allEventsControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        leading: CustomAppBarBackButton(),
        backgroundColor: AppTheme.baseCream,
        title: const Text('My Events'),
      ),
      body: calendarState.when(
        data: (calendarData) {
          // Get events from the calendar data (events are separate from activities now)
          final events = calendarData.events;

          if (events.isEmpty) {
            return _buildEmptyState(context, ref);
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allEventsControllerProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                // Find corresponding activity if one exists
                final activity = event.activityId != null
                    ? calendarData.activities.firstWhere(
                        (a) => a.id == event.activityId,
                        orElse: () => null as dynamic,
                      )
                    : null;

                return _buildEventCard(context, ref, activity, event);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading events: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(allEventsControllerProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push<Map<String, dynamic>>(
            MaterialPageRoute(
              builder: (context) => const EventCreationScreen(),
            ),
          );

          // Invalidate the provider to refresh the list
          if (result != null && result['success'] == true) {
            ref.invalidate(allEventsControllerProvider);

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Event "${result['eventName']}" created successfully!'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            }
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New Event'),
        backgroundColor: AppTheme.primary900 // Purple for events
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, WidgetRef ref, Activity? activity, Event event) {
    // If no activity, can't determine if past/upcoming
    final isPast = activity?.scheduledDateTime.isBefore(DateTime.now()) ?? false;
    final isUpcoming = !isPast;

    return Dismissible(
      key: Key(event.id), // Use event ID since activity might be null
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 32,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete Event'),
              content: Text(
                'Are you sure you want to delete "${event.eventName ?? event.formattedEventType}"?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        // Delete the activity if it exists (don't await - let it complete in background)
        if (activity != null) {
          ref.read(calendarControllerProvider.notifier).deleteActivity(activity.id);
        }

        // Show confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Deleted "${event.eventName ?? event.formattedEventType}"',
            ),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                // TODO: Implement undo functionality if needed
              },
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: isUpcoming ? 2 : 1,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EventDetailScreen(
                  eventId: event.id,
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
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withValues(
                      alpha: isPast ? 0.1 : 0.2,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.event,
                    color: Color(0xFF9C27B0).withValues(
                      alpha: isPast ? 0.5 : 1.0,
                    ),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),

                // Event details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.eventName ?? event.formattedEventType,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isPast ? Colors.grey[600] : Colors.black,
                            ),
                      ),
                      const SizedBox(height: 4),
                      if (activity?.scheduledDateTime != null)
                        Text(
                          DateFormat('EEEE, MMMM d, yyyy').format(activity!.scheduledDateTime),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: isPast ? Colors.grey[500] : Colors.grey[700],
                              ),
                        ),
                      if (event.location != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                event.location!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[500],
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (event.formattedGoalTime != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.timer,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Goal: ${event.formattedGoalTime}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[500],
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Status indicator
                if (activity?.scheduledDateTime != null)
                  Column(
                    children: [
                      if (isPast)
                        const Icon(
                          Icons.check_circle,
                          color: Colors.grey,
                          size: 24,
                        )
                      else
                        _buildCountdown(activity!.scheduledDateTime),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountdown(DateTime eventDate) {
    final now = DateTime.now();
    final difference = eventDate.difference(now);

    String countdownText;
    if (difference.inDays == 0) {
      countdownText = 'Today';
    } else if (difference.inDays == 1) {
      countdownText = '1 day';
    } else if (difference.inDays < 7) {
      countdownText = '${difference.inDays} days';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      countdownText = '$weeks ${weeks == 1 ? 'week' : 'weeks'}';
    } else {
      final months = (difference.inDays / 30).floor();
      countdownText = '$months ${months == 1 ? 'month' : 'months'}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        countdownText,
        style: const TextStyle(
          color: Color(0xFF9C27B0),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            'No Events Yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Create your first race event to get started with event-specific nutrition planning!',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[500],
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<Map<String, dynamic>>(
                MaterialPageRoute(
                  builder: (context) => const EventCreationScreen(),
                ),
              );

              // Invalidate the provider to refresh the list
              if (result != null && result['success'] == true) {
                ref.invalidate(allEventsControllerProvider);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Event "${result['eventName']}" created successfully!'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
              }
            },
            text: 'Create Event',
          ),
        ],
      ),
    );
  }
}
