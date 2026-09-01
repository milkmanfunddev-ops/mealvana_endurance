# Phase 0 — Git reconciliation

> **Status: DONE 2026-09-01.** Executed as written below with two deviations: the branch is named `mealplanning` (not `feature/meal-planning`), and the changelog was auto-published by `changelog-on-main.yml` (secrets were present) and then hand-corrected in Sanity (release date → 2026-08-13, tester-SKU bullet removed). Xuan's branches were left untouched for Lee to raise with her.

Goal: `main` = what shipped; `develop` = everything (release-only commits + Xuan's stranded fixes);
`feature/meal-planning` off the new develop = the meal-planning migrations + docs; prototype repo
committed, pushed, self-contained; the 1.23.x changelog published to Sanity.

Findings this plan is based on (2026-09-01, after `git fetch --all --prune`):

| Fact | Evidence |
|---|---|
| `main` tip is the **1.22.0** merge (`c171b9df`), 197 behind `release/1.23.1`, 0 ahead | `git rev-list --left-right --count origin/main...origin/release/1.23.1` → `0 197` |
| `release/1.23.1` (`1.23.3+1`) has 6 commits not on develop — 1.23.2/1.23.3 bumps, cutover runbook, schema dumps, the merge commit | `git log origin/develop..origin/release/1.23.1` |
| develop has 87 commits `release/1.23.1` lacks; pubspec `1.23.1+1`; Drift v18 | |
| Merge dry-runs release→main and release→develop: **0 conflicts** | `git merge-tree` |
| **There is no `release/1.23.2` branch.** 1.23.2 and 1.23.3 were commits on `release/1.23.1`. | `git branch -a` |
| `release/1.23.0`'s only unique commit is an empty CI-trigger commit | `8a8341a3` |
| `release/1.24.0` (`1.24.0+1`): its only content not already on develop (by patch-id) is the `chore(release): 1.24.0` version bump | `git cherry origin/develop origin/release/1.24.0` |
| **Xuan has no commits on any release branch that aren't on develop.** | per-branch `git log origin/develop..<branch>` by author |
| Xuan's stranded feature branches: `test/sync-serialization-invariants` (2 commits, 08-12: UTC upload timestamps + `sender_name`, 578-line invariant test), `fix/describe-default-1.24` (1 commit, 08-27, on top of release/1.24.0), `feature/brick-on-macro-dashboard` (5 commits, 08-26, "unratified candidate" WIP, 26 files), `feat/formula-kit` (June), `feat/analytics-events` (July, docs + pod artifacts), `fix/preworkout-bundle-may2026` (May, superseded by pre-workout v2 landing 08-27) | |
| Pushing non-docs commits to `main` fires `.github/workflows/changelog-on-main.yml` → `scripts/changelog/generate_and_publish.mjs` (Claude via AI Gateway → Sanity `sigrvh1t`, dataset `production`, optional Vercel deploy hook). Needs repo secrets `AI_GATEWAY_API_KEY`, `SANITY_WRITE_TOKEN`. | workflow file |
| Sanity's newest changelog entry is **1.22.0** (2026-07-23). No 1.23.x entry exists. | GROQ query |
| Local stashes 0–4 are old (1.22.0 / July / 1.16 / new_sync) — leave alone | `git stash list` |
| Untracked in this repo: 9 migrations, 7 scripts, `docs/new_mealplanning/`, `.gitignore` (+`.cache/`), stale `docs/*_schema.txt` regen | `git status` |
| Prototype repo: on `main` = origin at `1df9b3d` (05-18); Vana rewrite entirely uncommitted (85 D / 26 ?? / 7 M); `.env.local` and `.output` are ignored | |

## Steps

Order matters: the prototype repo first (its work is only on disk), then this repo's branch, then
main/develop, then the feature branch, then the changelog.

### 0. Safety
- Confirm no other Claude session / worktree is mid-operation on this tree (`.claude/worktrees/` has an
  old `wf_5918a4ae` worktree — check `git worktree list`; prune if stale).
- Do **not** `git stash -u` — 17 MB of untracked files and a shared index. Branch in place instead.
- Tag before merging: `git tag backup/pre-reconcile-20260901 origin/develop` and the same for
  `origin/main` and `origin/release/1.23.1`. Push the tags.

### 1. Prototype repo — commit, make self-contained, push
In `~/development/mealplanning-prototype`:
1. `git add -A` (deletions of the Jade/variant code + the Vana tree). Verify `packages/web/.env.local`
   is not staged (`git status --ignored | grep env.local`).
2. Commit: `feat(vana): rebuild the prototype around Vana — Food tab, planner agent, cooking mode`.
3. **Self-contained**: from the Flutter repo, `git mv`-equivalent (copy, then delete here) into the
   prototype repo:
   - `scripts/{seed_meal_library,export_direction_batches,fetch_recipe_sources,apply_source_scrape,
     apply_agent_directions,backfill_recipe_steps,find_meal_images}.mjs` → `packages/web/scripts/`
     (it already holds `seed-meal-library.mjs`, `backfill-meal-icons.ts` — dedupe the two seed scripts,
     keep one).
   - `docs/new_mealplanning/{meal-library-400.json,assembly-library.json,meal-images.json,
     source-scrape.json}` + `direction-batches/` + `direction-results/` → `packages/web/data/`.
   - Change every script's `--env` default from the absolute `~/development/mealplanning-prototype/...`
     path to a repo-relative `packages/web/.env.local`; change data paths to `packages/web/data/`.
   - Add a `data/README.md` naming the Flutter-side migrations these scripts assume
     (`mealvana_endurance/supabase/migrations/20260827090000` … `20260901160000`).
   - Delete the stale root `.env.example` (Clerk/JADE_* vars are dead); keep `packages/web/.env.example`.
   - `.gitignore`: add `.cache/` (the scrape cache), `packages/web/data/*.cache` if any.
4. `pnpm typecheck && pnpm test` green → commit `chore: make the prototype self-contained (scripts +
   data live here)` → `git push origin main`.

### 2. This repo — park the meal-planning work on its own branch (still based on release/1.23.1 for now)
1. `git checkout -b feature/meal-planning` (untracked files ride along).
2. `git checkout -- docs/dev_schema.txt docs/prod_schema.txt` — drop the stale regen; regenerate
   properly in Phase 5.
3. Delete the moved scripts and JSON/batches from step 1.3 here; `rm -rf .cache/`.
4. Three commits:
   - `feat(db): meal-planning schema — meal_library, plans, Vana conversations, feedback (dev-applied)`
     — the 9 migrations + `.gitignore`.
   - `docs(meal-planning): research corpus, specs, design system` — trimmed `docs/new_mealplanning/`.
   - `docs(meal-planning): integration plan` — `docs/implement_mealplanning/`.
5. Push `feature/meal-planning` (backup; will be rebased in step 5).

### 3. `main` ← `release/1.23.1`
1. `git checkout main && git pull --ff-only`.
2. `git merge --no-ff origin/release/1.23.1 -m "Merge release/1.23.1 into main (v1.23.3)"`.
   Zero conflicts expected. pubspec becomes `1.23.3+1` — that is the store version.
3. Push. Pushing main no longer auto-cuts a prod build (`b73c63c6`) — but it **does** fire the
   changelog workflow (step 6). If you want to review the generated entry before it goes live, run
   `node scripts/changelog/generate_and_publish.mjs` locally first with `FROM_REF=origin/main
   TO_REF=origin/release/1.23.1` and a dry-run flag if the script has one; otherwise let it run and
   edit in Studio.

### 4. `develop` ← `release/1.23.1` (+ Xuan's stranded fixes)
1. `git checkout develop && git pull --ff-only` (develop just received `d72d43c9`).
2. `git merge --no-ff origin/release/1.23.1`. Zero conflicts expected **except** pubspec version:
   release says `1.23.3+1`, develop says `1.23.1+1`. Resolve to the *next* version — recommend
   `1.24.0+1` to match `release/1.24.0` (confirm with Xuan). Drift stays 18.
3. `release/1.24.0` — content is already on develop; its bump commit is redundant once develop is
   `1.24.0+1`. Leave the branch; it is the next cut vehicle.
4. Xuan's branches — **hers to merge; ask first** (CLAUDE.md ownership rule applies to code as much
   as Notion). Recommended ask:
   - `test/sync-serialization-invariants` — small, a real bug fix (UTC timestamps, `sender_name`
     dropped). Merge to develop after her OK.
   - `fix/describe-default-1.24` — one commit; also relevant to `release/1.24.0`. Her call which
     branch it lands on.
   - `feature/brick-on-macro-dashboard` — WIP, unratified. Do not merge.
   - `feat/formula-kit`, `feat/analytics-events`, `fix/preworkout-bundle-may2026` — likely superseded;
     ask her whether to delete.
5. Push develop. Note: a develop push auto-builds a dev iOS build unless the tip carries `[skip ci]` —
   add `[skip ci]` to the merge commit message if no dev build is wanted from this merge.

### 5. `feature/meal-planning` onto the new develop
1. `git checkout feature/meal-planning && git rebase origin/develop` (3 commits, all additive files —
   no conflicts expected). If the rebase is unpleasant, `git merge origin/develop` is fine.
2. Confirm: `git diff origin/develop --stat` shows only migrations + docs.
3. `git push --force-with-lease`.
4. `flutter pub get && dart run build_runner build --delete-conflicting-outputs`, `flutter analyze`,
   `flutter test test/` to prove the base is healthy before any meal-planning code lands on it.

### 6. Changelog (me_website_new / Sanity)
- The main push in step 3 generates + publishes a 1.23.3 entry (`version` from pubspec; `label`
  should be `Latest`). Check the GitHub Actions run; if the secrets are missing (the repo move wiped
  them once before), run the script locally with `SANITY_WRITE_TOKEN` + `AI_GATEWAY_API_KEY` from
  `secrets/`.
- Review in Sanity Studio (`packages/sanity` in `me_website_new`, project `sigrvh1t`): the range
  1.22.0→1.23.3 covers token packs, onboarding redesign, Runna ICS, Android Play, the v3 catalog
  cutover, pre-workout v2 conformance — it may deserve `Major Update` with a hand-edited title.
  Flip the previous `Latest` label off 1.22.0 if the script doesn't.
- If the site does not rebuild automatically, trigger the Vercel deploy hook.
- `me_website_new` itself has unrelated untracked files (`docs/`, `rcm/`, a race-calculator HTML) —
  not part of this work; leave them.

### 7. Verify
- `git log --oneline -1 origin/main` == the merge; `git rev-list --count origin/main..origin/release/1.23.1` == 0.
- `git rev-list --count origin/release/1.23.1..origin/develop` > 0 and `git rev-list --count
  origin/develop..origin/release/1.23.1` == 0.
- `git rev-list --count origin/develop..origin/feature/meal-planning` == 3 (or 3 + Xuan merges).
- Prototype: `git status` clean, `origin/main` == `HEAD`, `pnpm dev` boots `/food/plan` against dev.
- Sanity has a 1.23.x changelog entry labelled `Latest`.
- Run `/sprint-sync` and `/release-cut` reconciliation only if a build is cut from this; otherwise
  just note the reconciliation on the Notion sprint card.
