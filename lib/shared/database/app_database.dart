import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:io';
import '../../features/auth/domain/user_preferences.dart' as domain;
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
import '../../features/nutrition_plan/domain/food_item.dart';

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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for testing with in-memory database
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1; // v1: Clean baseline schema

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

        // Ensure new preference_level column exists without bumping schema version
        await _ensureFoodPreferenceLevelColumn();

        if (kDebugMode) {
          // Enable detailed logging in debug mode
          await customStatement('PRAGMA synchronous = NORMAL');
          await customStatement('PRAGMA cache_size = 10000');
        }

        // Normalize any legacy timestamp strings in user_foods to Unix millis
        await _normalizeUserFoodTimestamps();
      },

      // Called when upgrading from older version
      onUpgrade: (Migrator m, int from, int to) async {
        // Future migrations will go here when we move to v2
      },
    );
  }

  /// Populate default data for fresh installations
  /// Note: categories, meal_types, and product_types are now enums in the database
  Future<void> _populateDefaultData() async {
    // No longer need to populate default data - using enums now
  }

  /// Get or create the current user profile (device-based)
  Future<domain.UserProfile?> getCurrentUserProfile() async {
    final query = select(userProfilesTable)
      ..orderBy([
        // Always prefer authenticated profiles over anonymous placeholders.
        (u) => OrderingTerm.asc(u.isAnonymous),
        // Within each auth type, pick the most recently updated profile.
        (u) => OrderingTerm.desc(u.updatedAt),
      ])
      ..limit(1);

    final results = await query.get();

    if (results.isEmpty) {
      return null;
    }

    final profile = _convertToDomainUserProfile(results.first);
    return profile;
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
  Future<void> saveUserProfile(domain.UserProfile profile) async {
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
        onboardingCompleted: Value(profile.onboardingCompleted),
        createdAt: Value(profile.createdAt),
        updatedAt: Value(profile.updatedAt),
        appVersion: Value(profile.appVersion),
      ),
    );
  }

  /// Update user profile
  Future<void> updateUserProfile(domain.UserProfile profile) async {
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
        onboardingCompleted: Value(profile.onboardingCompleted),
        updatedAt: Value(DateTime.now()),
        appVersion: Value(profile.appVersion),
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
  Future<void> saveFoodPreferences(
    String userId,
    Map<String, domain.FoodPreference> preferences, {
    Map<String, int>? sliderLevels,
  }) async {
    await ensureUserDataSyncColumns();
    await batch((batch) {
      // First delete existing preferences for this user
      batch.deleteWhere(foodPreferencesTable, (f) => f.userId.equals(userId));

      // Insert new preferences
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
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });

    final metadata = <String, dynamic>{};
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
    required int activityId,
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
  Future<void> clearActivityNutritionPlan(int activityId) async {
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
  Future<Activity?> getActivityByIdLocal(int activityId) async {
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

  /// Clear all user-scoped tables (profiles, preferences, calendar data, etc.)
  Future<void> clearUserScopedData() async {
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

  /// Clear all data (for testing/reset)
  Future<void> clearAllData() async {
    await clearUserScopedData();
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
      // Note: carb_loading_days is a CHILD table with ON DELETE CASCADE,
      // so deleting plans will automatically delete associated days
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
      // Delete OAuth user's old survey responses (if any)
      await customStatement(
        'DELETE FROM feature_survey_responses WHERE user_id = ?',
        [toUserId],
      );
      // Migrate anonymous user's survey responses to OAuth user
      await customStatement(
        'UPDATE feature_survey_responses SET user_id = ? WHERE user_id = ?',
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

  /// Get user foods for a user
  Future<List<UserFood>> getUserFoods(String userId) async {
    final query = select(userFoodsTable)
      ..where((f) => f.userId.equals(userId) & f.isDeleted.equals(false))
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
    return FoodItem(
      id: userFood.id,
      name: userFood.name,
      imageAddress: userFood.imageAddress,
      description: userFood.description,
      categories: [], // Categories loaded separately
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
      onboardingCompleted: dbUser.onboardingCompleted,
      createdAt: dbUser.createdAt,
      updatedAt: dbUser.updatedAt,
      appVersion: dbUser.appVersion ?? '',
      swipeHintShown: dbUser.swipeHintShown,
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

  Future<void> _ensureFoodPreferenceLevelColumn() async {
    // Skip if table doesn't exist yet (during initial create on fresh installs)
    final existingTablesResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='food_preferences'",
    ).get();
    if (existingTablesResult.isEmpty) {
      return;
    }

    final columns =
        await customSelect("PRAGMA table_info(food_preferences)").get();
    final hasPreferenceLevel =
        columns.any((row) => row.read<String>('name') == 'preference_level');

    if (!hasPreferenceLevel) {
      await customStatement(
        'ALTER TABLE food_preferences ADD COLUMN preference_level INTEGER NOT NULL DEFAULT 2;',
      );
      await customStatement('''
        UPDATE food_preferences
        SET preference_level = CASE preference
          WHEN 'like' THEN 3
          WHEN 'dislike' THEN 1
          ELSE 2
        END;
      ''');
    }
  }
}

/// Database connection setup with seed database support
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Put the database file in the documents directory
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'mealvana_endurance_db.sqlite'));

    // Also work around limitations on old Android versions
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    // Make sqlite3 pick a more suitable location for temporary files
    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    // TEMPORARY FIX: Use synchronous database in debug mode to avoid isolate issues
    // Background isolates can hang on iOS simulator during development
    final db = kDebugMode
        ? NativeDatabase(file, logStatements: true)
        : NativeDatabase.createInBackground(file);

    return db;
  });
}
