import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../app_database.dart';
import '../schema_versions.dart';

/// V1 -> V2 Migration (December 2025)
///
/// Changes:
/// - Adds preference_level and preference_source to food_preferences
/// - Adds dietary_preference, allergies, needs_upload to users table
/// - Renames user_id to device_id in feature_survey_responses
/// - Converts INTEGER IDs to TEXT (UUID) for offline-first tables:
///   - activities, events, carb_loading_plans, carb_loading_days, carb_loading_day_meals
/// - Adds allergens and excluded_diets columns to foods table
/// - Removes UNIQUE constraint on users.device_id
///
/// Note: Migration is idempotent - checks if columns exist before adding.
Future<void> runMigrationV1ToV2(
  AppDatabase db,
  Migrator m,
  Schema2 schema,
) async {
  // 1. Add preference_level to food_preferences if missing
  final foodPrefColumns = await db.customSelect("PRAGMA table_info(food_preferences_table)").get();
  final foodPrefColumnNames = foodPrefColumns.map((row) => row.read<String>('name')).toSet();

  if (!foodPrefColumnNames.contains('preference_level')) {
    await m.addColumn(schema.foodPreferencesTable, schema.foodPreferencesTable.preferenceLevel);
    // Migrate existing preference values to the new numeric scale
    await db.customStatement('''
      UPDATE food_preferences_table
      SET preference_level = CASE preference
        WHEN 'like' THEN 3
        WHEN 'dislike' THEN 1
        ELSE 2
      END;
    ''');
  }

  // 1b. Add preference_source to food_preferences if missing
  // Tracks the origin of food preferences: 'manual', 'allergy:{name}', or 'dietary:{name}'
  if (!foodPrefColumnNames.contains('preference_source')) {
    await db.customStatement(
      "ALTER TABLE food_preferences_table ADD COLUMN preference_source TEXT NOT NULL DEFAULT 'manual'"
    );
    // Existing preferences are user-set, so default to 'manual'
    await db.customStatement(
      "UPDATE food_preferences_table SET preference_source = 'manual' WHERE preference_source IS NULL OR preference_source = ''"
    );
  }

  // 2. Add dietary columns to users table if missing
  final usersColumns = await db.customSelect("PRAGMA table_info(users)").get();
  final usersColumnNames = usersColumns.map((row) => row.read<String>('name')).toSet();

  if (!usersColumnNames.contains('dietary_preference')) {
    await db.customStatement(
      'ALTER TABLE users ADD COLUMN dietary_preference TEXT'
    );
    // Ensure consistency with CHECK constraint
    await db.customStatement(
      "UPDATE users SET dietary_preference = NULL WHERE dietary_preference NOT IN ('omnivore', 'vegetarian', 'pescatarian', 'vegan', 'mediterranean', 'paleo', 'keto', 'low_carb')"
    );
  }

  if (!usersColumnNames.contains('allergies')) {
    // Use raw SQL to ensure default value is applied to existing rows
    await db.customStatement(
      "ALTER TABLE users ADD COLUMN allergies TEXT NOT NULL DEFAULT '{}'"
    );
    // Explicitly backfill default value (SQLite doesn't always apply defaults to existing rows)
    await db.customStatement(
      "UPDATE users SET allergies = '{}' WHERE allergies IS NULL OR allergies = ''"
    );
  }

  // 3. Add needs_upload to users table for background sync tracking
  if (!usersColumnNames.contains('needs_upload')) {
    await db.customStatement(
      'ALTER TABLE users ADD COLUMN needs_upload INTEGER NOT NULL DEFAULT 0'
    );
    // Ensure all existing rows have the default value
    await db.customStatement(
      'UPDATE users SET needs_upload = 0 WHERE needs_upload IS NULL'
    );
  }

  // 3b. Rename user_id to device_id in feature_survey_responses table
  final featureSurveyColumns = await db.customSelect("PRAGMA table_info(feature_survey_responses)").get();
  final featureSurveyColumnNames = featureSurveyColumns.map((row) => row.read<String>('name')).toSet();

  if (featureSurveyColumnNames.contains('user_id') && !featureSurveyColumnNames.contains('device_id')) {
    // SQLite 3.25+ supports RENAME COLUMN
    await db.customStatement('ALTER TABLE feature_survey_responses RENAME COLUMN user_id TO device_id');
    if (kDebugMode) {
      print('Renamed feature_survey_responses.user_id to device_id');
    }
  }

  // 4. INTEGER to TEXT (UUID) Migration for Offline-First Tables
  try {
    await _migrateActivitiesTableToUuid(db);
    await _migrateEventsTableToUuid(db);
    await _migrateCarbLoadingPlansTableToUuid(db);
    await _migrateCarbLoadingDaysTableToUuid(db);
    await _migrateCarbLoadingDayMealsTableToUuid(db);
  } catch (e) {
    if (kDebugMode) {
      print('V1->V2 migration warning: $e');
    }
    rethrow;
  }

  // 5. Add allergens and excluded_diets columns to foods table
  final foodsColumns = await db.customSelect("PRAGMA table_info(foods)").get();
  final foodsColumnNames = foodsColumns.map((row) => row.read<String>('name')).toSet();

  if (!foodsColumnNames.contains('allergens')) {
    await db.customStatement(
      "ALTER TABLE foods ADD COLUMN allergens TEXT NOT NULL DEFAULT '{}'"
    );
    if (kDebugMode) {
      print('Added allergens column to foods table');
    }
  }

  if (!foodsColumnNames.contains('excluded_diets')) {
    await db.customStatement(
      "ALTER TABLE foods ADD COLUMN excluded_diets TEXT NOT NULL DEFAULT '{}'"
    );
    if (kDebugMode) {
      print('Added excluded_diets column to foods table');
    }
  }

  // 6. Remove UNIQUE constraint on device_id in users table
  await _removeDeviceIdUniqueConstraint(db, usersColumnNames);

  if (kDebugMode) {
    print('V1->V2 migration completed: INTEGER to TEXT conversion successful');
  }
}

/// Generate UUID using SQLite's randomblob function
String get _sqliteUuidExpression =>
    "lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' || substr(hex(randomblob(2)), 2) || '-' || substr('89ab', abs(random()) % 4 + 1, 1) || substr(hex(randomblob(2)), 2) || '-' || hex(randomblob(6)))";

/// Migrate activities table from INTEGER id to TEXT UUID
Future<void> _migrateActivitiesTableToUuid(AppDatabase db) async {
  final activitiesColumns = await db.customSelect("PRAGMA table_info(activities)").get();
  final actIdCol = activitiesColumns.firstWhere(
    (r) => r.read<String>('name') == 'id',
    orElse: () => throw StateError('activities.id column not found'),
  );
  final actIdType = actIdCol.read<String>('type');

  if (actIdType.toUpperCase() != 'INTEGER') return;

  // Step 1: Create new table with TEXT id
  await db.customStatement('''
    CREATE TABLE activities_new (
      id TEXT PRIMARY KEY NOT NULL,
      user_id TEXT NOT NULL,
      activity_type TEXT NOT NULL CHECK (activity_type IN ('running', 'cycling', 'swimming')),
      title TEXT NOT NULL,
      scheduled_date_time INTEGER NOT NULL,
      status TEXT DEFAULT 'planned' CHECK (status IN ('planned', 'in_progress', 'completed', 'skipped')),
      distance_miles REAL,
      duration_minutes INTEGER,
      pace_target_minutes_per_mile REAL,
      intensity_level TEXT CHECK (intensity_level IS NULL OR intensity_level IN ('easy', 'moderate', 'hard', 'race')),
      cycling_speed_mph REAL,
      cycling_terrain TEXT CHECK (cycling_terrain IS NULL OR cycling_terrain IN ('flat', 'rolling', 'hilly')),
      cycling_indoor_outdoor TEXT CHECK (cycling_indoor_outdoor IS NULL OR cycling_indoor_outdoor IN ('indoor', 'outdoor')),
      cycling_elevation_gain_ft INTEGER,
      cycling_session_goal TEXT CHECK (cycling_session_goal IS NULL OR cycling_session_goal IN ('endurance', 'tempo', 'intervals')),
      swimming_pace_per_100m_seconds INTEGER,
      swimming_pool_or_open_water TEXT CHECK (swimming_pool_or_open_water IS NULL OR swimming_pool_or_open_water IN ('pool', 'open_water')),
      swimming_water_temp_c REAL,
      intensity_target TEXT,
      time_before_minutes INTEGER,
      reminder_enabled INTEGER DEFAULT 0 NOT NULL,
      reminder_days_before INTEGER,
      reminder_time_of_day TEXT,
      reminder_recurring INTEGER DEFAULT 0 NOT NULL,
      needs_upload INTEGER,
      local_updated_at INTEGER,
      completed_at INTEGER,
      completion_rating INTEGER CHECK (completion_rating IS NULL OR (completion_rating >= 1 AND completion_rating <= 5)),
      completion_notes TEXT,
      actual_distance_miles REAL,
      actual_duration_minutes INTEGER,
      nutrition_plan_data TEXT,
      notes TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER
    )
  ''');

  // Step 2: Copy data with generated UUIDs for existing INTEGER IDs
  await db.customStatement('''
    INSERT INTO activities_new
    SELECT
      $_sqliteUuidExpression,
      user_id, activity_type, title, scheduled_date_time, status,
      distance_miles, duration_minutes, pace_target_minutes_per_mile, intensity_level,
      cycling_speed_mph, cycling_terrain, cycling_indoor_outdoor, cycling_elevation_gain_ft, cycling_session_goal,
      swimming_pace_per_100m_seconds, swimming_pool_or_open_water, swimming_water_temp_c,
      intensity_target, time_before_minutes,
      reminder_enabled, reminder_days_before, reminder_time_of_day, reminder_recurring,
      needs_upload, local_updated_at,
      completed_at, completion_rating, completion_notes, actual_distance_miles, actual_duration_minutes,
      nutrition_plan_data, notes, created_at, updated_at, deleted_at
    FROM activities
  ''');

  // Step 3: Drop old table and rename new
  await db.customStatement('DROP TABLE activities');
  await db.customStatement('ALTER TABLE activities_new RENAME TO activities');

  // Step 4: Recreate indexes
  await db.customStatement('CREATE INDEX idx_activities_user_id ON activities(user_id)');
  await db.customStatement('CREATE INDEX idx_activities_scheduled_date_time ON activities(scheduled_date_time)');
  await db.customStatement('CREATE INDEX idx_activities_activity_type ON activities(activity_type)');
  await db.customStatement('CREATE INDEX idx_activities_status ON activities(status)');
  await db.customStatement('CREATE INDEX idx_activities_needs_upload ON activities(needs_upload, user_id) WHERE needs_upload = 1');
}

/// Migrate events table from INTEGER id to TEXT UUID
Future<void> _migrateEventsTableToUuid(AppDatabase db) async {
  final eventsColumns = await db.customSelect("PRAGMA table_info(events)").get();
  final evIdCol = eventsColumns.firstWhere(
    (r) => r.read<String>('name') == 'id',
    orElse: () => throw StateError('events.id column not found'),
  );
  final evIdType = evIdCol.read<String>('type');

  if (evIdType.toUpperCase() != 'INTEGER') return;

  await db.customStatement('''
    CREATE TABLE events_new (
      id TEXT PRIMARY KEY NOT NULL,
      activity_id TEXT,
      user_id TEXT NOT NULL,
      event_type TEXT NOT NULL,
      event_subtype TEXT,
      event_name TEXT,
      location TEXT,
      registration_url TEXT,
      event_date INTEGER,
      start_time TEXT,
      goal_time_minutes INTEGER,
      goal_pace_minutes_per_mile REAL,
      predicted_finish_time_minutes INTEGER,
      has_carb_loading INTEGER DEFAULT 0 NOT NULL,
      carb_loading_days INTEGER CHECK (carb_loading_days IS NULL OR carb_loading_days IN (1, 2, 3, 7)),
      carb_loading_start_date INTEGER,
      has_nutrition_plan INTEGER DEFAULT 0 NOT NULL,
      bib_number TEXT,
      wave_start_time TEXT,
      packet_pickup_info TEXT,
      actual_finish_time_minutes INTEGER,
      final_placement INTEGER,
      age_group_placement INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      needs_upload INTEGER,
      local_updated_at INTEGER
    )
  ''');

  await db.customStatement('''
    INSERT INTO events_new
    SELECT
      $_sqliteUuidExpression,
      NULL,
      user_id, event_type, event_subtype, event_name, location, registration_url,
      event_date, start_time, goal_time_minutes, goal_pace_minutes_per_mile, predicted_finish_time_minutes,
      has_carb_loading, carb_loading_days, carb_loading_start_date, has_nutrition_plan,
      bib_number, wave_start_time, packet_pickup_info,
      actual_finish_time_minutes, final_placement, age_group_placement,
      created_at, updated_at, needs_upload, local_updated_at
    FROM events
  ''');

  await db.customStatement('DROP TABLE events');
  await db.customStatement('ALTER TABLE events_new RENAME TO events');

  await db.customStatement('CREATE INDEX idx_events_activity_id ON events(activity_id)');
  await db.customStatement('CREATE INDEX idx_events_user_id ON events(user_id)');
  await db.customStatement('CREATE INDEX idx_events_event_type ON events(event_type)');
  await db.customStatement('CREATE INDEX idx_events_has_carb_loading ON events(has_carb_loading) WHERE has_carb_loading = 1');
  await db.customStatement('CREATE INDEX idx_events_needs_upload ON events(needs_upload, user_id) WHERE needs_upload = 1');
}

/// Migrate carb_loading_plans table from INTEGER id to TEXT UUID
Future<void> _migrateCarbLoadingPlansTableToUuid(AppDatabase db) async {
  final plansColumns = await db.customSelect("PRAGMA table_info(carb_loading_plans)").get();
  final planIdCol = plansColumns.firstWhere(
    (r) => r.read<String>('name') == 'id',
    orElse: () => throw StateError('carb_loading_plans.id column not found'),
  );
  final planIdType = planIdCol.read<String>('type');

  if (planIdType.toUpperCase() != 'INTEGER') return;

  await db.customStatement('''
    CREATE TABLE carb_loading_plans_new (
      id TEXT PRIMARY KEY NOT NULL,
      event_id TEXT,
      user_id TEXT NOT NULL,
      total_days INTEGER NOT NULL CHECK (total_days IN (1, 2, 3, 7)),
      start_date INTEGER NOT NULL,
      end_date INTEGER NOT NULL,
      daily_carb_target_grams INTEGER NOT NULL,
      daily_calorie_target INTEGER,
      generated_at INTEGER NOT NULL,
      algorithm_version TEXT DEFAULT 'v1.0' NOT NULL,
      adherence_score REAL CHECK (adherence_score IS NULL OR (adherence_score >= 0.0 AND adherence_score <= 1.0)),
      completed_at INTEGER,
      needs_upload INTEGER DEFAULT 0 NOT NULL,
      local_updated_at INTEGER NOT NULL
    )
  ''');

  await db.customStatement('''
    INSERT INTO carb_loading_plans_new
    SELECT
      $_sqliteUuidExpression,
      NULL,
      user_id, total_days, start_date, end_date, daily_carb_target_grams, daily_calorie_target,
      generated_at, algorithm_version, adherence_score, completed_at, needs_upload, local_updated_at
    FROM carb_loading_plans
  ''');

  await db.customStatement('DROP TABLE carb_loading_plans');
  await db.customStatement('ALTER TABLE carb_loading_plans_new RENAME TO carb_loading_plans');

  await db.customStatement('CREATE INDEX idx_carb_loading_plans_event_id ON carb_loading_plans(event_id)');
  await db.customStatement('CREATE INDEX idx_carb_loading_plans_user_id ON carb_loading_plans(user_id)');
  await db.customStatement('CREATE INDEX idx_carb_loading_plans_start_date ON carb_loading_plans(start_date, end_date)');
  await db.customStatement('CREATE INDEX idx_carb_loading_plans_needs_upload ON carb_loading_plans(needs_upload, user_id) WHERE needs_upload = 1');
}

/// Migrate carb_loading_days table from INTEGER id to TEXT UUID
Future<void> _migrateCarbLoadingDaysTableToUuid(AppDatabase db) async {
  final daysColumns = await db.customSelect("PRAGMA table_info(carb_loading_days)").get();
  final dayIdCol = daysColumns.firstWhere(
    (r) => r.read<String>('name') == 'id',
    orElse: () => throw StateError('carb_loading_days.id column not found'),
  );
  final dayIdType = dayIdCol.read<String>('type');

  if (dayIdType.toUpperCase() != 'INTEGER') return;

  await db.customStatement('''
    CREATE TABLE carb_loading_days_new (
      id TEXT PRIMARY KEY NOT NULL,
      carb_loading_plan_id TEXT NOT NULL,
      plan_date INTEGER NOT NULL,
      day_number INTEGER NOT NULL CHECK (day_number > 0),
      carb_target_grams INTEGER NOT NULL CHECK (carb_target_grams > 0),
      carb_protocol_g_per_kg REAL DEFAULT 8.0 NOT NULL,
      calorie_target INTEGER,
      meal_count INTEGER DEFAULT 6 NOT NULL CHECK (meal_count > 0),
      breakfast_percent REAL DEFAULT 0.25 NOT NULL CHECK (breakfast_percent >= 0.0 AND breakfast_percent <= 1.0),
      morning_snack_percent REAL DEFAULT 0.10 NOT NULL CHECK (morning_snack_percent >= 0.0 AND morning_snack_percent <= 1.0),
      lunch_percent REAL DEFAULT 0.25 NOT NULL CHECK (lunch_percent >= 0.0 AND lunch_percent <= 1.0),
      afternoon_snack_percent REAL DEFAULT 0.15 NOT NULL CHECK (afternoon_snack_percent >= 0.0 AND afternoon_snack_percent <= 1.0),
      dinner_percent REAL DEFAULT 0.20 NOT NULL CHECK (dinner_percent >= 0.0 AND dinner_percent <= 1.0),
      evening_snack_percent REAL DEFAULT 0.05 NOT NULL CHECK (evening_snack_percent >= 0.0 AND evening_snack_percent <= 1.0),
      logged_carbs_grams INTEGER DEFAULT 0 NOT NULL CHECK (logged_carbs_grams >= 0),
      logged_calories INTEGER DEFAULT 0 NOT NULL CHECK (logged_calories >= 0),
      completed INTEGER DEFAULT 0 NOT NULL,
      needs_upload INTEGER DEFAULT 0 NOT NULL,
      local_updated_at INTEGER NOT NULL,
      UNIQUE(carb_loading_plan_id, plan_date)
    )
  ''');

  // NOTE: Foreign keys cannot be migrated - plan_id will be NULL after this migration
  await db.customStatement('''
    INSERT INTO carb_loading_days_new
    SELECT
      $_sqliteUuidExpression,
      NULL,
      plan_date, day_number, carb_target_grams, carb_protocol_g_per_kg, calorie_target, meal_count,
      breakfast_percent, morning_snack_percent, lunch_percent, afternoon_snack_percent, dinner_percent, evening_snack_percent,
      logged_carbs_grams, logged_calories, completed, needs_upload, local_updated_at
    FROM carb_loading_days
  ''');

  await db.customStatement('DROP TABLE carb_loading_days');
  await db.customStatement('ALTER TABLE carb_loading_days_new RENAME TO carb_loading_days');

  await db.customStatement('CREATE INDEX idx_carb_loading_days_carb_loading_plan_id ON carb_loading_days(carb_loading_plan_id)');
  await db.customStatement('CREATE INDEX idx_carb_loading_days_plan_date ON carb_loading_days(plan_date)');
  await db.customStatement('CREATE INDEX idx_carb_loading_days_completed ON carb_loading_days(completed)');
  await db.customStatement('CREATE INDEX idx_carb_loading_days_needs_upload ON carb_loading_days(needs_upload) WHERE needs_upload = 1');
}

/// Migrate carb_loading_day_meals table from INTEGER carb_loading_day_id to TEXT UUID
Future<void> _migrateCarbLoadingDayMealsTableToUuid(AppDatabase db) async {
  final mealsColumns = await db.customSelect("PRAGMA table_info(carb_loading_day_meals)").get();
  final mealDayIdCol = mealsColumns.firstWhere(
    (r) => r.read<String>('name') == 'carb_loading_day_id',
    orElse: () => throw StateError('carb_loading_day_meals.carb_loading_day_id column not found'),
  );
  final mealDayIdType = mealDayIdCol.read<String>('type');

  if (mealDayIdType.toUpperCase() != 'INTEGER') return;

  await db.customStatement('''
    CREATE TABLE carb_loading_day_meals_new (
      id TEXT PRIMARY KEY NOT NULL,
      carb_loading_day_id TEXT NOT NULL,
      meal_type_id INTEGER NOT NULL,
      carb_loading_food_id TEXT,
      carb_loading_user_food_id TEXT,
      food_display_name TEXT,
      quantity INTEGER DEFAULT 1 NOT NULL CHECK (quantity > 0),
      carbs_consumed REAL NOT NULL CHECK (carbs_consumed >= 0),
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
      updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
      CHECK ((carb_loading_food_id IS NOT NULL AND carb_loading_user_food_id IS NULL) OR (carb_loading_food_id IS NULL AND carb_loading_user_food_id IS NOT NULL))
    )
  ''');

  // NOTE: Foreign keys cannot be migrated - day_id will be NULL after this migration
  await db.customStatement('''
    INSERT INTO carb_loading_day_meals_new
    SELECT
      $_sqliteUuidExpression,
      NULL,
      meal_type_id, carb_loading_food_id, carb_loading_user_food_id, food_display_name,
      quantity, carbs_consumed, created_at, updated_at
    FROM carb_loading_day_meals
  ''');

  await db.customStatement('DROP TABLE carb_loading_day_meals');
  await db.customStatement('ALTER TABLE carb_loading_day_meals_new RENAME TO carb_loading_day_meals');

  await db.customStatement('CREATE INDEX idx_carb_loading_day_meals_carb_loading_day_id ON carb_loading_day_meals(carb_loading_day_id)');
  await db.customStatement('CREATE INDEX idx_carb_loading_day_meals_meal_type_id ON carb_loading_day_meals(meal_type_id)');
  await db.customStatement('CREATE INDEX idx_carb_loading_day_meals_carb_loading_food_id ON carb_loading_day_meals(carb_loading_food_id) WHERE carb_loading_food_id IS NOT NULL');
  await db.customStatement('CREATE INDEX idx_carb_loading_day_meals_carb_loading_user_food_id ON carb_loading_day_meals(carb_loading_user_food_id) WHERE carb_loading_user_food_id IS NOT NULL');
}

/// Remove UNIQUE constraint on device_id in users table
/// Multiple users can share a device (e.g., family members, switching accounts).
Future<void> _removeDeviceIdUniqueConstraint(AppDatabase db, Set<String> usersColumnNames) async {
  // Check if the constraint exists by looking at indexes
  final userIndexes = await db.customSelect("PRAGMA index_list('users')").get();
  final hasDeviceIdUnique = userIndexes.any((idx) {
    final name = idx.read<String>('name');
    final unique = idx.read<int>('unique') == 1;
    return unique && name.toLowerCase().contains('device');
  });

  // Always recreate to ensure constraint is removed
  if (hasDeviceIdUnique || true) {
    final currentUsersColumns = await db.customSelect("PRAGMA table_info(users)").get();
    final currentColumnNames = currentUsersColumns.map((row) => row.read<String>('name')).toList();

    // Only recreate if device_id column exists
    if (currentColumnNames.contains('device_id')) {
      // Create new table without UNIQUE constraint on device_id
      await db.customStatement('''
        CREATE TABLE users_new (
          id TEXT PRIMARY KEY NOT NULL,
          device_id TEXT NOT NULL,
          auth_user_id TEXT,
          auth_provider TEXT DEFAULT 'anonymous' NOT NULL,
          is_anonymous INTEGER DEFAULT 1 NOT NULL,
          created_at INTEGER DEFAULT (strftime('%s', 'now') * 1000) NOT NULL,
          updated_at INTEGER DEFAULT (strftime('%s', 'now') * 1000) NOT NULL,
          gender TEXT,
          birthday INTEGER,
          height_feet INTEGER,
          height_inches INTEGER,
          weight_pounds REAL,
          runs_with_water_bottle INTEGER DEFAULT 0 NOT NULL,
          food_preferences TEXT DEFAULT '{}' NOT NULL,
          preferred_distance_unit TEXT DEFAULT 'miles' NOT NULL,
          preferred_pace_unit TEXT DEFAULT 'min_per_mile' NOT NULL,
          gut_training_level TEXT DEFAULT 'moderate' NOT NULL,
          onboarding_completed INTEGER DEFAULT 0 NOT NULL,
          last_active_at INTEGER DEFAULT (strftime('%s', 'now') * 1000) NOT NULL,
          app_version TEXT,
          notifications_enabled INTEGER DEFAULT 0 NOT NULL,
          default_reminder_day INTEGER DEFAULT 4 NOT NULL,
          default_reminder_hour INTEGER DEFAULT 17 NOT NULL,
          default_reminder_minute INTEGER DEFAULT 0 NOT NULL,
          default_reminder_recurring INTEGER DEFAULT 0 NOT NULL,
          temp_plan_data TEXT,
          swipe_hint_shown INTEGER DEFAULT 0 NOT NULL,
          calendar_week_start TEXT DEFAULT 'monday' NOT NULL,
          default_activity_time TEXT DEFAULT '07:00:00' NOT NULL,
          default_activity_day TEXT DEFAULT 'saturday' NOT NULL,
          auto_generate_nutrition INTEGER DEFAULT 1 NOT NULL,
          completion_reminders INTEGER DEFAULT 1 NOT NULL,
          sender_name TEXT,
          dietary_preference TEXT,
          allergies TEXT DEFAULT '{}' NOT NULL,
          needs_upload INTEGER DEFAULT 0 NOT NULL,
          CHECK (gender IN ('male', 'female', 'other') OR gender IS NULL),
          CHECK (gut_training_level IN ('low', 'moderate', 'high')),
          CHECK (preferred_distance_unit IN ('miles', 'kilometers')),
          CHECK (preferred_pace_unit IN ('min_per_mile', 'min_per_km')),
          CHECK (calendar_week_start IN ('sunday', 'monday')),
          CHECK (default_activity_day IN ('monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday')),
          CHECK (auth_provider IN ('anonymous', 'email', 'google', 'apple')),
          CHECK (dietary_preference IN ('omnivore', 'vegetarian', 'pescatarian', 'vegan', 'mediterranean', 'paleo', 'keto', 'low_carb') OR dietary_preference IS NULL)
        )
      ''');

      // Check if auth columns exist (they should in v1+, but be safe)
      final hasAuthColumns = currentColumnNames.contains('auth_user_id');

      if (hasAuthColumns) {
        // Full copy including auth columns
        await db.customStatement('''
          INSERT INTO users_new (
            id, device_id, auth_user_id, auth_provider, is_anonymous,
            created_at, updated_at, gender, birthday,
            height_feet, height_inches, weight_pounds, runs_with_water_bottle,
            food_preferences, preferred_distance_unit, preferred_pace_unit,
            gut_training_level, onboarding_completed, last_active_at, app_version,
            notifications_enabled, default_reminder_day, default_reminder_hour,
            default_reminder_minute, default_reminder_recurring, temp_plan_data,
            swipe_hint_shown, calendar_week_start, default_activity_time,
            default_activity_day, auto_generate_nutrition, completion_reminders,
            sender_name, dietary_preference, allergies, needs_upload
          )
          SELECT
            id, device_id, auth_user_id, auth_provider, is_anonymous,
            created_at, updated_at, gender, birthday,
            height_feet, height_inches, weight_pounds, runs_with_water_bottle,
            food_preferences, preferred_distance_unit, preferred_pace_unit,
            gut_training_level, onboarding_completed, last_active_at, app_version,
            notifications_enabled, default_reminder_day, default_reminder_hour,
            default_reminder_minute, default_reminder_recurring, temp_plan_data,
            swipe_hint_shown, calendar_week_start, default_activity_time,
            default_activity_day, auto_generate_nutrition, completion_reminders,
            sender_name, dietary_preference, allergies, needs_upload
          FROM users
        ''');
      } else {
        // Legacy migration - auth columns will get defaults
        await db.customStatement('''
          INSERT INTO users_new (
            id, device_id,
            created_at, updated_at, gender, birthday,
            height_feet, height_inches, weight_pounds, runs_with_water_bottle,
            food_preferences, preferred_distance_unit, preferred_pace_unit,
            gut_training_level, onboarding_completed, last_active_at, app_version,
            notifications_enabled, default_reminder_day, default_reminder_hour,
            default_reminder_minute, default_reminder_recurring, temp_plan_data,
            swipe_hint_shown, calendar_week_start, default_activity_time,
            default_activity_day, auto_generate_nutrition, completion_reminders,
            sender_name, dietary_preference, allergies, needs_upload
          )
          SELECT
            id, device_id,
            created_at, updated_at, gender, birthday,
            height_feet, height_inches, weight_pounds, runs_with_water_bottle,
            food_preferences, preferred_distance_unit, preferred_pace_unit,
            gut_training_level, onboarding_completed, last_active_at, app_version,
            notifications_enabled, default_reminder_day, default_reminder_hour,
            default_reminder_minute, default_reminder_recurring, temp_plan_data,
            swipe_hint_shown, calendar_week_start, default_activity_time,
            default_activity_day, auto_generate_nutrition, completion_reminders,
            sender_name, dietary_preference, allergies, needs_upload
          FROM users
        ''');
      }

      // Drop old table and rename new
      await db.customStatement('DROP TABLE users');
      await db.customStatement('ALTER TABLE users_new RENAME TO users');

      // Recreate index on device_id (non-unique, for query performance)
      await db.customStatement('CREATE INDEX IF NOT EXISTS idx_users_device_id ON users(device_id)');

      if (kDebugMode) {
        print('Removed UNIQUE constraint on users.device_id');
      }
    }
  }
}
