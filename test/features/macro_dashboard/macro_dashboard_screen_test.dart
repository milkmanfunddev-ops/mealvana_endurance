// Screen-level test for MacroDashboardScreen: pumps the REAL screen with the
// real macroDashboardDay provider + assembler + view notifier, overriding only
// the data sources it composes (calendar date, activities controller, meal
// logs, consumed totals, daily macros controller, preferences via the shared
// harness) with the canonical mock day.
//
// Exact energy figures are clock-dependent at this level (the provider passes
// DateTime.now() into the assembler), so the canonical numbers stay pinned by
// test/features/macro_dashboard/macro_dashboard_gestures_test.dart; THIS suite
// pins the screen wiring — assembly through providers, filter lens, tracking
// and timeline toggles, and expansion behavior — on stable, clock-safe
// assertions.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/presentation/providers/activities_controller.dart';
import 'package:mealvana_endurance/features/calendar/presentation/providers/calendar_selected_date_provider.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/daily_macro_targets.dart';
import 'package:mealvana_endurance/features/daily_macros/presentation/providers/daily_macros_controller.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/providers/macro_dashboard_providers.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';

import '../../helpers/widget_test_harness.dart';

// ---------------------------------------------------------------------------
// Canonical mock day (goldens manifest): verified 8:00 swim, planned 5:30 run,
// breakfast bagel, eaten 1,650, targets 4,152. The date is fixed in the past,
// so the planned run deterministically lands in the passive SKIPPED state.
// ---------------------------------------------------------------------------

final _day = DateTime(2026, 8, 14);

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

MealLog _bagel() => MealLog(
  id: 'm1',
  userId: 'u1',
  logDate: '2026-08-14',
  slot: MealSlot.breakfast,
  name: 'Everything Bagel',
  source: MealLogSource.manual,
  components: const [],
  calories: 574,
  carbsG: 58,
  proteinG: 30,
  fatG: 25,
  eatenAt: DateTime(2026, 8, 14, 7, 30),
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

const _consumed = ConsumedTotals(
  calories: 1650,
  carbsG: 262,
  proteinG: 68,
  fatG: 36,
);

class _FixedSelectedDate extends CalendarSelectedDate {
  @override
  DateTime build() => _day;
}

/// A run planned — and confirmed done — the day BEFORE the mock day, with
/// actual_time = planned_time (the mark-done write). It must render on ITS
/// day, never leak onto the selected one.
Activity _yesterdayRunDone() => Activity(
  id: 'w0',
  userId: 'u1',
  activityType: ActivityType.running,
  title: 'Yesterday run',
  scheduledDateTime: DateTime(2026, 8, 13, 7, 0),
  plannedTime: DateTime(2026, 8, 13, 7, 0),
  actualTime: DateTime(2026, 8, 13, 7, 0),
  status: ActivityStatus.completed,
  durationMinutes: 60,
  createdAt: _day,
  updatedAt: _day,
);

class _SeededActivitiesController extends ActivitiesController {
  @override
  FutureOr<List<Activity>> build() => [
    _yesterdayRunDone(),
    _swimVerified(),
    _runPlanned(),
  ];
}

class _SeededDailyMacrosController extends DailyMacrosController {
  @override
  Future<DailyMacrosState> build() async => DailyMacrosState(
    selectedDate: _day,
    dailyMacros: _targets(),
    weeklyMacros: List<DailyMacroTargets?>.filled(7, _targets()),
  );
}

/// A daily-macros controller the test can flip into "recomputing" (targets
/// null, isCalculating true) — what the real controller reports while an
/// invalidated day is being rebuilt by the edge function.
class _SwitchableDailyMacrosController extends DailyMacrosController {
  static bool recomputing = false;

  @override
  Future<DailyMacrosState> build() async => recomputing
      ? DailyMacrosState(
          selectedDate: _day,
          dailyMacros: null,
          weeklyMacros: List<DailyMacroTargets?>.filled(7, null),
          isCalculating: true,
        )
      : DailyMacrosState(
          selectedDate: _day,
          dailyMacros: _targets(),
          weeklyMacros: List<DailyMacroTargets?>.filled(7, _targets()),
        );
}

List<Override> _dayOverrides({bool switchableMacros = false}) => [
  userIdProvider.overrideWith((ref) async => 'u1'),
  calendarSelectedDateProvider.overrideWith(_FixedSelectedDate.new),
  activitiesControllerProvider.overrideWith(_SeededActivitiesController.new),
  dailyMacrosControllerProvider.overrideWith(
    switchableMacros
        ? _SwitchableDailyMacrosController.new
        : _SeededDailyMacrosController.new,
  ),
  mealLogsForDateProvider.overrideWith((ref, date) => Stream.value([_bagel()])),
  consumedTotalsForDateProvider.overrideWith(
    (ref, date) => Stream.value(_consumed),
  ),
];

Future<void> _pumpDashboard(
  WidgetTester tester, {
  bool switchableMacros = false,
}) async {
  await pumpSeeded(
    tester,
    const Scaffold(body: MacroDashboardScreen()),
    overrides: _dayOverrides(switchableMacros: switchableMacros),
    settle: true,
  );
}

void main() {
  setUp(HeldTargets.clear);

  // S-1 "same pump" across a targets recompute: when a skip / unskip /
  // profile edit invalidates the day's cached targets, the daily-macros
  // controller reports (null, isCalculating) until the engine answers. The
  // surface must keep showing the last targets it rendered for this
  // user+day rather than blank the energy card for the round trip.
  testWidgets('energy card holds through a targets recompute (no blink)', (
    tester,
  ) async {
    _SwitchableDailyMacrosController.recomputing = false;
    await _pumpDashboard(tester, switchableMacros: true);
    expect(
      find.byKey(const ValueKey('macro_dashboard.energy_card')),
      findsOneWidget,
    );

    // The recompute begins: targets vanish upstream…
    _SwitchableDailyMacrosController.recomputing = true;
    final el = tester.element(find.byType(MacroDashboardScreen));
    ProviderScope.containerOf(
      el,
      listen: false,
    ).invalidate(dailyMacrosControllerProvider);
    await tester.pumpAndSettle();

    // …but the surface holds the last-known targets, energy card intact.
    expect(
      find.byKey(const ValueKey('macro_dashboard.energy_card')),
      findsOneWidget,
      reason: 'the energy card must not blink out during a recompute',
    );

    // A genuine no-targets state (not recomputing) still renders no card.
    HeldTargets.clear();
    ProviderScope.containerOf(
      el,
      listen: false,
    ).invalidate(dailyMacrosControllerProvider);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('macro_dashboard.energy_card')),
      findsNothing,
      reason: 'nothing held for this user+day → no card, honestly',
    );
    _SwitchableDailyMacrosController.recomputing = false;
  });

  // The day view places a card on the day of actual_time ?? planned_time.
  // Mark-done writes actual_time = planned_time (ruled 2026-08-18), so a
  // workout confirmed on another day stays there — this pins that a done
  // card from the day before does NOT appear on, or count toward, the
  // selected day (the gap behind the 2026-08-18 "it disappeared" report:
  // with actual_time = now, a future/past card jumped to today).
  testWidgets('a workout confirmed on another day never leaks onto this day', (
    tester,
  ) async {
    await _pumpDashboard(tester);
    expect(
      find.byKey(const ValueKey('macro_dashboard.workout_w0')),
      findsNothing,
    );
    expect(find.text('Yesterday run'), findsNothing);
    // Only the mock day's two workouts feed the surface.
    expect(
      find.byKey(const ValueKey('macro_dashboard.workout_w1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('macro_dashboard.workout_w2')),
      findsOneWidget,
    );
  });

  testWidgets('assembles the canonical mock day through the real providers', (
    tester,
  ) async {
    await _pumpDashboard(tester);

    // Energy card (All face collapsed) + both workout cards + the meal card.
    expect(
      find.byKey(const ValueKey('macro_dashboard.energy_card')),
      findsOneWidget,
    );
    expect(find.text('NET BALANCE'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('macro_dashboard.workout_w1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('macro_dashboard.workout_w2')),
      findsOneWidget,
    );
    expect(find.text('Swim'), findsOneWidget);
    expect(find.text('Run'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('macro_dashboard.meal_m1')),
      findsOneWidget,
    );
    expect(find.text('Everything Bagel'), findsOneWidget);

    // The Garmin-completed swim wears the verified chip (Q-D1's subject).
    expect(find.text('verified · Garmin'), findsOneWidget);

    // Fixed past day → the un-synced planned run is PASSIVELY skipped
    // (Q-D6): "Skipped" chip, no timestamp on its rail row (S-7 tuck), and
    // the rejected v1 prompt copy must not exist anywhere.
    expect(find.text('Skipped'), findsOneWidget);
    expect(
      find.text('5:30 PM'),
      findsNothing,
      reason: 'a skipped card renders with no timestamp',
    );
    expect(find.textContaining('Did this happen?'), findsNothing);

    // Add row shows both pills on the All lens; rail times are visible.
    expect(
      find.byKey(const ValueKey('macro_dashboard.add_food')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('macro_dashboard.add_activity')),
      findsOneWidget,
    );
    expect(find.text('8:00 AM'), findsOneWidget);
  });

  testWidgets('filter pills drive the lens: cards and add row follow', (
    tester,
  ) async {
    await _pumpDashboard(tester);

    await tester.tap(
      find.byKey(const ValueKey('macro_dashboard.filter_workout')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Everything Bagel'), findsNothing);
    expect(find.text('Swim'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('macro_dashboard.add_food')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('macro_dashboard.add_activity')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('macro_dashboard.filter_meals')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Everything Bagel'), findsOneWidget);
    expect(find.text('Swim'), findsNothing);
    expect(find.text('Run'), findsNothing);
    expect(
      find.byKey(const ValueKey('macro_dashboard.add_food')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('macro_dashboard.add_activity')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('macro_dashboard.filter_all')));
    await tester.pumpAndSettle();
    expect(find.text('Everything Bagel'), findsOneWidget);
    expect(find.text('Swim'), findsOneWidget);
  });

  // Bug report 2026-08-20-dashboard-papercuts, item 3 (a11y): the dashed
  // add pills reported as static text (AXStaticText) to assistive tech —
  // they must expose button semantics with a tap action.
  testWidgets('add pills expose button semantics, not static text', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpDashboard(tester);

    for (final key in const [
      ValueKey('macro_dashboard.add_food'),
      ValueKey('macro_dashboard.add_activity'),
    ]) {
      expect(
        tester.getSemantics(find.byKey(key)),
        isSemantics(isButton: true, hasTapAction: true),
        reason: '$key must read as a button to assistive tech',
      );
    }
    handle.dispose();
  });

  testWidgets('tracking toggle hides the energy card and meal macros (§5)', (
    tester,
  ) async {
    await _pumpDashboard(tester);
    expect(
      find.byKey(const ValueKey('macro_dashboard.energy_card')),
      findsOneWidget,
    );
    expect(find.textContaining('574', findRichText: true), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('macro_dashboard.tracking_toggle')),
    );
    await tester.pumpAndSettle();

    // Every derived quantity leaves the surface; the log itself stays.
    expect(
      find.byKey(const ValueKey('macro_dashboard.energy_card')),
      findsNothing,
    );
    expect(find.textContaining('574', findRichText: true), findsNothing);
    expect(find.text('Everything Bagel'), findsOneWidget);
    expect(find.text('Swim'), findsOneWidget);
  });

  testWidgets('timeline toggle hides the rail time labels', (tester) async {
    await _pumpDashboard(tester);
    expect(find.text('8:00 AM'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('macro_dashboard.timeline_toggle')),
    );
    await tester.pumpAndSettle();
    expect(find.text('8:00 AM'), findsNothing);

    // Cards are unaffected — the rail is presentation only.
    expect(find.text('Swim'), findsOneWidget);
    expect(find.text('Everything Bagel'), findsOneWidget);
  });

  testWidgets(
    'energy expansion happens in place and survives a face switch (E1/P-1)',
    (tester) async {
      await _pumpDashboard(tester);
      expect(find.text('NET ENERGY BALANCE'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('macro_dashboard.energy_expand')),
      );
      await tester.pumpAndSettle();
      expect(find.text('NET ENERGY BALANCE'), findsOneWidget);

      // Face switch keeps the expansion (view-state owns it, not the card).
      await tester.tap(
        find.byKey(const ValueKey('macro_dashboard.filter_workout')),
      );
      await tester.pumpAndSettle();
      expect(find.text('ACTIVE ENERGY'), findsOneWidget);
    },
  );
}
