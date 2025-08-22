import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:mealvana_endurance/shared/services/sentry_service.dart';

void main() {
  group('SentryService', () {
    late ProviderContainer container;
    late SentryService sentryService;

    setUp(() {
      container = ProviderContainer();
      sentryService = container.read(sentryServiceProvider);
    });

    tearDown(() {
      container.dispose();
    });

    test('should create SentryService instance', () {
      expect(sentryService, isA<SentryService>());
    });

    test('should have correct methods available', () {
      expect(sentryService.reportCriticalError, isA<Function>());
      expect(sentryService.reportEdgeFunctionError, isA<Function>());
      expect(sentryService.reportDatabaseError, isA<Function>());
      expect(sentryService.setUserContext, isA<Function>());
      expect(sentryService.addBreadcrumb, isA<Function>());
      expect(sentryService.startTransaction, isA<Function>());
    });

    group('Error Reporting', () {
      test('reportCriticalError should not throw', () async {
        // This test verifies the method doesn't crash
        // In a real scenario, you'd mock Sentry to verify calls
        expect(
          () async => await sentryService.reportCriticalError(
            Exception('Test error'),
            context: 'unit_test',
            tags: {'test': 'true'},
          ),
          returnsNormally,
        );
      });

      test('reportEdgeFunctionError should not throw', () async {
        expect(
          () async => await sentryService.reportEdgeFunctionError(
            'test-function',
            Exception('Edge function test error'),
            responseTime: Duration(milliseconds: 500),
            statusCode: 500,
          ),
          returnsNormally,
        );
      });

      test('reportDatabaseError should not throw', () async {
        expect(
          () async => await sentryService.reportDatabaseError(
            Exception('Database test error'),
            operation: 'select',
            table: 'test_table',
          ),
          returnsNormally,
        );
      });
    });

    group('User Context', () {
      test('setUserContext should not throw', () async {
        expect(
          () async => await sentryService.setUserContext(
            deviceId: 'test-device-123',
            appVersion: '1.0.0-test',
            onboardingCompleted: true,
            gutTrainingLevel: 'moderate',
          ),
          returnsNormally,
        );
      });

      test('clearUserContext should not throw', () async {
        expect(
          () async => await sentryService.clearUserContext(),
          returnsNormally,
        );
      });
    });

    group('Breadcrumbs and Messages', () {
      test('addBreadcrumb should not throw', () {
        expect(
          () => sentryService.addBreadcrumb(
            message: 'Test breadcrumb',
            category: 'test',
            level: SentryLevel.info,
            data: {'test': true},
          ),
          returnsNormally,
        );
      });

      test('captureMessage should not throw', () async {
        expect(
          () async => await sentryService.captureMessage(
            'Test message',
            level: SentryLevel.info,
            tags: {'test': 'true'},
          ),
          returnsNormally,
        );
      });
    });

    group('Performance Monitoring', () {
      test('startTransaction should return transaction', () {
        final transaction = sentryService.startTransaction(
          'test_operation',
          'Test transaction description',
        );
        expect(transaction, isA<ISentrySpan>());
      });

      test('reportMetric should not throw', () {
        expect(
          () => sentryService.reportMetric(
            name: 'test_metric',
            value: 42.0,
            unit: 'ms',
            tags: {'test': 'true'},
          ),
          returnsNormally,
        );
      });
    });
  });
}