import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:mealvana_endurance/theme/app_theme.dart';
import '../../../../shared/utils/location_formatter.dart';
import '../../../activities/domain/activity.dart';
import '../../domain/event.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../providers/events_controller.dart';
import 'event_form_screen.dart';
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
    // Watch both events and activities controllers
    final eventsState = ref.watch(eventsControllerProvider);
    final activitiesState = ref.watch(activitiesControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        leading: CustomAppBarBackButton(),
        backgroundColor: AppTheme.baseCream,
        title: const Text('My Events'),
      ),
      body: eventsState.when(
        data: (events) {
          if (events.isEmpty) {
            return _buildEmptyState(context, ref);
          }

          // Get activities from activities controller
          final activities = activitiesState.maybeWhen(
            data: (acts) => acts,
            orElse: () => <Activity>[],
          );

          // Separate events into upcoming and past
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          final upcomingEvents = <({Event event, Activity? activity, DateTime eventDate})>[];
          final pastEvents = <({Event event, Activity? activity, DateTime eventDate})>[];

          for (final event in events) {
            // Find corresponding activity if one exists
            final activity = event.activityId != null
                ? activities.cast<Activity?>().firstWhere(
                    (a) => a?.id == event.activityId,
                    orElse: () => null,
                  )
                : null;

            // Get event date
            DateTime? eventDate;
            if (activity != null) {
              eventDate = activity.scheduledDateTime;
            } else if (event.startTime != null) {
              try {
                eventDate = DateTime.parse(event.startTime!);
              } catch (e) {
                // Skip events without valid dates
                continue;
              }
            } else {
              // Skip events without dates
              continue;
            }

            // Compare dates only (ignore time)
            final eventDateOnly = DateTime(eventDate.year, eventDate.month, eventDate.day);
            if (eventDateOnly.isAfter(today) || eventDateOnly.isAtSameMomentAs(today)) {
              upcomingEvents.add((event: event, activity: activity, eventDate: eventDate));
            } else {
              pastEvents.add((event: event, activity: activity, eventDate: eventDate));
            }
          }

          // Sort events by date
          upcomingEvents.sort((a, b) => a.eventDate.compareTo(b.eventDate)); // Ascending (earliest first)
          pastEvents.sort((a, b) => b.eventDate.compareTo(a.eventDate)); // Descending (most recent first)

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(eventsControllerProvider);
              ref.invalidate(activitiesControllerProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Upcoming Events Section
                if (upcomingEvents.isNotEmpty) ...[
                  Text(
                    'Upcoming Events',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary900,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ...upcomingEvents.map((eventData) => _buildEventCard(
                        context,
                        ref,
                        eventData.activity,
                        eventData.event,
                        eventData.eventDate,
                      )),
                ],

                // Past Events Section
                if (pastEvents.isNotEmpty) ...[
                  if (upcomingEvents.isNotEmpty) const SizedBox(height: 24),
                  Text(
                    'Past Events',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 12),
                  ...pastEvents.map((eventData) => _buildEventCard(
                        context,
                        ref,
                        eventData.activity,
                        eventData.event,
                        eventData.eventDate,
                      )),
                ],
              ],
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
                  ref.invalidate(eventsControllerProvider);
                  ref.invalidate(activitiesControllerProvider);
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
              builder: (context) => const EventFormScreen(), // Create mode (event = null)
            ),
          );

          // Invalidate the providers to refresh the list
          if (result != null && result['success'] == true) {
            ref.invalidate(eventsControllerProvider);
            ref.invalidate(activitiesControllerProvider);

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

  Widget _buildEventCard(BuildContext context, WidgetRef ref, Activity? activity, Event event, DateTime eventDate) {
    // Determine if past/upcoming based on provided eventDate
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDateOnly = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final isPast = eventDateOnly.isBefore(today);
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
      onDismissed: (direction) async {
        // Delete the event (which will also delete linked activity and carb loading plans)
        try {
          final eventsController = ref.read(eventsControllerProvider.notifier);
          await eventsController.deleteEvent(event.id);

          // Show confirmation
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Deleted "${event.eventName ?? event.formattedEventType}"',
                ),
              ),
            );
          }
        } catch (e) {
          // Show error if deletion fails
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Error deleting event: $e',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
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
                      if (event.location != null) ...[
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
                                LocationFormatter.parseAndFormatCityState(event.location),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[500],
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                      ],
                      if (event.formattedGoalTime != null) ...[
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

                // Date display on the right
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('MMM').format(eventDate),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isPast ? Colors.grey[500] : AppTheme.primary900,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      DateFormat('d').format(eventDate),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: isPast ? Colors.grey[600] : AppTheme.primary900,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                    ),
                    Text(
                      DateFormat('yyyy').format(eventDate),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isPast ? Colors.grey[500] : Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
          // const SizedBox(height: 32),
          // PrimaryButton(
          //   onPressed: () async {
          //     final result = await Navigator.of(context).push<Map<String, dynamic>>(
          //       MaterialPageRoute(
          //         builder: (context) => const EventCreationScreen(),
          //       ),
          //     );

          //     // Invalidate the provider to refresh the list
          //     if (result != null && result['success'] == true) {
          //       ref.invalidate(allEventsControllerProvider);

          //       if (context.mounted) {
          //         ScaffoldMessenger.of(context).showSnackBar(
          //           SnackBar(
          //             content: Text('Event "${result['eventName']}" created successfully!'),
          //             backgroundColor: AppTheme.successColor,
          //           ),
          //         );
          //       }
          //     }
          //   },
          //   text: 'Create Event',
          // ),
        ],
      ),
    );
  }
}
