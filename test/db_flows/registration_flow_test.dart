/// Registration / sign-in data-persistence tests.
///
/// Pins the 2026-08 fixes for onboarding data being dropped at the auth
/// boundary:
///  1. `UserSyncHandler.saveRemoteUserProfile` must NOT overwrite a dirty
///     (needs_upload) local profile with the server row, and when it does
///     hydrate it must carry EVERY column — the old partial companion reset
///     unit_system, sweat_rate, dietary preference, allergies and the
///     plan-reveal `nutrition_target_overrides` to table defaults, and forced
///     imperial pace/distance units onto metric athletes.
///  2. The Drift-entry → domain → `toJson()` chain used by both upload paths
///     must include the fields onboarding collects; the old hand-rolled
///     payloads silently omitted them, so the server never learned a new
///     user's name, units, sweat rate or plan edits.
///  3. `UserProfile.fromSupabaseRow` is the one shared remote-row parser and
///     must round-trip those same fields.
///  4. `migrateUserData` moves onboarding rows to the post-auth uid and
///     re-dirties the survey so it re-uploads under the new uid.
///  5. The SyncCoordinator dirty-upload roster must include every repository
///     onboarding writes — `onboarding_surveys` was missing, so a survey
///     whose opportunistic upload failed (e.g. offline signup) never retried.
library;

import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/sync/entity_sync/user_sync_handler.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_coordinator.dart';

import '../helpers/fakes/fake_supabase_client.dart';
import '../helpers/fakes/recording_app_logger.dart';
import '../helpers/fakes/recording_sentry_reporter.dart';

void main() {
  late AppDatabase database;
  late UserSyncHandler handler;

  setUp(() {
    database = AppDatabase.memory();
    handler = UserSyncHandler(
      database: database,
      logger: RecordingAppLogger(),
      // The paths under test never touch the network client.
      supabase: fakeSupabaseClient(),
    );
  });

  tearDown(() => database.close());

  /// A profile row shaped like a just-completed onboarding: sentinel values
  /// chosen so any silent reset to a table default is detectable.
  UserProfilesTableCompanion onboardedProfile(
    String id, {
    bool needsUpload = true,
  }) {
    final now = DateTime(2026, 8, 7, 9);
    return UserProfilesTableCompanion.insert(
      id: id,
      deviceId: id,
      authUserId: Value(id),
      authProvider: const Value('anonymous'),
      isAnonymous: const Value(true),
      gender: const Value('female'),
      birthday: Value(DateTime(1992, 7, 1)),
      heightFeet: const Value(5),
      heightInches: const Value(4),
      weightPounds: const Value(143.3),
      unitSystem: const Value('metric'),
      preferredDistanceUnit: const Value('kilometers'),
      preferredPaceUnit: const Value('minPerKm'),
      gutTrainingLevel: const Value('high'),
      sweatRate: const Value('heavy'),
      dietaryPreference: const Value('vegetarian'),
      allergies: const Value('{dairy}'),
      firstName: const Value('Mika'),
      lastName: const Value('Tan'),
      email: const Value('mika@example.com'),
      nutritionTargetOverrides: Value(
        jsonEncode({
          'duringRun': {'carbRateGPerH': 85.0},
        }),
      ),
      onboardingCompleted: const Value(true),
      createdAt: Value(now),
      updatedAt: Value(now),
      needsUpload: Value(needsUpload),
    );
  }

  Future<UserProfileEntry> profileRow(String id) => (database.select(
    database.userProfilesTable,
  )..where((t) => t.id.equals(id))).getSingle();

  group('saveRemoteUserProfile (post-sign-in hydration)', () {
    test(
      'does NOT overwrite a dirty local profile with the server row',
      () async {
        const userId = '00000000-0000-4000-8000-000000000d17';
        await database
            .into(database.userProfilesTable)
            .insert(onboardedProfile(userId, needsUpload: true));

        // Server still has the pre-onboarding stub for this uid.
        await handler.saveRemoteUserProfile({
          'id': userId,
          'device_id': userId,
          'gender': 'male',
          'birthday': '1990-01-01',
          'height_feet': 5,
          'height_inches': 10,
          'weight_pounds': 150.0,
          'unit_system': 'imperial',
          'sweat_rate': 'medium',
          'onboarding_completed': false,
        }, userId);

        final row = await profileRow(userId);
        expect(row.gender, 'female', reason: 'local dirty row must win');
        expect(row.weightPounds, 143.3);
        expect(row.unitSystem, 'metric');
        expect(row.sweatRate, 'heavy');
        expect(
          row.needsUpload,
          isTrue,
          reason: 'still pending upload — the local copy reconciles upward',
        );
      },
    );

    test(
      'hydrates ALL columns from the remote row (no default resets)',
      () async {
        const userId = '00000000-0000-4000-8000-00000000071d';

        await handler.saveRemoteUserProfile({
          'id': userId,
          'device_id': 'other-device',
          'auth_user_id': userId,
          'auth_provider': 'google',
          'is_anonymous': false,
          'gender': 'female',
          'birthday': '1992-07-01',
          'height_feet': 5,
          'height_inches': 4,
          'weight_pounds': 143.3,
          'unit_system': 'metric',
          'sweat_rate': 'heavy',
          'gut_training_level': 'high',
          'dietary_preference': 'vegetarian',
          'allergies': ['dairy'],
          'first_name': 'Mika',
          'last_name': 'Tan',
          'email': 'mika@example.com',
          'nutrition_target_overrides': {
            'duringRun': {'carbRateGPerH': 85.0},
          },
          'onboarding_completed': true,
          'created_at': '2026-08-01T10:00:00Z',
          'updated_at': '2026-08-07T10:00:00Z',
        }, userId);

        final row = await profileRow(userId);
        expect(row.gender, 'female');
        expect(row.weightPounds, 143.3);
        expect(
          row.unitSystem,
          'metric',
          reason: 'old parser reset metric athletes to imperial',
        );
        expect(
          row.preferredDistanceUnit,
          'kilometers',
          reason: 'old parser hardcoded miles',
        );
        expect(
          row.preferredPaceUnit,
          'minPerKm',
          reason: 'old parser hardcoded minPerMile',
        );
        expect(row.sweatRate, 'heavy');
        expect(row.gutTrainingLevel, 'high');
        expect(row.dietaryPreference, 'vegetarian');
        expect(row.allergies, '{dairy}');
        expect(row.firstName, 'Mika');
        expect(
          jsonDecode(row.nutritionTargetOverrides ?? '{}'),
          containsPair('duringRun', {'carbRateGPerH': 85.0}),
          reason: 'plan-reveal edits must survive hydration',
        );
        expect(row.onboardingCompleted, isTrue);
        expect(row.isAnonymous, isFalse);
        expect(
          row.needsUpload,
          isFalse,
          reason: 'hydration is not a local edit',
        );
      },
    );
  });

  group('upload payload completeness', () {
    test(
      'Drift entry → domain → toJson carries every onboarding field',
      () async {
        const userId = '00000000-0000-4000-8000-000000000a1d';
        await database
            .into(database.userProfilesTable)
            .insert(onboardedProfile(userId));

        final entry = await profileRow(userId);
        final payload = database.userDao.toDomainProfile(entry).toJson();

        // The exact fields the old hand-rolled payloads dropped:
        expect(payload['first_name'], 'Mika');
        expect(payload['last_name'], 'Tan');
        expect(payload['unit_system'], 'metric');
        expect(payload['sweat_rate'], 'heavy');
        expect(
          payload['nutrition_target_overrides'],
          containsPair('duringRun', {'carbRateGPerH': 85.0}),
        );
        // And the ones that were always there, as a canary:
        expect(payload['gender'], 'female');
        expect(payload['weight_pounds'], 143.3);
        expect(payload['gut_training_level'], 'high');
        expect(payload['dietary_preference'], 'vegetarian');
        expect(payload['allergies'], ['dairy']);
        expect(payload['email'], 'mika@example.com');
      },
    );
  });

  group('UserProfile.fromSupabaseRow', () {
    test('round-trips through toJson without losing fields', () {
      final profile = UserProfile.fromSupabaseRow({
        'id': 'u1',
        'device_id': 'u1',
        'gender': 'female',
        'birthday': '1992-07-01',
        'height_feet': 5,
        'height_inches': 4,
        'weight_pounds': 143.3,
        'unit_system': 'metric',
        'sweat_rate': 'heavy',
        'gut_training_level': 'high',
        'first_name': 'Mika',
        'nutrition_target_overrides': {
          'duringRun': {'carbRateGPerH': 85.0},
        },
      }, fallbackId: 'u1');

      expect(profile.unitSystem, UnitSystem.metric);
      expect(profile.sweatRate, SweatRateCat.heavy);
      expect(profile.gutTraining, GutTraining.high);
      expect(profile.firstName, 'Mika');
      expect(profile.nutritionTargetOverrides?.duringRun?.carbRateGPerH, 85.0);

      final json = profile.toJson();
      expect(json['unit_system'], 'metric');
      expect(json['sweat_rate'], 'heavy');
    });

    test('tolerates a sparse legacy row with per-field defaults', () {
      final profile = UserProfile.fromSupabaseRow(const {
        'id': 'legacy',
      }, fallbackId: 'legacy');
      expect(profile.id, 'legacy');
      expect(profile.deviceId, 'legacy');
      expect(profile.unitSystem, UnitSystem.imperial);
      expect(profile.sweatRate, SweatRateCat.medium);
      expect(profile.onboardingCompleted, isFalse);
      expect(
        profile.sweatSodium,
        isNull,
        reason: 'null sweat sodium means algorithmic default — not average',
      );
    });
  });

  group('migrateUserData at the auth boundary', () {
    test('moves the survey to the new uid and re-dirties it', () async {
      const anonId = 'anon-uid';
      const accountId = 'account-uid';
      final now = DateTime(2026, 8, 7, 9);

      await database
          .into(database.onboardingSurveysTable)
          .insert(
            OnboardingSurveysTableCompanion.insert(
              userId: anonId,
              sports: jsonEncode(['running', 'triathlon']),
              goals: jsonEncode(['performance']),
              pitfalls: jsonEncode(['gut_issues']),
              completedAt: now,
              createdAt: now,
              updatedAt: now,
              // Simulate "already uploaded under the anon uid".
              needsUpload: const Value(false),
              localUpdatedAt: Value(now),
            ),
          );

      await database.diagnosticDao.migrateUserData(anonId, accountId);

      final moved = await (database.select(
        database.onboardingSurveysTable,
      )..where((t) => t.userId.equals(accountId))).getSingle();
      expect(jsonDecode(moved.sports), ['running', 'triathlon']);
      expect(
        moved.needsUpload,
        isTrue,
        reason:
            'a survey uploaded under the anon uid is stranded behind RLS — '
            'it must re-upload under the account uid',
      );

      final oldRows = await (database.select(
        database.onboardingSurveysTable,
      )..where((t) => t.userId.equals(anonId))).get();
      expect(oldRows, isEmpty);
    });
  });

  group('saveUserProfile same-device sweep', () {
    /// Minimal domain profile for exercising the DAO directly.
    UserProfile domainProfile(String id, {required String deviceId}) {
      final now = DateTime(2026, 8, 7, 10);
      return UserProfile(
        id: id,
        deviceId: deviceId,
        gender: Gender.male,
        birthday: DateTime(1990, 1, 1),
        heightFeet: 5,
        heightInches: 10,
        weightPounds: 150,
        runsWithWaterBottle: false,
        createdAt: now,
        updatedAt: now,
        appVersion: '1.0.0',
      );
    }

    test('does NOT delete a dirty row sharing the device_id', () async {
      const anonId = '00000000-0000-4000-8000-00000000a201';
      const accountId = '00000000-0000-4000-8000-00000000acc1';
      const sharedDevice = 'device-shared-1';

      // Freshly-onboarded anon profile, not yet uploaded.
      await database
          .into(database.userProfilesTable)
          .insert(
            onboardedProfile(
              anonId,
              needsUpload: true,
            ).copyWith(deviceId: const Value(sharedDevice)),
          );

      // Caching the signed-in account's profile on the same device used to
      // sweep the anon row away — with its un-uploaded onboarding answers.
      await database.userDao.saveUserProfile(
        domainProfile(accountId, deviceId: sharedDevice),
      );

      final anonRow = await (database.select(
        database.userProfilesTable,
      )..where((t) => t.id.equals(anonId))).getSingleOrNull();
      expect(
        anonRow,
        isNotNull,
        reason:
            'a needs_upload row is un-persisted data — the same-device sweep '
            'must not destroy it',
      );
      expect(anonRow!.unitSystem, 'metric');
    });

    test('still sweeps a CLEAN row sharing the device_id', () async {
      const anonId = '00000000-0000-4000-8000-00000000a202';
      const accountId = '00000000-0000-4000-8000-00000000acc2';
      const sharedDevice = 'device-shared-2';

      await database
          .into(database.userProfilesTable)
          .insert(
            onboardedProfile(
              anonId,
              needsUpload: false,
            ).copyWith(deviceId: const Value(sharedDevice)),
          );

      await database.userDao.saveUserProfile(
        domainProfile(accountId, deviceId: sharedDevice),
      );

      final anonRow = await (database.select(
        database.userProfilesTable,
      )..where((t) => t.id.equals(anonId))).getSingleOrNull();
      expect(
        anonRow,
        isNull,
        reason:
            'an uploaded (clean) duplicate for the same device is the case '
            'the sweep exists for',
      );
    });
  });

  group('migrateUserData coverage (2026-08 additions)', () {
    test(
      'moves meal logs, pins and checklists; re-dirties syncables',
      () async {
        const anonId = 'anon-cover-uid';
        const accountId = 'account-cover-uid';
        final now = DateTime(2026, 8, 7, 9);

        await database
            .into(database.mealLogsTable)
            .insert(
              MealLogsTableCompanion.insert(
                id: const Value('meal-1'),
                userId: anonId,
                logDate: '2026-08-07',
                name: 'Oatmeal + banana',
                source: 'manual',
                createdAt: now,
                updatedAt: now,
                // Simulate "already uploaded under the anon uid".
                needsUpload: const Value(false),
              ),
            );
        await database
            .into(database.formulaPinsTable)
            .insert(
              FormulaPinsTableCompanion.insert(
                id: const Value('pin-1'),
                userId: anonId,
                templateId: 'tpl-1',
                templateKind: 'during_system',
                createdAt: now,
                updatedAt: now,
                needsUpload: const Value(false),
              ),
            );
        await database
            .into(database.raceChecklistItemsTable)
            .insert(
              RaceChecklistItemsTableCompanion.insert(
                id: const Value('chk-1'),
                userId: anonId,
                eventId: 'event-1',
                category: 'gear',
                itemName: 'Gels x6',
              ),
            );

        await database.diagnosticDao.migrateUserData(anonId, accountId);

        final meal = await (database.select(
          database.mealLogsTable,
        )..where((t) => t.id.equals('meal-1'))).getSingle();
        expect(meal.userId, accountId);
        expect(
          meal.needsUpload,
          isTrue,
          reason:
              'rows uploaded under the anon uid are stranded behind RLS — the '
              'move must re-dirty them',
        );

        final pin = await (database.select(
          database.formulaPinsTable,
        )..where((t) => t.id.equals('pin-1'))).getSingle();
        expect(pin.userId, accountId);
        expect(pin.needsUpload, isTrue);

        final checklist = await (database.select(
          database.raceChecklistItemsTable,
        )..where((t) => t.id.equals('chk-1'))).getSingle();
        expect(
          checklist.userId,
          accountId,
          reason:
              'race checklists must follow the athlete across the auth '
              'boundary (local-only table, no dirty flag to set)',
        );

        final anonLeftovers = await database
            .customSelect(
              'SELECT '
              '(SELECT COUNT(*) FROM meal_logs WHERE user_id = ?1) + '
              '(SELECT COUNT(*) FROM formula_pins WHERE user_id = ?1) + '
              '(SELECT COUNT(*) FROM race_checklist_items WHERE user_id = ?1) '
              'AS n',
              variables: [Variable.withString(anonId)],
            )
            .getSingle();
        expect(anonLeftovers.read<int>('n'), 0);
      },
    );
  });

  group('hasLocalDataWorthMigrating', () {
    UserRepository repo() => UserRepository(
      database: database,
      supabase: fakeSupabaseClient(),
      sentry: RecordingSentryReporter(),
    );

    test('false for an empty (post-sign-out) anonymous user', () async {
      expect(await repo().hasLocalDataWorthMigrating('empty-anon'), isFalse);
    });

    test('true when only the onboarding survey exists locally', () async {
      final now = DateTime(2026, 8, 7, 9);
      await database
          .into(database.onboardingSurveysTable)
          .insert(
            OnboardingSurveysTableCompanion.insert(
              userId: 'survey-only-anon',
              sports: jsonEncode(['running']),
              goals: jsonEncode(['performance']),
              pitfalls: jsonEncode([]),
              completedAt: now,
              createdAt: now,
              updatedAt: now,
              localUpdatedAt: Value(now),
            ),
          );
      expect(
        await repo().hasLocalDataWorthMigrating('survey-only-anon'),
        isTrue,
        reason:
            'an onboarded-but-offline anon has ONLY local rows — the old '
            'remote-only check skipped migration and orphaned them',
      );
    });

    test('true when only a local meal log exists', () async {
      final now = DateTime(2026, 8, 7, 9);
      await database
          .into(database.mealLogsTable)
          .insert(
            MealLogsTableCompanion.insert(
              userId: 'meals-only-anon',
              logDate: '2026-08-07',
              name: 'Rice bowl',
              source: 'manual',
              createdAt: now,
              updatedAt: now,
            ),
          );
      expect(
        await repo().hasLocalDataWorthMigrating('meals-only-anon'),
        isTrue,
      );
    });
  });

  group('sync roster', () {
    test(
      'every repository onboarding writes has a dirty-upload retry channel',
      () {
        final keys = SyncCoordinator.syncableRepositoryKeysForTesting;
        // Onboarding writes: profile, survey, food prefs (diet/allergy
        // defaults), integrations (connect step), formula pins.
        expect(
          keys,
          containsAll(<String>[
            'users',
            'onboarding_surveys',
            'food_preferences',
            'integrations',
            'formula_pins',
          ]),
          reason:
              'a repository missing from this roster uploads once '
              'opportunistically and then never retries — offline onboarding '
              'data stays local forever',
        );
      },
    );
  });
}
