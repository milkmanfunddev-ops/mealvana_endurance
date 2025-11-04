/// Database testing utilities for Mealvana Endurance
/// 
/// Provides helpers for setting up in-memory databases, populating test data,
/// and validating database operations for schema migration and data integrity tests.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;

import 'package:mealvana_endurance/shared/database/database.dart';

import 'test_data.dart';

/// Database testing utilities
class TestDatabaseUtils {
  /// Creates an in-memory database for fast testing
  static AppDatabase createInMemoryDatabase({int? schemaVersion}) {
    final connection = DatabaseConnection(
      NativeDatabase.memory(),
    );
    
    if (schemaVersion != null) {
      return AppDatabase.withConnection(connection, schemaVersion: schemaVersion);
    }
    
    return AppDatabase.withConnection(connection);
  }

  /// Creates a file-based test database (slower but persistent)
  static Future<AppDatabase> createFileDatabase({
    String? name,
    int? schemaVersion,
  }) async {
    final dbName = name ?? 'test_${DateTime.now().millisecondsSinceEpoch}.db';
    final tempDir = Directory.systemTemp;
    final dbFile = File(path.join(tempDir.path, dbName));
    
    // Ensure clean slate
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
    
    final connection = DatabaseConnection(
      NativeDatabase(dbFile),
    );
    
    if (schemaVersion != null) {
      return AppDatabase.withConnection(connection, schemaVersion: schemaVersion);
    }
    
    return AppDatabase.withConnection(connection);
  }

  /// Populates database with standard test data
  static Future<void> populateTestData(AppDatabase db) async {
    // Insert test user profile
    await db.userProfiles.insertOne(TestData.testUserProfile);

    // Insert test food preferences
    for (final preference in TestData.testFoodPreferences) {
      await db.foodPreferences.insertOne(preference);
    }

    // Insert test categories
    await db.categories.insertAll([
      const CategoryData(
        id: 'before_run',
        name: 'Before Run',
        description: 'Foods suitable for pre-run consumption',
        createdAt: TestData.timestamp1,
        updatedAt: TestData.timestamp1,
      ),
      const CategoryData(
        id: 'during_run',
        name: 'During Run',
        description: 'Foods suitable for consumption while running',
        createdAt: TestData.timestamp1,
        updatedAt: TestData.timestamp1,
      ),
      const CategoryData(
        id: 'after_run',
        name: 'After Run',
        description: 'Foods suitable for post-run recovery',
        createdAt: TestData.timestamp1,
        updatedAt: TestData.timestamp1,
      ),
    ]);

    // Insert test foods
    await _insertTestFoods(db);
    
    // Insert test food-category relationships
    await _insertTestFoodCategories(db);
  }

  /// Validates database schema integrity
  static Future<bool> validateSchema(AppDatabase db, int expectedVersion) async {
    try {
      // Check if all expected tables exist
      final tables = await db.customSelect('SELECT name FROM sqlite_master WHERE type="table"').get();
      final tableNames = tables.map((row) => row.data['name'] as String).toSet();
      
      // Expected tables for v2 schema
      const expectedTables = {
        'user_profiles',
        'food_preferences', 
        'nutrition_plans',
        'foods',
        'categories',
        'food_categories',
        'brands',
        'feedback',
        'macro_targets',
        'app_content',
      };
      
      // Check all tables exist
      for (final expectedTable in expectedTables) {
        if (!tableNames.contains(expectedTable)) {
          return false;
        }
      }
      
      // Verify we can perform basic operations
      await db.userProfiles.select().get();
      await db.foodPreferences.select().get();
      await db.nutritionPlans.select().get();
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Creates v1 schema database with test data for migration testing
  static Future<AppDatabase> createV1DatabaseWithData() async {
    final db = createInMemoryDatabase(schemaVersion: 1);
    
    // Populate with v1-style data
    await _populateV1TestData(db);
    
    return db;
  }

  /// Verifies data preservation after migration
  static Future<bool> verifyMigrationDataPreservation(
    AppDatabase originalDb,
    AppDatabase migratedDb,
  ) async {
    try {
      // Check user profiles preserved
      final originalProfiles = await originalDb.userProfiles.select().get();
      final migratedProfiles = await migratedDb.userProfiles.select().get();
      
      if (originalProfiles.length != migratedProfiles.length) {
        return false;
      }
      
      // Verify specific user data
      final originalUser = originalProfiles.firstWhere(
        (profile) => profile.deviceId == TestData.deviceId1,
      );
      final migratedUser = migratedProfiles.firstWhere(
        (profile) => profile.deviceId == TestData.deviceId1,
      );
      
      if (originalUser.age != migratedUser.age ||
          originalUser.weightKg != migratedUser.weightKg ||
          originalUser.heightCm != migratedUser.heightCm) {
        return false;
      }
      
      // Check new v2 tables are accessible
      await migratedDb.foodPreferences.select().get();
      await migratedDb.macroTargets.select().get();
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Simulates database corruption for error handling tests
  static Future<void> simulateCorruption(AppDatabase db) async {
    // Close the database
    await db.close();
    
    // This would simulate corruption in real scenarios
    // For tests, we'll just create an invalid state
    throw const DatabaseException('Database corrupted for testing');
  }

  /// Measures database operation performance
  static Future<Duration> measureOperationTime(Future<void> Function() operation) async {
    final stopwatch = Stopwatch()..start();
    await operation();
    stopwatch.stop();
    return stopwatch.elapsed;
  }

  /// Helper to insert test foods
  static Future<void> _insertTestFoods(AppDatabase db) async {
    final testFoods = [
      const FoodData(
        id: 'oatmeal',
        name: 'Oatmeal',
        servingAmount: 1.0,
        servingUnit: 'cup',
        servingUnitPlural: 'cups',
        servingQualifier: 'cooked',
        carbsG: 30.0,
        proteinG: 5.0,
        fatG: 3.0,
        sodiumMg: 0.0,
        isActive: true,
        createdAt: TestData.timestamp1,
        updatedAt: TestData.timestamp1,
      ),
      const FoodData(
        id: 'gels',
        name: 'Energy Gels',
        servingAmount: 1.0,
        servingUnit: 'packet',
        servingUnitPlural: 'packets',
        servingQualifier: '',
        carbsG: 22.0,
        proteinG: 0.0,
        fatG: 0.0,
        sodiumMg: 50.0,
        isActive: true,
        createdAt: TestData.timestamp1,
        updatedAt: TestData.timestamp1,
      ),
      const FoodData(
        id: 'sports_drink',
        name: 'Sports Drink',
        servingAmount: 8.0,
        servingUnit: 'fl oz',
        servingUnitPlural: 'fl oz',
        servingQualifier: '',
        carbsG: 14.0,
        proteinG: 0.0,
        fatG: 0.0,
        sodiumMg: 110.0,
        isActive: true,
        createdAt: TestData.timestamp1,
        updatedAt: TestData.timestamp1,
      ),
      const FoodData(
        id: 'banana',
        name: 'Banana',
        servingAmount: 1.0,
        servingUnit: 'medium',
        servingUnitPlural: 'medium',
        servingQualifier: '',
        carbsG: 27.0,
        proteinG: 1.0,
        fatG: 0.4,
        sodiumMg: 1.0,
        isActive: true,
        createdAt: TestData.timestamp1,
        updatedAt: TestData.timestamp1,
      ),
    ];

    for (final food in testFoods) {
      await db.foods.insertOne(food);
    }
  }

  /// Helper to insert test food-category relationships
  static Future<void> _insertTestFoodCategories(AppDatabase db) async {
    final relationships = [
      // Oatmeal - before run only
      const FoodCategoryData(
        foodId: 'oatmeal',
        categoryId: 'before_run',
        createdAt: TestData.timestamp1,
      ),
      // Gels - during run only
      const FoodCategoryData(
        foodId: 'gels',
        categoryId: 'during_run',
        createdAt: TestData.timestamp1,
      ),
      // Sports drink - all phases
      const FoodCategoryData(
        foodId: 'sports_drink',
        categoryId: 'before_run',
        createdAt: TestData.timestamp1,
      ),
      const FoodCategoryData(
        foodId: 'sports_drink',
        categoryId: 'during_run',
        createdAt: TestData.timestamp1,
      ),
      const FoodCategoryData(
        foodId: 'sports_drink',
        categoryId: 'after_run',
        createdAt: TestData.timestamp1,
      ),
      // Banana - before and after run (not during)
      const FoodCategoryData(
        foodId: 'banana',
        categoryId: 'before_run',
        createdAt: TestData.timestamp1,
      ),
      const FoodCategoryData(
        foodId: 'banana',
        categoryId: 'after_run',
        createdAt: TestData.timestamp1,
      ),
    ];

    for (final relationship in relationships) {
      await db.foodCategories.insertOne(relationship);
    }
  }

  /// Helper to populate v1 test data (simulated)
  static Future<void> _populateV1TestData(AppDatabase db) async {
    // Insert basic user profile that would exist in v1
    await db.userProfiles.insertOne(TestData.testUserProfile);
    
    // v1 wouldn't have food_preferences or macro_targets
    // This simulates the state before migration
  }
}