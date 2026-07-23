import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/application/auth_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/carbs_per_hour_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/fuel_log_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_state.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/swap_food_controller.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

// Regression tests for two fuel-log flaws surfaced by the ADD FOOD fix
// (bug 3a3e3fdb wrote added foods to fuelLogData, making these visible):
//
// 1. Added foods contributed ZERO macros: they are written with
//    plannedQuantity 0 ("not in the plan"), and actualNutritionalInfo
//    gated its scaling on plannedQuantity > 0 — so carbs/hr and coach
//    reports silently ignored everything the athlete added while logging.
//    Fixed via FuelLogItem.nutritionReferenceQuantity.
//
// 2. Quantity updates matched items by foodId + sectionId only. The same
//    food sitting in a sub-phase group AND in the "Added" bucket (or in
//    two sub-phases) meant one +/- tap moved BOTH rows. Fixed by also
//    discriminating on subPhaseType + isAdded.

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

const _activityId = 'activity-fuel-log-macros-1';

NutritionPlan _planWithEmptyDuringSection() {
  return const NutritionPlan(
    id: 'plan-1',
    name: 'Long Run Nutrition Plan',
    sections: [
      PlanSection(id: 'during_run', title: 'During Run', foodItems: []),
    ],
  );
}

Food _gel() {
  return const Food(
    id: 'maple-gel-1',
    name: 'Maple Gel',
    displayName: 'gel',
    displayNamePlural: 'gels',
    servingAmount: 1,
    carbsPerServing: 21,
    caloriesPerServing: 100,
    categories: ['during_run'],
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

  group('Bug 1 — added foods must contribute macros', () {
    test('a food added via the real ADD FOOD path counts toward during '
        'carbs, and +/- adjustments rescale it', () async {
      final plan = _planWithEmptyDuringSection();
      final seed = ActivityDetailState(
        nutritionPlan: plan,
        isFuelLogMode: true,
        fuelLogData: FuelLogData.fromNutritionPlan(plan),
      );
      final container = buildContainer(seed);

      const params = SwapFoodParams(
        activityId: _activityId,
        category: 'during_run',
      );
      final swapNotifier = container.read(
        swapFoodControllerProvider(params).notifier,
      );

      // Act: the real user path (fuel-log mode ADD FOOD → addFood →
      // addFoodToFuelLogFromRawFood). 2 gels × 21 g carbs = 42 g.
      await swapNotifier.addFood(params, _gel(), 'during_run', customAmount: 2);

      final detailProvider = activityDetailControllerProvider(
        activityId: _activityId,
        isNewActivity: false,
      );
      final fuelLog = container.read(detailProvider).value!.fuelLogData!;
      final added = fuelLog.items.singleWhere((i) => i.isAdded);
      expect(added.actualQuantity, 2.0);
      expect(
        added.plannedQuantity,
        0.0,
        reason: 'Added items are legitimately unplanned.',
      );

      // THE regression: the item's macros were captured for 2 units but
      // actualNutritionalInfo gated on plannedQuantity (> 0), so the
      // carbs/hr card and coach reports counted 0 g from added foods.
      expect(
        added.actualNutritionalInfo?.carbs,
        42,
        reason: 'An added food with quantity N must yield N × per-unit carbs.',
      );
      expect(const CarbsPerHourService().duringCarbsG(fuelLog), 42);

      // A +/- adjustment must rescale from the add-time reference
      // quantity: 2 → 2.5 gels is 42 g × 1.25 = 52.5 → 53 g rounded.
      final notifier = container.read(detailProvider.notifier);
      notifier.updateFuelLogItemQuantity(added, 0.5);
      final adjustedLog = container.read(detailProvider).value!.fuelLogData!;
      expect(const CarbsPerHourService().duringCarbsG(adjustedLog), 53);

      // The reference quantity must survive a JSON round-trip, or the
      // macros vanish again once the log is persisted and re-read
      // (coach reports read the stored blob).
      final roundTripped = FuelLogData.fromJson(adjustedLog.toJson());
      expect(const CarbsPerHourService().duringCarbsG(roundTripped), 53);
    });
  });

  group('Bug 2 — quantity update must target one row', () {
    test('updating the added copy of a food leaves the planned sub-phase '
        'copy untouched (and vice versa)', () async {
      // Same foodId twice in the same section: once planned inside the
      // 'meal' sub-phase, once as an added item. Pre-fix the matcher used
      // foodId + sectionId only, so one +/- tap moved BOTH rows.
      final plannedItem = FuelLogItem(
        foodId: 'banana-1',
        sectionId: 'before_run',
        subPhaseType: 'meal',
        plannedQuantity: 1,
        actualQuantity: 1,
        name: 'Banana',
      );
      final addedItem = FuelLogItem(
        foodId: 'banana-1',
        sectionId: 'before_run',
        plannedQuantity: 0,
        actualQuantity: 1,
        isAdded: true,
        nutritionReferenceQuantity: 1,
        name: 'Banana',
      );
      final seed = ActivityDetailState(
        nutritionPlan: _planWithEmptyDuringSection(),
        isFuelLogMode: true,
        fuelLogData: FuelLogData(items: [plannedItem, addedItem]),
      );
      final container = buildContainer(seed);

      final detailProvider = activityDetailControllerProvider(
        activityId: _activityId,
        isNewActivity: false,
      );
      final notifier = container.read(detailProvider.notifier);

      // Act 1: bump the ADDED row.
      notifier.updateFuelLogItemQuantity(addedItem, 0.5);

      var items = container.read(detailProvider).value!.fuelLogData!.items;
      expect(items.singleWhere((i) => i.isAdded).actualQuantity, 1.5);
      expect(
        items.singleWhere((i) => !i.isAdded).actualQuantity,
        1.0,
        reason: 'The planned sub-phase row must not move on an added-row tap.',
      );

      // Act 2: decrement the PLANNED row.
      final plannedNow = items.singleWhere((i) => !i.isAdded);
      notifier.updateFuelLogItemQuantity(plannedNow, -0.5);

      items = container.read(detailProvider).value!.fuelLogData!.items;
      expect(items.singleWhere((i) => !i.isAdded).actualQuantity, 0.5);
      expect(
        items.singleWhere((i) => i.isAdded).actualQuantity,
        1.5,
        reason: 'The added row must not move on a planned-row tap.',
      );
    });
  });
}
