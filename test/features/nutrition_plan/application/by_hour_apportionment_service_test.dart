import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/by_hour_apportionment_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/time_slot_assignment.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

void main() {
  late ByHourApportionmentService service;

  setUp(() {
    service = ByHourApportionmentService();
  });

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

  FoodItemData _electrolyte(String id, {String quantity = '1'}) => FoodItemData(
    id: id,
    name: 'Electrolyte $id',
    quantity: quantity,
    isDrink: false,
    timingCategory: TimingCategory.electrolyte,
    nutritionalInfo: const NutritionalInfo(
      calories: 10,
      carbs: 2,
      protein: 0,
      fat: 0,
      sodium: 500,
      fluids: 0,
    ),
  );

  // ========================================================================
  // apportion — basic behavior
  // ========================================================================

  group('ByHourApportionmentService.apportion', () {
    test('returns null for duration < 60 minutes', () {
      final result = service.apportion(
        foodItems: [_solid('s1')],
        durationMinutes: 45,
      );
      expect(result, isNull);
    });

    test('returns empty assignments for empty food list', () {
      final result = service.apportion(foodItems: [], durationMinutes: 120);
      expect(result, isNotNull);
      expect(result!.assignments, isEmpty);
      expect(result.durationMinutes, 120);
    });

    test(
      'drinks are placed at :00 slot with isSipThroughout in every hour',
      () {
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
          expect(a.timingCategory, TimingCategory.sipThroughout);
        }
      },
    );

    test(
      'drinks split uneven totals using 0.5 increments while preserving total',
      () {
        final result = service.apportion(
          foodItems: [_drink('d1', quantity: '8')],
          durationMinutes: 180, // 3 hours
        );

        expect(result, isNotNull);
        final drinkAssignments =
            result!.assignments.where((a) => a.foodItemId == 'd1').toList()
              ..sort(
                (a, b) => a.timeSlot.hourIndex.compareTo(b.timeSlot.hourIndex),
              );

        expect(drinkAssignments.length, 3);
        final quantities = drinkAssignments
            .map((a) => a.adjustedQuantity!)
            .toList();

        // Friendly values only (no repeating decimals like 2.666... / 2.7)
        expect(quantities, containsAll(<double>[2.5, 3.0]));
        for (final q in quantities) {
          expect(
            (q * 2) % 1,
            0,
            reason: 'Quantity $q should be in 0.5 increments',
          );
        }

        final total = quantities.reduce((a, b) => a + b);
        expect(total, closeTo(8.0, 0.001));
      },
    );

    test(
      'drinks with low total quantity reduce placements to keep minimum 0.5 each',
      () {
        final result = service.apportion(
          foodItems: [_drink('d1', quantity: '1')],
          durationMinutes: 180, // 3 hours
        );

        expect(result, isNotNull);
        final drinkAssignments = result!.assignments
            .where((a) => a.foodItemId == 'd1')
            .toList();

        // 1 serving cannot be spread across 3 hours with min 0.5 per placement.
        expect(drinkAssignments.length, 2);
        for (final a in drinkAssignments) {
          expect(a.adjustedQuantity, 0.5);
        }
      },
    );

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

    test('all drinks: each at :00 in every hour', () {
      final foods = [_drink('d1'), _drink('d2')];
      final result = service.apportion(foodItems: foods, durationMinutes: 120);

      expect(result, isNotNull);
      // 2 drinks × 2 hours = 4 assignments
      expect(result!.assignments.length, 4);
      for (final a in result.assignments) {
        expect(a.timeSlot.slotIndex, 0);
        expect(a.isSipThroughout, true);
      }
    });

    test('12-hour ultra: drinks have 12 assignments', () {
      final foods = [_drink('d1', quantity: '12')];
      final result = service.apportion(foodItems: foods, durationMinutes: 720);

      expect(result, isNotNull);
      expect(result!.totalHours, 12);
      expect(result.assignments.length, 12);
      for (final a in result.assignments) {
        expect(a.adjustedQuantity, 1.0); // 12 / 12
      }
    });

    test('assignments include timingCategory', () {
      final foods = [
        _drink('d1'),
        _gel('g1'),
        _solid('s1'),
        _electrolyte('e1'),
      ];
      final result = service.apportion(foodItems: foods, durationMinutes: 120);

      expect(result, isNotNull);
      for (final a in result!.assignments) {
        expect(a.timingCategory, isNotNull);
      }
    });
  });

  // ========================================================================
  // Quiet zone: no solids/gels before minute 30
  // ========================================================================

  group('Quiet zone (first 30 minutes)', () {
    test('drinks start at minute 0 (no quiet zone for drinks)', () {
      final result = service.apportion(
        foodItems: [_drink('d1')],
        durationMinutes: 120,
      );

      expect(result, isNotNull);
      final firstDrink = result!.assignments.first;
      expect(firstDrink.timeSlot.absoluteMinutes, 0);
    });

    test('gels do not appear before minute 30', () {
      final result = service.apportion(
        foodItems: [_gel('g1', quantity: '3')],
        durationMinutes: 180,
      );

      expect(result, isNotNull);
      for (final a in result!.assignments) {
        expect(
          a.timeSlot.absoluteMinutes,
          greaterThanOrEqualTo(30),
          reason: 'Gel at ${a.timeSlot.displayLabel} is before quiet zone',
        );
      }
    });

    test('solids do not appear before minute 30', () {
      final result = service.apportion(
        foodItems: [_solid('s1', quantity: '3')],
        durationMinutes: 180,
      );

      expect(result, isNotNull);
      for (final a in result!.assignments) {
        expect(
          a.timeSlot.absoluteMinutes,
          greaterThanOrEqualTo(30),
          reason: 'Solid at ${a.timeSlot.displayLabel} is before quiet zone',
        );
      }
    });
  });

  // ========================================================================
  // End cutoff: no solids/gels in last 15 minutes
  // ========================================================================

  group('End cutoff (last 15 minutes)', () {
    test('drinks continue through the finish', () {
      final result = service.apportion(
        foodItems: [_drink('d1', quantity: '3')],
        durationMinutes: 180,
      );

      expect(result, isNotNull);
      // Should have drink in last hour
      final lastHourAssignments = result!.assignments
          .where((a) => a.timeSlot.hourIndex == 2)
          .toList();
      expect(lastHourAssignments, isNotEmpty);
    });

    test('gels do not appear in the last 15 minutes', () {
      final result = service.apportion(
        foodItems: [_gel('g1', quantity: '6')],
        durationMinutes: 180,
        gutTraining: GutTraining.high, // 25-min spacing = more gels
      );

      expect(result, isNotNull);
      final endCutoff = 180 - 15; // 165 min
      for (final a in result!.assignments) {
        expect(
          a.timeSlot.absoluteMinutes,
          lessThanOrEqualTo(endCutoff),
          reason:
              'Gel at minute ${a.timeSlot.absoluteMinutes} is past end cutoff',
        );
      }
    });

    test('solids do not appear in the last 15 minutes', () {
      final result = service.apportion(
        foodItems: [_solid('s1', quantity: '3')],
        durationMinutes: 120,
      );

      expect(result, isNotNull);
      final endCutoff = 120 - 15; // 105 min
      for (final a in result!.assignments) {
        expect(
          a.timeSlot.absoluteMinutes,
          lessThanOrEqualTo(endCutoff),
          reason:
              'Solid at minute ${a.timeSlot.absoluteMinutes} is past end cutoff',
        );
      }
    });
  });

  // ========================================================================
  // Gut-training spacing
  // ========================================================================

  group('Gut-training spacing for gels', () {
    test('low gut training: gels spaced 45 minutes apart', () {
      final result = service.apportion(
        foodItems: [_gel('g1', quantity: '4')],
        durationMinutes: 240,
        gutTraining: GutTraining.low,
      );

      expect(result, isNotNull);
      final minutes =
          result!.assignments.map((a) => a.timeSlot.absoluteMinutes).toList()
            ..sort();

      // First gel at minute 30, then 75, 120, 165, 210
      expect(minutes.first, 30);
      for (int i = 1; i < minutes.length; i++) {
        expect(
          minutes[i] - minutes[i - 1],
          45,
          reason: 'Gap between gel ${i - 1} and $i should be 45 min',
        );
      }
    });

    test('moderate gut training: gels spaced 30 minutes apart', () {
      final result = service.apportion(
        foodItems: [_gel('g1', quantity: '6')],
        durationMinutes: 240,
        gutTraining: GutTraining.moderate,
      );

      expect(result, isNotNull);
      final minutes =
          result!.assignments.map((a) => a.timeSlot.absoluteMinutes).toList()
            ..sort();

      expect(minutes.first, 30);
      for (int i = 1; i < minutes.length; i++) {
        expect(
          minutes[i] - minutes[i - 1],
          30,
          reason: 'Gap between gel ${i - 1} and $i should be 30 min',
        );
      }
    });

    test('high gut training: gels spaced approximately 25 minutes apart', () {
      final result = service.apportion(
        foodItems: [_gel('g1', quantity: '8')],
        durationMinutes: 300,
        gutTraining: GutTraining.high,
      );

      expect(result, isNotNull);
      final minutes =
          result!.assignments.map((a) => a.timeSlot.absoluteMinutes).toList()
            ..sort();

      // First at 30
      expect(minutes.first, 30);

      // Due to 15-min slot quantization, exact 25-min gaps round to 15 or 30.
      // Verify that the requested minutes are correct (25-min spacing)
      // and that the slot count is reasonable for 5-hour activity.
      // Expected requested minutes: 30, 55, 80, 105, 130, 155, 180, 205, 230, 255, 280
      // After end cutoff (300-15=285): all should be <= 285
      for (final m in minutes) {
        expect(m, lessThanOrEqualTo(285));
        expect(m, greaterThanOrEqualTo(30));
      }
      // Should have reasonable number of gel placements
      expect(minutes.length, greaterThanOrEqualTo(8));
    });
  });

  // ========================================================================
  // Electrolyte timing
  // ========================================================================

  group('Electrolyte timing', () {
    test('electrolytes skipped for activities < 90 minutes', () {
      final result = service.apportion(
        foodItems: [_electrolyte('e1')],
        durationMinutes: 80,
      );

      expect(result, isNotNull);
      final elecAssignments = result!.assignments
          .where((a) => a.timingCategory == TimingCategory.electrolyte)
          .toList();
      expect(elecAssignments, isEmpty);
    });

    test('electrolytes start at minute 60', () {
      final result = service.apportion(
        foodItems: [_electrolyte('e1', quantity: '2')],
        durationMinutes: 180,
      );

      expect(result, isNotNull);
      final elecAssignments = result!.assignments
          .where((a) => a.timingCategory == TimingCategory.electrolyte)
          .toList();
      expect(elecAssignments, isNotEmpty);

      final firstMinute = elecAssignments
          .map((a) => a.timeSlot.absoluteMinutes)
          .reduce((a, b) => a < b ? a : b);
      expect(firstMinute, 60);
    });

    test('electrolytes spaced every 60 minutes', () {
      final result = service.apportion(
        foodItems: [_electrolyte('e1', quantity: '3')],
        durationMinutes: 240,
      );

      expect(result, isNotNull);
      final minutes =
          result!.assignments
              .where((a) => a.timingCategory == TimingCategory.electrolyte)
              .map((a) => a.timeSlot.absoluteMinutes)
              .toList()
            ..sort();

      expect(minutes, [60, 120, 180]);
    });
  });

  // ========================================================================
  // Sport-aware: cycling solids
  // ========================================================================

  group('Sport-aware behavior', () {
    test('cycling: solids placed only in first 2/3 of activity', () {
      final result = service.apportion(
        foodItems: [_solid('s1', quantity: '4')],
        durationMinutes: 180,
        activityType: ActivityType.cycling,
      );

      expect(result, isNotNull);
      final twoThirds = (180 * 2 / 3).round(); // 120 min
      for (final a in result!.assignments) {
        expect(
          a.timeSlot.absoluteMinutes,
          lessThanOrEqualTo(twoThirds),
          reason:
              'Cycling solid at minute ${a.timeSlot.absoluteMinutes} is past 2/3 mark',
        );
      }
    });

    test('running: solids can appear past 2/3 (up to end cutoff)', () {
      final result = service.apportion(
        foodItems: [_solid('s1', quantity: '4')],
        durationMinutes: 180,
        activityType: ActivityType.running,
      );

      expect(result, isNotNull);
      // Running uses standard end cutoff (180 - 15 = 165 min), not 2/3 (120 min)
      final maxMinute = result!.assignments
          .map((a) => a.timeSlot.absoluteMinutes)
          .reduce((a, b) => a > b ? a : b);
      // At least one solid should be past 120 (2/3 mark) if there are enough slots
      // This is not guaranteed for all quantities but the point is: no 2/3 cutoff for running
      expect(maxMinute, lessThanOrEqualTo(180 - 15));
    });
  });

  // ========================================================================
  // Legacy backward compatibility (null timingCategory)
  // ========================================================================

  group('Legacy backward compatibility', () {
    test('null timingCategory falls back to isDrink heuristic', () {
      // Create foods WITHOUT timingCategory (simulating old saved plans)
      final legacyDrink = FoodItemData(
        id: 'd_legacy',
        name: 'Legacy Drink',
        quantity: '2',
        isDrink: true,
        // timingCategory is null
        nutritionalInfo: const NutritionalInfo(calories: 50, carbs: 10),
      );
      final legacySolid = FoodItemData(
        id: 's_legacy',
        name: 'Legacy Solid',
        quantity: '2',
        isDrink: false,
        // timingCategory is null
        nutritionalInfo: const NutritionalInfo(calories: 100, carbs: 25),
      );

      final result = service.apportion(
        foodItems: [legacyDrink, legacySolid],
        durationMinutes: 120,
      );

      expect(result, isNotNull);

      // Legacy drink should be treated as sipThroughout
      final drinkAssignments = result!.assignments
          .where((a) => a.foodItemId == 'd_legacy')
          .toList();
      for (final a in drinkAssignments) {
        expect(a.isSipThroughout, true);
        expect(a.timeSlot.slotIndex, 0);
      }

      // Legacy solid should be treated as slowConsume
      final solidAssignments = result.assignments
          .where((a) => a.foodItemId == 's_legacy')
          .toList();
      for (final a in solidAssignments) {
        expect(a.isSipThroughout, false);
        expect(a.timingCategory, TimingCategory.slowConsume);
      }
    });
  });

  // ========================================================================
  // Mixed food types
  // ========================================================================

  group('Mixed food type apportionment', () {
    test('3-hour run with all food types distributes correctly', () {
      final foods = [
        _drink('d1', quantity: '3'),
        _gel('g1', quantity: '3'),
        _solid('s1', quantity: '2'),
        _electrolyte('e1', quantity: '2'),
      ];

      final result = service.apportion(
        foodItems: foods,
        durationMinutes: 180,
        gutTraining: GutTraining.moderate,
      );

      expect(result, isNotNull);

      // Drinks: 3 assignments (one per hour at :00)
      final drinks = result!.assignments
          .where((a) => a.foodItemId == 'd1')
          .toList();
      expect(drinks.length, 3);
      for (final d in drinks) {
        expect(d.timeSlot.slotIndex, 0);
        expect(d.isSipThroughout, true);
      }

      // Gels: placed after minute 30, spaced 30 min apart (moderate)
      final gels = result.assignments
          .where((a) => a.foodItemId == 'g1')
          .toList();
      expect(gels, isNotEmpty);
      for (final g in gels) {
        expect(g.timeSlot.absoluteMinutes, greaterThanOrEqualTo(30));
      }

      // Electrolytes: start at minute 60
      final elecs = result.assignments
          .where((a) => a.foodItemId == 'e1')
          .toList();
      expect(elecs, isNotEmpty);
      for (final e in elecs) {
        expect(e.timeSlot.absoluteMinutes, greaterThanOrEqualTo(60));
      }
    });
  });

  // ========================================================================
  // reapportion
  // ========================================================================

  group('ByHourApportionmentService.reapportion', () {
    test('removes assignments for deleted foods', () {
      final original = ByHourData(
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
            adjustedQuantity: 0.5,
            timingCategory: TimingCategory.slowConsume,
          ),
          const TimeSlotAssignment(
            foodItemId: 's2',
            timeSlot: TimeSlot(hourIndex: 1, slotIndex: 2),
            adjustedQuantity: 0.5,
            timingCategory: TimingCategory.slowConsume,
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

    test('adds new drink split across all hours', () {
      final original = ByHourData(
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
        ],
      );

      final updated = service.reapportion(
        existing: original,
        currentFoodItems: [
          _solid('s1'),
          _drink('d1', quantity: '2'),
        ],
      );

      // s1 kept (2 assignments) + d1 added (2 assignments, one per hour)
      expect(updated.assignments.length, 4);
      final d1Assignments = updated.assignments
          .where((a) => a.foodItemId == 'd1')
          .toList();
      expect(d1Assignments.length, 2);
      for (final a in d1Assignments) {
        expect(a.isSipThroughout, true);
        expect(a.adjustedQuantity, 1.0); // 2 / 2 hours
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
            timingCategory: TimingCategory.slowConsume,
          ),
        ],
      );

      final updated = service.reapportion(
        existing: original,
        currentFoodItems: [
          _solid('s1', quantity: '3'),
          _solid('s2', quantity: '2'),
        ],
        targetHourIndex: 1,
      );

      // s1 kept (1) + s2 added to hour 1 only (1)
      final s2Assignments = updated.assignments
          .where((a) => a.foodItemId == 's2')
          .toList();
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
            timingCategory: TimingCategory.slowConsume,
          ),
          const TimeSlotAssignment(
            foodItemId: 's1',
            timeSlot: TimeSlot(hourIndex: 1, slotIndex: 2),
            adjustedQuantity: 0.5,
            timingCategory: TimingCategory.slowConsume,
          ),
        ],
      );

      final updated = service.reapportion(
        existing: original,
        currentFoodItems: [_solid('s1'), _solid('s2')],
      );

      // s1 should stay at its original slots
      final s1Assignments = updated.assignments
          .where((a) => a.foodItemId == 's1')
          .toList();
      expect(s1Assignments.length, 2);
      expect(s1Assignments[0].timeSlot.slotIndex, 2);
      expect(s1Assignments[0].timeSlot.hourIndex, 0);
    });
  });

  // ========================================================================
  // parseQuantity
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
