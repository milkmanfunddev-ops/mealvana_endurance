/// Testing-wave 68-011 (ticket 74): a barcode lookup of Nutella
/// (3017620422003, a `nutrition_products` cache hit) showed the per-100 g
/// label values (539 kcal) as "1 serving".
///
/// Seam test: the input is the cache answer exactly as `lookup-product`
/// sends it (`supabase/functions/_shared/food_sources/cache.ts`, snake_case,
/// no `serving_quantity`), parsed by the production
/// [ApiFoodProduct.fromEdgeFunctionResponse]. Never a Food built by the
/// mapper.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/barcode_scanning/application/food_mapping_service.dart';
import 'package:mealvana_endurance/features/barcode_scanning/domain/api_food_product.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/food_repository.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item.dart';
import 'package:mocktail/mocktail.dart';

class _MockFoodRepository extends Mock implements FoodRepository {}

/// The cache row as the edge function answers it. Nutella's figures are its
/// per-100 g label; the row's `serving_grams` and `calories_per_serving` are
/// null (68-011's from-code reading of the row).
Map<String, dynamic> _cacheRow({
  String barcode = '03017620422003',
  Object? servingSize = '15 g',
  Object? servingGrams,
  Object? caloriesPerServing,
  Object? carbsPerServing,
  Object? proteinPerServing,
  Object? fatPerServing,
  Object? caloriesPer100g = 539,
  Object? carbsPer100g = 57.5,
  Object? proteinPer100g = 6.3,
  Object? fatPer100g = 30.9,
  String? nutritionDataPer = '100g',
}) => {
  'barcode': barcode,
  'product_name': 'Nutella',
  'brand_name': 'Ferrero',
  'image_url': null,
  'serving_size': servingSize,
  'serving_grams': servingGrams,
  'calories_per_100g': caloriesPer100g,
  'carbohydrates_per_100g': carbsPer100g,
  'protein_per_100g': proteinPer100g,
  'fat_per_100g': fatPer100g,
  'sodium_mg_per_100g': 41,
  'calories_per_serving': caloriesPerServing,
  'carbohydrates_per_serving': carbsPerServing,
  'protein_per_serving': proteinPerServing,
  'fat_per_serving': fatPerServing,
  'sodium_mg_per_serving': null,
  'categories': 'Spreads, Sweet spreads',
  'suggested_product_type': null,
  'nutrition_data_per': nutritionDataPer,
  'api_source': 'open_food_facts',
  'confidence_score': 0.9,
};

void main() {
  late _MockFoodRepository repository;
  late FoodMappingService service;

  setUp(() {
    repository = _MockFoodRepository();
    service = FoodMappingService(repository);
    when(
      () => repository.getFoodByBarcode(any()),
    ).thenAnswer((_) async => null);
    when(() => repository.getFoodByName(any())).thenAnswer((_) async => null);
    when(() => repository.getFoodCategories(any())).thenAnswer((_) async => []);
  });

  Future<Food> map(Map<String, dynamic> row) =>
      service.mapToFood(ApiFoodProduct.fromEdgeFunctionResponse(row));

  group('new food (no barcode row in the local catalog)', () {
    test(
      'Nutella as cached: the 15 g serving it names, about 81 kcal',
      () async {
        final food = await map(_cacheRow());

        expect(food.servingSize, '15 g');
        expect(food.caloriesPerServing, 81); // 539 x 0.15 = 80.85
        expect(food.carbsPerServing, closeTo(8.6, 0.05)); // 57.5 x 0.15
        expect(food.servingAmount, 1.0);
        expect(food.servingUnit, 'servings');
      },
    );

    test('no serving named: per-100 g values, labelled "100 g"', () async {
      final food = await map(_cacheRow(servingSize: null));

      expect(food.servingSize, '100 g');
      expect(food.caloriesPerServing, 539);
      expect(food.carbsPerServing, closeTo(57.5, 0.001));
    });

    test(
      'a serving text without grams never labels per-100 g values',
      () async {
        final food = await map(_cacheRow(servingSize: '1 portion'));

        expect(food.servingSize, '100 g');
        expect(food.caloriesPerServing, 539);
      },
    );

    test('grams inside a longer label: "1 portion (37 g)"', () async {
      final food = await map(_cacheRow(servingSize: '1 portion (37 g)'));

      expect(food.servingSize, '1 portion (37 g)');
      expect(food.caloriesPerServing, 199);
    });

    test(
      'per-serving values with no grams (USDA label shape): as sent',
      () async {
        final food = await map(
          _cacheRow(
            barcode: '00000012345670',
            servingSize: '2 tbsp',
            caloriesPerServing: 140,
            carbsPerServing: 21,
            proteinPerServing: 1,
            fatPerServing: 6,
            caloriesPer100g: null,
            carbsPer100g: null,
            proteinPer100g: null,
            fatPer100g: null,
            nutritionDataPer: 'serving',
          ),
        );

        expect(food.servingSize, '2 tbsp');
        expect(food.caloriesPerServing, 140);
        expect(food.carbsPerServing, 21);
      },
    );

    test('declared serving_grams 37 with per-100 g only: 199 kcal', () async {
      final food = await map(_cacheRow(servingSize: null, servingGrams: 37));

      expect(food.servingSize, '37 g');
      expect(food.caloriesPerServing, 199); // 539 x 0.37 = 199.43
    });

    test(
      'numbers arriving as strings (numeric columns) parse the same',
      () async {
        final food = await map(
          _cacheRow(caloriesPer100g: '539', carbsPer100g: '57.5'),
        );

        expect(food.caloriesPerServing, 81);
        expect(food.servingSize, '15 g');
      },
    );
  });

  group('existing food (barcode row in the local catalog)', () {
    setUp(() {
      when(() => repository.getFoodByBarcode(any())).thenAnswer(
        (_) async => FoodItem(
          id: 'catalog-nutella',
          name: 'Nutella',
          displayName: 'Nutella',
        ),
      );
    });

    test('Nutella as cached: 15 g, about 81 kcal', () async {
      final food = await map(_cacheRow());

      expect(food.name, 'Nutella');
      expect(food.servingSize, '15 g');
      expect(food.caloriesPerServing, 81);
    });

    test('no serving named: 539 kcal labelled "100 g"', () async {
      final food = await map(_cacheRow(servingSize: null));

      expect(food.servingSize, '100 g');
      expect(food.caloriesPerServing, 539);
    });

    test('declared serving_grams 37: 199 kcal', () async {
      final food = await map(_cacheRow(servingSize: null, servingGrams: 37));

      expect(food.servingSize, '37 g');
      expect(food.caloriesPerServing, 199);
    });
  });
}
