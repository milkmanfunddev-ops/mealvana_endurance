import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/core/guarded_navigation.dart';
import '../../../../shared/widgets/kyle_design/buttons/secondary_button.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
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
import '../../../fuel_timeline/presentation/widgets/fuel_timeline_day_header.dart';
import '../../../fuel_timeline/presentation/widgets/timeline_brick_tile.dart';
import '../../../meal_logging/presentation/screens/log_meal_screen.dart';
import '../../application/dashboard_assembler.dart';
import '../../domain/dashboard_models.dart';
import '../me_tokens.dart';
import '../providers/macro_dashboard_providers.dart';
import '../widgets/breakdown_pager.dart';
import '../widgets/dashboard_filter_row.dart';
import '../widgets/energy_summary_card.dart';
import '../widgets/meal_card.dart';
import '../widgets/workout_card.dart';

/// The macro dashboard — surface contract:
/// docs/ssot/spec/design/surfaces/macro-dashboard.md (RATIFIED v2 — pins
/// workout-card v2: skip replaces delete, S-2 skip scope, S-7 tuck).
/// Reference rendering: prototypes/macro-dashboard/index.html @ 5a22ca8.
///
/// Ships behind AppConfig.macroDashboardEnabled (fail-closed) as the
/// flag-gated successor to FuelTimelineScreen; the fuel-detail sheets and the
/// tapped-into workout detail are deliberately untouched (scope ruling).
///
/// BRICK — CANDIDATE, NOT RATIFIED (Lee, 2026-08-26). The brick flow was lost
/// twice in a row (Activities → Fuel Timeline, bug 3a6e3fdb; Fuel Timeline →
/// this surface, adeb1e38): the surface spec never mentioned it, so the port
/// faithfully omitted it. It is resurrected here as a straight carry-over of
/// the Fuel Timeline design (Notion 3a7e3fdb) so a design session has the
/// real thing to ratify from:
///   · a third `⛓ Brick` pill in the add row, after a divider, offered only
///     while `hasBrickCandidates` holds (brick_eligibility.dart: 2+ swim /
///     bike / run on the day, 2+ sports — adjacency NOT required, legs in
///     pick order; ruled Lee 2026-08-26, logic-SSOT record pending);
///   · tapping it swaps the add row for "Pick legs to link · Cancel" and the
///     day's workout cards become pickable in place (rail geometry unchanged);
///   · a docked LEG ORDER panel (Swap · Create Brick (n)) commits directly;
///   · a created brick renders as [TimelineBrickTile] — one time-dot, legs in
///     an indented bracket — reused verbatim from the fuel timeline.
/// Nothing brick-shaped lives in kyle_design/ yet, by design: promotion into
/// the library follows ratification (source-authority.md §3), not this port.
/// Test: test/features/macro_dashboard/macro_dashboard_brick_test.dart.
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
                  child: CircularProgressIndicator(color: MeTokens.electrolyte),
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
    final selectedDate = ref.watch(calendarSelectedDateProvider);
    final dayWorkouts = _dayWorkouts(ref, selectedDate);
    final picking = ref.watch(brickSelectionControllerProvider).isSelectionMode;

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
                  key: const ValueKey('macro_dashboard.energy_card'),
                  face: view.filter,
                  expanded: view.dashOpen,
                  data: data.energy!,
                  onToggleExpanded: notifier.toggleDash,
                  // E2: opens the face's sheet — the Breakdown Pager at the
                  // face's page (reference mapping: All → Today's Energy,
                  // Workout → Active Energy, Meals → Today's Fuel).
                  onFullBreakdown: () => showBreakdownPager(
                    context,
                    initialIndex: switch (view.filter) {
                      DashboardFilter.all => 0,
                      DashboardFilter.workout => 1,
                      DashboardFilter.meals => 2,
                    },
                  ),
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
              _addRow(context, ref, view, dayWorkouts, picking),
              for (final node in nodes)
                _railRow(context, ref, view, node, dayWorkouts, picking),
            ],
          ),
        ),
        // Leg-picking action bar (step 2): Cancel · Swap · Create Brick (n).
        // Docked below the list so it stays reachable while scrolling the day.
        if (picking) _brickActionBar(context, ref),
      ],
    );
  }

  /// The selected day's live workouts in timeline order — the sequence brick
  /// adjacency is judged over. Reads the activities controller directly (the
  /// assembled nodes carry render data, not activities).
  List<Activity> _dayWorkouts(WidgetRef ref, DateTime selectedDate) {
    final all = ref.watch(activitiesControllerProvider).value ?? const [];
    bool onDay(DateTime d) =>
        d.year == selectedDate.year &&
        d.month == selectedDate.month &&
        d.day == selectedDate.day;
    return all
        .where(
          (a) =>
              a.status != ActivityStatus.deleted &&
              a.deletedAt == null &&
              onDay(a.displayTime),
        )
        .toList(growable: false)
      ..sort((a, b) => a.displayTime.compareTo(b.displayTime));
  }

  /// The Add Food / Add Activity row, with the rail running up to a hollow
  /// "now" marker (reference rendering's top-of-timeline treatment).
  Widget _addRow(
    BuildContext context,
    WidgetRef ref,
    MacroDashboardViewState view,
    List<Activity> dayWorkouts,
    bool picking,
  ) {
    final selectedDate = ref.watch(calendarSelectedDateProvider);
    // The Brick pill only appears when 2+ groupable workouts are adjacent,
    // and never while leg-picking is already running.
    final showBrick =
        view.filter != DashboardFilter.meals &&
        !picking &&
        ref.watch(
          isBrickCreationAvailableProvider(
            activities: dayWorkouts,
            selectedDate: selectedDate,
          ),
        );
    // While picking legs the add row is replaced in place by the pick bar —
    // the adds are not available mid-flow, and reusing the slot keeps the
    // rail geometry identical so the timeline doesn't jump.
    final buttons = picking
        ? _pickLegsBar(ref)
        : Row(
            children: [
              if (view.filter != DashboardFilter.workout)
                Expanded(
                  child: _dashedPill(
                    key: const ValueKey('macro_dashboard.add_food'),
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
                    key: const ValueKey('macro_dashboard.add_activity'),
                    label: '+ Add Activity',
                    color: MeTokens.orange,
                    borderColor: MeTokens.orangeAlpha(0.45),
                    onTap: () => context.pushNamedOnce(
                      'distancepacegut',
                      extra: {'initialDate': selectedDate},
                    ),
                  ),
                ),
              if (showBrick) ...[
                // The divider is load-bearing: it separates "make something new"
                // from "operate on what's already here".
                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 20,
                  color: MeTokens.creamAlpha(0.25),
                ),
                const SizedBox(width: 8),
                _dashedPill(
                  key: const ValueKey('macro_dashboard.create_brick'),
                  label: 'Brick',
                  icon: Icons.link,
                  color: MeTokens.creamAlpha(0.8),
                  borderColor: MeTokens.creamAlpha(0.25),
                  onTap: () => ref
                      .read(brickSelectionControllerProvider.notifier)
                      .enterSelectionMode(),
                ),
              ],
            ],
          );
    if (!view.timelineOpen) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: buttons,
      );
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
                  child: Container(width: 2, color: MeTokens.creamAlpha(0.12)),
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
    Key? key,
    required String label,
    required Color color,
    required Color borderColor,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    // Semantics(button:) — without it the pill reads to assistive tech as
    // static text (AXStaticText on iOS) even though it is tappable.
    return Semantics(
      button: true,
      container: true,
      child: GestureDetector(
        key: key,
        onTap: onTap,
        child: CustomPaint(
          foregroundPainter: _DashedPillPainter(color: borderColor),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: 9,
              horizontal: icon == null ? 0 : 14,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Apercu',
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                    color: color,
                  ),
                ),
              ],
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
    List<Activity> dayWorkouts,
    bool picking,
  ) {
    // A created brick sits *inside* the timeline as an indented bracket — it
    // takes one time-dot like any other row, so the rail is never cut
    // (Notion 3a7e3fdb, problem A). The tile draws its own rail column.
    if (node.isBrick) {
      final brick = node.brick!;
      return TimelineBrickTile(
        key: ValueKey('macro_dashboard.brick_${brick.id}'),
        brick: brick,
        timelineOpen: view.timelineOpen,
        onOpenBrick: () => _openCombinedBrick(context, brick),
        onOpenLeg: (_) => _openCombinedBrick(context, brick),
        onUngroup: () => _ungroupBrick(context, ref, brick),
        onDelete: () => _deleteBrick(context, ref, brick),
      );
    }
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
                  ? picking
                        ? _pickableWorkout(ref, node.workout!, dayWorkouts)
                        : _workout(context, ref, node.workout!)
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
    // the token contract wins here.) A SKIPPED card's rail ink is neutral
    // (S-7): dimmed cream, not electrolyte, not orange.
    final color = node.isWorkout ? MeTokens.electrolyte : MeTokens.orange;
    if (node.railDashed) {
      // Planned entries get a hollow DOTTED ring (the "not yet" edge).
      return CustomPaint(
        size: const Size(11, 11),
        painter: _DottedRingPainter(
          color: node.isSkippedWorkout
              ? MeTokens.creamAlpha(0.28)
              : node.isWorkout
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
      key: ValueKey('macro_dashboard.workout_${data.activityId}'),
      data: data,
      // Tap into the card → the EXISTING detail surface, unchanged (scope
      // ruling): has-plan/import → Activity Detail, plan-less → the
      // pre-filled New Activity flow (openActivityFuel, Lee 2026-08-10).
      onTap: () => _openDetail(context, ref, data.activityId),
      onFuelTap: () => _openDetail(context, ref, data.activityId),
      // The controller rolls back its optimistic update and RETHROWS on
      // failure; discarding that future would turn a failed write into an
      // uncaught zone error, so surface it instead.
      onMarkDone: () => _guardWrite(
        context,
        () => activities.markWorkoutDone(data.activityId),
        'Could not mark workout done',
      ),
      onMarkUndone: () => _guardWrite(
        context,
        () => activities.markWorkoutUndone(data.activityId),
        'Could not undo — try again',
      ),
      onSkip: () => _skipWithUndo(context, ref, data, skipping: true),
      onUnskip: () => _skipWithUndo(context, ref, data, skipping: false),
    );
  }

  Future<void> _guardWrite(
    BuildContext context,
    Future<void> Function() write,
    String failureCopy,
  ) async {
    try {
      await write();
    } catch (_) {
      // The optimistic state is already rolled back by the controller.
      if (context.mounted) MealvanaSnackbar.showError(context, failureCopy);
    }
  }

  void _openDetail(BuildContext context, WidgetRef ref, String activityId) {
    final activities = ref.read(activitiesControllerProvider).value ?? const [];
    for (final a in activities) {
      if (a.id == activityId) {
        openActivityFuel(context, a);
        return;
      }
    }
  }

  /// G5 + S-2 + S-7: Skip writes status = 'skipped' (clearing actual_time if
  /// the card was DONE_CONFIRMED); the workout's kcal, fuel windows and
  /// timeline slot leave every surface figure in the same frame (the
  /// optimistic controller update recomputes the whole day) and the card
  /// tucks after every timed card. Unskip clears status and restores the
  /// slot. Both offer undo that restores the EXACT prior row (a skip taken
  /// on a confirmed card undoes back to confirmed, actual_time intact).
  /// Nothing here is a delete — the tombstone path is deferred (Q-D6).
  void _skipWithUndo(
    BuildContext context,
    WidgetRef ref,
    WorkoutCardData data, {
    required bool skipping,
  }) async {
    final notifier = ref.read(activitiesControllerProvider.notifier);
    final previous = await notifier.getActivityById(data.activityId);
    if (!context.mounted) return;
    try {
      if (skipping) {
        await notifier.skipWorkout(data.activityId);
      } else {
        await notifier.unskipWorkout(data.activityId);
      }
    } catch (_) {
      // Rolled back by the controller — the card is already back.
      if (context.mounted) {
        MealvanaSnackbar.showError(
          context,
          skipping ? 'Could not skip workout' : 'Could not unskip workout',
        );
      }
      return;
    }
    if (!context.mounted) return;
    MealvanaSnackbar.showInfo(
      context,
      '${data.name} ${skipping ? 'skipped' : 'unskipped'}',
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
            MealvanaSnackbar.showError(context, 'Could not undo — try again');
          }
        }
      },
    );
  }

  // ── Brick (candidate, see class doc) ──────────────────────────────────

  /// Step 2: the add row's slot while picking — "Pick legs to link · Cancel".
  Widget _pickLegsBar(WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: MeTokens.orangeAlpha(0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: MeTokens.orangeAlpha(0.55)),
      ),
      child: Row(
        children: [
          const Icon(Icons.link, size: 14, color: MeTokens.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Pick legs to link', style: _brickText(MeTokens.cream)),
          ),
          GestureDetector(
            key: const ValueKey('macro_dashboard.brick_cancel'),
            onTap: ref
                .read(brickSelectionControllerProvider.notifier)
                .exitSelectionMode,
            child: Text('Cancel', style: _brickText(MeTokens.creamAlpha(0.75))),
          ),
        ],
      ),
    );
  }

  /// Leg-picking: rows stay on the rail and simply become pickable, so the
  /// timeline never reflows mid-flow. Chosen rows get the orange outline and
  /// their leg number in PICK order — which need not match dashboard order.
  /// Ineligible rows (strength, imports, an existing brick) are dimmed and
  /// untouchable.
  Widget _pickableWorkout(
    WidgetRef ref,
    WorkoutCardData data,
    List<Activity> dayWorkouts,
  ) {
    final notifier = ref.read(brickSelectionControllerProvider.notifier);
    // Watch so the outline/number repaint as the selection changes.
    ref.watch(brickSelectionControllerProvider);
    final candidates = brickCandidateIds(
      dayWorkouts.cast<Activity?>().toList(growable: false),
    );
    final selectable = candidates.contains(data.activityId);
    final selected = notifier.isActivitySelected(data.activityId);
    final order = notifier.getSelectionOrder(data.activityId);
    Activity? activity;
    for (final a in dayWorkouts) {
      if (a.id == data.activityId) activity = a;
    }

    return Semantics(
      button: selectable,
      selected: selected,
      label: selectable ? 'Pick ${data.name} as a brick leg' : null,
      child: GestureDetector(
        key: ValueKey('macro_dashboard.brick_pick_${data.activityId}'),
        behavior: HitTestBehavior.opaque,
        onTap: selectable && activity != null
            ? () => notifier.toggleActivity(activity!)
            : null,
        child: Opacity(
          opacity: selectable ? 1 : 0.35,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? MeTokens.orange
                        : selectable
                        ? MeTokens.orangeAlpha(0.35)
                        : Colors.transparent,
                    width: selected ? 2 : 1,
                  ),
                ),
                // The card's own gestures are off mid-flow: a tap picks the
                // leg, and swipes must not mark-done / skip while picking.
                child: IgnorePointer(child: WorkoutCard(data: data)),
              ),
              if (order != null)
                Positioned(
                  top: -8,
                  left: -8,
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: MeTokens.orange,
                    ),
                    child: Text(
                      '$order',
                      style: const TextStyle(
                        fontFamily: 'Apercu',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        height: 1.0,
                        color: MeTokens.blackberry,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static const double _dockedBottomInset = 71;

  /// The docked LEG ORDER panel (step 2 → step 3): the chosen legs as ordered
  /// chips with a Swap affordance, over a full-width `Create Brick (n)` that
  /// commits directly — no confirm modal (Notion 3a7e3fdb, step 3). Below
  /// two legs the slot holds the instruction instead.
  Widget _brickActionBar(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(brickSelectionControllerProvider);
    final notifier = ref.read(brickSelectionControllerProvider.notifier);
    final legs = selection.selectedActivities;
    if (legs.length < 2) return _brickPickHint();

    final canSwap = legs.length >= 2;
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, _dockedBottomInset),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: MeTokens.orangeAlpha(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MeTokens.orangeAlpha(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'LEG ORDER',
                  style: TextStyle(
                    fontFamily: 'Apercu',
                    fontSize: 10.5,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                    color: MeTokens.creamAlpha(0.6),
                  ),
                ),
              ),
              GestureDetector(
                key: const ValueKey('macro_dashboard.brick_swap'),
                onTap: canSwap ? notifier.swapOrder : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.swap_horiz,
                      size: 15,
                      color: canSwap
                          ? MeTokens.electrolyte
                          : MeTokens.creamAlpha(0.3),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Swap',
                      style: _brickText(
                        canSwap
                            ? MeTokens.electrolyte
                            : MeTokens.creamAlpha(0.3),
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
                      color: MeTokens.creamAlpha(0.5),
                    ),
                  ),
                Expanded(child: _legChip(legs[i], i + 1)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          KyleSecondaryButtonSmall(
            key: const ValueKey('macro_dashboard.brick_create'),
            text: 'Create Brick (${legs.length})',
            onPressed: notifier.canCreateBrick()
                ? () => _createBrickFromSelection(context, ref)
                : null,
            variant: SecondaryButtonVariant.orange,
          ),
        ],
      ),
    );
  }

  Widget _brickPickHint() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, _dockedBottomInset),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: MeTokens.creamAlpha(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MeTokens.creamAlpha(0.12)),
      ),
      child: Text(
        'Tap two or more activities to link into a brick',
        textAlign: TextAlign.center,
        style: _brickText(MeTokens.creamAlpha(0.6)),
      ),
    );
  }

  /// One ordered leg chip: `① RUN`.
  Widget _legChip(Activity activity, int order) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: MeTokens.creamAlpha(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MeTokens.creamAlpha(0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: MeTokens.orange,
            ),
            child: Text(
              '$order',
              style: const TextStyle(
                fontFamily: 'Apercu',
                fontSize: 10,
                height: 1.0,
                fontWeight: FontWeight.w700,
                color: MeTokens.blackberry,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              activity.activityType.displayName.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Compadre',
                fontSize: 13,
                color: MeTokens.cream,
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _brickText(Color color) => TextStyle(
    fontFamily: 'Apercu',
    fontWeight: FontWeight.w500,
    fontSize: 12.5,
    color: color,
  );

  Future<void> _createBrickFromSelection(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final selected = List<Activity>.from(
      ref.read(brickSelectionControllerProvider).selectedActivities,
    );
    final loading = MealvanaSnackbar.showLoading(
      context,
      'Creating brick workout...',
    );
    var dismissed = false;
    void dismiss() {
      if (dismissed) return;
      dismissed = true;
      loading.close();
    }

    try {
      await ref
          .read(brickActionsControllerProvider.notifier)
          .createBrickFromSelection(
            activities: selected,
            segmentOrder: selected
                .map((a) => a.activityType.name)
                .toList(growable: false),
          );
      if (!context.mounted) return;
      ref.read(brickSelectionControllerProvider.notifier).exitSelectionMode();
      ref.invalidate(activitiesControllerProvider);
      dismiss();
      final legs = selected.map((a) => a.activityType.displayName).join(' → ');
      final createdBrickId = ref
          .read(activitiesControllerProvider)
          .value
          ?.firstWhere(
            (a) =>
                a.isBrick &&
                (a.brickMetadata?.originalActivityIds ?? const []).contains(
                  selected.first.id,
                ),
            orElse: () => selected.first,
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
      dismiss();
      if (!context.mounted) return;
      await showDialog<bool>(
        context: context,
        builder: (_) =>
            BrickValidationErrorDialog(exception: e, onRetry: () {}),
      );
    } on BrickCreationException catch (e) {
      dismiss();
      if (!context.mounted) return;
      final retry = await showDialog<bool>(
        context: context,
        builder: (_) => BrickCreationErrorDialog(exception: e, onRetry: () {}),
      );
      if (retry == true && e.code == 'NETWORK_ERROR' && context.mounted) {
        await _createBrickFromSelection(context, ref);
      }
    } catch (e) {
      dismiss();
      if (context.mounted) {
        MealvanaSnackbar.showError(
          context,
          'Unexpected error creating brick: $e',
        );
      }
    } finally {
      dismiss();
    }
  }

  Future<void> _ungroupBrick(
    BuildContext context,
    WidgetRef ref,
    Activity brick,
  ) async {
    final segmentCount = brick.brickMetadata?.segments.length ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => BrickUngroupDialog(segmentCount: segmentCount),
    );
    if (confirmed != true || !context.mounted) return;

    final loading = MealvanaSnackbar.showLoading(
      context,
      'Ungrouping brick...',
    );
    var dismissed = false;
    void dismiss() {
      if (dismissed) return;
      dismissed = true;
      loading.close();
    }

    try {
      await ref
          .read(brickActionsControllerProvider.notifier)
          .ungroupBrick(brick.id);
      if (!context.mounted) return;
      ref.invalidate(activitiesControllerProvider);
      dismiss();
      MealvanaSnackbar.showSuccess(context, 'Brick ungrouped successfully!');
    } on BrickUngroupException catch (e) {
      dismiss();
      if (!context.mounted) return;
      final retry = await showDialog<bool>(
        context: context,
        builder: (_) => BrickUngroupErrorDialog(exception: e, onRetry: () {}),
      );
      if (retry == true && e.code == 'NETWORK_ERROR' && context.mounted) {
        await _ungroupBrick(context, ref, brick);
      }
    } catch (e) {
      dismiss();
      if (context.mounted) {
        MealvanaSnackbar.showError(
          context,
          'Unexpected error ungrouping brick: $e',
        );
      }
    } finally {
      dismiss();
    }
  }

  void _openCombinedBrick(BuildContext context, Activity brick) {
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
        },
      );
    }
  }

  /// "Delete brick" returns the day to the UNGROUPED state (Notion 3a7e3fdb,
  /// "rules that fall out"): the legs come back as separate workouts and the
  /// brick — with its nutrition plan — goes away. A plain tombstone of the
  /// brick row is wrong here: it leaves the legs `archivedForBrick`, i.e.
  /// invisible, which is what happened on-sim 2026-08-26.
  Future<void> _deleteBrick(
    BuildContext context,
    WidgetRef ref,
    Activity brick,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Brick Workout?'),
        content: const Text(
          'Delete this brick and its nutrition plan? The legs return to the '
          'day as separate workouts.',
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
    final loading = MealvanaSnackbar.showLoading(context, 'Deleting brick...');
    var dismissed = false;
    void dismiss() {
      if (dismissed) return;
      dismissed = true;
      loading.close();
    }

    try {
      await ref
          .read(brickActionsControllerProvider.notifier)
          .ungroupBrick(brick.id);
      if (!context.mounted) return;
      ref.invalidate(activitiesControllerProvider);
      dismiss();
      MealvanaSnackbar.showSuccess(context, 'Brick deleted · legs restored');
    } catch (e) {
      dismiss();
      if (context.mounted) {
        MealvanaSnackbar.showError(context, 'Error deleting brick: $e');
      }
    } finally {
      dismiss();
    }
  }

  Widget _meals(
    WidgetRef ref,
    MacroDashboardViewState view,
    DashboardNode node,
  ) {
    final notifier = ref.read(macroDashboardViewProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in node.meals)
          MealCard(
            key: ValueKey('macro_dashboard.meal_${item.id}'),
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
