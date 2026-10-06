import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/user_foods/data/user_foods_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/fakes/recording_report.dart';

// Mocks
class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late AppDatabase database;
  late RecordingReport report;

  const testUserId = 'test-user-123';

  setUp(() async {
    // Initialize SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});

    // Create in-memory database
    database = AppDatabase.forTesting(NativeDatabase.memory());

    // Create mocks
    report = RecordingReport();

    // Set up Sentry to not throw on method calls
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
        report: report,
      );

      expect(repository.repositoryKey, 'user_foods');
    });

    test('dependencies should return ["users"]', () {
      final mockSupabase = MockSupabaseClient();
      final repository = UserFoodsRepository(
        database: database,
        supabase: mockSupabase,
        report: report,
      );

      expect(repository.dependencies, ['users']);
    });

    test('isStale should return true when never synced', () async {
      final mockSupabase = MockSupabaseClient();
      final repository = UserFoodsRepository(
        database: database,
        supabase: mockSupabase,
        report: report,
      );

      final isStale = await repository.isStale();
      expect(isStale, true);
    });

    test('isStale should return false when synced recently', () async {
      final mockSupabase = MockSupabaseClient();
      final repository = UserFoodsRepository(
        database: database,
        supabase: mockSupabase,
        report: report,
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
        report: report,
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
        report: report,
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
        report: report,
      );

      final retrieved = await repository.getLastSyncTime();
      expect(retrieved, isNull);
    });
  });

  group('UserFoodsRepository - Basic Functionality', () {
    test(
      'uploadDirtyRecords should return nothingToUpload when no dirty records',
      () async {
        final mockSupabase = MockSupabaseClient();
        final repository = UserFoodsRepository(
          database: database,
          supabase: mockSupabase,
          report: report,
        );

        final result = await repository.uploadDirtyRecords(testUserId);

        expect(result.success, true);
        expect(result.count, 0);
      },
    );
  });
}
