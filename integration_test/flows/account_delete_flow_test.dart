/// Sign up, meet the paywall, delete the account from its ⋯ menu, then sign
/// up again at the same address and get a new account (testing-wave 02,
/// mp-494, mp-622).
///
///   welcome → onboarding → Sign up with email at `lee+e2e-<millis>`
///     → paywall (a new account is never paid) → ⋯ → Delete account → confirm
///     → welcome; the account can no longer sign in
///     → onboarding → sign up again at the same address → a NEW user id,
///       and the paywall again (the Gate treats it as never paid)
///     → ⋯ → Delete account → welcome; gone again
///
/// What it cannot see: the database rows the delete removes (RLS hides a
/// deleted account's rows from everyone but the service role) and what
/// RevenueCat keeps. The testing-wave agent checks both by SQL and API
/// (`node scripts/testing-wave/sweep-accounts.mjs footprint <id>`). An
/// account this flow leaves behind after a failure is swept by
/// `sweep-accounts.mjs delete --apply`.
///
/// Needs a fresh install (no session): it self-skips otherwise, like the
/// onboarding signup flow. Dev only. If the project asks for email
/// confirmation, start the code probe first:
///   node scripts/testing-wave/code-probe.mjs serve
///
/// Run: patrol test --target integration_test/flows/account_delete_flow_test.dart \
///        --flavor dev --dart-define-from-file=.env.dev.local \
///        --device "iPhone 17 Pro"
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../helpers/e2e_account.dart';
import '../helpers/flow_launcher.dart';

void main() {
  patrolTest(
    'a new account deletes itself from the paywall menu and the same address '
    'then signs up as a new, never-paid account',
    ($) async {
      if (!e2eAccountsAllowed) {
        markTestSkipped('Throwaway accounts are made on dev only.');
        return;
      }
      await launchApp();
      await $.tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(minutes: 2),
      );
      if (!await onWelcomeScreen($)) {
        markTestSkipped(
          'Not on the welcome screen (a session is present). Reinstall the '
          'app for a clean signup run.',
        );
        return;
      }

      // ---- First account: sign up, meet the paywall, delete it ---------
      final first = E2eAccount.fresh();
      await walkOnboardingToSignup($);
      await signUpToPaywall($, first);
      expect(
        $(const ValueKey('paywall.continue_button')),
        findsOneWidget,
        reason: 'a new account meets the paywall (never paid)',
      );
      final firstId = await first.userId(
        waitFor: const Duration(seconds: 20),
      );
      expect(firstId, isNotNull, reason: '${first.email} signed up');

      await deleteFromPaywallMenu($);
      expect(
        await first.isGone(),
        isTrue,
        reason:
            'After Delete account, ${first.email} must no longer sign in: the '
            'auth user is gone. A delete that fails server-side still signs '
            'the app out, so the welcome screen alone proves nothing.',
      );

      // ---- Same address again: a new account, still never paid --------
      final second = first.again();
      await walkOnboardingToSignup($);
      await signUpToPaywall($, second);
      expect(
        $(const ValueKey('paywall.continue_button')),
        findsOneWidget,
        reason: 'the re-created account meets the paywall like any new one',
      );
      await $(const ValueKey('paywall.more_button')).tap();
      expect(
        $(const ValueKey('paywall.manage_button')),
        findsNothing,
        reason: 'no subscription to manage on a never-paid account (mp-494)',
      );
      await $.tester.tapAt(const Offset(20, 700));
      await $.pumpAndSettle();

      final secondId = await second.userId(
        waitFor: const Duration(seconds: 20),
      );
      expect(secondId, isNotNull, reason: 'the second signup landed');
      expect(
        secondId,
        isNot(firstId),
        reason: 'signing up again after a delete makes a new user id',
      );

      await deleteFromPaywallMenu($);
      expect(await second.isGone(), isTrue, reason: 'second delete landed');
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
