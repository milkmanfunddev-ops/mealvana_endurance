// Ticket 72 (round develop-2026-10): `EventsRepository.uploadDirtyRecords`
// sends one upsert per dirty row, so the server's 23505 on one row
// (`events_user_date_name_unique`) no longer blocks every later event.
//
// The real repository on an in-memory Drift and a real SupabaseClient whose
// HTTP goes to FakePostgrest. The dirty rows are shaped the way the form's
// create leaves them when its immediate upload failed: `needsUpload` true,
// `localUpdatedAt` set, naive-local `start_time` and its derived date.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_repository.dart';
import 'package:mealvana_endurance/features/events/data/events_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes/fake_postgrest.dart';
import '../../helpers/fakes/recording_report.dart';

const _athlete = '72a0e000-0000-4000-8000-000000000072';

void main() {
  late AppDatabase db;
  late FakePostgrest server;
  late RecordingReport report;
  late EventsRepository repository;

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
  });

  tearDown(() => db.close());

  Future<void> seedDirty(String id, String name, String startTime) {
    final start = DateTime.parse(startTime);
    return db
        .into(db.eventsTable)
        .insert(
          EventsTableCompanion.insert(
            id: Value(id),
            userId: _athlete,
            eventType: 'running',
            eventName: Value(name),
            eventDate: Value(DateTime(start.year, start.month, start.day)),
            startTime: Value(startTime),
            origin: const Value('manual'),
            needsUpload: const Value(true),
            localUpdatedAt: Value(DateTime(2026, 10, 8, 9, 15)),
            createdAt: DateTime(2026, 10, 8, 9, 15),
            updatedAt: DateTime(2026, 10, 8, 9, 15),
          ),
        );
  }

  Future<Set<String>> dirtyIds() async => {
    for (final row in await (db.select(
      db.eventsTable,
    )..where((t) => t.needsUpload.equals(true))).get())
      row.id,
  };

  List<Map<String, dynamic>> eventWriteBodies() => [
    for (final w in server.writes.where((w) => w.table == 'events'))
      Map<String, dynamic>.from(w.body! as Map),
  ];

  /// The server already holds a "Race" on 2026-11-01 (the row the sweep kept,
  /// or another device's): the unique index refuses a second one.
  void serverHoldsRaceOnNov1() {
    server.uniqueViolations['events'] = (row) =>
        row['event_name'] == 'Race' &&
        (row['event_date'] as String?)?.startsWith('2026-11-01') == true;
  }

  test('one refused row out of three: the other two land, it stays dirty, '
      'one degraded is recorded', () async {
    await seedDirty('72-a', 'Shakeout', '2026-10-31T08:00:00.000');
    await seedDirty('72-dup', 'Race', '2026-11-01T14:30:00.000');
    await seedDirty('72-c', 'Recovery jog', '2026-11-02T09:00:00.000');
    serverHoldsRaceOnNov1();

    final result = await repository.uploadDirtyRecords(_athlete);

    expect(result.failed, isTrue, reason: 'a row is still owed');
    expect(result.count, 2);
    expect(result.error, contains('23505'));
    expect(await dirtyIds(), {'72-dup'});

    // One request per row, each an upsert on id.
    final bodies = eventWriteBodies();
    expect(bodies.map((b) => b['id']).toSet(), {'72-a', '72-dup', '72-c'});
    expect(bodies, hasLength(3));
    for (final uri in server.writeUris) {
      expect(uri.queryParameters['on_conflict'], 'id');
    }

    expect(report.degradeds, hasLength(1));
    expect(report.degradeds.single.extra, {
      'eventId': '72-dup',
      'code': '23505',
    });
    expect(report.faults, isEmpty);
  });

  test('the next walk resends only the refused row', () async {
    await seedDirty('72-a', 'Shakeout', '2026-10-31T08:00:00.000');
    await seedDirty('72-dup', 'Race', '2026-11-01T14:30:00.000');
    await seedDirty('72-c', 'Recovery jog', '2026-11-02T09:00:00.000');
    serverHoldsRaceOnNov1();
    await repository.uploadDirtyRecords(_athlete);
    server.writes.clear();
    server.writeUris.clear();

    final second = await repository.uploadDirtyRecords(_athlete);

    expect(eventWriteBodies().map((b) => b['id']), ['72-dup']);
    expect(second.failed, isTrue);
    expect(second.count, 0);
    expect(report.degradeds, hasLength(2), reason: 'once per walk');

    // Once the athlete renames it (or the server row goes), it lands.
    server.uniqueViolations.clear();
    final third = await repository.uploadDirtyRecords(_athlete);
    expect(third.success, isTrue);
    expect(third.count, 1);
    expect(await dirtyIds(), isEmpty);
  });

  test('every row clean: success with the count, no degraded', () async {
    await seedDirty('72-a', 'Shakeout', '2026-10-31T08:00:00.000');
    await seedDirty('72-b', 'Race', '2026-11-01T07:00:00.000');

    final result = await repository.uploadDirtyRecords(_athlete);

    expect(result.success, isTrue);
    expect(result.count, 2);
    expect(await dirtyIds(), isEmpty);
    expect(eventWriteBodies(), hasLength(2));
    expect(report.degradeds, isEmpty);
  });

  test('an RLS refusal is a row failure too: written down, row kept dirty, '
      'the rest still land', () async {
    await seedDirty('72-a', 'Shakeout', '2026-10-31T08:00:00.000');
    server.rejectWrites.add('events');

    final result = await repository.uploadDirtyRecords(_athlete);

    expect(result.failed, isTrue);
    expect(await dirtyIds(), {'72-a'});
    expect(report.degradeds.single.extra, {'eventId': '72-a', 'code': '42501'});
  });
}
