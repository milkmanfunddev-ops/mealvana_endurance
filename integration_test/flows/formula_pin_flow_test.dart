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
///   ensureAuthenticated → calendar
///     → Settings gear → "Diet, Allergies & Formulas" hub → "Formula Library"
///     → During tab
///     → PIN: tap the first During card's thumbtack
///     → VERIFY: enable "pinned only" → at least one During card remains
///     → UNPIN (cleanup): tap the thumbtack again → pinned-only During list is
///       now the "no pins" empty state
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
import 'package:mealvana_endurance/main_dev.dart' as app;

const _loginEmail = String.fromEnvironment('INTEGRATION_TEST_EMAIL');
const _loginPassword = String.fromEnvironment('INTEGRATION_TEST_PASSWORD');

/// Matches every During-card thumbtack toggle, whose key is
/// `formula_kit.during_card_pin_<formulaId>`. Lets us act on the first formula
/// without knowing catalog ids.
Finder _duringPinToggles() => find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>)
              .value
              .startsWith('formula_kit.during_card_pin_'),
    );

void main() {
  patrolTest(
    'pin a During formula, see it in pinned-only view, then unpin it',
    ($) async {
      await app.main();
      await $.tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(minutes: 2),
      );

      // ---- 0. Authenticated on the calendar -----------------------------
      if (!await _ensureAuthenticated($)) {
        markTestSkipped(
          'Could not reach the calendar: no session and no '
          'INTEGRATION_TEST_EMAIL/PASSWORD. Pass '
          '--dart-define-from-file=secrets/integration_test.env to run.',
        );
        return;
      }

      // ---- 1. Settings → Diet/Allergies/Formulas hub → Formula Library --
      await $(const ValueKey('calendar.settings_button')).tap();
      await $(const ValueKey('settings.food_prefs_row')).waitUntilVisible(
        timeout: const Duration(seconds: 20),
      );
      await $(const ValueKey('settings.food_prefs_row')).scrollTo().tap();

      // Hub "Formula Library" tile has no ValueKey — tap it by title text.
      await $('Formula Library').waitUntilVisible(
        timeout: const Duration(seconds: 20),
      );
      await $('Formula Library').tap();

      await $(const ValueKey('formula_kit.library_screen')).waitUntilVisible(
        timeout: const Duration(seconds: 30),
      );

      // ---- 2. During tab ------------------------------------------------
      await $(const ValueKey('formula_kit.phase_tab.during')).tap();
      await $(const ValueKey('formula_kit.during_list')).waitUntilVisible(
        timeout: const Duration(seconds: 20),
      );

      // The library must have at least one During formula to pin.
      expect(
        _duringPinToggles(),
        findsWidgets,
        reason: 'Expected at least one During formula card with a pin toggle.',
      );

      // ---- 3. PIN the first During formula ------------------------------
      await $(_duringPinToggles()).first.scrollTo().tap();
      await $.pump(const Duration(milliseconds: 600));

      // ---- 4. VERIFY via "pinned only": the pinned formula remains -------
      await $(const ValueKey('formula_kit.pinned_only_button')).tap();
      await $.pump(const Duration(milliseconds: 600));
      expect(
        _duringPinToggles(),
        findsWidgets,
        reason: 'After pinning, the pinned-only During view should still show '
            'the pinned formula.',
      );

      // ---- 5. UNPIN (cleanup) → pinned-only During list is now empty -----
      await $(_duringPinToggles()).first.scrollTo().tap();
      await $.pump(const Duration(milliseconds: 800));
      await $(const ValueKey('formula_kit.during_empty_no_pins'))
          .waitUntilVisible(timeout: const Duration(seconds: 10));
      expect(
        _duringPinToggles(),
        findsNothing,
        reason: 'After unpinning the only pinned formula, the pinned-only '
            'During view should be empty.',
      );

      // Leave pinned-only mode so the screen is back to a clean state.
      await $(const ValueKey('formula_kit.pinned_only_button')).tap();
      await $.pump(const Duration(milliseconds: 300));
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
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
