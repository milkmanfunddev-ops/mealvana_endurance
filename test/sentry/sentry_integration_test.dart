import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:mealvana_endurance/shared/services/sentry_service.dart';

/// Integration test for Sentry functionality
/// 
/// This test should be run manually in development to verify Sentry is working.
/// It will send actual test data to Sentry.
/// 
/// To run: flutter test test/sentry/sentry_integration_test.dart
void main() {
  group('Sentry Integration Test', () {
    late ProviderContainer container;
    late SentryService sentryService;

    setUpAll(() async {
      // Initialize Sentry for testing
      await SentryFlutter.init(
        (options) {
          options.dsn = 'https://00d9cb3e5fc60c90fd5ca3ed2bf690c5@o4509882392969216.ingest.us.sentry.io/4509882394083328';
          options.environment = 'test';
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

    testWidgets('Sentry should be initialized and working', (tester) async {
      expect(sentryService.isEnabled, isTrue);
      
      // Test basic breadcrumb
      sentryService.addBreadcrumb(
        message: 'Integration test started',
        category: 'test',
        level: SentryLevel.info,
      );
      
      // Test message capture
      await sentryService.captureMessage(
        'Sentry integration test - message capture working',
        level: SentryLevel.info,
        tags: {
          'test_type': 'integration',
          'component': 'sentry_service',
          'test_run': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      
      // Test user context
      await sentryService.setUserContext(
        deviceId: 'test-device-integration-${DateTime.now().millisecondsSinceEpoch}',
        appVersion: '1.1.0-test',
        onboardingCompleted: true,
        gutTrainingLevel: 'moderate',
      );
      
      // Test error reporting
      try {
        throw Exception('Integration test exception - this is expected');
      } catch (error, stackTrace) {
        await sentryService.reportCriticalError(
          error,
          stackTrace: stackTrace,
          context: 'integration_test',
          tags: {
            'test_type': 'integration',
            'expected': 'true',
          },
        );
      }
      
      // Test Edge Function error simulation
      await sentryService.reportEdgeFunctionError(
        'test-function',
        Exception('Simulated Edge Function error for integration test'),
        responseTime: Duration(milliseconds: 1500),
        statusCode: 500,
      );
      
      // Test database error simulation
      await sentryService.reportDatabaseError(
        Exception('Simulated database error for integration test'),
        operation: 'test_query',
        table: 'test_table',
      );
      
      // Test performance transaction
      final transaction = sentryService.startTransaction(
        'test_integration',
        'Integration test transaction',
      );
      
      await Future.delayed(Duration(milliseconds: 100));
      
      transaction.finish(status: SpanStatus.ok());
      
      // Test metric reporting
      sentryService.reportMetric(
        name: 'integration_test_duration',
        value: 100.0,
        unit: 'ms',
        tags: {'test': 'integration'},
      );
      
      // Final breadcrumb
      sentryService.addBreadcrumb(
        message: 'Integration test completed successfully',
        category: 'test',
        level: SentryLevel.info,
        data: {
          'timestamp': DateTime.now().toIso8601String(),
          'status': 'success',
        },
      );
      
      print('✅ Sentry integration test completed');
      print('📊 Check your Sentry dashboard for test events');
      print('🔗 https://sentry.io/organizations/mealvana/projects/');
      
      // Wait a bit for events to be sent
      await Future.delayed(Duration(seconds: 2));
    });
  });
}