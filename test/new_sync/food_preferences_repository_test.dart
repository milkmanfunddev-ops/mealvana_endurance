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
      final value = sent['updated_at'] as String;
      expect(value, endsWith('Z'), reason: 'updated_at carries its offset');
      expect(DateTime.parse(value).isAtSameMomentAs(updatedAtUtc), isTrue);
      // Ticket 78: the server keeps its own id and created_at.
      expect(sent.containsKey('created_at'), isFalse);
      expect(sent.containsKey('id'), isFalse);
      expect(createdAtUtc.isUtc, isTrue);
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
      final value = sent['updated_at'] as String;
      expect(value, endsWith('Z'), reason: 'updated_at carries its offset');
      final at = DateTime.parse(value);
      expect(at.isBefore(before), isFalse);
      expect(at.isAfter(DateTime.now()), isFalse);
      expect(sent.containsKey('created_at'), isFalse, reason: 'ticket 78');
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

  // develop-2026-10 ticket 78 (Finding 68-001): a merge keeps local ids, and
  // the upload sends only the pending foods, without id or created_at.
  group('pending foods only (ticket 78)', () {
    Iterable<Map<String, dynamic>> rows(FakePostgrest server) => server.writes
        .where((w) => w.table == 'food_preferences')
        .expand((w) => (w.body as List).cast<Map>())
        .map((m) => m.cast<String, dynamic>());

    Future<void> seedLocal(String id, String food, int level) => database
        .into(database.foodPreferencesTable)
        .insert(
          FoodPreferencesTableCompanion.insert(
            id: id,
            userId: testUserId,
            foodName: food,
            preference: level <= 1
                ? 'dislike'
                : level >= 3
                ? 'like'
                : 'willing_to_try',
            preferenceLevel: Value(level),
            createdAt: Value(DateTime.utc(2026, 10, 8, 17, 23, 53)),
            updatedAt: Value(DateTime.utc(2026, 10, 8, 17, 23, 53)),
          ),
        );

    Future<FoodPreferenceEntry> local(String food) async =>
        (await database.foodPreferencesDao.getAllFoodPreferenceEntries(
          testUserId,
        )).singleWhere((r) => r.foodName == food);

    test('a pull keeps the local id of a row that already existed, and the '
        'server\'s source', () async {
      await seedLocal(
        '11111111-2222-4333-8444-555555555555',
        'sports_drink',
        4,
      );
      final server = FakePostgrest();
      server.tables['food_preferences'] = [
        {
          'id': 'f410fe6a-37c5-4efd-ac84-7cd145db900f',
          'user_id': testUserId,
          'food_name': 'sports_drink',
          'preference': 'like',
          'preference_level': 3,
          'preference_source': 'manual',
          'created_at': '2026-10-08 17:23:53+00',
          'updated_at': '2026-10-08 23:16:23+00',
        },
        {
          'id': '9a715ab3-7699-4d39-a816-a6293132ea74',
          'user_id': testUserId,
          'food_name': 'energy_bar',
          'preference': 'dislike',
          'preference_level': 0,
          'preference_source': 'allergy:gluten',
          'created_at': '2026-10-08 17:23:53+00',
          'updated_at': '2026-10-08 17:23:53+00',
        },
      ];
      final repository = FoodPreferencesRepository(
        supabase: server.client,
        database: database,
        report: report,
      );

      final result = await repository.syncFromRemote(testUserId);
      expect(result.success, isTrue);

      final drink = await local('sports_drink');
      expect(drink.id, '11111111-2222-4333-8444-555555555555');
      expect(
        drink.createdAt.isAtSameMomentAs(DateTime.utc(2026, 10, 8, 17, 23, 53)),
        isTrue,
      );
      expect(drink.preferenceLevel, 3);
      expect((await local('energy_bar')).preferenceSource, 'allergy:gluten');
      expect(rows(server), isEmpty, reason: 'a pull uploads nothing');
    });

    test('two saves of different foods while the first upload is in flight: '
        'the rerun sends both, and the names clear only after it', () async {
      final firstArrived = Completer<void>();
      final releaseFirst = Completer<void>();
      final bodies = <List<Map<String, dynamic>>>[];
      final client = SupabaseClient(
        'http://fake-postgrest.test',
        'anon-key',
        httpClient: MockClient((request) async {
          final headers = {'content-type': 'application/json'};
          if (request.method != 'GET') {
            bodies.add(
              (jsonDecode(request.body) as List)
                  .cast<Map>()
                  .map((m) => m.cast<String, dynamic>())
                  .toList(),
            );
            if (bodies.length == 1) {
              firstArrived.complete();
              await releaseFirst.future;
            }
          }
          return http.Response('[]', 201, request: request, headers: headers);
        }),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final repository = FoodPreferencesRepository(
        supabase: client,
        database: database,
        report: report,
      );

      await repository.saveFoodPreferences(
        testUserId,
        {'sports_drink': FoodPreference.like},
        sliderLevels: {'sports_drink': 3},
        mergeMode: true,
        upload: true,
      );
      await firstArrived.future;
      await repository.saveFoodPreferences(
        testUserId,
        {'granola_bar': FoodPreference.like},
        sliderLevels: {'granola_bar': 3},
        mergeMode: true,
        upload: true,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(foodPreferencesUploadPendingNamesKey(testUserId)),
        unorderedEquals(['sports_drink', 'granola_bar']),
      );

      releaseFirst.complete();
      await FoodPreferencesRepository.inFlightUploadFor(testUserId);

      expect(bodies, hasLength(2));
      expect(bodies.first.map((r) => r['food_name']), ['sports_drink']);
      expect(
        bodies.last.map((r) => r['food_name']),
        unorderedEquals(['sports_drink', 'granola_bar']),
      );
      expect(
        prefs.getBool(foodPreferencesUploadPendingKey(testUserId)),
        isNull,
      );
      expect(
        prefs.getStringList(foodPreferencesUploadPendingNamesKey(testUserId)),
        isNull,
      );
    });

    test('a refused upload keeps the names and the flag; the next dirty walk '
        'sends only those foods', () async {
      await seedLocal('22222222-2222-4333-8444-555555555555', 'banana', 2);
      final server = FakePostgrest()..rejectWrites.add('food_preferences');
      final repository = FoodPreferencesRepository(
        supabase: server.client,
        database: database,
        report: report,
      );

      await repository.saveFoodPreferences(
        testUserId,
        {'sports_drink': FoodPreference.like},
        sliderLevels: {'sports_drink': 3},
        mergeMode: true,
        upload: true,
      );
      await FoodPreferencesRepository.inFlightUploadFor(testUserId);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(foodPreferencesUploadPendingKey(testUserId)),
        isTrue,
      );
      expect(
        prefs.getStringList(foodPreferencesUploadPendingNamesKey(testUserId)),
        ['sports_drink'],
      );

      server.rejectWrites.clear();
      server.writes.clear();
      final result = await repository.uploadDirtyRecords(testUserId);
      expect(result.success, isTrue);
      expect(result.count, 1);
      final sent = rows(server).toList();
      expect(sent.map((r) => r['food_name']), ['sports_drink']);
      expect(sent.single.containsKey('id'), isFalse);
      expect(sent.single.containsKey('created_at'), isFalse);
      expect(
        prefs.getBool(foodPreferencesUploadPendingKey(testUserId)),
        isNull,
      );
      expect(
        prefs.getStringList(foodPreferencesUploadPendingNamesKey(testUserId)),
        isNull,
      );
    });

    test('the flag set with no names list (upgraded mid-pending) sends every '
        'local row once, without id or created_at', () async {
      await seedLocal('22222222-2222-4333-8444-555555555555', 'banana', 2);
      await seedLocal('33333333-2222-4333-8444-555555555555', 'gel', 4);
      SharedPreferences.setMockInitialValues({
        foodPreferencesUploadPendingKey(testUserId): true,
      });
      final server = FakePostgrest();
      final repository = FoodPreferencesRepository(
        supabase: server.client,
        database: database,
        report: report,
      );

      final result = await repository.uploadDirtyRecords(testUserId);
      expect(result.count, 2);
      final sent = rows(server).toList();
      expect(
        sent.map((r) => r['food_name']),
        unorderedEquals(['banana', 'gel']),
      );
      for (final row in sent) {
        expect(row.keys, isNot(contains('id')));
        expect(row.keys, isNot(contains('created_at')));
        expect(row['user_id'], testUserId);
        expect(row['preference_source'], 'manual');
      }
    });

    test('a save on a phone upgraded mid-pending keeps every old row '
        'pending', () async {
      await seedLocal('22222222-2222-4333-8444-555555555555', 'banana', 2);
      SharedPreferences.setMockInitialValues({
        foodPreferencesUploadPendingKey(testUserId): true,
      });
      final server = FakePostgrest()..rejectWrites.add('food_preferences');
      final repository = FoodPreferencesRepository(
        supabase: server.client,
        database: database,
        report: report,
      );

      await repository.saveFoodPreferences(
        testUserId,
        {'gel': FoodPreference.like},
        sliderLevels: {'gel': 3},
        mergeMode: true,
        upload: true,
      );
      await FoodPreferencesRepository.inFlightUploadFor(testUserId);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(foodPreferencesUploadPendingNamesKey(testUserId)),
        unorderedEquals(['banana', 'gel']),
      );
    });
  });
}
