import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/shopping_list_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/shopping_item.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/shopping_share_button.dart';

import '../helpers/test_content.dart';

/// The share action moved from the bottom of the list into the Food screen's
/// header, beside the settings gear (2026-09-03) — [ShoppingShareButton] is
/// that header button. It still uses the standard share icon, not a
/// "Send to Reminders" action.
void main() {
  testWidgets('the header share button uses the standard share icon', (
    tester,
  ) async {
    const oats = ShoppingItem(aisle: 'Pantry', name: 'Oats', qty: '500 g');
    const state = ShoppingListState(
      items: [oats],
      byAisle: {
        'Pantry': [oats],
      },
      itemCount: 1,
      totalServings: 4,
      mealCount: 2,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentServiceProvider.overrideWith(testContentService),
          shoppingListControllerProvider.overrideWith(
            () => _FixedShoppingListController(state),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Align(alignment: Alignment.topRight, child: ShoppingShareButton())),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('meal_planning.shopping_share')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            (widget.icon == Icons.share_outlined ||
                widget.icon == Icons.ios_share_outlined),
      ),
      findsOneWidget,
    );
    expect(find.text('Send to Reminders'), findsNothing);
  });
}

class _FixedShoppingListController extends ShoppingListController {
  _FixedShoppingListController(this.seed);

  final ShoppingListState seed;

  @override
  ShoppingListState build() => seed;
}
