// Seam tests — the home-shell calendar sheet's two data derivations
// (docs/test/README.md §Seam tests: feed producer-shaped data, never the
// consumer's own recompute).
//
// 1. The tint rollup crosses the Drift boundary: rows are written through
//    the REAL MealLogRepository insert path (the way the meal-logging
//    service writes them) and read back through watchLogDatesInRange.
// 2. The dot channel's day-key is the DISPLAY rule (Activity.displayTime =
//    actual ?? planned ?? scheduled) — pinned against the divergent
//    `scheduled_date_time` key with a producer-shaped synced row whose
//    measured actual_time crossed midnight.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/home_shell/application/home_shell_calendar_assembler.dart';
import 'package:mealvana_endurance/features/meal_logging/data/meal_log_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart'
    hide Activity;
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/navigation/kyle_calendar_sheet.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockAppLogger extends Mock implements AppLogger {}

class _MockSentryReporter extends Mock implements SentryReporter {}

void _stubLogger(_MockAppLogger logger) {
  when(
    () => logger.info(
      any(),
      context: any(named: 'context'),
      data: any(named: 'data'),
    ),
  ).thenReturn(null);
  when(
    () => logger.debug(
      any(),
      context: any(named: 'context'),
      data: any(named: 'data'),
    ),
  ).thenReturn(null);
  when(
    () => logger.warning(
      any(),
      context: any(named: 'context'),
      error: any(named: 'error'),
      stackTrace: any(named: 'stackTrace'),
      data: any(named: 'data'),
    ),
  ).thenReturn(null);
  when(
    () => logger.error(
      any(),
      context: any(named: 'context'),
      error: any(named: 'error'),
      stackTrace: any(named: 'stackTrace'),
      data: any(named: 'data'),
    ),
  ).thenReturn(null);
}

MealLog _producerLog({
  required String id,
  required String userId,
  required String logDate,
  MealLogSource source = MealLogSource.manual,
  bool isDeleted = false,
}) {
  final now = DateTime.utc(2026, 8, 14, 8);
  return MealLog(
    id: id,
    userId: userId,
    logDate: logDate,
    slot: MealSlot.snack,
    name: 'Fixture $id',
    source: source,
    components: const [],
    calories: 300,
    carbsG: 40,
    proteinG: 10,
    fatG: 8,
    isDeleted: isDeleted,
    createdAt: now,
    updatedAt: now,
  );
}

Activity _producerActivity({
  required String id,
  required DateTime scheduled,
  DateTime? planned,
  DateTime? actual,
  ActivityStatus status = ActivityStatus.planned,
  String? garminSummaryId,
}) => Activity(
  id: id,
  userId: 'u1',
  activityType: ActivityType.running,
  title: id,
  scheduledDateTime: scheduled,
  plannedTime: planned,
  actualTime: actual,
  status: status,
  garminSummaryId: garminSummaryId,
  durationMinutes: 60,
  createdAt: DateTime(2026, 8, 1),
  updatedAt: DateTime(2026, 8, 1),
);

void main() {
  group('tint rollup through the real repository (watchLogDatesInRange)', () {
    late AppDatabase database;
    late MealLogRepository repository;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      final logger = _MockAppLogger();
      _stubLogger(logger);
      final sentry = _MockSentryReporter();
      when(
        () => sentry.reportNetworkError(
          any(),
          url: any(named: 'url'),
          method: any(named: 'method'),
          statusCode: any(named: 'statusCode'),
          timeout: any(named: 'timeout'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async {});
      repository = MealLogRepository(
        supabase: _MockSupabaseClient(),
        database: database,
        logger: logger,
        sentry: sentry,
      );
    });

    tearDown(() async {
      await Future<void>.delayed(Duration.zero);
      await database.close();
    });

    test('every athlete source counts; tombstones, other users and '
        'out-of-range days do not', () async {
      // Producer-shaped writes through the real insert path — one per
      // source class, including the server-side jade_baseline shape.
      await repository.insertLog(
        _producerLog(id: 'a', userId: 'u1', logDate: '2026-08-14'),
      );
      await repository.insertLog(
        _producerLog(
          id: 'b',
          userId: 'u1',
          logDate: '2026-08-15',
          source: MealLogSource.saved,
        ),
      );
      await repository.insertLog(
        _producerLog(
          id: 'c',
          userId: 'u1',
          logDate: '2026-08-16',
          source: MealLogSource.aiCoachBaseline,
        ),
      );
      // A second log on an already-counted day (presence, not count).
      await repository.insertLog(
        _producerLog(
          id: 'd',
          userId: 'u1',
          logDate: '2026-08-14',
          source: MealLogSource.recipe,
        ),
      );
      // Tombstone: soft-deleted rows leave the rollup.
      await repository.insertLog(
        _producerLog(id: 'e', userId: 'u1', logDate: '2026-08-17'),
      );
      await repository.softDeleteLog(id: 'e', userId: 'u1');
      // Another athlete's day must not tint this user's calendar.
      await repository.insertLog(
        _producerLog(id: 'f', userId: 'u2', logDate: '2026-08-18'),
      );
      // Out of the month's range.
      await repository.insertLog(
        _producerLog(id: 'g', userId: 'u1', logDate: '2026-09-02'),
      );

      final dates = await repository
          .watchLogDatesInRange('u1', '2026-08-01', '2026-08-31')
          .first;
      expect(dates, {'2026-08-14', '2026-08-15', '2026-08-16'});
    });

    test('the rollup feeds the binary tint — presence only', () async {
      await repository.insertLog(
        _producerLog(id: 'a', userId: 'u1', logDate: '2026-08-15'),
      );
      final dates = await repository
          .watchLogDatesInRange('u1', '2026-08-01', '2026-08-31')
          .first;
      final days = assembleCalendarMonth(
        month: DateTime(2026, 8, 1),
        now: DateTime(2026, 8, 20),
        activities: const [],
        loggedDates: dates,
      );
      expect(days[15]?.tinted, isTrue);
      expect(days.length, 1, reason: 'no other day gained an entry');
    });
  });

  group('dot day-key is the display rule, never scheduled_date_time', () {
    test('a synced workout whose measured actual_time crossed midnight dots '
        'the actual day', () {
      // Producer shape: sync writes a measured actual_time + summary id.
      // Scheduled late on the 10th; the platform stamped 00:15 on the 11th.
      final crossed = _producerActivity(
        id: 'late-run',
        scheduled: DateTime(2026, 8, 10, 23, 30),
        planned: DateTime(2026, 8, 10, 23, 30),
        actual: DateTime(2026, 8, 11, 0, 15),
        status: ActivityStatus.completed,
        garminSummaryId: 'g-1',
      );
      final days = assembleCalendarMonth(
        month: DateTime(2026, 8, 1),
        now: DateTime(2026, 8, 20),
        activities: [crossed],
        loggedDates: const {},
      );
      expect(
        days[11]?.dot,
        CalendarDotState.done,
        reason:
            'displayTime (actual ?? planned ?? scheduled) buckets the '
            '11th',
      );
      expect(
        days[10],
        isNull,
        reason: 'the divergent scheduled_date_time key must NOT be used',
      );
    });

    test('a legacy row predating the two-time columns falls back to '
        'scheduled_date_time (the resolver\'s third rung)', () {
      final legacy = _producerActivity(
        id: 'legacy',
        scheduled: DateTime(2026, 8, 22, 7, 0),
        // planned/actual never written by the legacy producer.
      );
      final days = assembleCalendarMonth(
        month: DateTime(2026, 8, 1),
        now: DateTime(2026, 8, 20),
        activities: [legacy],
        loggedDates: const {},
      );
      expect(days[22]?.dot, CalendarDotState.planned);
    });

    test('tombstoned activities contribute nothing (§4b)', () {
      final deleted = _producerActivity(
        id: 'gone',
        scheduled: DateTime(2026, 8, 9, 7, 0),
        planned: DateTime(2026, 8, 9, 7, 0),
        status: ActivityStatus.deleted,
      );
      final days = assembleCalendarMonth(
        month: DateTime(2026, 8, 1),
        now: DateTime(2026, 8, 20),
        activities: [deleted],
        loggedDates: const {},
      );
      expect(days, isEmpty);
    });
  });
}
