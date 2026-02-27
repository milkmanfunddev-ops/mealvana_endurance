import '../domain/food_item_data.dart';
import '../domain/time_slot_assignment.dart';

/// Distributes food items across hourly time slots for the By-Hour view.
///
/// Algorithm (split-quantity):
/// 1. Each food item creates one assignment per hour with adjustedQuantity = originalQty / totalHours
/// 2. Drinks: placed at :00 of each hour with isSipThroughout=true
/// 3. Solids: distributed across preferred slots (:15, :30, :45) within each hour
/// 4. Partial last hour: only generate valid slot count
class ByHourApportionmentService {
  /// Generate by-hour assignments for a list of food items.
  ///
  /// Each food item is split across all hours, with adjustedQuantity representing
  /// the per-hour portion.
  ///
  /// Returns null if duration < 60 minutes (not enough for hourly view).
  ByHourData? apportion({
    required List<FoodItemData> foodItems,
    required int durationMinutes,
  }) {
    if (durationMinutes < 60) return null;
    if (foodItems.isEmpty) {
      return ByHourData(
        durationMinutes: durationMinutes,
        assignments: [],
      );
    }

    final totalHours = (durationMinutes / 60).ceil().clamp(1, 999);
    final drinks = foodItems.where((f) => f.isDrink).toList();
    final solids = foodItems.where((f) => !f.isDrink).toList();

    final assignments = <TimeSlotAssignment>[];

    // 1. Split each drink across all hours at :00 slot
    for (final drink in drinks) {
      final originalQty = _parseQuantity(drink);
      final perHourQty = originalQty / totalHours;

      for (int h = 0; h < totalHours; h++) {
        assignments.add(TimeSlotAssignment(
          foodItemId: drink.id,
          timeSlot: TimeSlot(hourIndex: h, slotIndex: 0),
          isSipThroughout: true,
          adjustedQuantity: perHourQty,
        ));
      }
    }

    // 2. Split each solid across all hours, distributing within preferred slots
    final preferredSlotOrder = [1, 2, 3, 0];
    // Track which slot cursor each hour is at (for spacing solids within an hour)
    final hourSlotCursors = List<int>.filled(totalHours, 0);

    for (final solid in solids) {
      final originalQty = _parseQuantity(solid);
      final perHourQty = originalQty / totalHours;

      for (int h = 0; h < totalHours; h++) {
        final cursorPos = hourSlotCursors[h];

        // Calculate available slots for this hour
        final lastHourRemainder = durationMinutes % 60;
        final lastHourSlotCount =
            lastHourRemainder == 0 ? 4 : (lastHourRemainder / 15).ceil().clamp(1, 4);
        final maxSlots = h == totalHours - 1 ? lastHourSlotCount : 4;

        final slotIndex =
            preferredSlotOrder[cursorPos % preferredSlotOrder.length];
        final safeSlotIndex = slotIndex < maxSlots ? slotIndex : 0;

        assignments.add(TimeSlotAssignment(
          foodItemId: solid.id,
          timeSlot: TimeSlot(hourIndex: h, slotIndex: safeSlotIndex),
          adjustedQuantity: perHourQty,
        ));

        hourSlotCursors[h] = cursorPos + 1;
      }
    }

    return ByHourData(
      durationMinutes: durationMinutes,
      assignments: assignments,
    );
  }

  /// Re-apportion after a food item is added or removed.
  ///
  /// When [targetHourIndex] is set, new foods are placed ONLY in that hour
  /// (no splitting) - used for "ADD TO HOUR X" button.
  /// When null, new foods are split across all hours (default behavior).
  ByHourData reapportion({
    required ByHourData existing,
    required List<FoodItemData> currentFoodItems,
    int? targetHourIndex,
  }) {
    final assignedIds = existing.assignments.map((a) => a.foodItemId).toSet();
    final currentIds = currentFoodItems.map((f) => f.id).toSet();

    // Remove assignments for deleted foods
    var updatedAssignments = existing.assignments
        .where((a) => currentIds.contains(a.foodItemId))
        .toList();

    // Add assignments for new foods
    final newFoodIds = currentIds.difference(assignedIds);
    if (newFoodIds.isNotEmpty) {
      final totalHours = existing.totalHours;
      for (final foodId in newFoodIds) {
        final food = currentFoodItems.firstWhere((f) => f.id == foodId);
        final originalQty = _parseQuantity(food);

        if (targetHourIndex != null) {
          // Place ONLY in the target hour (full quantity)
          final slot = _findBestSlotInHour(
            food, updatedAssignments, targetHourIndex, existing.durationMinutes, totalHours,
          );
          updatedAssignments.add(TimeSlotAssignment(
            foodItemId: foodId,
            timeSlot: slot,
            isSipThroughout: food.isDrink,
            adjustedQuantity: originalQty,
          ));
        } else {
          // Split across all hours (default)
          final perHourQty = originalQty / totalHours;
          for (int h = 0; h < totalHours; h++) {
            final slot = _findBestSlotInHour(
              food, updatedAssignments, h, existing.durationMinutes, totalHours,
            );
            updatedAssignments.add(TimeSlotAssignment(
              foodItemId: foodId,
              timeSlot: slot,
              isSipThroughout: food.isDrink,
              adjustedQuantity: perHourQty,
            ));
          }
        }
      }
    }

    return existing.copyWith(assignments: updatedAssignments);
  }

  /// Find the best slot within a specific hour for a food item.
  TimeSlot _findBestSlotInHour(
    FoodItemData food,
    List<TimeSlotAssignment> existingAssignments,
    int hourIndex,
    int durationMinutes,
    int totalHours,
  ) {
    if (food.isDrink) {
      return TimeSlot(hourIndex: hourIndex, slotIndex: 0);
    }

    // For solids: pick the preferred slot with fewest items
    final lastHourRemainder = durationMinutes % 60;
    final lastHourSlotCount =
        lastHourRemainder == 0 ? 4 : (lastHourRemainder / 15).ceil().clamp(1, 4);
    final maxSlots = hourIndex == totalHours - 1 ? lastHourSlotCount : 4;

    final preferredSlotOrder = [1, 2, 3, 0];
    final slotUsage = <int, int>{};
    for (final a in existingAssignments) {
      if (a.timeSlot.hourIndex == hourIndex && !a.isSipThroughout) {
        slotUsage[a.timeSlot.slotIndex] =
            (slotUsage[a.timeSlot.slotIndex] ?? 0) + 1;
      }
    }

    int bestSlot = preferredSlotOrder[0];
    int fewest = slotUsage[bestSlot] ?? 0;
    for (final s in preferredSlotOrder) {
      if (s >= maxSlots) continue;
      final count = slotUsage[s] ?? 0;
      if (count < fewest) {
        fewest = count;
        bestSlot = s;
      }
    }

    return TimeSlot(hourIndex: hourIndex, slotIndex: bestSlot);
  }

  /// Parse the numeric quantity from a food item's quantity string.
  /// e.g., "3 servings" → 3.0, "1.5 gels" → 1.5, "1" → 1.0
  static double parseQuantity(FoodItemData food) => _parseQuantity(food);

  static double _parseQuantity(FoodItemData food) {
    final match = RegExp(r'^([\d.]+)').firstMatch(food.quantity);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 1.0;
    }
    return 1.0;
  }
}
