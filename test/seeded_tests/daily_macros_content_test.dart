// Seeded CONTENT test (canonical template for the seeded widget layer).
//
// Unlike the smoke suite ("does the screen render?"), seeded tests drive a
// screen with fake state via `pumpSeeded` and assert the rendered VALUES are
// correct. Copy this shape per screen: seed the screen's AsyncNotifier/stream
// providers in `overrides`, then assert specific text/widgets.

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/daily_macros/domain/daily_macro_targets.dart';
import 'package:mealvana_endurance/features/daily_macros/presentation/providers/daily_macros_controller.dart';
import 'package:mealvana_endurance/features/daily_macros/presentation/screens/daily_macros_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';

import '../helpers/widget_test_harness.dart';

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

MealLog _sampleLog() {
  final now = DateTime.now();
  final logDate =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  return MealLog(
    id: 'log1',
    userId: 'u1',
    logDate: logDate,
    slot: MealSlot.breakfast,
    name: 'Oatmeal',
    source: MealLogSource.manual,
    components: const [],
    calories: 350,
    carbsG: 60,
    proteinG: 12,
    fatG: 6,
    createdAt: now,
    updatedAt: now,
  );
}

List<Override> _macroOverrides({List<MealLog> logs = const []}) => [
      dailyMacrosControllerProvider.overrideWith(_FakeDailyMacrosController.new),
      mealLogsForDateProvider.overrideWith((ref, date) => Stream.value(logs)),
      consumedTotalsForDateProvider.overrideWith(
        (ref, date) => Stream.value(const ConsumedTotals(
          calories: 939,
          carbsG: 106,
          proteinG: 47,
          fatG: 53,
          sodiumMg: 800,
        )),
      ),
    ];

void main() {
  testWidgets('shows the PLANNED face with correct planned calories when '
      'nothing is logged', (tester) async {
    await pumpSeeded(tester, const DailyMacrosScreen(),
        overrides: _macroOverrides());

    expect(find.text('Planned today'), findsOneWidget);
    expect(find.text('Eaten today'), findsNothing);
    // Planned calories = 305*4 + 107*4 + 98*9 = 2,530.
    expect(find.text('2,530'), findsOneWidget);
    expect(find.text('Show plan'), findsOneWidget);
  });

  testWidgets('flips to the EATEN face with consumed calories once a meal is '
      'logged', (tester) async {
    await pumpSeeded(tester, const DailyMacrosScreen(),
        overrides: _macroOverrides(logs: [_sampleLog()]));

    expect(find.text('Eaten today'), findsOneWidget);
    expect(find.text('Planned today'), findsNothing);
    expect(find.text('939'), findsOneWidget);
  });
}
