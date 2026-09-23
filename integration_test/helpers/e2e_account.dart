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
  Future<bool> isGone({
    Duration waitFor = const Duration(seconds: 30),
  }) async {
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
  await $(sportsContinue).waitUntilVisible(
    timeout: const Duration(seconds: 15),
  );

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
      await $(paywallMore).waitUntilVisible(
        timeout: const Duration(seconds: 40),
      );
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
bool get e2eAccountsAllowed => !TestConfig.isProd;
