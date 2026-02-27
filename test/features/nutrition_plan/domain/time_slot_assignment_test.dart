import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/time_slot_assignment.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';

void main() {
  group('TimeSlot', () {
    test('displayLabel formats correctly', () {
      expect(const TimeSlot(hourIndex: 0, slotIndex: 0).displayLabel, '0:00');
      expect(const TimeSlot(hourIndex: 0, slotIndex: 1).displayLabel, '0:15');
      expect(const TimeSlot(hourIndex: 0, slotIndex: 2).displayLabel, '0:30');
      expect(const TimeSlot(hourIndex: 0, slotIndex: 3).displayLabel, '0:45');
      expect(const TimeSlot(hourIndex: 1, slotIndex: 0).displayLabel, '1:00');
      expect(const TimeSlot(hourIndex: 2, slotIndex: 3).displayLabel, '2:45');
    });

    test('absoluteMinutes calculates correctly', () {
      expect(
          const TimeSlot(hourIndex: 0, slotIndex: 0).absoluteMinutes, 0);
      expect(
          const TimeSlot(hourIndex: 0, slotIndex: 3).absoluteMinutes, 45);
      expect(
          const TimeSlot(hourIndex: 1, slotIndex: 0).absoluteMinutes, 60);
      expect(
          const TimeSlot(hourIndex: 2, slotIndex: 1).absoluteMinutes, 135);
    });

    test('JSON round-trip', () {
      const original = TimeSlot(hourIndex: 1, slotIndex: 2);
      final json = original.toJson();
      final restored = TimeSlot.fromJson(json);
      expect(restored, equals(original));
    });

    test('equality', () {
      const a = TimeSlot(hourIndex: 1, slotIndex: 2);
      const b = TimeSlot(hourIndex: 1, slotIndex: 2);
      const c = TimeSlot(hourIndex: 1, slotIndex: 3);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('TimeSlotAssignment', () {
    test('JSON round-trip', () {
      const original = TimeSlotAssignment(
        foodItemId: 'food-123',
        timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
        isSipThroughout: true,
      );
      final json = original.toJson();
      final restored = TimeSlotAssignment.fromJson(json);
      expect(restored.foodItemId, 'food-123');
      expect(restored.timeSlot, const TimeSlot(hourIndex: 0, slotIndex: 1));
      expect(restored.isSipThroughout, true);
    });

    test('isSipThroughout defaults to false', () {
      final json = {
        'foodItemId': 'food-456',
        'timeSlot': {'hourIndex': 0, 'slotIndex': 0},
      };
      final assignment = TimeSlotAssignment.fromJson(json);
      expect(assignment.isSipThroughout, false);
    });

    test('copyWith creates modified copy', () {
      const original = TimeSlotAssignment(
        foodItemId: 'food-1',
        timeSlot: TimeSlot(hourIndex: 0, slotIndex: 0),
      );
      final moved = original.copyWith(
        timeSlot: const TimeSlot(hourIndex: 1, slotIndex: 2),
      );
      expect(moved.foodItemId, 'food-1');
      expect(moved.timeSlot.hourIndex, 1);
      expect(moved.timeSlot.slotIndex, 2);
    });

    test('adjustedQuantity JSON round-trip', () {
      const original = TimeSlotAssignment(
        foodItemId: 'food-1',
        timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
        adjustedQuantity: 1.5,
      );
      final json = original.toJson();
      expect(json['adjustedQuantity'], 1.5);

      final restored = TimeSlotAssignment.fromJson(json);
      expect(restored.adjustedQuantity, 1.5);
    });

    test('adjustedQuantity defaults to null (backward compat)', () {
      final json = {
        'foodItemId': 'food-1',
        'timeSlot': {'hourIndex': 0, 'slotIndex': 0},
      };
      final assignment = TimeSlotAssignment.fromJson(json);
      expect(assignment.adjustedQuantity, isNull);
    });

    test('adjustedQuantity omitted from JSON when null', () {
      const original = TimeSlotAssignment(
        foodItemId: 'food-1',
        timeSlot: TimeSlot(hourIndex: 0, slotIndex: 0),
      );
      final json = original.toJson();
      expect(json.containsKey('adjustedQuantity'), false);
    });

    test('copyWith preserves adjustedQuantity', () {
      const original = TimeSlotAssignment(
        foodItemId: 'food-1',
        timeSlot: TimeSlot(hourIndex: 0, slotIndex: 0),
        adjustedQuantity: 2.0,
      );
      final moved = original.copyWith(
        timeSlot: const TimeSlot(hourIndex: 1, slotIndex: 0),
      );
      expect(moved.adjustedQuantity, 2.0);
    });
  });

  group('ByHourData', () {
    test('JSON round-trip', () {
      const original = ByHourData(
        durationMinutes: 180,
        assignments: [
          TimeSlotAssignment(
            foodItemId: 'food-1',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
          ),
          TimeSlotAssignment(
            foodItemId: 'food-2',
            timeSlot: TimeSlot(hourIndex: 1, slotIndex: 0),
            isSipThroughout: true,
          ),
        ],
      );

      final json = original.toJson();
      // Full JSON serialization round-trip (via jsonEncode/Decode)
      final jsonStr = jsonEncode(json);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final restored = ByHourData.fromJson(decoded);

      expect(restored.durationMinutes, 180);
      expect(restored.assignments.length, 2);
      expect(restored.assignments[0].foodItemId, 'food-1');
      expect(restored.assignments[1].isSipThroughout, true);
    });

    test('totalHours calculates correctly', () {
      expect(
        const ByHourData(durationMinutes: 60, assignments: []).totalHours,
        1,
      );
      expect(
        const ByHourData(durationMinutes: 120, assignments: []).totalHours,
        2,
      );
      expect(
        const ByHourData(durationMinutes: 150, assignments: []).totalHours,
        3,
      );
      expect(
        const ByHourData(durationMinutes: 90, assignments: []).totalHours,
        2,
      );
    });

    test('lastHourSlotCount for partial hours', () {
      expect(
        const ByHourData(durationMinutes: 60, assignments: [])
            .lastHourSlotCount,
        4,
      );
      expect(
        const ByHourData(durationMinutes: 90, assignments: [])
            .lastHourSlotCount,
        2,
      );
      expect(
        const ByHourData(durationMinutes: 75, assignments: [])
            .lastHourSlotCount,
        1,
      );
      expect(
        const ByHourData(durationMinutes: 150, assignments: [])
            .lastHourSlotCount,
        2,
      );
    });

    test('assignmentsForHour filters and sorts correctly', () {
      const data = ByHourData(
        durationMinutes: 180,
        assignments: [
          TimeSlotAssignment(
            foodItemId: 'f3',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 3),
          ),
          TimeSlotAssignment(
            foodItemId: 'f1',
            timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
          ),
          TimeSlotAssignment(
            foodItemId: 'f2',
            timeSlot: TimeSlot(hourIndex: 1, slotIndex: 0),
          ),
        ],
      );

      final hour0 = data.assignmentsForHour(0);
      expect(hour0.length, 2);
      // Should be sorted by slotIndex
      expect(hour0[0].foodItemId, 'f1');
      expect(hour0[1].foodItemId, 'f3');

      final hour1 = data.assignmentsForHour(1);
      expect(hour1.length, 1);
      expect(hour1[0].foodItemId, 'f2');

      final hour2 = data.assignmentsForHour(2);
      expect(hour2, isEmpty);
    });
  });

  group('PlanSection.byHourData integration', () {
    test('fromJson parses byHourData when present', () {
      final json = {
        'id': 'during_run',
        'title': 'During Run',
        'foodItems': <dynamic>[],
        'byHourData': {
          'durationMinutes': 120,
          'assignments': [
            {
              'foodItemId': 'gel-1',
              'timeSlot': {'hourIndex': 0, 'slotIndex': 1},
              'isSipThroughout': false,
            },
          ],
        },
      };

      final section = PlanSection.fromJson(json);
      expect(section.byHourData, isNotNull);
      expect(section.byHourData!.durationMinutes, 120);
      expect(section.byHourData!.assignments.length, 1);
      expect(section.supportsByHour, true);
    });

    test('fromJson handles missing byHourData (backward compatible)', () {
      final json = {
        'id': 'during_run',
        'title': 'During Run',
        'foodItems': <dynamic>[],
      };

      final section = PlanSection.fromJson(json);
      expect(section.byHourData, isNull);
      expect(section.supportsByHour, false);
    });

    test('toJson includes byHourData when present', () {
      const section = PlanSection(
        id: 'during_run',
        title: 'During Run',
        foodItems: [],
        byHourData: ByHourData(
          durationMinutes: 60,
          assignments: [
            TimeSlotAssignment(
              foodItemId: 'gel-1',
              timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
            ),
          ],
        ),
      );

      final json = section.toJson();
      expect(json.containsKey('byHourData'), true);
      expect(json['byHourData']['durationMinutes'], 60);
    });

    test('toJson omits byHourData when null', () {
      const section = PlanSection(
        id: 'during_run',
        title: 'During Run',
        foodItems: [],
      );

      final json = section.toJson();
      expect(json.containsKey('byHourData'), false);
    });

    test('copyWith preserves byHourData', () {
      const original = PlanSection(
        id: 'during_run',
        title: 'During Run',
        foodItems: [],
        byHourData: ByHourData(durationMinutes: 120, assignments: []),
      );

      final copy = original.copyWith(title: 'Updated');
      expect(copy.byHourData, isNotNull);
      expect(copy.byHourData!.durationMinutes, 120);
    });

    test('copyWith with clearByHourData removes byHourData', () {
      const original = PlanSection(
        id: 'during_run',
        title: 'During Run',
        foodItems: [],
        byHourData: ByHourData(durationMinutes: 120, assignments: []),
      );

      final copy = original.copyWith(clearByHourData: true);
      expect(copy.byHourData, isNull);
    });

    test('supportsByHour returns false for short durations', () {
      const section = PlanSection(
        id: 'during_run',
        title: 'During Run',
        foodItems: [],
        byHourData: ByHourData(durationMinutes: 45, assignments: []),
      );
      expect(section.supportsByHour, false);
    });
  });
}
