import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart'
    hide Activity;
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockAppLogger extends Mock implements AppLogger {}

class MockSentryReporter extends Mock implements SentryReporter {}

class MockActivityDeduplicationService extends Mock
    implements ActivityDeduplicationService {}

/// P3 (RULED 2026-09-30, Xuan): a provider import that carries a distance but
/// no duration gets a duration estimated from the athlete's usual pace, marked
/// `duration_source='estimated'`.
///
/// These tests run through the REAL repository write seams — not the engine in
/// isolation, which `usual_pace_test.dart` already covers — because the thing
/// that can break here is the wiring: which rows become evidence, which rows
/// get written, and which durations must never be touched.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late ActivitiesRepository repository;

  const userId = 'user-p3';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());

    final mockLogger = MockAppLogger();
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
      () => mockLogger.warning(
        any(),
        context: any(named: 'context'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
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

    final mockSentry = MockSentryReporter();
    when(
      () => mockSentry.reportNetworkError(
        any(),
        url: any(named: 'url'),
        method: any(named: 'method'),
        statusCode: any(named: 'statusCode'),
        timeout: any(named: 'timeout'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});

    repository = ActivitiesRepository(
      supabase: MockSupabaseClient(),
      database: database,
      logger: mockLogger,
      sentry: mockSentry,
      deduplicationService: MockActivityDeduplicationService(),
    );
  });

  tearDown(() async {
    await database.close();
  });

  final now = DateTime.now();

  Activity imported({
    required String providerWorkoutId,
    double? distanceMiles,
    int? durationMinutes,
    String? durationSource,
    ActivityStatus status = ActivityStatus.planned,
    ActivityType activityType = ActivityType.running,
    DateTime? scheduledDateTime,
  }) {
    return Activity(
      id: '',
      userId: userId,
      activityType: activityType,
      title: 'Imported workout',
      status: status,
      scheduledDateTime: scheduledDateTime ?? now.add(const Duration(days: 1)),
      distanceMiles: distanceMiles,
      durationMinutes: durationMinutes,
      durationSource: durationSource,
      syncedFromProvider: 'final_surge',
      providerWorkoutId: providerWorkoutId,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// A finished session, the only shape that is evidence about usual pace.
  /// [durationSource] is how a row we estimated ourselves is simulated.
  Future<void> seedCompleted({
    required String id,
    required double distanceMiles,
    required int durationMinutes,
    String? durationSource,
    int daysAgo = 7,
    ActivityType activityType = ActivityType.running,
  }) async {
    await repository.insertActivity(
      Activity(
        id: '',
        userId: userId,
        activityType: activityType,
        title: 'Completed $id',
        status: ActivityStatus.completed,
        scheduledDateTime: now.subtract(Duration(days: daysAgo)),
        distanceMiles: distanceMiles,
        durationMinutes: durationMinutes,
        durationSource: durationSource,
        completedAt: now.subtract(Duration(days: daysAgo)),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  group('distance-only provider import', () {
    test(
      'estimates from the ruled fallback when there is no history',
      () async {
        final saved = await repository.insertActivity(
          imported(providerWorkoutId: 'fs-1', distanceMiles: 10.0),
        );

        // Running fallback is 10:00/mile, so 10 miles is 100 minutes.
        expect(saved.durationMinutes, 100);
        expect(saved.durationSource, 'estimated');
        expect(saved.isDurationEstimated, isTrue);
      },
    );

    test('estimates from the athlete\'s own slowest-quartile pace', () async {
      // 7:00 intervals, 7:30 tempo, 8:00 steady, 10:30 long run.
      await seedCompleted(id: 'a', distanceMiles: 4.0, durationMinutes: 28);
      await seedCompleted(id: 'b', distanceMiles: 6.0, durationMinutes: 45);
      await seedCompleted(id: 'c', distanceMiles: 5.0, durationMinutes: 40);
      await seedCompleted(id: 'd', distanceMiles: 12.0, durationMinutes: 126);

      final saved = await repository.insertActivity(
        imported(providerWorkoutId: 'fs-2', distanceMiles: 10.0),
      );

      // Slowest quarter is the 10:30 long run, so a 10-miler clears the
      // 90-minute long threshold instead of landing under it at median pace.
      expect(saved.durationMinutes, 105);
      expect(saved.durationSource, 'estimated');
    });

    test('a duration we estimated ourselves is not evidence', () async {
      // Four completed rows whose ONLY duration is one we invented. If these
      // counted, estimates would feed the pace that produces estimates.
      for (final (i, miles) in [4.0, 6.0, 5.0, 12.0].indexed) {
        await seedCompleted(
          id: 'est$i',
          distanceMiles: miles,
          durationMinutes: (miles * 6).round(), // an implausible 6:00/mile
          durationSource: 'estimated',
        );
      }

      final saved = await repository.insertActivity(
        imported(providerWorkoutId: 'fs-3', distanceMiles: 10.0),
      );

      // Falls back rather than adopting the invented 6:00/mile.
      expect(saved.durationMinutes, 100);
    });

    test('history from another sport does not leak across', () async {
      await seedCompleted(
        id: 'bike-a',
        distanceMiles: 20.0,
        durationMinutes: 60,
        activityType: ActivityType.cycling,
      );
      await seedCompleted(
        id: 'bike-b',
        distanceMiles: 30.0,
        durationMinutes: 90,
        activityType: ActivityType.cycling,
      );
      await seedCompleted(
        id: 'bike-c',
        distanceMiles: 25.0,
        durationMinutes: 75,
        activityType: ActivityType.cycling,
      );

      final run = await repository.insertActivity(
        imported(providerWorkoutId: 'fs-4', distanceMiles: 10.0),
      );
      expect(run.durationMinutes, 100, reason: 'running fallback, not 3:00/mi');
    });

    test('sessions older than the 90-day window are not evidence', () async {
      await seedCompleted(
        id: 'old-a',
        distanceMiles: 10.0,
        durationMinutes: 150,
        daysAgo: 200,
      );
      await seedCompleted(
        id: 'old-b',
        distanceMiles: 8.0,
        durationMinutes: 120,
        daysAgo: 150,
      );
      await seedCompleted(
        id: 'old-c',
        distanceMiles: 6.0,
        durationMinutes: 90,
        daysAgo: 120,
      );

      final saved = await repository.insertActivity(
        imported(providerWorkoutId: 'fs-5', distanceMiles: 10.0),
      );
      expect(saved.durationMinutes, 100, reason: 'fallback, not 15:00/mile');
    });
  });

  group('durations we must never touch', () {
    test('a provider-supplied duration survives untouched', () async {
      final saved = await repository.insertActivity(
        imported(
          providerWorkoutId: 'fs-6',
          distanceMiles: 10.0,
          durationMinutes: 73,
        ),
      );

      expect(saved.durationMinutes, 73);
      expect(
        saved.durationSource,
        isNull,
        reason: 'null means authoritative — never tag what we did not estimate',
      );
    });

    test('an import with no distance is left alone', () async {
      final saved = await repository.insertActivity(
        imported(providerWorkoutId: 'fs-7'),
      );

      expect(saved.durationMinutes, isNull);
      expect(saved.durationSource, isNull);
    });

    test('a completed import is never given an invented duration', () async {
      final saved = await repository.insertActivity(
        imported(
          providerWorkoutId: 'fs-8',
          distanceMiles: 10.0,
          status: ActivityStatus.completed,
          scheduledDateTime: now.subtract(const Duration(days: 1)),
        ),
      );

      expect(
        saved.durationMinutes,
        isNull,
        reason: 'an estimate on a finished session reads as what they did',
      );
      expect(saved.durationSource, isNull);
    });
  });

  group('re-sync', () {
    test('a provider duration arriving later replaces the estimate', () async {
      final first = await repository.insertActivity(
        imported(providerWorkoutId: 'fs-9', distanceMiles: 10.0),
      );
      expect(first.durationSource, 'estimated');

      final second = await repository.insertActivity(
        imported(
          providerWorkoutId: 'fs-9',
          distanceMiles: 10.0,
          durationMinutes: 88,
        ),
      );

      expect(second.id, first.id, reason: 'same row, not a duplicate');
      expect(second.durationMinutes, 88);
      expect(
        second.durationSource,
        isNull,
        reason: 'the row became authoritative',
      );
    });

    test('a re-sync that still carries no duration re-estimates', () async {
      final first = await repository.insertActivity(
        imported(providerWorkoutId: 'fs-10', distanceMiles: 10.0),
      );
      expect(first.durationMinutes, 100);

      // Same workout, lengthened by the coach, still with no duration.
      final second = await repository.insertActivity(
        imported(providerWorkoutId: 'fs-10', distanceMiles: 13.0),
      );

      expect(second.id, first.id);
      expect(second.durationMinutes, 130);
      expect(second.durationSource, 'estimated');
    });
  });
}
