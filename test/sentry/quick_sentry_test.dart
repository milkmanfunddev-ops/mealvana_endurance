import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:mealvana_endurance/shared/services/sentry_service.dart';

/// Quick Sentry test to send essential test data
/// Run with: flutter test test/sentry/quick_sentry_test.dart
void main() {
  group('Quick Sentry Test', () {
    late ProviderContainer container;
    late SentryService sentryService;

    setUpAll(() async {
      await SentryFlutter.init(
        (options) {
          options.dsn = 'https://00d9cb3e5fc60c90fd5ca3ed2bf690c5@o4509882392969216.ingest.us.sentry.io/4509882394083328';
          options.environment = 'quick_test';
          options.debug = true;
          options.tracesSampleRate = 1.0;
          options.sendDefaultPii = false;
          options.release = 'mealvana-endurance@1.1.0+8-quick-test';
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

    test('Send test errors to Sentry dashboard', () async {
      final testId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // 1. Critical Error
      try {
        throw Exception('🚨 TEST CRITICAL ERROR - Sentry verification test $testId');
      } catch (error, stackTrace) {
        await sentryService.reportCriticalError(
          error,
          stackTrace: stackTrace,
          context: 'quick_test',
          tags: {'test_id': testId, 'error_type': 'critical'},
        );
      }

      // 2. Edge Function Error
      await sentryService.reportEdgeFunctionError(
        'create-nutrition-plan',
        Exception('🔧 TEST EDGE FUNCTION ERROR - Timeout simulation $testId'),
        responseTime: Duration(milliseconds: 3000),
        statusCode: 504,
      );

      // 3. Database Error
      await sentryService.reportDatabaseError(
        Exception('💾 TEST DATABASE ERROR - Connection failure $testId'),
        operation: 'test_save',
        table: 'users',
      );

      // 4. Success Message
      await sentryService.captureMessage(
        '✅ Quick Sentry test completed successfully - Test ID: $testId',
        tags: {'test_id': testId, 'status': 'success'},
      );

      // Wait for transmission
      await Future.delayed(Duration(seconds: 1));

      print('');
      print('🎉 Quick Sentry test completed!');
      print('📊 Test ID: $testId');
      print('🔗 Check dashboard: https://sentry.io/organizations/mealvana/projects/');
      print('');
      print('Expected events:');
      print('  ✓ 1 Critical Error');
      print('  ✓ 1 Edge Function Error');
      print('  ✓ 1 Database Error');
      print('  ✓ 1 Success Message');
      print('');
    });
  });
}