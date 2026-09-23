/// Widget tests and goldens for [PaywallScreen] with the SDK-decoded
/// `default` and `founding` offerings of `offerings_fixtures.dart`.
///
/// Covers: the two plan cards pinned above one Continue button through the
/// whole scroll, annual selected with its saving and per-month price from
/// the store prices (mp-493 §3); the free week when eligible and not when
/// the store says it is spent; the ⋯ menu listing exactly Restore, Redeem
/// code, Manage (only with a subscription), Sign out and Delete account
/// (mp-494); Redeem code opening our own Code entry, which sends the Code
/// and says what it did or why it was refused (mp-458); the two presentations (mp-493 §5): no close
/// button full screen, and for a lapsed account a closable glass sheet over
/// the read-only app, opened by the plan-ended bar, an AI tap or an AI route,
/// that closes back to the same screen, while a never-subscribed account
/// stays full screen; each menu entry driving the right controller; the
/// unavailable state; founding prices beside the struck-through normal ones
/// (mp-453 §2); the trial terms, price after the trial and the terms and
/// privacy links (mp-453 §4); the opening clip (mp-493 §1); and light/dark
/// goldens of the full-screen paywall at phone size, plus the founding shape,
/// and of the sheet over the read-only app, light and dark.
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
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/settings/domain/settings_state.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/settings_controller.dart';
import 'package:mealvana_endurance/features/subscription/application/code_entry_controller.dart';
import 'package:mealvana_endurance/features/subscription/application/pro_paywall_controller.dart';
import 'package:mealvana_endurance/features/subscription/domain/code_redemption.dart';
import 'package:mealvana_endurance/features/subscription/presentation/widgets/redeem_code_sheet.dart';
import 'package:mealvana_endurance/features/subscription/application/subscription_status_provider.dart';
import 'package:mealvana_endurance/features/subscription/domain/entitlement.dart';
import 'package:mealvana_endurance/features/subscription/application/pro_gate.dart';
import 'package:mealvana_endurance/features/subscription/application/write_guard.dart';
import 'package:mealvana_endurance/features/subscription/presentation/ai_action_guard.dart';
import 'package:mealvana_endurance/features/subscription/presentation/plan_ended_host.dart';
import 'package:mealvana_endurance/features/subscription/presentation/pro_gate_redirect.dart';
import 'package:mealvana_endurance/features/subscription/presentation/screens/paywall_screen.dart';
import 'package:mealvana_endurance/shared/providers/is_admin_provider.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/feedback/plan_ended_bar.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/materials/glass.dart';
import 'package:mealvana_endurance/shared/services/privacy/privacy_links.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/buttons/overflow_menu_button.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/cards/feature_list.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/cards/plan_card.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/data/phone_clip_frame.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/icons/vana_avatar.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';

import '../../../helpers/widget_test_harness.dart';
import '../../../shared/widgets/kyle_design/phone_clip_fakes.dart';
import '../../meal_planning/presentation/helpers/test_content.dart';
import '../code_entry_fakes.dart';
import '../customer_info_fixtures.dart';
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
  CodeEntryController Function()? codeEntry,
  bool hasSubscription = false,
  SubscriptionStatus status = SubscriptionStatus.none,
}) {
  final resolved = plans ?? PaywallPlans(monthly: _monthly, annual: _annual);
  return [
    contentServiceProvider.overrideWith(_testContentService),
    paywallClipPlayerProvider.overrideWithValue(
      clip ?? () => FakePhoneClipPlayer(endOnStart: true),
    ),
    paywallClipPosterProvider.overrideWithValue(testPoster),
    subscriptionStatusProvider.overrideWith(() => _FixedStatus(status)),
    paywallPlansProvider.overrideWith((ref) async => resolved),
    paywallHasSubscriptionProvider.overrideWith((ref) async => hasSubscription),
    if (paywall != null) proPaywallControllerProvider.overrideWith(paywall),
    if (settings != null) settingsControllerProvider.overrideWith(settings),
    if (codeEntry != null) codeEntryControllerProvider.overrideWith(codeEntry),
    if (launcher != null)
      paywallUrlLauncherProvider.overrideWithValue(launcher),
  ];
}

const _restore = ValueKey('paywall.restore_button');
const _redeem = ValueKey('paywall.redeem_code_button');
const _manage = ValueKey('paywall.manage_button');
const _signOut = ValueKey('paywall.sign_out_button');
const _delete = ValueKey('paywall.delete_account_button');
const _confirm = ValueKey('paywall.confirm.action');
const _more = ValueKey('paywall.more_button');
const _close = ValueKey('paywall.close_button');
const _continue = ValueKey('paywall.continue_button');
const _tray = ValueKey('paywall.plans');
const _annualCard = ValueKey('paywall.plan.annual');
const _monthlyCard = ValueKey('paywall.plan.monthly');

/// Opens the ⋯ menu.
Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(_more));
  await tester.pumpAndSettle();
}

/// The menu's words, top to bottom.
List<String?> _menuLabels(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byKey(OverflowMenuButton.menuKey),
        matching: find.byType(Text),
      ),
    )
    .map((t) => t.data)
    .toList();

/// The text of [key] inside the plan card [card].
String? _onCard(WidgetTester tester, Key card, Key key) {
  final f = find.descendant(of: find.byKey(card), matching: find.byKey(key));
  if (f.evaluate().isEmpty) return null;
  return tester.widget<Text>(f).data;
}

void main() {
  testWidgets('renders without overflow (smoke)', (tester) async {
    await smokeScreen(tester, const PaywallScreen(), overrides: _overrides());
  });

  testWidgets('the two plan cards show the store prices and the free week, '
      'above one Continue', (tester) async {
    await smokeScreen(tester, const PaywallScreen(), overrides: _overrides());

    expect(find.byKey(_monthlyCard), findsOneWidget);
    expect(find.byKey(_annualCard), findsOneWidget);
    expect(_onCard(tester, _monthlyCard, PlanCard.priceKey), r'$24.99 / month');
    expect(_onCard(tester, _annualCard, PlanCard.priceKey), r'$199.99 / year');
    expect(_onCard(tester, _monthlyCard, PlanCard.noteKey), '7 days free');
    expect(_onCard(tester, _annualCard, PlanCard.noteKey), '7 days free');
    expect(find.byKey(const ValueKey('paywall.founding_line')), findsNothing);
    expect(_onCard(tester, _annualCard, PlanCard.regularPriceKey), isNull);
    expect(find.byKey(_continue), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    // The plans sit above the one button.
    expect(
      tester.getTopLeft(find.byKey(_monthlyCard)).dy,
      lessThan(tester.getTopLeft(find.byKey(_continue)).dy),
    );
  });

  testWidgets('annual is selected, with save 33% and \$16.67 a month from '
      'the store prices', (tester) async {
    await smokeScreen(tester, const PaywallScreen(), overrides: _overrides());

    PlanCard card(Key key) => tester.widget<PlanCard>(find.byKey(key));
    expect(card(_annualCard).selected, isTrue);
    expect(card(_monthlyCard).selected, isFalse);
    expect(
      find.descendant(
        of: find.byKey(_annualCard),
        matching: find.byKey(PlanCard.badgeKey),
      ),
      findsOneWidget,
    );
    expect(find.text('Save 33%'), findsOneWidget);
    expect(_onCard(tester, _annualCard, PlanCard.detailKey), r'$16.67 a month');
    expect(_onCard(tester, _monthlyCard, PlanCard.detailKey), isNull);
    expect(
      find.descendant(
        of: find.byKey(_monthlyCard),
        matching: find.text('Save 33%'),
      ),
      findsNothing,
    );
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

    expect(_onCard(tester, _monthlyCard, PlanCard.priceKey), r'$24.99 / month');
    expect(_onCard(tester, _annualCard, PlanCard.priceKey), r'$199.99 / year');
    expect(find.textContaining('days free'), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
  });

  group('pinned through the scroll (mp-493 §3)', () {
    testWidgets('the plans and Continue stay on screen from the top of the '
        'scroll to its end', (tester) async {
      await smokeScreen(tester, const PaywallScreen(), overrides: _overrides());
      const screen = Rect.fromLTWH(0, 0, 390, 844);
      final before = {
        for (final k in [_tray, _annualCard, _monthlyCard, _continue])
          k: tester.getRect(find.byKey(k)),
      };
      for (final rect in before.values) {
        expect(screen.contains(rect.topLeft), isTrue);
        expect(screen.contains(rect.bottomRight - const Offset(1, 1)), isTrue);
      }

      // Scroll to the very end: the privacy link is the last thing.
      await tester.dragUntilVisible(
        find.byKey(const ValueKey('paywall.privacy_link')),
        find.byKey(const ValueKey('paywall.scroll')),
        const Offset(0, -300),
      );
      await tester.drag(
        find.byKey(const ValueKey('paywall.scroll')),
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(const ValueKey('paywall.scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollable.position.pixels, greaterThan(0));
      expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);

      for (final entry in before.entries) {
        expect(
          tester.getRect(find.byKey(entry.key)),
          entry.value,
          reason: '${entry.key} moved with the scroll',
        );
      }
      // And still takes a tap there.
      await tester.tap(find.byKey(_monthlyCard));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PlanCard>(find.byKey(_monthlyCard)).selected,
        isTrue,
      );
    });
  });

  group('the ⋯ menu (mp-494)', () {
    testWidgets('the old stack of buttons is gone: the actions are only in '
        'the menu', (tester) async {
      await smokeScreen(tester, const PaywallScreen(), overrides: _overrides());
      for (final key in [_restore, _manage, _signOut, _delete]) {
        expect(find.byKey(key), findsNothing, reason: '$key');
      }
      expect(find.byType(AppBar), findsNothing);
      expect(find.byKey(_more), findsOneWidget);
    });

    testWidgets('never subscribed: Restore, Redeem code, Sign out, Delete '
        'account; no Manage', (tester) async {
      await smokeScreen(tester, const PaywallScreen(), overrides: _overrides());
      await _openMenu(tester);
      expect(_menuLabels(tester), [
        'Restore purchases',
        'Redeem code',
        'Sign out',
        'Delete account',
      ]);
      expect(find.byKey(_manage), findsNothing);
    });

    testWidgets('with a subscription: Restore, Redeem code, Manage, Sign out, '
        'Delete account', (tester) async {
      await smokeScreen(
        tester,
        const PaywallScreen(),
        overrides: _overrides(hasSubscription: true),
      );
      await _openMenu(tester);
      expect(_menuLabels(tester), [
        'Restore purchases',
        'Redeem code',
        'Manage subscription',
        'Sign out',
        'Delete account',
      ]);
    });

    testWidgets('the onboarding shape carries the same menu (mp-494 §2)', (
      tester,
    ) async {
      await smokeScreen(
        tester,
        const PaywallScreen(onboarding: true),
        overrides: _overrides(),
      );
      await _openMenu(tester);
      expect(_menuLabels(tester), [
        'Restore purchases',
        'Redeem code',
        'Sign out',
        'Delete account',
      ]);
    });
  });

  group('the close button: only on the sheet (mp-493 §5)', () {
    testWidgets('never subscribed: none', (tester) async {
      await smokeScreen(tester, const PaywallScreen(), overrides: _overrides());
      expect(find.byKey(_close), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('onboarding: none', (tester) async {
      await smokeScreen(
        tester,
        const PaywallScreen(onboarding: true),
        overrides: _overrides(),
      );
      expect(find.byKey(_close), findsNothing);
    });

    testWidgets('lapsed full screen (the paywall as the base location): '
        'none', (tester) async {
      await smokeScreen(
        tester,
        const PaywallScreen(),
        overrides: _overrides(hasSubscription: true),
      );
      expect(find.byKey(_close), findsNothing);
    });

    testWidgets('the sheet has one: a close beside ⋯, labelled Close', (
      tester,
    ) async {
      await smokeScreen(
        tester,
        const PaywallScreen(presentation: PaywallPresentation.sheet),
        overrides: _overrides(hasSubscription: true),
      );
      expect(find.byKey(_close), findsOneWidget);
      expect(find.byTooltip(_content['paywall.close_label']!), findsOneWidget);
      // Same row as ⋯, on the other side.
      expect(
        tester.getCenter(find.byKey(_close)).dy,
        tester.getCenter(find.byKey(_more)).dy,
      );
      expect(
        tester.getCenter(find.byKey(_close)).dx,
        lessThan(tester.getCenter(find.byKey(_more)).dx),
      );
    });
  });

  group('the opening clip (mp-493 §1, mp-497 §2)', () {
    const clip = ValueKey('paywall.clip');
    const still = ValueKey('paywall.clip_still');
    const features = ValueKey('paywall.features');
    const plans = _tray;
    const more = _more;

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
        'plans; ⋯ arrives with them', (tester) async {
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
      for (final key in [features, plans, more]) {
        expect(find.byKey(key), findsNothing, reason: '$key');
      }

      // The clip ends: the features and plans slide over it.
      player.phase.value = PhoneClipPhase.ended;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(features), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(more)).dx, greaterThan(393));
      await tester.pumpAndSettle();

      expect(find.byKey(clip), findsNothing);
      expect(player.disposed, isTrue);
      for (final key in [features, plans, more]) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
      expect(find.byKey(_close), findsNothing);
      expect(tester.getTopRight(find.byKey(more)).dx, greaterThan(340));
      expect(tester.getTopRight(find.byKey(more)).dx, lessThanOrEqualTo(393));
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
      for (final key in [features, plans, more]) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
      // Continue's own 200 ms enabled-state fade (the plans arrive after the
      // first frame) is the only motion allowed; a slide would still be
      // running at 250 ms (it takes 480).
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('iOS Reduce Motion: the first frame, straight on the '
        'features', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      var made = 0;
      await pumpPaywall(
        tester,
        overrides: _overrides(
          clip: () {
            made++;
            return FakePhoneClipPlayer();
          },
        ),
      );
      await tester.pump();
      expect(made, 0);
      expect(find.byKey(clip), findsNothing);
      expect(find.byKey(still), findsOneWidget);
      expect(find.byKey(features), findsOneWidget);
      expect(find.byKey(more), findsOneWidget);
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

  testWidgets('Continue buys annual, selected by default', (tester) async {
    final paywall = _RecordingPaywall();
    await smokeScreen(
      tester,
      const PaywallScreen(),
      overrides: _overrides(paywall: () => paywall),
    );

    await tester.tap(find.byKey(_continue));
    await tester.pumpAndSettle();
    expect(paywall.bought, ['me_pro_annual']);
    expect(find.text('Welcome to Mealvana Endurance!'), findsOneWidget);
  });

  testWidgets('picking monthly moves the selection; Continue buys monthly', (
    tester,
  ) async {
    final paywall = _RecordingPaywall();
    await smokeScreen(
      tester,
      const PaywallScreen(),
      overrides: _overrides(paywall: () => paywall),
    );

    await tester.tap(find.byKey(_monthlyCard));
    await tester.pumpAndSettle();
    expect(tester.widget<PlanCard>(find.byKey(_annualCard)).selected, isFalse);
    expect(tester.widget<PlanCard>(find.byKey(_monthlyCard)).selected, isTrue);
    await tester.tap(find.byKey(_continue));
    await tester.pumpAndSettle();
    expect(paywall.bought, ['me_pro_monthly']);
  });

  testWidgets('no offering → unavailable message, nothing to buy, the menu '
      'still there', (tester) async {
    final paywall = _RecordingPaywall();
    await smokeScreen(
      tester,
      const PaywallScreen(),
      overrides: _overrides(
        plans: const PaywallPlans(),
        paywall: () => paywall,
      ),
    );

    expect(
      find.byKey(const ValueKey('paywall.pricing_unavailable')),
      findsOneWidget,
    );
    expect(find.byType(PlanCard), findsNothing);
    await tester.tap(find.byKey(_continue));
    await tester.pumpAndSettle();
    expect(paywall.bought, isEmpty);
    await _openMenu(tester);
    for (final key in [_restore, _redeem, _signOut, _delete]) {
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

    await _openMenu(tester);
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

    await _openMenu(tester);
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
        hasSubscription: true,
        launcher: (u) async {
          launched.add(u);
          return true;
        },
      ),
    );

    await _openMenu(tester);
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
        hasSubscription: true,
        launcher: (_) async => true,
      ),
    );

    await _openMenu(tester);
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

    await _openMenu(tester);
    await tester.tap(find.byKey(_signOut));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('paywall.confirm.cancel')));
    await tester.pumpAndSettle();
    expect(settings.signOuts, 0);

    await _openMenu(tester);
    await tester.tap(find.byKey(_signOut));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_confirm));
    await tester.pumpAndSettle();
    expect(settings.signOuts, 1);
  });

  testWidgets('Delete account is in reach from the menu, confirms, then '
      'deletes through Settings', (tester) async {
    final settings = _RecordingSettings();
    await smokeScreen(
      tester,
      const PaywallScreen(),
      overrides: _overrides(settings: () => settings),
    );

    await _openMenu(tester);
    await tester.tap(find.byKey(_delete));
    await tester.pumpAndSettle();
    expect(find.text('Delete account?'), findsOneWidget);

    await tester.tap(find.byKey(_confirm));
    await tester.pumpAndSettle();
    expect(settings.deletes, 1);
    expect(settings.signOuts, 0);
  });

  group('Redeem code (mp-458, mp-494)', () {
    Future<RecordingCodeEntry> openEntry(
      WidgetTester tester,
      Object answer,
    ) async {
      final entry = RecordingCodeEntry(answer);
      await smokeScreen(
        tester,
        const PaywallScreen(),
        overrides: _overrides(codeEntry: () => entry),
      );
      await _openMenu(tester);
      await tester.tap(find.byKey(_redeem));
      await tester.pumpAndSettle();
      return entry;
    }

    Future<void> enter(WidgetTester tester, String code) async {
      await tester.enterText(find.byKey(RedeemCodeSheet.fieldKey), code);
      await tester.pump();
      await tester.tap(find.byKey(RedeemCodeSheet.submitKey));
      await tester.pumpAndSettle();
    }

    testWidgets('opens our own Code entry, not the store\'s sheet', (
      tester,
    ) async {
      await openEntry(
        tester,
        const CodeRedeemed(kind: RedeemedKind.attributed),
      );
      expect(find.byType(RedeemCodeSheet), findsOneWidget);
      expect(find.text(_content['redeem_code.title']!), findsOneWidget);
      expect(find.byKey(RedeemCodeSheet.fieldKey), findsOneWidget);
    });

    testWidgets('Redeem does nothing until a Code is typed', (tester) async {
      final entry = await openEntry(
        tester,
        const CodeRedeemed(kind: RedeemedKind.attributed),
      );
      await tester.tap(find.byKey(RedeemCodeSheet.submitKey));
      await tester.pumpAndSettle();
      expect(entry.sent, isEmpty);
      expect(find.byType(RedeemCodeSheet), findsOneWidget);
    });

    testWidgets("a coach's own Code: sent, the sheet closes and says what it "
        'did', (tester) async {
      final entry = await openEntry(
        tester,
        const CodeRedeemed(kind: RedeemedKind.coach, proDays: 30),
      );
      await enter(tester, 'coach42');

      expect(entry.sent, ['COACH42']);
      expect(find.byType(RedeemCodeSheet), findsNothing);
      expect(
        find.text("You're set up as a coach, with 30 days of Pro."),
        findsOneWidget,
      );
    });

    testWidgets('a giveaway Code says how many days of Pro', (tester) async {
      await openEntry(
        tester,
        const CodeRedeemed(kind: RedeemedKind.giveaway, proDays: 365),
      );
      await enter(tester, 'WIN365');
      expect(
        find.text('Code redeemed. You have 365 days of Pro.'),
        findsOneWidget,
      );
    });

    testWidgets("a coach's Code entered by an athlete says the pairing is "
        'asked for', (tester) async {
      await openEntry(
        tester,
        const CodeRedeemed(kind: RedeemedKind.paired, coachUserId: 'c-1'),
      );
      await enter(tester, 'COACH42');
      expect(
        find.text(_content['redeem_code.success_paired']!),
        findsOneWidget,
      );
    });

    testWidgets('a refused Code keeps the sheet open and says why', (
      tester,
    ) async {
      await openEntry(tester, const CodeRefused(reason: CodeRefusal.expired));
      await enter(tester, 'OLD');
      expect(find.byType(RedeemCodeSheet), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(RedeemCodeSheet.problemKey)).data,
        'That code has expired.',
      );

      // Typing another Code clears the refusal.
      await tester.enterText(find.byKey(RedeemCodeSheet.fieldKey), 'NEW');
      await tester.pump();
      expect(find.byKey(RedeemCodeSheet.problemKey), findsNothing);
    });

    testWidgets('an anonymous session is told to sign in', (tester) async {
      await openEntry(tester, const CodeRedeemFailure.signInRequired());
      await enter(tester, 'ABC');
      expect(find.byType(RedeemCodeSheet), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(RedeemCodeSheet.problemKey)).data,
        _content['redeem_code.failed_sign_in'],
      );
    });

    testWidgets('no answer asks to try again', (tester) async {
      await openEntry(tester, const CodeRedeemFailure.unavailable());
      await enter(tester, 'ABC');
      expect(
        tester.widget<Text>(find.byKey(RedeemCodeSheet.problemKey)).data,
        _content['redeem_code.failed_unavailable'],
      );
    });
  });

  group('founding prices (mp-453 §2)', () {
    testWidgets('each plan shows the founding price with the normal one '
        'struck through, under a Founding member line; annual saves 33% at '
        '\$8.33 a month', (tester) async {
      await smokeScreen(
        tester,
        const PaywallScreen(),
        overrides: _overrides(plans: _foundingPlans()),
      );

      expect(find.text('Founding member'), findsOneWidget);
      expect(
        _onCard(tester, _monthlyCard, PlanCard.priceKey),
        r'$12.49 / month',
      );
      expect(_onCard(tester, _annualCard, PlanCard.priceKey), r'$99.99 / year');
      expect(
        _onCard(tester, _monthlyCard, PlanCard.regularPriceKey),
        r'$24.99 / month',
      );
      expect(
        _onCard(tester, _annualCard, PlanCard.regularPriceKey),
        r'$199.99 / year',
      );
      final struck = tester.widget<Text>(
        find.descendant(
          of: find.byKey(_annualCard),
          matching: find.byKey(PlanCard.regularPriceKey),
        ),
      );
      expect(struck.style?.decoration, TextDecoration.lineThrough);
      expect(
        _onCard(tester, _annualCard, PlanCard.detailKey),
        r'$8.33 a month',
      );
      expect(find.text('Save 33%'), findsOneWidget);
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

      await tester.tap(find.byKey(_monthlyCard));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_continue));
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

  group('goldens — the full-screen paywall (mp-497 §3)', () {
    Future<void> golden(
      WidgetTester tester,
      Brightness brightness, {
      bool founding = false,
    }) async {
      tester.view.physicalSize = const Size(393, 852);
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
            home: const RepaintBoundary(
              key: Key('golden'),
              child: PaywallScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final name = brightness == Brightness.dark ? 'dark' : 'light';
      final shape = founding ? 'founding_' : '';
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
  });

  // The two presentations in the app (mp-493 §5, mp-457 §3): the router
  // wired the way app_router.dart wires it (the gate's redirect, the
  // paywall route's page from paywallRoutePage), the plan-ended host over
  // it the way root_app_widget.dart composes it, and the gate answering
  // from producer-shaped customer info through the real gate.
  group('two presentations in the app (mp-493 §5)', () {
    const aiButton = ValueKey('test.ai_action');
    const subscribe = ValueKey('plan_ended_bar.subscribe');

    Future<GoRouter> pumpApp(
      WidgetTester tester, {
      required SubscriptionStatus status,
      required String initial,
      Brightness brightness = Brightness.light,
    }) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      // A status bar, so the sheet stops below it and the screen shows above.
      tester.view.padding = const FakeViewPadding(top: 59);
      addTearDown(tester.view.reset);

      final c = ProviderContainer(
        overrides: [
          mockAppExternalDeps(),
          isAdminProvider.overrideWith((_) async => false),
          ..._overrides(status: status, hasSubscription: status.hadPro),
        ],
      );
      addTearDown(c.dispose);

      late final GoRouter router;
      final decided = <LocalKey, PaywallPresentation>{};
      Widget page(String label) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              Consumer(
                builder: (context, ref, _) => TextButton(
                  key: aiButton,
                  onPressed: () => unawaited(aiActionAllowed(context, ref)),
                  child: const Text('ask Vana'),
                ),
              ),
            ],
          ),
        ),
      );
      router = GoRouter(
        initialLocation: initial,
        redirect: (context, state) async {
          final path = state.uri.path;
          if (isUngatedPath(path)) return null;
          final access = await c.read(appGateProvider.future);
          return gateRedirect(path: path, access: access);
        },
        routes: [
          GoRoute(path: '/main', builder: (_, _) => page('main')),
          GoRoute(path: '/settings', builder: (_, _) => page('settings')),
          GoRoute(path: '/vana', builder: (_, _) => page('vana')),
          GoRoute(
            path: kPaywallPath,
            pageBuilder: (_, state) => paywallRoutePage(
              state,
              access: c.read(appGateProvider).value,
              current: router.routerDelegate.currentConfiguration,
              decided: decided,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: brightness,
              scaffoldBackgroundColor: brightness == Brightness.dark
                  ? AppColors.blackberry
                  : AppColors.cream,
            ),
            routerConfig: router,
            builder: (context, child) => RepaintBoundary(
              key: const Key('golden'),
              child: PlanEndedHost(router: router, child: child!),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    Finder sheetPaywall() => find.descendant(
      of: find.byType(GlassSheetSurface),
      matching: find.byKey(const ValueKey('paywall.screen')),
    );

    /// The sheet is up over [screen], then its close returns to [screen]
    /// under the plan-ended bar.
    Future<void> closesBackTo(
      WidgetTester tester,
      GoRouter router,
      String screen,
    ) async {
      expect(sheetPaywall(), findsOneWidget);
      expect(find.text(screen), findsOneWidget, reason: 'still under it');
      expect(find.byKey(_close), findsOneWidget);

      await tester.tap(find.byKey(_close));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('paywall.screen')), findsNothing);
      expect(find.text(screen), findsOneWidget);
      expect(find.byType(PlanEndedBar), findsOneWidget);
      expect(topPathOf(router.routerDelegate.currentConfiguration), '/$screen');
    }

    testWidgets('lapsed: the bar\'s Subscribe opens the sheet; close returns '
        'to the same screen', (tester) async {
      final router = await pumpApp(
        tester,
        status: statusOf(customerInfoLapsed),
        initial: '/settings',
      );
      expect(find.byType(PlanEndedBar), findsOneWidget);

      await tester.tap(find.byKey(subscribe));
      await tester.pumpAndSettle();
      await closesBackTo(tester, router, 'settings');
    });

    testWidgets('lapsed: an AI tap opens the sheet; close returns to the '
        'same screen', (tester) async {
      final router = await pumpApp(
        tester,
        status: statusOf(customerInfoLapsed),
        initial: '/main',
      );

      await tester.tap(find.byKey(aiButton));
      await tester.pumpAndSettle();
      await closesBackTo(tester, router, 'main');
    });

    testWidgets('lapsed: an AI route opens the sheet over the screen it was '
        'opened from', (tester) async {
      final router = await pumpApp(
        tester,
        status: statusOf(customerInfoLapsed),
        initial: '/settings',
      );

      unawaited(router.push('/vana'));
      await tester.pumpAndSettle();
      expect(find.text('vana'), findsNothing);
      await closesBackTo(tester, router, 'settings');
    });

    testWidgets('lapsed: a refused edit opens the sheet; close returns to the '
        'same screen', (tester) async {
      final router = await pumpApp(
        tester,
        status: statusOf(customerInfoLapsed),
        initial: '/settings',
      );

      // What a write controller's refused `canWrite()` does.
      ProviderScope.containerOf(
        tester.element(find.text('settings')),
      ).read(paywallRequestsProvider.notifier).request();
      await tester.pumpAndSettle();
      await closesBackTo(tester, router, 'settings');
    });

    testWidgets('lapsed: the sheet stays a sheet when a route is pushed over '
        'it and popped', (tester) async {
      final router = await pumpApp(
        tester,
        status: statusOf(customerInfoLapsed),
        initial: '/settings',
      );
      await tester.tap(find.byKey(subscribe));
      await tester.pumpAndSettle();
      expect(sheetPaywall(), findsOneWidget);

      // The paywall's page is rebuilt while another route is on top of it.
      final sheetState = tester.state(
        find.byKey(const ValueKey('paywall.screen')),
      );
      unawaited(router.push('/main'));
      await tester.pumpAndSettle();
      expect(
        find.byType(GlassSheetSurface, skipOffstage: false),
        findsOneWidget,
        reason: 'the paywall under the pushed route is still the sheet',
      );
      router.pop();
      await tester.pumpAndSettle();
      expect(
        tester.state(find.byKey(const ValueKey('paywall.screen'))),
        same(sheetState),
        reason: 'the same sheet, not a new one built on the pop',
      );
      await tester.pumpAndSettle();

      await closesBackTo(tester, router, 'settings');
    });

    testWidgets('never: full screen, no close, nothing under it', (
      tester,
    ) async {
      final router = await pumpApp(
        tester,
        status: statusOf(customerInfoNever),
        initial: '/main',
      );

      expect(
        topPathOf(router.routerDelegate.currentConfiguration),
        kPaywallPath,
      );
      expect(find.byKey(const ValueKey('paywall.screen')), findsOneWidget);
      expect(sheetPaywall(), findsNothing);
      expect(find.byType(GlassSheetSurface), findsNothing);
      expect(find.byKey(_close), findsNothing);
      expect(find.text('main'), findsNothing);
      expect(find.byType(PlanEndedBar), findsNothing);
      final scaffold = tester.widget<Scaffold>(
        find.byKey(const ValueKey('paywall.screen')),
      );
      expect(scaffold.backgroundColor, AppColors.cream);
    });

    group('goldens: the sheet over the read-only app (mp-497 §3)', () {
      Future<void> golden(WidgetTester tester, Brightness brightness) async {
        await pumpApp(
          tester,
          status: statusOf(customerInfoLapsed),
          initial: '/settings',
          brightness: brightness,
        );
        await tester.tap(find.byKey(subscribe));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(sheetPaywall(), findsOneWidget);

        final name = brightness == Brightness.dark ? 'dark' : 'light';
        await expectLater(
          find.byKey(const Key('golden')),
          matchesGoldenFile('goldens/paywall_sheet_$name.png'),
        );
      }

      testWidgets('light', (tester) => golden(tester, Brightness.light));
      testWidgets('dark', (tester) => golden(tester, Brightness.dark));
    });
  });
}
