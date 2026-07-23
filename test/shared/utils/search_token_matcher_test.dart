import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/utils/search_token_matcher.dart';

void main() {
  group('tokenizeSearchQuery', () {
    test('splits on whitespace and lowercases', () {
      expect(tokenizeSearchQuery('Breast Chicken'), ['breast', 'chicken']);
    });

    test('strips punctuation', () {
      expect(tokenizeSearchQuery('apple (medium)'), ['apple', 'medium']);
    });

    test('collapses extra whitespace', () {
      expect(tokenizeSearchQuery('  whole   milk  '), ['whole', 'milk']);
    });

    test('returns empty list for blank input', () {
      expect(tokenizeSearchQuery('   '), isEmpty);
    });
  });

  group('matchesSearchTokens', () {
    test('reversed word order matches', () {
      final tokens = tokenizeSearchQuery('breast chicken');
      expect(matchesSearchTokens('Chicken breast', tokens), isTrue);
    });

    test('correct word order matches', () {
      final tokens = tokenizeSearchQuery('chicken breast');
      expect(matchesSearchTokens('Chicken breast', tokens), isTrue);
    });

    test('query with parenthesised target matches', () {
      final tokens = tokenizeSearchQuery('medium apple');
      expect(matchesSearchTokens('Apple (medium)', tokens), isTrue);
    });

    test('whole milk matches Milk (whole)', () {
      final tokens = tokenizeSearchQuery('whole milk');
      expect(matchesSearchTokens('Milk (whole)', tokens), isTrue);
    });

    test('single token matches partial name', () {
      final tokens = tokenizeSearchQuery('chicken');
      expect(matchesSearchTokens('Chicken breast', tokens), isTrue);
    });

    test('unrelated query does not match', () {
      final tokens = tokenizeSearchQuery('beef');
      expect(matchesSearchTokens('Chicken breast', tokens), isFalse);
    });

    test('trailing-s singular fallback matches', () {
      final tokens = tokenizeSearchQuery('chickens breast');
      expect(matchesSearchTokens('Chicken breast', tokens), isTrue);
    });

    test('empty tokens match everything', () {
      expect(matchesSearchTokens('Anything', []), isTrue);
    });

    test('all tokens must match', () {
      final tokens = tokenizeSearchQuery('chicken pork');
      expect(matchesSearchTokens('Chicken breast', tokens), isFalse);
    });
  });
}
