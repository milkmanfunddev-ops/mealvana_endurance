/// Fueling-window lifetime under **Patrol** — proves the window belongs to the
/// ACTIVITY BEING CREATED, not to the app session.
///
/// Why this flow exists (the gap it closes):
///   The unit suite calls `resetFuelingWindowForNewActivity()` DIRECTLY
///   (test/features/nutrition_plan/create_flow_fueling_controls_conformance_test.dart).
///   Nothing there proves the create SCREEN calls it. Delete the call from
///   `_NewActivityScreenState._initializeFromEventData` and every unit test
///   still passes while the bug returns — the defect lived in the WIRING, and
///   only a real screen-to-screen flow can see it.
///
/// The bug being pinned (Xuan, on-device 2026-09-03; app 7418566f, D-018):
///   The sport input controllers are `keepAlive` singletons. Stepping the
///   window once latches `preRunMinutesManuallySet`, and without a per-activity
///   reset that flag suppressed EVERY later §3a re-derivation — a window
///   stepped on tonight's run rode into tomorrow's activity, and the ratified
///   Race Pace ⇒ 3 h default could never fire again.
///
/// Flow:
///   launchApp → ensureAuthenticated → Fuel Timeline
///     → activity A: open create, step the window DOWN once (latches the flag)
///     → leave without generating (back)
///     → activity B: open create again
///     → ASSERT the window is NOT activity A's stepped value
///   (§3a's preset→window mapping is deliberately NOT asserted here — see the
///    note at step 4: the §3 clamp collapses every row above ~64 min to the
///    same ceiling on a fresh form, so such an assertion could only be green
///    by accident. The unit suite covers the mapping directly.)
///
/// Settle-policy notes: same as the sibling flows — the create screen can hold
/// a spinner while the profile/weather load, so taps use SettlePolicy.noSettle
/// and gating is by waitUntilVisible + fixed pumps, never pumpAndSettle.
///
/// Run:
///   patrol test --target integration_test/flows/fueling_window_persistence_flow_test.dart \
///     --flavor dev \
///     --dart-define-from-file=.env.dev.local \
///     --dart-define-from-file=secrets/integration_test.env \
///     --device "iPhone 17"
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../helpers/flow_launcher.dart';

const _minusKey = ValueKey('activity_create.fueling_window_minus');
const _valueKey = ValueKey('activity_create.fueling_window_value');

/// The stepper's rendered label, e.g. "2 HOURS 30 MIN" / "45 MINUTES".
String _windowLabel(PatrolIntegrationTester $) {
  final text = $.tester.widget<Text>(find.byKey(_valueKey));
  return text.data ?? '';
}

/// Timeline → add activity → RUNNING tab, ready for the window stepper.
Future<void> _openRunningCreateForm(PatrolIntegrationTester $) async {
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
}

void main() {
  patrolTest(
    'a window stepped on one activity does not leak into the next',
    ($) async {
      await launchApp();
      await $.pump(const Duration(milliseconds: 500));

      if (!await ensureAuthenticated(
        $,
        sentinel: const ValueKey('fuel_timeline.settings'),
      )) {
        markTestSkipped(noAuthSkipMessage());
        return;
      }

      // ---- 1. Activity A: step the window down once ---------------------
      await _openRunningCreateForm($);
      final defaultA = _windowLabel($);
      expect(
        defaultA,
        isNotEmpty,
        reason: 'the stepper must render a §3a default on a fresh activity',
      );

      await $(_minusKey).scrollTo(
        maxScrolls: 12,
        settleBetweenScrollsTimeout: const Duration(seconds: 1),
      );
      await $(_minusKey).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 300));
      final steppedA = _windowLabel($);
      expect(
        steppedA,
        isNot(defaultA),
        reason: 'stepping must change the window (and latch the manual flag)',
      );

      // ---- 2. Leave without generating ----------------------------------
      await $(
        const ValueKey('activity_create.back_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 600));

      // ---- 3. Activity B: a NEW activity re-derives ----------------------
      await _openRunningCreateForm($);
      final defaultB = _windowLabel($);
      expect(
        defaultB,
        isNot(steppedA),
        reason:
            'D-018: the window belongs to the activity being created. A value '
            'stepped on the previous activity must not seed this one — if this '
            'fails, resetFuelingWindowForNewActivity() is no longer called from '
            'the create screen and the unit suite cannot see it.',
      );

      // ---- 4. §3a preset mapping is NOT asserted here — deliberately -----
      // The original draft asserted `Race Pace ⇒ 3 HOURS`. That can never pass
      // on a fresh create form, and the reason generalises:
      //
      //   `defaultNewActivityDateTime` seeds a new activity at now + 1 h
      //   rounded up to the next 15 min, so time-until-start is ALWAYS 60-75
      //   minutes, and §3 clamps the window to it. Race's 180, mid's 150 and
      //   the moderate default's 120 therefore all render as the SAME ceiling
      //   value. No preset tap can distinguish a real re-derivation from a
      //   suppressed one while that clamp binds.
      //
      // The only rows below the ceiling are `<60` (45 min) and `easy 60-90`
      // (60 min), and both need the estimated duration moved — which on this
      // screen is coupled to pace and re-derived when an intensity preset
      // changes the pace zone, so a typed duration does not survive.
      // Reaching an unclamped state needs the date/time picker.
      //
      // §3a's table mapping is covered directly by the unit suite
      // (test/features/nutrition_plan/create_flow_fueling_controls_conformance_test.dart).
      // What only THIS flow can see is the wiring above: that the create
      // screen resets the window per activity. Asserting a clamped value here
      // would add a test that can only ever be green by accident.

      // ---- 5. Cleanup: leave the create flow, nothing was persisted -----
      await $(
        const ValueKey('activity_create.back_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 400));
    },
  );
}
