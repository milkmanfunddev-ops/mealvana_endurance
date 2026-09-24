/// A paid athlete signs out and back in and never meets the paywall
/// (testing-wave 06, mp-457, mp-335, mp-626):
///
///   welcome → onboarding → Sign up with email at `lee+e2e-relogin-<millis>`
///     → paywall → Monthly → Continue → Test Store sheet → "Test valid purchase"
///     → the tabs shell (the Gate opens)
///     → Settings → Sign Out → confirm → welcome, and no paywall on the way
///     → Log in → Email → the same address and password → the tabs shell,
///       and no paywall frame at any pump on the way (mp-335: "an account
///       with access can never see it")
///     → the Entitlement row is still there, read as the account
///     → Settings → Delete account → welcome; the account is gone
///
/// What it cannot do: a cold start. Patrol runs inside the app's process, so
/// terminating the app ends the test. The testing-wave agent checks the cold
/// relaunch by hand (`simctl terminate` + `launch`), and RevenueCat by API.
///
/// Time: the Test Store monthly renews every 5 minutes and lapses about 25
/// minutes after the purchase (testing-wave Finding 05-003); this flow takes
/// a few minutes, well inside that.
///
/// Writes on dev: one auth user, its profile rows and one `user_entitlements`
/// row (the webhook's), removed by the account delete. RevenueCat keeps the
/// Test Store customer; nothing is charged. A step that throws skips the
/// delete: find the account with `node scripts/testing-wave/sweep-accounts.mjs
/// list` for its ID, then `sweep-accounts.mjs delete --id ID --apply` (a bare
/// `delete --apply` also takes another run's live account). Needs a fresh install (no session): it self-skips otherwise,
/// like the signup flows. Dev only, and only on a build whose RevenueCat key
/// is the Test Store's (`REVENUECAT_API_KEY_TEST` in `.env.dev.local`).
///
/// Run: patrol test --target integration_test/flows/paid_relogin_flow_test.dart \
///        --flavor dev --bundle-id com.milkman.mealvanaendurance.dev \
///        --dart-define-from-file=.env.dev.local \
///        --device "iPhone 17 Pro"
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../helpers/e2e_account.dart';
import '../helpers/flow_launcher.dart';

const _paywall = ValueKey('paywall.screen');
const _shell = authSentinel;
const _welcomeLogIn = ValueKey('welcome.log_in_button');

void main() {
  patrolTest(
    'a paid athlete signs out and back in and lands in the app with no '
    'paywall, and keeps the Entitlement row',
    ($) async {
      if (!e2eAccountsAllowed) {
        skipFlow('Throwaway accounts are made on dev only.');
        return;
      }
      await launchApp($);
      await $.pump(const Duration(seconds: 2));
      if (!await onWelcomeScreen($)) {
        skipFlow(
          'Not on the welcome screen (a session is present). Reinstall the '
          'app for a clean signup run.',
        );
        return;
      }

      final account = E2eAccount.fresh(
        tag: 'relogin-${DateTime.now().millisecondsSinceEpoch}',
      );
      await walkOnboardingToSignup($);
      await signUpToPaywall($, account);

      // ---- Buy Monthly through the Test Store ----------------------------
      await buyMonthlyInTestStore($);
      // The shell is under the What's New sheet's scrim on a first entry, so
      // wait for it to exist, not to be hit-testable (testing-wave 06's first
      // run failed on waitUntilVisible here).
      await _waitFor($, _shell);
      expect($(_shell).exists, isTrue, reason: 'the Gate opens after purchase');
      restoreTestErrorHandler();
      await dismissWhatsNew($);

      final failures = <String>[];
      void check(bool ok, String what) {
        if (!ok) failures.add(what);
      }

      // The webhook writes the row; it landed 1 s (ticket 05) to 25 s
      // (ticket 06) after the purchase.
      final before = await entitlementRows(
        account,
        waitFor: const Duration(seconds: 90),
      );
      check(
        before != null && before.length == 1,
        'one Entitlement row after the purchase (read: $before)',
      );

      // ---- Sign out: welcome, never the paywall --------------------------
      await openSettings($);
      await signOutFromSettings($);
      final sawPaywallOut = await _waitFor($, _welcomeLogIn);
      check(!sawPaywallOut, 'no paywall frame between Sign Out and welcome');
      check($(_welcomeLogIn).exists, 'Sign Out lands on the welcome screen');

      // ---- Sign in: the tabs shell, never the paywall --------------------
      await logInWithEmail($, account);
      final sawPaywallIn = await _waitFor($, _shell);
      check(!sawPaywallIn, 'no paywall frame between Log in and the app');
      check($(_shell).exists, 'Log in lands in the app');

      final after = await entitlementRows(account);
      check(
        after != null &&
            after.length == 1 &&
            after.single['period_type'] == before?.firstOrNull?['period_type'],
        'still one Entitlement row after sign-in, same period type '
        '(before: $before, after: $after)',
      );

      // ---- Delete the account from Settings ------------------------------
      await dismissWhatsNew($);
      await openSettings($);
      await _deleteFromSettings($);
      expect(
        await account.isGone(),
        isTrue,
        reason: '${account.email} can still sign in after Delete account.',
      );

      expect(failures, isEmpty, reason: failures.join('\n'));
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}

/// Pumps until [key] shows, for up to 40 s. Returns true when the paywall
/// showed at any pump on the way.
Future<bool> _waitFor(PatrolIntegrationTester $, ValueKey<String> key) async {
  var sawPaywall = false;
  for (var i = 0; i < 400; i++) {
    if ($(_paywall).exists) sawPaywall = true;
    if ($(key).exists) break;
    await $.pump(const Duration(milliseconds: 100));
  }
  return sawPaywall;
}

Future<void> _deleteFromSettings(PatrolIntegrationTester $) async {
  await $('Delete Account').scrollTo().tap(settlePolicy: SettlePolicy.noSettle);
  await $.pump(const Duration(milliseconds: 500));
  await $('Delete').last.tap(settlePolicy: SettlePolicy.noSettle);
  await $(
    const ValueKey('welcome.get_started_button'),
  ).waitUntilVisible(timeout: const Duration(seconds: 40));
}
