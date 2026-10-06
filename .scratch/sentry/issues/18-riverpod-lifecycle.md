# 18: Riverpod lifecycle

**What to build:** Every `UnmountedRefException` (prod CP, D1, C9, BZ, CK, CB, CA and the dev set), `userIdProvider` disposed during loading (CN, DEV-6T), and provider modified while building (CM, CJ, C5, DEV-8C). Fix the top offenders by hand with `ref.mounted` checks after async gaps and move modifications out of build, and fix the pattern where a shared helper exists.

**Blocked by:** 10 Contract

**Status:** done except DEV-9W (its code lives only on `mealplanning`) and the Sentry resolves (lead, after merge)

- [x] Each listed issue has a named root cause and a fix or a reasoned reclassification
- [x] The `allEventsProvider` and `settingsControllerProvider` cases cannot recur: tests reproduce the dispose-during-await and pass (red on the old code, green on the new)
- [ ] All listed issues resolved in Sentry (lead resolves after merge, table below)

## Note (2026-10-06, from ticket 15's device run)

`athleteZonesProvider` threw `UnmountedRefException` on every open of the Settings screen in the
dev build (`ref.read(reportProvider)` after the first `await`, introduced by the wave-3 Report
migration in `athlete_zones_provider.dart`). Fixed in ticket 15 by reading `Report` before the
await; dev event `242566ca993c4b738eb033a1174200b5`. The same shape, a `ref.read` of
`reportProvider` after an async gap, is worth a sweep across the other migrated providers when
this ticket runs.

## Root cause

I pulled the latest event for every issue (raw JSON kept in the agent scratch folder, not the repo).
They fall into four groups.

### A. A disposed provider's own build used `ref` after an `await`

Riverpod 3.0.1 keeps listening to a fully disposed element's last future, so that `provider.future`
still resolves. That covers an auto-dispose provider that lost its last listener and a family member
whose argument changed. When that build reaches `ref.read`/`ref.watch` after its await, it throws
`UnmountedRefException`. The error goes to `providerDidFail`, and the Sentry observer filed it as a
Fault. No user saw anything, because Riverpod discards the result.

- **CP, DEV-9D** (`allEventsProvider`, 96 + 144 events): `ref.read(eventsServiceProvider)` came
  after `await ref.read(userIdProvider.future)`. The events screens often leave while the id is
  still loading.
- **D1** (`eventDetailProvider`): repository, coordinator and service reads came after the user-id
  await.
- **CK, DEV-93** (`settingsControllerProvider.build`): `ref.read(athleteZonesProvider(..).future)`
  ran after the profile lookups. Sign-out or account deletion disposes Settings meanwhile (the
  breadcrumbs show `paywall.sign_out_button` / `delete_account_button`).
- **CB, DEV-7T** (`macroDashboardDayProvider`): a chain of `await ref.watch(x.future)`, so every
  watch after the first one followed an await.
- **DEV-98** (`carbDashboardForDateProvider`): `ref.watch(carbLoadingRepositoryProvider)` came after
  the user-id await.
- **DEV-8J** (`mealLogsForDateProvider`): `ref.read(mealLogRepositoryProvider)` came after the user
  lookup, and the day changed meanwhile.
- **DEV-92** (`homeControllerProvider`): `build` awaited the connectivity check, then `_load` read
  `ref`.
- **DEV-96** (`vanaChatControllerProvider`): `build` reached the `_logger` getter (now `_report`, a
  `ref.read`) in its catch after the history await.
- **DEV-AE** (`athleteZonesProvider`): the ticket 15 case, already fixed in `d8a7c29d` (Report is
  read before the await). The event came from build 1.29.0+6, which predates that commit.
- **DEV-9W** (`subscriptionScreenControllerProvider`): same shape (`ref.watch` after awaits in
  `build`). The file exists only on `mealplanning` (`e10a0b49`), not on `sentry`, so it can't be
  fixed here.

### B. A notifier method used `state`/`ref` after its provider was disposed mid-call

A screen that calls `ref.read(x.notifier).foo()` without watching `x` leaves `x` with no listener,
so `x` can be disposed during `foo()`'s awaits. The next `state =` or `ref.read` throws, and the
error escapes to the caller, often after the real work had already succeeded.

- **C9, CA** (settings): `build` started a `Future.microtask` that called
  `updateCyclingPreferences` / `updateSwimmingPreferences` (the TP FTP/CSS prefill). The microtask
  outlived the build and read `state` on a disposed controller (CA). `_saveProfile` then assigned
  `state` after a completed save (C9: 36 events from one user in a loop).
- **BZ** (settings `deleteAccount`): the sign-out inside the method disposes the controller, then
  `state = await AsyncValue.guard(...)` threw.
- **DEV-8S** (`onboardingSessionControllerProvider`): Welcome's "Build My Plan" called the notifier
  bare. Already fixed in `e293d27b` (2026-09-21, `_publish` checks `ref.mounted`); the last event
  was on 1.26.0.
- **DEV-A0** (`postOnboardingAuthControllerProvider.signInWithGoogle`): `state =` after the OAuth
  round trip, and the method's own return value was read from `state`.
- **DEV-A3** (`carbNudgeCoordinatorProvider`, keepAlive): `ref.read` after
  `await allEventsProvider.future`. A keepAlive notifier only goes stale when its container is
  disposed, and this event came in the same second (2026-10-01T21:07:26) as DEV-6T, a Patrol
  teardown (group D).

### C. A provider was modified while the widget tree was building

- **CM, CJ** (personal info step) and **C5, DEV-8C** (body composition step): `initState` subscribes
  to the keepAlive `onboardingIntegrationProfileProvider` with `listenManual(fireImmediately: true)`.
  When the athlete connected a platform on an earlier step, the profile had already resolved, so the
  listener fired inside `initState` and wrote the autofill into the onboarding draft
  (`OnboardingController._updateDraft` → `state =`). Riverpod's debug check rejects that write. It
  is a debug-only assertion: C5 says `production` but is a debug run of the prod flavour, and
  CM/CJ came from Patrol runs.

### D. `userIdProvider` "disposed during loading state" (CN, DEV-6T, DEV-6D)

This was not an auto-dispose race. `userIdProvider` is `keepAlive: true`, so only disposing the
container can dispose it. All three latest events have this stack:
`ProviderScopeState.dispose → ProviderContainer.dispose → ElementWithFuture.dispose` under
`LiveTestWidgetsFlutterBinding.handleDrawFrame`. That is a Patrol test tearing the app down.

In CN the breadcrumbs show "User signed out - invalidating user providers" just before. Once signed
out, `userIdProvider` rebuilds, throws "No user profile found" and goes into retry, which means it
is loading with no value. The teardown then hands every `.future` awaiter (`allEventsProvider`,
`activitiesControllerProvider`, `macroDashboardDayProvider`) Riverpod's `StateError`, and the
observer filed each one as a Fault. DEV-6D has the same teardown, with `mealLogsForDateProvider`'s
stream ending while loading.

## Fix

**Observer net** (`lib/shared/services/sentry/sentry_provider_observer.dart`):
- **Group D:** a "disposed during loading state" failure that arrives after the container itself
  is disposed becomes a `riverpod.duplicate` breadcrumb ("container disposed"), not an event.
  `ProviderContainer.disposed` is Riverpod-internal, so the observer reads a probe provider and
  catches the `StateError`. That catch has a reasoned entry in the source-guard allow-list.
- **Group A:** an `UnmountedRefException` that names the failing provider itself is now Degraded,
  tagged `riverpod_lifecycle: disposed_mid_build`. It is still counted, it never alerts, and the
  fix is still a guard at the site.

**Shared helper:** `extension ReportRef on Ref { Report get report }` in
`lib/shared/services/report/report.dart`. It returns `ref.read(reportProvider)` while mounted and
`SentryReport.global` (the same instance in the app) after disposal. Before this, a
`Report get _report => ref.read(reportProvider)` getter called in a `catch` after an await threw
and replaced the error it was reporting. 39 `_report` getters now read `ref.report`, including the
8 that had hand-rolled the same ternary.

**Hand fixes** (each sits next to a comment naming its Sentry id):
- `events_controller.dart`:
  - `allEvents`, `eventDetail` and `nextUpcomingEvent` read every dependency before the first await.
  - `allEvents` skips its query once disposed.
  - The controller's background sync and `forceRefresh` are guarded.
- `settings_controller.dart`:
  - The build's TP prefill runs only while mounted, and the microtask re-checks before each call.
  - The three `state = await AsyncValue.guard` sites now save into `result` and assign it only
    while mounted.
  - `_saveProfile` reads `dailyMacroServiceProvider` up front, so the Q-016 cache invalidation
    still runs after a disposal.
  - `signOut`, `_uploadDirtyBeforeLogout` and `deleteAccount` read everything before their awaits.
    `deleteAccount` falls back to the state captured before sign-out.
- `macro_dashboard_providers.dart`: all watches start before the first await, and the catches use a
  `report` read up front.
- `carb_dashboard_providers.dart`: the repository watch comes before the await. The meal-log watch
  stays behind a mounted check, since only loading days need it.
- `meal_log_providers.dart`: the four stream/future providers read their repository first.
  `consumedTotalsForDate` starts both watches together. `mealPhotoSignedUrl` reads Report first.
- `home_service.dart`: `build` and `refresh` guard before `_load`, and `_load` reads both
  dependencies first.
- `vana_chat_controller.dart`:
  - `build` returns early if it was disposed during the history load.
  - The pantry-photo path reads the AI service and the action client first.
  - `_foldPlan`, `_foldMemory`, `refreshDraft` and `loadOpener` guard after their awaits.
- `post_onboarding_auth_controller.dart`: each of the 7 methods reads Report, analytics and the auth
  service first, saves into `result`, sets state only while mounted, and returns from `result`.
- `carb_nudge_coordinator.dart`: dependencies are read before the first await.
- `personal_info_screen.dart` and `body_composition_screen.dart`: a listener that fires during
  `initState` applies the autofill in a post-frame callback. Later fires still apply inline.

**Tests** (each was red on the old code and green on the new; I checked by swapping the old file
back in):
- `test/features/events/events_providers_dispose_during_await_test.dart`:
  - `allEvents` disposed while awaiting the user id: no failure, and no query runs.
  - `allEvents` invalidated mid-await: the stale build is discarded and the fresh one is served
    (this one also passes on the old code; it documents the discard).
  - `eventDetail` disposed while awaiting the user id: no failure.
- `test/features/settings/settings_controller_dispose_during_await_test.dart`:
  - `build` disposed during the profile load: no throw, and the zone lookup is skipped.
  - A save whose controller is disposed mid-write still reaches the repository, and the call
    completes without a throw. This runs through the real notifier.
- `test/features/onboarding/onboarding_autofill_in_init_state_test.dart`: an already-resolved
  profile on both steps autofills without "Tried to modify a provider while the widget tree was
  building".
- `test/shared/services/sentry/sentry_provider_observer_test.dart`, two new cases:
  - Container teardown gives a breadcrumb and no event.
  - Own-disposal gives a Degraded event tagged `disposed_mid_build`.

## Sweep

- **Scanner:** `sweep.py` (agent scratch folder). It strips comments and strings, finds every
  `async` body, and lists each `ref.*` / `state` / ref-backed getter use that follows an `await`
  with no `mounted` check in between. It skips keepAlive providers and `_ref` service holders.
- **Before:** 1,101 candidates (630 distinct awaits) in 71 files.
- **Work:** I did the listed-issue files by hand. The rest went to four parallel sweep agents with
  one written rule set: read up front first; guard only the UI-state write and never a persistence
  write; return values come from locals.
- **Result: 78 files changed under `lib/`.** That count includes the hand fixes and the 39
  converted `_report` getters.
- **After:** 439 lines in 27 files, none of them live:
  - `oauth_service` (126): its `build` calls `ref.keepAlive()`.
  - `onboarding_controller` (88): its `build` holds a keepAlive link and never closes it.
  - `app_startup_service`, `auth_service`, `nutrition_plan_service`, `onboarding_service`,
    `llm_response_parser`, `food_preference_resolver`, `food_data_transformation_service`,
    `content_service`, `night_before_nudge_coordinator`: each sits in a plain, never-disposed
    `Provider`.
  - `_report.*` lines: the getter is now mounted-safe.
  - `lib/features/_archived/`: skipped.
  - The rest are scanner false positives. Examples: an await in an `if` branch that returns, a
    getter evaluated inside a guard closure, and `state` used as a US-state parameter.
- **Regressions the sweep caused, and fixed:**
  - `activity_detail_controller`: `late` service fields broke test stubs that override `build`.
    They are now cached getters with a `ref` fallback.
  - `checklist_controller`, `formula_editor_controller`, `app_startup_provider`: some reads moved
    out of their `try` or ahead of the branch that needs them. They are back inside the `try` and
    still before the first await.
  - `connect_training_controller`: the macro-window repository read is best effort again. If it
    fails it is reported, and the disconnect goes on.

## Verification

- `dart analyze lib` reports no errors. The two `coach_reports_controller.dart:250` warnings were
  already there.
- `flutter test test/shared/source_guard` passes (20).
- The 4 new or changed test files pass (19 tests).
- I went beyond the brief here and ran the existing test files that subclass or import a changed
  controller: 124 files, 1,208 tests, all green after the regression fixes above. This was not the
  full suite; the lead still runs that after merge.

## Owed

- **DEV-9W:** move the watches ahead of the awaits in
  `lib/features/subscription/application/subscription_screen_controller.dart` `build` on
  `mealplanning`. Until then the observer files it as Degraded once this merges.
- **Write-path seam tests:** only settings, events, onboarding and the observer have
  dispose-mid-call tests. The other swept controllers rely on analyze plus their existing tests.
  Still to cover: post-onboarding auth, vana chat, home, the carb-loading controllers and the
  coach controllers.
- **Device check:** none was run. I could not check on a device that Sign out / Delete account
  from Settings, and a quick back-swipe off the events list, no longer produce events.
- **Patrol noise:** Patrol runs (`LiveTestWidgetsFlutterBinding`) report to the dev and prod Sentry
  projects. The observer now drops the teardown case, but other test-run errors still land. Worth
  turning Sentry off (or tagging the events) in Patrol builds.
- **Not fixed:** `formula_editor_controller` / `personal_formulas_controller` builds pass `ref` into
  `hydrateComponentConflictMetadata` after awaits, and there is no cheap value to return. The
  observer net covers them.

## Sentry resolution

| Issue | Action | Comment for Sentry |
|---|---|---|
| MEALVANA-ENDURANCE-CP | resolve | allEvents reads its service before awaiting the user id and skips the query once disposed (ticket 18) |
| MEALVANA-ENDURANCE-D1 | resolve | eventDetail reads every dependency before its first await (ticket 18) |
| MEALVANA-ENDURANCE-C9 | resolve | settings save assigns state only while mounted; the save itself completes (ticket 18) |
| MEALVANA-ENDURANCE-BZ | resolve | deleteAccount no longer touches state/ref after the sign-out disposes the controller (ticket 18) |
| MEALVANA-ENDURANCE-CK | resolve | settings build reads athleteZones only while mounted (ticket 18) |
| MEALVANA-ENDURANCE-CB | resolve | macroDashboardDay starts every watch before its first await (ticket 18) |
| MEALVANA-ENDURANCE-CA | resolve | the TP prefill microtask re-checks ref.mounted before each update (ticket 18) |
| MEALVANA-ENDURANCE-CN | resolve | Patrol teardown: a failure after the container is disposed is now a breadcrumb, not an event (ticket 18) |
| MEALVANA-ENDURANCE-CM | resolve | personal info autofill fired in initState now lands post-frame (ticket 18) |
| MEALVANA-ENDURANCE-CJ | resolve | same fix as CM (ticket 18) |
| MEALVANA-ENDURANCE-C5 | resolve | body composition weight autofill fired in initState now lands post-frame (ticket 18) |
| MEALVANA-ENDURANCE-DEV-9D | resolve | same root cause and fix as CP (ticket 18) |
| MEALVANA-ENDURANCE-DEV-93 | resolve | same root cause and fix as CK (ticket 18) |
| MEALVANA-ENDURANCE-DEV-7T | resolve | same root cause and fix as CB (ticket 18) |
| MEALVANA-ENDURANCE-DEV-8S | resolve | fixed in e293d27b (2026-09-21): onboarding session publishes state only while mounted |
| MEALVANA-ENDURANCE-DEV-8J | resolve | mealLogsForDate reads its repository before the user lookup (ticket 18) |
| MEALVANA-ENDURANCE-DEV-92 | resolve | HomeController build/refresh guard before _load, which reads ref up front (ticket 18) |
| MEALVANA-ENDURANCE-DEV-96 | resolve | VanaChatController build bails when disposed during history load; Report getter is mounted-safe (ticket 18) |
| MEALVANA-ENDURANCE-DEV-98 | resolve | carbDashboardForDate watches its repository before the await (ticket 18) |
| MEALVANA-ENDURANCE-DEV-9W | leave-open: code only on mealplanning | subscriptionScreenController build watches after awaits; fix on mealplanning (ticket 18 owed) |
| MEALVANA-ENDURANCE-DEV-A0 | resolve | post-onboarding auth methods set state only while mounted and return from the guard result (ticket 18) |
| MEALVANA-ENDURANCE-DEV-A3 | resolve | carb nudge sweep reads deps before its first await; the event was a Patrol container teardown (ticket 18) |
| MEALVANA-ENDURANCE-DEV-AE | resolve | fixed in d8a7c29d (ticket 15): athleteZones reads Report before its await |
| MEALVANA-ENDURANCE-DEV-6T | resolve | same as CN: Patrol teardown is a breadcrumb now (ticket 18) |
| MEALVANA-ENDURANCE-DEV-6D | resolve | same as CN (mealLogsForDate stream during teardown) (ticket 18) |
| MEALVANA-ENDURANCE-DEV-8C | resolve | same root cause and fix as C5 (ticket 18) |
