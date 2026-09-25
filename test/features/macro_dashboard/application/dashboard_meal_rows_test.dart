import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/daily_macro_targets.dart';
import 'package:mealvana_endurance/features/macro_dashboard/application/dashboard_assembler.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';

/// Today's Fuel "Where it came from" names each meal by its name (testing-wave
/// ticket 80, finding 27-006). Two snacks at 2:08 and 2:09 could only be told
/// apart by their numbers while the row showed the slot's label instead. The
/// slot's label is the fallback for a meal with no name.
void main() {
  const assembler = MacroDashboardAssembler();
  final day = DateTime(2026, 9, 24);

  MealLog meal(String id, String name, MealSlot? slot, int minute) => MealLog(
    id: id,
    userId: 'u1',
    logDate: '2026-09-24',
    slot: slot,
    name: name,
    source: MealLogSource.manual,
    components: const [],
    calories: 100,
    eatenAt: DateTime(2026, 9, 24, 14, minute),
    createdAt: DateTime(2026, 9, 24, 14, minute),
    updatedAt: DateTime(2026, 9, 24, 14, minute),
  );

  final targets = DailyMacroTargets(
    id: 't1',
    userId: 'u1',
    targetDate: day,
    carbG: 447,
    protG: 85,
    fatG: 101,
    tdee: 3037,
    rmr: 1064,
    sessionKcal: 1290,
    neatKcal: 275,
    tefKcal: 304,
    mode: 'prospective',
    createdAt: day,
    updatedAt: day,
  );

  List<String> rowNames(List<MealLog> meals) => assembler
      .assemble(
        selectedDate: day,
        now: DateTime(2026, 9, 24, 16),
        activities: const [],
        meals: meals,
        targets: targets,
        consumed: const ConsumedTotals(),
        trackingOn: true,
      )
      .breakdown!
      .mealRows
      .map((r) => r.name)
      .toList();

  test('a meal with a slot is still named by its name', () {
    expect(
      rowNames([
        meal('a', 'Rice cake', MealSlot.snack, 8),
        meal('b', 'Cottage cheese', MealSlot.snack, 9),
        meal('c', 'Chicken wrap', MealSlot.lunch, 20),
      ]),
      ['Rice cake', 'Cottage cheese', 'Chicken wrap'],
    );
  });

  test('a meal with no name falls back to its slot, then to nothing', () {
    expect(rowNames([meal('a', '', MealSlot.lunch, 8)]), ['Lunch']);
    expect(rowNames([meal('b', '   ', MealSlot.snack, 9)]), ['Snack']);
    expect(rowNames([meal('c', '', null, 10)]), ['']);
  });
}
