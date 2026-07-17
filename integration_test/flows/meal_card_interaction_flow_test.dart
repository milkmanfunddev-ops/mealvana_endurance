/// Unified meal/activity card interaction (391e3fdb) under **Patrol** —
/// log a meal manually, tap its Fuel Timeline card to open the edit surface,
/// come back, then swipe the card to delete it with the Undo snackbar.
///
/// Flow:
///   ensureAuthenticated (reuse session, else email login)
///     → Fuel Timeline tab → "+ Add Food" → Manual tab
///     → enter a uniquely-named meal → Save → back to the timeline
///     → the meal card appears (timeline names render UPPERCASE)
///     → TAP the card → 'Edit Meal' screen opens (tap-anywhere-to-edit)
///     → back (no edits, so no discard prompt)
///     → SWIPE the card → 'Meal deleted' MealvanaSnackbar with Undo
///     → snackbar times out → the card is gone
///
/// Auth:
///   Reuses an existing session if the app launches straight to the timeline.
///   Otherwise logs in with INTEGRATION_TEST_EMAIL / INTEGRATION_TEST_PASSWORD.
///   On a clean install (no session, no creds) the test self-skips.
///
/// Run:
///   patrol test --target integration_test/flows/meal_card_interaction_flow_test.dart \
///     --flavor dev \
///     --dart-define-from-file=.env.dev.local \
///     --dart-define-from-file=secrets/integration_test.env \
///     --device "iPhone 17 Pro"
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:mealvana_endurance/main_dev.dart' as app;
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';

const _loginEmail = String.fromEnvironment('INTEGRATION_TEST_EMAIL');
const _loginPassword = String.fromEnvironment('INTEGRATION_TEST_PASSWORD');

void main() {
  patrolTest(
    'log a meal → tap card opens edit → swipe card deletes with Undo',
    ($) async {
      await app.main();
      // Do NOT call pumpAndSettle: the app may have a persistent loading
      // spinner during startup. _ensureAuthenticated uses explicit polls.
      await $.pump(const Duration(milliseconds: 500));

      if (!await _ensureAuthenticated($)) {
        markTestSkipped(
          'Could not reach the timeline: no existing session and no '
          'INTEGRATION_TEST_EMAIL/PASSWORD provided. Pass '
          '--dart-define-from-file=secrets/integration_test.env to run.',
        );
        return;
      }

      final stamp = DateTime.now().millisecondsSinceEpoch;
      final mealName = 'Patrol Meal $stamp';
      // TimelineNodeTile renders meal names uppercased.
      final cardText = mealName.toUpperCase();

      // ---- 1. Fuel Timeline → + Add Food → Manual tab --------------------
      await $(const ValueKey('bottom_nav.timeline_tab')).tap();
      await $(const ValueKey('fuel_timeline.add_food')).waitUntilVisible(
        timeout: const Duration(seconds: 20),
      );
      await $(const ValueKey('fuel_timeline.add_food')).tap();

      await $('Manual').waitUntilVisible(timeout: const Duration(seconds: 15));
      await $('Manual').tap();

      // ---- 2. Fill the manual form and Save ------------------------------
      await $.tester.enterText(
        find.widgetWithText(TextFormField, 'Meal name'),
        mealName,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await $.pump(const Duration(milliseconds: 300));
      await $('Save').scrollTo().tap();
      await $('Meal logged!').waitUntilVisible(
        timeout: const Duration(seconds: 15),
      );

      // ---- 3. Back to the timeline — the card is there -------------------
      await $(const ValueKey('log_meal.back_button')).tap();
      await $(cardText).waitUntilVisible(timeout: const Duration(seconds: 20));

      // ---- 4. TAP the card → edit surface (tap-anywhere-to-edit) ---------
      await $(cardText).tap();
      await $('Edit Meal').waitUntilVisible(
        timeout: const Duration(seconds: 15),
      );

      // Back out without editing (no discard prompt fires when unchanged).
      await $.tester.tap(find.byType(CustomAppBarBackButton).first);
      await $(cardText).waitUntilVisible(timeout: const Duration(seconds: 15));

      // ---- 5. SWIPE the card → soft delete + Undo snackbar ---------------
      final cardRow = find.ancestor(
        of: find.text(cardText),
        matching: find.byType(Dismissible),
      );
      await $.tester.drag(cardRow.first, const Offset(-500, 0));
      await $.pump(const Duration(milliseconds: 600));

      await $('Meal deleted').waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );
      expect($('Undo'), findsOneWidget);

      // Let the undo snackbar time out without tapping Undo.
      await $.pump(const Duration(seconds: 4));

      // ---- 6. The card is gone -------------------------------------------
      expect($(cardText), findsNothing);
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

/// Returns true once the Fuel Timeline is reachable (authenticated).
Future<bool> _ensureAuthenticated(PatrolIntegrationTester $) async {
  // The settings gear in the Fuel Timeline header is always present on the
  // main authenticated screen.
  const sentinel = ValueKey('fuel_timeline.settings');
  const welcome = ValueKey('welcome.log_in_button');

  // Poll up to 90 s for the sentinel (already authed) or the welcome button.
  var sentinelFound = false;
  var welcomeFound = false;
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
