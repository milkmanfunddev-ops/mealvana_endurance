/// A paid athlete opens the Subscription screen and sees the plan running,
/// the day it renews as RevenueCat has it, Manage subscription and Redeem
/// code (testing-wave 08; mp-495, mp-494, mp-558, mp-628):
///
///   welcome → onboarding → Sign up with email at
///     `lee+e2e-subscription-<millis>` → paywall → Monthly → Continue
///     → Test Store sheet → "Test valid purchase" → the tabs shell
///     → the Entitlement row the RevenueCat webhook wrote, read as the account
///     → Settings → Subscription:
///       - the status is the active plan (not trial, founding, a Grant or
///         ended), and there is no Upgrade button
///       - the date line names the local day of RevenueCat's `pro` expiry, as
///         the webhook wrote it to `user_entitlements.active_until`
///       - Manage subscription shows (a store subscription is on record,
///         mp-558)
///       - Redeem code opens our own "Redeem a code" sheet (mp-494), and its
///         close button returns to the same screen
///     → back → Settings → Delete Account → welcome; the account is gone
///
/// What it cannot do: tap Manage subscription. It leaves the app for the
/// store's page (or Safari on a simulator), and Patrol runs inside the app's
/// process. The testing-wave agent taps it by hand. Nor does it check that the
/// status names the plan bought (Monthly): the screen reads "Subscribed" for
/// every store plan today (Findings 07-008, 08-001); mp-495 asks for the
/// status only, and triage decides whether mp-628's "the plan they bought"
/// means the plan's name.
///
/// Time: the Test Store monthly renews every 5 minutes and lapses about 25
/// minutes after the purchase (testing-wave Finding 05-003); this flow takes
/// a few minutes. A renewal between the row read and the screen can move the
/// date only across local midnight, which the flow allows for.
///
/// Writes on dev: one auth user, its profile rows and one `user_entitlements`
/// row (the webhook's), removed by the account delete. RevenueCat keeps the
/// Test Store customer; nothing is charged. A step that throws skips the
/// delete: find the account with `node scripts/testing-wave/sweep-accounts.mjs
/// list` for its ID, then `sweep-accounts.mjs delete --id ID --apply` (a bare
/// `delete --apply` also takes another run's live account). Needs a fresh
/// install (no session): it self-skips otherwise, like the signup flows. Dev
/// only, and only on a build whose RevenueCat key is the Test Store's
/// (`REVENUECAT_API_KEY_TEST` in `.env.dev.local`).
///
/// Run: patrol test --target integration_test/flows/subscription_screen_flow_test.dart \
///        --flavor dev --bundle-id com.milkman.mealvanaendurance.dev \
///        --dart-define-from-file=.env.dev.local \
///        --device "iPhone 17 Pro"
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:patrol/patrol.dart';

import '../helpers/e2e_account.dart';
import '../helpers/flow_launcher.dart';

const _shell = authSentinel;
const _subscriptionRow = ValueKey('settings.subscription_row');
const _status = ValueKey('subscription.status');
const _date = ValueKey('subscription.date');
const _manage = ValueKey('subscription.manage_button');
const _upgrade = ValueKey('subscription.upgrade_button');
const _redeem = ValueKey('subscription.redeem_code_button');
const _redeemSheet = ValueKey('redeem_code.sheet');
const _sheetClose = ValueKey('kyle_sheet_header.close');

void main() {
  patrolTest(
    'a paid athlete sees the running plan, its renewal day as RevenueCat has '
    'it, Manage subscription and Redeem code on the Subscription screen',
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
        tag: 'subscription-${DateTime.now().millisecondsSinceEpoch}',
      );
      await walkOnboardingToSignup($);
      await signUpToPaywall($, account);

      // ---- Buy Monthly through the Test Store ----------------------------
      await buyMonthlyInTestStore($);
      // Under the What's New scrim the shell exists but is not hit-testable.
      await _pumpUntil($, _shell);
      expect($(_shell).exists, isTrue, reason: 'the Gate opens after purchase');
      restoreTestErrorHandler();
      await dismissWhatsNew($);

      final failures = <String>[];
      void check(bool ok, String what) {
        if (!ok) failures.add(what);
      }

      // RevenueCat's expiry, as its webhook wrote it (1 s to 25 s after the
      // purchase in tickets 05 and 06).
      final rows = await entitlementRows(
        account,
        waitFor: const Duration(seconds: 90),
      );
      final activeUntil = rows == null || rows.length != 1
          ? null
          : DateTime.tryParse('${rows.single['active_until']}');
      check(
        activeUntil != null,
        'one Entitlement row with an active_until after the purchase '
        '(read: $rows)',
      );

      // ---- Settings → Subscription ---------------------------------------
      await openSettings($);
      await $(_subscriptionRow).scrollTo().tap(
        settlePolicy: SettlePolicy.noSettle,
      );
      await $(_status).waitUntilVisible(timeout: const Duration(seconds: 15));
      // The status and date come from an async read of the customer; give
      // them a beat to replace the loading state.
      await _pumpUntil($, _date, max: const Duration(seconds: 10));

      final status = _text($, _status);
      final dateLine = _text($, _date);
      check(
        status == 'Subscribed',
        'the status is the active store plan ("Subscribed"), read "$status"',
      );
      check(!$(_upgrade).exists, 'no Upgrade while the plan runs');
      if (activeUntil != null) {
        final day = activeUntil.toLocal();
        final days = {
          DateFormat.yMMMMd().format(day),
          // A renewal after the row read can cross local midnight.
          DateFormat.yMMMMd().format(day.add(const Duration(minutes: 10))),
        };
        check(
          dateLine != null &&
              dateLine.startsWith('Renews') &&
              days.any(dateLine.contains),
          'the date line renews on RevenueCat\'s expiry day $days, read '
          '"$dateLine"',
        );
      }
      check($(_manage).exists, 'Manage subscription shows (mp-558)');

      // ---- Redeem code opens our own sheet and closes back ---------------
      await $(_redeem).scrollTo().tap(settlePolicy: SettlePolicy.noSettle);
      await _pumpUntil($, _redeemSheet, max: const Duration(seconds: 10));
      check($(_redeemSheet).exists, 'Redeem code opens the Redeem a code sheet');
      if ($(_redeemSheet).exists) {
        check(
          $('Redeem a code').exists,
          'the sheet is our own "Redeem a code" entry (mp-494)',
        );
        await $(_sheetClose).tap(settlePolicy: SettlePolicy.noSettle);
        for (var i = 0; i < 30 && $(_redeemSheet).exists; i++) {
          await $.pump(const Duration(milliseconds: 200));
        }
        check(!$(_redeemSheet).exists, 'the sheet closes');
        check(
          $(_status).exists && _text($, _status) == status,
          'the Subscription screen is unchanged after the sheet closes',
        );
      }

      // ---- Back to Settings, delete the account --------------------------
      await $(
        const ValueKey('subscription.back_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $(
        const ValueKey('settings.title'),
      ).waitUntilVisible(timeout: const Duration(seconds: 15));
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

/// Pumps until [key] exists, for up to [max].
Future<void> _pumpUntil(
  PatrolIntegrationTester $,
  ValueKey<String> key, {
  Duration max = const Duration(seconds: 40),
}) async {
  final deadline = DateTime.now().add(max);
  while (!$(key).exists && DateTime.now().isBefore(deadline)) {
    await $.pump(const Duration(milliseconds: 100));
  }
}

/// The text of the [Text] widget keyed [key], or null when it is not there.
String? _text(PatrolIntegrationTester $, ValueKey<String> key) {
  final found = find.byKey(key).evaluate();
  if (found.isEmpty) return null;
  final widget = found.first.widget;
  return widget is Text ? widget.data : null;
}

/// Settings → Delete Account → Delete → welcome. The same steps as the
/// paid relogin flow's private helper; kept private here too, since ticket 09
/// was editing the shared helpers in parallel.
Future<void> _deleteFromSettings(PatrolIntegrationTester $) async {
  await $('Delete Account').scrollTo().tap(settlePolicy: SettlePolicy.noSettle);
  await $.pump(const Duration(milliseconds: 500));
  await $('Delete').last.tap(settlePolicy: SettlePolicy.noSettle);
  await $(
    const ValueKey('welcome.get_started_button'),
  ).waitUntilVisible(timeout: const Duration(seconds: 40));
}
