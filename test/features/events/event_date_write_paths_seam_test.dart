// Ticket 65 (round develop-2026-10, Finding 50-004): event_date is derived from
// start_time on EVERY write path, so the two columns cannot drift.
//
// Seam test (docs/test/README.md §Seam tests): the real EventsController,
// EventsService and EventsRepository on an in-memory Drift, with a real
// SupabaseClient whose HTTP goes to FakePostgrest (only the wire is faked).
// Inputs are producer-shaped and never the derivation's own output: the dev
// row "Test" (event_date 2026-07-17, start_time 2026-06-20T08:58:00.000), and
// a TrainingPeaks import whose eventDate carries a time of day. Each case
// checks the Drift row AND the recorded insert/upsert payload.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activities_service.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_repository.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/providers/carb_nudge_coordinator.dart';
import 'package:mealvana_endurance/features/coach_mode/data/coach_repository.dart';
import 'package:mealvana_endurance/features/events/application/events_service.dart';
import 'package:mealvana_endurance/features/events/data/events_repository.dart';
import 'package:mealvana_endurance/features/events/presentation/providers/events_controller.dart';
import 'package:mealvana_endurance/features/integrations/application/provider_event_import_service.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_transformer.dart';
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

const _user = '65379d67-0000-4000-8000-000000000065';
const _devStart = '2026-06-20T08:58:00.000';

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
  late EventsRepository repository;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = FakePostgrest();
    report = RecordingReport();
    repository = EventsRepository(
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
        userIdProvider.overrideWith((ref) async => _user),
        carbNudgeCoordinatorProvider.overrideWith(_NoopNudge.new),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<Event> driftRow(String id) =>
      (db.select(db.eventsTable)..where((t) => t.id.equals(id))).getSingle();

  /// Every recorded events payload (insert or upsert, map or list body).
  List<Map<String, dynamic>> eventPayloads() => [
    for (final w in server.writes.where((w) => w.table == 'events'))
      if (w.body is Map)
        Map<String, dynamic>.from(w.body! as Map)
      else if (w.body is List)
        for (final row in w.body! as List)
          Map<String, dynamic>.from(row as Map),
  ];

  /// The background upload in updateEvent is unawaited; let it land.
  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void expectColumnsAgree(Event row, Map<String, dynamic> payload) {
    final start = row.startTime!;
    final day = DateTime.parse(start.substring(0, 10));
    expect(row.eventDate, day, reason: 'Drift event_date = start_time date');
    expect(payload['start_time'], start);
    expect(
      (payload['event_date'] as String).substring(0, 10),
      start.substring(0, 10),
      reason: 'payload event_date = start_time date',
    );
  }

  Future<void> seedDevRow({String? origin}) => db
      .into(db.eventsTable)
      .insert(
        EventsTableCompanion.insert(
          id: const Value('65379d67-test'),
          userId: _user,
          eventType: 'running',
          eventName: const Value('Test'),
          // The dev row: last written 31 s after creation by the pre-e8ccda76
          // update that moved start_time and kept the creation-day date.
          eventDate: Value(DateTime(2026, 7, 17)),
          startTime: const Value(_devStart),
          origin: Value(origin),
          needsUpload: const Value(false),
          createdAt: DateTime.utc(2026, 6, 17, 8, 58, 58),
          updatedAt: DateTime.utc(2026, 6, 17, 8, 59, 29),
        ),
      );

  test('create through the controller stores the start_time date', () async {
    await container.read(eventsControllerProvider.future);
    final id = await container
        .read(eventsControllerProvider.notifier)
        .createEvent(
          eventType: ActivityType.running,
          eventName: 'Test',
          startTime: _devStart,
        );

    final row = await driftRow(id);
    final insert = eventPayloads().single;
    expect(row.eventDate, DateTime(2026, 6, 20));
    expectColumnsAgree(row, insert);
  });

  test('update of the dev-shaped row with only the name changed heals '
      'event_date (Jul 17 -> Jun 20)', () async {
    await seedDevRow();
    final events = await container.read(eventsControllerProvider.future);
    final stale = events.single;
    expect(stale.eventDate, DateTime(2026, 7, 17), reason: 'seeded stale');

    await container
        .read(eventsControllerProvider.notifier)
        .updateEvent(stale.copyWith(eventName: 'Test (renamed)'));
    await settle();

    final row = await driftRow('65379d67-test');
    expect(row.eventName, 'Test (renamed)');
    expect(row.eventDate, DateTime(2026, 6, 20));
    expectColumnsAgree(row, eventPayloads().last);
  });

  test('update that moves start_time moves event_date with it', () async {
    await seedDevRow();
    final events = await container.read(eventsControllerProvider.future);

    await container
        .read(eventsControllerProvider.notifier)
        .updateEvent(
          events.single.copyWith(startTime: '2026-07-04T07:00:00.000'),
        );
    await settle();

    final row = await driftRow('65379d67-test');
    expect(row.eventDate, DateTime(2026, 7, 4));
    expectColumnsAgree(row, eventPayloads().last);
  });

  test(
    'a TrainingPeaks import whose eventDate carries a time of day stores '
    'the date only, and the dirty upload sends it (offline, then online)',
    () async {
      final import = ProviderEventImportService(
        eventsRepository: repository,
        report: report,
      );
      server.rejectWrites.add('events'); // offline: the immediate insert fails

      final saved = await import.importTrainingPeaksEvents(_user, [
        TrainingPeaksEventResult(
          eventId: 'tp-1',
          eventDate: DateTime.parse('2026-10-17T07:15:00'),
          eventType: 'RoadRunning',
          eventName: 'IM NC 70.3',
        ),
      ]);
      expect(saved, 1);

      final row = (await db.select(db.eventsTable).get()).single;
      expect(row.eventDate, DateTime(2026, 10, 17), reason: 'no time of day');
      expect(row.needsUpload, isTrue);
      expectColumnsAgree(row, eventPayloads().single);

      final offline = await repository.uploadDirtyRecords(_user);
      expect(offline.success, isFalse, reason: 'still offline');

      server.rejectWrites.clear();
      final writesBefore = server.writes.length;
      final online = await repository.uploadDirtyRecords(_user);
      expect(online.success, isTrue, reason: online.error);
      expect(online.count, 1);

      final dirtyPayload = server.writes.skip(writesBefore).single;
      expect(dirtyPayload.method, 'POST');
      // One upsert per dirty row since ticket 72: the body is the row itself.
      final body = dirtyPayload.body! as Map;
      expectColumnsAgree(
        await driftRow(row.id),
        Map<String, dynamic>.from(body),
      );
    },
  );

  test('the D-2c origin flip on a legacy row with a stale event_date heals '
      'the date', () async {
    await seedDevRow(); // origin null = legacy
    final import = ProviderEventImportService(
      eventsRepository: repository,
      report: report,
    );

    // TP reports the event on the stale day, so the dedupe (which keys on
    // event_date) matches the legacy row and flips its origin.
    final saved = await import.importTrainingPeaksEvents(_user, [
      TrainingPeaksEventResult(
        eventId: 'tp-2',
        eventDate: DateTime.parse('2026-07-17T08:00:00'),
        eventType: 'RoadRunning',
        eventName: 'Test',
      ),
    ]);
    await settle();

    expect(saved, 0, reason: 'matched, not created');
    final row = await driftRow('65379d67-test');
    expect(row.origin, 'training_peaks');
    expect(row.eventDate, DateTime(2026, 6, 20));
    final upsert = eventPayloads().last;
    expect(upsert['origin'], 'training_peaks');
    expectColumnsAgree(row, upsert);
  });

  test('twice at once: two concurrent updates write the same date', () async {
    await seedDevRow();
    final stale = (await container.read(
      eventsControllerProvider.future,
    )).single;
    final notifier = container.read(eventsControllerProvider.notifier);

    await Future.wait([
      notifier.updateEvent(stale.copyWith(eventName: 'A')),
      notifier.updateEvent(stale.copyWith(eventName: 'B')),
    ]);
    await settle();

    final row = await driftRow('65379d67-test');
    expect(row.eventDate, DateTime(2026, 6, 20));
    for (final p in eventPayloads()) {
      expect((p['event_date'] as String).substring(0, 10), '2026-06-20');
    }

    // After a refresh the controller rereads Drift and shows the same date.
    container.invalidate(eventsControllerProvider);
    final reread = await container.read(eventsControllerProvider.future);
    expect(reread.single.eventDate, DateTime(2026, 6, 20));
  });
}
