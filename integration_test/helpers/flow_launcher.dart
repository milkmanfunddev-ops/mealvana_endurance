/// Shared app launcher + authentication for Patrol flow tests.
///
/// Every flow must boot the app through [launchApp] instead of importing
/// `main_dev.dart` directly: the flavor entrypoints differ only in which
/// dotenv asset they load, so a flow that hardcodes `main_dev` boots against
/// the DEV Supabase project even when the run is `--flavor prod`. [launchApp]
/// picks the entrypoint from [TestConfig.isProd], which follows the
/// SUPABASE_URL in whichever `--dart-define-from-file` env file the run was
/// given (`.env.dev.local` or `.env.prod.local`).
///
/// [ensureAuthenticated] is the single canonical login walk (previously
/// copy-pasted into every flow). It reuses an existing session when the app
/// launches straight to the tabs shell, otherwise performs the email login
/// with the flavor-matched [TestConfig.loginEmail]/[TestConfig.loginPassword].
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mealvana_endurance/main_dev.dart' as dev;
import 'package:mealvana_endurance/main_prod.dart' as prod;

import 'test_config.dart';

/// Boots the app for the flavor this run targets. Call once per test, then
/// pump briefly — do NOT pumpAndSettle (startup may show a persistent
/// spinner); [ensureAuthenticated] uses explicit visibility gates instead.
Future<void> launchApp() async {
  _testErrorHandler = FlutterError.onError;
  if (TestConfig.isProd) {
    await prod.main();
  } else {
    await dev.main();
  }
}

/// flutter_test's own `FlutterError.onError`, captured before the app boots.
void Function(FlutterErrorDetails)? _testErrorHandler;

/// Put flutter_test's error handler back after the app has replaced it.
///
/// `main()` installs a Sentry handler on `FlutterError.onError` (after
/// `SentryFlutter.init`, inside an un-awaited `runZonedGuarded`), so it lands
/// some time AFTER [launchApp] returns. That matters more than it looks: when
/// an `expect` fails, flutter_test routes the `TestFailure` through
/// `FlutterError.reportError` and relies on its own handler to record it. With
/// Sentry's handler in place nothing is recorded, the binding hits its
/// `'_pendingExceptionDetails != null'` assertion inside the error path, and
/// the test never completes — every assertion failure turns into the 5-minute
/// test timeout with no message (brick_plan_flow, 2026-09-01: three runs of
/// "hang after step 15" that were really a failed segment-count expect).
///
/// Called once the tabs shell is on screen: Sentry init precedes `runApp`, so
/// by then the override has definitely happened.
void restoreTestErrorHandler() {
  final handler = _testErrorHandler;
  if (handler != null) FlutterError.onError = handler;
}

/// The landed-marker for the post-login tabs shell. Lives in the always-on
/// FloatingActionButtonsBar, so it is present regardless of which tab login
/// lands on. (`calendar.create_activity_fab` is gone — Activities + Nutrition
/// merged into the Fuel Timeline; `calendar.settings_button` is hidden on
/// tab 0.)
const ValueKey<String> authSentinel = ValueKey('bottom_nav.timeline_tab');

/// Ensures the app is signed in and the tabs shell is visible.
///
/// Returns true when the shell sentinel is on screen. Returns false when
/// there is no existing session and no credentials for this flavor — callers
/// should `markTestSkipped` with a clear message in that case rather than
/// fail.
Future<bool> ensureAuthenticated(
  PatrolIntegrationTester $, {
  ValueKey<String> sentinel = authSentinel,
  Duration pollFor = const Duration(seconds: 90),
  Duration loginTimeout = const Duration(seconds: 40),
}) async {
  const welcome = ValueKey('welcome.log_in_button');

  // Poll for either the authed sentinel (session reuse) or the welcome
  // screen (fresh install / logged out).
  bool sentinelFound = false;
  bool welcomeFound = false;
  final polls = pollFor.inMilliseconds ~/ 500;
  for (var i = 0; i < polls; i++) {
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

  if (sentinelFound) {
    restoreTestErrorHandler();
    if (!TestConfig.hasLoginCredentials || _sessionIsTestAccount()) {
      await _resetSharedAppState($);
      return true;
    }
    // Signed in, but as someone else — typically the `sim-dev-login`
    // Keychain account left on the simulator from a manual smoke test. The
    // UI steps would still pass, but every persisted-state assertion goes
    // through SupabaseProbe, which signs in as INTEGRATION_TEST_EMAIL, and
    // RLS then hides the rows this session wrote: "no activities row titled
    // …" while the row sits in the table under the other user (brick flow,
    // 2026-09-01). Sign out — the app's auth listener routes to /welcome —
    // and take the login path below as that account.
    await Supabase.instance.client.auth.signOut();
    for (var i = 0; i < 40 && !$(welcome).exists; i++) {
      await $.pump(const Duration(milliseconds: 500));
    }
    welcomeFound = $(welcome).exists;
  }
  if (!welcomeFound || !TestConfig.hasLoginCredentials) return false;

  await $(welcome).tap();
  await $(
    const ValueKey('login_options.email_button'),
  ).waitUntilVisible(timeout: const Duration(seconds: 15));
  await $(const ValueKey('login_options.email_button')).tap();
  await $(
    const ValueKey('login.email_field'),
  ).waitUntilVisible(timeout: const Duration(seconds: 15));
  await $(const ValueKey('login.email_field')).enterText(TestConfig.loginEmail);
  await $(
    const ValueKey('login.password_field'),
  ).enterText(TestConfig.loginPassword);
  await $(const ValueKey('login.log_in_button')).tap();

  await $(sentinel).waitUntilVisible(timeout: loginTimeout);
  if (!$(sentinel).exists) return false;
  restoreTestErrorHandler();
  await _resetSharedAppState($);
  return true;
}

/// True when the live Supabase session belongs to this flavor's
/// INTEGRATION_TEST account — the identity [SupabaseProbe] queries as.
bool _sessionIsTestAccount() {
  final email = Supabase.instance.client.auth.currentUser?.email;
  return email != null &&
      email.toLowerCase() == TestConfig.loginEmail.toLowerCase();
}

/// Return the app to a known baseline before a flow starts.
///
/// **Why this is here and not left to each flow.** Patrol runs the whole bundle
/// in ONE app session: 18 tests, one Riverpod container, one signed-in account.
/// Anything a flow leaves behind — the selected day, the timeline filter — is
/// still there for every flow that runs after it, and flows run in ALPHABETICAL
/// order, so the blast radius is "everything later in the alphabet".
///
/// That is not hypothetical. It produced three separate investigations on this
/// branch: a timeline stuck off today, a filter hiding workout cards, and a
/// meal flow that passed one run and failed the next purely because an earlier
/// flow had started completing its create stack.
///
/// Resetting per-flow was the first fix, but it is opt-in: a flow that forgets
/// the call silently inherits whatever the last one did. Doing it here makes
/// the baseline a property of *being authenticated* — every flow calls
/// ensureAuthenticated, so no flow can opt out by omission.
///
/// Best-effort by design. It runs before a flow has navigated anywhere, so the
/// controls may not be on screen; their absence is the success case, not an
/// error. Flows that navigate away and come back still call
/// [ensureTimelineOnToday] explicitly at the point they assert.
Future<void> _resetSharedAppState(PatrolIntegrationTester $) async {
  await ensureTimelineOnToday($);
}

/// Put the Fuel Timeline back on **today**, and select the All filter.
///
/// Both are app-level state (`calendarSelectedDateProvider` and the timeline
/// view state) that live in the Riverpod container for the whole app session —
/// which, under Patrol, spans *every flow in the bundle*. A flow that navigates
/// to another day or narrows the filter leaves it that way for everything that
/// runs after it.
///
/// That is what made "my newly created item appears on the timeline" fail in
/// four unrelated flows on the M1 run of 2026-07-31 (an activity, a brick and
/// two meals). The writes were fine — each flow had already seen its own
/// success confirmation, and `plan_detail` / "Meal logged!" rendered — but the
/// timeline they came back to was not showing today. `meal_log_build` passed in
/// the run before that only because nothing had moved the date yet; once
/// `activities_crud` started completing its create flow (it runs first,
/// alphabetically), the drift reached everything downstream.
///
/// So any flow asserting "my item is on the timeline" has to state that it
/// means *today's* timeline rather than inherit whatever the previous test
/// left behind.
///
/// Best-effort by design: `fuel_timeline.today_button` only renders when the
/// timeline is off today, so its absence is the success case, not an error.
/// If the timeline cannot be reached at all the caller's own assertion reports
/// that, which is a better error than one thrown from inside a helper.
Future<void> ensureTimelineOnToday(PatrolIntegrationTester $) async {
  const todayButton = ValueKey('fuel_timeline.today_button');
  const filterAll = ValueKey('fuel_timeline.filter_all');

  try {
    if ($(todayButton).exists) {
      await $(todayButton).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 600));
    }
    if ($(filterAll).exists) {
      await $(filterAll).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 400));
    }
  } on Exception catch (e) {
    debugPrint('[flow_launcher] could not reset the timeline day/filter: $e');
  }
}

/// Wait for [finder] to EXIST on the timeline, then bring it on screen.
///
/// Returns false if it never turned up, so callers can assert with their own
/// message rather than eat an exception from inside a helper.
///
/// Why not `waitUntilVisible`: that requires the widget to be *hit-testable*,
/// i.e. actually on screen. The Fuel Timeline is one long day-ordered list, and
/// the dev tester account accumulates rows — every Patrol run that fails leaves
/// its item behind, because cleanup is the last step and never runs. By
/// 2026-07-31 a single day held 13 activities plus meals and events, so a
/// newly created item sorted near the bottom was in the tree but far below the
/// fold, and `waitUntilVisible` could never succeed no matter how long it
/// polled. Confirmed against the dev database: the exact stamp from the failing
/// assertion (`Patrol Brick 1785537825702`, 18:45) was present and not deleted
/// while the test was timing out looking for it.
///
/// So: existence is the assertion, visibility is a separate step, and only the
/// callers that then tap or swipe the row need it.
///
/// Note for callers matching on a title: `TimelineNodeTile` renders names
/// UPPERCASED. Match on a case-invariant fragment (an epoch stamp) or
/// `toUpperCase()` the expected text — a mixed-case `find.text` silently never
/// matches.
Future<bool> waitForOnTimeline(
  PatrolIntegrationTester $,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  // Phase 1: wait for the async refetch. The row may not be in the tree yet.
  final polls = timeout.inMilliseconds ~/ 300;
  var found = false;
  for (var i = 0; i < polls; i++) {
    if (finder.evaluate().isNotEmpty) {
      found = true;
      break;
    }
    // Fixed pumps, never settles: the timeline holds a refresh spinner.
    await $.pump(const Duration(milliseconds: 300));
  }

  // Phase 2: scroll, because the timeline is a LAZY list.
  //
  // `evaluate()` only ever sees mounted widgets, and the day list builds its
  // children on demand. Newly created items sort by time, so they routinely
  // land below the fold on an account with a full day — and no amount of
  // polling mounts them. Every "my item never appeared on the timeline"
  // failure in this suite traced back to that, while the row sat correctly in
  // Supabase the whole time.
  //
  // Drag the VERTICAL scrollable specifically: the first Scrollable on this
  // screen is the horizontal filter strip, and dragging that scrolls sideways
  // forever.
  if (!found) {
    final vertical = _verticalScrollable();
    if (vertical != null) {
      for (var i = 0; i < 15 && !found; i++) {
        await $.tester.drag(vertical, const Offset(0, -400));
        await $.pump(const Duration(milliseconds: 300));
        found = finder.evaluate().isNotEmpty;
      }
    }
  }
  if (!found) return false;

  // Best-effort reveal — the assertion above already passed, and a row that
  // cannot be scrolled to still counts as present.
  try {
    await $.tester.ensureVisible(finder.first);
    await $.pump(const Duration(milliseconds: 400));
  } on Exception catch (e) {
    debugPrint('[flow_launcher] could not scroll the timeline row in: $e');
  }
  return true;
}

/// The first vertically-scrolling [Scrollable] on screen, or null.
///
/// `find.byType(Scrollable).first` is the wrong thing to drag on the Fuel
/// Timeline: the filter strip is horizontal and comes first in the tree, so
/// dragging it moves sideways and never reveals another row.
Finder? _verticalScrollable() {
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

/// Standard skip message for flows that could not authenticate.
String noAuthSkipMessage() =>
    'Could not reach the tabs shell: no existing session and no '
    '${TestConfig.isProd ? 'INTEGRATION_TEST_PROD_EMAIL/PASSWORD' : 'INTEGRATION_TEST_EMAIL/PASSWORD'} '
    'provided. Pass --dart-define-from-file=secrets/integration_test.env to run.';
