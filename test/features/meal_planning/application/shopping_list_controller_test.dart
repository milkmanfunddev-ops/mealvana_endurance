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
import 'package:mealvana_endurance/features/meal_planning/data/shopping_tick_store.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_action_client.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_exceptions.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan_status.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/shopping_item.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/shopping_list.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/shopping_list_name.dart';
import 'package:mealvana_endurance/shared/services/prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      case RenameShoppingListAction(:final id, :final name):
        final l = _list(id);
        l['name'] = name;
        return VanaActionResult(parts: const [], extras: {'list': _detail(l)});
      case DeleteShoppingListAction(:final id):
        if (!lists.any((l) => l['id'] == id)) throw StateError('no list $id');
        lists.removeWhere((l) => l['id'] == id);
        final sorted = _sorted();
        return VanaActionResult(
          parts: const [],
          extras: {'list': sorted.isEmpty ? null : _detail(sorted.first)},
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
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
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
    sharedPreferencesProvider.overrideWithValue(prefs),
  ]);

  // ── Ticks made offline (testing-wave ticket 36, Findings 20-001/20-002) ──

  group('offline ticks', () {
    test('live list, transport down: the tick stays on screen, is queued, and '
        'the state says offline', () async {
      final c = makeContainer();
      await c.read(shoppingListControllerProvider.future);
      server.calls.clear();
      server.failWith = const VanaOfflineException('unreachable');

      await c
          .read(shoppingListControllerProvider.notifier)
          .setChecked('Broccoli', true);

      final state = c.read(shoppingListControllerProvider).value!;
      expect(state.items.first.checked, isTrue, reason: 'not rolled back');
      expect(state.isOffline, isTrue);
      expect(state.listId, 'list-plan');
      final pending = c.read(shoppingTickStoreProvider).read('user-1');
      expect(pending.single.rowId, 'r1');
      expect(pending.single.field, ShoppingField.checked);
      expect(pending.single.value, isTrue);
    });

    test('offline copy: a tick survives a restart offline and reaches '
        'update_shopping_item {checked} once the server answers', () async {
      final name = plan.shopping.first.name;
      // The server's row for the same line, so the replay has an id.
      (server.lists.first['items'] as List).add(
        _row('r9', name, 'Produce', from: const []),
      );
      server.failWith = const VanaOfflineException('unreachable');

      // 1. Offline: the mirror stands in; the tick is kept.
      final first = makeContainer();
      final mirror = await first.read(shoppingListControllerProvider.future);
      expect(mirror.listId, isNull);
      expect(mirror.isOffline, isTrue);
      await first
          .read(shoppingListControllerProvider.notifier)
          .setChecked(name, true);
      expect(
        first.read(shoppingListControllerProvider).value!.items.first.checked,
        isTrue,
      );
      first.dispose();

      // 2. Restart, still offline: the tick shows on the mirror again.
      final second = makeContainer();
      final again = await second.read(shoppingListControllerProvider.future);
      expect(again.listId, isNull);
      expect(
        again.items.firstWhere((i) => i.name == name).checked,
        isTrue,
        reason: 'the queued tick overlays the plan mirror',
      );
      second.dispose();

      // 3. Restart online: the live list loads and the tick is sent by id.
      server.failWith = null;
      server.calls.clear();
      final third = makeContainer();
      final live = await third.read(shoppingListControllerProvider.future);

      expect(live.listId, 'list-plan');
      expect(live.isOffline, isFalse);
      final sent = server.calls.whereType<UpdateShoppingItemAction>().single;
      expect(sent.id, 'r9');
      expect(sent.checked, isTrue);
      expect(sent.have, isNull);
      expect(live.items.firstWhere((i) => i.name == name).checked, isTrue);
      expect(third.read(shoppingTickStoreProvider).read('user-1'), isEmpty);
      expect(
        (server.lists.first['items'] as List).cast<Map>().firstWhere(
          (r) => r['id'] == 'r9',
        )['checked'],
        isTrue,
        reason: 'shopping_items.checked agrees',
      );
    });

    test(
      'a live tick queued offline is sent once a later call succeeds',
      () async {
        final c = makeContainer();
        await c.read(shoppingListControllerProvider.future);
        server.failWith = const VanaOfflineException('unreachable');
        final n = c.read(shoppingListControllerProvider.notifier);
        await n.setChecked('Broccoli', true);
        server.failWith = null;
        server.calls.clear();

        await n.retryPending();

        final sent = server.calls.whereType<UpdateShoppingItemAction>().single;
        expect(sent.id, 'r1');
        expect(sent.checked, isTrue);
        final state = c.read(shoppingListControllerProvider).value!;
        expect(state.isOffline, isFalse);
        expect(state.items.first.checked, isTrue);
        expect(c.read(shoppingTickStoreProvider).read('user-1'), isEmpty);
      },
    );

    test('a write the server refuses rolls back, rethrows, and leaves nothing '
        'queued', () async {
      final c = makeContainer();
      await c.read(shoppingListControllerProvider.future);
      server.failWith = const VanaServerException(500, 'boom');

      await expectLater(
        c
            .read(shoppingListControllerProvider.notifier)
            .setChecked('Broccoli', true),
        throwsA(isA<VanaServerException>()),
      );

      final state = c.read(shoppingListControllerProvider).value!;
      expect(state.items.first.checked, isFalse);
      expect(state.isOffline, isFalse);
      expect(c.read(shoppingTickStoreProvider).read('user-1'), isEmpty);
    });
  });

  test("names this week's confirmed plan, so Previous lists can mark its list "
      '(19-005); a draft names none', () async {
    final draft = makeContainer();
    expect(
      (await draft.read(shoppingListControllerProvider.future)).weekPlanId,
      isNull,
    );

    final confirmed = makeContainer(
      withPlan: plan.copyWith(status: MealPlanStatus.confirmed),
    );
    final state = await confirmed.read(shoppingListControllerProvider.future);
    expect(state.weekPlanId, plan.id);
    // it survives a local edit of the state
    expect(state.copyWith(listName: 'Renamed').weekPlanId, plan.id);
  });

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

  // ── Rename and delete a list (Shopping tab redesign, 2026-09-16) ──────────

  test('rename: the open list, by id, name settled from the answer', () async {
    final c = makeContainer();
    await c.read(shoppingListControllerProvider.future);
    server.calls.clear();

    await c
        .read(shoppingListControllerProvider.notifier)
        .renameList('  Big shop ');

    final action = server.calls.single as RenameShoppingListAction;
    expect(action.id, 'list-plan');
    expect(action.name, 'Big shop');
    final state = c.read(shoppingListControllerProvider).value!;
    expect(state.listName, 'Big shop');
    expect(state.listId, 'list-plan');
    expect(state.itemCount, 3, reason: 'the rows are untouched');
    expect(state.previous.map((l) => l.id), ['list-old']);
  });

  test(
    'rename: a list in history changes name there, the open list does not',
    () async {
      final c = makeContainer();
      await c.read(shoppingListControllerProvider.future);
      server.calls.clear();

      await c
          .read(shoppingListControllerProvider.notifier)
          .renameList('Last week', id: 'list-old');

      expect((server.calls.single as RenameShoppingListAction).id, 'list-old');
      final state = c.read(shoppingListControllerProvider).value!;
      expect(state.listId, 'list-plan');
      expect(state.listName, 'Week of ${plan.weekStart}');
      expect(state.previous.single.name, 'Last week');
    },
  );

  /// Ticket 130 (Finding 89-015, Lee: all four). A rename to a name another
  /// list has takes the next free " (n)"; names cap at 60 like plan names.
  /// The app works the name out from the lists it knows and sends that; the
  /// server does the same over the table (shopping_lists.test.ts), so the
  /// two agree.
  group('rename: names are unique and capped (89-015)', () {
    test('uniqueShoppingListName: the next free number, the cap kept', () {
      expect(uniqueShoppingListName('Big shop', ['Costco']), 'Big shop');
      expect(uniqueShoppingListName('Big shop', ['big shop']), 'Big shop (2)');
      expect(
        uniqueShoppingListName('Big shop', ['Big shop', 'Big shop (2)']),
        'Big shop (3)',
      );
      // A typed " (2)" that is taken counts up from its base.
      expect(
        uniqueShoppingListName('Big shop (2)', ['Big shop (2)']),
        'Big shop (3)',
      );
      // Whitespace is collapsed and the cap is 60 (PLAN_NAME_MAX), suffix
      // included.
      expect(cleanShoppingListName('  Big   shop '), 'Big shop');
      expect(cleanShoppingListName('x' * 70).length, shoppingListNameMax);
      final long = uniqueShoppingListName('x' * 60, ['x' * 60]);
      expect(long.length, lessThanOrEqualTo(shoppingListNameMax));
      expect(long, endsWith(' (2)'));
    });

    test('a name another list has is sent with " (2)"', () async {
      final c = makeContainer();
      await c.read(shoppingListControllerProvider.future);
      server.calls.clear();

      await c
          .read(shoppingListControllerProvider.notifier)
          .renameList('Week of 2026-09-06');

      final action = server.calls.single as RenameShoppingListAction;
      expect(action.name, 'Week of 2026-09-06 (2)');
      final state = c.read(shoppingListControllerProvider).value!;
      expect(state.listName, 'Week of 2026-09-06 (2)');
    });

    test('renaming a list to its own name is not a duplicate', () async {
      final c = makeContainer();
      final before = await c.read(shoppingListControllerProvider.future);
      server.calls.clear();

      await c
          .read(shoppingListControllerProvider.notifier)
          .renameList(before.listName);

      expect((server.calls.single as RenameShoppingListAction).name, before.listName);
    });

    test('a long name is capped at 60 before it is sent', () async {
      final c = makeContainer();
      await c.read(shoppingListControllerProvider.future);
      server.calls.clear();

      await c
          .read(shoppingListControllerProvider.notifier)
          .renameList('y' * 123);

      expect((server.calls.single as RenameShoppingListAction).name.length, 60);
    });
  });

  test('rename: a blank name is refused before anything is sent', () async {
    final c = makeContainer();
    await c.read(shoppingListControllerProvider.future);
    server.calls.clear();

    await expectLater(
      c.read(shoppingListControllerProvider.notifier).renameList('   '),
      throwsStateError,
    );
    expect(server.calls, isEmpty);
  });

  test('rename: a failed write puts the old name back', () async {
    final c = makeContainer();
    final before = await c.read(shoppingListControllerProvider.future);
    server.failWith = StateError('offline');

    await expectLater(
      c.read(shoppingListControllerProvider.notifier).renameList('Nope'),
      throwsStateError,
    );
    expect(
      c.read(shoppingListControllerProvider).value!.listName,
      before.listName,
    );
  });

  test(
    'delete: the open list goes and the most recent one left takes its place',
    () async {
      final c = makeContainer();
      await c.read(shoppingListControllerProvider.future);
      server.calls.clear();

      await c
          .read(shoppingListControllerProvider.notifier)
          .deleteList('list-plan');

      expect(server.calls.map((a) => a.type), [
        'delete_shopping_list',
        'get_shopping_list',
        'list_shopping_lists',
      ]);
      expect((server.calls.first as DeleteShoppingListAction).id, 'list-plan');
      final state = c.read(shoppingListControllerProvider).value!;
      expect(state.listId, 'list-old');
      expect(state.isCurrent, isTrue);
      expect(state.previous, isEmpty);
      expect(state.items.single.name, 'Oats');
    },
  );

  test(
    'delete: a list in history leaves history, the open list stays',
    () async {
      final c = makeContainer();
      await c.read(shoppingListControllerProvider.future);
      server.calls.clear();

      await c
          .read(shoppingListControllerProvider.notifier)
          .deleteList('list-old');

      final state = c.read(shoppingListControllerProvider).value!;
      expect(state.listId, 'list-plan');
      expect(state.previous, isEmpty);
      expect(state.itemCount, 3);
    },
  );

  test('delete: the last list leaves the empty state', () async {
    final c = makeContainer();
    await c.read(shoppingListControllerProvider.future);
    final n = c.read(shoppingListControllerProvider.notifier);

    await n.deleteList('list-old');
    await n.deleteList('list-plan');

    final state = c.read(shoppingListControllerProvider).value!;
    expect(state.listId, isNull);
    expect(state.hasAnyList, isFalse);
    expect(state.isEmpty, isTrue);
  });

  test(
    'delete: an earlier list opened from history falls back to the current one',
    () async {
      final c = makeContainer();
      await c.read(shoppingListControllerProvider.future);
      final n = c.read(shoppingListControllerProvider.notifier);
      await n.openList('list-old');
      expect(c.read(shoppingListControllerProvider).value!.isCurrent, isFalse);

      await n.deleteList('list-old');

      final state = c.read(shoppingListControllerProvider).value!;
      expect(state.listId, 'list-plan');
      expect(state.isCurrent, isTrue);
      expect(state.previous, isEmpty);
    },
  );

  test('delete: a failed write puts today\'s lists back', () async {
    final c = makeContainer();
    final before = await c.read(shoppingListControllerProvider.future);
    server.failWith = StateError('offline');
    final n = c.read(shoppingListControllerProvider.notifier);

    await expectLater(n.deleteList('list-old'), throwsStateError);
    var state = c.read(shoppingListControllerProvider).value!;
    expect(state.previous.map((l) => l.id), ['list-old']);

    await expectLater(n.deleteList('list-plan'), throwsStateError);
    state = c.read(shoppingListControllerProvider).value!;
    expect(state.listId, before.listId);
    expect(state.items.map((i) => i.name), before.items.map((i) => i.name));
  });

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

  /// Ticket 130 (Finding 89-002): "9 items to buy" while six were ticked.
  /// The share summary counts what is left to buy: rows neither ticked nor
  /// already on hand. The header's "9 items" ([ShoppingListState.itemCount])
  /// still counts every row not on hand.
  test('the share count leaves out ticked rows and rows on hand', () {
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
    );

    expect(state.itemCount, 2);
    expect(state.toBuyCount, 1, reason: 'Bananas are ticked, oil is on hand');
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
