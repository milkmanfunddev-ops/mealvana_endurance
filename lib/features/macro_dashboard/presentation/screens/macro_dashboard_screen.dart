import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/core/guarded_navigation.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../../../calendar/presentation/providers/calendar_selected_date_provider.dart';
import '../../../fuel_timeline/presentation/widgets/fuel_timeline_day_header.dart';
import '../../../meal_logging/presentation/screens/log_meal_screen.dart';
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
                // A recompute (activities swipe, macro refresh) must repaint
                // in place, never strobe through a spinner — the previous
                // frame stays up until the new data lands (S-1's "same
                // pump", and flicker-proofing against invalidation cascades).
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: true,
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
              _addRow(context, ref, view),
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

  /// The Add Food / Add Activity row, with the rail running up to a hollow
  /// "now" marker (reference rendering's top-of-timeline treatment).
  Widget _addRow(
    BuildContext context,
    WidgetRef ref,
    MacroDashboardViewState view,
  ) {
    final selectedDate = ref.watch(calendarSelectedDateProvider);
    final buttons = Row(
      children: [
        if (view.filter != DashboardFilter.workout)
          Expanded(
            child: _dashedPill(
              label: '+ Add Food',
              color: MeTokens.creamAlpha(0.8),
              borderColor: MeTokens.creamAlpha(0.25),
              onTap: () => openLogMealScreen(
                context,
                logDate: _ymd(selectedDate),
                source: 'macro_dashboard',
              ),
            ),
          ),
        if (view.filter == DashboardFilter.all) const SizedBox(width: 8),
        if (view.filter != DashboardFilter.meals)
          Expanded(
            child: _dashedPill(
              label: '+ Add Activity',
              color: MeTokens.orange,
              borderColor: MeTokens.orangeAlpha(0.45),
              onTap: () => context.pushNamedOnce(
                'distancepacegut',
                extra: {'initialDate': selectedDate},
              ),
            ),
          ),
      ],
    );
    if (!view.timelineOpen) {
      return Padding(padding: const EdgeInsets.only(bottom: 16), child: buttons);
    }
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
                    color: MeTokens.creamAlpha(0.12),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 11),
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MeTokens.blackberry,
                      border: Border.all(
                        color: MeTokens.creamAlpha(0.35),
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
              child: buttons,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashedPill({
    required String label,
    required Color color,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        foregroundPainter: _DashedPillPainter(color: borderColor),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Apercu',
              fontWeight: FontWeight.w500,
              fontSize: 12.5,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  String _ymd(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  Widget _railRow(
    BuildContext context,
    WidgetRef ref,
    MacroDashboardViewState view,
    DashboardNode node,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  // One continuous rail: the line stretches the full row so
                  // it meets the neighbouring rows' segments.
                  Positioned(
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: MeTokens.creamAlpha(0.12),
                    ),
                  ),
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
      ),
    );
  }

  Widget _railDot(DashboardNode node) {
    // Workouts are always teal on the rail; meals are orange. (The reference
    // rendering tints some meal dots electrolyte — that predates the tokens
    // ruling that electrolyte may only signify the burn/verified domain, so
    // the token contract wins here.)
    final color = node.isWorkout ? MeTokens.electrolyte : MeTokens.orange;
    if (node.railDashed) {
      // Planned entries get a hollow DOTTED ring (the "not yet" edge).
      return CustomPaint(
        size: const Size(11, 11),
        painter: _DottedRingPainter(
          color: node.isWorkout
              ? MeTokens.electrolyteAlpha(0.65)
              : MeTokens.orange,
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

/// Hollow dotted ring — the planned entry's rail marker.
class _DottedRingPainter extends CustomPainter {
  const _DottedRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..addOval(Rect.fromLTWH(1, 1, size.width - 2, size.height - 2));
    const dash = 1.5;
    const gap = 3.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DottedRingPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Dashed rounded-pill outline (the Add buttons' border).
class _DashedPillPainter extends CustomPainter {
  const _DashedPillPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(size.height / 2),
        ),
      );
    const dash = 4.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPillPainter oldDelegate) =>
      oldDelegate.color != color;
}
