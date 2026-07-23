import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/barcode_scanning/application/catalog_search_service.dart';

void main() {
  group('CatalogSearchResult.displayName', () {
    test('returns "title — variantTitle" when both are present', () {
      final result = CatalogSearchResult(
        id: 'test-id',
        title: "Clif Builder's Protein Bar",
        variantTitle: 'Oreo / Box of 12',
        brand: 'Clif Bar',
        caloriesPerServing: 270,
      );

      expect(
        result.displayName,
        "Clif Builder's Protein Bar — Oreo / Box of 12",
      );
    });

    test('returns just title when variantTitle is null', () {
      final result = CatalogSearchResult(
        id: 'test-id',
        title: "Clif Builder's Protein Bar",
        brand: 'Clif Bar',
        caloriesPerServing: 270,
      );

      expect(result.displayName, "Clif Builder's Protein Bar");
    });

    test('returns just title when variantTitle is empty', () {
      final result = CatalogSearchResult(
        id: 'test-id',
        title: "Clif Builder's Protein Bar",
        variantTitle: '',
        brand: 'Clif Bar',
        caloriesPerServing: 270,
      );

      expect(result.displayName, "Clif Builder's Protein Bar");
    });

    test(
      'displayName never leads with the variant for a product with variant',
      () {
        final result = CatalogSearchResult(
          id: 'test-id',
          title: 'Huma Chia Energy Gel',
          variantTitle: 'Apples and Cinnamon',
          brand: 'Huma',
          caloriesPerServing: 100,
        );

        expect(result.displayName, startsWith('Huma Chia Energy Gel'));
        expect(result.displayName, isNot(startsWith('Apples and Cinnamon')));
      },
    );
  });

  group('CatalogSearchResult.brandedTitle', () {
    test('prepends brand when title lacks it', () {
      final result = CatalogSearchResult(
        id: 'test-id',
        title: "Builder's Protein Bar",
        variantTitle: 'Oreo / Box of 12',
        brand: 'Clif',
        caloriesPerServing: 270,
      );

      expect(result.brandedTitle, "Clif Builder's Protein Bar");
    });

    test('does not duplicate a brand already in the title', () {
      final result = CatalogSearchResult(
        id: 'test-id',
        title: 'Clif Bar Chocolate Chip',
        brand: 'Clif Bar',
        caloriesPerServing: 250,
      );

      expect(result.brandedTitle, 'Clif Bar Chocolate Chip');
    });

    test('brand match is case-insensitive', () {
      final result = CatalogSearchResult(
        id: 'test-id',
        title: 'CLIF Bar Chocolate Chip',
        brand: 'Clif',
        caloriesPerServing: 250,
      );

      expect(result.brandedTitle, 'CLIF Bar Chocolate Chip');
    });

    test('falls back to title when brand is null or empty', () {
      final noBrand = CatalogSearchResult(
        id: 'test-id',
        title: 'Generic Energy Gel',
        caloriesPerServing: 100,
      );
      final emptyBrand = CatalogSearchResult(
        id: 'test-id',
        title: 'Generic Energy Gel',
        brand: '',
        caloriesPerServing: 100,
      );

      expect(noBrand.brandedTitle, 'Generic Energy Gel');
      expect(emptyBrand.brandedTitle, 'Generic Energy Gel');
    });

    test('never surfaces the variant in the title line', () {
      final result = CatalogSearchResult(
        id: 'test-id',
        title: "Builder's Protein Bar",
        variantTitle: 'Oreo / Box of 12',
        brand: 'Clif',
        caloriesPerServing: 270,
      );

      expect(result.brandedTitle, isNot(contains('Oreo')));
    });
  });
}
