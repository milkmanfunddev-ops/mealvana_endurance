import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mealvana_endurance/shared/services/version_check_service.dart';
import 'package:mealvana_endurance/shared/models/version_check_result.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Mock classes
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}

class MockAppDatabase extends Mock implements AppDatabase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VersionCheckService', () {
    late MockSupabaseClient mockSupabase;
    late MockAppDatabase mockDatabase;
    late VersionCheckService service;

    setUp(() async {
      mockSupabase = MockSupabaseClient();
      mockDatabase = MockAppDatabase();

      // Mock database schema version
      when(() => mockDatabase.schemaVersion).thenReturn(3);

      // Set up PackageInfo mock with current version
      PackageInfo.setMockInitialValues(
        appName: 'Mealvana',
        packageName: 'com.mealvana.endurance',
        version: '1.12.1',
        buildNumber: '64',
        buildSignature: '',
      );

      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});

      service = VersionCheckService(
        supabase: mockSupabase,
        database: mockDatabase,
      );
    });

    tearDown(() async {
      // Clear cache after each test
      await service.clearCache();
    });

    group('checkVersion', () {
      test('returns ok when versions match', () async {
        // Arrange: Set up Supabase mock to return matching versions
        final mockQueryBuilder = MockSupabaseQueryBuilder();
        final mockFilterBuilder = MockPostgrestFilterBuilder();

        when(() => mockSupabase.from('app_config'))
            .thenReturn(mockQueryBuilder);
        when(() => mockQueryBuilder.select('key, value'))
            .thenReturn(mockFilterBuilder);
        when(() => mockFilterBuilder.inFilter('key', any()))
            .thenReturn(mockFilterBuilder);

        // Mock response with matching versions
        when(() => mockFilterBuilder.timeout(any())).thenAnswer(
          (_) async => [
            {'key': 'min_app_version', 'value': '1.12.0'},
            {'key': 'current_schema_version', 'value': '3'},
          ],
        );

        // Act
        final result = await service.checkVersion();

        // Assert
        expect(result.isOk, true);
        expect(result, const VersionCheckResult.ok());
      });

      test('returns updateRequired when app version too low', () async {
        // Arrange: Mock Supabase response with higher min version
        final mockQueryBuilder = MockSupabaseQueryBuilder();
        final mockFilterBuilder = MockPostgrestFilterBuilder();

        when(() => mockSupabase.from('app_config'))
            .thenReturn(mockQueryBuilder);
        when(() => mockQueryBuilder.select('key, value'))
            .thenReturn(mockFilterBuilder);
        when(() => mockFilterBuilder.inFilter('key', any()))
            .thenReturn(mockFilterBuilder);

        when(() => mockFilterBuilder.timeout(any())).thenAnswer(
          (_) async => [
            {'key': 'min_app_version', 'value': '2.0.0'},
            {'key': 'current_schema_version', 'value': '3'},
          ],
        );

        // Act
        final result = await service.checkVersion();

        // Assert
        expect(result.isUpdateRequired, true);
        expect(result, isA<VersionCheckUpdateRequired>());

        final updateResult = result as VersionCheckUpdateRequired;
        expect(updateResult.currentVersion, '1.12.1');
        expect(updateResult.requiredVersion, '2.0.0');
      });

      test('returns resyncRequired when schema mismatch', () async {
        // Arrange: Mock Supabase response with different schema version
        final mockQueryBuilder = MockSupabaseQueryBuilder();
        final mockFilterBuilder = MockPostgrestFilterBuilder();

        when(() => mockSupabase.from('app_config'))
            .thenReturn(mockQueryBuilder);
        when(() => mockQueryBuilder.select('key, value'))
            .thenReturn(mockFilterBuilder);
        when(() => mockFilterBuilder.inFilter('key', any()))
            .thenReturn(mockFilterBuilder);

        when(() => mockFilterBuilder.timeout(any())).thenAnswer(
          (_) async => [
            {'key': 'min_app_version', 'value': '1.12.0'},
            {'key': 'current_schema_version', 'value': '4'},
          ],
        );

        // Act
        final result = await service.checkVersion();

        // Assert
        expect(result.isResyncRequired, true);
        expect(result, isA<VersionCheckResyncRequired>());

        final resyncResult = result as VersionCheckResyncRequired;
        expect(resyncResult.localSchemaVersion, 3);
        expect(resyncResult.remoteSchemaVersion, 4);
      });

      test('prioritizes updateRequired over resyncRequired', () async {
        // Arrange: Mock response with BOTH version issues
        final mockQueryBuilder = MockSupabaseQueryBuilder();
        final mockFilterBuilder = MockPostgrestFilterBuilder();

        when(() => mockSupabase.from('app_config'))
            .thenReturn(mockQueryBuilder);
        when(() => mockQueryBuilder.select('key, value'))
            .thenReturn(mockFilterBuilder);
        when(() => mockFilterBuilder.inFilter('key', any()))
            .thenReturn(mockFilterBuilder);

        when(() => mockFilterBuilder.timeout(any())).thenAnswer(
          (_) async => [
            {'key': 'min_app_version', 'value': '2.0.0'},
            {'key': 'current_schema_version', 'value': '4'},
          ],
        );

        // Act
        final result = await service.checkVersion();

        // Assert: Should return updateRequired first
        expect(result.isUpdateRequired, true);
      });

      test('caches result on success', () async {
        // Arrange
        final mockQueryBuilder = MockSupabaseQueryBuilder();
        final mockFilterBuilder = MockPostgrestFilterBuilder();

        when(() => mockSupabase.from('app_config'))
            .thenReturn(mockQueryBuilder);
        when(() => mockQueryBuilder.select('key, value'))
            .thenReturn(mockFilterBuilder);
        when(() => mockFilterBuilder.inFilter('key', any()))
            .thenReturn(mockFilterBuilder);

        when(() => mockFilterBuilder.timeout(any())).thenAnswer(
          (_) async => [
            {'key': 'min_app_version', 'value': '1.12.0'},
            {'key': 'current_schema_version', 'value': '3'},
          ],
        );

        // Act
        await service.checkVersion();

        // Assert: Verify cache was written
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('cached_min_app_version'), '1.12.0');
        expect(prefs.getInt('cached_remote_schema_version'), 3);
        expect(prefs.getInt('version_check_cache_timestamp'), isNotNull);
      });

      test('uses cached result on network failure', () async {
        // Arrange: Populate cache with known values
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_min_app_version', '1.12.0');
        await prefs.setInt('cached_remote_schema_version', 3);
        await prefs.setInt(
          'version_check_cache_timestamp',
          DateTime.now().millisecondsSinceEpoch,
        );

        // Mock network failure
        final mockQueryBuilder = MockSupabaseQueryBuilder();
        when(() => mockSupabase.from('app_config'))
            .thenReturn(mockQueryBuilder);
        when(() => mockQueryBuilder.select('key, value'))
            .thenThrow(Exception('Network error'));

        // Act
        final result = await service.checkVersion();

        // Assert: Should use cached result
        expect(result.isOk, true);
      });

      test('returns ok on network failure with no cache', () async {
        // Arrange: No cache, network fails
        final mockQueryBuilder = MockSupabaseQueryBuilder();
        when(() => mockSupabase.from('app_config'))
            .thenReturn(mockQueryBuilder);
        when(() => mockQueryBuilder.select('key, value'))
            .thenThrow(Exception('Network error'));

        // Act
        final result = await service.checkVersion();

        // Assert: Should default to ok to allow app startup
        expect(result.isOk, true);
      });

      test('returns ok on network failure with expired cache', () async {
        // Arrange: Populate cache with old timestamp (25 hours ago)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_min_app_version', '1.12.0');
        await prefs.setInt('cached_remote_schema_version', 3);
        final expiredTimestamp = DateTime.now()
            .subtract(const Duration(hours: 25))
            .millisecondsSinceEpoch;
        await prefs.setInt('version_check_cache_timestamp', expiredTimestamp);

        // Mock network failure
        final mockQueryBuilder = MockSupabaseQueryBuilder();
        when(() => mockSupabase.from('app_config'))
            .thenReturn(mockQueryBuilder);
        when(() => mockQueryBuilder.select('key, value'))
            .thenThrow(Exception('Network error'));

        // Act
        final result = await service.checkVersion();

        // Assert: Should return ok due to expired cache
        expect(result.isOk, true);
      });

      test('handles timeout correctly', () async {
        // Arrange: Mock timeout
        final mockQueryBuilder = MockSupabaseQueryBuilder();
        final mockFilterBuilder = MockPostgrestFilterBuilder();

        when(() => mockSupabase.from('app_config'))
            .thenReturn(mockQueryBuilder);
        when(() => mockQueryBuilder.select('key, value'))
            .thenReturn(mockFilterBuilder);
        when(() => mockFilterBuilder.inFilter('key', any()))
            .thenReturn(mockFilterBuilder);

        when(() => mockFilterBuilder.timeout(any()))
            .thenThrow(TimeoutException('Query timeout'));

        // Act
        final result = await service.checkVersion();

        // Assert: Should gracefully handle timeout
        expect(result.isOk, true);
      });

      test('handles missing config keys', () async {
        // Arrange: Mock response missing schema version
        final mockQueryBuilder = MockSupabaseQueryBuilder();
        final mockFilterBuilder = MockPostgrestFilterBuilder();

        when(() => mockSupabase.from('app_config'))
            .thenReturn(mockQueryBuilder);
        when(() => mockQueryBuilder.select('key, value'))
            .thenReturn(mockFilterBuilder);
        when(() => mockFilterBuilder.inFilter('key', any()))
            .thenReturn(mockFilterBuilder);

        when(() => mockFilterBuilder.timeout(any())).thenAnswer(
          (_) async => [
            {'key': 'min_app_version', 'value': '1.12.0'},
            // Missing current_schema_version
          ],
        );

        // Act
        final result = await service.checkVersion();

        // Assert: Should handle gracefully
        expect(result.isOk, true);
      });

      test('correctly parses semantic versions', () async {
        // Arrange: Test various version formats
        final mockQueryBuilder = MockSupabaseQueryBuilder();
        final mockFilterBuilder = MockPostgrestFilterBuilder();

        when(() => mockSupabase.from('app_config'))
            .thenReturn(mockQueryBuilder);
        when(() => mockQueryBuilder.select('key, value'))
            .thenReturn(mockFilterBuilder);
        when(() => mockFilterBuilder.inFilter('key', any()))
            .thenReturn(mockFilterBuilder);

        // Test: 1.12.1 >= 1.12.0 (should be ok)
        when(() => mockFilterBuilder.timeout(any())).thenAnswer(
          (_) async => [
            {'key': 'min_app_version', 'value': '1.12.0'},
            {'key': 'current_schema_version', 'value': '3'},
          ],
        );

        final result = await service.checkVersion();
        expect(result.isOk, true);
      });

      test('returns cached updateRequired on network failure', () async {
        // Arrange: Cache shows update required
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_min_app_version', '2.0.0');
        await prefs.setInt('cached_remote_schema_version', 3);
        await prefs.setInt(
          'version_check_cache_timestamp',
          DateTime.now().millisecondsSinceEpoch,
        );

        // Mock network failure
        final mockQueryBuilder = MockSupabaseQueryBuilder();
        when(() => mockSupabase.from('app_config'))
            .thenReturn(mockQueryBuilder);
        when(() => mockQueryBuilder.select('key, value'))
            .thenThrow(Exception('Network error'));

        // Act
        final result = await service.checkVersion();

        // Assert: Should return cached updateRequired
        expect(result.isUpdateRequired, true);
        final updateResult = result as VersionCheckUpdateRequired;
        expect(updateResult.requiredVersion, '2.0.0');
      });

      test('returns cached resyncRequired on network failure', () async {
        // Arrange: Cache shows resync required
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_min_app_version', '1.12.0');
        await prefs.setInt('cached_remote_schema_version', 4);
        await prefs.setInt(
          'version_check_cache_timestamp',
          DateTime.now().millisecondsSinceEpoch,
        );

        // Mock network failure
        final mockQueryBuilder = MockSupabaseQueryBuilder();
        when(() => mockSupabase.from('app_config'))
            .thenReturn(mockQueryBuilder);
        when(() => mockQueryBuilder.select('key, value'))
            .thenThrow(Exception('Network error'));

        // Act
        final result = await service.checkVersion();

        // Assert: Should return cached resyncRequired
        expect(result.isResyncRequired, true);
        final resyncResult = result as VersionCheckResyncRequired;
        expect(resyncResult.remoteSchemaVersion, 4);
      });
    });

    group('clearCache', () {
      test('removes all cached values', () async {
        // Arrange: Populate cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_min_app_version', '1.12.0');
        await prefs.setInt('cached_remote_schema_version', 3);
        await prefs.setInt(
          'version_check_cache_timestamp',
          DateTime.now().millisecondsSinceEpoch,
        );

        // Act
        await service.clearCache();

        // Assert: Cache should be empty
        expect(prefs.getString('cached_min_app_version'), isNull);
        expect(prefs.getInt('cached_remote_schema_version'), isNull);
        expect(prefs.getInt('version_check_cache_timestamp'), isNull);
      });
    });
  });
}
