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

/// Test double for AppDatabase
class FakeAppDatabase extends Fake implements AppDatabase {
  @override
  int get schemaVersion => 3;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VersionCheckService', () {
    setUp(() async {
      // Set up PackageInfo mock
      PackageInfo.setMockInitialValues(
        appName: 'Mealvana',
        packageName: 'com.mealvana.endurance',
        version: '1.12.1',
        buildNumber: '64',
        buildSignature: '',
      );

      // Clear SharedPreferences
      SharedPreferences.setMockInitialValues({});
    });

    test('returns ok when versions match', () async {
      // Arrange
      final mockSupabase = MockSupabaseClient();
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockFilterBuilder = MockPostgrestFilterBuilder();
      final database = FakeAppDatabase();

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

      final service = VersionCheckService(
        supabase: mockSupabase,
        database: database,
      );

      // Act
      final result = await service.checkVersion();

      // Assert
      expect(result.isOk, true);
    });

    test('returns updateRequired when app version too low', () async {
      // Arrange
      final mockSupabase = MockSupabaseClient();
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockFilterBuilder = MockPostgrestFilterBuilder();
      final database = FakeAppDatabase();

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

      final service = VersionCheckService(
        supabase: mockSupabase,
        database: database,
      );

      // Act
      final result = await service.checkVersion();

      // Assert
      expect(result.isUpdateRequired, true);
      final updateResult = result as VersionCheckUpdateRequired;
      expect(updateResult.currentVersion, '1.12.1');
      expect(updateResult.requiredVersion, '2.0.0');
    });

    test('returns resyncRequired when schema mismatch', () async {
      // Arrange
      final mockSupabase = MockSupabaseClient();
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockFilterBuilder = MockPostgrestFilterBuilder();
      final database = FakeAppDatabase();

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

      final service = VersionCheckService(
        supabase: mockSupabase,
        database: database,
      );

      // Act
      final result = await service.checkVersion();

      // Assert
      expect(result.isResyncRequired, true);
      final resyncResult = result as VersionCheckResyncRequired;
      expect(resyncResult.localSchemaVersion, 3);
      expect(resyncResult.remoteSchemaVersion, 4);
    });

    test('caches result on success', () async {
      // Arrange
      final mockSupabase = MockSupabaseClient();
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockFilterBuilder = MockPostgrestFilterBuilder();
      final database = FakeAppDatabase();

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

      final service = VersionCheckService(
        supabase: mockSupabase,
        database: database,
      );

      // Act
      await service.checkVersion();

      // Assert
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cached_min_app_version'), '1.12.0');
      expect(prefs.getInt('cached_remote_schema_version'), 3);
      expect(prefs.getInt('version_check_cache_timestamp'), isNotNull);
    });

    test('uses cached result on network failure', () async {
      // Arrange
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_min_app_version', '1.12.0');
      await prefs.setInt('cached_remote_schema_version', 3);
      await prefs.setInt(
        'version_check_cache_timestamp',
        DateTime.now().millisecondsSinceEpoch,
      );

      final mockSupabase = MockSupabaseClient();
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final database = FakeAppDatabase();

      when(() => mockSupabase.from('app_config'))
          .thenReturn(mockQueryBuilder);
      when(() => mockQueryBuilder.select('key, value'))
          .thenThrow(Exception('Network error'));

      final service = VersionCheckService(
        supabase: mockSupabase,
        database: database,
      );

      // Act
      final result = await service.checkVersion();

      // Assert
      expect(result.isOk, true);
    });

    test('returns ok on network failure with no cache', () async {
      // Arrange
      final mockSupabase = MockSupabaseClient();
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final database = FakeAppDatabase();

      when(() => mockSupabase.from('app_config'))
          .thenReturn(mockQueryBuilder);
      when(() => mockQueryBuilder.select('key, value'))
          .thenThrow(Exception('Network error'));

      final service = VersionCheckService(
        supabase: mockSupabase,
        database: database,
      );

      // Act
      final result = await service.checkVersion();

      // Assert
      expect(result.isOk, true);
    });

    test('clearCache removes all cached values', () async {
      // Arrange
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_min_app_version', '1.12.0');
      await prefs.setInt('cached_remote_schema_version', 3);
      await prefs.setInt(
        'version_check_cache_timestamp',
        DateTime.now().millisecondsSinceEpoch,
      );

      final mockSupabase = MockSupabaseClient();
      final database = FakeAppDatabase();

      final service = VersionCheckService(
        supabase: mockSupabase,
        database: database,
      );

      // Act
      await service.clearCache();

      // Assert
      expect(prefs.getString('cached_min_app_version'), isNull);
      expect(prefs.getInt('cached_remote_schema_version'), isNull);
      expect(prefs.getInt('version_check_cache_timestamp'), isNull);
    });
  });
}
