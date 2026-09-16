/// ShoppingListController through the real notifier: the most recent list
/// on top, add / edit / delete / new list / switch list through
/// `vana-action`, the plan mirror when the server is unreachable, and the
/// share text.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_plan_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/shopping_list_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_action_client.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/shopping_item.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/shopping_list.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';

import '../domain/fixture_helpers.dart';
import '../helpers/container.dart';

class _FixedPlanController extends MealPlanController {
  _FixedPlanController(this.plan);

  final MealPlan? plan;

  @override
  FutureOr<MealPlan?> build() => plan;
}

/// A stand-in for the shopping actions on `vana-action`: lists and rows in
/// memory, answered in the contract's shape, every call recorded.
class _ShoppingServer extends Fake implements VanaActionClient {
  _ShoppingServer(this.lists);

  final List<Map<String, dynamic>> lists;
  final List<UiAction> calls = [];
  Object? failWith;
  int _seq = 100;

  Map<String, dynamic> _list(String id) =>
      lists.firstWhere((l) => l['id'] == id);

  List<Map<String, dynamic>> _rows(Map<String, dynamic> l) =>
      (l['items'] as List).cast<Map<String, dynamic>>();

  Map<String, dynamic> _detail(Map<String, dynamic> l) => {
    ...l,
    'itemCount': _rows(l).where((r) => r['have'] != true).length,
  };

  List<Map<String, dynamic>> _sorted() => [...lists]
    ..sort(
      (a, b) => ((b['confirmedAt'] ?? b['createdAt']) as String).compareTo(
        (a['confirmedAt'] ?? a['createdAt']) as String,
      ),
    );

  @override
  Future<VanaActionResult> run(UiAction action) async {
    calls.add(action);
    if (failWith != null) throw failWith!;
    switch (action) {
      case GetShoppingListAction(:final id):
        final sorted = _sorted();
        final hit = id == null
            ? (sorted.isEmpty ? null : sorted.first)
            : _list(id);
        return VanaActionResult(
          parts: const [],
          extras: {'list': hit == null ? null : _detail(hit)},
        );
      case ListShoppingListsAction():
        return VanaActionResult(
          parts: const [],
          extras: {
            'lists': [
              for (final l in _sorted()) {..._detail(l)}..remove('items'),
            ],
          },
        );
      case CreateShoppingListAction(:final name):
        final made = {
          'id': 'list-${_seq++}',
          'planId': null,
          'name': name ?? 'List',
          'createdAt': '2026-09-20T00:00:00Z',
          'updatedAt': '2026-09-20T00:00:00Z',
          'confirmedAt': null,
          'items': <Map<String, dynamic>>[],
        };
        lists.add(made);
        return VanaActionResult(
          parts: const [],
          extras: {'list': _detail(made)},
        );
      case AddShoppingItemAction(:final listId, :final name, :final qty):
        final l = _list(listId);
        _rows(l).add({
          'id': 'row-${_seq++}',
          'listId': listId,
          'aisle': 'Other',
          'name': name,
          'qty': qty ?? '',
          'checked': false,
          'have': false,
          'fromMealIds': const <String>[],
          'source': 'manual',
          'edited': false,
          'position': _rows(l).length,
        });
        return VanaActionResult(parts: const [], extras: {'list': _detail(l)});
      case UpdateShoppingItemAction(
        :final id,
        :final name,
        :final qty,
        :final checked,
        :final have,
      ):
        for (final l in lists) {
          for (final r in _rows(l)) {
            if (r['id'] != id) continue;
            if (name != null) {
              r['name'] = name;
              r['edited'] = true;
            }
            if (qty != null) {
              r['qty'] = qty;
              r['edited'] = true;
            }
            if (checked != null) r['checked'] = checked;
            if (have != null) r['have'] = have;
            return VanaActionResult(
              parts: const [],
              extras: {'list': _detail(l)},
            );
          }
        }
        throw StateError('no row $id');
      case DeleteShoppingItemAction(:final id):
        for (final l in lists) {
          final rows = _rows(l);
          final i = rows.indexWhere((r) => r['id'] == id);
          if (i < 0) continue;
          if (rows[i]['source'] == 'plan') {
            rows[i]['have'] = true;
            rows[i]['edited'] = true;
          } else {
            rows.removeAt(i);
          }
          return VanaActionResult(
            parts: const [],
            extras: {'list': _detail(l)},
          );
        }
        throw StateError('no row $id');
      default:
        throw UnimplementedError(action.type);
    }
  }
}

Map<String, dynamic> _row(
  String id,
  String name,
  String aisle, {
  String source = 'plan',
  String qty = '1',
  bool checked = false,
  bool have = false,
  List<String> from = const ['pm-1'],
}) => {
  'id': id,
  'listId': 'list-plan',
  'aisle': aisle,
  'name': name,
  'qty': qty,
  'checked': checked,
  'have': have,
  'fromMealIds': from,
  'source': source,
  'edited': false,
  'position': 0,
};

void main() {
  late MealPlan plan;
  late _ShoppingServer server;

  setUp(() {
    plan = VanaActionResult.fromJson(loadFixture('batch')).plan!;
    server = _ShoppingServer([
      {
        'id': 'list-plan',
        'planId': plan.id,
        'name': 'Week of ${plan.weekStart}',
        'createdAt': '2026-09-13T00:00:00Z',
        'updatedAt': '2026-09-13T00:00:00Z',
        'confirmedAt': '2026-09-14T00:00:00Z',
        'items': [
          _row('r1', 'Broccoli', 'Produce', from: [plan.meals.first.id]),
          _row('r2', 'Chicken breast', 'Protein', qty: '2 lb'),
          _row('r3', 'Coffee', 'Beverages', source: 'manual', from: const []),
        ],
      },
      {
        'id': 'list-old',
        'planId': 'plan-old',
        'name': 'Week of 2026-09-06',
        'createdAt': '2026-09-06T00:00:00Z',
        'updatedAt': '2026-09-06T00:00:00Z',
        'confirmedAt': '2026-09-07T00:00:00Z',
        'items': [_row('o1', 'Oats', 'Pantry')],
      },
    ]);
  });

  ProviderContainer makeContainer({MealPlan? withPlan}) => testContainer([
    ...baseOverrides(),
    mealPlanControllerProvider.overrideWith(
      () => _FixedPlanController(withPlan ?? plan),
    ),
    vanaActionClientProvider.overrideWithValue(server),
  ]);

  test(
    'opens on the most recent list, with the earlier ones behind it',
    () async {
      final c = makeContainer();
      final state = await c.read(shoppingListControllerProvider.future);

      expect(state.listId, 'list-plan');
      expect(state.isCurrent, isTrue);
      expect(state.isConfirmed, isTrue);
      expect(state.planId, plan.id);
      expect(state.listName, 'Week of ${plan.weekStart}');
      expect(state.byAisle.keys, ['Produce', 'Protein', 'Beverages']);
      expect(state.itemCount, 3);
      expect(state.previous.map((l) => l.id), ['list-old']);
      expect(state.meals, plan.meals, reason: 'sources resolve from the plan');
      expect(state.sourcesOf(state.items.first).map((m) => m.id), [
        plan.meals.first.id,
      ]);
      expect(server.calls.map((a) => a.type), [
        'get_shopping_list',
        'list_shopping_lists',
      ]);
    },
  );

  test(
    'add: one add_shopping_item on the open list, the row shows under its aisle',
    () async {
      final c = makeContainer();
      await c.read(shoppingListControllerProvider.future);
      server.calls.clear();

      await c
          .read(shoppingListControllerProvider.notifier)
          .addItem('Paper towels', qty: '1 pack');

      final action = server.calls.single as AddShoppingItemAction;
      expect(action.listId, 'list-plan');
      expect(action.name, 'Paper towels');
      expect(action.qty, '1 pack');
      final state = c.read(shoppingListControllerProvider).value!;
      expect(state.byAisle['Other']!.single.name, 'Paper towels');
      expect(state.itemCount, 4);
      expect(state.previous.map((l) => l.id), ['list-old']);
    },
  );

  test(
    'edit: name and qty go up by row id; the row comes back edited',
    () async {
      final c = makeContainer();
      final before = await c.read(shoppingListControllerProvider.future);
      server.calls.clear();
      final chicken = before.items.firstWhere(
        (i) => i.name == 'Chicken breast',
      );

      await c
          .read(shoppingListControllerProvider.notifier)
          .updateItem(chicken, name: 'Chicken thighs', qty: '3 lb');

      final action = server.calls.single as UpdateShoppingItemAction;
      expect(action.id, 'r2');
      expect(action.name, 'Chicken thighs');
      expect(action.qty, '3 lb');
      final after = c.read(shoppingListControllerProvider).value!;
      final row =
          after.items.firstWhere((i) => i.name == 'Chicken thighs')
              as ShoppingListItem;
      expect(row.edited, isTrue);
      expect(row.qty, '3 lb');
    },
  );

  test('tick: optimistic, then update_shopping_item {checked}', () async {
    final c = makeContainer();
    await c.read(shoppingListControllerProvider.future);
    server.calls.clear();

    final done = c
        .read(shoppingListControllerProvider.notifier)
        .setChecked('broccoli', true);
    expect(
      c.read(shoppingListControllerProvider).value!.items.first.checked,
      isTrue,
      reason: 'ticked before the server answers',
    );
    await done;

    final action = server.calls.single as UpdateShoppingItemAction;
    expect(action.id, 'r1');
    expect(action.checked, isTrue);
    expect(action.have, isNull);
  });

  test(
    'delete: a manual row leaves; a plan row becomes a tombstone the tab hides',
    () async {
      final c = makeContainer();
      final before = await c.read(shoppingListControllerProvider.future);
      server.calls.clear();
      final n = c.read(shoppingListControllerProvider.notifier);

      await n.deleteItem(before.items.firstWhere((i) => i.name == 'Coffee'));
      expect((server.calls.last as DeleteShoppingItemAction).id, 'r3');
      var state = c.read(shoppingListControllerProvider).value!;
      expect(state.items.map((i) => i.name), ['Broccoli', 'Chicken breast']);

      await n.deleteItem(state.items.firstWhere((i) => i.name == 'Broccoli'));
      state = c.read(shoppingListControllerProvider).value!;
      expect(state.itemCount, 1);
      expect(state.skipped, [
        'Broccoli',
      ], reason: 'off the list, one Add back away');
    },
  );

  test(
    'new list: created, opened, and the plan list moves into history',
    () async {
      final c = makeContainer();
      await c.read(shoppingListControllerProvider.future);
      server.calls.clear();

      await c
          .read(shoppingListControllerProvider.notifier)
          .newList(name: 'Costco');

      expect(server.calls.first, isA<CreateShoppingListAction>());
      final state = c.read(shoppingListControllerProvider).value!;
      expect(state.listName, 'Costco');
      expect(state.isCurrent, isTrue);
      expect(state.planId, isNull);
      expect(state.isEmpty, isTrue);
      expect(state.hasAnyList, isTrue);
      expect(state.mealCount, 0);
      expect(state.previous.map((l) => l.id), ['list-plan', 'list-old']);
    },
  );

  test(
    'switch: an earlier list opens read-through-the-same-rows, then back to current',
    () async {
      final c = makeContainer();
      await c.read(shoppingListControllerProvider.future);
      server.calls.clear();
      final n = c.read(shoppingListControllerProvider.notifier);

      await n.openList('list-old');
      expect((server.calls.first as GetShoppingListAction).id, 'list-old');
      var state = c.read(shoppingListControllerProvider).value!;
      expect(state.listId, 'list-old');
      expect(state.isCurrent, isFalse);
      expect(state.previous.map((l) => l.id), ['list-plan']);
      expect(state.items.single.name, 'Oats');

      // still checkable, and the tick lands on the old list's row
      await n.setChecked('Oats', true);
      expect((server.calls.last as UpdateShoppingItemAction).id, 'o1');
      expect(c.read(shoppingListControllerProvider).value!.isCurrent, isFalse);

      await n.openCurrent();
      state = c.read(shoppingListControllerProvider).value!;
      expect(state.listId, 'list-plan');
      expect(state.isCurrent, isTrue);
    },
  );

  test('a failed write puts the list back and surfaces the error', () async {
    final c = makeContainer();
    final before = await c.read(shoppingListControllerProvider.future);
    server.failWith = StateError('offline');

    await expectLater(
      c.read(shoppingListControllerProvider.notifier).addItem('Milk'),
      throwsStateError,
    );
    final after = c.read(shoppingListControllerProvider).value!;
    expect(after.items.map((i) => i.name), before.items.map((i) => i.name));
    expect(after.listId, 'list-plan');
  });

  test('server unreachable: the plan mirror stands in, read-only', () async {
    server.failWith = StateError('offline');
    final c = makeContainer();
    final state = await c.read(shoppingListControllerProvider.future);

    expect(state.listId, isNull);
    expect(state.planId, plan.id);
    expect(state.items.map((i) => i.name), plan.shopping.map((i) => i.name));
    expect(state.previous, isEmpty);
    // a tick still shows on screen, but nothing is sent with no row to write to
    server.calls.clear();
    await c
        .read(shoppingListControllerProvider.notifier)
        .setChecked(plan.shopping.first.name, true);
    expect(
      c.read(shoppingListControllerProvider).value!.items.first.checked,
      isTrue,
    );
    expect(server.calls, isEmpty);
    await expectLater(
      c.read(shoppingListControllerProvider.notifier).addItem('Milk'),
      throwsStateError,
    );
  });

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
