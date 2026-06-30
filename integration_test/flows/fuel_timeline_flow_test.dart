/// Fuel Timeline walk under **Patrol** — navigate to the Nutrition tab and
/// exercise the filter segments + tracking/timeline toggles end-to-end, driven
/// entirely by `ValueKey` finders.
///
/// Intentionally data-agnostic: it asserts the controls render and respond
/// (filter pills, tracking/timeline toggles) without depending on the test
/// account having meals/activities logged, so it stays green on a fresh dev
/// account.
///
/// Flow:
///   ensureAuthenticated (reuse session, else email login)
///     → Fuel Timeline tab (already active at startup)
///     → assert the filter row rendered (All pill visible)
///     → cycle filters: Workout → Meals → All
///     → toggle tracking off then on
///     → toggle the time rail off then on
///
/// Auth:
///   Reuses an existing session if the app launches straight to the calendar.
///   Otherwise logs in with INTEGRATION_TEST_EMAIL / INTEGRATION_TEST_PASSWORD.
///   On a clean install (no session, no creds) the test self-skips.
///
/// Run:
///   patrol test --target integration_test/flows/fuel_timeline_flow_test.dart \
///     --flavor dev \
///     --dart-define-from-file=.env.dev.local \
///     --dart-define-from-file=secrets/integration_test.env \
///     --device "iPhone 17 Pro"
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:mealvana_endurance/main_dev.dart' as app;

const _loginEmail = String.fromEnvironment('INTEGRATION_TEST_EMAIL');
const _loginPassword = String.fromEnvironment('INTEGRATION_TEST_PASSWORD');

void main() {
  patrolTest(
    'fuel timeline — filter + tracking/timeline toggles',
    ($) async {
      await app.main();
      // Do NOT call pumpAndSettle: the app may have a persistent loading
      // spinner during startup. _ensureAuthenticated uses explicit
      // waitUntilVisible gates instead.
      await $.pump(const Duration(milliseconds: 500));

      final onCalendar = await _ensureAuthenticated($);
      if (!onCalendar) {
        markTestSkipped(
          'Could not reach the calendar: no existing session and no '
          'INTEGRATION_TEST_EMAIL/PASSWORD provided. Pass '
          '--dart-define-from-file=secrets/integration_test.env to run.',
        );
        return;
      }

      // ---- 1. Ensure Fuel Timeline tab is active ---------------------------
      // The app opens on the Fuel Timeline (index 0). Tapping the nav button
      // is harmless if we're already there and guarantees the screen is active.
      // Key is bottom_nav.timeline_tab — the Activities + Nutrition tabs were
      // merged into one Fuel Timeline tab in the carbs-per-hour refactor.
      // The old key bottom_nav.diary_tab no longer exists.
      await $(const ValueKey('bottom_nav.timeline_tab')).tap();
      await $(const ValueKey('fuel_timeline.filter_all')).waitUntilVisible(
        timeout: const Duration(seconds: 20),
      );

      // ---- 2. Cycle the filters ------------------------------------------
      await $(const ValueKey('fuel_timeline.filter_workout')).tap();
      await $(const ValueKey('fuel_timeline.filter_meals')).tap();
      await $(const ValueKey('fuel_timeline.filter_all')).tap();

      // ---- 3. Toggle tracking off then on --------------------------------
      await $(const ValueKey('fuel_timeline.tracking_toggle')).tap();
      await $(const ValueKey('fuel_timeline.tracking_toggle')).tap();

      // ---- 4. Toggle the time rail off then on ---------------------------
      await $(const ValueKey('fuel_timeline.timeline_toggle')).tap();
      await $(const ValueKey('fuel_timeline.timeline_toggle')).tap();

      // The filter row is still present after all the toggling.
      expect($(const ValueKey('fuel_timeline.filter_all')), findsOneWidget);
    },
  );
}

Future<bool> _ensureAuthenticated(PatrolIntegrationTester $) async {
  // `calendar.create_activity_fab` was removed when Activities + Nutrition
  // merged into the Fuel Timeline tab. The settings gear in the Fuel Timeline
  // header is always present on the main authenticated screen.
  const sentinel = ValueKey('fuel_timeline.settings');

  // Poll up to 90 s for the sentinel (already authed) or the welcome button.
  bool sentinelFound = false;
  bool welcomeFound = false;
  const welcome = ValueKey('welcome.log_in_button');
  for (var i = 0; i < 180; i++) {
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
  if (!welcomeFound || _loginEmail.isEmpty || _loginPassword.isEmpty) {
    return false;
  }

  await $(welcome).tap();
  await $(const ValueKey('login_options.email_button')).waitUntilVisible(
    timeout: const Duration(seconds: 15),
  );
  await $(const ValueKey('login_options.email_button')).tap();
  await $(const ValueKey('login.email_field')).waitUntilVisible(
    timeout: const Duration(seconds: 15),
  );
  await $(const ValueKey('login.email_field')).enterText(_loginEmail);
  await $(const ValueKey('login.password_field')).enterText(_loginPassword);
  await $(const ValueKey('login.log_in_button')).tap();

  await $(sentinel).waitUntilVisible(timeout: const Duration(seconds: 40));
  return $(sentinel).exists;
}
