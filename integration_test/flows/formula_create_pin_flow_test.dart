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
/// ## Settle-policy notes
///
/// Several screens on this path render a [CircularProgressIndicator] while
/// async data loads (swap-food controller, editor draft, catalog search).
/// Patrol's default [SettlePolicy.trySettle] calls [pumpAndTrySettle] after
/// each tap/enterText, waiting up to [PatrolTesterConfig.settleTimeout]
/// (10 s) for animations to settle, then silently giving up. With a spinner
/// present, every such call burns the full 10 s. [scrollTo] is even worse:
/// it calls [dragUntilVisible] with [settleBetweenScrollsTimeout] (5 s per
/// drag × 15 max drags = 75 s per scrollTo call). Those numbers accumulate
/// far beyond the 20-minute timeout.
///
/// Mitigations applied:
///   • [SettlePolicy.noSettle] on every tap/enterText that follows a screen
///     with a potential spinner: one pump frame only, no pumpAndSettle.
///   • [scrollTo] is avoided entirely inside the swap-food flow; we tap the
///     food tile directly (local results render at the top of the list).
///   • [waitUntilVisible] is used explicitly to gate on loaded content (e.g.
///     the editor's name field, the "Add Food" button) before interacting.
///   • Fixed [$.pump] durations bridge the gap between action and next check.
///
/// The edge-function parity tests (supabase/functions/tests/parity fixtures
/// 07/08/34/35) prove the engine respects pins. This flow proves the UI
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

import '../helpers/flow_launcher.dart';

// ---------------------------------------------------------------------------
// Finders
// ---------------------------------------------------------------------------

/// All personal-formula card pin toggles whose key is
/// `formula_kit.personal_card_pin_<id>`. Used to pin without knowing the id.
Finder _personalPinToggles() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key as ValueKey<String>).value.startsWith(
        'formula_kit.personal_card_pin_',
      ),
);

// ---------------------------------------------------------------------------
// Test
// ---------------------------------------------------------------------------

void main() {
  patrolTest('create a personal During formula, add a food, save it, pin it, verify '
      'pinned-only view, then unpin (cleanup)', ($) async {
    await launchApp();
    // Give the engine one frame to render the first widget tree, then proceed.
    // Do NOT call pumpAndSettle here: the app may have a persistent loading
    // spinner (calendar activity fetch, startup provider init) that would
    // cause pumpAndSettle to sit for minutes. ensureAuthenticated uses
    // explicit poll gates instead.
    await $.pump(const Duration(milliseconds: 500));

    // ---- 0. Authenticated on the Fuel Timeline ----------------------------
    // Subsequent steps drive the Fuel Timeline's settings gear
    // (fuel_timeline.settings), so use it as the sentinel — see the note on
    // step 1 below for why the default nav-bar sentinel is not used here.
    if (!await ensureAuthenticated(
      $,
      sentinel: const ValueKey('fuel_timeline.settings'),
    )) {
      markTestSkipped(noAuthSkipMessage());
      return;
    }

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final formulaName = 'Patrol During $stamp';

    // ---- 1. Settings → Diet/Allergies/Formulas hub → Formula Library -----
    // The app starts on the FuelTimeline tab (index 0). On that tab, the
    // settings gear has key 'fuel_timeline.settings' (rendered by the
    // FuelTimeline header). The generic 'calendar.settings_button' is only
    // shown on non-zero tabs. Use the FuelTimeline-specific key here.
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
    await $(
      const ValueKey('settings.food_prefs_row'),
    ).scrollTo().tap(settlePolicy: SettlePolicy.noSettle);
    await $.pump(const Duration(milliseconds: 300));

    await $(
      'Formula Library',
    ).waitUntilVisible(timeout: const Duration(seconds: 20));
    await $('Formula Library').tap(settlePolicy: SettlePolicy.noSettle);
    await $.pump(const Duration(milliseconds: 300));

    await $(
      const ValueKey('formula_kit.library_screen'),
    ).waitUntilVisible(timeout: const Duration(seconds: 30));

    // ---- 2. During tab ---------------------------------------------------
    await $(
      const ValueKey('formula_kit.phase_tab.during'),
    ).tap(settlePolicy: SettlePolicy.noSettle);
    await $(
      const ValueKey('formula_kit.during_list'),
    ).waitUntilVisible(timeout: const Duration(seconds: 20));

    // ---- 3. Tap "New" to open the editor ---------------------------------
    // The library may show the "New" button below the fold; scrollTo is safe
    // here (no spinner in the library while catalog data is not being searched).
    await $(
      const ValueKey('formula_kit.your_formulas_new_during'),
    ).scrollTo().tap(settlePolicy: SettlePolicy.noSettle);
    await $.pump(const Duration(milliseconds: 400));

    // The Scaffold renders immediately with its key; wait for it.
    await $(
      const ValueKey('formula_kit.editor_screen.new'),
    ).waitUntilVisible(timeout: const Duration(seconds: 20));

    // ---- 4. Enter a unique formula name ----------------------------------
    // Wait for the draft to load (the name TextField is inside asyncDraft.when
    // data branch — it does not exist while asyncDraft is AsyncLoading).
    await $(
      const ValueKey('formula_kit.editor_name'),
    ).waitUntilVisible(timeout: const Duration(seconds: 20));
    await _fillField($, const ValueKey('formula_kit.editor_name'), formulaName);

    // ---- 5. Tap "Add Food" → swap-food screen opens in returnSelection mode
    // Wait for editor_add_food to be visible (inside asyncDraft.data branch).
    await $(
      const ValueKey('formula_kit.editor_add_food'),
    ).waitUntilVisible(timeout: const Duration(seconds: 20));
    await $(
      const ValueKey('formula_kit.editor_add_food'),
    ).tap(settlePolicy: SettlePolicy.noSettle);
    await $.pump(const Duration(milliseconds: 400));

    // Wait for the swap-food search field to appear.
    // The search field is inside controllerState.when(data: ...) so it only
    // renders after SwapFoodController finishes its async load. On a fresh
    // launch the controller syncs user_foods from Supabase before rendering,
    // which can take 30-45 s. Use a generous timeout.
    await $(
      const ValueKey('swap_food.search_field'),
    ).waitUntilVisible(timeout: const Duration(seconds: 60));

    // Type "gel" — triggers local template-food filtering synchronously.
    // IMPORTANT: typing ≥2 chars also kicks off a debounced catalog search
    // (300 ms), which sets isSearchingCatalog=true and renders a
    // CircularProgressIndicator. We use noSettle on enterText so we don't
    // burn 10 s waiting for that spinner to resolve.
    await $(
      const ValueKey('swap_food.search_field'),
    ).enterText('gel', settlePolicy: SettlePolicy.noSettle);
    // 200 ms is enough for local template filtering but less than the 300 ms
    // catalog-debounce, so the spinner may not have appeared yet.
    await $.pump(const Duration(milliseconds: 200));

    // Template food results are populated synchronously from local data.
    // CRITICAL: do NOT use scrollTo() here. The swap-food screen may have a
    // CircularProgressIndicator (catalog search in progress); scrollTo calls
    // pumpAndTrySettle up to 15 × 5 s = 75 s while that spinner runs.
    // Local results render at the top of the list — no scrolling needed.
    // Wait up to 10 s for at least one food tile to appear (local filtering
    // is synchronous but the widget rebuild takes a frame or two).
    final firstFoodCard = _firstFoodResultFinder();
    await $(
      firstFoodCard,
    ).waitUntilVisible(timeout: const Duration(seconds: 10));
    expect(
      firstFoodCard,
      findsWidgets,
      reason: 'Expected at least one food result for "gel".',
    );
    await $(firstFoodCard).first.tap(settlePolicy: SettlePolicy.noSettle);
    // Give Riverpod time to process selectFood() + clearSearch() state updates.
    // Both are synchronous, but the Flutter rebuild is async (next frame).
    // Use a 1 s pump to ensure both state changes have propagated before we
    // look for the confirm button.
    await $.pump(const Duration(milliseconds: 1000));

    // Confirm button is at the bottom of the page Column (outside the Expanded
    // scroll area), so it is always in the viewport when hasSelectedFood=true.
    // Use a 30 s timeout because the Riverpod rebuild could be delayed if the
    // FoodSearchController debounce timer is still running.
    await $(
      const ValueKey('swap_food.confirm_button'),
    ).waitUntilVisible(timeout: const Duration(seconds: 30));
    await $(
      const ValueKey('swap_food.confirm_button'),
    ).tap(settlePolicy: SettlePolicy.noSettle);
    // Route pop: give GoRouter a moment to push back to the editor.
    await $.pump(const Duration(milliseconds: 500));

    // Back in the editor — wait for the screen key to settle.
    await $(
      const ValueKey('formula_kit.editor_screen.new'),
    ).waitUntilVisible(timeout: const Duration(seconds: 15));

    // The newly added food row appears as editor_row_0.
    await $(
      const ValueKey('formula_kit.editor_row_0'),
    ).waitUntilVisible(timeout: const Duration(seconds: 10));

    // ---- 6. Save the formula ---------------------------------------------
    // editor_save is in a Positioned overlay at the bottom — always visible
    // when the draft is in the data state; no scrollTo needed.
    await $(
      const ValueKey('formula_kit.editor_save'),
    ).waitUntilVisible(timeout: const Duration(seconds: 10));
    await $(
      const ValueKey('formula_kit.editor_save'),
    ).tap(settlePolicy: SettlePolicy.noSettle);
    // After save, GoRouter pops back to the library screen.
    await $(
      const ValueKey('formula_kit.library_screen'),
    ).waitUntilVisible(timeout: const Duration(seconds: 30));

    // ---- 7. Verify the personal card appears in the During tab -----------
    await $(
      const ValueKey('formula_kit.phase_tab.during'),
    ).tap(settlePolicy: SettlePolicy.noSettle);
    await $.pump(const Duration(milliseconds: 600));

    // The formula name should appear in the "Your Formulas" section.
    await $(formulaName).waitUntilVisible(timeout: const Duration(seconds: 15));
    expect(
      $(formulaName),
      findsWidgets,
      reason: 'Saved personal formula name should be visible in the library.',
    );

    // ---- 8. PIN the formula ----------------------------------------------
    final pinToggle = _personalPinToggles();
    expect(
      pinToggle,
      findsWidgets,
      reason: 'Personal card should have a pin toggle after saving.',
    );
    // scrollTo is acceptable here: the library screen has no spinner at this
    // point (data already loaded).
    await $(
      pinToggle,
    ).first.scrollTo().tap(settlePolicy: SettlePolicy.noSettle);
    await $.pump(const Duration(milliseconds: 600));

    // ---- 9. Verify via "pinned only": the card is still shown ------------
    await $(
      const ValueKey('formula_kit.pinned_only_button'),
    ).tap(settlePolicy: SettlePolicy.noSettle);
    await $.pump(const Duration(milliseconds: 600));

    expect(
      _personalPinToggles(),
      findsWidgets,
      reason:
          'Pinned personal formula should still appear in pinned-only view.',
    );
    expect(
      $(formulaName),
      findsWidgets,
      reason: 'Formula name should be visible in pinned-only view.',
    );

    // ---- 10. UNPIN (cleanup) so the account is back to its prior state ---
    await $(
      _personalPinToggles(),
    ).first.scrollTo().tap(settlePolicy: SettlePolicy.noSettle);
    await $.pump(const Duration(milliseconds: 800));

    // Leave pinned-only mode.
    await $(
      const ValueKey('formula_kit.pinned_only_button'),
    ).tap(settlePolicy: SettlePolicy.noSettle);
    await $.pump(const Duration(milliseconds: 300));
  }, timeout: const Timeout(Duration(minutes: 5)));
}

// ---------------------------------------------------------------------------
// Local helpers
// ---------------------------------------------------------------------------

/// Find the first food result tile in the swap-food screen.
///
/// [FoodCardWidget] instances in the swap-food results are tagged with
/// `ValueKey('swap_food.food_tile_<foodId>')`. We match any widget whose key
/// starts with that prefix, then tap the first.
Finder _firstFoodResultFinder() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key as ValueKey<String>).value.startsWith('swap_food.food_tile_'),
);

/// Dismiss any open keyboard, wait for [key] to be visible, then enter [text].
///
/// Uses [SettlePolicy.noSettle] so that a [CircularProgressIndicator] present
/// elsewhere on the screen (e.g. during editor draft loading) does not cause
/// [enterText] to burn 10 s on [pumpAndTrySettle].
Future<void> _fillField(
  PatrolIntegrationTester $,
  ValueKey<String> key,
  String text,
) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await $.pump(const Duration(milliseconds: 300));
  // The field should already be visible (caller ensures this via waitUntilVisible).
  await $(key).enterText(text, settlePolicy: SettlePolicy.noSettle);
  await $.pump(const Duration(milliseconds: 200));
}
