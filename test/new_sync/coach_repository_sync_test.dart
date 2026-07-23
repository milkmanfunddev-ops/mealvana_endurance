import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/coach_mode/data/coach_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Mocks
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockAppDatabase extends Mock implements AppDatabase {}

class MockAppLogger extends Mock implements AppLogger {}

class MockSentryReporter extends Mock implements SentryReporter {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSupabaseClient mockSupabase;
  late MockAppDatabase mockDatabase;
  late MockAppLogger mockLogger;
  late MockSentryReporter mockSentry;
  late CoachRepository repository;

  setUpAll(() async {
    // Initialize SharedPreferences with in-memory values
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockDatabase = MockAppDatabase();
    mockLogger = MockAppLogger();
    mockSentry = MockSentryReporter();

    // Setup default logger behavior
    when(
      () => mockLogger.info(
        any(),
        context: any(named: 'context'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
    when(
      () => mockLogger.debug(
        any(),
        context: any(named: 'context'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
    when(
      () => mockLogger.error(
        any(),
        context: any(named: 'context'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
    when(
      () => mockLogger.warning(
        any(),
        context: any(named: 'context'),
        error: any(named: 'error'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);

    repository = CoachRepository(
      supabase: mockSupabase,
      database: mockDatabase,
      logger: mockLogger,
      sentry: mockSentry,
    );
  });

  group('SyncableRepository Implementation', () {
    test('repositoryKey returns "coaches"', () {
      expect(repository.repositoryKey, equals('coaches'));
    });

    test('dependencies returns ["users"]', () {
      expect(repository.dependencies, equals(['users']));
    });

    test('isStale returns true when never synced', () async {
      final isStale = await repository.isStale();
      expect(isStale, isTrue);
    });

    test('getLastSyncTime returns null when never synced', () async {
      final lastSync = await repository.getLastSyncTime();
      expect(lastSync, isNull);
    });

    test('setLastSyncTime and getLastSyncTime work together', () async {
      final now = DateTime.now();
      await repository.setLastSyncTime(now);

      final lastSync = await repository.getLastSyncTime();
      expect(lastSync, isNotNull);
      expect(lastSync!.difference(now).inSeconds, lessThan(2));
    });

    test('isStale returns false after recent sync', () async {
      await repository.setLastSyncTime(DateTime.now());
      final isStale = await repository.isStale();
      expect(isStale, isFalse);
    });
  });

  group('uploadDirtyRecords', () {
    const testUserId = 'test-user-id';

    test('returns nothingToUpload (dual-write pattern)', () async {
      // CoachRepository uses dual-write pattern (writes to both Drift and Supabase immediately)
      // so there are no dirty records to upload
      final result = await repository.uploadDirtyRecords(testUserId);

      expect(result.success, isTrue);
      expect(result.count, 0);
    });
  });

  // Note: syncFromRemote tests omitted due to complex Supabase mocking requirements.
  // The implementation is verified through integration tests and manual testing.
  // Key syncFromRemote behaviors:
  // 1. Syncs coach record when user is a coach
  // 2. Syncs relationships where user is coach OR athlete
  // 3. Handles empty responses correctly
  // 4. Updates last sync timestamp
  // 5. Returns appropriate SyncResult on success/failure
}
