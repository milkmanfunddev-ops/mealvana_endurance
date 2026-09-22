/// Widget tests and goldens for [PaywallScreen] with the SDK-decoded
/// `default` and `founding` offerings of `offerings_fixtures.dart`.
///
/// Covers: the two plans render from the store's own prices with the free
/// introductory week when eligible and without it when the store says the
/// offer is spent; the four actions (Restore, Manage subscription, Sign out,
/// Delete account) are present and each drives the right controller; the
/// unavailable state; founding prices beside the struck-through normal ones
/// (mp-453 §2); the trial terms, price after the trial and the terms and
/// privacy links (mp-453 §4); and light/dark goldens of the paywall with its
/// four actions (mp-263), plus the founding shape.
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
import 'package:mealvana_endurance/shared/services/privacy/privacy_links.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/cards/feature_list.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/data/phone_clip_frame.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/icons/vana_avatar.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';

import '../../../helpers/widget_test_harness.dart';
import '../../../shared/widgets/kyle_design/phone_clip_fakes.dart';
import '../../meal_planning/presentation/helpers/test_content.dart';
import '../offerings_fixtures.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

final _default = offeringFixture('default');
final _founding = offeringFixture('founding');
final _monthly = _default.monthly!;
final _annual = _default.annual!;

/// The plans while `founding` is current: founding packages sold, `default`
/// packages in the same slots for the struck-through prices.
PaywallPlans _foundingPlans({Set<String> introIneligible = const {}}) =>
    PaywallPlans(
      monthly: _founding.monthly,
      annual: _founding.annual,
      isFounding: true,
      regularMonthly: _monthly,
      regularAnnual: _annual,
      introIneligible: introIneligible,
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

/// Every test but the clip's own starts past the clip: its player ends the
/// moment it starts, so the page has moved on to the features and plans once
/// the pump settles. [clip] hands a test the player to drive instead.
List<Override> _overrides({
  PaywallPlans? plans,
  ProPaywallController Function()? paywall,
  SettingsController Function()? settings,
  Future<bool> Function(Uri)? launcher,
  PhoneClipPlayer Function()? clip,
}) {
  final resolved = plans ?? PaywallPlans(monthly: _monthly, annual: _annual);
  return [
    contentServiceProvider.overrideWith(_testContentService),
    paywallClipPlayerProvider.overrideWithValue(
      clip ?? () => FakePhoneClipPlayer(endOnStart: true),
    ),
    paywallClipPosterProvider.overrideWithValue(testPoster),
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
    expect(find.text(r'7 days free, then $24.99 / month'), findsOneWidget);
    expect(find.text(r'7 days free, then $199.99 / year'), findsOneWidget);
    expect(find.byKey(const ValueKey('paywall.founding_line')), findsNothing);
    expect(
      find.byKey(const ValueKey('paywall.plan.monthly.regular_price')),
      findsNothing,
    );
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
          introIneligible: const {'me_pro_monthly', 'me_pro_annual'},
        ),
      ),
    );

    expect(find.text(r'$24.99 / month'), findsOneWidget);
    expect(find.text(r'$199.99 / year'), findsOneWidget);
    expect(find.textContaining('days free'), findsNothing);
    expect(find.text('Subscribe'), findsNWidgets(2));
  });

  testWidgets('the four actions are present, and no app bar', (tester) async {
    await smokeScreen(tester, const PaywallScreen(), overrides: _overrides());

    for (final key in [_restore, _manage, _signOut, _delete]) {
      expect(find.byKey(key), findsOneWidget, reason: '$key');
    }
    expect(find.byType(AppBar), findsNothing);
  });

  group('the opening clip (mp-493 §1, mp-497 §2)', () {
    const clip = ValueKey('paywall.clip');
    const still = ValueKey('paywall.clip_still');
    const features = ValueKey('paywall.features');
    const plans = ValueKey('paywall.pricing_card');
    const close = ValueKey('paywall.close_button');
    const more = ValueKey('paywall.more_button');

    Future<void> pumpPaywall(
      WidgetTester tester, {
      required List<Override> overrides,
      bool reduceMotion = false,
    }) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [mockAppExternalDeps(), ...overrides],
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(393, 852),
                disableAnimations: reduceMotion,
              ),
              child: const PaywallScreen(),
            ),
          ),
        ),
      );
    }

    testWidgets('plays the clip silently, then slides to the features and '
        'plans; close and ⋯ arrive with them', (tester) async {
      final player = FakePhoneClipPlayer();
      var made = 0;
      await pumpPaywall(
        tester,
        overrides: _overrides(
          clip: () {
            made++;
            return player;
          },
        ),
      );
      await tester.pump();

      // Page one: the clip, playing muted, and nothing else.
      expect(made, 1);
      expect(player.started, isTrue);
      expect(player.muted, isTrue);
      player.phase.value = PhoneClipPhase.playing;
      await tester.pump();
      expect(find.byKey(clip), findsOneWidget);
      expect(find.byKey(FakePhoneClipPlayer.viewKey), findsOneWidget);
      for (final key in [features, plans, close, more]) {
        expect(find.byKey(key), findsNothing, reason: '$key');
      }

      // The clip ends: the features and plans slide over it.
      player.phase.value = PhoneClipPhase.ended;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(features), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(close)).dx, greaterThan(100));
      await tester.pumpAndSettle();

      expect(find.byKey(clip), findsNothing);
      expect(player.disposed, isTrue);
      for (final key in [features, plans, close, more]) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
      expect(tester.getTopLeft(find.byKey(close)).dx, lessThan(40));
    });

    testWidgets('a tap on the clip skips it', (tester) async {
      final player = FakePhoneClipPlayer();
      await pumpPaywall(tester, overrides: _overrides(clip: () => player));
      await tester.pump();
      await tester.tap(find.byKey(clip));
      await tester.pumpAndSettle();
      expect(find.byKey(features), findsOneWidget);
      expect(find.byKey(clip), findsNothing);
    });

    testWidgets('Reduce Motion: the first frame, straight on the features', (
      tester,
    ) async {
      var made = 0;
      await pumpPaywall(
        tester,
        reduceMotion: true,
        overrides: _overrides(
          clip: () {
            made++;
            return FakePhoneClipPlayer();
          },
        ),
      );
      await tester.pump();

      // No clip plays, no slide runs: the still frame heads the features.
      expect(made, 0);
      expect(find.byKey(clip), findsNothing);
      expect(find.byKey(still), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(still),
          matching: find.byKey(PhoneClipFrame.posterKey),
        ),
        findsOneWidget,
      );
      for (final key in [features, plans, close, more]) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('four headline features, the divider, then the rest, with '
        'the AI features on the one Vana line', (tester) async {
      await smokeScreen(tester, const PaywallScreen(), overrides: _overrides());
      String copy(String key) => _content[key]!;
      for (final key in [
        'paywall.feature_fuel_title',
        'paywall.feature_vana_title',
        'paywall.feature_vana_body',
        'paywall.feature_shopping_title',
        'paywall.feature_sync_title',
        'paywall.feature_recipes',
      ]) {
        expect(find.text(copy(key)), findsOneWidget, reason: key);
      }
      expect(find.byKey(FeatureList.headlineKey(3)), findsOneWidget);
      expect(find.byKey(FeatureList.headlineKey(4)), findsNothing);
      expect(
        find.text(copy('paywall.features_divider').toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(FeatureList.headlineKey(1)),
          matching: find.byType(VanaAvatar),
        ),
        findsOneWidget,
      );
      // The features come before the plans.
      expect(
        tester.getTopLeft(find.byKey(features)).dy,
        lessThan(tester.getTopLeft(find.byKey(plans)).dy),
      );
    });
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

    expect(paywall.bought, ['me_pro_annual']);
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

  group('founding prices (mp-453 §2)', () {
    testWidgets('each plan shows the founding price with the normal one '
        'struck through, under a Founding member line', (tester) async {
      await smokeScreen(
        tester,
        const PaywallScreen(),
        overrides: _overrides(plans: _foundingPlans()),
      );

      expect(find.text('Founding member'), findsOneWidget);
      expect(find.text(r'7 days free, then $12.49 / month'), findsOneWidget);
      expect(find.text(r'7 days free, then $99.99 / year'), findsOneWidget);

      final monthlyRegular = tester.widget<Text>(
        find.byKey(const ValueKey('paywall.plan.monthly.regular_price')),
      );
      final annualRegular = tester.widget<Text>(
        find.byKey(const ValueKey('paywall.plan.annual.regular_price')),
      );
      expect(monthlyRegular.data, r'$24.99 / month');
      expect(annualRegular.data, r'$199.99 / year');
      expect(monthlyRegular.style?.decoration, TextDecoration.lineThrough);
      expect(annualRegular.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('buying while founding is current buys the founding product', (
      tester,
    ) async {
      final paywall = _RecordingPaywall();
      await smokeScreen(
        tester,
        const PaywallScreen(),
        overrides: _overrides(plans: _foundingPlans(), paywall: () => paywall),
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('paywall.subscribe_monthly')),
      );
      await tester.tap(find.byKey(const ValueKey('paywall.subscribe_monthly')));
      await tester.pumpAndSettle();

      expect(paywall.bought, ['me_pro_monthly_founding']);
    });
  });

  group('terms (mp-453 §4)', () {
    testWidgets('the trial terms carry the free week and the price after it', (
      tester,
    ) async {
      await smokeScreen(tester, const PaywallScreen(), overrides: _overrides());

      expect(
        find.text(
          r'7 days free, then $24.99 a month or $199.99 a year. Nothing is '
          'charged during the free week. Cancel before it ends and you pay '
          'nothing.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('paywall.renewal_terms')),
        findsOneWidget,
      );
      expect(find.text('Terms of Use'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
    });

    testWidgets('while founding is current, the price after the trial is '
        'the founding price', (tester) async {
      await smokeScreen(
        tester,
        const PaywallScreen(),
        overrides: _overrides(plans: _foundingPlans()),
      );

      expect(
        find.textContaining(r'then $12.49 a month or $99.99 a year'),
        findsOneWidget,
      );
    });

    testWidgets('a spent free week leaves the plain prices in the terms', (
      tester,
    ) async {
      await smokeScreen(
        tester,
        const PaywallScreen(),
        overrides: _overrides(
          plans: PaywallPlans(
            monthly: _monthly,
            annual: _annual,
            introIneligible: const {'me_pro_monthly', 'me_pro_annual'},
          ),
        ),
      );

      expect(find.text(r'$24.99 a month or $199.99 a year.'), findsOneWidget);
    });

    testWidgets('no offering: renewal terms and links stay, no price line', (
      tester,
    ) async {
      await smokeScreen(
        tester,
        const PaywallScreen(),
        overrides: _overrides(plans: const PaywallPlans()),
      );

      expect(find.byKey(const ValueKey('paywall.trial_terms')), findsNothing);
      expect(
        find.byKey(const ValueKey('paywall.renewal_terms')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('paywall.terms_link')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('paywall.privacy_link')),
        findsOneWidget,
      );
    });

    testWidgets('the links open the terms of use and the privacy policy', (
      tester,
    ) async {
      final launched = <Uri>[];
      await smokeScreen(
        tester,
        const PaywallScreen(),
        overrides: _overrides(
          launcher: (u) async {
            launched.add(u);
            return true;
          },
        ),
      );

      for (final key in const [
        ValueKey('paywall.terms_link'),
        ValueKey('paywall.privacy_link'),
      ]) {
        await tester.ensureVisible(find.byKey(key));
        await tester.tap(find.byKey(key));
        await tester.pumpAndSettle();
      }

      expect(launched, [
        Uri.parse(kTermsOfServiceUrl),
        Uri.parse(kPrivacyPolicyUrl),
      ]);
    });

    testWidgets('a link that does not open says so', (tester) async {
      await smokeScreen(
        tester,
        const PaywallScreen(),
        overrides: _overrides(launcher: (_) async => false),
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('paywall.privacy_link')),
      );
      await tester.tap(find.byKey(const ValueKey('paywall.privacy_link')));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't open that page. Please try again."),
        findsOneWidget,
      );
    });
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
      bool founding = false,
    }) async {
      tester.view.physicalSize = const Size(393, 2500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mockAppExternalDeps(),
            ..._overrides(plans: founding ? _foundingPlans() : null),
          ],
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
      final shape = onboarding
          ? 'onboarding_'
          : founding
          ? 'founding_'
          : '';
      await expectLater(
        find.byKey(const Key('golden')),
        matchesGoldenFile('goldens/paywall_$shape$name.png'),
      );
    }

    testWidgets('light', (tester) => golden(tester, Brightness.light));
    testWidgets('dark', (tester) => golden(tester, Brightness.dark));
    testWidgets(
      'founding light',
      (tester) => golden(tester, Brightness.light, founding: true),
    );
    testWidgets(
      'founding dark',
      (tester) => golden(tester, Brightness.dark, founding: true),
    );
    testWidgets(
      'onboarding dark',
      (tester) => golden(tester, Brightness.dark, onboarding: true),
    );
  });
}
