/// Unit tests for [Recipe], [RecipeNutrition], and [RecipeType] domain objects.
///
/// Pure value-object tests: no Drift, no Supabase, no Riverpod.
/// Covers: construction, JSON round-trip, copyWith completeness,
/// RecipeType wire/display values, equality implied by copyWith contracts.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/recipes/domain/recipe.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

RecipeNutrition _nutrition({
  double calories = 400,
  double carbs = 60,
  double protein = 15,
  double fat = 10,
  double fiber = 5,
  double sugar = 8,
  double sodium = 300,
}) {
  return RecipeNutrition(
    calories: calories,
    carbohydratesGrams: carbs,
    proteinGrams: protein,
    fatGrams: fat,
    fiberGrams: fiber,
    sugarGrams: sugar,
    sodiumMilligrams: sodium,
  );
}

Recipe _recipe({
  String id = 'recipe-001',
  String name = 'Overnight Oats',
  RecipeType type = RecipeType.breakfast,
  RecipeNutrition? nutrition,
  String? imageUrl,
  List<String>? tags,
  bool isFavorite = false,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return Recipe(
    id: id,
    name: name,
    description: 'A simple overnight oats recipe.',
    ingredients: const ['1 cup rolled oats', '1 cup milk', '1 tbsp chia seeds'],
    instructions: const ['Mix oats and milk.', 'Refrigerate overnight.'],
    prepTimeMinutes: 5,
    servings: 2,
    type: type,
    nutrition: nutrition ?? _nutrition(),
    imageUrl: imageUrl,
    tags: tags,
    isFavorite: isFavorite,
    createdAt: createdAt ?? DateTime(2025, 1, 1),
    updatedAt: updatedAt ?? DateTime(2025, 6, 1),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // RecipeType
  // =========================================================================

  group('RecipeType.wireValue', () {
    test('breakfast → "breakfast"', () {
      expect(RecipeType.breakfast.wireValue, 'breakfast');
    });

    test('mains → "mains"', () {
      expect(RecipeType.mains.wireValue, 'mains');
    });

    test('snacks → "snacks"', () {
      expect(RecipeType.snacks.wireValue, 'snacks');
    });

    test('workoutFuel → "workout_fuel"', () {
      expect(RecipeType.workoutFuel.wireValue, 'workout_fuel');
    });

    test('recovery → "recovery"', () {
      expect(RecipeType.recovery.wireValue, 'recovery');
    });
  });

  group('RecipeType.fromWire', () {
    test('parses each valid wire value back to its enum', () {
      for (final t in RecipeType.values) {
        expect(RecipeType.fromWire(t.wireValue), t,
            reason: '"${t.wireValue}" should parse to ${t.name}');
      }
    });

    test('unknown wire value defaults to mains', () {
      expect(RecipeType.fromWire(''), RecipeType.mains);
      expect(RecipeType.fromWire('preRun'), RecipeType.mains,
          reason: 'legacy "preRun" is now mapped to mains');
      expect(RecipeType.fromWire('unknown'), RecipeType.mains);
    });

    test('wire value round-trips through fromWire and back to wireValue', () {
      for (final t in RecipeType.values) {
        final parsed = RecipeType.fromWire(t.wireValue);
        expect(parsed.wireValue, t.wireValue);
      }
    });
  });

  group('RecipeType.displayLabel', () {
    test('workoutFuel displays as "Workout Fuel" (two words)', () {
      expect(RecipeType.workoutFuel.displayLabel, 'Workout Fuel');
    });

    test('each type has a non-empty display label', () {
      for (final t in RecipeType.values) {
        expect(t.displayLabel, isNotEmpty,
            reason: '${t.name} must have a display label');
      }
    });

    // All display labels should start with a capital letter.
    test('all display labels start with a capital letter', () {
      for (final t in RecipeType.values) {
        expect(t.displayLabel[0].toUpperCase(), t.displayLabel[0],
            reason: '${t.name} display label must start with uppercase');
      }
    });
  });

  // =========================================================================
  // RecipeNutrition
  // =========================================================================

  group('RecipeNutrition — construction', () {
    test('stores all nutrition fields', () {
      final n = _nutrition(
        calories: 350,
        carbs: 55,
        protein: 12,
        fat: 8,
        fiber: 4,
        sugar: 6,
        sodium: 250,
      );
      expect(n.calories, 350);
      expect(n.carbohydratesGrams, 55);
      expect(n.proteinGrams, 12);
      expect(n.fatGrams, 8);
      expect(n.fiberGrams, 4);
      expect(n.sugarGrams, 6);
      expect(n.sodiumMilligrams, 250);
    });

    test('zero values are valid', () {
      final n = _nutrition(
        calories: 0,
        carbs: 0,
        protein: 0,
        fat: 0,
        fiber: 0,
        sugar: 0,
        sodium: 0,
      );
      expect(n.calories, 0);
      expect(n.carbohydratesGrams, 0);
    });
  });

  group('RecipeNutrition.fromJson / toJson', () {
    test('round-trips without data loss', () {
      final original = _nutrition(
          calories: 420, carbs: 65, protein: 14, fat: 11, fiber: 6, sugar: 9, sodium: 320);
      final json = original.toJson();
      final restored = RecipeNutrition.fromJson(json);

      expect(restored.calories, original.calories);
      expect(restored.carbohydratesGrams, original.carbohydratesGrams);
      expect(restored.proteinGrams, original.proteinGrams);
      expect(restored.fatGrams, original.fatGrams);
      expect(restored.fiberGrams, original.fiberGrams);
      expect(restored.sugarGrams, original.sugarGrams);
      expect(restored.sodiumMilligrams, original.sodiumMilligrams);
    });

    test('fromJson handles integer values in JSON (num.toDouble)', () {
      final n = RecipeNutrition.fromJson({
        'calories': 300,
        'carbohydratesGrams': 45,
        'proteinGrams': 10,
        'fatGrams': 8,
        'fiberGrams': 3,
        'sugarGrams': 5,
        'sodiumMilligrams': 200,
      });
      expect(n.calories, 300.0);
      expect(n.carbohydratesGrams, 45.0);
    });

    test('toJson uses camelCase keys matching fromJson expectations', () {
      final json = _nutrition().toJson();
      expect(json.containsKey('calories'), isTrue);
      expect(json.containsKey('carbohydratesGrams'), isTrue);
      expect(json.containsKey('proteinGrams'), isTrue);
      expect(json.containsKey('fatGrams'), isTrue);
      expect(json.containsKey('fiberGrams'), isTrue);
      expect(json.containsKey('sugarGrams'), isTrue);
      expect(json.containsKey('sodiumMilligrams'), isTrue);
    });
  });

  group('RecipeNutrition.copyWith', () {
    test('no-op copy preserves all values', () {
      final n = _nutrition();
      final copy = n.copyWith();
      expect(copy.calories, n.calories);
      expect(copy.carbohydratesGrams, n.carbohydratesGrams);
      expect(copy.proteinGrams, n.proteinGrams);
      expect(copy.fatGrams, n.fatGrams);
      expect(copy.fiberGrams, n.fiberGrams);
      expect(copy.sugarGrams, n.sugarGrams);
      expect(copy.sodiumMilligrams, n.sodiumMilligrams);
    });

    // BUG HUNT: each field must appear in the copyWith body.
    test('every field can be independently updated', () {
      final base = _nutrition();

      expect(base.copyWith(calories: 9999).calories, 9999);
      expect(base.copyWith(carbohydratesGrams: 9999).carbohydratesGrams, 9999);
      expect(base.copyWith(proteinGrams: 9999).proteinGrams, 9999);
      expect(base.copyWith(fatGrams: 9999).fatGrams, 9999);
      expect(base.copyWith(fiberGrams: 9999).fiberGrams, 9999);
      expect(base.copyWith(sugarGrams: 9999).sugarGrams, 9999);
      expect(base.copyWith(sodiumMilligrams: 9999).sodiumMilligrams, 9999);
    });

    test('sibling fields are not mutated when one field is overridden', () {
      final base = _nutrition(calories: 400, carbs: 60);
      final updated = base.copyWith(calories: 500);
      expect(updated.carbohydratesGrams, 60,
          reason: 'carbs must not change when only calories is overridden');
    });
  });

  group('RecipeNutrition.toString', () {
    test('includes calories and carb grams', () {
      final s = _nutrition(calories: 400, carbs: 60).toString();
      expect(s, contains('400'));
      expect(s, contains('60'));
    });
  });

  // =========================================================================
  // Recipe
  // =========================================================================

  group('Recipe — construction', () {
    test('stores all required and optional fields', () {
      final r = _recipe(
        id: 'r1',
        name: 'Test Recipe',
        type: RecipeType.snacks,
        imageUrl: 'https://example.com/img.jpg',
        tags: ['high-carb', 'vegan'],
        isFavorite: true,
        createdAt: DateTime(2025, 3, 1),
        updatedAt: DateTime(2025, 6, 15),
      );

      expect(r.id, 'r1');
      expect(r.name, 'Test Recipe');
      expect(r.type, RecipeType.snacks);
      expect(r.imageUrl, 'https://example.com/img.jpg');
      expect(r.tags, ['high-carb', 'vegan']);
      expect(r.isFavorite, isTrue);
      expect(r.prepTimeMinutes, 5);
      expect(r.servings, 2);
    });

    test('optional imageUrl defaults to null', () {
      final r = _recipe(imageUrl: null);
      expect(r.imageUrl, isNull);
    });

    test('optional tags defaults to null', () {
      final r = _recipe(tags: null);
      expect(r.tags, isNull);
    });

    test('isFavorite defaults to false', () {
      final r = _recipe();
      expect(r.isFavorite, isFalse);
    });
  });

  group('Recipe.fromJson / toJson', () {
    test('round-trips without data loss', () {
      final original = _recipe(
        id: 'r1',
        name: 'Oats',
        type: RecipeType.breakfast,
        imageUrl: 'https://example.com/img.jpg',
        tags: ['easy', 'quick'],
        isFavorite: true,
        createdAt: DateTime(2025, 1, 1, 0, 0, 0),
        updatedAt: DateTime(2025, 6, 1, 0, 0, 0),
      );

      final json = original.toJson();
      final restored = Recipe.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.description, original.description);
      expect(restored.ingredients, original.ingredients);
      expect(restored.instructions, original.instructions);
      expect(restored.prepTimeMinutes, original.prepTimeMinutes);
      expect(restored.servings, original.servings);
      expect(restored.type, original.type);
      expect(restored.imageUrl, original.imageUrl);
      expect(restored.tags, original.tags);
      expect(restored.isFavorite, original.isFavorite);
      expect(restored.createdAt?.toIso8601String(),
          original.createdAt?.toIso8601String());
      expect(restored.updatedAt?.toIso8601String(),
          original.updatedAt?.toIso8601String());
    });

    test('workoutFuel type survives round-trip with underscore wire value', () {
      final r = _recipe(type: RecipeType.workoutFuel);
      final json = r.toJson();
      expect(json['type'], 'workout_fuel');
      final restored = Recipe.fromJson(json);
      expect(restored.type, RecipeType.workoutFuel);
    });

    test('unknown type wire value in JSON → mains fallback', () {
      final json = _recipe().toJson();
      json['type'] = 'legacy_general'; // old wire value
      final r = Recipe.fromJson(json);
      expect(r.type, RecipeType.mains,
          reason: 'unknown type should fall back to mains');
    });

    test('null tags in JSON → null tags in model', () {
      final json = _recipe(tags: null).toJson();
      expect(json['tags'], isNull);
      final r = Recipe.fromJson(json);
      expect(r.tags, isNull);
    });

    test('null imageUrl in JSON → null imageUrl in model', () {
      final json = _recipe(imageUrl: null).toJson();
      expect(json['imageUrl'], isNull);
      final r = Recipe.fromJson(json);
      expect(r.imageUrl, isNull);
    });

    test('null createdAt/updatedAt in JSON → null in model', () {
      final json = _recipe().toJson();
      json['createdAt'] = null;
      json['updatedAt'] = null;
      final r = Recipe.fromJson(json);
      expect(r.createdAt, isNull);
      expect(r.updatedAt, isNull);
    });

    test('missing isFavorite in JSON defaults to false', () {
      final json = _recipe(isFavorite: true).toJson();
      json.remove('isFavorite');
      final r = Recipe.fromJson(json);
      expect(r.isFavorite, isFalse);
    });

    test('ingredient and instruction lists survive round-trip', () {
      final json = _recipe().toJson();
      final r = Recipe.fromJson(json);
      expect(r.ingredients.length, 3);
      expect(r.instructions.length, 2);
      expect(r.ingredients.first, '1 cup rolled oats');
    });
  });

  group('Recipe.copyWith', () {
    test('no-op copy preserves all values', () {
      final original = _recipe(
        tags: ['easy'],
        imageUrl: 'https://img.com/img.jpg',
        isFavorite: true,
      );
      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.name, original.name);
      expect(copy.description, original.description);
      expect(copy.ingredients, original.ingredients);
      expect(copy.instructions, original.instructions);
      expect(copy.prepTimeMinutes, original.prepTimeMinutes);
      expect(copy.servings, original.servings);
      expect(copy.type, original.type);
      expect(copy.imageUrl, original.imageUrl);
      expect(copy.tags, original.tags);
      expect(copy.isFavorite, original.isFavorite);
      expect(copy.createdAt, original.createdAt);
      expect(copy.updatedAt, original.updatedAt);
    });

    test('can toggle isFavorite without touching other fields', () {
      final original = _recipe(isFavorite: false);
      final favorited = original.copyWith(isFavorite: true);

      expect(favorited.isFavorite, isTrue);
      expect(favorited.id, original.id,
          reason: 'id must not change');
      expect(favorited.name, original.name);
    });

    // BUG HUNT: all 14 copyWith params must appear in the constructor call.
    test('every field can be independently overridden', () {
      final base = _recipe();
      final newNutrition = _nutrition(calories: 9999);

      expect(base.copyWith(id: 'new-id').id, 'new-id');
      expect(base.copyWith(name: 'New').name, 'New');
      expect(base.copyWith(description: 'Desc').description, 'Desc');
      expect(base.copyWith(ingredients: ['a']).ingredients, ['a']);
      expect(base.copyWith(instructions: ['b']).instructions, ['b']);
      expect(base.copyWith(prepTimeMinutes: 99).prepTimeMinutes, 99);
      expect(base.copyWith(servings: 10).servings, 10);
      expect(base.copyWith(type: RecipeType.recovery).type, RecipeType.recovery);
      expect(base.copyWith(nutrition: newNutrition).nutrition.calories, 9999);
      expect(base.copyWith(imageUrl: 'u').imageUrl, 'u');
      expect(base.copyWith(tags: ['x']).tags, ['x']);
      expect(base.copyWith(isFavorite: true).isFavorite, isTrue);
      expect(
          base.copyWith(createdAt: DateTime(2099, 1, 1)).createdAt?.year, 2099);
      expect(
          base.copyWith(updatedAt: DateTime(2099, 12, 31)).updatedAt?.year, 2099);
    });
  });

  group('Recipe.toString', () {
    test('includes id, name, and type', () {
      final s = _recipe(id: 'r1', name: 'Oats', type: RecipeType.breakfast)
          .toString();
      expect(s, contains('r1'));
      expect(s, contains('Oats'));
      expect(s, contains('breakfast'));
    });
  });
}
