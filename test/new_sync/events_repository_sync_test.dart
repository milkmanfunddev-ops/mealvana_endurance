import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/events/data/events_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_repository.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mocktail/mocktail.dart';

// Mocks
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockAppLogger extends Mock implements AppLogger {}

class MockSentryReporter extends Mock implements SentryReporter {}

class MockCarbLoadingRepository extends Mock implements CarbLoadingRepository {}

void main() {
  late AppDatabase database;
  late MockAppLogger mockLogger;
  late MockSentryReporter mockSentry;
  late MockCarbLoadingRepository mockCarbLoadingRepository;

  const testUserId = 'test-user-123';

  setUp(() async {
    // Initialize SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});

    // Create in-memory database
    database = AppDatabase.forTesting(NativeDatabase.memory());

    // Create mocks
    mockLogger = MockAppLogger();
    mockSentry = MockSentryReporter();
    mockCarbLoadingRepository = MockCarbLoadingRepository();

    // Set up logger to not throw on method calls
    when(() => mockLogger.info(any(),
            context: any(named: 'context'), data: any(named: 'data')))
        .thenReturn(null);
    when(() => mockLogger.debug(any(),
            context: any(named: 'context'), data: any(named: 'data')))
        .thenReturn(null);
    when(() => mockLogger.error(
          any(),
          context: any(named: 'context'),
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
          data: any(named: 'data'),
        )).thenReturn(null);
    when(() => mockLogger.warning(
          any(),
          context: any(named: 'context'),
          error: any(named: 'error'),
          data: any(named: 'data'),
        )).thenReturn(null);
  });

  tearDown(() async {
    await database.close();
  });

  group('SyncableRepository Interface', () {
    test('repositoryKey should return "events"', () {
      final mockSupabase = MockSupabaseClient();
      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        logger: mockLogger,
        carbLoadingRepository: mockCarbLoadingRepository,
        sentry: mockSentry,
      );

      expect(repository.repositoryKey, 'events');
    });

    test('dependencies should return ["users"]', () {
      final mockSupabase = MockSupabaseClient();
      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        logger: mockLogger,
        carbLoadingRepository: mockCarbLoadingRepository,
        sentry: mockSentry,
      );

      expect(repository.dependencies, ['users']);
    });

    test('isStale should return true when never synced', () async {
      final mockSupabase = MockSupabaseClient();
      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        logger: mockLogger,
        carbLoadingRepository: mockCarbLoadingRepository,
        sentry: mockSentry,
      );

      final isStale = await repository.isStale();
      expect(isStale, true);
    });

    test('isStale should return false when synced recently', () async {
      final mockSupabase = MockSupabaseClient();
      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        logger: mockLogger,
        carbLoadingRepository: mockCarbLoadingRepository,
        sentry: mockSentry,
      );

      await repository.setLastSyncTime(DateTime.now());
      final isStale = await repository.isStale();
      expect(isStale, false);
    });

    test('isStale should return true when synced more than 24 hours ago',
        () async {
      final mockSupabase = MockSupabaseClient();
      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        logger: mockLogger,
        carbLoadingRepository: mockCarbLoadingRepository,
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
      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        logger: mockLogger,
        carbLoadingRepository: mockCarbLoadingRepository,
        sentry: mockSentry,
      );

      final timestamp = await repository.getLastSyncTime();
      expect(timestamp, null);
    });

    test('setLastSyncTime and getLastSyncTime should work correctly',
        () async {
      final mockSupabase = MockSupabaseClient();
      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        logger: mockLogger,
        carbLoadingRepository: mockCarbLoadingRepository,
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
    test('should return nothingToUpload when no dirty records exist',
        () async {
      final mockSupabase = MockSupabaseClient();
      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        logger: mockLogger,
        carbLoadingRepository: mockCarbLoadingRepository,
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
  // - syncFromRemote(): Fetches events from Supabase and saves to Drift
  // - uploadDirtyRecords(): Uploads dirty events to Supabase and clears flags
  // - Error handling for network failures
  //
  // Integration tests should cover:
  // - Full sync cycle (upload dirty → sync fresh data)
  // - Network error handling and retry logic
  // - Data consistency between Drift and Supabase
}
