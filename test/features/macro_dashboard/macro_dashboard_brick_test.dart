// Brick-workout grouping on the MACRO DASHBOARD — the regression guard the
// last two surface migrations lacked (the brick flow was lost in
// Activities → Fuel Timeline (bug 3a6e3fdb) and again in Fuel Timeline →
// Macro Dashboard (adeb1e38), each time because nothing on the shipping
// surface asserted it).
//
// The pinned contract is the Fuel Timeline design carried over verbatim
// (Notion 3a7e3fdb) — a CANDIDATE awaiting ratification, not a ratified
// component. When the brick surface/component spec lands in
// docs/ssot/spec/design/, re-anchor these tests to its rows.
//
// - The Brick entry is a third pill in the ADD ROW (after a divider, with a
//   chain icon). It appears when 2+ brick-eligible workouts of different
//   sports exist on the selected day — adjacency NOT required, legs in pick
//   order (Lee, 2026-08-26).
// - Tapping it swaps the add row for "Pick legs to link … Cancel".
// - A created brick renders as a TimelineBrickTile — one time-dot on the rail
//   with its legs in an indented bracket.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/domain/brick_metadata.dart';
import 'package:mealvana_endurance/features/activities/presentation/providers/activities_controller.dart';
import 'package:mealvana_endurance/features/calendar/presentation/providers/calendar_selected_date_provider.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/daily_macro_targets.dart';
import 'package:mealvana_endurance/features/daily_macros/presentation/providers/daily_macros_controller.dart';
import 'package:mealvana_endurance/features/fuel_timeline/presentation/widgets/timeline_brick_tile.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/providers/macro_dashboard_providers.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';

import '../../helpers/widget_test_harness.dart';

final _day = DateTime(2026, 8, 14);

Activity _activity(
  String id,
  ActivityType type,
  int hour, {
  BrickMetadata? brickMetadata,
}) {
  return Activity(
    id: id,
    userId: 'u1',
    activityType: type,
    title: '$id workout',
    scheduledDateTime: DateTime(_day.year, _day.month, _day.day, hour),
    plannedTime: DateTime(_day.year, _day.month, _day.day, hour),
    durationMinutes: 60,
    brickMetadata: brickMetadata,
    createdAt: _day,
    updatedAt: _day,
  );
}

DailyMacroTargets _targets() => DailyMacroTargets(
  id: 't1',
  userId: 'u1',
  targetDate: _day,
  carbG: 300,
  protG: 140,
  fatG: 75,
  tdee: 1911,
  rmr: 1091,
  sessionKcal: 502,
  neatKcal: 300,
  mode: 'prospective',
  createdAt: _day,
  updatedAt: _day,
  weightKg: 75,
);

class _FixedSelectedDate extends CalendarSelectedDate {
  @override
  DateTime build() => _day;
}

class _SeededActivitiesController extends ActivitiesController {
  static List<Activity> seed = const [];

  @override
  FutureOr<List<Activity>> build() => seed;
}

class _SeededDailyMacrosController extends DailyMacrosController {
  @override
  Future<DailyMacrosState> build() async => DailyMacrosState(
    selectedDate: _day,
    dailyMacros: _targets(),
    weeklyMacros: List<DailyMacroTargets?>.filled(7, _targets()),
  );
}

List<Override> _overrides() => [
  userIdProvider.overrideWith((ref) async => 'u1'),
  calendarSelectedDateProvider.overrideWith(_FixedSelectedDate.new),
  activitiesControllerProvider.overrideWith(_SeededActivitiesController.new),
  dailyMacrosControllerProvider.overrideWith(_SeededDailyMacrosController.new),
  mealLogsForDateProvider.overrideWith(
    (ref, date) => Stream.value(const <MealLog>[]),
  ),
  consumedTotalsForDateProvider.overrideWith(
    (ref, date) => Stream.value(const ConsumedTotals()),
  ),
];

Future<void> _pump(WidgetTester tester, List<Activity> activities) async {
  _SeededActivitiesController.seed = activities;
  await pumpSeeded(
    tester,
    const Scaffold(body: MacroDashboardScreen()),
    overrides: _overrides(),
    settle: true,
  );
}

void main() {
  setUp(HeldTargets.clear);

  final brickPill = find.byKey(const ValueKey('macro_dashboard.create_brick'));
  final cancel = find.byKey(const ValueKey('macro_dashboard.brick_cancel'));

  testWidgets(
    'two adjacent activities of different sports show the Brick pill',
    (tester) async {
      await _pump(tester, [
        _activity('run1', ActivityType.running, 8),
        _activity('ride1', ActivityType.cycling, 16),
      ]);
      expect(brickPill, findsOneWidget);
    },
  );

  testWidgets('two same-day activities of the SAME sport show no pill', (
    tester,
  ) async {
    await _pump(tester, [
      _activity('run1', ActivityType.running, 8),
      _activity('run2', ActivityType.running, 16),
    ]);
    expect(brickPill, findsNothing);
  });

  testWidgets(
    'non-adjacent eligible workouts (strength between) still show the pill',
    (tester) async {
      await _pump(tester, [
        _activity('run1', ActivityType.running, 7),
        _activity('gym', ActivityType.other, 12),
        _activity('ride1', ActivityType.cycling, 18),
      ]);
      expect(brickPill, findsOneWidget);
    },
  );

  testWidgets('legs are numbered in PICK order, not dashboard order', (
    tester,
  ) async {
    // Taller viewport: in the default 800×600 the docked LEG ORDER panel
    // covers the second card, so the tap never reaches it. Width stays 800
    // (the Ahem test font is wide; a phone width overflows unrelated rows).
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, [
      _activity('run1', ActivityType.running, 8),
      _activity('ride1', ActivityType.cycling, 16),
    ]);
    await tester.tap(brickPill);
    await tester.pumpAndSettle();
    // Pick the later (ride) first, then the earlier (run). The test viewport
    // is short, so scroll each card clear of the docked panel before tapping.
    // Pick the later (ride) first, then the earlier (run).
    for (final id in ['ride1', 'run1']) {
      await tester.tap(find.byKey(ValueKey('macro_dashboard.brick_pick_$id')));
      await tester.pumpAndSettle();
    }

    // LEG ORDER panel: ① RIDE → ② RUN.
    final ride = tester.getCenter(find.text('RIDE'));
    final run = tester.getCenter(find.text('RUN'));
    expect(ride.dx, lessThan(run.dx));
    expect(
      find.byKey(const ValueKey('macro_dashboard.brick_create')),
      findsOneWidget,
    );
  });

  testWidgets('a single activity shows no pill', (tester) async {
    await _pump(tester, [_activity('run1', ActivityType.running, 8)]);
    expect(brickPill, findsNothing);
  });

  testWidgets('tapping Brick enters leg-picking: pick bar replaces the adds', (
    tester,
  ) async {
    await _pump(tester, [
      _activity('run1', ActivityType.running, 8),
      _activity('ride1', ActivityType.cycling, 16),
    ]);
    await tester.tap(brickPill);
    await tester.pumpAndSettle();

    expect(cancel, findsOneWidget);
    expect(brickPill, findsNothing);
    expect(
      find.byKey(const ValueKey('macro_dashboard.brick_pick_run1')),
      findsOneWidget,
    );

    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(cancel, findsNothing);
    expect(brickPill, findsOneWidget);
  });

  testWidgets('a created brick renders as a TimelineBrickTile', (tester) async {
    const metadata = BrickMetadata(
      segmentOrder: ['cycling', 'running'],
      segments: [
        BrickSegment(
          sport: 'cycling',
          order: 1,
          durationMinutes: 60,
          intensity: 'moderate',
        ),
        BrickSegment(
          sport: 'running',
          order: 2,
          durationMinutes: 30,
          intensity: 'moderate',
        ),
      ],
      originalActivityIds: ['ride1', 'run1'],
      createdFromExisting: true,
      totalDurationMinutes: 90,
    );
    await _pump(tester, [
      _activity('brick1', ActivityType.brick, 8, brickMetadata: metadata),
    ]);

    expect(find.byType(TimelineBrickTile), findsOneWidget);
    // An existing brick is not itself groupable: no pill.
    expect(brickPill, findsNothing);
  });
}
