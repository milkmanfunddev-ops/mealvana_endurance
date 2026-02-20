import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/food_item_data.dart';
import '../domain/nutrition_plan.dart';

/// Client-side proportional scaling for template-based food items.
///
/// When a user changes the quantity of one food item in a sub-phase,
/// this service calculates the proportional multiplier and applies it
/// to all sibling items, then snaps each to a friendly fraction.
class ProportionalScalingService {
  /// Friendly fractions that users can see
  static const _friendlyFractions = [
    0.25, 0.33, 0.5, 0.67, 0.75, 1.0,
    1.25, 1.33, 1.5, 1.67, 1.75, 2.0,
    2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 6.0,
  ];

  /// Snap a value to the nearest friendly fraction
  static double _snapToFriendly(double value) {
    if (value <= 0) return 0;

    double closest = _friendlyFractions[0];
    double minDist = (value - closest).abs();

    for (final frac in _friendlyFractions) {
      final dist = (value - frac).abs();
      if (dist < minDist) {
        minDist = dist;
        closest = frac;
      }
    }

    return closest;
  }

  /// Scale all items in a sub-phase proportionally when one item's quantity changes.
  ///
  /// [items] - Current food items in the sub-phase
  /// [changedIndex] - Index of the item that was changed
  /// [newQuantity] - New quantity for the changed item
  ///
  /// Returns updated list of FoodItemData with proportionally scaled quantities.
  static List<FoodItemData> scaleProportionally(
    List<FoodItemData> items,
    int changedIndex,
    double newQuantity,
  ) {
    if (items.isEmpty || changedIndex < 0 || changedIndex >= items.length) {
      return items;
    }

    final changedItem = items[changedIndex];
    final oldQuantity = double.tryParse(changedItem.quantity) ?? 1.0;

    if (oldQuantity <= 0) return items;

    // Calculate multiplier ratio
    final multiplier = newQuantity / oldQuantity;

    return items.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;

      if (index == changedIndex) {
        // The changed item gets the exact new quantity
        final snapped = _snapToFriendly(newQuantity);
        return _updateItemQuantity(item, snapped, multiplier);
      }

      // All other items scale proportionally
      final currentQty = double.tryParse(item.quantity) ?? 1.0;
      final scaledQty = currentQty * multiplier;
      final snapped = _snapToFriendly(scaledQty);

      return _updateItemQuantity(item, snapped, multiplier);
    }).toList();
  }

  /// Update a food item's quantity and recalculate nutrition
  static FoodItemData _updateItemQuantity(
    FoodItemData item,
    double newQuantity,
    double multiplier,
  ) {
    final oldQuantity = double.tryParse(item.quantity) ?? 1.0;
    final ratio = oldQuantity > 0 ? newQuantity / oldQuantity : 1.0;

    // Scale nutritional values
    NutritionalInfo? scaledNutrition;
    if (item.nutritionalInfo != null) {
      final info = item.nutritionalInfo!;
      scaledNutrition = NutritionalInfo(
        calories: info.calories != null ? (info.calories! * ratio).round() : null,
        carbs: info.carbs != null ? (info.carbs! * ratio).round() : null,
        protein: info.protein != null ? (info.protein! * ratio).round() : null,
        fat: info.fat != null ? (info.fat! * ratio).round() : null,
        sodium: info.sodium != null ? (info.sodium! * ratio).round() : null,
        fluids: info.fluids != null ? info.fluids! * ratio : null,
      );
    }

    return FoodItemData(
      id: item.id,
      name: item.name,
      quantity: _formatQuantity(newQuantity),
      imageAddress: item.imageAddress,
      description: item.description,
      timing: item.timing,
      nutritionalInfo: scaledNutrition ?? item.nutritionalInfo,
      instructions: item.instructions,
      displayName: item.displayName,
      displayNamePlural: item.displayNamePlural,
      displayOverride: item.displayOverride,
      servingSize: item.servingSize,
      isDrink: item.isDrink,
      templateId: item.templateId,
      scaleMultiplier: multiplier,
    );
  }

  /// Format a quantity as a display string
  static String _formatQuantity(double value) {
    if (value == 0) return '0';
    if ((value - value.roundToDouble()).abs() < 0.01) return value.round().toString();
    if ((value - 0.25).abs() < 0.05) return '0.25';
    if ((value - 0.33).abs() < 0.05) return '0.33';
    if ((value - 0.5).abs() < 0.05) return '0.5';
    if ((value - 0.67).abs() < 0.05) return '0.67';
    if ((value - 0.75).abs() < 0.05) return '0.75';

    final whole = value.floor();
    final frac = value - whole;

    if (whole > 0 && frac > 0.01) {
      if ((frac - 0.25).abs() < 0.05) return '$whole.25';
      if ((frac - 0.33).abs() < 0.05) return '$whole.33';
      if ((frac - 0.5).abs() < 0.05) return '$whole.5';
      if ((frac - 0.67).abs() < 0.05) return '$whole.67';
      if ((frac - 0.75).abs() < 0.05) return '$whole.75';
    }

    return value.toStringAsFixed(1);
  }

  /// Scale a sub-phase's food items when user adjusts one item
  static BeforeSubPhase scaleSubPhase(
    BeforeSubPhase subPhase,
    int changedIndex,
    double newQuantity,
  ) {
    final scaledItems = scaleProportionally(
      subPhase.foodItems,
      changedIndex,
      newQuantity,
    );

    return subPhase.copyWith(foodItems: scaledItems);
  }
}

/// Provider for ProportionalScalingService
final proportionalScalingServiceProvider = Provider<ProportionalScalingService>((ref) {
  return ProportionalScalingService();
});
