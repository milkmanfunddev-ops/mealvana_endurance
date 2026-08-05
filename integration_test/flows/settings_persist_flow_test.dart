/// Settings-persist smoke test under **Patrol**.
///
/// Proves that editing a numeric profile field (Body Composition → weight)
/// persists across a navigate-away and re-open, exercising the
/// `UserProfile.copyWith` / `updateUserProfile` save path.
///
/// This test is high-value because a DATA-LOSS bug previously silently
/// dropped cycling-speed and swim-pace fields on every save. The same
/// `updateUserProfile` call handles all body-composition fields; verifying
/// weight round-trips ensures the save/load cycle is intact.
///
/// Flow:
///   ensureAuthenticated
///     → fuel_timeline.settings → settings screen
///     → settings.body_composition_row → Body Composition screen
///     → read current weight from body_composition.weight_field
///     → set a sentinel weight (e.g. current + 1 lb, clamped 100–350)
///     → tap nutrition_profile.save_button
///     → wait for save to complete (button disappears = _hasChanges reset)
///     → back to settings screen (nutrition_profile.back_button)
///     → tap settings.body_composition_row again
///     → assert body_composition.weight_field shows the sentinel weight
///     → restore original weight (save again) for cleanup
///
/// Auth:
///   Boots via the shared launcher (helpers/flow_launcher.dart, flavor-aware)
///   and reuses an existing session via the shared ensureAuthenticated, else
///   logs in with the flavor-matched TestConfig.loginEmail/loginPassword.
///   Self-skips if no session and no credentials provided.
///
/// Run:
///   patrol test \
///     --target integration_test/flows/settings_persist_flow_test.dart \
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
    'settings — body composition weight persists across navigate-away and back',
    ($) async {
      await launchApp();
      await $.pump(const Duration(milliseconds: 500));

      // ---- 0. Auth ----------------------------------------------------------
      // Step 1 taps the Fuel Timeline's settings gear, so gate on that key
      // rather than the default nav-bar sentinel.
      if (!await ensureAuthenticated(
        $,
        sentinel: const ValueKey('fuel_timeline.settings'),
      )) {
        markTestSkipped(noAuthSkipMessage());
        return;
      }

      // ---- 1. Open Settings -------------------------------------------------
      await $(
        const ValueKey('fuel_timeline.settings'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      await $(
        const ValueKey('fuel_timeline.settings'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 300));

      // Wait for the settings Quick Links section to load (data state).
      // profile_row is the first visible row in the Quick Links section and
      // will appear immediately once settingsControllerProvider has data.
      // Do NOT waitUntilVisible on body_composition_row: it is the 5th row and
      // may be below the fold; waitUntilVisible would time out even though the
      // widget exists. Instead gate on profile_row, then scrollTo() for the
      // body_composition row.
      await $(
        const ValueKey('settings.profile_row'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));

      // ---- 2. Open Body Composition -----------------------------------------
      // Body Composition is the 5th row in the Quick Links section, which may
      // be below the fold on some screen sizes.  scrollTo() handles the scroll.
      // scrollTo() uses pumpAndTrySettle; the settings screen is in its data
      // state at this point (gated above on profile_row), so no spinner.
      await $(const ValueKey('settings.body_composition_row'))
          .scrollTo(
            maxScrolls: 12,
            settleBetweenScrollsTimeout: const Duration(milliseconds: 500),
          )
          .tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 400));

      // Wait for the weight field to appear (screen calls userRepository async).
      await $(
        const ValueKey('body_composition.weight_field'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));

      // ---- 3. Read the current weight + compute sentinel --------------------
      // The weight field is a KyleInputField (TextFormField wrapper).  We read
      // the current text via the EditableText descendant of the field's key.
      final weightFinder = find.descendant(
        of: find.byKey(const ValueKey('body_composition.weight_field')),
        matching: find.byType(EditableText),
      );
      expect(
        weightFinder,
        findsOneWidget,
        reason: 'weight field must contain an EditableText',
      );
      final editableText = $.tester.widget<EditableText>(weightFinder);
      final currentText = editableText.controller.text;
      final currentWeight = int.tryParse(currentText) ?? 160;

      // Sentinel: +1 lb, clamped to [100, 350] to stay valid.
      final sentinelWeight = (currentWeight + 1).clamp(100, 350);
      final sentinelStr = sentinelWeight.toString();

      // ---- 4. Edit the weight field ------------------------------------------
      // enterText replaces the full field content (Flutter WidgetTester
      // semantics: tap → set text value directly via TestTextInput).  Use
      // noSettle: the Garmin body-comp async call may still be running and
      // emitting a CircularProgressIndicator elsewhere on the screen.
      await $(
        const ValueKey('body_composition.weight_field'),
      ).enterText(sentinelStr, settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 300));

      // ---- 5. Save ----------------------------------------------------------
      // The save button only appears when _hasChanges is true (conditional
      // rendering in AppBar actions).  After we edit the field above,
      // _markChanged() is called inside onChanged, so the button should now
      // be visible.
      await $(
        const ValueKey('nutrition_profile.save_button'),
      ).waitUntilVisible(timeout: const Duration(seconds: 10));
      await $(
        const ValueKey('nutrition_profile.save_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);

      // The save button disappears when _hasChanges resets to false after a
      // successful save.  PatrolFinder has no waitUntilGone; poll manually.
      for (var i = 0; i < 30; i++) {
        await $.pump(const Duration(milliseconds: 500));
        if (!$(const ValueKey('nutrition_profile.save_button')).exists) break;
      }
      await $.pump(const Duration(milliseconds: 400));

      // ---- 6. Navigate back → re-open Body Composition ----------------------
      await $(
        const ValueKey('nutrition_profile.back_button'),
      ).waitUntilVisible(timeout: const Duration(seconds: 10));
      await $(
        const ValueKey('nutrition_profile.back_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 400));

      // Should be back on the settings screen — wait for data to load.
      await $(
        const ValueKey('settings.profile_row'),
      ).waitUntilVisible(timeout: const Duration(seconds: 15));
      await $(const ValueKey('settings.body_composition_row'))
          .scrollTo(
            maxScrolls: 12,
            settleBetweenScrollsTimeout: const Duration(milliseconds: 500),
          )
          .tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 400));

      // Wait for the weight field to populate (async load from repository).
      await $(
        const ValueKey('body_composition.weight_field'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      // Give the async _loadCurrentValues() time to set the text controller.
      await $.pump(const Duration(milliseconds: 1500));

      // ---- 7. Assert the saved weight is shown ------------------------------
      final weightFinderAfter = find.descendant(
        of: find.byKey(const ValueKey('body_composition.weight_field')),
        matching: find.byType(EditableText),
      );
      expect(
        weightFinderAfter,
        findsOneWidget,
        reason: 'weight field must contain an EditableText after reload',
      );
      final editableTextAfter = $.tester.widget<EditableText>(
        weightFinderAfter,
      );
      expect(
        editableTextAfter.controller.text,
        sentinelStr,
        reason:
            'Weight should persist as $sentinelStr after save + re-open. '
            'If this fails, updateUserProfile is silently dropping the field.',
      );

      // ---- 8. Cleanup: restore original weight ------------------------------
      // Restore the original value so the test account is left unchanged.
      await $(const ValueKey('body_composition.weight_field')).enterText(
        currentText.isEmpty ? '160' : currentText,
        settlePolicy: SettlePolicy.noSettle,
      );
      await $.pump(const Duration(milliseconds: 300));

      // Save only if the button is visible (enterText triggered _markChanged).
      if ($(const ValueKey('nutrition_profile.save_button')).exists) {
        await $(
          const ValueKey('nutrition_profile.save_button'),
        ).tap(settlePolicy: SettlePolicy.noSettle);
        // Poll until the save button disappears (save completed).
        for (var i = 0; i < 30; i++) {
          await $.pump(const Duration(milliseconds: 500));
          if (!$(const ValueKey('nutrition_profile.save_button')).exists) break;
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
