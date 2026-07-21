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
}
