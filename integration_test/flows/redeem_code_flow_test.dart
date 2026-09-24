/// Redeem code from the paywall's ⋯ menu, as a new athlete (testing-wave 11,
/// mp-458, mp-535, mp-598):
///
///   welcome → onboarding → Sign up with email at `lee+e2e-redeem-<millis>`
///     → paywall → ⋯ → Redeem code
///     → a made-up code: "not recognised" under the field, the sheet stays open
///     → a code longer than any code can be: the same, the sheet stays open
///     → DEVCOACH30 (a dev coach code the athlete does not own): the sheet
///       closes, still on the paywall (a pairing gives no Pro), and a pending,
///       athlete-requested pairing with the code's coach is readable as the
///       athlete
///     → ⋯ → Redeem code → DEVCOACH30 again: "already used", the sheet stays open
///     → close the sheet → ⋯ → Delete account → welcome; the account is gone
///
/// What it cannot see: `code_redemptions` (service role only) and the
/// RevenueCat `coach_code` attribute. The testing-wave agent checks both by
/// SQL and API. A coach redeeming their OWN code (marked coach, 30 days of
/// Pro) needs the code's owner account and is not scripted here: a fresh
/// account never owns a code (testing-wave Finding 11-001).
///
/// Writes on dev: one `code_redemptions` row and one pending pairing with
/// DEVCOACH30's owner, both removed by the account delete (they cascade on
/// the user). A step that throws (a key that never shows) skips the delete:
/// an account left behind that way, with its pending pairing on the coach,
/// is swept by `node scripts/testing-wave/sweep-accounts.mjs delete --apply`.
/// Needs a fresh install (no session): it self-skips otherwise, like the
/// signup flows. Dev only. If the project asks for email confirmation, start
/// the code probe first:
///   node scripts/testing-wave/code-probe.mjs serve
///
/// Run: patrol test --target integration_test/flows/redeem_code_flow_test.dart \
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

/// A dev coach code (mp-458). Its owner is fixed on the `codes` row.
const _coachCode = 'DEVCOACH30';

/// No code on dev; 3 to 32 characters, the shape a real code has.
const _madeUpCode = 'NOTACODE11';

/// Longer than any code (codes are at most 32 characters, the server answers
/// 400 invalid_input, which the app reads as not found).
const _overlongCode = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789WXYZ';

const _sheet = ValueKey('redeem_code.sheet');
const _field = ValueKey('redeem_code.field');
const _submit = ValueKey('redeem_code.submit');
const _problem = ValueKey('redeem_code.problem');

void main() {
  patrolTest(
    'a new athlete redeems a coach code from the paywall menu: wrong and '
    'overlong codes are refused with the sheet open, the coach code opens a '
    'pending pairing, and a second try of it is refused',
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
        tag: 'redeem-${DateTime.now().millisecondsSinceEpoch}',
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

      // ---- 1. A made-up code: refused, the sheet stays open (mp-598) -----
      await _openRedeemSheet($);
      await _redeem($, _madeUpCode);
      check(
        _problemText($)?.contains("don't recognise") ?? false,
        'a made-up code shows the not-found reason under the field '
        '(saw: ${_problemText($)})',
      );
      check($(_sheet).exists, 'the sheet stays open after a made-up code');

      // ---- 2. An overlong code: refused as not found, sheet open ---------
      await _redeem($, _overlongCode);
      check(
        _problemText($)?.contains("don't recognise") ?? false,
        'an overlong code shows the not-found reason (saw: ${_problemText($)})',
      );
      check($(_sheet).exists, 'the sheet stays open after an overlong code');

      // ---- 3. The coach code: the sheet closes, a pending pairing --------
      await _redeem($, _coachCode);
      final closed = await _waitGone($, _sheet);
      check(closed, '$_coachCode closes the sheet (saw: ${_problemText($)})');
      check(
        $(const ValueKey('paywall.screen')).exists,
        'a pairing gives no Pro: the athlete stays on the paywall',
      );
      final pairings = await _pairingsOf(account);
      check(
        pairings != null &&
            pairings.length == 1 &&
            pairings.single['status'] == 'pending' &&
            pairings.single['requested_by'] == 'athlete',
        '$_coachCode leaves one pending, athlete-requested pairing '
        '(read: $pairings)',
      );

      // ---- 4. The same code again: already used, sheet open (mp-535) -----
      if (closed) await _openRedeemSheet($);
      await _redeem($, _coachCode);
      check(
        _problemText($)?.contains('already used') ?? false,
        'a second $_coachCode is refused as already used '
        '(saw: ${_problemText($)})',
      );
      check($(_sheet).exists, 'the sheet stays open after the second try');

      // ---- Close the sheet, delete the account from the menu -------------
      await $(
        const ValueKey('kyle_sheet_header.close'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await _waitGone($, _sheet);
      await _deleteFromPaywallMenu($);
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

/// ⋯ → Redeem code, waiting for the sheet's field. The paywall never settles
/// (its opening clip keeps animating), so every tap here is noSettle.
Future<void> _openRedeemSheet(PatrolIntegrationTester $) async {
  await $(
    const ValueKey('paywall.more_button'),
  ).tap(settlePolicy: SettlePolicy.noSettle);
  await $(
    const ValueKey('paywall.redeem_code_button'),
  ).waitUntilVisible(timeout: const Duration(seconds: 10));
  await $(
    const ValueKey('paywall.redeem_code_button'),
  ).tap(settlePolicy: SettlePolicy.noSettle);
  await $(_field).waitUntilVisible(timeout: const Duration(seconds: 10));
}

/// Types [code] over whatever is in the field and taps Redeem, then waits for
/// an answer: a reason under the field, or the sheet gone.
Future<void> _redeem(PatrolIntegrationTester $, String code) async {
  await $(_field).enterText(code, settlePolicy: SettlePolicy.noSettle);
  await $.pump(const Duration(milliseconds: 300));
  await $(_submit).tap(settlePolicy: SettlePolicy.noSettle);
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await $.pump(const Duration(milliseconds: 500));
    if (!$(_sheet).exists || $(_problem).exists) return;
  }
}

String? _problemText(PatrolIntegrationTester $) {
  final found = find.byKey(_problem).evaluate();
  if (found.isEmpty) return null;
  return (found.first.widget as Text).data;
}

Future<bool> _waitGone(PatrolIntegrationTester $, ValueKey<String> key) async {
  for (var i = 0; i < 20; i++) {
    if (!$(key).exists) return true;
    await $.pump(const Duration(milliseconds: 500));
  }
  return !$(key).exists;
}

/// The account's pairings, read as the account (RLS shows an athlete its own
/// rows), or null when the read failed.
Future<List<Map<String, dynamic>>?> _pairingsOf(E2eAccount account) async {
  final probe = await SupabaseProbe.signInAs(
    email: account.email,
    password: account.password,
  );
  if (probe == null) return null;
  return probe.trySelect(
    'coach_athlete_relationships',
    query:
        'athlete_user_id=eq.${probe.userId}'
        '&select=coach_user_id,status,requested_by',
  );
}

/// ⋯ → Delete account → confirm → welcome, with noSettle taps (the shared
/// helper's settling taps can wait out the paywall's animation).
Future<void> _deleteFromPaywallMenu(PatrolIntegrationTester $) async {
  await $(
    const ValueKey('paywall.more_button'),
  ).tap(settlePolicy: SettlePolicy.noSettle);
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
