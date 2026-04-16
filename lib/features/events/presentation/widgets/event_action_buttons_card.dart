import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../activities/domain/activity.dart';
import '../../../calendar/domain/event_subtype.dart';
import '../../../carb_loading/presentation/providers/carb_loading_controller.dart';
import '../../../carb_loading/presentation/screens/carb_loading_day_detail_page.dart';
import '../../../carb_loading/presentation/screens/carb_loading_protocol_selection_screen.dart';
import '../../../../features/auth/data/user_repository.dart';
import '../../../../shared/database/app_database.dart' as db;
import '../../../../shared/services/logging_service.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../domain/event.dart';
import '../providers/events_controller.dart';

/// Event action buttons card showing nutrition planning and carb loading actions
class EventActionButtonsCard extends ConsumerWidget {
  final Activity? activity;
  final Event event;
  final String eventId;
  final String? forUserId;

  const EventActionButtonsCard({
    super.key,
    required this.activity,
    required this.event,
    required this.eventId,
    this.forUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasLinkedNutritionPlan =
        activity != null && activity!.nutritionPlanData != null;

    return BaseCard(
      margin: AppSpacing.screenPaddingHorizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nutrition Planning',
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Nutrition Plan Button (Create or View)
          KylePrimaryButton(
            onPressed: () async {
              if (hasLinkedNutritionPlan) {
                // Event is linked to activity - navigate to view/edit existing nutrition plan
                context.push(
                  '/plan',
                  extra: {'mode': 'view', 'activityId': activity!.id},
                );
              } else {
                // No activity linked yet - navigate to create new plan
                // We pass BOTH activityId (if exists) and eventId

                final scheduledDateTime =
                    activity?.scheduledDateTime ??
                    (event.startTime != null
                        ? DateTime.parse(event.startTime!)
                        : DateTime.now());

                final activityType = _getActivityTypeForNavigation(event);
                final distanceMiles =
                    activity?.distanceMiles ?? _getEventDistanceMiles(event);
                final eventSubtype = _getEventSubtype(event);

                final extras = <String, dynamic>{
                  'initialDate': scheduledDateTime,
                  'distance': distanceMiles,
                  'goalPace': event.goalPaceMinutesPerMile,
                  'activityId':
                      activity?.id, // Pass existing activity ID if any
                  'eventId':
                      event.id, // Pass event ID to link back after creation
                  'activityType': activityType,
                  'initialTitle': event.eventName,
                  'eventName':
                      event.eventName, // Pass event name for activity title
                  if (forUserId != null) 'forUserId': forUserId,
                };

                // For brick events, pass individual leg distances from EventSubtype
                if (activityType == 'brick' && eventSubtype != null) {
                  if (eventSubtype.swimDistanceMeters != null) {
                    extras['brickSwimDistanceMeters'] =
                        eventSubtype.swimDistanceMeters;
                  }
                  if (eventSubtype.bikeDistanceMiles != null) {
                    extras['brickBikeDistanceMiles'] =
                        eventSubtype.bikeDistanceMiles;
                  }
                  if (eventSubtype.runDistanceMiles != null) {
                    extras['brickRunDistanceMiles'] =
                        eventSubtype.runDistanceMiles;
                  }
                }

                context.push('/distance-pace-gut-entry', extra: extras);
              }
            },
            text: hasLinkedNutritionPlan
                ? 'View Nutrition Plan'
                : 'Create Nutrition Plan',
            icon: hasLinkedNutritionPlan
                ? FontAwesomeIcons.eye
                : FontAwesomeIcons.plus,
          ),

          const SizedBox(height: AppSpacing.sm),

          // Create or Edit Carb Loading Plan Button
          KyleSecondaryButton(
            onPressed: () => _handleCarbLoadingPlanAction(
              context,
              ref,
              activity,
              event,
              eventId,
            ),
            text: event.hasCarbLoading
                ? 'Edit Carb Loading Plan'
                : 'Create Carb Loading Plan',
            icon: event.hasCarbLoading
                ? FontAwesomeIcons.pen
                : FontAwesomeIcons.plus,
          ),


          // const SizedBox(height: AppSpacing.md),

          // // Info text
          // Text(
          //   'Create a nutrition plan for race day, or set up a multi-day carb loading protocol to maximize your glycogen stores.',
          //   style: AppTextStyles.bodyMedium.copyWith(
          //     color: Theme.of(context).colorScheme.onSurfaceVariant,
          //   ),
          //   textAlign: TextAlign.center,
          // ),
        ],
      ),
    );
  }

  double? _getEventDistanceMiles(Event event) {
    if (event.eventSubtype == null) return null;

    // Look up the EventSubtype to get distance information
    final eventSubtype = EventSubtype.findByName(
      event.eventType.dbValue,
      event.eventSubtype!,
    );

    return eventSubtype?.totalDistanceMiles;
  }

  /// Map event type to the correct NewActivityScreen tab
  ///
  /// Single-sport events map directly; multi-sport events (triathlon,
  /// duathlon, multisport) map to the brick tab.
  String _getActivityTypeForNavigation(Event event) {
    switch (event.eventType) {
      case ActivityType.running:
        return 'running';
      case ActivityType.cycling:
        return 'cycling';
      case ActivityType.swimming:
        return 'swimming';
      case ActivityType.triathlon:
      case ActivityType.duathlon:
      case ActivityType.multisport:
      case ActivityType.brick:
        return 'brick';
    }
  }

  /// Look up the EventSubtype for this event (if available)
  EventSubtype? _getEventSubtype(Event event) {
    if (event.eventSubtype == null) return null;
    return EventSubtype.findByName(
      event.eventType.dbValue,
      event.eventSubtype!,
    );
  }

  /// Handle carb loading plan creation or update
  /// This method is extracted to avoid using disposed refs across async gaps
  Future<void> _handleCarbLoadingPlanAction(
    BuildContext context,
    WidgetRef ref,
    Activity? activity,
    Event event,
    String eventId,
  ) async {
    // Capture context-dependent values BEFORE any async gaps
    final navigator = Navigator.of(context);

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
      final carbLoadingController = ref.read(
        carbLoadingControllerProvider.notifier,
      );
      final userRepository = await ref.read(userRepositoryProvider.future);

      // Get user profile for body weight
      // When coach is creating for an athlete, get the athlete's profile
      final userProfile = forUserId != null
          ? await userRepository.getUserProfileById(forUserId!)
          : await userRepository.getUserProfile();

      if (userProfile == null) {
        if (context.mounted) {
          MealvanaSnackbar.showWarning(
            context,
            forUserId != null
                ? 'Athlete profile not found'
                : 'Please complete your profile first',
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
          MealvanaSnackbar.showSuccess(
            context,
            'Updated to $selectedProtocol-day carb loading plan!',
          );
          // Refresh the event detail to show updated info
          ref.invalidate(eventDetailProvider(eventId));
        }
      } else {
        // Create new carb loading plan

        await carbLoadingController.createCarbLoadingPlan(
          eventId: event.id,
          protocolDays: selectedProtocol,
          raceDate: raceDate,
          bodyWeightPounds: userProfile.weightPounds,
          forUserId: forUserId,
        );

        if (context.mounted) {
          MealvanaSnackbar.showSuccess(
            context,
            'Created $selectedProtocol-day carb loading plan!',
          );
          // Refresh the event detail to show updated info
          ref.invalidate(eventDetailProvider(eventId));

          // Navigate to the first day of the carb loading plan
          try {
            // Fetch the carb loading plan to get plan ID
            final carbLoadingPlan = await ref.read(
              carbLoadingPlanProvider(event.id).future,
            );

            if (carbLoadingPlan != null) {
              // Fetch all carb loading days for this plan
              final carbLoadingDays = await ref.read(
                carbLoadingDaysForPlanProvider(carbLoadingPlan.id).future,
              );

              // Cast to the correct type
              final days = carbLoadingDays.cast<db.CarbLoadingDay>();

              // Find the first day (earliest date)
              if (days.isNotEmpty && context.mounted) {
                // Sort by date to ensure we get the first day (T-2, T-1, etc.)
                final sortedDays = List<db.CarbLoadingDay>.from(days)
                  ..sort((a, b) => a.planDate.compareTo(b.planDate));

                final firstDay = sortedDays.first;

                // Replace event detail with carb loading day so back returns
                // directly to the previous screen (e.g. Events list).
                await Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) =>
                        CarbLoadingDayDetailPage(carbLoadingDay: firstDay),
                  ),
                );
              }
            }
          } catch (e) {
            ref
                .read(appLoggerProvider)
                .error('Error navigating to carb loading day', error: e);
            // Don't show error to user - plan was created successfully
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        MealvanaSnackbar.showError(context, 'Error creating plan: $e');
      }
    }
  }

}
