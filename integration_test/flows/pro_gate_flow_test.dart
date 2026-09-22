/// The app gate under **Patrol** — everything is behind the one RevenueCat
/// entitlement (mp-280), and this flow proves the gate and the routes agree
/// for whatever account the build under test signs in as.
///
/// **Why it is written as an invariant rather than "the locked user sees the
/// paywall".** Patrol runs against the dev account, which holds an
/// entitlement, so a test demanding the paywall would be red on every run.
/// What is worth pinning either way is that the gate is one thing:
///
///   * Tabs shell on screen  → the gate is open: `/food` renders the Food
///                             screen, `/vana` the Vana chat, and pushing
///                             `/paywall` yields straight back to the shell.
///   * Paywall on screen     → the gate is closed: `/food` and `/vana` land
///                             on the paywall too, and it carries its four
///                             actions.
///
/// A gate that half-applies (shell shown but a route bounces, or paywall
/// shown but a deep link opens the feature) fails here in both states.
///
/// Flow:
///   launchApp → ensureAuthenticated
///     → read whether the tabs shell or the paywall is up
///     → router.push('/food'), assert food screen XOR paywall accordingly
///     → back out, router.push('/vana'), same assertion
///     → open state only: router.push('/paywall') lands back on the shell
///
/// Provider-free (no Garmin/TP credentials), so it runs on iOS and Android.
///
/// Run:
///   patrol test --target integration_test/flows/pro_gate_flow_test.dart \
///     --flavor dev \
///     --dart-define-from-file=.env.dev.local \
///     --dart-define-from-file=secrets/integration_test.env \
///     --device "iPhone 17 Pro"
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patrol/patrol.dart';

import '../helpers/flow_launcher.dart';

const _foodScreen = ValueKey('meal_planning.food_screen');
const _vanaScreen = ValueKey('meal_planning.vana_chat_screen');
const _paywallScreen = ValueKey('paywall.screen');
const _paywallMore = ValueKey('paywall.more_button');

/// Always in the paywall's ⋯ menu (mp-494); Manage subscription joins them
/// only for an account with a subscription on record.
const _paywallActions = [
  ValueKey('paywall.restore_button'),
  ValueKey('paywall.sign_out_button'),
  ValueKey('paywall.delete_account_button'),
];

/// Pushes [path] through the app's own GoRouter (the same redirect chain a
/// deep link takes) and pumps until one of [keys] shows up.
Future<ValueKey<String>?> _pushAndSettleOn(
  PatrolIntegrationTester $,
  String path,
  List<ValueKey<String>> keys, {
  Duration timeout = const Duration(seconds: 25),
}) async {
  final context = $.tester.element(find.byType(Navigator).first);
  GoRouter.of(context).push(path);

  final polls = timeout.inMilliseconds ~/ 500;
  for (var i = 0; i < polls; i++) {
    await $.pump(const Duration(milliseconds: 500));
    for (final key in keys) {
      if ($(key).exists) return key;
    }
  }
  return null;
}

/// Pops the pushed route through GoRouter. Patrol's `pressBack` is an
/// Android-only affordance and this suite runs on the iOS simulator too.
Future<void> _popRoute(PatrolIntegrationTester $) async {
  final context = $.tester.element(find.byType(Navigator).first);
  final router = GoRouter.of(context);
  if (router.canPop()) router.pop();
  await $.pump(const Duration(seconds: 1));
}

void main() {
  patrolTest(
    'App gate — the shell, the paywall and the food and vana routes agree',
    ($) async {
      await launchApp();
      await $.pump(const Duration(milliseconds: 500));

      if (!await ensureAuthenticated($)) {
        markTestSkipped(noAuthSkipMessage());
        return;
      }

      final locked = $(_paywallScreen).exists;

      if (locked) {
        // The actions sit behind the ⋯ button, which arrives with the page
        // after the opening clip.
        await $(_paywallMore).tap();
        await $.pumpAndSettle();
        for (final key in _paywallActions) {
          expect($(key).exists, isTrue, reason: 'paywall menu carries $key');
        }
        // Close the menu on its scrim.
        await $.tester.tapAt(const Offset(20, 700));
        await $.pumpAndSettle();
      }

      // ---- /food -------------------------------------------------------
      final foodLanding = await _pushAndSettleOn($, '/food', [
        _foodScreen,
        _paywallScreen,
      ]);
      expect(
        foodLanding,
        isNotNull,
        reason:
            '/food rendered neither the Food screen nor the paywall within 25 s',
      );
      expect(
        foodLanding,
        locked ? _paywallScreen : _foodScreen,
        reason: locked
            ? 'the paywall is up, so /food must stay on the paywall'
            : 'the shell is up, so /food must open the feature',
      );

      await _popRoute($);

      // ---- /vana -------------------------------------------------------
      final vanaLanding = await _pushAndSettleOn($, '/vana?mode=general', [
        _vanaScreen,
        _paywallScreen,
      ]);
      expect(
        vanaLanding,
        isNotNull,
        reason:
            '/vana rendered neither the Vana chat nor the paywall within 25 s',
      );
      expect(
        vanaLanding,
        locked ? _paywallScreen : _vanaScreen,
        reason: locked
            ? 'the paywall is up, so /vana must stay on the paywall'
            : 'the shell is up, so /vana must open the chat',
      );

      await _popRoute($);

      // ---- /paywall while unlocked yields to the shell -------------------
      if (!locked) {
        final paywallLanding = await _pushAndSettleOn($, '/paywall', [
          authSentinel,
          _paywallScreen,
        ]);
        expect(
          paywallLanding,
          authSentinel,
          reason: 'an entitled account pushing /paywall must land on the shell',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
