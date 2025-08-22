import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Manual exception test exactly like the docs
/// Run with: flutter test test/sentry/manual_exception_test.dart
void main() {
  group('Manual Exception Test', () {
    test('Manually capture StateError like docs example', () async {
      await SentryFlutter.init(
        (options) {
          options.dsn = 'https://00d9cb3e5fc60c90fd5ca3ed2bf690c5@o4509882392969216.ingest.us.sentry.io/4509882394083328';
          options.environment = 'manual_exception_test';
          options.debug = true;
          options.sendDefaultPii = false;
          
          options.beforeSend = (event, hint) {
            print('🚨 EXCEPTION CAPTURED BY SENTRY:');
            print('   Event ID: ${event.eventId}');
            print('   Exception Type: ${event.throwable.runtimeType}');
            print('   Exception Message: ${event.throwable}');
            print('   Environment: ${event.environment}');
            print('   Level: ${event.level}');
            return event;
          };
        },
      );

      print('🔍 Sentry initialized: ${Sentry.isEnabled}');
      print('🚨 Manually capturing StateError exactly like docs...');

      // Method 1: Manual capture with try-catch
      SentryId? eventId1;
      try {
        throw StateError('This is test exception');
      } catch (exception, stackTrace) {
        eventId1 = await Sentry.captureException(
          exception,
          stackTrace: stackTrace,
        );
        print('📤 Manual capture 1 - Event ID: $eventId1');
      }

      // Method 2: Direct capture (alternative approach)
      final eventId2 = await Sentry.captureException(
        StateError('This is test exception - direct capture'),
        stackTrace: StackTrace.current,
      );
      print('📤 Manual capture 2 - Event ID: $eventId2');

      // Method 3: Using zone error handling simulation
      print('🚨 Testing zone error handling...');
      await runZonedGuarded(() async {
        throw StateError('This is test exception - zone capture');
      }, (error, stackTrace) async {
        final eventId3 = await Sentry.captureException(error, stackTrace: stackTrace);
        print('📤 Zone capture - Event ID: $eventId3');
      });

      // Wait for transmission
      await Future.delayed(Duration(seconds: 2));

      print('');
      print('🎯 Manual Exception Test Completed!');
      print('');
      print('Event IDs sent to Sentry:');
      print('  🚨 StateError 1: $eventId1');
      print('  🚨 StateError 2: $eventId2');
      print('  🚨 StateError 3: (check zone capture output above)');
      print('');
      print('🔍 Search in Sentry dashboard for:');
      print('  - Environment: manual_exception_test');
      print('  - Exception type: StateError');
      print('  - Message: "This is test exception"');
      print('');
    });

    test('Test different exception types', () async {
      await SentryFlutter.init(
        (options) {
          options.dsn = 'https://00d9cb3e5fc60c90fd5ca3ed2bf690c5@o4509882392969216.ingest.us.sentry.io/4509882394083328';
          options.environment = 'exception_types_test';
          options.debug = true;
        },
      );

      final testId = DateTime.now().millisecondsSinceEpoch;

      // Different exception types
      final exceptions = [
        () => throw StateError('StateError test - $testId'),
        () => throw ArgumentError('ArgumentError test - $testId'),
        () => throw FormatException('FormatException test - $testId'),
        () => throw Exception('Generic Exception test - $testId'),
      ];

      for (int i = 0; i < exceptions.length; i++) {
        try {
          exceptions[i]();
        } catch (exception, stackTrace) {
          final eventId = await Sentry.captureException(exception, stackTrace: stackTrace);
          print('📤 Exception ${i + 1}: ${exception.runtimeType} - ID: $eventId');
        }
      }

      await Future.delayed(Duration(seconds: 1));

      print('');
      print('✅ Exception types test completed!');
      print('📊 Sent 4 different exception types with test ID: $testId');
      print('');
    });
  });
}