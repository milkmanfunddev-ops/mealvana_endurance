import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/providers/unit_system_provider.dart';
import '../../../shared/providers/user_id_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../../nutrition_plan/domain/run_parameters.dart';
import '../data/shopping_tick_store.dart';
import '../data/vana_action_client.dart';
import '../data/vana_exceptions.dart';
import '../domain/meal_plan.dart';
import '../domain/plan_meal.dart';
import '../domain/shopping_item.dart';
import '../domain/shopping_list.dart';
import '../domain/ui_action.dart';
import 'meal_plan_controller.dart';
import 'shopping_qty_formatter.dart';

part 'shopping_list_controller.g.dart';

/// The Shopping tab's view of one shopping list (2026-09-16: several lists,
/// each with its own rows — `shopping_lists` / `shopping_items`).
///
/// [listId] is the list on screen; [isCurrent] says whether it is the most
/// recent one (the one the tab opens on). [planId] is the plan whose meals
/// build the list, null for a hand-made list — Kroger keys on it.
class ShoppingListState {
  const ShoppingListState({
    this.listId,
    this.listName = '',
    this.listDate,
    this.isCurrent = true,
    this.planId,
    this.isConfirmed = false,
    this.items = const [],
    this.byAisle = const {},
    this.itemCount = 0,
    this.skipped = const [],
    this.totalServings = 0,
    this.mealCount = 0,
    this.meals = const [],
    this.previous = const [],
    this.weekPlanId,
    this.isOffline = false,
  });

  final String? listId;
  final String listName;

  /// True while the server is unreachable: the plan's offline copy is on
  /// screen, or the last write on the live list could not be sent. Ticks
  /// made meanwhile are kept on the device and sent when a call next
  /// succeeds (ticket 36).
  final bool isOffline;

  /// When the list was confirmed, else made.
  final DateTime? listDate;
  final bool isCurrent;
  final String? planId;
  final bool isConfirmed;
  final List<ShoppingItem> items;

  /// Aisle → items, in [ShoppingListController.aisleOrder] order (unknown
  /// aisles last, in first-seen order).
  final Map<String, List<ShoppingItem>> byAisle;

  /// Items not marked `have`.
  final int itemCount;

  /// Names left off because the athlete already has them.
  final List<String> skipped;
  final int totalServings;
  final int mealCount;

  /// The plan's meals, so a line's `fromMealIds` can be shown by name and
  /// tapped through to the recipe.
  final List<PlanMeal> meals;

  /// Every other list the athlete has, most recent first.
  final List<ShoppingListSummary> previous;

  /// This week's confirmed plan (the one the Plan tab shows), null while
  /// the week has none. Its list is marked in Previous lists so it stands
  /// apart from the lists of drafts that confirming archived (19-005).
  final String? weekPlanId;

  bool get isEmpty => items.isEmpty;

  /// What is left to buy: rows neither ticked nor already on hand. The share
  /// summary's number (Finding 89-002: "9 items to buy" while six were
  /// ticked); [itemCount] is the header's count of rows not on hand.
  int get toBuyCount => items.where((i) => !i.have && !i.checked).length;

  /// True once the account has any list at all, on screen or in
  /// [previous].
  bool get hasAnyList => listId != null || previous.isNotEmpty;

  /// The meals a line was built from, in plan order.
  List<PlanMeal> sourcesOf(ShoppingItem item) => [
    for (final meal in meals)
      if (item.fromMealIds.contains(meal.id)) meal,
  ];

  ShoppingListState copyWith({
    String? listName,
    List<ShoppingItem>? items,
    List<ShoppingListSummary>? previous,
    bool? isOffline,
  }) => ShoppingListController._build(
    listId: listId,
    listName: listName ?? this.listName,
    listDate: listDate,
    isCurrent: isCurrent,
    planId: planId,
    isConfirmed: isConfirmed,
    items: items ?? this.items,
    totalServings: totalServings,
    mealCount: mealCount,
    meals: meals,
    previous: previous ?? this.previous,
    weekPlanId: weekPlanId,
    isOffline: isOffline ?? this.isOffline,
  );
}

/// Reads the most recent list (or the one opened from "Previous lists")
/// through `vana-action`, groups it by aisle, and routes every edit — tick,
/// add, rename, delete, new list — back through the same actions. Each
/// write is optimistic on screen and settled by the server's answer.
///
/// Offline the server is unreachable, so the active plan's own mirror
/// (`meal_plans.shopping`, kept in Drift) stands in: the same lines, no
/// ids, no edits except ticks.
///
/// Ticks are local-first (ticket 36, Findings 20-001/20-002): each one is
/// written to [ShoppingTickStore] before `update_shopping_item` goes out
/// and dropped when the server answers. A transport failure keeps the tick
/// on screen and in the store, marks the state offline, and the tick is
/// replayed on the next build, on the next successful call, or by the
/// retry timer. A refusal the server answers (any other error) rolls the
/// tick back and rethrows so the screen can say so. The Drift mirror is
/// never written here: the server keeps `meal_plans.shopping` from
/// `shopping_items`, and a local replay of the mirror would clobber ticks
/// made online.
@riverpod
class ShoppingListController extends _$ShoppingListController {
  /// The design's aisle order (05 §4).
  static const aisleOrder = [
    'Produce',
    'Protein',
    'Dairy',
    'Bakery & Grains',
    'Pantry',
    'Spices',
    'Frozen',
    'Beverages',
    'Other',
  ];

  static const _context = 'SHOPPING_LIST';

  /// How often queued ticks are retried while the state is offline.
  static const retryEvery = Duration(seconds: 20);

  /// The list the athlete opened from history; null = the most recent one.
  String? _openedListId;

  String? _userId;
  Timer? _retry;

  @override
  FutureOr<ShoppingListState> build() async {
    // Riverpod reuses the notifier across invalidations: reset what a
    // previous build may have left.
    _retry?.cancel();
    _retry = null;
    ref.onDispose(() {
      _retry?.cancel();
      _retry = null;
    });
    _userId = await ref.watch(userIdProvider.future);
    // Every plan edit rebuilds the plan's list server-side, so the plan is
    // the signal to re-read; it is also the offline stand-in.
    final plan = await ref.watch(mealPlanControllerProvider.future);
    ShoppingListState loaded;
    try {
      loaded = await _load(plan, listId: _openedListId);
    } catch (e) {
      _logger.warning(
        'shopping list read failed; showing the plan mirror',
        context: _context,
        error: e,
      );
      return _offline(fromPlan(plan));
    }
    return _replay(loaded);
  }

  VanaActionClient get _client => ref.read(vanaActionClientProvider);
  ShoppingTickStore get _ticks => ref.read(shoppingTickStoreProvider);
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;

  Future<ShoppingListState> _load(MealPlan? plan, {String? listId}) async {
    final result = await _client.run(GetShoppingListAction(id: listId));
    final lists = (await _client.run(
      const ListShoppingListsAction(),
    )).shoppingLists;
    return _fromDetail(result.shoppingList, lists, plan);
  }

  ShoppingListState _fromDetail(
    ShoppingListDetail? list,
    List<ShoppingListSummary> lists,
    MealPlan? plan,
  ) {
    final weekPlanId = plan != null && plan.isConfirmed ? plan.id : null;
    if (list == null) {
      return _build(previous: lists, isCurrent: true, weekPlanId: weekPlanId);
    }
    final current = lists.isEmpty ? list.id : lists.first.id;
    final planMeals = plan != null && plan.id == list.planId
        ? plan.meals
        : const <PlanMeal>[];
    return _build(
      listId: list.id,
      listName: list.name,
      listDate: list.sortDate,
      isCurrent: list.id == current,
      planId: list.planId,
      isConfirmed: list.confirmedAt != null,
      items: list.items,
      totalServings: planMeals.fold<int>(0, (sum, m) => sum + m.servings),
      mealCount: planMeals.length,
      meals: planMeals,
      previous: [
        for (final l in lists)
          if (l.id != list.id) l,
      ],
      weekPlanId: weekPlanId,
    );
  }

  // ── Toggles ───────────────────────────────────────────────────────────────

  Future<void> setChecked(String name, bool value) async {
    await _toggle(name, ShoppingField.checked, value);
  }

  Future<void> setHave(String name, bool value) async {
    await _toggle(name, ShoppingField.have, value);
  }

  Future<void> _toggle(String name, ShoppingField field, bool value) async {
    final current = state.value;
    final userId = _userId;
    if (current == null || userId == null) return;
    final row = _rowNamed(current, name);
    // Optimistic: the server's answer settles it a beat later.
    final ticked = current.copyWith(
      items: _flipped(current.items, name, field, value),
    );
    state = AsyncData(ticked);
    // Local write first: the tick is on the device before anything is sent.
    final tick = PendingShoppingTick(
      name: name,
      field: field,
      value: value,
      at: DateTime.now(),
      listId: current.listId,
      planId: current.planId,
      rowId: row?.id,
    );
    await _ticks.add(userId, tick);
    if (row == null) {
      // The offline copy has no ids to write to; the tick waits for the
      // live list (matched by name on the plan's list).
      _armRetry();
      return;
    }
    try {
      await _settle(current, () => _client.run(_updateFor(row.id, tick)));
    } on VanaOfflineException catch (e) {
      // Kept, not lost: the tick stays on screen and in the store.
      _logger.warning(
        'shopping tick queued: transport down',
        context: _context,
        error: e,
      );
      state = AsyncData(ticked.copyWith(isOffline: true));
      _armRetry();
      return;
    } catch (_) {
      // The server answered and said no: nothing to replay.
      await _ticks.remove(userId, tick);
      rethrow;
    }
    await _ticks.remove(userId, tick);
  }

  /// Send every queued tick that belongs to the list on screen. Public so
  /// the retry timer and a future reconnect hook share one path; safe to
  /// call at any time (a no-op with nothing queued).
  Future<void> retryPending() async {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(await _replay(current));
  }

  /// [loaded] with its queued ticks sent (by row id, or by name on the
  /// plan's list for ticks made on the offline copy), each dropped from the
  /// store as the server answers. Stops at the first transport failure and
  /// overlays what is left, marked offline. A tick the server refuses, or
  /// one whose line no longer exists, is dropped and logged.
  Future<ShoppingListState> _replay(ShoppingListState loaded) async {
    final userId = _userId;
    if (userId == null) return loaded;
    var current = loaded;
    for (final tick in _ticks.read(userId)) {
      if (!tick.appliesTo(listId: current.listId, planId: current.planId)) {
        continue; // another list's tick; it waits for that list
      }
      final rowId = tick.rowId ?? _rowNamed(current, tick.name)?.id;
      if (rowId == null) {
        _logger.warning(
          'shopping tick dropped: no row for "${tick.name}"',
          context: _context,
        );
        await _ticks.remove(userId, tick);
        continue;
      }
      try {
        final result = await _client.run(_updateFor(rowId, tick));
        final list = result.shoppingList;
        if (list != null) {
          current = _fromDetail(
            list,
            _summariesWith(current, list),
            ref.read(mealPlanControllerProvider).value,
          );
        }
        await _ticks.remove(userId, tick);
      } on VanaOfflineException catch (e) {
        _logger.warning(
          'shopping tick replay stopped: transport down',
          context: _context,
          error: e,
        );
        return _offline(current);
      } catch (e) {
        _logger.warning(
          'shopping tick dropped: server refused "${tick.name}"',
          context: _context,
          error: e,
        );
        await _ticks.remove(userId, tick);
      }
    }
    _retry?.cancel();
    _retry = null;
    return current;
  }

  /// [base] as the offline view: queued ticks laid over its lines and the
  /// offline flag set, with the retry timer armed.
  ShoppingListState _offline(ShoppingListState base) {
    _armRetry();
    return _withPending(base).copyWith(isOffline: true);
  }

  ShoppingListState _withPending(ShoppingListState base) {
    final userId = _userId;
    if (userId == null) return base;
    var items = base.items;
    for (final tick in _ticks.read(userId)) {
      if (!tick.appliesTo(listId: base.listId, planId: base.planId)) continue;
      items = _flipped(items, tick.name, tick.field, tick.value);
    }
    return identical(items, base.items) ? base : base.copyWith(items: items);
  }

  void _armRetry() {
    if (_retry != null) return;
    _retry = Timer.periodic(retryEvery, (_) {
      if (!ref.mounted) return;
      unawaited(retryPending());
    });
  }

  static UpdateShoppingItemAction _updateFor(
    String rowId,
    PendingShoppingTick tick,
  ) => UpdateShoppingItemAction(
    id: rowId,
    checked: tick.field == ShoppingField.checked ? tick.value : null,
    have: tick.field == ShoppingField.have ? tick.value : null,
  );

  static List<ShoppingItem> _flipped(
    List<ShoppingItem> items,
    String name,
    ShoppingField field,
    bool value,
  ) {
    final target = name.trim().toLowerCase();
    return [
      for (final item in items)
        if (item.name.trim().toLowerCase() == target)
          switch (field) {
            ShoppingField.checked => item.copyWith(checked: value),
            ShoppingField.have => item.copyWith(have: value),
          }
        else
          item,
    ];
  }

  // ── Rows ──────────────────────────────────────────────────────────────────

  /// Add a hand-written line to the list on screen. Aisle is the server's
  /// guess. Throws when there is no list to add to (offline mirror).
  Future<void> addItem(String name, {String qty = ''}) async {
    final current = state.value;
    final listId = current?.listId;
    if (current == null || listId == null) {
      throw StateError('no shopping list to add to');
    }
    await _settle(
      current,
      () => _client.run(
        AddShoppingItemAction(listId: listId, name: name.trim(), qty: qty),
      ),
    );
  }

  /// Rename a line and/or change its amount. Either edit keeps the line
  /// through the next re-plan.
  Future<void> updateItem(
    ShoppingItem item, {
    required String name,
    required String qty,
  }) async {
    final current = state.value;
    final row = current == null ? null : _rowFor(current, item);
    if (current == null || row == null) {
      throw StateError('no shopping row to edit');
    }
    await _settle(
      current,
      () => _client.run(
        UpdateShoppingItemAction(id: row.id, name: name.trim(), qty: qty),
      ),
    );
  }

  Future<void> deleteItem(ShoppingItem item) async {
    final current = state.value;
    final row = current == null ? null : _rowFor(current, item);
    if (current == null || row == null) {
      throw StateError('no shopping row to delete');
    }
    state = AsyncData(
      current.copyWith(
        items: [
          for (final i in current.items)
            if (!identical(i, item) && i.name != item.name) i,
        ],
      ),
    );
    await _settle(
      current,
      () => _client.run(DeleteShoppingItemAction(id: row.id)),
    );
  }

  // ── Lists ─────────────────────────────────────────────────────────────────

  /// Start a new hand-made list and open it. The plan's own list stays in
  /// history.
  Future<void> newList({String? name}) async {
    final current = state.value ?? const ShoppingListState();
    state = await AsyncValue.guard(() async {
      final made = await _client.run(CreateShoppingListAction(name: name));
      final list = made.shoppingList;
      if (list == null) {
        throw StateError('create_shopping_list returned no list');
      }
      _openedListId = null; // the new list is the most recent, so no pin
      final lists = (await _client.run(
        const ListShoppingListsAction(),
      )).shoppingLists;
      return _fromDetail(
        list,
        lists,
        ref.read(mealPlanControllerProvider).value,
      );
    });
    if (state.hasError) {
      final error = state.error!;
      final stack = state.stackTrace;
      state = AsyncData(current);
      Error.throwWithStackTrace(error, stack ?? StackTrace.current);
    }
  }

  /// Rename the list on screen, or — from the previous-lists sheet — the
  /// list [id] names. The new name shows at once; the server's answer
  /// settles it, and a failure puts the old name back.
  Future<void> renameList(String name, {String? id}) async {
    final current = state.value;
    final clean = name.trim();
    final target = id ?? current?.listId;
    if (current == null || target == null || clean.isEmpty) {
      throw StateError('no shopping list to rename');
    }
    if (target == current.listId) {
      state = AsyncData(current.copyWith(listName: clean));
      await _settle(
        current,
        () => _client.run(RenameShoppingListAction(id: target, name: clean)),
      );
      return;
    }
    state = AsyncData(
      current.copyWith(
        previous: [
          for (final l in current.previous)
            if (l.id == target) _renamed(l, clean) else l,
        ],
      ),
    );
    final next = await AsyncValue.guard(() async {
      final answer = await _client.run(
        RenameShoppingListAction(id: target, name: clean),
      );
      final list = answer.shoppingList;
      if (list == null) return state.value ?? current;
      return current.copyWith(
        previous: [
          for (final l in current.previous)
            if (l.id == target) list else l,
        ],
      );
    });
    if (next.hasError) {
      state = AsyncData(current);
      Error.throwWithStackTrace(next.error!, next.stackTrace!);
    }
    state = next;
  }

  /// Delete a list and every row on it. When it is the list on screen the
  /// tab falls back to the most recent one left (or the empty state);
  /// otherwise it just leaves history. Same shape as [newList]: the whole
  /// state is re-read from the server, and a failure puts today's back.
  Future<void> deleteList(String id) async {
    final current = state.value ?? const ShoppingListState();
    final pinned = _openedListId;
    if (id != current.listId) {
      // Optimistic: the row leaves history before the server answers.
      state = AsyncData(
        current.copyWith(
          previous: [
            for (final l in current.previous)
              if (l.id != id) l,
          ],
        ),
      );
    } else if (_openedListId == id) {
      _openedListId = null;
    }
    state = await AsyncValue.guard(() async {
      await _client.run(DeleteShoppingListAction(id: id));
      return _load(
        ref.read(mealPlanControllerProvider).value,
        listId: _openedListId,
      );
    });
    if (state.hasError) {
      final error = state.error!;
      final stack = state.stackTrace;
      _openedListId = pinned;
      state = AsyncData(current);
      Error.throwWithStackTrace(error, stack ?? StackTrace.current);
    }
  }

  static ShoppingListSummary _renamed(ShoppingListSummary l, String name) =>
      ShoppingListSummary(
        id: l.id,
        planId: l.planId,
        name: name,
        createdAt: l.createdAt,
        updatedAt: l.updatedAt,
        confirmedAt: l.confirmedAt,
        itemCount: l.itemCount,
      );

  /// Open a list from "Previous lists" (still checkable).
  Future<void> openList(String listId) => _switchTo(listId);

  /// Back to the most recent list.
  Future<void> openCurrent() => _switchTo(null);

  Future<void> _switchTo(String? listId) async {
    final current = state.value ?? const ShoppingListState();
    _openedListId = listId;
    state = await AsyncValue.guard(
      () => _load(ref.read(mealPlanControllerProvider).value, listId: listId),
    );
    if (state.hasError) {
      final error = state.error!;
      final stack = state.stackTrace;
      _openedListId = current.isCurrent ? null : current.listId;
      state = AsyncData(current);
      Error.throwWithStackTrace(error, stack ?? StackTrace.current);
    }
  }

  /// Run one write, fold the answered list into state, and on failure put
  /// [before] back and rethrow so the screen can say so.
  Future<void> _settle(
    ShoppingListState before,
    Future<VanaActionResult> Function() write,
  ) async {
    final next = await AsyncValue.guard(() async {
      final result = await write();
      final list = result.shoppingList;
      if (list == null) return state.value ?? before;
      return _fromDetail(
        list,
        _summariesWith(before, list),
        ref.read(mealPlanControllerProvider).value,
      );
    });
    if (next.hasError) {
      state = AsyncData(before);
      Error.throwWithStackTrace(next.error!, next.stackTrace!);
    }
    state = next;
  }

  /// The history the tab already holds, with the list on screen in front
  /// — enough to keep [ShoppingListState.previous] right without a second
  /// round trip.
  static List<ShoppingListSummary> _summariesWith(
    ShoppingListState before,
    ShoppingListDetail list,
  ) {
    final others = [
      for (final l in before.previous)
        if (l.id != list.id) l,
    ];
    // Sorted the way the server sorts, so `isCurrent` reads the same here
    // as after a fresh load — including while viewing an earlier list.
    return [...others, list]..sort((a, b) => b.sortDate.compareTo(a.sortDate));
  }

  static ShoppingListItem? _rowFor(ShoppingListState s, ShoppingItem item) =>
      item is ShoppingListItem ? item : _rowNamed(s, item.name);

  static ShoppingListItem? _rowNamed(ShoppingListState s, String name) {
    final target = name.trim().toLowerCase();
    for (final i in s.items) {
      if (i is ShoppingListItem && i.name.trim().toLowerCase() == target) {
        return i;
      }
    }
    return null;
  }

  // ── Share ─────────────────────────────────────────────────────────────────

  /// Plain-text export for the native share sheet, grouped by aisle.
  String shareText({required String title, required String summary}) {
    final current = state.value;
    if (current == null || current.isEmpty) return '';
    final units = ref.read(unitSystemProvider).value ?? UnitSystem.imperial;
    return formatShareText(
      current,
      title: title,
      summary: summary,
      units: units,
    );
  }

  /// Formats a shopping list for Messages, Mail, Notes, Reminders, and other
  /// text destinations exposed by the platform share sheet. Quantities are
  /// rendered in [units] (metric passes the server's own text through).
  static String formatShareText(
    ShoppingListState current, {
    required String title,
    required String summary,
    UnitSystem units = UnitSystem.metric,
  }) {
    final buffer = StringBuffer();
    buffer
      ..writeln(title)
      ..writeln(summary)
      ..writeln();

    for (final entry in current.byAisle.entries) {
      final needed = entry.value.where((item) => !item.have).toList();
      if (needed.isEmpty) continue;

      buffer.writeln(entry.key.toUpperCase());
      for (final item in needed) {
        final mark = item.checked ? '☑' : '☐';
        final shown = formatShoppingQty(item.qty, units);
        final qty = shown.isEmpty ? '' : ' — $shown';
        buffer.writeln('$mark ${item.name}$qty');
      }
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }

  // ── Projections ───────────────────────────────────────────────────────────

  /// The offline stand-in: the active plan's mirrored lines, no list id.
  static ShoppingListState fromPlan(MealPlan? plan) {
    if (plan == null) return const ShoppingListState();
    final servings = plan.meals.fold<int>(0, (sum, m) => sum + m.servings);
    return _build(
      planId: plan.id,
      isConfirmed: plan.isConfirmed,
      items: plan.shopping,
      totalServings: servings,
      mealCount: plan.meals.length,
      meals: plan.meals,
      weekPlanId: plan.isConfirmed ? plan.id : null,
    );
  }

  static ShoppingListState _build({
    String? listId,
    String listName = '',
    DateTime? listDate,
    bool isCurrent = true,
    String? planId,
    bool isConfirmed = false,
    List<ShoppingItem> items = const [],
    int totalServings = 0,
    int mealCount = 0,
    List<PlanMeal> meals = const [],
    List<ShoppingListSummary> previous = const [],
    String? weekPlanId,
    bool isOffline = false,
  }) {
    final grouped = <String, List<ShoppingItem>>{};
    for (final aisle in aisleOrder) {
      final inAisle = items.where((i) => i.aisle == aisle).toList();
      if (inAisle.isNotEmpty) grouped[aisle] = inAisle;
    }
    for (final item in items) {
      if (aisleOrder.contains(item.aisle)) continue;
      grouped
          .putIfAbsent(item.aisle.isEmpty ? 'Other' : item.aisle, () => [])
          .add(item);
    }
    return ShoppingListState(
      listId: listId,
      listName: listName,
      listDate: listDate,
      isCurrent: isCurrent,
      planId: planId,
      isConfirmed: isConfirmed,
      items: items,
      byAisle: Map.unmodifiable(grouped),
      itemCount: items.where((i) => !i.have).length,
      skipped: [
        for (final i in items)
          if (i.have) i.name,
      ],
      totalServings: totalServings,
      mealCount: mealCount,
      meals: meals,
      previous: previous,
      weekPlanId: weekPlanId,
      isOffline: isOffline,
    );
  }
}
