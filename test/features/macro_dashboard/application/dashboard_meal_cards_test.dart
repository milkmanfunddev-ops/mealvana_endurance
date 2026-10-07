import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/macro_dashboard/application/dashboard_assembler.dart';
import 'package:mealvana_endurance/features/macro_dashboard/domain/dashboard_models.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';

/// Timeline meal cards follow the clock (testing-wave ticket 59, finding
/// 27-001). A meal sits under its own eaten time; two meals of one type share
/// a card only when the later one was eaten within 30 minutes of the card's
/// first meal. Cards stay in time order, and a delete never swaps two cards.
///
/// Meals are fed the way the dashboard receives them: local wall-clock times
/// (Drift returns local DateTimes) in `watchLogsForDate` order, eaten_at
/// descending. That order is what made the two 2:08 PM cards swap after a
/// delete: the card listed first was whichever slot held the newest meal.
void main() {
  const assembler = MacroDashboardAssembler();
  final day = DateTime(2026, 9, 24);

  MealLog meal(String id, MealSlot? slot, int hour, int minute) => MealLog(
    id: id,
    userId: 'u1',
    logDate: '2026-09-24',
    slot: slot,
    name: id,
    source: MealLogSource.manual,
    components: const [],
    calories: 100,
    eatenAt: DateTime(2026, 9, 24, hour, minute),
    createdAt: DateTime(2026, 9, 24, hour, minute),
    updatedAt: DateTime(2026, 9, 24, hour, minute),
  );

  /// The repository's order: newest eaten first.
  List<MealLog> repoOrder(List<MealLog> meals) =>
      [...meals]..sort((a, b) => b.eatenAt!.compareTo(a.eatenAt!));

  List<DashboardNode> cards(List<MealLog> meals) => assembler
      .assemble(
        selectedDate: day,
        now: DateTime(2026, 9, 24, 16),
        activities: const [],
        meals: repoOrder(meals),
        targets: null,
        consumed: const ConsumedTotals(),
        trackingOn: true,
      )
      .nodes;

  List<String> describe(List<DashboardNode> nodes) => [
    for (final n in nodes)
      '${n.timeLabel} ${n.mealGroupLabel}: ${n.meals.map((m) => m.id).join(', ')}',
  ];

  test('a 3:43 PM snack after a 2:08 PM snack gets its own 3:43 PM card', () {
    final nodes = cards([
      meal('rice-cake', MealSlot.snack, 14, 8),
      meal('late-snack', MealSlot.snack, 15, 43),
    ]);

    expect(describe(nodes), [
      '2:08 PM Snack: rice-cake',
      '3:43 PM Snack: late-snack',
    ]);
  });

  test('a 2:20 PM snack joins the 2:08 PM card', () {
    final nodes = cards([
      meal('rice-cake', MealSlot.snack, 14, 8),
      meal('cottage-cheese', MealSlot.snack, 14, 20),
    ]);

    expect(describe(nodes), ['2:08 PM Snack: rice-cake, cottage-cheese']);
  });

  test('a snack exactly 30 minutes after the card opened still joins it', () {
    final nodes = cards([
      meal('rice-cake', MealSlot.snack, 14, 8),
      meal('bar', MealSlot.snack, 14, 38),
    ]);

    expect(describe(nodes), ['2:08 PM Snack: rice-cake, bar']);
  });

  test('the window counts from the card\'s first meal, not its last', () {
    // 2:08 -> 2:30 joins (22 min); 2:45 is 37 min after 2:08, so a new card
    // even though it is only 15 min after 2:30.
    final nodes = cards([
      meal('a', MealSlot.snack, 14, 8),
      meal('b', MealSlot.snack, 14, 30),
      meal('c', MealSlot.snack, 14, 45),
    ]);

    expect(describe(nodes), ['2:08 PM Snack: a, b', '2:45 PM Snack: c']);
  });

  test('untagged meals follow the same 30-minute rule', () {
    final nodes = cards([
      meal('x', null, 9, 0),
      meal('y', null, 9, 10),
      meal('z', null, 11, 0),
    ]);

    expect(describe(nodes), ['9:00 AM Logged: x, y', '11:00 AM Logged: z']);
  });

  group('finding 112-011: "Any time" meals never sit out of clock order', () {
    // The wave-34 day: seven "Any time" meals from 6:24 to 6:30, a Lunch at
    // 6:25 and a Breakfast at 6:26. Grouping by slot filed the 6:30 soup
    // under 6:24, above meals eaten at 6:25 and 6:26.
    final day1824 = [
      meal('oatmeal', null, 18, 24),
      meal('bowl', null, 18, 24),
      meal('w13-23-lunch', MealSlot.lunch, 18, 25),
      meal('banana', null, 18, 26),
      meal('scramble', MealSlot.breakfast, 18, 26),
      meal('egg', null, 18, 27),
      meal('eggs', null, 18, 28),
      meal('chews', null, 18, 29),
      meal('soup', null, 18, 30),
    ];

    test('a card closes when another card opens inside its window', () {
      expect(describe(cards(day1824)), [
        '6:24 PM Logged: bowl, oatmeal',
        '6:25 PM Lunch: w13-23-lunch',
        '6:26 PM Breakfast: scramble',
        '6:26 PM Logged: banana, egg, eggs, chews, soup',
      ]);
    });

    test('no card ever holds a meal eaten after a later card opened', () {
      final nodes = cards(day1824);
      for (var i = 0; i + 1 < nodes.length; i++) {
        final nextOpen = nodes[i + 1].meals.first.id;
        final nextTime = day1824.firstWhere((m) => m.id == nextOpen).eatenAt!;
        for (final m in nodes[i].meals) {
          final t = day1824.firstWhere((x) => x.id == m.id).eatenAt!;
          expect(
            t.isAfter(nextTime),
            isFalse,
            reason: '${m.id} ($t) sits above a card opened at $nextTime',
          );
        }
      }
    });
  });

  group(
    'finding 27-001 day: cards in time order before and after a delete',
    () {
      final day2708 = [
        meal('w13-23-lunch', MealSlot.lunch, 14, 8),
        meal('rice-cake', MealSlot.snack, 14, 8),
        meal('cottage-cheese', MealSlot.snack, 14, 9),
        meal('w-317', MealSlot.dinner, 15, 17),
        meal('w-319', MealSlot.breakfast, 15, 19),
        meal('w15-27-edit', MealSlot.lunch, 15, 43),
        meal('w15-27-delete', MealSlot.snack, 15, 43),
      ];

      const before = [
        '2:08 PM Lunch: w13-23-lunch',
        '2:08 PM Snack: rice-cake, cottage-cheese',
        '3:17 PM Dinner: w-317',
        '3:19 PM Breakfast: w-319',
        '3:43 PM Lunch: w15-27-edit',
        '3:43 PM Snack: w15-27-delete',
      ];

      test('before the delete each meal sits under its own time', () {
        expect(describe(cards(day2708)), before);
      });

      test('after the delete the two 2:08 PM cards keep their order', () {
        final after = day2708
            .where((m) => m.id != 'w15-27-delete')
            .toList(growable: false);

        expect(describe(cards(after)), [
          for (final line in before)
            if (!line.contains('w15-27-delete')) line,
        ]);
      });

      test('card order never depends on the order meals arrive in', () {
        final forward = cards(day2708);
        final reversed = assembler
            .assemble(
              selectedDate: day,
              now: DateTime(2026, 9, 24, 16),
              activities: const [],
              meals: day2708.reversed.toList(),
              targets: null,
              consumed: const ConsumedTotals(),
              trackingOn: true,
            )
            .nodes;

        expect(describe(reversed), describe(forward));
      });
    },
  );
}
