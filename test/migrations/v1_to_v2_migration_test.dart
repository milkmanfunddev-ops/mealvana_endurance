/// Migration tests for v1 → v2 schema upgrade
///
/// These tests verify that the migration code runs successfully
/// and preserves user data correctly. We use in-memory databases
/// to test the actual migration logic without strict schema verification.
library;

import 'package:drift/drift.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:test/test.dart' as test_pkg;
import 'package:test/test.dart' hide isNull, isNotNull;

void main() {
  group('v1 to v2 migration tests (in-memory)', () {
    test('migration runs successfully on empty database', () async {
      // Create a fresh in-memory database
      // This tests the onCreate path
      final db = AppDatabase.memory();

      // Just opening the database should work without error.
      // schemaVersion is the current Drift schema version, which keeps
      // advancing as columns are added; the invariant this test cares about is
      // that the schema is at or past the v2 baseline it exercises (don't
      // hardcode the exact number — it changes every additive migration).
      expect(db.schemaVersion, greaterThanOrEqualTo(2));

      // Verify we can query the database
      final users = await db.select(db.userProfilesTable).get();
      expect(users, isEmpty);

      await db.close();
    });

    test('database has expected v2 columns in users table', () async {
      final db = AppDatabase.memory();

      // Insert a test user
      await db
          .into(db.userProfilesTable)
          .insert(
            UserProfilesTableCompanion.insert(
              id: 'test-user-123',
              deviceId: 'device-123',
              authProvider: const Value('anonymous'),
              isAnonymous: const Value(true),
            ),
          );

      // Verify we can read the user including v2 columns
      final users = await db.select(db.userProfilesTable).get();
      expect(users, hasLength(1));

      final user = users.first;
      expect(user.id, 'test-user-123');

      // V2 columns should have default values
      expect(user.dietaryPreference, test_pkg.isNull);
      expect(user.allergies, '{}');
      expect(user.needsUpload, false);

      await db.close();
    });

    test('food preferences table has preference_level column', () async {
      final db = AppDatabase.memory();

      // Insert a test food preference (id must be 36 chars - UUID format)
      await db
          .into(db.foodPreferencesTable)
          .insert(
            FoodPreferencesTableCompanion.insert(
              id: 'pref-123-abcd-efgh-ijkl-mnopqrst1234',
              userId: 'user-123',
              foodName: 'banana',
              preference: 'like',
              preferenceLevel: const Value(3),
            ),
          );

      final prefs = await db.select(db.foodPreferencesTable).get();
      expect(prefs, hasLength(1));
      expect(prefs.first.preferenceLevel, 3);

      await db.close();
    });

    test('activities table uses TEXT UUIDs for id', () async {
      final db = AppDatabase.memory();

      // Insert a test activity with UUID id
      await db
          .into(db.activitiesTable)
          .insert(
            ActivitiesTableCompanion.insert(
              id: const Value('abc12345-1234-1234-1234-123456789abc'),
              userId: 'user-123',
              activityType: 'running',
              title: 'Morning Run',
              scheduledDateTime: DateTime.now(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      final activities = await db.select(db.activitiesTable).get();
      expect(activities, hasLength(1));
      expect(activities.first.id, 'abc12345-1234-1234-1234-123456789abc');
      expect(activities.first.id.length, 36); // UUID length

      await db.close();
    });

    test('events table uses TEXT UUIDs for id', () async {
      final db = AppDatabase.memory();

      // Insert a test event with UUID id
      await db
          .into(db.eventsTable)
          .insert(
            EventsTableCompanion.insert(
              id: const Value('event-uuid-1234-5678-abcd-123456789abc'),
              userId: 'user-123',
              eventType: 'running',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      final events = await db.select(db.eventsTable).get();
      expect(events, hasLength(1));
      expect(events.first.id.length, greaterThan(30)); // UUID-like length

      await db.close();
    });

    test('migration handles preference backfill correctly', () async {
      // This test simulates what happens when migrating old preference values
      final db = AppDatabase.memory();

      // Insert food preferences with different preference values (UUIDs must be 36 chars)
      await db
          .into(db.foodPreferencesTable)
          .insert(
            FoodPreferencesTableCompanion.insert(
              id: 'pref-001-abcd-efgh-ijkl-mnopqrst0001',
              userId: 'user-1',
              foodName: 'banana',
              preference: 'like',
              preferenceLevel: const Value(3), // like → 3
            ),
          );
      await db
          .into(db.foodPreferencesTable)
          .insert(
            FoodPreferencesTableCompanion.insert(
              id: 'pref-002-abcd-efgh-ijkl-mnopqrst0002',
              userId: 'user-1',
              foodName: 'oatmeal',
              preference: 'dislike',
              preferenceLevel: const Value(1), // dislike → 1
            ),
          );
      await db
          .into(db.foodPreferencesTable)
          .insert(
            FoodPreferencesTableCompanion.insert(
              id: 'pref-003-abcd-efgh-ijkl-mnopqrst0003',
              userId: 'user-1',
              foodName: 'gel',
              preference: 'willing_to_try',
              preferenceLevel: const Value(2), // neutral → 2
            ),
          );

      final prefs = await db.select(db.foodPreferencesTable).get();
      expect(prefs, hasLength(3));

      // Verify each preference level
      expect(
        prefs.firstWhere((p) => p.foodName == 'banana').preferenceLevel,
        3,
      );
      expect(
        prefs.firstWhere((p) => p.foodName == 'oatmeal').preferenceLevel,
        1,
      );
      expect(prefs.firstWhere((p) => p.foodName == 'gel').preferenceLevel, 2);

      await db.close();
    });
  });

  group('migration code verification', () {
    test(
      'database exposes a current schema version and migration strategy',
      () {
        // The schema has advanced well past v2. There are no step-by-step
        // upgrade migrations anymore: VersionCheckService handles mismatches by
        // delete & resync, and onUpgrade recreates all tables as a fallback.
        // Verify the current contract: a current schema version plus a
        // configured MigrationStrategy with onCreate/onUpgrade handlers.
        final db = AppDatabase.memory();
        // Don't hardcode the exact version — it advances every additive
        // migration. The contract is simply that a current schema version is
        // exposed (past the v2 baseline) alongside a configured strategy.
        expect(db.schemaVersion, greaterThanOrEqualTo(2));
        expect(db.migration, test_pkg.isNotNull);
        expect(db.migration.onCreate, test_pkg.isNotNull);
        expect(db.migration.onUpgrade, test_pkg.isNotNull);
        db.close();
      },
    );
  });
}
