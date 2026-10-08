# Branch split handoff

Spec: `spec.md`. Research: `STRATEGY.md`. Written by the Phase A session, 2026-10-06.

## Status

**develop PUSHED 2026-10-08** (Lee's go in the terminal): `git push origin develop-pre-split sentry-original`, then
`git push --force-with-lease=develop:fb4a97e9 origin develop-next:develop` → origin/develop = `f2dc5951` (tip title
`[skip ci]`; Codemagic cut nothing, GitHub Actions skipped too). release/1.29.0 is an ancestor of the new develop.
Round develop-2026-10: waves 1–3 run, fix wave 4 (tickets 34–47) and retest wave 5 (48–51) still to run on
develop-next, which now tracks origin/develop. Xuan told by Lee: Lee says she is working on her own bugfixes and
will merge into develop (her branches must be based on release/1.29.0 or the new develop, see the rulings below).
Phase B (`mealplanning-next`) not started. Round-up test suite: 5154 pass at `2b730018`.

## Tips recorded 2026-10-06 (all `git fetch`ed, unchanged since the spec)

| ref | sha |
|---|---|
| origin/develop | `fb4a97e9` (tag `develop-pre-split`, LOCAL only — push on Lee's go) |
| origin/release/1.29.0 | `1dc88f48` |
| origin/mealplanning | `aec125f7` |
| local `sentry` | `bec11608` (tag `sentry-original`, LOCAL only — push on Lee's go; code at `deb59745`) |
| `develop-next` | code `1574cd93` + this docs commit (`git rev-parse develop-next`) |

Worktrees: `/Users/leemartin/development/mealvana_endurance-waves/branch-split/develop-next` and `.../sentry-next`
(env files copied in, gitignored).

## A1 — commit lists

Exclude list: the 48 commits of `a5af91d7..f71694ba^2` + `14e895bf 1e7b34e6 d24d8f18 2014fd90 0ecf6b4a` (53).
Include list: `git log origin/release/1.29.0...origin/develop --no-merges --cherry-pick --right-only` (113) minus
the exclude list = **69** (the spec's ≈70). NOTE: `--cherry-pick` needs the three-dot range; two-dot returns 152.

## A2 — develop-next = release/1.29.0 + 23 commits

Picked (oldest first):
- `3b12a2ef` ssot: re-sync mirror @ main 5dc1b82 — home-shell@v1 landed + close-out record [skip ci]
- `e43b8652` ssot: re-sync @ main 1b2a900 — Vana's two PROPOSED specs recovered into the QA repo and back into the mirro
- `d1ff3fdd` docs+skill: shorebird OTA patching — encode the 2026-09-11 flow [skip ci]
- `9d86e558` chore(db): drift_schema_v19.json now records the SHIPPED v19 shape
- `6672593f` docs(deploy): open the data-integrations@v1 runbook — §10 row
- `2c6284c0` feat(tp-writeback): logged fuel block — planned · consumed (Xuan opt A, 2026-09-10)
- `0e264cad` feat(dashboard): make the transient no-targets state visible to us
- `b50e2e41` docs(shorebird): record the pub-get Flutter-mismatch trap [skip ci]
- `fc945fd4` fix(macros-v6): F4a validator gap — unknown sports rejected before pricing [skip ci]
- `2698107b` fix(dashboard-telemetry): resolved event must be warning — prod drops info [skip ci]
- `418b9c80` fix(events): moving an event moves its linked activity (and its fuel)
- `83d45892` fix(events): refresh the activities cache after an event update
- `7fb4144d` feat(corpus): raw retention + capture + corpus engines — real-payload-corpus@v1 core
- `246cb710` test(settings): supply develop's deeper provider graph in the anonymous case
- `a1a377db` fix(garmin): activityDetails sample streams stopped landing at all [skip ci]
- `8820c588` docs(deploy): the corpus bundle row carries the DI-25 capture deploy [skip ci]
- `26a8e8a9` docs(shorebird): record the three traps the 1.28.0 patch run hit [skip ci]
- `cbf64199` docs(schema): prod baseline after duration_source apply (P1, 2026-10-01) [skip ci]
- `07fbb2ab` sync(1.29.0→develop): codegen + the fingerprint develop's v22 actually has
- `3c8187b6` playbook §10: carb-loading/1.28.0 and nudge/1.29.0 runbook rows — on develop, where release/* rows survive 
- `d5cd152f` playbook standing order 6: pg_dump >= server major for prod dumps (Xuan 2026-10-01) — version in commit msg
- `d0427457` CLAUDE.md: D9 non-negotiable — silent paths must record in a prod-readable channel [skip ci]
- `541167c6` CLAUDE.md: push-stack tripwire reaches develop (was stranded on fix/1.28.1) — 'touch', incl. startup chain 
- `a7f5963a` chore(branch-split): develop rebuilt from release/1.29.0 — fingerprint, Patrol paywall test, README, fuel-b

Skipped — 46, each because release already carried the same patch in its own shape (checked per file: the
conflicted file was byte-identical on `origin/develop` and `origin/release/1.29.0`, so release's copy IS Xuan's
final state), plus three that the spec predicted:
```
8aa4fe26 skipped: version bump to 1.26.0, release already 1.29.0+6
556c1ce8 skipped: became empty after taking release's identical files — fix(macro-dashboard): the docked brick panels are opaque chrome
4b2cbdec skipped: became empty after taking release's identical files — fix(home-shell): the shell publishes its bottom clearance; bodies stop guessing
0cb766db skipped: became empty after taking release's identical files — fix(macro-dashboard): the timeline scrolls exactly clear of the docked panel
4b37c6f4 skipped: became empty after taking release's identical files — fix(brick): ungroup can no longer destroy a workout — four bugs in one flow
bcc13c03 skipped: became empty after taking release's identical files — fix(onboarding): Garmin historical primer now fires — it was in the wrong handler
b27bd42b skipped: became empty after taking release's identical files — feat(onboarding): Garmin historical primer uses the glass sheet material
eaf00f3c skipped: became empty after taking release's identical files — fix(integrations): drop history/window sublabels from provider connect cards (D-4)
e64a1c30 skipped: became empty after taking release's identical files — fix(tp-writeback): minimal Pre copy + glass consent sheet (Xuan, 2026-09-14)
3a89b54c skipped: became empty after taking release's identical files — fix(tp-writeback): sequence the two completion writes (prod-smoke race)
eaf69600 skipped: became empty after taking release's identical files — fix(onboarding): system/edge back steps one page, not out to /welcome
d3361275 skipped: became empty after taking release's identical files — fix(carb-trend): duration-gate the baseline window so short runs don't starve it
74ba4757 skipped: became empty after taking release's identical files — fix(events): cycling events ask for Goal Speed (mph), not run pace
acbc2960 skipped: became empty after taking release's identical files — fix(events): editing an event's date now persists (derive eventDate from startTime)
4b231a06 skipped: became empty after taking release's identical files — fix(activity-type): unknown types map to `other`, never silently to `run`
68cc3b6d skipped: became empty after taking release's identical files — fix(by-hour): Sip Throughout carb badge scales with the row's quantity
e9f516d7 skipped: became empty after taking release's identical files — chore(coach): parseActivityType is a plain public static (drop meta import)
60202699 skipped: became empty after taking release's identical files — feat(corpus): dead-man sweep watch + disconnect purge covers raw payloads
8c572e8b skipped: became empty after taking release's identical files — fix(tp): IsPremium A1 re-key — no behavior on the flag, attempt-and-observe
7fba9826 skipped: became empty after taking release's identical files — feat(corpus): alert email leg — pg_net + raw-retention-alert edge fn
cfc505f5 skipped: became empty after taking release's identical files — feat(corpus): novelty-gated export — sampler + corpus-export edge fn
cc92c2f9 skipped: became empty after taking release's identical files — test(tp): DI-23 behavioral tests for the A1 re-key
1253dc70 skipped: became empty after taking release's identical files — fix(corpus): scrubber inverts to default-deny on content (@v1.1)
258c5af7 skipped: became empty after taking release's identical files — test(corpus): runner asserts the default-deny properties (@v1.1)
12fbaf01 skipped: became empty after taking release's identical files — chore(ssot): mirror the corrected corpus-deid vectors (@v1.1)
cfeca03a skipped: became empty after taking release's identical files — fix(corpus): deterministic synthetic ids + source-keyed provenance (@v1.1)
3edf3786 skipped: became empty after taking release's identical files — docs(corpus): correct the WorkoutSubTypeName exclusion rationale [skip ci]
671e2cda skipped: became empty after taking release's identical files — test(corpus): DI-27 dead-man check behaves in both directions
4887271c skipped: empty after HEAD (release has DI-25 + try/catch)
d5dd1c4b skipped: became empty after taking release's identical files — fix(tp): DI-26 — delete both fabricating fallbacks, refuse the whole structure
fd622096 skipped: became empty after taking release's identical files — fix(corpus): GPS is dropped by word-match, never fuzzed
a06a0a42 skipped: became empty after taking release's identical files — feat(corpus): DI-28a Garmin wing + class-level provenance stamps
cdaf42c2 skipped: became empty after taking release's identical files — fix(garmin): capture failure can never cost an activity
7035bc2e skipped: became empty after taking release's identical files — fix(corpus): preserve multisport structure — isParent allowlist + richest representative
1e92035d skipped: became empty after taking release's identical files — feat(corpus): embedded companions — linkage sets load as one coherent file [skip ci]
2f38041e skipped: became empty after taking release's identical files — fix(integrations): read TP TssPlanned/TssActual wire casing — tss_planned was never populating
a6592812 skipped: became empty after taking release's identical files — fix(auth): refuse LOGIN-mode OAuth sign-ins that mint a fresh empty account
e9a9220e skipped: became empty after taking release's identical files — fix(auth): stop minting a new anonymous UID on app open / re-onboarding
7bc61765 skipped: became empty after taking release's identical files — fix(settings): no plain sign-out for anonymous sessions
c66c50ce skipped: became empty after taking release's identical files — fix(create-flow): one lifetime for all create-flow form state (Q-CA2)
395f51fa skipped: became empty after taking release's identical files — feat(nutrition_plan): conditions provenance travels with the plan (CP-1..CP-6)
e293d27b skipped: became empty after taking release's identical files — fix(onboarding): Build My Plan was a dead end after sign-out
876dd308 skipped: became empty after taking release's identical files — fix(push): an unrestored session no longer strands the OneSignal alias [skip ci]
c60408a5 skipped: empty after HEAD (release has app_version step)
ff023563 skipped: empty after HEAD (release has 888682f3 launch trail)
92c3ab3b skipped: empty after HEAD (release owns v22 duration_source + empty v21)
```

Hand decisions on develop-next:
- `a6b7cf3d` (schema v19 json) did NOT need regenerating: Xuan's file already records the shipped, Vana-free v19
  shape (her commit message says so). Taken as-is.
- `1b8f7d77` re-pinned the schema fingerprint to develop's Vana-inclusive v22; develop-next has no Vana tables, so
  `schema_version_guard_test.dart` is back on the release line's `242db9fc…` (commit `a7f5963a`).
- Cherry-pick regression caught by the "develop==release but develop-next differs" check: `74f624b6` re-added the
  logged-fuel re-push block in `activity_detail_controller.dart` that `3a89b54c`/`4f0ad533` had already sequenced
  away on both tips. Reset to release. That check (`git diff --name-only origin/develop HEAD` filtered by
  `git diff --quiet origin/develop origin/release/1.29.0 -- f`) is the one to re-run after any further pick.
- Deleted: `integration_test/flows/paywall_render_flow_test.dart` (+ README rows, + the CI targets in
  `codemagic.yaml` ×2 and `tests-selfhosted.yml`, `EXPECTED_PATROL_TESTS` 24 → 23 — these last on sentry-next).
- `docs/database/README.md`: release's text said "schema v9"; rewritten to point at `schemaVersion` + the empty v21.
- Drift: `schemaVersion` 22, v21 EMPTY placeholder (release's), no Vana tables declared. Startup integrity check
  read (`AppDatabase._validateSchemaIntegrity`): it walks `allTables` (the DECLARED set) and fails only on a missing
  table or missing column — extra tables and extra columns are ignored. So a dev device coming from develop's v21
  (Vana tables present) walks the v22 step (adds `duration_source`), passes validation and keeps its orphan tables;
  one coming from develop's v22 (from == to) skips onUpgrade, already has `duration_source`, and passes too. No reset,
  no prod risk (prod never had the tables).
- Migrations: exactly the 12 meal-planning files + `cutover/meal_planning/` are absent (they were never on release);
  `20260901160000_catalog_conventions_c1_c3.sql` present.
- Restricted diff vs `origin/develop` (spec A2): 93 files, all read: pure meal-planning deletions or release's shape
  (`jade-chat` big version, `pro_version_screen` back, `ai_coach_chat_repository` on http.Client, raw
  `.env.example` recreated later from ticket 17's version minus PRO_GATE/PRO_PURCHASE/KROGER keys).

## A3 — sentry-next = 60 Sentry commits replayed + `89c6f65a` reconciliation

`git rebase --onto develop-next 6e969e77 sentry-next`: 60 non-merge commits replayed, **0 skipped**, 28 original
merge commits flattened. Meal-planning-only paths resolved as deleted automatically (46 `del` lines in the log).
Hand merges (17 stops):
-  ec0d19bc main*.dart = HEAD (drop ContentDefaultsCache import)
-  8294d09b main*.dart = theirs (bootstrap rewrite); bootstrap.dart ContentDefaultsCache import+preload removed; pubspec.lock = theirs minus share_plus/wakelock/vibration
-  834053ab jade-chat + revenuecat-webhook = release shape + ticket 12 intent (named withSentry, console.error sites → capture helpers/breadcrumbs)
-  67ed0617 saved_meal.dart = HEAD (meal_types decoder is mp-only; items decoder migrated)
-  821e0ccd bootstrap.dart imports (app_database kept, ContentDefaultsCache dropped); allow_list intersect
-  633fa52c app_router + tabs_screen = HEAD on mp hunks; Report edits applied
-  d96d49b1 ai_coach_chat_repository = release http shape + Report (ctor report, _r.fault on parse, provider wiring)
-  1921d922 integrations_providers = HEAD (unused sentry_reporter import dropped)
-  7882b8b4 content_service = Report try/catch kept, ContentDefaultsCache dropped; test keeps RecordingReport, drops auto-init stubs
-  ac1a0459 daily_macros ×2 = new report/performance_telemetry import, report import kept where used
-  8eab0fb4 settings_controller = Report upload loop minus mp repos, no Pro clear; events sync test = HEAD (shared recorder)
-  99dd3681 saved_meals_repository = HEAD (no updateNotes); saved_meal = DecodeIssue seam kept, mp fields/decoders dropped
-  57dca2d5 ai_coach_chat_repository off legacy logger (http shape): _r.info/degraded/fault, decodeIssue import; coach sync test = theirs
-  a0532ad9 settings_controller = HEAD (no Pro clear); area rename applied
-  67de8e4f .env.example recreated from ticket 17's version minus PRO_GATE/PRO_PURCHASE/KROGER keys
-  7e2a0feb expected_failures = union (Vana-era tags kept for now; usage check at cleanup)
-  df4fd41c auth ×2 = original sentry tip version (tips identical; ticket 18+20+merge fixes); settings_controller = futures-before-await fix minus mp repos, no Pro clear

Then `89c6f65a` (see its message): the two meal-planning files the Sentry tickets had ADDED removed; Vana-era
`ExpectedFailure` tags + table rows deleted; `settings_controller` without the Pro clear; `ai_coach_chat_repository`
402-body decode reports Degraded; `allow_list.md` rebuilt from the original `sentry` tip minus files that no longer
exist (the per-commit "intersect" resolution was WRONG for both-sides-added entries — do not reuse it; rebuild from
the tip instead); CI targets; 125 `.g.dart` hash lines regenerated.

Lost-in-rebase check (files identical on both tips, touched by Sentry, HEAD ≠ `sentry`): only `bootstrap.dart`
(ContentDefaultsCache removal), `connected_apps_screen.dart` and `root_app_widget.dart` (release's NEWER launch-trail
code that the `sentry` base predates). Nothing lost.

## Verification

- `flutter analyze`: 0 errors outside `integration_test/test_bundle.dart` (known Patrol mismatch), both branches.
- Source guard: 20/20 green on sentry-next.
- Edge functions: `deno test --allow-all` (NOT `--allow-all --allow-sys`; this Deno refuses the pair) — 806 passed;
  the only failures are `calculate-daily-macros-v6/index.integration.test.ts` (needs live SUPABASE_URL; skipped
  on develop-next, 29 ignored). Sentry-specific: `_shared/sentry*.test.ts` + revenuecat-webhook + jade-chat 38/38.
- develop-next full suite: `flutter test test/*/` (minus manual_live): 4456 passed, 3 failed before the CI-target fix — the paywall CI contract case is fixed in `89c6f65a`; the other two are the known reds below.
- sentry-next full suite: same command: all green except the two known reds below (`exit=1` from them only).
- Code review (Standards + Spec, base develop-next): Standards: no break; fixes applied in the review commit (jade-chat `persist` closure
  now `.catch` → `captureEdgeError` — it ran outside `withSentry`'s scope; `_area` literals; Kroger clause + test
  removed from the SDK event filter and the `upstreamUnavailable` comment; `_uploadDirtyBeforeLogout` doc note
  restored; `calculate-daily-macros` now names its `withSentry`). Judgement calls NOT taken, same as the original
  branch: `revenuecat-webhook` keeps `Authorization mismatch` / `missing app_user_id` as breadcrumbs (a 401 probe
  per event would be noise) and `no credit mapping` as a server log; the non-200 Fault in `ai_coach_chat_repository`
  still carries the response body in `extra`. Spec: nothing missing, nothing extra, nothing wrong; the spec's own
  acceptance grep for `vana` must be read as a whole word (it matches `mealvana`).

Known red (pre-existing, NOT from the split):
- `test/shared/ci_config_contract_test.dart` "push to develop runs the dev tests" (spec allows).
- `test/shared/widgets/custom_app_bar_back_button_test.dart` "does not crash when navigator cannot pop": the widget
  (Xuan's 2026-10-05 patch #4, "back control never dead-ends") now calls `GoRouter.of(context)` when `canPop` is
  false; the 1.16-era test provides no GoRouter. Widget + test are byte-identical on `origin/develop` and
  `origin/release/1.29.0`, so it is red there too. Round-up ticket material.

## Owed / open

- Push the two safety tags (`git push origin develop-pre-split sentry-original`) — Lee's go.
- Device: one cold start of a develop-next build on the dev simulator with an account that ran develop's v21.
- Deploy NOTHING (spec). The dev edge functions currently deployed are the `sentry` branch's (Vana-aware) versions;
  develop-next's `jade-chat` is the release-line body with reporting — redeploy only with the testing round.
- `sentry_coverage.test.ts` scans every handler: keep it green if functions are added.

## Not on this branch (for the mealplanning round)

Sentry dev issues whose code lives only on `mealplanning` (round-up ticket 20,
`.scratch/testing-wave/rounds/develop-2026-10/issues/20-sentry-leftovers.md`, has the evidence). Each needs
its fix on mealplanning, then `resolvedInNextRelease` with that sha.

- DEV-5G: RenderFlex overflows on mealplanning builds (onboarding 20550 px with the keyboard up, vana-browse 37 px); no widget named, revisit once events carry `flutter_error_details`.
- DEV-5H: vana-browse rail cards overflow at a fixed 132 px; fixed by `885db994`, resolve when it ships.
- DEV-7X: `MealCatalogController._localRecents` reads `ref` after dispose.
- DEV-7Y: `VanaSettingsController._repo` reads `ref` after dispose.
- DEV-7Z: `KrogerController._assertScope` throws `session_changed` on refresh-token churn.
- DEV-81: `VanaCompanionHost._onRoute` reads `ref` from a deactivated element during a Router restore; needs an activation guard.
- DEV-86: Flutter `RenderEditable.selectWord` null check on an iOS long-press in the Vana chat composer (framework, no app frame).
- DEV-8A: `VanaSettingsController.build` calls `ref.onDispose` after dispose.
- DEV-8B: `MealCatalogController._loadLocalRails` reads `ref` after dispose.
- DEV-8K: connection reset on the `kroger` edge call (the reset needle already downgrades it).
- DEV-8Y: `ai-cost-alert` (dev) daily cost over threshold, by design.
- DEV-8Z: `ai-cost-alert` forced test alert (`threshold_usd: -1`), by design.
- DEV-9E: Vana chat `_scrollToBottom` reads `maxScrollExtent` before layout; needs a `hasContentDimensions` guard.
- DEV-9F: navigator `finalizeRoute` assertion, same event as DEV-9G.
- DEV-9G: the paywall expiry redirect replaces the page stack under an open pageless sheet; pop pageless routes first.
- DEV-9R: the paywall clip seeks after dispose; adopt `DisposalSafeVideoPlayerController`.
- DEV-9W: `SubscriptionScreenController.build` watches after awaits (ticket 18 pattern).
- DEV-A1: Vana tools fabricate `log:` meal ids; fixed in `82b3ce71` (tools.ts), resolve once that function is on dev.

Related, not a Sentry row: mealplanning's Drift ladder reaches v24 without `activities.duration_source`
(its v22 is `users.home_*`; develop-next's v22 is `duration_source`). A device crossing between the two
lineages fails schema validation and resets (DEV-A5/A6/A7 on 2026-10-06). Phase B must renumber
develop-next's `duration_source` step above mealplanning's 24 (idempotent `addColumn`) when the lines merge.

## Rulings from the develop-2026-10 triage that Phase B must carry (2026-10-08)

- **Drift gap on branch-hopping devices (Lee, wontfix in code).** develop-next adds `activities.duration_source`
  in a migration step that mealplanning's v23/v24 never ran. A device that ran a mealplanning build is already
  at v24, so the step is skipped and the column is missing there. Fresh installs and real users are unaffected.
  Before any internal device (Lee's and Xuan's dev phones, the dev simulator) takes a post-merge build, wipe
  the app on it. No column guard, no v25.
- **Anonymous athletes leave server rows (Lee, wontfix, Finding 30-006).** "Continue without an account" makes an
  anonymous auth user with `users`, `daily_macro_targets` and `onboarding_surveys` rows and Settings offers it no
  Delete Account. The anonymous path is being removed; whoever removes it sweeps those rows on dev and prod
  (`select id from auth.users where is_anonymous` and the cascade through `public.users`).
- **Xuan's merges after the develop rewrite (Lee, 2026-10-08).** develop is force-pushed from `develop-next`
  (release/1.29.0 + the included commits). Xuan's bugfix branches must be based on `release/1.29.0` or the new
  `develop`; a branch off the old develop (`develop-pre-split`, `fb4a97e9`) would merge the 53 excluded
  meal-planning commits back in.
