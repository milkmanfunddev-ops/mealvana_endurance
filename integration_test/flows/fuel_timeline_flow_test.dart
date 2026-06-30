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
///     → calendar → Nutrition (diary) tab → Fuel Timeline
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
      await $.tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(minutes: 2),
      );

      final onCalendar = await _ensureAuthenticated($);
      if (!onCalendar) {
        markTestSkipped(
          'Could not reach the calendar: no existing session and no '
          'INTEGRATION_TEST_EMAIL/PASSWORD provided. Pass '
          '--dart-define-from-file=secrets/integration_test.env to run.',
        );
        return;
      }

      // ---- 1. Calendar → Nutrition (diary) tab → Fuel Timeline ------------
      await $(const ValueKey('bottom_nav.diary_tab')).tap();
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
  const fab = ValueKey('calendar.create_activity_fab');

  if ($(fab).exists) return true;
  if (_loginEmail.isEmpty || _loginPassword.isEmpty) return false;

  await $(const ValueKey('welcome.log_in_button')).tap();
  await $(const ValueKey('login_options.email_button')).tap();
  await $(const ValueKey('login.email_field')).enterText(_loginEmail);
  await $(const ValueKey('login.password_field')).enterText(_loginPassword);
  await $(const ValueKey('login.log_in_button')).tap();

  await $(fab).waitUntilVisible(timeout: const Duration(seconds: 40));
  return $(fab).exists;
}
