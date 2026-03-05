import '../domain/food_item_data.dart';
import '../domain/time_slot_assignment.dart';
import '../domain/unassigned_tray_item.dart';

/// Reactive sync service replacing auto-apportionment.
///
/// All methods are pure functions — no state is held. The unassigned tray
/// is always derived (summary qty − assigned qty), never stored.
class ByHourSyncService {
  /// Parse the leading numeric quantity from a food's quantity string.
  static double parseQuantity(FoodItemData food) {
    final match = RegExp(r'^([\d.]+)').firstMatch(food.quantity);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 1.0;
    }
    return 1.0;
  }

  /// Resolve timing category for a food item, with fallback for null.
  static TimingCategory resolveTimingCategory(FoodItemData food) {
    if (food.timingCategory != null) return food.timingCategory!;
    return food.isDrink
        ? TimingCategory.sipThroughout
        : TimingCategory.slowConsume;
  }

  /// Derive the unassigned tray items from summary foods and current assignments.
  ///
  /// Returns only items with remainingQuantity > 0.
  static List<UnassignedTrayItem> calculateUnassignedItems({
    required List<FoodItemData> summaryFoods,
    required ByHourData byHourData,
  }) {
    final result = <UnassignedTrayItem>[];

    for (final food in summaryFoods) {
      final summaryQty = parseQuantity(food);
      final assignedQty = byHourData.assignments
          .where((a) => a.foodItemId == food.id)
          .fold<double>(0, (sum, a) => sum + (a.adjustedQuantity ?? 0));
      final remaining = summaryQty - assignedQty;
      if (remaining > 0.01) {
        result.add(UnassignedTrayItem(
          foodId: food.id,
          food: food,
          remainingQuantity: _roundQuantity(remaining),
        ));
      }
    }

    return result;
  }

  /// Remove all assignments for a deleted food.
  static ByHourData removeFoodAssignments({
    required ByHourData existing,
    required String removedFoodId,
  }) {
    return existing.copyWith(
      assignments: existing.assignments
          .where((a) => a.foodItemId != removedFoodId)
          .toList(),
    );
  }

  /// Adjust assignments when summary quantity changes.
  ///
  /// If newQty >= assignedTotal, nothing changes (tray absorbs the delta).
  /// If newQty < assignedTotal, trim from last assigned hour first.
  static ByHourData adjustAssignmentsForQuantityChange({
    required ByHourData existing,
    required String foodId,
    required double newQty,
    required bool isIndivisible,
  }) {
    final foodAssignments =
        existing.assignments.where((a) => a.foodItemId == foodId).toList();
    final assignedTotal = foodAssignments.fold<double>(
      0,
      (sum, a) => sum + (a.adjustedQuantity ?? 0),
    );

    // Tray can absorb the change — no trimming needed
    if (newQty >= assignedTotal - 0.01) return existing;

    // Need to trim: remove from last hour backwards
    var excess = assignedTotal - newQty;
    final stepSize = isIndivisible ? 1.0 : 0.5;

    // Sort by hour descending, then slot descending (trim from end)
    final sorted = List<TimeSlotAssignment>.from(foodAssignments)
      ..sort((a, b) {
        final hourCmp =
            b.timeSlot.hourIndex.compareTo(a.timeSlot.hourIndex);
        if (hourCmp != 0) return hourCmp;
        return b.timeSlot.slotIndex.compareTo(a.timeSlot.slotIndex);
      });

    final toRemove = <TimeSlotAssignment>{};
    final toUpdate = <TimeSlotAssignment, double>{};

    for (final assignment in sorted) {
      if (excess <= 0.01) break;
      final qty = assignment.adjustedQuantity ?? 0;
      if (qty <= excess + 0.01) {
        // Remove entire assignment
        toRemove.add(assignment);
        excess -= qty;
      } else {
        // Partially reduce
        final newAssignmentQty = _snapToStep(qty - excess, stepSize);
        toUpdate[assignment] = newAssignmentQty;
        excess = 0;
      }
    }

    final updatedAssignments = existing.assignments.where((a) {
      if (a.foodItemId != foodId) return true;
      return !toRemove.contains(a);
    }).map((a) {
      if (a.foodItemId == foodId && toUpdate.containsKey(a)) {
        return a.copyWith(adjustedQuantity: toUpdate[a]);
      }
      return a;
    }).toList();

    return existing.copyWith(assignments: updatedAssignments);
  }

  /// Replace all old food assignments with new food in same slots (for swap).
  static ByHourData swapFoodAssignments({
    required ByHourData existing,
    required String oldFoodId,
    required String newFoodId,
  }) {
    final updatedAssignments = existing.assignments.map((a) {
      if (a.foodItemId == oldFoodId) {
        return a.copyWith(foodItemId: newFoodId);
      }
      return a;
    }).toList();

    return existing.copyWith(assignments: updatedAssignments);
  }

  /// Place a food item from the tray into a specific time slot.
  static ByHourData placeFoodInSlot({
    required ByHourData existing,
    required String foodId,
    required TimeSlot targetSlot,
    required double quantity,
    TimingCategory? timingCategory,
    bool isSipThroughout = false,
  }) {
    final newAssignment = TimeSlotAssignment(
      foodItemId: foodId,
      timeSlot: targetSlot,
      adjustedQuantity: quantity,
      timingCategory: timingCategory,
      isSipThroughout: isSipThroughout,
    );

    return existing.copyWith(
      assignments: [...existing.assignments, newAssignment],
    );
  }

  /// Remove a food from a specific time slot, returning it to the tray.
  ///
  /// Removes the first matching assignment at [sourceSlot] for [foodId].
  static ByHourData removeFoodFromSlot({
    required ByHourData existing,
    required String foodId,
    required TimeSlot sourceSlot,
  }) {
    var removed = false;
    final updatedAssignments = <TimeSlotAssignment>[];
    for (final a in existing.assignments) {
      if (!removed &&
          a.foodItemId == foodId &&
          a.timeSlot == sourceSlot) {
        removed = true;
        continue; // skip this one
      }
      updatedAssignments.add(a);
    }

    return existing.copyWith(assignments: updatedAssignments);
  }

  /// Check if a food has zero tray quantity AND zero assignments.
  /// If so, it should be auto-removed from Summary.
  static bool shouldAutoRemoveFromSummary({
    required List<FoodItemData> summaryFoods,
    required ByHourData byHourData,
    required String foodId,
  }) {
    final food = summaryFoods.where((f) => f.id == foodId).firstOrNull;
    if (food == null) return false;
    final summaryQty = parseQuantity(food);
    final assignedQty = byHourData.assignments
        .where((a) => a.foodItemId == foodId)
        .fold<double>(0, (sum, a) => sum + (a.adjustedQuantity ?? 0));
    final remaining = summaryQty - assignedQty;
    return remaining <= 0.01 && assignedQty <= 0.01;
  }

  static double _roundQuantity(double value) => (value * 100).round() / 100;

  static double _snapToStep(double value, double step) {
    if (value <= 0) return 0;
    return (value / step).round() * step;
  }
}
