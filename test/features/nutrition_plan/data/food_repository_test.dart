import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/food_repository.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/app_logger.dart';
import '../../../helpers/utils/console_logging.dart';

// Mock classes
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockAppDatabase extends Mock implements AppDatabase {}
class MockAppLogger extends Mock implements AppLogger {}

// Test data helpers
Map<String, dynamic> createTestFood({
  String id = 'food-123',
  String name = 'Test Food',
  int category = 1,
  double carbs = 30.0,
  double protein = 10.0,
  double fat = 5.0,
}) {
  return {
    'id': id,
    'name': name,
    'category': category,
    'carbs': carbs,
    'protein': protein,
    'fat': fat,
    'sodium': 200.0,
    'fiber': 3.0,
    'sugar': 10.0,
    'serving_size': '1 cup',
    'calories': 200,
    'fluid_oz': 8.0,
    'is_liquid': false,
    'product_type_id': 'type-1',
    'created_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  };
}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockAppDatabase mockDatabase;
  late MockAppLogger mockLogger;
  late FoodRepository repository;

  setUp(() {
    logTestHeading('FoodRepository Test Setup');

    // Initialize mocks
    mockSupabase = MockSupabaseClient();
    mockDatabase = MockAppDatabase();
    mockLogger = MockAppLogger();

    // Setup default mock behaviors
    when(() => mockLogger.debug(any())).thenReturn(null);
    when(() => mockLogger.info(any())).thenReturn(null);
    when(() => mockLogger.warning(any())).thenReturn(null);
    when(() => mockLogger.error(any(), any(), any())).thenReturn(null);

    // Create repository
    repository = FoodRepository(
      supabase: mockSupabase,
      database: mockDatabase,
      logger: mockLogger,
    );
  });

  group('FoodRepository', () {
    group('getAllFoods', () {
      test('should fetch all foods from database', () async {
        logTestHeading('Test: Get All Foods');

        // Arrange
        final mockFoods = [
          createTestFood(id: 'food-1', name: 'Banana'),
          createTestFood(id: 'food-2', name: 'Apple'),
          createTestFood(id: 'food-3', name: 'Orange'),
        ];

        when(() => mockDatabase.getAllFoods())
            .thenAnswer((_) async => mockFoods);

        // Act
        final foods = await repository.getAllFoods();

        // Assert
        expect(foods, isNotNull);
        expect(foods.length, equals(3));
        expect(foods[0].name, equals('Banana'));
        expect(foods[1].name, equals('Apple'));
        expect(foods[2].name, equals('Orange'));

        logTestResult('Foods Retrieved', {
          'count': foods.length,
          'names': foods.map((f) => f.name).toList(),
        });

        // Verify interactions
        verify(() => mockDatabase.getAllFoods()).called(1);
      });

      test('should handle empty food list', () async {
        logTestHeading('Test: Get All Foods - Empty');

        // Arrange
        when(() => mockDatabase.getAllFoods())
            .thenAnswer((_) async => []);

        // Act
        final foods = await repository.getAllFoods();

        // Assert
        expect(foods, isNotNull);
        expect(foods, isEmpty);

        logTestResult('No Foods Found', 'Empty list returned');
      });
    });

    group('getFoodsByCategory', () {
      test('should fetch foods by category', () async {
        logTestHeading('Test: Get Foods By Category');

        // Arrange
        const category = 1; // Before run
        final mockFoods = [
          createTestFood(id: 'food-1', name: 'Oatmeal', category: category),
          createTestFood(id: 'food-2', name: 'Toast', category: category),
        ];

        when(() => mockDatabase.getFoodsByCategory(category))
            .thenAnswer((_) async => mockFoods);

        // Act
        final foods = await repository.getFoodsByCategory(category);

        // Assert
        expect(foods, isNotNull);
        expect(foods.length, equals(2));
        expect(foods.every((f) => f.category == category), isTrue);

        logTestResult('Foods By Category', {
          'category': category,
          'count': foods.length,
          'names': foods.map((f) => f.name).toList(),
        });

        // Verify interactions
        verify(() => mockDatabase.getFoodsByCategory(category)).called(1);
      });
    });

    group('getFoodByName', () {
      test('should find food by exact name', () async {
        logTestHeading('Test: Get Food By Name');

        // Arrange
        const foodName = 'Banana';
        final mockFood = createTestFood(id: 'banana-123', name: foodName);

        when(() => mockDatabase.getFoodByName(foodName))
            .thenAnswer((_) async => mockFood);

        // Act
        final food = await repository.getFoodByName(foodName);

        // Assert
        expect(food, isNotNull);
        expect(food?.name, equals(foodName));
        expect(food?.id, equals('banana-123'));

        logTestResult('Food Found', {
          'name': food?.name,
          'id': food?.id,
        });

        // Verify interactions
        verify(() => mockDatabase.getFoodByName(foodName)).called(1);
      });

      test('should return null when food not found', () async {
        logTestHeading('Test: Get Food By Name - Not Found');

        // Arrange
        const foodName = 'NonexistentFood';

        when(() => mockDatabase.getFoodByName(foodName))
            .thenAnswer((_) async => null);

        // Act
        final food = await repository.getFoodByName(foodName);

        // Assert
        expect(food, isNull);

        logTestResult('Food Not Found', {
          'searchName': foodName,
          'result': 'null',
        });
      });
    });

    group('searchFoods', () {
      test('should search foods by query string', () async {
        logTestHeading('Test: Search Foods');

        // Arrange
        const query = 'ban';
        final mockResults = [
          createTestFood(id: 'food-1', name: 'Banana'),
          createTestFood(id: 'food-2', name: 'Banana Bread'),
        ];

        when(() => mockDatabase.searchFoods(query))
            .thenAnswer((_) async => mockResults);

        // Act
        final foods = await repository.searchFoods(query);

        // Assert
        expect(foods, isNotNull);
        expect(foods.length, equals(2));
        expect(foods.every((f) => f.name.toLowerCase().contains(query)), isTrue);

        logTestResult('Search Results', {
          'query': query,
          'count': foods.length,
          'names': foods.map((f) => f.name).toList(),
        });

        // Verify interactions
        verify(() => mockDatabase.searchFoods(query)).called(1);
      });

      test('should return empty list for no matches', () async {
        logTestHeading('Test: Search Foods - No Matches');

        // Arrange
        const query = 'xyz123';

        when(() => mockDatabase.searchFoods(query))
            .thenAnswer((_) async => []);

        // Act
        final foods = await repository.searchFoods(query);

        // Assert
        expect(foods, isNotNull);
        expect(foods, isEmpty);

        logTestResult('No Matches', {
          'query': query,
          'count': 0,
        });
      });
    });

    group('getPreferredFoods', () {
      test('should fetch user preferred foods', () async {
        logTestHeading('Test: Get Preferred Foods');

        // Arrange
        const deviceId = 'device-123';
        final mockPreferences = {
          'food-1': 'like',
          'food-2': 'like',
          'food-3': 'willing_to_try',
        };

        final mockFoods = [
          createTestFood(id: 'food-1', name: 'Banana'),
          createTestFood(id: 'food-2', name: 'Apple'),
          createTestFood(id: 'food-3', name: 'Orange'),
        ];

        when(() => mockDatabase.getUserFoodPreferences(deviceId))
            .thenAnswer((_) async => mockPreferences);

        when(() => mockDatabase.getFoodsByIds(any()))
            .thenAnswer((_) async => mockFoods);

        // Act
        final foods = await repository.getPreferredFoods(deviceId);

        // Assert
        expect(foods, isNotNull);
        expect(foods.length, equals(3));

        logTestResult('Preferred Foods', {
          'deviceId': deviceId,
          'count': foods.length,
          'names': foods.map((f) => f.name).toList(),
        });

        // Verify interactions
        verify(() => mockDatabase.getUserFoodPreferences(deviceId)).called(1);
        verify(() => mockDatabase.getFoodsByIds(any())).called(1);
      });

      test('should return empty list when no preferences', () async {
        logTestHeading('Test: Get Preferred Foods - No Preferences');

        // Arrange
        const deviceId = 'device-123';

        when(() => mockDatabase.getUserFoodPreferences(deviceId))
            .thenAnswer((_) async => {});

        // Act
        final foods = await repository.getPreferredFoods(deviceId);

        // Assert
        expect(foods, isNotNull);
        expect(foods, isEmpty);

        logTestResult('No Preferences', {
          'deviceId': deviceId,
          'count': 0,
        });
      });
    });

    group('getFoodByBarcode', () {
      test('should find food by barcode', () async {
        logTestHeading('Test: Get Food By Barcode');

        // Arrange
        const barcode = '012345678901';
        final mockFood = createTestFood(
          id: 'barcode-food',
          name: 'Barcode Product',
        );

        when(() => mockDatabase.getFoodByBarcode(barcode))
            .thenAnswer((_) async => mockFood);

        // Act
        final food = await repository.getFoodByBarcode(barcode);

        // Assert
        expect(food, isNotNull);
        expect(food?.name, equals('Barcode Product'));

        logTestResult('Barcode Food Found', {
          'barcode': barcode,
          'name': food?.name,
          'id': food?.id,
        });

        // Verify interactions
        verify(() => mockDatabase.getFoodByBarcode(barcode)).called(1);
      });

      test('should return null for unknown barcode', () async {
        logTestHeading('Test: Get Food By Barcode - Not Found');

        // Arrange
        const barcode = '999999999999';

        when(() => mockDatabase.getFoodByBarcode(barcode))
            .thenAnswer((_) async => null);

        // Act
        final food = await repository.getFoodByBarcode(barcode);

        // Assert
        expect(food, isNull);

        logTestResult('Barcode Not Found', {
          'barcode': barcode,
          'result': 'null',
        });
      });
    });

    group('Food Categories', () {
      test('should get food categories', () async {
        logTestHeading('Test: Get Food Categories');

        // Arrange
        final mockCategories = [
          {'id': 1, 'name': 'Before Run'},
          {'id': 2, 'name': 'During Run'},
          {'id': 3, 'name': 'After Run'},
        ];

        when(() => mockDatabase.getFoodCategories())
            .thenAnswer((_) async => mockCategories);

        // Act
        final categories = await repository.getFoodCategories();

        // Assert
        expect(categories, isNotNull);
        expect(categories.length, equals(3));
        expect(categories[0]['name'], equals('Before Run'));

        logTestResult('Categories Retrieved', {
          'count': categories.length,
          'names': categories.map((c) => c['name']).toList(),
        });

        // Verify interactions
        verify(() => mockDatabase.getFoodCategories()).called(1);
      });
    });
  });
}