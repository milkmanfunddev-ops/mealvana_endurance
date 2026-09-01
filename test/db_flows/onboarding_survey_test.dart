/// Drift-level tests for the v16 `onboarding_surveys` table: insert/update
/// round-trip, temp→real user migration, v16 onUpgrade idempotency, and the
/// loud-failure contract on constraint violations.
library;

import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/daos/diagnostic_dao.dart';

void main() {
  group('onboarding_surveys table', () {
    late AppDatabase database;

    setUp(() => database = AppDatabase.memory());
    tearDown(() => database.close());

    OnboardingSurveysTableCompanion survey(
      String userId, {
      List<String> sports = const ['running'],
      List<String> goals = const ['performance'],
      List<String> pitfalls = const ['energy_crash'],
      String? payload,
    }) {
      final now = DateTime(2026, 8, 6, 12);
      return OnboardingSurveysTableCompanion.insert(
        userId: userId,
        sports: jsonEncode(sports),
        goals: jsonEncode(goals),
        pitfalls: jsonEncode(pitfalls),
        surveyPayload: Value(payload),
        completedAt: now,
        createdAt: now,
        updatedAt: now,
        needsUpload: const Value(true),
        localUpdatedAt: Value(now),
      );
    }

    test('insert and read back round-trips all fields', () async {
      await database
          .into(database.onboardingSurveysTable)
          .insert(
            survey(
              'user-1',
              sports: ['running', 'triathlon'],
              goals: ['performance', 'eat_healthier'],
              pitfalls: ['gut_issues'],
              payload: '{"tridot_notify":true}',
            ),
          );

      final row = await (database.select(
        database.onboardingSurveysTable,
      )..where((t) => t.userId.equals('user-1'))).getSingle();

      expect(jsonDecode(row.sports), ['running', 'triathlon']);
      expect(jsonDecode(row.goals), ['performance', 'eat_healthier']);
      expect(jsonDecode(row.pitfalls), ['gut_issues']);
      expect(jsonDecode(row.surveyPayload!), {'tridot_notify': true});
      expect(row.needsUpload, isTrue);
    });

    test(
      'user_id is the PK: re-onboarding replaces, never duplicates',
      () async {
        await database
            .into(database.onboardingSurveysTable)
            .insert(survey('user-1'));
        await database
            .into(database.onboardingSurveysTable)
            .insert(
              survey('user-1', sports: ['cycling']),
              mode: InsertMode.insertOrReplace,
            );

        final rows = await database
            .select(database.onboardingSurveysTable)
            .get();
        expect(rows, hasLength(1));
        expect(jsonDecode(rows.single.sports), ['cycling']);
      },
    );

    test(
      'plain insert of a duplicate user_id fails loudly, not silently',
      () async {
        await database
            .into(database.onboardingSurveysTable)
            .insert(survey('user-1'));

        await expectLater(
          database
              .into(database.onboardingSurveysTable)
              .insert(survey('user-1')),
          throwsA(anything),
          reason: 'constraint violations must surface, not vanish',
        );
      },
    );

    test('migrateUserData moves the survey row temp → real', () async {
      final dao = DiagnosticDao(database);

      // Anonymous temp user finished onboarding; a stale row exists for the
      // target (previous account state) and must be replaced.
      await database
          .into(database.onboardingSurveysTable)
          .insert(survey('temp-user', sports: ['triathlon']));
      await database
          .into(database.onboardingSurveysTable)
          .insert(survey('real-user', sports: ['running']));

      await dao.migrateUserData('temp-user', 'real-user');

      final rows = await database.select(database.onboardingSurveysTable).get();
      expect(rows, hasLength(1));
      expect(rows.single.userId, 'real-user');
      expect(jsonDecode(rows.single.sports), ['triathlon']);
    });

    test(
      're-running the v16 onUpgrade step is a no-op (web replay safety)',
      () async {
        // onCreate builds the current schema, so the table already exists.
        await expectLater(
          database.migration.onUpgrade!(
            database.createMigrator(),
            15,
            database.schemaVersion,
          ),
          completes,
        );
        // Run it twice — ensureTable must skip both times.
        await expectLater(
          database.migration.onUpgrade!(
            database.createMigrator(),
            15,
            database.schemaVersion,
          ),
          completes,
        );

        final rows = await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name = 'onboarding_surveys'",
            )
            .get();
        expect(rows, isNotEmpty);
      },
    );
  });
}
