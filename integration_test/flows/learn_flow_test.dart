/// Learn tab flow under **Patrol** — open the education tab, confirm the
/// content list renders, open the first free lesson's video screen, then
/// come back.
///
/// Intentionally data-agnostic: if the education catalog is empty in this
/// environment the test self-skips (the "Mealvana 101" section renders an
/// empty-state card instead of lesson cards — that is not a crash).
///
/// Flow:
///   launchApp → ensureAuthenticated (reuse session, else email login)
///     → Learn tab (bottom_nav.learn_tab)
///     → 'Learn' title renders (learn.title) — the education controller
///       finished loading (its spinner precedes the whole scroll view)
///     → free-lessons list renders (learn.lesson_card_0) — else skip
///     → tap lesson card 0 → VideoPlayerScreen builds (lesson.title +
///       lesson.back_button) — the video itself may still be buffering,
///       which is fine; the screen building without throwing is the assertion
///     → back (lesson.back_button) → learn.title visible again
///     → return to the timeline tab.
///
/// Auth: reuses an existing session, else the flavor-matched
/// INTEGRATION_TEST creds; self-skips when neither is available.
///
/// Run:
///   patrol test --target integration_test/flows/learn_flow_test.dart \
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
    'learn tab — education list renders and the first lesson screen opens',
    ($) async {
      await launchApp();
      // No pumpAndSettle: startup may show persistent spinners.
      await $.pump(const Duration(milliseconds: 500));

      if (!await ensureAuthenticated($)) {
        markTestSkipped(noAuthSkipMessage());
        return;
      }

      // ---- 1. Learn tab ----------------------------------------------------
      await $(
        const ValueKey('bottom_nav.learn_tab'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 400));

      // The education controller shows a full-screen spinner while loading;
      // the title only exists in the data branch, so waiting on it proves the
      // load completed without the error state.
      await $(
        const ValueKey('learn.title'),
      ).waitUntilVisible(timeout: const Duration(seconds: 30));
      expect(
        $(const ValueKey('learn.mealvana_101_section')),
        findsOneWidget,
        reason: 'Mealvana 101 section header should render on the Learn tab.',
      );

      // ---- 2. First lesson card (skip gracefully if catalog is empty) ------
      const firstCard = ValueKey('learn.lesson_card_0');
      var cardFound = false;
      for (var i = 0; i < 30; i++) {
        await $.pump(const Duration(milliseconds: 500));
        if ($(firstCard).exists) {
          cardFound = true;
          break;
        }
      }
      if (!cardFound) {
        markTestSkipped(
          'No free lessons available in this environment — the Learn list '
          'rendered its empty state, nothing to open.',
        );
        return;
      }

      // ---- 3. Open the lesson → the player screen builds -------------------
      await $(firstCard).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 400));

      await $(
        const ValueKey('lesson.title'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      expect(
        $(const ValueKey('lesson.back_button')),
        findsOneWidget,
        reason: 'Video player screen should build with its app bar.',
      );

      // ---- 4. Back to the Learn list ---------------------------------------
      await $(
        const ValueKey('lesson.back_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $(
        const ValueKey('learn.title'),
      ).waitUntilVisible(timeout: const Duration(seconds: 15));

      // ---- 5. Leave the app on the timeline tab -----------------------------
      await $(
        const ValueKey('bottom_nav.timeline_tab'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 400));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
