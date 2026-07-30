/// Meal-logging CRUD walk under **Patrol** — log a meal from the Fuel Timeline
/// dashboard's "+ Add Food" button, read it back on the timeline, then remove it.
///
/// Covers the dashboard change that merged Activities + Nutrition into the single
/// Fuel Timeline tab: the dashboard now carries dashed `+ Add Food` and
/// `+ Add Activity` buttons instead of the old `calendar.create_activity_fab`.
///
/// **No AI.** The sheet's "Describe" tab is the LLM path and is deliberately
/// untouched — this test drives the "Manual" tab, which is a plain local write
/// through `MealLogController.logManualMeal` (offline-first, deterministic).
///
/// Flow:
///   ensureAuthenticated → Fuel Timeline tab → filter All
///     → CREATE: "+ Add Food" → log sheet → Manual tab → name + macros + slot
///                → Save → sheet closes
///     → READ:   the meal appears as a node on the timeline
///     → DELETE: tap the node to expand → Remove → assert it is gone
///
/// The meal name is stamped with the epoch millis so repeated CI runs never
/// collide, and the delete step keeps the dev account from accumulating rows.
///
/// Run:
///   patrol test --target integration_test/flows/meal_log_flow_test.dart \
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

void main() {
  patrolTest(
    'log a meal manually from the dashboard, read it back, then remove it',
    ($) async {
      await app.main();
      // Do NOT pumpAndSettle: startup can hold a persistent spinner.
      await $.pump(const Duration(milliseconds: 500));

      // ---- 0. Authenticated on the Fuel Timeline dashboard ---------------
      if (!await _ensureAuthenticated($)) {
        markTestSkipped(
          'Could not reach the dashboard: no session and no '
          'INTEGRATION_TEST_EMAIL/PASSWORD. Pass '
          '--dart-define-from-file=secrets/integration_test.env to run.',
        );
        return;
      }

      // Assertions match on the stamp alone, not the whole name: the timeline
      // tile renders `meal.name.toUpperCase()`, so an exact `find.text` on the
      // mixed-case name we typed finds nothing. The stamp is case-invariant.
      final stamp = '${DateTime.now().millisecondsSinceEpoch}';
      final mealName = 'Patrol Meal $stamp';
      final onTimeline = find.textContaining(stamp);

      // ---- 1. Timeline tab, All filter -----------------------------------
      // "+ Add Food" only renders under the All/Meals filters.
      await $(const ValueKey('bottom_nav.timeline_tab')).tap();
      await $(const ValueKey('fuel_timeline.filter_all')).waitUntilVisible(
        timeout: const Duration(seconds: 20),
      );
      await $(const ValueKey('fuel_timeline.filter_all')).tap();

      // ---- 2. "+ Add Food" opens the tabbed log sheet ---------------------
      await $(const ValueKey('fuel_timeline.add_food')).scrollTo().tap();
      await $(const ValueKey('log_sheet.root')).waitUntilVisible(
        timeout: const Duration(seconds: 20),
      );

      // ---- 3. Manual tab (NOT "Describe" — that one is the AI path) -------
      await $(const ValueKey('log_sheet.tab_manual')).tap();
      await $(const ValueKey('manual_log.name_field')).waitUntilVisible(
        timeout: const Duration(seconds: 15),
      );

      // ---- 4. Fill the manual entry --------------------------------------
      await _fillField($, const ValueKey('manual_log.name_field'), mealName);
      await $(const ValueKey('slot_chip.lunch')).scrollTo().tap();
      await _fillField($, const ValueKey('manual_log.calories_field'), '450');
      await _fillField($, const ValueKey('manual_log.carbs_field'), '60');
      await _fillField($, const ValueKey('manual_log.protein_field'), '25');
      await _fillField($, const ValueKey('manual_log.fat_field'), '12');

      // ---- 5. Save — the sheet closes on success -------------------------
      FocusManager.instance.primaryFocus?.unfocus();
      await $.pump(const Duration(milliseconds: 400));
      await $(const ValueKey('manual_log.save_button')).scrollTo().tap();

      await _waitUntilGone(
        $,
        const ValueKey('log_sheet.root'),
        reason: 'log sheet should close after a successful save',
      );

      // ---- 6. READ — the meal is on the timeline -------------------------
      await $(onTimeline).waitUntilVisible(
        timeout: const Duration(seconds: 20),
      );
      expect(
        $(onTimeline),
        findsWidgets,
        reason: 'The logged meal should appear as a node on the Fuel Timeline.',
      );

      // ---- 7. DELETE — expand the node, then Remove ----------------------
      await $(onTimeline).tap();
      await $(const ValueKey('timeline_node.remove_button')).waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );
      await $(const ValueKey('timeline_node.remove_button')).tap();

      // The delete is offline-first with an undo snackbar; let it settle and
      // let the snackbar (which also renders text) go away before asserting.
      await $.pump(const Duration(seconds: 6));

      expect(
        $(onTimeline),
        findsNothing,
        reason: 'The removed meal should no longer appear on the timeline.',
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

/// Enter [text] into [key] after dismissing any keyboard that would overlay it.
Future<void> _fillField(
  PatrolIntegrationTester $,
  ValueKey<String> key,
  String text,
) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await $.pump(const Duration(milliseconds: 300));
  await $(key).scrollTo();
  await $(key).enterText(text, settlePolicy: SettlePolicy.noSettle);
  await $.pump(const Duration(milliseconds: 200));
}

/// Poll until [key] is no longer in the tree (up to 20 s), then assert it.
Future<void> _waitUntilGone(
  PatrolIntegrationTester $,
  ValueKey<String> key, {
  required String reason,
}) async {
  for (var i = 0; i < 40; i++) {
    if (!$(key).exists) return;
    await $.pump(const Duration(milliseconds: 500));
  }
  expect($(key), findsNothing, reason: reason);
}

/// Returns true once the Fuel Timeline dashboard is reachable (authenticated).
///
/// Uses [fuel_timeline.settings] — the settings gear in the timeline day header
/// — as the "on the main screen" sentinel. The old
/// [calendar.create_activity_fab] sentinel was removed when Activities +
/// Nutrition merged into the single Fuel Timeline tab.
Future<bool> _ensureAuthenticated(PatrolIntegrationTester $) async {
  const sentinel = ValueKey('fuel_timeline.settings');
  const welcome = ValueKey('welcome.log_in_button');

  // Poll every 500 ms for up to 90 s — pumpAndSettle hangs on the startup
  // spinner, so gate on explicit finders instead.
  bool sentinelFound = false;
  bool welcomeFound = false;
  for (var i = 0; i < 180; i++) {
    await $.pump(const Duration(milliseconds: 500));
    if ($(sentinel).exists) {
      sentinelFound = true;
      break;
    }
    if ($(welcome).exists) {
      welcomeFound = true;
      break;
    }
  }

  if (sentinelFound) return true;
  if (!welcomeFound || _loginEmail.isEmpty || _loginPassword.isEmpty) {
    return false;
  }

  await $(welcome).tap();
  await $(const ValueKey('login_options.email_button')).waitUntilVisible(
    timeout: const Duration(seconds: 15),
  );
  await $(const ValueKey('login_options.email_button')).tap();
  await $(const ValueKey('login.email_field')).waitUntilVisible(
    timeout: const Duration(seconds: 15),
  );
  await $(const ValueKey('login.email_field')).enterText(_loginEmail);
  await $(const ValueKey('login.password_field')).enterText(_loginPassword);
  await $(const ValueKey('login.log_in_button')).tap();

  await $(sentinel).waitUntilVisible(timeout: const Duration(seconds: 40));
  return $(sentinel).exists;
}
