import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Simple test that throws an actual exception like the docs example
/// Run with: flutter test test/sentry/simple_throw_test.dart
void main() {
  group('Simple Throw Test', () {
    test('Throw StateError exactly like docs example', () async {
      // Initialize Sentry exactly like in the app
      await SentryFlutter.init(
        (options) {
          options.dsn = 'https://00d9cb3e5fc60c90fd5ca3ed2bf690c5@o4509882392969216.ingest.us.sentry.io/4509882394083328';
          options.environment = 'simple_throw_test';
          options.debug = true;
          options.sendDefaultPii = false;
          
          // Log what's being sent
          options.beforeSend = (event, hint) {
            print('🚨 SENDING ERROR TO SENTRY:');
            print('   Event ID: ${event.eventId}');
            print('   Exception: ${event.throwable}');
            print('   Message: ${event.message?.formatted}');
            print('   Environment: ${event.environment}');
            return event;
          };
        },
      );

      print('🔍 Sentry initialized: ${Sentry.isEnabled}');

      // Method 1: Direct throw (like docs example)
      print('🚨 Throwing StateError exactly like docs...');
      try {
        throw StateError('This is test exception');
      } catch (error, stackTrace) {
        print('🚨 Caught exception: $error');
        // This should be automatically caught by Sentry zone
        rethrow; // Let Sentry's zone handler catch it
      }
    });
  });
}