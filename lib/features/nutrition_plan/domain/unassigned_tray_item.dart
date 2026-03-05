import 'food_item_data.dart';

/// Lightweight model representing a food item with unassigned quantity
/// in the By-Hour unassigned tray.
///
/// `remainingQuantity` is derived: summary qty − sum(by-hour assignments).
class UnassignedTrayItem {
  const UnassignedTrayItem({
    required this.foodId,
    required this.food,
    required this.remainingQuantity,
  });

  final String foodId;
  final FoodItemData food;

  /// Summary quantity minus total assigned across all hours.
  final double remainingQuantity;

  /// Step size for tap-to-place: 1.0 for indivisible items, 0.5 otherwise.
  double get stepSize => food.isIndivisible ? 1.0 : 0.5;

  /// True when all of this food's quantity has been placed in time slots.
  bool get isFullyAssigned => remainingQuantity <= 0;
}

/// Drag data emitted when dragging from the unassigned tray.
class TrayDragData {
  const TrayDragData({
    required this.foodId,
    required this.food,
    required this.quantity,
    this.timingCategory,
  });

  final String foodId;
  final FoodItemData food;
  final double quantity;
  final TimingCategory? timingCategory;
}
