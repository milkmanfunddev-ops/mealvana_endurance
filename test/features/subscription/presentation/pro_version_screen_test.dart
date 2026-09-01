/// Widget tests for [ProVersionScreen] with a fake `default` offering.
///
/// Covers: real localised prices from `$rc_monthly` / `$rc_annual` render;
/// Buy is disabled unless `PRO_PURCHASE_ENABLED`; the active-status badge;
/// the unavailable state; Restore drives the controller and reports via
/// MealvanaSnackbar; and the smoke/overflow check that lived in
/// misc_smoke_test.dart before the screen moved into this feature.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:mealvana_endurance/features/subscription/application/pro_paywall_controller.dart';
import 'package:mealvana_endurance/features/subscription/application/subscription_status_provider.dart';
import 'package:mealvana_endurance/features/subscription/domain/entitlement.dart';
import 'package:mealvana_endurance/features/subscription/presentation/screens/pro_version_screen.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

import '../../../helpers/widget_test_harness.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeStoreProduct extends Fake implements StoreProduct {
  _FakeStoreProduct(this.identifier, this.priceString);
  @override
  final String identifier;
  @override
  final String priceString;
}

class _FakePackage extends Fake implements Package {
  _FakePackage(this.identifier, String sku, String price)
    : storeProduct = _FakeStoreProduct(sku, price);
  @override
  final String identifier;
  @override
  final StoreProduct storeProduct;
}

class _FakeOffering extends Fake implements Offering {
  _FakeOffering({this.monthly, this.annual});
  @override
  final String identifier = 'default';
  @override
  final Package? monthly;
  @override
  final Package? annual;
  @override
  Package? getPackage(String identifier) {
    if (identifier == r'$rc_monthly') return monthly;
    if (identifier == r'$rc_annual') return annual;
    return null;
  }
}

final _offering = _FakeOffering(
  monthly: _FakePackage(r'$rc_monthly', 'mealvana_pro_monthly', r'$9.99'),
  annual: _FakePackage(r'$rc_annual', 'mealvana_pro_annual', r'$69.99'),
);

class _FixedStatus extends SubscriptionStatusController {
  _FixedStatus(this.status);
  final SubscriptionStatus status;
  @override
  Future<SubscriptionStatus> build() async => status;
}

/// Records calls instead of touching the store.
class _RecordingPaywall extends ProPaywallController {
  _RecordingPaywall({this.restoreResult = true});
  final bool restoreResult;
  int restoreCalls = 0;
  final bought = <String>[];

  @override
  FutureOr<void> build() => null;

  @override
  Future<bool> restore() async {
    restoreCalls++;
    return restoreResult;
  }

  @override
  Future<ProPurchaseOutcome> buy(Package pkg) async {
    bought.add(pkg.storeProduct.identifier);
    return ProPurchaseOutcome.activated;
  }
}

List<Override> _overrides({
  SubscriptionStatus status = SubscriptionStatus.none,
  Offering? offering,
  bool offeringPresent = true,
  ProPaywallController Function()? paywall,
}) {
  return [
    subscriptionStatusProvider.overrideWith(() => _FixedStatus(status)),
    proOfferingProvider.overrideWith(
      (ref) async => offeringPresent ? (offering ?? _offering) : null,
    ),
    if (paywall != null) proPaywallControllerProvider.overrideWith(paywall),
  ];
}

void main() {
  testWidgets('renders without overflow (smoke)', (tester) async {
    await smokeScreen(tester, const ProVersionScreen(), overrides: _overrides());
  });

  testWidgets('shows the real localised monthly and annual prices', (
    tester,
  ) async {
    await smokeScreen(tester, const ProVersionScreen(), overrides: _overrides());

    expect(
      find.byKey(const ValueKey('pro_version.monthly_price')),
      findsOneWidget,
    );
    expect(find.text(r'$9.99 / month'), findsOneWidget);
    expect(find.text(r'$69.99 / year'), findsOneWidget);
  });

  testWidgets('Buy is disabled when PRO_PURCHASE_ENABLED is off', (
    tester,
  ) async {
    await smokeScreen(
      tester,
      const ProVersionScreen(),
      overrides: _overrides(),
      appConfig: AppConfig.forTesting(proPurchaseEnabled: false),
    );

    final button = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(const ValueKey('pro_version.subscribe_monthly')),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(
      find.byKey(const ValueKey('pro_version.purchase_coming_soon')),
      findsOneWidget,
    );
  });

  testWidgets('Buy is live when PRO_PURCHASE_ENABLED is on and calls buy()', (
    tester,
  ) async {
    final paywall = _RecordingPaywall();
    await smokeScreen(
      tester,
      const ProVersionScreen(),
      overrides: _overrides(paywall: () => paywall),
      appConfig: AppConfig.forTesting(proPurchaseEnabled: true),
    );

    expect(
      find.byKey(const ValueKey('pro_version.purchase_coming_soon')),
      findsNothing,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('pro_version.subscribe_annual')),
    );
    await tester.tap(find.byKey(const ValueKey('pro_version.subscribe_annual')));
    await tester.pumpAndSettle();

    expect(paywall.bought, ['mealvana_pro_annual']);
    expect(find.text('Welcome to Mealvana Pro!'), findsOneWidget);
  });

  testWidgets('active subscriber sees the Pro badge and no Buy', (
    tester,
  ) async {
    await smokeScreen(
      tester,
      const ProVersionScreen(),
      overrides: _overrides(
        status: SubscriptionStatus(
          active: true,
          source: SubscriptionSource.revenuecat,
          expiresAt: DateTime.utc(2026, 10, 1),
        ),
      ),
      appConfig: AppConfig.forTesting(proPurchaseEnabled: true),
    );

    expect(
      find.byKey(const ValueKey('pro_version.active_badge')),
      findsOneWidget,
    );
    expect(find.text("You're Pro"), findsOneWidget);
    final button = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(const ValueKey('pro_version.subscribe_monthly')),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('no offering → unavailable message, Restore still present', (
    tester,
  ) async {
    await smokeScreen(
      tester,
      const ProVersionScreen(),
      overrides: _overrides(offeringPresent: false),
    );

    expect(
      find.byKey(const ValueKey('pro_version.pricing_unavailable')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('pro_version.restore_button')),
      findsOneWidget,
    );
  });

  testWidgets('Restore calls the controller and reports success', (
    tester,
  ) async {
    final paywall = _RecordingPaywall(restoreResult: true);
    await smokeScreen(
      tester,
      const ProVersionScreen(),
      overrides: _overrides(paywall: () => paywall),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('pro_version.restore_button')),
    );
    await tester.tap(find.byKey(const ValueKey('pro_version.restore_button')));
    await tester.pumpAndSettle();

    expect(paywall.restoreCalls, 1);
    expect(find.text('Your Pro subscription has been restored.'), findsOneWidget);
  });

  testWidgets('Restore with nothing to restore says so', (tester) async {
    final paywall = _RecordingPaywall(restoreResult: false);
    await smokeScreen(
      tester,
      const ProVersionScreen(),
      overrides: _overrides(paywall: () => paywall),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('pro_version.restore_button')),
    );
    await tester.tap(find.byKey(const ValueKey('pro_version.restore_button')));
    await tester.pumpAndSettle();

    expect(
      find.text('No active subscription was found for this account.'),
      findsOneWidget,
    );
  });
}
