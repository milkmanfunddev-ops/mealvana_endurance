/// Mock providers for Mealvana Endurance tests
/// 
/// This file contains ProviderContainer overrides and mock implementations
/// following Andrea Bizzotto's testing patterns with real dependencies
/// where possible and strategic mocking for external services.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/features/content/data/content_repository.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/nutrition_plan_repository.dart';
import 'package:mealvana_endurance/shared/services/analytics_service.dart';

import 'test_config.dart';
import 'test_data.dart';

/// Mock classes for external dependencies
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockFunctionsClient extends Mock implements FunctionsClient {}
class MockFunctionResponse extends Mock implements FunctionResponse {}
class MockAnalyticsService extends Mock implements AnalyticsService {}

/// Mock repositories for testing specific scenarios  
class MockContentRepository extends Mock implements ContentRepository {}
class MockNutritionPlanRepository extends Mock implements NutritionPlanRepository {}

/// Generic Listener class for Andrea Bizzotto's testing pattern
class Listener<T> extends Mock {
  void call(T? previous, T next) {}
}

/// Test provider container factory
class TestProviderContainer {
  /// Creates a ProviderContainer with in-memory database and mock externals
  static ProviderContainer create({
    AppDatabase? database,
    SupabaseClient? supabaseClient,
    AnalyticsService? analyticsService,
    List<Override> additionalOverrides = const [],
  }) {
    final testDatabase = database ?? AppDatabase.testInstance();
    final mockSupabase = supabaseClient ?? _createMockSupabaseClient();
    final mockAnalytics = analyticsService ?? MockAnalyticsService();

    final container = ProviderContainer(
      overrides: [
        // Core database - use in-memory instance for speed
        appDatabaseProvider.overrideWith((ref) => testDatabase),
        
        // External services - mock for control and speed  
        analyticsServiceProvider.overrideWith((ref) => mockAnalytics),
        
        // Add any additional test-specific overrides
        ...additionalOverrides,
      ],
    );

    return container;
  }

  /// Creates a container with mock repositories for unit tests
  static ProviderContainer createWithMockRepositories({
    ContentRepository? contentRepository,
    NutritionPlanRepository? nutritionPlanRepository,
    List<Override> additionalOverrides = const [],
  }) {
    final mockContent = contentRepository ?? MockContentRepository();
    final mockNutritionPlan = nutritionPlanRepository ?? MockNutritionPlanRepository();

    return ProviderContainer(
      overrides: [
        contentRepositoryProvider.overrideWith((ref) => mockContent),
        nutritionPlanRepositoryProvider.overrideWith((ref) => mockNutritionPlan),
        ...additionalOverrides,
      ],
    );
  }

  /// Creates a container for schema migration testing
  static ProviderContainer createForMigrationTest({
    required int fromVersion,
    required int toVersion,
    List<Override> additionalOverrides = const [],
  }) {
    // Create database at specific version for migration testing
    final migrationDatabase = AppDatabase.testInstanceWithVersion(fromVersion);
    
    return create(
      database: migrationDatabase,
      additionalOverrides: additionalOverrides,
    );
  }

  /// Creates a container with live Supabase for integration tests
  static ProviderContainer createWithLiveSupabase({
    List<Override> additionalOverrides = const [],
  }) {
    // Validate test environment
    final configError = TestConfig.validateConfiguration();
    if (configError != null) {
      throw StateError('Test configuration invalid: $configError');
    }

    final liveSupabase = SupabaseClient(
      TestConfig.supabaseUrl,
      TestConfig.supabaseAnonKey,
    );

    return create(
      supabaseClient: liveSupabase,
      additionalOverrides: additionalOverrides,
    );
  }
}

/// Mock Supabase client setup with common responses
SupabaseClient _createMockSupabaseClient() {
  final mockClient = MockSupabaseClient();
  final mockFunctions = MockFunctionsClient();
  final mockResponse = MockFunctionResponse();

  // Setup mock functions client
  when(() => mockClient.functions).thenReturn(mockFunctions);

  // Setup successful nutrition plan generation response
  when(() => mockFunctions.invoke(
    'generate-ai-nutrition-plan',
    body: any(named: 'body'),
  )).thenAnswer((_) async {
    return mockResponse;
  });

  when(() => mockResponse.status).thenReturn(200);
  when(() => mockResponse.data).thenReturn(TestData.testNutritionPlanResult);

  // Setup fallback response for invalid requests
  when(() => mockFunctions.invoke(
    'generate-ai-nutrition-plan',
    body: argThat(contains('invalid'), named: 'body'),
  )).thenAnswer((_) async {
    final errorResponse = MockFunctionResponse();
    when(() => errorResponse.status).thenReturn(400);
    when(() => errorResponse.data).thenReturn({
      'success': false,
      'fallback_to_algorithm': true,
      'error': 'Invalid request data',
    });
    return errorResponse;
  });

  return mockClient;
}

/// Test setup helper for common mock configurations
class TestMockSetup {
  /// Sets up fallback values for mocktail
  static void setupFallbacks() {
    // AsyncValue fallbacks for listener testing
    registerFallbackValue(const AsyncLoading<Map<String, dynamic>>());
    registerFallbackValue(const AsyncData<Map<String, dynamic>>({}));
    registerFallbackValue(const AsyncError<Map<String, dynamic>>('test error', StackTrace.empty));

    // Common data fallbacks
    registerFallbackValue(TestData.testUserProfile);
    registerFallbackValue(TestData.testFoodPreferences.first);
    registerFallbackValue(TestData.testNutritionPlanRequest);
  }

  /// Sets up successful auth repository mock
  static void setupAuthRepositoryMock(MockAuthRepository mock) {
    when(() => mock.getDeviceId()).thenAnswer((_) async => TestData.deviceId1);
    when(() => mock.getCurrentUserId()).thenAnswer((_) async => TestData.deviceId1);
    when(() => mock.createProfile(any())).thenAnswer((_) async => TestData.testUserProfile);
    when(() => mock.getCurrentProfile()).thenAnswer((_) async => TestData.testUserProfile);
  }

  /// Sets up successful content repository mock
  static void setupContentRepositoryMock(MockContentRepository mock) {
    when(() => mock.getContent()).thenAnswer((_) async => TestData.testAppContent);
    when(() => mock.refreshFromBackend()).thenAnswer((_) async => true);
    when(() => mock.getValue(any(), defaultValue: any(named: 'defaultValue')))
        .thenAnswer((invocation) {
      final defaultValue = invocation.namedArguments[#defaultValue];
      return defaultValue ?? 'Test Content';
    });
  }

  /// Sets up successful nutrition plan repository mock
  static void setupNutritionPlanRepositoryMock(MockNutritionPlanRepository mock) {
    when(() => mock.generatePlan(any())).thenAnswer((_) async => TestData.testNutritionPlanResult);
    when(() => mock.savePlan(any())).thenAnswer((_) async => true);
    when(() => mock.getUserPlans(any())).thenAnswer((_) async => []);
  }

  /// Sets up analytics service mock (no-op for most tests)
  static void setupAnalyticsServiceMock(MockAnalyticsService mock) {
    when(() => mock.track(any(), properties: any(named: 'properties')))
        .thenAnswer((_) async {});
    when(() => mock.identify(any(), traits: any(named: 'traits')))
        .thenAnswer((_) async {});
  }
}

/// Test utilities for container management
class TestContainerUtils {
  /// Safely disposes container with error handling
  static void disposeContainer(ProviderContainer container) {
    try {
      container.dispose();
    } catch (e) {
      // Ignore disposal errors in tests
    }
  }

  /// Creates listener for AsyncNotifier testing
  static Listener<AsyncValue<T>> createListener<T>() {
    return Listener<AsyncValue<T>>();
  }

  /// Waits for AsyncNotifier to complete loading
  static Future<void> waitForAsyncValue<T>(
    ProviderContainer container,
    ProviderListenable<AsyncValue<T>> provider, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final completer = container.listen(
      provider,
      (previous, next) {
        if (!next.isLoading) {
          // Complete when not loading anymore
        }
      },
    );

    await Future.delayed(timeout);
    completer.close();
  }
}