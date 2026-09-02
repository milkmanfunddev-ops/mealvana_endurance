import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_type.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/picker_chips.dart';

import 'package:mealvana_endurance/features/content/application/content_service.dart';
import '../helpers/test_content.dart';

/// 02 §6 — the client-drawn chip strip: primary label follows coverage,
/// filter chips appear once the plan has a meal, chips disable after a pick
/// except `Something else…`.
void main() {
  Future<void> pumpChips(
    WidgetTester tester, {
    required int covered,
    required int of,
    MealType? nextType,
    required bool hasMeals,
    bool enabled = true,
    List<String> picked = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentServiceProvider.overrideWith(testContentService)],
        child: MaterialApp(
          home: Scaffold(
            body: PickerChips(
              covered: covered,
              of: of,
              nextType: nextType,
              hasMeals: hasMeals,
              enabled: enabled,
              onPick: picked.add,
              onSomethingElse: () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets("primary chip is \"That's my week\" when coverage is complete", (
    tester,
  ) async {
    await pumpChips(tester, covered: 14, of: 14, hasMeals: true);
    expect(find.text("That's my week"), findsOneWidget);
    expect(find.text('I like these'), findsNothing);
  });

  testWidgets('primary chip is "Next: Dinner" for the next slot', (
    tester,
  ) async {
    await pumpChips(
      tester,
      covered: 3,
      of: 14,
      nextType: MealType.dinner,
      hasMeals: true,
    );
    expect(find.text('Next: Dinner'), findsOneWidget);
  });

  testWidgets('primary chip falls back to "I like these"', (tester) async {
    await pumpChips(tester, covered: 0, of: 14, hasMeals: false);
    expect(find.text('I like these'), findsOneWidget);
    // No meals picked yet → filter chips hidden.
    expect(find.text('No recipe only'), findsNothing);
  });

  testWidgets('filter chips appear once the plan has a meal', (
    tester,
  ) async {
    await pumpChips(tester, covered: 1, of: 14, hasMeals: true);
    expect(find.text('No recipe only'), findsOneWidget);
    expect(find.text('Different protein'), findsOneWidget);
    expect(find.text('Under 20 min'), findsOneWidget);
  });

  testWidgets('tapping a chip reports its label', (tester) async {
    final picked = <String>[];
    await pumpChips(
      tester,
      covered: 1,
      of: 14,
      hasMeals: true,
      picked: picked,
    );
    await tester.tap(find.text('Other options'));
    expect(picked, ['Other options']);
  });

  testWidgets('disabled strip still allows "Something else…"', (
    tester,
  ) async {
    final picked = <String>[];
    var somethingElse = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentServiceProvider.overrideWith(testContentService)],
        child: MaterialApp(
          home: Scaffold(
            body: PickerChips(
              covered: 1,
              of: 14,
              hasMeals: true,
              enabled: false,
              onPick: picked.add,
              onSomethingElse: () => somethingElse++,
            ),
          ),
        ),
      ),
    );
    // The primary chip is present but disabled (opacity wrap, no gesture).
    await tester.tap(find.text('I like these'), warnIfMissed: false);
    await tester.tap(find.text('Something else…'), warnIfMissed: false);
    expect(picked, isEmpty);
    expect(somethingElse, 1);
  });
}
