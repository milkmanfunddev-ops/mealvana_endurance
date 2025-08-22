import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Debug test to verify Sentry DSN and connection
/// Run with: flutter test test/sentry/debug_sentry_test.dart
void main() {
  group('Debug Sentry Connection', () {
    test('Verify DSN and send simple event', () async {
      final dsn = 'https://00d9cb3e5fc60c90fd5ca3ed2bf690c5@o4509882392969216.ingest.us.sentry.io/4509882394083328';
      
      print('🔍 Testing Sentry DSN: $dsn');
      
      // Initialize with minimal configuration
      await SentryFlutter.init(
        (options) {
          options.dsn = dsn;
          options.environment = 'debug_test';
          options.debug = true; // Enable debug logging
          options.tracesSampleRate = 1.0; // 100% sampling
          options.sendDefaultPii = false;
          options.release = 'debug-test-${DateTime.now().millisecondsSinceEpoch}';
          
          // Override beforeSend to see what's being sent
          options.beforeSend = (event, hint) {
            print('📤 Sending event to Sentry:');
            print('   Event ID: ${event.eventId}');
            print('   Level: ${event.level}');
            print('   Environment: ${event.environment}');
            print('   Release: ${event.release}');
            print('   Message: ${event.message?.formatted}');
            print('   Exception: ${event.throwable}');
            return event; // Allow the event to be sent
          };
        },
      );

      print('✅ Sentry initialized');
      print('🔗 Sentry enabled: ${Sentry.isEnabled}');

      // Test 1: Simple message
      final messageId = await Sentry.captureMessage(
        'DEBUG TEST: Simple message to verify Sentry connection',
        level: SentryLevel.info,
      );
      print('📨 Message sent with ID: $messageId');

      // Test 2: Exception
      SentryId? exceptionId;
      try {
        throw Exception('DEBUG TEST: Test exception for Sentry verification');
      } catch (error, stackTrace) {
        exceptionId = await Sentry.captureException(
          error,
          stackTrace: stackTrace,
        );
        print('🚨 Exception sent with ID: $exceptionId');
      }

      // Test 3: Add breadcrumb and another message
      Sentry.addBreadcrumb(Breadcrumb(
        message: 'Debug test breadcrumb',
        category: 'debug',
        level: SentryLevel.info,
        data: {
          'test': true,
          'timestamp': DateTime.now().toIso8601String(),
        },
      ));

      final finalId = await Sentry.captureMessage(
        'DEBUG TEST: Final message with breadcrumb',
        level: SentryLevel.warning,
      );
      print('📨 Final message sent with ID: $finalId');

      // Wait for events to be sent
      print('⏳ Waiting 3 seconds for events to be transmitted...');
      await Future.delayed(Duration(seconds: 3));

      print('');
      print('🎯 Debug test completed!');
      print('');
      print('If you still don\'t see events in Sentry:');
      print('1. Check the DSN is correct in your Sentry project');
      print('2. Verify the project exists and is accessible');
      print('3. Check if there are any rate limits or filters');
      print('4. Look at the debug output above for any errors');
      print('');
      print('Event IDs to search for:');
      print('  Message: $messageId');
      print('  Exception: $exceptionId');
      print('  Final: $finalId');
      print('');
    });

    test('Test different Sentry features individually', () async {
      final dsn = 'https://00d9cb3e5fc60c90fd5ca3ed2bf690c5@o4509882392969216.ingest.us.sentry.io/4509882394083328';
      
      // Re-initialize for clean slate
      await SentryFlutter.init(
        (options) {
          options.dsn = dsn;
          options.environment = 'feature_test';
          options.debug = true;
          options.tracesSampleRate = 1.0;
        },
      );

      final testId = DateTime.now().millisecondsSinceEpoch;

      // Test user context
      await Sentry.configureScope((scope) {
        scope.setUser(SentryUser(
          id: 'debug-user-$testId',
          email: null, // No PII
          username: null, // No PII
          data: {'test': 'debug'},
        ));
      });

      // Test tags
      await Sentry.configureScope((scope) {
        scope.setTag('test_type', 'debug');
        scope.setTag('test_id', testId.toString());
        scope.setTag('platform', 'flutter');
        scope.setTag('test_framework', 'flutter_test');
      });

      // Send event with full context
      final contextId = await Sentry.captureMessage(
        'DEBUG TEST: Message with full context and user data',
        level: SentryLevel.info,
      );

      print('📨 Context message sent: $contextId');
      print('👤 User ID: debug-user-$testId');
      print('🏷️ Tags: test_type=debug, test_id=$testId');

      await Future.delayed(Duration(seconds: 2));

      print('');
      print('✅ Feature test completed!');
      print('Search in Sentry for user ID: debug-user-$testId');
      print('');
    });
  });
}