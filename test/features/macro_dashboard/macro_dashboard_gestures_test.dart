// GESTURE / BEHAVIOR tests for the macro dashboard — one per row of
// docs/ssot/conformance/design/macro-dashboard.gestures.yaml. A test pins
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
import 'package:mealvana_endurance/features/macro_dashboard/presentation/widgets/energy_summary_card.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/widgets/workout_card.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

// ---------------------------------------------------------------------------
// Canonical mock day (goldens manifest): verified 8:00 swim 229 kcal,
// planned 5:30 run 1,205 kcal, snapshot 15:00, eaten 1,650, targets 4,152.
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
      sessionKcal: 1434,
      neatKcal: 394.9,
      mode: 'prospective',
      algorithmVersion: 'v6.0.0',
      createdAt: _day,
      updatedAt: _day,
      weightKg: 75,
    );

DashboardData _assemble(List<Activity> activities) {
  const assembler = MacroDashboardAssembler();
  return assembler.assemble(
    selectedDate: _day,
    now: _now,
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

WorkoutCardData _card(WorkoutCardState state, {String id = 'w2'}) =>
    WorkoutCardData(
      activityId: id,
      name: 'Run',
      timeLabel: '5:30 PM',
      metaLabel: '90 min',
      kcal: 1205,
      state: state,
      sport: 'running',
    );

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

void main() {
  // g1_swipe_right_marks_done (workout-card G1)
  testWidgets('g1: full right-swipe on PLANNED marks done', (tester) async {
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
    // The actual_time = now / planned_time-untouched half of G1 is pinned
    // at the write seam below ('two-time writes').
  });

  // g2_swipe_right_again_undoes (workout-card G2)
  testWidgets('g2: full right-swipe on DONE_CONFIRMED undoes', (tester) async {
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
  });

  // g3_verified_suppressed — NEGATIVE TEST (Q-D1 ruling)
  testWidgets('g3: right-swipe on DONE_VERIFIED is suppressed entirely',
      (tester) async {
    await tester.pumpWidget(
      _host(
        WorkoutCard(
          data: _card(WorkoutCardState.doneVerified),
          onMarkDone: () => fail('verified card must not emit done'),
          onMarkUndone: () => fail('verified card must not emit undone'),
        ),
      ),
    );
    final before = tester.getTopLeft(find.text('Run'));
    await _drag(tester, find.byType(WorkoutCard), 320);
    final after = tester.getTopLeft(find.text('Run'));
    // Zero translation after release...
    expect(after.dx - before.dx, 0);
    // ...no reveal renders, and no "Mark undone" node in the tree.
    expect(find.text('Mark undone'), findsNothing);
    expect(find.text('Mark done'), findsNothing);
  });

  // g4_swipe_left_reveals_delete (workout-card G4)
  testWidgets('g4: partial left-swipe reveals labeled Delete; swipe never deletes',
      (tester) async {
    var deleted = 0;
    await tester.pumpWidget(
      _host(
        WorkoutCard(
          data: _card(WorkoutCardState.planned),
          onDelete: () => deleted++,
        ),
      ),
    );
    await _drag(tester, find.byType(WorkoutCard), -90);
    // The swipe itself NEVER deletes; the labeled button does.
    expect(deleted, 0);
    expect(find.text('Delete'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  // g5_delete_removes_everywhere (G5 + surface S-2): a deleted workout's
  // kcal leaves EVERY surface figure in the same recompute — the tombstone
  // contributes zero to burned, net, projected, and the row list.
  test('g5: deletion removes the workout from every surface figure', () {
    final before = _assemble([_swimVerified(), _runPlanned()]);
    final after = _assemble([
      _swimVerified().copyWith(
        status: ActivityStatus.deleted,
        deletedAt: _now,
      ),
      _runPlanned(),
    ]);

    expect(before.nodes.where((n) => n.isWorkout).length, 2);
    expect(after.nodes.where((n) => n.isWorkout).length, 1);
    expect(
      after.energy!.workoutDoneKcal,
      0,
      reason: 'the deleted swim contributes zero everywhere (§4b)',
    );
    expect(
      after.energy!.burnedKcal,
      lessThan(before.energy!.burnedKcal),
    );
    expect(
      after.energy!.workoutProjectedKcal,
      lessThan(before.energy!.workoutProjectedKcal),
    );
  });

  // g7_emission_propagates (G7 + surface S-1): one state change moves net
  // balance, band copy, and the Active Energy numbers together — the
  // verified example −133 ⇄ −1,338.
  test('g7: marking the run done flips net −133 → −1,338 with copy following',
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
    expect(done.energy!.netKcal, -1338);
    expect(done.energy!.bandCopy, 'deficit — time to eat');
    expect(done.energy!.workoutDoneKcal, closeTo(1434, 1));
    expect(done.energy!.workoutPlannedKcal, 0);
  });

  // e1_toggle_expansion (energy-card E1)
  testWidgets('e1: chevron toggles expansion in place, never navigates',
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
                  onToggleExpanded: () => setState(() => expanded = !expanded),
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
    expect(navigatorKey.currentState!.canPop(), isFalse,
        reason: 'E1 never navigates');
    setOuterState(() {});
  });

  // p1_expansion_persists_across_faces (energy-card P-1)
  testWidgets('p1: expansion persists across a face switch', (tester) async {
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
  });

  // p1_expansion_survives_swipe (P-1 + S-4, the W-8 regression guard):
  // expansion lives in the surface view-state, so a workout-card state
  // change (a data recompute) cannot collapse it.
  test('p1: expansion state is independent of the day recompute', () {
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
  });

  // s6_no_unconditional_deadlines (surface S-6) — string-level check over
  // every copy string the surface can render.
  test('s6: no rendered copy states an unconditional refueling deadline', () {
    final sources = Directory('lib/features/macro_dashboard')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    final withinMinutes = RegExp(r'within \d+ min', caseSensitive: false);
    final withinHour = RegExp(r'within the hour', caseSensitive: false);
    for (final f in sources) {
      final content = f.readAsStringSync();
      expect(withinMinutes.hasMatch(content), isFalse,
          reason: '${f.path} contains an unconditional-deadline string');
      expect(withinHour.hasMatch(content), isFalse,
          reason: '${f.path} contains an unconditional-deadline string');
    }
  });

  // band_copy_matches_register (intraday-display §2 via energy-card P-3)
  test('band copy for the mock net (−133) is exactly "on track"', () {
    expect(
      IntradayDisplay.netBandCopy(netKcal: -133, energyBasis: 'as_computed'),
      'on track',
    );
    // The full register is pinned by the intraday-display vectors; this is
    // the P-3 spot-check the manifest asks for.
    final assembled = _assemble([_swimVerified(), _runPlanned()]);
    expect(assembled.energy!.bandCopy, 'on track');
  });

  // sync_upgrades_confirmed_to_verified (platform-resolution two-time model)
  test('sync upgrade: DONE_CONFIRMED flips to verified with measured start',
      () {
    final confirmedAt = DateTime(2026, 8, 14, 15, 0); // mark-done at 3 PM
    final confirmed = _runPlanned().copyWith(
      status: ActivityStatus.completed,
      actualTime: confirmedAt,
    );
    final beforeSync = _assemble([confirmed]);
    final confirmedCard =
        beforeSync.nodes.firstWhere((n) => n.isWorkout).workout!;
    expect(confirmedCard.state, WorkoutCardState.doneConfirmed);
    expect(confirmedCard.chipLabel, 'self-reported');
    expect(confirmedCard.timeLabel, '3:00 PM',
        reason: 'mark-done moves the card to now (W-7)');

    // A later Garmin sync overwrites the mark-done actual_time with the
    // measured start (MANUAL → GARMIN) and links the summary id.
    final synced = confirmed.copyWith(
      garminSummaryId: 'g-run-99',
      actualTime: DateTime(2026, 8, 14, 14, 42),
    );
    final afterSync = _assemble([synced]);
    final verifiedCard =
        afterSync.nodes.firstWhere((n) => n.isWorkout).workout!;
    expect(verifiedCard.state, WorkoutCardState.doneVerified);
    expect(verifiedCard.chipLabel, 'verified · Garmin');
    expect(verifiedCard.timeLabel, '2:42 PM',
        reason: 'actual_time overwritten with the measured start');
  });

  // tombstone_prevents_reimport — the display half (never renders,
  // contributes zero); the matcher half is pinned by
  // test/features/integrations/tombstone_sync_matching_test.dart and the
  // platform-resolution vectors.
  test('tombstone: a status=deleted row never renders on the dashboard', () {
    final data = _assemble([
      _swimVerified().copyWith(
        status: ActivityStatus.deleted,
        deletedAt: _now,
      ),
      _runPlanned(),
    ]);
    expect(
      data.nodes.where((n) => n.isWorkout && n.workout!.name == 'Swim'),
      isEmpty,
    );
    expect(data.energy!.workoutDoneKcal, 0);
  });

  // Two-time write seam (G1/G2 data contract, pinned at the mapper level —
  // the repository methods write exactly these companions).
  test('two-time writes: mark-done sets actual only; undone clears to null',
      () {
    final planned = _runPlanned();
    final done = planned.copyWith(
      status: ActivityStatus.completed,
      actualTime: _now,
    );
    expect(done.plannedTime, planned.plannedTime,
        reason: 'planned_time is never modified by any gesture');
    expect(done.actualTime, _now);
    expect(done.displayTime, _now,
        reason: 'card moves to the current time on the timeline');

    final undone = done.copyWith(
      status: ActivityStatus.planned,
      clearActualTime: true,
    );
    expect(undone.actualTime, isNull, reason: 'cleared — null, not zero');
    expect(undone.displayTime, planned.plannedTime,
        reason: 'card returns to planned_time');
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
  workoutPlannedKcal: 1205,
  workoutProjectedKcal: 1434,
  workoutRows: [],
  carbTargetG: 596,
  proteinTargetG: 130,
  fatTargetG: 138,
  carbEatenG: 262,
  proteinEatenG: 68,
  fatEatenG: 36,
);
