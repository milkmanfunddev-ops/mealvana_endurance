// Regression test for the pinned macro-strip SliverGeometry assert: pumps the
// real DailyMacrosScreen with fake data — the pinned header child must fill
// its fixed extent or layoutExtent exceeds paintExtent (see docs/logs.txt).
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

void main() {
  testWidgets('DailyMacrosScreen lays out without sliver geometry errors',
      (tester) async {
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

    expect(tester.takeException(), isNull);
  });
}
