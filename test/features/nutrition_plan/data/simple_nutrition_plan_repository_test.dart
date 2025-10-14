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

void main() {
  late MockSupabaseClient mockSupabase;
  late MockAppDatabase mockDatabase;
  late MockSentryReporter mockSentry;
  late MockFoodDataTransformationService mockTransformationService;
  late MockFunctionsClient mockFunctions;
  late NutritionPlanRepository repository;

  setUp(() {
    logTestHeading('Simple NutritionPlanRepository Test Setup');

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

  group('NutritionPlanRepository - Simple Tests', () {
    test('should call run-plan edge function with correct parameters', () async {
      logTestHeading('Test: Create Plan via Edge Function');

      // Arrange
      const deviceId = 'test-device-123';
      const weightKg = 70.0;
      const durationMin = 90;  // 90 minutes run

      final mockResponse = {
        'success': true,
        'data': {
          'nutritionPlan': {
            'id': 'test-plan-123',
            'name': 'Test Plan',
            'sections': [],
            'macroTargets': {
              'calories': 2000,
              'carbs': 300,
              'protein': 80,
              'fat': 60,
            },
          },
          'calculations': {
            'totalCalories': 2000,
          },
        },
      };

      when(() => mockFunctions.invoke(
        'run-plan',
        body: any(named: 'body'),
      )).thenAnswer((_) async => FunctionResponse(
        data: mockResponse,
        status: 200,
      ));

      logTestInput({
        'deviceId': deviceId,
        'weightKg': weightKg,
        'durationMin': durationMin,
      });

      // Act
      final result = await repository.createNutritionPlanV2(
        deviceId: deviceId,
        weightKg: weightKg,
        durationMin: durationMin,
      );

      // Assert
      expect(result.success, isTrue);
      expect(result.plan, isNotNull);
      expect(result.plan?.id, equals('test-plan-123'));

      logTestResult('Edge Function Called', {
        'success': result.success,
        'planId': result.plan?.id,
      });

      // Verify edge function was called
      verify(() => mockFunctions.invoke(
        'run-plan',
        body: any(named: 'body'),
      )).called(1);
    });

    test('should handle edge function error response', () async {
      logTestHeading('Test: Handle Edge Function Error');

      // Arrange
      const deviceId = 'test-device-123';

      when(() => mockFunctions.invoke(
        'run-plan',
        body: any(named: 'body'),
      )).thenAnswer((_) async => FunctionResponse(
        data: {
          'success': false,
          'error': 'Service unavailable',
        },
        status: 500,
      ));

      // Act
      final result = await repository.createNutritionPlanV2(
        deviceId: deviceId,
        weightKg: 70.0,
        durationMin: 60,
      );

      // Assert
      expect(result.success, isFalse);
      expect(result.plan, isNull);
      expect(result.message, contains('Failed'));

      logTestResult('Error Handled', {
        'success': result.success,
        'message': result.message,
      });
    });

    test('should include optional parameters when provided', () async {
      logTestHeading('Test: Optional Parameters');

      // Arrange
      const deviceId = 'test-device-123';

      final mockResponse = {
        'success': true,
        'data': {
          'nutritionPlan': {
            'id': 'test-plan',
            'name': 'Test',
            'sections': [],
          },
        },
      };

      when(() => mockFunctions.invoke(
        'run-plan',
        body: any(named: 'body'),
      )).thenAnswer((_) async => FunctionResponse(
        data: mockResponse,
        status: 200,
      ));

      // Act
      await repository.createNutritionPlanV2(
        deviceId: deviceId,
        weightKg: 70.0,
        durationMin: 90,
        preWindowMin: 120,
        gutTraining: 'moderate',
        tempF: 75.0,
        humidity: 60.0,
      );

      // Verify that invoke was called with body containing optional params
      final captured = verify(() => mockFunctions.invoke(
        'run-plan',
        body: captureAny(named: 'body'),
      )).captured.single as Map<String, dynamic>;

      expect(captured['preWindowMin'], equals(120));
      expect(captured['gutTraining'], equals('moderate'));
      expect(captured['tempF'], equals(75.0));
      expect(captured['humidity'], equals(60.0));

      logTestResult('Optional Parameters', {
        'preWindowMin': captured['preWindowMin'],
        'gutTraining': captured['gutTraining'],
        'tempF': captured['tempF'],
        'humidity': captured['humidity'],
      });
    });

    test('should handle malformed response gracefully', () async {
      logTestHeading('Test: Malformed Response');

      // Arrange
      when(() => mockFunctions.invoke(
        'run-plan',
        body: any(named: 'body'),
      )).thenAnswer((_) async => FunctionResponse(
        data: 'Invalid response format',  // Not a map
        status: 200,
      ));

      // Act
      final result = await repository.createNutritionPlanV2(
        deviceId: 'test-device',
        weightKg: 70.0,
        durationMin: 60,
      );

      // Assert
      expect(result.success, isFalse);
      expect(result.plan, isNull);
      expect(result.message, contains('Failed'));

      logTestResult('Malformed Response Handled', {
        'success': result.success,
        'hasError': result.message != null,
      });
    });

    test('should add sentry breadcrumbs for debugging', () async {
      logTestHeading('Test: Sentry Breadcrumbs');

      // Arrange
      final mockResponse = {
        'success': true,
        'data': {
          'nutritionPlan': {
            'id': 'test',
            'name': 'Test',
            'sections': [],
          },
        },
      };

      when(() => mockFunctions.invoke(
        'run-plan',
        body: any(named: 'body'),
      )).thenAnswer((_) async => FunctionResponse(
        data: mockResponse,
        status: 200,
      ));

      // Act
      await repository.createNutritionPlanV2(
        deviceId: 'test-device',
        weightKg: 70.0,
        durationMin: 60,
      );

      // Assert - verify breadcrumb was added
      verify(() => mockSentry.addBreadcrumb(
        message: any(named: 'message'),
        category: any(named: 'category'),
        data: any(named: 'data'),
      )).called(greaterThanOrEqualTo(1));

      logTestResult('Breadcrumbs Added', 'Sentry tracking confirmed');
    });
  });
}