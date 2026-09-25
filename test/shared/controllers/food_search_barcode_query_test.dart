/// Testing-wave 28-004 (ticket 98, part 1): typing a barcode number into the
/// food search returned "No foods found" even for a product already cached in
/// `nutrition_products`, because `search-catalog` matches names only.
///
/// An 8, 12, 13 or 14-digit query is a barcode: the controller routes it to
/// `lookup-product` (catalog → cache → USDA/OFF, the same cascade a scan
/// uses) and shows the hit as a "More Results" card, whose tap already
/// resolves by barcode.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/barcode_scanning/application/product_detail_service.dart';
import 'package:mealvana_endurance/features/barcode_scanning/domain/api_food_product.dart';
import 'package:mealvana_endurance/shared/controllers/food_search_controller.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/food_management/nutrition_product_search_service.dart';
import 'package:mealvana_endurance/shared/services/food_management/shared_food_search_service.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mealvana_endurance/shared/utils/search_token_matcher.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockAnalyticsTracker extends Mock implements AnalyticsTracker {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockSentryReporter extends Mock implements SentryReporter {}

class _MockAppLogger extends Mock implements AppLogger {}

class _MockSharedPreferences extends Mock implements SharedPreferences {}

class _MockSharedFoodSearchService extends Mock
    implements SharedFoodSearchService {}

class _MockProductDetailService extends Mock implements ProductDetailService {}

class _MockNutritionProductSearchService extends Mock
    implements NutritionProductSearchService {}

/// The row the run found cached on dev (TEXAS RICE, source usda_fdc), in the
/// shape `lookup-product` answers with.
const _texasRice = ApiFoodProduct(
  barcode: '00720579120045',
  productName: 'TEXAS RICE',
  brandName: 'Texas Best',
  servingSize: '45 g',
  servingGrams: 45,
  caloriesPerServing: 160,
  carbohydratesPerServing: 36,
  proteinPerServing: 3,
  fatPerServing: 0.5,
  sodiumMgPerServing: 0,
  nutritionDataPer: 'serving',
  apiSource: 'usda_fdc',
  confidenceScore: 0.8,
);

void main() {
  late _MockSharedFoodSearchService shared;
  late _MockProductDetailService detail;
  late _MockNutritionProductSearchService nutrition;
  late ProviderContainer container;
  late FoodSearchController controller;

  final provider = foodSearchControllerProvider('test');

  setUp(() {
    shared = _MockSharedFoodSearchService();
    detail = _MockProductDetailService();
    nutrition = _MockNutritionProductSearchService();
    when(() => shared.searchCatalog(any())).thenAnswer((_) async => []);
    when(
      () => nutrition.search(any(), limit: any(named: 'limit')),
    ).thenAnswer((_) async => []);

    container = ProviderContainer(
      overrides: [
        appExternalDepsProvider.overrideWithValue(
          AppExternalDeps(
            analytics: _MockAnalyticsTracker(),
            supabaseClient: _MockSupabaseClient(),
            sentry: _MockSentryReporter(),
            logger: _MockAppLogger(),
            sharedPreferences: _MockSharedPreferences(),
          ),
        ),
        sharedFoodSearchServiceProvider.overrideWithValue(shared),
        productDetailServiceProvider.overrideWithValue(detail),
        nutritionProductSearchServiceProvider.overrideWithValue(nutrition),
      ],
    );
    // Keep the autoDispose notifier alive for the test.
    container.listen(provider, (_, __) {});
    controller = container.read(provider.notifier);
  });

  tearDown(() => container.dispose());

  /// Let the 300 ms search debounce fire and the lookup settle.
  Future<void> settle() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await pumpEventQueue();
  }

  group('barcodeDigits', () {
    test('accepts 8, 12, 13 and 14 digits, with spaces or dashes', () {
      expect(barcodeDigits('00720579120045'), '00720579120045');
      expect(barcodeDigits('3017620422003'), '3017620422003');
      expect(barcodeDigits('012345678905'), '012345678905');
      expect(barcodeDigits('96385074'), '96385074');
      expect(barcodeDigits('0 072057 912004 5'), '00720579120045');
      expect(barcodeDigits('301762-0422003'), '3017620422003');
    });

    test('is null for names, short numbers and mixed text', () {
      expect(barcodeDigits('texas rice'), isNull);
      expect(barcodeDigits('1234567'), isNull);
      expect(barcodeDigits('123456789'), isNull);
      expect(barcodeDigits('123456789012345'), isNull);
      expect(barcodeDigits('rx 12345678'), isNull);
      expect(barcodeDigits(''), isNull);
    });
  });

  test('a cached barcode typed into search shows that product', () async {
    when(
      () => detail.getProductDetails(barcode: '00720579120045'),
    ).thenAnswer((_) async => _texasRice);

    controller.updateSearch('00720579120045');
    await settle();

    final state = container.read(provider);
    expect(state.isSearchingNutritionProducts, isFalse);
    expect(state.isSearchingCatalog, isFalse);
    final hit = state.nutritionProductResults.single;
    expect(hit.barcode, '00720579120045');
    expect(hit.productName, 'TEXAS RICE');
    expect(hit.brandName, 'Texas Best');
    expect(hit.carbsPerServing, 36);
    expect(hit.source, 'usda_fdc');
    expect(hit.hasValidId, isTrue);

    // A number is not a name: neither name search runs.
    verifyNever(() => shared.searchCatalog(any()));
    verifyNever(() => nutrition.search(any(), limit: any(named: 'limit')));
  });

  test(
    'a barcode nobody has leaves the list empty, without an error',
    () async {
      when(
        () => detail.getProductDetails(barcode: '3017620422003'),
      ).thenThrow(ProductDetailException('Product not found'));

      controller.updateSearch('3017620422003');
      await settle();

      final state = container.read(provider);
      expect(state.nutritionProductResults, isEmpty);
      expect(state.isSearchingNutritionProducts, isFalse);
      verifyNever(() => shared.searchCatalog(any()));
    },
  );

  test(
    'a hit from an older query is dropped once the query moved on',
    () async {
      final lookup = Completer<ApiFoodProduct?>();
      when(
        () => detail.getProductDetails(barcode: '00720579120045'),
      ).thenAnswer((_) => lookup.future);

      controller.updateSearch('00720579120045');
      await Future<void>.delayed(const Duration(milliseconds: 320));
      expect(container.read(provider).isSearchingNutritionProducts, isTrue);

      // The athlete keeps typing while the lookup is still out.
      controller.updateSearch('texas rice');
      lookup.complete(_texasRice);
      await settle();

      expect(container.read(provider).nutritionProductResults, isEmpty);
    },
  );

  test('a name still goes to the catalog search', () async {
    controller.updateSearch('texas rice');
    await settle();

    verify(() => shared.searchCatalog('texas rice')).called(1);
    verifyNever(() => detail.getProductDetails(barcode: any(named: 'barcode')));
  });
}
