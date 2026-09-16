import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/shopping_list_controller.dart';
import 'package:mealvana_endurance/features/kroger/application/kroger_availability.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/shopping_item.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/shopping_list.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/shopping_tab.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/shopping_share_button.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';
import 'package:mealvana_endurance/shared/providers/unit_system_provider.dart';

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
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: ShoppingShareButton(),
            ),
          ),
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

  _severalListsTests();
}

class _FixedShoppingListController extends ShoppingListController {
  _FixedShoppingListController(this.seed);

  final ShoppingListState seed;

  @override
  ShoppingListState build() => seed;
}

// ── Several lists (2026-09-16): the add row, the header, previous lists ──────

class _RecordingShoppingListController extends ShoppingListController {
  _RecordingShoppingListController(this.seed);

  final ShoppingListState seed;
  final List<String> opened = [];
  int newLists = 0;

  @override
  ShoppingListState build() => seed;

  @override
  Future<void> openList(String listId) async => opened.add(listId);

  @override
  Future<void> newList({String? name}) async => newLists++;
}

Future<_RecordingShoppingListController> _pumpTab(
  WidgetTester tester,
  ShoppingListState state,
) async {
  final controller = _RecordingShoppingListController(state);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        contentServiceProvider.overrideWith(testContentService),
        shoppingListControllerProvider.overrideWith(() => controller),
        unitSystemProvider.overrideWith((ref) async => UnitSystem.imperial),
        krogerEntryVisibleProvider.overrideWithValue(false),
      ],
      child: const MaterialApp(home: Scaffold(body: ShoppingTab())),
    ),
  );
  await tester.pump();
  return controller;
}

ShoppingListState _listState({
  List<ShoppingListSummary> previous = const [],
  bool isCurrent = true,
}) {
  const broccoli = ShoppingListItem(
    id: 'r1',
    listId: 'list-1',
    aisle: 'Produce',
    name: 'Broccoli',
    qty: '2',
    source: ShoppingItemSource.plan,
  );
  return ShoppingListState(
    listId: 'list-1',
    listName: 'Week of 2026-09-13',
    listDate: DateTime.utc(2026, 9, 14),
    isCurrent: isCurrent,
    planId: 'plan-1',
    isConfirmed: true,
    items: const [broccoli],
    byAisle: const {
      'Produce': [broccoli],
    },
    itemCount: 1,
    previous: previous,
  );
}

ShoppingListSummary _summary(String id, String name) => ShoppingListSummary(
  id: id,
  planId: null,
  name: name,
  createdAt: DateTime.utc(2026, 9, 6),
  updatedAt: DateTime.utc(2026, 9, 6),
  confirmedAt: null,
  itemCount: 4,
);

void _severalListsTests() {
  final content = loadDefaultContent();

  testWidgets(
    'the current list shows its name, an add row, and a New list button',
    (tester) async {
      await _pumpTab(tester, _listState());

      expect(find.text('Week of 2026-09-13'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_add_name')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_add_qty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_add_submit')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_new_list')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_row_menu_Broccoli')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_back_to_current')),
        findsNothing,
      );
    },
  );

  testWidgets('the row menu offers Edit and Delete', (tester) async {
    await _pumpTab(tester, _listState());

    await tester.tap(
      find.byKey(const ValueKey('meal_planning.shopping_row_menu_Broccoli')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(content['meal_planning.shopping_edit_action']!),
      findsOneWidget,
    );
    expect(
      find.text(content['meal_planning.shopping_delete_action']!),
      findsOneWidget,
    );
  });

  testWidgets(
    'Previous lists starts collapsed and opens to the earlier lists, newest first',
    (tester) async {
      final controller = await _pumpTab(
        tester,
        _listState(
          previous: [
            _summary('list-a', 'Costco'),
            _summary('list-b', 'Old week'),
          ],
        ),
      );

      expect(find.text('Costco'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('meal_planning.shopping_previous')),
      );
      await tester.pump();
      expect(find.text('Costco'), findsOneWidget);
      expect(find.text('Old week'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('meal_planning.shopping_previous_list-b')),
      );
      await tester.pump();
      expect(controller.opened, ['list-b']);
    },
  );

  testWidgets('an earlier list says so and offers the way back', (
    tester,
  ) async {
    await _pumpTab(tester, _listState(isCurrent: false));

    expect(
      find.text(content['meal_planning.shopping_viewing_prior']!),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meal_planning.shopping_back_to_current')),
      findsOneWidget,
    );
  });

  testWidgets('no list anywhere: the empty state still offers New list', (
    tester,
  ) async {
    final controller = await _pumpTab(tester, const ShoppingListState());

    expect(
      find.byKey(const ValueKey('meal_planning.shopping_empty')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('meal_planning.shopping_new_list')),
    );
    await tester.pump();
    expect(controller.newLists, 1);
  });
}
