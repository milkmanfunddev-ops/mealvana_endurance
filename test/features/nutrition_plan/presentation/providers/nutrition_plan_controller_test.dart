import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/nutrition_plan_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/nutrition_plan_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/nutrition_plan_analytics.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/auth/application/auth_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/meal.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_logger.dart';
import '../../../../helpers/utils/console_logging.dart';
import '../../../../helpers/fakes/external_deps.dart';
import '../../../../helpers/fixtures/nutrition_plan_requests.dart';

// Mock classes
class MockNutritionPlanService extends Mock implements NutritionPlanService {}
class MockContentService extends Mock implements ContentService {}
class MockAuthService extends Mock implements AuthService {}
class MockAnalyticsTracker extends Mock implements AnalyticsTracker {}
class MockAppLogger extends Mock implements AppLogger {}
class MockNutritionPlanAnalytics extends Mock implements NutritionPlanAnalytics {}

// Fake classes for fallback values
class FakeNutritionPlan extends Fake implements NutritionPlan {}
class FakeMacroTargets extends Fake implements MacroTargets {}

void main() {
  late ProviderContainer container;
  late MockNutritionPlanService mockService;
  late MockContentService mockContentService;
  late MockAuthService mockAuthService;
  late MockAnalyticsTracker mockAnalytics;
  late MockAppLogger mockLogger;
  late MockNutritionPlanAnalytics mockPlanAnalytics;

  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(FakeNutritionPlan());
    registerFallbackValue(FakeMacroTargets());
  });

  setUp(() {
    logTestHeading('NutritionPlanController Test Setup');

    // Initialize mocks
    mockService = MockNutritionPlanService();
    mockContentService = MockContentService();
    mockAuthService = MockAuthService();
    mockAnalytics = MockAnalyticsTracker();
    mockLogger = MockAppLogger();
    mockPlanAnalytics = MockNutritionPlanAnalytics();

    // Setup default mock behaviors
    when(() => mockContentService.getValue(any(), defaultValue: any(named: 'defaultValue')))
        .thenReturn('Test Text');
    when(() => mockAuthService.currentUser).thenReturn('test-device-123');
    when(() => mockLogger.debug(any())).thenReturn(null);
    when(() => mockLogger.info(any())).thenReturn(null);
    when(() => mockLogger.warning(any())).thenReturn(null);
    when(() => mockLogger.error(any(), any(), any())).thenReturn(null);
    when(() => mockAnalytics.track(any(), any())).thenReturn(null);
    when(() => mockPlanAnalytics.trackPlanGenerated(any())).thenReturn(null);
    when(() => mockPlanAnalytics.trackPlanSaved(any())).thenReturn(null);
    when(() => mockPlanAnalytics.trackPlanError(any())).thenReturn(null);

    // Create provider container with overrides
    container = ProviderContainer(
      overrides: [
        nutritionPlanServiceProvider.overrideWithValue(mockService),
        contentServiceProvider.overrideWithValue(mockContentService),
        authServiceProvider.overrideWithValue(mockAuthService),
        nutritionPlanAnalyticsProvider.overrideWithValue(mockPlanAnalytics),
        overrideAppExternalDeps(buildTestExternalDeps(
          analyticsTracker: mockAnalytics,
          logger: mockLogger,
        )),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('NutritionPlanController', () {
    test('should initialize with empty state', () async {
      logTestHeading('Test: Controller Initialization');

      // Act
      final controller = container.read(nutritionPlanControllerProvider.notifier);
      final state = container.read(nutritionPlanControllerProvider);

      // Assert
      state.when(
        data: (data) {
          expect(data.plan, isNull);
          expect(data.isSaved, isFalse);
          expect(data.isLoading, isFalse);
          expect(data.error, isNull);
          expect(data.planId, isNull);
          logTestResult('Initial State', 'Empty state initialized correctly');
        },
        loading: () => fail('Should not be loading'),
        error: (_, __) => fail('Should not have error'),
      );
    });

    test('should generate nutrition plan successfully', () async {
      logTestHeading('Test: Generate Plan - Success');

      // Arrange
      final request = NutritionPlanRequestFixtures.marathon();
      final expectedPlan = NutritionPlan(
        id: 'plan-123',
        deviceId: 'test-device-123',
        macroTargets: MacroTargets(
          preRunCarbs: 150.0,
          preRunProtein: 20.0,
          preRunFat: 10.0,
          preRunSodium: 500.0,
          preRunFluid: 500.0,
          duringRunCarbsPerHour: 60.0,
          duringRunFluidPerHour: 750.0,
          duringRunSodiumPerHour: 300.0,
          totalDuringRunCarbs: 180.0,
          totalDuringRunFluid: 2250.0,
          totalDuringRunSodium: 900.0,
        ),
        meals: [
          Meal(
            id: 'meal-1',
            name: 'Pre-Run Meal',
            category: 'before',
            foods: [
              FoodItem(
                id: 'food-1',
                name: 'Oatmeal',
                quantity: 1.0,
                unit: 'cup',
                carbs: 54.0,
                protein: 6.0,
                fat: 3.0,
                sodium: 150.0,
                fluid: 0.0,
              ),
            ],
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

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
      )).thenAnswer((_) async => expectedPlan);

      logTestInput('Request', request);

      // Act
      final controller = container.read(nutritionPlanControllerProvider.notifier);
      await controller.generatePlan(
        distanceMiles: request['distance_miles'] as double,
        paceMinutesPerMile: request['pace_minutes_per_mile'] as double,
        timeBeforeRunHours: request['time_before_run_hours'] as double,
        gutTrainingLevel: request['gut_training_level'] as String,
      );

      // Wait for state to update
      await container.pump();

      // Assert
      final state = container.read(nutritionPlanControllerProvider);
      state.when(
        data: (data) {
          expect(data.plan, isNotNull);
          expect(data.plan?.id, equals('plan-123'));
          expect(data.isSaved, isFalse); // Not saved yet
          expect(data.isLoading, isFalse);
          expect(data.error, isNull);

          logTestResult('Generated Plan', {
            'id': data.plan?.id,
            'meals': data.plan?.meals.length,
            'isSaved': data.isSaved,
          });
        },
        loading: () => fail('Should not be loading'),
        error: (_, __) => fail('Should not have error'),
      );

      // Verify interactions
      verify(() => mockService.generateNutritionPlan(
        distanceMiles: any(named: 'distanceMiles'),
        paceMinutesPerMile: any(named: 'paceMinutesPerMile'),
        timeBeforeRunHours: any(named: 'timeBeforeRunHours'),
        gutTrainingLevel: any(named: 'gutTrainingLevel'),
        tempF: any(named: 'tempF'),
        humidity: any(named: 'humidity'),
        sweatRate: any(named: 'sweatRate'),
        giSensitivity: any(named: 'giSensitivity'),
        allowHighCarbRun: any(named: 'allowHighCarbRun'),
      )).called(1);

      verify(() => mockPlanAnalytics.trackPlanGenerated(any())).called(1);
    });

    test('should handle plan generation failure', () async {
      logTestHeading('Test: Generate Plan - Failure');

      // Arrange
      final request = NutritionPlanRequestFixtures.casual5K();
      final error = Exception('Failed to generate plan');

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
      )).thenThrow(error);

      when(() => mockContentService.getValue('error_generating_plan', defaultValue: any(named: 'defaultValue')))
          .thenReturn('Failed to generate nutrition plan');

      logTestInput('Request', request);
      logTestInput('Expected Error', error.toString());

      // Act
      final controller = container.read(nutritionPlanControllerProvider.notifier);
      await controller.generatePlan(
        distanceMiles: request['distance_miles'] as double,
        paceMinutesPerMile: request['pace_minutes_per_mile'] as double,
        timeBeforeRunHours: request['time_before_run_hours'] as double,
        gutTrainingLevel: request['gut_training_level'] as String,
      );

      // Wait for state to update
      await container.pump();

      // Assert
      final state = container.read(nutritionPlanControllerProvider);
      state.when(
        data: (data) {
          expect(data.plan, isNull);
          expect(data.error, isNotNull);
          expect(data.error, contains('Failed to generate nutrition plan'));
          expect(data.isLoading, isFalse);

          logTestResult('Error State', {
            'error': data.error,
            'plan': data.plan,
          });
        },
        loading: () => fail('Should not be loading'),
        error: (_, __) => fail('Should be in data state with error'),
      );

      // Verify interactions
      verify(() => mockPlanAnalytics.trackPlanError(any())).called(1);
    });

    test('should save plan successfully', () async {
      logTestHeading('Test: Save Plan - Success');

      // Arrange
      final plan = NutritionPlan(
        id: 'plan-123',
        deviceId: 'test-device-123',
        macroTargets: FakeMacroTargets(),
        meals: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(() => mockService.updateNutritionPlan(any()))
          .thenAnswer((_) async => plan.copyWith(updatedAt: DateTime.now()));

      // Act
      final controller = container.read(nutritionPlanControllerProvider.notifier);

      // First set a generated plan
      controller.setGeneratedPlan(plan);
      await container.pump();

      // Then save it
      await controller.savePlan();
      await container.pump();

      // Assert
      final state = container.read(nutritionPlanControllerProvider);
      state.when(
        data: (data) {
          expect(data.plan, isNotNull);
          expect(data.isSaved, isTrue);
          expect(data.error, isNull);

          logTestResult('Saved Plan', {
            'id': data.plan?.id,
            'isSaved': data.isSaved,
          });
        },
        loading: () => fail('Should not be loading'),
        error: (_, __) => fail('Should not have error'),
      );

      // Verify interactions
      verify(() => mockService.updateNutritionPlan(any())).called(1);
      verify(() => mockPlanAnalytics.trackPlanSaved(any())).called(1);
    });

    test('should swap food item in plan', () async {
      logTestHeading('Test: Swap Food Item');

      // Arrange
      final originalFood = FoodItem(
        id: 'food-1',
        name: 'Oatmeal',
        quantity: 1.0,
        unit: 'cup',
        carbs: 54.0,
        protein: 6.0,
        fat: 3.0,
        sodium: 150.0,
        fluid: 0.0,
      );

      final newFood = FoodItem(
        id: 'food-2',
        name: 'Banana',
        quantity: 1.0,
        unit: 'medium',
        carbs: 27.0,
        protein: 1.0,
        fat: 0.5,
        sodium: 1.0,
        fluid: 0.0,
      );

      final plan = NutritionPlan(
        id: 'plan-123',
        deviceId: 'test-device-123',
        macroTargets: FakeMacroTargets(),
        meals: [
          Meal(
            id: 'meal-1',
            name: 'Pre-Run Meal',
            category: 'before',
            foods: [originalFood],
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Act
      final controller = container.read(nutritionPlanControllerProvider.notifier);

      // Set initial plan
      controller.setGeneratedPlan(plan);
      await container.pump();

      // Swap food
      controller.swapFoodItem('meal-1', 'food-1', newFood);
      await container.pump();

      // Assert
      final state = container.read(nutritionPlanControllerProvider);
      state.when(
        data: (data) {
          expect(data.plan, isNotNull);
          expect(data.plan!.meals.first.foods.length, equals(1));
          expect(data.plan!.meals.first.foods.first.name, equals('Banana'));
          expect(data.plan!.meals.first.foods.first.id, equals('food-2'));

          logTestResult('Swapped Food', {
            'original': originalFood.name,
            'new': newFood.name,
          });
        },
        loading: () => fail('Should not be loading'),
        error: (_, __) => fail('Should not have error'),
      );

      // Verify analytics
      verify(() => mockAnalytics.track(any(), any())).called(greaterThanOrEqualTo(1));
    });

    test('should update food quantity', () async {
      logTestHeading('Test: Update Food Quantity');

      // Arrange
      final food = FoodItem(
        id: 'food-1',
        name: 'Oatmeal',
        quantity: 1.0,
        unit: 'cup',
        carbs: 54.0,
        protein: 6.0,
        fat: 3.0,
        sodium: 150.0,
        fluid: 0.0,
      );

      final plan = NutritionPlan(
        id: 'plan-123',
        deviceId: 'test-device-123',
        macroTargets: FakeMacroTargets(),
        meals: [
          Meal(
            id: 'meal-1',
            name: 'Pre-Run Meal',
            category: 'before',
            foods: [food],
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Act
      final controller = container.read(nutritionPlanControllerProvider.notifier);

      // Set initial plan
      controller.setGeneratedPlan(plan);
      await container.pump();

      // Update quantity
      controller.updateFoodQuantity('meal-1', 'food-1', 2.0);
      await container.pump();

      // Assert
      final state = container.read(nutritionPlanControllerProvider);
      state.when(
        data: (data) {
          expect(data.plan, isNotNull);
          expect(data.plan!.meals.first.foods.first.quantity, equals(2.0));
          // Macros should double
          expect(data.plan!.meals.first.foods.first.carbs, equals(108.0));
          expect(data.plan!.meals.first.foods.first.protein, equals(12.0));

          logTestResult('Updated Quantity', {
            'original': 1.0,
            'new': 2.0,
            'carbs': data.plan!.meals.first.foods.first.carbs,
          });
        },
        loading: () => fail('Should not be loading'),
        error: (_, __) => fail('Should not have error'),
      );
    });
  });
}