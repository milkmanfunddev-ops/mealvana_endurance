import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../../../fuel_timeline/presentation/widgets/fuel_timeline_day_header.dart';
import '../../application/dashboard_assembler.dart';
import '../../domain/dashboard_models.dart';
import '../me_tokens.dart';
import '../providers/macro_dashboard_providers.dart';
import '../widgets/dashboard_filter_row.dart';
import '../widgets/energy_summary_card.dart';
import '../widgets/meal_card.dart';
import '../widgets/workout_card.dart';

/// The macro dashboard — surface contract:
/// docs/ssot/spec/design/surfaces/macro-dashboard.md (RATIFIED v1).
/// Reference rendering: prototypes/macro-dashboard/index.html @ aa81d21.
///
/// Ships behind AppConfig.macroDashboardEnabled (fail-closed) as the
/// flag-gated successor to FuelTimelineScreen; the fuel-detail sheets and the
/// tapped-into workout detail are deliberately untouched (scope ruling).
class MacroDashboardScreen extends ConsumerWidget {
  const MacroDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(macroDashboardViewProvider);
    final dayAsync = ref.watch(macroDashboardDayProvider);

    return Container(
      color: MeTokens.blackberry,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const FuelTimelineDayHeader(),
            Expanded(
              child: dayAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: MeTokens.electrolyte,
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Could not load your day',
                    style: TextStyle(
                      fontFamily: 'Apercu',
                      color: MeTokens.creamAlpha(0.7),
                    ),
                  ),
                ),
                data: (data) => _body(context, ref, view, data),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    MacroDashboardViewState view,
    DashboardData data,
  ) {
    final notifier = ref.read(macroDashboardViewProvider.notifier);
    final nodes = data.nodes
        .where(
          (n) => switch (view.filter) {
            DashboardFilter.all => true,
            DashboardFilter.workout => n.isWorkout,
            DashboardFilter.meals => !n.isWorkout,
          },
        )
        .toList(growable: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: Column(
            children: [
              // §5: tracking-off hides every derived quantity; the card is
              // one of them. (The EA gate itself still ran server-side.)
              if (view.trackingOn && data.energy != null)
                EnergySummaryCard(
                  face: view.filter,
                  expanded: view.dashOpen,
                  data: data.energy!,
                  onToggleExpanded: notifier.toggleDash,
                ),
              const SizedBox(height: 16),
              DashboardFilterRow(
                filter: view.filter,
                trackingOn: view.trackingOn,
                timelineOpen: view.timelineOpen,
                onFilter: notifier.setFilter,
                onToggleTracking: notifier.toggleTracking,
                onToggleTimeline: notifier.toggleTimeline,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 90),
            children: [
              for (final node in nodes)
                _railRow(
                  context,
                  ref,
                  view,
                  node,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _railRow(
    BuildContext context,
    WidgetRef ref,
    MacroDashboardViewState view,
    DashboardNode node,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (view.timelineOpen) ...[
          SizedBox(
            width: 54,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                node.timeLabel,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'Apercu',
                  fontSize: 10.5,
                  color: MeTokens.creamAlpha(0.5),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 16,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: _railDot(node),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: node.isWorkout
                ? _workout(context, ref, node.workout!)
                : _meals(ref, view, node),
          ),
        ),
      ],
    );
  }

  Widget _railDot(DashboardNode node) {
    // Workouts are always teal on the rail — orange belongs to meals.
    final color = node.isWorkout ? MeTokens.electrolyte : MeTokens.orange;
    if (node.railDashed) {
      return Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: node.isWorkout
                ? MeTokens.electrolyteAlpha(0.65)
                : MeTokens.orange,
            width: 2,
          ),
        ),
      );
    }
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: MeTokens.blackberry, width: 2),
      ),
    );
  }

  Widget _workout(BuildContext context, WidgetRef ref, WorkoutCardData data) {
    final activities = ref.read(activitiesControllerProvider.notifier);
    return WorkoutCard(
      data: data,
      onMarkDone: () => activities.markWorkoutDone(data.activityId),
      onMarkUndone: () => activities.markWorkoutUndone(data.activityId),
      onDelete: () => _deleteWithUndo(context, ref, data),
    );
  }

  /// G5 + S-2: the delete press removes the workout's contributions from
  /// every surface figure in the same frame (the optimistic controller
  /// update recomputes the whole day); upstream the write is a soft delete
  /// (status='deleted', row persists).
  void _deleteWithUndo(
    BuildContext context,
    WidgetRef ref,
    WorkoutCardData data,
  ) async {
    final notifier = ref.read(activitiesControllerProvider.notifier);
    final previous = await notifier.getActivityById(data.activityId);
    if (!context.mounted) return;
    notifier.deleteActivity(data.activityId);
    MealvanaSnackbar.showInfo(
      context,
      '${data.name} deleted',
      duration: const Duration(seconds: 5),
      actionLabel: 'Undo',
      onAction: () async {
        if (previous == null) return;
        try {
          await ref
              .read(activitiesControllerProvider.notifier)
              .restoreActivity(previous);
        } catch (_) {
          if (context.mounted) {
            MealvanaSnackbar.showError(context, 'Could not restore workout');
          }
        }
      },
    );
  }

  Widget _meals(WidgetRef ref, MacroDashboardViewState view, DashboardNode node) {
    final notifier = ref.read(macroDashboardViewProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in node.meals)
          MealCard(
            item: item,
            expanded: view.expandedMealId == item.id,
            showMacros: view.trackingOn,
            onToggle: () => notifier.toggleMealExpanded(item.id),
          ),
      ],
    );
  }
}
