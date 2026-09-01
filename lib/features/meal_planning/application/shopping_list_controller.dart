import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/meal_plan.dart';
import '../domain/shopping_item.dart';
import '../domain/ui_action.dart';
import 'meal_plan_controller.dart';

part 'shopping_list_controller.g.dart';

/// The Shopping tab's view of the active plan's list.
class ShoppingListState {
  const ShoppingListState({
    this.planId,
    this.isConfirmed = false,
    this.items = const [],
    this.byAisle = const {},
    this.itemCount = 0,
    this.skipped = const [],
    this.totalServings = 0,
    this.mealCount = 0,
  });

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

  bool get isEmpty => items.isEmpty;
}

/// Groups the active plan's `shopping` by aisle and routes the local-first
/// `checked` / `have` toggles through [MealPlanController].
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

  @override
  FutureOr<ShoppingListState> build() async {
    final plan = await ref.watch(mealPlanControllerProvider.future);
    return fromPlan(plan);
  }

  Future<void> setChecked(String name, bool value) =>
      _toggle(name, ShoppingField.checked, value);

  Future<void> setHave(String name, bool value) =>
      _toggle(name, ShoppingField.have, value);

  Future<void> _toggle(String name, ShoppingField field, bool value) async {
    final current = state.value;
    if (current == null || current.planId == null) return;
    // Optimistic: the Drift watch confirms a beat later.
    final target = name.trim().toLowerCase();
    final items = [
      for (final item in current.items)
        if (item.name.trim().toLowerCase() == target)
          switch (field) {
            ShoppingField.checked => item.copyWith(checked: value),
            ShoppingField.have => item.copyWith(have: value),
          }
        else
          item,
    ];
    state = AsyncData(
      _build(
        current.planId,
        current.isConfirmed,
        items,
        current.totalServings,
        current.mealCount,
      ),
    );
    state = await AsyncValue.guard(() async {
      await ref
          .read(mealPlanControllerProvider.notifier)
          .toggleShopping(name, field, value);
      return state.value ?? current;
    });
  }

  /// Plain-text export for the share sheet (one line per item, grouped by
  /// aisle). The title is the presentation layer's (content key).
  String shareText() {
    final current = state.value;
    if (current == null || current.isEmpty) return '';
    final buffer = StringBuffer();
    for (final entry in current.byAisle.entries) {
      buffer.writeln(entry.key);
      for (final item in entry.value) {
        if (item.have) continue;
        final mark = item.checked ? '[x]' : '[ ]';
        final qty = item.qty.isEmpty ? '' : ' — ${item.qty}';
        buffer.writeln('$mark ${item.name}$qty');
      }
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }

  /// Pure projection of a plan into the tab's state.
  static ShoppingListState fromPlan(MealPlan? plan) {
    if (plan == null) return const ShoppingListState();
    final servings = plan.meals.fold<int>(0, (sum, m) => sum + m.servings);
    return _build(
      plan.id,
      plan.isConfirmed,
      plan.shopping,
      servings,
      plan.meals.length,
    );
  }

  static ShoppingListState _build(
    String? planId,
    bool isConfirmed,
    List<ShoppingItem> items,
    int totalServings,
    int mealCount,
  ) {
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
    );
  }
}
