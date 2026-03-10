import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mealvana_endurance/shared/services/version_check_service.dart';
import 'package:mealvana_endurance/shared/models/version_check_result.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/dirty_record_backup_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Mock classes
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockAppLogger extends Mock implements AppLogger {}

class MockDirtyRecordBackupService extends Mock
    implements DirtyRecordBackupService {}

/// Test double for AppDatabase
class FakeAppDatabase extends Fake implements AppDatabase {
  @override
  int get schemaVersion => 3;
}

/// Test double for AppDatabase with schema version 4
class FakeAppDatabaseV4 extends Fake implements AppDatabase {
  @override
  int get schemaVersion => 4;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Set up PackageInfo mock once
    PackageInfo.setMockInitialValues(
      appName: 'Mealvana',
      packageName: 'com.mealvana.endurance',
      version: '1.12.1',
      buildNumber: '64',
      buildSignature: '',
    );
  });

  group('VersionCheckResult', () {
    test('VersionCheckOk has correct properties', () {
      const result = VersionCheckOk();
      expect(result.isOk, true);
      expect(result.isUpdateRequired, false);
      expect(result.isResyncRequired, false);
    });

    test('VersionCheckUpdateRequired has correct properties', () {
      const result = VersionCheckUpdateRequired(
        currentVersion: '1.0.0',
        requiredVersion: '2.0.0',
      );
      expect(result.isOk, false);
      expect(result.isUpdateRequired, true);
      expect(result.isResyncRequired, false);
      expect(result.currentVersion, '1.0.0');
      expect(result.requiredVersion, '2.0.0');
    });

    test('VersionCheckResyncRequired has correct properties', () {
      const result = VersionCheckResyncRequired(
        localSchemaVersion: 1,
        remoteSchemaVersion: 2,
      );
      expect(result.isOk, false);
      expect(result.isUpdateRequired, false);
      expect(result.isResyncRequired, true);
      expect(result.localSchemaVersion, 1);
      expect(result.remoteSchemaVersion, 2);
    });
  });

  group('VersionCheckService', () {
    test('clearCache removes all cached values', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'cached_min_app_version': '1.12.0',
        'cached_remote_schema_version': 3,
        'cached_min_supported_schema_version': 3,
        'version_check_cache_timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      final mockSupabase = MockSupabaseClient();
      final database = FakeAppDatabase();
      final mockLogger = MockAppLogger();
      final mockBackupService = MockDirtyRecordBackupService();
      final container = ProviderContainer();

      final testProvider = Provider((ref) {
        return VersionCheckService(
          supabase: mockSupabase,
          database: database,
          logger: mockLogger,
          backupService: mockBackupService,
          ref: ref,
        );
      });
      final service = container.read(testProvider);

      // Act
      await service.clearCache();

      // Assert
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cached_min_app_version'), isNull);
      expect(prefs.getInt('cached_remote_schema_version'), isNull);
      expect(prefs.getInt('cached_min_supported_schema_version'), isNull);
      expect(prefs.getInt('version_check_cache_timestamp'), isNull);

      container.dispose();
    });

    test('service can be instantiated with all dependencies', () {
      // Arrange
      final mockSupabase = MockSupabaseClient();
      final database = FakeAppDatabase();
      final mockLogger = MockAppLogger();
      final mockBackupService = MockDirtyRecordBackupService();
      final container = ProviderContainer();

      // Act & Assert
      final testProvider = Provider((ref) {
        return VersionCheckService(
          supabase: mockSupabase,
          database: database,
          logger: mockLogger,
          backupService: mockBackupService,
          ref: ref,
        );
      });
      final service = container.read(testProvider);
      expect(service, isNotNull);

      container.dispose();
    });

    test('FakeAppDatabase returns correct schema version', () {
      final database = FakeAppDatabase();
      expect(database.schemaVersion, 3);
    });

    test(
      'checkVersion returns ok from cache when schema is behind latest but within compatibility window',
      () async {
        SharedPreferences.setMockInitialValues({
          'cached_min_app_version': '1.0.0',
          'cached_remote_schema_version': 4,
          'cached_min_supported_schema_version': 3,
          'version_check_cache_timestamp':
              DateTime.now().millisecondsSinceEpoch,
        });

        final mockSupabase = MockSupabaseClient();
        final database = FakeAppDatabase(); // Local schema = 3
        final mockLogger = MockAppLogger();
        final mockBackupService = MockDirtyRecordBackupService();
        final container = ProviderContainer();

        final testProvider = Provider((ref) {
          return VersionCheckService(
            supabase: mockSupabase,
            database: database,
            logger: mockLogger,
            backupService: mockBackupService,
            ref: ref,
          );
        });
        final service = container.read(testProvider);

        final result = await service.checkVersion();
        expect(result, isA<VersionCheckOk>());

        container.dispose();
      },
    );

    test(
      'checkVersion returns updateRequired from cache when schema is below minimum supported',
      () async {
        SharedPreferences.setMockInitialValues({
          'cached_min_app_version': '1.12.0',
          'cached_remote_schema_version': 4,
          'cached_min_supported_schema_version': 4,
          'version_check_cache_timestamp':
              DateTime.now().millisecondsSinceEpoch,
        });

        final mockSupabase = MockSupabaseClient();
        final database = FakeAppDatabase(); // Local schema = 3
        final mockLogger = MockAppLogger();
        final mockBackupService = MockDirtyRecordBackupService();
        final container = ProviderContainer();

        final testProvider = Provider((ref) {
          return VersionCheckService(
            supabase: mockSupabase,
            database: database,
            logger: mockLogger,
            backupService: mockBackupService,
            ref: ref,
          );
        });
        final service = container.read(testProvider);

        final result = await service.checkVersion();
        expect(result, isA<VersionCheckUpdateRequired>());

        container.dispose();
      },
    );

    test(
      'checkVersion preserves strict behavior when compatibility key is missing',
      () async {
        SharedPreferences.setMockInitialValues({
          'cached_min_app_version': '1.0.0',
          'cached_remote_schema_version': 4,
          'version_check_cache_timestamp':
              DateTime.now().millisecondsSinceEpoch,
        });

        final mockSupabase = MockSupabaseClient();
        final database = FakeAppDatabase(); // Local schema = 3
        final mockLogger = MockAppLogger();
        final mockBackupService = MockDirtyRecordBackupService();
        final container = ProviderContainer();

        final testProvider = Provider((ref) {
          return VersionCheckService(
            supabase: mockSupabase,
            database: database,
            logger: mockLogger,
            backupService: mockBackupService,
            ref: ref,
          );
        });
        final service = container.read(testProvider);

        final result = await service.checkVersion();
        expect(result, isA<VersionCheckResyncRequired>());

        container.dispose();
      },
    );

    test(
      'checkVersion returns ok when local schema is ahead of cached latest schema',
      () async {
        SharedPreferences.setMockInitialValues({
          'cached_min_app_version': '1.0.0',
          'cached_remote_schema_version': 3,
          'cached_min_supported_schema_version': 3,
          'version_check_cache_timestamp':
              DateTime.now().millisecondsSinceEpoch,
        });

        final mockSupabase = MockSupabaseClient();
        final database = FakeAppDatabaseV4(); // Local schema = 4
        final mockLogger = MockAppLogger();
        final mockBackupService = MockDirtyRecordBackupService();
        final container = ProviderContainer();

        final testProvider = Provider((ref) {
          return VersionCheckService(
            supabase: mockSupabase,
            database: database,
            logger: mockLogger,
            backupService: mockBackupService,
            ref: ref,
          );
        });
        final service = container.read(testProvider);

        final result = await service.checkVersion();
        expect(result, isA<VersionCheckOk>());

        container.dispose();
      },
    );

    // NOTE: Tests that require mocking the full Supabase fluent API chain
    // (checkVersion with various responses) are deferred to integration tests
    // due to mocktail limitations with Supabase's builder pattern.
    //
    // Integration tests should verify:
    // - returns ok when versions match
    // - returns updateRequired when app version too low
    // - returns resyncRequired when schema mismatch
    // - caches result on success
    // - uses cached result on network failure
    // - returns ok on network failure with no cache
  });
}
