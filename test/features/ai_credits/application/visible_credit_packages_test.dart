/// Unit tests for [visibleCreditPackagesProvider] — the single place that
/// decides which credit packs a build may display.
///
/// The rule under test: tester-only SKUs ([kTesterOnlyProductIds], i.e. the
/// $0.99 pipeline-test pack) are visible on dev builds and on devices flagged
/// internal via the 7-tap tester reveal — and NEVER to a regular production
/// user. The regular 50/250 packs are visible everywhere.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:mealvana_endurance/features/ai_credits/application/purchase_controller.dart';
import 'package:mealvana_endurance/features/ai_credits/data/revenuecat_service.dart';
import 'package:mealvana_endurance/shared/services/analytics/internal_user_service.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

class _MockRevenueCatService extends Mock implements RevenueCatService {}

class _FakeStoreProduct extends Fake implements StoreProduct {
  _FakeStoreProduct(this.identifier);

  @override
  final String identifier;
}

class _FakePackage extends Fake implements Package {
  _FakePackage(String sku) : storeProduct = _FakeStoreProduct(sku);

  @override
  final StoreProduct storeProduct;
}

class _FakeOffering extends Fake implements Offering {
  _FakeOffering(this.availablePackages);

  @override
  final List<Package> availablePackages;
}

class _FakeOfferings extends Fake implements Offerings {
  _FakeOfferings(this._credits);

  final Offering _credits;

  @override
  Offering? getOffering(String identifier) =>
      identifier == 'credits' ? _credits : null;
}

/// Pins the internal-device flag without touching the keychain-backed
/// singleton.
class _FixedFlag extends InternalDeviceFlagNotifier {
  _FixedFlag(this._value);

  final bool _value;

  @override
  bool build() => _value;
}

void main() {
  const allSkus = [
    'mealvana_credits_50',
    'mealvana_credits_250',
    'mealvana_credits_test_1',
    'mealvana_credits_test_1_prod',
  ];

  ProviderContainer buildContainer({
    required String appEnvironment,
    required bool devModeEnabled,
    required bool internalDevice,
    List<String> skus = allSkus,
  }) {
    final rc = _MockRevenueCatService();
    when(() => rc.getOfferings()).thenAnswer(
      (_) async => _FakeOfferings(
        _FakeOffering([for (final sku in skus) _FakePackage(sku)]),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        revenueCatServiceProvider.overrideWithValue(rc),
        appConfigProvider.overrideWithValue(
          AppConfig.forTesting(
            appEnvironment: appEnvironment,
            devModeEnabled: devModeEnabled,
          ),
        ),
        internalDeviceFlagProvider.overrideWith(
          () => _FixedFlag(internalDevice),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<List<String>> visibleSkus(ProviderContainer c) async {
    final packages = await c.read(visibleCreditPackagesProvider.future);
    return packages.map((p) => p.storeProduct.identifier).toList();
  }

  test('dev build → tester pack visible', () async {
    final c = buildContainer(
      appEnvironment: 'dev',
      devModeEnabled: true,
      internalDevice: false,
    );
    expect(await visibleSkus(c), allSkus);
  });

  test('production build, regular device → tester pack hidden, '
      'regular packs untouched', () async {
    final c = buildContainer(
      appEnvironment: 'prod',
      devModeEnabled: false,
      internalDevice: false,
    );
    expect(await visibleSkus(c), [
      'mealvana_credits_50',
      'mealvana_credits_250',
    ]);
  });

  test(
    'production build, 7-tap internal device → tester pack visible '
    '(this is what enables the real-money \$0.99 test after release)',
    () async {
      final c = buildContainer(
        appEnvironment: 'prod',
        devModeEnabled: false,
        internalDevice: true,
      );
      expect(await visibleSkus(c), allSkus);
    },
  );

  test('no credits offering → empty list, no throw', () async {
    final rc = _MockRevenueCatService();
    when(() => rc.getOfferings()).thenAnswer((_) async => null);
    final container = ProviderContainer(
      overrides: [
        revenueCatServiceProvider.overrideWithValue(rc),
        appConfigProvider.overrideWithValue(AppConfig.forTesting()),
        internalDeviceFlagProvider.overrideWith(() => _FixedFlag(false)),
      ],
    );
    addTearDown(container.dispose);
    expect(await visibleSkus(container), isEmpty);
  });
}
