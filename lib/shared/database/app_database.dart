import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../../features/auth/domain/user_preferences.dart' as domain;
import 'tables/user_profiles.dart';
import 'tables/food_preferences.dart';
import 'tables/feedback.dart';
import 'tables/foods_table.dart';
import 'tables/app_content_table.dart';
import 'tables/edge_functions_table.dart';
import 'tables/user_foods_table.dart';
import 'tables/auth_sessions_table.dart';
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
/// V1 schema with 19 tables including auth_sessions for Supabase authentication
@DriftDatabase(tables: [
  // Core tables aligned with Supabase
  UserProfilesTable,
  FoodPreferencesTable,
  FeedbackTable,

  // Authentication
  AuthSessionsTable,

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
])
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

  // Note: product_types table has been dropped - now using product_type_enum

  /// V1 database setup with seed database support and migration strategy
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      // Called when database is first created (version 0 -> 1)
      onCreate: (Migrator m) async {
        if (kDebugMode) {
          print('🔨 onCreate triggered - checking for seed tables');
        }

        // Check which tables already exist (from seed DB)
        final existingTablesResult = await customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
        ).get();

        final existingTables = existingTablesResult
            .map((row) => row.read<String>('name'))
            .toSet();

        if (kDebugMode) {
          print('📊 Found ${existingTables.length} existing tables from seed DB: ${existingTables.join(", ")}');
        }

        // 🚨 CRITICAL FIX: m.createAll() DROPS tables before recreating them!
        // This wipes seed data even though tables exist. Instead, we manually
        // create each table using CREATE TABLE IF NOT EXISTS to preserve seed data.

        // Seed tables (already have data - must NOT be recreated)
        // Using actual SQLite table names from seed DB (NOT Drift class names)
        // Note: categories, meal_types, product_types, and their join tables are now dropped
        final seedTables = {
          'foods',  // FoodsTable
          'carb_loading_foods',  // CarbLoadingFoodsTable
        };

        // For each table definition, manually create with IF NOT EXISTS
        if (kDebugMode) {
          print('📝 Creating ${allTables.length} tables...');
        }

        for (final table in allTables) {
          final tableName = table.actualTableName;

          // Skip tables that already exist AND are seed tables (have data)
          if (existingTables.contains(tableName) && seedTables.contains(tableName)) {
            if (kDebugMode) {
              print('  ⏭️ Skipping $tableName (seed table with data)');
            }
            continue; // Don't recreate this table
          }

          // Create all other tables (new tables OR non-seed tables)
          if (kDebugMode) {
            print('  🔨 Creating table: $tableName');
          }
          await m.createTable(table);
          if (kDebugMode) {
            print('  ✅ Created table: $tableName');
          }
        }

        if (kDebugMode) {
          print('✅ All tables created successfully');
        }

        // Only populate default data for NEW tables (not seed tables)
        await _populateDefaultData();

        if (kDebugMode) {
          // Verify food count after onCreate
          final foodCountResult = await customSelect('SELECT COUNT(*) as count FROM foods').getSingle();
          final foodCount = foodCountResult.read<int>('count');
          print('✅ onCreate completed - foods table has $foodCount items');
        }
      },

      // Called immediately after database is opened
      beforeOpen: (details) async {
        if (kDebugMode) {
          print('🔓 beforeOpen called (wasCreated: ${details.wasCreated})');
        }

        // Enable foreign key support (required for Drift)
        if (kDebugMode) {
          print('  🔧 Enabling foreign keys...');
        }
        await customStatement('PRAGMA foreign_keys = ON');

        if (kDebugMode) {
          print('  ✅ Foreign keys enabled');
          // Enable detailed logging in debug mode
          await customStatement('PRAGMA synchronous = NORMAL');
          await customStatement('PRAGMA cache_size = 10000');
          print('  ✅ PRAGMA settings configured');
        }

        if (details.wasCreated) {
          if (kDebugMode) {
            print('  🔍 Verifying database creation...');
          }
          // Database just created from seed file
          // onCreate already ran to create missing tables
          // Verify seed data is still present
          try {
            final foodCountResult = await customSelect('SELECT COUNT(*) as count FROM foods').getSingle();
            final foodCount = foodCountResult.read<int>('count');

            if (foodCount > 0) {
              if (kDebugMode) {
                print('✅ Database initialized with $foodCount seed foods');
              }
            } else {
              if (kDebugMode) {
                print('⚠️ No seed foods found - will need fallback sync');
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Could not verify seed data: $e');
            }
          }
        } else if (kDebugMode) {
          // Existing database opened
          print('📂 Existing database opened (v${details.versionBefore} → v${details.versionNow})');
        }
      },

      // Called when upgrading from older version
      onUpgrade: (Migrator m, int from, int to) async {
        if (kDebugMode) {
          print('🔄 Migrating database from v$from to v$to');
        }

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
    if (kDebugMode) {
      print('🔍 getCurrentUserProfile: Building query...');
    }
    final query = select(userProfilesTable)
      ..orderBy([(u) => OrderingTerm.desc(u.updatedAt)])
      ..limit(1);

    if (kDebugMode) {
      print('🔍 getCurrentUserProfile: Executing query...');
    }
    final results = await query.get();

    if (kDebugMode) {
      print('🔍 getCurrentUserProfile: Query returned ${results.length} results');
    }

    if (results.isEmpty) {
      if (kDebugMode) {
        print('🔍 getCurrentUserProfile: No user found, returning null');
      }
      return null;
    }

    if (kDebugMode) {
      print('🔍 getCurrentUserProfile: Converting result to domain model...');
    }
    final profile = _convertToDomainUserProfile(results.first);

    if (kDebugMode) {
      print('🔍 getCurrentUserProfile: Conversion complete, returning profile');
    }
    return profile;
  }

  /// Save a user profile
  Future<void> saveUserProfile(domain.UserProfile profile) async {
    await into(userProfilesTable).insertOnConflictUpdate(
      UserProfilesTableCompanion.insert(
        id: profile.id,
        deviceId: profile.id, // Use profile.id as deviceId for device-based auth
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
    await (update(userProfilesTable)..where((u) => u.id.equals(profile.id))).write(
      UserProfilesTableCompanion(
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
    final deletedRows = await (delete(userProfilesTable)..where((u) => u.id.equals(userId))).go();
    return deletedRows > 0;
  }

  /// Save food preferences for a user
  Future<void> saveFoodPreferences(String userId, Map<String, domain.FoodPreference> preferences) async {
    await batch((batch) {
      // First delete existing preferences for this user
      batch.deleteWhere(foodPreferencesTable, (f) => f.userId.equals(userId));

      // Insert new preferences
      for (final entry in preferences.entries) {
        batch.insert(
          foodPreferencesTable,
          FoodPreferencesTableCompanion.insert(
            id: _generateUuid(),
            userId: userId,
            foodName: entry.key,
            preference: entry.value.value, // Use .value instead of .name to get database-compatible format
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Get food preferences for a user
  Future<Map<String, domain.FoodPreference>> getUserFoodPreferences(String userId) async {
    final query = select(foodPreferencesTable)..where((f) => f.userId.equals(userId));
    final results = await query.get();

    final preferencesMap = <String, domain.FoodPreference>{};
    for (final row in results) {
      final preference = domain.FoodPreference.values.firstWhere(
        (p) => p.value == row.preference, // Use .value to match database underscore format
        orElse: () => domain.FoodPreference.dislike,
      );
      preferencesMap[row.foodName] = preference;
    }

    return preferencesMap;
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
    final countQuery = selectOnly(foodsTable)..addColumns([foodsTable.id.count()]);
    final result = await countQuery.getSingle();
    return result.read(foodsTable.id.count()) ?? 0;
  }

  /// Attach a nutrition plan JSON payload directly to an activity row.
  Future<void> setActivityNutritionPlan({
    required int activityId,
    required String planData,
  }) async {
    await (update(activitiesTable)..where((tbl) => tbl.id.equals(activityId))).write(
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
    await (update(activitiesTable)..where((tbl) => tbl.id.equals(activityId))).write(
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
      ..where((tbl) => tbl.userId.equals(userId) & tbl.nutritionPlanData.isNotNull())
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)])
      ..limit(1);
    return await query.getSingleOrNull();
  }

  /// Get all activities for a user that contain nutrition plans.
  Future<List<Activity>> getActivitiesWithNutritionPlans(String userId) async {
    final query = select(activitiesTable)
      ..where((tbl) => tbl.userId.equals(userId) & tbl.nutritionPlanData.isNotNull())
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]);
    return await query.get();
  }

  /// Clear all data (for testing/reset)
  Future<void> clearAllData() async {
    await batch((batch) {
      batch.deleteAll(userProfilesTable);
      batch.deleteAll(foodPreferencesTable);
    });
  }

  /// Check if database has any user data
  Future<bool> hasUserData() async {
    final userCount = await (selectOnly(userProfilesTable)..addColumns([userProfilesTable.id.count()])).getSingle();
    return userCount.read(userProfilesTable.id.count())! > 0;
  }

  /// Get database statistics for logging/debugging
  Future<Map<String, int>> getDatabaseStats() async {
    final userCount = await (selectOnly(userProfilesTable)..addColumns([userProfilesTable.id.count()])).getSingle();
    final preferencesCount = await (selectOnly(foodPreferencesTable)..addColumns([foodPreferencesTable.userId.count()])).getSingle();
    final foodsCount = await (selectOnly(foodsTable)..addColumns([foodsTable.id.count()])).getSingle();
    final contentCount = await (selectOnly(appContentTable)..addColumns([appContentTable.id.count()])).getSingle();

    return {
      'users': userCount.read(userProfilesTable.id.count())!,
      'preferences': preferencesCount.read(foodPreferencesTable.userId.count())!,
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
        batch.insert(foodsTable, _mapToFoodEntry(food), mode: InsertMode.insertOrReplace);
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
      ..where((c) => 
        c.environment.equals(environment) &
        c.locale.equals(locale) &
        c.isActive.equals(true)
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
      await (update(userProfilesTable)
            ..where((t) => t.id.equals(user.id)))
          .write(UserProfilesTableCompanion(
        swipeHintShown: const Value(true),
        updatedAt: Value(DateTime.now()),
      ));
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
  }

  /// Get user foods for a device
  Future<List<UserFood>> getUserFoods(String deviceId) async {
    final query = select(userFoodsTable)
      ..where((f) => f.deviceId.equals(deviceId) & f.isDeleted.equals(false))
      ..orderBy([(f) => OrderingTerm.desc(f.createdAt)]);

    return await query.get();
  }

  /// Check for duplicate barcode in user foods
  Future<bool> hasUserFoodWithBarcode(String deviceId, String barcode) async {
    final query = select(userFoodsTable)
      ..where((f) => f.deviceId.equals(deviceId) &
                     f.barcode.equals(barcode) &
                     f.isDeleted.equals(false))
      ..limit(1);

    final results = await query.get();
    return results.isNotEmpty;
  }

  /// Delete user food completely (not soft delete)
  Future<bool> deleteUserFood(String userFoodId) async {
    // Delete the user food (categories are now stored as array, no join table)
    final deletedRows = await (delete(userFoodsTable)
      ..where((f) => f.id.equals(userFoodId))).go();

    return deletedRows > 0;
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
}

/// Database connection setup with seed database support
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    if (kDebugMode) {
      print('🔌 _openConnection: Starting database connection setup');
    }

    // Put the database file in the documents directory
    if (kDebugMode) {
      print('🔌 _openConnection: Getting documents directory...');
    }
    final dbFolder = await getApplicationDocumentsDirectory();

    if (kDebugMode) {
      print('🔌 _openConnection: Documents directory: ${dbFolder.path}');
      print('🔌 _openConnection: Creating file path...');
    }
    final file = File(p.join(dbFolder.path, 'mealvana_endurance_db.sqlite'));

    // Log database initialization status
    if (kDebugMode) {
      print('🔌 _openConnection: Checking if database exists...');
      final dbExists = await file.exists();
      if (!dbExists) {
        print('🌱 Fresh install detected - creating empty database');
        print('📍 Target path: ${file.path}');
        print('📋 All tables will be created by onCreate migration');
        print('📥 Reference data will be downloaded via sync after onboarding');
      } else {
        print('📂 Database file already exists at: ${file.path}');
        print('💡 This is NOT a fresh install - using existing database');
      }
      print('🔌 _openConnection: Creating NativeDatabase instance...');
    }

    // Also work around limitations on old Android versions
    if (Platform.isAndroid) {
      if (kDebugMode) {
        print('🔌 _openConnection: Applying Android workarounds...');
      }
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    // Make sqlite3 pick a more suitable location for temporary files
    if (kDebugMode) {
      print('🔌 _openConnection: Setting temp directory for sqlite3...');
    }
    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    if (kDebugMode) {
      print('🔌 _openConnection: Calling NativeDatabase.createInBackground...');
    }

    // TEMPORARY FIX: Use synchronous database in debug mode to avoid isolate issues
    // Background isolates can hang on iOS simulator during development
    final db = kDebugMode
        ? NativeDatabase(file, logStatements: true)
        : NativeDatabase.createInBackground(file);

    if (kDebugMode) {
      print('🔌 _openConnection: NativeDatabase created (debug mode: direct, release mode: background isolate)');
      print('🔌 _openConnection: Returning database instance');
    }

    return db;
  });
}
