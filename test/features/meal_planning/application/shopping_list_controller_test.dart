import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/application/shopping_list_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/shopping_item.dart';

void main() {
  test('share text is readable, aisle-grouped, and excludes pantry items', () {
    final oats = _item('Oats', 'Pantry', qty: '500 g');
    final oil = _item('Olive oil', 'Pantry', have: true);
    final bananas = _item('Bananas', 'Produce', qty: '6', checked: true);
    final state = ShoppingListState(
      items: [oats, oil, bananas],
      byAisle: {
        'Produce': [bananas],
        'Pantry': [oats, oil],
      },
      itemCount: 2,
      totalServings: 8,
      mealCount: 3,
    );

    expect(
      ShoppingListController.formatShareText(
        state,
        title: 'Mealvana shopping list',
        summary: '2 items to buy',
      ),
      '''Mealvana shopping list
2 items to buy

PRODUCE
☑ Bananas — 6

PANTRY
☐ Oats — 500 g''',
    );
  });

  test('share text leaves out an aisle when every item is already on hand', () {
    final oil = _item('Olive oil', 'Pantry', have: true);
    final state = ShoppingListState(
      items: [oil],
      byAisle: {
        'Pantry': [oil],
      },
    );

    final text = ShoppingListController.formatShareText(
      state,
      title: 'Mealvana shopping list',
      summary: '0 items to buy',
    );

    expect(text, isNot(contains('PANTRY')));
    expect(text, isNot(contains('Olive oil')));
  });
}

ShoppingItem _item(
  String name,
  String aisle, {
  String qty = '',
  bool checked = false,
  bool have = false,
}) => ShoppingItem.fromJson({
  'aisle': aisle,
  'name': name,
  'qty': qty,
  'checked': checked,
  'have': have,
  'fromMealIds': <String>[],
});
