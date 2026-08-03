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
///     → ASSERT the brick's name on plan detail (see below)
///     → back to the timeline; a brick tile renders (smoke, see below)
///     → CLEANUP (best effort, only when unambiguous): swipe the tile away
///
/// **Where identity is checked.** `TimelineBrickTile` never renders the
/// brick's own name — it shows "BRICK", a leg summary and per-sport labels —
/// so a name/stamp finder on the timeline can never match a brick however long
/// it polls. Plan detail's app-bar title is the only surface that shows it, so
/// that is where this flow proves it created *its* brick.
///
/// The timeline step is a deliberate SMOKE check and is labelled as one. It
/// cannot re-establish identity, and counting tiles does not work either: the
/// timeline is a lazily-built list, so `find.byType` only sees the tiles
/// currently mounted, and a count delta fails whenever the new brick sorts
/// off-screen. That is a false failure, and false failures erode a suite faster
/// than missing coverage does — tried on 2026-08-03, where the brick was
/// persisted (Patrol Brick 1785766143061) while the mounted count never moved.
///
/// Asserting persisted state is the right answer and is not available yet:
/// DatabaseVerification needs an authenticated user JWT (RLS returns [] for the
/// anon key) and its getCurrentUserId is unimplemented. Until that lands, the
/// strong assertion in this flow is the plan-detail title, not the timeline.
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

import 'package:mealvana_endurance/features/fuel_timeline/presentation/widgets/timeline_brick_tile.dart';

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

      // ---- 1. Fuel Timeline → "+ Add Activity" --------------------------
      // Put the timeline on today with the All filter first. Both "+ Add
      // Activity" and the workout cards only render under All/Workout, and
      // both the selected day and the filter are app-level state that survive
      // from whichever flow ran before this one in the same app session — so
      // neither the entry point nor the end-of-test assertion can assume them.
      await $(
        const ValueKey('bottom_nav.timeline_tab'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await ensureTimelineOnToday($);

      // Baseline for the failure message only. It is NOT used as an
      // assertion: the timeline is lazily built, so a mounted-tile count says
      // nothing reliable about what the day contains (see the note at step 9).
      final bricksBefore = find.byType(TimelineBrickTile).evaluate().length;

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

      // ---- 7. Create the plan → land on plan detail ----------------------
      await $(
        const ValueKey('adjust_macros.create_plan_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);

      // Wait for plan detail BEFORE unwinding. Without this the back-button
      // walk starts while the push is still in flight, taps
      // `adjust_macros.back_button` instead, and reverses out of the create
      // stack mid-creation (observed on the M1 run of 2026-08-03: the flow
      // never tapped plan_detail.back_button at all).
      await $(
        const ValueKey('plan_detail.title'),
      ).waitUntilVisible(timeout: const Duration(seconds: 40));

      // ---- 8. IDENTITY — assert the title here, not on the timeline ------
      // This is the only surface that renders the brick's own name.
      // TimelineBrickTile deliberately does not: it shows "BRICK", a leg
      // summary and per-sport labels, so a stamp-matching finder on the
      // timeline can never match a brick no matter how long it polls. That is
      // what failed this flow on 2026-08-03 while the row sat happily in
      // Supabase (Patrol Brick 1785761943969, not deleted).
      expect(
        $(const ValueKey('plan_detail.title')).text,
        contains(stamp),
        reason:
            'Plan detail should be showing the brick we just created; its '
            'title is the only place the brick name is rendered.',
      );

      // ---- 9. Back to the timeline; a brick tile is rendered -------------
      await _returnToTimeline($);
      // Re-assert day + filter after the create stack unwinds: a workout card
      // is hidden under the Meals filter, and both are shared app state.
      await ensureTimelineOnToday($);

      // A RENDERING check, not an identity one — and deliberately labelled as
      // such so nobody mistakes it for proof that *this* brick is on screen.
      //
      // Identity was already established above, on plan detail. It cannot be
      // re-established here: the tile exposes nothing unique, and counting
      // tiles does not work either — the timeline is a lazily-built list, so
      // `find.byType` only ever sees the handful of tiles currently mounted.
      // A count delta therefore fails whenever the new brick sorts off-screen,
      // which is a false failure, and false failures erode a suite faster than
      // missing coverage does. (Tried on 2026-08-03: the brick was persisted —
      // Patrol Brick 1785766143061 — while the mounted count never moved.)
      //
      // Asserting persisted state is the right answer and is NOT available
      // yet: DatabaseVerification needs an authenticated user JWT (RLS returns
      // [] for the anon key) and its getCurrentUserId is unimplemented. Until
      // that lands, this step is honestly a smoke check.
      final brickTile = find.byType(TimelineBrickTile);
      final brickTileRendered = await waitForOnTimeline(
        $,
        brickTile,
        timeout: const Duration(seconds: 30),
      );
      expect(
        brickTileRendered,
        isTrue,
        reason:
            'The Fuel Timeline rendered no brick tile at all after a brick was '
            'created (the day held $bricksBefore when this flow started, and '
            'plan detail confirmed the brick was written). Zero bricks here '
            'means the timeline is not rendering the brick node type — a '
            'regression in the brick-grouping path, not a lost write.',
      );

      // ---- 10. CLEANUP — best effort, never fails the run ----------------
      // Cannot target THIS brick specifically (no per-brick text or key), so
      // clean up only when exactly one brick is on the day — otherwise a
      // leftover from an earlier run would be deleted instead. A skipped
      // cleanup is not a failure: the name is stamped, so nothing collides.
      try {
        if (brickTile.evaluate().length == 1) {
          final card = find.ancestor(
            of: brickTile,
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
        } else {
          debugPrint(
            '[brick_plan_flow] ${brickTile.evaluate().length} bricks mounted '
            '— skipping cleanup rather than deleting the wrong one.',
          );
        }
      } on Exception catch (e) {
        debugPrint('[brick_plan_flow] cleanup skipped: $e');
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
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
