import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/core/guarded_navigation.dart';
import '../../../../shared/services/analytics/analytics_events.dart';
import '../../../../shared/services/analytics/analytics_tracker.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../activities/domain/activity.dart';
import '../../../activities/domain/brick_eligibility.dart';
import '../../../activities/domain/brick_exceptions.dart';
import '../../../activities/presentation/navigation/open_activity_fuel.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../../../activities/presentation/providers/brick_actions_controller.dart';
import '../../../activities/presentation/providers/brick_creation_available_provider.dart';
import '../../../activities/presentation/providers/brick_selection_controller.dart';
import '../../../activities/presentation/widgets/brick_ungroup_dialog.dart';
import '../../../activities/presentation/widgets/brick_validation_error_dialog.dart';
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
import '../widgets/timeline_brick_tile.dart';
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
              // Add row: Food · Activity · | · Brick. The Brick pill replaces
              // the old standalone "Create Brick" button that sat above the
              // adds and read like a third add action (Notion 3a7e3fdb).
              _addRow(context, ref, view, workoutNodes, selectedDate),
              for (final n in nodes)
                _tile(context, ref, n, view, workoutNodes),
              if (nodes.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: _emptyTimeline(context, ref),
                ),
            ],
          ),
        ),
        // Leg-picking action bar (step 2): Cancel · Swap · Create Brick (n).
        // Docked below the list so it stays reachable while scrolling the day.
        if (ref.watch(brickSelectionControllerProvider).isSelectionMode)
          _brickActionBar(context, ref),
      ],
    );
  }

  /// The Add Food / Add Activity row, with the timeline rail running up to it
  /// (a hollow "now" marker), matching the mockup.
  Widget _addRow(
    BuildContext context,
    WidgetRef ref,
    FuelTimelineViewState view,
    List<WorkoutNode> workoutNodes,
    DateTime selectedDate,
  ) {
    // While picking legs the add row is replaced in place by the pick bar —
    // the adds are not available mid-flow, and reusing the slot keeps the rail
    // geometry identical so the timeline doesn't jump.
    final picking = ref.watch(brickSelectionControllerProvider).isSelectionMode;
    final addButtons = picking
        ? _pickLegsBar(context, ref)
        : _addButtons(context, ref, view.filter, workoutNodes, selectedDate);
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
    List<WorkoutNode> workoutNodes,
  ) {
    final selectionState = ref.watch(brickSelectionControllerProvider);
    final picking = selectionState.isSelectionMode;

    switch (node) {
      case MealNode(:final meal):
        return TimelineNodeTile(
          node: node,
          timelineOpen: view.timelineOpen,
          trackingOn: view.trackingOn,
          selectionMode: picking,
          // Tap the meal → edit-meal page (where components can be edited and
          // swapped). Swipe either direction removes with Undo.
          onTap: () => context.push('/meal-log/edit', extra: {'log': meal}),
          onRemove: () => _deleteMealWithUndo(context, ref, meal),
        );
      case WorkoutNode(:final activity):
        // A created brick sits *inside* the timeline as an indented bracket —
        // it takes one time-dot like any other row, so the rail is never cut
        // (Notion 3a7e3fdb, problem A).
        if (activity.isBrick) {
          return TimelineBrickTile(
            brick: activity,
            timelineOpen: view.timelineOpen,
            onOpenBrick: () => _handleViewCombinedBrick(context, activity),
            onOpenLeg: (index) =>
                _handleOpenBrickLeg(context, ref, activity, index),
            onUngroup: () => _handleUngroupBrick(context, ref, activity),
            onDelete: () => _handleDeleteBrick(context, ref, activity),
          );
        }
        // Leg-picking: rows stay on the rail and simply become pickable, so
        // the timeline never reflows mid-flow. Chosen rows get the orange
        // spine — "a live preview of the brick".
        if (picking) {
          final notifier = ref.read(
            brickSelectionControllerProvider.notifier,
          );
          final candidates = adjacentBrickCandidateIds(
            workoutNodes
                .map<Activity?>((n) => n.activity)
                .toList(growable: false),
          );
          return TimelineNodeTile(
            node: node,
            timelineOpen: view.timelineOpen,
            trackingOn: view.trackingOn,
            selectionMode: true,
            selectable: candidates.contains(activity.id),
            selected: notifier.isActivitySelected(activity.id),
            legOrder: notifier.getSelectionOrder(activity.id),
            onSelectToggle: () => notifier.toggleActivity(activity),
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
          selectionMode: picking,
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
          selectionMode: picking,
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

  /// Bottom clearance for anything docked below the timeline list.
  ///
  /// The tab bar is a *floating* pill (`Positioned(bottom: 16, height: 43)` in
  /// [FloatingActionButtonsBar]) drawn in a Stack over this screen, so it does
  /// not consume layout height — a docked panel that only respects the safe
  /// area slides straight under it. 16 + 43 + a 12pt breathing gap.
  static const double _dockedBottomInset = 71;

  /// The docked LEG ORDER panel (step 2 → step 3).
  ///
  /// Shows the chosen legs as ordered chips with a Swap affordance, over a
  /// full-width `Create Brick (n)` that commits directly — no confirm modal
  /// (Notion 3a7e3fdb, step 3).
  ///
  /// Below two legs there is no order to set yet, so the slot holds the
  /// instruction instead — the panel only earns its space once swapping and
  /// creating are both real choices.
  Widget _brickActionBar(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(brickSelectionControllerProvider);
    final notifier = ref.read(brickSelectionControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? AppColors.cream : AppColors.blackberry;
    final legs = selection.selectedActivities;
    if (legs.length < 2) return _brickPickHint(context, onSurface);

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        _dockedBottomInset,
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'LEG ORDER',
                    style: FtType.eyebrow.copyWith(
                      color: onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                GestureDetector(
                  key: const ValueKey('fuel_timeline.brick_swap'),
                  // "Swap reverses leg order" — only meaningful with 2+ legs.
                  onTap: legs.length >= 2 ? notifier.swapOrder : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swap_horiz,
                        size: 15,
                        color: legs.length >= 2
                            ? AppColors.electrolyte
                            : onSurface.withValues(alpha: 0.3),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Swap',
                        style: FtType.pill.copyWith(
                          color: legs.length >= 2
                              ? AppColors.electrolyte
                              : onSurface.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < legs.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 13,
                        color: onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  Expanded(child: _legChip(legs[i], i + 1, onSurface)),
                ],
              ],
            ),
            const SizedBox(height: 12),
            KyleSecondaryButtonSmall(
              key: const ValueKey('fuel_timeline.brick_create'),
              text: 'Create Brick (${legs.length})',
              onPressed: notifier.canCreateBrick()
                  ? () => _handleConfirmSelection(context, ref)
                  : null,
              variant: SecondaryButtonVariant.orange,
            ),
        ],
      ),
    );
  }

  /// The step-2 instruction, occupying the LEG ORDER panel's slot until two
  /// legs are picked: "Tap two or more activities to link into a brick."
  Widget _brickPickHint(BuildContext context, Color onSurface) {
    return Container(
      // The parent Column is centre-aligned, so without this the box hugs its
      // text instead of matching the LEG ORDER panel it stands in for.
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        _dockedBottomInset,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: onSurface.withValues(alpha: 0.12)),
      ),
      child: Text(
        'Tap two or more activities to link into a brick',
        textAlign: TextAlign.center,
        style: FtType.addButton.copyWith(
          color: onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  /// One ordered leg chip: `① RUN`.
  Widget _legChip(Activity activity, int order, Color onSurface) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: onSurface.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.orange,
            ),
            child: Text(
              '$order',
              style: FtType.macroLine.copyWith(
                fontSize: 10,
                height: 1.0,
                color: AppColors.blackberry,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              activity.activityType.displayName.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FtType.itemName.copyWith(color: onSurface),
            ),
          ),
        ],
      ),
    );
  }

  /// Create the brick from the picked legs.
  ///
  /// Step 3 "commits directly — no modal", so there is no confirmation dialog
  /// here any more; validation/creation *errors* still surface as dialogs.
  Future<void> _handleConfirmSelection(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Selection order is preserved by the controller: [0] = first segment.
    final selectedActivities = List<Activity>.from(
      ref.read(brickSelectionControllerProvider).selectedActivities,
    );

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
      // "✓ Brick created · Run → Swim   Undo" — creation commits directly with
      // no confirm modal, so the toast carries the safety net instead. Undo
      // ungroups, which is exactly the pre-create state.
      final legs = selectedActivities
          .map((a) => a.activityType.displayName)
          .join(' → ');
      final createdBrickId = ref
          .read(activitiesControllerProvider)
          .value
          ?.firstWhere(
            (a) =>
                a.isBrick &&
                (a.brickMetadata?.originalActivityIds ?? const []).contains(
                  selectedActivities.first.id,
                ),
            orElse: () => selectedActivities.first,
          )
          .id;
      MealvanaSnackbar.showSuccess(
        context,
        'Brick created · $legs',
        duration: const Duration(seconds: 5),
        actionLabel: 'Undo',
        onAction: () async {
          if (createdBrickId == null) return;
          try {
            await ref
                .read(brickActionsControllerProvider.notifier)
                .ungroupBrick(createdBrickId);
            ref.invalidate(activitiesControllerProvider);
          } catch (_) {
            if (context.mounted) {
              MealvanaSnackbar.showError(context, 'Could not undo the brick');
            }
          }
        },
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

  /// Tap a leg inside the brick's bracket → that leg's fuel detail.
  ///
  /// A brick's fuel plan is one plan with a section per segment, so this opens
  /// the combined plan where the leg's detail lives. Scrolling straight to the
  /// tapped segment needs a focus parameter on the plan screen — a follow-up,
  /// not something to fake with an argument the screen ignores.
  void _handleOpenBrickLeg(
    BuildContext context,
    WidgetRef ref,
    Activity brick,
    int legIndex,
  ) {
    _handleViewCombinedBrick(context, brick);
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

  /// Step 2's header, occupying the add row's slot: `⛓ Pick legs to link`
  /// with Cancel on the right.
  Widget _pickLegsBar(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? AppColors.cream : AppColors.blackberry;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          const Icon(Icons.link, size: 14, color: AppColors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pick legs to link',
              style: FtType.addButton.copyWith(color: onSurface),
            ),
          ),
          GestureDetector(
            key: const ValueKey('fuel_timeline.brick_cancel'),
            onTap: ref
                .read(brickSelectionControllerProvider.notifier)
                .exitSelectionMode,
            child: Text(
              'Cancel',
              style: FtType.addButton.copyWith(
                color: onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The add row: `+ Food` · `+ Activity` · │ · `⛓ Brick`.
  ///
  /// Brick redesign (Notion 3a7e3fdb, step 1): "A third pill in the add row —
  /// shorter labels make room, a divider and the chain icon keep it from
  /// reading as another 'add'." The labels lost the word "Add" deliberately:
  /// it buys the room, and together with the divider + chain icon it is what
  /// stops Brick reading as a third add action.
  Widget _addButtons(
    BuildContext context,
    WidgetRef ref,
    FuelTimelineFilter filter,
    List<WorkoutNode> workoutNodes,
    DateTime selectedDate,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? AppColors.cream : AppColors.blackberry;

    // The Brick pill only appears when 2+ groupable workouts are adjacent, and
    // never while leg-picking is already running.
    final selection = ref.watch(brickSelectionControllerProvider);
    final showBrick =
        filter.showsAddActivity &&
        !selection.isSelectionMode &&
        ref.watch(
          isBrickCreationAvailableProvider(
            activities: workoutNodes
                .map((n) => n.activity)
                .toList(growable: false),
            selectedDate: selectedDate,
          ),
        );

    return Row(
      children: [
        if (filter.showsAddFood)
          Expanded(
            child: _pillButton(
              key: const ValueKey('fuel_timeline.add_food'),
              label: '+ Food',
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
            child: _pillButton(
              key: const ValueKey('fuel_timeline.add_activity'),
              label: '+ Activity',
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
        if (showBrick) ...[
          // The divider is load-bearing: it separates "make something new"
          // from "operate on what's already here".
          const SizedBox(width: 8),
          Container(
            width: 1,
            height: 20,
            color: onSurface.withValues(alpha: 0.25),
          ),
          const SizedBox(width: 8),
          _pillButton(
            key: const ValueKey('fuel_timeline.create_brick'),
            label: 'Brick',
            color: onSurface.withValues(alpha: 0.8),
            icon: Icons.link,
            onTap: () => ref
                .read(brickSelectionControllerProvider.notifier)
                .enterSelectionMode(),
          ),
        ],
      ],
    );
  }

  Widget _pillButton({
    Key? key,
    required String label,
    required Color color,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: 10,
          horizontal: icon == null ? 6 : 11,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        // The add row sits to the RIGHT of the timeline rail, so three pills
        // share only ~270pt on a 390pt screen. Labels must be allowed to
        // ellipsize rather than force an overflow — at large text scales even
        // "+ Activity" outgrows its share.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: FtType.addButton.copyWith(color: color),
              ),
            ),
          ],
        ),
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
