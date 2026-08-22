// GESTURE / BEHAVIOR tests for the macro dashboard — one per row of
// docs/ssot/conformance/design/macro-dashboard.gestures.yaml (v3, 18 rows;
// each test name starts with the manifest id it pins). A test pins
// its contract only if it executes the REAL code path (no false pins):
// gesture rows drive the real WorkoutCard/EnergySummaryCard widgets;
// data-model rows run the real assembler/domain code on the canonical
// mock day.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/daily_macro_targets.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/intraday_display.dart';
import 'package:mealvana_endurance/features/macro_dashboard/application/dashboard_assembler.dart';
import 'package:mealvana_endurance/features/macro_dashboard/domain/dashboard_models.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/me_tokens.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/widgets/energy_summary_card.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/widgets/workout_card.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/daily_baseline_calculator.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/intensity_distribution.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/domain/session_input_resolver.dart';

/// The ruled zones-absent IF (2026-08-22): the engine's default distribution
/// through the one RMS derivation — never a hardcoded constant here, so this
/// suite cannot drift from the resolver the way the flat 0.74 did.
final double _zonelessIf = DailyBaselineCalculator.zoneDistributionToIf(
  pctConversational: SessionInputResolver.defaultZ1Z2Pct / 100,
  pctTempo: SessionInputResolver.defaultZ3Z4Pct / 100,
  pctAllout: SessionInputResolver.defaultZ5Pct / 100,
);

// ---------------------------------------------------------------------------
// Canonical mock day (goldens manifest): verified 8:00 swim 229 kcal,
// planned 5:30 run 1,309 kcal (was 1,205 at the retired flat-0.74 IF), snapshot 15:00, eaten 1,650, targets 4,152.
// ---------------------------------------------------------------------------

final _day = DateTime(2026, 8, 14);
final _now = DateTime(2026, 8, 14, 15, 0);

Activity _swimVerified() => Activity(
  id: 'w1',
  userId: 'u1',
  activityType: ActivityType.swimming,
  title: 'Swim',
  scheduledDateTime: DateTime(2026, 8, 14, 8, 0),
  plannedTime: DateTime(2026, 8, 14, 8, 0),
  actualTime: DateTime(2026, 8, 14, 8, 0),
  status: ActivityStatus.completed,
  garminSummaryId: 'g-swim-1',
  caloriesBurned: 228.7,
  durationMinutes: 40,
  createdAt: _day,
  updatedAt: _day,
);

Activity _runPlanned() => Activity(
  id: 'w2',
  userId: 'u1',
  activityType: ActivityType.running,
  title: 'Run',
  scheduledDateTime: DateTime(2026, 8, 14, 17, 30),
  plannedTime: DateTime(2026, 8, 14, 17, 30),
  status: ActivityStatus.planned,
  durationMinutes: 90,
  createdAt: _day,
  updatedAt: _day,
);

DailyMacroTargets _targets() => DailyMacroTargets(
  id: 't1',
  userId: 'u1',
  targetDate: _day,
  carbG: 596,
  protG: 130,
  fatG: 138,
  tdee: 4152,
  rmr: 1908,
  sessionKcal: 1538,
  neatKcal: 394.9,
  mode: 'prospective',
  algorithmVersion: 'v6.0.0',
  createdAt: _day,
  updatedAt: _day,
  weightKg: 75,
);

/// The same day viewed the morning after — every unresolved workout is then
/// PASSIVELY skipped (Q-D5/Q-D6 passive trigger).
final _nextMorning = DateTime(2026, 8, 15, 9, 0);

Activity _runSkippedActively() =>
    _runPlanned().copyWith(status: ActivityStatus.skipped);

DashboardData _assemble(List<Activity> activities, {DateTime? now}) {
  const assembler = MacroDashboardAssembler();
  return assembler.assemble(
    selectedDate: _day,
    now: now ?? _now,
    activities: activities,
    meals: const [],
    targets: _targets(),
    consumed: const ConsumedTotals(
      calories: 1650,
      carbsG: 262,
      proteinG: 68,
      fatG: 36,
    ),
    trackingOn: true,
  );
}

WorkoutCardData _card(
  WorkoutCardState state, {
  String id = 'w2',
  bool skipActive = false,
}) => WorkoutCardData(
  activityId: id,
  name: 'Run',
  timeLabel: '5:30 PM',
  metaLabel: '90 min',
  kcal: 1309,
  state: state,
  sport: 'running',
  skipActive: skipActive,
);

WorkoutCardData _workoutCardOf(DashboardData d, String name) =>
    d.nodes.firstWhere((n) => n.isWorkout && n.workout!.name == name).workout!;

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Center(child: SizedBox(width: 640, child: child)),
  ),
);

/// Drive a horizontal drag on the card in small steps (a fling test would
/// bypass the widget's incremental clamping).
Future<void> _drag(WidgetTester tester, Finder finder, double dx) async {
  final gesture = await tester.startGesture(tester.getCenter(finder));
  const steps = 12;
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(dx / steps, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

/// True when any Container / Ink / decoration in the tree paints the
/// dragonfruit token — the token contract forbids it on the v2 card.
bool _paintsDragonfruit(WidgetTester tester) {
  bool isDragon(Color? c) => c == MeTokens.dragonfruit;
  for (final w in tester.allWidgets) {
    if (w is Container && isDragon(w.color)) return true;
    if (w is Container && w.decoration is BoxDecoration) {
      final d = w.decoration as BoxDecoration;
      if (isDragon(d.color)) return true;
    }
    if (w is DecoratedBox && w.decoration is BoxDecoration) {
      if (isDragon((w.decoration as BoxDecoration).color)) return true;
    }
    if (w is ColoredBox && isDragon(w.color)) return true;
    if (w is Icon && isDragon(w.color)) return true;
    if (w is Text && isDragon(w.style?.color)) return true;
  }
  return false;
}

void main() {
  // g1_swipe_right_marks_done (workout-card G1)
  testWidgets(
    'g1_swipe_right_marks_done: full right-swipe on PLANNED emits mark-done',
    (tester) async {
      var markedDone = 0;
      await tester.pumpWidget(
        _host(
          WorkoutCard(
            data: _card(WorkoutCardState.planned),
            onMarkDone: () => markedDone++,
            onMarkUndone: () => fail('planned card must emit done, not undone'),
          ),
        ),
      );
      await _drag(tester, find.byType(WorkoutCard), 320);
      expect(markedDone, 1);
      // The actual_time / planned_time-untouched half of G1 is pinned at the
      // write seam below ('two-time writes').
    },
  );

  // G1 on a FUTURE day is suppressed (ruled by the spec owner 2026-08-18,
  // app implemented ahead of the SSOT fold — qa intake
  // 2026-08-18-mark-done-on-non-current-day.md): a workout that hasn't
  // happened cannot be confirmed. Like G3: token nudge, no reveal, no emit.
  // Skip (left) stays available; mark-UNDONE on a confirmed card stays
  // available so a legacy future-day confirmation can be corrected.
  testWidgets(
    'g1_future_day_not_offered: future-day right-swipe suppressed; skip and undone still work',
    (tester) async {
      var skipped = 0;
      await tester.pumpWidget(
        _host(
          WorkoutCard(
            data: WorkoutCardData(
              activityId: 'w9',
              name: 'Tomorrow ride',
              timeLabel: '7:00 AM',
              metaLabel: '100 min',
              kcal: 1022,
              state: WorkoutCardState.planned,
              sport: 'cycling',
              markDoneAllowed: false,
            ),
            onMarkDone: () =>
                fail('a future-day workout cannot be marked done'),
            onSkip: () => skipped++,
          ),
        ),
      );
      final before = tester.getTopLeft(find.text('Tomorrow ride'));
      await _drag(tester, find.byType(WorkoutCard), 320);
      expect(tester.getTopLeft(find.text('Tomorrow ride')).dx - before.dx, 0);
      expect(find.text('Mark done'), findsNothing);
      // Skip is still offered.
      await _drag(tester, find.byType(WorkoutCard), -90);
      expect(find.text('Skip'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(skipped, 1);

      // A (legacy) confirmed card on a future day can still be undone.
      var undone = 0;
      await tester.pumpWidget(
        _host(
          WorkoutCard(
            data: WorkoutCardData(
              activityId: 'w9',
              name: 'Tomorrow ride',
              timeLabel: '7:00 AM',
              metaLabel: '100 min',
              kcal: 1022,
              state: WorkoutCardState.doneConfirmed,
              sport: 'cycling',
              markDoneAllowed: false,
            ),
            onMarkUndone: () => undone++,
          ),
        ),
      );
      await _drag(tester, find.byType(WorkoutCard), 320);
      expect(undone, 1);
    },
  );

  // G1 also recovers a SKIPPED card (passive or active) → DONE_CONFIRMED.
  testWidgets(
    'skipped_swipe_right_recovers: full right-swipe on SKIPPED emits mark-done',
    (tester) async {
      for (final active in [false, true]) {
        var markedDone = 0;
        await tester.pumpWidget(
          _host(
            WorkoutCard(
              data: _card(WorkoutCardState.skipped, skipActive: active),
              onMarkDone: () => markedDone++,
              onMarkUndone: () => fail('skipped card must emit done'),
            ),
          ),
        );
        await _drag(tester, find.byType(WorkoutCard), 320);
        expect(markedDone, 1, reason: 'skipActive=$active');
      }
    },
  );

  // g2_swipe_right_again_undoes (workout-card G2)
  testWidgets(
    'g2_swipe_right_again_undoes: full right-swipe on DONE_CONFIRMED undoes',
    (tester) async {
      var undone = 0;
      await tester.pumpWidget(
        _host(
          WorkoutCard(
            data: _card(WorkoutCardState.doneConfirmed),
            onMarkDone: () => fail('confirmed card must emit undone'),
            onMarkUndone: () => undone++,
          ),
        ),
      );
      await _drag(tester, find.byType(WorkoutCard), 320);
      expect(undone, 1);
    },
  );

  // g3_verified_suppressed — NEGATIVE TEST (Q-D1 ruling; widened to BOTH
  // swipe directions in v2)
  testWidgets(
    'g3_verified_suppressed: any swipe on DONE_VERIFIED is suppressed entirely',
    (tester) async {
      await tester.pumpWidget(
        _host(
          WorkoutCard(
            data: _card(WorkoutCardState.doneVerified),
            onMarkDone: () => fail('verified card must not emit done'),
            onMarkUndone: () => fail('verified card must not emit undone'),
            onSkip: () => fail('verified card must not emit skip'),
            onUnskip: () => fail('verified card must not emit unskip'),
          ),
        ),
      );
      final before = tester.getTopLeft(find.text('Run'));

      // Right-swipe: zero translation after release, no reveal, no
      // "Mark undone" node.
      await _drag(tester, find.byType(WorkoutCard), 320);
      expect(tester.getTopLeft(find.text('Run')).dx - before.dx, 0);
      expect(find.text('Mark undone'), findsNothing);
      expect(find.text('Mark done'), findsNothing);

      // LEFT-swipe: zero translation after release, no reveal, no
      // Skip/Unskip node in the tree.
      await _drag(tester, find.byType(WorkoutCard), -120);
      expect(tester.getTopLeft(find.text('Run')).dx - before.dx, 0);
      expect(find.text('Skip'), findsNothing);
      expect(find.text('Unskip'), findsNothing);
      expect(
        find.byKey(const ValueKey('macro_dashboard.skip_button')),
        findsNothing,
      );
    },
  );

  // Card tap → the existing detail surface (scope ruling: the tapped-into
  // view is untouched; the card only routes to it). A tap while the delete
  // reveal is open closes the reveal instead of navigating.
  testWidgets('tap: card tap emits onTap; reveal-open tap only closes reveal', (
    tester,
  ) async {
    var tapped = 0;
    await tester.pumpWidget(
      _host(
        WorkoutCard(
          data: _card(WorkoutCardState.planned),
          onTap: () => tapped++,
        ),
      ),
    );
    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();
    expect(tapped, 1);

    // Open the skip reveal, then tap the card: reveal closes, no navigate.
    await _drag(tester, find.byType(WorkoutCard), -90);
    expect(find.text('Skip'), findsOneWidget);
    await tester.tap(find.text('Run'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tapped, 1, reason: 'a reveal-closing tap must not navigate');
  });

  // g4_swipe_left_reveals_skip (workout-card G4, v2)
  testWidgets(
    'g4_swipe_left_reveals_skip: partial left-swipe reveals a labeled Skip / Unskip; the swipe never changes state',
    (tester) async {
      // PLANNED and DONE_CONFIRMED reveal "Skip".
      for (final state in [
        WorkoutCardState.planned,
        WorkoutCardState.doneConfirmed,
      ]) {
        var skipped = 0;
        await tester.pumpWidget(
          _host(
            WorkoutCard(
              data: _card(state),
              onSkip: () => skipped++,
              onUnskip: () => fail('$state must reveal Skip, not Unskip'),
              onMarkDone: () => fail('a left swipe must never change state'),
              onMarkUndone: () => fail('a left swipe must never change state'),
            ),
          ),
        );
        await _drag(tester, find.byType(WorkoutCard), -90);
        // The swipe itself NEVER skips; the labeled button does.
        expect(skipped, 0, reason: '$state');
        expect(find.text('Skip'), findsOneWidget, reason: '$state');
        expect(find.text('Unskip'), findsNothing);
        // Neutral, never destructive: no dragonfruit anywhere in the reveal.
        expect(
          _paintsDragonfruit(tester),
          isFalse,
          reason: 'skip reveal must carry no dragonfruit token',
        );
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
        expect(skipped, 1, reason: '$state');
      }

      // An ACTIVELY skipped card reveals "Unskip".
      var unskipped = 0;
      await tester.pumpWidget(
        _host(
          WorkoutCard(
            data: _card(WorkoutCardState.skipped, skipActive: true),
            onSkip: () => fail('an actively skipped card reveals Unskip'),
            onUnskip: () => unskipped++,
          ),
        ),
      );
      await _drag(tester, find.byType(WorkoutCard), -90);
      expect(unskipped, 0);
      expect(find.text('Unskip'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
      expect(_paintsDragonfruit(tester), isFalse);
      await tester.tap(find.text('Unskip'));
      await tester.pumpAndSettle();
      expect(unskipped, 1);

      // A past-day PASSIVE skip has nothing to un-skip: the reveal carries no
      // button (recovery there is G1 only).
      await tester.pumpWidget(
        _host(
          WorkoutCard(
            data: _card(WorkoutCardState.skipped, skipActive: false),
            onSkip: () => fail('passive skip reveals no button'),
            onUnskip: () => fail('passive skip reveals no button'),
          ),
        ),
      );
      await _drag(tester, find.byType(WorkoutCard), -90);
      expect(find.text('Skip'), findsNothing);
      expect(find.text('Unskip'), findsNothing);
      expect(
        find.byKey(const ValueKey('macro_dashboard.skip_button')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('macro_dashboard.unskip_button')),
        findsNothing,
      );
    },
  );

  // g5_skip_removes_everywhere (G5 + surface S-2 + S-7): a Skip press
  // writes status='skipped' (clearing actual_time if the card was
  // DONE_CONFIRMED); the workout's kcal leaves EVERY surface figure in the
  // same recompute; the card renders with no timestamp, tucked after every
  // timed card; Unskip restores state, slot and figures.
  test(
    'g5_skip_removes_everywhere: skip removes the workout from every surface figure and tucks it; unskip restores',
    () {
      final before = _assemble([_swimVerified(), _runPlanned()]);
      // -- the write seam: Skip on a DONE_CONFIRMED card clears actual_time.
      final confirmed = _runPlanned().copyWith(
        status: ActivityStatus.completed,
        actualTime: _now,
      );
      final skippedRow = confirmed.copyWith(
        status: ActivityStatus.skipped,
        clearActualTime: true,
      );
      expect(skippedRow.status, ActivityStatus.skipped);
      expect(
        skippedRow.actualTime,
        isNull,
        reason: 'skipping asserts it did not happen',
      );
      expect(
        skippedRow.plannedTime,
        confirmed.plannedTime,
        reason: 'planned_time is never touched',
      );

      // -- the surface: figures leave in the same frame.
      final after = _assemble([_swimVerified(), skippedRow]);
      final card = _workoutCardOf(after, 'Run');
      expect(card.state, WorkoutCardState.skipped);
      expect(card.skipActive, isTrue);
      expect(card.chipLabel, 'Skipped');
      // Still on the timeline (tucked), but out of every figure.
      expect(after.nodes.where((n) => n.isWorkout).length, 2);
      expect(
        after.energy!.workoutPlannedKcal,
        0,
        reason: 'the skipped run leaves the projected total',
      );
      expect(
        after.energy!.workoutProjectedKcal,
        lessThan(before.energy!.workoutProjectedKcal),
      );
      expect(
        after.energy!.workoutRows.map((r) => r.name),
        ['Swim'],
        reason: 'the Active Energy sheet drops the skipped row',
      );
      expect(
        after.breakdown!.workoutByEnd,
        lessThan(before.breakdown!.workoutByEnd),
        reason: 'by-end-of-day burn drops it too',
      );
      // The mock-day net (−133) is unaffected because the planned run had
      // no so-far contribution; band copy stays "on track".
      expect(after.energy!.netKcal, -133);
      expect(after.energy!.bandCopy, 'on track');

      // -- S-7: no timestamp, tucked after every timed card.
      final tuckedNode = after.nodes.last;
      expect(tuckedNode.isSkippedWorkout, isTrue);
      expect(
        tuckedNode.timeLabel,
        '',
        reason: 'a skipped card renders with no timestamp',
      );
      expect(after.nodes.first.workout!.name, 'Swim');

      // -- Unskip → PLANNED, status cleared, planned_time unchanged, card back
      // in its time-ordered slot, kcal re-enters every figure.
      final unskippedRow = skippedRow.copyWith(status: ActivityStatus.planned);
      expect(unskippedRow.plannedTime, _runPlanned().plannedTime);
      final restored = _assemble([_swimVerified(), unskippedRow]);
      final restoredCard = _workoutCardOf(restored, 'Run');
      expect(restoredCard.state, WorkoutCardState.planned);
      expect(
        restored.nodes.last.timeLabel,
        '5:30 PM',
        reason: 'back in its time-ordered slot',
      );
      expect(
        restored.energy!.workoutProjectedKcal,
        before.energy!.workoutProjectedKcal,
      );
      expect(restored.energy!.workoutRows.map((r) => r.name), ['Swim', 'Run']);
      // Undo restores the exact prior state — the screen writes `previous`
      // back through restoreActivity; the domain round-trip is the identity.
      expect(
        skippedRow.copyWith(
          status: confirmed.status,
          actualTime: confirmed.actualTime,
        ),
        confirmed,
      );
    },
  );

  // s7 tuck ordering: several skipped cards order by planned_time ascending,
  // after every timed card (planned or done) — meals included.
  test(
    's7 (g5_skip_removes_everywhere): skipped cards tuck after every timed card, ordered by planned_time',
    () {
      final earlySkipped = _runPlanned().copyWith(
        id: 'w3',
        title: 'Early run',
        status: ActivityStatus.skipped,
        plannedTime: DateTime(2026, 8, 14, 6, 0),
        scheduledDateTime: DateTime(2026, 8, 14, 6, 0),
      );
      final lateSkipped = _runSkippedActively();
      final data = _assemble([lateSkipped, _swimVerified(), earlySkipped]);
      final names = [for (final n in data.nodes) n.workout!.name];
      expect(names, ['Swim', 'Early run', 'Run']);
      expect(data.nodes[1].timeLabel, '');
      expect(data.nodes[2].timeLabel, '');
    },
  );

  // g6_sync_beats_skip (workout-card G6 + platform-resolution SKIPPED
  // addition): a matching platform sync upgrades a skipped row — active or
  // passive — to DONE_VERIFIED with the measured start; fuel is back in
  // every figure; and no gesture reverts it (G3). The matcher half (match
  // key: platform id, else platform+sport+start ±15 min; skipped rows are
  // never filtered before matching) is pinned server-side in
  // supabase/functions/_shared/garmin/activity_completion.test.ts.
  test('g6_sync_beats_skip: sync beats skip — active and passive', () {
    // The completion write the Garmin matcher performs
    // (buildGarminCompletionUpdate): status completed, actual_time =
    // measured start, summary id linked, kcal mirrored.
    Activity synced(Activity row) => row.copyWith(
      status: ActivityStatus.completed,
      actualTime: DateTime(2026, 8, 14, 17, 34),
      garminSummaryId: 'g-run-99',
      caloriesBurned: 1180,
    );

    // Active skip.
    final activeBefore = _assemble([_swimVerified(), _runSkippedActively()]);
    expect(activeBefore.energy!.workoutDoneKcal, 229);
    final activeAfter = _assemble([
      _swimVerified(),
      synced(_runSkippedActively()),
    ]);
    final activeCard = _workoutCardOf(activeAfter, 'Run');
    expect(activeCard.state, WorkoutCardState.doneVerified);
    expect(
      activeCard.timeLabel,
      '5:34 PM',
      reason: 'actual_time = measured start',
    );
    expect(
      activeAfter.energy!.workoutDoneKcal,
      229 + 1180,
      reason: 'kcal back in every figure',
    );
    expect(activeAfter.energy!.workoutRows.map((r) => r.name), ['Swim', 'Run']);

    // Passive skip (past day, unresolved) — same outcome.
    final passiveBefore = _assemble([
      _swimVerified(),
      _runPlanned(),
    ], now: _nextMorning);
    expect(
      _workoutCardOf(passiveBefore, 'Run').state,
      WorkoutCardState.skipped,
    );
    expect(_workoutCardOf(passiveBefore, 'Run').skipActive, isFalse);
    final passiveAfter = _assemble([
      _swimVerified(),
      synced(_runPlanned()),
    ], now: _nextMorning);
    expect(
      _workoutCardOf(passiveAfter, 'Run').state,
      WorkoutCardState.doneVerified,
    );
    expect(passiveAfter.energy!.workoutDoneKcal, 229 + 1180);

    // After the sync, the card is verified: G3 suppresses every gesture
    // (pinned by the g3 widget test above).
    expect(activeCard.isVerified, isTrue);
  });

  // skipped_passive_only_on_past_days (Q-D6 passive trigger = Q-D5)
  test(
    'skipped_passive_only_on_past_days: passive SKIPPED renders on a past day only — never today',
    () {
      // Past day: the unresolved run renders SKIPPED, neutral drain, chip.
      final past = _assemble([
        _swimVerified(),
        _runPlanned(),
      ], now: _nextMorning);
      final pastCard = _workoutCardOf(past, 'Run');
      expect(pastCard.state, WorkoutCardState.skipped);
      expect(pastCard.skipActive, isFalse);
      expect(pastCard.chipLabel, 'Skipped');

      // The SAME untouched unresolved workout on the current day renders
      // PLANNED — never SKIPPED, even late in the evening (the rejected
      // same-day-22:00 trigger must not exist).
      for (final now in [
        DateTime(2026, 8, 14, 15, 0),
        DateTime(2026, 8, 14, 22, 30),
        DateTime(2026, 8, 14, 23, 59),
      ]) {
        final today = _assemble([_swimVerified(), _runPlanned()], now: now);
        expect(
          _workoutCardOf(today, 'Run').state,
          WorkoutCardState.planned,
          reason: 'at $now',
        );
      }
    },
  );

  // skipped_active_on_current_day (Q-D6 active trigger + G4/G5)
  test(
    'skipped_active_on_current_day: Skip on TODAY\'s planned workout renders SKIPPED today',
    () {
      final data = _assemble([_swimVerified(), _runSkippedActively()]);
      final card = _workoutCardOf(data, 'Run');
      expect(card.state, WorkoutCardState.skipped);
      expect(card.skipActive, isTrue);
      expect(card.chipLabel, 'Skipped');
      // Tucked: last node, no timestamp.
      expect(data.nodes.last.workout!.name, 'Run');
      expect(data.nodes.last.timeLabel, '');
    },
  );

  // skipped_fuel_not_counted (Q-D5/Q-D6 fuel + confirmation rung + S-2)
  test(
    'skipped_fuel_not_counted: a SKIPPED workout appears in NO surface figure — passive and active alike',
    () {
      void expectNotCounted(DashboardData d) {
        expect(d.energy!.workoutPlannedKcal, 0);
        expect(d.energy!.workoutDoneKcal, 229, reason: 'only the swim');
        expect(d.energy!.workoutProjectedKcal, 229);
        expect(d.energy!.workoutRows.map((r) => r.name), ['Swim']);
        expect(d.breakdown!.workoutByEnd, 229);
      }

      expectNotCounted(_assemble([_swimVerified(), _runSkippedActively()]));
      expectNotCounted(
        _assemble([_swimVerified(), _runPlanned()], now: _nextMorning),
      );
    },
  );

  // skipped_swipe_right_recovers (G1/G2 on SKIPPED)
  test(
    'skipped_swipe_right_recovers: right-swipe recovers to DONE_CONFIRMED at its planned slot on its own day; again → the day\'s unresolved state',
    () {
      // G1 on an actively skipped card: mark-done → status leaves skipped,
      // actual_time = planned_time (Q-D7), fuel re-enters, card back on the
      // time-ordered rail at its planned slot.
      final recovered = _runSkippedActively().copyWith(
        status: ActivityStatus.completed,
        actualTime: _runPlanned().plannedTime,
      );
      final today = _assemble([_swimVerified(), recovered]);
      final todayCard = _workoutCardOf(today, 'Run');
      expect(todayCard.state, WorkoutCardState.doneConfirmed);
      expect(todayCard.timeLabel, '5:30 PM', reason: 'its planned slot');
      expect(today.energy!.workoutDoneKcal, closeTo(1538, 1));
      expect(
        today.nodes.last.timeLabel,
        isNot(''),
        reason: 'back on the time-ordered rail',
      );
      // A PAST-day recovery lands on its own day, at its slot — never today.
      final pastRecovered = _assemble([
        _swimVerified(),
        recovered,
      ], now: _nextMorning);
      expect(
        _workoutCardOf(pastRecovered, 'Run').state,
        WorkoutCardState.doneConfirmed,
      );
      expect(_workoutCardOf(pastRecovered, 'Run').timeLabel, '5:30 PM');

      // G2 again → the day's unresolved state: PLANNED on the current day...
      final undone = recovered.copyWith(
        status: ActivityStatus.planned,
        clearActualTime: true,
      );
      expect(
        _workoutCardOf(_assemble([_swimVerified(), undone]), 'Run').state,
        WorkoutCardState.planned,
      );
      // ...SKIPPED (derived) on a past day — never a PLANNED card on a past
      // day (the W-10 guard).
      final pastUndone = _assemble([
        _swimVerified(),
        undone,
      ], now: _nextMorning);
      final pastCard = _workoutCardOf(pastUndone, 'Run');
      expect(pastCard.state, WorkoutCardState.skipped);
      expect(pastCard.skipActive, isFalse);
      expect(
        pastUndone.nodes.last.timeLabel,
        '',
        reason: 'back to the S-7 tucked position on a past day',
      );
    },
  );

  // g7_emission_propagates (G7 + surface S-1): one state change moves net
  // balance, band copy, and the Active Energy numbers together — the
  // verified example −133 ⇄ −1,338.
  test(
    'g7_emission_propagates: marking the run done flips net −133 → −1,338 with copy following',
    () {
      final rest = _assemble([_swimVerified(), _runPlanned()]);
      expect(rest.energy!.netKcal, -133);
      expect(rest.energy!.bandCopy, 'on track');

      final done = _assemble([
        _swimVerified(),
        _runPlanned().copyWith(
          status: ActivityStatus.completed,
          actualTime: _now,
        ),
      ]);
      expect(done.energy!.netKcal, -1442);
      expect(done.energy!.bandCopy, 'deficit — time to eat');
      expect(done.energy!.workoutDoneKcal, closeTo(1538, 1));
      expect(done.energy!.workoutPlannedKcal, 0);
    },
  );

  // e1_toggle_expansion (energy-card E1)
  testWidgets(
    'e1_toggle_expansion: chevron toggles expansion in place, never navigates',
    (tester) async {
      var expanded = false;
      late StateSetter setOuterState;
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setOuterState = setState;
                return SizedBox(
                  width: 640,
                  child: EnergySummaryCard(
                    face: DashboardFilter.all,
                    expanded: expanded,
                    data: _energyData,
                    onToggleExpanded: () =>
                        setState(() => expanded = !expanded),
                  ),
                );
              },
            ),
          ),
        ),
      );
      expect(find.text('NET ENERGY BALANCE'), findsNothing);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();
      expect(expanded, isTrue);
      expect(find.text('NET ENERGY BALANCE'), findsOneWidget);
      expect(
        navigatorKey.currentState!.canPop(),
        isFalse,
        reason: 'E1 never navigates',
      );
      setOuterState(() {});
    },
  );

  // p1_expansion_persists_across_faces (energy-card P-1)
  testWidgets(
    'p1_expansion_persists_across_faces: expansion persists across a face switch',
    (tester) async {
      var face = DashboardFilter.meals;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SizedBox(
                width: 640,
                child: Column(
                  children: [
                    EnergySummaryCard(
                      face: face,
                      expanded: true, // expanded in MEALS...
                      data: _energyData,
                      onToggleExpanded: () {},
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => face = DashboardFilter.workout),
                      child: const Text('switch'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('INTAKE TODAY'), findsOneWidget);
      await tester.tap(find.text('switch'));
      await tester.pumpAndSettle();
      // ...WORKOUT arrives expanded (the card never unmounted, E3).
      expect(find.text('ACTIVE ENERGY'), findsOneWidget);
    },
  );

  // p1_expansion_survives_swipe (P-1 + S-4, the W-8 regression guard):
  // expansion lives in the surface view-state, so a workout-card state
  // change (a data recompute) cannot collapse it.
  test(
    'p1_expansion_survives_swipe: expansion state is independent of the day recompute',
    () {
      // The view-state object carries dashOpen; assembling a new day (the
      // effect of any card swipe) produces data only — nothing in
      // DashboardData can reset dashOpen by construction.
      final before = _assemble([_swimVerified(), _runPlanned()]);
      final after = _assemble([
        _swimVerified(),
        _runPlanned().copyWith(
          status: ActivityStatus.completed,
          actualTime: _now,
        ),
      ]);
      expect(before.runtimeType, after.runtimeType);
      expect(
        DashboardData(
          nodes: after.nodes,
          energy: after.energy,
          trackingOn: after.trackingOn,
        ),
        isA<DashboardData>(),
        reason: 'DashboardData carries no expansion field to clobber (S-4)',
      );
    },
  );

  // s6_no_unconditional_deadlines (surface S-6) — string-level check over
  // every copy string the surface can render.
  test(
    's6_no_unconditional_deadlines: no rendered copy states an unconditional refueling deadline',
    () {
      final sources = Directory('lib/features/macro_dashboard')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      final withinMinutes = RegExp(r'within \d+ min', caseSensitive: false);
      final withinHour = RegExp(r'within the hour', caseSensitive: false);
      for (final f in sources) {
        final content = f.readAsStringSync();
        expect(
          withinMinutes.hasMatch(content),
          isFalse,
          reason: '${f.path} contains an unconditional-deadline string',
        );
        expect(
          withinHour.hasMatch(content),
          isFalse,
          reason: '${f.path} contains an unconditional-deadline string',
        );
      }
    },
  );

  // Q-D4 regression pin (bug report 2026-08-20-awaiting-sync-copy-on-active-
  // energy-sheet): the awaiting-sync concept is RULED dead — "self-reported"
  // IS the never-synced signal (workout-card.md); the reference rendering's
  // awaitingSync flag stays dead. String-level check over every dashboard
  // source (like s6 above) so sibling-surface copy — sheets included, which
  // goldens/gesture manifests don't cover — cannot resurrect it.
  test(
    'q_d4_no_awaiting_sync_copy: "awaiting sync" appears nowhere in the macro_dashboard sources',
    () {
      final sources = Directory('lib/features/macro_dashboard')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      final awaitingSync = RegExp(r'awaiting[ _-]?sync', caseSensitive: false);
      for (final f in sources) {
        // Comment lines may cite the ruling by name; only code (string
        // literals, identifiers) can resurrect the concept.
        final code = f
            .readAsStringSync()
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        expect(
          awaitingSync.hasMatch(code),
          isFalse,
          reason:
              '${f.path} resurrects the ruled-dead awaiting-sync concept (Q-D4)',
        );
      }
    },
  );

  // W-6 outside-dismiss (bug report 2026-08-20-dashboard-papercuts, item 1):
  // the reference rendering's reveal never auto-dismisses — a known
  // prototype defect the SSOT lists as NOT to encode (workout-card.md,
  // "Known reference-rendering defects"). A tap landing outside the card
  // closes an open reveal without emitting skip or navigation; the reveal
  // and its button keep working afterwards.
  testWidgets(
    'reveal_outside_tap_dismisses: a tap outside the card closes an open Skip reveal',
    (tester) async {
      var tapped = 0;
      var skipped = 0;
      await tester.pumpWidget(
        _host(
          WorkoutCard(
            data: _card(WorkoutCardState.planned),
            onTap: () => tapped++,
            onSkip: () => skipped++,
          ),
        ),
      );
      await _drag(tester, find.byType(WorkoutCard), -90);
      expect(find.text('Skip'), findsOneWidget);

      // Tap the scaffold well outside the card: reveal closes, nothing emits.
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(
        find.text('Skip'),
        findsNothing,
        reason: 'an outside tap must close the reveal (W-6 is not contract)',
      );
      expect(tapped, 0, reason: 'an outside tap must not navigate');
      expect(skipped, 0, reason: 'an outside tap must not skip');

      // The reveal still opens and its button still emits after a dismissal.
      await _drag(tester, find.byType(WorkoutCard), -90);
      expect(find.text('Skip'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(skipped, 1);
    },
  );

  // band_copy_matches_register (intraday-display §2 via energy-card P-3)
  test(
    'band_copy_matches_register: band copy for the mock net (−133) is exactly "on track"',
    () {
      expect(
        IntradayDisplay.netBandCopy(netKcal: -133, energyBasis: 'as_computed'),
        'on track',
      );
      // The full register is pinned by the intraday-display vectors; this is
      // the P-3 spot-check the manifest asks for.
      final assembled = _assemble([_swimVerified(), _runPlanned()]);
      expect(assembled.energy!.bandCopy, 'on track');
    },
  );

  // sync_upgrades_confirmed_to_verified (platform-resolution two-time model)
  test(
    'sync_upgrades_confirmed_to_verified: DONE_CONFIRMED flips to verified with measured start',
    () {
      // Mark-done wrote actual_time = planned_time (Q-D7): the card sits at
      // its 5:30 PM slot, self-reported.
      final confirmed = _runPlanned().copyWith(
        status: ActivityStatus.completed,
        actualTime: _runPlanned().plannedTime,
      );
      final beforeSync = _assemble([confirmed]);
      final confirmedCard = beforeSync.nodes
          .firstWhere((n) => n.isWorkout)
          .workout!;
      expect(confirmedCard.state, WorkoutCardState.doneConfirmed);
      expect(confirmedCard.chipLabel, 'self-reported');
      expect(
        confirmedCard.timeLabel,
        '5:30 PM',
        reason: 'mark-done keeps the planned slot (Q-D7)',
      );

      // A later Garmin sync overwrites the mark-done actual_time (= planned)
      // with the measured start (MANUAL → GARMIN) and links the summary id —
      // unchanged by Q-D7 (vector two-time-sync-overwrites-mark-done).
      final synced = confirmed.copyWith(
        garminSummaryId: 'g-run-99',
        actualTime: DateTime(2026, 8, 14, 14, 42),
      );
      final afterSync = _assemble([synced]);
      final verifiedCard = afterSync.nodes
          .firstWhere((n) => n.isWorkout)
          .workout!;
      expect(verifiedCard.state, WorkoutCardState.doneVerified);
      expect(verifiedCard.chipLabel, 'verified · Garmin');
      expect(
        verifiedCard.timeLabel,
        '2:42 PM',
        reason: 'actual_time overwritten with the measured start',
      );
    },
  );

  // The §4b render rule (still ratified): a status=deleted tombstone never
  // renders and contributes zero. (The v1 manifest row
  // tombstone_prevents_reimport is RETIRED in v2 — no surface affordance
  // writes the tombstone; the matcher half stays pinned by
  // test/features/integrations/tombstone_sync_matching_test.dart.)
  test('tombstone: a status=deleted row never renders on the dashboard', () {
    final data = _assemble([
      _swimVerified().copyWith(status: ActivityStatus.deleted, deletedAt: _now),
      _runPlanned(),
    ]);
    expect(
      data.nodes.where((n) => n.isWorkout && n.workout!.name == 'Swim'),
      isEmpty,
    );
    expect(data.energy!.workoutDoneKcal, 0);
  });

  // Two-time write seam (G1/G2 data contract, pinned at the mapper level —
  // the repository methods write exactly these companions; the persisted
  // half is pinned in activities_repository_skip_test.dart).
  //
  // Mark-done writes actual_time = PLANNED_TIME (ruled by the spec owner
  // 2026-08-18; the v2 manifest's literal "= now" was written for the
  // current day and, applied to another day, moved yesterday's un-synced run
  // onto today's timeline and today's burned-so-far). The card stays on its
  // day and slot; a later Garmin sync still overwrites it with the measured
  // start (MANUAL → GARMIN).
  test(
    'g1_swipe_right_marks_done: mark-done writes actual = planned (now before AND after it, current AND past day); card keeps its slot; undone clears to null',
    () {
      final planned = _runPlanned(); // planned 5:30 PM on the mock day
      // The write (mirrors ActivitiesRepository.markWorkoutDone / the
      // controller's optimistic update — the persisted seam is pinned in
      // activities_repository_skip_test.dart): actual_time = planned_time,
      // regardless of the clock.
      final done = planned.copyWith(
        status: ActivityStatus.completed,
        actualTime: planned.plannedTime,
      );
      expect(
        done.plannedTime,
        planned.plannedTime,
        reason: 'planned_time is never modified by any gesture',
      );
      expect(done.actualTime, planned.plannedTime);
      expect(
        done.displayTime,
        planned.plannedTime,
        reason: 'the card stays at its planned slot on its own day',
      );

      // now BEFORE planned (3:00 PM), now AFTER planned (9:00 PM), and the
      // NEXT DAY (past-day confirmation): the card renders DONE_CONFIRMED at
      // 5:30 PM on the mock day every time, and its kcal count on THAT day.
      for (final now in [
        DateTime(2026, 8, 14, 15, 0),
        DateTime(2026, 8, 14, 21, 0),
        _nextMorning,
      ]) {
        final d = _assemble([_swimVerified(), done], now: now);
        final card = _workoutCardOf(d, 'Run');
        expect(card.state, WorkoutCardState.doneConfirmed, reason: 'now=$now');
        expect(
          card.timeLabel,
          '5:30 PM',
          reason: 'keeps its planned slot (now=$now)',
        );
        expect(
          d.energy!.workoutDoneKcal,
          closeTo(1538, 1),
          reason: 'counts on its own day (now=$now)',
        );
      }
      // Nothing of it lands on the following day: the day provider places a
      // card by actual ?? planned (pinned at the provider seam in
      // macro_dashboard_screen_test.dart, "confirmed on another day never
      // leaks onto this day").

      final undone = done.copyWith(
        status: ActivityStatus.planned,
        clearActualTime: true,
      );
      expect(undone.actualTime, isNull, reason: 'cleared — null, not zero');
      expect(
        undone.displayTime,
        planned.plannedTime,
        reason: 'card returns to planned_time',
      );
    },
  );

  // -------------------------------------------------------------------------
  // Weight resolution & cross-surface session pricing
  // (bugs 2026-08-20-dashboard-weight-fallback-70kg and
  //  2026-08-20-session-kcal-three-surfaces-disagree; feature-test-plan
  //  invariants I4, I6/I8 — F4 cost is exactly linear in body weight, so the
  //  property is pinned at THREE weights, never only the 75-kg reference.)
  // -------------------------------------------------------------------------
  group('session kcal weight resolution (F4 linear in weight)', () {
    DailyMacroTargets targetsWith({double? weightKg}) => DailyMacroTargets(
      id: 't1',
      userId: 'u1',
      targetDate: _day,
      carbG: 596,
      protG: 130,
      fatG: 138,
      tdee: 4152,
      rmr: 1908,
      sessionKcal: 1538,
      neatKcal: 394.9,
      mode: 'prospective',
      algorithmVersion: 'v6.0.0',
      createdAt: _day,
      updatedAt: _day,
      weightKg: weightKg,
    );

    DashboardData assembleWith({
      List<Activity>? activities,
      DailyMacroTargets? targets,
      double? profileWeightKg,
    }) => const MacroDashboardAssembler().assemble(
      selectedDate: _day,
      now: _now,
      activities: activities ?? [_runPlanned()],
      meals: const [],
      targets: targets,
      consumed: const ConsumedTotals(
        calories: 1650,
        carbsG: 262,
        proteinG: 68,
        fatG: 36,
      ),
      trackingOn: true,
      profileWeightKg: profileWeightKg,
    );

    // I8: the 90-min zone-less planned run priced at 50 / 75 / 95 kg. The
    // expected value is computed from the SAME ratified formula the engine
    // uses (DailyBaselineCalculator.sessionCost = F4), at the documented
    // the ruled zones-absent IF — so a reintroduced weight constant anywhere in
    // the display path breaks at two of the three weights.
    test('I8: card kcal is F4 at the athlete weight — 50 / 75 / 95 kg', () {
      final kcalAt = <double, double>{};
      for (final w in [50.0, 75.0, 95.0]) {
        final d = assembleWith(targets: targetsWith(weightKg: w));
        final run = _workoutCardOf(d, 'Run');
        final expected = DailyBaselineCalculator.sessionCost(
          sport: 'running',
          durationHr: 1.5,
          intensityFactor: _zonelessIf,
          weightKg: w,
        );
        expect(run.kcal, isNotNull, reason: 'weight resolved → priced');
        expect(run.kcal, closeTo(expected, 1e-9), reason: 'weight $w kg');
        kcalAt[w] = run.kcal!;
      }
      // The I6 property itself: cost is EXACTLY linear in body weight.
      expect(kcalAt[50.0]! / 50.0, closeTo(kcalAt[75.0]! / 75.0, 1e-9));
      expect(kcalAt[95.0]! / 95.0, closeTo(kcalAt[75.0]! / 75.0, 1e-9));
      // And none of the three is the old silent-70 value (1,124 kcal).
      final at70 = DailyBaselineCalculator.sessionCost(
        sport: 'running',
        durationHr: 1.5,
        intensityFactor: _zonelessIf,
        weightKg: 70,
      );
      for (final v in kcalAt.values) {
        expect(
          (v - at70).abs(),
          greaterThan(1),
          reason: 'no weight may silently price as 70 kg',
        );
      }
    });

    test('profile weight beats targets.weightKg (a Settings edit reprices '
        'the display without waiting for the recalc)', () {
      final d = assembleWith(
        targets: targetsWith(weightKg: 73.0),
        profileWeightKg: 49.9,
      );
      final expected = DailyBaselineCalculator.sessionCost(
        sport: 'running',
        durationHr: 1.5,
        intensityFactor: _zonelessIf,
        weightKg: 49.9,
      );
      expect(_workoutCardOf(d, 'Run').kcal, closeTo(expected, 1e-9));
    });

    test(
      'targets.weightKg is the fallback when no profile weight is passed',
      () {
        final d = assembleWith(targets: targetsWith(weightKg: 49.9));
        final expected = DailyBaselineCalculator.sessionCost(
          sport: 'running',
          durationHr: 1.5,
          intensityFactor: _zonelessIf,
          weightKg: 49.9,
        );
        expect(_workoutCardOf(d, 'Run').kcal, closeTo(expected, 1e-9));
      },
    );

    // I4 concrete (2026-08-20-session-kcal-three-surfaces-disagree): for a
    // seeded athlete, card kcal == Active-Energy sheet row kcal ==
    // F4(profile weight, resolved IF), with IF resolved from the planned
    // zones (ruling 2026-08-22: zones when present, else the engine's
    // 70/20/10 default through the same derivation — on
    // every surface; intraday-display §1 / F22 FORMULA rung).
    test('I4: card kcal == sheet row kcal == F4(profile weight, zones IF)', () {
      const zones = IntensityDistribution(
        conversationalPct: 60,
        tempoPct: 25,
        allOutPct: 15,
      );
      final run = _runPlanned().copyWith(
        durationMinutes: 45,
        intensityDistribution: zones,
      );
      const profileWeightKg = 49.9; // Xuan's real case: 110 lb
      final resolvedIf = DailyBaselineCalculator.zoneDistributionToIf(
        pctConversational: 0.60,
        pctTempo: 0.25,
        pctAllout: 0.15,
      );
      final f4 = DailyBaselineCalculator.sessionCost(
        sport: 'running',
        durationHr: 45 / 60.0,
        intensityFactor: resolvedIf,
        weightKg: profileWeightKg,
      );

      final d = assembleWith(
        activities: [_swimVerified(), run],
        targets: targetsWith(weightKg: 73.0),
        profileWeightKg: profileWeightKg,
      );

      final card = _workoutCardOf(d, 'Run');
      final sheetRow = d.energy!.workoutRows.singleWhere(
        (r) => r.name == 'Run',
      );

      expect(
        card.kcal,
        closeTo(f4, 1e-9),
        reason: 'card = F4(profile weight, zones IF)',
      );
      expect(
        sheetRow.kcal,
        closeTo(f4, 1e-9),
        reason: 'Active Energy sheet row = the same _sessionKcal result',
      );
      expect(
        sheetRow.kcal,
        card.kcal,
        reason:
            'I4: no surface disagrees with another on the same '
            'quantity — one function prices both',
      );
      // The measured swim rides the GARMIN rung untouched by weight.
      final swimRow = d.energy!.workoutRows.singleWhere(
        (r) => r.name == 'Swim',
      );
      expect(swimRow.kcal, 228.7);
    });

    test('BOTH weights absent → formula sessions surface as ABSENT, never '
        'a stand-in number', () {
      final d = assembleWith(
        activities: [_swimVerified(), _runPlanned()],
        targets: targetsWith(weightKg: null),
        // no profileWeightKg
      );

      // The run still renders on the timeline…
      final run = _workoutCardOf(d, 'Run');
      // …but is unpriced: no invented kcal (the old code said 70 kg here).
      expect(run.kcal, isNull);

      // It enters NO energy figure and gets NO receipt row, so the rows
      // shown still sum exactly to the totals shown (least-lying
      // representation — a 0-kcal row would be a false statement).
      expect(d.energy!.workoutPlannedKcal, 0);
      expect(d.energy!.workoutRows.map((r) => r.name), ['Swim']);

      // The measured swim is unaffected: the GARMIN rung needs no weight.
      expect(d.energy!.workoutDoneKcal, closeTo(229, 0.5));
      expect(_workoutCardOf(d, 'Swim').kcal, 228.7);
    });
  });
}

const _energyData = EnergyCardData(
  netKcal: -133,
  bandCopy: 'on track',
  eatenKcal: 1650,
  burnedKcal: 1783,
  targetKcal: 4152,
  remainingKcal: 2502,
  workoutDoneKcal: 229,
  workoutPlannedKcal: 1309,
  workoutProjectedKcal: 1538,
  workoutRows: [],
  carbTargetG: 596,
  proteinTargetG: 130,
  fatTargetG: 138,
  carbEatenG: 262,
  proteinEatenG: 68,
  fatEatenG: 36,
);
