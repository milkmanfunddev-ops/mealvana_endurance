import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/by_hour_apportionment_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/time_slot_assignment.dart';

void main() {
  late ByHourApportionmentService service;

  setUp(() {
    service = ByHourApportionmentService();
  });

  FoodItemData _solid(String id, {String quantity = '1'}) => FoodItemData(
        id: id,
        name: 'Solid $id',
        quantity: quantity,
        isDrink: false,
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
        nutritionalInfo: const NutritionalInfo(
          calories: 50,
          carbs: 10,
          protein: 0,
          fat: 0,
          sodium: 200,
          fluids: 500,
        ),
      );

  group('ByHourApportionmentService.apportion', () {
    test('returns null for duration < 60 minutes', () {
      final result = service.apportion(
        foodItems: [_solid('s1')],
        durationMinutes: 45,
      );
      expect(result, isNull);
    });

    test('returns empty assignments for empty food list', () {
      final result = service.apportion(
        foodItems: [],
        durationMinutes: 120,
      );
      expect(result, isNotNull);
      expect(result!.assignments, isEmpty);
      expect(result.durationMinutes, 120);
    });

    test('each food creates one assignment per hour (split quantity)', () {
      final foods = [
        _solid('s1', quantity: '3 servings'),
        _solid('s2', quantity: '3 servings'),
      ];
      final result = service.apportion(
        foodItems: foods,
        durationMinutes: 180,
      );

      expect(result, isNotNull);
      expect(result!.totalHours, 3);
      // 2 solids × 3 hours = 6 assignments
      expect(result.assignments.length, 6);

      // Each hour should have 2 solid assignments
      for (int h = 0; h < 3; h++) {
        final hourAssignments = result.assignmentsForHour(h);
        expect(hourAssignments.length, 2,
            reason: 'Hour $h should have 2 items');
      }
    });

    test('adjustedQuantity is originalQuantity / totalHours', () {
      final foods = [_solid('s1', quantity: '3 servings')];
      final result = service.apportion(
        foodItems: foods,
        durationMinutes: 180,
      );

      expect(result, isNotNull);
      // 3 servings / 3 hours = 1.0 per hour
      for (final a in result!.assignments) {
        expect(a.adjustedQuantity, 1.0);
      }
    });

    test('drinks are placed at :00 slot with isSipThroughout in every hour', () {
      final foods = [_drink('d1', quantity: '2'), _solid('s1')];
      final result = service.apportion(
        foodItems: foods,
        durationMinutes: 120,
      );

      expect(result, isNotNull);
      final drinkAssignments = result!.assignments
          .where((a) => a.foodItemId == 'd1')
          .toList();
      // Drink should appear in both hours
      expect(drinkAssignments.length, 2);
      for (final a in drinkAssignments) {
        expect(a.timeSlot.slotIndex, 0);
        expect(a.isSipThroughout, true);
        expect(a.adjustedQuantity, 1.0); // 2 / 2 hours
      }
    });

    test('solids prefer :15, :30, :45 over :00', () {
      final foods = [_solid('s1'), _solid('s2'), _solid('s3')];
      final result = service.apportion(
        foodItems: foods,
        durationMinutes: 60,
      );

      expect(result, isNotNull);
      // Each solid has 1 assignment (1 hour)
      expect(result!.assignments.length, 3);
      // Within hour 0, they should go to slots 1, 2, 3 (:15, :30, :45)
      final slots = result.assignments.map((a) => a.timeSlot.slotIndex).toSet();
      expect(slots, containsAll([1, 2, 3]));
    });

    test('partial last hour: 150 min = 3 hours, last hour has 2 slots', () {
      final result = service.apportion(
        foodItems: [_solid('s1')],
        durationMinutes: 150,
      );

      expect(result, isNotNull);
      expect(result!.totalHours, 3);
      expect(result.lastHourSlotCount, 2);
      expect(result.slotCountForHour(0), 4);
      expect(result.slotCountForHour(1), 4);
      expect(result.slotCountForHour(2), 2);
    });

    test('single solid in 1 hour: 1 assignment with full quantity', () {
      final foods = [_solid('s1', quantity: '2 gels')];
      final result = service.apportion(
        foodItems: foods,
        durationMinutes: 60,
      );

      expect(result, isNotNull);
      expect(result!.assignments.length, 1);
      expect(result.assignments.first.adjustedQuantity, 2.0); // 2 / 1 hour
    });

    test('all drinks: each at :00 in every hour', () {
      final foods = [_drink('d1'), _drink('d2')];
      final result = service.apportion(
        foodItems: foods,
        durationMinutes: 120,
      );

      expect(result, isNotNull);
      // 2 drinks × 2 hours = 4 assignments
      expect(result!.assignments.length, 4);
      for (final a in result.assignments) {
        expect(a.timeSlot.slotIndex, 0);
        expect(a.isSipThroughout, true);
      }
    });

    test('single hour with mixed items', () {
      final foods = [_drink('d1'), _solid('s1'), _solid('s2')];
      final result = service.apportion(
        foodItems: foods,
        durationMinutes: 60,
      );

      expect(result, isNotNull);
      // 1 drink + 2 solids, all in 1 hour = 3 assignments
      expect(result!.assignments.length, 3);
      expect(result.totalHours, 1);

      final drink = result.assignments.firstWhere((a) => a.foodItemId == 'd1');
      expect(drink.timeSlot.slotIndex, 0);
      expect(drink.isSipThroughout, true);
    });

    test('12-hour ultra: each item has 12 assignments', () {
      final foods = [_solid('s1', quantity: '12')];
      final result = service.apportion(
        foodItems: foods,
        durationMinutes: 720,
      );

      expect(result, isNotNull);
      expect(result!.totalHours, 12);
      // 1 food × 12 hours = 12 assignments
      expect(result.assignments.length, 12);
      for (final a in result.assignments) {
        expect(a.adjustedQuantity, 1.0); // 12 / 12
      }
    });
  });

  group('ByHourApportionmentService.reapportion', () {
    test('removes assignments for deleted foods', () {
      final original = ByHourData(
        durationMinutes: 120,
        assignments: [
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
            adjustedQuantity: 0.5,
          ),
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 1, slotIndex: 1),
            adjustedQuantity: 0.5,
          ),
          const TimeSlotAssignment(
            foodItemId: 's2',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 2),
            adjustedQuantity: 0.5,
          ),
          const TimeSlotAssignment(
            foodItemId: 's2',
            timeSlot: TimeSlot(hourIndex: 1, slotIndex: 2),
            adjustedQuantity: 0.5,
          ),
        ],
      );

      // s2 was deleted
      final updated = service.reapportion(
        existing: original,
        currentFoodItems: [_solid('s1')],
      );

      expect(updated.assignments.length, 2);
      expect(updated.assignments.every((a) => a.foodItemId == 's1'), true);
    });

    test('adds new food split across all hours by default', () {
      final original = ByHourData(
        durationMinutes: 120,
        assignments: [
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
            adjustedQuantity: 0.5,
          ),
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 1, slotIndex: 1),
            adjustedQuantity: 0.5,
          ),
        ],
      );

      final updated = service.reapportion(
        existing: original,
        currentFoodItems: [_solid('s1'), _solid('s2', quantity: '2')],
      );

      // s1 kept (2 assignments) + s2 added (2 assignments, one per hour)
      expect(updated.assignments.length, 4);
      final s2Assignments = updated.assignments.where((a) => a.foodItemId == 's2').toList();
      expect(s2Assignments.length, 2);
      // Each s2 assignment gets 2/2 = 1.0
      for (final a in s2Assignments) {
        expect(a.adjustedQuantity, 1.0);
      }
    });

    test('targetHourIndex places food only in that hour', () {
      final original = ByHourData(
        durationMinutes: 180,
        assignments: [
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
            adjustedQuantity: 1.0,
          ),
        ],
      );

      final updated = service.reapportion(
        existing: original,
        currentFoodItems: [_solid('s1', quantity: '3'), _solid('s2', quantity: '2')],
        targetHourIndex: 1,
      );

      // s1 kept (1) + s2 added to hour 1 only (1)
      final s2Assignments = updated.assignments.where((a) => a.foodItemId == 's2').toList();
      expect(s2Assignments.length, 1);
      expect(s2Assignments.first.timeSlot.hourIndex, 1);
      expect(s2Assignments.first.adjustedQuantity, 2.0); // Full quantity
    });

    test('preserves existing assignments when adding new food', () {
      final original = ByHourData(
        durationMinutes: 120,
        assignments: [
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 2),
            adjustedQuantity: 0.5,
          ),
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 1, slotIndex: 2),
            adjustedQuantity: 0.5,
          ),
        ],
      );

      final updated = service.reapportion(
        existing: original,
        currentFoodItems: [_solid('s1'), _solid('s2')],
      );

      // s1 should stay at its original slots
      final s1Assignments =
          updated.assignments.where((a) => a.foodItemId == 's1').toList();
      expect(s1Assignments.length, 2);
      expect(s1Assignments[0].timeSlot.slotIndex, 2);
      expect(s1Assignments[0].timeSlot.hourIndex, 0);
    });
  });

  group('parseQuantity', () {
    test('parses integer quantity', () {
      expect(
        ByHourApportionmentService.parseQuantity(_solid('s1', quantity: '3 servings')),
        3.0,
      );
    });

    test('parses decimal quantity', () {
      expect(
        ByHourApportionmentService.parseQuantity(_solid('s1', quantity: '1.5 gels')),
        1.5,
      );
    });

    test('defaults to 1.0 for non-numeric', () {
      expect(
        ByHourApportionmentService.parseQuantity(_solid('s1', quantity: 'some food')),
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
}
