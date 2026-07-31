/// Unified meal/activity card interaction (391e3fdb) under **Patrol** —
/// log a meal manually, tap its Fuel Timeline card to open the edit surface,
/// come back, then swipe the card to delete it with the Undo snackbar.
///
/// Flow:
///   launchApp (flavor-aware) → ensureAuthenticated (reuse session, else login)
///     → Fuel Timeline tab → "+ Add Food" → Manual tab
///     → enter a uniquely-named meal → Save → back to the timeline
///     → the meal card appears (timeline names render UPPERCASE)
///     → TAP the card → 'Edit Meal' screen opens (tap-anywhere-to-edit)
///     → back (no edits, so no discard prompt)
///     → SWIPE the card → 'Meal deleted' MealvanaSnackbar with Undo
///     → snackbar times out → the card is gone
///
/// Settle-policy notes:
///   The Fuel Timeline keeps a persistent CircularProgressIndicator while
///   tracking/plan data refreshes, so every default-settle tap burns its full
///   10 s pumpAndTrySettle. All taps here use SettlePolicy.noSettle, gated by
///   waitUntilVisible (plain 100 ms pump polls — never settles) and fixed
///   $.pump durations. The Dismissible swipe uses a raw drag + fixed pumps.
///
/// Auth:
///   Boots via the shared launcher (helpers/flow_launcher.dart) and signs in
///   with the flavor-matched TestConfig.loginEmail/loginPassword. On a clean
///   install with no session and no credentials the test self-skips.
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
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';

import '../helpers/flow_launcher.dart';

void main() {
  patrolTest(
    'log a meal → tap card opens edit → swipe card deletes with Undo',
    ($) async {
      await launchApp();
      // Do NOT call pumpAndSettle: the app may have a persistent loading
      // spinner during startup. ensureAuthenticated uses explicit polls.
      await $.pump(const Duration(milliseconds: 500));

      // The subsequent steps drive the Fuel Timeline header, so gate on its
      // settings gear rather than the default nav-bar sentinel.
      if (!await ensureAuthenticated(
        $,
        sentinel: const ValueKey('fuel_timeline.settings'),
      )) {
        markTestSkipped(noAuthSkipMessage());
        return;
      }

      final stamp = DateTime.now().millisecondsSinceEpoch;
      final mealName = 'Patrol Meal $stamp';
      // TimelineNodeTile renders meal names uppercased.
      final cardText = mealName.toUpperCase();

      // ---- 1. Fuel Timeline → + Add Food → Manual tab --------------------
      await $(
        const ValueKey('bottom_nav.timeline_tab'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $(
        const ValueKey('fuel_timeline.add_food'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      await $(
        const ValueKey('fuel_timeline.add_food'),
      ).tap(settlePolicy: SettlePolicy.noSettle);

      await $('Manual').waitUntilVisible(timeout: const Duration(seconds: 15));
      await $('Manual').tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 400));

      // ---- 2. Fill the manual form and Save ------------------------------
      await $.tester.enterText(
        find.widgetWithText(TextFormField, 'Meal name'),
        mealName,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await $.pump(const Duration(milliseconds: 300));
      // Target the button by key, and pin the scroll to the form's own
      // vertical scroll view.
      //
      // `$('Save').scrollTo(...)` failed on the M1 run of 2026-07-31: with no
      // `view:` the finder defaults to the first Scrollable in the tree, which
      // on this screen is horizontal, so every drag moved sideways and the
      // finder ran out its iterations. Matching on the text 'Save' is also
      // ambiguous — `manual_log.save_button` names exactly one widget.
      await $(const ValueKey('manual_log.save_button'))
          .scrollTo(
            view: find.byType(SingleChildScrollView).first,
            maxScrolls: 12,
            settleBetweenScrollsTimeout: const Duration(milliseconds: 500),
          )
          .tap(settlePolicy: SettlePolicy.noSettle);
      await $(
        'Meal logged!',
      ).waitUntilVisible(timeout: const Duration(seconds: 15));

      // ---- 3. Back to the timeline — the card is there -------------------
      await $(
        const ValueKey('log_meal.back_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $(cardText).waitUntilVisible(timeout: const Duration(seconds: 20));

      // ---- 4. TAP the card → edit surface (tap-anywhere-to-edit) ---------
      // noSettle: the Edit Meal screen loads async and the timeline spinner
      // would otherwise burn the settle timeout. waitUntilVisible polls with
      // plain pumps, so it tolerates the load.
      await $(cardText).tap(settlePolicy: SettlePolicy.noSettle);
      await $(
        'Edit Meal',
      ).waitUntilVisible(timeout: const Duration(seconds: 20));

      // Back out without editing (no discard prompt fires when unchanged).
      await $.tester.tap(find.byType(CustomAppBarBackButton).first);
      await $.pump(const Duration(milliseconds: 400));
      await $(cardText).waitUntilVisible(timeout: const Duration(seconds: 20));

      // ---- 5. SWIPE the card → soft delete + Undo snackbar ---------------
      final cardRow = find.ancestor(
        of: find.text(cardText),
        matching: find.byType(Dismissible),
      );
      expect(
        cardRow,
        findsWidgets,
        reason: 'Meal card should be wrapped in a Dismissible.',
      );
      await $.tester.drag(cardRow.first, const Offset(-500, 0));
      // Run the dismiss animation with fixed pumps (no settling).
      for (var i = 0; i < 4; i++) {
        await $.pump(const Duration(milliseconds: 300));
      }

      await $(
        'Meal deleted',
      ).waitUntilVisible(timeout: const Duration(seconds: 15));
      expect($('Undo'), findsOneWidget);

      // Let the undo snackbar time out without tapping Undo (fixed pumps).
      for (var i = 0; i < 16; i++) {
        await $.pump(const Duration(milliseconds: 300));
      }

      // ---- 6. The card is gone -------------------------------------------
      final cardGone = await _pumpUntilGone($, $(cardText));
      expect(
        cardGone,
        isTrue,
        reason: 'Deleted meal card should no longer appear on the timeline.',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
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
