import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/coach_mode/data/coach_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/fakes/fake_postgrest.dart';
import '../helpers/fakes/recording_report.dart';

// Mocks
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockAppDatabase extends Mock implements AppDatabase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSupabaseClient mockSupabase;
  late MockAppDatabase mockDatabase;
  late RecordingReport report;
  late CoachRepository repository;

  setUpAll(() async {
    // Initialize SharedPreferences with in-memory values
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockDatabase = MockAppDatabase();
    report = RecordingReport();

    repository = CoachRepository(
      supabase: mockSupabase,
      database: mockDatabase,
      report: report,
    );
  });

  group('SyncableRepository Implementation', () {
    test('repositoryKey returns "coaches"', () {
      expect(repository.repositoryKey, equals('coaches'));
    });

    test('dependencies returns ["users"]', () {
      expect(repository.dependencies, equals(['users']));
    });

    test('isStale returns true when never synced', () async {
      final isStale = await repository.isStale();
      expect(isStale, isTrue);
    });

    test('getLastSyncTime returns null when never synced', () async {
      final lastSync = await repository.getLastSyncTime();
      expect(lastSync, isNull);
    });

    test('setLastSyncTime and getLastSyncTime work together', () async {
      final now = DateTime.now();
      await repository.setLastSyncTime(now);

      final lastSync = await repository.getLastSyncTime();
      expect(lastSync, isNotNull);
      expect(lastSync!.difference(now).inSeconds, lessThan(2));
    });

    test('isStale returns false after recent sync', () async {
      await repository.setLastSyncTime(DateTime.now());
      final isStale = await repository.isStale();
      expect(isStale, isFalse);
    });
  });

  group('uploadDirtyRecords', () {
    const testUserId = 'test-user-id';

    test('returns nothingToUpload (dual-write pattern)', () async {
      // CoachRepository uses dual-write pattern (writes to both Drift and Supabase immediately)
      // so there are no dirty records to upload
      final result = await repository.uploadDirtyRecords(testUserId);

      expect(result.success, isTrue);
      expect(result.count, 0);
    });
  });

  // Note: syncFromRemote tests omitted due to complex Supabase mocking requirements.
  // The implementation is verified through integration tests and manual testing.
  // Key syncFromRemote behaviors:
  // 1. Syncs coach record when user is a coach
  // 2. Syncs relationships where user is coach OR athlete
  // 3. Handles empty responses correctly
  // 4. Updates last sync timestamp
  // 5. Returns appropriate SyncResult on success/failure

  // develop-2026-10 ticket 39: every coach write into a `timestamptz` column
  // goes out in UTC. A naive local string (no offset) was stored by Postgres
  // as if it were UTC, hours off in any zone west or east of it.
  group('timestamptz writes go out in UTC', () {
    const coachId = 'c0c0c0c0-0000-4000-8000-000000000001';
    const athleteId = 'a0a0a0a0-0000-4000-8000-000000000002';

    late AppDatabase database;
    late FakePostgrest server;
    late CoachRepository repo;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      server = FakePostgrest();
      repo = CoachRepository(
        supabase: server.client,
        database: database,
        report: RecordingReport(),
      );
    });

    Map<String, dynamic> lastBody(String table) {
      final write = server.writes.lastWhere((w) => w.table == table);
      final body = write.body is List
          ? (write.body as List).single
          : write.body;
      return (body as Map).cast<String, dynamic>();
    }

    void expectUtcWithin(
      Map<String, dynamic> body,
      List<String> keys,
      DateTime before,
      DateTime after,
    ) {
      for (final key in keys) {
        final sent = body[key] as String;
        expect(sent, endsWith('Z'), reason: '$key carries its offset');
        final at = DateTime.parse(sent);
        expect(at.isBefore(before), isFalse, reason: key);
        expect(at.isAfter(after), isFalse, reason: key);
      }
    }

    test('createRelationship sends the same instant it returns', () async {
      final created = await repo.createRelationship(
        coachUserId: coachId,
        athleteUserId: athleteId,
        requestedBy: 'coach',
      );

      final body = lastBody('coach_athlete_relationships');
      for (final key in [
        'requested_at',
        'accepted_at',
        'created_at',
        'updated_at',
      ]) {
        final sent = body[key] as String;
        expect(sent, endsWith('Z'), reason: '$key carries its offset');
        expect(
          DateTime.parse(sent).isAtSameMomentAs(created.requestedAt),
          isTrue,
          reason: key,
        );
      }
    });

    test('accept, decline and archive send UTC', () async {
      final created = await repo.createRelationship(
        coachUserId: coachId,
        athleteUserId: athleteId,
        requestedBy: 'athlete',
      );

      var before = DateTime.now();
      await repo.acceptRelationship(created.id);
      expectUtcWithin(
        lastBody('coach_athlete_relationships'),
        ['accepted_at', 'updated_at'],
        before,
        DateTime.now(),
      );

      before = DateTime.now();
      await repo.declineRelationship(created.id);
      expectUtcWithin(
        lastBody('coach_athlete_relationships'),
        ['declined_at', 'updated_at'],
        before,
        DateTime.now(),
      );

      before = DateTime.now();
      await repo.archiveRelationship(created.id);
      expectUtcWithin(
        lastBody('coach_athlete_relationships'),
        ['archived_at', 'updated_at'],
        before,
        DateTime.now(),
      );
    });

    test('athlete profile and nutrition-target edits send users.updated_at '
        'in UTC', () async {
      var before = DateTime.now();
      await repo.updateAthleteProfile(
        athleteUserId: athleteId,
        firstName: 'Ana',
      );
      expectUtcWithin(
        lastBody('users'),
        ['updated_at'],
        before,
        DateTime.now(),
      );

      before = DateTime.now();
      await repo.updateAthleteNutritionTargets(
        athleteUserId: athleteId,
        overridesJson: null,
      );
      expectUtcWithin(
        lastBody('users'),
        ['updated_at'],
        before,
        DateTime.now(),
      );
    });

    test('submitCoachApplication sends UTC', () async {
      final before = DateTime.now();
      final ok = await repo.submitCoachApplication(
        userId: coachId,
        firstName: 'Cora',
        lastName: 'Coach',
        email: 'cora@example.com',
      );
      expect(ok, isTrue);
      expectUtcWithin(
        lastBody('coaches'),
        ['submitted_at', 'created_at', 'updated_at'],
        before,
        DateTime.now(),
      );
    });
  });
}
