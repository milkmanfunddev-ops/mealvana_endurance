import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activities_service.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/auth/application/auth_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/food_operations_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/fuel_log_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_state.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mocktail/mocktail.dart';

// Regression test for Bug 3a3e3fdb-754c-8101-adb0-d2471b0d4bb5:
// "Fuel logging: 'Food added' confirmation shows but the food is not actually added"
//
// Root cause: SwapFoodController.addFood() always called
// activityDetailController.addFoodItem() (writes to NutritionPlan) instead of
// checking isFuelLogMode and calling addFoodToFuelLog() (writes to FuelLogData).
// The snackbar fired on the plan write, but FuelLogScreen reads from
// state.fuelLogData, so the added food never appeared.

class MockActivitiesService extends Mock implements ActivitiesService {}

class MockAuthService extends Mock implements AuthService {}

class FakeActivity extends Fake implements Activity {}

class _SeededActivityDetailController extends ActivityDetailController {
  _SeededActivityDetailController(this._seed);

  final ActivityDetailState _seed;

  @override
  FutureOr<ActivityDetailState> build({
    required String activityId,
    bool isNewActivity = false,
  }) {
    return _seed;
  }
}

const _activityId = 'activity-add-food-1';
const _userId = 'user-add-food-1';

Activity _activity() {
  return Activity(
    id: _activityId,
    userId: _userId,
    activityType: ActivityType.running,
    title: 'Long Run',
    scheduledDateTime: DateTime(2026, 7, 18, 7),
    durationMinutes: 120,
    status: ActivityStatus.upcoming,
    createdAt: DateTime(2026, 7, 17),
    updatedAt: DateTime(2026, 7, 17),
  );
}

NutritionPlan _plan() {
  return const NutritionPlan(
    id: 'plan-1',
    name: 'Long Run Nutrition Plan',
    sections: [
      PlanSection(
        id: 'during_run',
        title: 'During Run',
        foodItems: [
          FoodItemData(
            id: 'existing-gel',
            name: 'Energy Gel',
            quantity: '3 gels',
            isIndivisible: true,
            nutritionalInfo: NutritionalInfo(carbs: 30),
          ),
        ],
      ),
    ],
  );
}

FuelLogData _initialFuelLog() {
  return FuelLogData(
    items: [
      FuelLogItem(
        foodId: 'existing-gel',
        sectionId: 'during_run',
        plannedQuantity: 3,
        actualQuantity: 3,
        name: 'Energy Gel',
        isIndivisible: true,
        nutritionalInfo: const NutritionalInfo(carbs: 30),
      ),
    ],
  );
}

Food _newFood() {
  return const Food(
    id: 'honey-waffle-1',
    name: 'Honey Stinger Honey Waffle',
    displayName: 'waffle',
    displayNamePlural: 'waffles',
    servingAmount: 1,
    carbsPerServing: 21,
    caloriesPerServing: 150,
    categories: ['during_run'],
  );
}

ProviderContainer _containerWithSeed(
  ActivityDetailState seed, {
  required MockActivitiesService activitiesService,
  required MockAuthService authService,
}) {
  final container = ProviderContainer(
    overrides: [
      activitiesServiceProvider.overrideWithValue(activitiesService),
      authServiceProvider.overrideWithValue(authService),
      foodOperationsServiceProvider
          .overrideWithValue(FoodOperationsService()),
      activityDetailControllerProvider(
        activityId: _activityId,
        isNewActivity: false,
      ).overrideWith(() => _SeededActivityDetailController(seed)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeActivity());
  });

  group(
      'Bug 3a3e3fdb — addFoodToFuelLogFromRawFood writes to fuelLogData, '
      'not nutritionPlan', () {
    test(
        'adding a food in fuel-log mode appends a FuelLogItem with '
        'isAdded: true to fuelLogData.items', () {
      final mockActivitiesService = MockActivitiesService();
      final mockAuthService = MockAuthService();

      final seed = ActivityDetailState(
        activity: _activity(),
        nutritionPlan: _plan(),
        scheduledDateTime: _activity().scheduledDateTime,
        isFuelLogMode: true,
        fuelLogData: _initialFuelLog(),
      );

      final container = _containerWithSeed(
        seed,
        activitiesService: mockActivitiesService,
        authService: mockAuthService,
      );

      final provider = activityDetailControllerProvider(
        activityId: _activityId,
        isNewActivity: false,
      );

      // Prime the provider.
      container.read(provider);

      final notifier = container.read(provider.notifier);

      // Act: call the new method that the fixed SwapFoodController.addFood()
      // delegates to when isFuelLogMode is true.
      notifier.addFoodToFuelLogFromRawFood(_newFood(), 'during_run');

      final state = container.read(provider);
      final fuelLog = state.value!.fuelLogData;

      // The fuel log must now contain the added food.
      expect(fuelLog, isNotNull);
      expect(fuelLog!.items.length, 2,
          reason: 'Fuel log should have the original item plus the new one.');

      final addedItem = fuelLog.items.firstWhere(
        (item) => item.name == 'Honey Stinger Honey Waffle',
      );
      expect(addedItem.isAdded, isTrue,
          reason: 'The added food must be marked isAdded: true.');
      expect(addedItem.plannedQuantity, 0,
          reason: 'An ad-hoc addition has plannedQuantity 0.');
      expect(addedItem.sectionId, 'during_run');
    });

    test(
        'adding a food in fuel-log mode does NOT modify the nutrition plan '
        'section food list', () {
      final mockActivitiesService = MockActivitiesService();
      final mockAuthService = MockAuthService();

      final seed = ActivityDetailState(
        activity: _activity(),
        nutritionPlan: _plan(),
        scheduledDateTime: _activity().scheduledDateTime,
        isFuelLogMode: true,
        fuelLogData: _initialFuelLog(),
      );

      final container = _containerWithSeed(
        seed,
        activitiesService: mockActivitiesService,
        authService: mockAuthService,
      );

      final provider = activityDetailControllerProvider(
        activityId: _activityId,
        isNewActivity: false,
      );

      container.read(provider);

      final notifier = container.read(provider.notifier);

      // Snapshot the plan's food items before the add.
      final planBefore = container.read(provider).value!.nutritionPlan!;
      final duringBefore = planBefore.sections
          .firstWhere((s) => s.id == 'during_run')
          .foodItems;

      notifier.addFoodToFuelLogFromRawFood(_newFood(), 'during_run');

      // The nutrition plan must be unchanged — pre-fix, addFoodItem() would
      // append a FoodItemData to the plan section, so this assertion would fail.
      final planAfter = container.read(provider).value!.nutritionPlan!;
      final duringAfter = planAfter.sections
          .firstWhere((s) => s.id == 'during_run')
          .foodItems;

      expect(duringAfter.length, duringBefore.length,
          reason: 'Nutrition plan must not gain a food item when in fuel-log '
              'mode — the write must go to fuelLogData only.');
      expect(duringAfter.map((f) => f.id), duringBefore.map((f) => f.id));
    });
  });
}
