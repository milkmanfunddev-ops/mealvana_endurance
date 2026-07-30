/// Activities (fueling-plan) CRUD walk under **Patrol** — create a running
/// activity via the deterministic edge-function macro engine (NO LLM/AI),
/// read it back from the Fuel Timeline, then delete it from Activity Detail.
///
/// Why "Generate Plan" and not "Use Template":
///   The "Use Template" button only renders when the user already has a saved
///   template (`hasTemplates`), which a fresh test environment may not have.
///   "Generate Plan" is always present and calls the macro edge function
///   (generate-macros / generate-nutrition-plan) — deterministic math, not AI —
///   which is exactly the engine we want exercised.
///
/// Flow:
///   ensureAuthenticated → Fuel Timeline dashboard → '+ Add Activity' (route 'distancepacegut')
///     → CREATE: running tab, name + distance + duration → Generate Plan
///                → adjust-macros (assert macros rendered) → Create Plan
///                → lands on the plan detail screen
///     → READ:   back to the dashboard → our workout is a node on the timeline
///     → DELETE: open Activity Detail → trash → confirm → assert the node is gone
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

      // ---- 0. Authenticated on the dashboard ----------------------------
      if (!await _ensureAuthenticated($)) {
        markTestSkipped(
          'Could not reach the dashboard: no session and no '
          'INTEGRATION_TEST_EMAIL/PASSWORD. Pass '
          '--dart-define-from-file=secrets/integration_test.env to run.',
        );
        return;
      }

      // Assertions match on the stamp alone, not the whole name: the timeline
      // tile renders `activity.title.toUpperCase()`, so an exact `find.text`
      // on the mixed-case name we typed finds nothing. The stamp survives the
      // case transform.
      final stamp = '${DateTime.now().millisecondsSinceEpoch}';
      final workoutName = 'Patrol Run $stamp';
      final onTimeline = find.textContaining(stamp);

      // ---- 1. "+ Add Activity" → running create form --------------------
      // The old `calendar.create_activity_fab` was removed when Activities +
      // Nutrition merged into the Fuel Timeline tab; the dashboard now shows a
      // dashed "+ Add Activity" button under the timeline. It only renders
      // under the All/Workout filters, so force All first.
      await $(const ValueKey('fuel_timeline.filter_all')).tap();
      await $(const ValueKey('fuel_timeline.add_activity'))
          .waitUntilVisible(timeout: const Duration(seconds: 20));
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

      // ---- 6. READ — back on the dashboard, our activity node is present -
      // Create builds a deep stack: dashboard → new_activity → adjust-macros →
      // plan_detail. plan_detail's back only pops one level, so unwind by
      // tapping whichever back button is present until the dashboard reappears.
      await _returnToDashboard($);
      await $(onTimeline).waitUntilVisible(
        timeout: const Duration(seconds: 20),
      );
      expect(
        $(onTimeline),
        findsWidgets,
        reason: 'Created activity should appear as a node on the Fuel Timeline.',
      );

      // ---- 7. DELETE — open the activity, delete from its detail screen --
      // Swipe-to-delete is gone: it lived on ActivitiesListScreen, which the
      // router no longer reaches after the Activities + Nutrition merge. The
      // timeline's workout node opens Activity Detail, which owns the delete.
      await $(onTimeline).tap();
      await $(const ValueKey('plan_detail.delete_button')).waitUntilVisible(
        timeout: const Duration(seconds: 30),
      );
      await $(const ValueKey('plan_detail.delete_button')).tap();

      await $(const ValueKey('activity_delete.confirm_button')).waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );
      await $(const ValueKey('activity_delete.confirm_button')).tap();

      // Delete pops back to the dashboard and shows a success snackbar; give
      // the snackbar time to clear before asserting absence.
      await _returnToDashboard($);
      await $.pump(const Duration(seconds: 5));

      // ---- 8. Assert the activity node is gone --------------------------
      expect(
        $(onTimeline),
        findsNothing,
        reason: 'Deleted activity should no longer appear on the timeline.',
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

/// Unwind the create-flow stack back to the dashboard by tapping whichever
/// screen's back button is currently present, until the dashboard shows.
Future<void> _returnToDashboard(PatrolIntegrationTester $) async {
  const sentinel = ValueKey('fuel_timeline.settings');
  const backButtons = [
    ValueKey('plan_detail.back_button'),
    ValueKey('adjust_macros.back_button'),
    ValueKey('activity_create.back_button'),
  ];

  for (var i = 0; i < 12; i++) {
    if ($(sentinel).exists) return;

    // Settle for a beat before deciding to tap. After a delete the screen pops
    // itself while an async write is still in flight, so the dashboard may be
    // one frame away — tapping a back button in that window pops too far.
    await $.pump(const Duration(milliseconds: 500));
    if ($(sentinel).exists) return;

    for (final back in backButtons) {
      if ($(back).exists) {
        // noSettle is essential: the delete keeps a spinner up, and a settling
        // tap waits on it forever. That hung this flow for the full 10-minute
        // test timeout on CI rather than failing an assertion.
        await $(back).tap(settlePolicy: SettlePolicy.noSettle);
        break;
      }
    }
  }
  await $(sentinel).waitUntilVisible(timeout: const Duration(seconds: 30));
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
  const sentinel = ValueKey('fuel_timeline.settings');
  if ($(sentinel).exists) return true;
  if (_loginEmail.isEmpty || _loginPassword.isEmpty) return false;

  await $(const ValueKey('welcome.log_in_button')).tap();
  await $(const ValueKey('login_options.email_button')).tap();
  await $(const ValueKey('login.email_field')).enterText(_loginEmail);
  await $(const ValueKey('login.password_field')).enterText(_loginPassword);
  await $(const ValueKey('login.log_in_button')).tap();
  await $(sentinel).waitUntilVisible(timeout: const Duration(seconds: 40));
  return $(sentinel).exists;
}
