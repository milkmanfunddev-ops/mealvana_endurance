import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/user_foods/data/user_foods_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    test('repositoryKey should return "user_foods"', () {
      final mockSupabase = MockSupabaseClient();
      final repository = UserFoodsRepository(
        database: database,
        supabase: mockSupabase,
        sentry: mockSentry,
      );

      expect(repository.repositoryKey, 'user_foods');
    });

    test('dependencies should return ["users"]', () {
      final mockSupabase = MockSupabaseClient();
      final repository = UserFoodsRepository(
        database: database,
        supabase: mockSupabase,
        sentry: mockSentry,
      );

      expect(repository.dependencies, ['users']);
    });

    test('isStale should return true when never synced', () async {
      final mockSupabase = MockSupabaseClient();
      final repository = UserFoodsRepository(
        database: database,
        supabase: mockSupabase,
        sentry: mockSentry,
      );

      final isStale = await repository.isStale();
      expect(isStale, true);
    });

    test('isStale should return false when synced recently', () async {
      final mockSupabase = MockSupabaseClient();
      final repository = UserFoodsRepository(
        database: database,
        supabase: mockSupabase,
        sentry: mockSentry,
      );

      await repository.setLastSyncTime(DateTime.now());

      final isStale = await repository.isStale();
      expect(isStale, false);
    });

    test('isStale should return true after 24 hours', () async {
      final mockSupabase = MockSupabaseClient();
      final repository = UserFoodsRepository(
        database: database,
        supabase: mockSupabase,
        sentry: mockSentry,
      );

      final oldTime = DateTime.now().subtract(const Duration(hours: 25));
      await repository.setLastSyncTime(oldTime);

      final isStale = await repository.isStale();
      expect(isStale, true);
    });

    test('getLastSyncTime should persist and retrieve timestamp', () async {
      final mockSupabase = MockSupabaseClient();
      final repository = UserFoodsRepository(
        database: database,
        supabase: mockSupabase,
        sentry: mockSentry,
      );

      final testTime = DateTime(2024, 1, 15, 12, 30);
      await repository.setLastSyncTime(testTime);

      final retrieved = await repository.getLastSyncTime();
      expect(retrieved, isA<DateTime>());
      expect(retrieved?.year, testTime.year);
      expect(retrieved?.month, testTime.month);
      expect(retrieved?.day, testTime.day);
      expect(retrieved?.hour, testTime.hour);
      expect(retrieved?.minute, testTime.minute);
    });

    test('getLastSyncTime should return null when never synced', () async {
      final mockSupabase = MockSupabaseClient();
      final repository = UserFoodsRepository(
        database: database,
        supabase: mockSupabase,
        sentry: mockSentry,
      );

      final retrieved = await repository.getLastSyncTime();
      expect(retrieved, isNull);
    });
  });

  group('UserFoodsRepository - Basic Functionality', () {
    test('uploadDirtyRecords should return nothingToUpload when no dirty records',
        () async {
      final mockSupabase = MockSupabaseClient();
      final repository = UserFoodsRepository(
        database: database,
        supabase: mockSupabase,
        sentry: mockSentry,
      );

      final result = await repository.uploadDirtyRecords(testUserId);

      expect(result.success, true);
      expect(result.count, 0);
    });
  });
}
