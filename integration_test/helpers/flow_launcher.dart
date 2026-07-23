/// Shared app launcher + authentication for Patrol flow tests.
///
/// Every flow must boot the app through [launchApp] instead of importing
/// `main_dev.dart` directly: the flavor entrypoints differ only in which
/// dotenv asset they load, so a flow that hardcodes `main_dev` boots against
/// the DEV Supabase project even when the run is `--flavor prod`. [launchApp]
/// picks the entrypoint from [TestConfig.isProd], which follows the
/// SUPABASE_URL in whichever `--dart-define-from-file` env file the run was
/// given (`.env.dev.local` or `.env.prod.local`).
///
/// [ensureAuthenticated] is the single canonical login walk (previously
/// copy-pasted into every flow). It reuses an existing session when the app
/// launches straight to the tabs shell, otherwise performs the email login
/// with the flavor-matched [TestConfig.loginEmail]/[TestConfig.loginPassword].
library;

import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';
import 'package:mealvana_endurance/main_dev.dart' as dev;
import 'package:mealvana_endurance/main_prod.dart' as prod;

import 'test_config.dart';

/// Boots the app for the flavor this run targets. Call once per test, then
/// pump briefly — do NOT pumpAndSettle (startup may show a persistent
/// spinner); [ensureAuthenticated] uses explicit visibility gates instead.
Future<void> launchApp() async {
  if (TestConfig.isProd) {
    await prod.main();
  } else {
    await dev.main();
  }
}

/// The landed-marker for the post-login tabs shell. Lives in the always-on
/// FloatingActionButtonsBar, so it is present regardless of which tab login
/// lands on. (`calendar.create_activity_fab` is gone — Activities + Nutrition
/// merged into the Fuel Timeline; `calendar.settings_button` is hidden on
/// tab 0.)
const ValueKey<String> authSentinel = ValueKey('bottom_nav.timeline_tab');

/// Ensures the app is signed in and the tabs shell is visible.
///
/// Returns true when the shell sentinel is on screen. Returns false when
/// there is no existing session and no credentials for this flavor — callers
/// should `markTestSkipped` with a clear message in that case rather than
/// fail.
Future<bool> ensureAuthenticated(
  PatrolIntegrationTester $, {
  ValueKey<String> sentinel = authSentinel,
  Duration pollFor = const Duration(seconds: 90),
  Duration loginTimeout = const Duration(seconds: 40),
}) async {
  const welcome = ValueKey('welcome.log_in_button');

  // Poll for either the authed sentinel (session reuse) or the welcome
  // screen (fresh install / logged out).
  bool sentinelFound = false;
  bool welcomeFound = false;
  final polls = pollFor.inMilliseconds ~/ 500;
  for (var i = 0; i < polls; i++) {
    await $.pump(const Duration(milliseconds: 500));
    if ($(sentinel).exists) {
      sentinelFound = true;
      break;
    }
    if ($(welcome).exists) {
      welcomeFound = true;
      break;
    }
  }

  if (sentinelFound) return true;
  if (!welcomeFound || !TestConfig.hasLoginCredentials) return false;

  await $(welcome).tap();
  await $(
    const ValueKey('login_options.email_button'),
  ).waitUntilVisible(timeout: const Duration(seconds: 15));
  await $(const ValueKey('login_options.email_button')).tap();
  await $(
    const ValueKey('login.email_field'),
  ).waitUntilVisible(timeout: const Duration(seconds: 15));
  await $(const ValueKey('login.email_field')).enterText(TestConfig.loginEmail);
  await $(
    const ValueKey('login.password_field'),
  ).enterText(TestConfig.loginPassword);
  await $(const ValueKey('login.log_in_button')).tap();

  await $(sentinel).waitUntilVisible(timeout: loginTimeout);
  return $(sentinel).exists;
}

/// Standard skip message for flows that could not authenticate.
String noAuthSkipMessage() =>
    'Could not reach the tabs shell: no existing session and no '
    '${TestConfig.isProd ? 'INTEGRATION_TEST_PROD_EMAIL/PASSWORD' : 'INTEGRATION_TEST_EMAIL/PASSWORD'} '
    'provided. Pass --dart-define-from-file=secrets/integration_test.env to run.';
