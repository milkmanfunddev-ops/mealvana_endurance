import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:mealvana_endurance/shared/services/sentry_service.dart';
import 'package:mealvana_endurance/shared/services/release_service.dart';

/// Live test for Sentry functionality - sends real data to Sentry
/// 
/// This test should be run manually to verify Sentry integration is working.
/// It will send actual test data to the Sentry project.
/// 
/// Run with: flutter test test/sentry/sentry_live_test.dart
/// 
/// After running, check the Sentry dashboard at:
/// https://sentry.io/organizations/mealvana/projects/
void main() {
  group('Sentry Live Test - Real Data Transmission', () {
    late ProviderContainer container;
    late SentryService sentryService;
    late ReleaseService releaseService;

    setUpAll(() async {
      // Initialize Sentry for live testing
      await SentryFlutter.init(
        (options) {
          options.dsn = 'https://00d9cb3e5fc60c90fd5ca3ed2bf690c5@o4509882392969216.ingest.us.sentry.io/4509882394083328';
          options.environment = 'test_live';
          options.debug = true;
          options.tracesSampleRate = 1.0;
          options.sendDefaultPii = false;
          options.release = 'mealvana-endurance@1.1.0+8-test';
        },
      );
      
      print('🚀 Sentry initialized for live testing');
    });

    setUp(() {
      container = ProviderContainer();
      sentryService = container.read(sentryServiceProvider);
      releaseService = container.read(releaseServiceProvider);
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('Send comprehensive test data to Sentry', (tester) async {
      final testRunId = DateTime.now().millisecondsSinceEpoch.toString();
      
      print('📊 Starting comprehensive Sentry test - Run ID: $testRunId');
      
      // 1. Set user context
      await sentryService.setUserContext(
        deviceId: 'test-device-$testRunId',
        appVersion: '1.1.0-test',
        onboardingCompleted: true,
        gutTrainingLevel: 'high',
      );
      
      sentryService.addBreadcrumb(
        message: 'Live test session started',
        category: 'test',
        data: {
          'test_run_id': testRunId,
          'test_type': 'comprehensive_live_test',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      print('✅ 1. User context set');

      // 2. Test critical error reporting
      try {
        throw Exception('TEST CRITICAL ERROR - This is a controlled test exception for Sentry verification');
      } catch (error, stackTrace) {
        await sentryService.reportCriticalError(
          error,
          stackTrace: stackTrace,
          context: 'live_test_critical',
          tags: {
            'test_run_id': testRunId,
            'error_type': 'critical_test',
            'severity': 'test_only',
          },
        );
      }
      
      print('✅ 2. Critical error sent');

      // 3. Test Edge Function error
      await sentryService.reportEdgeFunctionError(
        'create-nutrition-plan',
        Exception('TEST EDGE FUNCTION ERROR - Simulated timeout for testing'),
        responseTime: Duration(milliseconds: 5000),
        statusCode: 504,
      );
      
      print('✅ 3. Edge Function error sent');

      // 4. Test database error
      await sentryService.reportDatabaseError(
        Exception('TEST DATABASE ERROR - Simulated connection failure'),
        operation: 'test_query',
        table: 'test_users',
      );
      
      print('✅ 4. Database error sent');

      // 5. Test network error
      await sentryService.reportNetworkError(
        Exception('TEST NETWORK ERROR - Simulated API timeout'),
        url: 'https://api.test.mealvana.com/test-endpoint',
        method: 'POST',
        statusCode: 408,
        timeout: Duration(seconds: 30),
      );
      
      print('✅ 5. Network error sent');

      // 6. Test performance transaction
      final transaction = sentryService.startTransaction(
        'live_test_performance',
        'Performance test transaction for Sentry verification',
      );
      
      // Simulate some work
      await Future.delayed(Duration(milliseconds: 150));
      
      final span = sentryService.startSpan('test_operation');
      await Future.delayed(Duration(milliseconds: 50));
      span?.finish();
      
      transaction.finish(status: SpanStatus.ok());
      
      print('✅ 6. Performance transaction completed');

      // 7. Test metrics reporting
      sentryService.reportMetric(
        name: 'live_test_metric',
        value: 42.0,
        unit: 'ms',
        tags: {
          'test_run_id': testRunId,
          'metric_type': 'performance',
        },
      );
      
      print('✅ 7. Metrics sent');

      // 8. Test release tracking
      await releaseService.trackAppLaunch();
      
      print('✅ 8. Release tracking sent');

      // 9. Test message capture
      await sentryService.captureMessage(
        'LIVE TEST MESSAGE - Sentry integration verification complete',
        level: SentryLevel.info,
        tags: {
          'test_run_id': testRunId,
          'test_status': 'success',
          'verification': 'complete',
        },
      );
      
      print('✅ 9. Test message sent');

      // 10. Add final breadcrumbs
      sentryService.addBreadcrumb(
        message: 'All test data sent successfully',
        category: 'test_completion',
        data: {
          'test_run_id': testRunId,
          'errors_sent': '5',
          'transactions_sent': '1',
          'messages_sent': '1',
          'completion_time': DateTime.now().toIso8601String(),
        },
      );

      print('✅ 10. Final breadcrumbs added');

      // Wait for events to be sent
      await Future.delayed(Duration(seconds: 3));
      
      print('');
      print('🎉 LIVE TEST COMPLETED SUCCESSFULLY!');
      print('');
      print('📊 Test Run ID: $testRunId');
      print('🔗 Check your Sentry dashboard for events:');
      print('   https://sentry.io/organizations/mealvana/projects/');
      print('');
      print('🔍 Look for events with these tags:');
      print('   - test_run_id: $testRunId');
      print('   - environment: test_live');
      print('   - release: mealvana-endurance@1.1.0+8-test');
      print('');
      print('📋 Expected Events:');
      print('   ✓ 1 Critical Error (Exception)');
      print('   ✓ 1 Edge Function Error (504 timeout)');
      print('   ✓ 1 Database Error (connection failure)');
      print('   ✓ 1 Network Error (API timeout)');
      print('   ✓ 1 Performance Transaction');
      print('   ✓ 1 Info Message (test completion)');
      print('   ✓ 1 Release Tracking Event');
      print('   ✓ Multiple Breadcrumbs');
      print('');
    });

    testWidgets('Test error filtering and deduplication', (tester) async {
      final testRunId = DateTime.now().millisecondsSinceEpoch.toString();
      
      print('📊 Testing error filtering - Run ID: $testRunId');

      // Send multiple similar errors to test grouping
      for (int i = 1; i <= 3; i++) {
        try {
          throw Exception('DUPLICATE TEST ERROR - This error should be grouped in Sentry (occurrence $i)');
        } catch (error, stackTrace) {
          await sentryService.reportCriticalError(
            error,
            stackTrace: stackTrace,
            context: 'duplicate_test',
            tags: {
              'test_run_id': testRunId,
              'occurrence': i.toString(),
              'deduplication_test': 'true',
            },
          );
        }
        
        // Small delay between similar errors
        await Future.delayed(Duration(milliseconds: 100));
      }

      print('✅ Sent 3 similar errors for grouping test');

      // Test different error types
      final errorTypes = [
        'TimeoutException: Connection timeout',
        'FormatException: Invalid JSON format',
        'StateError: Widget not mounted',
      ];

      for (int i = 0; i < errorTypes.length; i++) {
        try {
          throw Exception(errorTypes[i]);
        } catch (error, stackTrace) {
          await sentryService.reportCriticalError(
            error,
            stackTrace: stackTrace,
            context: 'error_variety_test',
            tags: {
              'test_run_id': testRunId,
              'error_category': 'type_${i + 1}',
            },
          );
        }
      }

      print('✅ Sent 3 different error types');

      await Future.delayed(Duration(seconds: 2));
      
      print('');
      print('🔍 Error Filtering Test Complete!');
      print('📊 Check Sentry for:');
      print('   - Error grouping (3 similar errors should be grouped)');
      print('   - Error categorization (3 different error types)');
      print('   - Proper tagging and context');
      print('');
    });

    testWidgets('Test user lifecycle tracking', (tester) async {
      final testRunId = DateTime.now().millisecondsSinceEpoch.toString();
      final userId = 'test-user-$testRunId';
      
      print('📊 Testing user lifecycle tracking - Run ID: $testRunId');

      // Simulate user onboarding
      await sentryService.setUserContext(
        deviceId: userId,
        appVersion: '1.1.0-test',
        onboardingCompleted: false,
        gutTrainingLevel: 'moderate',
      );

      sentryService.addBreadcrumb(
        message: 'User started onboarding',
        category: 'user_lifecycle',
        data: {
          'user_id': userId,
          'onboarding_step': 'started',
        },
      );

      await sentryService.captureMessage(
        'User onboarding started',
        tags: {
          'test_run_id': testRunId,
          'lifecycle_event': 'onboarding_start',
          'user_id': userId,
        },
      );

      // Simulate onboarding completion
      await sentryService.setUserContext(
        deviceId: userId,
        appVersion: '1.1.0-test',
        onboardingCompleted: true,
        gutTrainingLevel: 'moderate',
      );

      sentryService.addBreadcrumb(
        message: 'User completed onboarding',
        category: 'user_lifecycle',
        data: {
          'user_id': userId,
          'onboarding_step': 'completed',
          'food_preferences_count': '15',
        },
      );

      await sentryService.captureMessage(
        'User onboarding completed',
        tags: {
          'test_run_id': testRunId,
          'lifecycle_event': 'onboarding_complete',
          'user_id': userId,
        },
      );

      // Clear user context (logout simulation)
      await sentryService.clearUserContext();

      sentryService.addBreadcrumb(
        message: 'User logged out',
        category: 'user_lifecycle',
        data: {
          'user_id': userId,
          'session_end': DateTime.now().toIso8601String(),
        },
      );

      print('✅ User lifecycle events sent');
      
      await Future.delayed(Duration(seconds: 1));
      
      print('');
      print('👤 User Lifecycle Test Complete!');
      print('📊 Check Sentry for user context changes');
      print('');
    });
  });
}