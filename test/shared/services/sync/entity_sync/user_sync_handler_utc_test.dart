/// [UserSyncHandler]'s writes into `timestamptz` columns go out in UTC
/// (develop-2026-10 ticket 39). Drift reads its epoch columns back as local
/// time; an ISO string from a local DateTime carries no offset, so Postgres
/// stored the wall clock as if it were UTC.
///
/// Seam: rows written to an in-memory Drift database, read back and uploaded
/// through the real handler against [FakePostgrest], which records the body.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/sync/entity_sync/user_sync_handler.dart';

import '../../../../helpers/fakes/fake_postgrest.dart';
import '../../../../helpers/fakes/recording_report.dart';

void main() {
  const userId = '3d4e5f6a-7b8c-4d9e-8f0a-1b2c3d4e5f6a';
  // Whole seconds: Drift keeps epoch seconds.
  final createdAtUtc = DateTime.utc(2026, 10, 7, 11, 11, 3);
  final updatedAtUtc = DateTime.utc(2026, 10, 8, 2, 40, 9);

  late AppDatabase database;
  late FakePostgrest server;
  late UserSyncHandler handler;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    server = FakePostgrest();
    handler = UserSyncHandler(
      database: database,
      supabase: server.client,
      report: RecordingReport(),
    );
  });

  Map<String, dynamic> body(Object? raw) =>
      ((raw is List ? raw.first : raw) as Map).cast<String, dynamic>();

  test('uploadFoodPreferences sends created_at and updated_at as the stored '
      'instants, ending in Z', () async {
    await database
        .into(database.foodPreferencesTable)
        .insert(
          FoodPreferencesTableCompanion.insert(
            id: '11111111-2222-4333-8444-555555555555',
            userId: userId,
            foodName: 'Banana',
            preference: 'like',
            createdAt: Value(createdAtUtc),
            updatedAt: Value(updatedAtUtc),
          ),
        );
    final stored = await database.foodPreferencesDao
        .getAllFoodPreferenceEntries(userId);
    expect(stored.single.createdAt.isUtc, isFalse, reason: 'reads back local');

    await handler.uploadFoodPreferences(userId);

    final write = server.writes.singleWhere(
      (w) => w.table == 'food_preferences',
    );
    final sent = body(write.body);
    for (final (key, instant) in [
      ('created_at', createdAtUtc),
      ('updated_at', updatedAtUtc),
    ]) {
      final value = sent[key] as String;
      expect(value, endsWith('Z'), reason: '$key carries its offset');
      expect(DateTime.parse(value).isAtSameMomentAs(instant), isTrue);
    }
  });

  group('users.updated_at', () {
    setUp(() async {
      await database
          .into(database.userProfilesTable)
          .insert(
            UserProfilesTableCompanion.insert(
              id: userId,
              deviceId: userId,
              authUserId: const Value(userId),
            ),
          );
    });

    void expectUtcNow(Map<String, dynamic> sent, DateTime before) {
      final value = sent['updated_at'] as String;
      expect(value, endsWith('Z'));
      final at = DateTime.parse(value);
      expect(at.isBefore(before), isFalse);
      expect(at.isAfter(DateTime.now()), isFalse);
    }

    test('syncUsers sends it in UTC', () async {
      final before = DateTime.now();
      await handler.syncUsers(userId);

      final write = server.writes.lastWhere((w) => w.table == 'users');
      expectUtcNow(body(write.body), before);
    });

    test('uploadUserProfile sends it in UTC', () async {
      final profile = await (database.select(
        database.userProfilesTable,
      )..where((t) => t.id.equals(userId))).getSingle();
      final before = DateTime.now();

      await handler.uploadUserProfile(profile);

      final write = server.writes.lastWhere((w) => w.table == 'users');
      expectUtcNow(body(write.body), before);
    });
  });
}
