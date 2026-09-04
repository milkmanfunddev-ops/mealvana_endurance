import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/application/shopping_list_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/shopping_item.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/shopping_list.dart';

import 'package:mealvana_endurance/features/content/application/content_service.dart';
import '../helpers/test_content.dart';

/// 05 §4 — the aisle-grouped list: header counts, per-aisle rows, checkbox
/// and "have it" toggles reporting intents, empty state.
void main() {
  ShoppingListState stateWith(List<ShoppingItem> items) {
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
    );
  }

  Future<void> pumpList(
    WidgetTester tester,
    ShoppingListState state, {
    void Function(String name, bool value)? onChecked,
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  ShoppingItem item(String name, String aisle, {bool have = false}) =>
      ShoppingItem.fromJson({
        'aisle': aisle,
        'name': name,
        'qty': '500 g',
        'checked': false,
        'have': have,
        'fromMealIds': <String>[],
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
}
