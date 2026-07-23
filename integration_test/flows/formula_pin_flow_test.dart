/// Pinned-formula flow under **Patrol** — proves the user-facing PIN PROCESS
/// works end to end: a user can open the Formula Library, pin a During formula,
/// see it surface in the "pinned only" view, and unpin it.
///
/// Why this split:
///   Per the testing strategy (docs/test/testing-build-plan-2026.md), Patrol
///   proves "a user CAN do the thing" (pin a formula and it sticks), while the
///   deterministic edge-function parity tests prove "the algorithm RESPECTS the
///   pin" (fixtures 07/08/34/35 in supabase/functions/tests/parity, run via
///   run-algorithm-tests.sh). Numeric "formula honored" assertions belong in
///   that layer; this flow exercises the real UI pin lifecycle.
///
/// Flow:
///   launchApp (flavor-aware) → ensureAuthenticated → Fuel Timeline
///     → Settings gear → "Diet, Allergies & Formulas" hub → "Formula Library"
///     → During tab
///     → PIN: tap the first During card's thumbtack
///     → VERIFY: enable "pinned only" → at least one During card remains
///     → UNPIN (cleanup): tap the thumbtack again → pinned-only During list is
///       now the "no pins" empty state
///
/// Settle-policy notes:
///   The library screen can render a CircularProgressIndicator while catalog /
///   pin state loads, so default-settle taps and scrollTo burn their full
///   pumpAndTrySettle timeouts (10 s per tap, per drag for scrollTo). All taps
///   here use SettlePolicy.noSettle and scrollTo caps its between-drag settle
///   at 1 s (settleBetweenScrollsTimeout); waitUntilVisible/waitUntilExists
///   (plain 100 ms pump polls — never settle) gate on loaded content instead.
///
/// Auth:
///   Boots via the shared launcher (helpers/flow_launcher.dart) and signs in
///   with the flavor-matched TestConfig.loginEmail/loginPassword. Self-skips
///   when there is no session and no credentials.
///
/// Run:
///   patrol test --target integration_test/flows/formula_pin_flow_test.dart \
///     --flavor dev \
///     --dart-define-from-file=.env.dev.local \
///     --dart-define-from-file=secrets/integration_test.env \
///     --device "iPhone 17 Pro"
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../helpers/flow_launcher.dart';

/// Matches every During-card thumbtack toggle, whose key is
/// `formula_kit.during_card_pin_<formulaId>`. Lets us act on the first formula
/// without knowing catalog ids.
Finder _duringPinToggles() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key as ValueKey<String>).value.startsWith(
        'formula_kit.during_card_pin_',
      ),
);

void main() {
  patrolTest(
    'pin a During formula, see it in pinned-only view, then unpin it',
    ($) async {
      await launchApp();
      // Do NOT pumpAndSettle: startup may show a persistent spinner.
      await $.pump(const Duration(milliseconds: 500));

      // ---- 0. Authenticated on the Fuel Timeline -------------------------
      // The next step taps the Fuel Timeline's settings gear, so gate on that
      // key rather than the default nav-bar sentinel.
      if (!await ensureAuthenticated(
        $,
        sentinel: const ValueKey('fuel_timeline.settings'),
      )) {
        markTestSkipped(noAuthSkipMessage());
        return;
      }

      // ---- 1. Settings → Diet/Allergies/Formulas hub → Formula Library --
      // The app lands on the Fuel Timeline tab (index 0), where the settings
      // gear key is 'fuel_timeline.settings' (the generic
      // 'calendar.settings_button' only renders on non-zero tabs).
      await $(
        const ValueKey('fuel_timeline.settings'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      await $(
        const ValueKey('fuel_timeline.settings'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 300));

      await $(
        const ValueKey('settings.food_prefs_row'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      await $(const ValueKey('settings.food_prefs_row'))
          .scrollTo(settleBetweenScrollsTimeout: const Duration(seconds: 1))
          .tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 300));

      // Hub "Formula Library" tile has no ValueKey — tap it by title text.
      await $(
        'Formula Library',
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      await $('Formula Library').tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 300));

      await $(
        const ValueKey('formula_kit.library_screen'),
      ).waitUntilVisible(timeout: const Duration(seconds: 30));

      // ---- 2. During tab ------------------------------------------------
      await $(
        const ValueKey('formula_kit.phase_tab.during'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $(
        const ValueKey('formula_kit.during_list'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));

      // The library must have at least one During formula to pin. The cards
      // load async — wait for the first pin toggle to exist before asserting.
      await $(
        _duringPinToggles(),
      ).waitUntilExists(timeout: const Duration(seconds: 20));
      expect(
        _duringPinToggles(),
        findsWidgets,
        reason: 'Expected at least one During formula card with a pin toggle.',
      );

      // ---- 3. PIN the first During formula ------------------------------
      await $(_duringPinToggles()).first
          .scrollTo(settleBetweenScrollsTimeout: const Duration(seconds: 1))
          .tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 600));

      // ---- 4. VERIFY via "pinned only": the pinned formula remains -------
      await $(
        const ValueKey('formula_kit.pinned_only_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 600));
      expect(
        _duringPinToggles(),
        findsWidgets,
        reason:
            'After pinning, the pinned-only During view should still show '
            'the pinned formula.',
      );

      // ---- 5. UNPIN (cleanup) → pinned-only During list is now empty -----
      await $(_duringPinToggles()).first
          .scrollTo(settleBetweenScrollsTimeout: const Duration(seconds: 1))
          .tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 800));
      await $(
        const ValueKey('formula_kit.during_empty_no_pins'),
      ).waitUntilVisible(timeout: const Duration(seconds: 10));
      expect(
        _duringPinToggles(),
        findsNothing,
        reason:
            'After unpinning the only pinned formula, the pinned-only '
            'During view should be empty.',
      );

      // Leave pinned-only mode so the screen is back to a clean state.
      await $(
        const ValueKey('formula_kit.pinned_only_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 300));
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
