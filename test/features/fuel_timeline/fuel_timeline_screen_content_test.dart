import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/daily_macro_targets.dart';
import 'package:mealvana_endurance/features/fuel_timeline/application/day_timeline_assembler.dart';
import 'package:mealvana_endurance/features/fuel_timeline/presentation/providers/fuel_timeline_controller.dart';
import 'package:mealvana_endurance/features/fuel_timeline/presentation/screens/fuel_timeline_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/preferences_service.dart';

import '../../helpers/widget_test_harness.dart';

void main() {
  late PreferencesService prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = PreferencesService(await SharedPreferences.getInstance());
  });

  DayTimelineResult result() {
    final date = DateTime(2026, 6, 17);
    final meal = MealLog(
      id: 'm1',
      userId: 'u',
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
      userId: 'u',
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
      id: 't',
      userId: 'u',
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

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final overrides = <Override>[
      mockAppExternalDeps(),
      preferencesServiceProvider.overrideWithValue(prefs),
      fuelTimelineDayProvider.overrideWith((ref) async => result()),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(home: FuelTimelineScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('switching to Meals shows macro budget + hides the ride', (
    tester,
  ) async {
    await pumpScreen(tester);

    // Default All filter: ride visible, Intake/Burned dashboard.
    expect(find.text('25 MI RIDE'), findsOneWidget);
    expect(find.text('INTAKE'), findsOneWidget);

    await tester.tap(find.text('Meals'));
    await tester.pumpAndSettle();

    expect(find.text('DAILY BUDGET'), findsOneWidget);
    expect(find.text('25 MI RIDE'), findsNothing); // ride filtered out
    expect(find.text('+ Add Activity'), findsNothing); // gated by filter
  });

  testWidgets('switching to Workout shows Active Energy + hides meals', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Workout'));
    await tester.pumpAndSettle();

    expect(find.text("TODAY'S WORKOUT"), findsOneWidget);
    expect(find.text('EVERYTHING BAGEL'), findsNothing);
    expect(find.text('+ Add Food'), findsNothing);
  });

  testWidgets('tracking toggle hides the dashboard and macro line', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('INTAKE'), findsOneWidget);
    expect(find.textContaining('574 kcal'), findsOneWidget);

    // The tracking toggle is the heart icon in the filter row.
    await tester.tap(find.byIcon(Icons.show_chart));
    await tester.pumpAndSettle();

    expect(find.text('INTAKE'), findsNothing); // dashboard hidden
    expect(
      find.textContaining('574 kcal'),
      findsNothing,
    ); // macro line stripped
    expect(find.text('EVERYTHING BAGEL'), findsOneWidget); // meal still shown
  });

  testWidgets('timeline toggle hides the time-rail labels', (tester) async {
    await pumpScreen(tester);
    expect(find.text('7:30 AM'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.schedule));
    await tester.pumpAndSettle();

    expect(find.text('7:30 AM'), findsNothing);
  });
}
