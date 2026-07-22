/// Activities (fueling-plan) CRUD walk under **Patrol** — create a running
/// activity via the deterministic edge-function macro engine (NO LLM/AI),
/// read it back, then delete it via swipe-to-delete.
///
/// Why "Generate Plan" and not "Use Template":
///   The "Use Template" button only renders when the user already has a saved
///   template (`hasTemplates`), which a fresh test environment may not have.
///   "Generate Plan" is always present and calls the macro edge function
///   (generate-macros / generate-nutrition-plan) — deterministic math, not AI —
///   which is exactly the engine we want exercised.
///
/// Flow:
///   ensureAuthenticated → calendar → New activity FAB (route 'distancepacegut')
///     → CREATE: running tab, name + distance + duration → Generate Plan
///                → adjust-macros (assert macros rendered) → Create Plan
///                → lands on the plan detail screen
///     → READ:   back to calendar → the activity card for our workout is present
///     → DELETE: swipe the card left → confirm → assert the card is gone
///
/// Macro VALUE-RANGE assertions live in the direct edge-function integration
/// tests (better suited to numeric checks); here we assert the plan renders and
/// the CRUD round-trips. See the testing roadmap in docs/test/.
///
/// Run:
///   patrol test --target integration_test/flows/activities_crud_flow_test.dart \
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
    'create a running activity (generate macros), read it, then delete it',
    ($) async {
      await app.main();
      await $.tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(minutes: 2),
      );

      // ---- 0. Authenticated on the calendar -----------------------------
      if (!await _ensureAuthenticated($)) {
        markTestSkipped(
          'Could not reach the calendar: no session and no '
          'INTEGRATION_TEST_EMAIL/PASSWORD. Pass '
          '--dart-define-from-file=secrets/integration_test.env to run.',
        );
        return;
      }

      final stamp = DateTime.now().millisecondsSinceEpoch;
      final workoutName = 'Patrol Run $stamp';

      // ---- 1. New activity → running create form ------------------------
      // There is no calendar FAB: the app's entry point to /distancepacegut is
      // the Fuel Timeline's add-activity button, so hop to that tab first.
      await $(const ValueKey('bottom_nav.timeline_tab')).tap();
      await $(const ValueKey('fuel_timeline.add_activity')).waitUntilVisible(
        timeout: const Duration(seconds: 20),
      );
      await $(const ValueKey('fuel_timeline.add_activity')).tap();
      await $(const ValueKey('activity_create.tab_running')).waitUntilVisible(
        timeout: const Duration(seconds: 20),
      );
      await $(const ValueKey('activity_create.tab_running')).tap();

      // ---- 2. Fill the running form -------------------------------------
      // Each field: dismiss the prior field's keyboard (it overlays lower
      // fields and makes them un-hit-testable) and scroll into view first.
      await _fillField($, const ValueKey('activity_create.workout_name_field'),
          workoutName);
      await _fillField($, const ValueKey('activity_create.distance_field'), '10');

      // Secondary input depends on the Duration/Pace toggle's current mode —
      // fill whichever editable the form is currently showing.
      const durHrKey = ValueKey('activity_create.duration_hr_field');
      if ($(durHrKey).exists) {
        await _fillField($, durHrKey, '1');
        await _fillField(
            $, const ValueKey('activity_create.duration_mins_field'), '0');
      }

      // ---- 3. Generate Plan (edge-function macro engine) ----------------
      FocusManager.instance.primaryFocus?.unfocus();
      await $.pump(const Duration(milliseconds: 400));
      await $(const ValueKey('activity_create.generate_plan_button'))
          .scrollTo()
          .tap();

      // ---- 4. Adjust-macros screen — macros generated & rendered --------
      await $(const ValueKey('adjust_macros.create_plan_button')).waitUntilVisible(
        timeout: const Duration(seconds: 60),
      );
      expect(
        $(const ValueKey('adjust_macros.calories_stat')),
        findsWidgets,
        reason: 'Generated plan should render a calories stat on adjust-macros.',
      );

      // ---- 5. Create Plan → lands on the plan detail --------------------
      await $(const ValueKey('adjust_macros.create_plan_button')).scrollTo().tap();
      await $(const ValueKey('plan_detail.title')).waitUntilVisible(
        timeout: const Duration(seconds: 40),
      );

      // ---- 6. READ — back on the calendar, our activity card is present -
      // Create builds a deep stack: calendar → new_activity → adjust-macros →
      // plan_detail. plan_detail's back only pops one level, so unwind by
      // tapping whichever back button is present until the calendar reappears.
      await _returnToCalendar($);
      expect(
        $(workoutName),
        findsWidgets,
        reason: 'Created activity should appear as a card on the calendar.',
      );

      // ---- 7. DELETE — swipe the card (either direction deletes) --------
      // Unified card interaction (391e3fdb): no confirm dialog — the swipe
      // soft-deletes immediately and shows an Undo snackbar.
      final cardRow = find.ancestor(
        of: find.text(workoutName),
        matching: find.byType(Dismissible),
      );
      await $.tester.drag(cardRow.first, const Offset(-500, 0));
      await $.pump(const Duration(milliseconds: 600));

      await $('Activity deleted').waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );
      // Let the undo snackbar time out without tapping Undo.
      await $.pump(const Duration(seconds: 4));

      // ---- 8. Assert the activity card is gone --------------------------
      expect(
        $(workoutName),
        findsNothing,
        reason: 'Deleted activity should no longer appear on the calendar.',
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

/// Unwind the create-flow stack back to the calendar by tapping whichever
/// screen's back button is currently present, until the calendar FAB shows.
Future<void> _returnToCalendar(PatrolIntegrationTester $) async {
  const fab = ValueKey('bottom_nav.timeline_tab');
  const backButtons = [
    ValueKey('plan_detail.back_button'),
    ValueKey('adjust_macros.back_button'),
    ValueKey('activity_create.back_button'),
  ];
  for (var i = 0; i < 6; i++) {
    if ($(fab).exists) return;
    var tapped = false;
    for (final back in backButtons) {
      if ($(back).exists) {
        await $(back).tap();
        tapped = true;
        break;
      }
    }
    if (!tapped) break;
    await $.pump(const Duration(milliseconds: 500));
  }
  await $(fab).waitUntilVisible(timeout: const Duration(seconds: 30));
}

/// Dismiss any open keyboard (it overlays lower fields and makes them
/// un-hit-testable), scroll the target field into view, then enter text.
/// `enterText` resolves to the descendant EditableText, so a ValueKey on a
/// wrapper widget (e.g. _DistanceInput) is fine.
Future<void> _fillField(
  PatrolIntegrationTester $,
  ValueKey<String> key,
  String text,
) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await $.pump(const Duration(milliseconds: 300));
  await $(key).scrollTo();
  await $(key).enterText(text);
}

/// Returns true once the calendar is reachable (authenticated).
Future<bool> _ensureAuthenticated(PatrolIntegrationTester $) async {
  const fab = ValueKey('bottom_nav.timeline_tab');
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
