import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/by_hour_apportionment_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/by_hour_sync_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/time_slot_assignment.dart';

void main() {
  // ========================================================================
  // Test helpers
  // ========================================================================

  FoodItemData _solid(String id, {String quantity = '1'}) => FoodItemData(
    id: id,
    name: 'Solid $id',
    quantity: quantity,
    isDrink: false,
    timingCategory: TimingCategory.slowConsume,
    nutritionalInfo: const NutritionalInfo(
      calories: 100,
      carbs: 25,
      protein: 2,
      fat: 1,
      sodium: 100,
      fluids: 0,
    ),
  );

  FoodItemData _drink(String id, {String quantity = '1'}) => FoodItemData(
    id: id,
    name: 'Drink $id',
    quantity: quantity,
    isDrink: true,
    timingCategory: TimingCategory.sipThroughout,
    nutritionalInfo: const NutritionalInfo(
      calories: 50,
      carbs: 10,
      protein: 0,
      fat: 0,
      sodium: 200,
      fluids: 500,
    ),
  );

  FoodItemData _gel(String id, {String quantity = '1'}) => FoodItemData(
    id: id,
    name: 'Gel $id',
    quantity: quantity,
    isDrink: false,
    timingCategory: TimingCategory.quickConsume,
    nutritionalInfo: const NutritionalInfo(
      calories: 100,
      carbs: 25,
      protein: 0,
      fat: 0,
      sodium: 50,
      fluids: 0,
    ),
  );

  FoodItemData _indivisible(String id, {String quantity = '1'}) => FoodItemData(
    id: id,
    name: 'Indivisible $id',
    quantity: quantity,
    isDrink: false,
    isIndivisible: true,
    timingCategory: TimingCategory.quickConsume,
    nutritionalInfo: const NutritionalInfo(
      calories: 100,
      carbs: 25,
      protein: 0,
      fat: 0,
      sodium: 50,
      fluids: 0,
    ),
  );

  // ========================================================================
  // parseQuantity (ByHourApportionmentService — kept utility)
  // ========================================================================

  group('parseQuantity', () {
    test('parses integer quantity', () {
      expect(
        ByHourApportionmentService.parseQuantity(
          _solid('s1', quantity: '3 servings'),
        ),
        3.0,
      );
    });

    test('parses decimal quantity', () {
      expect(
        ByHourApportionmentService.parseQuantity(
          _solid('s1', quantity: '1.5 gels'),
        ),
        1.5,
      );
    });

    test('defaults to 1.0 for non-numeric', () {
      expect(
        ByHourApportionmentService.parseQuantity(
          _solid('s1', quantity: 'some food'),
        ),
        1.0,
      );
    });

    test('parses plain number', () {
      expect(
        ByHourApportionmentService.parseQuantity(_solid('s1', quantity: '2')),
        2.0,
      );
    });
  });

  // ========================================================================
  // ByHourSyncService.parseQuantity (same logic, second entry point)
  // ========================================================================

  group('ByHourSyncService.parseQuantity', () {
    test('parses integer quantity', () {
      expect(ByHourSyncService.parseQuantity(_solid('s1', quantity: '3 servings')), 3.0);
    });

    test('parses decimal quantity', () {
      expect(ByHourSyncService.parseQuantity(_solid('s1', quantity: '1.5 gels')), 1.5);
    });

    test('defaults to 1.0 for non-numeric', () {
      expect(ByHourSyncService.parseQuantity(_solid('s1', quantity: 'some food')), 1.0);
    });
  });

  // ========================================================================
  // ByHourSyncService.resolveTimingCategory
  // ========================================================================

  group('ByHourSyncService.resolveTimingCategory', () {
    test('returns explicit timingCategory when present', () {
      expect(
        ByHourSyncService.resolveTimingCategory(_gel('g1')),
        TimingCategory.quickConsume,
      );
    });

    test('fallback: isDrink=true → sipThroughout', () {
      final legacy = FoodItemData(
        id: 'ld',
        name: 'Legacy Drink',
        quantity: '1',
        isDrink: true,
        nutritionalInfo: const NutritionalInfo(calories: 50, carbs: 10),
      );
      expect(
        ByHourSyncService.resolveTimingCategory(legacy),
        TimingCategory.sipThroughout,
      );
    });

    test('fallback: isDrink=false → slowConsume', () {
      final legacy = FoodItemData(
        id: 'ls',
        name: 'Legacy Solid',
        quantity: '1',
        isDrink: false,
        nutritionalInfo: const NutritionalInfo(calories: 100, carbs: 25),
      );
      expect(
        ByHourSyncService.resolveTimingCategory(legacy),
        TimingCategory.slowConsume,
      );
    });
  });

  // ========================================================================
  // ByHourSyncService.calculateUnassignedItems
  // ========================================================================

  group('ByHourSyncService.calculateUnassignedItems', () {
    test('all foods unassigned → full quantities in tray', () {
      final foods = [_solid('s1', quantity: '2'), _drink('d1', quantity: '3')];
      final byHour = ByHourData(durationMinutes: 120, assignments: []);

      final items = ByHourSyncService.calculateUnassignedItems(
        summaryFoods: foods,
        byHourData: byHour,
      );

      expect(items.length, 2);
      expect(items.firstWhere((i) => i.foodId == 's1').remainingQuantity, 2.0);
      expect(items.firstWhere((i) => i.foodId == 'd1').remainingQuantity, 3.0);
    });

    test('partially assigned food → remaining in tray', () {
      final foods = [_solid('s1', quantity: '3')];
      final byHour = ByHourData(
        durationMinutes: 120,
        assignments: [
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
            adjustedQuantity: 1.0,
            timingCategory: TimingCategory.slowConsume,
          ),
        ],
      );

      final items = ByHourSyncService.calculateUnassignedItems(
        summaryFoods: foods,
        byHourData: byHour,
      );

      expect(items.length, 1);
      expect(items.first.remainingQuantity, 2.0);
    });

    test('fully assigned food → not in tray', () {
      final foods = [_solid('s1', quantity: '1')];
      final byHour = ByHourData(
        durationMinutes: 120,
        assignments: [
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
            adjustedQuantity: 1.0,
            timingCategory: TimingCategory.slowConsume,
          ),
        ],
      );

      final items = ByHourSyncService.calculateUnassignedItems(
        summaryFoods: foods,
        byHourData: byHour,
      );

      expect(items, isEmpty);
    });
  });

  // ========================================================================
  // ByHourSyncService.removeFoodAssignments
  // ========================================================================

  group('ByHourSyncService.removeFoodAssignments', () {
    test('removes all assignments for deleted food', () {
      final byHour = ByHourData(
        durationMinutes: 120,
        assignments: [
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
            adjustedQuantity: 0.5,
            timingCategory: TimingCategory.slowConsume,
          ),
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 1, slotIndex: 1),
            adjustedQuantity: 0.5,
            timingCategory: TimingCategory.slowConsume,
          ),
          const TimeSlotAssignment(
            foodItemId: 's2',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 2),
            adjustedQuantity: 1.0,
            timingCategory: TimingCategory.slowConsume,
          ),
        ],
      );

      final updated = ByHourSyncService.removeFoodAssignments(
        existing: byHour,
        removedFoodId: 's1',
      );

      expect(updated.assignments.length, 1);
      expect(updated.assignments.first.foodItemId, 's2');
    });

    test('no-op if foodId not in assignments', () {
      final byHour = ByHourData(
        durationMinutes: 120,
        assignments: [
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
            adjustedQuantity: 1.0,
            timingCategory: TimingCategory.slowConsume,
          ),
        ],
      );

      final updated = ByHourSyncService.removeFoodAssignments(
        existing: byHour,
        removedFoodId: 'nonexistent',
      );

      expect(updated.assignments.length, 1);
    });
  });

  // ========================================================================
  // ByHourSyncService.adjustAssignmentsForQuantityChange
  // ========================================================================

  group('ByHourSyncService.adjustAssignmentsForQuantityChange', () {
    test('no trimming needed when newQty >= assignedTotal', () {
      final byHour = ByHourData(
        durationMinutes: 120,
        assignments: [
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
            adjustedQuantity: 1.0,
            timingCategory: TimingCategory.slowConsume,
          ),
        ],
      );

      final updated = ByHourSyncService.adjustAssignmentsForQuantityChange(
        existing: byHour,
        foodId: 's1',
        newQty: 3.0,
        isIndivisible: false,
      );

      expect(updated.assignments.length, 1);
      expect(updated.assignments.first.adjustedQuantity, 1.0);
    });

    test('trims from last hour when newQty < assignedTotal', () {
      final byHour = ByHourData(
        durationMinutes: 180,
        assignments: [
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
            adjustedQuantity: 1.0,
            timingCategory: TimingCategory.slowConsume,
          ),
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 1, slotIndex: 1),
            adjustedQuantity: 1.0,
            timingCategory: TimingCategory.slowConsume,
          ),
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 2, slotIndex: 1),
            adjustedQuantity: 1.0,
            timingCategory: TimingCategory.slowConsume,
          ),
        ],
      );

      // Reduce from 3 → 1: should remove last 2 hours' assignments
      final updated = ByHourSyncService.adjustAssignmentsForQuantityChange(
        existing: byHour,
        foodId: 's1',
        newQty: 1.0,
        isIndivisible: false,
      );

      expect(updated.assignments.length, 1);
      expect(updated.assignments.first.timeSlot.hourIndex, 0);
    });

    test('partial reduction adjusts quantity on last assignment', () {
      final byHour = ByHourData(
        durationMinutes: 120,
        assignments: [
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
            adjustedQuantity: 1.0,
            timingCategory: TimingCategory.slowConsume,
          ),
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 1, slotIndex: 1),
            adjustedQuantity: 1.0,
            timingCategory: TimingCategory.slowConsume,
          ),
        ],
      );

      // Reduce from 2 → 1.5: should partially reduce hour 1's assignment
      final updated = ByHourSyncService.adjustAssignmentsForQuantityChange(
        existing: byHour,
        foodId: 's1',
        newQty: 1.5,
        isIndivisible: false,
      );

      expect(updated.assignments.length, 2);
      // Hour 0 unchanged
      final hour0 = updated.assignments
          .firstWhere((a) => a.timeSlot.hourIndex == 0);
      expect(hour0.adjustedQuantity, 1.0);
      // Hour 1 reduced
      final hour1 = updated.assignments
          .firstWhere((a) => a.timeSlot.hourIndex == 1);
      expect(hour1.adjustedQuantity, 0.5);
    });

    test('does not affect other food assignments', () {
      final byHour = ByHourData(
        durationMinutes: 120,
        assignments: [
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
            adjustedQuantity: 1.0,
            timingCategory: TimingCategory.slowConsume,
          ),
          const TimeSlotAssignment(
            foodItemId: 's2',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 2),
            adjustedQuantity: 2.0,
            timingCategory: TimingCategory.slowConsume,
          ),
        ],
      );

      final updated = ByHourSyncService.adjustAssignmentsForQuantityChange(
        existing: byHour,
        foodId: 's1',
        newQty: 0.0,
        isIndivisible: false,
      );

      // s1 removed, s2 untouched
      expect(updated.assignments.length, 1);
      expect(updated.assignments.first.foodItemId, 's2');
      expect(updated.assignments.first.adjustedQuantity, 2.0);
    });

    test('indivisible uses step size 1.0', () {
      final byHour = ByHourData(
        durationMinutes: 120,
        assignments: [
          const TimeSlotAssignment(
            foodItemId: 'i1',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
            adjustedQuantity: 2.0,
            timingCategory: TimingCategory.quickConsume,
          ),
        ],
      );

      // Reduce from 2 → 1: should snap to step 1.0
      final updated = ByHourSyncService.adjustAssignmentsForQuantityChange(
        existing: byHour,
        foodId: 'i1',
        newQty: 1.0,
        isIndivisible: true,
      );

      expect(updated.assignments.length, 1);
      expect(updated.assignments.first.adjustedQuantity, 1.0);
    });
  });

  // ========================================================================
  // ByHourSyncService.swapFoodAssignments
  // ========================================================================

  group('ByHourSyncService.swapFoodAssignments', () {
    test('replaces all old food assignments with new food', () {
      final byHour = ByHourData(
        durationMinutes: 120,
        assignments: [
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
            adjustedQuantity: 1.0,
            timingCategory: TimingCategory.slowConsume,
          ),
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 1, slotIndex: 2),
            adjustedQuantity: 0.5,
            timingCategory: TimingCategory.slowConsume,
          ),
          const TimeSlotAssignment(
            foodItemId: 's2',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 2),
            adjustedQuantity: 1.0,
            timingCategory: TimingCategory.slowConsume,
          ),
        ],
      );

      final updated = ByHourSyncService.swapFoodAssignments(
        existing: byHour,
        oldFoodId: 's1',
        newFoodId: 's3',
      );

      expect(updated.assignments.length, 3);
      // s1 replaced with s3 everywhere
      expect(
        updated.assignments.where((a) => a.foodItemId == 's3').length,
        2,
      );
      // s2 untouched
      expect(
        updated.assignments.where((a) => a.foodItemId == 's2').length,
        1,
      );
      // Slots preserved
      final s3Assignments = updated.assignments
          .where((a) => a.foodItemId == 's3')
          .toList()
        ..sort((a, b) => a.timeSlot.hourIndex.compareTo(b.timeSlot.hourIndex));
      expect(s3Assignments[0].timeSlot.slotIndex, 1);
      expect(s3Assignments[0].adjustedQuantity, 1.0);
      expect(s3Assignments[1].timeSlot.slotIndex, 2);
      expect(s3Assignments[1].adjustedQuantity, 0.5);
    });
  });

  // ========================================================================
  // ByHourSyncService.placeFoodInSlot
  // ========================================================================

  group('ByHourSyncService.placeFoodInSlot', () {
    test('adds assignment to existing list', () {
      final byHour = ByHourData(
        durationMinutes: 120,
        assignments: [
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
            adjustedQuantity: 1.0,
            timingCategory: TimingCategory.slowConsume,
          ),
        ],
      );

      final updated = ByHourSyncService.placeFoodInSlot(
        existing: byHour,
        foodId: 'g1',
        targetSlot: const TimeSlot(hourIndex: 1, slotIndex: 2),
        quantity: 0.5,
        timingCategory: TimingCategory.quickConsume,
      );

      expect(updated.assignments.length, 2);
      final newAssignment = updated.assignments.last;
      expect(newAssignment.foodItemId, 'g1');
      expect(newAssignment.timeSlot.hourIndex, 1);
      expect(newAssignment.timeSlot.slotIndex, 2);
      expect(newAssignment.adjustedQuantity, 0.5);
      expect(newAssignment.timingCategory, TimingCategory.quickConsume);
    });

    test('supports sip-throughout placement', () {
      final byHour = ByHourData(durationMinutes: 120, assignments: []);

      final updated = ByHourSyncService.placeFoodInSlot(
        existing: byHour,
        foodId: 'd1',
        targetSlot: const TimeSlot(hourIndex: 0, slotIndex: 0),
        quantity: 1.0,
        timingCategory: TimingCategory.sipThroughout,
        isSipThroughout: true,
      );

      expect(updated.assignments.length, 1);
      expect(updated.assignments.first.isSipThroughout, true);
    });
  });

  // ========================================================================
  // ByHourSyncService.removeFoodFromSlot
  // ========================================================================

  group('ByHourSyncService.removeFoodFromSlot', () {
    test('removes first matching assignment at slot', () {
      final byHour = ByHourData(
        durationMinutes: 120,
        assignments: [
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
            adjustedQuantity: 1.0,
            timingCategory: TimingCategory.slowConsume,
          ),
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 1, slotIndex: 1),
            adjustedQuantity: 1.0,
            timingCategory: TimingCategory.slowConsume,
          ),
        ],
      );

      final updated = ByHourSyncService.removeFoodFromSlot(
        existing: byHour,
        foodId: 's1',
        sourceSlot: const TimeSlot(hourIndex: 0, slotIndex: 1),
      );

      expect(updated.assignments.length, 1);
      expect(updated.assignments.first.timeSlot.hourIndex, 1);
    });

    test('no-op if slot does not match', () {
      final byHour = ByHourData(
        durationMinutes: 120,
        assignments: [
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
            adjustedQuantity: 1.0,
            timingCategory: TimingCategory.slowConsume,
          ),
        ],
      );

      final updated = ByHourSyncService.removeFoodFromSlot(
        existing: byHour,
        foodId: 's1',
        sourceSlot: const TimeSlot(hourIndex: 1, slotIndex: 3),
      );

      expect(updated.assignments.length, 1);
    });
  });

  // ========================================================================
  // ByHourSyncService.shouldAutoRemoveFromSummary
  // ========================================================================

  group('ByHourSyncService.shouldAutoRemoveFromSummary', () {
    test('returns true when tray=0 and assignments=0', () {
      final foods = [_solid('s1', quantity: '1')];
      // No assignments, but summary has qty 1 → tray > 0
      final byHour = ByHourData(durationMinutes: 120, assignments: []);

      // Summary qty 1, assigned 0 → remaining 1 > 0 → false
      expect(
        ByHourSyncService.shouldAutoRemoveFromSummary(
          summaryFoods: foods,
          byHourData: byHour,
          foodId: 's1',
        ),
        false,
      );
    });

    test('returns false when food still has tray quantity', () {
      final foods = [_solid('s1', quantity: '2')];
      final byHour = ByHourData(
        durationMinutes: 120,
        assignments: [
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
            adjustedQuantity: 1.0,
            timingCategory: TimingCategory.slowConsume,
          ),
        ],
      );

      expect(
        ByHourSyncService.shouldAutoRemoveFromSummary(
          summaryFoods: foods,
          byHourData: byHour,
          foodId: 's1',
        ),
        false,
      );
    });

    test('returns false when food has assignments but no tray qty', () {
      final foods = [_solid('s1', quantity: '1')];
      final byHour = ByHourData(
        durationMinutes: 120,
        assignments: [
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
            adjustedQuantity: 1.0,
            timingCategory: TimingCategory.slowConsume,
          ),
        ],
      );

      // Summary 1 - assigned 1 = 0 remaining, but assigned = 1 > 0 → false
      expect(
        ByHourSyncService.shouldAutoRemoveFromSummary(
          summaryFoods: foods,
          byHourData: byHour,
          foodId: 's1',
        ),
        false,
      );
    });

    test('returns false for nonexistent food', () {
      expect(
        ByHourSyncService.shouldAutoRemoveFromSummary(
          summaryFoods: [],
          byHourData: ByHourData(durationMinutes: 120, assignments: []),
          foodId: 'nonexistent',
        ),
        false,
      );
    });
  });

  // ========================================================================
  // TimingCategory.fromFoodProperties
  // ========================================================================

  group('TimingCategory.fromFoodProperties', () {
    test('isLiquid=true → sipThroughout', () {
      expect(
        TimingCategory.fromFoodProperties(
          isLiquid: true,
          productType: 'real_food',
          isElectrolyte: false,
        ),
        TimingCategory.sipThroughout,
      );
    });

    test('productType=sports_drink → sipThroughout', () {
      expect(
        TimingCategory.fromFoodProperties(
          isLiquid: false,
          productType: 'sports_drink',
          isElectrolyte: false,
        ),
        TimingCategory.sipThroughout,
      );
    });

    test('productType=beverage → sipThroughout', () {
      expect(
        TimingCategory.fromFoodProperties(
          isLiquid: false,
          productType: 'beverage',
          isElectrolyte: false,
        ),
        TimingCategory.sipThroughout,
      );
    });

    test('productType=gel → quickConsume', () {
      expect(
        TimingCategory.fromFoodProperties(
          isLiquid: false,
          productType: 'gel',
          isElectrolyte: false,
        ),
        TimingCategory.quickConsume,
      );
    });

    test('productType=chew → quickConsume', () {
      expect(
        TimingCategory.fromFoodProperties(
          isLiquid: false,
          productType: 'chew',
          isElectrolyte: false,
        ),
        TimingCategory.quickConsume,
      );
    });

    test(
      'isLiquid=true + isElectrolyte=true → sipThroughout (liquids take priority)',
      () {
        expect(
          TimingCategory.fromFoodProperties(
            isLiquid: true,
            productType: 'sports_drink',
            isElectrolyte: true,
          ),
          TimingCategory.sipThroughout,
        );
      },
    );

    test('productType=supplement → electrolyte', () {
      expect(
        TimingCategory.fromFoodProperties(
          isLiquid: false,
          productType: 'supplement',
          isElectrolyte: false,
        ),
        TimingCategory.electrolyte,
      );
    });

    test('productType=bar → slowConsume', () {
      expect(
        TimingCategory.fromFoodProperties(
          isLiquid: false,
          productType: 'bar',
          isElectrolyte: false,
        ),
        TimingCategory.slowConsume,
      );
    });

    test('productType=real_food → slowConsume', () {
      expect(
        TimingCategory.fromFoodProperties(
          isLiquid: false,
          productType: 'real_food',
          isElectrolyte: false,
        ),
        TimingCategory.slowConsume,
      );
    });

    test('unknown productType → slowConsume', () {
      expect(
        TimingCategory.fromFoodProperties(
          isLiquid: false,
          productType: 'unknown_thing',
          isElectrolyte: false,
        ),
        TimingCategory.slowConsume,
      );
    });
  });
}
