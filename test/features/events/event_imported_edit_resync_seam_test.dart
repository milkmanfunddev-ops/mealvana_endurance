// Ticket 80 (round develop-2026-10): an imported TrainingPeaks event, edited
// in the app, then synced again.
//  * 69-004 / D-2c: a Location-only edit keeps origin `training_peaks` and
//    the empty race distance; a rename flips it `manual`.
//  * Q3 (Lee 2026-10-09): the import stores TrainingPeaks' event id and
//    matches on it first, so a renamed or re-dated imported event is not
//    imported a second time.
//
// Seam test (docs/test/README.md §Seam tests): the real EventsController,
// EventsService, EventsRepository and ProviderEventImportService on an
// in-memory Drift with a real SupabaseClient over FakePostgrest. The import
// input is producer-shaped: TrainingPeaks' /v2/events JSON through the real
// TrainingPeaksTransformer (`Id` is a JSON integer, `EventDate` has no zone).
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activities_service.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_repository.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/providers/carb_nudge_coordinator.dart';
import 'package:mealvana_endurance/features/coach_mode/data/coach_repository.dart';
import 'package:mealvana_endurance/features/events/application/events_service.dart';
import 'package:mealvana_endurance/features/events/data/events_repository.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart' as domain;
import 'package:mealvana_endurance/features/events/presentation/providers/events_controller.dart';
import 'package:mealvana_endurance/features/integrations/application/provider_event_import_service.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_transformer.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_coordinator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes/fake_postgrest.dart';
import '../../helpers/fakes/recording_report.dart';

const _athlete = '80b0e000-0000-4000-8000-000000000080';

/// One event as TrainingPeaks' /v2/events/{start}/{end} answers it.
Map<String, dynamic> _tpWire({
  int id = 1234567890,
  String name = 'IM NC 70.3',
  String date = '2026-10-17T00:00:00',
}) => {
  'Id': id,
  'Name': name,
  'EventDate': date,
  'EventType': 'Triathlon',
  'Description': null,
  'Goals': null,
  'WorkoutIds': null,
};

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
  late ProviderEventImportService importer;
  late ProviderContainer container;
  const transformer = TrainingPeaksTransformer();

  setUp(() {
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
    importer = ProviderEventImportService(
      eventsRepository: repository,
      report: report,
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
        userIdProvider.overrideWith((ref) async => _athlete),
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

  Future<int> sync(List<Map<String, dynamic>> wire) =>
      importer.importTrainingPeaksEvents(_athlete, [
        for (final w in wire) transformer.transformEvent(w)!,
      ]);

  Future<List<Event>> rows() => db.select(db.eventsTable).get();

  /// The stored row as the app reads it, the way the edit form gets it.
  Future<domain.Event> domainEvent(String id) async =>
      (await container
          .read(eventsServiceProvider)
          .getEventById(_athlete, id))!;

  Map<String, dynamic>? lastEventsUpsert() {
    final w = server.writes.lastWhere((w) => w.table == 'events');
    final body = w.body;
    final row = body is List ? body.last : body;
    return row as Map<String, dynamic>?;
  }

  test('the import stores the TrainingPeaks id and sends it', () async {
    expect(await sync([_tpWire()]), 1);
    final row = (await rows()).single;
    expect(row.providerEventId, '1234567890');
    expect(row.origin, 'training_peaks');
    expect(row.eventSubtype, isNull);
    expect(lastEventsUpsert()?['provider_event_id'], '1234567890');
  });

  test('69-004: a Location-only edit keeps origin and the empty distance, '
      'and the next sync adds nothing', () async {
    await sync([_tpWire()]);
    await container.read(eventsControllerProvider.future);
    final stored = await domainEvent((await rows()).single.id);

    // What the form sends: Location set, startTime re-serialised, subtype
    // still null.
    await controller().updateEvent(
      stored.copyWith(
        location: 'Raleigh, North Carolina',
        startTime: DateTime.parse(stored.startTime!).toIso8601String(),
      ),
    );

    final row = (await rows()).single;
    expect(row.location, 'Raleigh, North Carolina');
    expect(row.origin, 'training_peaks');
    expect(row.eventSubtype, isNull);
    expect(row.providerEventId, '1234567890');
    expect(lastEventsUpsert()?['origin'], 'training_peaks');

    expect(await sync([_tpWire()]), 0);
    expect(await rows(), hasLength(1));
    expect((await rows()).single.location, 'Raleigh, North Carolina');
  });

  test('Q3: a renamed imported event flips manual and is not imported again',
      () async {
    await sync([_tpWire()]);
    await container.read(eventsControllerProvider.future);
    final stored = await domainEvent((await rows()).single.id);

    await controller().updateEvent(stored.copyWith(eventName: 'IM NC'));

    final row = (await rows()).single;
    expect(row.eventName, 'IM NC');
    expect(row.origin, 'manual');
    expect(row.providerEventId, '1234567890', reason: 'the edit keeps the id');

    expect(await sync([_tpWire()]), 0, reason: 'matched on the provider id');
    expect(await rows(), hasLength(1));
  });

  test('Q3: a re-dated imported event is not imported again', () async {
    await sync([_tpWire()]);
    await container.read(eventsControllerProvider.future);
    final stored = await domainEvent((await rows()).single.id);

    await controller().updateEvent(
      stored.copyWith(startTime: DateTime(2026, 10, 18, 7).toIso8601String()),
    );
    expect((await rows()).single.eventDate, DateTime(2026, 10, 18));

    expect(await sync([_tpWire()]), 0);
    expect(await rows(), hasLength(1));
  });

  test('Q3: a row imported before the id was stored gets it on the next '
      '(name, date) match, then survives a rename', () async {
    await db
        .into(db.eventsTable)
        .insert(
          EventsTableCompanion.insert(
            id: const Value('80-pre-v25'),
            userId: _athlete,
            eventType: 'triathlon',
            eventName: const Value('IM NC 70.3'),
            eventDate: Value(DateTime(2026, 10, 17)),
            startTime: Value(DateTime(2026, 10, 17).toIso8601String()),
            origin: const Value('training_peaks'),
            needsUpload: const Value(false),
            createdAt: DateTime.utc(2026, 9, 1),
            updatedAt: DateTime.utc(2026, 9, 1),
          ),
        );

    expect(await sync([_tpWire()]), 0);
    expect((await rows()).single.providerEventId, '1234567890');
    expect((await rows()).single.origin, 'training_peaks');

    await container.read(eventsControllerProvider.future);
    final stored = await domainEvent('80-pre-v25');
    await controller().updateEvent(stored.copyWith(eventName: 'Renamed'));

    expect(await sync([_tpWire()]), 0);
    expect(await rows(), hasLength(1));
  });

  test('a different TrainingPeaks event on the same day still imports',
      () async {
    await sync([_tpWire()]);
    expect(await sync([_tpWire(id: 42, name: 'Shakeout 5K')]), 1);
    expect(await rows(), hasLength(2));
  });
}
