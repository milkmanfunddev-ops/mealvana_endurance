/// Settings-tree crash sweep under **Patrol** — open every top-level settings
/// row, assert the target screen renders a landmark widget, then navigate
/// back and confirm the settings list is intact.
///
/// This is the cheapest way to catch route/build crashes across the whole
/// settings tree: a broken provider or a bad build() in any of these screens
/// turns into a missing landmark here.
///
/// Flow:
///   launchApp → ensureAuthenticated (reuse session, else email login)
///     → Fuel Timeline → settings gear (fuel_timeline.settings)
///     → for each row that exists:
///         Profile & Preferences   → profile_edit.back_button
///         Diet/Allergies/Formulas → food_prefs.title
///         Sport Preferences       → sport_prefs.title
///         Body Composition        → nutrition_profile.title
///         Nutrition Targets       → nutrition_targets.title
///         Coach Connection        → coach_connection.title
///         Connected Apps          → connected_apps.title
///         Help & Feedback         → help.title
///       tap in → landmark visible → back → settings.title visible again.
///
/// Deliberately NOT swept:
///   - settings.appearance_row — opens a theme dialog, not a route.
///   - settings.privacy_row — commented out in settings_screen.dart
///     (hidden 2026-07-14 pending privacy-UX rethink).
///   - Sweat profile / per-sport settings — not top-level rows (they live
///     inside the Sport Preferences hub).
///
/// Auth:
///   Reuses an existing session, else logs in with the flavor-matched
///   INTEGRATION_TEST creds. Self-skips when neither is available.
///
/// Run:
///   patrol test --target integration_test/flows/settings_sweep_flow_test.dart \
///     --flavor dev \
///     --dart-define-from-file=.env.dev.local \
///     --dart-define-from-file=secrets/integration_test.env \
///     --device "iPhone 17 Pro"
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../helpers/flow_launcher.dart';

/// One settings row → landmark → back-button triple.
class _SweepTarget {
  const _SweepTarget({
    required this.name,
    required this.rowKey,
    required this.landmarkKey,
    required this.backKey,
  });

  final String name;
  final ValueKey<String> rowKey;
  final ValueKey<String> landmarkKey;
  final ValueKey<String> backKey;
}

const List<_SweepTarget> _targets = [
  _SweepTarget(
    name: 'Profile & Preferences',
    rowKey: ValueKey('settings.profile_row'),
    landmarkKey: ValueKey('profile_edit.back_button'),
    backKey: ValueKey('profile_edit.back_button'),
  ),
  _SweepTarget(
    name: 'Diet, Allergies & Formulas',
    rowKey: ValueKey('settings.food_prefs_row'),
    landmarkKey: ValueKey('food_prefs.title'),
    backKey: ValueKey('food_prefs.back_button'),
  ),
  _SweepTarget(
    name: 'Sport Preferences',
    rowKey: ValueKey('settings.sport_prefs_row'),
    landmarkKey: ValueKey('sport_prefs.title'),
    backKey: ValueKey('sport_prefs.back_button'),
  ),
  _SweepTarget(
    name: 'Body Composition',
    rowKey: ValueKey('settings.body_composition_row'),
    landmarkKey: ValueKey('nutrition_profile.title'),
    backKey: ValueKey('nutrition_profile.back_button'),
  ),
  _SweepTarget(
    name: 'Nutrition Targets',
    rowKey: ValueKey('settings.nutrition_targets_row'),
    landmarkKey: ValueKey('nutrition_targets.title'),
    backKey: ValueKey('nutrition_targets.back_button'),
  ),
  _SweepTarget(
    name: 'Coach Connection',
    rowKey: ValueKey('settings.coach_connection_row'),
    landmarkKey: ValueKey('coach_connection.title'),
    backKey: ValueKey('coach_connection.back_button'),
  ),
  _SweepTarget(
    name: 'Connected Apps',
    rowKey: ValueKey('settings.connected_apps_row'),
    landmarkKey: ValueKey('connected_apps.title'),
    backKey: ValueKey('connected_apps.back_button'),
  ),
  _SweepTarget(
    name: 'Help & Feedback',
    rowKey: ValueKey('settings.help_row'),
    landmarkKey: ValueKey('help.title'),
    backKey: ValueKey('help.back_button'),
  ),
];

void main() {
  patrolTest(
    'settings sweep — every top-level settings row opens and comes back',
    ($) async {
      await launchApp();
      await $.pump(const Duration(milliseconds: 500));

      if (!await ensureAuthenticated($)) {
        markTestSkipped(noAuthSkipMessage());
        return;
      }

      // ---- 1. Fuel Timeline → settings gear ------------------------------
      await $(
        const ValueKey('fuel_timeline.settings'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      await $(
        const ValueKey('fuel_timeline.settings'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 400));

      await $(
        const ValueKey('settings.title'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));

      // ---- 2. Sweep every top-level row -----------------------------------
      for (final target in _targets) {
        // Bring the row into view. If the row is not in the tree at all
        // (feature hidden in this flavor), record it and move on — a missing
        // entry point is not a crash.
        final rowFound = await _scrollRowIntoView($, target.rowKey);
        if (!rowFound) {
          // ignore: avoid_print
          print('settings_sweep: row ${target.rowKey.value} absent — skipped');
          continue;
        }

        await $(target.rowKey).tap(settlePolicy: SettlePolicy.noSettle);
        await $.pump(const Duration(milliseconds: 400));

        // The landmark MUST render — this is the crash assertion.
        await $(
          target.landmarkKey,
        ).waitUntilVisible(timeout: const Duration(seconds: 30));
        expect(
          $(target.landmarkKey),
          findsWidgets,
          reason:
              '${target.name} screen should render its landmark '
              '(${target.landmarkKey.value}) after tapping '
              '${target.rowKey.value}.',
        );

        // Navigate back and confirm we're on the settings list again.
        await $(
          target.backKey,
        ).waitUntilVisible(timeout: const Duration(seconds: 15));
        await $(target.backKey).tap(settlePolicy: SettlePolicy.noSettle);
        await $.pump(const Duration(milliseconds: 400));

        await $(
          const ValueKey('settings.title'),
        ).waitUntilVisible(timeout: const Duration(seconds: 20));
      }

      // Final sanity: settings list still alive after the whole sweep.
      expect($(const ValueKey('settings.title')), findsOneWidget);
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

/// Returns true once [rowKey] is in the tree, scrolling the settings list a
/// few screens down if needed. Manual bounded drags instead of `scrollTo()`
/// so a stray spinner elsewhere on screen can't burn 75 s of settle time.
Future<bool> _scrollRowIntoView(
  PatrolIntegrationTester $,
  ValueKey<String> rowKey,
) async {
  for (var attempt = 0; attempt < 8; attempt++) {
    if ($(rowKey).exists) {
      // Nudge it fully into the viewport so the tap lands.
      try {
        await $.tester.ensureVisible(find.byKey(rowKey).first);
      } catch (_) {
        // Best-effort — the tap below will fail loudly if it's still hidden.
      }
      await $.pump(const Duration(milliseconds: 200));
      return true;
    }
    // Drag the outer settings list upward one viewport-ish step.
    await $.tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await $.pump(const Duration(milliseconds: 300));
  }
  return $(rowKey).exists;
}
