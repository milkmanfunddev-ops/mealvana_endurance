// Unified card interaction (391e3fdb): the meal log row has no overflow
// menu, tap anywhere opens edit, and swiping in EITHER direction deletes.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/saved_meal.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/widgets/meal_log_row.dart';

void main() {
  final now = DateTime(2026, 6, 13);

  MealLog log() => MealLog(
        id: 'log-1',
        userId: 'u1',
        logDate: '2026-06-13',
        slot: MealSlot.lunch,
        name: 'Chicken rice bowl',
        source: MealLogSource.manual,
        components: const [],
        calories: 640,
        carbsG: 72,
        proteinG: 45,
        fatG: 18,
        createdAt: now,
        updatedAt: now,
      );

  Widget host({
    VoidCallback? onDelete,
    VoidCallback? onEdit,
  }) =>
      ProviderScope(
        overrides: [
          // Keep the favorite lookup off the real DB stack.
          savedMealsProvider.overrideWith(
            (ref) => Stream.value(const <SavedMeal>[]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MealLogRow(
              log: log(),
              onDelete: onDelete ?? () {},
              onEdit: onEdit ?? () {},
            ),
          ),
        ),
      );

  testWidgets('renders no ellipsis/overflow menu — star stays as the only '
      'trailing affordance', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.byType(PopupMenuButton), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    // One-tap favorite star still present.
    expect(find.byIcon(Icons.star_border), findsOneWidget);
  });

  testWidgets('tap anywhere on the row fires onEdit', (tester) async {
    var edited = false;
    await tester.pumpWidget(host(onEdit: () => edited = true));
    await tester.pump();

    await tester.tap(find.text('Chicken rice bowl'));
    expect(edited, isTrue);
  });

  for (final (label, offset) in [
    ('right→left', const Offset(-400.0, 0.0)),
    ('left→right', const Offset(400.0, 0.0)),
  ]) {
    testWidgets('swipe $label fires onDelete', (tester) async {
      var deleted = false;
      await tester.pumpWidget(host(onDelete: () => deleted = true));
      await tester.pump();

      await tester.drag(find.byType(Dismissible), offset);
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
      // confirmDismiss returns false → the row is still in the tree; removal
      // happens via the provider rebuild in the parent list.
      expect(find.text('Chicken rice bowl'), findsOneWidget);
    });
  }
}
