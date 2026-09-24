/// Auth + login walk — the explicit email-login test built on the
/// post-instrumentation ValueKey infrastructure.
///
/// What it verifies:
///   - The welcome screen appears with the `welcome.*` keys.
///   - `welcome.log_in_button` → routes to the login-options sheet.
///   - `login_options.email_button` → routes to the email-login form.
///   - `login.email_field` / `login.password_field` accept input.
///   - `login.log_in_button` → submits and ultimately lands on the tabs
///     shell (`kyle_tab_bar.item.timeline`), or on the paywall
///     (`paywall.screen`) when the account has no active subscription.
///
/// Unlike every other flow, this test does NOT call the shared
/// ensureAuthenticated() — the manual login walk IS the thing under test.
/// It still boots through the shared launcher (helpers/flow_launcher.dart)
/// so the right flavor entrypoint runs, and reads the flavor-matched
/// credentials from TestConfig.loginEmail/loginPassword (injected via
/// --dart-define-from-file=secrets/integration_test.env). With no
/// credentials for the current flavor it self-skips.
///
/// Run:
///   patrol test --target integration_test/flows/auth_flow_test.dart \
///     --flavor dev \
///     --dart-define-from-file=.env.dev.local \
///     --dart-define-from-file=secrets/integration_test.env \
///     --device "iPhone 17 Pro"
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../helpers/flow_launcher.dart';
import '../helpers/test_config.dart';

void main() {
  patrolTest(
    'email login walk lands on the tabs shell or the paywall',
    ($) async {
      await launchApp($);
      // Do NOT pumpAndSettle: startup may show a persistent spinner. Poll
      // with plain pumps for either an existing session (sentinel) or the
      // welcome screen.
      const welcome = ValueKey('welcome.log_in_button');
      // Everything sits behind the app gate (mp-280): a signed-in account
      // without an active subscription lands on the paywall, not the shell.
      // Either one means the login worked; which one is the gate's business
      // (pro_gate_flow_test checks the gate). Updated by testing-wave 03.
      const paywall = ValueKey('paywall.screen');
      var authed = false;
      var onWelcome = false;
      for (var i = 0; i < 180; i++) {
        await $.pump(const Duration(milliseconds: 500));
        if ($(authSentinel).exists || $(paywall).exists) {
          authed = true;
          break;
        }
        if ($(welcome).exists) {
          onWelcome = true;
          break;
        }
      }

      if (authed) {
        // Re-run on a hot simulator with a persisted session — the login walk
        // is not reachable. The shell or the paywall is all we can assert.
        expect(
          $(authSentinel).exists || $(paywall).exists,
          isTrue,
          reason: 'A persisted session should land on the shell or paywall.',
        );
        return;
      }

      expect(
        onWelcome,
        isTrue,
        reason:
            'Neither the tabs shell nor the welcome screen appeared '
            'within 90 s of launch.',
      );

      if (!TestConfig.hasLoginCredentials) {
        skipFlow(
          'No ${TestConfig.isProd ? 'INTEGRATION_TEST_PROD_EMAIL/PASSWORD' : 'INTEGRATION_TEST_EMAIL/PASSWORD'} '
          'provided — cannot exercise the login walk. Pass '
          '--dart-define-from-file=secrets/integration_test.env to run.',
        );
        return;
      }

      // ---- The explicit manual login walk (the thing under test) --------
      // Welcome → Login options
      await $(welcome).tap();
      await $(
        const ValueKey('login_options.email_button'),
      ).waitUntilVisible(timeout: const Duration(seconds: 15));

      // Login options → email login
      await $(const ValueKey('login_options.email_button')).tap();
      await $(
        const ValueKey('login.email_field'),
      ).waitUntilVisible(timeout: const Duration(seconds: 15));

      // Fill credentials
      await $(
        const ValueKey('login.email_field'),
      ).enterText(TestConfig.loginEmail);
      await $(
        const ValueKey('login.password_field'),
      ).enterText(TestConfig.loginPassword);

      // Submit — noSettle so a post-login loading spinner cannot burn the
      // settle timeout; the sentinel wait below gates on the landed shell.
      await $(
        const ValueKey('login.log_in_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);

      // Allow the Supabase round-trip + redirect to the tabs shell, or to
      // the paywall for an account the gate keeps closed.
      var landed = false;
      for (var i = 0; i < 120; i++) {
        await $.pump(const Duration(milliseconds: 500));
        if ($(authSentinel).exists || $(paywall).exists) {
          landed = true;
          break;
        }
      }
      expect(
        landed,
        isTrue,
        reason:
            'Expected the tabs shell or the paywall within 60 s of login. If '
            'this fails, dump the tree with `debugDumpApp()` and check what '
            'screen we landed on.',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
