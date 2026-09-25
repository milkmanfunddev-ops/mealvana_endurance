// Ticket 103 (testing-wave; Finding 86-012): since a failed upload no longer
// stops the pull, every repository the SyncCoordinator syncs must keep a
// `needs_upload` row when its pull brings the server's older copy.
//
// Each test runs the repository's real `syncFromRemote` against a real
// SupabaseClient whose HTTP goes to an in-memory PostgREST (only the wire is
// faked) and a real in-memory Drift. The server rows carry the columns the
// dev schema has (docs/dev_schema.txt). A first pull lands the row clean, an
// offline edit marks it dirty, the server's copy changes, and a second pull
// must leave the local edit and its flag alone.
//
// meal_plans and user_memories pull through their own remote seams and are
// covered in test/features/meal_planning/data/.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_repository.dart';
import 'package:mealvana_endurance/features/events/data/events_repository.dart';
import 'package:mealvana_endurance/features/feedback/data/feedback_repository.dart';
import 'package:mealvana_endurance/features/food_preferences/data/food_preferences_repository.dart';
import 'package:mealvana_endurance/features/formula_kit/data/formula_pins_repository.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/data/meal_log_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/data/saved_meals_repository.dart';
import 'package:mealvana_endurance/features/onboarding/data/onboarding_survey_repository.dart';
import 'package:mealvana_endurance/features/user_foods/data/user_foods_repository.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes/fake_postgrest.dart';

const _user = '607f9dd5-6fa7-48ee-a628-720d4a0506a1';
const _device = 'B5E1C2D4-7F3A-4C8E-9D21-3A6F0E8B1C77';
const _created = '2026-09-20T08:00:00.123456+00:00';
const _edited = '2026-09-25T13:24:00.654321+00:00';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakePostgrest server;
  const logger = NoopAppLogger();
  const sentry = NoopSentryReporter();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = FakePostgrest();
  });

  tearDown(() => db.close());

  /// Pull [serverRow] clean, edit [column] offline (dirty), change the
  /// server's copy of [serverColumn], pull again: the edit and flag stay.
  Future<void> expectPullKeepsDirtyRow(
    SyncableRepository repo, {
    required String table,
    required Map<String, dynamic> serverRow,
    required String column,
    required Object localValue,
    required Object serverValue,
    String? serverColumn,
    String keyColumn = 'id',
    Map<String, List<Map<String, dynamic>>> otherTables = const {},
  }) async {
    final key = '${serverRow[keyColumn]}';
    server.tables.addAll(otherTables);
    server.tables[table] = [serverRow];

    final first = await repo.syncFromRemote(_user);
    expect(first.success, isTrue, reason: first.error);

    await db.customStatement(
      'UPDATE "$table" SET needs_upload = 1, "$column" = ? '
      'WHERE "$keyColumn" = ?',
      [localValue, key],
    );

    server.tables[table] = [
      {
        ...serverRow,
        serverColumn ?? column: serverValue,
        'updated_at': _edited,
      },
    ];
    final second = await repo.syncFromRemote(_user);
    expect(second.success, isTrue, reason: second.error);

    final rows = await db
        .customSelect(
          'SELECT "$column" AS v, needs_upload AS dirty FROM "$table" '
          'WHERE "$keyColumn" = ?',
          variables: [Variable.withString(key)],
        )
        .get();
    expect(rows, hasLength(1), reason: 'the dirty row is still there');
    expect(rows.single.data['v'], localValue, reason: 'local edit kept');
    expect(rows.single.data['dirty'], 1, reason: 'still needs upload');
  }

  test('users', () async {
    await expectPullKeepsDirtyRow(
      UserRepository(database: db, supabase: server.client, sentry: sentry),
      table: 'users',
      serverRow: {
        'id': _user,
        'device_id': _device,
        'auth_provider': 'apple',
        'is_anonymous': false,
        'first_name': 'Lee',
        'sweat_rate': 'moderate',
        'weight_pounds': 165.0,
        'created_at': _created,
        'updated_at': _created,
      },
      column: 'first_name',
      localValue: 'Lee (edited offline)',
      serverValue: 'Lee (edited on the web)',
    );
  });

  test('activities', () async {
    await expectPullKeepsDirtyRow(
      ActivitiesRepository(
        supabase: server.client,
        database: db,
        logger: logger,
        sentry: sentry,
        deduplicationService: ActivityDeduplicationService(logger: logger),
      ),
      table: 'activities',
      serverRow: {
        'id': 'act-1758787200000',
        'user_id': _user,
        'title': 'Tempo run',
        'activity_type': 'run',
        'scheduled_date_time': '2026-09-27T07:00:00',
        'duration_minutes': 60,
        'status': 'planned',
        'deleted_at': null,
        'created_at': _created,
        'updated_at': _created,
      },
      column: 'title',
      localValue: 'Tempo run (moved offline)',
      serverValue: 'Tempo run (coach edit)',
    );
  });

  test('events', () async {
    final carbLoading = CarbLoadingRepository(
      supabase: server.client,
      database: db,
      logger: logger,
      sentry: sentry,
    );
    await expectPullKeepsDirtyRow(
      EventsRepository(
        supabase: server.client,
        database: db,
        logger: logger,
        carbLoadingRepository: carbLoading,
        sentry: sentry,
      ),
      table: 'events',
      serverRow: {
        'id': 'evt-1758787200000',
        'user_id': _user,
        'event_type': 'run',
        'event_name': 'Chicago Marathon',
        'event_date': '2026-10-11T07:30:00',
        'created_at': _created,
        'updated_at': _created,
      },
      column: 'event_name',
      localValue: 'Chicago Marathon (renamed offline)',
      serverValue: 'Chicago Marathon (coach edit)',
    );
  });

  test('carb_loading_plans (and its days)', () async {
    final repo = CarbLoadingRepository(
      supabase: server.client,
      database: db,
      logger: logger,
      sentry: sentry,
    );
    final day = {
      'id': 'cld-1',
      'carb_loading_plan_id': 'clp-1',
      'plan_date': '2026-10-08T00:00:00',
      'day_number': 1,
      'carb_target_grams': 560,
      'calorie_target': 3400,
      'meal_count': 6,
      'breakfast_percent': 0.25,
      'morning_snack_percent': 0.10,
      'lunch_percent': 0.25,
      'afternoon_snack_percent': 0.15,
      'dinner_percent': 0.20,
      'evening_snack_percent': 0.05,
      'logged_carbs_grams': 0,
      'logged_calories': 0,
      'completed': false,
      'carb_protocol_g_per_kg': 8.0,
      'updated_at': _created,
    };
    await expectPullKeepsDirtyRow(
      repo,
      table: 'carb_loading_plans',
      serverRow: {
        'id': 'clp-1',
        'user_id': _user,
        'event_id': 'evt-1758787200000',
        'total_days': 3,
        'start_date': '2026-10-08T00:00:00',
        'end_date': '2026-10-10T00:00:00',
        'daily_carb_target_grams': 560,
        'generated_at': '2026-09-20T08:00:00',
        'created_at': _created,
        'updated_at': _created,
      },
      column: 'daily_carb_target_grams',
      localValue: 600,
      serverValue: 520,
      otherTables: {
        'carb_loading_days': [day],
      },
    );

    // The day: dirty offline, changed on the server, pulled again.
    await db.customStatement(
      'UPDATE carb_loading_days SET needs_upload = 1, carb_target_grams = 610 '
      "WHERE id = 'cld-1'",
    );
    server.tables['carb_loading_days'] = [
      {...day, 'carb_target_grams': 500, 'updated_at': _edited},
    ];
    expect((await repo.syncFromRemote(_user)).success, isTrue);
    final dayRow = await db
        .customSelect(
          "SELECT carb_target_grams AS v, needs_upload AS dirty "
          "FROM carb_loading_days WHERE id = 'cld-1'",
        )
        .getSingle();
    expect(dayRow.data['v'], 610);
    expect(dayRow.data['dirty'], 1);
  });

  test('feedback', () async {
    await expectPullKeepsDirtyRow(
      FeedbackRepository(db, logger, server.client, sentry),
      table: 'feedback',
      serverRow: {
        'id': '0b6f1f0e-5d0e-4d3f-9a55-2f3c1c9a7e10',
        'user_name': _user,
        'device_id': _device,
        'satisfaction_level': 4,
        'satisfaction_emoji': 'happy',
        'satisfaction_label': 'Good',
        'app_feedback': 'Gels were spot on',
        'created_at': _created,
        'updated_at': _created,
      },
      keyColumn: 'id',
      column: 'app_feedback',
      localValue: 'Gels were spot on (edited offline)',
      serverValue: 'Gels were spot on (server)',
    );
  });

  test('user_foods', () async {
    await expectPullKeepsDirtyRow(
      UserFoodsRepository(
        database: db,
        supabase: server.client,
        sentry: sentry,
      ),
      table: 'user_foods',
      serverRow: {
        'id': '5d2c7a51-0c1e-4f7b-8e0a-9f5b6a1d2c33',
        'user_id': _user,
        'device_id': _device,
        'client_food_id': 'client-food-1',
        'name': 'Maurten Gel 100',
        'categories': ['during_run'],
        'carbs': 25,
        'is_deleted': false,
        'created_at': _created,
        'updated_at': _created,
      },
      column: 'name',
      localValue: 'Maurten Gel 100 CAF',
      serverValue: 'Maurten Gel (server)',
    );
  });

  test('meal_logs', () async {
    await expectPullKeepsDirtyRow(
      MealLogRepository(
        supabase: server.client,
        database: db,
        logger: logger,
        sentry: sentry,
      ),
      table: 'meal_logs',
      serverRow: {
        'id': '9162543b-1022-4462-8c4b-00ef7cf926c4',
        'user_id': _user,
        'log_date': '2026-09-23',
        'slot': 'snack',
        'name': 'Rice cake and Almond butter',
        'source': 'manual',
        'items': [
          {
            'name': 'Rice cake',
            'fat_g': 0.6,
            'carb_g': 15,
            'portion': '2 cakes',
            'calories': 70,
            'protein_g': 1.4,
          },
        ],
        'calories': 168,
        'carbs_g': 18,
        'protein_g': 4.8,
        'fat_g': 9.6,
        'sodium_mg': 0,
        'photo_path': null,
        'recipe_id': null,
        'saved_meal_id': null,
        'notes': null,
        'eaten_at': '2026-09-23T13:46:00+00:00',
        'created_at': '2026-09-23T13:46:59.034208+00:00',
        'updated_at': '2026-09-23T13:46:59.034992+00:00',
        'is_deleted': false,
        'plan_meal_id': null,
      },
      column: 'name',
      localValue: 'Rice cake (edited offline)',
      serverValue: 'Rice cake (server)',
    );
  });

  test('saved_meals', () async {
    await expectPullKeepsDirtyRow(
      SavedMealsRepository(
        supabase: server.client,
        database: db,
        logger: logger,
        sentry: sentry,
      ),
      table: 'saved_meals',
      serverRow: {
        'id': 'fd993bbb-a13a-43e7-a662-ea71ed2ae64a',
        'user_id': _user,
        'name': 'Egg & Veggie Scramble',
        'items': [
          {
            'name': 'Egg & Veggie Scramble',
            'fat_g': 18,
            'carb_g': 8,
            'portion': '1 serving',
            'calories': 280,
            'protein_g': 22,
          },
        ],
        'calories': 280,
        'carbs_g': 8,
        'protein_g': 22,
        'fat_g': 18,
        'sodium_mg': 0,
        'photo_path': null,
        'last_used_at': '2026-06-17T13:42:39.046288+00:00',
        'created_at': '2026-06-17T13:42:39.046288+00:00',
        'updated_at': '2026-09-16T14:48:39.909968+00:00',
        'is_deleted': false,
        'library_meal_id': null,
        'meal_types': const <String>[],
        'batch': null,
        'icon': 'egg',
        'notes': 'Low heat, butter, splash of cream.',
      },
      column: 'name',
      localValue: 'Egg Scramble (renamed offline)',
      serverValue: 'Egg Scramble (server)',
    );
  });

  group('integrations', () {
    IntegrationsRepository repo() => IntegrationsRepository(
      database: db,
      supabase: server.client,
      logger: logger,
      sentry: sentry,
    );

    Map<String, dynamic> tpRow(String id, String token) => {
      'id': id,
      'user_id': _user,
      'provider': 'training_peaks',
      'access_token': token,
      'refresh_token': 'refresh-$token',
      'token_expires_at': '2026-09-25T15:00:00+00:00',
      'provider_athlete_id': 'ath-1',
      'is_active': true,
      'last_sync_status': 'success',
      'created_at': _created,
      'updated_at': _created,
    };

    test('same id', () async {
      await expectPullKeepsDirtyRow(
        repo(),
        table: 'integrations',
        serverRow: tpRow('3f0c9b8e-1111-4e2a-9d7c-5b6a4c3d2e1f', 'server'),
        column: 'access_token',
        localValue: 'fresh-from-reconnect',
        serverValue: 'stale-on-server',
      );
    });

    test('a server row with another id for the same provider does not '
        'replace the dirty local one', () async {
      // Reconnect minted local id A; the server already holds B for the
      // same (user_id, provider), so A's upload is refused every time.
      const a = '3f0c9b8e-1111-4e2a-9d7c-5b6a4c3d2e1f';
      const b = '7a1d2e3f-2222-4b5c-8d9e-0f1a2b3c4d5e';
      server.tables['integrations'] = [tpRow(a, 'first')];
      expect((await repo().syncFromRemote(_user)).success, isTrue);
      await db.customStatement(
        "UPDATE integrations SET needs_upload = 1, access_token = 'fresh' "
        "WHERE id = '$a'",
      );
      server.tables['integrations'] = [tpRow(b, 'stale')];

      expect((await repo().syncFromRemote(_user)).success, isTrue);

      final rows = await db
          .customSelect(
            'SELECT id, access_token, needs_upload FROM integrations',
          )
          .get();
      expect(rows.map((r) => r.data['id']), [a]);
      expect(rows.single.data['access_token'], 'fresh');
      expect(rows.single.data['needs_upload'], 1);
    });
  });

  test('formula_pins', () async {
    await expectPullKeepsDirtyRow(
      FormulaPinsRepository(
        supabase: server.client,
        database: db,
        logger: logger,
        sentry: sentry,
      ),
      table: 'formula_pins',
      serverRow: {
        'id': 'c4b3a291-3333-4d5e-8f70-112233445566',
        'user_id': _user,
        'template_id': 'e7f8a9b0-4444-4c1d-9e2f-665544332211',
        'template_kind': 'pre_system',
        'is_deleted': false,
        'created_at': _created,
        'updated_at': _created,
      },
      // Unpinned offline; the server still has it pinned.
      column: 'is_deleted',
      localValue: 1,
      serverValue: false,
    );
  });

  test('onboarding_surveys', () async {
    await expectPullKeepsDirtyRow(
      OnboardingSurveyRepository(
        supabase: server.client,
        database: db,
        logger: logger,
        sentry: sentry,
      ),
      table: 'onboarding_surveys',
      keyColumn: 'user_id',
      serverRow: {
        'user_id': _user,
        'sports': ['run'],
        'goals': ['performance'],
        'pitfalls': ['bonking'],
        'survey_payload': null,
        'completed_at': _created,
        'created_at': _created,
        'updated_at': _created,
      },
      column: 'goals',
      localValue: '["performance","weight"]',
      serverColumn: 'goals',
      serverValue: ['health'],
    );
  });

  group('food_preferences (no needs_upload column)', () {
    FoodPreferencesRepository repo() => FoodPreferencesRepository(
      database: db,
      supabase: server.client,
      sentry: sentry,
    );

    Map<String, dynamic> pref(String food, String preference) => {
      'id': 'fp-$food',
      'user_id': _user,
      'food_name': food,
      'preference': preference,
      'preference_level': preference == 'like' ? 4 : 0,
      'preference_source': 'manual',
      'created_at': _created,
      'updated_at': _created,
    };

    test('after a refused upload, the pull keeps unsent local values and '
        'only adds foods the phone does not have', () async {
      server.tables['food_preferences'] = [pref('banana', 'like')];
      expect((await repo().syncFromRemote(_user)).success, isTrue);

      // Offline edit: banana flips to dislike; the upload is refused.
      await db.foodPreferencesDao.saveFoodPreferences(_user, {
        'banana': FoodPreference.dislike,
      });
      server.rejectWrites.add('food_preferences');
      final upload = await repo().uploadDirtyRecords(_user);
      expect(upload.success, isFalse);

      // Another device liked oats meanwhile.
      server.tables['food_preferences'] = [
        pref('banana', 'like'),
        pref('oats', 'like'),
      ];
      expect((await repo().syncFromRemote(_user)).success, isTrue);

      final local = await db.foodPreferencesDao.getUserFoodPreferences(_user);
      expect(local['banana'], FoodPreference.dislike, reason: 'unsent edit');
      expect(local['oats'], FoodPreference.like, reason: 'new server food');
    });

    test('once the upload lands, the pull applies the server again', () async {
      server.tables['food_preferences'] = [pref('banana', 'like')];
      await repo().syncFromRemote(_user);
      await db.foodPreferencesDao.saveFoodPreferences(_user, {
        'banana': FoodPreference.dislike,
      });
      server.rejectWrites.add('food_preferences');
      await repo().uploadDirtyRecords(_user);

      server.rejectWrites.clear();
      expect((await repo().uploadDirtyRecords(_user)).success, isTrue);
      // Later edit on the web.
      server.tables['food_preferences'] = [pref('banana', 'like')];
      await repo().syncFromRemote(_user);

      final local = await db.foodPreferencesDao.getUserFoodPreferences(_user);
      expect(local['banana'], FoodPreference.like);
    });
  });
}
