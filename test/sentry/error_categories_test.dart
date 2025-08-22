import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:mealvana_endurance/shared/services/sentry_service.dart';

/// Test different error categories and user context tracking
/// Run with: flutter test test/sentry/error_categories_test.dart
void main() {
  group('Error Categories Test', () {
    late ProviderContainer container;
    late SentryService sentryService;

    setUpAll(() async {
      await SentryFlutter.init(
        (options) {
          options.dsn = 'https://00d9cb3e5fc60c90fd5ca3ed2bf690c5@o4509882392969216.ingest.us.sentry.io/4509882394083328';
          options.environment = 'error_categories_test';
          options.debug = true;
          options.tracesSampleRate = 1.0;
          options.sendDefaultPii = false;
        },
      );
    });

    setUp(() {
      container = ProviderContainer();
      sentryService = container.read(sentryServiceProvider);
    });

    tearDown(() {
      container.dispose();
    });

    test('Test all error categories with user context', () async {
      final testId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Set user context
      await sentryService.setUserContext(
        deviceId: 'test-device-$testId',
        appVersion: '1.1.0-test',
        onboardingCompleted: true,
        gutTrainingLevel: 'high',
      );

      sentryService.addBreadcrumb(
        message: 'Error categories test started',
        category: 'test_lifecycle',
        data: {'test_id': testId, 'test_type': 'error_categories'},
      );

      // 1. Critical App Error
      try {
        throw StateError('App crashed during nutrition plan calculation');
      } catch (error, stackTrace) {
        await sentryService.reportCriticalError(
          error,
          stackTrace: stackTrace,
          context: 'nutrition_calculation',
          tags: {
            'test_id': testId,
            'component': 'nutrition_plan',
            'severity': 'critical',
          },
        );
      }

      // 2. Edge Function Timeout
      await sentryService.reportEdgeFunctionError(
        'create-nutrition-plan',
        Exception('Edge Function timeout - user has slow connection'),
        responseTime: Duration(milliseconds: 8000),
        statusCode: 504,
      );

      // 3. Database Constraint Error
      await sentryService.reportDatabaseError(
        Exception('UNIQUE constraint failed: users.device_id'),
        operation: 'insert',
        table: 'users',
      );

      // 4. Network Connectivity Issue
      await sentryService.reportNetworkError(
        Exception('No internet connection available'),
        url: 'https://wvmvsodrvbkxfydabqed.supabase.co',
        method: 'POST',
        statusCode: null, // No status code for connection error
        timeout: Duration(seconds: 30),
      );

      // 5. Performance Transaction
      final transaction = sentryService.startTransaction(
        'user_onboarding_flow',
        'Complete user onboarding process',
      );

      // Simulate onboarding steps
      final profileSpan = sentryService.startSpan('create_user_profile');
      await Future.delayed(Duration(milliseconds: 100));
      profileSpan?.finish();

      final preferencesSpan = sentryService.startSpan('save_food_preferences');
      await Future.delayed(Duration(milliseconds: 200));
      preferencesSpan?.finish();

      transaction.finish(status: SpanStatus.ok());

      // 6. User Lifecycle Events
      sentryService.addBreadcrumb(
        message: 'User completed nutrition plan creation',
        category: 'user_action',
        data: {
          'plan_distance': '13.1',
          'plan_pace': '8.5',
          'plan_type': 'half_marathon',
        },
      );

      // 7. Business Logic Error
      try {
        throw ArgumentError('Invalid distance: -5 miles');
      } catch (error, stackTrace) {
        await sentryService.reportCriticalError(
          error,
          stackTrace: stackTrace,
          context: 'input_validation',
          tags: {
            'test_id': testId,
            'component': 'plan_creation',
            'error_category': 'validation',
          },
        );
      }

      // 8. Success Metrics
      sentryService.reportMetric(
        name: 'plan_creation_duration',
        value: 1250.0,
        unit: 'ms',
        tags: {
          'test_id': testId,
          'plan_type': 'half_marathon',
          'user_gut_training': 'high',
        },
      );

      await sentryService.captureMessage(
        'Error categories test completed - all error types sent',
        tags: {
          'test_id': testId,
          'errors_sent': '5',
          'transactions_sent': '1',
          'test_status': 'complete',
        },
      );

      await Future.delayed(Duration(milliseconds: 500));

      print('');
      print('🎯 Error Categories Test Completed!');
      print('📊 Test ID: $testId');
      print('');
      print('Sent to Sentry:');
      print('  🚨 Critical App Error (StateError)');
      print('  ⏱️  Edge Function Timeout (8000ms)');
      print('  💾 Database Constraint Error');
      print('  🌐 Network Connection Error');
      print('  📊 Performance Transaction (onboarding)');
      print('  ❌ Input Validation Error');
      print('  📈 Performance Metrics');
      print('  ✅ Success Message');
      print('');
      print('Check Sentry dashboard for:');
      print('  - Error grouping by component');
      print('  - User context correlation');
      print('  - Performance monitoring');
      print('  - Breadcrumb trails');
      print('');
    });

    test('Test error severity levels', () async {
      final testId = DateTime.now().millisecondsSinceEpoch.toString();

      // Low severity - Info level
      await sentryService.captureMessage(
        'User viewed nutrition plan',
        level: SentryLevel.info,
        tags: {
          'test_id': testId,
          'severity': 'info',
          'action': 'view_plan',
        },
      );

      // Medium severity - Warning level
      await sentryService.captureMessage(
        'Slow Edge Function response detected',
        level: SentryLevel.warning,
        tags: {
          'test_id': testId,
          'severity': 'warning',
          'response_time': '3500ms',
        },
      );

      // High severity - Error level
      try {
        throw Exception('Failed to save user preferences to local storage');
      } catch (error, stackTrace) {
        await sentryService.reportCriticalError(
          error,
          stackTrace: stackTrace,
          context: 'local_storage',
          tags: {
            'test_id': testId,
            'severity': 'error',
            'storage_type': 'drift',
          },
        );
      }

      await Future.delayed(Duration(milliseconds: 300));

      print('');
      print('📊 Severity Levels Test Completed!');
      print('📊 Test ID: $testId');
      print('');
      print('Sent severity levels:');
      print('  ℹ️  Info: User action tracking');
      print('  ⚠️  Warning: Performance issue');
      print('  🚨 Error: Critical failure');
      print('');
    });
  });
}