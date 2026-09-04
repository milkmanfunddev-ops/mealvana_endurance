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
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/presentation/providers/activities_controller.dart';
import 'package:mealvana_endurance/features/auth/application/auth_service.dart'
    show currentUserProvider;
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/calendar/presentation/providers/calendar_selected_date_provider.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/daily_macro_targets.dart';
import 'package:mealvana_endurance/features/daily_macros/presentation/providers/daily_macros_controller.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/providers/macro_dashboard_providers.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/data/meal_log_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/data/saved_meals_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart'
    hide Activity;
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/preferences_service.dart';

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
  sessionKcal: 1538,
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

class _MockUserRepository extends Mock implements UserRepository {}

/// Records delete/restore calls so the screen-wiring test can assert the
/// pills reach the controller without dragging real async into the fake zone.
class _RecordingMealLogController extends MealLogController {
  static final deleted = <String>[];
  static final restored = <String>[];

  @override
  Future<void> deleteLog(String logId) async {
    deleted.add(logId);
  }

  @override
  Future<void> restoreLog(String logId) async {
    restored.add(logId);
  }
}

UserProfile _userProfile() => UserProfile(
  id: 'u1',
  deviceId: 'd1',
  gender: Gender.male,
  birthday: DateTime(1985, 3, 20),
  heightFeet: 5,
  heightInches: 11,
  weightPounds: 165,
  runsWithWaterBottle: false,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  appVersion: '1.0.0',
);

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

List<Override> _dayOverrides({
  bool switchableMacros = false,
  Override? mealLogs,
}) => [
  userIdProvider.overrideWith((ref) async => 'u1'),
  calendarSelectedDateProvider.overrideWith(_FixedSelectedDate.new),
  activitiesControllerProvider.overrideWith(_SeededActivitiesController.new),
  dailyMacrosControllerProvider.overrideWith(
    switchableMacros
        ? _SwitchableDailyMacrosController.new
        : _SeededDailyMacrosController.new,
  ),
  mealLogs ??
      mealLogsForDateProvider.overrideWith(
        (ref, date) => Stream.value([_bagel()]),
      ),
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

  // Bug 2026-09-03: the expanded meal card's action pills were rendered with
  // null callbacks — dead to the touch. These tests pin the wiring (screen →
  // controller / editor route) and the delete path through the real notifier.

  testWidgets('Remove pill deletes via the controller and offers Undo', (
    tester,
  ) async {
    _RecordingMealLogController.deleted.clear();
    _RecordingMealLogController.restored.clear();

    await pumpSeeded(
      tester,
      const Scaffold(body: MacroDashboardScreen()),
      settle: true,
      overrides: [
        ..._dayOverrides(),
        mealLogControllerProvider.overrideWith(
          _RecordingMealLogController.new,
        ),
      ],
    );

    // Expand the card, then hit Remove.
    await tester.tap(find.byKey(const ValueKey('macro_dashboard.meal_m1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(_RecordingMealLogController.deleted, ['m1']);
    expect(find.text('Meal deleted'), findsOneWidget);

    // Undo restores through the controller.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(_RecordingMealLogController.restored, ['m1']);
  });

  // The delete/restore write path through the REAL notifier → repository →
  // Drift: the tombstone lands with needsUpload for the sync sweep, and the
  // assembler drops tombstoned rows from the surface.
  test('deleteLog tombstones through the real notifier; restoreLog undoes', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final mealRepo = MealLogRepository(
      supabase: fakeSupabaseClient(),
      database: db,
      logger: MockAppLogger(),
      sentry: mockSentryReporter(),
    );
    await mealRepo.insertLog(_bagel());

    final userRepo = _MockUserRepository();
    when(
      () => userRepo.getCurrentUser(),
    ).thenAnswer((_) async => _userProfile());

    final container = ProviderContainer(
      overrides: [
        mockAppExternalDeps(),
        userRepositoryProvider.overrideWith((_) async => userRepo),
        mealLogRepositoryProvider.overrideWithValue(mealRepo),
        // The controller's guard eagerly builds the logging service, whose
        // saved-meals repo reads Supabase.instance — keep it off the network.
        savedMealsRepositoryProvider.overrideWith(
          (ref) => SavedMealsRepository(
            supabase: fakeSupabaseClient(),
            database: db,
            logger: MockAppLogger(),
            sentry: mockSentryReporter(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Keep the auto-dispose controller alive across the awaits.
    container.listen(mealLogControllerProvider, (_, __) {});

    await container
        .read(mealLogControllerProvider.notifier)
        .deleteLog('m1');
    expect(container.read(mealLogControllerProvider), isA<AsyncData<void>>());

    final row = await (db.select(
      db.mealLogsTable,
    )..where((t) => t.id.equals('m1'))).getSingle();
    expect(row.isDeleted, isTrue);
    expect(row.needsUpload, isTrue, reason: 'the tombstone must sync up');

    await container
        .read(mealLogControllerProvider.notifier)
        .restoreLog('m1');
    final restored = await (db.select(
      db.mealLogsTable,
    )..where((t) => t.id.equals('m1'))).getSingle();
    expect(restored.isDeleted, isFalse);
    expect(restored.needsUpload, isTrue);
  });

  testWidgets('Edit food opens the meal-log editor carrying the tapped log', (
    tester,
  ) async {
    Object? pushedExtra;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: MacroDashboardScreen()),
        ),
        GoRoute(
          path: '/meal-log/edit',
          builder: (_, state) {
            pushedExtra = state.extra;
            return const Scaffold(body: Text('EDITOR'));
          },
        ),
      ],
    );

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockAppExternalDeps(),
          appConfigProvider.overrideWithValue(AppConfig.forTesting()),
          inMemoryDatabaseOverride(db),
          preferencesServiceProvider.overrideWith(
            (ref) => PreferencesService(prefs),
          ),
          currentUserProvider.overrideWith((ref) async => null),
          ..._dayOverrides(),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (_, __) => MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('macro_dashboard.meal_m1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit food'));
    await tester.pumpAndSettle();

    expect(find.text('EDITOR'), findsOneWidget);
    final extra = pushedExtra! as Map<String, dynamic>;
    expect((extra['log'] as MealLog?)?.id, 'm1');
  });
}
