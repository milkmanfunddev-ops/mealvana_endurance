# 34: Backgrounded notification taps are collected on resume

**Status:** retest FAILED 2026-10-08 (ticket 50, wave 5): 32-008 passes; 22-001 fixed from a cold start, held after an in-session login → 50-001
**Labels:** fix, round:develop-2026-10, area:notifications
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** nothing. Not with 36 in the same agent (both touch nothing in common, but 36 is a settings ticket; keep areas apart).
**Next:** `/testing-wave develop-2026-10` (fix wave 4)
**Model:** opus

**What to build:** `NotificationService.consumeLegacyResumeTap()` (`lib/shared/services/notification_service.dart:876-904`) is defined and never called (Finding 22-001; `grep -rn consumeLegacyResumeTap lib` shows only the definition). iOS writes the two keys it reads: `AppDelegate.swift:183` writes `flutter.ios_un_response_payload` inside `userNotificationCenter(_:didReceive:withCompletionHandler:)` and `:267` writes `flutter.ios_legacy_resume_payload` inside the deprecated `application(_:didReceive: UILocalNotification)`. So a notification tapped while the app is backgrounded (not killed) is never routed, and the keys stay set until a cold start tapes them. Line numbers from code at `4e77cf43`.

1. **Call it on every foreground resume.** `_RootAppWidgetState` (`lib/shared/widgets/root_app_widget.dart:90-91`) is already a `WidgetsBindingObserver`; its resume branch (`:156-172`) tapes `app resumed`, calls `LaunchTrail.pullNative()`, and runs the two nudge coordinators. Add `await NotificationService.consumeLegacyResumeTap()` there, after `pullNative()` (so the tape has the native lines first) and before the nudges. The method is already consume-then-dispatch, UN key first, and already satisfies D9 (a read failure goes to `_r.fault(area: 'push')` and the tape).
2. **Routing when the handler is set.** `_dispatchNavigation` (`:854-865`) calls the navigation handler when one is set and parks the tap as pending otherwise; the root widget sets the handler at `:97` and replays a pending tap in a post-frame callback (`:114-123`). On resume the handler is set, so the tap routes at once. Nothing to change; confirm it in the test.
3. **No double handling.** The launch path (`initialize()`, `:366-386`) reads a different key (`ios_legacy_launch_payload`), so a tap that launched the app and a tap that resumed it never share a key. State it in a comment on the call site.

**Findings:** 22-001.

**Decisions:**
- The notification-testing skill named in the Finding's triage note does not exist on this branch (`IMPROVEMENTS.md` #101, closed 2026-10-07: read the notification code itself first). CLAUDE.md's D9 rule applies and is already met by the method.
- Resume only; no change to the launch path, to `AppDelegate.swift`, or to `LaunchTrail`.

**Touches:** lib/shared/widgets/root_app_widget.dart, test/shared/services/notification_resume_tap_test.dart (new). 2 files. No generated files.

**Overlaps:** none in wave 4 (36 touches settings files only; 37 touches integrations; 39 touches repositories).

No edge-function or schema change. Nothing to deploy.

**Fix notes (wave 4).**
- Found while fixing: the call alone would not have worked on a device. shared_preferences serves reads from a Dart cache filled at launch, and AppDelegate writes UserDefaults natively while the app is backgrounded, so `consumeLegacyResumeTap()` (and `LaunchTrail.pullNative()`, the same blind spot) read nothing. The resume path now calls `prefs.reload()` first. The test proves it: with the reload commented out, 4 of 5 cases fail.
- Shape: a top-level `collectResumeTaps(Report)` in `root_app_widget.dart` (reload, `pullNative()`, consume). The resume branch tapes `app resumed`, then awaits it in `_onResumed`, then runs the dev dialog and the two nudge coordinators. The nudges now run after the await rather than synchronously in the callback. The launch/resume key split is stated on the function.
- D9: a failed reload writes a tape line and `report.fault(area: 'push')` and carries on with the cache. A root unmounted during collection tapes a line plus a breadcrumb before skipping the nudges. A joined collection does the same.
- The test drives `collectResumeTaps` directly, not `RootAppWidget` through `handleAppLifecycleStateChanged`: pumping the root needs the router, startup, Wiredash and both nudge coordinators, and the resume branch adds only the `app resumed` line. The device retest covers the widget wiring.

**Runs twice at once / after a refresh.**
- Two resumes overlapping: the second call joins the running collection (one future, held in `_resumeCollection`), tapes `resume tap collection joined` and a breadcrumb, and does no reload of its own. Without that, one reload's store read could land before the other's `remove` reached the store and put a consumed key back in the cache, so the tap would route twice. A tap written after the running collection reloaded is collected on the next resume. Tested: two concurrent calls route once.
- Inside one collection, `getString` and the cache side of `remove` both run synchronously with no await between them, so even two direct `consumeLegacyResumeTap()` calls cannot both see the key.
- After a refresh (rebuilt root state, or provider invalidation): the join lock is module-level, not per-state, so a new state joins an old state's running collection. The consumed key is gone from cache and store, so a later resume routes nothing (tested). `reload()` replaces the whole cache with the store. A write elsewhere in the app that is in flight during that one platform call could read stale from the cache until it lands. The window is one channel round trip per resume; LaunchTrail rewrites its whole tape on every line, so it heals itself.

- [x] Seam test (`notification_resume_tap_test.dart`, beside `notification_permission_moment_test.dart`, which shows `NotificationService.debugReset()` and the resume pattern; `launch_trail_test.dart:21` shows seeding the native keys with `SharedPreferences.setMockInitialValues`): seed `ios_un_response_payload` with a real `activity:<id>` payload (the shape `notification_payload_parsing_test.dart` uses), set a navigation handler, pump `RootAppWidget` or call the resume branch through `tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed)` (pattern: `barcode_scanner_screen_test.dart:76-78`), and assert the handler received the activity id and type once, the key is gone from prefs, and the tape has the `(consumed)` line. A second resume with no key routes nothing. The legacy key is read when the UN key is absent.
- [x] `flutter analyze` clean on touched files.
- [ ] Retest on a simulator: a local notification tapped with the app backgrounded opens the activity (retest ticket in the next test wave; `xcrun simctl push` can deliver a payload to the dev app).

Next: /testing-wave develop-2026-10 (fix wave 4)
