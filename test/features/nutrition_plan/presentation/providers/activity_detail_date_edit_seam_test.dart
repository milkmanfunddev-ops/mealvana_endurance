// Seam test for the plan-screen DATE / TIME pencils
// (`ActivityDetailController.updateScheduledDateTime`) against a REAL
// in-memory Drift database through the real ActivitiesService and
// ActivitiesRepository. Only Supabase, the coach repository, auth and
// logging are mocked.
//
// Prod 1.29.0 (activity c0c76488): the pencil wrote `scheduled_date_time`
// only. Timeline and calendar render `Activity.displayTime`
// (actualTime ?? plannedTime ?? scheduledDateTime), so a set `planned_time`
// kept the workout on the old day while the plan screen showed the new one.
// These tests pin the stored row: planned_time follows scheduled_date_time
// when set, stays null when null, actual_time is untouched, and the row is
// re-stamped dirty (needs_upload, local_updated_at) for the sync queue.
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activities_service.dart';
import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/auth/application/auth_service.dart';
import 'package:mealvana_endurance/features/coach_mode/data/coach_repository.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_state.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart'
    as db
    show AppDatabase, ActivitiesTableCompanion, Activity;
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/fixtures/user_fixtures.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockAppLogger extends Mock implements AppLogger {}

class MockSentryReporter extends Mock implements SentryReporter {}

class MockActivityDeduplicationService extends Mock
    implements ActivityDeduplicationService {}

class MockCoachRepository extends Mock implements CoachRepository {}

class MockAuthService extends Mock implements AuthService {}

/// Seeds the loaded state (the screen already has the activity open) and
/// defers to the real controller for `updateScheduledDateTime`.
class _SeededActivityDetailController extends ActivityDetailController {
  _SeededActivityDetailController(this._seed);

  final ActivityDetailState _seed;

  @override
  FutureOr<ActivityDetailState> build({
    required String activityId,
    bool isNewActivity = false,
  }) {
    return _seed;
  }
}

const _userId = 'user-date-edit';
final _originalStart = DateTime(2026, 10, 12, 7, 30);
final _syncedAt = DateTime(2026, 10, 1, 12);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  late ActivitiesRepository repository;
  late ActivitiesService service;
  late MockAuthService authService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    final logger = MockAppLogger();
    final sentry = MockSentryReporter();
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
    repository = ActivitiesRepository(
      supabase: MockSupabaseClient(),
      database: database,
      logger: logger,
      sentry: sentry,
      deduplicationService: MockActivityDeduplicationService(),
    );
    service = ActivitiesService(
      database,
      logger,
      repository,
      MockCoachRepository(),
    );
    authService = MockAuthService();
    when(
      () => authService.getCurrentUser(),
    ).thenAnswer((_) async => UserFixtures.completedUser(id: _userId));
  });

  tearDown(() => database.close());

  /// Inserts a planned row the way the create flow does (planned_time is
  /// stamped from the scheduled time at insert), optionally clearing
  /// planned_time or recording an actual_time afterwards.
  Future<Activity> seedRow({
    bool clearPlannedTime = false,
    DateTime? actualTime,
  }) async {
    final now = DateTime.now();
    final inserted = await repository.insertActivity(
      Activity(
        id: '',
        userId: _userId,
        activityType: ActivityType.running,
        title: 'Tempo',
        scheduledDateTime: _originalStart,
        durationMinutes: 60,
        createdAt: now,
        updatedAt: now,
      ),
    );
    // Pretend the row synced a while ago. Drift stores DateTime at second
    // resolution, so an explicit old stamp (not a millisecond sleep) is what
    // lets the test see the edit's re-stamp.
    await (database.update(
      database.activitiesTable,
    )..where((t) => t.id.equals(inserted.id))).write(
      db.ActivitiesTableCompanion(
        needsUpload: const Value(false),
        localUpdatedAt: Value(_syncedAt),
        plannedTime: clearPlannedTime
            ? const Value(null)
            : const Value.absent(),
        actualTime: actualTime == null
            ? const Value.absent()
            : Value(actualTime),
      ),
    );
    return (await repository.getActivityById(_userId, inserted.id))!;
  }

  Future<db.Activity> readRow(String id) async {
    return (database.select(
      database.activitiesTable,
    )..where((t) => t.id.equals(id))).getSingle();
  }

  ActivityDetailController notifierFor(Activity activity) {
    final container = ProviderContainer(
      overrides: [
        activitiesServiceProvider.overrideWithValue(service),
        authServiceProvider.overrideWithValue(authService),
        activityDetailControllerProvider(
          activityId: activity.id,
          isNewActivity: false,
        ).overrideWith(
          () => _SeededActivityDetailController(
            ActivityDetailState(
              activity: activity,
              scheduledDateTime: activity.scheduledDateTime,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final provider = activityDetailControllerProvider(
      activityId: activity.id,
      isNewActivity: false,
    );
    container.read(provider); // prime the seeded build
    return container.read(provider.notifier);
  }

  group(
    'ActivityDetailController.updateScheduledDateTime (DATE/TIME pencils)',
    () {
      test('DATE pencil: planned_time follows scheduled_date_time and the row '
          'is re-stamped dirty', () async {
        final seeded = await seedRow();
        final before = await readRow(seeded.id);
        expect(
          before.plannedTime,
          _originalStart,
          reason: 'seed stamps planned',
        );
        expect(before.needsUpload, isFalse);
        expect(before.localUpdatedAt, _syncedAt);

        // Same hour/minute, three days later — exactly what the date picker
        // handler on the screen builds.
        final newDate = DateTime(2026, 10, 15, 7, 30);
        await notifierFor(seeded).updateScheduledDateTime(newDate);

        final after = await readRow(seeded.id);
        expect(after.scheduledDateTime, newDate);
        expect(after.plannedTime, newDate, reason: 'displayTime prefers it');
        expect(after.actualTime, isNull);
        expect(after.needsUpload, isTrue);
        expect(
          after.localUpdatedAt!.isAfter(_syncedAt),
          isTrue,
          reason: 'sync queue must see the edit',
        );
      });

      test('TIME pencil: same path, same day, new hour', () async {
        final seeded = await seedRow();
        final newTime = DateTime(2026, 10, 12, 17, 45);

        await notifierFor(seeded).updateScheduledDateTime(newTime);

        final after = await readRow(seeded.id);
        expect(after.scheduledDateTime, newTime);
        expect(after.plannedTime, newTime);
      });

      // Three-time model (Xuan 2026-10-11): the edit fills the athlete's time.
      test('a row with planned_time null gets it set', () async {
        final seeded = await seedRow(clearPlannedTime: true);
        expect(seeded.plannedTime, isNull);
        final newDate = DateTime(2026, 10, 15, 7, 30);

        await notifierFor(seeded).updateScheduledDateTime(newDate);

        final after = await readRow(seeded.id);
        expect(after.scheduledDateTime, newDate);
        expect(after.plannedTime, newDate);
        expect(after.needsUpload, isTrue);
      });

      test('actual_time is never touched by a date edit', () async {
        final performed = DateTime(2026, 10, 12, 8, 2);
        final seeded = await seedRow(actualTime: performed);
        final newDate = DateTime(2026, 10, 15, 7, 30);

        await notifierFor(seeded).updateScheduledDateTime(newDate);

        final after = await readRow(seeded.id);
        expect(after.actualTime, performed);
        expect(after.plannedTime, newDate);
        expect(after.scheduledDateTime, newDate);
      });
    },
  );
}
