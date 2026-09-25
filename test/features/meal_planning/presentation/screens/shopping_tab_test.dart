import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/content/domain/content_keys.dart';
import 'package:mealvana_endurance/features/meal_planning/application/shopping_list_controller.dart';
import 'package:mealvana_endurance/features/kroger/application/kroger_availability.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/shopping_item.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/shopping_list.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/shopping_tab.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/shopping_list.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/shopping_share_button.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';
import 'package:mealvana_endurance/shared/providers/unit_system_provider.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';

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

  _redesignTests();
}

class _FixedShoppingListController extends ShoppingListController {
  _FixedShoppingListController(this.seed);

  final ShoppingListState seed;

  @override
  ShoppingListState build() => seed;
}

// ── The redesigned tab (2026-09-16): header, menu, sheets, add row ──────────

class _RecordingShoppingListController extends ShoppingListController {
  _RecordingShoppingListController(this.seed);

  final ShoppingListState seed;
  final List<String> opened = [];
  final List<(String name, String? id)> renames = [];
  final List<String> deleted = [];
  final List<(String name, String qty)> added = [];
  int newLists = 0;
  int backToCurrent = 0;
  final List<(String name, bool value)> ticks = [];

  /// When set, every tick throws it (a write the server refused).
  Object? tickFailsWith;

  @override
  ShoppingListState build() => seed;

  @override
  Future<void> setChecked(String name, bool value) async {
    ticks.add((name, value));
    if (tickFailsWith != null) throw tickFailsWith!;
  }

  @override
  Future<void> openList(String listId) async => opened.add(listId);

  @override
  Future<void> openCurrent() async => backToCurrent++;

  @override
  Future<void> newList({String? name}) async => newLists++;

  @override
  Future<void> renameList(String name, {String? id}) async =>
      renames.add((name, id));

  @override
  Future<void> deleteList(String id) async => deleted.add(id);

  @override
  Future<void> addItem(String name, {String qty = ''}) async =>
      added.add((name, qty));
}

Future<_RecordingShoppingListController> _pumpTab(
  WidgetTester tester,
  ShoppingListState state, {
  bool krogerVisible = false,
  bool krogerPending = false,
}) async {
  final controller = _RecordingShoppingListController(state);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        contentServiceProvider.overrideWith(testContentService),
        shoppingListControllerProvider.overrideWith(() => controller),
        unitSystemProvider.overrideWith((ref) async => UnitSystem.imperial),
        krogerEntryVisibleProvider.overrideWithValue(krogerVisible),
        krogerEntryPendingProvider.overrideWithValue(krogerPending),
      ],
      child: const MaterialApp(home: Scaffold(body: ShoppingTab())),
    ),
  );
  await tester.pump();
  return controller;
}

const _broccoli = ShoppingListItem(
  id: 'r1',
  listId: 'list-1',
  aisle: 'Produce',
  name: 'Broccoli',
  qty: '2',
  source: ShoppingItemSource.plan,
);

ShoppingListState _listState({
  List<ShoppingListSummary> previous = const [],
  bool isCurrent = true,
  bool empty = false,
  String? planId = 'plan-1',
  String? weekPlanId,
  bool isOffline = false,
}) => ShoppingListState(
  listId: 'list-1',
  listName: 'Week of 2026-09-13',
  listDate: DateTime.utc(2026, 9, 14),
  isCurrent: isCurrent,
  planId: planId,
  isConfirmed: planId != null,
  items: empty ? const [] : const [_broccoli],
  byAisle: empty
      ? const {}
      : const {
          'Produce': [_broccoli],
        },
  itemCount: empty ? 0 : 1,
  previous: previous,
  weekPlanId: weekPlanId,
  isOffline: isOffline,
);

ShoppingListSummary _summary(
  String id,
  String name, {
  DateTime? on,
  String? planId,
}) => ShoppingListSummary(
  id: id,
  planId: planId,
  name: name,
  createdAt: on ?? DateTime.utc(2026, 9, 6),
  updatedAt: on ?? DateTime.utc(2026, 9, 6),
  confirmedAt: null,
  itemCount: 4,
);

Future<void> _openMenu(WidgetTester tester, String menuKey) async {
  await tester.tap(find.byKey(ValueKey(menuKey)));
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String itemKey) async {
  await tester.tap(find.byKey(ValueKey(itemKey)));
  await tester.pumpAndSettle();
}

/// A first read that never answers (the list lives server-side).
class _LoadingShoppingListController extends ShoppingListController {
  @override
  Future<ShoppingListState> build() => Completer<ShoppingListState>().future;
}

void _redesignTests() {
  final content = loadDefaultContent();

  // ── Loading never reads as empty (ticket 46, Findings 16-003, 20-003) ────

  group('first read', () {
    testWidgets('while the list is on the wire the tab shows loading, not '
        'No shopping list', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentServiceProvider.overrideWith(testContentService),
            shoppingListControllerProvider.overrideWith(
              _LoadingShoppingListController.new,
            ),
            unitSystemProvider.overrideWith((ref) async => UnitSystem.imperial),
            krogerEntryVisibleProvider.overrideWithValue(false),
            krogerEntryPendingProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(home: Scaffold(body: ShoppingTab())),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('meal_planning.shopping_loading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_empty')),
        findsNothing,
      );
      expect(
        find.text(content['meal_planning.shopping_empty_title']!),
        findsNothing,
      );
    });

    testWidgets('while Kroger coverage is still being asked the rows sit '
        'where they will once the button lands', (tester) async {
      await _pumpTab(tester, _listState(), krogerPending: true);
      expect(
        find.byKey(const ValueKey('meal_planning.kroger_pending')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('meal_planning.kroger')), findsNothing);
      final pendingTop = tester.getTopLeft(find.byType(ShoppingList)).dy;

      await _pumpTab(tester, _listState(), krogerVisible: true);
      expect(
        find.byKey(const ValueKey('meal_planning.kroger')),
        findsOneWidget,
      );
      final landedTop = tester.getTopLeft(find.byType(ShoppingList)).dy;

      expect(pendingTop, landedTop, reason: 'no jump when the button lands');
    });

    testWidgets('an answered no from Kroger takes the room away', (
      tester,
    ) async {
      await _pumpTab(tester, _listState());
      expect(
        find.byKey(const ValueKey('meal_planning.kroger_pending')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('meal_planning.kroger')), findsNothing);
    });
  });

  // ── Offline (testing-wave ticket 36, Findings 20-001/20-002) ─────────────

  group('offline', () {
    testWidgets('the offline copy says so and does not offer Kroger', (
      tester,
    ) async {
      await _pumpTab(tester, _listState(isOffline: true), krogerVisible: true);

      expect(
        find.byKey(const ValueKey('meal_planning.shopping_offline')),
        findsOneWidget,
      );
      expect(
        find.text(content['meal_planning.shopping_offline']!),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('meal_planning.kroger')), findsNothing);
    });

    testWidgets('online there is no notice and Kroger is offered', (
      tester,
    ) async {
      await _pumpTab(tester, _listState(), krogerVisible: true);

      expect(
        find.byKey(const ValueKey('meal_planning.shopping_offline')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('meal_planning.kroger')),
        findsOneWidget,
      );
    });

    testWidgets('a tick the server refuses tells the athlete', (tester) async {
      final controller = await _pumpTab(tester, _listState());
      controller.tickFailsWith = StateError('refused');

      await tester.tap(
        find.byKey(const ValueKey('meal_planning.shopping_check_Broccoli')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(controller.ticks, [('Broccoli', true)]);
      expect(
        find.text(content['meal_planning.shopping_failed']!),
        findsOneWidget,
      );
    });
  });

  group('header', () {
    testWidgets('shows the name and date, a menu, and no inline add fields', (
      tester,
    ) async {
      await _pumpTab(tester, _listState());

      // a list made before 2026-09-25 carries its week as an ISO date; it
      // reads in words, like the lists made since (Finding 16-007)
      expect(find.text('Week of Sep 13'), findsOneWidget);
      expect(find.text('Week of 2026-09-13'), findsNothing);
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_list_date')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_menu')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_add_name')),
        findsNothing,
      );
      expect(find.byType(TextField), findsNothing);
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_add_item')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_row_menu_Broccoli')),
        findsOneWidget,
      );
    });

    testWidgets('the menu offers New list, Previous lists and Delete list', (
      tester,
    ) async {
      final controller = await _pumpTab(tester, _listState());

      await _openMenu(tester, 'meal_planning.shopping_menu');
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_new_list')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_previous')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_delete_list')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_back_to_current')),
        findsNothing,
        reason: 'the current list has nothing to go back to',
      );

      await _choose(tester, 'meal_planning.shopping_new_list');
      expect(controller.newLists, 1);
    });

    testWidgets('tapping the name opens a prefilled rename sheet', (
      tester,
    ) async {
      final controller = await _pumpTab(tester, _listState());

      await tester.tap(
        find.byKey(const ValueKey('meal_planning.shopping_list_name')),
      );
      await tester.pumpAndSettle();

      final field = find.byKey(
        const ValueKey('meal_planning.shopping_rename_name'),
      );
      expect(field, findsOneWidget);
      expect(find.text('Week of Sep 13'), findsWidgets);
      await tester.enterText(field, 'Big shop');
      await tester.tap(
        find.byKey(const ValueKey('meal_planning.shopping_rename_save')),
      );
      await tester.pumpAndSettle();

      expect(controller.renames, [('Big shop', 'list-1')]);
    });

    testWidgets('Delete list asks first; Keep it sends nothing', (
      tester,
    ) async {
      final controller = await _pumpTab(tester, _listState());

      await _openMenu(tester, 'meal_planning.shopping_menu');
      await _choose(tester, 'meal_planning.shopping_delete_list');
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_delete_confirm')),
        findsOneWidget,
      );
      await _choose(tester, 'meal_planning.shopping_delete_cancel');
      expect(controller.deleted, isEmpty);

      await _openMenu(tester, 'meal_planning.shopping_menu');
      await _choose(tester, 'meal_planning.shopping_delete_list');
      await _choose(tester, 'meal_planning.shopping_delete_go');
      expect(controller.deleted, ['list-1']);
    });

    // Ticket 96 (Finding 19-002, Lee 09-25): the confirmed plan's own list
    // may be deleted, behind its own short warning that the Plan tab can
    // rebuild it; a hand-made list keeps the plain one.
    testWidgets("the confirmed plan's list warns it is the plan's list", (
      tester,
    ) async {
      final content = loadDefaultContent();
      final controller = await _pumpTab(
        tester,
        _listState(planId: 'plan-1', weekPlanId: 'plan-1'),
      );

      await _openMenu(tester, 'meal_planning.shopping_menu');
      await _choose(tester, 'meal_planning.shopping_delete_list');
      expect(
        find.text(content[ContentKeys.mpShoppingDeletePlanListTitle]!),
        findsOneWidget,
      );
      expect(
        find.text(content[ContentKeys.mpShoppingDeletePlanListBody]!),
        findsOneWidget,
      );
      expect(
        find.text(content[ContentKeys.mpShoppingDeleteListBody]!),
        findsNothing,
      );
      await _choose(tester, 'meal_planning.shopping_delete_go');
      expect(controller.deleted, ['list-1']);
    });

    testWidgets("a hand-made list's delete keeps the plain warning", (
      tester,
    ) async {
      final content = loadDefaultContent();
      await _pumpTab(tester, _listState(planId: null, weekPlanId: 'plan-1'));

      await _openMenu(tester, 'meal_planning.shopping_menu');
      await _choose(tester, 'meal_planning.shopping_delete_list');
      expect(
        find.text(content[ContentKeys.mpShoppingDeleteListTitle]!),
        findsOneWidget,
      );
      expect(
        find.text(content[ContentKeys.mpShoppingDeletePlanListBody]!),
        findsNothing,
      );
    });

    testWidgets("an archived draft's list is not the plan's list", (
      tester,
    ) async {
      final content = loadDefaultContent();
      await _pumpTab(
        tester,
        _listState(planId: 'archived-draft', weekPlanId: 'plan-1'),
      );

      await _openMenu(tester, 'meal_planning.shopping_menu');
      await _choose(tester, 'meal_planning.shopping_delete_list');
      expect(
        find.text(content[ContentKeys.mpShoppingDeleteListBody]!),
        findsOneWidget,
      );
    });

    testWidgets('an earlier list says so and the menu offers the way back', (
      tester,
    ) async {
      final controller = await _pumpTab(tester, _listState(isCurrent: false));

      expect(
        find.textContaining(content['meal_planning.shopping_viewing_prior']!),
        findsOneWidget,
      );
      await _openMenu(tester, 'meal_planning.shopping_menu');
      await _choose(tester, 'meal_planning.shopping_back_to_current');
      expect(controller.backToCurrent, 1);
    });
  });

  group('lines', () {
    testWidgets('the add row opens an empty sheet whose Add calls addItem', (
      tester,
    ) async {
      final controller = await _pumpTab(tester, _listState());

      await tester.tap(
        find.byKey(const ValueKey('meal_planning.shopping_add_item')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('meal_planning.shopping_add_sheet')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('meal_planning.shopping_add_name')),
        'Milk',
      );
      await tester.enterText(
        find.byKey(const ValueKey('meal_planning.shopping_add_qty')),
        '1 gal',
      );
      await tester.tap(
        find.byKey(const ValueKey('meal_planning.shopping_add_submit')),
      );
      await tester.pumpAndSettle();

      expect(controller.added, [('Milk', '1 gal')]);
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_add_sheet')),
        findsNothing,
        reason: 'the sheet closes; the next add starts clean',
      );
    });

    testWidgets('the add row is the last thing under the list', (tester) async {
      await _pumpTab(tester, _listState());

      final list = find.byType(ShoppingList);
      final add = find.byKey(const ValueKey('meal_planning.shopping_add_item'));
      expect(
        tester.getTopLeft(add).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(list).dy),
      );
    });

    testWidgets(
      'an empty hand list says so quietly and never shows the no-list copy',
      (tester) async {
        await _pumpTab(tester, _listState(empty: true, planId: null));

        expect(
          find.byKey(const ValueKey('meal_planning.shopping_list_empty')),
          findsOneWidget,
        );
        expect(
          find.text(content['meal_planning.shopping_empty_title']!),
          findsNothing,
        );
        expect(find.textContaining('Confirm a meal plan'), findsNothing);
        expect(
          find.byKey(const ValueKey('meal_planning.shopping_add_item')),
          findsOneWidget,
        );
      },
    );

    testWidgets('no list anywhere: the empty state still offers New list', (
      tester,
    ) async {
      final controller = await _pumpTab(tester, const ShoppingListState());

      expect(
        find.byKey(const ValueKey('meal_planning.shopping_empty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_menu')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('meal_planning.shopping_new_list')),
      );
      await tester.pump();
      expect(controller.newLists, 1);
    });
  });

  group('Kroger', () {
    testWidgets(
      'a plan list features the hand-off full width under the header',
      (tester) async {
        await _pumpTab(tester, _listState(), krogerVisible: true);

        final entry = find.byKey(const ValueKey('meal_planning.kroger'));
        expect(entry, findsOneWidget);
        final width = tester.getSize(find.byType(ShoppingTab)).width;
        expect(tester.getSize(entry).width, width - 2 * AppSpacing.md);
        expect(
          tester.getBottomLeft(entry).dy,
          lessThan(tester.getTopLeft(find.byType(ShoppingList)).dy),
        );
        expect(
          tester.getTopLeft(entry).dy,
          greaterThan(
            tester
                .getBottomLeft(
                  find.byKey(
                    const ValueKey('meal_planning.shopping_list_name'),
                  ),
                )
                .dy,
          ),
        );
      },
    );

    testWidgets('a hand list has no Kroger button', (tester) async {
      await _pumpTab(tester, _listState(planId: null), krogerVisible: true);
      expect(find.byKey(const ValueKey('meal_planning.kroger')), findsNothing);
    });
  });

  group('previous lists sheet', () {
    final previous = [
      _summary('list-b', 'Old week', on: DateTime.utc(2026, 9, 6)),
      _summary(
        'list-a',
        'Costco',
        on: DateTime.utc(2026, 9, 8),
        planId: 'plan-0',
      ),
    ];

    Future<_RecordingShoppingListController> open(WidgetTester tester) async {
      final controller = await _pumpTab(tester, _listState(previous: previous));
      await _openMenu(tester, 'meal_planning.shopping_menu');
      await _choose(tester, 'meal_planning.shopping_previous');
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_previous_sheet')),
        findsOneWidget,
      );
      return controller;
    }

    testWidgets('lists every list newest first, marking plan lists', (
      tester,
    ) async {
      await open(tester);

      double top(String id) => tester
          .getTopLeft(
            find.byKey(ValueKey('meal_planning.shopping_previous_$id')),
          )
          .dy;
      expect(top('list-1'), lessThan(top('list-a')));
      expect(top('list-a'), lessThan(top('list-b')));
      expect(find.text('Costco'), findsOneWidget);
      expect(find.text('Old week'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_from_plan_list-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_from_plan_list-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_from_plan_list-b')),
        findsNothing,
      );
      expect(
        find.textContaining(
          content['meal_planning.shopping_previous_current']!,
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      "marks this week's confirmed plan's list apart from other plans' lists (19-005)",
      (tester) async {
        await _pumpTab(
          tester,
          _listState(
            planId: null,
            weekPlanId: 'plan-confirmed',
            previous: [
              _summary(
                'list-draft',
                'Week of 2026-09-20',
                on: DateTime.utc(2026, 9, 24),
                planId: 'plan-draft',
              ),
              _summary(
                'list-week',
                'Week of Sep 20',
                on: DateTime.utc(2026, 9, 20),
                planId: 'plan-confirmed',
              ),
            ],
          ),
        );
        await _openMenu(tester, 'meal_planning.shopping_menu');
        await _choose(tester, 'meal_planning.shopping_previous');

        final mark = find.byKey(
          const ValueKey('meal_planning.shopping_week_plan_list-week'),
        );
        expect(mark, findsOneWidget);
        expect(
          find.descendant(
            of: mark,
            matching: find.text(content['meal_planning.shopping_week_plan']!),
          ),
          findsOneWidget,
        );
        // the plan's list carries the stronger mark only
        expect(
          find.byKey(
            const ValueKey('meal_planning.shopping_from_plan_list-week'),
          ),
          findsNothing,
        );
        // an archived or draft plan's list keeps the plain "From plan"
        expect(
          find.byKey(
            const ValueKey('meal_planning.shopping_from_plan_list-draft'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const ValueKey('meal_planning.shopping_week_plan_list-draft'),
          ),
          findsNothing,
        );
        // both same-week names read in words, whichever way they were stored
        expect(find.text('Week of Sep 20'), findsNWidgets(2));
      },
    );

    testWidgets('no confirmed plan this week: no list is marked', (
      tester,
    ) async {
      await open(tester);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'meal_planning.shopping_week_plan_',
              ),
        ),
        findsNothing,
      );
    });

    testWidgets('tapping a row opens that list', (tester) async {
      final controller = await open(tester);

      await _choose(tester, 'meal_planning.shopping_previous_list-b');
      expect(controller.opened, ['list-b']);
      expect(
        find.byKey(const ValueKey('meal_planning.shopping_previous_sheet')),
        findsNothing,
      );
    });

    testWidgets('a row\'s menu renames that list', (tester) async {
      final controller = await open(tester);

      await _openMenu(tester, 'meal_planning.shopping_previous_menu_list-a');
      await _choose(tester, 'meal_planning.shopping_previous_rename_list-a');
      final field = find.byKey(
        const ValueKey('meal_planning.shopping_rename_name'),
      );
      expect(field, findsOneWidget);
      await tester.enterText(field, 'Bulk run');
      await tester.tap(
        find.byKey(const ValueKey('meal_planning.shopping_rename_save')),
      );
      await tester.pumpAndSettle();

      expect(controller.renames, [('Bulk run', 'list-a')]);
    });

    testWidgets('a row\'s menu deletes that list after asking', (tester) async {
      final controller = await open(tester);

      await _openMenu(tester, 'meal_planning.shopping_previous_menu_list-b');
      await _choose(tester, 'meal_planning.shopping_previous_delete_list-b');
      await _choose(tester, 'meal_planning.shopping_delete_go');

      expect(controller.deleted, ['list-b']);
    });

    // Ticket 49, Finding 19-003: 14 lists overflowed the sheet by 80 px and
    // the last ones could not be reached.
    testWidgets('fourteen lists scroll to the last one with no overflow', (
      tester,
    ) async {
      final many = [
        for (var i = 1; i <= 13; i++)
          _summary(
            'list-old-$i',
            'Week $i',
            on: DateTime.utc(2026, 9, 12).subtract(Duration(days: 7 * i)),
          ),
      ];
      final controller = await _pumpTab(tester, _listState(previous: many));
      await _openMenu(tester, 'meal_planning.shopping_menu');
      await _choose(tester, 'meal_planning.shopping_previous');
      expect(tester.takeException(), isNull);

      final sheet = find.byKey(
        const ValueKey('meal_planning.shopping_previous_sheet'),
      );
      final last = find.byKey(
        const ValueKey('meal_planning.shopping_previous_list-old-13'),
      );
      await tester.scrollUntilVisible(
        last,
        200,
        scrollable: find
            .descendant(of: sheet, matching: find.byType(Scrollable))
            .first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await _choose(tester, 'meal_planning.shopping_previous_list-old-13');
      expect(controller.opened, ['list-old-13']);
    });
  });
}
