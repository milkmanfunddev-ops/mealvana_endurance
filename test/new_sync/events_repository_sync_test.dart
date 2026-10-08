import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/events/data/events_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes/fake_postgrest.dart';
import '../helpers/fakes/recording_report.dart';

// Mocks
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockCarbLoadingRepository extends Mock implements CarbLoadingRepository {}

void main() {
  late AppDatabase database;
  late RecordingReport report;
  late MockCarbLoadingRepository mockCarbLoadingRepository;

  const testUserId = 'test-user-123';

  setUp(() async {
    // Initialize SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});

    // Create in-memory database
    database = AppDatabase.forTesting(NativeDatabase.memory());

    // Create mocks
    report = RecordingReport();
    mockCarbLoadingRepository = MockCarbLoadingRepository();
  });

  tearDown(() async {
    await database.close();
  });

  group('SyncableRepository Interface', () {
    test('repositoryKey should return "events"', () {
      final mockSupabase = MockSupabaseClient();
      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        report: report,
        carbLoadingRepository: mockCarbLoadingRepository,
      );

      expect(repository.repositoryKey, 'events');
    });

    test('dependencies should return ["users", "activities"]', () {
      final mockSupabase = MockSupabaseClient();
      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        report: report,
        carbLoadingRepository: mockCarbLoadingRepository,
      );

      // activities is required because events.activity_id has an FK to
      // activities.id — uploading an event before its activity violates
      // events_activity_id_fkey (Sentry MEALVANA-ENDURANCE-DEV-5K).
      expect(repository.dependencies, ['users', 'activities']);
    });

    test('isStale should return true when never synced', () async {
      final mockSupabase = MockSupabaseClient();
      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        report: report,
        carbLoadingRepository: mockCarbLoadingRepository,
      );

      final isStale = await repository.isStale();
      expect(isStale, true);
    });

    test('isStale should return false when synced recently', () async {
      final mockSupabase = MockSupabaseClient();
      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        report: report,
        carbLoadingRepository: mockCarbLoadingRepository,
      );

      await repository.setLastSyncTime(DateTime.now());
      final isStale = await repository.isStale();
      expect(isStale, false);
    });

    test(
      'isStale should return true when synced more than 24 hours ago',
      () async {
        final mockSupabase = MockSupabaseClient();
        final repository = EventsRepository(
          supabase: mockSupabase,
          database: database,
          report: report,
          carbLoadingRepository: mockCarbLoadingRepository,
        );

        final oldSync = DateTime.now().subtract(const Duration(hours: 25));
        await repository.setLastSyncTime(oldSync);
        final isStale = await repository.isStale();
        expect(isStale, true);
      },
    );
  });

  group('Timestamp Management', () {
    test('getLastSyncTime should return null when never synced', () async {
      final mockSupabase = MockSupabaseClient();
      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        report: report,
        carbLoadingRepository: mockCarbLoadingRepository,
      );

      final timestamp = await repository.getLastSyncTime();
      expect(timestamp, null);
    });

    test('setLastSyncTime and getLastSyncTime should work correctly', () async {
      final mockSupabase = MockSupabaseClient();
      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        report: report,
        carbLoadingRepository: mockCarbLoadingRepository,
      );

      final now = DateTime.now();
      await repository.setLastSyncTime(now);

      final retrieved = await repository.getLastSyncTime();
      expect(retrieved, isNotNull);
      expect(retrieved!.difference(now).inSeconds, lessThan(1));
    });
  });

  group('uploadDirtyRecords', () {
    test('should return nothingToUpload when no dirty records exist', () async {
      final mockSupabase = MockSupabaseClient();
      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        report: report,
        carbLoadingRepository: mockCarbLoadingRepository,
      );

      // Act
      final result = await repository.uploadDirtyRecords(testUserId);

      // Assert
      expect(result.success, true);
      expect(result.count, 0);
    });
  });

  // Ticket 65 (round develop-2026-10, Finding 50-004): the download re-derives
  // event_date from start_time without dirtying the row, and says so (D9).
  group('syncFromRemote re-derives event_date', () {
    const athlete = '65379d67-aaaa-4bbb-8ccc-000000000065';

    /// Shaped exactly like dev's `65379d67-…` "Test" row (read-only,
    /// 2026-10-08): stale event_date, naive start_time, origin null.
    Map<String, dynamic> devRow({
      String id = 'ev-test',
      String? eventDate = '2026-07-17',
      String? startTime = '2026-06-20T08:58:00.000',
    }) => {
      'id': id,
      'user_id': athlete,
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
      'updated_at': '2026-06-17T08:59:29.310184+00:00',
    };

    late FakePostgrest server;
    late EventsRepository repository;

    setUp(() {
      server = FakePostgrest();
      repository = EventsRepository(
        supabase: server.client,
        database: database,
        report: report,
        carbLoadingRepository: mockCarbLoadingRepository,
      );
    });

    List<RecordedReport> rederiveNotes() => report.notes
        .where((n) => n.message?.contains('event_date re-derived') ?? false)
        .toList();

    test('a stale server row lands with the start_time date, clean, and one '
        'note', () async {
      server.tables['events'] = [devRow()];

      final result = await repository.syncFromRemote(athlete);
      expect(result.success, isTrue, reason: result.error);

      final row = await database.select(database.eventsTable).getSingle();
      expect(row.eventDate, DateTime(2026, 6, 20));
      expect(row.startTime, '2026-06-20T08:58:00.000');
      expect(row.needsUpload, isFalse, reason: 'a download never dirties');
      expect(rederiveNotes(), hasLength(1));
      expect(rederiveNotes().single.data, {'count': 1});
      expect(server.writes, isEmpty, reason: 'nothing uploaded');
    });

    test('a row whose columns agree records no note', () async {
      server.tables['events'] = [devRow(eventDate: '2026-06-20')];

      await repository.syncFromRemote(athlete);

      final row = await database.select(database.eventsTable).getSingle();
      expect(row.eventDate, DateTime(2026, 6, 20));
      expect(rederiveNotes(), isEmpty);
    });

    test('a row with start_time null keeps its event_date', () async {
      server.tables['events'] = [devRow(startTime: null)];

      await repository.syncFromRemote(athlete);

      final row = await database.select(database.eventsTable).getSingle();
      expect(row.eventDate, DateTime(2026, 7, 17));
      expect(rederiveNotes(), isEmpty);
    });

    test(
      'a row with event_date null (dev row 69) gets the derived date',
      () async {
        server.tables['events'] = [devRow(eventDate: null)];

        await repository.syncFromRemote(athlete);

        final row = await database.select(database.eventsTable).getSingle();
        expect(row.eventDate, DateTime(2026, 6, 20));
        expect(rederiveNotes(), hasLength(1));
      },
    );

    test('one note per batch, counting every corrected row', () async {
      server.tables['events'] = [
        devRow(id: 'a'),
        devRow(id: 'b'),
        devRow(id: 'c', eventDate: '2026-06-20'),
      ];

      await repository.syncFromRemote(athlete);

      expect(rederiveNotes(), hasLength(1));
      expect(rederiveNotes().single.data, {'count': 2});
    });

    test('a dirty local row is still skipped and not counted', () async {
      server.tables['events'] = [devRow()];
      await repository.syncFromRemote(athlete);
      await (database.update(
        database.eventsTable,
      )..where((t) => t.id.equals('ev-test'))).write(
        EventsTableCompanion(
          needsUpload: const Value(true),
          eventName: const Value('Local edit'),
        ),
      );
      report.calls.clear();

      await repository.syncFromRemote(athlete);

      final row = await database.select(database.eventsTable).getSingle();
      expect(row.eventName, 'Local edit');
      expect(row.needsUpload, isTrue);
      expect(rederiveNotes(), isEmpty);
    });

    test(
      'run twice while the server is stale: same row, a note each time',
      () async {
        server.tables['events'] = [devRow()];

        await repository.syncFromRemote(athlete);
        await repository.syncFromRemote(athlete);

        final rows = await database.select(database.eventsTable).get();
        expect(rows, hasLength(1));
        expect(rows.single.eventDate, DateTime(2026, 6, 20));
        expect(rederiveNotes(), hasLength(2));
      },
    );
  });

  // NOTE: Tests for syncFromRemote() and uploadDirtyRecords() with actual Supabase
  // operations are skipped due to the complexity of mocking the Supabase fluent API.
  // These will be tested via integration tests with real Supabase instances.
  //
  // The following functionality is implemented but not unit tested:
  // - syncFromRemote(): Fetches events from Supabase and saves to Drift
  // - uploadDirtyRecords(): Uploads dirty events to Supabase and clears flags
  // - Error handling for network failures
  //
  // Integration tests should cover:
  // - Full sync cycle (upload dirty → sync fresh data)
  // - Network error handling and retry logic
  // - Data consistency between Drift and Supabase
}
