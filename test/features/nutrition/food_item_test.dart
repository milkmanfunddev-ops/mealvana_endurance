/// Unit tests for [FoodItem] domain model.
///
/// Covers: JSON round-trip, camelCase and snake_case key aliases, field
/// parsing (int/double/string coercion), copyWith completeness, imageUrl
/// resolution, and equality / hashCode.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition/domain/food_item.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

FoodItem _fullItem({
  String id = 'food-001',
  String name = 'Banana',
  String quantity = '1 medium',
}) {
  return FoodItem(
    id: id,
    name: name,
    quantity: quantity,
    displayName: 'medium banana',
    displayNamePlural: 'medium bananas',
    imageAddress: 'banana.jpg',
    description: 'A ripe banana.',
    timing: '30-60 min pre-run',
    instructions: 'Peel and eat.',
    servingSize: '1 medium (118g)',
    calories: 105,
    carbsGrams: 27.0,
    proteinGrams: 1.3,
    fatGrams: 0.4,
    sodiumMg: 1,
    fluidsMl: 88.0,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FoodItem — construction', () {
    test('minimal required fields only', () {
      const item = FoodItem(id: 'x', name: 'Water', quantity: '500ml');
      expect(item.id, 'x');
      expect(item.name, 'Water');
      expect(item.quantity, '500ml');
      // All optional fields default to null.
      expect(item.calories, isNull);
      expect(item.carbsGrams, isNull);
      expect(item.proteinGrams, isNull);
      expect(item.fatGrams, isNull);
      expect(item.sodiumMg, isNull);
      expect(item.fluidsMl, isNull);
      expect(item.displayName, isNull);
      expect(item.imageAddress, isNull);
    });

    test('fully-populated item stores all values correctly', () {
      final item = _fullItem();
      expect(item.calories, 105);
      expect(item.carbsGrams, 27.0);
      expect(item.proteinGrams, 1.3);
      expect(item.fatGrams, 0.4);
      expect(item.sodiumMg, 1);
      expect(item.fluidsMl, 88.0);
      expect(item.timing, '30-60 min pre-run');
      expect(item.servingSize, '1 medium (118g)');
    });
  });

  // -------------------------------------------------------------------------
  // JSON round-trip (camelCase canonical keys)
  // -------------------------------------------------------------------------

  group('FoodItem.fromJson — camelCase keys', () {
    test('round-trips via toJson/fromJson without data loss', () {
      final original = _fullItem();
      final json = original.toJson();
      final restored = FoodItem.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.quantity, original.quantity);
      expect(restored.displayName, original.displayName);
      expect(restored.displayNamePlural, original.displayNamePlural);
      expect(restored.imageAddress, original.imageAddress);
      expect(restored.description, original.description);
      expect(restored.timing, original.timing);
      expect(restored.instructions, original.instructions);
      expect(restored.servingSize, original.servingSize);
      expect(restored.calories, original.calories);
      expect(restored.carbsGrams, original.carbsGrams);
      expect(restored.proteinGrams, original.proteinGrams);
      expect(restored.fatGrams, original.fatGrams);
      expect(restored.sodiumMg, original.sodiumMg);
      expect(restored.fluidsMl, original.fluidsMl);
    });

    test('toJson uses camelCase keys', () {
      final json = _fullItem().toJson();
      expect(json.containsKey('carbsGrams'), isTrue,
          reason: 'toJson should use carbsGrams, not carbs_grams');
      expect(json.containsKey('proteinGrams'), isTrue);
      expect(json.containsKey('fatGrams'), isTrue);
      expect(json.containsKey('sodiumMg'), isTrue);
      expect(json.containsKey('fluidsMl'), isTrue);
      expect(json.containsKey('displayName'), isTrue);
      expect(json.containsKey('displayNamePlural'), isTrue);
      expect(json.containsKey('imageAddress'), isTrue);
      expect(json.containsKey('servingSize'), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // JSON parsing — snake_case alias support (edge function payload format)
  // -------------------------------------------------------------------------

  group('FoodItem.fromJson — snake_case aliases', () {
    test('parses snake_case macro keys', () {
      final item = FoodItem.fromJson({
        'food_id': 'food-002',
        'food_name': 'Oats',
        'quantity': '100g',
        'carbs_grams': 66.0,
        'protein_grams': 13.0,
        'fat_grams': 7.0,
        'sodium_mg': 2,
        'fluids_ml': 0.0,
        'display_name': 'rolled oats',
        'display_name_plural': 'rolled oats',
        'image_address': 'oats.jpg',
        'serving_size': '100g',
      });

      expect(item.id, 'food-002');
      expect(item.name, 'Oats');
      expect(item.carbsGrams, 66.0);
      expect(item.proteinGrams, 13.0);
      expect(item.fatGrams, 7.0);
      expect(item.sodiumMg, 2);
      expect(item.fluidsMl, 0.0);
      expect(item.displayName, 'rolled oats');
      expect(item.imageAddress, 'oats.jpg');
      expect(item.servingSize, '100g');
    });

    test('short aliases (carbs / protein / fat / sodium / fluids) are accepted',
        () {
      final item = FoodItem.fromJson({
        'id': 'food-003',
        'name': 'Gel',
        'quantity': '1 pack',
        'carbs': 22.0,
        'protein': 0.0,
        'fat': 0.0,
        'sodium': 200,
        'fluids': 0.0,
      });

      expect(item.carbsGrams, 22.0);
      expect(item.proteinGrams, 0.0);
      expect(item.sodiumMg, 200);
    });

    test('camelCase takes precedence over snake_case when both present', () {
      // camelCase key should win; snake_case is a fallback.
      final item = FoodItem.fromJson({
        'id': 'food-004',
        'name': 'Gel',
        'quantity': '1',
        'carbsGrams': 30.0,
        'carbs_grams': 99.0, // should NOT be used
        'proteinGrams': 5.0,
        'protein_grams': 99.0,
      });

      expect(item.carbsGrams, 30.0,
          reason: 'camelCase should win over snake_case');
      expect(item.proteinGrams, 5.0);
    });

    test('missing optional fields parse as null, not error', () {
      final item = FoodItem.fromJson({
        'id': 'food-005',
        'name': 'Water',
        'quantity': '1 bottle',
      });

      expect(item.calories, isNull);
      expect(item.carbsGrams, isNull);
      expect(item.imageAddress, isNull);
      expect(item.timing, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Numeric type coercion in _parseIntOrNull / _parseDoubleOrNull
  // -------------------------------------------------------------------------

  group('FoodItem.fromJson — numeric type coercion', () {
    test('calories: int literal → int', () {
      final item = FoodItem.fromJson(
          {'id': 'x', 'name': 'x', 'quantity': '1', 'calories': 200});
      expect(item.calories, 200);
    });

    test('calories: double literal → int (truncate)', () {
      final item = FoodItem.fromJson(
          {'id': 'x', 'name': 'x', 'quantity': '1', 'calories': 200.9});
      // _parseIntOrNull(double) calls toInt() = 200
      expect(item.calories, 200);
    });

    test('calories: string literal → int parse', () {
      final item = FoodItem.fromJson(
          {'id': 'x', 'name': 'x', 'quantity': '1', 'calories': '150'});
      expect(item.calories, 150);
    });

    test('carbsGrams: int literal → double', () {
      final item = FoodItem.fromJson(
          {'id': 'x', 'name': 'x', 'quantity': '1', 'carbsGrams': 27});
      expect(item.carbsGrams, 27.0);
    });

    test('carbsGrams: string literal → double parse', () {
      final item = FoodItem.fromJson(
          {'id': 'x', 'name': 'x', 'quantity': '1', 'carbsGrams': '13.5'});
      expect(item.carbsGrams, 13.5);
    });

    test('invalid string for calories → null (no crash)', () {
      final item = FoodItem.fromJson(
          {'id': 'x', 'name': 'x', 'quantity': '1', 'calories': 'not-a-num'});
      expect(item.calories, isNull);
    });

    test('quantity is coerced to string via toString()', () {
      // Edge function sometimes sends quantity as a number.
      final item =
          FoodItem.fromJson({'id': 'x', 'name': 'x', 'quantity': 2});
      expect(item.quantity, '2');
    });
  });

  // -------------------------------------------------------------------------
  // imageUrl computed getter
  // -------------------------------------------------------------------------

  group('FoodItem.imageUrl', () {
    test('null imageAddress → null imageUrl', () {
      const item = FoodItem(id: 'x', name: 'x', quantity: '1');
      expect(item.imageUrl, isNull);
    });

    test('empty string imageAddress → null imageUrl', () {
      const item =
          FoodItem(id: 'x', name: 'x', quantity: '1', imageAddress: '');
      expect(item.imageUrl, isNull);
    });

    test('full Open Food Facts URL passes through unchanged', () {
      const item = FoodItem(
        id: 'x',
        name: 'x',
        quantity: '1',
        imageAddress:
            'https://images.openfoodfacts.org/images/products/001.jpg',
      );
      expect(item.imageUrl,
          'https://images.openfoodfacts.org/images/products/001.jpg');
    });

    test('static openfoodfacts URL passes through unchanged', () {
      const item = FoodItem(
        id: 'x',
        name: 'x',
        quantity: '1',
        imageAddress:
            'https://static.openfoodfacts.org/images/products/002.jpg',
      );
      expect(item.imageUrl,
          'https://static.openfoodfacts.org/images/products/002.jpg');
    });

    test('bare filename is prefixed with S3 bucket URL', () {
      const item = FoodItem(
          id: 'x', name: 'x', quantity: '1', imageAddress: 'banana.jpg');
      expect(item.imageUrl,
          'https://milkman-dev.s3.us-east-2.amazonaws.com/foods/banana.jpg');
    });

    test('S3 URL prefix is not doubled for an already-S3 filename', () {
      // A hypothetical bug: if someone stored a full S3 URL, it should pass
      // through unchanged (starts with 'https://').
      const fullS3 =
          'https://milkman-dev.s3.us-east-2.amazonaws.com/foods/banana.jpg';
      const item =
          FoodItem(id: 'x', name: 'x', quantity: '1', imageAddress: fullS3);
      // The getter checks startsWith('https://openfoodfacts') first, then
      // falls through to the else branch for other https:// URLs — this test
      // guards against a future regression where non-OFF https URLs get
      // prefixed again.
      expect(item.imageUrl, isNotNull);
      expect(item.imageUrl, startsWith('https://'));
    });
  });

  // -------------------------------------------------------------------------
  // copyWith
  // -------------------------------------------------------------------------

  group('FoodItem.copyWith', () {
    test('returns identical values when nothing overridden', () {
      final original = _fullItem();
      final copy = original.copyWith();

      // Every field must match.
      expect(copy.id, original.id);
      expect(copy.name, original.name);
      expect(copy.quantity, original.quantity);
      expect(copy.displayName, original.displayName);
      expect(copy.displayNamePlural, original.displayNamePlural);
      expect(copy.imageAddress, original.imageAddress);
      expect(copy.description, original.description);
      expect(copy.timing, original.timing);
      expect(copy.instructions, original.instructions);
      expect(copy.servingSize, original.servingSize);
      expect(copy.calories, original.calories);
      expect(copy.carbsGrams, original.carbsGrams);
      expect(copy.proteinGrams, original.proteinGrams);
      expect(copy.fatGrams, original.fatGrams);
      expect(copy.sodiumMg, original.sodiumMg);
      expect(copy.fluidsMl, original.fluidsMl);
    });

    test('overrides only the specified field', () {
      final original = _fullItem();
      final copy = original.copyWith(calories: 999);

      expect(copy.calories, 999);
      // Sibling fields must be unchanged.
      expect(copy.carbsGrams, original.carbsGrams);
      expect(copy.name, original.name);
    });

    test('can override to a null-compatible value for numeric fields', () {
      // copyWith takes nullable params; supplying explicit non-null is fine.
      final item = _fullItem();
      final copy = item.copyWith(sodiumMg: 0);
      expect(copy.sodiumMg, 0);
      expect(copy.calories, item.calories, reason: 'calories must not change');
    });

    // BUG HUNT: copyWith should not silently drop fields.
    // If a field is missing from the copyWith body it will always use `this`,
    // hiding a caller's intended override.
    test('copyWith can update every field independently', () {
      final base = _fullItem();

      final updates = <String, Object?>{
        'id': 'new-id',
        'name': 'New Name',
        'quantity': '2 cups',
        'displayName': 'new display',
        'displayNamePlural': 'new plurals',
        'imageAddress': 'new.jpg',
        'description': 'new desc',
        'timing': 'during',
        'instructions': 'new instr',
        'servingSize': '2 cups (240g)',
        'calories': 200,
        'carbsGrams': 50.0,
        'proteinGrams': 5.0,
        'fatGrams': 2.0,
        'sodiumMg': 10,
        'fluidsMl': 200.0,
      };

      expect(base.copyWith(id: 'new-id').id, 'new-id',
          reason: 'id update');
      expect(base.copyWith(name: 'New Name').name, 'New Name',
          reason: 'name update');
      expect(base.copyWith(quantity: '2 cups').quantity, '2 cups',
          reason: 'quantity update');
      expect(base.copyWith(displayName: 'new display').displayName,
          'new display',
          reason: 'displayName update');
      expect(
          base.copyWith(displayNamePlural: 'new plurals').displayNamePlural,
          'new plurals',
          reason: 'displayNamePlural update');
      expect(base.copyWith(imageAddress: 'new.jpg').imageAddress, 'new.jpg',
          reason: 'imageAddress update');
      expect(
          base.copyWith(description: 'new desc').description, 'new desc',
          reason: 'description update');
      expect(base.copyWith(timing: 'during').timing, 'during',
          reason: 'timing update');
      expect(
          base.copyWith(instructions: 'new instr').instructions, 'new instr',
          reason: 'instructions update');
      expect(base.copyWith(servingSize: '2 cups (240g)').servingSize,
          '2 cups (240g)',
          reason: 'servingSize update');
      expect(base.copyWith(calories: 200).calories, 200,
          reason: 'calories update');
      expect(base.copyWith(carbsGrams: 50.0).carbsGrams, 50.0,
          reason: 'carbsGrams update');
      expect(base.copyWith(proteinGrams: 5.0).proteinGrams, 5.0,
          reason: 'proteinGrams update');
      expect(base.copyWith(fatGrams: 2.0).fatGrams, 2.0,
          reason: 'fatGrams update');
      expect(base.copyWith(sodiumMg: 10).sodiumMg, 10,
          reason: 'sodiumMg update');
      expect(base.copyWith(fluidsMl: 200.0).fluidsMl, 200.0,
          reason: 'fluidsMl update');

      // Ensure the updates map was fully consumed (no typos in test params).
      expect(updates.length, 16, reason: 'all 16 fields covered');
    });
  });

  // -------------------------------------------------------------------------
  // Equality and hashCode
  // -------------------------------------------------------------------------

  group('FoodItem — equality and hashCode', () {
    test('two identically-constructed items are equal', () {
      final a = _fullItem();
      final b = _fullItem();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('items with different ids are not equal', () {
      expect(_fullItem(id: 'a'), isNot(equals(_fullItem(id: 'b'))));
    });

    test('items with different names are not equal', () {
      expect(_fullItem(name: 'A'), isNot(equals(_fullItem(name: 'B'))));
    });

    test('item is equal to itself (identity)', () {
      final item = _fullItem();
      expect(item, equals(item));
    });

    test('item is not equal to null', () {
      expect(_fullItem(), isNot(equals(null)));
    });
  });

  // -------------------------------------------------------------------------
  // toString
  // -------------------------------------------------------------------------

  group('FoodItem.toString', () {
    test('includes id, name, and quantity', () {
      final s = _fullItem(id: 'food-001', name: 'Banana', quantity: '1 medium')
          .toString();
      expect(s, contains('food-001'));
      expect(s, contains('Banana'));
      expect(s, contains('1 medium'));
    });
  });
}
