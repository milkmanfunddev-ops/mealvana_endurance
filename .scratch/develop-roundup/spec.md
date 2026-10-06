# Develop round-up: test every part of the app on `develop-next`, fix what breaks, Sentry clean

**Labels:** ready-for-agent (blocked by Phase A of `.scratch/branch-split/spec.md`)
**Branch:** `develop-next` (the rebuilt develop + Sentry work). All fixes commit here. No pushes: the branch-split
spec's Phase B pushes everything after this round is green.
**Decision record:** Lee, 2026-10-06: run the emulator round-up on develop, fix every error found, fix the
remaining Sentry issues in the same round, look at Sentry until it is clear, then push.
**Procedure of record:** the testing-wave, which lives ONLY on the `mealplanning` branch:
`.scratch/testing-wave/{spec.md,RUNBOOK.md,IMPROVEMENTS.md}`, `scripts/testing-wave/*`,
`docs/ssot/decisions/_page/sync.mjs` (simulator pool), `.claude/skills/implement-lee/`. Read them from
`origin/mealplanning` (`git show origin/mealplanning:<path>`) before touching anything; the rules there (no Patrol,
credentials only through `cred.mjs`, nothing fixed during a run, every problem is a Finding, cost caps, one simulator
per ticket, max three simulators at once) all apply.

## Problem Statement

`develop-next` is a branch nobody has run end to end: it is the release line plus ~70 cherry-picked commits plus the
Sentry rebase, built by hand. Lee's standard before pushing a branch like this is the testing-wave: several
simulators at once, an agent per ticket walking one part of the app, every error written down as a Finding, then a
triage into fix tickets. At the same time 49 dev and 3 prod Sentry issues are still unresolved after the Sentry
triage (the first pass pulled a capped list of 100, so ~25 older dev issues were never looked at), and Lee wants
every event handled. Both happen in this round because they share the build, the simulators and the Sentry projects.

## Solution

1. Make the testing-wave a reusable system that lives on every branch (§ 1), seeded from the one on `mealplanning`.
2. Cut a develop ticket set: the testing-wave test tickets whose screens exist on develop-next, plus one Sentry
   ticket (the leftovers) and one ticket per Sentry fix area that needs a device check.
3. Run waves: two or three simulators, one agent per ticket, Findings filed, lead triages in the terminal with Lee.
4. Fix waves: fix tickets per Finding theme, each with a test; Sentry leftovers get root cause + fix or reasoned
   Degraded, resolved `resolvedInNextRelease` with the sha.
5. Exit: all Findings triaged and the bug ones fixed or wontfix-ruled by Lee; the dev Sentry project shows no
   unresolved issue with an event from the round's build; the prod project's 3 open issues stay open with their
   upstream comments; full suite green (known red only). Then Phase B of the branch split.

## User Stories

1. As Lee, I want every screen on develop-next opened by a tester with a clean console, so that the rebuilt branch
   is known to work before it replaces develop.
2. As Lee, I want each error written down with steps and evidence, so that fixes come from observed behaviour, not
   from guesses.
3. As Lee, I want every open Sentry issue to end with a named cause and a code change or a reasoned downgrade, so
   that the dev project reads empty after the next build.
4. As Lee, I want the testing process itself to improve as it runs (IMPROVEMENTS.md), so the next round is cheaper.

## Implementation Decisions

### 1. The testing-wave as a reusable system (Lee, 2026-10-06: "not a port; a system we reuse")
One system, committed on the trunk (`develop-next`, so every branch inherits it by merge), with durable ledgers that
every round appends to and per-round working folders that are disposable. Layout:
- `docs/testing-wave/README.md` — what the system is, the three ledgers, how a round starts and ends (≤ 1 page).
- `docs/testing-wave/RUNBOOK.md` and `docs/testing-wave/SPEC.md` — the run procedure and its rules, moved from
  mealplanning's `.scratch/testing-wave/RUNBOOK.md` / `spec.md`, de-branded of meal-planning examples (Vana cost
  kinds stay; they are no-ops on a branch without Vana). Branch-specific facts (which screens exist) never go here;
  they go in the round's ticket set.
- The three ledgers Lee asked for, append-only, each row dated and pointing at its round:
  - `docs/testing-wave/IMPROVEMENTS.md` — ways to improve the testing process (seeded with mealplanning's 90 entries,
    status preserved).
  - `docs/testing-wave/BUGS.md` — bugs found by testing, across rounds: id, round, ticket, title, kind, status
    (triaged / fixed @sha / wontfix with the ruling), the fix ticket. Seeded from mealplanning's 556 Findings INDEX.
  - `docs/testing-wave/COVERAGE.md` — additional tests to consider: every `followup-test` and `idea` Finding, plus
    screens no ticket has covered yet (the round's cold-start ticket lists them). Seeded from the 235 follow-ups
    and the retest drafts 143–161.
- `scripts/testing-wave/` — the tools, unchanged in purpose: `lock.mjs`, `cost.mjs`, `state.mjs`, `cred.mjs`,
  `clear-app.sh`, `test_accounts.template.md`, and `findings.mjs` gaining two commands: `findings.mjs ledger
  <round>` (appends a round's Findings to BUGS.md / COVERAGE.md, idempotent by Finding id) and `findings.mjs round
  new <name>` (creates the round folder from templates). `simulator claim` stays in
  `docs/ssot/decisions/_page/sync.mjs` if that file exists on develop-next; otherwise move the simulator subcommands
  into `scripts/testing-wave/simulator.mjs` and leave a one-line shim. Node tests in `test/scripts/testing-wave/`.
- `.scratch/testing-wave/rounds/<round>/` — the disposable per-round tracker: `issues/NN-*.md`, `findings/`,
  `runs/`, `app-build.json`, `TRIAGE.md`. This round is `develop-2026-10`. On Phase B's merge, mealplanning's old
  `.scratch/testing-wave/{issues,findings,runs,retest-drafts,…}` move to `rounds/mealplanning-2026-09/` with
  `git mv` so history survives; its RUNBOOK/spec/IMPROVEMENTS are superseded by `docs/testing-wave/`.
- `.claude/skills/testing-wave/SKILL.md` — user-invocable `/testing-wave <round> [--only NN,..]`: the wave lead's
  routine from the RUNBOOK (open the round, build once if code changed, claim simulators, spawn one Opus agent per
  ticket with the prompt template, merge, `findings index`, triage in the terminal, `findings ledger`, update
  IMPROVEMENTS). It replaces mealplanning's `.claude/skills/implement-lee` for testing; that skill's wave mechanics
  are the source for it. Subagents on Opus, Fable is the lead only (`feedback-subagents-run-on-opus`).
- Seeding is a one-time `git show origin/mealplanning:<path>` of each source file into its new home, then the ledger
  import; after that nothing is ever copied between branches again, it merges.
- Credentials: `secrets/test_accounts.md` already exists in the main clone (gitignored). Do not open it; `CRED list`.
- Simulators: the pool and `simulator claim` copy the dev simulator; the lead builds `develop-next` once with
  `scripts/run_dev.sh` from a clean worktree, installs it on the dev simulator, and records the sha in
  `app-build.json`. Rebuild only when `lib/`, `pubspec`, `ios/`, `assets/` change (fix waves).

### 2. The ticket set (`.scratch/develop-roundup/issues/NN-*.md`, testing-wave ticket format)
Start from the testing-wave test tickets on `origin/mealplanning` (`.scratch/testing-wave/issues/01-32`) and keep
the ones whose screens exist on develop-next. Expected keep list (verify each by grepping develop-next for the
screen): 02 delete account + signup sweep (drop its paywall-menu steps), 23–28 meal logging (describe, photo,
manual/build, recent/common, edit/delete, barcode on a simulator), 29 cold start every tab, 30 timeline + fuelling
plan, 31 settings/profile/sign-out, 32 signup code + forgot password. Drop: 01 (harness), 03 (Patrol), 04–13 (the
subscription paywall, Test Store, redeem code, Pro gate: NONE of that exists on develop-next, by Lee's rule in the
branch-split spec), 14–22 (Plans, Vana, Shopping, Kroger). Add an **AI credits** ticket instead (the pre-existing
credits system: balance, the insufficient-credits wall, a Jade/describe call spending a credit). Add:
- **Integrations** (Garmin, TrainingPeaks, FinalSurge, VDOT, Runna): connect, sync, disconnect, with the Sentry
  ticket-19/22 changes (a dead Garmin token → Degraded 409 path, TP write-back edit window) as explicit steps.
  Credentials via `CRED`; `secrets/integration_test.env` holds API creds (never print).
- **Activities + events + race checklist + carb loading** (Xuan's carb-loading G-series is on develop-next; the
  carb-loading spec is `.scratch/carb-loading/spec.md`): create/edit/delete an activity, a brick, an event, the
  nudges' surfaces (read `.claude/skills/notification-testing/` if it exists on develop-next; CLAUDE.md says to;
  it was missing on 10-06 — say so in IMPROVEMENTS if still missing).
- **Sentry probes** (ticket 15 of the Sentry spec): Developer/Tester role → debug console → the four probe buttons;
  acceptance = one event of each class in the dev project with the round's release tag, the Fault-after-Note carrying
  the breadcrumb, the edge probe in environment `edge-dev`.
- **Sentry leftovers** (one fix-style ticket, see § 4).
- **Coach mode** (coach portal at phone width was fixed in Sentry ticket 24a; coach/athlete linking, coach-on-athlete
  writes need remote ack per CLAUDE.md).
Each ticket lists its expected records (RevenueCat, dev DB) and its screens; `findings.mjs new` files Findings.

### 3. Waves
- Lead routine from the RUNBOOK ("The wave lead's routine"): one worktree per ticket, `.env*` copied, one simulator
  per ticket claimed up front (`SYNC simulator claim testing-wave-NN`, max three at once, `clear-app.sh` on each
  except leak tickets), one Opus agent per ticket with its own `<scratchpad>/testing-wave-NN/`, agents never build.
- Agents drive with the mobile MCP (taps) and idb (screen reads), keep the console in `runs/NN/`, redact tokens,
  file Findings with kind `bug | ssot-conflict | followup-test | idea`, delete their created accounts, release the
  lock, commit `findings/` + `runs/NN`.
- After each wave the lead merges, runs `FINDINGS index`, reads every notes file, and triages WITH LEE IN THE
  TERMINAL (never on the decisions page: testing stays off the SSOT): bug → fix ticket; ssot-conflict → review
  queue entry; followup-test → next wave; idea → IMPROVEMENTS or wontfix. One Finding, one decision.
- Fix waves: fix tickets grouped by area, one Opus agent each, analyze + their own test files only, lead runs the one
  full suite after merging, `/code-review` since the wave base, commit. A fix ticket closes when its retest passes on
  a simulator in the next wave (Lee's 09-28 "no more retests" ruling was for the mealplanning backlog; this round
  retests, because the point is to push a verified branch).

### 4. The Sentry leftovers ticket
Open as of 2026-10-06 (`curl /projects/milkman-24/<project>/issues/?query=is:unresolved&statsPeriod=` — use the
API, token in `~/.sentryclirc`; short-id → group id via `/organizations/milkman-24/shortids/<id>/`; latest event
at `/issues/<gid>/events/latest/`; resolve with `PUT {status: resolvedInNextRelease}` + a comment naming the sha):
- Prod (3, leave open, already commented): BP, C2 (Play pre-launch emulator), B7 (watchdog false positive).
- Dev (49). Groups:
  - **DEV-4** = legacy catch-all `PostgrestException` group (307 events: qa-seed uuid 26, `user_entitlements.
    entitlement` 12 — branch skew, gone once develop-next runs because the subscription code that queried it was
    meal planning, `duration_source` column 5 — dev DB lacked Xuan's column at the time: check it exists now,
    integrations FK 4, RLS 1). Action: confirm each sub-cause is either fixed on develop-next or a QA-seed artifact
    (review-queue entry for the QA repo, never a commit there), then resolve with that breakdown in the comment.
  - **Never ticketed (older):** DEV-47 (502), 6Y (activities upload 1/5), 82 (qa-seed uuid on integrations upload),
    4W/4B/8K (connection reset), 61/60 (database reset warnings, 09-14), 7K/87/7V (slow operation, old form),
    70/6W/85/84 (user cancelled login → Degraded `cancelled_sign_in`, confirm the allow-list matches the exact
    message), 6P/83 (504), 86 (null check), 7Z (Kroger `session_changed`; Kroger is not on develop-next — resolve
    as "not on this branch"), 7X/7Y/8A/8B (UnmountedRef on mealCatalog/vanaSettings — meal planning, not on this
    branch), 8D (AccountAlreadyExists → routing signal, Degraded).
  - **Carried from the Sentry triage, left open with reasons:** 5G, 5H, 7W (overflows: get the widget name from a
    Report-era event or resolve as stale), 9E (Vana chat scroll — meal planning, not on this branch), 9R/9G/9F/81/
    9W/A1 (mealplanning-only → "not on this branch", they belong to the mealplanning round), 7D (dev watchdog).
  - **Branch-era:** A2 (users RLS on upload), 8G (no user profile → onboarding first), 99 (carb loading day refresh),
    9H (Test Store simulated failure → Degraded `cancelled_purchase`-style reason), A6 (DriftRemoteException schema
    corrupted — likely a v21/v22 device; verify with the branch-split's Drift decision), AB (cooldown warning, by
    design: resolve-as-degraded with the note).
  - **By design, keep open or resolve with a note:** 8Y/8Z (AI cost warnings), 9B (retention sweep stale: check the
    cron monitor `raw-retention-sweep` check-ins; it was due 2026-10-07 03:17 UTC), A5/A7/A8/A9 (typed Degraded).
- Rule: every item ends in the ticket table as `resolve | resolve-as-degraded | leave-open: reason`, with root
  cause; code changes come with a test that was red first; "not on this branch" items get a line in
  `.scratch/branch-split/HANDOFF.md` so the mealplanning round picks them up.
- Also: fix or delete the known-red `test/shared/ci_config_contract_test.dart` ("push to develop runs dev tests":
  read `codemagic.yaml`; the test's expectation may be stale since the integration-test workflows were disarmed on
  2026-08-20 — if the contract is wrong, change the test, never re-arm a workflow).

### 5. Exit criteria (all must hold before Phase B)
- `findings/INDEX.md`: zero `open` Findings; every bug is `closed` (retest passed) or `wontfix` (Lee's ruling
  recorded in the Finding).
- Sentry dev project: `is:unresolved` returns nothing with `release:<round build>`; the leftovers ticket's table is
  fully actioned. Prod: only BP, C2, B7.
- Full suite green except nothing (the ci_config test fixed or deleted); analyze clean; source guard green.
- `IMPROVEMENTS.md` updated; `HANDOFF.md` in `.scratch/branch-split/` says "round-up green at <sha>".

## Testing Decisions
- A Finding is evidence: steps, expected, observed, console excerpt (redacted), screenshot path under `runs/NN/`.
- Fix tickets follow the repo's seam rules (`docs/test/README.md` § Seam tests): through the real notifier,
  producer-shaped data, `RecordingReport` for reporting assertions.
- Device verification by Claude via mobile MCP; never list a device check as owed to Lee except Lee's physical
  phone (Apple sandbox purchase, barcode camera, push taps).

## Out of Scope
- Anything under `lib/features/meal_planning`, Vana, Plans, Shopping, Kroger (mealplanning round, later).
- Prod deploys, prod `app_config`, pushing any branch (Phase B of the branch split does that).
- New features; onboarding body copy (Xuan's); activity-detail UI beyond real code bugs.

## Further Notes
- Simulator cap is three. Mac OOMs if Xcode/`flutter run` runs beside a full `flutter test`.
- `MACRO_DASHBOARD_ENABLED` removal is still pending (CLAUDE.md); do not add hide-flags.
- The dev build cut by Phase B's push is the first build with symbols upload and the new SDK; the round's local
  builds have no release health. That is fine for this round; `/release-cut` after Phase B.
