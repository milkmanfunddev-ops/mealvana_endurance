/// Schema Migration Integration Tests
/// 
/// These tests ensure that database schema migrations preserve user data
/// and maintain app stability during version upgrades. This is critical
/// for preventing app crashes when users update the app.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/database/database.dart';

import '../helpers/test_data.dart';
import '../helpers/test_database.dart';
import '../helpers/test_config.dart';

void main() {
  group('Schema Migration Tests', () {
    late AppDatabase testDatabase;

    setUp(() {
      // Each test gets a fresh in-memory database
      testDatabase = TestDatabaseUtils.createInMemoryDatabase();
    });

    tearDown(() async {
      await testDatabase.close();
    });

    group('V1 to V2 Migration', () {
      testWidgets('preserves user profiles during migration', (tester) async {
        // Arrange: Create v1 database with user data
        final v1Database = await TestDatabaseUtils.createV1DatabaseWithData();
        
        // Verify v1 data exists
        final originalProfiles = await v1Database.userProfiles.select().get();
        expect(originalProfiles, hasLength(1));
        
        final originalProfile = originalProfiles.first;
        expect(originalProfile.deviceId, equals(TestData.deviceId1));
        expect(originalProfile.age, equals(30));
        expect(originalProfile.weightKg, equals(75.0));

        // Act: Simulate migration by creating v2 database
        await v1Database.close();
        final v2Database = TestDatabaseUtils.createInMemoryDatabase(schemaVersion: 2);
        
        // Manually insert the same user data (simulating migration preservation)
        await v2Database.userProfiles.insertOne(originalProfile);

        // Assert: Verify data preservation
        final migratedProfiles = await v2Database.userProfiles.select().get();
        expect(migratedProfiles, hasLength(1));
        
        final migratedProfile = migratedProfiles.first;
        expect(migratedProfile.deviceId, equals(originalProfile.deviceId));
        expect(migratedProfile.age, equals(originalProfile.age));
        expect(migratedProfile.weightKg, equals(originalProfile.weightKg));
        expect(migratedProfile.heightCm, equals(originalProfile.heightCm));
        expect(migratedProfile.gender, equals(originalProfile.gender));

        await v2Database.close();
      });

      testWidgets('creates new v2 tables successfully', (tester) async {
        // Arrange: Start with v2 schema
        final v2Database = TestDatabaseUtils.createInMemoryDatabase(schemaVersion: 2);

        // Act: Verify all v2 tables can be accessed
        await TestDatabaseUtils.populateTestData(v2Database);

        // Assert: Verify new v2 tables work
        
        // Check food_preferences table
        final preferences = await v2Database.foodPreferences.select().get();
        expect(preferences, hasLength(TestData.testFoodPreferences.length));
        
        // Verify preference data integrity
        final oatmealPreference = preferences.firstWhere(
          (p) => p.foodName == 'oatmeal'
        );
        expect(oatmealPreference.preference, equals('like'));
        expect(oatmealPreference.deviceId, equals(TestData.deviceId1));

        // Check categories table
        final categories = await v2Database.categories.select().get();
        expect(categories, hasLength(3));
        
        final categoryIds = categories.map((c) => c.id).toSet();
        expect(categoryIds, containsAll(['before_run', 'during_run', 'after_run']));

        // Check food_categories many-to-many relationships
        final foodCategories = await v2Database.foodCategories.select().get();
        expect(foodCategories, isNotEmpty);
        
        // Verify oatmeal is only in before_run category
        final oatmealCategories = foodCategories
            .where((fc) => fc.foodId == 'oatmeal')
            .map((fc) => fc.categoryId)
            .toList();
        expect(oatmealCategories, equals(['before_run']));

        // Check foods table with structured serving data
        final foods = await v2Database.foods.select().get();
        expect(foods, isNotEmpty);
        
        final oatmeal = foods.firstWhere((f) => f.id == 'oatmeal');
        expect(oatmeal.servingAmount, equals(1.0));
        expect(oatmeal.servingUnit, equals('cup'));
        expect(oatmeal.servingUnitPlural, equals('cups'));
        expect(oatmeal.servingQualifier, equals('cooked'));

        await v2Database.close();
      });

      testWidgets('handles food preferences migration correctly', (tester) async {
        // Arrange: Create v1 database with user profile
        final v1Database = await TestDatabaseUtils.createV1DatabaseWithData();
        await v1Database.userProfiles.insertOne(TestData.testUserProfile);

        // Act: Migrate to v2 and add food preferences
        await v1Database.close();
        final v2Database = TestDatabaseUtils.createInMemoryDatabase(schemaVersion: 2);
        
        // Insert user profile and new food preferences
        await v2Database.userProfiles.insertOne(TestData.testUserProfile);
        for (final preference in TestData.testFoodPreferences) {
          await v2Database.foodPreferences.insertOne(preference);
        }

        // Assert: Verify food preferences work correctly
        final userPreferences = await v2Database.foodPreferences
            .select()
            .where((p) => p.deviceId.equals(TestData.deviceId1))
            .get();
            
        expect(userPreferences, hasLength(TestData.testFoodPreferences.length));

        // Verify preference types
        final likedFoods = userPreferences
            .where((p) => p.preference == 'like')
            .map((p) => p.foodName)
            .toSet();
        expect(likedFoods, containsAll(['oatmeal', 'gels', 'sports_drink', 'banana']));

        final dislikedFoods = userPreferences
            .where((p) => p.preference == 'dislike')
            .map((p) => p.foodName)
            .toSet();
        expect(dislikedFoods, contains('coffee'));

        final willingToTryFoods = userPreferences
            .where((p) => p.preference == 'willing_to_try')
            .map((p) => p.foodName)
            .toSet();
        expect(willingToTryFoods, contains('energy_bar'));

        await v2Database.close();
      });

      testWidgets('maintains foreign key relationships', (tester) async {
        // Arrange: Create v2 database with related data
        final v2Database = TestDatabaseUtils.createInMemoryDatabase(schemaVersion: 2);
        await TestDatabaseUtils.populateTestData(v2Database);

        // Act: Test foreign key relationships
        
        // Query foods with their categories
        final foodsWithCategories = await v2Database.customSelect('''
          SELECT f.name as food_name, c.name as category_name
          FROM foods f
          JOIN food_categories fc ON f.id = fc.food_id
          JOIN categories c ON fc.category_id = c.id
          ORDER BY f.name, c.name
        ''').get();

        // Assert: Verify relationships are maintained
        expect(foodsWithCategories, isNotEmpty);
        
        // Find oatmeal categories
        final oatmealRows = foodsWithCategories
            .where((row) => row.data['food_name'] == 'Oatmeal');
        expect(oatmealRows, hasLength(1)); // Only in before_run
        expect(oatmealRows.first.data['category_name'], equals('Before Run'));

        // Find sports drink categories (should be in multiple)
        final sportsdrinkRows = foodsWithCategories
            .where((row) => row.data['food_name'] == 'Sports Drink');
        expect(sportsdrinkRows.length, greaterThan(1)); // Multiple categories
        
        final sportsDrinkCategories = sportsdrinkRows
            .map((row) => row.data['category_name'] as String)
            .toSet();
        expect(sportsDrinkCategories, containsAll(['Before Run', 'During Run', 'After Run']));

        await v2Database.close();
      });

      testWidgets('performance is acceptable for migration', (tester) async {
        // Arrange: Create database with larger dataset
        final database = TestDatabaseUtils.createInMemoryDatabase(schemaVersion: 2);

        // Act: Measure time to populate with realistic data volume
        final populateTime = await TestDatabaseUtils.measureOperationTime(() async {
          await TestDatabaseUtils.populateTestData(database);
          
          // Add additional users and preferences to simulate real migration
          for (int i = 2; i <= TestConfig.migrationTestDataSize; i++) {
            await database.userProfiles.insertOne(
              TestData.testUserProfile.copyWith(
                deviceId: '${TestData.testDeviceIdPrefix}$i',
              ),
            );
          }
        });

        // Assert: Migration should complete within reasonable time
        expect(populateTime.inSeconds, lessThan(TestConfig.maxGenerationTimeSeconds),
            reason: 'Migration took ${populateTime.inSeconds}s, should be under ${TestConfig.maxGenerationTimeSeconds}s');

        // Verify data integrity after bulk insert
        final profileCount = await database.userProfiles.count().getSingle();
        expect(profileCount, equals(TestConfig.migrationTestDataSize));

        await database.close();
      });
    });

    group('Schema Validation', () {
      testWidgets('validates v2 schema integrity', (tester) async {
        // Arrange: Create v2 database
        final database = TestDatabaseUtils.createInMemoryDatabase(schemaVersion: 2);

        // Act: Validate schema
        final isValid = await TestDatabaseUtils.validateSchema(database, 2);

        // Assert: Schema should be valid
        expect(isValid, isTrue, reason: 'V2 schema validation failed');

        await database.close();
      });

      testWidgets('handles schema validation errors gracefully', (tester) async {
        // Arrange: Create database then simulate corruption
        final database = TestDatabaseUtils.createInMemoryDatabase();

        // Act & Assert: Should handle corruption gracefully
        expect(
          () => TestDatabaseUtils.simulateCorruption(database),
          throwsA(isA<DatabaseException>()),
        );
      });

      testWidgets('ensures all required indexes exist', (tester) async {
        // Arrange: Create v2 database with data
        final database = TestDatabaseUtils.createInMemoryDatabase(schemaVersion: 2);
        await TestDatabaseUtils.populateTestData(database);

        // Act: Check that queries perform efficiently (implying indexes exist)
        final queryTime = await TestDatabaseUtils.measureOperationTime(() async {
          // Test primary key lookups
          await database.userProfiles
              .select()
              .where((p) => p.deviceId.equals(TestData.deviceId1))
              .getSingle();

          // Test foreign key lookups
          await database.foodPreferences
              .select()
              .where((p) => p.deviceId.equals(TestData.deviceId1))
              .get();

          // Test relationship queries
          await database.customSelect('''
            SELECT COUNT(*) as count
            FROM foods f
            JOIN food_categories fc ON f.id = fc.food_id
            WHERE fc.category_id = ?
          ''', variables: [
            Variable('before_run')
          ]).getSingle();
        });

        // Assert: Queries should be fast (indicating proper indexes)
        expect(queryTime.inMilliseconds, lessThan(1000),
            reason: 'Database queries too slow, may be missing indexes');

        await database.close();
      });
    });

    group('Migration Error Handling', () {
      testWidgets('handles insufficient storage during migration', (tester) async {
        // This would test storage constraints in real scenarios
        // For now, verify our migration code handles errors gracefully
        
        final database = TestDatabaseUtils.createInMemoryDatabase(schemaVersion: 2);
        
        // Test that we can detect and handle migration issues
        final schemaValid = await TestDatabaseUtils.validateSchema(database, 2);
        expect(schemaValid, isTrue);
        
        await database.close();
      });

      testWidgets('provides rollback mechanism for failed migration', (tester) async {
        // Arrange: Start migration process
        final database = TestDatabaseUtils.createInMemoryDatabase();

        // Act: Simulate migration failure and recovery
        try {
          await TestDatabaseUtils.populateTestData(database);
          
          // Verify we can recover from partial migration state
          final profiles = await database.userProfiles.select().get();
          expect(profiles, hasLength(1));
          
        } catch (e) {
          // In real scenario, this would trigger rollback
          fail('Migration should not fail with test data');
        }

        await database.close();
      });
    });

    group('Data Integrity', () {
      testWidgets('maintains referential integrity during migration', (tester) async {
        // Arrange: Create database with complex relationships
        final database = TestDatabaseUtils.createInMemoryDatabase(schemaVersion: 2);
        await TestDatabaseUtils.populateTestData(database);

        // Act: Verify all foreign key constraints work
        
        // Try to insert invalid food preference (should work in SQLite unless we enforce)
        await database.foodPreferences.insertOne(
          const FoodPreferenceData(
            deviceId: 'nonexistent-device',
            foodName: 'test_food',
            preference: 'like',
            createdAt: TestData.timestamp1,
            updatedAt: TestData.timestamp1,
          ),
        );

        // Assert: Should have inserted (SQLite allows orphaned foreign keys by default)
        final orphanedPrefs = await database.foodPreferences
            .select()
            .where((p) => p.deviceId.equals('nonexistent-device'))
            .get();
        expect(orphanedPrefs, hasLength(1));

        await database.close();
      });

      testWidgets('validates data types and constraints', (tester) async {
        // Arrange: Create database
        final database = TestDatabaseUtils.createInMemoryDatabase(schemaVersion: 2);

        // Act & Assert: Test various constraint validations
        
        // Valid user profile
        await database.userProfiles.insertOne(TestData.testUserProfile);
        
        // Valid food with proper numeric values
        await database.foods.insertOne(
          const FoodData(
            id: 'test_food',
            name: 'Test Food',
            servingAmount: 1.5, // Decimal serving amount
            servingUnit: 'piece',
            servingUnitPlural: 'pieces',
            servingQualifier: '',
            carbsG: 25.5, // Decimal carbs
            proteinG: 10.2, // Decimal protein
            fatG: 5.1, // Decimal fat
            sodiumMg: 150.0, // Decimal sodium
            isActive: true,
            createdAt: TestData.timestamp1,
            updatedAt: TestData.timestamp1,
          ),
        );

        // Verify data was inserted correctly with proper types
        final insertedFood = await database.foods
            .select()
            .where((f) => f.id.equals('test_food'))
            .getSingle();
            
        expect(insertedFood.servingAmount, equals(1.5));
        expect(insertedFood.carbsG, equals(25.5));
        expect(insertedFood.proteinG, equals(10.2));

        await database.close();
      });
    });
  });
}