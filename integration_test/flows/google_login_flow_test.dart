/// Google sign-in flow under **Patrol** — ANDROID ONLY.
///
/// Why Android only:
///   On iOS, `google_sign_in` presents Google's auth inside a system sheet
///   (`ASWebAuthenticationSession`) that Apple sandboxes from UI automation —
///   Patrol cannot type into it. On Android, Google sign-in surfaces as a
///   native account picker / Custom Tab that Patrol's native automation CAN
///   drive. So this test self-skips on iOS.
///
/// What it does:
///   welcome → Log In → login-options → "Continue with Google" → native account
///   picker. If a Google account is already added to the emulator it taps it and
///   expects to land on the calendar. If no account is present, the full
///   add-account web flow is subject to Google bot-detection and is NOT reliably
///   automatable — in that case pre-add GOOGLE_TEST_EMAIL to the emulator
///   (Settings → Passwords & accounts → Add account → Google) before running.
///
/// Credentials (gitignored secrets/integration_test.env):
///   patrol test --target integration_test/flows/google_login_flow_test.dart \
///     --flavor dev --dart-define-from-file=.env.dev.local \
///     --dart-define-from-file=secrets/integration_test.env \
///     --device emulator-5554
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:mealvana_endurance/main_dev.dart' as app;

import '../helpers/test_helpers.dart';

const _googleEmail = String.fromEnvironment('GOOGLE_TEST_EMAIL');

void main() {
  patrolTest(
    'sign in with Google lands on calendar (Android only)',
    ($) async {
      final tester = $.tester;

      // iOS: Google auth runs in ASWebAuthenticationSession — not automatable.
      if (Platform.isIOS) {
        markTestSkipped(
          'Google sign-in is not automatable on iOS '
          '(ASWebAuthenticationSession is sandboxed). Android only.',
        );
        return;
      }

      await app.main();
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(minutes: 2),
      );

      // If already authed (calendar present), nothing to do.
      if (find
          .byKey(const ValueKey('bottom_nav.timeline_tab'))
          .evaluate()
          .isNotEmpty) {
        expect(find.byKey(const ValueKey('bottom_nav.timeline_tab')),
            findsOneWidget);
        return;
      }

      // welcome → login options
      final loginBtn = find.byKey(const ValueKey('welcome.log_in_button'));
      if (loginBtn.evaluate().isEmpty) {
        markTestSkipped('Not on welcome screen — reinstall for a clean run.');
        return;
      }
      await tester.mustTap(loginBtn, reason: 'welcome.log_in_button');

      // Tap "Continue with Google".
      await tester.mustTap(
        find.byKey(const ValueKey('login_options.google_button')),
        reason: 'login_options.google_button',
      );
      await tester.pump(const Duration(seconds: 3));

      // Native account picker — tap the pre-added Google account if present.
      // ignore: deprecated_member_use
      final native = $.native;
      if (_googleEmail.isNotEmpty) {
        try {
          await native.tap(Selector(textContains: _googleEmail));
          await tester.pump(const Duration(seconds: 3));
        } catch (_) {
          // Account not in the picker — try a generic "Continue"/account row.
          try {
            await native.tap(Selector(textContains: 'Continue'));
          } catch (_) {/* fall through to the assertion */}
        }
      }

      // Allow the Supabase round-trip + redirect.
      await tester.pumpAndSettle(const Duration(seconds: 30));

      final landed = await tester.waitForWidget(
        find.byKey(const ValueKey('bottom_nav.timeline_tab')),
        timeout: const Duration(seconds: 20),
      );
      expect(
        landed,
        isTrue,
        reason:
            'Expected the calendar after Google sign-in. If this fails, ensure '
            'GOOGLE_TEST_EMAIL is added to the emulator (Settings → Accounts) — '
            'Google blocks fully-automated web sign-in (bot detection).',
      );
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
