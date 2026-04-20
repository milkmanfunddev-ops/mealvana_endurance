import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../activities/domain/activity.dart';
import '../../domain/event.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../providers/events_controller.dart';
import '../widgets/event_list_card.dart';
import '../widgets/events_empty_state.dart';
import 'event_form_screen.dart';
import 'event_detail_screen.dart';

/// Events List Screen showing all user events (past and upcoming).
///
/// Updated with Kyle's Design System:
/// - AppColors for theme-aware colors
/// - AppTextStyles for typography
/// - BaseCard for consistent card styling
/// - KylePrimaryButton for actions
///
/// Accessed via the "Upcoming Event" widget on the Activities List screen.
/// Shows:
/// - All events sorted by date
/// - Past events grayed out
/// - Upcoming events highlighted
/// - Button below list to create new events
class EventsListScreen extends ConsumerStatefulWidget {
  const EventsListScreen({super.key});

  @override
  ConsumerState<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends ConsumerState<EventsListScreen> {
  // Track dismissed events for optimistic UI updates
  final Set<String> _dismissedEventIds = {};

  @override
  Widget build(BuildContext context) {
    // Watch both events and activities controllers
    final eventsState = ref.watch(eventsControllerProvider);
    final activitiesState = ref.watch(activitiesControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        // leading: IconButton(
        //   icon: Icon(
        //     FontAwesomeIcons.chevronLeft,
        //     size: AppIconSizes.sm,
        //     color: Theme.of(context).colorScheme.onSurface,
        //   ),
        //   onPressed: () => Navigator.of(context).pop(),
        // ),
        title: Text(
          'My Events',
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
        //   IconButton(
        //     icon: Icon(
        //       FontAwesomeIcons.house,
        //       size: AppIconSizes.sm,
        //       color: Theme.of(context).colorScheme.onSurface,
        //     ),
        //     tooltip: 'Home',
        //     onPressed: () => context.go('/main'),
        //   ),
        ],
      ),
      body: eventsState.when(
        data: (events) {
          // Filter out dismissed events for optimistic UI
          final visibleEvents = events.where((e) => !_dismissedEventIds.contains(e.id)).toList();

          if (visibleEvents.isEmpty) {
            return EventsEmptyState(
              onCreateEvent: _openCreateEvent,
            );
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

          for (final event in visibleEvents) {
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
              // Force sync from Supabase to get coach changes
              await ref.read(eventsControllerProvider.notifier).forceRefresh();
              ref.invalidate(activitiesControllerProvider);
            },
            color: AppColors.electrolyte,
            child: ListView(
              padding: AppSpacing.screenPaddingHorizontal,
              children: [
                const SizedBox(height: AppSpacing.lg),

                // Upcoming Events Section
                if (upcomingEvents.isNotEmpty) ...[
                  Text(
                    'Upcoming Events',
                    style: AppTextStyles.subtitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...upcomingEvents.map((eventData) => EventListCard(
                        event: eventData.event,
                        activity: eventData.activity,
                        eventDate: eventData.eventDate,
                        onDismissed: () => _handleEventDismissed(eventData.event),
                      )),
                ],

                // Past Events Section
                if (pastEvents.isNotEmpty) ...[
                  if (upcomingEvents.isNotEmpty) const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Past Events',
                    style: AppTextStyles.subtitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...pastEvents.map((eventData) => EventListCard(
                        event: eventData.event,
                        activity: eventData.activity,
                        eventDate: eventData.eventDate,
                        onDismissed: () => _handleEventDismissed(eventData.event),
                      )),
                ],

                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: KylePrimaryButton(
                    text: 'New Event',
                    icon: FontAwesomeIcons.plus,
                    isFullWidth: false,
                    onPressed: _openCreateEvent,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(
              color: AppColors.electrolyte,
            ),
          ),
          error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FontAwesomeIcons.circleExclamation,
                size: AppIconSizes.xl,
                color: AppColors.dragonfruit,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Error loading events',
                style: AppTextStyles.subtitle.copyWith(
                  color: AppColors.dragonfruit,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: AppSpacing.screenPaddingHorizontal,
                child: Text(
                  error.toString(),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              KylePrimaryButton(
                text: 'Retry',
                isFullWidth: false,
                onPressed: () {
                  ref.invalidate(eventsControllerProvider);
                  ref.invalidate(activitiesControllerProvider);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateEvent() async {
    if (!mounted) return;
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
        MealvanaSnackbar.showSuccess(
          context,
          'Event "${result['eventName']}" created successfully!',
        );
      }

      final createdEventId = result['eventId'];
      if (createdEventId is String && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => EventDetailScreen(
              eventId: createdEventId,
            ),
          ),
        );
      }
    }
  }

  /// Handle event dismissal with optimistic UI update
  void _handleEventDismissed(Event event) {
    // Immediately mark as dismissed for optimistic UI
    setState(() {
      _dismissedEventIds.add(event.id);
    });

    final eventName = event.eventName ?? event.formattedEventType;
    final eventsController = ref.read(eventsControllerProvider.notifier);

    // Delete the event in the background
    eventsController.deleteEvent(event.id).then((_) {
      // Show success message
      if (mounted) {
        MealvanaSnackbar.showInfo(
          context,
          'Deleted "$eventName"',
        );
      }
    }).catchError((e) {
      // Deletion failed - restore the event in the UI
      if (mounted) {
        setState(() {
          _dismissedEventIds.remove(event.id);
        });

        MealvanaSnackbar.showError(
          context,
          'Error deleting event: $e',
        );
      }
    });
  }
}
