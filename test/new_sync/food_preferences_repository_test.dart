import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/food_preferences/data/food_preferences_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mocktail/mocktail.dart';

// Mocks
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSentryReporter extends Mock implements SentryReporter {}

void main() {
  late AppDatabase database;
  late MockSentryReporter mockSentry;

  const testUserId = 'test-user-123';

  setUp(() async {
    // Initialize SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});

    // Create in-memory database
    database = AppDatabase.forTesting(NativeDatabase.memory());

    // Create mocks
    mockSentry = MockSentryReporter();

    // Set up Sentry to not throw on method calls
    when(() => mockSentry.addBreadcrumb(
          message: any(named: 'message'),
          category: any(named: 'category'),
          data: any(named: 'data'),
        )).thenReturn(null);
    when(() => mockSentry.reportDatabaseError(
          any(),
          operation: any(named: 'operation'),
          table: any(named: 'table'),
          stackTrace: any(named: 'stackTrace'),
        )).thenAnswer((_) async {});
    when(() => mockSentry.reportNetworkError(
          any(),
          url: any(named: 'url'),
          method: any(named: 'method'),
          stackTrace: any(named: 'stackTrace'),
        )).thenAnswer((_) async {});
  });

  tearDown(() async {
    await database.close();
  });

  group('SyncableRepository Interface', () {
    test('repositoryKey should return "food_preferences"', () {
      final mockSupabase = MockSupabaseClient();
      final repository = FoodPreferencesRepository(
        supabase: mockSupabase,
        database: database,
        sentry: mockSentry,
      );

      expect(repository.repositoryKey, 'food_preferences');
    });

    test('dependencies should return ["users", "foods"]', () {
      final mockSupabase = MockSupabaseClient();
      final repository = FoodPreferencesRepository(
        supabase: mockSupabase,
        database: database,
        sentry: mockSentry,
      );

      expect(repository.dependencies, ['users', 'foods']);
    });

    test('isStale should return true when never synced', () async {
      final mockSupabase = MockSupabaseClient();
      final repository = FoodPreferencesRepository(
        supabase: mockSupabase,
        database: database,
        sentry: mockSentry,
      );

      final isStale = await repository.isStale();
      expect(isStale, true);
    });

    test('isStale should return false when synced recently', () async {
      final mockSupabase = MockSupabaseClient();
      final repository = FoodPreferencesRepository(
        supabase: mockSupabase,
        database: database,
        sentry: mockSentry,
      );

      await repository.setLastSyncTime(DateTime.now());
      final isStale = await repository.isStale();
      expect(isStale, false);
    });

    test('isStale should return true when synced more than 24 hours ago',
        () async {
      final mockSupabase = MockSupabaseClient();
      final repository = FoodPreferencesRepository(
        supabase: mockSupabase,
        database: database,
        sentry: mockSentry,
      );

      final oldSync = DateTime.now().subtract(const Duration(hours: 25));
      await repository.setLastSyncTime(oldSync);
      final isStale = await repository.isStale();
      expect(isStale, true);
    });
  });

  group('Timestamp Management', () {
    test('getLastSyncTime should return null when never synced', () async {
      final mockSupabase = MockSupabaseClient();
      final repository = FoodPreferencesRepository(
        supabase: mockSupabase,
        database: database,
        sentry: mockSentry,
      );

      final timestamp = await repository.getLastSyncTime();
      expect(timestamp, null);
    });

    test('setLastSyncTime and getLastSyncTime should work correctly',
        () async {
      final mockSupabase = MockSupabaseClient();
      final repository = FoodPreferencesRepository(
        supabase: mockSupabase,
        database: database,
        sentry: mockSentry,
      );

      final now = DateTime.now();
      await repository.setLastSyncTime(now);

      final retrieved = await repository.getLastSyncTime();
      expect(retrieved, isNotNull);
      expect(retrieved!.difference(now).inSeconds, lessThan(1));
    });
  });

  group('uploadDirtyRecords', () {
    test('should return nothingToUpload when no preferences exist', () async {
      final mockSupabase = MockSupabaseClient();
      final repository = FoodPreferencesRepository(
        supabase: mockSupabase,
        database: database,
        sentry: mockSentry,
      );

      // Act
      final result = await repository.uploadDirtyRecords(testUserId);

      // Assert
      expect(result.success, true);
      expect(result.count, 0);
    });
  });

  // NOTE: Tests for syncFromRemote() and uploadDirtyRecords() with actual Supabase
  // operations are skipped due to the complexity of mocking the Supabase fluent API.
  // These will be tested via integration tests with real Supabase instances.
  //
  // The following functionality is implemented but not unit tested:
  // - syncFromRemote(): Fetches food preferences from Supabase and saves to Drift
  // - uploadDirtyRecords(): Uploads all food preferences to Supabase
  // - Error handling for network failures
  //
  // Integration tests should cover:
  // - Full sync cycle (upload preferences → sync fresh data)
  // - Network error handling and retry logic
  // - Data consistency between Drift and Supabase
  // - Merge mode behavior when syncing from server
}
