# 77: Reconnect is read from the server's integrations row on every device; a dead Garmin token is an expected failure

**Status:** ready (round develop-2026-10, fix wave 8)
**Labels:** fix, round:develop-2026-10, area:integrations, area:sync
**Branch:** `develop-next` (fix-wave worktree)
**Source:** Findings 68-008, 69-010; TRIAGE.md rulings of 2026-10-09
**Blocked by:** 73 (shares `connect_training_controller.dart`, the Garmin mirror `_markGarminNeedsReauth`, and `sync_status_write_seam_test.dart`). Run 77 strictly after 73 merges, line numbers re-read, or 73 + 77 as one agent with 73 first. No file shared with 74, 75 or 76.
**Next:** `/testing-wave develop-2026-10` (fix wave 8)
**Model:** opus

Line numbers are from code at `84615131`. Tickets 63/64 (wave 6) are in that base; 73 will move the Garmin mirror.

## Findings

- **68-008 · Garmin is active and requires_reauth on the server, but neither the Timeline notice nor the Connected Apps card says so (retest of 49-004).** Run 68's simulator (device B) signed in with Garmin `success`. At 23:38:08Z run 69's simulator (device A, same account) moved the server row to `requires_reauth` / `reauth_required`. Device B's Timeline showed no notice before or after a relaunch (23:44:39Z) and a pull-to-refresh. Its Connected Apps card still showed Sync Now and no "Sign in again" line. Evidence: `runs/68/db-integrations-start.txt`, `runs/68/db-integrations-check12.txt`, `runs/68/12n-timeline-garmin-requires-reauth.png`, `runs/68/12o-relaunch-timeline.png`, `runs/68/12p-after-pull-refresh.png`, `runs/68/12q-connected-apps-garmin.png`.
- **69-010 · Opening Connected Apps fires a Garmin backfill that, on an expired token, reports `error_reported` degraded to Sentry.** Run 69's first open of Connected Apps in the session (23:38:05Z, nothing tapped) fired `triggerGarminBackfill()` from the controller's build. garmin-backfill answered 409 at 23:38:08Z; the console printed `error_reported {severity: degraded, area: garmin, exception_type: FunctionException, sentry_event_id: ef8d56c9…}`. The row moved to `requires_reauth` that second; the card then showed Reconnect, and the Timeline notice showed on this device. Evidence: `runs/69/console-redacted.log` (18:38:08 local), `runs/69/edge-23-16-to-23-44.txt`, `runs/69/db-integrations-after-tp-reconnect.txt`, `runs/69/k01-connected-apps.png`.

## Fix

**Ruling (2026-10-09):**
- The reconnect notice and the card's Reconnect state come from the `integrations` row (`last_sync_status = requires_reauth`, active), on every device and every launch, until the row changes. This replaces ticket 138's "shown once per move" (Lee 2026-09-26).
- The automatic backfill treats a dead token as an `expected_failure` (area `garmin`, reason `token_expired`) with one breadcrumb, not a degraded report.
- It does not re-fire on every open while the row says `requires_reauth`.
- D9: the skip is recorded (breadcrumb + LaunchTrail line).

**Why device B never knew (from code):**
- The notice's state is set only by `ReconnectNoticeController.onSyncStatusWritten` (`lib/features/integrations/presentation/providers/reconnect_notice_controller.dart:32-48`). That hook fires only from `IntegrationsRepository.updateSyncStatus` (`lib/features/integrations/data/integrations_repository.dart:458`), the write a device makes when its own sync finds the dead token. Garmin is push-only, so device B never ran such a sync.
- A row that changes on the server reaches Drift through `syncFromRemote` (`:55-127`), which fires no hook.
- That pull runs from `ensureIntegrationsSynced` (`lib/features/integrations/application/integration_sync_coordinator.dart:66-71, :108-122`) through `SyncCoordinator.ensureSynced`, which skips a repository synced within the last hour (`lib/shared/services/sync/sync_coordinator.dart:580-599`). The stamp is persisted, so a relaunch inside the hour pulls nothing. Run 68 relaunched six minutes after the server write.
- Even after a pull, "shown once" is remembered in SharedPreferences (`reconnect_notice_shown.<provider>`, `:27, :35-40`), so the notice would not return on the next launch.
- The Connected Apps card reads the local Drift row at the controller's build (`connect_training_controller.dart:486-490`, `Integration.needsReconnect`, `lib/features/integrations/domain/integration.dart:95`), so it is as stale as Drift.

**Why the backfill re-fires and reports (from code):**
- `build` fires `triggerGarminBackfill()` when Garmin is active, not yet fired in this controller and the 6 h cooldown has run out (`connect_training_controller.dart:452-467`, cooldown `:288`, `_shouldTriggerGarminBackfill` `:505-…`). Nothing looks at `needsReconnect`.
- The 409 lands in the catch as `_report.degraded(…, area: 'garmin')` (`:1286-1299`), the `error_reported` the run saw. The non-throwing branch (`:1236-1247`) marks the row and reports nothing.

1. **Drift watch.** `IntegrationsRepository.watchIntegrationsForUser(String userId) → Stream<List<IntegrationModel>>`, a Drift `.watch()` beside `getIntegrationsForUser` (`:292-298`), mapped with `_toModel`.
2. **The rows needing reconnect, as one provider.** In `reconnect_notice_controller.dart`, `@Riverpod(keepAlive: true) Stream<Set<String>> integrationsNeedingReconnect(Ref ref, String userId)`: the providers whose row `needsReconnect` (active and `requires_reauth`), from item 1's stream. Every write path then reaches it: this device's `updateSyncStatus`, a pull's `syncFromRemote`, a reconnect clearing the status (64), a disconnect deactivating the row.
3. **One pull per launch.** In the same file, `@Riverpod(keepAlive: true) Future<void> integrationRowsLaunchPull(Ref ref, String userId)` calls `ref.read(syncCoordinatorProvider.notifier).forceSyncRepository('integrations', userId, repository: ref.read(integrationsRepositoryProvider))` (`sync_coordinator.dart:921-…`; it uploads dirty rows first, then pulls, bypassing the hour). keepAlive makes it once per process per user, so once per launch. Recording is already in place: offline is a structured `info` (`:939-945`), a failure a `fault` (`:995-1004`).
4. **The notice, derived.** `ReconnectNoticeController.build()`:
   - `userId = ref.watch(userIdProvider).value` (`lib/shared/providers/user_id_provider.dart`); null → null.
   - `ref.watch(integrationRowsLaunchPullProvider(userId))` (starts the pull; the value is ignored).
   - `needing = ref.watch(integrationsNeedingReconnectProvider(userId)).value ?? {}`.
   - Returns the first of `garmin, training_peaks, final_surge, vdot, runna` in `needing` and not dismissed this session.
   - `dismiss()` adds the shown provider to an in-memory `_dismissed` set and recomputes. It comes back on the next launch (the ruling's "every launch"), and the X or Reconnect hides it for this launch only.
   - Clear `_dismissed` when the user id changes.
   - Delete `onSyncStatusWritten`, the prefs key and its class comment (`:10-24, :27, :32-48`). Stale `reconnect_notice_shown.*` keys left in prefs are harmless and never read again.
   - `ReconnectNotice` (`lib/features/integrations/presentation/widgets/reconnect_notice.dart`) and its mount on the Timeline (`macro_dashboard_screen.dart:1576`) do not change.
5. **The hook goes.** The Drift watch covers every write, so remove `onSyncStatusWritten`: the constructor parameter and field (`integrations_repository.dart:26, :36-40`), the call (`:458`) and its doc line (`:418`), and the wiring in `integrationsRepository` (`lib/features/integrations/presentation/providers/integrations_providers.dart:169-173`). Ticket 64's inactive-row skip (`:427-438`) is unchanged; it simply has no hook to skip.
6. **The card follows the row while the screen is open.** In `ConnectTrainingController.build`, once `_currentUserId` is resolved and is not a temp id (`connect_training_controller.dart:385-408`), `ref.listen(integrationsNeedingReconnectProvider(_currentUserId!), (_, next) { … })`. On data, patch the current state with `copyWith(garminNeedsReauth: set.contains('garmin'), trainingPeaksNeedsReauth: …, finalSurgeNeedsReauth: …, vdotNeedsReauth: …)`. Skip when `!ref.mounted` or there is no current value. The initial values at `:486-490` stay, read from Drift at build.
7. **No automatic backfill while the row says requires_reauth (69-010, D9).** At `:452-467` add `&& !(garminIntegration?.needsReconnect ?? false)` to the condition. When Garmin is active and the row needs reconnect, record the skip once per launch (a `static bool` on the controller, since the controller is auto-dispose and rebuilds on every open):
   - `_report.breadcrumb('Garmin auto backfill skipped: integration requires_reauth', category: 'garmin.expected', data: {'reason': 'token_expired'})`;
   - `LaunchTrail.add('garmin auto backfill skipped: requires_reauth')` (`lib/shared/services/launch_trail.dart:120`; the prod tape reader is in Connected Apps, `connected_apps_screen.dart:1616-…`).
   Leave the cooldown stamp alone, so the first open after a reconnect fires at once. Sync Now (`integration_sync_helpers.dart:296-…`) still calls `triggerGarminBackfill` by hand; the card offers Reconnect, not Sync Now, while the row needs it (`connected_apps_screen.dart:441-461`).
8. **A dead token is expected, not degraded.** One private `_onGarminTokenExpired()` for both the catch branch (`:1282-1299`) and the non-throwing branch (`:1241-1244`):
   - `await _report.noteExpected('garmin-backfill 409: Garmin token expired, athlete must reconnect Garmin', area: 'garmin', reason: 'token_expired', analytics: ref.read(appExternalDepsProvider).analytics)` (`lib/shared/services/report/report.dart:842-…`; `garmin` is not a promoted area, so the note is one breadcrumb plus one `expected_failure {area: garmin, reason: token_expired}`, with no Sentry event and no `error_reported`);
   - then `_markGarminNeedsReauth()` (`:1342-1368`).
   The 502/429 and unexpected branches (`:1300-1328`) are unchanged.

## Touches

lib/features/integrations/data/integrations_repository.dart
lib/features/integrations/presentation/providers/reconnect_notice_controller.dart
lib/features/integrations/presentation/providers/reconnect_notice_controller.g.dart (generated)
lib/features/integrations/presentation/providers/integrations_providers.dart
lib/features/integrations/presentation/providers/connect_training_controller.dart
test/features/integrations/reauth_from_server_row_seam_test.dart (new)
test/features/integrations/reconnect_notice_test.dart
test/features/integrations/garmin_backfill_failure_report_test.dart
test/features/integrations/sync_status_write_seam_test.dart
test/features/settings/connected_apps_garmin_reauth_test.dart

10 files. `ReconnectNoticeController` gets two new `@Riverpod` providers, so run the unfiltered codegen (`dart run build_runner build --delete-conflicting-outputs`) and check `git status` for deleted files (#58). `connect_training_controller.g.dart` and `integrations_providers.g.dart` should not change (no signature change); if they do, they join the commit.

## Tests

- [ ] **Seam, device B** (`reauth_from_server_row_seam_test.dart`, on the harness of `disconnect_clears_reconnect_seam_test.dart`: the real `IntegrationsRepository` on in-memory Drift and the real postgrest builder against `FakePostgrest`, `test/helpers/fakes/fake_postgrest.dart`). Local Drift holds the Garmin row `is_active true, last_sync_status success`, and the integrations last-sync stamp is 6 minutes old (inside the hour, as run 68). The server row as PostgREST sends it: `last_sync_status: 'requires_reauth'`, `last_sync_error: 'reauth_required'`, `is_active: true`, `updated_at: '2026-10-08T23:38:08.123+00:00'`. Build a fresh `ProviderContainer` (a launch):
  - `reconnectNoticeControllerProvider` reads `garmin` once the pull lands;
  - `connectTrainingControllerProvider`'s `garminNeedsReauth` is true;
  - the fake `functions` client saw no `garmin-backfill` call;
  - the Report fake has the skip breadcrumb once, and `LaunchTrail.text` holds the line;
  - opening the controller a second time adds no second breadcrumb.
  Red before the fix.
- [ ] Same file: the server row turns `success` (a reconnect on device A), then a second launch: the notice is null and the card's flag false. Dismiss, then a new container: the notice is back. The row turns `success` while the controller is alive: item 6's listener clears `garminNeedsReauth` with no rebuild.
- [ ] `reconnect_notice_test.dart`, rewritten for the derived controller. Drop "shown once" and "remembered across a refresh". Keep "renders nothing until a connection needs signing in again" and "names the app, offers Reconnect"; Reconnect now hides it for the launch only. Add: two providers needing reconnect show one at a time, the second after the first is dismissed; an ordinary `error` shows nothing; an inactive `requires_reauth` row shows nothing.
- [ ] `garmin_backfill_failure_report_test.dart:123-136`: a 409 `garmin_reauth_required` now records no `degraded` and no `fault`, one `note` in area `garmin` carrying `expected_failure: token_expired`, and one `expected_failure` analytics event `{area: garmin, reason: token_expired}`; the local row is `requires_reauth`. The unexpected-500 case (`:138-…`) still faults.
- [ ] `sync_status_write_seam_test.dart:409-…`: "fires the hook" becomes "writes and pushes" (the hook is gone); the inactive-row cases are unchanged.
- [ ] `connected_apps_garmin_reauth_test.dart`: add the card switching from Sync Now to Reconnect when the Drift row changes under an open screen.
- [ ] #116: `grep -rl` under `test/` for `onSyncStatusWritten`, `ReconnectNoticeController`, `reconnectNoticeControllerProvider`, `ReconnectNotice`, `IntegrationsRepository(`, `watchIntegrationsForUser`, `integrationsNeedingReconnect`, `integrationRowsLaunchPull`, `triggerGarminBackfill`, `_markGarminNeedsReauth`, `garminNeedsReauth`, `connectTrainingControllerProvider`, `ConnectTrainingController`, `forceSyncRepository`; run every file named. Known today, beyond the four above: `connected_apps_reconnect_test.dart`, `test/smoke_tests/settings_smoke_test.dart`, `connect_identity_seam_test.dart`, `integration_sync_coordinator_test.dart`, `disconnect_clears_reconnect_seam_test.dart`, `reconnect_unhides_seam_test.dart`, `connect_training_upload_guard_test.dart`, `test/features/onboarding/connect_training_failure_test.dart`, `onboarding_overflow_test.dart`, `onboarding_integration_profile_provider_test.dart`. Fakes of `SyncCoordinator` or `IntegrationsRepository` that list exact calls need the launch pull (#76).
- [ ] `test/shared/source_guard/`: no new reporting helper. `noteExpected` and `breadcrumb` are existing Report calls; the skip is recorded, not silent (#117).
- [ ] Async paths, written in the fix notes:
  - (i) the launch pull and a sync writing `requires_reauth` at once: both end in Drift, the watch emits twice, the derived state is the same;
  - (ii) the pull lands while Connected Apps is mid-OAuth: item 6 patches only the four flags, the connect's own success write follows and the next emission clears Garmin's flag;
  - (iii) sign-out and sign-in as another user: `userIdProvider` changes, the notice rebuilds on the new id, `_dismissed` resets, the pull runs once for the new id;
  - (iv) offline launch: the pull is skipped with `info`, the notice reads whatever Drift holds, and the next launch pulls again;
  - (v) two Connected Apps opens in a row: the static flag records the skip once.
  No retry or timeout added (#82 does not apply).
- [ ] `flutter analyze` clean on the touched files.

## Deploy

None (client only; garmin-backfill's 409 shape is unchanged). Before the retest the lead puts the dev test account's Garmin row into the state the checks need (below), on dev only.

## Retest

Next test wave, Connected Apps / meal-logging retest tickets, two simulators on one account:
- **68-008:** the server row is Garmin `is_active true, requires_reauth / reauth_required`, and simulator B's Drift row reads `success` (sign B in while the row is `success`, then the lead sets it on dev). Relaunch B within the hour: the Timeline shows "Garmin needs you to sign in again to keep syncing." with Reconnect and X, and Connected Apps' Garmin card shows Reconnect. X, relaunch: the notice is back. The lead sets the row to `success`, B relaunches: no notice, the card shows Sync Now.
- **69-010:** the row says `requires_reauth`. Open Connected Apps twice. The dev edge logs show no garmin-backfill request from the app, the console shows no `error_reported` for area garmin, and Settings' Launch trail holds `garmin auto backfill skipped: requires_reauth` once. Then the lead sets the row to `success` with the token still dead and clears the 6 h cooldown (sign out and in, or a fresh install). Open Connected Apps: garmin-backfill answers 409, and the console shows `expected_failure {area: garmin, reason: token_expired}`, no `error_reported`, and no new dev Sentry event for it.

## Questions for Lee
