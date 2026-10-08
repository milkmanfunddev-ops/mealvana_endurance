import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mealvana_endurance/shared/services/launch_trail.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mealvana_endurance/shared/services/version_check_service.dart';
import 'package:mealvana_endurance/shared/models/version_check_result.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/dirty_record_backup_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/fakes/recording_report.dart';

// Mock classes
class MockSupabaseClient extends Mock implements SupabaseClient {}

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
      final report = RecordingReport();
      final mockBackupService = MockDirtyRecordBackupService();
      final container = ProviderContainer();

      final testProvider = Provider((ref) {
        return VersionCheckService(
          supabase: mockSupabase,
          database: database,
          report: report,
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
      final report = RecordingReport();
      final mockBackupService = MockDirtyRecordBackupService();
      final container = ProviderContainer();

      // Act & Assert
      final testProvider = Provider((ref) {
        return VersionCheckService(
          supabase: mockSupabase,
          database: database,
          report: report,
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
        final report = RecordingReport();
        final mockBackupService = MockDirtyRecordBackupService();
        final container = ProviderContainer();

        final testProvider = Provider((ref) {
          return VersionCheckService(
            supabase: mockSupabase,
            database: database,
            report: report,
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
        final report = RecordingReport();
        final mockBackupService = MockDirtyRecordBackupService();
        final container = ProviderContainer();

        final testProvider = Provider((ref) {
          return VersionCheckService(
            supabase: mockSupabase,
            database: database,
            report: report,
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
        final report = RecordingReport();
        final mockBackupService = MockDirtyRecordBackupService();
        final container = ProviderContainer();

        final testProvider = Provider((ref) {
          return VersionCheckService(
            supabase: mockSupabase,
            database: database,
            report: report,
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
        final report = RecordingReport();
        final mockBackupService = MockDirtyRecordBackupService();
        final container = ProviderContainer();

        final testProvider = Provider((ref) {
          return VersionCheckService(
            supabase: mockSupabase,
            database: database,
            report: report,
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

    // develop-2026-10 ticket 41 (32-007): an offline cold start is weather.
    // The real postgrest builder runs; only the wire is replaced, by what
    // dart:io throws offline, or by an app_config row the parser refuses.
    group('when app_config cannot be read', () {
      setUp(() {
        LaunchTrail.debugReset();
        ExpectedFailureCounts.debugReset();
        SharedPreferences.setMockInitialValues({
          'cached_min_app_version': '1.0.0',
          'cached_remote_schema_version': 3,
          'cached_min_supported_schema_version': 3,
          'version_check_cache_timestamp':
              DateTime.now().millisecondsSinceEpoch,
        });
      });
      tearDown(ExpectedFailureCounts.debugReset);

      Future<(VersionCheckResult, RecordingReport)> check(
        Future<http.Response> Function(http.Request) wire,
      ) async {
        final supabase = SupabaseClient(
          'http://app-config.test',
          'anon-key',
          httpClient: MockClient(wire),
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        final report = RecordingReport();
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final service = container.read(
          Provider(
            (ref) => VersionCheckService(
              supabase: supabase,
              database: FakeAppDatabase(),
              report: report,
              backupService: MockDirtyRecordBackupService(),
              ref: ref,
            ),
          ),
        );
        return (await service.checkVersion(), report);
      }

      test('offline: the cached result, a startup.weather breadcrumb, a '
          'LaunchTrail line, a held count, and no fault', () async {
        final (result, report) = await check(
          (_) async => throw const SocketException(
            "Failed host lookup: 'vlmtsdzpnjnavdgytcmi.supabase.co'",
          ),
        );

        expect(result, isA<VersionCheckOk>());
        expect(report.faults, isEmpty);
        expect(report.degradeds, isEmpty);
        final crumbs = report.calls.where(
          (c) => c.severity == 'breadcrumb' && c.area == 'startup.weather',
        );
        expect(crumbs, hasLength(1));
        expect(crumbs.single.data?['expected_failure'], 'offline');
        expect(
          LaunchTrail.text,
          contains('version check offline: cached result'),
        );
        expect(ExpectedFailureCounts.pending, [
          (area: 'startup', reason: 'offline'),
        ]);
      });

      test('a schema error in app_config still faults', () async {
        final (result, report) = await check(
          (request) async => http.Response(
            jsonEncode([
              {'key': 'min_app_version', 'value': '1.0.0'},
              {'key': 'latest_schema_version', 'value': 'four'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        );

        expect(result, isA<VersionCheckOk>(), reason: 'still the cache');
        expect(report.faults, hasLength(1));
        expect(report.faults.single.area, 'startup');
        expect(report.faults.single.error, isA<FormatException>());
        expect(LaunchTrail.text, isNot(contains('version check')));
        expect(ExpectedFailureCounts.pending, isEmpty);
      });
    });

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
