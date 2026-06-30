import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/carb_loading/domain/carb_loading_plan_simple.dart';

void main() {
  // ---------------------------------------------------------------------------
  // RaceDistance multipliers
  // ---------------------------------------------------------------------------

  group('CarbLoadingPlan.getRaceDistanceMultiplier', () {
    test('halfMarathon → 0.8', () {
      expect(CarbLoadingPlan.getRaceDistanceMultiplier(RaceDistance.halfMarathon), 0.8);
    });

    test('marathon → 1.0', () {
      expect(CarbLoadingPlan.getRaceDistanceMultiplier(RaceDistance.marathon), 1.0);
    });

    test('50k → 1.1', () {
      expect(CarbLoadingPlan.getRaceDistanceMultiplier(RaceDistance.ultramarathon50k), 1.1);
    });

    test('100k → 1.1', () {
      expect(CarbLoadingPlan.getRaceDistanceMultiplier(RaceDistance.ultramarathon100k), 1.1);
    });

    test('50 mile → 1.2', () {
      expect(CarbLoadingPlan.getRaceDistanceMultiplier(RaceDistance.ultramarathon50mile), 1.2);
    });

    test('100 mile → 1.2', () {
      expect(CarbLoadingPlan.getRaceDistanceMultiplier(RaceDistance.ultramarathon100mile), 1.2);
    });
  });

  // ---------------------------------------------------------------------------
  // TrainingVolume multipliers
  // ---------------------------------------------------------------------------

  group('CarbLoadingPlan.getTrainingVolumeMultiplier', () {
    test('low → 0.9', () {
      expect(CarbLoadingPlan.getTrainingVolumeMultiplier(TrainingVolume.low), 0.9);
    });

    test('moderate → 1.0', () {
      expect(CarbLoadingPlan.getTrainingVolumeMultiplier(TrainingVolume.moderate), 1.0);
    });

    test('high → 1.1', () {
      expect(CarbLoadingPlan.getTrainingVolumeMultiplier(TrainingVolume.high), 1.1);
    });
  });

  // ---------------------------------------------------------------------------
  // createDefault – carb target calculation
  // Formula: 8.0 * raceMultiplier * volumeMultiplier * bodyWeightKg
  // ---------------------------------------------------------------------------

  group('CarbLoadingPlan.createDefault – dailyCarbTargetG', () {
    final raceDate = DateTime(2026, 10, 5);

    test('marathon + moderate + 70kg → 8*1.0*1.0*70 = 560g', () {
      final plan = CarbLoadingPlan.createDefault(
        userId: 'user-1',
        raceDate: raceDate,
        raceDistance: RaceDistance.marathon,
        trainingVolume: TrainingVolume.moderate,
        bodyWeightKg: 70.0,
      );
      expect(plan.dailyCarbTargetG, 560);
      expect(plan.carbsPerKgTarget, closeTo(8.0, 0.001));
    });

    test('halfMarathon + low + 60kg → 8*0.8*0.9*60 = 345.6 → rounds to 346', () {
      final plan = CarbLoadingPlan.createDefault(
        userId: 'user-1',
        raceDate: raceDate,
        raceDistance: RaceDistance.halfMarathon,
        trainingVolume: TrainingVolume.low,
        bodyWeightKg: 60.0,
      );
      // 8 * 0.8 * 0.9 = 5.76; 5.76 * 60 = 345.6 → round → 346
      expect(plan.dailyCarbTargetG, 346);
      expect(plan.carbsPerKgTarget, closeTo(5.76, 0.001));
    });

    test('100mile + high + 80kg → 8*1.2*1.1*80 = 844.8 → rounds to 845', () {
      final plan = CarbLoadingPlan.createDefault(
        userId: 'user-1',
        raceDate: raceDate,
        raceDistance: RaceDistance.ultramarathon100mile,
        trainingVolume: TrainingVolume.high,
        bodyWeightKg: 80.0,
      );
      // 8 * 1.2 * 1.1 = 10.56; 10.56 * 80 = 844.8 → 845
      expect(plan.dailyCarbTargetG, 845);
      expect(plan.carbsPerKgTarget, closeTo(10.56, 0.001));
    });

    test('dailyServingsTarget = round(dailyCarbTargetG / 50)', () {
      final plan = CarbLoadingPlan.createDefault(
        userId: 'user-1',
        raceDate: raceDate,
        raceDistance: RaceDistance.marathon,
        trainingVolume: TrainingVolume.moderate,
        bodyWeightKg: 70.0,
      );
      // 560 / 50 = 11.2 → round → 11
      expect(plan.dailyServingsTarget, 11);
    });

    test('creates daySelections for days -2, -1, 0', () {
      final plan = CarbLoadingPlan.createDefault(
        userId: 'user-1',
        raceDate: raceDate,
        raceDistance: RaceDistance.marathon,
        trainingVolume: TrainingVolume.moderate,
        bodyWeightKg: 70.0,
      );
      expect(plan.daySelections.keys, containsAll([-2, -1, 0]));
      expect(plan.daySelections.length, 3);
    });

    test('each day starts with 5 empty meals', () {
      final plan = CarbLoadingPlan.createDefault(
        userId: 'user-1',
        raceDate: raceDate,
        raceDistance: RaceDistance.marathon,
        trainingVolume: TrainingVolume.moderate,
        bodyWeightKg: 70.0,
      );
      for (final day in plan.daySelections.values) {
        expect(day.meals.keys, containsAll(['breakfast', 'lunch', 'snack1', 'dinner', 'snack2']));
        expect(day.totalCarbs, 0);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // DayFoodSelections
  // ---------------------------------------------------------------------------

  group('DayFoodSelections', () {
    test('empty() has zero total carbs', () {
      final day = DayFoodSelections.empty();
      expect(day.totalCarbs, 0);
      expect(day.totalCalories, 0);
    });

    test('totalCarbs sums across all meals', () {
      // MealFoods.totalCarbs = each food contributes qty * 50g
      final meal1 = MealFoods(selectedFoods: {'pasta': 2}); // 100g
      final meal2 = MealFoods(selectedFoods: {'rice': 3});  // 150g
      final day = DayFoodSelections(meals: {'breakfast': meal1, 'lunch': meal2});
      expect(day.totalCarbs, 250);
    });

    test('totalCalories = totalCarbs * 4', () {
      final meal = MealFoods(selectedFoods: {'pasta': 2}); // 100g
      final day = DayFoodSelections(meals: {'breakfast': meal});
      expect(day.totalCalories, 400);
    });

    test('updateMeal replaces the meal and recalculates totalCarbs', () {
      final day = DayFoodSelections.empty();
      final updatedDay = day.updateMeal('breakfast', MealFoods(selectedFoods: {'oats': 1}));
      expect(updatedDay.totalCarbs, 50);
    });

    test('copyWith returns new instance with replaced meals', () {
      final day = DayFoodSelections.empty();
      final newMeals = {'breakfast': MealFoods(selectedFoods: {'bagel': 2})};
      final copy = day.copyWith(meals: newMeals);
      expect(copy.totalCarbs, 100);
      expect(day.totalCarbs, 0); // original unchanged
    });
  });

  // ---------------------------------------------------------------------------
  // MealFoods
  // ---------------------------------------------------------------------------

  group('MealFoods', () {
    test('empty() has zero carbs', () {
      final meal = MealFoods.empty();
      expect(meal.totalCarbs, 0);
      expect(meal.selectedFoods, isEmpty);
    });

    test('totalCarbs = qty * 50 per food item', () {
      final meal = MealFoods(selectedFoods: {'pasta': 3, 'rice': 2});
      expect(meal.totalCarbs, (3 + 2) * 50); // 250
    });

    test('addFood increments quantity', () {
      final meal = MealFoods(selectedFoods: {'pasta': 1});
      final updated = meal.addFood('pasta');
      expect(updated.selectedFoods['pasta'], 2);
    });

    test('addFood adds new item with quantity 1', () {
      final meal = MealFoods.empty();
      final updated = meal.addFood('pasta');
      expect(updated.selectedFoods['pasta'], 1);
    });

    test('removeFood decrements quantity', () {
      final meal = MealFoods(selectedFoods: {'pasta': 3});
      final updated = meal.removeFood('pasta');
      expect(updated.selectedFoods['pasta'], 2);
    });

    test('removeFood removes item when quantity reaches 1', () {
      final meal = MealFoods(selectedFoods: {'pasta': 1});
      final updated = meal.removeFood('pasta');
      expect(updated.selectedFoods.containsKey('pasta'), isFalse);
    });

    test('removeFood on non-existent food is a no-op', () {
      final meal = MealFoods(selectedFoods: {'pasta': 2});
      final updated = meal.removeFood('rice');
      expect(updated.selectedFoods['pasta'], 2);
      expect(updated.selectedFoods.containsKey('rice'), isFalse);
    });

    test('updateFoodQuantity sets quantity', () {
      final meal = MealFoods(selectedFoods: {'pasta': 1});
      final updated = meal.updateFoodQuantity('pasta', 5);
      expect(updated.selectedFoods['pasta'], 5);
      expect(updated.totalCarbs, 250);
    });

    test('updateFoodQuantity removes item when quantity is 0', () {
      final meal = MealFoods(selectedFoods: {'pasta': 3});
      final updated = meal.updateFoodQuantity('pasta', 0);
      expect(updated.selectedFoods.containsKey('pasta'), isFalse);
    });

    test('updateFoodQuantity removes item when quantity is negative', () {
      final meal = MealFoods(selectedFoods: {'pasta': 3});
      final updated = meal.updateFoodQuantity('pasta', -1);
      expect(updated.selectedFoods.containsKey('pasta'), isFalse);
    });

    test('immutability: original unchanged after addFood', () {
      final original = MealFoods(selectedFoods: {'pasta': 1});
      original.addFood('pasta');
      expect(original.selectedFoods['pasta'], 1);
    });

    test('immutability: original unchanged after removeFood', () {
      final original = MealFoods(selectedFoods: {'pasta': 2});
      original.removeFood('pasta');
      expect(original.selectedFoods['pasta'], 2);
    });
  });

  // ---------------------------------------------------------------------------
  // CarbLoadingPlan – isCarbLoadingActive
  // ---------------------------------------------------------------------------

  group('CarbLoadingPlan.isCarbLoadingActive', () {
    // isCarbLoadingActive = now.isAfter(raceDate - 2) && now.isBefore(raceDate)
    // This hardcodes 2 days regardless of the actual protocol length.

    CarbLoadingPlan _plan(DateTime raceDate) {
      return CarbLoadingPlan(
        id: 'plan-1',
        userId: 'user-1',
        raceDate: raceDate,
        raceDistance: RaceDistance.marathon,
        trainingVolume: TrainingVolume.moderate,
        dailyCarbTargetG: 560,
        dailyServingsTarget: 11,
        bodyWeightKg: 70.0,
        carbsPerKgTarget: 8.0,
        daySelections: {-2: DayFoodSelections.empty(), -1: DayFoodSelections.empty(), 0: DayFoodSelections.empty()},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    test('isCarbLoadingActive is false when race is in the far future (>2 days away)', () {
      // Use a date far in the future so now < raceDate - 2
      final raceDate = DateTime.now().add(const Duration(days: 365));
      expect(_plan(raceDate).isCarbLoadingActive, isFalse);
    });

    test('isCarbLoadingActive is false when race has already passed', () {
      final raceDate = DateTime.now().subtract(const Duration(days: 3));
      expect(_plan(raceDate).isCarbLoadingActive, isFalse);
    });

    // BUG CHECK NOTE: isCarbLoadingActive always uses carbLoadingStartDate = raceDate - 2 days
    // even when the protocol is 3 days. The 3-day protocol window (day -3) would NOT
    // show as active until the day -2 threshold is crossed. This is a potential bug.
    test('BUG-CHECK: isCarbLoadingActive uses hardcoded 2-day window, not actual protocol length', () {
      // raceDate = now + 2.5 days, so carb loading started 0.5 days ago
      final raceDate = DateTime.now().add(const Duration(hours: 60)); // ~2.5 days
      // If this were a 3-day protocol, day -3 would have started yesterday.
      // But isCarbLoadingActive only checks raceDate - 2.
      // With raceDate at now+60h, carbLoadingStartDate = now+60h-48h = now+12h
      // Since now.isAfter(now+12h) is FALSE, the method returns false even
      // though a 3-day protocol SHOULD show as active.
      final plan = _plan(raceDate);
      // Confirming the hardcoded-2-day behaviour:
      expect(plan.isCarbLoadingActive, isFalse); // BUG: should be true for 3-day protocol
    });
  });

  // ---------------------------------------------------------------------------
  // CarbLoadingPlan – JSON round-trip
  // ---------------------------------------------------------------------------

  group('CarbLoadingPlan JSON round-trip', () {
    final raceDate = DateTime(2026, 10, 5);

    test('toJson / fromJson preserves all scalar fields', () {
      final original = CarbLoadingPlan.createDefault(
        userId: 'user-round-trip',
        raceDate: raceDate,
        raceDistance: RaceDistance.marathon,
        trainingVolume: TrainingVolume.high,
        bodyWeightKg: 75.0,
      );

      final json = original.toJson();
      final restored = CarbLoadingPlan.fromJson(json);

      expect(restored.userId, original.userId);
      expect(restored.raceDate, original.raceDate);
      expect(restored.raceDistance, original.raceDistance);
      expect(restored.trainingVolume, original.trainingVolume);
      expect(restored.dailyCarbTargetG, original.dailyCarbTargetG);
      expect(restored.dailyServingsTarget, original.dailyServingsTarget);
      expect(restored.bodyWeightKg, closeTo(original.bodyWeightKg, 0.001));
      expect(restored.carbsPerKgTarget, closeTo(original.carbsPerKgTarget, 0.001));
      expect(restored.isActive, original.isActive);
    });

    test('toJson / fromJson preserves daySelections with food data', () {
      final plan = CarbLoadingPlan.createDefault(
        userId: 'user-1',
        raceDate: raceDate,
        raceDistance: RaceDistance.marathon,
        trainingVolume: TrainingVolume.moderate,
        bodyWeightKg: 70.0,
      );

      // Add some food to day -2
      final day = plan.daySelections[-2]!.updateMeal(
        'breakfast',
        MealFoods(selectedFoods: {'pasta': 3, 'rice': 2}),
      );
      final updatedPlan = plan.copyWith(
        daySelections: {...plan.daySelections, -2: day},
      );

      final json = updatedPlan.toJson();
      final restored = CarbLoadingPlan.fromJson(json);

      final restoredDay = restored.daySelections[-2]!;
      expect(restoredDay.meals['breakfast']!.selectedFoods['pasta'], 3);
      expect(restoredDay.meals['breakfast']!.selectedFoods['rice'], 2);
      expect(restoredDay.totalCarbs, 250);
    });

    // NOTE: This test also documents a BUG in CarbLoadingPlan.fromJson:
    // When 'daySelections' is an empty map literal `{}` (Map<dynamic,dynamic>),
    // the cast `as Map<String, dynamic>?` throws a TypeError at runtime.
    // fromJson must use `Map<String, dynamic>.from(json['daySelections'])` or
    // check the runtime type. Using a pre-typed Map works around the issue.
    test('fromJson defaults missing raceDistance to marathon', () {
      final daySelections = <String, dynamic>{}; // typed to avoid cast bug
      final json = <String, dynamic>{
        'id': 'test-id',
        'userId': 'user-1',
        'raceDate': '2026-10-05T00:00:00.000',
        'raceDistance': 'unknown_value', // unknown
        'trainingVolume': 'moderate',
        'dailyCarbTargetG': 560,
        'dailyServingsTarget': 11,
        'bodyWeightKg': 70.0,
        'carbsPerKgTarget': 8.0,
        'daySelections': daySelections,
        'createdAt': '2026-01-01T00:00:00.000',
        'updatedAt': '2026-01-01T00:00:00.000',
        'isActive': true,
      };

      final plan = CarbLoadingPlan.fromJson(json);
      expect(plan.raceDistance, RaceDistance.marathon);
    });

    test('fromJson defaults missing trainingVolume to moderate', () {
      final daySelections = <String, dynamic>{};
      final json = <String, dynamic>{
        'id': 'test-id',
        'userId': 'user-1',
        'raceDate': '2026-10-05T00:00:00.000',
        'raceDistance': 'marathon',
        'trainingVolume': 'unknown_value', // unknown
        'dailyCarbTargetG': 560,
        'dailyServingsTarget': 11,
        'bodyWeightKg': 70.0,
        'carbsPerKgTarget': 8.0,
        'daySelections': daySelections,
        'createdAt': '2026-01-01T00:00:00.000',
        'updatedAt': '2026-01-01T00:00:00.000',
        'isActive': true,
      };

      final plan = CarbLoadingPlan.fromJson(json);
      expect(plan.trainingVolume, TrainingVolume.moderate);
    });
  });

  // ---------------------------------------------------------------------------
  // MealFoods – totalCalories simple estimate (4 kcal/g carb)
  // ---------------------------------------------------------------------------

  group('MealFoods.totalCalories', () {
    test('zero foods → 0 calories', () {
      expect(MealFoods.empty().totalCalories, 0);
    });

    test('1 food unit (50g carb) → 200 calories', () {
      final meal = MealFoods(selectedFoods: {'pasta': 1});
      expect(meal.totalCalories, 200);
    });

    test('3 servings across 2 foods → 600 calories', () {
      final meal = MealFoods(selectedFoods: {'pasta': 2, 'rice': 1});
      expect(meal.totalCalories, 600);
    });
  });
}
