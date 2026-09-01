/// Barcode scanner entry flow under **Patrol**.
///
/// SCOPE — read this before extending. A simulator has no camera and cannot
/// present a barcode, so the *scan* itself is not automatable here and this
/// flow deliberately does not attempt it. What it does cover is the part that
/// actually regresses: the route into the scanner and back out.
///
/// That boundary is worth guarding on its own. `_onBarcodeScan` in
/// log_meal_screen pushes a NAMED route with an `extra` map
/// (`{'category': 'add_food', 'context': 'meal_log_discover'}`) and then casts
/// the popped result to `Food`. Four screens push the same named route with
/// their own extras. A rename, a router change, or a missing extra turns into a
/// crash or a dead button at exactly this seam — and no unit test crosses it,
/// because the seam IS the router.
///
/// Flow:
///   launchApp → ensureAuthenticated
///     → Fuel Timeline → + Add Food
///     → tap the search bar's barcode button (add_food.barcode_button)
///     → BarcodeScannerScreen builds: title + instructions + its camera
///       controls (flash / switch)
///     → back (barcode.back_button) → we are on the add-food sheet again
///     → close the sheet, back to the timeline.
///
/// The camera preview may or may not initialise on a simulator; the flow never
/// asserts on it. The assertion is that the SCREEN builds and pops cleanly —
/// a scanner that throws on push, or a back button that strands the user, fails
/// here regardless of camera state.
///
/// Auth: reuses an existing session, else the flavor-matched INTEGRATION_TEST
/// creds; self-skips when neither is available.
///
/// Run:
///   patrol test --target integration_test/flows/barcode_scanner_entry_flow_test.dart \
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
    'barcode scanner opens from add-food and returns without stranding the user',
    ($) async {
      await launchApp();
      // No pumpAndSettle: startup may show persistent spinners.
      await $.pump(const Duration(milliseconds: 500));

      if (!await ensureAuthenticated($)) {
        markTestSkipped(noAuthSkipMessage());
        return;
      }

      // ---- 1. Fuel Timeline → + Add Food -----------------------------------
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
        const ValueKey('add_food.barcode_button'),
      ).waitUntilVisible(timeout: const Duration(seconds: 15));

      // ---- 2. Into the scanner ---------------------------------------------
      await $(
        const ValueKey('add_food.barcode_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 600));

      // noSettle throughout: the camera controller schedules continuous frames,
      // so this screen may never reach a settled state on a real device.
      await $(
        const ValueKey('barcode.title'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      expect(
        $(const ValueKey('barcode.instructions')),
        findsOneWidget,
        reason:
            'The scanner should tell the user what to do. If this is missing '
            'the screen built in an unexpected state branch.',
      );
      expect(
        $(const ValueKey('barcode.back_button')),
        findsOneWidget,
        reason:
            'Without a back button the scanner is a dead end — there is no '
            'other way out of this route.',
      );

      // ---- 3. Back out — the seam this flow exists to guard -----------------
      await $(
        const ValueKey('barcode.back_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 600));

      // Popping with no result must land back on the add-food sheet, NOT crash
      // in the `result as Food` cast: log_meal_screen guards on a null result
      // before casting, and this is what proves that guard is still there.
      await $(
        const ValueKey('add_food.barcode_button'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));

      // ---- 4. Leave the app on the timeline ---------------------------------
      await $(
        const ValueKey('log_meal.back_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $(
        const ValueKey('fuel_timeline.add_food'),
      ).waitUntilVisible(timeout: const Duration(seconds: 15));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
