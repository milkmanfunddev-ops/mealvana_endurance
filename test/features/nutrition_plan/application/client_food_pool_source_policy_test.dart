// Food-source policy (2026-07-29) for the CLIENT fallback solver.
//
// The client plan service is the fallback that runs when the V3 edge function
// call fails. It used to load `user_foods` into the pool and score them ABOVE
// everything else (kPrefScoreUserFood = 300), which meant an offline plan could
// be built almost entirely out of barcode-scanned branded groceries.
//
// Policy: plan generation draws foods ONLY from the curated `template_foods`
// catalog. The single legitimate user-originating source is a pinned personal
// formula, which is self-contained (components carry their own macros and never
// read this pool).
//
// These tests pin:
//   1. the branded/unclassified `product_type` gate, and
//   2. the absence of any `user_foods` load from ClientFoodPoolService — checked
//      statically against the source, because exercising the real pool needs the
//      full Drift + Riverpod stack and would not catch a re-added query that
//      happens to return nothing in the test fixture.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/client_plan/client_food_pool_service.dart';

void main() {
  group('isClassifiedProductType', () {
    test('accepts a real classified product type', () {
      expect(
        ClientFoodPoolService.isClassifiedProductType('real_food'),
        isTrue,
      );
      expect(ClientFoodPoolService.isClassifiedProductType('gel'), isTrue);
      expect(ClientFoodPoolService.isClassifiedProductType('beverage'), isTrue);
    });

    test('rejects null, empty and whitespace-only', () {
      expect(ClientFoodPoolService.isClassifiedProductType(null), isFalse);
      expect(ClientFoodPoolService.isClassifiedProductType(''), isFalse);
      expect(ClientFoodPoolService.isClassifiedProductType('   '), isFalse);
    });

    test('rejects imported/branded scanned items, case-insensitively', () {
      expect(ClientFoodPoolService.isClassifiedProductType('import'), isFalse);
      expect(ClientFoodPoolService.isClassifiedProductType('IMPORT'), isFalse);
      expect(
        ClientFoodPoolService.isClassifiedProductType('  import  '),
        isFalse,
      );
    });
  });

  group('ClientFoodPoolService source policy', () {
    late String source;

    setUpAll(() {
      source = File(
        'lib/features/nutrition_plan/application/client_plan/'
        'client_food_pool_service.dart',
      ).readAsStringSync();
    });

    test('does not load user foods into the pool', () {
      expect(
        source.contains('getUserFoods'),
        isFalse,
        reason:
            'user_foods must not be a plan-generation food source — the only '
            'legitimate user-originating source is a pinned personal formula, '
            'which is self-contained and never reads this pool.',
      );
    });

    test('does not score anything with the retired user-food score', () {
      expect(
        source.contains('kPrefScoreUserFood'),
        isFalse,
        reason:
            'the client fallback used to score user foods above every curated '
            'food; nothing in the pool may carry that score again.',
      );
    });

    test('does not construct SolverFood from a user food', () {
      expect(
        source.contains('SolverFood.fromUserFood'),
        isFalse,
        reason: 'a user food must never become a solver pool member.',
      );
    });
  });
}
