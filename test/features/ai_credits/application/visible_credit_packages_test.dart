/// Unit tests for [visibleCreditPackagesProvider] — the single place that
/// decides which credit packs a build may display.
///
/// The rule under test (since 2026-08-10): tester-only SKUs
/// ([kTesterOnlyProductIds], i.e. the $0.99 pipeline-test pack) are visible
/// exactly when tester mode is ON (the 7-tap switch, which defaults on for
/// IS_INTERNAL/debug builds but can be toggled OFF anywhere — including dev
/// builds). The regular 50/250 packs are visible everywhere.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:mealvana_endurance/features/ai_credits/application/purchase_controller.dart';
import 'package:mealvana_endurance/features/ai_credits/data/revenuecat_service.dart';
import 'package:mealvana_endurance/shared/services/analytics/internal_user_service.dart';

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

/// Pins the tester-mode flag without touching the keychain-backed singleton.
class _FixedFlag extends InternalDeviceFlagNotifier {
  _FixedFlag(this._value);

  final bool _value;

  @override
  bool build() => _value;
}

/// A live (non-fixed) flag seeded off, so a test can flip it at runtime and
/// assert the filter actually follows the toggle — the regression the
/// original fixed-only tests could never catch.
class _ToggleableFlag extends InternalDeviceFlagNotifier {
  @override
  bool build() => false;

  @override
  Future<void> setInternal(bool value) async {
    state = value;
  }
}

void main() {
  const allSkus = [
    'mealvana_credits_50',
    'mealvana_credits_250',
    'mealvana_credits_test_1',
    'mealvana_credits_test_1_prod',
  ];
  const regularSkus = ['mealvana_credits_50', 'mealvana_credits_250'];

  ProviderContainer buildContainer({
    InternalDeviceFlagNotifier Function()? flag,
    required bool testerMode,
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
        internalDeviceFlagProvider.overrideWith(
          flag ?? () => _FixedFlag(testerMode),
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

  test('tester mode ON → tester pack visible', () async {
    final c = buildContainer(testerMode: true);
    expect(await visibleSkus(c), allSkus);
  });

  test('tester mode OFF → tester pack hidden, regular packs untouched — '
      'even on dev builds (no isDevelopment short-circuit)', () async {
    final c = buildContainer(testerMode: false);
    expect(await visibleSkus(c), regularSkus);
  });

  test('toggling tester mode OFF at runtime hides the tester pack '
      '(the 7-tap toggle regression)', () async {
    final c = buildContainer(testerMode: false, flag: _ToggleableFlag.new);

    final flag = c.read(internalDeviceFlagProvider.notifier);
    await flag.setInternal(true);
    expect(await visibleSkus(c), allSkus);

    await flag.setInternal(false);
    expect(await visibleSkus(c), regularSkus);
  });

  test('no credits offering → empty list, no throw', () async {
    final rc = _MockRevenueCatService();
    when(() => rc.getOfferings()).thenAnswer((_) async => null);
    final container = ProviderContainer(
      overrides: [
        revenueCatServiceProvider.overrideWithValue(rc),
        internalDeviceFlagProvider.overrideWith(() => _FixedFlag(false)),
      ],
    );
    addTearDown(container.dispose);
    expect(await visibleSkus(container), isEmpty);
  });
}
