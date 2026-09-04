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
    bool? isFirstPicker,
    VoidCallback? onBrowse,
  }) async {
    final chips = PickerChips(
      covered: covered,
      of: of,
      nextType: nextType,
      hasMeals: hasMeals,
      enabled: enabled,
      onPick: picked.add,
      onSomethingElse: () {},
      onBrowse: onBrowse,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentServiceProvider.overrideWith(testContentService)],
        child: MaterialApp(
          home: Scaffold(
            body: isFirstPicker == null
                ? chips
                : VanaPickerScope(isFirstPicker: isFirstPicker, child: chips),
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

  testWidgets('filter chips appear once the plan has a meal', (tester) async {
    await pumpChips(tester, covered: 1, of: 14, hasMeals: true);
    expect(find.text('No recipe only'), findsOneWidget);
    expect(find.text('Different protein'), findsOneWidget);
    expect(find.text('Under 20 min'), findsOneWidget);
  });

  testWidgets('tapping a chip reports its label', (tester) async {
    final picked = <String>[];
    await pumpChips(tester, covered: 1, of: 14, hasMeals: true, picked: picked);
    await tester.tap(find.text('Other options'));
    expect(picked, ['Other options']);
  });

  testWidgets('disabled strip still allows "Something else…"', (tester) async {
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

  group('"Draft my whole week" (plan Phase 2.3)', () {
    testWidgets('leads the first picker while the draft is empty', (
      tester,
    ) async {
      final picked = <String>[];
      await pumpChips(
        tester,
        covered: 0,
        of: 14,
        hasMeals: false,
        picked: picked,
        isFirstPicker: true,
      );
      expect(find.text('Draft my whole week'), findsOneWidget);
      // It is the leading chip.
      final draftX = tester.getTopLeft(find.text('Draft my whole week')).dx;
      final likeX = tester.getTopLeft(find.text('I like these')).dx;
      expect(draftX, lessThan(likeX));

      await tester.tap(find.text('Draft my whole week'));
      expect(picked, ['Draft my whole week']);
    });

    testWidgets('absent once the plan has a meal', (tester) async {
      await pumpChips(
        tester,
        covered: 1,
        of: 14,
        hasMeals: true,
        isFirstPicker: true,
      );
      expect(find.text('Draft my whole week'), findsNothing);
    });

    testWidgets('absent on later pickers even with an empty draft', (
      tester,
    ) async {
      await pumpChips(
        tester,
        covered: 0,
        of: 14,
        hasMeals: false,
        isFirstPicker: false,
      );
      expect(find.text('Draft my whole week'), findsNothing);
      expect(find.text('I like these'), findsOneWidget);
    });

    testWidgets('no scope reads as the first picker', (tester) async {
      await pumpChips(tester, covered: 0, of: 14, hasMeals: false);
      expect(find.text('Draft my whole week'), findsOneWidget);
    });
  });

  group('"Browse meals" (2026-09-03)', () {
    testWidgets('sits after "Something else…" and opens the browser', (
      tester,
    ) async {
      var opened = 0;
      await pumpChips(
        tester,
        covered: 1,
        of: 14,
        hasMeals: true,
        onBrowse: () => opened++,
      );
      expect(find.text('Browse meals'), findsOneWidget);
      // After "Something else…" in reading order: a later row, or the
      // same row further right (the Wrap may break between them).
      final elseAt = tester.getTopLeft(find.text('Something else…'));
      final browseAt = tester.getTopLeft(find.text('Browse meals'));
      expect(
        browseAt.dy > elseAt.dy ||
            (browseAt.dy == elseAt.dy && browseAt.dx > elseAt.dx),
        isTrue,
      );

      await tester.tap(find.text('Browse meals'));
      expect(opened, 1);
    });

    testWidgets('stays live once the strip is spent', (tester) async {
      var opened = 0;
      await pumpChips(
        tester,
        covered: 1,
        of: 14,
        hasMeals: true,
        enabled: false,
        onBrowse: () => opened++,
      );
      await tester.tap(find.text('Browse meals'));
      expect(opened, 1);
    });

    testWidgets('disabled while the conversation has no id', (tester) async {
      await pumpChips(tester, covered: 0, of: 14, hasMeals: false);
      expect(find.text('Browse meals'), findsOneWidget);
      // No gesture behind it — tapping does nothing and does not throw.
      await tester.tap(find.text('Browse meals'), warnIfMissed: false);
    });
  });
}
