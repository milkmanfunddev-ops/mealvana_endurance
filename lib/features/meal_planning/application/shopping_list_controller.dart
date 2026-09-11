import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/providers/unit_system_provider.dart';
import '../../nutrition_plan/domain/run_parameters.dart';
import '../domain/meal_plan.dart';
import '../domain/plan_meal.dart';
import '../domain/shopping_item.dart';
import '../domain/ui_action.dart';
import 'meal_plan_controller.dart';
import 'shopping_qty_formatter.dart';

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
    this.meals = const [],
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

  /// The plan's meals, so a line's `fromMealIds` can be shown by name and
  /// tapped through to the recipe.
  final List<PlanMeal> meals;

  bool get isEmpty => items.isEmpty;

  /// The meals a line was built from, in plan order.
  List<PlanMeal> sourcesOf(ShoppingItem item) => [
    for (final meal in meals)
      if (item.fromMealIds.contains(meal.id)) meal,
  ];
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
        current.meals,
      ),
    );
    state = await AsyncValue.guard(() async {
      await ref
          .read(mealPlanControllerProvider.notifier)
          .toggleShopping(name, field, value);
      return state.value ?? current;
    });
  }

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
      plan.meals,
    );
  }

  static ShoppingListState _build(
    String? planId,
    bool isConfirmed,
    List<ShoppingItem> items,
    int totalServings,
    int mealCount,
    List<PlanMeal> meals,
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
      meals: meals,
    );
  }
}
