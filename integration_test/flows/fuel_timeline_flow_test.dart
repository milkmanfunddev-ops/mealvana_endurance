/// Fuel Timeline walk under **Patrol** — navigate to the Nutrition tab and
/// exercise the filter segments + tracking/timeline toggles end-to-end, driven
/// entirely by `ValueKey` finders.
///
/// Intentionally data-agnostic: it asserts the controls render and respond
/// (filter pills, tracking/timeline toggles) without depending on the test
/// account having meals/activities logged, so it stays green on a fresh dev
/// account.
///
/// Flow:
///   ensureAuthenticated (reuse session, else email login)
///     → Fuel Timeline tab (already active at startup)
///     → assert the filter row rendered (All pill visible)
///     → cycle filters: Workout → Meals → All
///     → toggle tracking off then on
///     → toggle the time rail off then on
///
/// Auth:
///   Boots via the shared launcher (helpers/flow_launcher.dart, flavor-aware)
///   and reuses an existing session if the app launches straight to the
///   timeline; otherwise ensureAuthenticated logs in with the flavor-matched
///   TestConfig.loginEmail/loginPassword. On a clean install (no session, no
///   creds) the test self-skips.
///
/// Run:
///   patrol test --target integration_test/flows/fuel_timeline_flow_test.dart \
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
  patrolTest('fuel timeline — filter + tracking/timeline toggles', ($) async {
    await launchApp();
    // Do NOT call pumpAndSettle: the app may have a persistent loading
    // spinner during startup. ensureAuthenticated uses explicit polls.
    await $.pump(const Duration(milliseconds: 500));

    // The flow exercises the Fuel Timeline header controls, so gate on the
    // timeline's settings gear rather than the default nav-bar sentinel.
    if (!await ensureAuthenticated(
      $,
      sentinel: const ValueKey('fuel_timeline.settings'),
    )) {
      markTestSkipped(noAuthSkipMessage());
      return;
    }

    // ---- 1. Ensure Fuel Timeline tab is active ---------------------------
    // The app opens on the Fuel Timeline (index 0). Tapping the nav button
    // is harmless if we're already there and guarantees the screen is active.
    // Key is bottom_nav.timeline_tab — the Activities + Nutrition tabs were
    // merged into one Fuel Timeline tab in the carbs-per-hour refactor.
    // The old key bottom_nav.diary_tab no longer exists.
    await $(const ValueKey('bottom_nav.timeline_tab')).tap();
    await $(
      const ValueKey('fuel_timeline.filter_all'),
    ).waitUntilVisible(timeout: const Duration(seconds: 20));

    // ---- 2. Cycle the filters ------------------------------------------
    await $(const ValueKey('fuel_timeline.filter_workout')).tap();
    await $(const ValueKey('fuel_timeline.filter_meals')).tap();
    await $(const ValueKey('fuel_timeline.filter_all')).tap();

    // ---- 3. Toggle tracking off then on --------------------------------
    await $(const ValueKey('fuel_timeline.tracking_toggle')).tap();
    await $(const ValueKey('fuel_timeline.tracking_toggle')).tap();

    // ---- 4. Toggle the time rail off then on ---------------------------
    await $(const ValueKey('fuel_timeline.timeline_toggle')).tap();
    await $(const ValueKey('fuel_timeline.timeline_toggle')).tap();

    // The filter row is still present after all the toggling.
    expect($(const ValueKey('fuel_timeline.filter_all')), findsOneWidget);
  });
}
