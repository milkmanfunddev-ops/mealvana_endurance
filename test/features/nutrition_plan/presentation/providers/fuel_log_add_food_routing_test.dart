import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/application/auth_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/fuel_log_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_state.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/swap_food_controller.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

// Regression test for Bug 3a3e3fdb-754c-8101-adb0-d2471b0d4bb5:
// "Fuel logging: 'Food added' confirmation shows but the food is not added"
//
// Write-path half of the bug: SwapFoodController.addFood() always called
// activityDetailController.addFoodItem(), which writes to the nutrition
// plan's sections. In fuel-log mode the fuel log screen renders from
// state.fuelLogData, so the snackbar confirmed a write the screen never
// shows. Worse, on a section with sub-phases and no sub-phase target the
// plan write appended the food to EVERY sub-phase.
//
// This test drives the real user path (SwapFoodController.addFood) and
// asserts the write lands in fuelLogData and leaves the plan untouched.

class MockAppExternalDeps extends Mock implements AppExternalDeps {}

class MockAppLogger extends Mock implements AppLogger {}

class MockAuthService extends Mock implements AuthService {}

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

const _activityId = 'activity-fuel-log-1';

NutritionPlan _planWithSubPhases() {
  return const NutritionPlan(
    id: 'plan-1',
    name: 'Long Run Nutrition Plan',
    sections: [
      PlanSection(
        id: 'before_run',
        title: 'Before Run',
        foodItems: [],
        subPhases: [
          BeforeSubPhase(
            subPhaseType: 'meal',
            foodItems: [
              FoodItemData(
                id: 'oatmeal-1',
                name: 'Oatmeal',
                quantity: '1 cup cooked oatmeal',
              ),
            ],
          ),
          BeforeSubPhase(
            subPhaseType: 'snack',
            foodItems: [
              FoodItemData(
                id: 'banana-1',
                name: 'Banana',
                quantity: '1 banana',
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Food _newFood() {
  return const Food(
    id: 'honey-waffle-1',
    name: 'Honey Waffle',
    displayName: 'waffle',
    displayNamePlural: 'waffles',
    servingAmount: 1,
    carbsPerServing: 21,
    caloriesPerServing: 150,
    categories: ['before_run'],
  );
}

void main() {
  late MockAppExternalDeps mockDeps;
  late MockAppLogger mockLogger;
  late MockAuthService mockAuthService;

  setUp(() {
    mockDeps = MockAppExternalDeps();
    mockLogger = MockAppLogger();
    mockAuthService = MockAuthService();

    when(() => mockDeps.logger).thenReturn(mockLogger);
    when(() => mockAuthService.getCurrentUser()).thenAnswer((_) async => null);
    when(
      () => mockAuthService.getFoodPreferences(any()),
    ).thenAnswer((_) async => {});
  });

  ProviderContainer buildContainer(ActivityDetailState seed) {
    final container = ProviderContainer(
      overrides: [
        appExternalDepsProvider.overrideWithValue(mockDeps),
        authServiceProvider.overrideWithValue(mockAuthService),
        activityDetailControllerProvider(
          activityId: _activityId,
          isNewActivity: false,
        ).overrideWith(() => _SeededActivityDetailController(seed)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('Bug 3a3e3fdb — SwapFoodController.addFood in fuel-log mode', () {
    test('writes the added food to fuelLogData (null subPhaseType, isAdded) '
        'and does not touch the nutrition plan sub-phases', () async {
      final plan = _planWithSubPhases();
      final seed = ActivityDetailState(
        nutritionPlan: plan,
        isFuelLogMode: true,
        fuelLogData: FuelLogData.fromNutritionPlan(plan),
      );

      final container = buildContainer(seed);

      const params = SwapFoodParams(
        activityId: _activityId,
        category: 'before_run',
      );
      final swapProvider = swapFoodControllerProvider(params);

      // Instantiating the notifier runs build(); its food loading is
      // internally error-guarded, so unstubbed dependencies degrade to an
      // empty SwapFoodState without failing the provider.
      final swapNotifier = container.read(swapProvider.notifier);

      // Act: same call FuelLogScreen's ADD FOOD flow ends in
      // (swap_food_screen._handleConfirm -> addFood with the section id).
      await swapNotifier.addFood(params, _newFood(), 'before_run');

      final detailProvider = activityDetailControllerProvider(
        activityId: _activityId,
        isNewActivity: false,
      );
      final state = container.read(detailProvider).value;
      expect(state, isNotNull);

      // THE regression: pre-fix the fuel log never received the food, so
      // the fuel log screen (which renders from fuelLogData) showed
      // nothing despite the success snackbar.
      final fuelLog = state!.fuelLogData!;
      final added = fuelLog.items
          .where((item) => item.name == 'Honey Waffle')
          .toList();
      expect(
        added,
        hasLength(1),
        reason: 'The added food must land in fuelLogData exactly once.',
      );
      expect(added.first.sectionId, 'before_run');
      expect(added.first.isAdded, isTrue);
      expect(
        added.first.subPhaseType,
        isNull,
        reason:
            'No sub-phase may be invented for a section-level add — '
            'that would skew downstream timing/carb analysis.',
      );
      expect(added.first.actualQuantity, greaterThan(0));

      // The nutrition plan must be untouched. Pre-fix, addFoodItem()
      // appended the food to EVERY sub-phase of the section (no
      // sub-phase target was specified), corrupting the plan.
      final section = state.nutritionPlan!.sections.single;
      for (final subPhase in section.subPhases!) {
        expect(
          subPhase.foodItems,
          hasLength(1),
          reason:
              'Sub-phase ${subPhase.subPhaseType} must not gain a '
              'food item from a fuel-log add.',
        );
      }
    });
  });
}
