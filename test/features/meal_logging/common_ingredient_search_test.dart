import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/common_ingredients.dart';
import 'package:mealvana_endurance/shared/utils/search_token_matcher.dart';

/// Audit repro (2026-07-15 food-DB audit): client-side quick-match filtering
/// must be token-based, not whole-phrase substring — "breast chicken" found
/// nothing while "chicken breast" worked. Mirrors the exact filter expression
/// `UnifiedMealSearchResults` applies to [kCommonIngredients].
List<String> _matchingIngredientNames(String query) {
  final tokens = tokenizeSearchQuery(query);
  return kCommonIngredients
      .where((i) => matchesSearchTokens(i.name, tokens))
      .map((i) => i.name)
      .toList();
}

void main() {
  group('common-ingredient quick-match filtering', () {
    test('"breast chicken" finds the Chicken breast ingredient', () {
      expect(
        _matchingIngredientNames('breast chicken'),
        contains('Chicken breast'),
      );
    });

    test('"chicken breast" still finds the Chicken breast ingredient', () {
      expect(
        _matchingIngredientNames('chicken breast'),
        contains('Chicken breast'),
      );
    });

    test('multi-token queries are order-insensitive', () {
      expect(
        _matchingIngredientNames('breast chicken'),
        _matchingIngredientNames('chicken breast'),
      );
    });

    test('single-token behaviour unchanged', () {
      expect(_matchingIngredientNames('chicken'), contains('Chicken breast'));
    });

    test('all tokens must match — no partial-token false positives', () {
      expect(
        _matchingIngredientNames('chicken asphalt'),
        isNot(contains('Chicken breast')),
      );
    });
  });
}
