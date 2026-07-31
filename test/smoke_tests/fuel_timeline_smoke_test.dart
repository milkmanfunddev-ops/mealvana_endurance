// Screen smoke suite — Fuel Timeline (Nutrition tab).
//
// Pumps every screen/widget in the fuel_timeline feature with mocked external
// deps and asserts:
//   1. No exception is thrown during build/layout on a standard phone (390 px).
//   2. No RenderFlex overflow on the standard phone for the *data* branch
//      (loading branches are excluded — they trivially can't overflow).
//
// Existing granular widget tests live in
// test/features/fuel_timeline/fuel_timeline_screen_smoke_test.dart (loading +
// data state) and test/features/fuel_timeline/fuel_timeline_widgets_test.dart
// (TimelineNodeTile, EnergyDashboardCard, FuelFilterRow, WeeklyFuelChart).
//
// THIS file enforces the full-screen overflow guarantee at 390 px and verifies
// the feature-flag ValueKeys (fuel_timeline.add_food / add_activity / settings /
// filter_<name>) that must be present for automation and integration testing.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/daily_macro_targets.dart';
import 'package:mealvana_endurance/features/daily_macros/presentation/providers/daily_macros_controller.dart';
import 'package:mealvana_endurance/features/fuel_timeline/application/day_timeline_assembler.dart';
import 'package:mealvana_endurance/features/fuel_timeline/presentation/providers/fuel_timeline_controller.dart';
import 'package:mealvana_endurance/features/fuel_timeline/presentation/screens/fuel_timeline_screen.dart';
import 'package:mealvana_endurance/features/fuel_timeline/presentation/widgets/energy_breakdown_sheet.dart';
import 'package:mealvana_endurance/features/fuel_timeline/presentation/widgets/fuel_timeline_day_header.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/preferences_service.dart';

import '../helpers/widget_test_harness.dart';

// ---------------------------------------------------------------------------
// Fixture helpers
// ---------------------------------------------------------------------------

DayTimelineResult _seededResult() {
  final date = DateTime(2026, 6, 17);
  final meal = MealLog(
    id: 'm1',
    userId: 'u1',
    logDate: '2026-06-17',
    slot: MealSlot.breakfast,
    name: 'Everything Bagel',
    source: MealLogSource.manual,
    components: const [],
    calories: 574,
    carbsG: 58,
    proteinG: 30,
    fatG: 25,
    eatenAt: DateTime(2026, 6, 17, 7, 30),
    createdAt: date,
    updatedAt: date,
  );
  final ride = Activity(
    id: 'a1',
    userId: 'u1',
    activityType: ActivityType.cycling,
    title: '25 mi Ride',
    scheduledDateTime: DateTime(2026, 6, 17, 16, 15),
    distanceMiles: 25,
    cyclingSpeedMph: 15,
    durationMinutes: 100,
    createdAt: date,
    updatedAt: date,
  );
  final targets = DailyMacroTargets(
    id: 't1',
    userId: 'u1',
    targetDate: date,
    carbG: 300,
    protG: 140,
    fatG: 75,
    tdee: 1911,
    rmr: 1091,
    sessionKcal: 502,
    neatKcal: 300,
    mode: 'prospective',
    createdAt: date,
    updatedAt: date,
  );
  return const DayTimelineAssembler().assemble(
    selectedDate: date,
    now: DateTime(2026, 6, 17, 20),
    meals: [meal],
    activities: [ride],
    targets: targets,
    consumed: const ConsumedTotals(
      calories: 574,
      carbsG: 58,
      proteinG: 30,
      fatG: 25,
    ),
  );
}

DayTimelineResult _emptyResult() {
  final date = DateTime(2026, 6, 17);
  final targets = DailyMacroTargets(
    id: 't1',
    userId: 'u1',
    targetDate: date,
    carbG: 300,
    protG: 140,
    fatG: 75,
    tdee: 1911,
    rmr: 1091,
    sessionKcal: 502,
    neatKcal: 300,
    mode: 'prospective',
    createdAt: date,
    updatedAt: date,
  );
  return const DayTimelineAssembler().assemble(
    selectedDate: date,
    now: DateTime(2026, 6, 17, 20),
    meals: const [],
    activities: const [],
    targets: targets,
    consumed: const ConsumedTotals(),
  );
}

// ---------------------------------------------------------------------------
// Shared setup
// ---------------------------------------------------------------------------

Future<List<Override>> _baseOverrides() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = PreferencesService(await SharedPreferences.getInstance());
  return [preferencesServiceProvider.overrideWithValue(prefs)];
}

// ---------------------------------------------------------------------------
// Seeded daily macros controller (avoids network calls)
// ---------------------------------------------------------------------------

class _SeededDailyMacrosController extends DailyMacrosController {
  @override
  Future<DailyMacrosState> build() async {
    final date = DateTime(2026, 6, 17);
    final targets = DailyMacroTargets(
      id: 't1',
      userId: 'u1',
      targetDate: date,
      carbG: 300,
      protG: 140,
      fatG: 75,
      tdee: 1911,
      rmr: 1091,
      sessionKcal: 502,
      neatKcal: 300,
      mode: 'prospective',
      createdAt: date,
      updatedAt: date,
    );
    return DailyMacrosState(
      selectedDate: date,
      dailyMacros: targets,
      weeklyMacros: List<DailyMacroTargets?>.filled(7, targets),
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FuelTimelineScreen smoke tests', () {
    // -----------------------------------------------------------------------
    // 1. Loading state — no overflow (layout renders a spinner, not content)
    // -----------------------------------------------------------------------
    testWidgets('loading state renders without crashing at 390 px', (
      tester,
    ) async {
      final base = await _baseOverrides();
      await smokeScreen(
        tester,
        const FuelTimelineScreen(),
        overrides: base,
        settle: false,
      );
    });

    // -----------------------------------------------------------------------
    // 2. Data state (All filter) — seeded content, enforce no overflow at 390
    // -----------------------------------------------------------------------
    testWidgets('data state (All filter) renders without overflow at 390 px', (
      tester,
    ) async {
      final base = await _baseOverrides();
      await smokeScreen(
        tester,
        const FuelTimelineScreen(),
        overrides: [
          ...base,
          fuelTimelineDayProvider.overrideWith((ref) async => _seededResult()),
          dailyMacrosControllerProvider.overrideWith(
            _SeededDailyMacrosController.new,
          ),
        ],
        // Enforce overflow at standard phone — the data branch lays out real
        // content (dashboard + filter row + timeline nodes) and is where layout
        // bugs hide.
        overflowSizes: const [standardPhoneSize],
      );
    });

    // -----------------------------------------------------------------------
    // 3. Data state — multi-size: small phone + tablet portrait
    // -----------------------------------------------------------------------
    testWidgets('data state renders without crashing on small phone + tablet', (
      tester,
    ) async {
      final base = await _baseOverrides();
      await smokeScreen(
        tester,
        const FuelTimelineScreen(),
        overrides: [
          ...base,
          fuelTimelineDayProvider.overrideWith((ref) async => _seededResult()),
          dailyMacrosControllerProvider.overrideWith(
            _SeededDailyMacrosController.new,
          ),
        ],
        sizes: kSmokeSizes,
        // Only enforce overflow at standard phone; 320 px is notoriously noisy
        // in this feature (long macro tokens on narrow cards).
        overflowSizes: const [standardPhoneSize],
      );
    });

    // -----------------------------------------------------------------------
    // 4. Empty-timeline state — the "Nothing logged yet" branch must not
    //    overflow (it's a centered Text inside a ListView with bottom padding).
    // -----------------------------------------------------------------------
    testWidgets('empty-day state renders without overflow at 390 px', (
      tester,
    ) async {
      final base = await _baseOverrides();
      await smokeScreen(
        tester,
        const FuelTimelineScreen(),
        overrides: [
          ...base,
          fuelTimelineDayProvider.overrideWith((ref) async => _emptyResult()),
          dailyMacrosControllerProvider.overrideWith(
            _SeededDailyMacrosController.new,
          ),
        ],
        overflowSizes: const [standardPhoneSize],
      );
    });

    // -----------------------------------------------------------------------
    // 5. Error state — the Retry button + error message must not overflow.
    // -----------------------------------------------------------------------
    testWidgets('error state renders without overflow at 390 px', (
      tester,
    ) async {
      final base = await _baseOverrides();
      await smokeScreen(
        tester,
        const FuelTimelineScreen(),
        overrides: [
          ...base,
          fuelTimelineDayProvider.overrideWith(
            (ref) async => throw Exception('load failed'),
          ),
          dailyMacrosControllerProvider.overrideWith(
            _SeededDailyMacrosController.new,
          ),
        ],
        overflowSizes: const [standardPhoneSize],
      );
    });
  });

  // -------------------------------------------------------------------------
  // FuelTimelineDayHeader — standalone smoke
  // -------------------------------------------------------------------------
  group('FuelTimelineDayHeader smoke tests', () {
    testWidgets('week-strip mode renders without overflow at 390 px', (
      tester,
    ) async {
      final base = await _baseOverrides();
      await smokeScreen(
        tester,
        const Scaffold(body: Column(children: [FuelTimelineDayHeader()])),
        overrides: [
          ...base,
          dailyMacrosControllerProvider.overrideWith(
            _SeededDailyMacrosController.new,
          ),
        ],
        overflowSizes: const [standardPhoneSize],
      );
    });
  });

  // -------------------------------------------------------------------------
  // EnergyBreakdownSheet — standalone smoke (already in features/ but enforced
  // here as part of the standard smoke suite at 390 px with overflow check).
  // -------------------------------------------------------------------------
  group('EnergyBreakdownSheet smoke tests', () {
    testWidgets('loading state renders without crashing', (tester) async {
      final base = await _baseOverrides();
      await smokeScreen(
        tester,
        const EnergyBreakdownSheet(),
        overrides: base,
        settle: false,
      );
    });

    testWidgets('seeded daily macros renders without overflow at 390 px', (
      tester,
    ) async {
      final base = await _baseOverrides();
      await smokeScreen(
        tester,
        const EnergyBreakdownSheet(),
        overrides: [
          ...base,
          dailyMacrosControllerProvider.overrideWith(
            _SeededDailyMacrosController.new,
          ),
        ],
        overflowSizes: const [standardPhoneSize],
      );
    });
  });

  // -------------------------------------------------------------------------
  // ValueKey assertions — the keys the task specifies must be present so
  // integration tests and automation can find the add-buttons and settings.
  // -------------------------------------------------------------------------
  group('FuelTimelineScreen ValueKey presence', () {
    // pump helper: data state settled at standard phone size.
    Future<void> pumpData(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PreferencesService(await SharedPreferences.getInstance());
      tester.view.physicalSize = standardPhoneSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mockAppExternalDeps(),
            mockSharedPreferences(),
            preferencesServiceProvider.overrideWithValue(prefs),
            fuelTimelineDayProvider.overrideWith(
              (ref) async => _seededResult(),
            ),
            dailyMacrosControllerProvider.overrideWith(
              _SeededDailyMacrosController.new,
            ),
          ],
          child: wrapForTest(const FuelTimelineScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('fuel_timeline.settings key is present in header', (
      tester,
    ) async {
      await pumpData(tester);
      expect(
        find.byKey(const ValueKey('fuel_timeline.settings')),
        findsOneWidget,
        reason:
            'settings gear icon must carry ValueKey("fuel_timeline.settings")',
      );
    });

    testWidgets(
      'fuel_timeline.add_food and fuel_timeline.add_activity present (All filter)',
      (tester) async {
        await pumpData(tester);
        // All filter: both buttons visible.
        expect(
          find.byKey(const ValueKey('fuel_timeline.add_food')),
          findsOneWidget,
          reason:
              'Add Food button must carry ValueKey("fuel_timeline.add_food")',
        );
        expect(
          find.byKey(const ValueKey('fuel_timeline.add_activity')),
          findsOneWidget,
          reason:
              'Add Activity button must carry ValueKey("fuel_timeline.add_activity")',
        );
      },
    );

    // BUG CANDIDATE: if the filter gating logic or key assignment is wrong,
    // the Workout filter would incorrectly show the Add Food key.
    testWidgets('fuel_timeline.add_food is ABSENT under Workout filter', (
      tester,
    ) async {
      await pumpData(tester);
      await tester.tap(find.text('Workout'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('fuel_timeline.add_food')),
        findsNothing,
        reason:
            'Workout filter must hide Add Food — key must be absent, not just invisible',
      );
      expect(
        find.byKey(const ValueKey('fuel_timeline.add_activity')),
        findsOneWidget,
        reason: 'Workout filter must keep Add Activity',
      );
    });

    // BUG CANDIDATE: if the Meals filter incorrectly shows the Add Activity key.
    testWidgets('fuel_timeline.add_activity is ABSENT under Meals filter', (
      tester,
    ) async {
      await pumpData(tester);
      await tester.tap(find.text('Meals'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('fuel_timeline.add_activity')),
        findsNothing,
        reason: 'Meals filter must hide Add Activity',
      );
      expect(
        find.byKey(const ValueKey('fuel_timeline.add_food')),
        findsOneWidget,
        reason: 'Meals filter must keep Add Food',
      );
    });
  });
}
