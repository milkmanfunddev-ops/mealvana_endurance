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
import '../helpers/supabase_probe.dart';

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
      await _buyMonthly($);
      // The shell is under the What's New sheet's scrim on a first entry, so
      // wait for it to exist, not to be hit-testable (testing-wave 06's first
      // run failed on waitUntilVisible here).
      await _waitFor($, _shell);
      expect($(_shell).exists, isTrue, reason: 'the Gate opens after purchase');
      restoreTestErrorHandler();
      await _dismissWhatsNew($);

      final failures = <String>[];
      void check(bool ok, String what) {
        if (!ok) failures.add(what);
      }

      // The webhook writes the row; it landed 1 s (ticket 05) to 25 s
      // (ticket 06) after the purchase.
      final before = await _entitlementRows(
        account,
        waitFor: const Duration(seconds: 90),
      );
      check(
        before != null && before.length == 1,
        'one Entitlement row after the purchase (read: $before)',
      );

      // ---- Sign out: welcome, never the paywall --------------------------
      await _openSettings($);
      await _signOut($);
      final sawPaywallOut = await _waitFor($, _welcomeLogIn);
      check(!sawPaywallOut, 'no paywall frame between Sign Out and welcome');
      check($(_welcomeLogIn).exists, 'Sign Out lands on the welcome screen');

      // ---- Sign in: the tabs shell, never the paywall --------------------
      await _logIn($, account);
      final sawPaywallIn = await _waitFor($, _shell);
      check(!sawPaywallIn, 'no paywall frame between Log in and the app');
      check($(_shell).exists, 'Log in lands in the app');

      final after = await _entitlementRows(account);
      check(
        after != null &&
            after.length == 1 &&
            after.single['period_type'] == before?.firstOrNull?['period_type'],
        'still one Entitlement row after sign-in, same period type '
        '(before: $before, after: $after)',
      );

      // ---- Delete the account from Settings ------------------------------
      await _dismissWhatsNew($);
      await _openSettings($);
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

/// Monthly → Continue → the Test Store's native alert → "Test valid
/// purchase". The paywall never settles, so taps are noSettle.
Future<void> _buyMonthly(PatrolIntegrationTester $) async {
  await $(
    const ValueKey('paywall.plan.monthly'),
  ).tap(settlePolicy: SettlePolicy.noSettle);
  await $(
    const ValueKey('paywall.continue_button'),
  ).tap(settlePolicy: SettlePolicy.noSettle);
  // The Test Store sheet is an in-app UIKit alert with the buttons "Test
  // valid purchase", "Test failed purchase" and "Cancel" (testing-wave 05).
  await $.platform.tap(
    IOSSelector(label: 'Test valid purchase'),
    timeout: const Duration(seconds: 20),
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

/// Taps "Got it" on the What's New sheet when it shows within [wait]. It
/// opens over the first screen after the Gate opens.
Future<void> _dismissWhatsNew(
  PatrolIntegrationTester $, {
  Duration wait = const Duration(seconds: 5),
}) async {
  const cta = ValueKey('whats_new.cta');
  final deadline = DateTime.now().add(wait);
  while (DateTime.now().isBefore(deadline)) {
    if ($(cta).exists) {
      await $(cta).tap(settlePolicy: SettlePolicy.noSettle);
      for (var i = 0; i < 20 && $(cta).exists; i++) {
        await $.pump(const Duration(milliseconds: 200));
      }
      return;
    }
    await $.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _openSettings(PatrolIntegrationTester $) async {
  await $(
    const ValueKey('kyle_date_header.settings'),
  ).tap(settlePolicy: SettlePolicy.noSettle);
  await $(
    const ValueKey('settings.title'),
  ).waitUntilVisible(timeout: const Duration(seconds: 15));
}

Future<void> _signOut(PatrolIntegrationTester $) async {
  await $('Sign Out').scrollTo().tap(settlePolicy: SettlePolicy.noSettle);
  await $.pump(const Duration(milliseconds: 500));
  // The confirm dialog's action repeats the label.
  await $('Sign Out').last.tap(settlePolicy: SettlePolicy.noSettle);
}

Future<void> _logIn(PatrolIntegrationTester $, E2eAccount account) async {
  // Sign-out lands on welcome mid-transition; a tap before the route settles
  // is dropped (testing-wave 06's second run), so wait, then tap until the
  // login options show.
  await $(_welcomeLogIn).waitUntilVisible(timeout: const Duration(seconds: 15));
  const emailOption = ValueKey('login_options.email_button');
  for (var i = 0; i < 3 && !$(emailOption).exists; i++) {
    await $.pump(const Duration(seconds: 1));
    if ($(_welcomeLogIn).exists) {
      await $(_welcomeLogIn).tap(settlePolicy: SettlePolicy.noSettle);
    }
    for (var j = 0; j < 20 && !$(emailOption).exists; j++) {
      await $.pump(const Duration(milliseconds: 250));
    }
  }
  await $(emailOption).waitUntilVisible(timeout: const Duration(seconds: 15));
  await $(const ValueKey('login_options.email_button')).tap();
  await $(
    const ValueKey('login.email_field'),
  ).waitUntilVisible(timeout: const Duration(seconds: 15));
  await $(const ValueKey('login.email_field')).enterText(account.email);
  await $(const ValueKey('login.password_field')).enterText(account.password);
  await $(
    const ValueKey('login.log_in_button'),
  ).tap(settlePolicy: SettlePolicy.noSettle);
}

Future<void> _deleteFromSettings(PatrolIntegrationTester $) async {
  await $('Delete Account').scrollTo().tap(settlePolicy: SettlePolicy.noSettle);
  await $.pump(const Duration(milliseconds: 500));
  await $('Delete').last.tap(settlePolicy: SettlePolicy.noSettle);
  await $(
    const ValueKey('welcome.get_started_button'),
  ).waitUntilVisible(timeout: const Duration(seconds: 40));
}

/// The account's Entitlement rows, read as the account (RLS shows an athlete
/// its own row), or null when the read failed. Polls for [waitFor] until a
/// row shows.
Future<List<Map<String, dynamic>>?> _entitlementRows(
  E2eAccount account, {
  Duration waitFor = Duration.zero,
}) async {
  final deadline = DateTime.now().add(waitFor);
  while (true) {
    final probe = await SupabaseProbe.signInAs(
      email: account.email,
      password: account.password,
    );
    final rows = probe == null
        ? null
        : await probe.trySelect(
            'user_entitlements',
            query: 'user_id=eq.${probe.userId}&select=active_until,period_type',
          );
    if ((rows != null && rows.isNotEmpty) ||
        !DateTime.now().isBefore(deadline)) {
      return rows;
    }
    await Future<void>.delayed(const Duration(seconds: 3));
  }
}
