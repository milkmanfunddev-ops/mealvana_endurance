import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../activities/domain/activity.dart';
import '../../../carb_loading/presentation/providers/carb_loading_controller.dart';
import '../../../carb_loading/presentation/screens/carb_loading_protocol_selection_screen.dart';
import '../../../carb_loading/presentation/screens/carb_plan_summary_screen.dart';
import '../../../carb_loading/domain/carb_loading_entryway_engine.dart';
import '../../../../features/auth/data/user_repository.dart';
import '../../../../shared/database/app_database.dart' as db;
import '../../application/nutrition_plan_navigation.dart';
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
                final extras = buildNutritionPlanExtras(
                  event: event,
                  activity: activity,
                  forUserId: forUserId,
                );

                context.push('/distance-pace-gut-entry', extra: extras);
              }
            },
            text: hasLinkedNutritionPlan
                ? 'View Nutrition Plan'
                : 'Create Nutrition Plan',
            icon: hasLinkedNutritionPlan
                ? FontAwesomeIcons.eye.data
                : FontAwesomeIcons.plus.data,
          ),

          const SizedBox(height: AppSpacing.sm),

          // The carb-loading entryway row (CE-1, two states + the CE-8
          // race-day state). With a plan: a door to the plan summary —
          // re-picking is an action ON the plan, one level in. Without one:
          // Set Up opens the chooser; on race day nothing is choosable and
          // the row says so instead of hiding.
          if (event.hasCarbLoading)
            KyleSecondaryButton(
              key: const ValueKey('event_details.carb_loading_button'),
              onPressed: () => CarbPlanSummaryScreen.open(context, eventId),
              text: 'Carb Loading Plan',
              icon: FontAwesomeIcons.chartLine.data,
            )
          else if (_carbWindowPassed(event))
            KyleSecondaryButton(
              key: const ValueKey('event_details.carb_loading_button'),
              onPressed: null,
              text: 'Carb loading window has passed',
              icon: FontAwesomeIcons.clock.data,
            )
          else ...[
            KyleSecondaryButton(
              key: const ValueKey('event_details.carb_loading_button'),
              onPressed: () => _handleCarbLoadingPlanAction(
                context,
                ref,
                activity,
                event,
                eventId,
              ),
              text: 'Set Up Carb Loading',
              icon: FontAwesomeIcons.plus.data,
            ),
            if (_feasibleSubtitle(event) != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  key: const ValueKey('event_details.carb_loading_subtitle'),
                  _feasibleSubtitle(event)!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],

          const SizedBox(height: AppSpacing.sm),

          // Race Day Checklist Button
          KyleSecondaryButton(
            key: const ValueKey('event_details.checklist_button'),
            onPressed: () {
              context.push('/events/$eventId/checklist');
            },
            text: 'Race Day Checklist',
            icon: FontAwesomeIcons.listCheck.data,
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

      // CREATE (the edit path lives on the plan summary now — CE-4). The
      // retired behavior push-replaced onto the legacy day page and popped
      // event details out of the stack; CE-2 rules the opposite: selection
      // returns HERE, the row flips to its plan state, and only when the
      // window is already underway does a snackbar CTA offer today's fuel.
      await carbLoadingController.createCarbLoadingPlan(
        eventId: event.id,
        protocolDays: selectedProtocol,
        raceDate: raceDate,
        bodyWeightPounds: userProfile.weightPounds,
        forUserId: forUserId,
      );

      if (context.mounted) {
        ref.invalidate(eventDetailProvider(eventId));
        final startDate = raceDate.subtract(Duration(days: selectedProtocol));
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final underway = !DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
        ).isAfter(today);
        MealvanaSnackbar.showSuccess(
          context,
          'Created $selectedProtocol-day carb loading plan!',
          actionLabel: underway ? "Go to today's fuel" : null,
          onAction: underway
              ? () => Navigator.of(context).popUntil((r) => r.isFirst)
              : null,
        );
      }
    } catch (e) {
      if (context.mounted) {
        MealvanaSnackbar.showError(context, 'Error creating plan: $e');
      }
    }
  }

  /// CE-8: race morning (or later) offers nothing — daysUntilRace counts
  /// whole days with race morning == 0.
  bool _carbWindowPassed(Event event) {
    final days = _daysUntilRace(event);
    return days != null &&
        CarbLoadingEntrywayEngine.choosableProtocols(days).isEmpty;
  }

  /// F1: the subtitle enumerates only the feasible protocol set.
  String? _feasibleSubtitle(Event event) {
    final days = _daysUntilRace(event);
    if (days == null) return null;
    final feasible = CarbLoadingEntrywayEngine.choosableProtocols(
      days,
    ).reversed.toList(growable: false);
    if (feasible.isEmpty) return null;
    if (feasible.length == 1) return '${feasible.first}-day protocol';
    final parts = [
      for (var i = 0; i < feasible.length; i++)
        i == feasible.length - 1
            ? '${feasible[i]}-day protocols'
            : '${feasible[i]}-',
    ];
    final head = parts.sublist(0, parts.length - 1).join(', ');
    final sep = feasible.length > 2 ? ', and ' : ' and ';
    return '$head$sep${parts.last}';
  }

  int? _daysUntilRace(Event event) {
    DateTime? race = event.eventDate;
    if (race == null && event.startTime != null) {
      race = DateTime.tryParse(event.startTime!);
    }
    if (race == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(race.year, race.month, race.day).difference(today).inDays;
  }
}
