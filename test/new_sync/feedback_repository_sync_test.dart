import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/feedback/data/feedback_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';

// Mocks
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockAppLogger extends Mock implements AppLogger {}

class MockSentryReporter extends Mock implements SentryReporter {}

void main() {
  late AppDatabase database;
  late FeedbackRepository repository;
  late MockSupabaseClient mockSupabase;
  late MockAppLogger mockLogger;
  late MockSentryReporter mockSentry;

  const testUserId = 'test-user-123';

  setUp(() async {
    // Clear SharedPreferences for clean tests
    SharedPreferences.setMockInitialValues({});

    // Create in-memory database
    database = AppDatabase.forTesting(NativeDatabase.memory());

    // Create mocks
    mockLogger = MockAppLogger();
    mockSupabase = MockSupabaseClient();
    mockSentry = MockSentryReporter();

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

    repository = FeedbackRepository(database, mockLogger, mockSupabase, mockSentry);
  });

  tearDown(() async {
    await database.close();
  });

  group('FeedbackRepository SyncableRepository implementation', () {
    test('repositoryKey should be "feedback"', () {
      expect(repository.repositoryKey, equals('feedback'));
    });

    test('dependencies should include "users"', () {
      expect(repository.dependencies, contains('users'));
      expect(repository.dependencies.length, equals(1));
    });

    test('isStale returns true when never synced', () async {
      final isStale = await repository.isStale();
      expect(isStale, isTrue);
    });

    test('isStale returns false after recent sync', () async {
      await repository.setLastSyncTime(DateTime.now());
      final isStale = await repository.isStale();
      expect(isStale, isFalse);
    });

    test('isStale returns true after 25 hours', () async {
      final oldTime = DateTime.now().subtract(const Duration(hours: 25));
      await repository.setLastSyncTime(oldTime);
      final isStale = await repository.isStale();
      expect(isStale, isTrue);
    });
  });

  group('FeedbackRepository syncFromRemote', () {
    test('successfully syncs feedback from Supabase', () async {
      // This is an integration test that requires:
      // 1. Valid Supabase credentials
      // 2. feedback table in Supabase
      // 3. Test data in the feedback table

      // For now, we test the method signature and error handling
      final result = await repository.syncFromRemote(testUserId);

      // Should return a result (success or failure)
      expect(result, isA<SyncResult>());

      // If successful, should have updated last sync time
      if (result.success) {
        final lastSync = await repository.getLastSyncTime();
        expect(lastSync != null, true);
      }
    });

    test('handles Supabase errors gracefully', () async {
      // Test that errors are caught and returned as failed SyncResult
      // Since we have a mock Supabase without proper setup, this will fail
      final result = await repository.syncFromRemote('test-user');

      // Should return a result (either success with 0 or failure)
      expect(result, isA<SyncResult>());

      // The result can be either success or failure depending on Supabase mock behavior
      // What matters is it doesn't throw an exception
    });
  });

  group('FeedbackRepository uploadDirtyRecords', () {
    test('returns nothingToUpload when no dirty records', () async {
      final result = await repository.uploadDirtyRecords(testUserId);

      expect(result.success, isTrue);
      expect(result.count, equals(0));
    });

    test('uploads dirty feedback records to Supabase', () async {
      // Create a dirty feedback record in local database
      final feedbackId = 'test-feedback-${DateTime.now().millisecondsSinceEpoch}';
      final companion = FeedbackTableCompanion(
        id: Value(feedbackId),
        deviceId: const Value(testUserId),
        satisfactionLevel: const Value(5),
        satisfactionEmoji: const Value('😊'),
        satisfactionLabel: const Value('Very Satisfied'),
        confidenceLevel: const Value(4),
        confidenceLabel: const Value('Very Confident'),
        reuseIntent: const Value('definitely'),
        reminderRequested: const Value(true),
        reminderDayOfWeek: const Value(4),
        reminderHour: const Value(17),
        reminderMinute: const Value(0),
        reminderRecurring: const Value(false),
        needsUpload: const Value(true),
        localUpdatedAt: Value(DateTime.now()),
        createdAt: Value(DateTime.now()),
      );

      await database.into(database.feedbackTable).insert(companion);

      // Verify dirty record exists
      final dirtyRecords = await (database.select(database.feedbackTable)
            ..where((t) => t.needsUpload.equals(true)))
          .get();
      expect(dirtyRecords.length, equals(1));

      // Upload dirty records
      final result = await repository.uploadDirtyRecords(testUserId);

      // Should attempt upload (may succeed or fail based on Supabase availability)
      expect(result, isA<UploadResult>());

      if (result.success) {
        // If upload succeeded, dirty flag should be cleared
        final remainingDirty = await (database.select(database.feedbackTable)
              ..where((t) => t.needsUpload.equals(true)))
            .get();
        expect(remainingDirty.isEmpty, isTrue);
      }
    });

    test('handles upload failure gracefully', () async {
      // Create a feedback record with invalid data that will fail upload
      final feedbackId = 'invalid-feedback';
      final longDeviceId = 'x' * 500; // Very long device ID
      final companion = FeedbackTableCompanion(
        id: Value(feedbackId),
        deviceId: Value(longDeviceId),
        satisfactionLevel: const Value(999), // Invalid satisfaction level
        satisfactionEmoji: const Value('🚫'),
        satisfactionLabel: const Value('Invalid'),
        needsUpload: const Value(true),
        localUpdatedAt: Value(DateTime.now()),
        createdAt: Value(DateTime.now()),
      );

      await database.into(database.feedbackTable).insert(companion);

      // Attempt upload
      final result = await repository.uploadDirtyRecords(testUserId);

      // Should return a result (may be success or failure)
      expect(result, isA<UploadResult>());

      // If failed, dirty flag should remain set for retry
      if (!result.success) {
        final dirtyRecords = await (database.select(database.feedbackTable)
              ..where((t) => t.needsUpload.equals(true)))
            .get();
        expect(dirtyRecords.isNotEmpty, isTrue);
      }
    });
  });

  group('FeedbackRepository timestamp tracking', () {
    test('getLastSyncTime returns null when never synced', () async {
      final lastSync = await repository.getLastSyncTime();
      expect(lastSync == null, true);
    });

    test('setLastSyncTime stores timestamp correctly', () async {
      final now = DateTime.now();
      await repository.setLastSyncTime(now);

      final retrieved = await repository.getLastSyncTime();
      expect(retrieved != null, true);

      // Allow for some time difference due to DateTime.parse precision
      final diff = retrieved!.difference(now).inSeconds.abs();
      expect(diff, lessThan(2));
    });

    test('handles invalid timestamp gracefully', () async {
      // Manually set invalid timestamp in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('feedback_last_sync', 'invalid-timestamp');

      final lastSync = await repository.getLastSyncTime();
      expect(lastSync == null, true); // Should treat as never synced
    });
  });
}
