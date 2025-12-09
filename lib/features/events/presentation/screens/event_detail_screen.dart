import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/utils/location_formatter.dart';
import '../../../activities/domain/activity.dart';
import '../../../calendar/domain/event_subtype.dart';
import '../../domain/event.dart';
import '../providers/events_controller.dart';
import '../../../carb_loading/presentation/providers/carb_loading_controller.dart';
import '../../../../features/auth/data/user_repository.dart';
import '../../../carb_loading/presentation/screens/carb_loading_protocol_selection_screen.dart';
import '../../../carb_loading/presentation/screens/carb_loading_day_detail_page.dart';
import '../../../../shared/database/app_database.dart' as db;
import '../../../../shared/services/logging_service.dart';
import 'event_form_screen.dart';

/// Event Detail Screen showing event information and action buttons.
///
/// Updated with Kyle's Design System:
/// - AppColors for theme-aware colors
/// - AppTextStyles for typography
/// - BaseCard for consistent card styling
/// - KylePrimaryButton for actions
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
  final int eventId;

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
              'Event Details',
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
              IconButton(
                icon: Icon(
                  FontAwesomeIcons.pen,
                  size: AppIconSizes.sm,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
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
            'Event Details',
            style: AppTextStyles.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: AppColors.electrolyte,
          ),
        ),
      ),
      error: (error, stack) => Scaffold(
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
            'Event Details',
            style: AppTextStyles.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        body: Center(
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
                'Error loading event',
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
            ],
          ),
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

          const SizedBox(height: AppSpacing.md),

          // Event Details Card
          _buildEventDetailsCard(context, activity, event),

          const SizedBox(height: AppSpacing.md),

          // Action Buttons Card
          _buildActionButtonsCard(context, ref, activity, event),

          const SizedBox(height: AppSpacing.md),

          // Text links for navigation
          _buildFooterLinks(context),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildEventHeaderCard(BuildContext context, Activity? activity, Event event) {
    return BaseCard(
      margin: AppSpacing.screenPaddingHorizontal.copyWith(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event name/type
          Text(
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
                  activity != null
                    ? DateFormat('EEEE, MMMM d, yyyy').format(activity.scheduledDateTime)
                    : event.startTime != null
                      ? DateFormat('EEEE, MMMM d, yyyy').format(DateTime.parse(event.startTime!))
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.electrolyte.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.electrolyte.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        countdownText,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.electrolyte,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEventDetailsCard(BuildContext context, Activity? activity, Event event) {
    return BaseCard(
      margin: AppSpacing.screenPaddingHorizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Event Information',
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Distance
          if (activity?.distanceMiles != null)
            _buildDetailRow(
              context,
              icon: FontAwesomeIcons.ruler,
              label: 'Distance',
              value: '${activity!.distanceMiles} miles',
            ),

          if (event.location != null) ...[
            const Divider(height: AppSpacing.xl),
            _buildDetailRow(
              context,
              icon: FontAwesomeIcons.locationDot,
              label: 'Location',
              value: LocationFormatter.parseAndFormatCityState(event.location),
            ),
          ],

          if (event.formattedGoalTime != null) ...[
            const Divider(height: AppSpacing.xl),
            _buildDetailRow(
              context,
              icon: FontAwesomeIcons.clock,
              label: 'Goal Time',
              value: event.formattedGoalTime!,
            ),
          ],

          if (event.formattedGoalPace != null) ...[
            const Divider(height: AppSpacing.xl),
            _buildDetailRow(
              context,
              icon: FontAwesomeIcons.gaugeHigh,
              label: 'Goal Pace',
              value: event.formattedGoalPace!,
            ),
          ],

          if (event.registrationUrl != null) ...[
            const Divider(height: AppSpacing.xl),
            _buildDetailRow(
              context,
              icon: FontAwesomeIcons.link,
              label: 'Registration',
              value: 'View registration',
              isLink: true,
            ),
          ],

          if (event.bibNumber != null) ...[
            const Divider(height: AppSpacing.xl),
            _buildDetailRow(
              context,
              icon: FontAwesomeIcons.hashtag,
              label: 'Bib Number',
              value: event.bibNumber!,
            ),
          ],
        ],
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
        Icon(
          icon,
          size: AppIconSizes.sm,
          color: AppColors.electrolyte,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.smallLabel.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                value,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: isLink
                      ? AppColors.electrolyte
                      : Theme.of(context).colorScheme.onSurface,
                  decoration: isLink ? TextDecoration.underline : null,
                ),
              ),
            ],
          ),
        ),
      ],
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

      // Get user profile for body weight
      final userProfile = await userRepository.getUserProfile();

      if (userProfile == null) {
        if (context.mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Please complete your profile first',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                ),
              ),
              backgroundColor: AppColors.dragonfruit,
              behavior: SnackBarBehavior.floating,
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
              content: Text(
                'Updated to $selectedProtocol-day carb loading plan!',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                ),
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
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
        );

        if (context.mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Created $selectedProtocol-day carb loading plan!',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                ),
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Refresh the event detail to show updated info
          ref.invalidate(eventDetailProvider(eventId));

          // Navigate to the first day of the carb loading plan
          try {
            // Fetch the carb loading plan to get plan ID
            final carbLoadingPlan = await ref.read(carbLoadingPlanProvider(event.id).future);

            if (carbLoadingPlan != null) {
              // Fetch all carb loading days for this plan
              final carbLoadingDays = await ref.read(carbLoadingDaysForPlanProvider(carbLoadingPlan.id).future);

              // Cast to the correct type
              final days = carbLoadingDays.cast<db.CarbLoadingDay>();

              // Find the first day (earliest date)
              if (days.isNotEmpty && context.mounted) {
                // Sort by date to ensure we get the first day (T-2, T-1, etc.)
                final sortedDays = List<db.CarbLoadingDay>.from(days)
                  ..sort((a, b) => a.planDate.compareTo(b.planDate));

                final firstDay = sortedDays.first;

                // Navigate to the carb loading day detail page
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CarbLoadingDayDetailPage(
                      carbLoadingDay: firstDay,
                    ),
                  ),
                );
              }
            }
          } catch (e) {
            ref.read(appLoggerProvider).error('Error navigating to carb loading day', error: e);
            // Don't show error to user - plan was created successfully
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Error creating plan: $e',
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
  }

  Widget _buildActionButtonsCard(BuildContext context, WidgetRef ref, Activity? activity, Event event) {
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
              if (activity != null && event.hasNutritionPlan) {
                // Activity exists AND nutrition plan exists - navigate to view/edit existing nutrition plan
                context.push(
                  '/plan',
                  extra: {
                    'mode': 'view',
                    'activityId': activity.id,
                  },
                );
              } else {
                // Either no activity yet OR activity exists but no nutrition plan
                // Navigate to distance/pace/gut entry screen to create new plan
                // We pass BOTH activityId (if exists) and eventId
                
                final scheduledDateTime = activity?.scheduledDateTime ?? 
                    (event.startTime != null ? DateTime.parse(event.startTime!) : DateTime.now());
                
                final distanceMiles = activity?.distanceMiles ?? _getEventDistanceMiles(event);
                
                context.push(
                  '/distance-pace-gut-entry',
                  extra: {
                    'initialDate': scheduledDateTime,
                    'distance': distanceMiles,
                    'goalPace': event.goalPaceMinutesPerMile,
                    'activityId': activity?.id, // Pass existing activity ID if any
                    'eventId': event.id, // Pass event ID to link back after creation
                  },
                );
              }
            },
            text: event.hasNutritionPlan ? 'View Nutrition Plan' : 'Create Nutrition Plan',
            icon: event.hasNutritionPlan ? FontAwesomeIcons.eye : FontAwesomeIcons.plus,
          ),

          const SizedBox(height: AppSpacing.sm),

          // Create or Edit Carb Loading Plan Button
          KyleSecondaryButton(
            onPressed: () => _handleCarbLoadingPlanAction(
              context,
              ref,
              activity,
              event,
            ),
            text: event.hasCarbLoading ? 'Edit Carb Loading Plan' : 'Create Carb Loading Plan',
            icon: event.hasCarbLoading ? FontAwesomeIcons.pen : FontAwesomeIcons.plus,
          ),

          const SizedBox(height: AppSpacing.md),

          // Info text
          Text(
            'Create a nutrition plan for race day, or set up a multi-day carb loading protocol to maximize your glycogen stores.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLinks(BuildContext context) {
    return Padding(
      padding: AppSpacing.screenPaddingHorizontal,
      child: Column(
        children: [
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.xs,
            children: [
              TextButton(
                onPressed: () => context.push('/events'),
                child: Text(
                  'View events list',
                  style: AppTextStyles.buttonTertiary.copyWith(
                    color: AppColors.electrolyte,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push<Map<String, dynamic>>(
                    MaterialPageRoute(
                      builder: (_) => const EventFormScreen(),
                    ),
                  );
                  if (result != null && result['success'] == true) {
                    final newEventId = result['eventId'];
                    if (newEventId is int && context.mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => EventDetailScreen(eventId: newEventId),
                        ),
                      );
                    }
                  }
                },
                child: Text(
                  'Create new event',
                  style: AppTextStyles.buttonTertiary.copyWith(
                    color: AppColors.electrolyte,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
