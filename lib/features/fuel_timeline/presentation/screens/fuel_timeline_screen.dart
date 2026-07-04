import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../activities/domain/activity.dart';
import '../../../activities/presentation/navigation/open_activity_fuel.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../../../calendar/presentation/providers/calendar_selected_date_provider.dart';
import '../../../calendar/presentation/providers/calendar_view_provider.dart';
import '../../../calendar/presentation/widgets/calendar_view_toggle.dart'
    show CalendarViewMode;
import '../../../calendar/presentation/widgets/calendar_month_view_kyle.dart';
import '../../../content/application/content_service.dart';
import '../../../integrations/presentation/widgets/garmin_connect_banner.dart';
import '../../../meal_logging/domain/meal_log.dart';
import '../../../meal_logging/presentation/providers/meal_log_providers.dart';
import '../../../meal_logging/presentation/widgets/tabbed_log_sheet.dart';
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
          if (calendarMode == CalendarViewMode.month) ...[
            const SizedBox(height: 8),
            CalendarMonthViewKyle(
              selectedDate: selectedDate,
              onDateSelected: (date) =>
                  ref.read(calendarSelectedDateProvider.notifier).setDate(date),
              dayIndicators: const {},
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
              child: Align(
                alignment: Alignment.topCenter,
                child: addButtons,
              ),
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
          // swapped). Swipe right→left also opens it to swap; swipe left→right
          // removes with Undo.
          onTap: () => context.push('/meal-log/edit', extra: {'log': meal}),
          onSwap: () => context.push('/meal-log/edit', extra: {'log': meal}),
          onRemove: () => _deleteMealWithUndo(context, ref, meal),
        );
      case WorkoutNode(:final activity):
        // Import-only activities (Garmin/TP/FS imports we don't natively
        // support) can be deleted but never edited — no Swap affordance for
        // those (see ActivityType.isImportOnly).
        final canEdit = activity.activityType.isCreatable;
        return TimelineNodeTile(
          node: node,
          timelineOpen: view.timelineOpen,
          trackingOn: view.trackingOn,
          // Tap the workout → Activity Detail page (its fuel plan).
          onTap: () => openActivityFuel(context, activity),
          // Swipe right→left → the activity editor, prefilled. Swipe
          // left→right removes with Undo (mirrors the meal row above).
          onSwap: canEdit
              ? () => _openActivityEditor(context, activity)
              : null,
          onRemove: () => _deleteActivityWithUndo(context, ref, activity),
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
  /// [_deleteMealWithUndo]. There's no dedicated "restore" call for
  /// activities (unlike meal logs), so Undo re-submits the pre-delete
  /// [Activity] via `updateActivity` — the repository writes the object as
  /// given, including its (null) `deletedAt`, which clears the soft-delete.
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
      onAction: () => notifier.updateActivity(activity),
    );
  }

  /// Opens the New Activity screen prefilled with [activity]'s data, matching
  /// the existing "edit" entry point used by the Activities list
  /// (see `activity_card.dart`'s no-nutrition-plan tap handling).
  void _openActivityEditor(BuildContext context, Activity activity) {
    context.push(
      '/distancepacegut',
      extra: {
        'activityId': activity.id,
        'initialDate': activity.scheduledDateTime,
        'distance': activity.distanceMiles,
        'initialDurationMinutes': activity.durationMinutes,
        'goalPace': activity.paceTargetMinutesPerMile,
        'initialTitle': activity.title,
        'activityType': activity.activityType.name,
        // Cycling-specific parameters
        'cyclingSpeedMph': activity.cyclingSpeedMph,
        'cyclingTerrain': activity.cyclingTerrain,
        'cyclingIndoorOutdoor': activity.cyclingIndoorOutdoor,
        'cyclingElevationGainFt': activity.cyclingElevationGainFt,
        'cyclingSessionGoal': activity.cyclingSessionGoal,
        // Swimming-specific parameters
        'swimmingPacePer100mSeconds': activity.swimmingPacePer100mSeconds,
        'swimmingPoolOrOpenWater': activity.swimmingPoolOrOpenWater,
        'swimmingWaterTempC': activity.swimmingWaterTempC,
        // Shared parameters
        'intensityTarget': activity.intensityTarget,
        'timeBeforeMinutes': activity.timeBeforeMinutes,
      },
    );
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
              onTap: () =>
                  showTabbedLogSheet(context, logDate: _ymd(selectedDate)),
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
              onTap: () => context.pushNamed(
                'distancepacegut',
                extra: {'initialDate': selectedDate},
              ),
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
