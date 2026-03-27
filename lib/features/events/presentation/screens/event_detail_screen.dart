import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:mealvana_endurance/shared/widgets/content_area.dart';
import '../providers/events_controller.dart';
import '../widgets/event_header_card.dart';
import '../widgets/event_details_card.dart';
import '../widgets/event_action_buttons_card.dart';
import '../widgets/event_footer_links.dart';
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
  final String eventId;
  final String? forUserId;

  const EventDetailScreen({super.key, required this.eventId, this.forUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventDetailAsync = ref.watch(
      eventDetailProvider(eventId, forUserId: forUserId),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const CustomAppBarBackButton(),
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
          // Only show menu when event is loaded successfully
          if (eventDetailAsync.hasValue)
            PopupMenuButton<String>(
              icon: Icon(
                FontAwesomeIcons.ellipsisVertical,
                size: AppIconSizes.sm,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              tooltip: 'More options',
              onSelected: (value) async {
                final event = eventDetailAsync.value!.event;
                if (value == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventFormScreen(event: event),
                    ),
                  ).then((_) {
                    ref.invalidate(
                      eventDetailProvider(eventId, forUserId: forUserId),
                    );
                  });
                } else if (value == 'delete') {
                  await _showDeleteConfirmation(context, ref, event.eventName);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
                        FontAwesomeIcons.pen,
                        size: AppIconSizes.xs,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Edit Event',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        FontAwesomeIcons.trash,
                        size: AppIconSizes.xs,
                        color: AppColors.dragonfruit,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Delete Event',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.dragonfruit,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: ContentArea.wide(
        child: eventDetailAsync.when(
          data: (eventDetail) {
            final activity = eventDetail.activity;
            final event = eventDetail.event;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Event Header Card
                  EventHeaderCard(activity: activity, event: event),

                  const SizedBox(height: AppSpacing.md),

                  // Event Details Card
                  EventDetailsCard(activity: activity, event: event),

                  const SizedBox(height: AppSpacing.md),

                  // Action Buttons Card
                  EventActionButtonsCard(
                    activity: activity,
                    event: event,
                    eventId: eventId,
                    forUserId: forUserId,
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Footer links for navigation
                  const EventFooterLinks(),

                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.electrolyte),
          ),
          error: (error, stack) => SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),

                // Error message card
                BaseCard(
                  margin: AppSpacing.screenPaddingHorizontal.copyWith(
                    top: AppSpacing.lg,
                  ),
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
                      Text(
                        error.toString(),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Footer links still visible even on error
                const EventFooterLinks(),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Show delete confirmation dialog
  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    String? eventName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Event',
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${eventName ?? 'this event'}"?\n\n'
          'This will also delete any associated nutrition plans and carb loading plans.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.dragonfruit,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        // Show loading indicator
        MealvanaSnackbar.showInfo(
          context,
          'Deleting event...',
          duration: const Duration(seconds: 1),
        );

        // Delete the event
        await ref.read(eventsControllerProvider.notifier).deleteEvent(eventId);

        if (context.mounted) {
          // Show success message
          MealvanaSnackbar.showSuccess(context, 'Event deleted successfully');

          // Navigate back to events list
          context.go('/main');
        }
      } catch (e) {
        if (context.mounted) {
          MealvanaSnackbar.showError(context, 'Failed to delete event: $e');
        }
      }
    }
  }
}
