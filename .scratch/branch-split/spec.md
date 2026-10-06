# Branch split: `develop` without meal planning, `mealplanning` with everything

**Labels:** ready-for-agent
**Branches:** builds `develop-next` (replaces `develop`) and `mealplanning-next` (fast-forwards `mealplanning`).
**Decision record:** Lee, 2026-10-06: "whatever you recommend, go ahead" → option R (rebuild) from `STRATEGY.md`
beside this file. Read `STRATEGY.md` first; every number below comes from its dry runs.
**Runs in two phases.** Phase A is the prerequisite of the testing round (`.scratch/develop-roundup/spec.md`).
Phase B runs after that round is green. Different sessions may do A and B; a `HANDOFF.md` beside this file
carries state between them.

## Problem Statement

Meal planning (Vana, plans, Pro gate, Food tab) was merged into `develop` on 2026-09-06 (`f71694ba`) and has
sat there since, while the product decision is that it ships only from the `mealplanning` branch. Nothing from it
has ever reached a release or `main`. Xuan's real line is `release/1.29.0` (+ `fix/*`), which she syncs onto
`develop`; her work is unaffected by meal planning. The Sentry work (branch `sentry`, 85 commits over develop
`6e969e77`, local only) must land on both `develop` and `mealplanning` so they do not drift. Reverting the merge
on `develop` would poison every later `develop` → `mealplanning` merge (it would delete meal planning there), so
`develop` is rebuilt from the release line instead, and its history never contains meal planning.

## Solution

Phase A (local, no pushes):
1. `develop-next` = `origin/release/1.29.0` + Xuan's develop-only non-meal-planning commits, Drift v22 kept.
2. `sentry-next` = the Sentry commits rebased onto `develop-next`, meal-planning hunks dropped; `develop-next`
   fast-forwarded to it.
Phase B (after the testing round):
3. `mealplanning-next` = `mealplanning` + original `sentry` (meal-planning half of the Sentry migration) +
   `develop-next` (Xuan's latest + the testing round's fixes) + a Drift v25 for `activities.duration_source`.
4. Pushes, each on Lee's explicit go: `develop-next` → `develop` by `--force-with-lease` (one push; it auto-cuts
   the dev TestFlight build, ~9¢/min); `mealplanning-next` → `mealplanning` by normal push.

## Phase A — build `develop-next` and `sentry-next`

### A0. Preconditions (do these, in order)
- `git fetch origin`. Record the tips in `HANDOFF.md`: `origin/develop`, `origin/release/1.29.0`,
  `origin/mealplanning`, local `sentry`. On 2026-10-06 they were `fb4a97e9`, (tip of release/1.29.0),
  `aec125f7`, `5ae86d97`. If `origin/develop` moved, the new commits are Xuan's: add them to the cherry-pick
  list in A2.
- Safety tags, pushed (Lee's go for the push): `develop-pre-split` = `origin/develop`,
  `sentry-original` = local `sentry`. Nothing below is allowed to lose either.
- Work in worktrees under `/Users/leemartin/development/mealvana_endurance-waves/branch-split/<name>`; copy
  `.env`, `.env.dev.local`, `.env.prod.local` in (gitignored, never commit). Never `git stash` in this repo.
  Never push `release/*`. Never touch prod Supabase or `app_config`.
- Lee tells Xuan the plan before Phase B's force push (she must `git fetch && git reset --hard origin/develop`
  afterwards; her `release/*` and `fix/*` branches are untouched). Record in `HANDOFF.md` when that is done.

### A1. The commit lists
- Meal-planning commits to EXCLUDE: the 48 commits that `f71694ba` merged (`git log a5af91d7..f71694ba^2`), plus
  Xuan's meal-planning touch-ups `14e895bf`, `1e7b34e6`, `d24d8f18`, `2014fd90`, and `0ecf6b4a` (Patrol
  meal-plan/Pro-gate flows). Confirm each by `git show --stat`.
- Xuan's develop-only commits to INCLUDE: `git log origin/release/1.29.0..origin/develop --no-merges --cherry-pick
  --right-only --format=%h` minus the exclude list. Expected ≈ 70 (plus anything pushed since 10-05). Save the
  ordered list to `HANDOFF.md`.

### A2. Build `develop-next`
- `git worktree add <path> -b develop-next origin/release/1.29.0`.
- Cherry-pick the include list oldest-first (`git cherry-pick -x`). Expected: ≈43 clean, ≈25 conflicts where
  release already carries an equivalent (take Xuan's develop side), `a6b7cf3d` (schema v19 json) fails → skip it
  and regenerate the snapshot with the repo's schema-dump command (`docs/database/README.md`).
- Drift: `schemaVersion` stays 22 with release's EMPTY v21 placeholder (its comment explains why). The four Vana
  tables are not declared. Check `lib/shared/database/app_database.dart` has no `meal_plans`, `plan_meals`,
  `user_entitlements`, `user_memories`, and the startup schema-integrity check tolerates orphan tables on a dev
  device that ran develop's v21 (read the validator; if it would reset the DB on unknown tables, say so in
  `HANDOFF.md` — a one-time dev reset is acceptable, a prod risk is not, and prod is at v19/v22 without them).
- Migrations: drop the 12 meal-planning files under `supabase/migrations/` dated 20260827–20260903 and
  `supabase/migrations/cutover/meal_planning/` ONLY if they are not already absent on release (they should be).
  Keep Xuan's `20260901160000_catalog_conventions_c1_c3.sql`.
- Codegen: `dart run build_runner build --delete-conflicting-outputs`.
- Verify the result equals develop minus meal planning: `git diff origin/develop develop-next --stat -- . ':!lib/features/meal_planning' ':!test/features/meal_planning' ':!docs/new_mealplanning' ':!docs/implement_mealplanning' ':!supabase/functions/vana-*' ':!supabase/functions/_shared' ':!lib/features/subscription'` and read every remaining hunk: each must be either a meal-planning edit to a shared file (expected to go) or something release has in a different shape (keep release's). The 27 files of genuine Xuan-only content named in `STRATEGY.md` § 3 must be present.
- `flutter analyze` (0 errors outside the Patrol `integration_test/test_bundle.dart`, which is a known
  pre-existing Patrol version mismatch) and the full suite: `flutter test $(ls -d test/*/ | grep -v manual_live)`
  (zsh: `${=T}`). Known red allowed: `test/shared/ci_config_contract_test.dart` ("push to develop runs dev tests").
  Delete tests that only exist for meal planning (they came with the merge; `git log --diff-filter=A` tells you).

### A3. Rebase the Sentry work → `sentry-next`
- `git branch sentry-next sentry && git rebase --onto develop-next 6e969e77 sentry-next` (57 non-merge commits;
  merges flatten). Expected: 21 conflicting commits. 59 delete/modify conflicts are files that exist only because
  of meal planning (`lib/features/meal_planning/**`, `lib/features/subscription/**` Pro-gate files,
  `supabase/functions/vana-*`, `_shared` edge files): resolve as DELETED (`git rm`). 26 shared files need hand
  merges: `main*.dart`, `app_router.dart`, `tabs_screen.dart`, `pubspec.lock`, `jade-chat`, `revenuecat-webhook`,
  `content_service`, `saved_meal(s)`, `ai_coach_chat_repository`, `settings_controller`,
  `test/shared/source_guard/allow_list.md` (8 times; both-deletions pattern: keep only lines neither side
  deleted, then run the guard and delete stale entries), `events_service` + test, auth ×2, `daily_macros` ×2,
  `integrations_providers`, `expected_failures.dart`, 2 sync tests, shorebird docs.
- Keep every Sentry commit's intent; where a commit becomes empty after dropping meal-planning hunks,
  `git rebase --skip` and list it in `HANDOFF.md`.
- After the rebase: codegen, `flutter test test/shared/source_guard`, `flutter analyze`, the full suite (same
  known red only), then `/code-review` with base `develop-next` (Standards + Spec; the Sentry spec is
  `.scratch/sentry/spec.md`). Fix findings in one commit. Fast-forward: `git checkout develop-next && git merge
  --ff-only sentry-next`.
- Edge functions: `develop-next` must still deploy the Sentry edge wrapper (ticket 12) for the non-Vana functions.
  `cd supabase/functions && deno test --allow-all --allow-sys` for every function with tests. Deploy NOTHING.
- Write `HANDOFF.md`: tips, the exclude/include lists, skipped commits, resolved files, suite numbers, and the
  sentence "Phase A done; testing round may start on `develop-next` @ <sha>".

## Phase B — `mealplanning-next` and the pushes (after the testing round is green)

### B1. `mealplanning-next`
- `git worktree add <path> -b mealplanning-next origin/mealplanning` (refetch; Lee's wave sessions may have
  moved it).
- `git merge sentry-original` (the tag from A0: the ORIGINAL Sentry branch, which carries the meal-planning half
  of the Report migration, ~45 files / 1,347 lines, that `sentry-next` dropped). Expected 124 conflicts: 21
  meal_planning, 9 meal_logging, 8 `_shared`, 8 auth, 7 integrations, `app_database.dart`, `app_router`,
  `tabs_screen`, `pubspec.yaml`/`.lock`; add/add `CONTEXT.md` (keep both glossaries) and
  `.scratch/ssot/review-queue.md` (keep both lists); modify/delete: mealplanning deleted `ai-coach`,
  `coach_insight_controller`, `ai_coach_client`, `insufficient_credits_paywall` → keep deleted; sentry deleted
  `sentry_event_filter.dart` + test and two `Package.resolved` → take sentry's deletion ONLY if `develop-next`
  also lacks them (check), else keep. Rule for code conflicts: mealplanning's behaviour + Sentry's reporting
  (`Report.fault/degraded/note`, no legacy logger). `CodeEntryController._invoke` still calls the deleted legacy
  logger on mealplanning: convert it (see `.scratch/sentry/WAVE-5-CLOSEOUT.md` § owed for this and the other
  five mealplanning-only fixes: DEV-9R, 9G/9F, 81, 9W, `CodeRedeemFailure` needle). Do those six here.
- `git merge develop-next` (Xuan's newest + the testing round's fixes). Patch-equivalent commits mostly
  auto-resolve; resolve the rest the same way.
- Drift on mealplanning: add **v25** that adds `activities.duration_source` exactly as develop's v22 does (a
  mealplanning dev device at v24 lacks it). Leave mealplanning's v22–v24 as they are. Write in
  `docs/implement_mealplanning/06-*` (cutover runbook) that at the eventual mealplanning → develop cutover its
  v22/23/24/25 steps must be renumbered above develop's v22 and v21 must stay empty on develop, and that the
  migration timestamp `20260901160000` is shared by two files (rename the meal-imagery one then).
- Codegen, source guard, full suite (mealplanning's own known reds are listed in
  `.scratch/testing-wave/HANDOFF.md` on that branch), `/code-review` since `origin/mealplanning`.

### B2. Pushes (each only on Lee's explicit go, in this order)
1. `git push origin develop-pre-split sentry-original` (tags) if not already pushed.
2. Xuan confirmed she has pushed everything and will reset: `git push --force-with-lease=develop:<tip recorded in
   HANDOFF.md> origin develop-next:develop`. ONE push. Then run `/release-cut` for the dev build it cuts.
3. `git push origin mealplanning-next:mealplanning` (fast-forward; if not, merge `origin/mealplanning` first).
4. Local branches: `git branch -f develop develop-next`, `git branch -f mealplanning mealplanning-next`; keep
   `sentry` and the tags.

## Testing Decisions
- Phase A acceptance is mechanical: suite green (known red only), analyze clean, the restricted diff in A2 reads as
  "release's shape or meal-planning removal" only, `grep -rn "meal_planning\|vana\|isProGatedPath" lib/ test/`
  returns nothing on `develop-next`, `grep -rn "sentry_flutter" lib/` only under `lib/shared/services/report/`
  and `lib/shared/core/bootstrap/`, and the Sentry debug-console probes (ticket 15, Developer/Tester role) still
  exist.
- Phase B acceptance: `git merge-base --is-ancestor develop-next mealplanning-next` true; `grep -rn
  "appLoggerProvider\|DebugLogger\|SentryReporter" lib/` empty on mealplanning-next; v25 migration test in the
  style of the existing `test/shared/database/*migration*` tests; suite green.
- Device: one cold start of a `develop-next` build on the dev simulator (`scripts/run_dev.sh`) with a dev account
  that previously ran develop's v21: app opens, no `DatabaseReset` warning in Sentry dev. Same for
  `mealplanning-next` from a v24 device (the v25 step applies).

## Out of Scope
- Fixing app bugs (the testing round owns them), Sentry leftovers (same), prod deploys, `app_config`, the
  eventual mealplanning → develop cutover, any change to `release/*`.

## Further Notes
- `git log --cherry-pick --right-only` is how you tell "already in release" from "develop-only". Trust it over
  commit titles: Xuan's sync commits carry the same patches under new shas.
- The source guard's allow-list conflicts recur on every merge; the resolver pattern is in the Sentry memory:
  keep lines neither side deleted, run the guard, delete what it calls stale.
- zsh: `${=VAR}` to word-split; `GID` is a reserved variable name.
