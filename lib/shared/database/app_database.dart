import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:sqlite3/sqlite3.dart';
import 'dart:io';
import '../../features/auth/domain/user_preferences.dart' as domain;
import 'tables/user_profiles.dart';
import 'tables/food_preferences.dart';
import 'tables/nutrition_plans.dart';
import 'tables/macro_targets.dart';
import 'tables/feedback.dart';
import 'tables/foods_table.dart';
import 'tables/categories_table.dart';
import 'tables/food_categories_table.dart';
import 'tables/product_types_table.dart';
import 'tables/app_content_table.dart';
import 'tables/workout_notes_table.dart';
import 'tables/edge_functions_table.dart';
import 'tables/user_foods_table.dart';
import 'tables/user_food_categories_table.dart';
import 'tables/user_hidden_foods_table.dart';
// NEW: Calendar tables
import 'tables/activities_table.dart';
import 'tables/events_table.dart';
import 'tables/activity_completions_table.dart';
import 'tables/carb_loading_plans_table.dart';
import 'tables/carb_loading_days_table.dart';
// NEW: Carb Loading Food tables
import 'tables/meal_types_table.dart';
import 'tables/carb_loading_foods_table.dart';
import 'tables/carb_loading_user_foods_table.dart';
import 'tables/carb_loading_food_meal_types_table.dart';
import 'tables/carb_loading_user_food_meal_types_table.dart';
import 'tables/carb_loading_day_meals_table.dart';
import '../services/logging_service.dart';
import '../../features/nutrition_plan/domain/food_item.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';

part 'app_database.g.dart';

/// Main Drift database for the Mealvana Endurance app
/// V1 schema with 27 tables (100% parity with Supabase)
@DriftDatabase(tables: [
  // Core tables aligned with Supabase
  UserProfilesTable,
  FoodPreferencesTable,
  NutritionPlans,
  MacroTargetsTable,
  FeedbackTable,

  // Food system tables
  FoodsTable,
  CategoriesTable,
  FoodCategoriesTable,
  ProductTypesTable,

  // User-specific food tables (new in v3)
  UserFoodsTable,
  UserFoodCategoriesTable,
  UserHiddenFoodsTable,

  // Content management
  AppContentTable,

  // Additional features
  WorkoutNotesTable,
  EdgeFunctionsTable,

  // Calendar feature tables
  ActivitiesTable,
  EventsTable,
  ActivityCompletionsTable,
  CarbLoadingPlansTable,
  CarbLoadingDaysTable,

  // Carb Loading Food tables
  MealTypesTable,
  CarbLoadingFoodsTable,
  CarbLoadingUserFoodsTable,
  CarbLoadingFoodMealTypesTable,
  CarbLoadingUserFoodMealTypesTable,
  CarbLoadingDayMealsTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase({AppLogger? logger})
      : _logger = logger ?? const NoopAppLogger(),
        super(_openConnection());

  /// Constructor for testing with in-memory database
  AppDatabase.memory({AppLogger? logger})
      : _logger = logger ?? const NoopAppLogger(),
        super(NativeDatabase.memory());

  final AppLogger _logger;

  @override
  int get schemaVersion => 1; // v1: Baseline schema with 26 tables (fresh installs only)

  /// Generate a UUID for new records
  String _generateUuid() {
    // Generate a proper UUID that meets the 36-character requirement
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random1 = (DateTime.now().microsecond % 10000).toString().padLeft(4, '0');
    final random2 = (DateTime.now().millisecond % 10000).toString().padLeft(4, '0');
    final random3 = ((DateTime.now().second * 1000 + DateTime.now().millisecond) % 100000).toString().padLeft(5, '0');

    // Format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (36 characters total)
    final uuid = '${timestamp.substring(timestamp.length - 8)}-$random1-$random2-${random3.substring(0, 4)}-$random3${timestamp.substring(timestamp.length - 7)}';

    return uuid;
  }

  /// Initialize default product types if they don't exist
  Future<void> initializeDefaultProductTypes() async {
    try {
      // Check if product types already exist
      final existingTypes = await select(productTypesTable).get();
      if (existingTypes.isNotEmpty) {
        return; // Already initialized
      }

      DebugLogger.debug('🏭 Initializing default product types...');
      
      // Insert default product types
      final importedId = _generateUuid();
      await into(productTypesTable).insert(
        ProductTypesTableCompanion.insert(
          id: importedId,
          code: 'imported',
          name: 'Imported',
          namePlural: 'Imported',
          sortOrder: const Value(1),
        ),
      );

      DebugLogger.info('✅ Default product types initialized successfully');
    } catch (e) {
      _logger.error('Failed to initialize default product types', error: e);
      rethrow;
    }
  }

  /// Get the ID for the 'Imported' product type
  Future<String?> getImportedProductTypeId() async {
    try {
      final importedType = await (select(productTypesTable)
        ..where((tbl) => tbl.code.equals('imported'))).getSingleOrNull();
      return importedType?.id;
    } catch (e) {
      _logger.error('Failed to get imported product type ID', error: e);
      return null;
    }
  }

  /// V1 database setup - fresh installs only (no migrations needed)
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        // Create all v1 tables for fresh installs
        _logger.database('Creating new v1 database schema (26 tables)');
        await m.createAll();
        await _populateDefaultData();
        _logger.database('Database v1 schema created successfully');
      },
      // No onUpgrade needed - v1 is the baseline, all users start fresh
      beforeOpen: (details) async {
        // Enable foreign key support
        await customStatement('PRAGMA foreign_keys = ON');

        if (kDebugMode) {
          // Enable detailed logging in debug mode
          await customStatement('PRAGMA synchronous = NORMAL');
          await customStatement('PRAGMA cache_size = 10000');
        }
      },
    );
  }

  /// Populate default data for fresh installations
  Future<void> _populateDefaultData() async {
    try {
      // Step 1: Populate categories (nutrition plan timing)
      _logger.database('Populating categories', operation: 'populate_data');
      await batch((batch) {
        batch.insert(categoriesTable,
          CategoriesTableCompanion.insert(id: const Value(1), name: 'before_run'),
          mode: InsertMode.insertOrIgnore
        );
        batch.insert(categoriesTable,
          CategoriesTableCompanion.insert(id: const Value(2), name: 'during_run'),
          mode: InsertMode.insertOrIgnore
        );
        batch.insert(categoriesTable,
          CategoriesTableCompanion.insert(id: const Value(3), name: 'after_run'),
          mode: InsertMode.insertOrIgnore
        );
      });

      // Step 1b: Populate meal types (carb loading meals)
      _logger.database('Populating meal types', operation: 'populate_data');
      await batch((batch) {
        batch.insert(mealTypesTable,
          MealTypesTableCompanion.insert(
            id: const Value(1),
            name: 'breakfast',
            displayName: 'Breakfast'
          ),
          mode: InsertMode.insertOrIgnore
        );
        batch.insert(mealTypesTable,
          MealTypesTableCompanion.insert(
            id: const Value(2),
            name: 'lunch',
            displayName: 'Lunch'
          ),
          mode: InsertMode.insertOrIgnore
        );
        batch.insert(mealTypesTable,
          MealTypesTableCompanion.insert(
            id: const Value(3),
            name: 'dinner',
            displayName: 'Dinner'
          ),
          mode: InsertMode.insertOrIgnore
        );
        batch.insert(mealTypesTable,
          MealTypesTableCompanion.insert(
            id: const Value(4),
            name: 'snacks',
            displayName: 'Snacks'
          ),
          mode: InsertMode.insertOrIgnore
        );
      });

      // Step 2: Populate product types with seed data
      _logger.database('Populating product types', operation: 'populate_data');
      await batch((batch) {
        // Product types data provided by user
        final productTypes = [
          {'id': '8a847f4f-8c26-41ef-a1e2-132b404be95e', 'code': 'gel', 'name': 'Gel', 'namePlural': 'Gels', 'sortOrder': 10},
          {'id': 'fc915f1b-d541-45fa-ae5c-695ee41073db', 'code': 'chew', 'name': 'Chew', 'namePlural': 'Chews', 'sortOrder': 20},
          {'id': 'd3908cb2-a21d-4ef1-8d33-c999d29eefcc', 'code': 'drink_mix', 'name': 'Drink mix', 'namePlural': 'Drink mixes', 'sortOrder': 30},
          {'id': '09930546-1942-485e-9728-bced1cf933a2', 'code': 'electrolyte_only', 'name': 'Electrolyte-only', 'namePlural': 'Electrolyte-only', 'sortOrder': 40},
          {'id': 'b27bc986-1402-4e20-b022-a65b5ffbd4d2', 'code': 'sports_drink', 'name': 'Sports drink', 'namePlural': 'Sports drinks', 'sortOrder': 50},
          {'id': '6102eea1-2dfe-44cf-8863-b258c27262ef', 'code': 'bar', 'name': 'Bar', 'namePlural': 'Bars', 'sortOrder': 60},
          {'id': '666408c5-6d5b-4fc6-bda3-d6428e8362b9', 'code': 'waffle', 'name': 'Waffle', 'namePlural': 'Waffles', 'sortOrder': 70},
          {'id': '52a0ff7c-a0f5-4e26-b409-2a7ce3298f4d', 'code': 'capsule', 'name': 'Capsule', 'namePlural': 'Capsules', 'sortOrder': 80},
          {'id': '76c16c67-1746-47d7-adea-e5fc9dcd1f4d', 'code': 'real_food', 'name': 'Real food', 'namePlural': 'Real foods', 'sortOrder': 90},
          {'id': 'cbcfd036-127c-43fb-88d5-34a9d9ba5db4', 'code': 'recovery_shake', 'name': 'Recovery shake', 'namePlural': 'Recovery shakes', 'sortOrder': 100},
          {'id': '3b5d6f2e-3d3a-4b6a-9e3b-5c7a1f0d7a10', 'code': 'quick_carbs', 'name': 'Quick carb', 'namePlural': 'Quick carbs', 'sortOrder': 10},
          {'id': '8f4f2c73-9a65-4d5a-b3be-9d5f9e2a1c2d', 'code': 'solid_carb_snacks', 'name': 'Solid carb snack', 'namePlural': 'Solid carb snacks', 'sortOrder': 20},
          {'id': 'f2a8c4e1-7d82-4d9b-8b79-9a03e7b4a6c1', 'code': 'real_food_carbs', 'name': 'Real-food carb', 'namePlural': 'Real-food carbs', 'sortOrder': 30},
          {'id': 'c7e2a1d4-5b6c-4f9d-8e2a-1a7c9b3e5d2f', 'code': 'hydration_with_carbs', 'name': 'Hydration with carbs', 'namePlural': 'Hydration with carbs', 'sortOrder': 40},
          {'id': 'a1e2c3d4-b5a6-4c7d-8e9f-0a1b2c3d4e5f', 'code': 'electrolytes_fluids', 'name': 'Electrolytes & fluids', 'namePlural': 'Electrolytes & fluids', 'sortOrder': 50},
          {'id': 'd4c3b2a1-6e5d-4c3b-8a9f-1e2d3c4b5a6f', 'code': 'protein_recovery', 'name': 'Protein & recovery', 'namePlural': 'Protein & recovery', 'sortOrder': 60},
          {'id': 'cdd6a8f1-750c-4c78-93f7-ab706285ac7b', 'code': 'imported', 'name': 'Imported', 'namePlural': 'Imported', 'sortOrder': 70},
        ];

        for (final productType in productTypes) {
          batch.insert(productTypesTable,
            ProductTypesTableCompanion.insert(
              id: productType['id'] as String,
              code: productType['code'] as String,
              name: productType['name'] as String,
              namePlural: productType['namePlural'] as String,
              sortOrder: Value(productType['sortOrder'] as int),
            ),
            mode: InsertMode.insertOrIgnore
          );
        }
      });

      _logger.database('Default data populated successfully');
    } catch (e) {
      _logger.error('Failed to populate default data',
        context: 'DATABASE',
        error: e
      );
      // Don't rethrow - app should continue even if default data fails
    }
  }

  /// Get or create the current user profile (device-based)
  Future<domain.UserProfile?> getCurrentUserProfile() async {
    final query = select(userProfilesTable)
      ..orderBy([(u) => OrderingTerm.desc(u.updatedAt)])
      ..limit(1);
    final results = await query.get();
    return results.isNotEmpty ? _convertToDomainUserProfile(results.first) : null;
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
  Future<void> saveFoodPreferences(String deviceId, Map<String, domain.FoodPreference> preferences) async {
    await batch((batch) {
      // First delete existing preferences for this user
      batch.deleteWhere(foodPreferencesTable, (f) => f.deviceId.equals(deviceId));

      // Insert new preferences
      for (final entry in preferences.entries) {
        batch.insert(
          foodPreferencesTable,
          FoodPreferencesTableCompanion.insert(
            id: _generateUuid(),
            deviceId: deviceId,
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
  Future<Map<String, domain.FoodPreference>> getUserFoodPreferences(String deviceId) async {
    final query = select(foodPreferencesTable)..where((f) => f.deviceId.equals(deviceId));
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
  Future<List<String>> getLikedFoods(String deviceId) async {
    final query = select(foodPreferencesTable)
      ..where((f) => f.deviceId.equals(deviceId) & f.preference.equals('like'));
    final results = await query.get();
    return results.map((r) => r.foodName).toList();
  }

  /// Get disliked foods for a user
  Future<List<String>> getDislikedFoods(String deviceId) async {
    final query = select(foodPreferencesTable)
      ..where((f) => f.deviceId.equals(deviceId) & f.preference.equals('dislike'));
    final results = await query.get();
    return results.map((r) => r.foodName).toList();
  }

  /// Save nutrition plan with complete metadata (updated for new schema)
  Future<void> saveNutritionPlan({
    required String id,
    required String deviceId,
    required String planId,
    required String planName,
    required String planData,
    double? distanceMiles,
    double? paceMinutesPerMile,
    int? totalCalories,
    String? notes,
    String? activityId, // Link to calendar activity
  }) async {
    await into(nutritionPlans).insertOnConflictUpdate(
      NutritionPlansCompanion.insert(
        id: id,
        deviceId: deviceId,
        planId: planId,
        planName: planName,
        planData: planData,
        distanceMiles: Value(distanceMiles),
        paceMinutesPerMile: Value(paceMinutesPerMile),
        totalCalories: Value(totalCalories),
        notes: Value(notes),
        activityId: Value(activityId), // Save activity ID linkage
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Save temporary nutrition plan (unsaved plan that persists through app restart)
  Future<void> saveTempNutritionPlan(String userId, String planData) async {
    await (update(userProfilesTable)..where((u) => u.id.equals(userId)))
        .write(UserProfilesTableCompanion(tempPlanData: Value(planData)));
  }

  /// Get temporary nutrition plan
  Future<String?> getTempNutritionPlan(String userId) async {
    final query = select(userProfilesTable)..where((u) => u.id.equals(userId));
    final result = await query.getSingleOrNull();
    return result?.tempPlanData;
  }

  /// Clear temporary nutrition plan
  Future<void> clearTempNutritionPlan(String userId) async {
    await (update(userProfilesTable)..where((u) => u.id.equals(userId)))
        .write(const UserProfilesTableCompanion(tempPlanData: Value(null)));
  }

  /// Get latest nutrition plan for user (updated for new schema)
  Future<NutritionPlanEntry?> getLatestNutritionPlan(String deviceId) async {
    final query = select(nutritionPlans)
      ..where((n) => n.deviceId.equals(deviceId) & n.isDeleted.equals(false))
      ..orderBy([
        (n) => OrderingTerm.desc(n.updatedAt),
        (n) => OrderingTerm.desc(n.id), // Secondary sort by ID to handle ties
      ])
      ..limit(1);

    final results = await query.get();
    return results.isNotEmpty ? results.first : null;
  }

  /// Get all nutrition plans for user (updated for new schema)
  Future<List<NutritionPlanEntry>> getAllNutritionPlans(String deviceId) async {
    final query = select(nutritionPlans)
      ..where((n) => n.deviceId.equals(deviceId) & n.isDeleted.equals(false))
      ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]);

    final results = await query.get();
    return results;
  }

  /// Delete nutrition plan
  Future<bool> deleteNutritionPlan(String planId) async {
    final deletedRows = await (delete(nutritionPlans)..where((n) => n.id.equals(planId))).go();
    return deletedRows > 0;
  }

  /// Clear all data (for testing/reset)
  Future<void> clearAllData() async {
    await batch((batch) {
      batch.deleteAll(userProfilesTable);
      batch.deleteAll(foodPreferencesTable);
      batch.deleteAll(nutritionPlans);
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
    final preferencesCount = await (selectOnly(foodPreferencesTable)..addColumns([foodPreferencesTable.deviceId.count()])).getSingle();
    final plansCount = await (selectOnly(nutritionPlans)..addColumns([nutritionPlans.id.count()])).getSingle();
    final foodsCount = await (selectOnly(foodsTable)..addColumns([foodsTable.id.count()])).getSingle();
    final categoriesCount = await (selectOnly(categoriesTable)..addColumns([categoriesTable.id.count()])).getSingle();
    final contentCount = await (selectOnly(appContentTable)..addColumns([appContentTable.id.count()])).getSingle();

    return {
      'users': userCount.read(userProfilesTable.id.count())!,
      'preferences': preferencesCount.read(foodPreferencesTable.deviceId.count())!,
      'plans': plansCount.read(nutritionPlans.id.count())!,
      'foods': foodsCount.read(foodsTable.id.count())!,
      'categories': categoriesCount.read(categoriesTable.id.count())!,
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
    
    _logger.database('Cached foods from Supabase', 
      operation: 'cache_foods',
      data: {'food_count': foodsData.length}
    );
  }
  
  /// Get foods by category
  Future<List<FoodEntry>> getFoodsByCategory(String categoryName) async {
    final query = select(foodsTable).join([
      leftOuterJoin(foodCategoriesTable, foodCategoriesTable.foodId.equalsExp(foodsTable.id)),
      leftOuterJoin(categoriesTable, categoriesTable.id.equalsExp(foodCategoriesTable.categoryId)),
    ])
    ..where(categoriesTable.name.equals(categoryName));
    
    final result = await query.get();
    return result.map((row) => row.readTable(foodsTable)).toList();
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
    
    _logger.database('Cached app content', 
      operation: 'cache_content',
      data: {
        'environment': contentData['environment'],
        'locale': contentData['locale'],
        'version': contentData['version']
      }
    );
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
      beforeRunSuitable: Value(foodData['before_run_suitable'] ?? false),
      duringRunSuitable: Value(foodData['during_run_suitable'] ?? false),
      afterRunSuitable: Value(foodData['after_run_suitable'] ?? false),
      runPortable: Value(foodData['run_portable'] ?? false),
      requiresPreparation: Value(foodData['requires_preparation'] ?? false),
      aidStationAvailable: Value(foodData['aid_station_available'] ?? false),
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

  /// Save a scanned food with category associations
  Future<void> saveUserFood({
    required String deviceId,
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
    required List<int> categoryIds,
  }) async {
    await transaction(() async {
      // Insert the user food
      await into(userFoodsTable).insert(
        UserFoodsTableCompanion.insert(
          id: id,
          deviceId: deviceId,
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
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // Insert category associations
      for (final categoryId in categoryIds) {
        await into(userFoodCategoriesTable).insert(
          UserFoodCategoriesTableCompanion.insert(
            userFoodId: id,
            categoryId: categoryId,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });

    _logger.database('Saved user food with categories',
      operation: 'save_user_food',
      data: {
        'user_food_id': id,
        'device_id': deviceId,
        'name': name,
        'category_count': categoryIds.length,
      }
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
    return await transaction(() async {
      // Delete category associations first
      await (delete(userFoodCategoriesTable)
        ..where((c) => c.userFoodId.equals(userFoodId))).go();

      // Delete the user food
      final deletedRows = await (delete(userFoodsTable)
        ..where((f) => f.id.equals(userFoodId))).go();

      if (deletedRows > 0) {
        _logger.database('Deleted user food completely',
          operation: 'delete_user_food',
          data: {'user_food_id': userFoodId}
        );
        return true;
      }
      return false;
    });
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

/// Database connection setup
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

    return NativeDatabase.createInBackground(file);
  });
}
