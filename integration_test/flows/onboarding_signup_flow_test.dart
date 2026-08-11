/// Onboarding (2026-08 redesign) end-to-end walks, driven by `ValueKey`
/// finders through the 9-step PageView:
///
///   splash → sports → goals → pitfalls → connect_training → personal_info
///     → body_composition → nutrition_settings → plan_reveal
///     → daily_plan_preview → auth ("Your plan is ready…").
///
/// Two flows, in declaration order:
///
///   1. **Skip-everything anonymous** — minimal selections, skip the connect
///      step, defaults on every form, "Continue without an account" → lands
///      on /main as an anonymous user with no error snackbar. Needs a fresh
///      install (guards on the welcome screen and self-skips otherwise).
///   2. **Happy path** — Running + a goal, "I don't use training plan apps"
///      tile, personal info, one plan-reveal edit, a daily-preview tab
///      switch, "Save My Plan", then email signup → lands on the tabs shell.
///      When flow 1 just ran, this flow recovers to the welcome screen by
///      signing the anonymous user out via the keyed Settings path
///      (`settings.sign_out_button` → `signout_dialog.sign_out_anyway_button`,
///      which routes to /welcome); otherwise it self-skips.
///
/// The connect-FAILURE path (error snackbar → card back in Connect state →
/// retry / Skip still advances) is deliberately NOT scripted here: Patrol
/// cannot genuinely fail a real OAuth handshake without faking it. It is
/// covered at the widget-test layer instead
/// (test/features/onboarding/connect_training_failure_test.dart).
///
/// Uses **Patrol's `$` action API** (not bare `WidgetTester.pumpAndSettle`).
/// Patrol actions settle with `SettlePolicy.trySettle` bounded by a 10s
/// `settleTimeout`, so a never-settling tree caps each step at ~10s and
/// proceeds instead of hanging `pumpAndSettle` for its 10-minute default.
///
/// ANDROID QUIRK (carried over from the pre-redesign test, 2026-06-13): the
/// birth-year `CupertinoPicker` modal deadlocks the test binding on Android —
/// even a raw `WidgetTester.tap` on its "Done" button never returns (works
/// fine on iOS). The picker wheel also ignores Patrol scrolls, so both flows
/// drive the sheet with raw tester taps + bounded pumps and accept the
/// pre-selected year (1990) via Done. See markers in git history.
///
/// BUNDLE-ORDER NOTE: in a full-bundle run, flows execute alphabetically and
/// the earlier ones call `ensureAuthenticated`, which signs in the shared
/// tester account — so by the time this file runs there is a session and both
/// flows self-skip. Run this file standalone on a fresh install:
///
/// Run: patrol test --target integration_test/flows/onboarding_signup_flow_test.dart \
///        --flavor dev --dart-define-from-file=.env.dev.local \
///        --device "iPhone 17 Pro"      # or: --device emulator-5554
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../helpers/flow_launcher.dart';
import '../helpers/supabase_probe.dart';

void main() {
  patrolTest(
    'skip-everything onboarding lands on /main as an anonymous user',
    ($) async {
      await launchApp();
      await _settleFirstFrame($);

      if (!await _onWelcomeScreen($)) {
        markTestSkipped(
          'Welcome screen not present — app launched with an existing '
          'session. Reinstall the app for a clean onboarding run.',
        );
        return;
      }

      await _startOnboardingFromWelcome($);

      // ---- Sports (≥1 required; everything after is skippable) ----------
      await $(const ValueKey('sport_selection.running_chip')).tap();
      await $(const ValueKey('sport_selection.continue_button')).tap();

      // ---- Goals + Pitfalls: non-blocking, continue straight through ----
      await $(const ValueKey('goals.continue_button')).tap();
      await $(const ValueKey('pitfalls.continue_button')).tap();

      // ---- Connect training → Continue (the 2026-08 design owner removed
      // Skip-for-now: it was equivalent to Continue) -----------------------
      await $(const ValueKey('connect_training.continue_button')).tap();

      // ---- Personal info (gender + birth year gate the continue) --------
      await _fillPersonalInfoMinimum($);

      // ---- Body composition + nutrition settings: defaults --------------
      await $(const ValueKey('body_comp.continue_button')).tap();
      await $(const ValueKey('nutrition_settings.continue_button')).tap();

      // ---- Plan reveal: wait out the loader (footer disabled during it) --
      await _waitForPlanReveal($);
      await $(const ValueKey('plan_reveal.continue_button')).tap();

      // ---- Daily preview → Save My Plan ---------------------------------
      await $(
        const ValueKey('daily_preview.save_button'),
      ).waitUntilVisible(timeout: const Duration(seconds: 15));
      await $(const ValueKey('daily_preview.save_button')).tap();

      // ---- Auth screen → Continue without an account --------------------
      await $(
        const ValueKey('create_account.skip_button'),
      ).waitUntilVisible(timeout: const Duration(seconds: 15));
      await $(const ValueKey('create_account.skip_button')).tap();

      // ---- Landed on the tabs shell, with the local save succeeding -----
      // (The Drift survey row is not reachable from the Patrol process — the
      // app owns the database connection — so the flow asserts the two
      // user-visible facts instead: navigation happened, and the
      // "Failed to save your preferences" MealvanaSnackbar did not.)
      await $(
        const ValueKey('bottom_nav.timeline_tab'),
      ).waitUntilVisible(timeout: const Duration(seconds: 40));
      expect(
        $(const ValueKey('bottom_nav.timeline_tab')),
        findsOneWidget,
        reason:
            'Expected the tabs shell after skipping account creation. If this '
            'fails, saveAllOnboardingData failed or the anonymous redirect '
            'changed.',
      );
      expect(
        find.textContaining('Failed to save'),
        findsNothing,
        reason:
            'The anonymous save path must not surface the save-failure '
            'snackbar.',
      );
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );

  patrolTest(
    'new user completes onboarding, edits a target, and signs up with email',
    ($) async {
      await launchApp();
      await _settleFirstFrame($);

      // Fresh install → welcome directly. Anonymous session left behind by
      // the flow above → recover via the keyed Settings sign-out (routes to
      // /welcome). Anything else (signed-in tester account) → skip.
      if (!await _onWelcomeScreen($) && !await _recoverToWelcome($)) {
        markTestSkipped(
          'Could not reach the welcome screen (existing non-anonymous '
          'session?). Reinstall the app for a clean onboarding run.',
        );
        return;
      }

      // Unique email so repeated runs never collide on "account exists".
      final uniqueEmail =
          'audit_${DateTime.now().millisecondsSinceEpoch}@example.com';
      const password = 'Test1234!';

      await _startOnboardingFromWelcome($);

      // ---- Sports: Running (drives the long-run card on the reveal) -----
      await $(const ValueKey('sport_selection.running_chip')).tap();
      await $(const ValueKey('sport_selection.continue_button')).tap();

      // ---- Goals: pick one, continue ------------------------------------
      await $(const ValueKey('goals.performance_chip')).tap();
      await $(const ValueKey('goals.continue_button')).tap();

      // ---- Pitfalls: skip through (non-blocking) ------------------------
      await $(const ValueKey('pitfalls.continue_button')).tap();

      // ---- Connect training → "I don't use training plan apps." ---------
      // The declined tile is an affirmative answer (records a survey flag +
      // analytics) and advances on its own — no continue tap needed.
      await _scrollIntoView(
        $,
        const ValueKey('connect_training.declined_tile'),
      );
      await $(const ValueKey('connect_training.declined_tile')).tap();

      // ---- Personal info -------------------------------------------------
      await _fillPersonalInfoMinimum($);

      // ---- Body composition: switch to METRIC as a persistence sentinel --
      // (the weight/height wheels ignore Patrol scrolls — the unit toggle is
      // the one distinguishable input on this step, and unit_system is one of
      // the fields the 2026-08 audit caught being reset to imperial).
      await $(const ValueKey('body_comp.units_metric_button')).tap();
      await $(const ValueKey('body_comp.continue_button')).tap();

      // ---- Nutrition settings: high gut + HEAVY sweat (both sentinels) ---
      await $(const ValueKey('nutrition_settings.gut_high')).tap();
      await $(const ValueKey('nutrition_settings.sweat_heavy')).tap();
      await $(const ValueKey('nutrition_settings.continue_button')).tap();

      // ---- Plan reveal: wait for the loader, then edit the long-run target
      await _waitForPlanReveal($);

      await _scrollIntoView($, const ValueKey('plan_reveal.edit_long_run'));
      await $(const ValueKey('plan_reveal.edit_long_run')).tap();
      await $(
        const ValueKey('plan_reveal.edit_plus'),
      ).waitUntilVisible(timeout: const Duration(seconds: 10));
      await $(const ValueKey('plan_reveal.edit_plus')).tap();
      await $(const ValueKey('plan_reveal.edit_save')).tap();

      await $(const ValueKey('plan_reveal.continue_button')).tap();

      // ---- Daily preview: switch to the Rest tab, then Save My Plan -----
      await $(
        const ValueKey('daily_preview.tab_rest'),
      ).waitUntilVisible(timeout: const Duration(seconds: 15));
      await $(const ValueKey('daily_preview.tab_rest')).tap();
      await $(const ValueKey('daily_preview.save_button')).tap();

      // ---- Auth screen → Sign up with Email -----------------------------
      await $(
        const ValueKey('post_onboarding.email_button'),
      ).waitUntilVisible(timeout: const Duration(seconds: 15));
      await $(const ValueKey('post_onboarding.email_button')).tap();

      await $(
        const ValueKey('signup_email.email_field'),
      ).enterText(uniqueEmail);
      await $(
        const ValueKey('signup_email.password_field'),
      ).enterText(password);
      await $(
        const ValueKey('signup_email.confirm_password_field'),
      ).enterText(password);
      await $(const ValueKey('signup_email.create_account_button')).tap();

      // ---- Landed on the tabs shell with the plan saved -----------------
      await $(
        const ValueKey('bottom_nav.timeline_tab'),
      ).waitUntilVisible(timeout: const Duration(seconds: 40));
      expect(
        $(const ValueKey('bottom_nav.timeline_tab')),
        findsOneWidget,
        reason:
            'Expected the tabs shell after signup. If this fails, the signup '
            'round-trip did not complete or the post-signup redirect changed.',
      );
      expect(
        find.textContaining('Failed to save'),
        findsNothing,
        reason:
            'The signup save path must not surface the save-failure '
            'snackbar.',
      );

      // ---- THE POINT OF THIS FLOW: the answers actually persisted --------
      // Probe Supabase AS THE ACCOUNT JUST CREATED (the shared tester session
      // can't see it under RLS) and assert the sentinel answers landed:
      // gender female, metric units, high gut training, heavy sweat rate,
      // the plan-reveal carb edit, and the survey row. These are exactly the
      // fields the 2026-08 audit found being dropped or reset at the auth
      // boundary. The upload is a background walk after navigation, so poll.
      final rows = await _pollForPersistedOnboarding(uniqueEmail, password);
      final userRow = rows.userRow;
      final surveyRow = rows.surveyRow;

      if (userRow == null) {
        fail(
          'users row for $uniqueEmail never appeared in Supabase within the '
          'polling window — the post-signup profile upload did not land.',
        );
      }
      expect(userRow['gender'], 'female');
      expect(
        userRow['unit_system'],
        'metric',
        reason:
            'unit_system was one of the fields the old upload payload '
            'omitted — an imperial value here means the payload regressed.',
      );
      expect(userRow['gut_training_level'], 'high');
      expect(
        userRow['sweat_rate'],
        'heavy',
        reason: 'sweat_rate was omitted from the old upload payload.',
      );
      expect(userRow['onboarding_completed'], true);
      final overrides = userRow['nutrition_target_overrides'];
      expect(
        overrides,
        isNotNull,
        reason:
            'the plan-reveal edit must persist as a nutrition_target_override '
            '— it was omitted from the old upload payload.',
      );
      expect(
        (overrides as Map)['duringRun'],
        isNotNull,
        reason: 'the edited long-RUN carb target must survive signup.',
      );

      expect(
        surveyRow,
        isNotNull,
        reason:
            'the onboarding_surveys row (sports/goals/pitfalls) must reach '
            'Supabase — it now has a dirty-record retry channel, so absence '
            'means the upload never ran at all.',
      );
      expect(surveyRow!['sports'], contains('running'));
      expect(surveyRow['goals'], contains('performance'));
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}

/// Poll Supabase (as the just-registered account) for the uploaded profile
/// and survey rows. The post-signup upload runs in the background after
/// navigation, so give it up to ~90s of wall clock before giving up.
Future<({Map<String, dynamic>? userRow, Map<String, dynamic>? surveyRow})>
_pollForPersistedOnboarding(String email, String password) async {
  Map<String, dynamic>? userRow;
  Map<String, dynamic>? surveyRow;

  for (var attempt = 0; attempt < 18; attempt++) {
    await Future<void>.delayed(const Duration(seconds: 5));
    final probe = await SupabaseProbe.signInAs(
      email: email,
      password: password,
    );
    if (probe == null) continue; // auth row may itself lag a beat
    userRow ??= await probe.userRow();
    surveyRow ??= await probe.onboardingSurvey();
    // The users row is a hard requirement; the survey is uploaded by the
    // same background walk, so once both are present we're done.
    if (userRow != null && surveyRow != null) break;
  }
  return (userRow: userRow, surveyRow: surveyRow);
}

/// Bounded first-frame settle (default 100ms interval, 2-min ceiling).
Future<void> _settleFirstFrame(PatrolIntegrationTester $) async {
  await $.tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(minutes: 2),
  );
}

/// Polls briefly for the welcome screen's entry point.
Future<bool> _onWelcomeScreen(PatrolIntegrationTester $) async {
  const welcomeKey = ValueKey('welcome.get_started_button');
  for (var i = 0; i < 20; i++) {
    if ($(welcomeKey).exists) return true;
    await $.pump(const Duration(milliseconds: 500));
  }
  return $(welcomeKey).exists;
}

/// Best-effort recovery from an ANONYMOUS session (left behind by the
/// skip-everything flow) back to /welcome, using the keyed Settings sign-out
/// path that only anonymous users get. Returns true when the welcome screen
/// is reached. Never throws — a failed recovery becomes a test skip.
Future<bool> _recoverToWelcome(PatrolIntegrationTester $) async {
  try {
    if (!$(const ValueKey('bottom_nav.timeline_tab')).exists) return false;

    await $(
      const ValueKey('fuel_timeline.settings'),
    ).waitUntilVisible(timeout: const Duration(seconds: 20));
    await $(
      const ValueKey('fuel_timeline.settings'),
    ).tap(settlePolicy: SettlePolicy.noSettle);
    await $.pump(const Duration(milliseconds: 600));

    // The anonymous sign-out button sits below the account section.
    if (!await _scrollIntoView($, const ValueKey('settings.sign_out_button'))) {
      return false;
    }
    await $(
      const ValueKey('settings.sign_out_button'),
    ).tap(settlePolicy: SettlePolicy.noSettle);
    await $.pump(const Duration(milliseconds: 400));

    await $(
      const ValueKey('signout_dialog.sign_out_anyway_button'),
    ).waitUntilVisible(timeout: const Duration(seconds: 10));
    await $(
      const ValueKey('signout_dialog.sign_out_anyway_button'),
    ).tap(settlePolicy: SettlePolicy.noSettle);

    // signOut + context.go('/welcome') round-trip.
    await $(
      const ValueKey('welcome.get_started_button'),
    ).waitUntilVisible(timeout: const Duration(seconds: 20));
    return true;
  } on Exception catch (e) {
    debugPrint('[onboarding_signup] recovery to welcome failed: $e');
    return $(const ValueKey('welcome.get_started_button')).exists;
  }
}

/// Taps "Build My Plan" and lands on the sports step, answering the regional
/// privacy-consent interstitial if it appears (strict-regime devices only).
Future<void> _startOnboardingFromWelcome(PatrolIntegrationTester $) async {
  await $(const ValueKey('welcome.get_started_button')).tap();

  // Strict-regime regions (EEA/UK, WA) get /privacy-consent first.
  const consentContinue = ValueKey('privacy_consent.continue_button');
  for (var i = 0; i < 6; i++) {
    if ($(const ValueKey('sport_selection.continue_button')).exists) return;
    if ($(consentContinue).exists) {
      await $(consentContinue).tap();
      break;
    }
    await $.pump(const Duration(milliseconds: 500));
  }

  await $(
    const ValueKey('sport_selection.continue_button'),
  ).waitUntilVisible(timeout: const Duration(seconds: 15));
}

/// Satisfies the personal-info gate (gender) and continues.
///
/// The 2026-08 spec port replaced the birth-year bottom sheet with an
/// inline wheel that always carries a value (default 1994, written to the
/// draft on first frame) — so gender is the only gate and no sheet
/// interaction exists. This also removes the old Android CupertinoPicker
/// Done-tap deadlock from this flow entirely.
Future<void> _fillPersonalInfoMinimum(PatrolIntegrationTester $) async {
  await $(
    const ValueKey('personal_info.gender_female'),
  ).waitUntilVisible(timeout: const Duration(seconds: 15));
  await $(const ValueKey('personal_info.gender_female')).tap();

  await $(const ValueKey('personal_info.continue_button')).tap();
}

/// Waits out the plan-reveal loader (≥1.5s minimum + the insight digest,
/// which is itself bounded at 10s) until the reveal title renders.
Future<void> _waitForPlanReveal(PatrolIntegrationTester $) async {
  await $(
    const ValueKey('plan_reveal.title'),
  ).waitUntilVisible(timeout: const Duration(seconds: 30));
}

/// Brings [key] into view inside the first vertical scrollable, dragging in
/// viewport-ish steps (same pattern as settings_sweep's row scroller).
/// Returns whether the widget ended up in the tree.
Future<bool> _scrollIntoView(
  PatrolIntegrationTester $,
  ValueKey<String> key,
) async {
  for (var attempt = 0; attempt < 8; attempt++) {
    if ($(key).exists) {
      try {
        await $.tester.ensureVisible(find.byKey(key).first);
      } catch (_) {
        // Best-effort — the caller's tap will fail loudly if still hidden.
      }
      await $.pump(const Duration(milliseconds: 200));
      return true;
    }
    final scrollable = _firstVerticalScrollable();
    if (scrollable == null) break;
    await $.tester.drag(scrollable, const Offset(0, -400));
    await $.pump(const Duration(milliseconds: 300));
  }
  return $(key).exists;
}

/// The first vertically-scrolling [Scrollable] on screen, or null. (Some
/// onboarding steps put a horizontal strip first in the tree.)
Finder? _firstVerticalScrollable() {
  final all = find.byType(Scrollable).evaluate().toList();
  for (var i = 0; i < all.length; i++) {
    final widget = all[i].widget;
    if (widget is Scrollable &&
        (widget.axisDirection == AxisDirection.down ||
            widget.axisDirection == AxisDirection.up)) {
      return find.byType(Scrollable).at(i);
    }
  }
  return null;
}
