/// A paid athlete's Pro ends: the app stays open until then, and afterwards
/// the account stays signed in on the full-screen paywall (testing-wave 09,
/// mp-457, mp-280, mp-629):
///
///   welcome → onboarding → Sign up with email at `lee+e2e-cancel-<millis>`
///     → paywall → Monthly → Continue → Test Store sheet → "Test valid purchase"
///     → the tabs shell (the Gate opens); one Entitlement row whose
///       `active_until` is in the future
///     → wait, with the app in the foreground, until the Test Store monthly
///       lapses on its own (testing-wave Finding 05-003: four 5-minute
///       renewals, then expired, about 25 minutes after the purchase). The
///       row's `active_until` stays in the past for [_lapseSettle] before the
///       flow calls it lapsed, because a renewal can land minutes after the
///       period end (06-002, 07-003).
///     → Home, then back to the app (a resume: 05-005 saw a foreground app
///       stay open after the lapse until the next resume)
///     → the full-screen paywall, no close or back control, not poppable;
///       still signed in as the account
///     → ⋯: Restore purchases, Redeem code, Manage subscription (the account
///       has a subscription to manage), Sign out, Delete account (mp-280)
///     → one `vana-chat` message with the account's own token is refused
///       with 403 `{error: pro_required}` (the refusal comes before the budget
///       and the model, so it costs nothing)
///     → the account's `users` row and its Entitlement row are still there
///       (mp-280: data is kept)
///     → ⋯ → Delete account → welcome; the account is gone
///
/// Stands in for the cancellation: the Test Store sheet offers no cancel,
/// so the natural lapse is the end of the period here (the testing-wave agent
/// tries Manage subscription by hand). Any read-only mode, plan-ended bar or
/// paywall sheet would fail the "full-screen paywall" check.
///
/// What it cannot do: a cold start (Patrol runs inside the app's process, so
/// terminating the app ends the test) and RevenueCat's side of the end date.
/// The testing-wave agent checks both by hand (`simctl terminate` + `launch`,
/// the RevenueCat API), and keeps its own lapsed account for ticket 10.
///
/// Time: about 30 minutes, nearly all of it the wait. The test times out at
/// 45 minutes; wrap the run in a shell timeout too (a hung Patrol run once
/// took the simulator down, 06-009).
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
/// Run: timeout 3300 patrol test \
///        --target integration_test/flows/cancellation_flow_test.dart \
///        --flavor dev --bundle-id com.milkman.mealvanaendurance.dev \
///        --dart-define-from-file=.env.dev.local \
///        --device "iPhone 17 Pro"
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:patrol/patrol.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/e2e_account.dart';
import '../helpers/flow_launcher.dart';
import '../helpers/supabase_probe.dart';
import '../helpers/test_config.dart';

const _paywall = ValueKey('paywall.screen');
const _more = ValueKey('paywall.more_button');
const _shell = authSentinel;

/// How long the row's `active_until` must stay in the past before the flow
/// calls the subscription lapsed. Renewals have landed up to about 4 minutes
/// after the period end (05: 08:55:45 → 08:59:37).
const _lapseSettle = Duration(minutes: 6);

/// The Test Store monthly lapsed 25 minutes after purchase in ticket 05; this
/// leaves room for late renewals and the settle window.
const _lapseDeadline = Duration(minutes: 38);

void main() {
  patrolTest(
    'a paid athlete keeps the app until Pro ends, then stays signed in on '
    'the full-screen paywall with the ⋯ menu, the server refuses AI, and '
    'the data is kept',
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
        tag: 'cancel-${DateTime.now().millisecondsSinceEpoch}',
      );
      await walkOnboardingToSignup($);
      await signUpToPaywall($, account);

      // ---- Buy Monthly: the Gate opens -----------------------------------
      await buyMonthlyInTestStore($);
      await _pumpUntil($, (_) => $(_shell).exists);
      expect($(_shell).exists, isTrue, reason: 'the Gate opens after purchase');
      restoreTestErrorHandler();
      await dismissWhatsNew($);

      final failures = <String>[];
      void check(bool ok, String what) {
        if (!ok) failures.add(what);
      }

      final bought = await entitlementRows(
        account,
        waitFor: const Duration(seconds: 90),
      );
      final firstEnd = _activeUntil(bought);
      check(
        firstEnd != null && firstEnd.isAfter(DateTime.now().toUtc()),
        'one Entitlement row in the future after the purchase (read: $bought)',
      );

      // ---- Before the end: the app stays open ----------------------------
      check(
        $(_shell).exists && !$(_paywall).exists,
        'the app is open, not the paywall, while Pro is live',
      );

      // ---- Wait for the lapse, app in the foreground ---------------------
      final lapsedAt = await _waitForLapse($, account);
      expect(
        lapsedAt,
        isNotNull,
        reason:
            'The Test Store monthly did not lapse within '
            '${_lapseDeadline.inMinutes} minutes of the purchase '
            '(testing-wave 05-003 saw 25). Last row: '
            '${await entitlementRows(account)}',
      );
      // ignore: avoid_print
      print('[cancellation] lapsed; active_until $lapsedAt');

      // ---- Resume: the full-screen paywall, still signed in --------------
      await $.platform.mobile.pressHome();
      await Future<void>.delayed(const Duration(seconds: 3));
      await $.platform.mobile.openApp();
      await _pumpUntil($, (_) => $(_more).exists, within: 40);
      expect(
        $(_paywall).exists,
        isTrue,
        reason:
            'mp-280: after Pro ends the app lands on the full-screen paywall '
            'on resume',
      );
      _expectNoWayOffThePaywall($);
      final session = Supabase.instance.client.auth.currentSession;
      expect(
        session?.user.email?.toLowerCase(),
        account.email.toLowerCase(),
        reason: 'mp-280: the account stays signed in after Pro ends',
      );

      // ---- The ⋯ menu (mp-280, mp-494) -----------------------------------
      await $(_more).tap(settlePolicy: SettlePolicy.noSettle);
      for (final key in const [
        ValueKey('paywall.restore_button'),
        ValueKey('paywall.redeem_code_button'),
        ValueKey('paywall.manage_button'),
        ValueKey('paywall.sign_out_button'),
        ValueKey('paywall.delete_account_button'),
      ]) {
        await $(key).waitUntilVisible(timeout: const Duration(seconds: 10));
        check($(key).exists, 'mp-280: the paywall ⋯ menu carries $key');
      }
      await $.tester.tapAt(const Offset(20, 700));
      await $.pump(const Duration(seconds: 1));

      // ---- The server refuses AI on its own (mp-457) ---------------------
      final res = await _sendVanaMessage(session!);
      // ignore: avoid_print
      print('[cancellation] vana-chat ${res.statusCode} ${res.body}');
      check(
        res.statusCode == 403 &&
            (jsonDecode(res.body) as Map<String, dynamic>)['error'] ==
                'pro_required',
        'mp-457: the server refuses a Vana message without Pro '
        '(${res.statusCode} ${res.body})',
      );

      // ---- The data is kept (mp-280) -------------------------------------
      final probe = await SupabaseProbe.signInAs(
        email: account.email,
        password: account.password,
      );
      final userRow = await probe?.userRow();
      final after = await entitlementRows(account);
      check(userRow != null, 'mp-280: the users row is kept after Pro ends');
      check(
        after != null && after.length == 1,
        'the Entitlement row is kept after Pro ends (read: $after)',
      );

      // ---- Delete the throwaway account from the paywall menu ------------
      await deleteFromPaywallMenu($);
      expect(
        await account.isGone(),
        isTrue,
        reason: '${account.email} can still sign in after Delete account.',
      );

      expect(failures, isEmpty, reason: failures.join('\n'));
    },
    timeout: const Timeout(Duration(minutes: 45)),
  );
}

DateTime? _activeUntil(List<Map<String, dynamic>>? rows) {
  final raw = rows?.firstOrNull?['active_until'] as String?;
  return raw == null ? null : DateTime.parse(raw).toUtc();
}

/// Polls the row every 30 s, keeping the app pumped, until its
/// `active_until` has stayed in the past for [_lapseSettle]. Returns that
/// `active_until`, or null when [_lapseDeadline] passes first.
Future<DateTime?> _waitForLapse(
  PatrolIntegrationTester $,
  E2eAccount account,
) async {
  final deadline = DateTime.now().add(_lapseDeadline);
  DateTime? pastSince;
  while (DateTime.now().isBefore(deadline)) {
    final until = _activeUntil(await entitlementRows(account));
    final now = DateTime.now().toUtc();
    if (until != null && until.isBefore(now)) {
      pastSince ??= now;
      if (now.difference(pastSince) >= _lapseSettle) return until;
    } else {
      pastSince = null;
    }
    for (var i = 0; i < 30; i++) {
      await $.pump(const Duration(seconds: 1));
    }
  }
  return null;
}

/// Pumps every 100 ms until [done] holds, for up to [within] seconds.
Future<void> _pumpUntil(
  PatrolIntegrationTester $,
  bool Function(PatrolIntegrationTester) done, {
  int within = 40,
}) async {
  for (var i = 0; i < within * 10 && !done($); i++) {
    await $.pump(const Duration(milliseconds: 100));
  }
}

/// mp-457 / mp-280: the closed Gate is the full-screen paywall, with no close
/// or back control and nothing under it to pop back to. Same checks as the
/// signup flow's private copy.
void _expectNoWayOffThePaywall(PatrolIntegrationTester $) {
  final screen = find.byKey(_paywall);
  expect(screen, findsOneWidget, reason: 'the paywall is the screen shown');
  for (final escape in [
    find.byType(CloseButton),
    find.byType(BackButton),
    find.byIcon(Icons.close),
    find.byIcon(Icons.close_rounded),
    find.byIcon(Icons.arrow_back),
    find.byIcon(Icons.arrow_back_ios),
    find.byIcon(Icons.arrow_back_ios_new),
  ]) {
    expect(
      find.descendant(of: screen, matching: escape),
      findsNothing,
      reason: 'mp-457: the paywall has no close button ($escape)',
    );
  }
  final route = ModalRoute.of($.tester.element(screen));
  expect(
    route?.canPop ?? false,
    isFalse,
    reason:
        'mp-457: the lapsed paywall is a full screen with nothing behind it, '
        'not a sheet over the app',
  );
}

/// One Vana message straight to `vana-chat` as the signed-in athlete.
Future<http.Response> _sendVanaMessage(Session session) => http
    .post(
      Uri.parse('${TestConfig.supabaseUrl}/functions/v1/vana-chat'),
      headers: {
        'apikey': TestConfig.supabaseAnonKey,
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'kind': 'general',
        'message': 'How much carbohydrate should I eat before a long run?',
      }),
    )
    .timeout(const Duration(seconds: 30));
