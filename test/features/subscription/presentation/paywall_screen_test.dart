/// Widget tests and goldens for [PaywallScreen] with a fake `default`
/// offering.
///
/// Covers: the two plans render from the store's own prices with the free
/// introductory week when eligible and without it when the store says the
/// offer is spent; the four actions (Restore, Manage subscription, Sign out,
/// Delete account) are present and each drives the right controller; the
/// unavailable state; and light/dark goldens of the paywall with its four
/// actions (mp-263).
///
/// Fonts: widget tests render with the test font, so the goldens pin LAYOUT,
/// COLOUR and STRUCTURE, not glyph shapes.
///
///   flutter test test/features/subscription/presentation/paywall_screen_test.dart
///   flutter test test/features/subscription/presentation/paywall_screen_test.dart --update-goldens
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/settings/domain/settings_state.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/settings_controller.dart';
import 'package:mealvana_endurance/features/subscription/application/pro_paywall_controller.dart';
import 'package:mealvana_endurance/features/subscription/application/subscription_status_provider.dart';
import 'package:mealvana_endurance/features/subscription/domain/entitlement.dart';
import 'package:mealvana_endurance/features/subscription/presentation/screens/paywall_screen.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';

import '../../../helpers/widget_test_harness.dart';
import '../../meal_planning/presentation/helpers/test_content.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

const _freeWeek = IntroductoryPrice(0, r'$0.00', 'P1W', 1, PeriodUnit.week, 1);

class _FakeStoreProduct extends Fake implements StoreProduct {
  _FakeStoreProduct(
    this.identifier,
    this.priceString, {
    this.introductoryPrice,
  });
  @override
  final String identifier;
  @override
  final String priceString;
  @override
  final IntroductoryPrice? introductoryPrice;
}

class _FakePackage extends Fake implements Package {
  _FakePackage(
    this.identifier,
    String sku,
    String price, {
    IntroductoryPrice? intro,
  }) : storeProduct = _FakeStoreProduct(sku, price, introductoryPrice: intro);
  @override
  final String identifier;
  @override
  final StoreProduct storeProduct;
}

final _monthly = _FakePackage(
  r'$rc_monthly',
  'mealvana_pro_monthly',
  r'$9.99',
  intro: _freeWeek,
);
final _annual = _FakePackage(
  r'$rc_annual',
  'mealvana_pro_annual',
  r'$69.99',
  intro: _freeWeek,
);

class _FixedStatus extends SubscriptionStatusController {
  _FixedStatus(this.status);
  final SubscriptionStatus status;
  @override
  Future<SubscriptionStatus> build() async => status;
}

/// Records calls instead of touching the store.
class _RecordingPaywall extends ProPaywallController {
  _RecordingPaywall({this.restoreResult = true, this.manageUri});
  final bool restoreResult;
  final Uri? manageUri;
  int restoreCalls = 0;
  int manageCalls = 0;
  final bought = <String>[];

  @override
  FutureOr<void> build() => null;

  @override
  Future<bool> restore() async {
    restoreCalls++;
    return restoreResult;
  }

  @override
  Future<Uri?> managementUrl() async {
    manageCalls++;
    return manageUri;
  }

  @override
  Future<ProPurchaseOutcome> buy(Package pkg) async {
    bought.add(pkg.storeProduct.identifier);
    return ProPurchaseOutcome.activated;
  }
}

/// Records sign-out / delete instead of touching Supabase.
class _RecordingSettings extends SettingsController {
  int signOuts = 0;
  int deletes = 0;

  @override
  FutureOr<SettingsState> build() => Completer<SettingsState>().future;

  @override
  Future<void> signOut() async => signOuts++;

  @override
  Future<void> deleteAccount() async => deletes++;
}

/// The exact strings of `assets/config/content_defaults.json`, so the tests
/// assert what the app renders rather than a hand-copied label.
final _content = loadDefaultContent();
ContentService _testContentService(Ref ref) =>
    TestContentService(ref, _content);

List<Override> _overrides({
  PaywallPlans? plans,
  ProPaywallController Function()? paywall,
  SettingsController Function()? settings,
  Future<bool> Function(Uri)? launcher,
}) {
  final resolved = plans ?? PaywallPlans(monthly: _monthly, annual: _annual);
  return [
    contentServiceProvider.overrideWith(_testContentService),
    subscriptionStatusProvider.overrideWith(
      () => _FixedStatus(SubscriptionStatus.none),
    ),
    paywallPlansProvider.overrideWith((ref) async => resolved),
    if (paywall != null) proPaywallControllerProvider.overrideWith(paywall),
    if (settings != null) settingsControllerProvider.overrideWith(settings),
    if (launcher != null)
      paywallUrlLauncherProvider.overrideWithValue(launcher),
  ];
}

const _restore = ValueKey('paywall.restore_button');
const _manage = ValueKey('paywall.manage_button');
const _signOut = ValueKey('paywall.sign_out_button');
const _delete = ValueKey('paywall.delete_account_button');
const _confirm = ValueKey('paywall.confirm.action');

void main() {
  testWidgets('renders without overflow (smoke)', (tester) async {
    await smokeScreen(tester, const PaywallScreen(), overrides: _overrides());
  });

  testWidgets('the two plans show the store prices and the free week', (
    tester,
  ) async {
    await smokeScreen(tester, const PaywallScreen(), overrides: _overrides());

    expect(find.byKey(const ValueKey('paywall.plan.monthly')), findsOneWidget);
    expect(find.byKey(const ValueKey('paywall.plan.annual')), findsOneWidget);
    expect(find.text(r'7 days free, then $9.99 / month'), findsOneWidget);
    expect(find.text(r'7 days free, then $69.99 / year'), findsOneWidget);
    expect(find.text('Start trial'), findsNWidgets(2));
  });

  testWidgets('a spent introductory offer shows the plain price', (
    tester,
  ) async {
    await smokeScreen(
      tester,
      const PaywallScreen(),
      overrides: _overrides(
        plans: PaywallPlans(
          monthly: _monthly,
          annual: _annual,
          introIneligible: const {
            'mealvana_pro_monthly',
            'mealvana_pro_annual',
          },
        ),
      ),
    );

    expect(find.text(r'$9.99 / month'), findsOneWidget);
    expect(find.text(r'$69.99 / year'), findsOneWidget);
    expect(find.textContaining('days free'), findsNothing);
    expect(find.text('Subscribe'), findsNWidgets(2));
  });

  testWidgets('the four actions are present, and no close button', (
    tester,
  ) async {
    await smokeScreen(tester, const PaywallScreen(), overrides: _overrides());

    for (final key in [_restore, _manage, _signOut, _delete]) {
      expect(find.byKey(key), findsOneWidget, reason: '$key');
    }
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('Start trial calls buy() for that plan', (tester) async {
    final paywall = _RecordingPaywall();
    await smokeScreen(
      tester,
      const PaywallScreen(),
      overrides: _overrides(paywall: () => paywall),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('paywall.subscribe_annual')),
    );
    await tester.tap(find.byKey(const ValueKey('paywall.subscribe_annual')));
    await tester.pumpAndSettle();

    expect(paywall.bought, ['mealvana_pro_annual']);
    expect(find.text('Welcome to Mealvana Endurance!'), findsOneWidget);
  });

  testWidgets('no offering → unavailable message, actions still present', (
    tester,
  ) async {
    await smokeScreen(
      tester,
      const PaywallScreen(),
      overrides: _overrides(plans: const PaywallPlans()),
    );

    expect(
      find.byKey(const ValueKey('paywall.pricing_unavailable')),
      findsOneWidget,
    );
    for (final key in [_restore, _manage, _signOut, _delete]) {
      expect(find.byKey(key), findsOneWidget, reason: '$key');
    }
  });

  testWidgets('Restore calls the controller and reports success', (
    tester,
  ) async {
    final paywall = _RecordingPaywall(restoreResult: true);
    await smokeScreen(
      tester,
      const PaywallScreen(),
      overrides: _overrides(paywall: () => paywall),
    );

    await tester.ensureVisible(find.byKey(_restore));
    await tester.tap(find.byKey(_restore));
    await tester.pumpAndSettle();

    expect(paywall.restoreCalls, 1);
    expect(find.text('Your subscription has been restored.'), findsOneWidget);
  });

  testWidgets('Restore with nothing to restore says so', (tester) async {
    final paywall = _RecordingPaywall(restoreResult: false);
    await smokeScreen(
      tester,
      const PaywallScreen(),
      overrides: _overrides(paywall: () => paywall),
    );

    await tester.ensureVisible(find.byKey(_restore));
    await tester.tap(find.byKey(_restore));
    await tester.pumpAndSettle();

    expect(
      find.text('No active subscription was found for this account.'),
      findsOneWidget,
    );
  });

  testWidgets('Manage subscription opens the management URL', (tester) async {
    final uri = Uri.parse('https://apps.apple.com/account/subscriptions');
    final paywall = _RecordingPaywall(manageUri: uri);
    final launched = <Uri>[];
    await smokeScreen(
      tester,
      const PaywallScreen(),
      overrides: _overrides(
        paywall: () => paywall,
        launcher: (u) async {
          launched.add(u);
          return true;
        },
      ),
    );

    await tester.ensureVisible(find.byKey(_manage));
    await tester.tap(find.byKey(_manage));
    await tester.pumpAndSettle();

    expect(paywall.manageCalls, 1);
    expect(launched, [uri]);
  });

  testWidgets('Manage subscription with nowhere to go says where to look', (
    tester,
  ) async {
    final paywall = _RecordingPaywall(manageUri: null);
    await smokeScreen(
      tester,
      const PaywallScreen(),
      overrides: _overrides(
        paywall: () => paywall,
        launcher: (_) async => true,
      ),
    );

    await tester.ensureVisible(find.byKey(_manage));
    await tester.tap(find.byKey(_manage));
    await tester.pumpAndSettle();

    expect(find.textContaining('Manage your subscription'), findsOneWidget);
  });

  testWidgets('Sign out confirms, then signs out through Settings', (
    tester,
  ) async {
    final settings = _RecordingSettings();
    await smokeScreen(
      tester,
      const PaywallScreen(),
      overrides: _overrides(settings: () => settings),
    );

    await tester.ensureVisible(find.byKey(_signOut));
    await tester.tap(find.byKey(_signOut));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('paywall.confirm.cancel')));
    await tester.pumpAndSettle();
    expect(settings.signOuts, 0);

    await tester.tap(find.byKey(_signOut));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_confirm));
    await tester.pumpAndSettle();
    expect(settings.signOuts, 1);
  });

  testWidgets('Delete account confirms, then deletes through Settings', (
    tester,
  ) async {
    final settings = _RecordingSettings();
    await smokeScreen(
      tester,
      const PaywallScreen(),
      overrides: _overrides(settings: () => settings),
    );

    await tester.ensureVisible(find.byKey(_delete));
    await tester.tap(find.byKey(_delete));
    await tester.pumpAndSettle();
    expect(find.text('Delete account?'), findsOneWidget);

    await tester.tap(find.byKey(_confirm));
    await tester.pumpAndSettle();
    expect(settings.deletes, 1);
    expect(settings.signOuts, 0);
  });

  testWidgets('onboarding mode: plans and Restore, no account actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mockAppExternalDeps(), ..._overrides()],
        child: const MaterialApp(home: PaywallScreen(onboarding: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paywall.plan.monthly')), findsOneWidget);
    expect(find.byKey(const ValueKey('paywall.plan.annual')), findsOneWidget);
    expect(find.byKey(_restore), findsOneWidget);
    expect(find.byKey(_manage), findsNothing);
    expect(find.byKey(_signOut), findsNothing);
    expect(find.byKey(_delete), findsNothing);
  });

  group('goldens — the paywall with its four actions', () {
    Future<void> golden(
      WidgetTester tester,
      Brightness brightness, {
      bool onboarding = false,
    }) async {
      tester.view.physicalSize = const Size(393, 1320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [mockAppExternalDeps(), ..._overrides()],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: brightness,
              scaffoldBackgroundColor: brightness == Brightness.dark
                  ? AppColors.blackberry
                  : AppColors.cream,
            ),
            home: RepaintBoundary(
              key: const Key('golden'),
              child: PaywallScreen(onboarding: onboarding),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final name = brightness == Brightness.dark ? 'dark' : 'light';
      final shape = onboarding ? 'onboarding_' : '';
      await expectLater(
        find.byKey(const Key('golden')),
        matchesGoldenFile('goldens/paywall_$shape$name.png'),
      );
    }

    testWidgets('light', (tester) => golden(tester, Brightness.light));
    testWidgets('dark', (tester) => golden(tester, Brightness.dark));
    testWidgets(
      'onboarding dark',
      (tester) => golden(tester, Brightness.dark, onboarding: true),
    );
  });
}
