import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mealvana_endurance/features/food_preferences/data/food_preferences_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes/fake_postgrest.dart';
import '../helpers/fakes/recording_report.dart';

// Mocks
class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late AppDatabase database;
  late RecordingReport report;

  const testUserId = 'test-user-123';

  setUp(() async {
    // Initialize SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});

    // Create in-memory database
    database = AppDatabase.forTesting(NativeDatabase.memory());

    // Create mocks
    report = RecordingReport();

    // Set up Sentry to not throw on method calls
  });

  tearDown(() async {
    await database.close();
  });

  group('SyncableRepository Interface', () {
    test('repositoryKey should return "food_preferences"', () {
      final mockSupabase = MockSupabaseClient();
      final repository = FoodPreferencesRepository(
        supabase: mockSupabase,
        database: database,
        report: report,
      );

      expect(repository.repositoryKey, 'food_preferences');
    });

    test('dependencies should return ["users", "template_foods"]', () {
      final mockSupabase = MockSupabaseClient();
      final repository = FoodPreferencesRepository(
        supabase: mockSupabase,
        database: database,
        report: report,
      );

      expect(repository.dependencies, ['users', 'template_foods']);
    });

    test('isStale should return true when never synced', () async {
      final mockSupabase = MockSupabaseClient();
      final repository = FoodPreferencesRepository(
        supabase: mockSupabase,
        database: database,
        report: report,
      );

      final isStale = await repository.isStale();
      expect(isStale, true);
    });

    test('isStale should return false when synced recently', () async {
      final mockSupabase = MockSupabaseClient();
      final repository = FoodPreferencesRepository(
        supabase: mockSupabase,
        database: database,
        report: report,
      );

      await repository.setLastSyncTime(DateTime.now());
      final isStale = await repository.isStale();
      expect(isStale, false);
    });

    test(
      'isStale should return true when synced more than 24 hours ago',
      () async {
        final mockSupabase = MockSupabaseClient();
        final repository = FoodPreferencesRepository(
          supabase: mockSupabase,
          database: database,
          report: report,
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
      final repository = FoodPreferencesRepository(
        supabase: mockSupabase,
        database: database,
        report: report,
      );

      final timestamp = await repository.getLastSyncTime();
      expect(timestamp, null);
    });

    test('setLastSyncTime and getLastSyncTime should work correctly', () async {
      final mockSupabase = MockSupabaseClient();
      final repository = FoodPreferencesRepository(
        supabase: mockSupabase,
        database: database,
        report: report,
      );

      final now = DateTime.now();
      await repository.setLastSyncTime(now);

      final retrieved = await repository.getLastSyncTime();
      expect(retrieved, isNotNull);
      expect(retrieved!.difference(now).inSeconds, lessThan(1));
    });
  });

  group('uploadDirtyRecords', () {
    test('should return nothingToUpload when no preferences exist', () async {
      final mockSupabase = MockSupabaseClient();
      final repository = FoodPreferencesRepository(
        supabase: mockSupabase,
        database: database,
        report: report,
      );

      // Act
      final result = await repository.uploadDirtyRecords(testUserId);

      // Assert
      expect(result.success, true);
      expect(result.count, 0);
    });
  });

  // NOTE: Tests for syncFromRemote() and uploadDirtyRecords() with actual Supabase
  // operations are skipped due to the complexity of mocking the Supabase fluent API.
  // These will be tested via integration tests with real Supabase instances.
  //
  // The following functionality is implemented but not unit tested:
  // - syncFromRemote(): Fetches food preferences from Supabase and saves to Drift
  // - uploadDirtyRecords(): Uploads all food preferences to Supabase
  // - Error handling for network failures
  //
  // Integration tests should cover:
  // - Full sync cycle (upload preferences → sync fresh data)
  // - Network error handling and retry logic
  // - Data consistency between Drift and Supabase
  // - Merge mode behavior when syncing from server

  // develop-2026-10 ticket 39: food_preferences.created_at/updated_at are
  // timestamptz. Drift reads them back local; the upload now sends UTC.
  group('timestamptz writes go out in UTC', () {
    // Whole seconds: Drift keeps epoch seconds.
    final createdAtUtc = DateTime.utc(2026, 10, 7, 11, 11, 3);
    final updatedAtUtc = DateTime.utc(2026, 10, 8, 2, 40, 9);

    Map<String, dynamic> firstRow(Object? raw) =>
        ((raw is List ? raw.first : raw) as Map).cast<String, dynamic>();

    test('uploadDirtyRecords sends the stored instants, ending in Z', () async {
      final server = FakePostgrest();
      final repository = FoodPreferencesRepository(
        supabase: server.client,
        database: database,
        report: report,
      );
      await database
          .into(database.foodPreferencesTable)
          .insert(
            FoodPreferencesTableCompanion.insert(
              id: '11111111-2222-4333-8444-555555555555',
              userId: testUserId,
              foodName: 'Banana',
              preference: 'like',
              createdAt: Value(createdAtUtc),
              updatedAt: Value(updatedAtUtc),
            ),
          );
      // uploadDirtyRecords sends only while the pending flag is set (ticket 58).
      SharedPreferences.setMockInitialValues({
        foodPreferencesUploadPendingKey(testUserId): true,
      });

      final result = await repository.uploadDirtyRecords(testUserId);
      expect(result.success, isTrue);

      final sent = firstRow(
        server.writes.singleWhere((w) => w.table == 'food_preferences').body,
      );
      for (final (key, instant) in [
        ('created_at', createdAtUtc),
        ('updated_at', updatedAtUtc),
      ]) {
        final value = sent[key] as String;
        expect(value, endsWith('Z'), reason: '$key carries its offset');
        expect(DateTime.parse(value).isAtSameMomentAs(instant), isTrue);
      }
    });

    test('a local edit\'s immediate upload sends UTC', () async {
      final server = FakePostgrest();
      final repository = FoodPreferencesRepository(
        supabase: server.client,
        database: database,
        report: report,
      );
      // Drift truncates to whole seconds.
      final before = DateTime.now().subtract(const Duration(seconds: 1));

      await repository.saveFoodPreferences(testUserId, {
        'Banana': FoodPreference.like,
      });
      await FoodPreferencesRepository.inFlightUploadFor(testUserId);

      final sent = firstRow(
        server.writes.singleWhere((w) => w.table == 'food_preferences').body,
      );
      for (final key in ['created_at', 'updated_at']) {
        final value = sent[key] as String;
        expect(value, endsWith('Z'), reason: '$key carries its offset');
        final at = DateTime.parse(value);
        expect(at.isBefore(before), isFalse, reason: key);
        expect(at.isAfter(DateTime.now()), isFalse, reason: key);
      }
    });
  });

  // develop-2026-10 ticket 58: one immediate upload in flight per user; a
  // save during it reruns it once, so the last save's rows go last.
  group('immediate uploads are serialised', () {
    Map<String, Object?> rowFor(Object? body, String food) =>
        ((body as List).cast<Map>().singleWhere(
          (r) => r['food_name'] == food,
        )).cast<String, Object?>();

    test('two saves at once send the second save\'s rows last', () async {
      final server = FakePostgrest();
      final repository = FoodPreferencesRepository(
        supabase: server.client,
        database: database,
        report: report,
      );

      final first = repository.saveFoodPreferences(
        testUserId,
        {'sports_drink': FoodPreference.like},
        sliderLevels: {'sports_drink': 3},
        mergeMode: true,
        upload: true,
      );
      final second = repository.saveFoodPreferences(
        testUserId,
        {'sports_drink': FoodPreference.like},
        sliderLevels: {'sports_drink': 4},
        mergeMode: true,
        upload: true,
      );
      await Future.wait([first, second]);
      await FoodPreferencesRepository.inFlightUploadFor(testUserId);

      final writes = server.writes
          .where((w) => w.table == 'food_preferences')
          .toList();
      expect(writes.length, inInclusiveRange(1, 2));
      expect(rowFor(writes.last.body, 'sports_drink')['preference_level'], 4);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(foodPreferencesUploadPendingKey(testUserId)),
        isNull,
        reason: 'the last pass landed, so nothing is pending',
      );
    });

    test('a save while an upload is in flight reruns it once', () async {
      final server = FakePostgrest();
      final repository = FoodPreferencesRepository(
        supabase: server.client,
        database: database,
        report: report,
      );

      // Both saves are issued before either's upload can finish, so the
      // second finds the first's upload in flight and owes it one rerun.
      await Future.wait([
        repository.saveFoodPreferences(
          testUserId,
          {'gel': FoodPreference.like},
          sliderLevels: {'gel': 3},
          mergeMode: true,
          upload: true,
        ),
        repository.saveFoodPreferences(
          testUserId,
          {'gel': FoodPreference.dislike},
          sliderLevels: {'gel': 0},
          mergeMode: true,
          upload: true,
        ),
      ]);
      await FoodPreferencesRepository.inFlightUploadFor(testUserId);

      final writes = server.writes
          .where((w) => w.table == 'food_preferences')
          .toList();
      expect(writes, hasLength(2), reason: 'the first pass plus one rerun');
      expect(rowFor(writes.last.body, 'gel')['preference_level'], 0);
      expect(FoodPreferencesRepository.inFlightUploadFor(testUserId), isNull);
    });
  });

  // develop-2026-10 ticket 58 review: the dirty walk's upload must not clear
  // the pending flag a save set while it ran, when that save's own immediate
  // upload was refused.
  group('dirty walk vs a save mid-upload', () {
    test(
      'a save mid-walk whose upload is refused leaves the flag set',
      () async {
        final walkArrived = Completer<void>();
        final releaseWalk = Completer<void>();
        var writes = 0;
        final client = SupabaseClient(
          'http://fake-postgrest.test',
          'anon-key',
          httpClient: MockClient((request) async {
            final headers = {'content-type': 'application/json'};
            if (request.method == 'GET') {
              return http.Response(
                '[]',
                200,
                request: request,
                headers: headers,
              );
            }
            writes++;
            if (writes == 1) {
              // The walk's upload: held until the save's upload is refused.
              walkArrived.complete();
              await releaseWalk.future;
              return http.Response(
                request.body,
                201,
                request: request,
                headers: headers,
              );
            }
            return http.Response(
              jsonEncode({
                'code': '42501',
                'message': 'new row violates row-level security policy',
                'details': null,
                'hint': null,
              }),
              403,
              request: request,
              headers: headers,
            );
          }),
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        final repository = FoodPreferencesRepository(
          supabase: client,
          database: database,
          report: report,
        );
        await database
            .into(database.foodPreferencesTable)
            .insert(
              FoodPreferencesTableCompanion.insert(
                id: '11111111-2222-4333-8444-555555555555',
                userId: testUserId,
                foodName: 'banana',
                preference: 'like',
              ),
            );
        SharedPreferences.setMockInitialValues({
          foodPreferencesUploadPendingKey(testUserId): true,
        });

        final walk = repository.uploadDirtyRecords(testUserId);
        await walkArrived.future;

        await repository.saveFoodPreferences(
          testUserId,
          {'gel': FoodPreference.dislike},
          sliderLevels: {'gel': 0},
          mergeMode: true,
          upload: true,
        );
        await FoodPreferencesRepository.inFlightUploadFor(testUserId);

        releaseWalk.complete();
        final result = await walk;
        expect(result.success, isTrue);

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool(foodPreferencesUploadPendingKey(testUserId)),
          isTrue,
          reason: 'the gel edit never reached the server',
        );
      },
    );
  });
}
