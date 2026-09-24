/// Onboarding (2026-08 redesign) end-to-end walks, driven by `ValueKey`
/// finders through the 9-step PageView:
///
///   splash → sports → goals → pitfalls → connect_training → personal_info
///     → body_composition → nutrition_settings → plan_reveal
///     → daily_plan_preview → auth ("Your plan is ready…").
///
/// One flow (the anonymous "skip everything" flow was removed on 2026-09-16
/// with the guest path itself; mp-417: the account is required):
///
///   **Happy path** — Running + a goal, "I don't use training plan apps"
///   tile, personal info, one plan-reveal edit, a daily-preview tab switch,
///   "Save My Plan", then email signup at a sweepable `lee+e2e-*` address →
///   lands on the full-screen paywall with no close button (mp-457). Its ⋯
///   menu lists Restore, Redeem code, Sign out and Delete account, and no
///   Manage (nothing to manage, mp-494). The account's rows are read (users,
///   survey, and no `user_entitlements` row, mp-624), then the account deletes
///   itself from the menu, and only then are the rows asserted, so a red run
///   leaves nothing on dev. When a session is present the flow self-skips.
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

import '../helpers/e2e_account.dart';
import '../helpers/flow_launcher.dart';
import '../helpers/supabase_probe.dart';

void main() {
  patrolTest(
    'new user completes onboarding, edits a target, and signs up with email',
    ($) async {
      await launchApp($);
      await _settleFirstFrame($);

      // Fresh install → welcome directly. Anything else (a signed-in
      // session) → skip.
      if (!await _onWelcomeScreen($)) {
        skipFlow(
          'Could not reach the welcome screen (existing non-anonymous '
          'session?). Reinstall the app for a clean onboarding run.',
        );
        return;
      }

      // A throwaway `lee+e2e-*` address (unique per run, so repeated runs
      // never collide on "account exists"). Only that shape is swept from dev
      // by scripts/testing-wave/sweep-accounts.mjs; the old
      // `audit_*@example.com` accounts were never cleaned up (testing-wave 03).
      final account = E2eAccount.fresh(
        tag: 'signup-${DateTime.now().millisecondsSinceEpoch}',
      );
      final uniqueEmail = account.email;
      final password = account.password;

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
      // The pencil opens an inline slider (the +/- and Save sheet is gone;
      // updated by testing-wave 03). Dragging it commits on release.
      await $(const ValueKey('plan_reveal.edit_long_run')).tap();
      await $(
        const ValueKey('plan_reveal.slider_long_run'),
      ).waitUntilVisible(timeout: const Duration(seconds: 10));
      await $.tester.drag(
        find.byKey(const ValueKey('plan_reveal.slider_long_run')),
        const Offset(60, 0),
      );
      await $.pump(const Duration(milliseconds: 400));
      await $(const ValueKey('plan_reveal.edit_long_run')).tap();

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

      // ---- Landed on the full-screen paywall (mp-457: closed Gate) ------
      // A new account has no Pro, so the Gate answers closed and the app
      // stays on the paywall. The ⋯ button arrives with the plans after the
      // opening clip.
      await $(
        const ValueKey('paywall.more_button'),
      ).waitUntilVisible(timeout: const Duration(seconds: 40));
      expect(
        $(const ValueKey('paywall.continue_button')),
        findsOneWidget,
        reason:
            'Expected the paywall after signup. If this fails, the signup '
            'round-trip did not complete or the post-signup redirect changed.',
      );
      _expectNoWayOffThePaywall($);

      // ---- The ⋯ menu for an account with nothing to manage (mp-494) -----
      // Restore purchases, Redeem code, Sign out, Delete account; Manage
      // subscription only when there is a subscription to manage, so never
      // for a new account. The paywall never settles (its opening clip keeps
      // animating), so a bare pumpAndSettle here runs the flow into its
      // timeout (testing-wave 03). Wait for the menu rows instead.
      await $(
        const ValueKey('paywall.more_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      for (final key in const [
        ValueKey('paywall.restore_button'),
        ValueKey('paywall.redeem_code_button'),
        ValueKey('paywall.sign_out_button'),
        ValueKey('paywall.delete_account_button'),
      ]) {
        await $(key).waitUntilVisible(timeout: const Duration(seconds: 10));
        expect($(key), findsOneWidget, reason: 'paywall menu carries $key');
      }
      expect(
        $(const ValueKey('paywall.manage_button')),
        findsNothing,
        reason:
            'mp-494: Manage subscription shows only when the account has a '
            'subscription to manage; a new account has none.',
      );
      // Close the menu (a tap outside the panel dismisses its PopupRoute).
      await $.tester.tapAt(const Offset(20, 700));
      await $.pump(const Duration(seconds: 1));
      expect(
        find.textContaining('Failed to save'),
        findsNothing,
        reason:
            'The signup save path must not surface the save-failure '
            'snackbar.',
      );

      // ---- Read the account's rows before deleting it --------------------
      // Probe Supabase AS THE ACCOUNT JUST CREATED (RLS scopes every read to
      // it). The upload is a background walk after navigation, so poll. The
      // rows are only read here; the assertions run after the delete, so a
      // failed assertion never leaves the account behind on dev.
      final rows = await _pollForPersistedOnboarding(uniqueEmail, password);

      // ---- Delete the account from the paywall's ⋯ menu (mp-494) ---------
      await $(
        const ValueKey('paywall.more_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $(
        const ValueKey('paywall.delete_account_button'),
      ).waitUntilVisible(timeout: const Duration(seconds: 10));
      await $(
        const ValueKey('paywall.delete_account_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $(
        const ValueKey('paywall.confirm.action'),
      ).waitUntilVisible(timeout: const Duration(seconds: 10));
      await $(
        const ValueKey('paywall.confirm.action'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $(
        const ValueKey('welcome.get_started_button'),
      ).waitUntilVisible(timeout: const Duration(seconds: 40));
      expect(
        await account.isGone(),
        isTrue,
        reason: '$uniqueEmail can still sign in after Delete account.',
      );

      // ---- The Gate's inputs: no Entitlement row for a new account -------
      // An empty read only means something once the same probe has read the
      // users row, which proves the token and the transport worked.
      final userRow = rows.userRow;
      final surveyRow = rows.surveyRow;
      if (userRow == null) {
        fail(
          'users row for $uniqueEmail never appeared in Supabase within the '
          'polling window — the post-signup profile upload did not land.',
        );
      }
      expect(
        rows.entitlementRows,
        isEmpty,
        reason:
            'A new account has never paid, so user_entitlements holds no row '
            'for it (mp-624).',
      );

      // ---- THE POINT OF THIS FLOW: the answers actually persisted --------
      // gender female, metric units, high gut training, heavy sweat rate,
      // the plan-reveal carb edit, and the survey row. These are exactly the
      // fields the 2026-08 audit found being dropped or reset at the auth
      // boundary.
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

      // Last, because it is red on an open app bug (testing-wave 03-009:
      // the plan-reveal edit is dropped at signup) and every check above
      // should still report.
      final overrides = userRow['nutrition_target_overrides'];
      expect(
        overrides,
        isNotNull,
        reason:
            'the plan-reveal edit must persist as a nutrition_target_override '
            '— it was omitted from the old upload payload (03-009).',
      );
      expect(
        (overrides as Map)['duringRun'],
        isNotNull,
        reason: 'the edited long-RUN carb target must survive signup.',
      );
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}

/// Poll Supabase (as the just-registered account) for the uploaded profile
/// and survey rows, and read its `user_entitlements` rows once both are in.
/// The post-signup upload runs in the background after navigation, so give
/// it up to ~90s of wall clock before giving up.
Future<
  ({
    Map<String, dynamic>? userRow,
    Map<String, dynamic>? surveyRow,
    List<Map<String, dynamic>> entitlementRows,
  })
>
_pollForPersistedOnboarding(String email, String password) async {
  Map<String, dynamic>? userRow;
  Map<String, dynamic>? surveyRow;
  var entitlementRows = const <Map<String, dynamic>>[];

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
    if (userRow != null && surveyRow != null) {
      entitlementRows = await probe.select(
        'user_entitlements',
        query: 'user_id=eq.${probe.userId}&select=*',
      );
      break;
    }
  }
  return (
    userRow: userRow,
    surveyRow: surveyRow,
    entitlementRows: entitlementRows,
  );
}

/// mp-457: a closed Gate lands on the full-screen paywall and stays there.
/// No close or back control on the screen, and nothing under it to pop back
/// to (an iOS edge swipe pops whatever the route can pop).
void _expectNoWayOffThePaywall(PatrolIntegrationTester $) {
  final screen = find.byKey(const ValueKey('paywall.screen'));
  expect(screen, findsOneWidget, reason: 'the paywall is the screen shown');
  for (final escape in [
    find.byType(CloseButton),
    find.byType(BackButton),
    find.byIcon(Icons.close),
    find.byIcon(Icons.close_rounded),
    find.byIcon(Icons.arrow_back),
    find.byIcon(Icons.arrow_back_ios),
    find.byIcon(Icons.arrow_back_ios_new),
  ]) {
    expect(
      find.descendant(of: screen, matching: escape),
      findsNothing,
      reason: 'mp-457: the paywall has no close button ($escape)',
    );
  }
  final route = ModalRoute.of($.tester.element(screen));
  expect(
    route?.canPop ?? false,
    isFalse,
    reason:
        'mp-457: nothing sits behind the paywall, so it must not be poppable '
        '(a back swipe would leave it).',
  );
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
