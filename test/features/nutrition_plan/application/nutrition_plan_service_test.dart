import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/nutrition_plan_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/llm_nutrition_plan_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/nutrition_plan_repository.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/food_repository.dart';
import 'package:mealvana_endurance/features/auth/application/auth_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/meal.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import '../../../helpers/utils/console_logging.dart';
import '../../../helpers/fakes/external_deps.dart';
import '../../../helpers/fixtures/nutrition_plan_requests.dart';

// Mock classes
class MockNutritionPlanRepository extends Mock implements NutritionPlanRepository {}
class MockFoodRepository extends Mock implements FoodRepository {}
class MockAuthService extends Mock implements AuthService {}
class MockLLMNutritionPlanService extends Mock implements LLMNutritionPlanService {}
class MockSentryReporter extends Mock implements SentryReporter {}

// Fake classes for fallback values
class FakeNutritionPlan extends Fake implements NutritionPlan {}
class FakeMacroTargets extends Fake implements MacroTargets {}

void main() {
  late ProviderContainer container;
  late MockNutritionPlanRepository mockPlanRepository;
  late MockFoodRepository mockFoodRepository;
  late MockAuthService mockAuthService;
  late MockLLMNutritionPlanService mockLLMService;
  late MockSentryReporter mockSentry;
  late NutritionPlanService service;

  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(FakeNutritionPlan());
    registerFallbackValue(FakeMacroTargets());
  });

  setUp(() {
    logTestHeading('NutritionPlanService Test Setup');

    // Initialize mocks
    mockPlanRepository = MockNutritionPlanRepository();
    mockFoodRepository = MockFoodRepository();
    mockAuthService = MockAuthService();
    mockLLMService = MockLLMNutritionPlanService();
    mockSentry = MockSentryReporter();

    // Create provider container with overrides
    container = ProviderContainer(
      overrides: [
        nutritionPlanRepositoryProvider.overrideWithValue(mockPlanRepository),
        foodRepositoryProvider.overrideWithValue(mockFoodRepository),
        authServiceProvider.overrideWithValue(mockAuthService),
        llmNutritionPlanServiceProvider.overrideWithValue(mockLLMService),
        overrideAppExternalDeps(buildTestExternalDeps()),
      ],
    );

    // Get the service instance
    service = container.read(nutritionPlanServiceProvider);
  });

  tearDown(() {
    container.dispose();
  });

  group('NutritionPlanService', () {
    group('generateNutritionPlan', () {
      test('should generate a nutrition plan successfully using LLM service', () async {
        logTestHeading('Test: Generate Nutrition Plan - Success');

        // Arrange
        const deviceId = 'test-device-123';
        final request = NutritionPlanRequestFixtures.marathon();
        final expectedMacros = MacroTargets(
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
        );

        final expectedPlan = NutritionPlan(
          id: 'plan-123',
          deviceId: deviceId,
          macroTargets: expectedMacros,
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

        // Mock the current user
        when(() => mockAuthService.currentUser).thenReturn(deviceId);

        // Mock LLM service to return a plan
        when(() => mockLLMService.generateNutritionPlan(
          deviceId: deviceId,
          distanceMiles: request['distance_miles'] as double,
          paceMinutesPerMile: request['pace_minutes_per_mile'] as double,
          timeBeforeRunHours: request['time_before_run_hours'] as double,
          gutTrainingLevel: request['gut_training_level'] as String,
          tempF: request['temp_f'] as double?,
          humidity: request['humidity'] as double?,
          sweatRate: request['sweat_rate'] as String?,
          giSensitivity: request['gi_sensitivity'] as String?,
          allowHighCarbRun: request['allow_high_carb_run'] as bool?,
        )).thenAnswer((_) async => expectedPlan);

        // Mock repository save
        when(() => mockPlanRepository.savePlan(any())).thenAnswer((_) async => expectedPlan);

        logTestInput('Request', request);

        // Act
        final result = await service.generateNutritionPlan(
          distanceMiles: request['distance_miles'] as double,
          paceMinutesPerMile: request['pace_minutes_per_mile'] as double,
          timeBeforeRunHours: request['time_before_run_hours'] as double,
          gutTrainingLevel: request['gut_training_level'] as String,
          tempF: request['temp_f'] as double?,
          humidity: request['humidity'] as double?,
          sweatRate: request['sweat_rate'] as String?,
          giSensitivity: request['gi_sensitivity'] as String?,
          allowHighCarbRun: request['allow_high_carb_run'] as bool?,
        );

        // Assert
        expect(result, isNotNull);
        expect(result.id, equals('plan-123'));
        expect(result.deviceId, equals(deviceId));
        expect(result.macroTargets, equals(expectedMacros));
        expect(result.meals.length, equals(1));
        expect(result.meals.first.foods.length, equals(1));

        logTestResult('Generated Plan', {
          'id': result.id,
          'deviceId': result.deviceId,
          'meals': result.meals.length,
          'foods': result.meals.fold(0, (sum, meal) => sum + meal.foods.length),
        });

        // Verify interactions
        verify(() => mockLLMService.generateNutritionPlan(
          deviceId: deviceId,
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

        verify(() => mockPlanRepository.savePlan(any())).called(1);
      });

      test('should handle LLM service failure and return error', () async {
        logTestHeading('Test: Generate Nutrition Plan - LLM Failure');

        // Arrange
        const deviceId = 'test-device-123';
        final request = NutritionPlanRequestFixtures.casual5K();
        final error = Exception('LLM service unavailable');

        when(() => mockAuthService.currentUser).thenReturn(deviceId);
        when(() => mockLLMService.generateNutritionPlan(
          deviceId: deviceId,
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

        logTestInput('Request', request);
        logTestInput('Expected Error', error.toString());

        // Act & Assert
        expect(
          () async => await service.generateNutritionPlan(
            distanceMiles: request['distance_miles'] as double,
            paceMinutesPerMile: request['pace_minutes_per_mile'] as double,
            timeBeforeRunHours: request['time_before_run_hours'] as double,
            gutTrainingLevel: request['gut_training_level'] as String,
          ),
          throwsException,
        );

        logTestResult('Error Thrown', 'Exception handled correctly');
      });
    });

    group('getUserNutritionPlans', () {
      test('should return user nutrition plans from repository', () async {
        logTestHeading('Test: Get User Nutrition Plans');

        // Arrange
        const deviceId = 'test-device-123';
        final plans = [
          NutritionPlan(
            id: 'plan-1',
            deviceId: deviceId,
            macroTargets: FakeMacroTargets(),
            meals: [],
            createdAt: DateTime.now().subtract(const Duration(days: 2)),
            updatedAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
          NutritionPlan(
            id: 'plan-2',
            deviceId: deviceId,
            macroTargets: FakeMacroTargets(),
            meals: [],
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
            updatedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ];

        when(() => mockAuthService.currentUser).thenReturn(deviceId);
        when(() => mockPlanRepository.getUserPlans(deviceId)).thenAnswer((_) async => plans);

        // Act
        final result = await service.getUserNutritionPlans();

        // Assert
        expect(result, isNotNull);
        expect(result.length, equals(2));
        expect(result[0].id, equals('plan-1'));
        expect(result[1].id, equals('plan-2'));

        logTestResult('Plans Retrieved', {
          'count': result.length,
          'planIds': result.map((p) => p.id).toList(),
        });

        // Verify interactions
        verify(() => mockPlanRepository.getUserPlans(deviceId)).called(1);
      });

      test('should return empty list when no plans exist', () async {
        logTestHeading('Test: Get User Nutrition Plans - Empty');

        // Arrange
        const deviceId = 'test-device-123';

        when(() => mockAuthService.currentUser).thenReturn(deviceId);
        when(() => mockPlanRepository.getUserPlans(deviceId)).thenAnswer((_) async => []);

        // Act
        final result = await service.getUserNutritionPlans();

        // Assert
        expect(result, isNotNull);
        expect(result, isEmpty);

        logTestResult('Empty Plans', 'No plans found for user');

        // Verify interactions
        verify(() => mockPlanRepository.getUserPlans(deviceId)).called(1);
      });
    });

    group('validateNutritionPlan', () {
      test('should validate nutrition plan successfully', () async {
        logTestHeading('Test: Validate Nutrition Plan');

        // Arrange
        final plan = NutritionPlan(
          id: 'plan-123',
          deviceId: 'device-123',
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
                  carbs: 150.0,
                  protein: 20.0,
                  fat: 10.0,
                  sodium: 500.0,
                  fluid: 500.0,
                ),
              ],
            ),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final result = service.validateNutritionPlan(plan);

        // Assert
        expect(result, isTrue);

        logTestResult('Validation', 'Plan is valid');
      });

      test('should return false for plan with insufficient macros', () async {
        logTestHeading('Test: Validate Nutrition Plan - Invalid');

        // Arrange
        final plan = NutritionPlan(
          id: 'plan-123',
          deviceId: 'device-123',
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
                  name: 'Small snack',
                  quantity: 1.0,
                  unit: 'piece',
                  carbs: 10.0, // Way below target
                  protein: 2.0,
                  fat: 1.0,
                  sodium: 50.0,
                  fluid: 0.0,
                ),
              ],
            ),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final result = service.validateNutritionPlan(plan);

        // Assert
        expect(result, isFalse);

        logTestResult('Validation', 'Plan is invalid due to insufficient macros');
      });
    });
  });
}