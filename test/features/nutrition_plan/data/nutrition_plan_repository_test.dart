import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/nutrition_plan_repository.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/food_data_transformation_service.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import '../../../helpers/utils/console_logging.dart';

// Mock classes
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockAppDatabase extends Mock implements AppDatabase {}
class MockSentryReporter extends Mock implements SentryReporter {}
class MockFoodDataTransformationService extends Mock implements FoodDataTransformationService {}
class MockFunctionsClient extends Mock implements FunctionsClient {}
class MockNutritionPlansCompanion extends Mock implements NutritionPlansCompanion {}

// Test data helper
Map<String, dynamic> createTestPlanJson() {
  return {
    'id': 'test-plan-123',
    'name': 'Test Nutrition Plan',
    'sections': [
      {
        'id': 'section-1',
        'title': 'Before Run',
        'foodItems': [],
      },
      {
        'id': 'section-2',
        'title': 'During Run',
        'foodItems': [],
      },
    ],
    'macroTargets': {
      'calories': 2500,
      'carbs': 400,
      'protein': 100,
      'fat': 70,
    },
    'totalCalories': 2500,
    'notes': 'Test notes',
    'createdAt': DateTime.now().toIso8601String(),
    'updatedAt': DateTime.now().toIso8601String(),
  };
}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockAppDatabase mockDatabase;
  late MockSentryReporter mockSentry;
  late MockFoodDataTransformationService mockTransformationService;
  late MockFunctionsClient mockFunctions;
  late NutritionPlanRepository repository;

  setUp(() {
    logTestHeading('NutritionPlanRepository Test Setup');

    // Initialize mocks
    mockSupabase = MockSupabaseClient();
    mockDatabase = MockAppDatabase();
    mockSentry = MockSentryReporter();
    mockTransformationService = MockFoodDataTransformationService();
    mockFunctions = MockFunctionsClient();

    // Setup mock returns
    when(() => mockSupabase.functions).thenReturn(mockFunctions);
    when(() => mockSentry.addBreadcrumb(
      message: any(named: 'message'),
      category: any(named: 'category'),
      data: any(named: 'data'),
    )).thenReturn(null);

    // Create repository
    repository = NutritionPlanRepository(
      supabase: mockSupabase,
      database: mockDatabase,
      sentry: mockSentry,
      transformationService: mockTransformationService,
    );
  });

  group('NutritionPlanRepository', () {
    group('createNutritionPlanV2', () {
      test('should create nutrition plan successfully via edge function', () async {
        logTestHeading('Test: Create Nutrition Plan V2 - Success');

        // Arrange
        const deviceId = 'test-device-123';
        final request = {
          'deviceId': deviceId,
          'weightKg': 70.0,
          'durationMin': 111,  // for half marathon at 8.5 min/mile pace
          'preWindowMin': 120,  // 2 hours
          'gutTraining': 'moderate',
        };

        final mockResponse = {
          'success': true,
          'data': {
            'nutritionPlan': createTestPlanJson(),
            'calculations': {
              'totalCalories': 2500,
              'carbsPercentage': 64,
            },
          },
        };

        when(() => mockFunctions.invoke(
          'run-plan',
          body: request,
        )).thenAnswer((_) async => FunctionResponse(
          data: mockResponse,
          status: 200,
        ));

        logTestInput(request);

        // Act
        final result = await repository.createNutritionPlanV2(
          deviceId: deviceId,
          weightKg: 70.0,
          durationMin: 111,
          preWindowMin: 120,
          gutTraining: 'moderate',
        );

        // Assert
        expect(result.success, isTrue);
        expect(result.plan, isNotNull);
        expect(result.plan?.id, equals('test-plan-123'));
        expect(result.plan?.name, equals('Test Nutrition Plan'));
        expect(result.calculations, isNotNull);
        expect(result.calculations?['totalCalories'], equals(2500));

        logTestResult('Plan Created', {
          'success': result.success,
          'planId': result.plan?.id,
          'calories': result.calculations?['totalCalories'],
        });

        // Verify interactions
        verify(() => mockFunctions.invoke(
          'run-plan',
          body: request,
        )).called(1);
      });

      test('should handle edge function failure', () async {
        logTestHeading('Test: Create Nutrition Plan V2 - Edge Function Failure');

        // Arrange
        const deviceId = 'test-device-123';
        final request = {
          'deviceId': deviceId,
          'weightKg': 70.0,
          'durationMin': 111,  // for half marathon at 8.5 min/mile pace
          'preWindowMin': 120,  // 2 hours
          'gutTraining': 'moderate',
        };

        when(() => mockFunctions.invoke(
          'run-plan',
          body: request,
        )).thenAnswer((_) async => FunctionResponse(
          data: {'success': false, 'error': 'Service unavailable'},
          status: 500,
        ));

        logTestInput(request);

        // Act
        final result = await repository.createNutritionPlanV2(
          deviceId: deviceId,
          weightKg: 70.0,
          durationMin: 111,
          preWindowMin: 120,
          gutTraining: 'moderate',
        );

        // Assert
        expect(result.success, isFalse);
        expect(result.plan, isNull);
        expect(result.message, contains('Failed'));

        logTestResult('Edge Function Failed', {
          'success': result.success,
          'message': result.message,
        });
      });
    });

    group('Local Cache Operations', () {
      test('should save temp plan to local database', () async {
        logTestHeading('Test: Save Temp Plan');

        // Arrange
        final plan = NutritionPlan(
          id: 'temp-plan-123',
          name: 'Temp Plan',
          sections: [],
        );

        final planJson = plan.toJson();

        // Need to mock the database update operation
        when(() => mockDatabase.updateUserTempPlan(any(), any()))
            .thenAnswer((_) async => 1);

        logTestInput({
          'id': plan.id,
          'name': plan.name,
        });

        // Act
        await repository.saveTempPlan('device-123', plan);

        // Assert
        verify(() => mockDatabase.updateUserTempPlan('device-123', any())).called(1);

        logTestResult('Temp Plan Saved', 'Successfully saved to local database');
      });

      test('should retrieve temp plan from local database', () async {
        logTestHeading('Test: Get Temp Plan');

        // Arrange
        const deviceId = 'device-123';
        final tempPlanJson = createTestPlanJson();

        when(() => mockDatabase.getUserTempPlan(deviceId))
            .thenAnswer((_) async => tempPlanJson);

        // Act
        final plan = await repository.getTempPlan(deviceId);

        // Assert
        expect(plan, isNotNull);
        expect(plan?.id, equals('test-plan-123'));
        expect(plan?.name, equals('Test Nutrition Plan'));

        logTestResult('Temp Plan Retrieved', {
          'id': plan?.id,
          'name': plan?.name,
        });

        // Verify interactions
        verify(() => mockDatabase.getUserTempPlan(deviceId)).called(1);
      });

      test('should clear temp plan from local database', () async {
        logTestHeading('Test: Clear Temp Plan');

        // Arrange
        const deviceId = 'device-123';

        when(() => mockDatabase.clearUserTempPlan(deviceId))
            .thenAnswer((_) async => 1);

        // Act
        await repository.clearTempPlan(deviceId);

        // Assert
        verify(() => mockDatabase.clearUserTempPlan(deviceId)).called(1);

        logTestResult('Temp Plan Cleared', 'Successfully cleared from database');
      });
    });

    group('getUserNutritionPlans', () {
      test('should fetch user nutrition plans from database', () async {
        logTestHeading('Test: Get User Nutrition Plans');

        // Arrange
        const deviceId = 'device-123';
        final mockPlans = [
          createTestPlanJson(),
          {
            ...createTestPlanJson(),
            'id': 'test-plan-456',
            'name': 'Second Plan',
          },
        ];

        when(() => mockDatabase.getUserNutritionPlans(deviceId))
            .thenAnswer((_) async => mockPlans);

        // Act
        final plans = await repository.getUserNutritionPlans(deviceId);

        // Assert
        expect(plans, isNotNull);
        expect(plans.length, equals(2));
        expect(plans[0].id, equals('test-plan-123'));
        expect(plans[1].id, equals('test-plan-456'));

        logTestResult('Plans Retrieved', {
          'count': plans.length,
          'planIds': plans.map((p) => p.id).toList(),
        });

        // Verify interactions
        verify(() => mockDatabase.getUserNutritionPlans(deviceId)).called(1);
      });

      test('should return empty list when no plans exist', () async {
        logTestHeading('Test: Get User Nutrition Plans - Empty');

        // Arrange
        const deviceId = 'device-123';

        when(() => mockDatabase.getUserNutritionPlans(deviceId))
            .thenAnswer((_) async => []);

        // Act
        final plans = await repository.getUserNutritionPlans(deviceId);

        // Assert
        expect(plans, isNotNull);
        expect(plans, isEmpty);

        logTestResult('No Plans Found', 'Empty list returned');
      });
    });

    group('updateNutritionPlan', () {
      test('should update nutrition plan in database', () async {
        logTestHeading('Test: Update Nutrition Plan');

        // Arrange
        final plan = NutritionPlan(
          id: 'plan-to-update',
          name: 'Updated Plan',
          sections: [],
          notes: 'Updated notes',
        );

        when(() => mockDatabase.updateNutritionPlan(any()))
            .thenAnswer((_) async => 1);

        logTestInput({
          'id': plan.id,
          'name': plan.name,
          'notes': plan.notes,
        });

        // Act
        await repository.updateNutritionPlan(plan);

        // Assert
        verify(() => mockDatabase.updateNutritionPlan(any())).called(1);

        logTestResult('Plan Updated', 'Successfully updated in database');
      });
    });

    group('deleteNutritionPlan', () {
      test('should delete nutrition plan from database', () async {
        logTestHeading('Test: Delete Nutrition Plan');

        // Arrange
        const planId = 'plan-to-delete';

        when(() => mockDatabase.deleteNutritionPlan(planId))
            .thenAnswer((_) async => 1);

        // Act
        await repository.deleteNutritionPlan(planId);

        // Assert
        verify(() => mockDatabase.deleteNutritionPlan(planId)).called(1);

        logTestResult('Plan Deleted', {
          'planId': planId,
        });
      });
    });
  });
}