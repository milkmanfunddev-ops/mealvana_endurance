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
import 'tables/brands_table.dart';
import 'tables/app_content_table.dart';
import 'tables/workout_notes_table.dart';
import '../services/logging_service.dart';

part 'app_database.g.dart';

/// Main Drift database for the Mealvana Endurance app
/// V2 implementation with proper migrations and full table set
@DriftDatabase(tables: [
  // Existing v1 tables (preserved)
  UserProfilesTable,
  FoodPreferencesTable, 
  NutritionPlans,
  MacroTargetsTable,
  FeedbackTable,
  
  // New v2 tables
  FoodsTable,
  CategoriesTable,
  FoodCategoriesTable,
  BrandsTable,
  AppContentTable,
  
  // Workout notes table (v5)
  WorkoutNotesTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  
  /// Constructor for testing with in-memory database
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 8; // v7: Added display_override field to foods
  
  LoggingService get _logger => AppLogger.instance;

  /// Big Bang migration strategy: v1 → v2 with new tables
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        // For fresh installs, create all v2 tables
        await m.createAll();
        await _populateDefaultData();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        _logger.database('Starting database migration', 
          operation: 'migration',
          data: {'from_version': from, 'to_version': to}
        );
        
        if (from == 1 && to == 8) {
          // Direct migration v1 → v8
          await _migrateV1ToV2(m);  // Add new tables
          await _migrateV2ToV3(m);  // Add swipeHintShown column
          await _migrateV3ToV4(m);  // Add user journal fields
          await _migrateV4ToV5(m);  // Add workout_notes table
          await _migrateV5ToV6(m);  // Add display_name_plural and to_exclude_from_solver
          await _migrateV6ToV7(m);  // Add display_override field
          await _migrateV7ToV8(m);  // Sync column names with Supabase schema
        } else if (from == 1 && to == 7) {
          // Direct migration v1 → v7
          await _migrateV1ToV2(m);  // Add new tables
          await _migrateV2ToV3(m);  // Add swipeHintShown column
          await _migrateV3ToV4(m);  // Add user journal fields
          await _migrateV4ToV5(m);  // Add workout_notes table
          await _migrateV5ToV6(m);  // Add display_name_plural and to_exclude_from_solver
          await _migrateV6ToV7(m);  // Add display_override field
        } else if (from == 1 && to == 6) {
          // Direct migration v1 → v6
          await _migrateV1ToV2(m);  // Add new tables
          await _migrateV2ToV3(m);  // Add swipeHintShown column
          await _migrateV3ToV4(m);  // Add user journal fields
          await _migrateV4ToV5(m);  // Add workout_notes table
          await _migrateV5ToV6(m);  // Add display_name_plural and to_exclude_from_solver
        } else if (from == 1 && to == 5) {
          // Direct migration v1 → v5
          await _migrateV1ToV2(m);  // Add new tables
          await _migrateV2ToV3(m);  // Add swipeHintShown column
          await _migrateV3ToV4(m);  // Add user journal fields
          await _migrateV4ToV5(m);  // Add workout_notes table
        } else if (from == 1 && to == 4) {
          // Direct migration v1 → v4
          await _migrateV1ToV2(m);  // Add new tables
          await _migrateV2ToV3(m);  // Add swipeHintShown column
          await _migrateV3ToV4(m);  // Add user journal fields
        } else if (from == 1 && to == 3) {
          // Direct migration v1 → v3
          await _migrateV1ToV2(m);  // Add new tables
          await _migrateV2ToV3(m);  // Add swipeHintShown column
        } else if (from == 1 && to == 2) {
          await _migrateV1ToV2(m);
        } else if (from == 2 && to == 8) {
          await _migrateV2ToV3(m);
          await _migrateV3ToV4(m);
          await _migrateV4ToV5(m);
          await _migrateV5ToV6(m);
          await _migrateV6ToV7(m);
          await _migrateV7ToV8(m);
        } else if (from == 2 && to == 7) {
          await _migrateV2ToV3(m);
          await _migrateV3ToV4(m);
          await _migrateV4ToV5(m);
          await _migrateV5ToV6(m);
          await _migrateV6ToV7(m);
        } else if (from == 2 && to == 6) {
          await _migrateV2ToV3(m);
          await _migrateV3ToV4(m);
          await _migrateV4ToV5(m);
          await _migrateV5ToV6(m);
        } else if (from == 2 && to == 5) {
          await _migrateV2ToV3(m);
          await _migrateV3ToV4(m);
          await _migrateV4ToV5(m);
        } else if (from == 2 && to == 4) {
          await _migrateV2ToV3(m);
          await _migrateV3ToV4(m);
        } else if (from == 2 && to == 3) {
          await _migrateV2ToV3(m);
        } else if (from == 3 && to == 8) {
          await _migrateV3ToV4(m);
          await _migrateV4ToV5(m);
          await _migrateV5ToV6(m);
          await _migrateV6ToV7(m);
          await _migrateV7ToV8(m);
        } else if (from == 3 && to == 7) {
          await _migrateV3ToV4(m);
          await _migrateV4ToV5(m);
          await _migrateV5ToV6(m);
          await _migrateV6ToV7(m);
        } else if (from == 3 && to == 6) {
          await _migrateV3ToV4(m);
          await _migrateV4ToV5(m);
          await _migrateV5ToV6(m);
        } else if (from == 3 && to == 5) {
          await _migrateV3ToV4(m);
          await _migrateV4ToV5(m);
        } else if (from == 3 && to == 4) {
          await _migrateV3ToV4(m);
        } else if (from == 4 && to == 8) {
          await _migrateV4ToV5(m);
          await _migrateV5ToV6(m);
          await _migrateV6ToV7(m);
          await _migrateV7ToV8(m);
        } else if (from == 4 && to == 7) {
          await _migrateV4ToV5(m);
          await _migrateV5ToV6(m);
          await _migrateV6ToV7(m);
        } else if (from == 4 && to == 6) {
          await _migrateV4ToV5(m);
          await _migrateV5ToV6(m);
        } else if (from == 4 && to == 5) {
          await _migrateV4ToV5(m);
        } else if (from == 5 && to == 8) {
          await _migrateV5ToV6(m);
          await _migrateV6ToV7(m);
          await _migrateV7ToV8(m);
        } else if (from == 5 && to == 7) {
          await _migrateV5ToV6(m);
          await _migrateV6ToV7(m);
        } else if (from == 5 && to == 6) {
          await _migrateV5ToV6(m);
        } else if (from == 6 && to == 8) {
          await _migrateV6ToV7(m);
          await _migrateV7ToV8(m);
        } else if (from == 6 && to == 7) {
          await _migrateV6ToV7(m);
        } else if (from == 7 && to == 8) {
          await _migrateV7ToV8(m);
        } else {
          // For future migrations, add more conditions here
          _logger.warning('Unsupported migration path', 
            context: 'DATABASE',
            data: {'from': from, 'to': to}
          );
          throw UnsupportedError('Migration from v$from to v$to not supported');
        }
      },
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
  
  /// Migrate from v1 to v2: Add new tables while preserving existing data
  Future<void> _migrateV1ToV2(Migrator m) async {
    _logger.database('Migrating database from v1 to v2');
    
    try {
      // Step 1: Create new tables only (existing tables untouched)
      _logger.database('Creating new v2 tables', operation: 'create_tables');
      await m.createTable(foodsTable);
      await m.createTable(categoriesTable);  
      await m.createTable(foodCategoriesTable);
      await m.createTable(brandsTable);
      await m.createTable(appContentTable);
      
      // Step 2: Populate default data
      await _populateDefaultData();
      
      _logger.database('Migration v1 → v2 completed successfully');
    } catch (e, stackTrace) {
      _logger.error('Migration v1 → v2 failed', 
        context: 'DATABASE',
        error: e,
        stackTrace: stackTrace
      );
      rethrow;
    }
  }

  /// Helper method to add a column only if it doesn't already exist
  Future<void> _addColumnIfNotExists(Migrator m, TableInfo table, GeneratedColumn column, String columnName) async {
    try {
      await m.addColumn(table, column);
      _logger.database('Added $columnName column successfully');
    } catch (e) {
      // Column likely already exists - check if it's the duplicate column error
      if (e.toString().contains('duplicate column name: $columnName')) {
        _logger.database('$columnName column already exists, skipping');
      } else {
        // Re-throw if it's a different error
        rethrow;
      }
    }
  }

  /// Migrate from v2 to v3: Add swipeHintShown column to user_profiles table
  Future<void> _migrateV2ToV3(Migrator m) async {
    _logger.database('Migrating database from v2 to v3');

    try {
      // Check if column already exists before adding it
      _logger.database('Adding swipeHintShown column to user_profiles table',
        operation: 'alter_table');

      await _addColumnIfNotExists(m, userProfilesTable, userProfilesTable.swipeHintShown, 'swipe_hint_shown');

      _logger.database('Migration v2 → v3 completed successfully');
    } catch (e, stackTrace) {
      _logger.error('Migration v2 → v3 failed',
        context: 'DATABASE',
        error: e,
        stackTrace: stackTrace
      );
      rethrow;
    }
  }
  
  /// Migrate from v3 to v4: Add user journal fields to nutrition_plans table
  Future<void> _migrateV3ToV4(Migrator m) async {
    _logger.database('Migrating database from v3 to v4');

    try {
      // Add user journal fields to the nutrition_plans table
      _logger.database('Adding user journal columns to nutrition_plans table',
        operation: 'alter_table');

      // Add each column with defensive checks
      await _addColumnIfNotExists(m, nutritionPlans, nutritionPlans.runDateTime, 'run_date_time');
      await _addColumnIfNotExists(m, nutritionPlans, nutritionPlans.planRating, 'plan_rating');
      await _addColumnIfNotExists(m, nutritionPlans, nutritionPlans.journalNotes, 'journal_notes');

      _logger.database('Migration v3 → v4 completed successfully');
    } catch (e, stackTrace) {
      _logger.error('Migration v3 → v4 failed',
        context: 'DATABASE',
        error: e,
        stackTrace: stackTrace
      );
      rethrow;
    }
  }
  
  /// Migrate from v4 to v5: Add workout_notes table
  Future<void> _migrateV4ToV5(Migrator m) async {
    _logger.database('Migrating database from v4 to v5');

    try {
      // Create the new workout_notes table
      _logger.database('Creating workout_notes table', operation: 'create_table');
      await m.createTable(workoutNotesTable);

      _logger.database('Migration v4 → v5 completed successfully');
    } catch (e, stackTrace) {
      _logger.error('Migration v4 → v5 failed',
        context: 'DATABASE',
        error: e,
        stackTrace: stackTrace
      );
      rethrow;
    }
  }

  /// Migrate from v5 to v6: Add display_name_plural and to_exclude_from_solver to foods table
  Future<void> _migrateV5ToV6(Migrator m) async {
    _logger.database('Migrating database from v5 to v6');

    try {
      // Add display_name_plural column to foods table
      _logger.database('Adding display_name_plural column to foods table',
        operation: 'alter_table');
      await _addColumnIfNotExists(m, foodsTable, foodsTable.displayNamePlural, 'display_name_plural');

      // Add to_exclude_from_solver column to foods table
      _logger.database('Adding to_exclude_from_solver column to foods table',
        operation: 'alter_table');
      await _addColumnIfNotExists(m, foodsTable, foodsTable.toExcludeFromSolver, 'to_exclude_from_solver');

      _logger.database('Migration v5 → v6 completed successfully');
    } catch (e, stackTrace) {
      _logger.error('Migration v5 → v6 failed',
        context: 'DATABASE',
        error: e,
        stackTrace: stackTrace
      );
      rethrow;
    }
  }

  /// Migrate from v6 to v7: Add display_override field to foods table
  Future<void> _migrateV6ToV7(Migrator m) async {
    _logger.database('Migrating database from v6 to v7');

    try {
      // Add display_override column to foods table
      _logger.database('Adding display_override column to foods table',
        operation: 'alter_table');
      await _addColumnIfNotExists(m, foodsTable, foodsTable.displayOverride, 'display_override');

      _logger.database('Migration v6 → v7 completed successfully');
    } catch (e, stackTrace) {
      _logger.error('Migration v6 → v7 failed',
        context: 'DATABASE',
        error: e,
        stackTrace: stackTrace
      );
      rethrow;
    }
  }

  /// Migrate from v7 to v8: Sync column names with Supabase schema
  Future<void> _migrateV7ToV8(Migrator m) async {
    _logger.database('Migrating database from v7 to v8');

    try {
      // This migration only changes column name mappings via .named() in Dart code
      // No actual database schema changes are needed since Drift handles the mapping
      _logger.database('Synchronizing column names with Supabase schema');

      _logger.database('Migration v7 → v8 completed successfully');
    } catch (e, stackTrace) {
      _logger.error('Migration v7 → v8 failed',
        context: 'DATABASE',
        error: e,
        stackTrace: stackTrace
      );
      rethrow;
    }
  }

  /// Populate default data for new installations and migrations
  Future<void> _populateDefaultData() async {
    try {
      // Step 1: Populate categories
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
        gender: profile.gender.name,
        birthday: profile.birthday,
        heightFeet: profile.heightFeet,
        heightInches: profile.heightInches,
        weightPounds: profile.weightPounds,
        runsWithWaterBottle: profile.runsWithWaterBottle,
        gutTraining: profile.gutTraining.name,
        onboardingCompleted: Value(profile.onboardingCompleted),
        createdAt: profile.createdAt,
        updatedAt: profile.updatedAt,
        appVersion: profile.appVersion,
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
        gutTraining: Value(profile.gutTraining.name),
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
            userId: userId,
            foodId: entry.key,
            preference: entry.value.name,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
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
        (p) => p.name == row.preference,
        orElse: () => domain.FoodPreference.dislike,
      );
      preferencesMap[row.foodId] = preference;
    }
    
    return preferencesMap;
  }

  /// Get liked foods for a user
  Future<List<String>> getLikedFoods(String userId) async {
    final query = select(foodPreferencesTable)
      ..where((f) => f.userId.equals(userId) & f.preference.equals('like'));
    final results = await query.get();
    return results.map((r) => r.foodId).toList();
  }

  /// Get disliked foods for a user
  Future<List<String>> getDislikedFoods(String userId) async {
    final query = select(foodPreferencesTable)
      ..where((f) => f.userId.equals(userId) & f.preference.equals('dislike'));
    final results = await query.get();
    return results.map((r) => r.foodId).toList();
  }

  /// Save nutrition plan as JSON
  Future<void> saveNutritionPlan(String planId, String userId, String planData) async {
    await into(nutritionPlans).insertOnConflictUpdate(
      NutritionPlansCompanion.insert(
        id: planId,
        userId: userId,
        planData: planData,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
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

  /// Get latest nutrition plan for user
  Future<String?> getLatestNutritionPlan(String userId) async {
    final query = select(nutritionPlans)
      ..where((n) => n.userId.equals(userId))
      ..orderBy([
        (n) => OrderingTerm.desc(n.updatedAt),
        (n) => OrderingTerm.desc(n.id), // Secondary sort by ID to handle ties
      ])
      ..limit(1);
    
    final results = await query.get();
    return results.isNotEmpty ? results.first.planData : null;
  }

  /// Get all nutrition plans for user
  Future<List<String>> getAllNutritionPlans(String userId) async {
    final query = select(nutritionPlans)
      ..where((n) => n.userId.equals(userId))
      ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]);
    
    final results = await query.get();
    return results.map((r) => r.planData).toList();
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

  /// Get database statistics (v2 with new tables)
  Future<Map<String, int>> getDatabaseStats() async {
    final userCount = await (selectOnly(userProfilesTable)..addColumns([userProfilesTable.id.count()])).getSingle();
    final preferencesCount = await (selectOnly(foodPreferencesTable)..addColumns([foodPreferencesTable.userId.count()])).getSingle();
    final plansCount = await (selectOnly(nutritionPlans)..addColumns([nutritionPlans.id.count()])).getSingle();
    
    // New v2 table stats
    final foodsCount = await (selectOnly(foodsTable)..addColumns([foodsTable.id.count()])).getSingle();
    final categoriesCount = await (selectOnly(categoriesTable)..addColumns([categoriesTable.id.count()])).getSingle();
    final brandsCount = await (selectOnly(brandsTable)..addColumns([brandsTable.id.count()])).getSingle();
    final contentCount = await (selectOnly(appContentTable)..addColumns([appContentTable.id.count()])).getSingle();
    
    return {
      'users': userCount.read(userProfilesTable.id.count())!,
      'preferences': preferencesCount.read(foodPreferencesTable.userId.count())!,
      'plans': plansCount.read(nutritionPlans.id.count())!,
      'foods': foodsCount.read(foodsTable.id.count())!,
      'categories': categoriesCount.read(categoriesTable.id.count())!,
      'brands': brandsCount.read(brandsTable.id.count())!,
      'content': contentCount.read(appContentTable.id.count())!,
    };
  }
  
  // === New v2 methods for food and content management ===
  
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
  
  /// Helper method to map Supabase food data to FoodEntry
  /// Since schemas are now identical, this is a direct mapping
  FoodsTableCompanion _mapToFoodEntry(Map<String, dynamic> foodData) {
    return FoodsTableCompanion.insert(
      id: foodData['id'] ?? '',
      name: foodData['name'] ?? '',
      displayName: Value(foodData['display_name']),
      displayNamePlural: Value(foodData['display_name_plural']),
      displayOverride: Value(foodData['display_override']),
      imageAddress: Value(foodData['image_address']),
      description: Value(foodData['description']),
      instructions: Value(foodData['instructions']),
      nutritionalInfo: Value(foodData['nutritional_info'] ?? {}),
      servingAmount: Value(foodData['serving_amount']?.toDouble()),
      servingUnit: Value(foodData['serving_unit']),
      servingUnitPlural: Value(foodData['serving_unit_plural']),
      servingQualifier: Value(foodData['serving_qualifier']),
      servingSize: Value(foodData['serving_size']),
      beforeRunSuitable: Value(foodData['before_run_suitable'] ?? false),
      duringRunSuitable: Value(foodData['during_run_suitable'] ?? false),
      afterRunSuitable: Value(foodData['after_run_suitable'] ?? false),
      runPortable: Value(foodData['run_portable'] ?? false),
      requiresPreparation: Value(foodData['requires_preparation'] ?? false),
      aidStationAvailable: Value(foodData['aid_station_available'] ?? false),
      isElectrolyte: Value(foodData['is_electrolyte'] ?? false),
      toExcludeFromSolver: Value(foodData['to_exclude_from_solver'] ?? false),
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
      brandId: Value(foodData['brand_id']),
      productType: Value(foodData['product_type']),
      purchaseUrl: Value(foodData['purchase_url']),
      affiliateSource: Value(foodData['affiliate_source']),
      showInPreferences: Value(foodData['show_in_preferences'] ?? false),
      preferencePriority: Value(foodData['preference_priority'] ?? 999),
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

  /// Convert Drift UserProfileEntry to Domain UserProfile
  domain.UserProfile _convertToDomainUserProfile(UserProfileEntry dbUser) {
    return domain.UserProfile(
      id: dbUser.id,
      gender: domain.Gender.values.firstWhere(
        (g) => g.name == dbUser.gender,
        orElse: () => domain.Gender.other,
      ),
      birthday: dbUser.birthday,
      heightFeet: dbUser.heightFeet,
      heightInches: dbUser.heightInches,
      weightPounds: dbUser.weightPounds,
      runsWithWaterBottle: dbUser.runsWithWaterBottle,
      gutTraining: domain.GutTraining.values.firstWhere(
        (g) => g.name == dbUser.gutTraining,
        orElse: () => domain.GutTraining.moderate,
      ),
      onboardingCompleted: dbUser.onboardingCompleted,
      createdAt: dbUser.createdAt,
      updatedAt: dbUser.updatedAt,
      appVersion: dbUser.appVersion,
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

