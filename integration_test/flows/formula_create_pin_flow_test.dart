/// Personal-formula create → add food → save → pin flow under **Patrol**.
///
/// Proves the full personal-formula lifecycle:
///   1. Navigate to Formula Library → During tab.
///   2. Tap "New" to open the formula editor.
///   3. Enter a unique formula name.
///   4. Add a food via the swap-food returnSelection page (search "gel",
///      pick the first local result).
///   5. Save the formula.
///   6. The personal card appears in the During tab.
///   7. Pin the formula via its card pin toggle.
///   8. Enable "pinned only" filter → the card is still visible.
///   9. Clean up: unpin (to leave the account in the original state).
///
/// The edge-function parity tests (supabase/functions/tests/parity fixtures
/// 07/08/34/35) prove the engine respects pins.  This flow proves the UI
/// lifecycle: a user CAN create a personal formula, add a food to it, save it,
/// and pin it so it surfaces in the pinned-only view.
///
/// Run:
///   patrol test \
///     --target integration_test/flows/formula_create_pin_flow_test.dart \
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

// ---------------------------------------------------------------------------
// Finders
// ---------------------------------------------------------------------------

/// All personal-formula card pin toggles whose key is
/// `formula_kit.personal_card_pin_<id>`. Used to pin without knowing the id.
Finder _personalPinToggles() => find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>)
              .value
              .startsWith('formula_kit.personal_card_pin_'),
    );

// ---------------------------------------------------------------------------
// Test
// ---------------------------------------------------------------------------

void main() {
  patrolTest(
    'create a personal During formula, add a food, save it, pin it, verify '
    'pinned-only view, then unpin (cleanup)',
    ($) async {
      await app.main();
      await $.tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(minutes: 2),
      );

      // ---- 0. Authenticated on the calendar --------------------------------
      if (!await _ensureAuthenticated($)) {
        markTestSkipped(
          'Could not reach the calendar: no session and no '
          'INTEGRATION_TEST_EMAIL/PASSWORD. Pass '
          '--dart-define-from-file=secrets/integration_test.env to run.',
        );
        return;
      }

      final stamp = DateTime.now().millisecondsSinceEpoch;
      final formulaName = 'Patrol During $stamp';

      // ---- 1. Settings → Diet/Allergies/Formulas hub → Formula Library -----
      await $(const ValueKey('calendar.settings_button')).tap();
      await $(const ValueKey('settings.food_prefs_row')).waitUntilVisible(
        timeout: const Duration(seconds: 20),
      );
      await $(const ValueKey('settings.food_prefs_row')).scrollTo().tap();

      await $('Formula Library').waitUntilVisible(
        timeout: const Duration(seconds: 20),
      );
      await $('Formula Library').tap();

      await $(const ValueKey('formula_kit.library_screen')).waitUntilVisible(
        timeout: const Duration(seconds: 30),
      );

      // ---- 2. During tab ---------------------------------------------------
      await $(const ValueKey('formula_kit.phase_tab.during')).tap();
      await $(const ValueKey('formula_kit.during_list')).waitUntilVisible(
        timeout: const Duration(seconds: 20),
      );

      // ---- 3. Tap "New" to open the editor ---------------------------------
      await $(const ValueKey('formula_kit.your_formulas_new_during'))
          .scrollTo()
          .tap();

      // Editor screen key is `formula_kit.editor_screen.new`
      await $(const ValueKey('formula_kit.editor_screen.new'))
          .waitUntilVisible(timeout: const Duration(seconds: 20));

      // ---- 4. Enter a unique formula name ----------------------------------
      await _fillField($, const ValueKey('formula_kit.editor_name'), formulaName);

      // ---- 5. Tap "Add Food" → swap-food screen opens in returnSelection mode
      await $(const ValueKey('formula_kit.editor_add_food')).scrollTo().tap();

      // Wait for the swap-food search field to appear.
      await $(const ValueKey('swap_food.search_field')).waitUntilVisible(
        timeout: const Duration(seconds: 20),
      );

      // Type "gel" — triggers local template-food filtering synchronously.
      await $(const ValueKey('swap_food.search_field')).enterText('gel');
      await $.pump(const Duration(milliseconds: 600));

      // Pick the first local result by tapping any visible food card text.
      // Template food results are `FoodCardWidget` instances — tap the first one.
      // We look for any InkWell inside a BaseCard that is now visible.
      // Fallback: tap the first Text widget inside a listview that matches.
      final firstFoodCard = _firstFoodResultFinder();
      expect(firstFoodCard, findsWidgets,
          reason: 'Expected at least one food result for "gel".');
      await $(firstFoodCard).first.scrollTo().tap();
      await $.pump(const Duration(milliseconds: 400));

      // Confirm button should appear (food is selected, search cleared).
      await $(const ValueKey('swap_food.confirm_button')).waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );
      await $(const ValueKey('swap_food.confirm_button')).tap();

      // Back in the editor — the food row should appear.
      await $(const ValueKey('formula_kit.editor_screen.new'))
          .waitUntilVisible(timeout: const Duration(seconds: 10));
      expect(
        $(const ValueKey('formula_kit.editor_row_0')),
        findsWidgets,
        reason: 'The chosen food should appear as editor row 0.',
      );

      // ---- 6. Save the formula ---------------------------------------------
      await $(const ValueKey('formula_kit.editor_save')).scrollTo().tap();
      // After save, GoRouter pops back to the library screen.
      await $(const ValueKey('formula_kit.library_screen')).waitUntilVisible(
        timeout: const Duration(seconds: 30),
      );

      // ---- 7. Verify the personal card appears in the During tab -----------
      // Still on the During tab (or re-tap if needed).
      await $(const ValueKey('formula_kit.phase_tab.during')).tap();
      await $.pump(const Duration(milliseconds: 600));

      // The formula name should appear in the "Your Formulas" section.
      await $(formulaName).waitUntilVisible(
        timeout: const Duration(seconds: 15),
      );
      expect(
        $(formulaName),
        findsWidgets,
        reason: 'Saved personal formula name should be visible in the library.',
      );

      // ---- 8. PIN the formula ----------------------------------------------
      final pinToggle = _personalPinToggles();
      expect(pinToggle, findsWidgets,
          reason: 'Personal card should have a pin toggle after saving.');
      await $(pinToggle).first.scrollTo().tap();
      await $.pump(const Duration(milliseconds: 600));

      // ---- 9. Verify via "pinned only": the card is still shown ------------
      await $(const ValueKey('formula_kit.pinned_only_button')).tap();
      await $.pump(const Duration(milliseconds: 600));

      expect(
        _personalPinToggles(),
        findsWidgets,
        reason: 'Pinned personal formula should still appear in pinned-only view.',
      );
      expect(
        $(formulaName),
        findsWidgets,
        reason: 'Formula name should be visible in pinned-only view.',
      );

      // ---- 10. UNPIN (cleanup) so the account is back to its prior state ---
      await $(_personalPinToggles()).first.scrollTo().tap();
      await $.pump(const Duration(milliseconds: 800));

      // Leave pinned-only mode.
      await $(const ValueKey('formula_kit.pinned_only_button')).tap();
      await $.pump(const Duration(milliseconds: 300));
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

// ---------------------------------------------------------------------------
// Local helpers
// ---------------------------------------------------------------------------

/// Find the first food result tile in the swap-food screen.
///
/// `FoodCardWidget` instances in the swap-food results are tagged with
/// `ValueKey('swap_food.food_tile_<foodId>')`. We match any widget whose key
/// starts with that prefix, then tap the first.
Finder _firstFoodResultFinder() => find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>)
              .value
              .startsWith('swap_food.food_tile_'),
    );

/// Dismiss any open keyboard, scroll the target field into view, enter text.
Future<void> _fillField(
  PatrolIntegrationTester $,
  ValueKey<String> key,
  String text,
) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await $.pump(const Duration(milliseconds: 300));
  await $(key).scrollTo();
  await $(key).enterText(text);
}

/// Returns true once the calendar is reachable (authenticated).
Future<bool> _ensureAuthenticated(PatrolIntegrationTester $) async {
  const fab = ValueKey('calendar.create_activity_fab');
  if ($(fab).exists) return true;
  if (_loginEmail.isEmpty || _loginPassword.isEmpty) return false;

  await $(const ValueKey('welcome.log_in_button')).tap();
  await $(const ValueKey('login_options.email_button')).tap();
  await $(const ValueKey('login.email_field')).enterText(_loginEmail);
  await $(const ValueKey('login.password_field')).enterText(_loginPassword);
  await $(const ValueKey('login.log_in_button')).tap();
  await $(fab).waitUntilVisible(timeout: const Duration(seconds: 40));
  return $(fab).exists;
}
