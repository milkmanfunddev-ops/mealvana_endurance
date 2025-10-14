import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/nutrition_plan_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/nutrition_plan_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import '../../../../helpers/utils/console_logging.dart';

// Mock classes
class MockNutritionPlanService extends Mock implements NutritionPlanService {}

// Fake classes for fallback values
class FakeNutritionPlan extends Fake implements NutritionPlan {}

void main() {
  late ProviderContainer container;
  late MockNutritionPlanService mockService;

  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(FakeNutritionPlan());
  });

  setUp(() {
    logTestHeading('Simple NutritionPlanController Test Setup');

    // Initialize mock
    mockService = MockNutritionPlanService();

    // Create provider container with overrides
    container = ProviderContainer(
      overrides: [
        nutritionPlanServiceProvider.overrideWithValue(mockService),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('NutritionPlanController - Simple Tests', () {
    test('should initialize with empty state', () {
      logTestHeading('Test: Controller Initial State');

      // Act
      final state = container.read(nutritionPlanControllerProvider);

      // Assert
      state.when(
        data: (data) {
          expect(data.plan, isNull);
          expect(data.isSaved, isFalse);
          expect(data.isLoading, isFalse);
          expect(data.error, isNull);
          expect(data.planId, isNull);

          logTestResult('Initial State', {
            'plan': data.plan,
            'isSaved': data.isSaved,
            'isLoading': data.isLoading,
          });
        },
        loading: () => fail('Should not be loading initially'),
        error: (_, __) => fail('Should not have error initially'),
      );
    });

    test('should set generated plan', () async {
      logTestHeading('Test: Set Generated Plan');

      // Arrange
      final testPlan = NutritionPlan(
        id: 'test-plan-123',
        name: 'Test Plan',
        sections: [
          PlanSection(
            id: 'section-1',
            title: 'Before Run',
            foodItems: [
              FoodItemData(
                id: 'food-1',
                name: 'Banana',
                quantity: '1 medium',
              ),
            ],
          ),
        ],
      );

      logTestInput('Plan to Set', {
        'id': testPlan.id,
        'name': testPlan.name,
        'sections': testPlan.sections.length,
      });

      // Act
      final controller = container.read(nutritionPlanControllerProvider.notifier);
      controller.setGeneratedPlan(testPlan);

      // Wait for state update
      await container.pump();

      // Assert
      final state = container.read(nutritionPlanControllerProvider);
      state.when(
        data: (data) {
          expect(data.plan, isNotNull);
          expect(data.plan?.id, equals('test-plan-123'));
          expect(data.plan?.name, equals('Test Plan'));
          expect(data.plan?.sections.length, equals(1));
          expect(data.isSaved, isFalse);

          logTestResult('Plan Set', {
            'planId': data.plan?.id,
            'planName': data.plan?.name,
            'sectionCount': data.plan?.sections.length,
          });
        },
        loading: () => fail('Should not be loading'),
        error: (_, __) => fail('Should not have error'),
      );
    });

    test('should handle error state', () async {
      logTestHeading('Test: Error State');

      // Arrange
      const errorMessage = 'Test error message';

      when(() => mockService.generateNutritionPlan(
        distanceMiles: any(named: 'distanceMiles'),
        paceMinutesPerMile: any(named: 'paceMinutesPerMile'),
        timeBeforeRunHours: any(named: 'timeBeforeRunHours'),
        gutTrainingLevel: any(named: 'gutTrainingLevel'),
        tempF: any(named: 'tempF'),
        humidity: any(named: 'humidity'),
        sweatRate: any(named: 'sweatRate'),
        giSensitivity: any(named: 'giSensitivity'),
        allowHighCarbRun: any(named: 'allowHighCarbRun'),
      )).thenThrow(Exception(errorMessage));

      // Act
      final controller = container.read(nutritionPlanControllerProvider.notifier);

      await controller.generatePlan(
        distanceMiles: 5.0,
        paceMinutesPerMile: 10.0,
        timeBeforeRunHours: 2.0,
        gutTrainingLevel: 'moderate',
      );

      // Wait for state update
      await container.pump();

      // Assert
      final state = container.read(nutritionPlanControllerProvider);
      state.when(
        data: (data) {
          expect(data.error, isNotNull);
          expect(data.plan, isNull);
          expect(data.isLoading, isFalse);

          logTestResult('Error State', {
            'error': data.error,
            'hasError': data.error != null,
          });
        },
        loading: () => fail('Should not be loading'),
        error: (_, __) => fail('Should be data state with error'),
      );
    });

    test('should clear current plan', () async {
      logTestHeading('Test: Clear Current Plan');

      // Arrange - first set a plan
      final testPlan = NutritionPlan(
        id: 'plan-to-clear',
        name: 'Plan to Clear',
        sections: [],
      );

      final controller = container.read(nutritionPlanControllerProvider.notifier);
      controller.setGeneratedPlan(testPlan);
      await container.pump();

      // Verify plan is set
      var state = container.read(nutritionPlanControllerProvider);
      state.whenData((data) {
        expect(data.plan, isNotNull);
      });

      // Act - clear the plan
      controller.clearCurrentPlan();
      await container.pump();

      // Assert
      state = container.read(nutritionPlanControllerProvider);
      state.when(
        data: (data) {
          expect(data.plan, isNull);
          expect(data.isSaved, isFalse);
          expect(data.error, isNull);

          logTestResult('Plan Cleared', {
            'plan': data.plan,
            'isSaved': data.isSaved,
          });
        },
        loading: () => fail('Should not be loading'),
        error: (_, __) => fail('Should not have error'),
      );
    });

    test('should update food quantity in plan', () async {
      logTestHeading('Test: Update Food Quantity');

      // Arrange
      final testPlan = NutritionPlan(
        id: 'test-plan',
        name: 'Test Plan',
        sections: [
          PlanSection(
            id: 'section-1',
            title: 'Before Run',
            foodItems: [
              FoodItemData(
                id: 'food-1',
                name: 'Banana',
                quantity: '1 medium',
                nutritionalInfo: NutritionalInfo(
                  calories: 105,
                  carbs: 27,
                  protein: 1,
                  fat: 0,
                ),
              ),
            ],
          ),
        ],
      );

      final controller = container.read(nutritionPlanControllerProvider.notifier);
      controller.setGeneratedPlan(testPlan);
      await container.pump();

      // Act - update quantity
      controller.updateFoodQuantity('section-1', 'food-1', 2.0);
      await container.pump();

      // Assert
      final state = container.read(nutritionPlanControllerProvider);
      state.when(
        data: (data) {
          expect(data.plan, isNotNull);
          final food = data.plan?.sections.first.foodItems.first;
          expect(food?.quantity, equals('2.0')); // Quantity updated

          logTestResult('Quantity Updated', {
            'foodName': food?.name,
            'newQuantity': food?.quantity,
          });
        },
        loading: () => fail('Should not be loading'),
        error: (_, __) => fail('Should not have error'),
      );
    });
  });
}