/// Brick workout create → plan → verify → clean up, under **Patrol**.
///
/// Bricks are the app's only multi-sport path and they have their own macro
/// service, their own metadata column and their own rendering branch in the
/// adjust-macros table. Every bug in bf0b591f that was *not* a shared utility
/// lived on that branch: fluid targets rendered as raw millilitres under an
/// "oz" header (a 3.5 h brick read "3105oz"), and provenance was erased on
/// re-save. Nothing in CI exercised it.
///
/// Flow:
///   launchApp (flavor-aware) → ensureAuthenticated (reuse session, else login)
///     → Fuel Timeline → "+ Add Activity" → Brick tab
///     → name the brick uniquely
///     → select Bike + Run (two disciplines is the minimum for a brick)
///     → Generate Plan → adjust-macros
///     → ASSERT the fluid row is in a plausible imperial range (the "3105oz"
///       guard — see below)
///     → Create Plan → lands on the plan detail screen
///     → back to the timeline; the brick card is there
///     → CLEANUP (best effort): swipe the card away
///
/// **The fluids assertion.** The table renders whole numbers with a unit
/// header. A brick's during-phase fluid target in ounces is realistically tens
/// of ounces; the same figure in millilitres is ~30x larger. So a four-digit
/// number under an "oz" header is the bug, and this flow fails on it rather
/// than eyeballing a screenshot. It reads the rendered row rather than the
/// model, because the bug was purely in the presentation layer — the model was
/// always correct millilitres.
///
/// **No AI.** The brick path uses the deterministic macro edge function, not
/// plan generation via LLM.
///
/// Settle policy: the Fuel Timeline holds a persistent CircularProgressIndicator
/// while tracking/plan data refreshes, so every default-settle action burns its
/// full 10 s pumpAndTrySettle. Taps use SettlePolicy.noSettle gated by
/// waitUntilVisible (which polls with plain 100 ms pumps and never settles).
///
/// Auth: reuses an existing session, else the flavor-matched INTEGRATION_TEST
/// creds; self-skips when neither is available.
///
/// Run:
///   patrol test --target integration_test/flows/brick_plan_flow_test.dart \
///     --flavor dev \
///     --dart-define-from-file=.env.dev.local \
///     --dart-define-from-file=secrets/integration_test.env \
///     --device "iPhone 17 Pro"
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../helpers/flow_launcher.dart';

/// Largest believable single-phase fluid target in **ounces**. A 3.5 h brick
/// tops out around 120 oz; the millilitre figure for the same target is ~3100.
/// Anything at or above this under an imperial header is a unit-conversion bug.
const _implausibleOunces = 400;

void main() {
  patrolTest(
    'create a brick, generate its plan, verify units, delete it',
    ($) async {
      await launchApp();
      // Do NOT pumpAndSettle: startup can hold a persistent spinner.
      await $.pump(const Duration(milliseconds: 500));

      if (!await ensureAuthenticated($)) {
        markTestSkipped(noAuthSkipMessage());
        return;
      }

      final stamp = '${DateTime.now().millisecondsSinceEpoch}';
      final brickName = 'Patrol Brick $stamp';
      // The timeline renders activity titles uppercased, so match on the stamp,
      // which is case-invariant.
      final onTimeline = find.textContaining(stamp);

      // ---- 1. Fuel Timeline → "+ Add Activity" --------------------------
      // Force the All filter first. Both "+ Add Activity" and the workout
      // cards themselves only render under All/Workout, and the filter is
      // app-level state that survives from whichever flow ran before this one
      // in the same app session — so neither the entry point nor the
      // end-of-test assertion can assume it.
      await $(
        const ValueKey('bottom_nav.timeline_tab'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await _selectAllFilter($);
      await $(
        const ValueKey('fuel_timeline.add_activity'),
      ).waitUntilVisible(timeout: const Duration(seconds: 25));
      await $(
        const ValueKey('fuel_timeline.add_activity'),
      ).tap(settlePolicy: SettlePolicy.noSettle);

      // ---- 2. Brick tab --------------------------------------------------
      await $(
        const ValueKey('activity_create.tab_brick'),
      ).waitUntilVisible(timeout: const Duration(seconds: 25));
      await $(
        const ValueKey('activity_create.tab_brick'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 500));

      // ---- 3. Name it ----------------------------------------------------
      await $(
        const ValueKey('brick.workout_name_field'),
      ).waitUntilVisible(timeout: const Duration(seconds: 15));
      FocusManager.instance.primaryFocus?.unfocus();
      await $.pump(const Duration(milliseconds: 300));
      await $(
        const ValueKey('brick.workout_name_field'),
      ).enterText(brickName, settlePolicy: SettlePolicy.noSettle);
      FocusManager.instance.primaryFocus?.unfocus();
      await $.pump(const Duration(milliseconds: 300));

      // ---- 4. Two disciplines — the minimum that makes it a brick --------
      await $(
        const ValueKey('brick.discipline_bike_chip'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 300));
      await $(
        const ValueKey('brick.discipline_run_chip'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 500));

      // The total-duration label is the brick tab's own summary; its presence
      // confirms both segments registered.
      expect(
        $(const ValueKey('brick.total_duration_label')).exists,
        isTrue,
        reason:
            'Selecting two disciplines should produce a brick duration total.',
      );

      // ---- 5. Generate the plan -----------------------------------------
      await $(const ValueKey('activity_create.generate_plan_button'))
          .scrollTo(settleBetweenScrollsTimeout: const Duration(seconds: 1))
          .tap(settlePolicy: SettlePolicy.noSettle);

      // Macro generation hits an edge function; give it room. waitUntilVisible
      // polls with plain pumps, so it tolerates the spinner.
      await $(
        const ValueKey('adjust_macros.create_plan_button'),
      ).waitUntilVisible(timeout: const Duration(seconds: 90));

      // ---- 6. The units guard -------------------------------------------
      // Read the fluids row as rendered. In imperial the numbers are tens of
      // ounces; unconverted millilitres are ~30x that.
      final fluidsRow = $(const ValueKey('adjust_macros.row_fluids'));
      expect(
        fluidsRow.exists,
        isTrue,
        reason: 'The brick macro table should render a fluids row.',
      );

      final rendered = $.tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('adjust_macros.row_fluids')),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data ?? '')
          .join(' ');

      final isImperial = rendered.toLowerCase().contains('oz');
      if (isImperial) {
        for (final match in RegExp(r'\d+').allMatches(rendered)) {
          final value = int.parse(match.group(0)!);
          expect(
            value,
            lessThan(_implausibleOunces),
            reason:
                'Fluids row rendered "$rendered" under an ounces header. A value '
                'of $value oz is a millilitre figure that was never converted — '
                'this is the "3105oz" bug (bf0b591f).',
          );
        }
      }

      // ---- 7. Create the plan -------------------------------------------
      await $(
        const ValueKey('adjust_macros.create_plan_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);

      // ---- 8. Back to the timeline; the brick is there -------------------
      await _returnToTimeline($);
      // Re-assert the filter after the create stack unwinds: a workout card is
      // hidden under the Meals filter, so an unfiltered timeline is part of the
      // precondition for this assertion, not an incidental detail.
      await _selectAllFilter($);
      await $(
        onTimeline,
      ).waitUntilVisible(timeout: const Duration(seconds: 30));
      expect(
        $(onTimeline),
        findsWidgets,
        reason: 'The created brick should appear on the Fuel Timeline.',
      );

      // ---- 9. CLEANUP — best effort, never fails the run -----------------
      try {
        final card = find.ancestor(
          of: find.textContaining(stamp),
          matching: find.byType(Dismissible),
        );
        if (card.evaluate().isNotEmpty) {
          await $.tester.drag(card.first, const Offset(-500, 0));
          for (var i = 0; i < 4; i++) {
            await $.pump(const Duration(milliseconds: 300));
          }
          // Let the undo snackbar time out without tapping Undo.
          for (var i = 0; i < 16; i++) {
            await $.pump(const Duration(milliseconds: 300));
          }
        }
      } on Exception catch (e) {
        // A leftover row on the dev tester account is not a test failure — the
        // name is stamped, so the next run will not collide with it.
        debugPrint('[brick_plan_flow] cleanup skipped: $e');
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

/// Put the Fuel Timeline on its All filter, tolerating the pill not being
/// there yet.
///
/// The filter is app-level state that persists across flows in the same app
/// session, so a flow that needs workout cards visible has to set it rather
/// than inherit whatever the previous test left behind. Best-effort: if the
/// pill never appears the caller's own `waitUntilVisible` reports the real
/// problem, which is a better error than a failure inside a helper.
Future<void> _selectAllFilter(PatrolIntegrationTester $) async {
  const filterAll = ValueKey('fuel_timeline.filter_all');
  try {
    await $(filterAll).waitUntilVisible(timeout: const Duration(seconds: 20));
    await $(filterAll).tap(settlePolicy: SettlePolicy.noSettle);
    await $.pump(const Duration(milliseconds: 400));
  } on Exception catch (e) {
    debugPrint('[brick_plan_flow] could not select the All filter: $e');
  }
}

/// Unwind the create-flow stack until the timeline tab is showing again.
Future<void> _returnToTimeline(PatrolIntegrationTester $) async {
  const sentinel = ValueKey('bottom_nav.timeline_tab');
  const backButtons = [
    ValueKey('plan_detail.back_button'),
    ValueKey('adjust_macros.back_button'),
    ValueKey('activity_create.back_button'),
  ];

  for (var i = 0; i < 6; i++) {
    if ($(sentinel).exists) return;
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
  await $(sentinel).waitUntilVisible(timeout: const Duration(seconds: 30));
}
