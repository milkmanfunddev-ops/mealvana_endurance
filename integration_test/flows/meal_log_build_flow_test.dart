/// Build-a-meal (search-based, no AI) flow under **Patrol** — the core
/// meal-logging path: search a food, add it to a draft, log the meal, see it
/// on the Fuel Timeline, then clean up with a swipe-delete.
///
/// Flow:
///   launchApp → ensureAuthenticated (reuse session, else email login)
///     → Fuel Timeline → "+ Add Food" (fuel_timeline.add_food) → LogMealScreen
///     → "Build a meal" app-bar action (log_meal.build_a_meal_button)
///     → BuildMealScreen empty state → "+ Add food" (build_meal.add_food_button)
///     → search "banana" (add_food.search_field), await results
///     → tap the first meal_search.food_tile_* / catalog_tile_* result
///       (adds it straight to the draft — "Added …" snackbar)
///     → back (add_food.back_button) → draft view
///     → name the meal uniquely (build_meal.name_field)
///     → "Log meal" (build_meal.log_meal_button) → "Meal logged!" snackbar
///     → back to the timeline (log_meal.back_button)
///     → the meal card appears (timeline renders names UPPERCASE)
///     → CLEANUP (best-effort, in try/catch): swipe the card left →
///       "Meal deleted" undo snackbar → let it time out.
///
/// Settle policy: SettlePolicy.noSettle on taps/enterText near the food
/// search (typing ≥2 chars kicks off a debounced catalog search whose
/// CircularProgressIndicator would burn 10 s per default-settle action), and
/// NO .scrollTo(maxScrolls: 12, settleBetweenScrollsTimeout: const Duration(milliseconds: 500)) on the fuel timeline. Fixed pumps bridge the gaps.
///
/// Auth: reuses an existing session, else the flavor-matched
/// INTEGRATION_TEST creds; self-skips when neither is available. Also
/// self-skips if the search yields no results (data prerequisite).
///
/// Run:
///   patrol test --target integration_test/flows/meal_log_build_flow_test.dart \
///     --flavor dev \
///     --dart-define-from-file=.env.dev.local \
///     --dart-define-from-file=secrets/integration_test.env \
///     --device "iPhone 17 Pro"
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../helpers/flow_launcher.dart';
import '../helpers/supabase_probe.dart';

/// Any food/catalog result tile in the add-food unified search results.
Finder _searchResultTiles() => find.byWidgetPredicate((w) {
  final key = w.key;
  if (key is! ValueKey<String>) return false;
  return key.value.startsWith('meal_search.food_tile_') ||
      key.value.startsWith('meal_search.catalog_tile_');
});

void main() {
  patrolTest(
    'build a meal from search, log it, see it on the timeline, then delete it',
    ($) async {
      await launchApp();
      // No pumpAndSettle: startup may show persistent spinners.
      await $.pump(const Duration(milliseconds: 500));

      if (!await ensureAuthenticated($)) {
        markTestSkipped(noAuthSkipMessage());
        return;
      }

      final stamp = DateTime.now().millisecondsSinceEpoch;
      final mealName = 'Patrol Build $stamp';
      // TimelineNodeTile renders meal names uppercased.
      final cardText = mealName.toUpperCase();

      // ---- 1. Fuel Timeline → + Add Food → Build a meal -------------------
      await $(
        const ValueKey('bottom_nav.timeline_tab'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $(
        const ValueKey('fuel_timeline.add_food'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      await $(
        const ValueKey('fuel_timeline.add_food'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 400));

      await $(
        const ValueKey('log_meal.build_a_meal_button'),
      ).waitUntilVisible(timeout: const Duration(seconds: 15));
      await $(
        const ValueKey('log_meal.build_a_meal_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 400));

      // ---- 2. Empty draft → + Add food → search "banana" ------------------
      await $(
        const ValueKey('build_meal.add_food_button'),
      ).waitUntilVisible(timeout: const Duration(seconds: 15));
      await $(
        const ValueKey('build_meal.add_food_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 400));

      await $(
        const ValueKey('add_food.search_field'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      // noSettle: typing triggers the debounced catalog search + spinner.
      await $(
        const ValueKey('add_food.search_field'),
      ).enterText('banana', settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 300));

      // Local template-food results render synchronously at the top of the
      // list; catalog results may trickle in. Poll rather than settle.
      final tiles = _searchResultTiles();
      var found = false;
      for (var i = 0; i < 60; i++) {
        await $.pump(const Duration(milliseconds: 500));
        if (tiles.evaluate().isNotEmpty) {
          found = true;
          break;
        }
      }
      if (!found) {
        markTestSkipped(
          'No search results for "banana" — the food pool/catalog appears '
          'empty in this environment, cannot exercise the build flow.',
        );
        return;
      }

      // ---- 3. Add the first result to the draft ---------------------------
      // No scrollTo — the first result is already at the top of the list.
      await $(tiles).first.tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 600));

      // Back to the draft.
      await $(
        const ValueKey('add_food.back_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 400));

      // The draft now shows the name field (non-empty content state).
      await $(
        const ValueKey('build_meal.name_field'),
      ).waitUntilVisible(timeout: const Duration(seconds: 15));

      // ---- 4. Give the meal a unique name and log it ----------------------
      FocusManager.instance.primaryFocus?.unfocus();
      await $.pump(const Duration(milliseconds: 300));
      await $(
        const ValueKey('build_meal.name_field'),
      ).enterText(mealName, settlePolicy: SettlePolicy.noSettle);
      // Dismiss the keyboard so it doesn't cover the bottom "Log meal" bar.
      FocusManager.instance.primaryFocus?.unfocus();
      await $.pump(const Duration(milliseconds: 400));

      await $(
        const ValueKey('build_meal.log_meal_button'),
      ).waitUntilVisible(timeout: const Duration(seconds: 10));
      await $(
        const ValueKey('build_meal.log_meal_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);

      // REAL outcome #1: the success snackbar.
      await $(
        'Meal logged!',
      ).waitUntilVisible(timeout: const Duration(seconds: 20));

      // ---- 5. Back to the timeline — the card is there --------------------
      // BuildMealScreen pops itself on success; we land on LogMealScreen.
      await $(
        const ValueKey('log_meal.back_button'),
      ).waitUntilVisible(timeout: const Duration(seconds: 15));
      await $(
        const ValueKey('log_meal.back_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);

      // REAL outcome #2: the logged meal card appears on the Fuel Timeline.
      // "the timeline" means *today's* timeline — the selected day is app-level
      // state shared with every other flow in the bundle.
      await ensureTimelineOnToday($);
      final onTimeline = await waitForOnTimeline($, find.text(cardText));
      expect(
        onTimeline,
        isTrue,
        reason: 'Logged meal "$cardText" never appeared on the Fuel Timeline.',
      );
      expect(
        $(cardText),
        findsWidgets,
        reason: 'Logged meal should appear as a card on the Fuel Timeline.',
      );

      // ---- 6. PERSISTED STATE — the components actually saved -------------
      // The whole point of build-a-meal is that the meal carries the foods you
      // assembled. The timeline card shows a name and a macro line, so a meal
      // that persisted with an EMPTY component list renders indistinguishably
      // from a correct one — exactly the kind of silent data loss a UI-only
      // assertion cannot see.
      final probe = await SupabaseProbe.signIn();
      if (probe == null) {
        debugPrint(
          '[meal_log_build] Supabase probe unavailable — persistence '
          'assertions skipped (UI assertions above still ran).',
        );
      } else {
        final row = await probe.mealLogByName(mealName);
        expect(
          row,
          isNotNull,
          reason:
              'No meal_logs row named "$mealName" for this athlete, though the '
              'UI showed "Meal logged!" and the card rendered.',
        );
        expect(
          row!['is_deleted'] == true,
          isFalse,
          reason: 'The freshly logged meal was written already tombstoned.',
        );

        // One food was added to the draft before logging, so the saved meal
        // must carry at least one component.
        final components = row['components'];
        final count = components is List
            ? components.length
            : (components is String
                  ? (jsonDecode(components) as List?)?.length ?? 0
                  : 0);
        expect(
          count,
          greaterThanOrEqualTo(1),
          reason:
              'Built the meal from a search result, but the persisted row '
              'carries $count component(s): $components. The draft\'s foods '
              'were dropped on save — the card still looks normal.',
        );
      }

      // ---- 7. CLEANUP — swipe-delete the created card (best-effort) -------
      // Guarded so a cleanup hiccup never fails an otherwise-green test; the
      // meal name is timestamp-unique so a leftover can't poison future runs.
      try {
        final cardRow = find.ancestor(
          of: find.text(cardText),
          matching: find.byType(Dismissible),
        );
        await $.tester.drag(cardRow.first, const Offset(-500, 0));
        await $.pump(const Duration(milliseconds: 600));
        await $(
          'Meal deleted',
        ).waitUntilVisible(timeout: const Duration(seconds: 10));
        // Let the Undo snackbar time out so the delete commits.
        await $.pump(const Duration(seconds: 4));
      } catch (e) {
        // ignore: avoid_print
        print('meal_log_build cleanup failed (non-fatal): $e');
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
