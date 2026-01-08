import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:mealvana_endurance/shared/database/schema_versions.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// Platform-specific connection implementations
import 'connection_native.dart' if (dart.library.html) 'connection_web.dart';
import '../../features/auth/domain/user_preferences.dart' as domain;
import '../../features/onboarding/domain/dietary_preference.dart';
import '../../features/onboarding/domain/allergy.dart';
import 'tables/user_profiles.dart';
import 'tables/food_preferences.dart';
import 'tables/feedback.dart';
import 'tables/foods_table.dart';
import 'tables/app_content_table.dart';
import 'tables/edge_functions_table.dart';
import 'tables/user_foods_table.dart';
// NEW: Calendar tables
import 'tables/activities_table.dart';
import 'tables/events_table.dart';
import 'tables/carb_loading_plans_table.dart';
import 'tables/carb_loading_days_table.dart';
// NEW: Carb Loading Food tables
import 'tables/carb_loading_foods_table.dart';
import 'tables/carb_loading_user_foods_table.dart';
import 'tables/carb_loading_day_meals_table.dart';
// NEW: Weather feature table
import 'tables/weather_forecasts_table.dart';
// NEW: Feature survey table
import 'tables/feature_survey_responses_table.dart';
// NEW: External integrations (Final Surge, TrainingPeaks, etc.)
import 'tables/integrations_table.dart';
// NEW: Coach mode tables
import 'tables/coaches_table.dart';
import 'tables/coach_athlete_relationships_table.dart';
import 'tables/coach_messages_table.dart';
import '../../features/nutrition_plan/domain/food_item.dart';

// Migration files (extracted for modularity)
import 'migrations/migration_v1_to_v2.dart';
import 'migrations/migration_v2_to_v3.dart';

// DAOs (extracted for modularity)
import 'daos/user_dao.dart';
import 'daos/food_preferences_dao.dart';
import 'daos/activity_dao.dart';
import 'daos/foods_dao.dart';
import 'daos/content_dao.dart';
import 'daos/diagnostic_dao.dart';

part 'app_database.g.dart';

/// Main Drift database for the Mealvana Endurance app
/// V1 schema with 16 tables (added auth columns to users table)
@DriftDatabase(
  tables: [
    // Core tables aligned with Supabase
    UserProfilesTable,
    FoodPreferencesTable,
    FeedbackTable,

    // Food system tables
    FoodsTable,

    // User-specific food tables
    UserFoodsTable,

    // Content management
    AppContentTable,

    // Additional features
    EdgeFunctionsTable,

    // Calendar feature tables
    ActivitiesTable,
    EventsTable,
    CarbLoadingPlansTable,
    CarbLoadingDaysTable,

    // Carb Loading Food tables
    CarbLoadingFoodsTable,
    CarbLoadingUserFoodsTable,
    CarbLoadingDayMealsTable,

    // Weather feature tables
    WeatherForecastsTable,

    // Feature survey tables
    FeatureSurveyResponsesTable,

    // External integrations (Final Surge, TrainingPeaks, Strava, etc.)
    IntegrationsTable,

    // Coach mode tables
    CoachesTable,
    CoachAthleteRelationshipsTable,
    CoachMessagesTable,
  ],
  daos: [
    UserDao,
    FoodPreferencesDao,
    ActivityDao,
    FoodsDao,
    ContentDao,
    DiagnosticDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for testing with in-memory database
  factory AppDatabase.memory() {
    return AppDatabase._internal(createNativeMemoryDatabase());
  }

  /// Constructor for migration testing with SchemaVerifier
  /// Allows injecting a custom QueryExecutor for testing migrations
  factory AppDatabase.forTesting(QueryExecutor executor) {
    return AppDatabase._internal(executor);
  }

  /// Internal constructor for factory
  AppDatabase._internal(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 3; // v3: Added integrations, sweat_rate, sync columns, AND coach mode (is_coach, relationships, messages)

  /// Generate a proper UUID v4 for new records
  /// Uses the uuid package to ensure RFC 4122 compliance and exact 36-character length
  String _generateUuid() {
    const uuid = Uuid();
    return uuid.v4();
  }

  /// Ensure sync tracking columns exist for user-authored tables.
  /// Uses ALTER TABLE IF NOT EXISTS which is supported in modern SQLite (3.35+).
  Future<void> ensureUserDataSyncColumns() async {
    // v1 ships with the correct schema; skip runtime ALTERs to avoid legacy migrations.
    return;
  }

  // Note: product_types table has been dropped - now using product_type_enum

  /// V1 database setup with seed database support and migration strategy
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      // Called when database is first created (version 0 -> 1)
      onCreate: (Migrator m) async {
        // Check which tables already exist (from seed DB)
        final existingTablesResult = await customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
        ).get();

        final existingTables = existingTablesResult
            .map((row) => row.read<String>('name'))
            .toSet();

        // 🚨 CRITICAL FIX: m.createAll() DROPS tables before recreating them!
        // This wipes seed data even though tables exist. Instead, we manually
        // create each table using CREATE TABLE IF NOT EXISTS to preserve seed data.

        // Seed tables (already have data - must NOT be recreated)
        // Using actual SQLite table names from seed DB (NOT Drift class names)
        // Note: categories, meal_types, product_types, and their join tables are now dropped
        final seedTables = {
          'foods', // FoodsTable
          'carb_loading_foods', // CarbLoadingFoodsTable
          'user_foods', // UserFoodsTable
        };

        // For each table definition, manually create with IF NOT EXISTS
        for (final table in allTables) {
          final tableName = table.actualTableName;

          // Skip tables that already exist AND are seed tables (have data)
          if (existingTables.contains(tableName) &&
              seedTables.contains(tableName)) {
            continue; // Don't recreate this table
          }

          // Create all other tables (new tables OR non-seed tables)
          await m.createTable(table);
        }

        // Only populate default data for NEW tables (not seed tables)
        await _populateDefaultData();
      },

      // Called immediately after database is opened
      beforeOpen: (details) async {
        // Enable foreign key support (required for Drift)
        await customStatement('PRAGMA foreign_keys = ON');

        if (kDebugMode) {
          // Enable detailed logging in debug mode
          await customStatement('PRAGMA synchronous = NORMAL');
          await customStatement('PRAGMA cache_size = 10000');
        }

        // Schema integrity validation - fail fast if schema is corrupted
        // This replaces the old "safety net" approach with proper validation
        if (!details.wasCreated) {
          await _validateSchemaIntegrity();
        }

        // Normalize any legacy timestamp strings in user_foods to Unix millis
        await _normalizeUserFoodTimestamps();
      },

      // Called when upgrading from older version - uses Drift's official stepByStep migrations
      // Migration logic extracted to lib/shared/database/migrations/ for modularity
      onUpgrade: stepByStep(
        from1To2: (m, schema) => runMigrationV1ToV2(this, m, schema),
        from2To3: (m, schema) => runMigrationV2ToV3(this, m, schema),
      ),
    );
  }

  /// Populate default data for fresh installations
  /// Note: categories, meal_types, and product_types are now enums in the database
  Future<void> _populateDefaultData() async {
    // No longer need to populate default data - using enums now
  }

  /// Validate schema integrity on database open
  ///
  /// Uses Drift's `allTables` to automatically check that all expected tables
  /// and columns exist in the database. This is version-agnostic - works for
  /// v2, v3, v4, etc. without code changes.
  ///
  /// If validation fails (indicating a failed or incomplete migration), it will:
  /// 1. Delete the corrupted database
  /// 2. Throw a [DatabaseSchemaException] to trigger app restart with fresh database
  ///
  /// This approach replaces manual column checking and automatically handles
  /// any new columns added in future schema versions.
  Future<void> _validateSchemaIntegrity() async {
    final errors = <String>[];

    // Iterate through all tables defined in Drift and verify they exist with correct columns
    for (final table in allTables) {
      final tableName = table.actualTableName;

      try {
        // Get actual columns from SQLite
        final actualColumns = await customSelect(
          "PRAGMA table_info('$tableName')",
        ).get();

        if (actualColumns.isEmpty) {
          // Table doesn't exist at all
          errors.add('Table "$tableName" does not exist');
          continue;
        }

        final actualColumnNames = actualColumns
            .map((row) => row.read<String>('name'))
            .toSet();

        // Get expected columns from Drift's table definition
        final expectedColumnNames = table.$columns
            .map((col) => col.$name)
            .toSet();

        // Check for missing columns
        final missingColumns = expectedColumnNames.difference(actualColumnNames);
        if (missingColumns.isNotEmpty) {
          errors.add('Table "$tableName" missing columns: ${missingColumns.join(', ')}');
        }
      } catch (e) {
        // Error querying table - might not exist
        errors.add('Failed to validate table "$tableName": $e');
      }
    }

    // If any errors found, delete database and force recreation
    if (errors.isNotEmpty) {
      if (kDebugMode) {
        for (final error in errors) {
          print('❌ Schema validation failed: $error');
        }
        print('🗑️ Deleting corrupted database to force fresh sync...');
      }

      // Delete the corrupted database
      await deleteAndResync();

      // Throw exception to signal app needs to restart with fresh database
      throw DatabaseSchemaException(
        'Database schema is corrupted or incomplete. The app will resync data from the server.',
        errors: errors,
      );
    }

    if (kDebugMode) {
      print('✅ Schema validation passed (${allTables.length} tables verified)');
    }
  }

  /// Get the current user profile for the authenticated session.
  ///
  /// [currentAuthUserId] - The current Supabase auth user ID. Pass null if no auth session.
  ///
  /// Returns the profile matching the auth user ID, or null if:
  /// - No auth user ID provided (user not authenticated)
  /// - No profile found matching the auth user ID
  ///
  /// This ensures that after logout, getCurrentUserProfile() returns null
  /// even if old profile data exists in the database from a previous user.
  Future<domain.UserProfile?> getCurrentUserProfile({
    String? currentAuthUserId,
  }) async {
    // If no auth user ID provided, there's no current user
    // This happens after logout when no Supabase session exists
    if (currentAuthUserId == null) {
      return null;
    }

    // Find profile matching this auth user
    return getUserProfileByAuthUserId(currentAuthUserId);
  }

  /// Look up a user profile by Supabase auth user ID.
  Future<domain.UserProfile?> getUserProfileByAuthUserId(
    String authUserId,
  ) async {
    final result =
        await (select(userProfilesTable)
              ..where((u) => u.authUserId.equals(authUserId))
              ..limit(1))
            .getSingleOrNull();

    if (result == null) {
      return null;
    }

    return _convertToDomainUserProfile(result);
  }

  /// Look up a user profile by its primary key/ID.
  Future<domain.UserProfile?> getUserProfileById(String userId) async {
    final result =
        await (select(userProfilesTable)
              ..where((u) => u.id.equals(userId))
              ..limit(1))
            .getSingleOrNull();

    if (result == null) {
      return null;
    }

    return _convertToDomainUserProfile(result);
  }

  /// Save a user profile
  /// [needsUpload] - If true, marks profile for background upload to Supabase (for new registrations)
  ///
  /// IMPORTANT: This method handles the case where a different user exists with the same device_id.
  /// Since device_id has a UNIQUE constraint (legacy schema), we must delete any existing user
  /// with the same device_id before inserting the new user.
  Future<void> saveUserProfile(domain.UserProfile profile, {bool needsUpload = false}) async {
    // Delete any existing user with this device_id that has a DIFFERENT id
    // This handles the case where a new user is created on a device that already has a user
    await (delete(userProfilesTable)
      ..where((u) => u.deviceId.equals(profile.deviceId) & u.id.equals(profile.id).not()))
      .go();

    await into(userProfilesTable).insertOnConflictUpdate(
      UserProfilesTableCompanion.insert(
        id: profile.id,
        deviceId: profile.deviceId,
        authUserId: Value(profile.authUserId),
        authProvider: Value(profile.authProvider),
        isAnonymous: Value(profile.isAnonymous),
        gender: Value(profile.gender.name),
        birthday: Value(profile.birthday),
        heightFeet: Value(profile.heightFeet),
        heightInches: Value(profile.heightInches),
        weightPounds: Value(profile.weightPounds),
        runsWithWaterBottle: Value(profile.runsWithWaterBottle),
        gutTrainingLevel: Value(profile.gutTraining.name),
        sweatRate: Value(profile.sweatRate.name),
        onboardingCompleted: Value(profile.onboardingCompleted),
        createdAt: Value(profile.createdAt),
        updatedAt: Value(profile.updatedAt),
        appVersion: Value(profile.appVersion),
        // Dietary preference and allergies
        // Convert DietaryPreference.none to null for database (constraint doesn't allow 'none')
        dietaryPreference: Value(
          profile.dietaryPreference == null || profile.dietaryPreference == DietaryPreference.none
            ? null
            : profile.dietaryPreference!.dbValue
        ),
        allergies: Value(Allergy.toDbArray(profile.allergies)),
        // Background sync tracking
        needsUpload: Value(needsUpload),
      ),
    );
  }

  /// Update user profile
  /// [needsUpload] - If true, marks profile for background upload to Supabase (defaults to true for onboarding updates)
  Future<void> updateUserProfile(domain.UserProfile profile, {bool needsUpload = true}) async {
    await (update(
      userProfilesTable,
    )..where((u) => u.id.equals(profile.id))).write(
      UserProfilesTableCompanion(
        deviceId: Value(profile.deviceId),
        authUserId: Value(profile.authUserId),
        authProvider: Value(profile.authProvider),
        isAnonymous: Value(profile.isAnonymous),
        gender: Value(profile.gender.name),
        birthday: Value(profile.birthday),
        heightFeet: Value(profile.heightFeet),
        heightInches: Value(profile.heightInches),
        weightPounds: Value(profile.weightPounds),
        runsWithWaterBottle: Value(profile.runsWithWaterBottle),
        gutTrainingLevel: Value(profile.gutTraining.name),
        sweatRate: Value(profile.sweatRate.name),
        onboardingCompleted: Value(profile.onboardingCompleted),
        updatedAt: Value(DateTime.now()),
        appVersion: Value(profile.appVersion),
        // Dietary preference and allergies
        // Convert DietaryPreference.none to null for database (constraint doesn't allow 'none')
        dietaryPreference: Value(
          profile.dietaryPreference == null || profile.dietaryPreference == DietaryPreference.none
            ? null
            : profile.dietaryPreference!.dbValue
        ),
        allergies: Value(Allergy.toDbArray(profile.allergies)),
        // Background sync tracking
        needsUpload: Value(needsUpload),
      ),
    );
  }

  /// Delete user profile
  Future<bool> deleteUserProfile(String userId) async {
    final deletedRows = await (delete(
      userProfilesTable,
    )..where((u) => u.id.equals(userId))).go();
    return deletedRows > 0;
  }

  /// Save food preferences for a user
  ///
  /// [mergeMode] controls how existing preferences are handled:
  /// - `false` (default): Replace all preferences (used when user explicitly saves)
  /// - `true`: Merge with existing preferences, only updating provided items
  ///   (used when syncing from server to avoid data loss)
  /// [source] identifies the origin of the preference:
  /// - 'manual': User explicitly set this preference (default)
  /// - 'allergy:{name}': Auto-set due to an allergy (e.g., 'allergy:gluten')
  /// - 'dietary:{name}': Auto-set due to dietary preference (e.g., 'dietary:vegan')
  Future<void> saveFoodPreferences(
    String userId,
    Map<String, domain.FoodPreference> preferences, {
    Map<String, int>? sliderLevels,
    bool mergeMode = false,
    String source = 'manual',
  }) async {
    await ensureUserDataSyncColumns();

    // Get existing preferences to merge metadata properly
    Map<String, domain.FoodPreference>? existingPrefs;
    Map<String, int>? existingLevels;
    if (mergeMode) {
      existingPrefs = await getUserFoodPreferences(userId);
      existingLevels = await getUserFoodPreferenceLevels(userId);
    }

    await batch((batch) {
      // Only delete all preferences if NOT in merge mode
      // In merge mode, we upsert individual items to preserve local data
      if (!mergeMode) {
        batch.deleteWhere(foodPreferencesTable, (f) => f.userId.equals(userId));
      }

      // Insert/update preferences using upsert
      for (final entry in preferences.entries) {
        final sliderLevel =
            sliderLevels?[entry.key] ?? _defaultSliderLevel(entry.value);
        batch.insert(
          foodPreferencesTable,
          FoodPreferencesTableCompanion.insert(
            id: _generateUuid(),
            userId: userId,
            foodName: entry.key,
            preference: entry
                .value
                .value, // Use .value instead of .name to get database-compatible format
            preferenceLevel: Value(sliderLevel),
            preferenceSource: Value(source),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });

    // Build metadata map, preserving existing entries in merge mode
    final metadata = <String, dynamic>{};

    // In merge mode, start with existing preferences
    if (mergeMode && existingPrefs != null) {
      for (final entry in existingPrefs.entries) {
        final existingLevel = existingLevels?[entry.key] ?? _defaultSliderLevel(entry.value);
        metadata[entry.key] = {
          'preference': entry.value.value,
          'slider_level': existingLevel,
        };
      }
    }

    // Add/update with new preferences (these override existing in merge mode)
    for (final entry in preferences.entries) {
      final sliderLevel = sliderLevels?[entry.key] ?? _defaultSliderLevel(entry.value);
      metadata[entry.key] = {
        'preference': entry.value.value,
        'slider_level': sliderLevel,
      };
    }

    await (update(userProfilesTable)..where((u) => u.id.equals(userId))).write(
      UserProfilesTableCompanion(
        foodPreferences: Value(metadata),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // food_preferences table is server-managed and doesn't have sync columns
    // The batch operations above handle local storage only
  }

  /// Get food preferences for a user
  Future<Map<String, domain.FoodPreference>> getUserFoodPreferences(
    String userId,
  ) async {
    final query = select(foodPreferencesTable)
      ..where((f) => f.userId.equals(userId));
    final results = await query.get();

    final preferencesMap = <String, domain.FoodPreference>{};
    for (final row in results) {
      final preference = domain.FoodPreference.values.firstWhere(
        (p) =>
            p.value ==
            row.preference, // Use .value to match database underscore format
        orElse: () => domain.FoodPreference.dislike,
      );
      preferencesMap[row.foodName] = preference;
    }

    return preferencesMap;
  }

  Future<Map<String, int>> getUserFoodPreferenceLevels(String userId) async {
    final rows = await (select(foodPreferencesTable)
          ..where((f) => f.userId.equals(userId)))
        .get();

    if (rows.isEmpty) {
      // Fallback to legacy JSON metadata in user profile
      final profile = await (select(userProfilesTable)
            ..where((u) => u.id.equals(userId))
            ..limit(1))
          .getSingleOrNull();

      if (profile == null) return {};

      final legacyLevels = <String, int>{};
      profile.foodPreferences.forEach((foodName, rawValue) {
        if (rawValue is Map<String, dynamic>) {
          final slider = rawValue['slider_level'];
          if (slider is num) {
            legacyLevels[foodName] = slider.toInt().clamp(0, 4);
          }
        }
      });

      return legacyLevels;
    }

    final levels = <String, int>{};
    for (final row in rows) {
      final normalizedLevel =
          (row.preferenceLevel ?? _defaultSliderLevel(_parsePreference(row.preference)))
              .clamp(0, 4)
              .toInt();
      levels[row.foodName] = normalizedLevel;
    }

    return levels;
  }

  /// Get liked foods for a user
  Future<List<String>> getLikedFoods(String userId) async {
    final query = select(foodPreferencesTable)
      ..where((f) => f.userId.equals(userId) & f.preference.equals('like'));
    final results = await query.get();
    return results.map((r) => r.foodName).toList();
  }

  /// Get disliked foods for a user
  Future<List<String>> getDislikedFoods(String userId) async {
    final query = select(foodPreferencesTable)
      ..where((f) => f.userId.equals(userId) & f.preference.equals('dislike'));
    final results = await query.get();
    return results.map((r) => r.foodName).toList();
  }

  /// Remove food preferences by source
  /// Used when allergies or dietary preferences are removed to undo auto-avoids
  /// [source] - The source to match (e.g., 'allergy:gluten', 'dietary:vegan')
  /// Returns the number of preferences removed
  Future<int> removeFoodPreferencesBySource(String userId, String source) async {
    return await (delete(foodPreferencesTable)
      ..where((f) => f.userId.equals(userId) & f.preferenceSource.equals(source)))
      .go();
  }

  /// Remove all food preferences with sources matching a pattern
  /// [sourcePrefix] - The prefix to match (e.g., 'allergy:' or 'dietary:')
  /// Returns the number of preferences removed
  Future<int> removeFoodPreferencesBySourcePrefix(String userId, String sourcePrefix) async {
    // Use LIKE pattern for prefix matching
    return await (delete(foodPreferencesTable)
      ..where((f) => f.userId.equals(userId))
      ..where((f) => f.preferenceSource.like('$sourcePrefix%')))
      .go();
  }

  /// Get food preferences with their sources for a user
  /// Returns a map of food name -> preference source
  Future<Map<String, String>> getFoodPreferenceSources(String userId) async {
    final query = select(foodPreferencesTable)
      ..where((f) => f.userId.equals(userId));
    final results = await query.get();

    final sourcesMap = <String, String>{};
    for (final row in results) {
      sourcesMap[row.foodName] = row.preferenceSource;
    }
    return sourcesMap;
  }

  /// Get all food preference entries for a user (for upload to Supabase)
  /// Returns raw FoodPreferenceEntry objects with id, food_name, preference, preference_level
  Future<List<FoodPreferenceEntry>> getAllFoodPreferenceEntries(String userId) async {
    final query = select(foodPreferencesTable)
      ..where((f) => f.userId.equals(userId));
    return await query.get();
  }

  /// Get count of nutrition foods in local database
  /// Used during app startup to determine if fallback food loading is needed
  Future<int> getFoodCount() async {
    final countQuery = selectOnly(foodsTable)
      ..addColumns([foodsTable.id.count()]);
    final result = await countQuery.getSingle();
    return result.read(foodsTable.id.count()) ?? 0;
  }

  /// Attach a nutrition plan JSON payload directly to an activity row.
  Future<void> setActivityNutritionPlan({
    required String activityId,
    required String planData,
  }) async {
    await (update(
      activitiesTable,
    )..where((tbl) => tbl.id.equals(activityId))).write(
      ActivitiesTableCompanion(
        nutritionPlanData: Value(planData),
        needsUpload: const Value(true),
        localUpdatedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Clear the nutrition plan fields for an activity.
  Future<void> clearActivityNutritionPlan(String activityId) async {
    await (update(
      activitiesTable,
    )..where((tbl) => tbl.id.equals(activityId))).write(
      const ActivitiesTableCompanion(
        nutritionPlanData: Value(null),
        needsUpload: Value(true),
      ),
    );
  }

  /// Fetch an activity row by primary key.
  Future<Activity?> getActivityByIdLocal(String activityId) async {
    final query = select(activitiesTable)
      ..where((tbl) => tbl.id.equals(activityId))
      ..limit(1);
    return await query.getSingleOrNull();
  }

  /// Get the most recently updated activity that has a nutrition plan.
  Future<Activity?> getLatestActivityWithNutritionPlan(String userId) async {
    final query = select(activitiesTable)
      ..where(
        (tbl) => tbl.userId.equals(userId) & tbl.nutritionPlanData.isNotNull(),
      )
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)])
      ..limit(1);
    return await query.getSingleOrNull();
  }

  /// Get all activities for a user that contain nutrition plans.
  Future<List<Activity>> getActivitiesWithNutritionPlans(String userId) async {
    final query = select(activitiesTable)
      ..where(
        (tbl) => tbl.userId.equals(userId) & tbl.nutritionPlanData.isNotNull(),
      )
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]);
    return await query.get();
  }

  /// Clear user-scoped data from local database
  ///
  /// **Behavior:**
  /// - **Logout**: Keeps all data (forceDelete=false) for offline-first architecture
  /// - **Account Deletion**: Deletes user's data (forceDelete=true)
  ///
  /// **Why keep data on logout?**
  /// - Allows users to sign back in offline and see their data
  /// - Supports multi-user scenarios (queries filter by current user)
  /// - Follows offline-first best practices (Linear, Notion, Figma)
  ///
  /// **Security:**
  /// - Queries already filter by getCurrentUserProfile().id
  /// - Data is isolated between users via user_id
  /// - For shared devices, use Settings > Clear Local Data
  ///
  /// @param userId - Required for account deletion, identifies which user to delete
  /// @param forceDelete - If true, actually delete data. If false, keep data (no-op)
  Future<void> clearUserScopedData({
    String? userId,
    bool forceDelete = false,
  }) async {
    // OPTION B: No-op for logout (keep data for offline-first)
    // Only delete if explicitly deleting account (forceDelete = true)

    if (!forceDelete) {
      // Logout scenario - keep all data
      // Queries already filter by getCurrentUserProfile().id
      return;
    }

    // Account deletion scenario - delete this user's data
    if (userId == null) {
      throw ArgumentError('userId required for account deletion');
    }

    await transaction(() async {
      // Delete with WHERE user_id = userId
      // Child tables first (foreign key constraints)

      // carb_loading_day_meals (via carb_loading_days via carb_loading_plans.user_id)
      await customStatement('''
        DELETE FROM carb_loading_day_meals
        WHERE carb_loading_day_id IN (
          SELECT id FROM carb_loading_days
          WHERE carb_loading_plan_id IN (
            SELECT id FROM carb_loading_plans WHERE user_id = ?
          )
        )
      ''', [userId]);

      // carb_loading_days (via carb_loading_plans.user_id)
      await customStatement('''
        DELETE FROM carb_loading_days
        WHERE carb_loading_plan_id IN (
          SELECT id FROM carb_loading_plans WHERE user_id = ?
        )
      ''', [userId]);

      // Direct user_id filtering
      await (delete(carbLoadingPlansTable)..where((t) => t.userId.equals(userId))).go();
      await (delete(eventsTable)..where((t) => t.userId.equals(userId))).go();
      await (delete(activitiesTable)..where((t) => t.userId.equals(userId))).go();
      await (delete(carbLoadingUserFoodsTable)..where((t) => t.userId.equals(userId))).go();
      await (delete(userFoodsTable)..where((t) => t.userId.equals(userId))).go();
      await (delete(featureSurveyResponsesTable)..where((t) => t.deviceId.equals(userId))).go();

      // feedback uses device_id, need to join with users table
      await customStatement('''
        DELETE FROM feedback_table
        WHERE device_id IN (
          SELECT device_id FROM users WHERE id = ?
        )
      ''', [userId]);

      // food_preferences uses user_id
      await (delete(foodPreferencesTable)..where((t) => t.userId.equals(userId))).go();

      // Delete user profile last
      await (delete(userProfilesTable)..where((t) => t.id.equals(userId))).go();
    });
  }

  /// Clear all data (for testing/reset)
  /// This clears ALL data regardless of user - used for testing and full reset
  Future<void> clearAllData() async {
    await transaction(() async {
      // Child tables first to satisfy foreign key constraints
      await delete(carbLoadingDayMealsTable).go();
      await delete(carbLoadingDaysTable).go();
      await delete(carbLoadingPlansTable).go();
      await delete(eventsTable).go();
      await delete(activitiesTable).go();
      await delete(carbLoadingUserFoodsTable).go();
      await delete(userFoodsTable).go();
      await delete(featureSurveyResponsesTable).go();
      await delete(feedbackTable).go();
      await delete(userProfilesTable).go();
      await delete(foodPreferencesTable).go();
    });
  }

  /// Delete ALL data from ALL tables - for troubleshooting/reset
  /// Uses PRAGMA to disable foreign keys, making it safe regardless of table order
  /// This is the Drift-recommended approach for complete database clearing
  Future<void> deleteEverythingForTroubleshooting() async {
    await transaction(() async {
      // Disable foreign key checks to allow deletion in any order
      await customStatement('PRAGMA foreign_keys = OFF');

      // Delete from all tables
      for (final table in allTables) {
        await delete(table).go();
      }

      // Re-enable foreign key checks
      await customStatement('PRAGMA foreign_keys = ON');
    });
  }

  /// Migrate all user-scoped data from one user ID to another
  /// Used when signing into an existing OAuth account to preserve anonymous user's data
  /// Strategy: DELETE existing OAuth user data first, then UPDATE anonymous user data to OAuth user ID
  /// This preserves the fresh onboarding data from the anonymous session
  Future<void> migrateUserData(String fromUserId, String toUserId) async {
    await transaction(() async {
      // STRATEGY: For each table, we DELETE the OAuth user's old data first,
      // then UPDATE the anonymous user's fresh data to use the OAuth user ID.
      // This ensures the fresh onboarding data is preserved without UNIQUE constraint violations.

      // ============ ACTIVITIES ============
      // Delete OAuth user's old activities (if any)
      await customStatement(
        'DELETE FROM activities WHERE user_id = ?',
        [toUserId],
      );
      // Migrate anonymous user's activities to OAuth user
      await customStatement(
        'UPDATE activities SET user_id = ? WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      // ============ EVENTS ============
      // Delete OAuth user's old events (if any)
      await customStatement(
        'DELETE FROM events WHERE user_id = ?',
        [toUserId],
      );
      // Migrate anonymous user's events to OAuth user
      await customStatement(
        'UPDATE events SET user_id = ? WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      // ============ FOOD PREFERENCES ============
      // Delete OAuth user's old food preferences (if any)
      await customStatement(
        'DELETE FROM food_preferences_table WHERE user_id = ?',
        [toUserId],
      );
      // Migrate anonymous user's food preferences to OAuth user
      await customStatement(
        'UPDATE food_preferences_table SET user_id = ? WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      // ============ USER FOODS ============
      // Delete OAuth user's old custom foods (if any)
      await customStatement(
        'DELETE FROM user_foods WHERE user_id = ?',
        [toUserId],
      );
      // Migrate anonymous user's custom foods to OAuth user
      await customStatement(
        'UPDATE user_foods SET user_id = ? WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      // ============ CARB LOADING PLANS ============
      // Delete OAuth user's old carb loading plans (if any)
      // Note: Drift doesn't have FK cascades - must manually delete child tables first

      // Step 1: Delete carb_loading_day_meals for OAuth user's plans
      await customStatement('''
        DELETE FROM carb_loading_day_meals
        WHERE carb_loading_day_id IN (
          SELECT id FROM carb_loading_days
          WHERE carb_loading_plan_id IN (
            SELECT id FROM carb_loading_plans WHERE user_id = ?
          )
        )
      ''', [toUserId]);

      // Step 2: Delete carb_loading_days for OAuth user's plans
      await customStatement('''
        DELETE FROM carb_loading_days
        WHERE carb_loading_plan_id IN (
          SELECT id FROM carb_loading_plans WHERE user_id = ?
        )
      ''', [toUserId]);

      // Step 3: Delete carb_loading_plans for OAuth user
      await customStatement(
        'DELETE FROM carb_loading_plans WHERE user_id = ?',
        [toUserId],
      );
      // Migrate anonymous user's carb loading plans to OAuth user
      // Note: carb_loading_days does NOT have user_id column - it inherits
      // user ownership through carb_loading_plan_id foreign key
      await customStatement(
        'UPDATE carb_loading_plans SET user_id = ? WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      // ============ CARB LOADING USER FOODS ============
      // Delete OAuth user's old carb loading user foods (if any)
      await customStatement(
        'DELETE FROM carb_loading_user_foods WHERE user_id = ?',
        [toUserId],
      );
      // Migrate anonymous user's carb loading user foods to OAuth user
      await customStatement(
        'UPDATE carb_loading_user_foods SET user_id = ? WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      // ============ FEEDBACK ============
      // Note: feedback table uses device_id, NOT user_id
      // Feedback stays with the device, not migrated with user account
      // No migration needed here

      // ============ FEATURE SURVEY RESPONSES ============
      // Note: feature_survey_responses table uses device_id, NOT user_id
      // Survey responses stay with the device (like feedback), not migrated with user account
      // The device_id is inherited from anonymous user to OAuth user via users.device_id
      // No migration needed here

      // ============ INTEGRATIONS ============
      // Delete OAuth user's old integrations (if any)
      await customStatement(
        'DELETE FROM integrations WHERE user_id = ?',
        [toUserId],
      );
      // Migrate anonymous/temp user's integrations to OAuth user
      await customStatement(
        'UPDATE integrations SET user_id = ? WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      // ============ USER PROFILE ============
      // Delete the old anonymous user profile
      // The OAuth user profile will be created/updated separately by the caller
      await customStatement(
        'DELETE FROM users WHERE id = ?',
        [fromUserId],
      );
    });
  }

  /// Check if database has any user data
  Future<bool> hasUserData() async {
    final userCount = await (selectOnly(
      userProfilesTable,
    )..addColumns([userProfilesTable.id.count()])).getSingle();
    return userCount.read(userProfilesTable.id.count())! > 0;
  }

  /// Get database statistics for logging/debugging
  Future<Map<String, int>> getDatabaseStats() async {
    final userCount = await (selectOnly(
      userProfilesTable,
    )..addColumns([userProfilesTable.id.count()])).getSingle();
    final preferencesCount = await (selectOnly(
      foodPreferencesTable,
    )..addColumns([foodPreferencesTable.userId.count()])).getSingle();
    final foodsCount = await (selectOnly(
      foodsTable,
    )..addColumns([foodsTable.id.count()])).getSingle();
    final contentCount = await (selectOnly(
      appContentTable,
    )..addColumns([appContentTable.id.count()])).getSingle();

    return {
      'users': userCount.read(userProfilesTable.id.count())!,
      'preferences': preferencesCount.read(
        foodPreferencesTable.userId.count(),
      )!,
      'foods': foodsCount.read(foodsTable.id.count())!,
      'content': contentCount.read(appContentTable.id.count())!,
    };
  }

  // === Food and content management ===

  /// Get all cached foods
  Future<List<FoodEntry>> getAllCachedFoods() async {
    return await select(foodsTable).get();
  }

  /// Cache foods from Supabase
  Future<void> cacheFoods(List<Map<String, dynamic>> foodsData) async {
    await batch((batch) {
      for (final food in foodsData) {
        batch.insert(
          foodsTable,
          _mapToFoodEntry(food),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Get foods by category (using array-based categories now)
  /// TODO: Implement array-based category filtering after foods_table is updated
  Future<List<FoodEntry>> getFoodsByCategory(String categoryName) async {
    // Temporarily return all foods until array filtering is implemented
    return await select(foodsTable).get();
  }

  /// Get active app content
  Future<AppContentEntry?> getActiveAppContent({
    String environment = 'production',
    String locale = 'en',
  }) async {
    final query = select(appContentTable)
      ..where(
        (c) =>
            c.environment.equals(environment) &
            c.locale.equals(locale) &
            c.isActive.equals(true),
      )
      ..orderBy([(c) => OrderingTerm.desc(c.version)])
      ..limit(1);

    return await query.getSingleOrNull();
  }

  /// Cache app content
  Future<void> cacheAppContent(Map<String, dynamic> contentData) async {
    final entry = AppContentTableCompanion(
      id: Value(contentData['id'] ?? 'main'),
      version: Value(contentData['version'] ?? 1),
      environment: Value(contentData['environment'] ?? 'production'),
      locale: Value(contentData['locale'] ?? 'en'),
      content: Value(contentData['content'] ?? '{}'),
      isActive: const Value(true),
      lastSyncAt: Value(DateTime.now()),
      isCached: const Value(true),
    );

    await into(appContentTable).insertOnConflictUpdate(entry);
  }

  /// Helper method to map Supabase food data to FoodEntry (updated for new simplified schema)
  FoodsTableCompanion _mapToFoodEntry(Map<String, dynamic> foodData) {
    return FoodsTableCompanion.insert(
      id: foodData['id'] ?? '',
      name: Value(foodData['name']),
      displayName: Value(foodData['display_name']),
      imageAddress: Value(foodData['image_address']),
      description: Value(foodData['description']),
      instructions: Value(foodData['instructions']),
      nutritionalInfo: Value(foodData['nutritional_info']),
      servingAmount: Value(foodData['serving_amount']?.toDouble()),
      servingUnit: Value(foodData['serving_unit']),
      servingUnitPlural: Value(foodData['serving_unit_plural']),
      servingQualifier: Value(foodData['serving_qualifier']),
      servingSize: Value(foodData['serving_size']),
      servingDescription: Value(foodData['serving_description']),
      isElectrolyte: Value(foodData['is_electrolyte'] ?? false),
      maxServingsBefore: Value(foodData['max_servings_before']),
      maxServingsDuring: Value(foodData['max_servings_during']),
      maxServingsAfter: Value(foodData['max_servings_after']),
      sodiumMg: Value(foodData['sodium_mg']),
      caffeineMg: Value(foodData['caffeine_mg']),
      potassiumMg: Value(foodData['potassium_mg']),
      fatPerServing: Value(foodData['fat_per_serving']?.toDouble()),
      carbsPerServing: Value(foodData['carbs_per_serving']?.toDouble()),
      proteinPerServing: Value(foodData['protein_per_serving']?.toDouble()),
      caloriesPerServing: Value(foodData['calories_per_serving']),
      fluidMlPerServing: Value(foodData['fluid_ml_per_serving']?.toDouble()),
      productTypeId: Value(foodData['product_type_id']),
      purchaseUrl: Value(foodData['purchase_url']),
      affiliateSource: Value(foodData['affiliate_source']),
      showInPreferences: Value(foodData['show_in_preferences'] ?? false),
      preferencePriority: Value(foodData['preference_priority']),
    );
  }

  /// Save survey response to local database
  Future<void> saveSurveyResponse({
    required String id,
    required int confidenceLevel,
    required String confidenceLabel,
    required String reuseIntent,
    bool reminderRequested = false,
    List<String>? missedReasons,
    String? missedOther,
    int? reminderDayOfWeek,
    int? reminderHour,
    int? reminderMinute,
    bool? reminderRecurring,
    String? deviceId,
    String? planName,
  }) async {
    await ensureUserDataSyncColumns();
    await into(feedbackTable).insertOnConflictUpdate(
      FeedbackTableCompanion.insert(
        id: id,
        satisfactionLevel: 2, // Default to "just right" for now
        satisfactionEmoji: '🤗',
        satisfactionLabel: 'Just right',
        confidenceLevel: Value(confidenceLevel),
        confidenceLabel: Value(confidenceLabel),
        reuseIntent: Value(reuseIntent),
        reminderRequested: Value(reminderRequested),
        missedReasons: Value(missedReasons?.join(',')),
        missedOther: Value(missedOther),
        reminderDayOfWeek: Value(reminderDayOfWeek),
        reminderHour: Value(reminderHour ?? 17),
        reminderMinute: Value(reminderMinute ?? 0),
        reminderRecurring: Value(reminderRecurring ?? false),
        deviceId: Value(deviceId),
        planName: Value(planName),
        timestamp: Value(DateTime.now()),
      ),
    );

    // Use Unix timestamp in milliseconds for Drift compatibility
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    await customStatement(
      'UPDATE feedback SET needs_upload = 1, local_updated_at = ? WHERE id = ?',
      [nowMillis, id],
    );
  }

  /// Get latest survey response for user
  Future<FeedbackEntry?> getLatestSurveyResponse(String deviceId) async {
    final query = select(feedbackTable)
      ..where((f) => f.deviceId.equals(deviceId))
      ..orderBy([(f) => OrderingTerm.desc(f.createdAt)])
      ..limit(1);

    final results = await query.get();
    return results.isNotEmpty ? results.first : null;
  }

  /// Update user notification preferences
  Future<void> updateUserNotificationPreferences({
    required String userId,
    required bool notificationsEnabled,
    required int defaultReminderDay,
    required int defaultReminderHour,
    required int defaultReminderMinute,
    required bool defaultReminderRecurring,
  }) async {
    await (update(userProfilesTable)..where((u) => u.id.equals(userId))).write(
      UserProfilesTableCompanion(
        notificationsEnabled: Value(notificationsEnabled),
        defaultReminderDay: Value(defaultReminderDay),
        defaultReminderHour: Value(defaultReminderHour),
        defaultReminderMinute: Value(defaultReminderMinute),
        defaultReminderRecurring: Value(defaultReminderRecurring),
      ),
    );
  }

  /// Check if swipe hint animation has been shown for current user
  /// NOTE: Swipe hint now uses SharedPreferences for global persistence
  /// This method is kept for backward compatibility with user profiles
  Future<bool> hasShownSwipeHint() async {
    final user = await getCurrentUserProfile();
    if (user != null) {
      return user.swipeHintShown;
    }
    return false; // Default to not shown if no user profile
  }

  /// Mark swipe hint animation as shown for current user
  /// NOTE: Swipe hint now uses SharedPreferences for global persistence
  /// This method is kept for backward compatibility with user profiles
  Future<void> markSwipeHintAsShown() async {
    final user = await getCurrentUserProfile();
    if (user != null) {
      // Update user profile
      await (update(
        userProfilesTable,
      )..where((t) => t.id.equals(user.id))).write(
        UserProfilesTableCompanion(
          swipeHintShown: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  // === User Foods Methods (Phase 3 implementation) ===

  /// Save a scanned food with categories and activity types arrays
  Future<void> saveUserFood({
    required String deviceId,
    required String userId,
    required String id,
    required String clientFoodId,
    String? barcode,
    required String name,
    String? displayName,
    String? displayNamePlural,
    String? description,
    String? imageAddress,
    double? servingAmount,
    String? servingUnit,
    int? caloriesPerServing,
    double? carbsPerServing,
    double? proteinPerServing,
    double? fatPerServing,
    int? sodiumMg,
    double? fluidMlPerServing,
    String? productTypeId,
    required List<String> categories,
    List<String>? activityTypes,
    DateTime? clientUpdatedAt,
  }) async {
    await ensureUserDataSyncColumns();
    // Convert arrays to PostgreSQL array format for consistency with Supabase
    // Format: {value1,value2,value3} or null if empty
    final categoriesJson = categories.isNotEmpty
        ? '{${categories.join(',')}}'
        : null;
    final activityTypesJson = activityTypes != null && activityTypes.isNotEmpty
        ? '{${activityTypes.join(',')}}'
        : null;

    // Insert the user food with category and activity type arrays
    await into(userFoodsTable).insert(
      UserFoodsTableCompanion.insert(
        id: id,
        deviceId: deviceId,
        userId: userId,
        clientFoodId: Value(clientFoodId),
        barcode: Value(barcode),
        name: name,
        displayName: Value(displayName),
        displayNamePlural: Value(displayNamePlural),
        description: Value(description),
        imageAddress: Value(imageAddress),
        servingAmount: Value(servingAmount),
        servingUnit: Value(servingUnit),
        caloriesPerServing: Value(caloriesPerServing),
        carbsPerServing: Value(carbsPerServing),
        proteinPerServing: Value(proteinPerServing),
        fatPerServing: Value(fatPerServing),
        sodiumMg: Value(sodiumMg),
        fluidMlPerServing: Value(fluidMlPerServing),
        productTypeId: Value(productTypeId),
        categories: Value(categoriesJson),
        activityTypes: Value(activityTypesJson),
        clientUpdatedAt: Value(clientUpdatedAt),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // Mark as dirty for sync - use Unix timestamp for Drift compatibility
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    await customStatement(
      'UPDATE user_foods SET needs_upload = 1, local_updated_at = ? WHERE id = ?',
      [nowMillis, id],
    );
  }

  /// Update an existing user food
  Future<bool> updateUserFood({
    required String id,
    String? name,
    String? displayName,
    String? displayNamePlural,
    String? description,
    double? servingAmount,
    String? servingUnit,
    int? caloriesPerServing,
    double? carbsPerServing,
    double? proteinPerServing,
    double? fatPerServing,
    int? sodiumMg,
    double? fluidMlPerServing,
    List<String>? categories,
  }) async {
    await ensureUserDataSyncColumns();

    // Build update companion with only provided fields
    final companion = UserFoodsTableCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      displayName: displayName != null ? Value(displayName) : const Value.absent(),
      displayNamePlural: displayNamePlural != null ? Value(displayNamePlural) : const Value.absent(),
      description: description != null ? Value(description) : const Value.absent(),
      servingAmount: servingAmount != null ? Value(servingAmount) : const Value.absent(),
      servingUnit: servingUnit != null ? Value(servingUnit) : const Value.absent(),
      caloriesPerServing: caloriesPerServing != null ? Value(caloriesPerServing) : const Value.absent(),
      carbsPerServing: carbsPerServing != null ? Value(carbsPerServing) : const Value.absent(),
      proteinPerServing: proteinPerServing != null ? Value(proteinPerServing) : const Value.absent(),
      fatPerServing: fatPerServing != null ? Value(fatPerServing) : const Value.absent(),
      sodiumMg: sodiumMg != null ? Value(sodiumMg) : const Value.absent(),
      fluidMlPerServing: fluidMlPerServing != null ? Value(fluidMlPerServing) : const Value.absent(),
      categories: categories != null
          ? Value(categories.isNotEmpty ? '{${categories.join(',')}}' : null)
          : const Value.absent(),
      updatedAt: Value(DateTime.now()),
      clientUpdatedAt: Value(DateTime.now()),
    );

    final updatedRows = await (update(userFoodsTable)
          ..where((f) => f.id.equals(id)))
        .write(companion);

    // Mark as dirty for sync
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    await customStatement(
      'UPDATE user_foods SET needs_upload = 1, local_updated_at = ? WHERE id = ?',
      [nowMillis, id],
    );

    return updatedRows > 0;
  }

  /// Get user foods for a user
  /// Searches by both userId AND deviceId for backwards compatibility
  /// (older foods may have been saved with deviceId only)
  Future<List<UserFood>> getUserFoods(String userId) async {
    final query = select(userFoodsTable)
      ..where((f) =>
          (f.userId.equals(userId) | f.deviceId.equals(userId)) &
          f.isDeleted.equals(false))
      ..orderBy([(f) => OrderingTerm.desc(f.createdAt)]);

    try {
      return await query.get();
    } on FormatException {
      // Legacy rows may store timestamps as TEXT; normalize and retry
      await _normalizeUserFoodTimestamps();
      return await query.get();
    }
  }

  /// Normalize legacy TEXT timestamps in user_foods to Unix millis to satisfy Drift
  Future<void> _normalizeUserFoodTimestamps() async {
    const timestampColumns = [
      'created_at',
      'updated_at',
      'client_updated_at',
      'local_updated_at',
    ];

    await transaction(() async {
      for (final column in timestampColumns) {
        await customStatement('''
          UPDATE user_foods
          SET $column = CAST(
            strftime('%s', replace(replace($column, 'T', ' '), 'Z', ''))
            AS INTEGER
          ) * 1000
          WHERE typeof($column) = 'text'
            AND $column IS NOT NULL
            AND $column != ''
            AND strftime('%s', replace(replace($column, 'T', ' '), 'Z', '')) IS NOT NULL;
        ''');
      }
    });
  }

  /// Check for duplicate barcode in user foods
  Future<bool> hasUserFoodWithBarcode(String userId, String barcode) async {
    final query = select(userFoodsTable)
      ..where(
        (f) =>
            f.userId.equals(userId) &
            f.barcode.equals(barcode) &
            f.isDeleted.equals(false),
      )
      ..limit(1);

    final results = await query.get();
    return results.isNotEmpty;
  }

  /// Delete user food completely (not soft delete)
  Future<bool> deleteUserFood(String userFoodId) async {
    await ensureUserDataSyncColumns();
    // Soft delete: mark is_deleted for offline sync durability
    final updatedRows =
        await (update(userFoodsTable)..where((f) => f.id.equals(userFoodId)))
            .write(const UserFoodsTableCompanion(isDeleted: Value(true)));

    // Update sync tracking columns - use Unix timestamp for Drift compatibility
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    await customStatement(
      'UPDATE user_foods SET needs_upload = 1, local_updated_at = ? WHERE id = ?',
      [nowMillis, userFoodId],
    );

    return updatedRows > 0;
  }

  Future<void> replaceUserFoods(String userId, List<Map<String, dynamic>> remoteFoods) async {
    await transaction(() async {
      await (delete(userFoodsTable)..where((tbl) => tbl.userId.equals(userId))).go();

      for (final food in remoteFoods) {
        try {
          final categoriesJson = food['categories'];
          final activityTypesJson = food['activity_types'];

          await into(userFoodsTable).insertOnConflictUpdate(
            UserFoodsTableCompanion(
              id: Value(food['id'] as String),
              deviceId: Value(food['device_id'] as String? ?? userId),
              userId: Value(userId),
              clientFoodId: Value(food['client_food_id'] as String?),
              barcode: Value(food['barcode'] as String?),
              name: Value(food['name'] as String),
              displayName: Value(food['display_name'] as String?),
              displayNamePlural: Value(food['display_name_plural'] as String?),
              description: Value(food['description'] as String?),
              imageAddress: Value(food['image_address'] as String?),
              servingAmount: Value((food['serving_amount'] as num?)?.toDouble()),
              servingUnit: Value(food['serving_unit'] as String?),
              caloriesPerServing: Value(food['calories_per_serving'] as int?),
              carbsPerServing: Value((food['carbs_per_serving'] as num?)?.toDouble()),
              proteinPerServing: Value((food['protein_per_serving'] as num?)?.toDouble()),
              fatPerServing: Value((food['fat_per_serving'] as num?)?.toDouble()),
              sodiumMg: Value(food['sodium_mg'] as int?),
              fluidMlPerServing: Value((food['fluid_ml_per_serving'] as num?)?.toDouble()),
              productTypeId: Value((food['product_type'] ?? food['product_type_id']) as String?),
              categories: Value(
                categoriesJson is List
                    ? jsonEncode(categoriesJson)
                    : categoriesJson as String?,
              ),
              activityTypes: Value(
                activityTypesJson is List
                    ? jsonEncode(activityTypesJson)
                    : activityTypesJson as String?,
              ),
              isElectrolyte: Value(_asBool(food['is_electrolyte'])),
              toExcludeFromSolver: Value(_asBool(food['to_exclude_from_solver'])),
              isDeleted: Value(_asBool(food['is_deleted'])),
              createdAt: Value(_parseDate(food['created_at'] ) ?? DateTime.now()),
              updatedAt: Value(_parseDate(food['updated_at'] ) ?? DateTime.now()),
              clientUpdatedAt: Value(_parseDate(food['client_updated_at'])),
              needsUpload: const Value(false),
            ),
          );
        } catch (_) {
          // Skip malformed rows but continue syncing others
        }
      }
    });
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return false;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  /// Convert UserFood (Drift) to FoodItem (Domain) for display
  FoodItem convertUserFoodToFoodItem(UserFood userFood) {
    // Parse categories from database string field
    final categories = _parseUserFoodCategories(userFood.categories);

    return FoodItem(
      id: userFood.id,
      name: userFood.name,
      imageAddress: userFood.imageAddress,
      description: userFood.description,
      categories: categories,
      servingAmount: userFood.servingAmount,
      displayName: userFood.displayName,
      displayNamePlural: userFood.displayNamePlural,
      carbsPerServing: userFood.carbsPerServing,
      proteinPerServing: userFood.proteinPerServing,
      fatPerServing: userFood.fatPerServing,
      caloriesPerServing: userFood.caloriesPerServing,
      fluidMlPerServing: userFood.fluidMlPerServing,
      sodiumMg: userFood.sodiumMg,
      beforeRunSuitable: true, // Default for scanned foods
      duringRunSuitable: true,
      runPortable: true,
      requiresPreparation: false,
      aidStationAvailable: false,
      maxServingsBefore: 2,
      maxServingsDuring: 1,
      toExcludeFromSolver: userFood.toExcludeFromSolver,
    );
  }

  /// Parse categories from UserFood database string to FoodCategory list
  /// Handles PostgreSQL array format {a,b,c} and JSON format ["a","b"]
  List<FoodCategory> _parseUserFoodCategories(String? categoriesStr) {
    if (categoriesStr == null || categoriesStr.isEmpty) {
      return [];
    }

    final trimmed = categoriesStr.trim();
    List<String> categoryStrings = [];

    // Handle PostgreSQL array format: {before_run,during_run,after_run}
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      final inner = trimmed.substring(1, trimmed.length - 1);
      if (inner.isNotEmpty) {
        categoryStrings = inner.split(',').map((s) => s.trim()).toList();
      }
    }
    // Handle JSON array format: ["before_run","during_run"]
    else if (trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          categoryStrings = List<String>.from(decoded);
        }
      } catch (_) {
        // Fallback to comma-separated
        categoryStrings = trimmed.split(',').map((s) => s.trim()).toList();
      }
    }
    // Fallback: treat as single category or comma-separated
    else if (trimmed.contains(',')) {
      categoryStrings = trimmed.split(',').map((s) => s.trim()).toList();
    } else if (trimmed.isNotEmpty) {
      categoryStrings = [trimmed];
    }

    // Convert strings to FoodCategory enums
    return categoryStrings
        .map((str) {
          try {
            return FoodCategory.fromDbValue(str);
          } catch (_) {
            return null;
          }
        })
        .whereType<FoodCategory>()
        .toList();
  }

  /// Convert Drift UserProfileEntry to Domain UserProfile
  domain.UserProfile _convertToDomainUserProfile(UserProfileEntry dbUser) {
    return domain.UserProfile(
      id: dbUser.id,
      deviceId: dbUser.deviceId,
      authUserId: dbUser.authUserId,
      authProvider: dbUser.authProvider,
      isAnonymous: dbUser.isAnonymous,
      gender: domain.Gender.values.firstWhere(
        (g) => g.name == dbUser.gender,
        orElse: () => domain.Gender.other,
      ),
      birthday: dbUser.birthday ?? DateTime.now(),
      heightFeet: dbUser.heightFeet ?? 0,
      heightInches: dbUser.heightInches ?? 0,
      weightPounds: dbUser.weightPounds ?? 0.0,
      runsWithWaterBottle: dbUser.runsWithWaterBottle,
      gutTraining: domain.GutTraining.values.firstWhere(
        (g) => g.name == dbUser.gutTrainingLevel,
        orElse: () => domain.GutTraining.moderate,
      ),
      sweatRate: domain.SweatRateCat.values.firstWhere(
        (s) => s.name == dbUser.sweatRate,
        orElse: () => domain.SweatRateCat.medium,
      ),
      onboardingCompleted: dbUser.onboardingCompleted,
      createdAt: dbUser.createdAt,
      updatedAt: dbUser.updatedAt,
      appVersion: dbUser.appVersion ?? '',
      swipeHintShown: dbUser.swipeHintShown,
      // Dietary preference and allergies (onboarding revamp)
      // Convert null to DietaryPreference.none for UI (database stores null, UI uses none enum)
      dietaryPreference: DietaryPreference.fromDbValue(dbUser.dietaryPreference) ?? DietaryPreference.none,
      allergies: Allergy.fromDbArray(dbUser.allergies),
      // Coach mode
      isCoach: dbUser.isCoach,
      // Sharing preferences
      senderName: dbUser.senderName,
    );
  }

  int _defaultSliderLevel(domain.FoodPreference preference) {
    switch (preference) {
      case domain.FoodPreference.dislike:
        return 1;
      case domain.FoodPreference.willingToTry:
        return 2;
      case domain.FoodPreference.like:
        return 3;
    }
  }

  domain.FoodPreference _parsePreference(String value) {
    return domain.FoodPreference.values.firstWhere(
      (p) => p.value == value,
      orElse: () => domain.FoodPreference.willingToTry,
    );
  }

  // === Database Health & Recovery Methods ===

  /// Check if database is healthy using PRAGMA integrity_check
  /// Returns true if database passes integrity check, false otherwise
  Future<bool> isDatabaseHealthy() async {
    try {
      final result = await customSelect('PRAGMA integrity_check').get();

      if (result.isEmpty) {
        return false;
      }

      final integrityCheck = result.first.data['integrity_check'] as String?;
      return integrityCheck == 'ok';
    } catch (e) {
      // If we can't even run the integrity check, database is unhealthy
      return false;
    }
  }

  /// Quick health check - try to execute a simple query
  /// Returns true if database can execute basic queries, false otherwise
  Future<bool> canExecuteQueries() async {
    try {
      // Try to count records in users table (always exists)
      await customSelect('SELECT COUNT(*) FROM users').get();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete corrupted database and trigger full resync
  ///
  /// This is the safest recovery strategy:
  /// 1. Close all database connections
  /// 2. Delete corrupted file
  /// 3. Re-initialize fresh database
  /// 4. Trigger full sync from Supabase
  ///
  /// Data loss: Only unsynced records (upload-first sync minimizes this)
  static Future<void> deleteAndResync() async {
    try {
      // Get database path before closing
      final dbPath = await _getDatabasePath();

      // Delete corrupted file
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }

      // Delete WAL and SHM files if they exist
      final walFile = File('$dbPath-wal');
      if (await walFile.exists()) {
        await walFile.delete();
      }

      final shmFile = File('$dbPath-shm');
      if (await shmFile.exists()) {
        await shmFile.delete();
      }
    } catch (e) {
      throw Exception('Database recovery failed: $e');
    }
  }

  /// Get the platform-specific database file path
  static Future<String> _getDatabasePath() async {
    if (kIsWeb) {
      // Web uses IndexedDB, no file path needed
      throw UnsupportedError('Database file path not available on web');
    }

    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'mealvana_endurance_db.sqlite');
  }
}

/// Database connection setup with seed database support
/// Implementation is platform-specific (see connection_native.dart / connection_web.dart)
LazyDatabase _openConnection() => openNativeConnection();

/// Exception thrown when database schema validation fails
///
/// This exception indicates that the database schema is corrupted or incomplete,
/// typically due to a failed migration from v1 to v2. The database has been
/// deleted and the app needs to restart to create a fresh database and resync.
class DatabaseSchemaException implements Exception {
  final String message;
  final List<String> errors;

  DatabaseSchemaException(this.message, {this.errors = const []});

  @override
  String toString() {
    if (errors.isEmpty) {
      return 'DatabaseSchemaException: $message';
    }
    return 'DatabaseSchemaException: $message\nErrors: ${errors.join(', ')}';
  }
}
