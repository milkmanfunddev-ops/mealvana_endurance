import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/app_startup/application/app_startup_provider.dart';
import 'package:mealvana_endurance/features/app_startup/application/app_startup_service.dart';
import 'package:mealvana_endurance/shared/services/version_check_service.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/models/version_check_result.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';

// Mock classes
class MockVersionCheckService extends Mock implements VersionCheckService {}
class MockAppStartupService extends Mock implements AppStartupService {}
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockAppLogger extends Mock implements AppLogger {}
class MockSentryReporter extends Mock implements SentryReporter {}
class MockAnalyticsTracker extends Mock implements AnalyticsTracker {}
class MockAppDatabase extends Mock implements AppDatabase {}
class MockSharedPreferences extends Mock implements SharedPreferences {}

/// Integration test for version check during app startup
///
/// Tests:
/// 1. Normal startup when version check passes
/// 2. Force upgrade when app version is too low
/// 3. Schema resync when schema version mismatch detected
void main() {
  group('AppStartup Version Check Integration', () {
    late MockVersionCheckService mockVersionCheckService;
    late MockAppStartupService mockAppStartupService;
    late MockSupabaseClient mockSupabaseClient;
    late MockGoTrueClient mockGoTrueClient;
    late MockAppLogger mockLogger;
    late MockSentryReporter mockSentry;
    late MockAnalyticsTracker mockAnalytics;
    late MockAppDatabase mockDatabase;
    late MockSharedPreferences mockSharedPreferences;
    late ProviderContainer container;

    setUp(() {
      mockVersionCheckService = MockVersionCheckService();
      mockAppStartupService = MockAppStartupService();
      mockSupabaseClient = MockSupabaseClient();
      mockGoTrueClient = MockGoTrueClient();
      mockLogger = MockAppLogger();
      mockSentry = MockSentryReporter();
      mockAnalytics = MockAnalyticsTracker();
      mockDatabase = MockAppDatabase();
      mockSharedPreferences = MockSharedPreferences();

      // Setup default mocks
      when(() => mockSupabaseClient.auth).thenReturn(mockGoTrueClient);
      when(() => mockGoTrueClient.currentSession).thenReturn(null);
      when(() => mockLogger.info(any(), context: any(named: 'context'))).thenReturn(null);
      when(() => mockLogger.warning(any(), context: any(named: 'context'))).thenReturn(null);
      when(() => mockLogger.error(any(), context: any(named: 'context'), error: any(named: 'error'), stackTrace: any(named: 'stackTrace'))).thenReturn(null);
      when(() => mockSentry.addBreadcrumb(
        message: any(named: 'message'),
        category: any(named: 'category'),
        data: any(named: 'data'),
      )).thenReturn(null);

      // Setup AppExternalDeps
      final mockAppExternalDeps = AppExternalDeps(
        supabaseClient: mockSupabaseClient,
        logger: mockLogger,
        sentry: mockSentry,
        analytics: mockAnalytics,
        sharedPreferences: mockSharedPreferences,
      );

      // Create container with overrides
      container = ProviderContainer(
        overrides: [
          versionCheckServiceProvider.overrideWithValue(mockVersionCheckService),
          appStartupServiceProvider.overrideWithValue(mockAppStartupService),
          appExternalDepsProvider.overrideWithValue(mockAppExternalDeps),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('proceeds with normal startup when version check passes', () async {
      // Arrange
      when(() => mockVersionCheckService.checkVersion()).thenAnswer(
        (_) async => const VersionCheckResult.ok(),
      );
      when(() => mockAppStartupService.initializeDatabase()).thenAnswer((_) async {});
      // initializeSupabaseAuth was removed - Supabase init happens in main.dart
      when(() => mockAppStartupService.setSentryUserContext()).thenAnswer((_) async {});
      when(() => mockAppStartupService.initializeDeferredServices()).thenAnswer((_) async {});
      when(() => mockAppStartupService.checkForPendingFeedback()).thenAnswer((_) async => null);

      // Mock database provider is needed but won't be called during version check
      // We need to override it to prevent real database initialization
      final containerWithDb = ProviderContainer(
        overrides: [
          versionCheckServiceProvider.overrideWithValue(mockVersionCheckService),
          appStartupServiceProvider.overrideWithValue(mockAppStartupService),
          appExternalDepsProvider.overrideWithValue(
            AppExternalDeps(
              supabaseClient: mockSupabaseClient,
              logger: mockLogger,
              sentry: mockSentry,
              analytics: mockAnalytics,
              sharedPreferences: mockSharedPreferences,
            ),
          ),
          appDatabaseProvider.overrideWithValue(mockDatabase),
        ],
      );

      when(() => mockDatabase.userDao.getCurrentUserProfile(currentAuthUserId: any(named: 'currentAuthUserId')))
          .thenAnswer((_) async => null);
      when(() => mockDatabase.schemaVersion).thenReturn(2);

      // Act
      final result = await containerWithDb.read(appStartupProvider.future);

      // Assert
      expect(result.forceUpgradeRequired, false);
      expect(result.resyncRequired, false);
      expect(result.user, null); // No user on fresh install

      // Verify version check was called
      verify(() => mockVersionCheckService.checkVersion()).called(1);
      verify(() => mockLogger.info('Version check passed - continuing with normal startup', context: 'VERSION_CHECK')).called(1);

      containerWithDb.dispose();
    });

    test('returns force upgrade state when app version is too low', () async {
      // Arrange
      when(() => mockVersionCheckService.checkVersion()).thenAnswer(
        (_) async => const VersionCheckResult.updateRequired(
          currentVersion: '1.0.0',
          requiredVersion: '2.0.0',
        ),
      );

      // Act
      final result = await container.read(appStartupProvider.future);

      // Assert
      expect(result.forceUpgradeRequired, true);
      expect(result.currentVersion, '1.0.0');
      expect(result.requiredVersion, '2.0.0');
      expect(result.resyncRequired, false);

      // Verify version check was called
      verify(() => mockVersionCheckService.checkVersion()).called(1);
      verify(() => mockLogger.warning(
        'Force upgrade required: current=1.0.0, required=2.0.0',
        context: 'VERSION_CHECK',
      )).called(1);

      // Verify database initialization was NOT called (startup stopped early)
      verifyNever(() => mockAppStartupService.initializeDatabase());
    });

    test('returns resync state when schema version mismatch detected', () async {
      // Arrange
      when(() => mockVersionCheckService.checkVersion()).thenAnswer(
        (_) async => const VersionCheckResult.resyncRequired(
          localSchemaVersion: 1,
          remoteSchemaVersion: 2,
        ),
      );

      // Act
      final result = await container.read(appStartupProvider.future);

      // Assert
      expect(result.resyncRequired, true);
      expect(result.localSchemaVersion, 1);
      expect(result.remoteSchemaVersion, 2);
      expect(result.forceUpgradeRequired, false);

      // Verify version check was called
      verify(() => mockVersionCheckService.checkVersion()).called(1);
      verify(() => mockLogger.warning(
        'Schema resync required: local=1, remote=2',
        context: 'VERSION_CHECK',
      )).called(1);

      // Verify database initialization was NOT called (startup stopped early)
      verifyNever(() => mockAppStartupService.initializeDatabase());
    });

    test('handles version check network failure gracefully', () async {
      // Arrange - version check throws exception but returns cached ok result
      when(() => mockVersionCheckService.checkVersion()).thenAnswer(
        (_) async => const VersionCheckResult.ok(), // Cached result
      );
      when(() => mockAppStartupService.initializeDatabase()).thenAnswer((_) async {});
      // initializeSupabaseAuth was removed - Supabase init happens in main.dart
      when(() => mockAppStartupService.setSentryUserContext()).thenAnswer((_) async {});
      when(() => mockAppStartupService.initializeDeferredServices()).thenAnswer((_) async {});
      when(() => mockAppStartupService.checkForPendingFeedback()).thenAnswer((_) async => null);

      final containerWithDb = ProviderContainer(
        overrides: [
          versionCheckServiceProvider.overrideWithValue(mockVersionCheckService),
          appStartupServiceProvider.overrideWithValue(mockAppStartupService),
          appExternalDepsProvider.overrideWithValue(
            AppExternalDeps(
              supabaseClient: mockSupabaseClient,
              logger: mockLogger,
              sentry: mockSentry,
              analytics: mockAnalytics,
              sharedPreferences: mockSharedPreferences,
            ),
          ),
          appDatabaseProvider.overrideWithValue(mockDatabase),
        ],
      );

      when(() => mockDatabase.userDao.getCurrentUserProfile(currentAuthUserId: any(named: 'currentAuthUserId')))
          .thenAnswer((_) async => null);
      when(() => mockDatabase.schemaVersion).thenReturn(2);

      // Act
      final result = await containerWithDb.read(appStartupProvider.future);

      // Assert - app should start normally with cached result
      expect(result.forceUpgradeRequired, false);
      expect(result.resyncRequired, false);

      containerWithDb.dispose();
    });
  });
}
