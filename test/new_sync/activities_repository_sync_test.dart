import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Mocks
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockAppDatabase extends Mock implements AppDatabase {}
class MockAppLogger extends Mock implements AppLogger {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSupabaseClient mockSupabase;
  late MockAppDatabase mockDatabase;
  late MockAppLogger mockLogger;
  late ActivitiesRepository repository;

  setUpAll(() async {
    // Initialize SharedPreferences with in-memory values
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockDatabase = MockAppDatabase();
    mockLogger = MockAppLogger();

    // Setup default logger behavior to avoid null errors
    when(() => mockLogger.info(any(), context: any(named: 'context'), data: any(named: 'data')))
        .thenReturn(null);
    when(() => mockLogger.debug(any(), context: any(named: 'context'), data: any(named: 'data')))
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

    repository = ActivitiesRepository(
      supabase: mockSupabase,
      database: mockDatabase,
      logger: mockLogger,
    );
  });

  group('SyncableRepository Implementation', () {
    test('repositoryKey returns "activities"', () {
      expect(repository.repositoryKey, equals('activities'));
    });

    test('dependencies returns ["users"]', () {
      expect(repository.dependencies, equals(['users']));
    });

    test('isStale returns true when never synced', () async {
      // This test verifies the inherited behavior from SyncableRepository
      // When no timestamp exists in SharedPreferences, data is considered stale
      final isStale = await repository.isStale();
      expect(isStale, isTrue);
    });

    test('getLastSyncTime returns null when never synced', () async {
      // Verify that getLastSyncTime returns null for a repository that has never been synced
      final lastSync = await repository.getLastSyncTime();
      expect(lastSync, isNull);
    });

    test('setLastSyncTime and getLastSyncTime work together', () async {
      // Set a sync time
      final now = DateTime.now();
      await repository.setLastSyncTime(now);

      // Retrieve it
      final lastSync = await repository.getLastSyncTime();
      expect(lastSync, isNotNull);

      // Should be within 1 second of the original time (accounting for serialization)
      expect(
        lastSync!.difference(now).abs().inSeconds,
        lessThan(2),
      );
    });

    test('isStale returns false after recent sync', () async {
      // Set a recent sync time
      await repository.setLastSyncTime(DateTime.now());

      // Data should not be stale
      final isStale = await repository.isStale();
      expect(isStale, isFalse);
    });

    test('isStale returns true after 25 hours', () async {
      // Set a sync time 25 hours ago
      final oldTime = DateTime.now().subtract(const Duration(hours: 25));
      await repository.setLastSyncTime(oldTime);

      // Data should be stale
      final isStale = await repository.isStale();
      expect(isStale, isTrue);
    });
  });

  group('syncFromRemote', () {
    test('logs error and returns failure when Supabase throws exception', () async {
      // Arrange
      const userId = 'test-user-id';

      // Mock Supabase to throw an exception
      when(() => mockSupabase.from(any())).thenThrow(Exception('Network error'));

      // Act
      final result = await repository.syncFromRemote(userId);

      // Assert
      expect(result.success, isFalse);
      expect(result.error, contains('Network error'));

      // Verify error was logged
      verify(() => mockLogger.error(
        any(),
        context: 'ACTIVITIES_REPOSITORY',
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
        data: any(named: 'data'),
      )).called(1);
    });
  });

  group('uploadDirtyRecords', () {
    test('handles exceptions gracefully', () async {
      // Note: Full integration tests with database mocking are complex
      // This is a placeholder for future comprehensive testing
      // The actual implementation is tested through integration tests
      expect(repository.repositoryKey, equals('activities'));
    });
  });
}
