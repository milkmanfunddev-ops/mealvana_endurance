// Golden coverage for the meal-planning surfaces named in
// `docs/implement_mealplanning/07-verification-release.md` §Tests: the plan
// (empty / draft / confirmed), the meal picker + chips, the plan bar
// (minimized / expanded) and the shopping list — each in light and dark,
// at iPhone-SE width.
//
// The plan and shopping fixtures are the frozen `contract-v1` wire payloads
// (`test/features/meal_planning/fixtures/`), so a golden that moves means the
// UI moved, not that a hand-typed sample drifted.
//
// Fonts: widget tests render with the test font, so these goldens pin
// LAYOUT, COLOUR and STRUCTURE, not glyph shapes. That is the regression
// they are here to catch (a token swap, a padding change, a state that stops
// rendering) — screenshot review of typography stays a `/verify-app` job.
//
//   flutter test test/features/meal_planning/presentation/widget_goldens_test.dart
//   flutter test test/features/meal_planning/presentation/widget_goldens_test.dart --update-goldens
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/shopping_list_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_type.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/shopping_item.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/confirmed_card.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/meal_picker_carousel.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/picker_chips.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/plan_bar.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/plan_list.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/plan_summary.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/shopping_list.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';

import '../domain/fixture_helpers.dart';
import 'helpers/test_content.dart';

/// iPhone SE logical width — the narrowest layout the app supports.
const _seWidth = 320.0;

void main() {
  // The confirmed plan straight off the wire (`confirm_plan.json` → the
  // `batch` part), and the same plan re-cast as a draft.
  final confirmedPlan = MealPlan.fromJson(
    (loadFixture('confirm_plan')['parts'] as List).firstWhere(
          (p) => (p as Map)['kind'] == 'batch',
        )['plan']
        as Map<String, dynamic>,
  );
  final draftPlan = MealPlan.fromJson({
    ...confirmedPlan.toJson(),
    'status': 'draft',
  });

  final shoppingPart =
      VanaPart.fromJson(loadFixture('shopping_list')) as VanaShoppingListPart;

  final pickerPart =
      VanaPart.fromJson(loadFixture('meal_picker')) as VanaMealPickerPart;

  ShoppingListState shoppingState() {
    final items = shoppingPart.items;
    final byAisle = <String, List<ShoppingItem>>{};
    for (final item in items) {
      byAisle.putIfAbsent(item.aisle, () => []).add(item);
    }
    return ShoppingListState(
      planId: confirmedPlan.id,
      isConfirmed: true,
      items: items,
      byAisle: byAisle,
      itemCount: shoppingPart.itemCount,
      skipped: shoppingPart.skipped,
      totalServings: 8,
      mealCount: confirmedPlan.meals.length,
    );
  }

  /// Pumps [child] on a fixed-width surface in [brightness] and matches
  /// `goldens/<name>_<light|dark>.png`.
  Future<void> goldenTest(
    WidgetTester tester,
    String name,
    Brightness brightness,
    Widget child, {
    double height = 900,
    Future<void> Function(WidgetTester tester)? beforeMatch,
  }) async {
    tester.view.physicalSize = Size(_seWidth, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final isDark = brightness == Brightness.dark;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentServiceProvider.overrideWith(testContentService)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            backgroundColor: isDark
                ? AppColors.blackberry
                : AppColors.surfaceLight,
            body: RepaintBoundary(
              key: const Key('golden'),
              child: SizedBox(
                width: _seWidth,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    if (beforeMatch != null) {
      await beforeMatch(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    final suffix = isDark ? 'dark' : 'light';
    await expectLater(
      find.byKey(const Key('golden')),
      matchesGoldenFile('goldens/${name}_$suffix.png'),
    );
  }

  /// Runs [build] as a golden in both themes.
  void bothThemes(String name, Widget Function() build, {double height = 900}) {
    for (final brightness in Brightness.values) {
      testWidgets('golden: $name (${brightness.name})', (tester) async {
        await goldenTest(tester, name, brightness, build(), height: height);
      });
    }
  }

  group('plan', () {
    bothThemes(
      'plan_draft',
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlanSummary(plan: draftPlan),
          const SizedBox(height: 8),
          PlanList(
            meals: draftPlan.meals,
            onTapMeal: (_) {},
            onSwap: (_) {},
            onRemove: (_) {},
          ),
        ],
      ),
    );

    bothThemes(
      'plan_confirmed',
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlanSummary(plan: confirmedPlan),
          const SizedBox(height: 8),
          PlanList(
            meals: confirmedPlan.meals,
            showMacros: true,
            onTapMeal: (_) {},
            onSwap: (_) {},
            onRemove: (_) {},
          ),
          const SizedBox(height: 8),
          ConfirmedCard(
            part: shoppingPart,
            plan: confirmedPlan,
            onView: () {},
            onViewPlan: () {},
          ),
        ],
      ),
    );

    // The empty plan: PlanList renders nothing, and the tab's own dashed
    // card is private to plan_tab.dart — the contract worth pinning here is
    // "no meals paints no rows and throws nothing".
    bothThemes(
      'plan_empty',
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlanSummary(
            plan: MealPlan.fromJson({
              ...confirmedPlan.toJson(),
              'status': 'draft',
              'meals': <Object>[],
              'shopping': <Object>[],
            }),
          ),
          const SizedBox(height: 8),
          PlanList(
            meals: const [],
            onTapMeal: (_) {},
            onSwap: (_) {},
            onRemove: (_) {},
          ),
        ],
      ),
      height: 400,
    );
  });

  group('picker', () {
    bothThemes(
      'meal_picker',
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MealPickerCarousel(
            title: pickerPart.title,
            meals: pickerPart.meals,
            multi: pickerPart.multi,
            pickedIds: {
              if (pickerPart.meals.isNotEmpty) pickerPart.meals.first.id,
            },
            onPick: (_) {},
          ),
          const SizedBox(height: 12),
          PickerChips(
            covered: 3,
            of: 5,
            nextType: MealType.dinner,
            hasMeals: true,
            onPick: (_) {},
            onSomethingElse: () {},
          ),
        ],
      ),
      height: 600,
    );

    bothThemes(
      'picker_chips_complete',
      () => PickerChips(
        covered: 5,
        of: 5,
        hasMeals: true,
        onPick: (_) {},
        onSomethingElse: () {},
      ),
      height: 240,
    );
  });

  group('plan bar', () {
    bothThemes(
      'plan_bar_minimized',
      () => PlanBar(
        meals: confirmedPlan.meals,
        onServings: (_, __) {},
        onRemove: (_) {},
        onSwap: (_, __) {},
        onReview: () {},
      ),
      height: 240,
    );

    for (final brightness in Brightness.values) {
      testWidgets('golden: plan_bar_expanded (${brightness.name})', (
        tester,
      ) async {
        await goldenTest(
          tester,
          'plan_bar_expanded',
          brightness,
          PlanBar(
            meals: confirmedPlan.meals,
            onServings: (_, __) {},
            onRemove: (_) {},
            onSwap: (_, __) {},
            onReview: () {},
          ),
          height: 600,
          // The bar always mounts minimized; expand it before the match so
          // this golden pins the expanded state, not a second copy of the
          // minimized one.
          beforeMatch: (tester) => tester.tap(
            find.byKey(const ValueKey('meal_planning.plan_bar.minimized')),
          ),
        );
      });
    }
  });

  group('shopping', () {
    bothThemes(
      'shopping_list',
      () => ShoppingList(
        state: shoppingState(),
        onToggleChecked: (_, __) {},
        onAddBack: (_) {},
      ),
      height: 900,
    );

    bothThemes(
      'shopping_list_empty',
      () => ShoppingList(
        state: const ShoppingListState(),
        onToggleChecked: (_, __) {},
        onAddBack: (_) {},
      ),
      height: 300,
    );
  });

  test('fixtures carry the shapes these goldens depend on', () {
    // A silently-empty fixture would produce a blank golden that still
    // "passes" forever — pin the preconditions.
    expect(confirmedPlan.meals, isNotEmpty);
    expect(confirmedPlan.shopping, isNotEmpty);
    expect(shoppingPart.items, isNotEmpty);
    expect(pickerPart.meals, isNotEmpty);
    expect(pickerPart.meals.first, isA<MealRef>());
  });
}
