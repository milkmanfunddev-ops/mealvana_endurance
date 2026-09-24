/// A throwaway account for flows that sign up, meet the paywall and delete
/// themselves (testing-wave ticket 02).
///
/// **Addresses.** Every account is `lee+e2e-<tag>@rightpathprogramming.com`,
/// the only shape `scripts/testing-wave/sweep-accounts.mjs` may delete, so an
/// account a failed run leaves behind is swept later and nothing else ever is.
/// The tag defaults to epoch millis, unique per run.
///
/// **Codes.** When the project asks for email confirmation, signup stops on
/// the verify screen. The flow cannot open a mailbox, so it asks the code
/// probe: `node scripts/testing-wave/code-probe.mjs serve` on the Mac, which
/// has the dev Auth admin API generate the code (and sends no email). The
/// simulator shares the Mac's loopback, so the default URL works on iOS; pass
/// `--dart-define=E2E_CODE_PROBE_URL=...` to point elsewhere (Android
/// emulators reach the Mac at 10.0.2.2). Dev auto-confirms signups as of
/// 2026-09-23, so the verify screen, and the probe, only come into play if
/// that setting changes.
///
/// **Passwords** are random per account and live only in this run's memory;
/// the account is deleted by the same flow.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:patrol/patrol.dart';

import 'supabase_probe.dart';
import 'test_config.dart';

/// One signup's address and password.
class E2eAccount {
  E2eAccount._(this.email, this.password);

  /// A new `lee+e2e-<tag>` address with a random password.
  factory E2eAccount.fresh({String? tag}) {
    final t = tag ?? '${DateTime.now().millisecondsSinceEpoch}';
    return E2eAccount._('lee+e2e-$t@rightpathprogramming.com', _password());
  }

  /// The same address again with a new password: signing up again after a
  /// delete must start a new account.
  E2eAccount again() => E2eAccount._(email, _password());

  final String email;
  final String password;

  static String _password() {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(15, (_) => r.nextInt(256)));
  }

  /// The auth user id behind this address and password, or null when the
  /// account cannot sign in (deleted, or not there yet). Polls for
  /// [waitFor] because the auth row can trail the screen by a beat.
  Future<String?> userId({Duration waitFor = Duration.zero}) async {
    final deadline = DateTime.now().add(waitFor);
    while (true) {
      final probe = await SupabaseProbe.signInAs(
        email: email,
        password: password,
      );
      if (probe != null) return probe.userId;
      if (!DateTime.now().isBefore(deadline)) return null;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  /// True once this account can no longer sign in, polled for [waitFor].
  Future<bool> isGone({Duration waitFor = const Duration(seconds: 30)}) async {
    final deadline = DateTime.now().add(waitFor);
    while (true) {
      final probe = await SupabaseProbe.signInAs(
        email: email,
        password: password,
      );
      if (probe == null) return true;
      if (!DateTime.now().isBefore(deadline)) return false;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }
}

/// The host-side code probe (scripts/testing-wave/code-probe.mjs).
class CodeProbe {
  static const url = String.fromEnvironment(
    'E2E_CODE_PROBE_URL',
    defaultValue: 'http://127.0.0.1:8787',
  );

  /// The email code for [account], or null when the probe is not running or
  /// refuses. Never throws: the caller fails with its own message.
  static Future<String?> read(
    E2eAccount account, {
    String type = 'signup',
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$url/code'),
            body: jsonEncode({
              'email': account.email,
              'type': type,
              'password': account.password,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      return (jsonDecode(res.body) as Map<String, dynamic>)['code'] as String?;
    } on Exception {
      return null;
    }
  }
}

/// Polls briefly for the welcome screen; false when something else is up
/// (a signed-in session), which the caller turns into a skip.
Future<bool> onWelcomeScreen(PatrolIntegrationTester $) async {
  const welcomeKey = ValueKey('welcome.get_started_button');
  for (var i = 0; i < 30; i++) {
    if ($(welcomeKey).exists) return true;
    await $.pump(const Duration(milliseconds: 500));
  }
  return $(welcomeKey).exists;
}

/// From the welcome screen, the shortest honest path through onboarding to
/// the "Sign up with email" button: one sport, one goal, no pitfalls, no
/// training app, a gender, the defaults after that.
Future<void> walkOnboardingToSignup(PatrolIntegrationTester $) async {
  await $(const ValueKey('welcome.get_started_button')).tap();

  // Strict-regime regions (EEA/UK, WA) get /privacy-consent first.
  const consentContinue = ValueKey('privacy_consent.continue_button');
  const sportsContinue = ValueKey('sport_selection.continue_button');
  for (var i = 0; i < 6; i++) {
    if ($(sportsContinue).exists) break;
    if ($(consentContinue).exists) {
      await $(consentContinue).tap();
      break;
    }
    await $.pump(const Duration(milliseconds: 500));
  }
  await $(
    sportsContinue,
  ).waitUntilVisible(timeout: const Duration(seconds: 15));

  await $(const ValueKey('sport_selection.running_chip')).tap();
  await $(sportsContinue).tap();
  await $(const ValueKey('goals.performance_chip')).tap();
  await $(const ValueKey('goals.continue_button')).tap();
  await $(const ValueKey('pitfalls.continue_button')).tap();

  await _scrollIntoView($, const ValueKey('connect_training.declined_tile'));
  await $(const ValueKey('connect_training.declined_tile')).tap();

  await $(
    const ValueKey('personal_info.gender_female'),
  ).waitUntilVisible(timeout: const Duration(seconds: 15));
  await $(const ValueKey('personal_info.gender_female')).tap();
  await $(const ValueKey('personal_info.continue_button')).tap();

  await $(const ValueKey('body_comp.continue_button')).tap();

  await $(const ValueKey('nutrition_settings.gut_high')).tap();
  await $(const ValueKey('nutrition_settings.sweat_heavy')).tap();
  await $(const ValueKey('nutrition_settings.continue_button')).tap();

  await $(
    const ValueKey('plan_reveal.title'),
  ).waitUntilVisible(timeout: const Duration(seconds: 30));
  await _scrollIntoView($, const ValueKey('plan_reveal.continue_button'));
  await $(const ValueKey('plan_reveal.continue_button')).tap();

  await $(
    const ValueKey('daily_preview.save_button'),
  ).waitUntilVisible(timeout: const Duration(seconds: 15));
  await $(const ValueKey('daily_preview.save_button')).tap();

  await $(
    const ValueKey('post_onboarding.email_button'),
  ).waitUntilVisible(timeout: const Duration(seconds: 15));
}

/// Signs [account] up from the auth screen and waits for the paywall. If the
/// project asks for email confirmation, reads the code from [CodeProbe].
Future<void> signUpToPaywall(
  PatrolIntegrationTester $,
  E2eAccount account,
) async {
  await $(const ValueKey('post_onboarding.email_button')).tap();
  await $(const ValueKey('signup_email.email_field')).enterText(account.email);
  await $(
    const ValueKey('signup_email.password_field'),
  ).enterText(account.password);
  await $(
    const ValueKey('signup_email.confirm_password_field'),
  ).enterText(account.password);
  await $(const ValueKey('signup_email.create_account_button')).tap();

  const paywallMore = ValueKey('paywall.more_button');
  const verifyField = ValueKey('auth.verify_code_field');
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(deadline)) {
    if ($(paywallMore).exists) return;
    if ($(verifyField).exists) {
      final code = await CodeProbe.read(account);
      if (code == null) {
        fail(
          'Signup asked for an email code and the code probe at '
          '${CodeProbe.url} gave none. Start it with '
          '`node scripts/testing-wave/code-probe.mjs serve`.',
        );
      }
      await $(verifyField).enterText(code);
      await $(const ValueKey('auth.verify_submit')).tap();
      await $(
        paywallMore,
      ).waitUntilVisible(timeout: const Duration(seconds: 40));
      return;
    }
    await $.pump(const Duration(milliseconds: 500));
  }
  fail(
    'Neither the paywall nor the verify screen appeared within 60s of '
    'Create account for ${account.email}.',
  );
}

/// Opens the paywall's ⋯ menu and deletes the account (mp-494), then waits
/// for the welcome screen the delete returns to.
Future<void> deleteFromPaywallMenu(PatrolIntegrationTester $) async {
  await $(const ValueKey('paywall.more_button')).tap();
  await $(const ValueKey('paywall.delete_account_button')).tap();
  await $(const ValueKey('paywall.confirm.action')).tap();
  await $(
    const ValueKey('welcome.get_started_button'),
  ).waitUntilVisible(timeout: const Duration(seconds: 40));
}

/// Brings [key] into view inside the first vertical scrollable (some
/// onboarding steps put a horizontal strip first, which Patrol's own
/// `scrollTo` would pick). Same pattern as the onboarding signup flow.
Future<void> _scrollIntoView(
  PatrolIntegrationTester $,
  ValueKey<String> key,
) async {
  for (var attempt = 0; attempt < 8; attempt++) {
    if ($(key).exists) {
      try {
        await $.tester.ensureVisible(find.byKey(key).first);
      } catch (_) {
        // Best effort: the caller's tap fails loudly if it is still hidden.
      }
      await $.pump(const Duration(milliseconds: 200));
      return;
    }
    final all = find.byType(Scrollable).evaluate().toList();
    final i = all.indexWhere((e) {
      final w = e.widget as Scrollable;
      return w.axisDirection == AxisDirection.down ||
          w.axisDirection == AxisDirection.up;
    });
    if (i == -1) return;
    await $.tester.drag(find.byType(Scrollable).at(i), const Offset(0, -400));
    await $.pump(const Duration(milliseconds: 300));
  }
}

/// Guard for destructive flows: a throwaway account is only ever made on dev.
/// An allowlist on the dev project, not "anything but prod", so a staging or
/// local `SUPABASE_URL` is refused too (the sweep's `assertDev` does the same).
bool get e2eAccountsAllowed =>
    TestConfig.supabaseUrl.contains('vlmtsdzpnjnavdgytcmi');

/// Buys Pro Monthly on the paywall (testing-wave 06): Monthly → Continue → the Test Store's native alert → "Test valid
/// purchase". The paywall never settles, so taps are noSettle.
Future<void> buyMonthlyInTestStore(PatrolIntegrationTester $) async {
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

/// Taps "Got it" on the What's New sheet when it shows within [wait]. It
/// opens over the first screen after the Gate opens.
Future<void> dismissWhatsNew(
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

Future<void> openSettings(PatrolIntegrationTester $) async {
  await $(
    const ValueKey('kyle_date_header.settings'),
  ).tap(settlePolicy: SettlePolicy.noSettle);
  await $(
    const ValueKey('settings.title'),
  ).waitUntilVisible(timeout: const Duration(seconds: 15));
}

Future<void> signOutFromSettings(PatrolIntegrationTester $) async {
  await $('Sign Out').scrollTo().tap(settlePolicy: SettlePolicy.noSettle);
  await $.pump(const Duration(milliseconds: 500));
  // The confirm dialog's action repeats the label.
  await $('Sign Out').last.tap(settlePolicy: SettlePolicy.noSettle);
}

Future<void> logInWithEmail(
  PatrolIntegrationTester $,
  E2eAccount account,
) async {
  // Sign-out lands on welcome mid-transition; a tap before the route settles
  // is dropped (testing-wave 06's second run), so wait, then tap until the
  // login options show.
  await $(
    const ValueKey('welcome.log_in_button'),
  ).waitUntilVisible(timeout: const Duration(seconds: 15));
  const emailOption = ValueKey('login_options.email_button');
  for (var i = 0; i < 3 && !$(emailOption).exists; i++) {
    await $.pump(const Duration(seconds: 1));
    if ($(const ValueKey('welcome.log_in_button')).exists) {
      await $(
        const ValueKey('welcome.log_in_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
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

/// The account's Entitlement rows, read as the account (RLS shows an athlete
/// its own row), or null when the read failed. Polls for [waitFor] until a
/// row shows.
Future<List<Map<String, dynamic>>?> entitlementRows(
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
            query:
                'user_id=eq.${probe.userId}&select=user_id,active_until,period_type',
          );
    if ((rows != null && rows.isNotEmpty) ||
        !DateTime.now().isBefore(deadline)) {
      return rows;
    }
    await Future<void>.delayed(const Duration(seconds: 3));
  }
}
