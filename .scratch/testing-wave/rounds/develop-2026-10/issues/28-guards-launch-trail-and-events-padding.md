# 28: Guards batch: the dev launch-trail dialog, and Events padding

**Status:** ready (round develop-2026-10, fix)
**Labels:** fix, round:develop-2026-10, area:startup
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** 29 (the backport ticket runs first, alone, because its Touches cross every area).
**Next:** `/testing-wave develop-2026-10` (fix wave)
**Model:** opus

**What to build:** Lee's rulings of 2026-10-07 (TRIAGE 08-007, 01-011, 08-008), the guards batch. One agent.
Line numbers are from code at `f2e8576e`; re-read after 29 lands.

**Notification rule.** Item 1 changes a guard on the notification launch path. CLAUDE.md says anything that
touches notifications invokes the `notification-testing` skill first and reads
`ops/docs/messaging-relay-and-testing.md`. That skill is missing on this branch (IMPROVEMENTS #101). Read the
fact sheet if it exists, and read `lib/shared/services/notification_service.dart` and
`lib/shared/services/notification_intent_routes.dart` before touching the guard: every `LaunchTrail.add` there
is a line the guard reads.

1. **The launch-trail guard matches a real notification only (08-007).** `LaunchTrail.hasNotificationEvidence`
   (`launch_trail.dart:147-155`) is true when the tape contains `payload=`. Every launch writes
   `launchDetails didNotificationLaunchApp=false payload=null` (`notification_service.dart:158-162`), so the
   dev dialog opens on every launch and every resume. Change the guard to count only:
   - a `payload=` followed by a real value: not `null`, not empty (a regex such as `payload=(?!null\b)\S`).
     This keeps `onDidReceiveNotificationResponse payload=<id>` (`:523`), `legacy_launch payload=… (consumed)`
     (`:180`), `<key> payload=… (consumed)` (`:677`) and the native `ios_*_payload=<value>` lines;
   - `routing id=`, `HELD `, `REPLAY `, `navigated(` as today (`root_app_widget.dart:215`, `:219`, `:311`,
     `:318`);
   - `willpresent` only on a line added during this process. `ios_un_willpresent` is written by AppDelegate
     (`AppDelegate.swift:225`, `:237`) and never removed, so `LaunchTrail.begin()` (`:67-73`) re-tapes a stale
     value as `native ios_un_willpresent=…` on every later launch (from code, unverified on device). Match the
     `willpresent` lines that `pullNative()` adds when the value changed, not the ones `begin()` seeds. Check
     the other native keys the same way: a stale `ios_*_payload` value that is never cleared would trip the
     guard too (`ios_legacy_launch_payload` and both resume keys are removed when consumed; confirm in code).
   - Keep the doc comment's reason (the dialog broke every authenticating Patrol flow) and add one line on
     `payload=null`.

2. **The dialog shows once per process (01-011).** `_showTrailDialog` (`root_app_widget.dart:122-152`) skips only
   when `LaunchTrail.length` is unchanged. Each resume adds an `app resumed` line (`:158`), so every resume
   pushes another dialog on top of the last (three stacked on Welcome in the run). Replace `_trailShownAt` with
   a once-per-process flag (a static on `LaunchTrail`, e.g. `markDialogShown()` / `dialogShown`, so it
   survives a rebuilt root state) and return when it is set. The resume path (`:163-165`) and the launch path
   (`:105-109`) both go through it. Dev only, as today (`appConfigProvider.devModeEnabled`).

3. **Events' New Event clears the floating tab bar (08-008).** The Events list ends with
   `SizedBox(height: AppSpacing.xxxl)` (`events_list_screen.dart:220`; 40 px, `app_spacing.dart:17`). The
   glass tab bar floats 28 px above the screen bottom and is 60 px tall
   (`home_shell_chrome.dart:78`, `:90-91`, `:169-171`), so the button ends under it. The shell publishes the
   clearance every tab body must use: `HomeShellChrome.bottomChromeClearancePx`. The Timeline takes it as a
   `bottomInset` from `tabs_screen.dart:166-168` and adds one gap (`macro_dashboard_screen.dart:1508-1509`,
   `_dockGap` at `:754`). Do the same: `EventsListScreen({this.bottomInset = 0})`, `tabs_screen.dart:173`
   passes `HomeShellChrome.bottomChromeClearancePx`, and the list's last spacer becomes
   `AppSpacing.xxxl + bottomInset`. This is what mealplanning's `818578e7` did; if 29 already brought it,
   check it and add only the test. Call sites of `EventsListScreen(` at `f2e8576e`: `tabs_screen.dart:173` (the tab: passes the
   inset); `app_router.dart:578` (the `/events` route) and the two `upcoming_event_widget.dart` pushes
   (`features/calendar/…:26`, `features/events/…:27`) are full-screen routes with no floating bar, so they keep
   the default 0; `test/smoke_tests/events_meal_logging_smoke_test.dart:152` needs no change. Learn's hardcoded `SizedBox(height: 100)`
   (`education_screen.dart:141`) is out of scope.

**Findings:** 08-007, 01-011, 08-008.

**Decisions:** none on the page. Lee ruled in the terminal (TRIAGE 2026-10-07: 08-007, 01-011, 08-008).

**Touches:** lib/shared/services/launch_trail.dart, lib/shared/widgets/root_app_widget.dart,
lib/features/events/presentation/screens/events_list_screen.dart, lib/shared/widgets/tabs_screen.dart,
test/shared/services/launch_trail_test.dart (new),
test/features/events/events_list_new_event_clears_tab_bar_test.dart (new, or from 29).
No codegen.

**Overlaps:** 29 (backports cross every area; `events_list_screen.dart` and `tabs_screen.dart` if it brings
`818578e7`). 21 and 22 share no file. Tickets 23, 24, 26, 27 were not written when this was cut: the lead
checks `root_app_widget.dart` and `tabs_screen.dart` against them (the Jade and orphan archives may touch the
shell).

- [ ] Unit test on the guard (`launch_trail_test.dart`), fed the tape lines the app writes: the run's ordinary
      launch (`launchDetails didNotificationLaunchApp=false payload=null`, the `plugin.initialize()` lines,
      `app resumed`) is false; a seeded stale `native ios_un_willpresent=…` alone is false;
      `onDidReceiveNotificationResponse payload=act_123 …`, `legacy_launch payload=… (consumed)`,
      `routing id=…` and a fresh `willpresent` from `pullNative()` are each true.
- [ ] Widget test on the root (or the extracted dialog helper): two resumes with notification evidence show
      one dialog, not two.
- [ ] Widget test (`events_list_new_event_clears_tab_bar_test.dart`): with five events and the shell's inset,
      scrolled to the end, the New Event button's bottom edge sits above `bottomChromeClearancePx` from the
      screen bottom and a tap on it opens Create Event.
- [ ] `flutter analyze` clean on touched files.
- [ ] Retest on a simulator (ticket 32): no launch-trail dialog on a plain cold start or resume, and the
      Events tab's New Event can be scrolled clear and tapped.
