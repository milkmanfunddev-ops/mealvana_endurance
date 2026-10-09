// Ticket 65 (round develop-2026-10, Finding 50-004): EventSyncHandler (the
// DataSyncService path and the coach's syncAthleteEvents) re-derives
// event_date from start_time on download, never dirties the row, and writes
// the correction down (D9).
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/sync/entity_sync/event_sync_handler.dart';

import '../../../../helpers/fakes/recording_report.dart';

const _athlete = '65379d67-aaaa-4bbb-8ccc-000000000065';

/// Shaped exactly like dev's `65379d67-…` "Test" row (read-only, 2026-10-08).
Map<String, dynamic> _devRow({
  String id = 'ev-test',
  String? eventDate = '2026-07-17',
  String? startTime = '2026-06-20T08:58:00.000',
  String updatedAt = '2026-06-17T08:59:29.310184+00:00',
}) => {
  'id': id,
  'user_id': _athlete,
  'activity_id': null,
  'event_type': 'running',
  'event_subtype': null,
  'event_name': 'Test',
  'location': null,
  'registration_url': null,
  'event_date': eventDate,
  'start_time': startTime,
  'goal_time_minutes': null,
  'goal_pace_minutes_per_mile': null,
  'predicted_finish_time_minutes': null,
  'has_carb_loading': false,
  'carb_loading_days': null,
  'carb_loading_start_date': null,
  'has_nutrition_plan': false,
  'bib_number': null,
  'wave_start_time': null,
  'packet_pickup_info': null,
  'actual_finish_time_minutes': null,
  'final_placement': null,
  'age_group_placement': null,
  'origin': null,
  'created_at': '2026-06-17T08:58:58.123456+00:00',
  'updated_at': updatedAt,
};

void main() {
  late AppDatabase db;
  late RecordingReport report;
  late EventSyncHandler handler;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    report = RecordingReport();
    handler = EventSyncHandler(database: db, report: report);
  });

  tearDown(() => db.close());

  List<RecordedReport> rederiveNotes() => report.notes
      .where((n) => n.message?.contains('event_date re-derived') ?? false)
      .toList();

  test('a stale server row lands with the start_time date, clean, and one '
      'note naming the row', () async {
    await handler.upsertEvent(_devRow(), _athlete);

    final row = await db.select(db.eventsTable).getSingle();
    expect(row.eventDate, DateTime(2026, 6, 20));
    expect(row.needsUpload, isNot(true)); // the handler leaves it unset
    expect(rederiveNotes(), hasLength(1));
    expect(rederiveNotes().single.area, 'sync');
    expect(rederiveNotes().single.data, {'eventId': 'ev-test'});
    expect(report.faults, isEmpty);
  });

  test('origin and provider_event_id survive the download (wave-8 review: '
      'insertOrReplace rebuilds the row)', () async {
    await handler.upsertEvent({
      ..._devRow(),
      'origin': 'training_peaks',
      'provider_event_id': 'tp-123',
    }, _athlete);
    final row = await db.select(db.eventsTable).getSingle();
    expect(row.origin, 'training_peaks');
    expect(row.providerEventId, 'tp-123');
  });

  test('a row whose columns agree records no note', () async {
    await handler.upsertEvent(_devRow(eventDate: '2026-06-20'), _athlete);

    final row = await db.select(db.eventsTable).getSingle();
    expect(row.eventDate, DateTime(2026, 6, 20));
    expect(rederiveNotes(), isEmpty);
  });

  test('a row with start_time null keeps its event_date', () async {
    await handler.upsertEvent(_devRow(startTime: null), _athlete);

    final row = await db.select(db.eventsTable).getSingle();
    expect(row.eventDate, DateTime(2026, 7, 17));
    expect(rederiveNotes(), isEmpty);
  });

  test(
    'the coach path (syncAthleteEvents) corrects the athlete row too',
    () async {
      await handler.syncAthleteEvents([_devRow()]);

      final row = await db.select(db.eventsTable).getSingle();
      expect(row.userId, _athlete);
      expect(row.eventDate, DateTime(2026, 6, 20));
      expect(
        row.needsUpload,
        isNot(true),
        reason: 'never upload another user row',
      );
      expect(rederiveNotes(), hasLength(1));
    },
  );

  test('after the server is healed (newer updated_at, agreeing columns) the '
      'row is rewritten with no note', () async {
    await handler.upsertEvent(_devRow(), _athlete);
    report.calls.clear();

    await handler.upsertEvent(
      _devRow(
        eventDate: '2026-06-20',
        updatedAt: '2026-10-08T12:00:00.000000+00:00',
      ),
      _athlete,
    );

    final row = await db.select(db.eventsTable).getSingle();
    expect(row.eventDate, DateTime(2026, 6, 20));
    expect(rederiveNotes(), isEmpty);
  });

  test('eventToJson sends the derived date', () async {
    await handler.upsertEvent(_devRow(), _athlete);
    final row = await db.select(db.eventsTable).getSingle();
    final stale = row.copyWith(eventDate: Value(DateTime(2026, 7, 17)));

    final json = handler.eventToJson(stale);
    expect((json['event_date'] as String).substring(0, 10), '2026-06-20');
  });
}
