import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/daily_macro_targets.dart';
import 'package:mealvana_endurance/features/fuel_timeline/application/day_timeline_assembler.dart';
import 'package:mealvana_endurance/features/fuel_timeline/presentation/providers/fuel_timeline_controller.dart';
import 'package:mealvana_endurance/features/fuel_timeline/presentation/screens/fuel_timeline_screen.dart';
import 'package:mealvana_endurance/features/fuel_timeline/presentation/widgets/energy_breakdown_sheet.dart';
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

  DayTimelineResult fixtureResult() {
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
      createdAt: DateTime(2026, 6, 17, 7, 30),
      updatedAt: DateTime(2026, 6, 17, 7, 30),
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

  List<Override> baseOverrides() => [
    preferencesServiceProvider.overrideWithValue(prefs),
  ];

  testWidgets('renders loading state without crashing', (tester) async {
    await smokeScreen(
      tester,
      const FuelTimelineScreen(),
      overrides: baseOverrides(),
      settle: false,
    );
  });

  testWidgets('renders data state with timeline + dashboard', (tester) async {
    final result = fixtureResult();
    await smokeScreen(
      tester,
      const FuelTimelineScreen(),
      overrides: [
        ...baseOverrides(),
        fuelTimelineDayProvider.overrideWith((ref) async => result),
      ],
    );

    expect(find.text('EVERYTHING BAGEL'), findsOneWidget);
    expect(find.text('25 MI RIDE'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
  });

  testWidgets('energy breakdown sheet renders without crashing', (
    tester,
  ) async {
    await smokeScreen(
      tester,
      const EnergyBreakdownSheet(),
      overrides: baseOverrides(),
      settle: false,
    );
    expect(find.text("Today's Fueling"), findsOneWidget);
  });
}
