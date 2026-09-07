/// Energy breakdown flow under **Patrol** — the `daily_macros` read path, which
/// had no end-to-end coverage at all before this flow.
///
/// The breakdown sheet is the only surface in the shipped build that renders
/// `EnergySourceBreakdown`, and it is where the TDEE arithmetic the whole plan
/// engine depends on becomes visible to the user: resting + daily activity +
/// workout, summing into TDEE. A regression here (a null summary, a divide-by-
/// zero, a provider that never resolves) shows up as a blank or spinning sheet,
/// which no unit test on the calculator would catch.
///
/// Flow:
///   launchApp → ensureAuthenticated
///     → Fuel Timeline tab
///     → make the breakdown button reachable: the card must be rendered
///       (tracking on) AND expanded — `_breakdownButton` is built only by
///       `_expandedAll` / `_expandedMeals`, so a collapsed card has no button
///       at all. Flows share ONE app session, so neither `trackingOn` nor
///       `dashOpen` can be assumed from its default.
///     → tap the dashboard's "Full Breakdown" button
///     → the Breakdown Pager renders (macro_dashboard.pager) with its
///       unconditional 'Resting' burn row
///     → dismiss via pager_close and confirm we are back on the timeline.
///
/// Deliberately NOT asserted: the pager's Workout/Daily-activity rows carry
/// data-dependent marks (verified/self-reported/estimated), so requiring
/// specifics would make this flow depend on the tester account's data for the
/// day. The pager + Resting row are unconditional, which is what makes this a
/// stable assertion rather than a seeded-data one. (Re-anchored from the old
/// fuel-timeline sheet's nutrition_diary.* rows when home-shell@v1 deleted
/// that screen.)
///
/// Also not asserted: the Weekly tab's `weekly_chart.*` keys. Per
/// energy_breakdown_sheet.dart, `daily_macros`' WeeklyOverviewChart is dead
/// code in this build — those keys render nothing.
///
/// Auth: reuses an existing session, else the flavor-matched INTEGRATION_TEST
/// creds; self-skips when neither is available.
///
/// Run:
///   patrol test --target integration_test/flows/energy_breakdown_flow_test.dart \
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
    'energy breakdown sheet renders the resting → TDEE decomposition',
    ($) async {
      await launchApp();
      // No pumpAndSettle: startup may show persistent spinners.
      await $.pump(const Duration(milliseconds: 500));

      if (!await ensureAuthenticated($)) {
        markTestSkipped(noAuthSkipMessage());
        return;
      }

      // ---- 1. Fuel Timeline ------------------------------------------------
      await $(
        const ValueKey('kyle_tab_bar.item.timeline'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $(
        const ValueKey('macro_dashboard.add_food'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));

      // ---- 2. Make sure the breakdown button is reachable -------------------
      //
      // Three conditions gate it, and only the middle one is usually wrong:
      //   1. tracking on   → EnergyDashboardCard renders at all
      //   2. card EXPANDED → _breakdownButton is built only by _expandedAll /
      //                      _expandedMeals; the collapsed card has no button
      //   3. filter All or Meals → _expandedWorkout has no button either
      //
      // (2) is the gate this flow originally got wrong: it treated a missing
      // button as "tracking is off" and tapped the tracking toggle, which
      // turned tracking OFF on an already-tracking timeline and hid the card
      // completely. Check for the card first, and only touch tracking when the
      // card itself is absent.
      //
      // (3) is already handled: ensureTimelineOnToday (called by
      // ensureAuthenticated) selects the All filter, and flows share one app
      // session so that reset matters.
      const breakdownButton = ValueKey('macro_dashboard.full_breakdown');
      const dashToggle = ValueKey('macro_dashboard.energy_expand');

      if (!$(dashToggle).exists) {
        // No card at all → tracking really is off. This is the only case where
        // touching the tracking toggle is correct.
        final tracking = $(const ValueKey('macro_dashboard.tracking_toggle'));
        if (tracking.exists) {
          await tracking.tap(settlePolicy: SettlePolicy.noSettle);
          await $.pump(const Duration(milliseconds: 800));
        }
      }
      await $(
        dashToggle,
      ).waitUntilVisible(timeout: const Duration(seconds: 20));

      // Card present but collapsed → expand it. dashOpen is app-level state
      // shared across the whole bundle, so its value here depends on what ran
      // before; never assume a default.
      if (!$(breakdownButton).exists) {
        await $(dashToggle).tap(settlePolicy: SettlePolicy.noSettle);
        await $.pump(const Duration(milliseconds: 800));
      }
      await $(
        breakdownButton,
      ).waitUntilVisible(timeout: const Duration(seconds: 20));

      // ---- 3. Open the breakdown sheet -------------------------------------
      await $(breakdownButton).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 500));

      // The dashboard's Full Breakdown opens the Breakdown Pager (the old
      // fuel-timeline sheet and its nutrition_diary.* rows are gone with the
      // FuelTimelineScreen). The pager surface itself plus its unconditional
      // 'Resting' burn row are the stable anchors: Resting renders regardless
      // of the day's data, so if the breakdown provider resolved at all it is
      // present.
      await $(
        const ValueKey('macro_dashboard.pager'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));

      expect(
        $('Resting'),
        // findsWidgets, not findsOneWidget: the info-dot overlay content also
        // titles itself 'Resting' and may sit (offstage) in the same tree.
        findsWidgets,
        reason:
            'The pager must show the resting-energy component. Its absence '
            'means the daily breakdown resolved empty rather than with a BMR.',
      );

      // ---- 4. Dismiss, back to the timeline --------------------------------
      // Use the pager's own close control, not a native back press: this suite
      // runs on the iOS simulator, where Patrol's pressBack is unavailable.
      await $(
        const ValueKey('macro_dashboard.pager_close'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 600));

      await $(
        const ValueKey('macro_dashboard.add_food'),
      ).waitUntilVisible(timeout: const Duration(seconds: 15));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
