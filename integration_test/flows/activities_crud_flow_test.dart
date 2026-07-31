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
///   launchApp (flavor-aware) → ensureAuthenticated → calendar
///     → New activity FAB (route 'distancepacegut')
///     → CREATE: running tab, name + distance + duration → Generate Plan
///                → adjust-macros (assert macros rendered) → Create Plan
///                → lands on the plan detail screen
///     → READ:   back to calendar → the activity card for our workout is present
///     → DELETE: swipe the card left → 'Activity deleted' Undo snackbar
///                → snackbar times out → assert the card is gone
///
/// Settle-policy notes:
///   The timeline/calendar can hold a persistent CircularProgressIndicator
///   (plan/ledger refresh), so every default-settle tap burns its full 10 s
///   pumpAndTrySettle and scrollTo burns it between every drag. All taps here
///   use SettlePolicy.noSettle, gated by waitUntilVisible (which polls with
///   plain 100 ms pumps and never settles) and fixed $.pump durations.
///   scrollTo keeps trySettle between drags but caps it at 1 s
///   (settleBetweenScrollsTimeout) — a pure noSettle scrollTo pumps a single
///   zero-duration frame between drags, which leaves scroll physics and the
///   keyboard-dismiss animation frozen and the drags never accumulate
///   (observed: scrollTo on duration_hr_field timed out that way).
///
/// Auth:
///   Boots via the shared launcher (helpers/flow_launcher.dart) and signs in
///   with the flavor-matched TestConfig.loginEmail/loginPassword. Self-skips
///   when there is no session and no credentials.
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

import '../helpers/flow_launcher.dart';

void main() {
  patrolTest(
    'create a running activity (generate macros), read it, then delete it',
    ($) async {
      await launchApp();
      // Do NOT pumpAndSettle: startup may show a persistent spinner.
      await $.pump(const Duration(milliseconds: 500));

      // ---- 0. Authenticated on the calendar -----------------------------
      if (!await ensureAuthenticated($)) {
        markTestSkipped(noAuthSkipMessage());
        return;
      }

      final stamp = DateTime.now().millisecondsSinceEpoch;
      final workoutName = 'Patrol Run $stamp';

      // ---- 1. New activity → running create form ------------------------
      // There is no calendar FAB: the app's entry point to /distancepacegut is
      // the Fuel Timeline's add-activity button, so hop to that tab first.
      await $(
        const ValueKey('bottom_nav.timeline_tab'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $(
        const ValueKey('fuel_timeline.add_activity'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      await $(
        const ValueKey('fuel_timeline.add_activity'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $(
        const ValueKey('activity_create.tab_running'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      await $(
        const ValueKey('activity_create.tab_running'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 400));

      // ---- 2. Fill the running form -------------------------------------
      // Each field: dismiss the prior field's keyboard (it overlays lower
      // fields and makes them un-hit-testable) and scroll into view first.
      await _fillField(
        $,
        const ValueKey('activity_create.workout_name_field'),
        workoutName,
      );
      await _fillField(
        $,
        const ValueKey('activity_create.distance_field'),
        '10',
      );

      // Secondary input depends on the Duration/Pace toggle's current mode —
      // fill whichever editable the form is currently showing.
      const durHrKey = ValueKey('activity_create.duration_hr_field');
      if ($(durHrKey).exists) {
        await _fillField($, durHrKey, '1');
        await _fillField(
          $,
          const ValueKey('activity_create.duration_mins_field'),
          '0',
        );
      }

      // ---- 3. Generate Plan (edge-function macro engine) ----------------
      FocusManager.instance.primaryFocus?.unfocus();
      await $.pump(const Duration(milliseconds: 400));
      await $(const ValueKey('activity_create.generate_plan_button'))
          .scrollTo(settleBetweenScrollsTimeout: const Duration(seconds: 1))
          .tap(settlePolicy: SettlePolicy.noSettle);

      // ---- 4. Adjust-macros screen — macros generated & rendered --------
      await $(
        const ValueKey('adjust_macros.create_plan_button'),
      ).waitUntilVisible(timeout: const Duration(seconds: 60));
      expect(
        $(const ValueKey('adjust_macros.calories_stat')),
        findsWidgets,
        reason:
            'Generated plan should render a calories stat on adjust-macros.',
      );

      // ---- 5. Create Plan → lands on the plan detail --------------------
      await $(const ValueKey('adjust_macros.create_plan_button'))
          .scrollTo(settleBetweenScrollsTimeout: const Duration(seconds: 1))
          .tap(settlePolicy: SettlePolicy.noSettle);
      await $(
        const ValueKey('plan_detail.title'),
      ).waitUntilVisible(timeout: const Duration(seconds: 40));

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
      // soft-deletes immediately and shows an Undo snackbar. Raw drag + fixed
      // pumps only: any settle here can burn its full timeout against the
      // timeline's persistent spinner.
      final cardRow = find.ancestor(
        of: find.text(workoutName),
        matching: find.byType(Dismissible),
      );
      expect(
        cardRow,
        findsWidgets,
        reason: 'Activity card should be wrapped in a Dismissible.',
      );
      await $.tester.drag(cardRow.first, const Offset(-500, 0));
      // Run the dismiss animation with fixed pumps (no settling).
      for (var i = 0; i < 4; i++) {
        await $.pump(const Duration(milliseconds: 300));
      }

      // waitUntilVisible polls with plain 100 ms pumps — it never settles, so
      // it is safe even while a spinner is animating.
      await $(
        'Activity deleted',
      ).waitUntilVisible(timeout: const Duration(seconds: 15));
      // Let the undo snackbar time out without tapping Undo (fixed pumps).
      for (var i = 0; i < 16; i++) {
        await $.pump(const Duration(milliseconds: 300));
      }

      // ---- 8. Assert the activity card is gone --------------------------
      final cardGone = await _pumpUntilGone($, $(workoutName));
      expect(
        cardGone,
        isTrue,
        reason: 'Deleted activity should no longer appear on the calendar.',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
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
        await $(back).tap(settlePolicy: SettlePolicy.noSettle);
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
/// wrapper widget (e.g. _DistanceInput) is fine. The scroll settles at most
/// 1 s per drag (bounded, spinner-proof) and enterText never settles.
Future<void> _fillField(
  PatrolIntegrationTester $,
  ValueKey<String> key,
  String text,
) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await $.pump(const Duration(milliseconds: 500));
  // Prefer not scrolling at all: after the keyboard dismisses, the running
  // form usually fits the viewport. A blind scrollTo is dangerous here —
  // its default view is the FIRST visible Scrollable, which on this screen
  // is a horizontal one (sport selector strip), so it drags sideways forever
  // and times out (observed on duration_hr_field, 2026-07-21). When a scroll
  // is genuinely needed, pin the view to the form's vertical scroll view.
  try {
    await $(key).waitUntilVisible(timeout: const Duration(seconds: 3));
  } on Exception {
    await _revealField($, key);
  }
  await $(key).enterText(text, settlePolicy: SettlePolicy.noSettle);
  await $.pump(const Duration(milliseconds: 200));
}

/// Bring [key] into view without guessing a scroll direction.
///
/// `scrollTo` drags one way only — it takes its direction from the
/// scrollable's `axisDirection`, which for this form is always `down`. When the
/// target sits *above* the current offset every drag moves further from it, so
/// the finder walks its full `maxScrolls` to the bottom of the form and only
/// then throws. That is what happened to `duration_hr_field` on the M1 run of
/// 2026-07-31, and a naive "try down, then up" retry does not fix it either:
/// the recovery pass has to out-scroll everything the first pass travelled just
/// to get back to where it started.
///
/// `ensureVisible` asks the target's own nearest Scrollable to reveal it, so
/// it needs neither a direction nor an iteration count and cannot overshoot.
/// The [key] must already exist in the tree — callers check that first, and a
/// widget that exists but still refuses to become hit-testable is a real
/// finding rather than something to scroll harder at.
Future<void> _revealField(
  PatrolIntegrationTester $,
  ValueKey<String> key,
) async {
  final target = find.byKey(key);
  if (target.evaluate().isEmpty) {
    throw StateError(
      '${key.value} is not in the widget tree at all — the form is showing a '
      'different mode or tab than this flow expects.',
    );
  }

  await $.tester.ensureVisible(target.first);
  // Fixed pump, never settle: this form can hold a weather/zone spinner.
  await $.pump(const Duration(milliseconds: 400));
}

/// Polls with fixed pumps (never settles) until [finder] matches nothing.
/// Returns whether the widget disappeared within [timeout].
Future<bool> _pumpUntilGone(
  PatrolIntegrationTester $,
  PatrolFinder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final polls = timeout.inMilliseconds ~/ 300;
  for (var i = 0; i < polls; i++) {
    if (!finder.exists) return true;
    await $.pump(const Duration(milliseconds: 300));
  }
  return !finder.exists;
}
