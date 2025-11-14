import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/utils/location_formatter.dart';
import '../../../activities/domain/activity.dart';
import '../../domain/event.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../providers/events_controller.dart';
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
/// - FAB to create new events
class EventsListScreen extends ConsumerWidget {
  const EventsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch both events and activities controllers
    final eventsState = ref.watch(eventsControllerProvider);
    final activitiesState = ref.watch(activitiesControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            FontAwesomeIcons.chevronLeft,
            size: AppIconSizes.sm,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'My Events',
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              FontAwesomeIcons.house,
              size: AppIconSizes.sm,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            tooltip: 'Home',
            onPressed: () => context.go('/main'),
          ),
        ],
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
                  if (upcomingEvents.isNotEmpty) const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Past Events',
                    style: AppTextStyles.subtitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...pastEvents.map((eventData) => _buildEventCard(
                        context,
                        ref,
                        eventData.activity,
                        eventData.event,
                        eventData.eventDate,
                      )),
                ],

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
                  content: Text(
                    'Event "${result['eventName']}" created successfully!',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }

            final createdEventId = result['eventId'];
            if (createdEventId is int && context.mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EventDetailScreen(
                    eventId: createdEventId,
                  ),
                ),
              );
            }
          }
        },
        icon: const Icon(FontAwesomeIcons.plus, size: AppIconSizes.sm),
        label: Text(
          'New Event',
          style: AppTextStyles.buttonPrimary.copyWith(
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, WidgetRef ref, Activity? activity, Event event, DateTime eventDate) {
    // Determine if past/upcoming based on provided eventDate
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDateOnly = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final isPast = eventDateOnly.isBefore(today);

    return Dismissible(
      key: Key(event.id.toString()), // Use event ID since activity might be null
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
          builder: (BuildContext context) {
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
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: AppTextStyles.buttonTertiary.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
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
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
                backgroundColor: Theme.of(context).colorScheme.onSurface,
                behavior: SnackBarBehavior.floating,
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
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
                backgroundColor: AppColors.dragonfruit,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      child: BaseCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EventDetailScreen(
                eventId: event.id,
              ),
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
                    style: AppTextStyles.activityTitle.copyWith(
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
                            LocationFormatter.parseAndFormatCityState(event.location),
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPaddingHorizontal,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.calendarDay,
              size: AppIconSizes.xxl,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'No Events Yet',
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Create your first race event to get started with event-specific nutrition planning!',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
