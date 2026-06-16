// Layout + re-integration test for the Nutrition Diary (Daily Macros) screen.
//
// Pumps the real DailyMacrosScreen with fake targets + consumed totals and
// asserts:
//   • it lays out without exceptions, and
//   • the re-integrated meal-planning surface is present: the planned-vs-eaten
//     comparison table, the Jade coach banner, and the Today's Log section.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/auth/application/auth_service.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/daily_macro_targets.dart';
import 'package:mealvana_endurance/features/daily_macros/presentation/providers/daily_macros_controller.dart';
import 'package:mealvana_endurance/features/daily_macros/presentation/screens/daily_macros_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/shared/services/preferences_service.dart';

class _FakeDailyMacrosController extends DailyMacrosController {
  @override
  Future<DailyMacrosState> build() async {
    final now = DateTime.now();
    final targets = DailyMacroTargets(
      id: 'test',
      userId: 'u1',
      targetDate: now,
      carbG: 305,
      protG: 107,
      fatG: 98,
      tdee: 2530,
      rmr: 1600,
      sessionKcal: 400,
      mode: 'standard',
      algorithmVersion: 'v1',
      createdAt: now,
      updatedAt: now,
    );
    return DailyMacrosState(
      selectedDate: now,
      dailyMacros: targets,
      weeklyMacros: List<DailyMacroTargets?>.filled(7, targets),
    );
  }
}

Future<void> _pumpScreen(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dailyMacrosControllerProvider
            .overrideWith(_FakeDailyMacrosController.new),
        mealLogsForDateProvider
            .overrideWith((ref, date) => Stream.value(const <MealLog>[])),
        consumedTotalsForDateProvider.overrideWith(
          (ref, date) => Stream.value(const ConsumedTotals(
            calories: 939,
            carbsG: 106,
            proteinG: 47,
            fatG: 53,
            sodiumMg: 800,
          )),
        ),
        preferencesServiceProvider
            .overrideWith((ref) => PreferencesService(prefs)),
        currentUserProvider.overrideWith((ref) async => null),
      ],
      child: const MaterialApp(home: DailyMacrosScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('DailyMacrosScreen lays out without exceptions',
      (tester) async {
    await _pumpScreen(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the planned-vs-eaten comparison rows', (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Planned'), findsOneWidget);
    expect(find.text('Eaten'), findsOneWidget);
    expect(find.text('Left'), findsOneWidget);
    expect(find.byKey(const ValueKey('nutrition_diary.daily_total_card')),
        findsOneWidget);
  });

  testWidgets('re-integrates the Jade banner and Today\'s Log section',
      (tester) async {
    await _pumpScreen(tester);

    expect(find.byKey(const ValueKey('jade.coach_banner')), findsOneWidget);
    expect(find.text("Today's Log"), findsOneWidget);
  });
}
