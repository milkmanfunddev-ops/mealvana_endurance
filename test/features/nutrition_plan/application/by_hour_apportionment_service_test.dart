import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/by_hour_apportionment_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/time_slot_assignment.dart';

void main() {
  late ByHourApportionmentService service;

  setUp(() {
    service = ByHourApportionmentService();
  });

  FoodItemData _solid(String id) => FoodItemData(
        id: id,
        name: 'Solid $id',
        quantity: '1',
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

  FoodItemData _drink(String id) => FoodItemData(
        id: id,
        name: 'Drink $id',
        quantity: '1',
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

    test('even distribution of solids across hours', () {
      final foods = [
        _solid('s1'),
        _solid('s2'),
        _solid('s3'),
        _solid('s4'),
        _solid('s5'),
        _solid('s6'),
      ];
      final result = service.apportion(
        foodItems: foods,
        durationMinutes: 180,
      );

      expect(result, isNotNull);
      expect(result!.totalHours, 3);

      // Each hour should get 2 solids (6 / 3 = 2 per hour)
      for (int h = 0; h < 3; h++) {
        final hourAssignments = result.assignmentsForHour(h);
        expect(hourAssignments.length, 2,
            reason: 'Hour $h should have 2 items');
      }
    });

    test('drinks are placed at :00 slot with isSipThroughout', () {
      final foods = [_drink('d1'), _solid('s1')];
      final result = service.apportion(
        foodItems: foods,
        durationMinutes: 60,
      );

      expect(result, isNotNull);
      final drinkAssignment = result!.assignments
          .firstWhere((a) => a.foodItemId == 'd1');
      expect(drinkAssignment.timeSlot.slotIndex, 0);
      expect(drinkAssignment.isSipThroughout, true);
    });

    test('drinks are distributed evenly across hours', () {
      final foods = [_drink('d1'), _drink('d2'), _drink('d3')];
      final result = service.apportion(
        foodItems: foods,
        durationMinutes: 180,
      );

      expect(result, isNotNull);
      // One drink per hour
      for (int h = 0; h < 3; h++) {
        final hourDrinks = result!.assignmentsForHour(h)
            .where((a) => a.isSipThroughout)
            .toList();
        expect(hourDrinks.length, 1,
            reason: 'Hour $h should have 1 drink');
      }
    });

    test('solids prefer :15, :30, :45 over :00', () {
      final foods = [_solid('s1'), _solid('s2'), _solid('s3')];
      final result = service.apportion(
        foodItems: foods,
        durationMinutes: 60,
      );

      expect(result, isNotNull);
      // With 3 solids in 1 hour, they should go to slots 1, 2, 3 (:15, :30, :45)
      final slots = result!.assignments.map((a) => a.timeSlot.slotIndex).toSet();
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

    test('more items than slots: stacking', () {
      // 8 solids in 1 hour = 4 slots, some will stack
      final foods = List.generate(8, (i) => _solid('s$i'));
      final result = service.apportion(
        foodItems: foods,
        durationMinutes: 60,
      );

      expect(result, isNotNull);
      expect(result!.assignments.length, 8);
      // All items should be in hour 0
      for (final a in result.assignments) {
        expect(a.timeSlot.hourIndex, 0);
      }
    });

    test('all drinks: each at :00', () {
      final foods = [_drink('d1'), _drink('d2')];
      final result = service.apportion(
        foodItems: foods,
        durationMinutes: 120,
      );

      expect(result, isNotNull);
      for (final a in result!.assignments) {
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
      expect(result!.assignments.length, 3);
      expect(result.totalHours, 1);

      final drink = result.assignments.firstWhere((a) => a.foodItemId == 'd1');
      expect(drink.timeSlot.slotIndex, 0);
      expect(drink.isSipThroughout, true);
    });

    test('12-hour ultra: items distributed correctly', () {
      final foods = List.generate(12, (i) => _solid('s$i'));
      final result = service.apportion(
        foodItems: foods,
        durationMinutes: 720,
      );

      expect(result, isNotNull);
      expect(result!.totalHours, 12);
      // Each hour should get 1 solid
      for (int h = 0; h < 12; h++) {
        final hourAssignments = result.assignmentsForHour(h);
        expect(hourAssignments.length, 1,
            reason: 'Hour $h should have 1 item');
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
          ),
          const TimeSlotAssignment(
            foodItemId: 's2',
            timeSlot: TimeSlot(hourIndex: 1, slotIndex: 1),
          ),
        ],
      );

      // s2 was deleted
      final updated = service.reapportion(
        existing: original,
        currentFoodItems: [_solid('s1')],
      );

      expect(updated.assignments.length, 1);
      expect(updated.assignments.first.foodItemId, 's1');
    });

    test('adds assignment for new food', () {
      final original = ByHourData(
        durationMinutes: 120,
        assignments: [
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
          ),
        ],
      );

      final updated = service.reapportion(
        existing: original,
        currentFoodItems: [_solid('s1'), _solid('s2')],
      );

      expect(updated.assignments.length, 2);
      expect(
        updated.assignments.any((a) => a.foodItemId == 's2'),
        true,
      );
    });

    test('preserves existing assignments when adding new food', () {
      final original = ByHourData(
        durationMinutes: 120,
        assignments: [
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 2),
          ),
        ],
      );

      final updated = service.reapportion(
        existing: original,
        currentFoodItems: [_solid('s1'), _solid('s2')],
      );

      // s1 should stay at its original slot
      final s1Assignment =
          updated.assignments.firstWhere((a) => a.foodItemId == 's1');
      expect(s1Assignment.timeSlot.slotIndex, 2);
      expect(s1Assignment.timeSlot.hourIndex, 0);
    });
  });
}
