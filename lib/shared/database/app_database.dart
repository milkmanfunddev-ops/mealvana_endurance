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

part 'app_database.g.dart';

/// Main Drift database for the Mealvana Endurance app
/// Replaces Hive for type-safe local storage with automatic migrations
@DriftDatabase(tables: [UserProfilesTable, FoodPreferencesTable, NutritionPlans, MacroTargetsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  
  /// Constructor for testing with in-memory database
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 2;

  /// Migration strategy for schema changes
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Version 2: Add MacroTargetsTable
        if (from < 2) {
          await m.createTable(macroTargetsTable);
        }
        
        // Future schema migrations will go here
        // Example for version 3:
        // if (from < 3) {
        //   await m.addColumn(someTable, someTable.newColumn);
        // }
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

  /// Get database statistics
  Future<Map<String, int>> getDatabaseStats() async {
    final userCount = await (selectOnly(userProfilesTable)..addColumns([userProfilesTable.id.count()])).getSingle();
    final preferencesCount = await (selectOnly(foodPreferencesTable)..addColumns([foodPreferencesTable.userId.count()])).getSingle();
    final plansCount = await (selectOnly(nutritionPlans)..addColumns([nutritionPlans.id.count()])).getSingle();
    
    return {
      'users': userCount.read(userProfilesTable.id.count())!,
      'preferences': preferencesCount.read(foodPreferencesTable.userId.count())!,
      'plans': plansCount.read(nutritionPlans.id.count())!,
    };
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

