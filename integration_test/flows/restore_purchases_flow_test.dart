/// Restore purchases from the paywall's ⋯ menu, as a new athlete with nothing
/// to restore (testing-wave 07, mp-494; Finding 04-003):
///
///   welcome → onboarding → Sign up with email at `lee+e2e-restore-<millis>`
///     → paywall → ⋯ → Restore purchases
///     → the "nothing found" message; still on the paywall; no
///       `user_entitlements` row for the account
///     → ⋯ again: still no Manage subscription (nothing to manage)
///     → ⋯ → Delete account → welcome; the account is gone
///
/// What it cannot do: the ticket's own scenario. A Patrol flow cannot delete
/// and reinstall the app it runs in, and on dev a Test Store purchase is held
/// by RevenueCat against the signed-in account, so signing in after a
/// reinstall finds Pro without Restore (testing-wave run 07). A restore that
/// brings a subscription back needs a store receipt on the device (Apple
/// sandbox, Lee's iPhone ticket). The testing-wave agent checks RevenueCat.
///
/// Writes on dev: one throwaway account, removed by its own delete. A step
/// that throws (a key that never shows) skips the delete; find its id with
/// `node scripts/testing-wave/sweep-accounts.mjs list`, then
/// `sweep-accounts.mjs delete --id ID --apply` (a bare `delete --apply`
/// also takes another run's live account).
/// Needs a fresh install (no session): it self-skips otherwise, like the
/// signup flows. Dev only. If the project asks for email confirmation, start
/// the code probe first:
///   node scripts/testing-wave/code-probe.mjs serve
///
/// Run: patrol test --target integration_test/flows/restore_purchases_flow_test.dart \
///        --flavor dev --bundle-id com.milkman.mealvanaendurance.dev \
///        --dart-define-from-file=.env.dev.local \
///        --device "iPhone 17 Pro"
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../helpers/e2e_account.dart';
import '../helpers/flow_launcher.dart';

/// `paywall.restore_none` in content_defaults.json, the start of it.
const _nothingFound = 'No active subscription was found';

const _paywall = ValueKey('paywall.screen');
const _more = ValueKey('paywall.more_button');
const _restore = ValueKey('paywall.restore_button');
const _manage = ValueKey('paywall.manage_button');

void main() {
  patrolTest(
    'a new athlete taps Restore purchases on the paywall: nothing is found, '
    'the paywall stays, no entitlement row appears, and Manage stays hidden',
    ($) async {
      if (!e2eAccountsAllowed) {
        skipFlow('Throwaway accounts are made on dev only.');
        return;
      }
      await launchApp($);
      await $.tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(minutes: 2),
      );
      if (!await onWelcomeScreen($)) {
        skipFlow(
          'Not on the welcome screen (a session is present). Reinstall the '
          'app for a clean signup run.',
        );
        return;
      }

      final account = E2eAccount.fresh(
        tag: 'restore-${DateTime.now().millisecondsSinceEpoch}',
      );
      await walkOnboardingToSignup($);
      await signUpToPaywall($, account);

      // Every check below reports only after the account is deleted, so a
      // failed check leaves nothing on dev (a thrown wait still does; see the
      // header).
      final failures = <String>[];
      void check(bool ok, String what) {
        if (!ok) failures.add(what);
      }

      // ---- ⋯ → Restore purchases: nothing found, still on the paywall ----
      await _openMenu($);
      await $(_restore).tap(settlePolicy: SettlePolicy.noSettle);
      final message = await _waitForText($, _nothingFound);
      check(message, 'Restore shows "$_nothingFound…" for a new account');
      check($(_paywall).exists, 'the account stays on the paywall');

      final rows = await entitlementRows(account);
      check(
        rows != null && rows.isEmpty,
        'no user_entitlements row after a restore with nothing to restore '
        '(read: $rows)',
      );

      // ---- ⋯ again: Manage still hidden (nothing to manage, mp-494) ------
      await _openMenu($);
      check(
        !$(_manage).exists,
        'Manage subscription stays out of the menu after an empty restore',
      );

      // ---- Delete the account from the menu (already open) --------------
      await _deleteFromOpenMenu($);
      expect(
        await account.isGone(),
        isTrue,
        reason: '${account.email} can still sign in after Delete account.',
      );

      expect(failures, isEmpty, reason: failures.join('\n'));
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

/// Opens the ⋯ menu and waits for Restore purchases. The paywall never
/// settles (its opening clip keeps animating), so every tap is noSettle.
Future<void> _openMenu(PatrolIntegrationTester $) async {
  await $(_more).tap(settlePolicy: SettlePolicy.noSettle);
  await $(_restore).waitUntilVisible(timeout: const Duration(seconds: 10));
}

/// Pumps until a Text containing [text] shows, up to 30 s (the restore goes
/// to RevenueCat and back).
Future<bool> _waitForText(PatrolIntegrationTester $, String text) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await $.pump(const Duration(milliseconds: 500));
    if (find.textContaining(text).evaluate().isNotEmpty) return true;
  }
  return false;
}

/// Delete account → confirm → welcome, from a menu that is already open.
Future<void> _deleteFromOpenMenu(PatrolIntegrationTester $) async {
  await $(
    const ValueKey('paywall.delete_account_button'),
  ).waitUntilVisible(timeout: const Duration(seconds: 10));
  await $(
    const ValueKey('paywall.delete_account_button'),
  ).tap(settlePolicy: SettlePolicy.noSettle);
  await $(
    const ValueKey('paywall.confirm.action'),
  ).waitUntilVisible(timeout: const Duration(seconds: 10));
  await $(
    const ValueKey('paywall.confirm.action'),
  ).tap(settlePolicy: SettlePolicy.noSettle);
  await $(
    const ValueKey('welcome.get_started_button'),
  ).waitUntilVisible(timeout: const Duration(seconds: 40));
}
