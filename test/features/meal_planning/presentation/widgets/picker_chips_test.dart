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
    VoidCallback? onShowMore,
    List<String> suggested = const [],
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
      onShowMore: onShowMore,
      suggested: suggested,
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
    await tester.ensureVisible(find.text('Something else…'));
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

      await tester.ensureVisible(find.text('Browse meals'));
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
      await tester.ensureVisible(find.text('Browse meals'));
      await tester.tap(find.text('Browse meals'));
      expect(opened, 1);
    });

    testWidgets('disabled while the conversation has no id', (tester) async {
      await pumpChips(tester, covered: 0, of: 14, hasMeals: false);
      expect(find.text('Browse meals'), findsOneWidget);
      // No gesture behind it — tapping does nothing and does not throw.
      await tester.ensureVisible(find.text('Browse meals'));
      await tester.tap(find.text('Browse meals'), warnIfMissed: false);
    });
  });

  /// mp-272 — the turn may name the chips it expects next; the app still
  /// draws them, and its own doors out of the picker stay put.
  group('a turn names its chips (mp-272, ticket 31)', () {
    testWidgets('the named labels stand in for the app set', (tester) async {
      final picked = <String>[];
      await pumpChips(
        tester,
        covered: 3,
        of: 14,
        nextType: MealType.dinner,
        hasMeals: true,
        picked: picked,
        suggested: const ['Salmon instead', 'Keep it quick'],
      );

      expect(find.text('Salmon instead'), findsOneWidget);
      expect(find.text('Keep it quick'), findsOneWidget);
      expect(find.text('Next: Dinner'), findsNothing);
      expect(find.text('Other options'), findsNothing);
      // Only the replies are replaced; the filters stay (mp-230 clause 4).
      expect(find.text('No recipe only'), findsOneWidget);
      // The doors stay.
      expect(find.text('Something else…'), findsOneWidget);
      expect(find.text('Browse meals'), findsOneWidget);

      await tester.tap(find.text('Salmon instead'));
      expect(picked, ['Salmon instead']);
    });

    testWidgets('a named chip is spent with the rest of the strip', (
      tester,
    ) async {
      final picked = <String>[];
      await pumpChips(
        tester,
        covered: 0,
        of: 14,
        hasMeals: false,
        enabled: false,
        picked: picked,
        suggested: const ['Salmon instead', 'Keep it quick'],
      );
      await tester.tap(find.text('Salmon instead'));
      expect(picked, isEmpty);
      // "Draft my whole week" is a door, not a reply: it stays beside the
      // named chips on the first picker of an empty draft.
      expect(find.text('Draft my whole week'), findsOneWidget);
    });

    testWidgets('named chips keep the filters once the plan has a meal', (
      tester,
    ) async {
      // mp-230 clause 4: the filters appear once the plan has a meal; a
      // turn naming its replies does not take them away.
      await pumpChips(
        tester,
        covered: 1,
        of: 14,
        hasMeals: true,
        suggested: const ['Salmon instead', 'Keep it quick'],
      );
      expect(find.text('Salmon instead'), findsOneWidget);
      expect(find.text('No recipe only'), findsOneWidget);
      expect(find.text('Other options'), findsNothing);
    });

    testWidgets('an empty list leaves the app set exactly as it was', (
      tester,
    ) async {
      await pumpChips(
        tester,
        covered: 3,
        of: 14,
        nextType: MealType.dinner,
        hasMeals: true,
        suggested: const [],
      );
      expect(find.text('Next: Dinner'), findsOneWidget);
      expect(find.text('Other options'), findsOneWidget);
      expect(find.text('No recipe only'), findsOneWidget);
    });

    testWidgets('"Show more" is drawn only when the picker has a tail', (
      tester,
    ) async {
      await pumpChips(tester, covered: 0, of: 14, hasMeals: false);
      expect(find.text('Show more'), findsNothing);

      var raised = 0;
      await pumpChips(
        tester,
        covered: 0,
        of: 14,
        hasMeals: false,
        onShowMore: () => raised++,
      );
      await tester.tap(find.text('Show more'));
      expect(raised, 1);
    });

    testWidgets('"Show more" stays live once the strip is spent', (
      tester,
    ) async {
      var raised = 0;
      await pumpChips(
        tester,
        covered: 0,
        of: 14,
        hasMeals: false,
        enabled: false,
        onShowMore: () => raised++,
      );
      await tester.tap(find.text('Show more'));
      expect(raised, 1);
    });
  });
}
