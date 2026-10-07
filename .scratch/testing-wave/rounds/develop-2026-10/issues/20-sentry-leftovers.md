# 20: Sentry leftovers, every open issue with a cause and an action

**Status:** done 2026-10-06: code in `03b23ce4` + `ce1a1527`; all 48 Sentry actions applied (dev project unresolved = DEV-7D only; prod = BP, B7, C2). Retests: tickets 13/14 (A2, 9B), 16 (99), 18 (probes).
**Labels:** fix, round:develop-2026-10, area:sentry
**Branch:** `develop-next`
**Source:** `.scratch/develop-roundup/spec.md` § 4
**Blocked by:** none.
**Model:** opus

Pulled 2026-10-06 ~20:00 UTC with the API, paginated: **49 dev** (`mealvana-endurance-dev`) and **3 prod**
(`mealvana-endurance`) unresolved. Every row's cause comes from the issue's latest event (stack, message,
tags, release, environment, breadcrumbs) and, where it needed one, the dev database (read-only). Prior triage
comments (wave 5, 2026-10-06) are folded into the cause or action.

Actions: **resolve** (cause fixed on develop-next or gone) · **resolve-as-degraded** (future events arrive as
warnings by design) · **leave-open: reason** · **resolve: not on this branch** (the spec's "resolve as 'not on this branch'": plain `resolved` with that comment, no sha; the fix lands in the mealplanning round via a line in
`.scratch/branch-split/HANDOFF.md`). Resolutions use `resolvedInNextRelease` with the commit sha, per the
wave-5 rule.

## Counts

| action | dev | prod | total |
|---|---|---|---|
| resolve | 13 | 0 | 13 |
| resolve-as-degraded | 17 | 0 | 17 |
| leave-open | 1 | 3 | 4 |
| resolve: not on this branch | 18 | 0 | 18 |
| **total** | **49** | **3** | **52** |

## Code changes (all with a test run red first, then green)

| change | file | test | red → green |
|---|---|---|---|
| flutter_web_auth_2 "User canceled" → `cancelled_sign_in` | `lib/shared/services/report/expected_failures.dart` | `test/shared/services/report/expected_failures_test.dart` (group "integration OAuth") | 2 red (classified `null`) → green |
| Test Store simulated failure → new `simulated_purchase_failure` | same | same (group "RevenueCat Test Store") | 1 red → green |
| `userIdProvider` signed-out throw → new `no_profile` | same | `test/shared/providers/user_id_provider_signed_out_test.dart` (real provider) | red → green |
| `users` upload session guard; `UploadResult.deferred`; coordinator treats a deferral as no failure; integrations guard uses the same shape | `lib/features/auth/data/user_repository.dart`, `lib/shared/data/syncable_repository.dart`, `lib/shared/services/sync/sync_coordinator.dart`, `lib/features/integrations/data/integrations_repository.dart` | `test/features/auth/user_profile_upload_session_seam_test.dart` (real repo + PostgREST vs a fake server with the dev `users` policy), `test/new_sync/edge_cases/deferred_upload_test.dart` | 2 + 1 red → green; `integrations_rls_seam_test` still green |
| re-pick invalidates every carb surface at once | `lib/features/carb_loading/presentation/providers/carb_loading_controller.dart` | `test/features/carb_loading/dev99_repick_stale_day_test.dart` (real controller, sync held in flight) | red → green; all 136 carb-loading tests green |
| dead-man check skips with no session | `lib/features/integrations/application/raw_retention_dead_man_check.dart` | `test/features/integrations/raw_retention_dead_man_session_seam_test.dart` (real PostgREST vs the dev audit-table policy) | 2 red → green; DI-27 test still green |

## DEV-4 breakdown (48 retained events of 307; retention is 30 days)

| sub-cause | events | release | last | status on develop-next |
|---|---|---|---|---|
| 22P02 `invalid input syntax for type uuid: "qa-seed-int-fs"` (integrations upload) | 26 | 1.26.0+1 | 09-14 | QA-seed artifact: the QA repo seeded a local integrations row whose id is not a uuid. Review-queue entry for the QA repo (already in `.scratch/ssot/review-queue.md`, "Sentry DEV-4 / DEV-82", written by sentry ticket 15) owed (lead), never a commit there. |
| 42703 `column user_entitlements.entitlement does not exist` | 12 | 1.29.0+6 | 10-06 | Branch skew. The querying code (`features/subscription/data/user_entitlements_repository.dart`) is on `sentry` and `origin/develop` only; develop-next has zero `user_entitlements` reads in `lib/`. The 10-06 events are a `sentry` build (same 1.29.0+6 version). Dev DB table has mealplanning's columns (user_id, period_type, active_until, event_at, will_renew). |
| PGRST204 `Could not find the 'duration_source' column of 'activities'` | 5 | 1.29.0+6 | 10-01 | Fixed: dev DB has `activities.duration_source text` (read 10-06). |
| 23503 `integrations_user_id_fkey` | 4 | 1.26.0+1/+138 | 09-14 | Fixed by ticket 16's parent-row guard (`c6fa42a9`, on develop-next). |
| 42501 RLS on `users` | 1 | 1.29.0+6 | 10-01 | Same incident as DEV-A2, fixed here. |

## The table

| short id | group id | title | events | group (spec § 4) | root cause | action | code change (file) | test |
|---|---|---|---|---|---|---|---|---|
| DEV-4 | 7116969527 | PostgrestException (catch-all) | 307 | DEV-4 | Five sub-causes, see breakdown above | resolve, with the breakdown in the comment | none (sub-causes fixed, gone, or QA artifact) | `integrations_rls_seam_test.dart`, `user_profile_upload_session_seam_test.dart` |
| DEV-47 | 7542460177 | SentryHttpClientError 502 | 44 | never ticketed | `garmin-backfill` answered 502 (Garmin upstream) to `ConnectTrainingController.triggerGarminBackfill`; 1.26.0+1, last 09-14 | resolve-as-degraded | none: `sentry_event_filter.dart` already classifies 502 from `/functions/v1/garmin-backfill` as `upstream_unavailable` (ticket 19) | `sentry_event_filter_test.dart` "garmin-backfill 502 is upstream_unavailable" |
| DEV-4B | 7546041602 | ClientException: Connection reset by peer (`/auth/v1/token`) | 83 | never ticketed | Socket reset during GoTrue's auto-refresh; `connectivity: none` breadcrumb just before; 1.27.1+4, last 09-27 | resolve-as-degraded | none: allow-list `Connection reset by peer` → `connection_reset` | `expected_failures_test.dart` "AuthRetryableFetchException wrapping a reset by peer" |
| DEV-4W | 7555624298 | ClientException: Connection reset by peer (`/rest/v1/activities`) | 10 | never ticketed | Same reset on an activities GET (a 15 min hung GET precedes it); 1.26.0+1, last 09-20 | resolve-as-degraded | none: same needle | same, plus `sentry_event_filter_test.dart` |
| DEV-5G | 7593683591 | RenderFlex overflowed by 20550 px (bottom) | 39 | carried | 4 retained events, all mealplanning builds (1.27.0+3, 1.27.1+4): onboarding 20550 px with the keyboard up, vana-browse 37 px, two unnamed. No widget in any event; no Report-era event | resolve: not on this branch: wave-5 ruling, mealplanning-only code; revisit once events carry `flutter_error_details` | none | none |
| DEV-5H | 7593683714 | RenderFlex overflowed by 7.0 px (bottom) | 29 | carried | vana-browse rail cards at a fixed 132 px (5/5 events `vana-browse`, 1.27.1+4) | resolve: not on this branch: fixed by mealplanning `885db994` | none | none |
| DEV-60 | 7625825781 | Local database reset: schema_integrity_validation_failed | 10 | never ticketed | Legacy message-form reset warning from a local build (1.26.0+138, Flutter 3.47.2 user-branch), 09-14. Validation failed and the designed reset ran | resolve: superseded by the typed `DatabaseReset` group (DEV-A5) | none | none |
| DEV-61 | 7625825800 | Local database reset: startup_database_initialization_exception | 10 | never ticketed | Same device and minute as DEV-60: the startup catch's second reset | resolve: superseded by DEV-A7 | none | none |
| DEV-6P | 7651789897 | SentryHttpClientError 504 | 4 | never ticketed | `GET /rest/v1/users` 504 (gateway timeout), 1.26.0+1, 09-13 | resolve-as-degraded | none: filter classifies 504 on `/rest/v1` as `gateway_timeout` (ticket 19) | `sentry_event_filter_test.dart` "a 504 from PostgREST or GoTrue is gateway_timeout" |
| DEV-6W | 7657769648 | PlatformException(CANCELED, User canceled login) | 4 | never ticketed | Athlete closed TrainingPeaks' OAuth sheet (`TrainingPeaksOAuthService.authenticate` → `_connectProvider` → `integrationFailure` → `fault`). The needles matched only Google/Apple wording, so this stayed a Fault | resolve-as-degraded | `expected_failures.dart`: needle `PlatformException(CANCELED, User canceled` → `cancelled_sign_in` | `expected_failures_test.dart` "iOS / Android "User canceled login" is cancelled_sign_in" |
| DEV-6Y | 7659246406 | StateError: Upload failed for activities: Uploaded 1/5 | 34 | never ticketed | 1.26.0+1, 09-10: after offline token-refresh retries, 4 activity upserts answered 409 Conflict (unique or FK constraint). 1.26.0 logged the per-row PostgREST code to the console only, so the constraint is unnamed | resolve: on develop-next each failing row reports its own Fault with its PostgREST code and the users-FK case is Degraded and skipped; a recurrence names its cause in a sibling group | none | none (behaviour pre-existing on develop-next) |
| DEV-70 | 7659317347 | PlatformException(CANCELED, User canceled login) | 5 | never ticketed | Same as DEV-6W, FinalSurge sheet (1.26.0+138) | resolve-as-degraded | same needle | same test |
| DEV-7D | 7667174122 | WatchdogTermination | 13 | carried | Local `flutter run` / Xcode installs (+1/+5) on Lee's iPhone 14 Plus, stopped by the IDE; last 1.28.0+5, 10-01 | leave-open: wave-5 ruling (ticket 21), needs Cocoa watchdog V2, not reachable from sentry_flutter 9.30.1 | none | none |
| DEV-7K | 7706719135 | Slow operation: deferred.revenuecat | 7 | never ticketed | Old slow-op warning (every threshold breach was an event), 1.26.0+1, 09-15 | resolve: ticket 11 made slow steps span measurements; only a step over `PerformanceTelemetry.slowCeiling` (10 s) raises a warning | none | `performance_telemetry_test.dart` (existing) |
| DEV-7V | 7717429785 | Slow operation: startup.local_user_lookup | 1 | never ticketed | Same, 1.25.0+1 | resolve: same | none | same |
| DEV-7W | 7717554751 | RenderFlex overflowed by 8.6 px (right) | 3 | carried | iPhone SE, home (`main`) at cold start, 1.25.0+1 only, last 09-07; no widget named; dashboard recomposed since | resolve (stale): no event in 30 days, none Report-era; a recurrence regresses the group | none | none |
| DEV-7X | 7717981499 | UnmountedRefException: mealCatalogControllerProvider | 1 | never ticketed | `MealCatalogController._localRecents` read after dispose (meal planning) | resolve: not on this branch | none | none |
| DEV-7Y | 7717981507 | UnmountedRefException: vanaSettingsControllerProvider | 1 | never ticketed | `VanaSettingsController._repo` read after dispose (Vana) | resolve: not on this branch | none | none |
| DEV-7Z | 7720478457 | KrogerException: session_changed | 1 | never ticketed | `KrogerController._assertScope` on a refresh-token churn (Kroger) | resolve: not on this branch | none | none |
| DEV-81 | 7726388997 | Looking up a deactivated widget's ancestor is unsafe | 5 | carried | `VanaCompanionHost._onRoute` reads `ref` from a deactivated element during a Router restore | resolve: not on this branch: activation guard owed on mealplanning | none | none |
| DEV-82 | 7727546104 | Upload failed for integrations: 22P02 "qa-seed-int-fs" | 13 | never ticketed | QA-seed artifact: a locally seeded integrations row with a non-uuid id; the server column is uuid. Same source as DEV-4's largest sub-cause | resolve: review-queue entry for the QA repo owed (lead) | none | none |
| DEV-83 | 7728581424 | SentryHttpClientError 504 | 2 | never ticketed | `POST /auth/v1/token` 504 during GoTrue auto-refresh (breadcrumb: "Gateway Timeout" after 6.2 s, next refresh OK) | resolve-as-degraded | none: filter, `/auth/v1` 504 → `gateway_timeout` | same as DEV-6P |
| DEV-84 | 7730477628 | PlatformException(CANCELED, User canceled login) | 1 | never ticketed | Same as DEV-6W, TrainingPeaks from Settings | resolve-as-degraded | same needle | same test |
| DEV-85 | 7732214022 | PlatformException(CANCELED, User canceled login) | 1 | never ticketed | Same, Garmin sheet (`GarminOAuthService.authenticate`) | resolve-as-degraded | same needle | same test |
| DEV-86 | 7733619555 | TypeError: Null check operator used on a null value | 1 | never ticketed | Flutter framework, `RenderEditable.selectWord` (`editable.dart:2147`, `_lastTapDownPosition!`): an iOS long-press on an unfocused field whose RenderEditable never saw the tap-down. No app frame. Only witness: view `vana-chat`, 1.26.0+1 simulator | resolve: not on this branch: the Vana chat composer; a recurrence on a develop screen is an upstream Flutter issue | none | none |
| DEV-87 | 7734340685 | Slow operation: database.normalize_user_food_timestamps | 1 | never ticketed | Old slow-op form, 1.26.0+1 | resolve: same as DEV-7K | none | same |
| DEV-8A | 7735477334 | UnmountedRefException: vanaSettingsControllerProvider | 1 | never ticketed | `VanaSettingsController.build` `ref.onDispose` after dispose (Vana) | resolve: not on this branch | none | none |
| DEV-8B | 7735477337 | UnmountedRefException: mealCatalogControllerProvider | 1 | never ticketed | `MealCatalogController._loadLocalRails` after dispose (meal planning) | resolve: not on this branch | none | none |
| DEV-8D | 7735614149 | AccountAlreadyExistsException | 1 | never ticketed | Linking a Google account that belongs to another user (`OAuthService.linkGoogleAccount` from the post-onboarding auth screen); the screen routes on it | resolve-as-degraded | none: allow-list `AccountAlreadyExistsException` → `account_exists` (wave 5, on develop-next) | `expected_failures_test.dart` "an existing account is account_exists (DEV-8D)" |
| DEV-8G | 7736235832 | Exception: No user profile found. User must complete onboarding first. | 7 | branch-era | `userIdProvider` rebuilds after sign-out with no session and no cached profile and throws; the Riverpod net reported it as a Fault. It is the router's signal, not a failure | resolve-as-degraded | `expected_failures.dart`: needle → new `no_profile` | `user_id_provider_signed_out_test.dart` |
| DEV-8K | 7743309792 | ClientException: Connection reset by peer (`/functions/v1/kroger`) | 2 | never ticketed | Reset on a Kroger edge call (Kroger) | resolve: not on this branch (the reset needle downgrades it anyway) | none | none |
| DEV-8Y | 7747428683 | AI cost: account 37129f7e… $1.80 | 1 | by design | `ai-cost-alert` edge fn (dev): $1.80 over a $1.50 threshold | resolve: not on this branch: `ai-cost-alert` exists only on mealplanning | none | none |
| DEV-8Z | 7747428835 | AI cost: account 607f9dd5… $0.00 | 1 | by design | Same function, `threshold_usd: -1`: a forced test alert | resolve: not on this branch | none | none |
| DEV-99 | 7754528390 | Exception: Failed to retrieve updated carb loading day | 1 | branch-era | Trail: plan created (2 days), re-pick at 13:00:12 (`DELETE carb_loading_days id=in.(9a6c0a0f…)`), Edit Target saved at 13:00:25, no local row. `applyRepickProtocol` invalidated only itself and the range family; the summary's plan / days-for-plan families waited on the rebuild's background sync, so the summary offered the dropped day while that sync was on the network | resolve | `carb_loading_controller.dart`: `applyRepickProtocol` calls `_invalidateCarbSurfaces()` | `dev99_repick_stale_day_test.dart` |
| DEV-9B | 7754601678 | raw_retention_sweep_stale | 2 | by design | False alarm. Trail (10-01): "User signed out" 17:03:04.970, then the dead-man `GET raw_retention_audit` 17:03:05.459 with no session; the table's only read policy admits `authenticated`/`service_role`, PostgREST answers anon with `[]`, the check read that as "never swept". The dev sweep ran daily (`cron.job_run_details` succeeded 10-01…10-06; newest audit row 10-06 03:17 UTC). Cron monitor `raw-retention-sweep` (prod project, `17 3 * * *`, margin 30, max runtime 30): **zero check-ins ever, no environments**; first due 10-07 03:17 UTC | resolve | `raw_retention_dead_man_check.dart`: skip with a Note when there is no session, without spending the throttle | `raw_retention_dead_man_session_seam_test.dart` |
| DEV-9E | 7755252212 | TypeError: Null check (vana-browse) | 3 | carried | Vana chat `_scrollToBottom` reads `maxScrollExtent` before layout | resolve: not on this branch: `hasContentDimensions` guard owed on mealplanning | none | none |
| DEV-9F | 7755273263 | AssertionError: `entry.currentState == _RouteLifecycle.popping` | 1 | carried | Same event as DEV-9G | resolve: not on this branch | none | none |
| DEV-9G | 7755273291 | AssertionError: `!navigator._debugLocked` | 1 | carried | Paywall expiry redirect replaced the page stack while a pageless sheet was open | resolve: not on this branch: pop pageless routes before the redirect, on mealplanning | none | none |
| DEV-9H | 7755478280 | PlatformException(42, Purchase failure simulated successfully in Test Store.) | 5 | branch-era | A tester chose "fail" in the RevenueCat Test Store sheet (`readable_error_code: TEST_STORE_SIMULATED_PURCHASE_ERROR`), reported by `RevenueCatService.purchase` as "purchase failed (unexpected)". The event came from the mealplanning paywall, but develop-next's credits purchase has the same catch under a `test_` key | resolve-as-degraded | `expected_failures.dart`: needle → new `simulated_purchase_failure` | `expected_failures_test.dart` "a simulated purchase failure is simulated_purchase_failure (DEV-9H)" |
| DEV-9R | 7755672606 | VideoPlayerController used after being disposed | 1 | carried | Paywall clip seeks after dispose | resolve: not on this branch: adopt `DisposalSafeVideoPlayerController` on mealplanning | none | none |
| DEV-9W | 7755759797 | UnmountedRefException: subscriptionScreenControllerProvider | 1 | carried | `SubscriptionScreenController.build` watches after awaits | resolve: not on this branch: ticket-18 fix owed on mealplanning | none | none |
| DEV-A1 | 7756445545 | VanaServerException(400): meal not found: log:… | 1 | carried | Fabricated `log:` meal ids from Vana tools | resolve: not on this branch: fixed in mealplanning `82b3ce71` (tools.ts), resolve when that function is on dev | none | none |
| DEV-A2 | 7766398787 | Upload failed for users: 42501 RLS on "users" | 1 | branch-era | A sync for 4a74be96 marked the profile dirty; the athlete signed out 0.13 s later; the in-flight `users` upsert went out with no session. Policies are `id = auth.uid()` (dev DB). The coordinator then reported the failed upload as a Fault | resolve | `user_repository.dart` (session guard + promoted sync Note), `syncable_repository.dart` (`UploadResult.deferred`), `sync_coordinator.dart` (a deferral is not a failure: no Fault, no download, no cooldown, not stamped), `integrations_repository.dart` (same shape) | `user_profile_upload_session_seam_test.dart`, `deferred_upload_test.dart` |
| DEV-A5 | 7777313549 | DatabaseReset: schema_integrity_validation_failed | 1 | by design | Device ae6df305 carried mealplanning's v24 DB (mealplanning's v22 is `users.home_*`; its ladder never adds `activities.duration_source`) into a v22 `sentry` build. Validation found `duration_source` missing and the designed reset ran | resolve-as-degraded | none | none |
| DEV-A6 | 7777313625 | DriftRemoteException: DatabaseSchemaException (activities missing duration_source) | 1 | branch-era | Same incident: the activities date-range read was the first query to meet the exception validation throws after the reset. HANDOFF's Drift decision covers devices from develop's v21 and v22, not mealplanning's v24; prod devices never carry it | resolve: branch-crossing artifact; `clear-app.sh` keeps round simulators off it | none (ruling for Lee below) | none |
| DEV-A7 | 7777313641 | DatabaseReset: startup_database_initialization_exception | 1 | by design | Same incident: the startup catch reset again after the validation throw | resolve-as-degraded | none | none |
| DEV-A8 | 7777316021 | DashboardTargetsAnomaly: Dashboard shown without targets | 1 | by design | After the A5 reset the dashboard rendered while targets were computing (`reason: computing`) | resolve-as-degraded (anomaly events stay warnings, spec) | none | none |
| DEV-A9 | 7777316073 | DashboardTargetsAnomaly: transient resolved | 1 | by design | Same, resolved 1 s later | resolve-as-degraded | none | none |
| DEV-AB | 7777316129 | integration sync reported failure; cooldown armed | 8 | branch-era | Promoted sync Note (D9). Dev account 607f9dd5's TrainingPeaks token is dead ("TrainingPeaks token expired; event sync skipped"), so the cooldown arms on every launch. The account needs TP reconnected (wave-5 owed list) | resolve-as-degraded (by design, no code) | none | none |
| B7 (prod) | 7666917790 | WatchdogTermination | 4 | prod | Existing comment: heuristic false positive; 2 of 3 events within 15 min of a TestFlight beta-review submission; no memory warnings; MetricKit shows 0 watchdog/memory exits; needs Cocoa 9.5 watchdog V2, not reachable from sentry_flutter 9.30.1 (ticket 21) | leave-open: as commented | none | none |
| BP (prod) | 7687038795 | SIGSEGV: Segfault | 5 | prod | Existing comment: Play pre-launch x86_64 emulator ("OnePlus8Pro", SwiftShader + ndk_translation), PC in JIT memory, never on a real device; latest 1.29.0+148, 10-01 | leave-open: archive or inbound-filter (ticket 21) | none | none |
| C2 (prod) | 7729583049 | SIGBUS: BusError | 1 | prod | Existing comment: same pre-launch emulator, PC 0x0 under libndk_translation | leave-open: archive or inbound-filter (ticket 21) | none | none |

## Rulings and owed items for the lead

- **Regression risk on resolve-as-degraded.** The allow-list keeps each issue's grouping and lowers only
  the level, so a cancelled sheet after `resolvedInNextRelease` regresses DEV-6W et al. as a warning.
  Resolve them anyway (the spec's exit counts unresolved issues with the round's release), or archive the
  pure-noise ones (DEV-6W/70/84/85, 8D, 9H) "until escalating".
- **DEV-A6 (ruling for Lee):** one corrupted-schema incident produces three events: a reset (Degraded),
  a Fault from whichever repository reads first, and a second reset from the startup catch. Listing
  `DatabaseSchemaException` as expected would drop the duplicate Fault; not done here (no prod evidence).
- **Review-queue entry for the QA repo:** seeded integrations rows use a non-uuid id (`qa-seed-int-fs`),
  DEV-82 + 26 DEV-4 events. Not written by this ticket.
- **Cron monitor:** `raw-retention-sweep` has never received a check-in. Check it after 2026-10-07
  03:17 UTC + 30 min. The dev sweep is pg_cron calling `raw_retention_sweep_and_notify()`; whether that
  path reaches the edge function's `edgeCheckIn` was not verified.
- **Coordinator change touches integrations too:** ticket 16's deferral used to surface as a Fault
  `Upload failed for integrations: deferred: …` through the coordinator. It now stops quietly after the
  repository's promoted Note.
