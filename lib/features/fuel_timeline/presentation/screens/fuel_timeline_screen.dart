import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/core/guarded_navigation.dart';
import '../../../../shared/services/analytics/analytics_events.dart';
import '../../../../shared/services/analytics/analytics_tracker.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../activities/domain/activity.dart';
import '../../../activities/domain/brick_exceptions.dart';
import '../../../activities/presentation/navigation/open_activity_fuel.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../../../activities/presentation/providers/brick_actions_controller.dart';
import '../../../activities/presentation/providers/brick_creation_available_provider.dart';
import '../../../activities/presentation/providers/brick_selection_controller.dart';
import '../../../activities/presentation/widgets/activity_card.dart';
import '../../../activities/presentation/widgets/brick_confirmation_dialog.dart';
import '../../../activities/presentation/widgets/brick_group_card.dart';
import '../../../activities/presentation/widgets/brick_minimum_warning_dialog.dart';
import '../../../activities/presentation/widgets/brick_ungroup_dialog.dart';
import '../../../activities/presentation/widgets/brick_validation_error_dialog.dart';
import '../../../activities/presentation/widgets/create_brick_button.dart';
import '../../../calendar/presentation/providers/calendar_selected_date_provider.dart';
import '../../../calendar/presentation/providers/calendar_day_indicators_provider.dart';
import '../../../events/presentation/screens/event_detail_screen.dart';
import '../../../calendar/presentation/providers/calendar_view_provider.dart';
import '../../../calendar/presentation/widgets/calendar_view_toggle.dart'
    show CalendarViewMode;
import '../../../calendar/presentation/widgets/calendar_month_view_kyle.dart';
import '../../../content/application/content_service.dart';
import '../../../daily_macros/presentation/providers/daily_macros_controller.dart';
import '../../../integrations/presentation/widgets/garmin_connect_banner.dart';
import '../../../meal_logging/domain/meal_log.dart';
import '../../../meal_logging/presentation/providers/meal_log_providers.dart';
import '../../../meal_logging/presentation/screens/log_meal_screen.dart';
import '../../application/day_timeline_assembler.dart';
import '../../domain/fuel_timeline_filter.dart';
import '../../domain/timeline_node.dart';
import '../fuel_timeline_type.dart';
import '../providers/fuel_timeline_controller.dart';
import '../providers/fuel_timeline_view_state.dart';
import '../widgets/energy_breakdown_sheet.dart';
import '../widgets/energy_dashboard_card.dart';
import '../widgets/fuel_filter_row.dart';
import '../widgets/fuel_timeline_day_header.dart';
import '../widgets/timeline_node_tile.dart';

/// The unified daily "Fuel Timeline" screen — the new Nutrition tab.
///
/// Phase 2 scaffold: calendar header (reused), the All/"Energy Balance"
/// dashboard, the filter + tracking/timeline toggles, Add Food / Add Activity
/// (wired to existing flows), and the live chronological meal + workout
/// timeline. Node interactions and the Meals/Workout dashboard variants land in
/// later phases.
class FuelTimelineScreen extends ConsumerWidget {
  const FuelTimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(calendarSelectedDateProvider);
    final calendarMode = ref.watch(calendarViewProvider);
    final macrosAreCalculating =
        ref.watch(dailyMacrosControllerProvider).value?.isCalculating ?? false;

    // Brand surface — resolves to blackberry in dark mode, cream in light
    // mode (matches the app's ThemeData, so the screen renders correctly in
    // both themes instead of a fixed dark surface).
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 12),
          // Header manages its own per-section insets (toggle/month inset more,
          // week strip spreads wide — matching the mockup).
          const FuelTimelineDayHeader(),
          if (macrosAreCalculating)
            const LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.electrolyte,
              backgroundColor: Colors.transparent,
            ),
          if (calendarMode == CalendarViewMode.month) ...[
            const SizedBox(height: 8),
            CalendarMonthViewKyle(
              selectedDate: selectedDate,
              onDateSelected: (date) =>
                  ref.read(calendarSelectedDateProvider.notifier).setDate(date),
              // Real dots for activities, events, and carb-loading days. This
              // used to be `const {}`, which is why nothing showed on the month
              // calendar after the home tab moved to the fuel timeline.
              dayIndicators: ref.watch(calendarDayIndicatorsProvider),
            ),
          ],
          Expanded(
            child: ref
                .watch(fuelTimelineDayProvider)
                .when(
                  // Keep showing the current day's content through a reload
                  // (e.g. date change, invalidateSelf after a mutation)
                  // instead of flashing back to a bare spinner.
                  skipLoadingOnReload: true,
                  data: (result) => _body(context, ref, result, selectedDate),
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.electrolyte,
                    ),
                  ),
                  error: (e, _) => _error(context, ref),
                ),
          ),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    DayTimelineResult result,
    DateTime selectedDate,
  ) {
    final view = ref.watch(fuelTimelineViewProvider);
    final viewNotifier = ref.read(fuelTimelineViewProvider.notifier);
    final nodes = result.nodes
        .where(view.filter.matches)
        .toList(growable: false);
    final workoutNodes = result.nodes.whereType<WorkoutNode>().toList(
      growable: false,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: AppSpacing.screenPaddingHorizontal,
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),
              // Garmin connect prompt (self-hides once connected). Jade banner
              // intentionally not shown here (Lee, 2026-06-28).
              // Do NOT add a SizedBox after this: the banner carries its own
              // bottom margin so the gap vanishes when the banner self-hides.
              const GarminConnectBanner(),
              if (view.trackingOn) ...[
                EnergyDashboardCard(
                  filter: view.filter,
                  summary: result.summary,
                  workouts: workoutNodes,
                  expanded: view.dashOpen,
                  onToggle: viewNotifier.toggleDash,
                  onOpenBreakdown: () => showEnergyBreakdownSheet(context),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              FuelFilterRow(
                filter: view.filter,
                trackingOn: view.trackingOn,
                timelineOpen: view.timelineOpen,
                onPickFilter: viewNotifier.setFilter,
                onToggleTracking: viewNotifier.toggleTracking,
                onToggleTimeline: viewNotifier.toggleTimeline,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
        // The timeline scrolls; the Add row sits at its top so the rail runs up
        // to it (per the mockup).
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              100,
            ),
            children: [
              // Brick grouping controls: "Create Brick" when the day has 2+
              // activities of different sports, or Cancel/Confirm while in
              // selection mode. Hidden under the Meals filter (no workouts
              // visible to group).
              if (view.filter.showsAddActivity)
                _brickControls(context, ref, workoutNodes, selectedDate),
              _addRow(context, ref, view, selectedDate),
              for (final n in nodes) _tile(context, ref, n, view),
              if (nodes.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: _emptyTimeline(context, ref),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// The Add Food / Add Activity row, with the timeline rail running up to it
  /// (a hollow "now" marker), matching the mockup.
  Widget _addRow(
    BuildContext context,
    WidgetRef ref,
    FuelTimelineViewState view,
    DateTime selectedDate,
  ) {
    final addButtons = _addButtons(context, ref, view.filter, selectedDate);
    if (!view.timelineOpen) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: addButtons,
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? AppColors.cream : AppColors.blackberry;
    // The hollow "now" marker's fill is meant to match the real page
    // background (a cutout), so it must track the theme, not a fixed value.
    final surfaceBg = isDark ? AppColors.blackberry : AppColors.cream;
    // stretch so the rail line fills the full row height and meets the first
    // tile's rail below it (one continuous timeline rail).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: 54),
          const SizedBox(width: 10),
          SizedBox(
            width: 16,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    color: onSurface.withValues(alpha: 0.22),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 11),
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: surfaceBg,
                      border: Border.all(
                        color: onSurface.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Align(alignment: Alignment.topCenter, child: addButtons),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    WidgetRef ref,
    TimelineNode node,
    FuelTimelineViewState view,
  ) {
    switch (node) {
      case MealNode(:final meal):
        return TimelineNodeTile(
          node: node,
          timelineOpen: view.timelineOpen,
          trackingOn: view.trackingOn,
          // Tap the meal → edit-meal page (where components can be edited and
          // swapped). Swipe either direction removes with Undo.
          onTap: () => context.push('/meal-log/edit', extra: {'log': meal}),
          onRemove: () => _deleteMealWithUndo(context, ref, meal),
        );
      case WorkoutNode(:final activity):
        final selectionState = ref.watch(brickSelectionControllerProvider);
        // Brick selection mode: workouts render as selectable activity cards
        // (checkbox + 1/2/3 order badge), mirroring the old activities screen.
        // Full-width (no time rail): these cards are designed for the full
        // screen width and overflow inside the rail row.
        if (selectionState.isSelectionMode) {
          final selectionNotifier = ref.read(
            brickSelectionControllerProvider.notifier,
          );
          return Padding(
            // The card's own 12px bottom margin + 4 ≈ the tile row's 16px gap.
            padding: const EdgeInsets.only(bottom: 4),
            child: ActivityCard(
              activity: activity,
              isSelectionMode: true,
              isSelected: selectionNotifier.isActivitySelected(activity.id),
              selectionOrder: selectionNotifier.getSelectionOrder(activity.id),
              onSelectionToggle: () =>
                  selectionNotifier.toggleActivity(activity),
            ),
          );
        }
        // Brick workouts render as the grouped brick card (segments +
        // View Combined / Ungroup / Remove Segment / Delete), not a regular
        // workout tile. Full-width for the same reason as above; delete goes
        // through its own confirm dialog (it also deletes the nutrition
        // plan), so no swipe-to-remove here.
        if (activity.isBrick) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: BrickGroupCard(
              brick: activity,
              onUngroup: () => _handleUngroupBrick(context, ref, activity),
              onViewCombined: () => _handleViewCombinedBrick(context, activity),
              onRemoveSegment: (segmentIndex) =>
                  _handleRemoveSegment(context, ref, activity, segmentIndex),
              onDelete: () => _handleDeleteBrick(context, ref, activity),
            ),
          );
        }
        return TimelineNodeTile(
          node: node,
          timelineOpen: view.timelineOpen,
          trackingOn: view.trackingOn,
          // Tap the workout → Activity Detail page (its fuel plan / editor).
          // Swipe either direction removes with Undo.
          onTap: () => openActivityFuel(context, activity),
          onRemove: () => _deleteActivityWithUndo(context, ref, activity),
        );
      case EventNode(:final event):
        return TimelineNodeTile(
          node: node,
          timelineOpen: view.timelineOpen,
          trackingOn: view.trackingOn,
          // Tap the race banner → the event detail page.
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EventDetailScreen(eventId: event.id),
            ),
          ),
        );
      case CarbLoadingNode():
        return TimelineNodeTile(
          node: node,
          timelineOpen: view.timelineOpen,
          trackingOn: view.trackingOn,
          // Tap a carb-loading day → the carb loading day detail. Routing is
          // handled by the calendar's carb loading day card flow; here we just
          // surface it. A dedicated tap target is a follow-up.
          onTap: null,
        );
    }
  }

  /// Soft-delete a logged meal with an undo affordance (offline-first), mirroring
  /// the existing meal-log delete flow.
  void _deleteMealWithUndo(BuildContext context, WidgetRef ref, MealLog meal) {
    // Capture the messenger before kicking off the delete so we're never
    // relying on `context` staying valid past this point, and clear any
    // snackbar already in flight so a rapid double-swipe can't queue two
    // "Meal deleted" toasts back to back.
    final messenger = ScaffoldMessenger.of(context);
    ref.read(mealLogControllerProvider.notifier).deleteLog(meal.id);
    messenger.clearSnackBars();
    MealvanaSnackbar.showInfo(
      context,
      'Meal deleted',
      duration: const Duration(seconds: 3),
      actionLabel: 'Undo',
      onAction: () =>
          ref.read(mealLogControllerProvider.notifier).restoreLog(meal.id),
    );
  }

  /// Soft-delete a scheduled activity with an undo affordance, mirroring
  /// [_deleteMealWithUndo]. Undo restores the pre-delete [Activity] via
  /// `restoreActivity`, which optimistically re-inserts it and persists the
  /// object as given — including its (null) `deletedAt`, which clears the
  /// soft-delete.
  void _deleteActivityWithUndo(
    BuildContext context,
    WidgetRef ref,
    Activity activity,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(activitiesControllerProvider.notifier);
    notifier.deleteActivity(activity.id);
    messenger.clearSnackBars();
    MealvanaSnackbar.showInfo(
      context,
      'Activity deleted',
      duration: const Duration(seconds: 3),
      actionLabel: 'Undo',
      // Read the notifier fresh at tap time (the autoDispose provider may have
      // been recreated since delete) and surface any failure — restoreActivity
      // returns a Future, so without this the error would be dropped silently.
      onAction: () async {
        try {
          await ref
              .read(activitiesControllerProvider.notifier)
              .restoreActivity(activity);
        } catch (_) {
          if (context.mounted) {
            MealvanaSnackbar.showError(context, 'Could not restore activity');
          }
        }
      },
    );
  }

  /// Brick grouping controls above the Add row (ported from the old
  /// activities list screen): a "Create Brick" button when the selected day
  /// has 2+ activities of different sports, replaced by Cancel / Confirm (n)
  /// while selection mode is active.
  Widget _brickControls(
    BuildContext context,
    WidgetRef ref,
    List<WorkoutNode> workoutNodes,
    DateTime selectedDate,
  ) {
    final dayActivities = workoutNodes
        .map((n) => n.activity)
        .toList(growable: false);
    final selectionState = ref.watch(brickSelectionControllerProvider);
    final isSelectionMode = selectionState.isSelectionMode;
    final isBrickAvailable = ref.watch(
      isBrickCreationAvailableProvider(
        activities: dayActivities,
        selectedDate: selectedDate,
      ),
    );

    if (!isSelectionMode && !isBrickAvailable) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!isSelectionMode)
            CreateBrickButton(
              onPressed: () => ref
                  .read(brickSelectionControllerProvider.notifier)
                  .enterSelectionMode(),
            ),
          if (isSelectionMode) ...[
            // Flexible so the two buttons can shrink instead of overflowing
            // on narrow widths (the button text ellipsizes gracefully).
            Flexible(
              child: KyleSecondaryButtonSmall(
                text: 'Cancel',
                onPressed: () => ref
                    .read(brickSelectionControllerProvider.notifier)
                    .exitSelectionMode(),
                variant: SecondaryButtonVariant.light,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: KyleSecondaryButtonSmall(
                text: 'Confirm (${selectionState.selectedActivityIds.length})',
                onPressed:
                    ref
                        .read(brickSelectionControllerProvider.notifier)
                        .canCreateBrick()
                    ? () => _handleConfirmSelection(context, ref)
                    : null,
                variant: SecondaryButtonVariant.orange,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Handle Confirm in brick selection mode: confirmation dialog → create the
  /// brick via [BrickActionsController] → exit selection mode. Mirrors the old
  /// activities screen flow, including validation/creation error dialogs.
  Future<void> _handleConfirmSelection(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Selection order is preserved by the controller: [0] = first segment.
    final selectedActivities = List<Activity>.from(
      ref.read(brickSelectionControllerProvider).selectedActivities,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          BrickConfirmationDialog(selectedActivities: selectedActivities),
    );
    if (confirmed != true || !context.mounted) return;

    // Show loading indicator before try block so catch blocks can dismiss it
    final loadingSnackbarController = MealvanaSnackbar.showLoading(
      context,
      'Creating brick workout...',
    );
    var loadingDismissed = false;
    void dismissLoadingSnackbar() {
      if (loadingDismissed) return;
      loadingDismissed = true;
      loadingSnackbarController.close();
    }

    try {
      // Business logic lives in the controller (FOA) — the screen only wires
      // dialogs + feedback.
      await ref
          .read(brickActionsControllerProvider.notifier)
          .createBrickFromSelection(
            activities: selectedActivities,
            segmentOrder: selectedActivities
                .map((activity) => activity.activityType.name)
                .toList(),
          );

      if (!context.mounted) return;

      ref.read(brickSelectionControllerProvider.notifier).exitSelectionMode();
      // fuelTimelineDayProvider watches the activities controller, so this
      // refreshes the timeline (brick replaces the grouped activities).
      ref.invalidate(activitiesControllerProvider);

      dismissLoadingSnackbar();
      MealvanaSnackbar.showSuccess(
        context,
        'Brick workout created successfully!',
      );
    } on BrickValidationException catch (e) {
      dismissLoadingSnackbar();
      if (!context.mounted) return;
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => BrickValidationErrorDialog(
          exception: e,
          onRetry: () {
            // Keep selection mode active so user can adjust selection
          },
        ),
      );
    } on BrickCreationException catch (e) {
      dismissLoadingSnackbar();
      if (!context.mounted) return;
      final shouldRetry = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => BrickCreationErrorDialog(
          exception: e,
          onRetry: () {
            // Retry callback - executed after dialog closes
          },
        ),
      );
      if (shouldRetry == true && e.code == 'NETWORK_ERROR' && context.mounted) {
        await _handleConfirmSelection(context, ref);
      }
    } catch (e) {
      dismissLoadingSnackbar();
      if (context.mounted) {
        MealvanaSnackbar.showError(
          context,
          'Unexpected error creating brick: ${e.toString()}',
        );
      }
    } finally {
      dismissLoadingSnackbar();
    }
  }

  /// Handle Ungroup on a brick group card: confirmation dialog → restore the
  /// original standalone activities via [BrickActionsController].
  Future<void> _handleUngroupBrick(
    BuildContext context,
    WidgetRef ref,
    Activity brick,
  ) async {
    final segmentCount = brick.brickMetadata?.segments.length ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BrickUngroupDialog(segmentCount: segmentCount),
    );
    if (confirmed != true || !context.mounted) return;

    final loadingSnackbarController = MealvanaSnackbar.showLoading(
      context,
      'Ungrouping brick...',
    );
    var loadingDismissed = false;
    void dismissLoadingSnackbar() {
      if (loadingDismissed) return;
      loadingDismissed = true;
      loadingSnackbarController.close();
    }

    try {
      await ref
          .read(brickActionsControllerProvider.notifier)
          .ungroupBrick(brick.id);

      if (!context.mounted) return;
      ref.invalidate(activitiesControllerProvider);

      dismissLoadingSnackbar();
      MealvanaSnackbar.showSuccess(context, 'Brick ungrouped successfully!');
    } on BrickUngroupException catch (e) {
      dismissLoadingSnackbar();
      if (!context.mounted) return;
      final shouldRetry = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => BrickUngroupErrorDialog(
          exception: e,
          onRetry: () {
            // Retry callback - executed after dialog closes
          },
        ),
      );
      if (shouldRetry == true && e.code == 'NETWORK_ERROR' && context.mounted) {
        await _handleUngroupBrick(context, ref, brick);
      }
    } catch (e) {
      dismissLoadingSnackbar();
      if (context.mounted) {
        MealvanaSnackbar.showError(
          context,
          'Unexpected error ungrouping brick: ${e.toString()}',
        );
      }
    } finally {
      dismissLoadingSnackbar();
    }
  }

  /// Handle View Combined on a brick group card. With a nutrition plan → the
  /// Activity Detail screen; without one → the New Activity screen's Brick tab
  /// to complete setup (same routing as the old activities screen).
  void _handleViewCombinedBrick(BuildContext context, Activity brick) {
    if (brick.nutritionPlanData != null) {
      context.push('/plan', extra: {'mode': 'view', 'activityId': brick.id});
    } else {
      context.push(
        '/distancepacegut',
        extra: {
          'activityId': brick.id,
          'initialDate': brick.scheduledDateTime,
          'initialTitle': brick.title,
          'activityType': 'brick',
          // Brick metadata will be loaded from the activity by the screen
        },
      );
    }
  }

  /// Handle Remove Segment on a brick segment card. Removing down to 1 sport
  /// isn't a brick anymore, so at 2 segments this offers to ungroup instead.
  Future<void> _handleRemoveSegment(
    BuildContext context,
    WidgetRef ref,
    Activity brick,
    int segmentIndex,
  ) async {
    final segmentCount = brick.brickMetadata?.segments.length ?? 0;

    // If removing this segment would leave only 1 sport, offer ungroup instead
    if (segmentCount <= 2) {
      final shouldUngroup = await showDialog<bool>(
        context: context,
        builder: (context) => const BrickMinimumWarningDialog(),
      );
      if (shouldUngroup == true && context.mounted) {
        await _handleUngroupBrick(context, ref, brick);
      }
      return;
    }

    // If 3+ segments, remove segment is not yet implemented (parity with the
    // old activities screen — BrickActionsController.removeSegmentFromBrick
    // is still Phase 3.4).
    MealvanaSnackbar.showInfo(
      context,
      'Remove segment feature not yet implemented',
    );
  }

  /// Handle Delete on a brick group card: confirm (the nutrition plan goes
  /// with it), then delete via the activities controller.
  Future<void> _handleDeleteBrick(
    BuildContext context,
    WidgetRef ref,
    Activity brick,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Brick Workout?'),
        content: const Text(
          'Delete this brick workout? This will also delete the nutrition plan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final loadingSnackbarController = MealvanaSnackbar.showLoading(
      context,
      'Deleting brick...',
    );
    var loadingDismissed = false;
    void dismissLoadingSnackbar() {
      if (loadingDismissed) return;
      loadingDismissed = true;
      loadingSnackbarController.close();
    }

    try {
      await ref
          .read(activitiesControllerProvider.notifier)
          .deleteActivity(brick.id);

      if (!context.mounted) return;
      ref.invalidate(activitiesControllerProvider);

      dismissLoadingSnackbar();
      MealvanaSnackbar.showSuccess(context, 'Brick deleted successfully');
    } catch (e) {
      dismissLoadingSnackbar();
      if (context.mounted) {
        MealvanaSnackbar.showError(
          context,
          'Error deleting brick: ${e.toString()}',
        );
      }
    } finally {
      dismissLoadingSnackbar();
    }
  }

  Widget _addButtons(
    BuildContext context,
    WidgetRef ref,
    FuelTimelineFilter filter,
    DateTime selectedDate,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? AppColors.cream : AppColors.blackberry;
    return Row(
      children: [
        if (filter.showsAddFood)
          Expanded(
            child: _dashedButton(
              key: const ValueKey('fuel_timeline.add_food'),
              label: '+ Add Food',
              color: onSurface.withValues(alpha: 0.8),
              onTap: () => openLogMealScreen(
                context,
                logDate: _ymd(selectedDate),
                source: 'fuel_timeline',
              ),
            ),
          ),
        if (filter.showsAddFood && filter.showsAddActivity)
          const SizedBox(width: 8),
        if (filter.showsAddActivity)
          Expanded(
            child: _dashedButton(
              key: const ValueKey('fuel_timeline.add_activity'),
              label: '+ Add Activity',
              color: AppColors.orange,
              onTap: () {
                ref
                    .read(analyticsTrackerProvider)
                    .trackActivityButtonPressed(selectedDate: selectedDate);
                context.pushNamedOnce(
                  'distancepacegut',
                  extra: {'initialDate': selectedDate},
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _dashedButton({
    Key? key,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Text(label, style: FtType.addButton.copyWith(color: color)),
      ),
    );
  }

  Widget _emptyTimeline(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? AppColors.cream : AppColors.blackberry;
    return Center(
      child: Text(
        content.getValue(
          'fuel_timeline.empty_day',
          defaultValue: 'Nothing logged yet for this day.',
        ),
        style: FtType.body.copyWith(color: onSurface.withValues(alpha: 0.5)),
      ),
    );
  }

  Widget _error(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            content.getValue(
              'fuel_timeline.load_error',
              defaultValue: 'Could not load your day.',
            ),
            style: AppTextStyles.subtitle.copyWith(
              color: AppColors.dragonfruit,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          KyleSecondaryButton(
            text: content.getValue('common.retry', defaultValue: 'Retry'),
            onPressed: () => ref.invalidate(fuelTimelineDayProvider),
          ),
        ],
      ),
    );
  }

  String _ymd(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}
