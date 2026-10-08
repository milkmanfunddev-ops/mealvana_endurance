# 59: A notification tap held after an in-session login is replayed

**Status:** done 2026-10-09: 50-001 (held tap dropped on login, never replayed) and the cold-start half passed in ticket 69 (wave 7)
**Labels:** fix, round:develop-2026-10, area:notifications
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** 56. 56 keeps `appStartupProvider`'s snapshot live after an in-session login (`AppStartup.refreshSession`). This ticket's guard reads that snapshot, and its replay fires on that snapshot's change. Run after 56 merges and re-read the line numbers then.
**Next:** `/testing-wave develop-2026-10` (fix wave 6)
**Model:** opus

**Notification rule (CLAUDE.md).** This ticket touches what deep-links from a notification tap. The `notification-testing` skill CLAUDE.md names (`.claude/skills/notification-testing/`) and the push-stack fact sheet `ops/docs/messaging-relay-and-testing.md` are **not on this machine**: `.claude/skills/` has device-sweep, drive-device, shorebird-patch and testing-wave, and `../ops/docs/` has no such file (IMPROVEMENTS #101). Before writing anything, read these in full: `lib/shared/services/notification_service.dart` (the handler `:99, :301-305`, `_dispatchNavigation` `:854-865`, `consumeLegacyResumeTap` `:876-904`), `lib/shared/services/launch_trail.dart` (`add` `:120-126`: the tape, persisted, printed as `[LAUNCH]`, **not** a Sentry breadcrumb), `lib/shared/widgets/root_app_widget.dart` (all of it: `collectResumeTaps` `:84-153`, the hold/replay `:258-406`), and `ios/Runner/AppDelegate.swift` (it writes a backgrounded tap to `flutter.ios_un_response_payload` `:183` or the legacy `flutter.ios_legacy_resume_payload` `:267`).

**What to build:** Lee, 2026-10-08 (TRIAGE): "notification rule: routability reads the live auth/onboarding state, a held tap is replayed when it becomes routable; unit test on the guard; retest on a simulator and ticket 51." Line numbers are from code at `f8dd9171`.

**What happened (50-001), from the tape and the code.** The app was cleared, launched signed out, and the athlete logged in in-session. A backgrounded tap was collected on resume (`collectResumeTaps` → `consumeLegacyResumeTap`, which removes the key, `notification_service.dart:890-891`, `(consumed)`), then dispatched to `_handleNotificationNavigation` (`root_app_widget.dart:286`). `_isRoutableNow()` (`:277-284`) reads `appStartupProvider` and needs `d.user != null`. The snapshot resolved at launch with no session, so `user` was null and the tap was HELD (`:289-293`) in `_deferredTap` (`:262`). **Why no REPLAY:** the only release is `ref.listen(appStartupProvider, …)` → `_flushDeferredTap` (`:404-406`, `:391-397`), and `appStartupProvider` never changed. An in-session login invalidates only `userIdProvider` (`auth_listener_service.dart:242-259`); nothing re-resolves or rewrites the startup snapshot (56's diagnosis). So the tap sat in widget memory until the process died, and every backgrounded tap until the next cold start was held the same way. The control run (signed-in cold start) routed, because its snapshot had a user.

1. **The guard reads the live state the router uses.** The router resolves `/` with `AppRouter.rootRedirect` on `appStartupProvider`'s data (`app_router.dart:137-190, :269-280`), and every other protected route with the live `supabase.auth.currentSession` (`:255-261`). After 56 that data follows auth. Replace `_isRoutableNow()` with a pure, `@visibleForTesting` function in `root_app_widget.dart`, e.g. `bool notificationTapRoutable(AsyncValue<AppStartupData> startup, {required bool hasSession, required bool pendingSignupOpen, required bool needsConsentPrompt})`. It returns true iff there is a live session and startup has data and `AppRouter.rootRedirect(data, pendingSignupOpen: …, needsConsentPrompt: …) == '/main'`. That one rule covers what `:279-281` checked (force-upgrade, resync, a user) and adds the onboarding state (`hasCompletedOnboarding`, `isLoggedOut`), an open pending signup, and the consent backfill. A tap is never routed into the app mid-onboarding or mid-consent. The `_deepLinkTo` seed (`router.go('/')`, `:340`) then cannot be redirected out from under the push: the guard and the router answer from the same function. The widget passes `ref.read(appStartupProvider)`, `ref.read(appExternalDepsProvider).supabaseClient.auth.currentSession != null`, `ref.read(pendingSignupStoreProvider).isOpen` and `ref.read(analyticsConsentProvider).needsPrompt`, the same reads the router makes (`:272-279`).
2. **A held tap is replayed when it becomes routable.** Keep `ref.listen(appStartupProvider, …)` (`:404-406`). After 56 it fires on every snapshot refresh (sign-in, sign-out, onboarding saved). Add `ref.listen(analyticsConsentProvider, …)` with the same `_flushDeferredTap`, since a consent decision moves the guard's answer and writes no snapshot. `_flushDeferredTap` keeps its shape (check, trail, clear, route).
3. **Every held, replayed or dropped tap is written down (D9).** `LaunchTrail` is a device tape, not PROD-readable on its own. Each line below also writes `report.breadcrumb(<same text>, category: 'push', data: {'id':…, 'type':…})`. `push` is a promoted note area (`report.dart:41-46`), so this is a breadcrumb, not a note.
   - HELD (`:291`): keep the line and add the reason the guard failed: `no session`, `startup loading`, or the `rootRedirect` answer (`/welcome`, `/force-upgrade`, `/privacy-consent`, `?resume=verify`). Return it from a sibling of the guard (`notificationTapHoldReason(...)`) so the tape says why.
   - REPLAY (`:394`): unchanged text, plus the breadcrumb.
   - DROPPED, which today is silent in three places:
     - (a) a second tap arrives while one is held, and `:292` overwrites it. Write `DROPPED id=<old> (replaced by id=<new>)`. Keep the newest, which is the athlete's latest intent.
     - (b) the early return `if (!mounted || activityId.isEmpty) return;` (`:287`). Write `DROPPED id=$activityId (root unmounted)` or `(empty id)`.
     - (c) `dispose` (`:251-256`) with a tap still held. Write `DROPPED id=… (root disposed while held)`.
   - The breadcrumb goes through `ref.read(reportProvider)`. In `dispose`, read it in a way Riverpod allows (capture the report in `initState`, as `OAuthService` does at `oauth_service.dart:64-70`).
4. **Testability.** Move the hold/replay/drop bookkeeping into a small class in the same file (e.g. `HeldNotificationTap` with `hold`, `takeIfRoutable`, `dropOnDispose`, each writing its trail line and breadcrumb through an injected `Report`). The widget wires it, and the unit tests drive it without pumping `RootAppWidget`.

**Findings:** 50-001. Related follow-up 50-016 step 1 (a tap held while signed out, then a login in the same session) is retested with this ticket in retest ticket 69, item 2.

**Decisions:**
- Routable means "the router would answer `/main` right now, with a live session". It is one function shared with the router, not a second list of conditions that can drift (today's `:279-281` already had: it ignored onboarding).
- The newest held tap wins; the replaced one is written down.
- No change to `NotificationService`, the plugin or AppDelegate: the tap is collected and dispatched correctly (the tape shows `consumed` and `dispatch … handlerSet=true`); only the root widget's guard and release were wrong.

**Concurrency and refresh (every async path added).**
- Replay racing a new tap: `_flushDeferredTap` clears `_deferredTap` before routing (`:395`), so a tap dispatched during the replay is evaluated on its own and is not replayed twice.
- Two snapshot refreshes in a row (56's sign-in then onboarding-saved): the first that makes the guard true replays, and the second finds nothing held.
- A refresh to "signed out" with a tap held: the guard stays false and the tap stays held (`HELD` reason `no session`); a later login replays it (Questions for Lee 1).
- A resume and a launch tap at once: unchanged. `collectResumeTaps` joins a running collection (`:112-125`), and launch and resume keys never overlap (`:92-96`).
- `_goPrefilled`'s await (`:348-381`): the guard was true when it started; it routes after the lookup as today.

**Questions for Lee.**
1. A tap held while signed out (50-016 step 1) is replayed after any login on that device. If a different athlete logs in, the reminder's activity is not theirs and its detail page will not load. Replay only when the account that logs in owns the activity (one local lookup), or drop a tap held across a login?
2. Should a held tap expire (for example, not replayed more than 30 minutes after the tap), or is "the next time it becomes routable in this process" right?

**Touches:** lib/shared/widgets/root_app_widget.dart, test/shared/widgets/notification_tap_guard_test.dart (new: the guard and the held-tap class), test/shared/services/notification_resume_tap_test.dart (stays green; extend if it reads `_isRoutableNow`'s behaviour), test/shared/services/launch_trail_test.dart (stays green). Read, not changed: notification_service.dart, launch_trail.dart, AppDelegate.swift, app_router.dart (`rootRedirect` is called, not edited), app_startup_provider.dart (56). About 3 files. No generated files.

**Overlaps:** 56 (blocker; it owns `app_router.dart` and `app_startup_provider.dart` in this wave). 55 and 57 share no file. Tickets 34 (done) and 22 own the resume collection this reads; their tests must stay green.

- [x] Unit (`notification_tap_guard_test.dart`, on `notificationTapRoutable`). Feed `AppStartupData` shaped as the launch path builds it after a signed-out launch (`user: null, hasCompletedOnboarding: false`). It is not routable with `hasSession: true`; that is 50-001's state before 56. The same data refreshed after a login (a `UserProfile` from the download mapping with `onboarding_completed true`, `isLoggedOut false`) with `hasSession: true` is routable. With `hasSession: false` it is not routable. `hasCompletedOnboarding: false` is not routable (reason `/welcome`). `forceUpgradeRequired` → `/force-upgrade`, `resyncRequired`, an open pending signup, a pending consent prompt, and loading/error startup are not routable. Each reason is the string the HELD line will carry.
- [x] Unit (`HeldNotificationTap` with a `RecordingReport`). Hold, then a not-routable check: still held, no route. Then routable: one REPLAY, one route call, held cleared. A second hold replaces the first with one DROPPED line and one `push` breadcrumb. Dispose with a held tap writes DROPPED. The empty-id and unmounted paths write DROPPED. Every line appears in `LaunchTrail` (read the tape the way `launch_trail_test.dart` does) and as a breadcrumb.
- [x] Seam through the real providers: a `ProviderContainer` with the real `AppStartup` (56's `refreshSession`) resolved signed out. Hold a tap, give the mocked auth a session and seed the onboarded profile, call `refreshSession(reason: 'signed_in')`. The listener releases the tap once, and the route call targets `destinationForIntent('reminder', id)`.
- [x] #116: `grep -rl` under `test/` for `_isRoutableNow`, `_flushDeferredTap`, `_handleNotificationNavigation`, `RootAppWidget`, `collectResumeTaps`, `setNavigationHandler`, `rootRedirect`, and run every file named.
- [x] #117: the new breadcrumbs are `report.` calls; no new helper. If the held-tap class adds a catch, it reports. Run `test/shared/source_guard/`.
- [x] #118: no notifier state is written by this ticket.
- [x] `flutter analyze` clean on touched files.
- [ ] Retest on a simulator in test wave 7, retest ticket 69 (the held tap). Clear the app, launch signed out, log in in-session, allow notifications, background. `xcrun simctl push <udid> com.milkman.mealvanaendurance.dev` with `"payload":"reminder:<activityId>"` for a planned activity of that account, then tap the banner. The tape shows `consumed` → `dispatch … handlerSet=true` → `routing id=…` → `deepLinkTo /plan…`, the activity detail opens, and Back goes to the Timeline. Then, signed out, deliver and tap a reminder (`HELD … (no session)`), log in, and see `REPLAY id=…` then the detail (50-016 step 1, retest ticket 69 item 2).
- [ ] Real push on Lee's phone in ticket 51: the same backgrounded tap after a fresh login routes (a release-signed build, since the simulator cannot stand in for a real APNs tap, `launch_trail.dart:6-13`).

**Rulings (Lee, 2026-10-08, after drafting).**
- A tap held across a login is DROPPED, never replayed: a tap routes only when the app is routable at the moment it is consumed; a held tap is dropped with a LaunchTrail line and a `push` breadcrumb when the session changes (sign-in or sign-out). No ownership check, no expiry needed. The 'replayed' half of this ticket's title is superseded: the fix is that routability reads the live state, so a tap after an in-session login routes at once instead of being held.


Next: /testing-wave develop-2026-10 (fix wave 6)

## Fix notes (wave 6, pass B, 2026-10-08)

**Read in full before writing** (the `notification-testing` skill and `ops/docs/messaging-relay-and-testing.md` are not on this machine, IMPROVEMENTS #101/#123): `lib/shared/services/notification_service.dart`, `lib/shared/services/launch_trail.dart`, `lib/shared/widgets/root_app_widget.dart`, `ios/Runner/AppDelegate.swift`, plus `lib/features/app_startup/application/app_startup_provider.dart` (`refreshSession`, `refreshStartupSnapshot`, the sequence rule) and `AppRouter.rootRedirect` / `welcomeRedirect` in `lib/shared/core/app_router.dart`. None of those was changed.

**What changed** (`lib/shared/widgets/root_app_widget.dart` only, per the rulings):
- `notificationTapHoldReason(startup, hasSession:, pendingSignupOpen:, needsConsentPrompt:)` (pure, `@visibleForTesting`) returns null when a tap can route, else the reason: `no session`, `startup loading`, `startup failed`, or `rootRedirect`'s answer when it is not `/main` (`/welcome`, `/force-upgrade`, `/privacy-consent`, `/auth/post-onboarding?resume=verify`). `notificationTapRoutable` is its boolean twin. The two closures have the same shape `rootRedirect` takes, so the guard reads lazily, the way the router does.
- `notificationTapGate(read)` makes the router's reads: `appStartupProvider`, the live `supabaseClient.auth.currentSession`, `pendingSignupStoreProvider.isOpen`, `analyticsConsentProvider.needsPrompt`. It also returns the session's user id.
- `HeldNotificationTap` (injected `Report`): `hold`, `dropReplacedBy`, `takeIfRoutable(gate)`, `dropOnDispose`, `dropIncoming`. Every line goes to `LaunchTrail` and, with the same text, to `report.breadcrumb(..., category: 'push', data: {'id', 'type'})`. No catch was added.
- The widget captures `reportProvider` in `initState` (so `dispose` can write without reading a provider). It replaced `_deferredTap` / `_isRoutableNow` / `_flushDeferredTap` with the class. The empty-id and unmounted early returns now write `DROPPED`. A tap that routes at once drops any tap still held (`replaced by`). Listeners: `appStartupProvider` (kept) and `analyticsConsentProvider` (new), both calling `_releaseHeldTap`.

**Held reasons: what replays and what drops.** A held tap remembers the session user id it was held under. On every re-check, a different session user id (null to id = `signed in`, id to null = `signed out`, id to another id = `account changed`) DROPS it: `DROPPED id=… type=… (session changed: …)`. Same session user: it REPLAYS once the reason clears.
- Replayed (same session): `startup loading` (cold-start tap with a restored session, released when startup resolves), `startup failed` (if startup is rebuilt and resolves), `/privacy-consent` (released by the consent listener on a decision), `/welcome` with a session (e.g. a guest who finishes onboarding: `onboarding_saved` refresh), `/auth/post-onboarding?resume=verify` (the store is not observable, so it releases on the next snapshot or consent change after the signup closes, if the uid did not change). Each has a unit test (`REPLAY: held for "…"`).
- Dropped: `no session` (the only way out is a sign-in, which is a session change: 50-001's case), and any reason when the session user changes. `/force-upgrade` never clears in-process, so that tap stays held until a session change, a newer tap or dispose drops it. Unit tests: `DROP: held with no session, then a sign-in`, `DROP: … then a sign-out`, `DROP: … another account signs in`.
- Also dropped: a held tap replaced by a newer one (held or routed), the root disposed while holding, an empty id, root unmounted.

**Async paths: twice at once, after a refresh.**
- Two snapshot writes in a row (56's `signed_in`, then `onboarding_saved`): the first re-check drops (session changed) or replays and clears the slot, and the second finds nothing held (`isHeld` short-circuit). Seam test: the cold-start replay, then an `onboarding_saved` refresh, routes once.
- Replay racing a new tap: `takeIfRoutable` clears the slot before the widget routes, so a tap dispatched during the replay is evaluated on its own and is not replayed twice. A tap arriving while one is held replaces it, and the replaced one is written down.
- A `refreshSession` that skips (startup has no data yet, superseded, the session user changed mid-refresh) writes no snapshot, so no listener fires. The held tap is then re-checked on the next snapshot or consent change, or replaced by the next tap. It is never replayed into a different session, because the drop compares the live session user at that moment, not the snapshot.
- `_goPrefilled`'s await is unchanged: the guard was true when it started, and it routes after the lookup.
- A sign-out with no snapshot write is not seen until the next change. Listening to the auth stream directly would need `lib/shared/services/auth/**` (forbidden this pass) or a second auth subscription in the widget; not done.

**Out of scope, noted.** `LaunchTrail.isNotificationEvidence` does not count `DROPPED ` lines (launch_trail.dart was not mine to edit). A tape whose only evidence is a dropped empty-id tap would not open the dev dialog; a dropped held tap always has its `HELD` line, which does count.

**Tests run** (no full suite):
- `test/shared/widgets/notification_tap_guard_test.dart` (new): 25 passed. Guard: 8. `HeldNotificationTap`: 14, five of them the replay reasons. Seam through the real `AppStartup` + `refreshSession`: 3. Those cover a tap held signed out being dropped on the login and the next tap routing at once to `destinationForIntent('reminder', id)`; a cold-start tap replayed once when startup resolves; a tap held on consent being dropped on sign-out.
- #116 `grep -rl` for `_isRoutableNow`, `_flushDeferredTap`, `_handleNotificationNavigation`, `_deferredTap`, `RootAppWidget`, `collectResumeTaps`, `setNavigationHandler`, `rootRedirect`, `root_app_widget` under `test/` named: pending_signup_resume_seam, startup_snapshot_refresh, notification_resume_tap, launch_trail, launch_trail_dialog_once (33 passed together); home_shell_gestures + g27_carb_nudge (31 passed); widget_test_harness (helper).
- #117 `test/shared/source_guard/`: 20 passed.
- `flutter analyze lib/shared/widgets/root_app_widget.dart test/shared/widgets/notification_tap_guard_test.dart`: no issues.
- #118: no notifier state is written; the widget only reads providers.
- No codegen (no annotated file touched).

**Not met here:** the simulator retest (test wave 7, retest ticket 69) and the real push on Lee's phone (ticket 51). Under the ruling, 69 item 2 should now expect `HELD … (no session)` then `DROPPED … (session changed: signed in)` after the login, not `REPLAY`.

**Questions for Lee.**
1. A tap held for a reason that clears without a sign-in or sign-out is replayed in the same session. Examples: an anonymous guest who is not onboarded (`/welcome`) and then finishes onboarding, or a pending signup upgraded in place (uid kept). Is that right, or should only `startup loading` and `/privacy-consent` replay and every other held tap be dropped?

**Rulings (Lee, 2026-10-08, at the wave-6 close).**
- Q1 (Lee, 2026-10-08, at the wave-6 close): as built; same-session holds replay when the reason clears, any session change drops.
