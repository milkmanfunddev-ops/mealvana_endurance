import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/services/sentry_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Test our refactored Sentry integration
/// Run with: flutter test test/sentry/refactored_sentry_test.dart
void main() {
  group('Refactored Sentry Integration Test', () {
    test('Initialize Sentry with our service and send test data', () async {
      bool appRunnerCalled = false;
      
      // Test our static initialization method
      await SentryService.initializeSentry(
        appRunner: () {
          appRunnerCalled = true;
        },
        customEnvironment: 'refactored_test',
      );

      expect(appRunnerCalled, isTrue, reason: 'App runner should be called');
      expect(Sentry.isEnabled, isTrue, reason: 'Sentry should be enabled');

      print('🔍 Sentry enabled: ${Sentry.isEnabled}');

      // Test that we can send errors with our refactored setup
      SentryId? eventId;
      try {
        throw StateError('Refactored Sentry test exception');
      } catch (error, stackTrace) {
        eventId = await Sentry.captureException(
          error,
          stackTrace: stackTrace,
        );
        print('📤 Test exception sent: $eventId');
      }

      // Test message capture
      final messageId = await Sentry.captureMessage(
        'Refactored Sentry integration test completed successfully',
        level: SentryLevel.info,
      );
      print('📤 Test message sent: $messageId');

      // Test breadcrumbs
      Sentry.addBreadcrumb(Breadcrumb(
        message: 'Refactored integration test breadcrumb',
        category: 'test',
        level: SentryLevel.info,
        data: {
          'test_type': 'refactored_integration',
          'timestamp': DateTime.now().toIso8601String(),
        },
      ));

      await Future.delayed(Duration(seconds: 1));

      print('');
      print('🎯 Refactored Sentry Test Completed!');
      print('🔍 Check Sentry dashboard for:');
      print('   - Environment: refactored_test');
      print('   - StateError: "Refactored Sentry test exception"');
      print('   - Message: "Refactored Sentry integration test completed"');
      print('   - Event IDs: $eventId, $messageId');
      print('');
    });

    test('Test SentryService instance methods', () async {
      // Initialize Sentry first
      await SentryService.initializeSentry(
        appRunner: () {},
        customEnvironment: 'service_test',
      );

      // Create service instance
      final sentryService = SentryService();

      expect(sentryService.isEnabled, isTrue);

      // Test critical error reporting
      try {
        throw Exception('SentryService instance test error');
      } catch (error, stackTrace) {
        await sentryService.reportCriticalError(
          error,
          stackTrace: stackTrace,
          context: 'service_instance_test',
          tags: {
            'test_type': 'service_methods',
            'method': 'reportCriticalError',
          },
        );
      }

      // Test user context
      await sentryService.setUserContext(
        deviceId: 'test-device-refactored-${DateTime.now().millisecondsSinceEpoch}',
        appVersion: '1.1.0-refactored-test',
        onboardingCompleted: true,
        gutTrainingLevel: 'high',
      );

      // Test breadcrumbs
      sentryService.addBreadcrumb(
        message: 'Service method test breadcrumb',
        category: 'service_test',
        data: {
          'service': 'SentryService',
          'method_tested': 'addBreadcrumb',
        },
      );

      // Test app startup completion tracking
      await sentryService.trackAppStartupCompleted();

      await Future.delayed(Duration(milliseconds: 500));

      print('✅ SentryService instance methods test completed!');
    });
  });
}