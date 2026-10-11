// Local reschedule beats provider re-sync (Xuan, 2026-10-10,
// qa/intake/2026-10-10-local-reschedule-beats-provider-resync.md), against
// a REAL in-memory Drift database and the real repository merge path
// (insertActivity -> _mergeProviderUpdate -> updateActivityFromProvider):
//   - a provider-synced planned workout moved IN THE APP keeps its local
//     scheduled_date_time / planned_time when the provider re-sends its own
//     (older) date;
//   - provider_scheduled_at always records the provider's own date;
//   - a row that was never moved locally keeps following the provider
//     (no false positive);
//   - a same-date re-sync changes nothing but fills provider_scheduled_at.
// Prod bug: activity c0c76488 (ops bug-report
// 2026-10-10-provider-resync-overwrites-local-reschedule.md).
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart'
    as db
    show AppDatabase, ActivitiesTableCompanion, Activity;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  late ActivitiesRepository repository;

  const userId = 'user-local-reschedule';
  const deviceId = 'device-test';
  const provider = 'final_surge';
  const providerWorkoutId = 'fs-long-run-1';

  // Day D as Final Surge sends it (WorkoutDate + WorkoutTime -> local wall
  // clock, see FinalSurgeTransformer._parseScheduledDate).
  final dayD = DateTime(2026, 10, 11, 7, 0);
  final dayDPlus1 = DateTime(2026, 10, 12, 7, 0);
  final dayDPlus2 = DateTime(2026, 10, 13, 7, 0);

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
  });

  tearDown(() => database.close());

  /// What the FinalSurgeTransformer hands the sync service for one planned
  /// workout: provider fields set, no two-time / kcal fields, and (today)
  /// no providerScheduledAt — the repository derives it from the date.
  Activity providerPayload({
    required DateTime scheduledDateTime,
    String title = 'Long Run',
    double distanceMiles = 14.0,
    DateTime? lastSyncedAt,
  }) {
    final now = DateTime.now();
    return Activity(
      id: '',
      userId: userId,
      activityType: ActivityType.running,
      title: title,
      scheduledDateTime: scheduledDateTime,
      distanceMiles: distanceMiles,
      durationMinutes: 120,
      syncedFromProvider: provider,
      providerWorkoutId: providerWorkoutId,
      lastSyncedAt: lastSyncedAt ?? now,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// First sync: the FS planned run lands on day D.
  Future<Activity> seedProviderRun() =>
      repository.insertActivity(providerPayload(scheduledDateTime: dayD));

  /// A later sync: the sync service re-sends the provider's row through the
  /// same entry point (insertActivity finds the provider-keyed row and
  /// merges; the UPDATED branch calls updateActivityFromProvider directly —
  /// both go through _mergeProviderUpdate).
  Future<Activity> providerResync(DateTime providerDate) => repository
      .insertActivity(providerPayload(scheduledDateTime: providerDate));

  /// The in-app reschedule as the edit path performs it: a copy of the row
  /// with the new date, saved through updateActivity (which bumps
  /// local_updated_at and marks it dirty). planned_time moves with the date
  /// (fix/1.30.0-plan-date-edit makes every in-app date edit do this).
  Future<void> rescheduleLocally(Activity current, DateTime to) =>
      repository.updateActivity(
        deviceId: deviceId,
        activity: current.copyWith(scheduledDateTime: to, plannedTime: to),
      );

  Future<db.Activity> row(String id) => (database.select(
    database.activitiesTable,
  )..where((t) => t.id.equals(id))).getSingle();

  group('local reschedule beats provider re-sync', () {
    test(
      'first sync records the provider date in provider_scheduled_at',
      () async {
        final run = await seedProviderRun();
        final r = await row(run.id);
        expect(r.scheduledDateTime, dayD);
        expect(r.plannedTime, dayD);
        expect(
          r.providerScheduledAt,
          dayD,
          reason: 'the provider\'s own date is recorded from the first sync',
        );
      },
    );

    test('(a) row moved in the app to D+1 stays on D+1 when the provider '
        're-sends D; provider_scheduled_at == D', () async {
      final run = await seedProviderRun();
      await rescheduleLocally(run, dayDPlus1);
      final moved = await row(run.id);
      expect(moved.scheduledDateTime, dayDPlus1);
      expect(moved.plannedTime, dayDPlus1);
      expect(moved.providerScheduledAt, dayD);

      final syncedAt = DateTime(2026, 10, 10, 12, 0);
      await repository.insertActivity(
        providerPayload(
          scheduledDateTime: dayD,
          title: 'Long Run (renamed in FS)',
          lastSyncedAt: syncedAt,
        ),
      );

      final r = await row(run.id);
      expect(r.scheduledDateTime, dayDPlus1, reason: 'the app edit wins');
      expect(r.plannedTime, dayDPlus1, reason: 'planned_time stays local');
      expect(
        r.providerScheduledAt,
        dayD,
        reason: 'the provider\'s own date is still recorded',
      );
      expect(
        r.title,
        'Long Run (renamed in FS)',
        reason: 'other provider fields keep today\'s merge behaviour',
      );
      expect(r.lastSyncedAt, syncedAt, reason: 'the kept row still syncs');
      expect(r.syncedFromProvider, provider);
      expect(r.providerWorkoutId, providerWorkoutId);
    });

    test('(b) a row never moved in the app follows a provider move to D+2 '
        '(no false positive)', () async {
      final run = await seedProviderRun();
      await providerResync(dayDPlus2);
      final r = await row(run.id);
      expect(r.scheduledDateTime, dayDPlus2);
      expect(r.plannedTime, dayDPlus2, reason: 'scheduling owns planned_time');
      expect(r.providerScheduledAt, dayDPlus2);
    });

    test(
      '(c) a same-date re-sync changes nothing and fills provider_scheduled_at',
      () async {
        final run = await seedProviderRun();
        // Simulate a row synced before this fix: no recorded provider date.
        await (database.update(
          database.activitiesTable,
        )..where((t) => t.id.equals(run.id))).write(
          const db.ActivitiesTableCompanion(providerScheduledAt: Value(null)),
        );
        expect((await row(run.id)).providerScheduledAt, isNull);

        await providerResync(dayD);
        final r = await row(run.id);
        expect(r.scheduledDateTime, dayD);
        expect(r.plannedTime, dayD);
        expect(r.providerScheduledAt, dayD);
      },
    );

    test('a row synced before the fix (no provider date on file) follows the '
        'provider once, then its next in-app move is kept', () async {
      // Pre-fix prod rows (e.g. c0c76488): provider_scheduled_at NULL, and a
      // local move cannot be told apart from the provider\'s own date.
      final run = await seedProviderRun();
      await rescheduleLocally(run, dayDPlus1);
      // Null AFTER the move: a pre-fix in-app edit read a row with no
      // provider date and wrote it back the same way.
      await (database.update(
        database.activitiesTable,
      )..where((t) => t.id.equals(run.id))).write(
        const db.ActivitiesTableCompanion(providerScheduledAt: Value(null)),
      );
      expect((await row(run.id)).scheduledDateTime, dayDPlus1);

      // First sync after the fix: documented limitation, the date reverts
      // once while the provider date gets recorded.
      await providerResync(dayD);
      var r = await row(run.id);
      expect(r.scheduledDateTime, dayD);
      expect(r.providerScheduledAt, dayD);

      // The athlete moves it again; from now on the app edit wins.
      await rescheduleLocally(repository.mapper.fromDriftRow(r), dayDPlus1);
      await providerResync(dayD);
      r = await row(run.id);
      expect(r.scheduledDateTime, dayDPlus1);
      expect(r.plannedTime, dayDPlus1);
      expect(r.providerScheduledAt, dayD);
    });

    test(
      'UNRULED edge, documents today\'s behaviour: a provider move after a '
      'local move keeps the local date and records the new provider date',
      () async {
        final run = await seedProviderRun();
        await rescheduleLocally(run, dayDPlus1);
        await providerResync(dayDPlus2);
        final r = await row(run.id);
        expect(r.scheduledDateTime, dayDPlus1);
        expect(r.plannedTime, dayDPlus1);
        expect(
          r.providerScheduledAt,
          dayDPlus2,
          reason: 'the later provider change is detectable from the row',
        );
      },
    );

    test(
      'updateActivityFromProvider (the UPDATED branch) keeps the local date too',
      () async {
        final run = await seedProviderRun();
        await rescheduleLocally(run, dayDPlus1);
        await repository.updateActivityFromProvider(
          providerPayload(scheduledDateTime: dayD).copyWith(id: run.id),
        );
        final r = await row(run.id);
        expect(r.scheduledDateTime, dayDPlus1);
        expect(r.plannedTime, dayDPlus1);
        expect(r.providerScheduledAt, dayD);
      },
    );
  });
}
