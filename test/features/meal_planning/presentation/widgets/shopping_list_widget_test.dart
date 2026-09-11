import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/application/shopping_list_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/plan_meal.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/shopping_item.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/shopping_list.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';

import 'package:mealvana_endurance/features/content/application/content_service.dart';
import '../helpers/test_content.dart';

/// 05 §4 — the aisle-grouped list: header counts, per-aisle rows, checkbox
/// and "have it" toggles reporting intents, empty state.
void main() {
  ShoppingListState stateWith(
    List<ShoppingItem> items, {
    List<PlanMeal> meals = const [],
  }) {
    final byAisle = <String, List<ShoppingItem>>{};
    for (final item in items) {
      byAisle.putIfAbsent(item.aisle, () => []).add(item);
    }
    return ShoppingListState(
      planId: 'plan-1',
      isConfirmed: true,
      items: items,
      byAisle: byAisle,
      itemCount: items.where((i) => !i.have).length,
      skipped: [
        for (final i in items)
          if (i.have) i.name,
      ],
      totalServings: 8,
      mealCount: 3,
      meals: meals,
    );
  }

  Future<void> pumpList(
    WidgetTester tester,
    ShoppingListState state, {
    void Function(String name, bool value)? onChecked,
    UnitSystem units = UnitSystem.imperial,
    ValueChanged<PlanMeal>? onOpenMeal,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentServiceProvider.overrideWith(testContentService)],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShoppingList(
                state: state,
                onToggleChecked: (item, value) =>
                    onChecked?.call(item.name, value),
                onAddBack: (_) {},
                units: units,
                onOpenMeal: onOpenMeal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  ShoppingItem item(
    String name,
    String aisle, {
    bool have = false,
    List<String> from = const [],
  }) => ShoppingItem.fromJson({
    'aisle': aisle,
    'name': name,
    'qty': '500 g',
    'checked': false,
    'have': have,
    'fromMealIds': from,
  });

  PlanMeal meal(String id, String name) => PlanMeal.fromJson({
    'id': id,
    'planId': 'plan-1',
    'source': 'library',
    'name': name,
    'mealType': 'dinner',
    'servings': 4,
    'servingsLeft': 4,
  });

  testWidgets('renders header counts and aisle groups', (tester) async {
    await pumpList(
      tester,
      stateWith([item('Chicken breast', 'Protein'), item('Oats', 'Pantry')]),
    );
    expect(find.text('2 items'), findsOneWidget);
    expect(find.textContaining('8 servings'), findsOneWidget);
    // Aisle names render as uppercase eyebrows.
    expect(find.text('PROTEIN'), findsOneWidget);
    expect(find.text('PANTRY'), findsOneWidget);
    expect(find.text('Chicken breast'), findsOneWidget);
  });

  testWidgets('skipped items show the add-back row', (tester) async {
    await pumpList(
      tester,
      stateWith([item('Olive oil', 'Pantry', have: true)]),
    );
    expect(find.textContaining('I left olive oil off'), findsOneWidget);
    // Item count excludes what the athlete already has.
    expect(find.text('0 items'), findsOneWidget);
  });

  testWidgets('checkbox reports the item', (tester) async {
    final toggles = <String>[];
    await pumpList(
      tester,
      stateWith([item('Chicken breast', 'Protein')]),
      onChecked: (name, value) => toggles.add('$name:$value'),
    );
    await tester.tap(
      find.byKey(const ValueKey('meal_planning.shopping_check_Chicken breast')),
    );
    expect(toggles, ['Chicken breast:true']);
  });

  testWidgets('items the athlete has are left off the list', (tester) async {
    await pumpList(tester, stateWith([item('Oats', 'Pantry', have: true)]));
    // Only Vana's "I left … off" note mentions it; there is no row for it.
    expect(
      find.byKey(const ValueKey('meal_planning.shopping_check_Oats')),
      findsNothing,
    );
    expect(find.text('PANTRY'), findsNothing);
  });

  testWidgets('empty state shows the confirm hint', (tester) async {
    await pumpList(tester, const ShoppingListState());
    expect(find.text('No shopping list'), findsOneWidget);
    expect(find.textContaining('Confirm a meal plan'), findsOneWidget);
  });

  testWidgets('quantities read imperial by default, metric when chosen', (
    tester,
  ) async {
    await pumpList(tester, stateWith([item('Oats', 'Pantry')]));
    expect(find.text('1.1 lb'), findsOneWidget);
    expect(find.text('500 g'), findsNothing);

    await pumpList(
      tester,
      stateWith([item('Oats', 'Pantry')]),
      units: UnitSystem.metric,
    );
    expect(find.text('500 g'), findsOneWidget);
  });

  testWidgets('a line from several meals carries a count badge; one does not', (
    tester,
  ) async {
    final meals = [
      meal('m1', 'Chicken rice bowl'),
      meal('m2', 'Garlic salmon'),
    ];
    await pumpList(
      tester,
      stateWith([
        item('Garlic', 'Produce', from: ['m1', 'm2']),
        item('Salmon', 'Protein', from: ['m2']),
      ], meals: meals),
      onOpenMeal: (_) {},
    );
    expect(
      find.byKey(const ValueKey('meal_planning.shopping_sources_Garlic')),
      findsOneWidget,
    );
    expect(find.text('2'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('meal_planning.shopping_sources_Salmon')),
      findsNothing,
    );
  });

  testWidgets(
    'tapping a line opens its meals; tapping a meal opens the recipe',
    (tester) async {
      final meals = [
        meal('m1', 'Chicken rice bowl'),
        meal('m2', 'Garlic salmon'),
      ];
      final opened = <String>[];
      await pumpList(
        tester,
        stateWith([
          item('Garlic', 'Produce', from: ['m1', 'm2']),
        ], meals: meals),
        onOpenMeal: (m) => opened.add(m.id),
      );
      await tester.tap(
        find.byKey(const ValueKey('meal_planning.shopping_row_Garlic')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_sources_sheet')),
        findsOneWidget,
      );
      expect(
        find.text('From 2 meals · Tap a meal to see the recipe'),
        findsOneWidget,
      );
      expect(find.text('Chicken rice bowl'), findsOneWidget);
      expect(find.text('Garlic salmon'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('meal_planning.shopping_source_m2')),
      );
      await tester.pumpAndSettle();
      expect(opened, ['m2']);
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_sources_sheet')),
        findsNothing,
      );
    },
  );

  testWidgets('without an opener the row body is inert', (tester) async {
    await pumpList(
      tester,
      stateWith(
        [
          item('Garlic', 'Produce', from: ['m1']),
        ],
        meals: [meal('m1', 'Garlic salmon')],
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('meal_planning.shopping_row_Garlic')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('meal_planning.shopping_sources_sheet')),
      findsNothing,
    );
  });
}
