import '../domain/food_item_data.dart';
import '../domain/time_slot_assignment.dart';

/// Distributes food items across hourly time slots for the By-Hour view.
///
/// Algorithm:
/// 1. Separate drinks from solids
/// 2. Distribute drinks evenly: 1 per hour at :00, isSipThroughout=true
/// 3. Distribute solids round-robin across hours
/// 4. Within each hour, assign solids to :15, :30, :45 first, then :00
/// 5. Multiple items can stack on the same slot
/// 6. Partial last hour: only generate valid slot count
class ByHourApportionmentService {
  /// Generate by-hour assignments for a list of food items.
  ///
  /// [foodItems] - The food items from the during-activity PlanSection
  /// [durationMinutes] - Total duration of the during phase
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

    // 1. Distribute drinks evenly across hours at :00 slot
    assignments.addAll(_distributeDrinks(drinks, totalHours));

    // 2. Distribute solids round-robin across hours, filling :15, :30, :45
    assignments.addAll(
      _distributeSolids(solids, totalHours, durationMinutes),
    );

    return ByHourData(
      durationMinutes: durationMinutes,
      assignments: assignments,
    );
  }

  /// Re-apportion after a food item is added or removed.
  ///
  /// Preserves existing assignments where possible, only adding/removing
  /// the changed food item.
  ByHourData reapportion({
    required ByHourData existing,
    required List<FoodItemData> currentFoodItems,
  }) {
    // Find food IDs that are in current items but not in assignments
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
        final slot = _findBestSlotForNewFood(
          food,
          updatedAssignments,
          totalHours,
          existing.durationMinutes,
        );
        updatedAssignments.add(TimeSlotAssignment(
          foodItemId: foodId,
          timeSlot: slot,
          isSipThroughout: food.isDrink,
        ));
      }
    }

    return existing.copyWith(assignments: updatedAssignments);
  }

  List<TimeSlotAssignment> _distributeDrinks(
    List<FoodItemData> drinks,
    int totalHours,
  ) {
    if (drinks.isEmpty) return [];

    final assignments = <TimeSlotAssignment>[];

    // Distribute drinks evenly: round-robin across hours at :00
    for (int i = 0; i < drinks.length; i++) {
      final hourIndex = i % totalHours;
      assignments.add(TimeSlotAssignment(
        foodItemId: drinks[i].id,
        timeSlot: TimeSlot(hourIndex: hourIndex, slotIndex: 0),
        isSipThroughout: true,
      ));
    }

    return assignments;
  }

  List<TimeSlotAssignment> _distributeSolids(
    List<FoodItemData> solids,
    int totalHours,
    int durationMinutes,
  ) {
    if (solids.isEmpty) return [];

    final assignments = <TimeSlotAssignment>[];

    // Build per-hour solid slot trackers
    // Preferred solid slots are :15, :30, :45 (indices 1, 2, 3), then :00 (index 0)
    final preferredSlotOrder = [1, 2, 3, 0];

    // Track next available slot per hour
    final hourSlotCursors = List<int>.filled(totalHours, 0);

    // Calculate last hour slot count for partial hours
    final lastHourRemainder = durationMinutes % 60;
    final lastHourSlotCount =
        lastHourRemainder == 0 ? 4 : (lastHourRemainder / 15).ceil().clamp(1, 4);

    // Round-robin distribute solids across hours
    for (int i = 0; i < solids.length; i++) {
      final hourIndex = i % totalHours;
      final cursorPos = hourSlotCursors[hourIndex];

      // Determine available slot count for this hour
      final maxSlots =
          hourIndex == totalHours - 1 ? lastHourSlotCount : 4;

      // Pick the slot using preferred order, wrapping if we exceed available slots
      final slotIndex =
          preferredSlotOrder[cursorPos % preferredSlotOrder.length];

      // Ensure we don't assign to a slot beyond what the hour supports
      final safeSlotIndex = slotIndex < maxSlots ? slotIndex : 0;

      assignments.add(TimeSlotAssignment(
        foodItemId: solids[i].id,
        timeSlot: TimeSlot(hourIndex: hourIndex, slotIndex: safeSlotIndex),
      ));

      hourSlotCursors[hourIndex] = cursorPos + 1;
    }

    return assignments;
  }

  /// Find the best available slot for a newly added food item.
  TimeSlot _findBestSlotForNewFood(
    FoodItemData food,
    List<TimeSlotAssignment> existingAssignments,
    int totalHours,
    int durationMinutes,
  ) {
    if (food.isDrink) {
      // Find the hour with fewest drinks and place at :00
      final drinkCountPerHour = <int, int>{};
      for (final a in existingAssignments) {
        if (a.isSipThroughout) {
          drinkCountPerHour[a.timeSlot.hourIndex] =
              (drinkCountPerHour[a.timeSlot.hourIndex] ?? 0) + 1;
        }
      }

      int bestHour = 0;
      int fewestDrinks = drinkCountPerHour[0] ?? 0;
      for (int h = 1; h < totalHours; h++) {
        final count = drinkCountPerHour[h] ?? 0;
        if (count < fewestDrinks) {
          fewestDrinks = count;
          bestHour = h;
        }
      }

      return TimeSlot(hourIndex: bestHour, slotIndex: 0);
    }

    // For solids: find the hour with fewest solids, pick first empty preferred slot
    final solidCountPerHour = <int, int>{};
    for (final a in existingAssignments) {
      if (!a.isSipThroughout) {
        solidCountPerHour[a.timeSlot.hourIndex] =
            (solidCountPerHour[a.timeSlot.hourIndex] ?? 0) + 1;
      }
    }

    int bestHour = 0;
    int fewestSolids = solidCountPerHour[0] ?? 0;
    for (int h = 1; h < totalHours; h++) {
      final count = solidCountPerHour[h] ?? 0;
      if (count < fewestSolids) {
        fewestSolids = count;
        bestHour = h;
      }
    }

    // Find the first preferred slot in that hour that has fewest items
    final lastHourRemainder = durationMinutes % 60;
    final lastHourSlotCount =
        lastHourRemainder == 0 ? 4 : (lastHourRemainder / 15).ceil().clamp(1, 4);
    final maxSlots = bestHour == totalHours - 1 ? lastHourSlotCount : 4;

    final preferredSlotOrder = [1, 2, 3, 0];
    final slotUsage = <int, int>{};
    for (final a in existingAssignments) {
      if (a.timeSlot.hourIndex == bestHour) {
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

    return TimeSlot(hourIndex: bestHour, slotIndex: bestSlot);
  }
}
