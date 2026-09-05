/// Recommendation test under **Patrol** — pre-workout occasion *stacking* by
/// fueling window (QA generate-plan SSOT invariant **H5**).
///
/// **D-017 is settled (Lee, 2026-08-05): the meal occasion is `t >= 120`.**
/// H5's bands are now `t < 30 / 30 <= t < 120 / t >= 120`, inclusive at the
/// bottom. Both cases below happen to sit clear of the moved boundary — the
/// stacking case steps to **120 min** and the top-off-only case to **15 min**
/// — so the assertions hold unchanged under the new rule; only the prose
/// needed correcting from "≥90" to "≥120".
///
/// **In all three CI target lists as of 2026-08-06** (the M1 list in
/// `.github/workflows/tests-selfhosted.yml` and both Codemagic dev lanes in
/// `codemagic.yaml`), after QA's green 2/2 local Patrol run on the iPhone 17
/// sim. `ci_config_contract_test` asserts those lists agree, so a one-sided
/// edit fails the unit suite.
///
/// Unlike `activities_crud_flow_test.dart` (which deliberately only asserts that
/// a plan *renders*), this asserts on the RECOMMENDATION output itself: which
/// pre-workout eating occasions the food-selection engine produces for a given
/// fueling window. It moves the H5 check off the manual simulator sweep and into
/// an automated, device-run guard.
///
/// H5 (qa/spec/recommendation/generate-plan.md): pre-workout occasions stack by
/// the fueling window —
///   • t < 30        → {Top-Off}
///   • 30 <= t < 120 → {Pre-Workout Snack, Top-Off}
///   • t >= 120      → {Full Meal, Pre-Workout Snack, Top-Off}
/// Occasion labels come from `preWorkoutFeedingTitle`
/// (lib/features/nutrition_plan/domain/pre_workout_feeding_labels.dart) and are
/// sport-aware for the meal: a running activity reads **"Pre-Run Meal"**, not
/// "Full Meal". This flow imports that function rather than hardcoding the
/// strings — see the note on the label constants below for what the hardcoded
/// version cost.
///
/// Diet-independent, so it runs as the single integration account
/// (avery@test.com) — no per-athlete credentials needed. Self-skips when there
/// is no session and no credentials.
///
/// Run:
///   patrol test --target integration_test/flows/recommendation_stacking_flow_test.dart \
///     --flavor dev \
///     --dart-define-from-file=.env.dev.local \
///     --dart-define-from-file=secrets/integration_test.env \
///     --device "iPhone 17 Pro"
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:mealvana_endurance/features/nutrition_plan/domain/pre_workout_feeding_labels.dart';

import '../helpers/flow_launcher.dart';

// Pre-workout occasion labels — the BEFORE sub-section titles rendered on the
// plan-detail screen (before_phase_widget.dart:295, title case, not uppercased).
//
// Derived from the domain function rather than hardcoded. The literals used to
// be `'Full Meal' / 'Pre-Workout Snack' / 'Top-Off'`, and the meal one went
// stale when the fueling rework made the title sport-aware: the app now renders
// "Pre-Run Meal" / "Pre-Ride Meal" / "Pre-Workout Meal" and emits the string
// "Full Meal" nowhere on this screen at all.
//
// That did NOT surface as a clean failure. `expect($(_fullMeal), findsWidgets)`
// blocked until the 600s test timeout instead of failing on the assertion, and
// the ≤30 case's `findsNothing` checks silently went VACUOUS — passing because
// the label could never appear, rather than because the engine withheld it.
//
// Deriving from `preWorkoutFeedingTitle` means a future rename moves these with
// the app. The flow builds a RUNNING activity, so that is the sport to pass.
// FC-1 (feeding-card v1, RATIFIED 2026-08-26): "Pre-Run Meal" for every
// sport — the sport-aware variant is retired (deferred-ledger P4).
final _fullMeal = preWorkoutFeedingTitle(PreWorkoutFeedingTier.meal);
final _snack = preWorkoutFeedingTitle(PreWorkoutFeedingTier.snack);
final _topOff = preWorkoutFeedingTitle(PreWorkoutFeedingTier.topOff);

void main() {
  patrolTest(
    'recommendation H5: a >=120 min fueling window stacks Full Meal + Snack + Top-Off',
    ($) async {
      // 8 × 15-min steps up from the floor = 120 min → the ≥120 band
      // (exactly on the boundary, which H5 defines as inclusive).
      final ready = await _generateRunPlanWithWindow(
        $,
        plusStepsFromFloor: 8,
        expectWindowLabel: '2 HOURS',
      );
      if (!ready) return; // skipped: no auth

      // The plan-detail Column is eager (SingleChildScrollView), so every
      // occasion label is in the tree regardless of scroll position.
      expect(
        $(_fullMeal),
        findsWidgets,
        reason: 'A ≥120 min window must recommend a Full Meal occasion (H5).',
      );
      expect(
        $(_snack),
        findsWidgets,
        reason: 'A ≥120 min window must recommend a Pre-Workout Snack (H5).',
      );
      expect(
        $(_topOff),
        findsWidgets,
        reason: 'A ≥120 min window must recommend a Top-Off occasion (H5).',
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  patrolTest(
    'recommendation H5: a <=30 min fueling window yields Top-Off only (no Meal / Snack)',
    ($) async {
      // 1 × 15-min step up from the floor = 15 min → the t < 30 band.
      final ready = await _generateRunPlanWithWindow(
        $,
        plusStepsFromFloor: 1,
        expectWindowLabel: '15 MINUTES',
      );
      if (!ready) return; // skipped: no auth

      expect(
        $(_topOff),
        findsWidgets,
        reason:
            'A ≤30 min window must still recommend a Top-Off occasion (H5).',
      );
      expect(
        $(_fullMeal),
        findsNothing,
        reason:
            'A ≤30 min window must NOT recommend a Full Meal occasion (H5).',
      );
      expect(
        $(_snack),
        findsNothing,
        reason: 'A ≤30 min window must NOT recommend a Pre-Workout Snack (H5).',
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

/// Boots, authenticates, creates a running activity with a deterministic
/// fueling window, generates the plan, and lands on the plan-detail screen.
/// Returns false (after `markTestSkipped`) when the run has no auth — the
/// caller should early-return.
Future<bool> _generateRunPlanWithWindow(
  PatrolIntegrationTester $, {
  required int plusStepsFromFloor,
  required String expectWindowLabel,
}) async {
  await launchApp();
  // Do NOT pumpAndSettle: startup may show a persistent spinner.
  await $.pump(const Duration(milliseconds: 500));

  if (!await ensureAuthenticated($)) {
    markTestSkipped(noAuthSkipMessage());
    return false;
  }

  final workoutName = 'Patrol H5 ${DateTime.now().millisecondsSinceEpoch}';

  // ---- Running create form ------------------------------------------------
  await $(
    const ValueKey('bottom_nav.timeline_tab'),
  ).tap(settlePolicy: SettlePolicy.noSettle);
  await $(
    const ValueKey('macro_dashboard.add_activity'),
  ).waitUntilVisible(timeout: const Duration(seconds: 20));
  await $(
    const ValueKey('macro_dashboard.add_activity'),
  ).tap(settlePolicy: SettlePolicy.noSettle);
  await $(
    const ValueKey('activity_create.tab_running'),
  ).waitUntilVisible(timeout: const Duration(seconds: 20));
  await $(
    const ValueKey('activity_create.tab_running'),
  ).tap(settlePolicy: SettlePolicy.noSettle);
  await $.pump(const Duration(milliseconds: 400));

  // ---- Required fields ----------------------------------------------------
  await _fillField(
    $,
    const ValueKey('activity_create.workout_name_field'),
    workoutName,
  );
  await _fillField($, const ValueKey('activity_create.distance_field'), '10');
  // Secondary input depends on the Duration/Pace toggle's mode. Fill it when
  // Duration mode is active, but treat it as BEST-EFFORT: the form derives a
  // valid duration from distance × the selected pace by default, and H5 only
  // depends on the pre-workout WINDOW (below), not the run duration.
  const durHrKey = ValueKey('activity_create.duration_hr_field');
  if ($(durHrKey).exists) {
    try {
      await _fillField($, durHrKey, '1');
      await _fillField(
        $,
        const ValueKey('activity_create.duration_mins_field'),
        '0',
      );
    } on Object catch (_) {
      // Fall back to the form's derived default duration.
      //
      // Catch Object, not Exception: _ensureVisibleInForm raises a StateError
      // (an Error, not an Exception) when a field is absent entirely, which is
      // exactly the Pace-mode case this block is already best-effort about.
      // `on Exception` let that escape and fail the whole flow over an optional
      // field.
    }
  }

  // Fasted must be OFF or the pre-workout occasions are all zeroed. The form
  // defaults to off, so we do not toggle it. (If a profile ever defaults
  // fasted-on, the ≥120 test would lose its occasions — revisit here if so.)

  // ---- Schedule tomorrow (ruled clamp headroom) ---------------------------
  // CF-1 (create-flow-fueling-controls, AMENDED 2026-09-03): the stepper's
  // MAXIMUM is min(240, time-until-start). A quick-add activity seeds at
  // now + ~1 h (defaultNewActivityDateTime), so the ≥120-min H5 window is
  // UNREACHABLE from the stepper without rescheduling — by design, not by
  // defect. Move the session to tomorrow (same seeded time ⇒ ~24 h out ⇒
  // the full 240 cap) via the real pickers: date grid → OK → time OK.
  await _ensureVisibleInForm(
    $,
    const ValueKey('activity_create.edit_datetime_button'),
  );
  await $(
    const ValueKey('activity_create.edit_datetime_button'),
  ).tap(settlePolicy: SettlePolicy.noSettle);
  await $.pump(const Duration(milliseconds: 600));
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  if (tomorrow.day == 1) {
    // Month boundary: tomorrow's cell lives in the next month's grid.
    await $(const Key('nextMonthIcon')).tap(settlePolicy: SettlePolicy.noSettle);
    await $.pump(const Duration(milliseconds: 300));
  }
  await $('${tomorrow.day}').tap(settlePolicy: SettlePolicy.noSettle);
  await $.pump(const Duration(milliseconds: 200));
  await $('OK').tap(settlePolicy: SettlePolicy.noSettle); // date dialog
  await $.pump(const Duration(milliseconds: 600));
  await $('OK').tap(settlePolicy: SettlePolicy.noSettle); // time dialog (keep)
  await $.pump(const Duration(milliseconds: 400));

  // ---- Deterministic fueling window ---------------------------------------
  // Floor it (the minus button clamps at 0 and becomes a no-op ElevatedButton),
  // then step up. Each step is 15 min on the 00/15/30/45 grid (CF-1).
  FocusManager.instance.primaryFocus?.unfocus();
  await $.pump(const Duration(milliseconds: 800));
  await _ensureVisibleInForm(
    $,
    const ValueKey('activity_create.fueling_window_minus'),
  );
  for (var i = 0; i < 34; i++) {
    if ($('0 MINUTES').exists) break; // floored
    await $(
      const ValueKey('activity_create.fueling_window_minus'),
    ).tap(settlePolicy: SettlePolicy.noSettle);
    await $.pump(const Duration(milliseconds: 120));
  }
  for (var i = 0; i < plusStepsFromFloor; i++) {
    await $(
      const ValueKey('activity_create.fueling_window_plus'),
    ).tap(settlePolicy: SettlePolicy.noSettle);
    await $.pump(const Duration(milliseconds: 120));
  }
  // Self-verify the window is exactly what we intended before generating.
  expect(
    $(expectWindowLabel),
    findsWidgets,
    reason: 'Fueling window should read "$expectWindowLabel" after stepping.',
  );

  // ---- Generate → adjust-macros → Create Plan → plan detail ---------------
  FocusManager.instance.primaryFocus?.unfocus();
  await $.pump(const Duration(milliseconds: 300));
  await $(const ValueKey('activity_create.generate_plan_button'))
      .scrollTo(settleBetweenScrollsTimeout: const Duration(seconds: 1))
      .tap(settlePolicy: SettlePolicy.noSettle);
  await $(
    const ValueKey('adjust_macros.create_plan_button'),
  ).waitUntilVisible(timeout: const Duration(seconds: 60));
  await $(const ValueKey('adjust_macros.create_plan_button'))
      .scrollTo(settleBetweenScrollsTimeout: const Duration(seconds: 1))
      .tap(settlePolicy: SettlePolicy.noSettle);
  await $(
    const ValueKey('plan_detail.title'),
  ).waitUntilVisible(timeout: const Duration(seconds: 40));
  // Let the plan-detail sections build.
  await $.pump(const Duration(milliseconds: 600));
  return true;
}

/// Dismiss any keyboard, ensure the field is on screen (scroll the form's
/// vertical view only if needed), then enter text. Mirrors the settle-policy
/// of activities_crud_flow_test.dart.
Future<void> _fillField(
  PatrolIntegrationTester $,
  ValueKey<String> key,
  String text,
) async {
  // Dismiss the prior field's keyboard (it overlays lower fields and makes them
  // un-hit-testable) and give it time to fully animate out before we scroll to
  // or measure the visibility of the next field.
  FocusManager.instance.primaryFocus?.unfocus();
  await $.pump(const Duration(milliseconds: 800));
  await _ensureVisibleInForm($, key);
  await $(key).enterText(text, settlePolicy: SettlePolicy.noSettle);
  await $.pump(const Duration(milliseconds: 200));
}

/// Bring [key] into view without guessing a scroll direction.
///
/// This used a blind `scrollTo`, which is what burned the 600s timeout on
/// `activity_create.duration_hr_field` in the M1 run of 2026-08-07. `scrollTo`
/// drags ONE way — it takes its direction from the scrollable's `axisDirection`,
/// always `down` on this form — so when the target sits *above* the current
/// offset every drag moves further from it, and the finder walks its full
/// `maxScrolls` to the bottom before throwing. At a 1s settle per drag that is
/// minutes of wall clock per attempt.
///
/// The old comment here also claimed this form has no horizontal scrollables.
/// It does: the sport selector strip. activities_crud_flow_test hit the same
/// wall on the same field on 2026-07-31 and documented both facts.
///
/// `ensureVisible` asks the target's own nearest Scrollable to reveal it, so it
/// needs neither a direction nor an iteration count and cannot overshoot. In
/// the 2026-08-07 run activities_crud passed on this exact key using it while
/// this flow timed out without — same app, same form, same build.
///
/// A widget that exists but still refuses to become hit-testable is a real
/// finding, not something to scroll harder at.
Future<void> _ensureVisibleInForm(
  PatrolIntegrationTester $,
  ValueKey<String> key,
) async {
  // Cheapest path first: once the keyboard is dismissed the form usually
  // already fits the viewport, and then no scroll is needed at all.
  try {
    await $(key).waitUntilVisible(timeout: const Duration(seconds: 3));
    return;
  } on Exception {
    // Fall through to an explicit, direction-free reveal.
  }

  final target = find.byKey(key);
  if (target.evaluate().isEmpty) {
    throw StateError(
      '${key.value} is not in the widget tree at all — the create form is '
      'showing a different mode or tab than this flow expects.',
    );
  }

  await $.tester.ensureVisible(target.first);
  // Fixed pump, never settle: this form can hold a weather/zone spinner.
  await $.pump(const Duration(milliseconds: 400));
}
