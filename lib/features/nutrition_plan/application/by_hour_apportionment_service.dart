import '../../../shared/domain/activity_type.dart';
import '../../../features/auth/domain/user_preferences.dart';
import '../domain/food_item_data.dart';
import '../domain/time_slot_assignment.dart';

/// Distributes food items across hourly time slots for the By-Hour view.
///
/// Algorithm v2 — timing-intelligent, sport-aware, gut-training-aware:
///
/// Phase 1 - SIP_THROUGHOUT: Drinks at :00 every hour from minute 0
/// Phase 2 - ELECTROLYTES: Every 60 min starting at minute 60 (skip if <90 min)
/// Phase 3 - QUICK_CONSUME: Gels/chews after 30-min quiet zone, spaced by gut training
/// Phase 4 - SLOW_CONSUME: Bars/real food after 30-min quiet zone, cycling stops at 2/3
class ByHourApportionmentService {
  /// Quiet zone: no solids/gels before this minute.
  static const int _quietZoneMinutes = 30;

  /// No solids/gels in the last N minutes.
  static const int _endCutoffMinutes = 15;

  /// Friendly increment for sip-throughout liquids.
  static const double _sipIncrement = 0.5;
  static const double _quickIncrement = 0.5;

  /// Generate by-hour assignments for a list of food items.
  ///
  /// Returns null if duration < 60 minutes (not enough for hourly view).
  ByHourData? apportion({
    required List<FoodItemData> foodItems,
    required int durationMinutes,
    GutTraining gutTraining = GutTraining.moderate,
    ActivityType activityType = ActivityType.running,
  }) {
    if (durationMinutes < 60) return null;
    if (foodItems.isEmpty) {
      return ByHourData(durationMinutes: durationMinutes, assignments: []);
    }

    final totalHours = (durationMinutes / 60).ceil().clamp(1, 999);
    final assignments = <TimeSlotAssignment>[];

    // Categorize food items
    final sipItems = <FoodItemData>[];
    final electrolyteItems = <FoodItemData>[];
    final quickItems = <FoodItemData>[];
    final slowItems = <FoodItemData>[];

    for (final food in foodItems) {
      final category = _resolveTimingCategory(food);
      switch (category) {
        case TimingCategory.sipThroughout:
        case TimingCategory.fuelDrink:
          // fuelDrink is placed like sipThroughout (at :00) but tagged differently for UI
          sipItems.add(food);
        case TimingCategory.electrolyte:
          electrolyteItems.add(food);
        case TimingCategory.quickConsume:
          quickItems.add(food);
        case TimingCategory.slowConsume:
          slowItems.add(food);
      }
    }

    // Phase 1: SIP_THROUGHOUT + FUEL_DRINK — drinks at :00 every hour from minute 0
    // Enforce minimum 0.5 per hour; reduce placement count if needed
    for (final drink in sipItems) {
      final originalQty = _parseQuantity(drink);
      final placementCount = _sipPlacementCount(originalQty, totalHours);
      final splitQuantities = _splitSipQuantity(
        originalQty: originalQty,
        placementCount: placementCount,
      );

      // Preserve the resolved timing category for UI display
      final drinkCategory = _resolveTimingCategory(drink);
      final isSip = drinkCategory != TimingCategory.fuelDrink;

      // Spread placements evenly across available hours
      final hourStep = placementCount < totalHours
          ? (totalHours / placementCount).floor()
          : 1;
      for (int i = 0; i < placementCount; i++) {
        final h = (i * hourStep).clamp(0, totalHours - 1);
        assignments.add(
          TimeSlotAssignment(
            foodItemId: drink.id,
            timeSlot: TimeSlot(hourIndex: h, slotIndex: 0),
            isSipThroughout: isSip,
            adjustedQuantity: splitQuantities[i],
            timingCategory: drinkCategory,
          ),
        );
      }
    }

    // Phase 2: ELECTROLYTES — every 60 min starting at minute 60, skip if <90 min
    // Enforce whole-number quantities (can't split a tablet)
    if (durationMinutes >= 90) {
      for (final elec in electrolyteItems) {
        final allMinutes = <int>[];
        for (int m = 60; m < durationMinutes; m += 60) {
          allMinutes.add(m);
        }

        if (allMinutes.isEmpty) continue;

        // Round to whole number — tablets are indivisible
        final originalQty = _parseQuantity(elec);
        final wholeQty = originalQty.round().clamp(1, 999);
        // Limit placements to available quantity (each gets exactly 1)
        final placementCount = allMinutes.length <= wholeQty
            ? allMinutes.length
            : wholeQty;
        final usedMinutes = allMinutes.take(placementCount).toList();

        for (final minute in usedMinutes) {
          final slot = _minuteToTimeSlot(minute);
          assignments.add(
            TimeSlotAssignment(
              foodItemId: elec.id,
              timeSlot: slot,
              adjustedQuantity: 1.0,
              timingCategory: TimingCategory.electrolyte,
            ),
          );
        }
      }
    }

    // Phase 3: QUICK_CONSUME — gels/chews after quiet zone, spaced by gut training
    // Distribute by time (not front-loading by quantity) so carbs are spread across the effort.
    if (quickItems.isNotEmpty) {
      final interval = _gelIntervalMinutes(gutTraining);
      final endCutoff = durationMinutes - _endCutoffMinutes;

      // Generate placement minutes
      final placementMinutes = <int>[];
      for (int m = _quietZoneMinutes; m <= endCutoff; m += interval) {
        placementMinutes.add(m);
      }
      final trimmedPlacementMinutes = _omitLastAllowedPlacement(placementMinutes);

      if (trimmedPlacementMinutes.isNotEmpty) {
        for (final food in quickItems) {
          final originalQty = _parseQuantity(food);
          final placementCount = _eventPlacementCount(
            originalQty: originalQty,
            availableSlots: trimmedPlacementMinutes.length,
            minIncrement: _quickIncrement,
            isIndivisible: food.isIndivisible,
          );
          final selectedMinutes = _selectEvenlySpacedMinutes(
            trimmedPlacementMinutes,
            placementCount,
          );
          final splitQuantities = food.isIndivisible
              ? List<double>.filled(placementCount, 1.0)
              : _splitSipQuantity(
                  originalQty: originalQty,
                  placementCount: placementCount,
                );

          for (int i = 0; i < selectedMinutes.length; i++) {
            assignments.add(
              TimeSlotAssignment(
                foodItemId: food.id,
                timeSlot: _minuteToTimeSlot(selectedMinutes[i]),
                adjustedQuantity: splitQuantities[i],
                timingCategory: TimingCategory.quickConsume,
              ),
            );
          }
        }
      }
    }

    // Phase 4: SLOW_CONSUME — bars/real food after quiet zone
    // Place 1 whole unit per time slot, up to total quantity per food
    if (slowItems.isNotEmpty) {
      int endCutoff = durationMinutes - _endCutoffMinutes;

      // Cycling override: solids only in first 2/3 of activity
      if (activityType == ActivityType.cycling) {
        final twoThirds = (durationMinutes * 2 / 3).round();
        endCutoff = endCutoff < twoThirds ? endCutoff : twoThirds;
      }

      // Place solids, avoiding :00 slots (reserved for drinks)
      // Use 30-min spacing between slow items
      final placementMinutes = <int>[];
      for (int m = _quietZoneMinutes; m <= endCutoff; m += 30) {
        // Avoid :00 (top-of-hour) slots — those are for drinks
        if (m % 60 == 0) continue;
        placementMinutes.add(m);
      }

      if (placementMinutes.isNotEmpty) {
        for (int i = 0; i < slowItems.length; i++) {
          final food = slowItems[i];
          final originalQty = _parseQuantity(food);
          final wholeQty = originalQty < 1 ? 1.0 : originalQty;
          var remaining = wholeQty;

          // Distribute this food across available slots
          final foodPlacements = <int>[];
          for (int j = i; j < placementMinutes.length; j += slowItems.length) {
            foodPlacements.add(placementMinutes[j]);
          }

          if (foodPlacements.isEmpty) {
            // Fallback: place at first available minute after quiet zone
            foodPlacements.add(_quietZoneMinutes);
          }

          // Place 1 unit per slot, up to total quantity
          for (final minute in foodPlacements) {
            if (remaining <= 0) break;
            final slot = _minuteToTimeSlot(minute);
            assignments.add(
              TimeSlotAssignment(
                foodItemId: food.id,
                timeSlot: slot,
                adjustedQuantity: 1.0,
                timingCategory: TimingCategory.slowConsume,
              ),
            );
            remaining -= 1;
          }
        }
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
  /// When null, new foods are placed using the timing-aware algorithm.
  ByHourData reapportion({
    required ByHourData existing,
    required List<FoodItemData> currentFoodItems,
    int? targetHourIndex,
    GutTraining gutTraining = GutTraining.moderate,
    ActivityType activityType = ActivityType.running,
  }) {
    final assignedIds = existing.assignments.map((a) => a.foodItemId).toSet();
    final currentIds = currentFoodItems.map((f) => f.id).toSet();

    // Remove assignments for deleted foods
    var updatedAssignments = existing.assignments
        .where((a) => currentIds.contains(a.foodItemId))
        .toList();

    // Scale adjustedQuantity for existing foods whose total quantity changed
    for (final food in currentFoodItems) {
      if (!assignedIds.contains(food.id)) continue; // new food, handled below
      final currentQty = _parseQuantity(food);
      final totalAssigned = updatedAssignments
          .where((a) => a.foodItemId == food.id)
          .fold<double>(
            0,
            (sum, a) => sum + (a.adjustedQuantity ?? currentQty),
          );
      if ((totalAssigned - currentQty).abs() > 0.01) {
        final scale = totalAssigned > 0 ? currentQty / totalAssigned : 1.0;
        updatedAssignments = updatedAssignments.map((a) {
          if (a.foodItemId == food.id && a.adjustedQuantity != null) {
            final scaledQty = a.adjustedQuantity! * scale;
            return a.copyWith(
              adjustedQuantity: _normalizeAssignmentQuantity(food, scaledQty),
            );
          }
          return a;
        }).toList();
      }
    }

    // Add assignments for new foods
    final newFoodIds = currentIds.difference(assignedIds);
    if (newFoodIds.isNotEmpty) {
      for (final foodId in newFoodIds) {
        final food = currentFoodItems.firstWhere((f) => f.id == foodId);
        final originalQty = _parseQuantity(food);
        final category = _resolveTimingCategory(food);

        if (targetHourIndex != null) {
          // Place ONLY in the target hour (full quantity)
          final slot = _findBestSlotInHour(
            food,
            updatedAssignments,
            targetHourIndex,
            existing.durationMinutes,
            existing.totalHours,
          );
          updatedAssignments.add(
            TimeSlotAssignment(
              foodItemId: foodId,
              timeSlot: slot,
              isSipThroughout: category == TimingCategory.sipThroughout,
              adjustedQuantity: originalQty,
              timingCategory: category,
            ),
          );
        } else {
          // Use timing-aware placement for new foods
          final newAssignments = _placeNewFood(
            food: food,
            category: category,
            durationMinutes: existing.durationMinutes,
            totalHours: existing.totalHours,
            gutTraining: gutTraining,
            activityType: activityType,
            existingAssignments: updatedAssignments,
          );
          updatedAssignments.addAll(newAssignments);
        }
      }
    }

    return existing.copyWith(assignments: updatedAssignments);
  }

  /// Place a new food item using timing-aware rules.
  List<TimeSlotAssignment> _placeNewFood({
    required FoodItemData food,
    required TimingCategory category,
    required int durationMinutes,
    required int totalHours,
    required GutTraining gutTraining,
    required ActivityType activityType,
    required List<TimeSlotAssignment> existingAssignments,
  }) {
    final originalQty = _parseQuantity(food);
    final assignments = <TimeSlotAssignment>[];

    switch (category) {
      case TimingCategory.sipThroughout:
      case TimingCategory.fuelDrink:
        // Split across all hours at :00, enforce minimum 0.5 per hour
        final placementCount = _sipPlacementCount(originalQty, totalHours);
        final splitQuantities = _splitSipQuantity(
          originalQty: originalQty,
          placementCount: placementCount,
        );
        final isSip = category != TimingCategory.fuelDrink;
        final hourStep = placementCount < totalHours
            ? (totalHours / placementCount).floor()
            : 1;
        for (int i = 0; i < placementCount; i++) {
          final h = (i * hourStep).clamp(0, totalHours - 1);
          assignments.add(
            TimeSlotAssignment(
              foodItemId: food.id,
              timeSlot: TimeSlot(hourIndex: h, slotIndex: 0),
              isSipThroughout: isSip,
              adjustedQuantity: splitQuantities[i],
              timingCategory: category,
            ),
          );
        }

      case TimingCategory.electrolyte:
        // Enforce whole-number quantities (can't split a tablet)
        if (durationMinutes >= 90) {
          final allMinutes = <int>[];
          for (int m = 60; m < durationMinutes; m += 60) {
            allMinutes.add(m);
          }
          if (allMinutes.isNotEmpty) {
            final wholeQty = originalQty.round().clamp(1, 999);
            final placementCount = allMinutes.length <= wholeQty
                ? allMinutes.length
                : wholeQty;
            final usedMinutes = allMinutes.take(placementCount).toList();
            for (final m in usedMinutes) {
              assignments.add(
                TimeSlotAssignment(
                  foodItemId: food.id,
                  timeSlot: _minuteToTimeSlot(m),
                  adjustedQuantity: 1.0,
                  timingCategory: category,
                ),
              );
            }
          }
        }

      case TimingCategory.quickConsume:
        // Distribute by time across available slots to avoid front-loading.
        final interval = _gelIntervalMinutes(gutTraining);
        final endCutoff = durationMinutes - _endCutoffMinutes;
        final placements = <int>[];
        for (int m = _quietZoneMinutes; m <= endCutoff; m += interval) {
          placements.add(m);
        }
        final trimmedPlacements = _omitLastAllowedPlacement(placements);
        if (trimmedPlacements.isNotEmpty) {
          final placementCount = _eventPlacementCount(
            originalQty: originalQty,
            availableSlots: trimmedPlacements.length,
            minIncrement: _quickIncrement,
            isIndivisible: food.isIndivisible,
          );
          final selectedPlacements = _selectEvenlySpacedMinutes(
            trimmedPlacements,
            placementCount,
          );
          final splitQuantities = food.isIndivisible
              ? List<double>.filled(placementCount, 1.0)
              : _splitSipQuantity(
                  originalQty: originalQty,
                  placementCount: placementCount,
                );

          for (int i = 0; i < selectedPlacements.length; i++) {
            assignments.add(
              TimeSlotAssignment(
                foodItemId: food.id,
                timeSlot: _minuteToTimeSlot(selectedPlacements[i]),
                adjustedQuantity: splitQuantities[i],
                timingCategory: category,
              ),
            );
          }
        }

      case TimingCategory.slowConsume:
        // Place 1 whole unit per time slot, up to total quantity
        int endCutoff = durationMinutes - _endCutoffMinutes;
        if (activityType == ActivityType.cycling) {
          final twoThirds = (durationMinutes * 2 / 3).round();
          endCutoff = endCutoff < twoThirds ? endCutoff : twoThirds;
        }
        final placements = <int>[];
        for (int m = _quietZoneMinutes; m <= endCutoff; m += 30) {
          if (m % 60 == 0) continue;
          placements.add(m);
        }
        if (placements.isNotEmpty) {
          final wholeQty = originalQty < 1 ? 1.0 : originalQty;
          var remaining = wholeQty;
          for (final m in placements) {
            if (remaining <= 0) break;
            assignments.add(
              TimeSlotAssignment(
                foodItemId: food.id,
                timeSlot: _minuteToTimeSlot(m),
                adjustedQuantity: 1.0,
                timingCategory: category,
              ),
            );
            remaining -= 1;
          }
        }
    }

    // Fallback: if no placements were made, use best-slot-in-hour approach
    if (assignments.isEmpty) {
      final perHourQty = originalQty / totalHours;
      for (int h = 0; h < totalHours; h++) {
        final slot = _findBestSlotInHour(
          food,
          existingAssignments,
          h,
          durationMinutes,
          totalHours,
        );
        assignments.add(
          TimeSlotAssignment(
            foodItemId: food.id,
            timeSlot: slot,
            isSipThroughout: category == TimingCategory.sipThroughout,
            adjustedQuantity: perHourQty,
            timingCategory: category,
          ),
        );
      }
    }

    return assignments;
  }

  /// Find the best slot within a specific hour for a food item.
  TimeSlot _findBestSlotInHour(
    FoodItemData food,
    List<TimeSlotAssignment> existingAssignments,
    int hourIndex,
    int durationMinutes,
    int totalHours,
  ) {
    final category = _resolveTimingCategory(food);
    if (category == TimingCategory.sipThroughout ||
        category == TimingCategory.fuelDrink) {
      return TimeSlot(hourIndex: hourIndex, slotIndex: 0);
    }

    // For non-drinks: pick the preferred slot with fewest items
    // Match the slot count logic in ByHourData.lastHourSlotCount:
    // only show slots where at least 15 min (END_CUTOFF) remains after slot start
    final lastHourRemainder = durationMinutes % 60;
    final int lastHourSlotCount;
    if (lastHourRemainder == 0) {
      lastHourSlotCount = 4;
    } else {
      final usable = lastHourRemainder - _endCutoffMinutes;
      lastHourSlotCount = usable <= 0 ? 1 : (usable ~/ 15) + 1;
    }
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

  /// Convert absolute minutes to a TimeSlot.
  static TimeSlot _minuteToTimeSlot(int absoluteMinutes) {
    final hourIndex = absoluteMinutes ~/ 60;
    final minuteInHour = absoluteMinutes % 60;
    final slotIndex = (minuteInHour ~/ 15).clamp(0, 3);
    return TimeSlot(hourIndex: hourIndex, slotIndex: slotIndex);
  }

  /// Resolve timing category for a food item, with fallback for null.
  static TimingCategory _resolveTimingCategory(FoodItemData food) {
    if (food.timingCategory != null) return food.timingCategory!;
    // Legacy fallback: use isDrink heuristic
    return food.isDrink
        ? TimingCategory.sipThroughout
        : TimingCategory.slowConsume;
  }

  /// Gel/chew spacing interval based on gut training level.
  static int _gelIntervalMinutes(GutTraining gutTraining) {
    switch (gutTraining) {
      case GutTraining.low:
        return 45;
      case GutTraining.moderate:
        return 30;
      case GutTraining.high:
        return 25;
    }
  }

  /// Parse the numeric quantity from a food item's quantity string.
  /// e.g., "3 servings" → 3.0, "1.5 gels" → 1.5, "1" → 1.0
  static double parseQuantity(FoodItemData food) => _parseQuantity(food);

  static int _sipPlacementCount(double originalQty, int totalHours) {
    var placementCount = totalHours;
    final perHourQty = placementCount > 0 ? originalQty / placementCount : 0.0;

    // Reduce placements to maintain a minimum quantity per sip event.
    if (perHourQty < _sipIncrement && originalQty > 0) {
      placementCount = (originalQty / _sipIncrement).floor().clamp(
        1,
        totalHours,
      );
    }

    return placementCount;
  }

  static List<double> _splitSipQuantity({
    required double originalQty,
    required int placementCount,
  }) {
    if (placementCount <= 0) return const [];

    // Snap to friendly 0.5 increments while preserving total servings.
    final baseQty =
        ((originalQty / placementCount) / _sipIncrement).floor() *
        _sipIncrement;
    final quantities = List<double>.filled(
      placementCount,
      _roundQuantity(baseQty),
    );

    final assignedTotal = quantities.fold<double>(0, (sum, q) => sum + q);
    var extraUnits = ((originalQty - assignedTotal + 1e-9) / _sipIncrement)
        .floor();
    if (extraUnits < 0) extraUnits = 0;
    if (extraUnits > placementCount) extraUnits = placementCount;

    // Add remaining half-servings to later placements.
    for (int i = 0; i < extraUnits; i++) {
      final idx = placementCount - 1 - i;
      quantities[idx] = _roundQuantity(quantities[idx] + _sipIncrement);
    }

    return quantities;
  }

  static int _eventPlacementCount({
    required double originalQty,
    required int availableSlots,
    required double minIncrement,
    required bool isIndivisible,
  }) {
    if (availableSlots <= 0) return 0;
    final qty = originalQty < 1 ? 1.0 : originalQty;
    if (isIndivisible) {
      return qty.round().clamp(1, availableSlots);
    }

    var placementCount = availableSlots;
    final perSlotQty = qty / placementCount;
    if (perSlotQty < minIncrement) {
      placementCount = (qty / minIncrement).floor().clamp(1, availableSlots);
    }
    return placementCount;
  }

  static List<int> _selectEvenlySpacedMinutes(List<int> minutes, int count) {
    if (count <= 0 || minutes.isEmpty) return const [];
    if (count >= minutes.length) return List<int>.from(minutes);
    if (count == 1) return [minutes.first];

    final selectedIndices = <int>[];
    final used = <int>{};
    final maxIndex = minutes.length - 1;

    for (int i = 0; i < count; i++) {
      var idx = ((i * maxIndex) / (count - 1)).round();
      if (!used.contains(idx)) {
        used.add(idx);
        selectedIndices.add(idx);
        continue;
      }

      // Resolve collisions from rounding by expanding outward.
      var offset = 1;
      var placed = false;
      while (!placed) {
        final left = idx - offset;
        final right = idx + offset;
        if (left >= 0 && !used.contains(left)) {
          used.add(left);
          selectedIndices.add(left);
          placed = true;
        } else if (right <= maxIndex && !used.contains(right)) {
          used.add(right);
          selectedIndices.add(right);
          placed = true;
        } else {
          offset++;
        }
      }
    }

    selectedIndices.sort();
    return selectedIndices.map((idx) => minutes[idx]).toList();
  }

  static List<int> _omitLastAllowedPlacement(List<int> placements) {
    if (placements.length <= 1) return placements;
    return placements.sublist(0, placements.length - 1);
  }

  static double _normalizeAssignmentQuantity(FoodItemData food, double value) {
    if (food.isIndivisible) {
      return value.round().clamp(1, 999).toDouble();
    }
    return _roundToFriendlyIncrement(value);
  }

  static double _roundToFriendlyIncrement(double value) {
    if (value <= 0) return 0;

    final halfStep = (value / _sipIncrement).round() * _sipIncrement;
    final thirdStep = (value * 3).round() / 3;
    final halfDiff = (value - halfStep).abs();
    final thirdDiff = (value - thirdStep).abs();

    // Prefer halves by default; use thirds only when meaningfully closer.
    final rounded = thirdDiff + 0.08 < halfDiff ? thirdStep : halfStep;
    return _roundQuantity(rounded);
  }

  static double _roundQuantity(double value) => (value * 100).round() / 100;

  static double _parseQuantity(FoodItemData food) {
    final match = RegExp(r'^([\d.]+)').firstMatch(food.quantity);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 1.0;
    }
    return 1.0;
  }
}
