import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Test that exactly replicates the Sentry docs example
/// Run with: flutter test test/sentry/docs_example_test.dart
void main() {
  group('Docs Example Test', () {
    testWidgets('Replicate exact docs example with button press', (tester) async {
      // Initialize Sentry
      await SentryFlutter.init(
        (options) {
          options.dsn = 'https://00d9cb3e5fc60c90fd5ca3ed2bf690c5@o4509882392969216.ingest.us.sentry.io/4509882394083328';
          options.environment = 'docs_example_test';
          options.debug = true;
          options.sendDefaultPii = false;
          
          options.beforeSend = (event, hint) {
            print('📤 Sentry captured exception:');
            print('   Event ID: ${event.eventId}');
            print('   Exception: ${event.throwable}');
            print('   Stack trace available: ${event.exceptions?.isNotEmpty ?? false}');
            return event;
          };
        },
      );

      // Create the exact widget from docs
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  throw StateError('This is test exception');
                },
                child: const Text('Verify Sentry Setup'),
              ),
            ),
          ),
        ),
      );

      print('🔍 Widget built, Sentry enabled: ${Sentry.isEnabled}');

      // Find and tap the button (this should trigger the exception)
      final button = find.text('Verify Sentry Setup');
      expect(button, findsOneWidget);

      print('🚨 Tapping button to trigger StateError...');
      
      // This should throw the exception and be caught by Sentry
      await expectLater(
        () => tester.tap(button),
        throwsStateError,
      );

      print('✅ StateError was thrown');

      // Wait for Sentry to process
      await Future.delayed(Duration(seconds: 2));
      
      print('');
      print('🎯 Docs example test completed!');
      print('🔍 Check Sentry dashboard for StateError: "This is test exception"');
      print('📊 Environment: docs_example_test');
      print('');
    });

    test('Direct exception capture like manual error reporting', () async {
      await SentryFlutter.init(
        (options) {
          options.dsn = 'https://00d9cb3e5fc60c90fd5ca3ed2bf690c5@o4509882392969216.ingest.us.sentry.io/4509882394083328';
          options.environment = 'manual_capture_test';
          options.debug = true;
        },
      );

      print('🚨 Manually capturing StateError...');
      
      // Manually capture the exact same exception
      try {
        throw StateError('This is test exception');
      } catch (exception, stackTrace) {
        final eventId = await Sentry.captureException(
          exception,
          stackTrace: stackTrace,
        );
        
        print('📤 Manually captured exception with ID: $eventId');
      }

      // Also test with our service
      try {
        throw StateError('This is test exception via service');
      } catch (exception, stackTrace) {
        await Sentry.captureException(exception, stackTrace: stackTrace);
        print('📤 Captured via Sentry.captureException');
      }

      await Future.delayed(Duration(seconds: 1));
      
      print('');
      print('✅ Manual capture test completed!');
      print('🔍 Look for "This is test exception" in Sentry');
      print('');
    });
  });
}