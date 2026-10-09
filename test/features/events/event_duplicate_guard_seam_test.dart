// Ticket 72 (round develop-2026-10): the server's unique index
// `events_user_date_name_unique (user_id, event_date, event_name)` refuses a
// second same-name same-day event with 23505, so the controller refuses it
// before the write and the form shows `event_form.duplicate_name_day`.
//
// Seam test (docs/test/README.md §Seam tests): the real EventsController,
// EventsService and EventsRepository on an in-memory Drift, with a real
// SupabaseClient whose HTTP goes to FakePostgrest. Inputs are what the event
// form sends: a trimmed name and `DateTime.toIso8601String()` start times
// (naive local, no zone).
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activities_service.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_repository.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/providers/carb_nudge_coordinator.dart';
import 'package:mealvana_endurance/features/coach_mode/data/coach_repository.dart';
import 'package:mealvana_endurance/features/events/application/events_service.dart';
import 'package:mealvana_endurance/features/events/data/events_repository.dart';
import 'package:mealvana_endurance/features/events/domain/duplicate_event_name_on_day.dart';
import 'package:mealvana_endurance/features/events/presentation/providers/events_controller.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_coordinator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes/fake_postgrest.dart';
import '../../helpers/fakes/recording_report.dart';

const _athlete = '72a0e000-0000-4000-8000-000000000072';
const _coach = '72c0ac00-0000-4000-8000-000000000072';

// What the form sends: `_startTime!.toIso8601String()` on a local DateTime.
const _raceMorning = '2026-11-01T07:00:00.000';
const _raceAfternoon = '2026-11-01T14:30:00.000';
const _nextDay = '2026-11-02T07:00:00.000';

class _MockActivitiesService extends Mock implements ActivitiesService {}

class _MockCoachRepository extends Mock implements CoachRepository {}

class _NoopSyncCoordinator extends SyncCoordinator {
  @override
  SyncState build() => SyncState.idle;

  @override
  Future<void> ensureSynced(
    String repoKey,
    String userId, {
    SyncableRepository? repository,
  }) async {}
}

class _NoopNudge extends CarbNudgeCoordinator {
  @override
  Future<void> run() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakePostgrest server;
  late RecordingReport report;
  late ProviderContainer container;
  // The signed-in user; the coach case switches it before the first read.
  var signedInUser = _athlete;

  setUp(() {
    signedInUser = _athlete;
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = FakePostgrest();
    report = RecordingReport();
    final repository = EventsRepository(
      supabase: server.client,
      database: db,
      report: report,
      carbLoadingRepository: CarbLoadingRepository(
        supabase: server.client,
        database: db,
        report: report,
      ),
    );
    final service = EventsService(
      db,
      repository,
      _MockActivitiesService(),
      _MockCoachRepository(),
      report: report,
    );
    container = ProviderContainer(
      overrides: [
        eventsServiceProvider.overrideWithValue(service),
        eventsRepositoryProvider.overrideWithValue(repository),
        reportProvider.overrideWithValue(report),
        syncCoordinatorProvider.overrideWith(_NoopSyncCoordinator.new),
        userIdProvider.overrideWith((ref) async => signedInUser),
        carbNudgeCoordinatorProvider.overrideWith(_NoopNudge.new),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  EventsController controller() =>
      container.read(eventsControllerProvider.notifier);

  Future<List<Event>> driftRows() => db.select(db.eventsTable).get();

  int eventWrites() => server.writes.where((w) => w.table == 'events').length;

  Future<String> create(String name, String startTime, {String? forUserId}) =>
      controller().createEvent(
        eventType: ActivityType.running,
        eventName: name,
        startTime: startTime,
        forUserId: forUserId,
      );

  test('a second create with the same name on the same day is refused and '
      'writes nothing', () async {
    await container.read(eventsControllerProvider.future);
    final firstId = await create('Race', _raceMorning);
    final writesAfterFirst = eventWrites();

    await expectLater(
      create('Race', _raceAfternoon),
      throwsA(
        isA<DuplicateEventNameOnDayException>()
            .having((e) => e.existingEventId, 'existingEventId', firstId)
            .having((e) => e.eventDate, 'eventDate', DateTime(2026, 11, 1)),
      ),
    );

    expect((await driftRows()).map((r) => r.id), [firstId]);
    expect(eventWrites(), writesAfterFirst, reason: 'nothing sent');
    expect(report.faults, isEmpty, reason: 'a refusal is not a fault');
    expect(
      report.calls.where(
        (c) => c.severity == 'info' && (c.message ?? '').contains('refused'),
      ),
      hasLength(1),
      reason: 'the refusal is written down',
    );
  });

  test('the same name on a different day saves', () async {
    await container.read(eventsControllerProvider.future);
    await create('Race', _raceMorning);
    await create('Race', _nextDay);

    final rows = await driftRows();
    expect(rows, hasLength(2));
    expect(rows.map((r) => r.eventDate).toSet(), {
      DateTime(2026, 11, 1),
      DateTime(2026, 11, 2),
    });
  });

  test('a different name on the same day saves', () async {
    await container.read(eventsControllerProvider.future);
    await create('Race', _raceMorning);
    await create('Shakeout', _raceAfternoon);
    expect(await driftRows(), hasLength(2));
  });

  test('an older row stored with a trailing space still collides', () async {
    await db
        .into(db.eventsTable)
        .insert(
          EventsTableCompanion.insert(
            id: const Value('72-legacy'),
            userId: _athlete,
            eventType: 'running',
            eventName: const Value('Race '),
            eventDate: Value(DateTime(2026, 11, 1)),
            startTime: const Value(_raceMorning),
            needsUpload: const Value(false),
            createdAt: DateTime.utc(2026, 10, 1),
            updatedAt: DateTime.utc(2026, 10, 1),
          ),
        );
    await container.read(eventsControllerProvider.future);

    await expectLater(
      create('Race', _raceAfternoon),
      throwsA(isA<DuplicateEventNameOnDayException>()),
    );
    expect(await driftRows(), hasLength(1));
  });

  test(
    'a rename that collides on update is refused and changes nothing',
    () async {
      await container.read(eventsControllerProvider.future);
      await create('Race', _raceMorning);
      final tuneUpId = await create('Tune-up', _raceAfternoon);
      final writesBefore = eventWrites();

      final events = await container.read(eventsControllerProvider.future);
      final tuneUp = events.singleWhere((e) => e.id == tuneUpId);

      await expectLater(
        controller().updateEvent(tuneUp.copyWith(eventName: 'Race')),
        throwsA(isA<DuplicateEventNameOnDayException>()),
      );

      final row = await (db.select(
        db.eventsTable,
      )..where((t) => t.id.equals(tuneUpId))).getSingle();
      expect(row.eventName, 'Tune-up');
      expect(eventWrites(), writesBefore, reason: 'nothing sent');
      expect(report.faults, isEmpty);
    },
  );

  test('a move onto a day that already has the name is refused', () async {
    await container.read(eventsControllerProvider.future);
    await create('Race', _raceMorning);
    final laterId = await create('Race', _nextDay);
    final events = await container.read(eventsControllerProvider.future);
    final later = events.singleWhere((e) => e.id == laterId);

    await expectLater(
      controller().updateEvent(later.copyWith(startTime: _raceAfternoon)),
      throwsA(isA<DuplicateEventNameOnDayException>()),
    );
  });

  test('saving an event unchanged is not a collision with itself', () async {
    await container.read(eventsControllerProvider.future);
    final id = await create('Race', _raceMorning);
    final events = await container.read(eventsControllerProvider.future);
    final race = events.singleWhere((e) => e.id == id);

    await controller().updateEvent(race.copyWith(location: 'Central Park'));

    final row = await (db.select(
      db.eventsTable,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(row.location, 'Central Park');
  });

  test('a coach creating for an athlete is refused against the athlete\'s '
      'events', () async {
    // The athlete's own event, as their device synced it down.
    await db
        .into(db.eventsTable)
        .insert(
          EventsTableCompanion.insert(
            id: const Value('72-athlete-race'),
            userId: _athlete,
            eventType: 'running',
            eventName: const Value('Race'),
            eventDate: Value(DateTime(2026, 11, 1)),
            startTime: const Value(_raceMorning),
            needsUpload: const Value(false),
            createdAt: DateTime.utc(2026, 10, 1),
            updatedAt: DateTime.utc(2026, 10, 1),
          ),
        );
    signedInUser = _coach;
    await container.read(eventsControllerProvider.future);

    await expectLater(
      create('Race', _raceAfternoon, forUserId: _athlete),
      throwsA(
        isA<DuplicateEventNameOnDayException>().having(
          (e) => e.userId,
          'userId',
          _athlete,
        ),
      ),
    );
    expect(await driftRows(), hasLength(1));
    expect(eventWrites(), 0);
  });
}
