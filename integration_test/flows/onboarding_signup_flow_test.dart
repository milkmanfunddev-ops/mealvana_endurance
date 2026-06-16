/// Onboarding → create-new-user walk — the full anonymous onboarding flow
/// driven end-to-end by `ValueKey` finders, ending in an email signup that
/// lands on the calendar.
///
/// Uses **Patrol's `$` action API** (not bare `WidgetTester.pumpAndSettle`).
/// Patrol actions settle with `SettlePolicy.trySettle` bounded by a 10s
/// `settleTimeout`, so a never-settling tree caps each step at ~10s and
/// proceeds instead of hanging `pumpAndSettle` for its 10-minute default.
///
/// STATUS (2026-06-13):
///   - iOS (iPhone 17 Pro / iOS 26.2): PASSES (~90s).
///   - Android (emulator): every step PASSES except the birth-year picker.
///     The birth-year `CupertinoPicker` modal (`showBirthYearPicker`) deadlocks
///     the test binding on Android — even a raw `WidgetTester.tap` on its "Done"
///     button never returns (works fine on iOS). Tracked as the sole Android
///     blocker. Likely needs an app-side test-friendliness tweak to the picker
///     (e.g. disable the magnifier animation under test, or expose a way to set
///     the birthday without the modal). See markers in git history.
///
/// Flow: welcome → connect-training (skip) → profile → sports → dietary →
///   allergies → food (skip) → create account → sign-up with email → calendar.
///
/// Run: patrol test --target integration_test/flows/onboarding_signup_flow_test.dart \
///        --flavor dev --dart-define-from-file=.env.dev.local \
///        --device "iPhone 17 Pro"      # or: --device emulator-5554
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:mealvana_endurance/main_dev.dart' as app;

void main() {
  patrolTest(
    'new user completes onboarding and lands on calendar',
    ($) async {
      await app.main();
      // Bounded first-frame settle (default 100ms interval, 2-min ceiling).
      await $.tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(minutes: 2),
      );

      // Unique email so repeated runs never collide on "account exists".
      final uniqueEmail =
          'audit_${DateTime.now().millisecondsSinceEpoch}@example.com';
      const password = 'Test1234!';

      // ---- Guard: must start on the welcome screen ----------------------
      if (!$(const ValueKey('welcome.get_started_button')).exists) {
        markTestSkipped(
          'Welcome screen not present — app launched with an existing '
          'session. Reinstall the app for a clean onboarding run.',
        );
        expect(
          $(const ValueKey('calendar.create_activity_fab')),
          findsOneWidget,
          reason: 'Not on welcome AND not on calendar — unexpected state.',
        );
        return;
      }

      // ---- 1. Welcome → Connect Training --------------------------------
      await $(const ValueKey('welcome.get_started_button')).tap();

      // ---- 2. Connect Training → skip -----------------------------------
      await $(const ValueKey('connect_training.skip_button')).tap();

      // ---- 3. Profile form ----------------------------------------------
      await $(const ValueKey('profile.first_name_field')).enterText('Audit');
      await $(const ValueKey('profile.last_name_field')).enterText('User');
      await $(const ValueKey('profile.email_field')).enterText(uniqueEmail);

      // Gender (defaults to MALE; tap explicitly for determinism).
      await $(const ValueKey('profile.gender_male_button')).tap();

      // Birth year — open the wheel picker and accept the default (1990).
      // Driven via the RAW WidgetTester (no Patrol wrapper / no auto-settle) +
      // bounded manual pumps. NOTE: this still deadlocks on Android (the Done
      // tap never returns) — see STATUS above. Passes on iOS.
      await $.tester
          .tap(find.byKey(const ValueKey('profile.birth_year_button')));
      await $.tester.pump(const Duration(seconds: 1));
      await $.tester.tap(
        find.byKey(const ValueKey('profile.birth_year_done_button')),
        warnIfMissed: false,
      );
      await $.tester.pump(const Duration(milliseconds: 400));

      // Physical info (imperial by default: ft / in / lbs).
      await $(const ValueKey('profile.height_ft_field')).enterText('5');
      await $(const ValueKey('profile.height_in_field')).enterText('10');
      await $(const ValueKey('profile.weight_field')).enterText('170');

      await $(const ValueKey('profile.continue_button')).tap();

      // ---- 4. Sport selection (Running pre-selected) --------------------
      await $(const ValueKey('sport_selection.continue_button')).tap();

      // ---- 5. Dietary preference → Omnivore -----------------------------
      await $(const ValueKey('dietary_preference.omnivore_chip')).tap();
      await $(const ValueKey('dietary_preference.continue_button')).tap();

      // ---- 6. Allergies → None ------------------------------------------
      await $(const ValueKey('allergies.none_chip')).tap();
      await $(const ValueKey('allergies.continue_button')).tap();

      // ---- 7. Food selection (optional — skip) --------------------------
      await $(const ValueKey('food_selection.continue_button')).tap();

      // ---- 8. Create account → Sign up with Email -----------------------
      await $(const ValueKey('post_onboarding.email_button')).tap();

      // ---- 9. Email signup form -----------------------------------------
      await $(const ValueKey('signup_email.email_field')).enterText(uniqueEmail);
      await $(const ValueKey('signup_email.password_field')).enterText(password);
      await $(const ValueKey('signup_email.confirm_password_field'))
          .enterText(password);
      await $(const ValueKey('signup_email.create_account_button')).tap();

      // ---- 10. Assert we landed on the calendar -------------------------
      await $(const ValueKey('calendar.create_activity_fab')).waitUntilVisible(
        timeout: const Duration(seconds: 40),
      );
      expect(
        $(const ValueKey('calendar.create_activity_fab')),
        findsOneWidget,
        reason:
            'Expected the calendar FAB after signup. If this fails, the signup '
            'round-trip did not complete or the post-signup redirect changed.',
      );
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
