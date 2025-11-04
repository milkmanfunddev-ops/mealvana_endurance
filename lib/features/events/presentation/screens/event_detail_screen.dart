import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:mealvana_endurance/shared/widgets/primary_button.dart';
import 'package:mealvana_endurance/shared/widgets/secondary_button.dart';
import 'package:mealvana_endurance/theme/app_theme.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/analytics/analytics_events.dart';
import '../../../../shared/utils/location_formatter.dart';
import '../../../activities/domain/activity.dart';
import '../../domain/event.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../providers/events_controller.dart';
import '../../../carb_loading/presentation/providers/carb_loading_controller.dart';
import '../../../../features/auth/data/user_repository.dart';
import '../../../carb_loading/presentation/screens/carb_loading_protocol_selection_screen.dart';
import 'event_form_screen.dart';

/// Event Detail Screen showing event information and action buttons.
///
/// Displays:
/// - Event metadata (name, date, location, goal time, etc.)
/// - Two primary action buttons:
///   - "Create Nutrition Plan" - Navigate to distance/pace/gut entry
///   - "Create Carb Loading Plan" - Navigate to protocol selection (Phase 2)
///
/// CRITICAL: This screen does NOT contain carb loading configuration.
/// Carb loading is a separate action initiated from this screen.
class EventDetailScreen extends ConsumerWidget {
  final String eventId;

  const EventDetailScreen({
    super.key,
    required this.eventId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventDetailAsync = ref.watch(eventDetailProvider(eventId));

    return eventDetailAsync.when(
      data: (eventDetail) {
        final activity = eventDetail.activity;
        final event = eventDetail.event;

        return Scaffold(
          backgroundColor: AppTheme.baseCream,
          appBar: AppBar(
            title: const Text('Event Details'),
            leading: CustomAppBarBackButton(),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit Event',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventFormScreen(
                        event: event, // Edit mode (event is provided)
                      ),
                    ),
                  ).then((_) {
                    // Refresh the event detail provider when returning from edit
                    ref.invalidate(eventDetailProvider(eventId));
                  });
                },
              ),
            ],
          ),
          body: _buildBody(context, ref, activity, event),
        );
      },
      loading: () => Scaffold(
        backgroundColor: AppTheme.baseCream,
        appBar: AppBar(
          title: const Text('Event Details'),
          leading: CustomAppBarBackButton(),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: AppTheme.baseCream,
        appBar: AppBar(
          title: const Text('Event Details'),
          leading: CustomAppBarBackButton(),
        ),
        body: Center(
          child: Text('Error loading event: $error'),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, Activity? activity, Event event) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Event Header Card
          _buildEventHeaderCard(context, activity, event),

          const SizedBox(height: 16),

          // Event Details Card
          _buildEventDetailsCard(context, activity, event),

          const SizedBox(height: 16),

          // Action Buttons Card
          _buildActionButtonsCard(context, ref, activity, event),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildEventHeaderCard(BuildContext context, Activity? activity, Event event) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary900,
            AppTheme.primary900.withValues(alpha: 0.7),
          ],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event,
              color: Colors.white,
              size: 32,
            ),
          ),

          const SizedBox(height: 16),

          // Event name/type
          Text(
            event.eventName ?? event.formattedEventType,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 8),

          // Date (from activity if exists, otherwise parse from event.startTime)
          if (activity?.scheduledDateTime != null || event.startTime != null)
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  activity != null
                    ? DateFormat('EEEE, MMMM d, yyyy').format(activity.scheduledDateTime)
                    : event.startTime != null
                      ? DateFormat('EEEE, MMMM d, yyyy').format(DateTime.parse(event.startTime!))
                      : 'Date TBD',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                      ),
                ),
              ],
            ),

          const SizedBox(height: 8),

          // Countdown (from activity if exists, otherwise parse from event.startTime)
          if (activity?.scheduledDateTime != null)
            _buildCountdownBadge(context, activity!)
          else if (event.startTime != null)
            _buildCountdownBadgeFromDate(context, DateTime.parse(event.startTime!)),
        ],
      ),
    );
  }

  Widget _buildCountdownBadge(BuildContext context, Activity activity) {
    return _buildCountdownBadgeFromDate(context, activity.scheduledDateTime);
  }

  Widget _buildCountdownBadgeFromDate(BuildContext context, DateTime eventDate) {
    final now = DateTime.now();
    final difference = eventDate.difference(now);

    String countdownText;
    if (difference.inDays < 0) {
      countdownText = 'Event completed';
    } else if (difference.inDays == 0) {
      countdownText = 'Today!';
    } else if (difference.inDays == 1) {
      countdownText = '1 day away';
    } else if (difference.inDays < 7) {
      countdownText = '${difference.inDays} days away';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      countdownText = '$weeks ${weeks == 1 ? 'week' : 'weeks'} away';
    } else {
      final months = (difference.inDays / 30).floor();
      countdownText = '$months ${months == 1 ? 'month' : 'months'} away';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        countdownText,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildEventDetailsCard(BuildContext context, Activity? activity, Event event) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Event Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Distance
            if (activity?.distanceMiles != null)
              _buildDetailRow(
                context,
                icon: Icons.straighten,
                label: 'Distance',
                value: '${activity!.distanceMiles} miles',
              ),

            if (event.location != null) ...[
              const Divider(height: 24),
              _buildDetailRow(
                context,
                icon: Icons.location_on,
                label: 'Location',
                value: LocationFormatter.parseAndFormatCityState(event.location),
              ),
            ],

            if (event.formattedGoalTime != null) ...[
              const Divider(height: 24),
              _buildDetailRow(
                context,
                icon: Icons.timer,
                label: 'Goal Time',
                value: event.formattedGoalTime!,
              ),
            ],

            if (event.formattedGoalPace != null) ...[
              const Divider(height: 24),
              _buildDetailRow(
                context,
                icon: Icons.speed,
                label: 'Goal Pace',
                value: event.formattedGoalPace!,
              ),
            ],

            if (event.registrationUrl != null) ...[
              const Divider(height: 24),
              _buildDetailRow(
                context,
                icon: Icons.link,
                label: 'Registration',
                value: 'View registration',
                isLink: true,
              ),
            ],

            if (event.bibNumber != null) ...[
              const Divider(height: 24),
              _buildDetailRow(
                context,
                icon: Icons.confirmation_number,
                label: 'Bib Number',
                value: event.bibNumber!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool isLink = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isLink ? AppTheme.primary900 : Colors.black,
                      decoration: isLink ? TextDecoration.underline : null,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _getEventDistanceMiles(EventType eventType) {
    switch (eventType) {
      case EventType.marathon:
        return 26.2;
      case EventType.halfMarathon:
        return 13.1;
      case EventType.tenK:
        return 6.2;
      case EventType.fiveK:
        return 3.1;
      case EventType.ultra50K:
        return 31.0;
      case EventType.ultra50M:
        return 50.0;
      case EventType.ultra100K:
        return 62.0;
      case EventType.ultra100M:
        return 100.0;
      case EventType.custom:
        return 0.0;
    }
  }

  /// Handle carb loading plan creation or update
  /// This method is extracted to avoid using disposed refs across async gaps
  Future<void> _handleCarbLoadingPlanAction(
    BuildContext context,
    WidgetRef ref,
    Activity? activity,
    Event event,
  ) async {
    // Capture context-dependent values BEFORE any async gaps
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Navigate to protocol selection screen
    final selectedProtocol = await navigator.push<int>(
      MaterialPageRoute(
        builder: (context) => CarbLoadingProtocolSelectionScreen(event: event),
      ),
    );

    // Early return if no protocol selected or context is no longer mounted
    if (selectedProtocol == null || !context.mounted) {
      return;
    }

    try {
      // Read fresh provider references AFTER navigation
      // This ensures we don't use disposed providers
      final carbLoadingController = ref.read(carbLoadingControllerProvider.notifier);
      final userRepository = await ref.read(userRepositoryProvider.future);
      final analytics = ref.read(appExternalDepsProvider).analytics;

      // Get user profile for body weight
      final userProfile = await userRepository.getUserProfile();

      if (userProfile == null) {
        if (context.mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Please complete your profile first'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get race date from activity or event startTime
      DateTime raceDate;
      if (activity != null) {
        raceDate = activity.scheduledDateTime;
      } else if (event.startTime != null) {
        raceDate = DateTime.parse(event.startTime!);
      } else {
        throw Exception('Event has no date');
      }

      if (event.hasCarbLoading) {
        // Update existing carb loading protocol
        await carbLoadingController.updateCarbLoadingProtocol(
          eventId: event.id,
          newProtocolDays: selectedProtocol,
          raceDate: raceDate,
          bodyWeightPounds: userProfile.weightPounds,
        );

        if (context.mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Updated to $selectedProtocol-day carb loading plan!'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh the event detail to show updated info
          ref.invalidate(eventDetailProvider(eventId));
        }
      } else {
        // Create new carb loading plan

        // TODO: Track carb loading plan creation (analytics method needs to be implemented)
        // await analytics.trackCarbLoadingPlanCreationStarted(
        //   eventId: event.id,
        //   activityType: activity?.activityType.name ?? 'unknown',
        //   eventDate: raceDate,
        // );

        await carbLoadingController.createCarbLoadingPlan(
          eventId: event.id,
          protocolDays: selectedProtocol,
          raceDate: raceDate,
          bodyWeightPounds: userProfile.weightPounds,
        );

        if (context.mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Created $selectedProtocol-day carb loading plan!'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh the event detail to show updated info
          ref.invalidate(eventDetailProvider(eventId));
        }
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error creating plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildActionButtonsCard(BuildContext context, WidgetRef ref, Activity? activity, Event event) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nutrition Planning',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Nutrition Plan Button (Create or View)
            PrimaryButton(
              onPressed: () async {
                if (activity != null) {
                  // Activity exists - check if nutrition plan exists
                  if (event.hasNutritionPlan) {
                    // Navigate to view/edit existing nutrition plan
                    context.push(
                      '/plan',
                      extra: {
                        'mode': 'view',
                        'activityId': activity.id,
                      },
                    );
                  } else {
                    // Navigate to distance/pace/gut entry screen to create new plan
                    context.push(
                      '/distance-pace-gut-entry',
                      extra: {
                        'initialDate': activity.scheduledDateTime,
                        'distance': activity.distanceMiles,
                        'goalPace': event.goalPaceMinutesPerMile,
                        'activityId': activity.id, // Link plan to this activity
                        'eventId': event.id, // Pass event ID to link back
                      },
                    );
                  }
                } else {
                  // No activity yet - create one first, then navigate
                  try {
                    // Get event date and calculate distance from event type
                    final scheduledDateTime = event.startTime != null
                        ? DateTime.parse(event.startTime!)
                        : DateTime.now();
                    final distanceMiles = _getEventDistanceMiles(event.eventType);

                    // Create activity using ActivitiesController directly
                    final activitiesController = ref.read(activitiesControllerProvider.notifier);
                    final activityId = await activitiesController.createActivity(
                      title: event.eventName ?? event.formattedEventType,
                      scheduledDateTime: scheduledDateTime,
                      activityType: ActivityType.running,
                      distanceMiles: distanceMiles,
                    );

                    // Link activity to event using EventsController directly
                    final eventsController = ref.read(eventsControllerProvider.notifier);
                    await eventsController.updateEvent(
                      event.copyWith(activityId: activityId),
                    );

                    // Refresh the event detail provider to get updated data
                    ref.invalidate(eventDetailProvider(eventId));

                    // Navigate to distance/pace/gut entry
                    if (context.mounted) {
                      context.push(
                        '/distance-pace-gut-entry',
                        extra: {
                          'initialDate': scheduledDateTime,
                          'distance': distanceMiles,
                          'goalPace': event.goalPaceMinutesPerMile,
                          'activityId': activityId,
                          'eventId': event.id, // Pass event ID to link back
                        },
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error creating activity: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              text: event.hasNutritionPlan ? 'View Nutrition Plan' : 'Create Nutrition Plan',
            ),

            const SizedBox(height: 12),

            // Create or Edit Carb Loading Plan Button
            SecondaryButton(
              onPressed: () => _handleCarbLoadingPlanAction(
                context,
                ref,
                activity,
                event,
              ),
              text: event.hasCarbLoading ? 'Edit Carb Loading Plan' : 'Create Carb Loading Plan',
            ),

            const SizedBox(height: 16),

            // Info text
            Text(
              'Create a nutrition plan for race day, or set up a multi-day carb loading protocol to maximize your glycogen stores.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
