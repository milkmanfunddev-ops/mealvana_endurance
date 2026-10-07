# Testing wave: the rules

Moved from `mealplanning`'s `.scratch/testing-wave/spec.md` (written by `/to-spec` on 2026-09-23
from Lee's grilling session, changed by his rulings of 09-24 to 09-28). This file holds the rules
that hold on every branch. What a branch's app contains (its screens, its paywall, its integrations)
goes in a round's tickets, never here. `RUNBOOK.md` is the procedure; `CLAUDE.md` binds both.

## Why

Features get built across many waves, and each wave checks its own ticket. Nobody runs the app end
to end the way an athlete would. When a wave does check on a device, it checks the screen and rarely
checks that RevenueCat and the dev database agree with what the screen shows. A testing round does
that, writes down everything it finds in one place, and keeps going until nothing is open.

## The loop

1. A wave runs: one agent per ticket, each on its own simulator, driving the dev app.
2. Triage: Lee and the wave lead go through the open Findings in the terminal, one at a time.
3. A fix wave lands the fix tickets.
4. The next wave retests what the fixes touched, plus the follow-up tests triage chose.

The round ends when every Finding is `closed` or `wontfix`. `findings.mjs index` reports whether
that holds (exit 0).

## Runs

- **Real app, real dev backend.** Agents drive the dev flavor's debug build on an iOS simulator
  through the mobile MCP, and read the screen with idb. Nothing is faked. Nothing touches prod:
  not the prod project, prod RevenueCat, or prod `app_config`.
- **No Patrol** (Lee, 2026-09-24). Agents test by driving the app. They neither write nor run Patrol
  flows, whatever an older ticket says.
- **Agents never build.** The wave lead builds the testing app once, and only when `lib/`,
  `pubspec*`, `ios/` or `assets/` changed since the commit in the round's `app-build.json`
  (Lee, 2026-09-24). Builds go through `scripts/run_dev.sh` from a clean worktree, never
  `flutter build`.
- **One simulator per ticket, at most three at once** (Lee, 2026-09-15: the Mac cannot carry more).
  The lead claims them with `scripts/testing-wave/simulator.mjs` before spawning. Each is a copy of
  the dev simulator, so it carries the testing build. The lead empties the app's data with
  `scripts/testing-wave/clear-app.sh` on each, except for a ticket that tests leftover data. The dev
  simulator itself is never a wave simulator.
- **One run slot per agent.** Each run holds a slot in `scripts/testing-wave/lock.mjs` for its whole
  scenario; the slot count is set there. No full unit-test run while a test wave is live: the
  simulators and the suite do not fit in memory together.
- **What a run checks.** What the screen shows, what RevenueCat holds, what the dev database holds,
  and what the console printed. Never how the app is built inside. Each ticket writes its expected
  external records down before the run, so pass or fail is judged against something fixed in
  advance.
- **Reads, not writes.** RevenueCat through its v2 API or MCP, the dev database through read-only
  SQL over the Management API, edge-function logs for the functions the scenario touched. No write
  the ticket does not name, even on the run's own account. A browser only for what the APIs cannot
  show.

## Findings, not fixes

- No agent fixes anything during a run, simple or complex. Every problem is a Finding.
- A Finding is one file in the round's `findings/`, made by `findings.mjs new`, so two agents never
  write the same file. It records: kind, status, ticket, run, screen, steps, expected, actual,
  evidence (paths under the run folder), and for an `ssot-conflict` the rule it breaks and its
  quoted text.
- Kinds: `bug`, `ssot-conflict` (the app contradicts a decision or a spec under `docs/ssot/`),
  `followup-test` (another path or failure worth testing), `idea` (a change to the app or the
  process).
- Statuses: `open` (what agents write), `triaged`, `fixing`, `closed`, `wontfix`. Only triage and
  retests move them.
- An `ssot-conflict` cites a decision id, or a spec reference `docs/ssot/spec/<path>.md#<heading>`,
  and quotes its text word for word. `findings.mjs index` checks that the file, the heading and the
  quote exist.
- An agent keeps going after a Finding. It stops only when a Finding makes the rest of the scenario
  meaningless, and says so in that Finding and in `runs/NN/STOPPED.md`. A failed account delete is
  always a stop.
- **Look around on every screen.** On each screen visited, the agent lists other paths through it
  and other ways it could break. Each one is a `followup-test` Finding. This is how the round's
  scenario list grows.

## Accounts and credentials

- New accounts sign up at plus addresses on Lee's work mailbox, one per ticket and run
  (`lee+e2e-NN-<UTC time>@rightpathprogramming.com`). Agents read signup and reset codes from that
  mailbox with the Gmail tool.
- One gitignored file in the main clone, `secrets/test_accounts.md`, holds the dev admin, the shared
  test logins and every account a run created. Agents reach it only through
  `scripts/testing-wave/cred.mjs`, which never prints a password. Nobody opens that file in any
  way; `CRED list` shows addresses and states. Agents type these passwords themselves. This applies
  to this repo only; the QA repo's rule that Claude never enters a password is unchanged.
- Every account a run creates gets a row (`CRED new`), and the run keeps its state current
  (`CRED update`).
- Each run deletes the accounts it created through the app's own delete-account flow, so deletion
  is tested every time. `scripts/testing-wave/sweep-accounts.mjs` removes leftovers on dev.
- A start state a check needs is written on the run's own account, through the app or a seed script
  the ticket names, never planned on another run's account, which that run deletes.

## Cost caps

AI calls cost real money, so each wave caps them across all agents: at most three new Vana plans,
five AI logging calls and five Vana chat calls (an opener, or a turn that is not a plan).
`scripts/testing-wave/cost.mjs` enforces the caps and holds the numbers. An agent spends before the
step, never after. When the cap refuses, the agent skips the step and writes a `followup-test`
Finding for it. A kind with no matching feature on the branch is never spent.

## Triage

In the terminal with Lee after each wave, one Finding at a time, one decision each (Lee,
2026-09-24: testing stays off the SSOT):

- `bug` becomes a fix ticket in the round's `issues/`, or `wontfix` with Lee's ruling written into
  the Finding.
- `ssot-conflict` becomes an entry in the review queue (`.scratch/ssot/review-queue.md`). The
  testing wave writes nothing to the SSOT or a decisions page.
- `followup-test` goes into the next wave's retest tickets, or is rewritten or closed when a run
  proved it impossible as written.
- `idea` goes to `IMPROVEMENTS.md` (a process idea) or becomes `wontfix`.

A retest ticket holds about ten checks, grouped by screen and by the account and start state they
need; more checks make more tickets (Lee, 2026-09-25: long runs degrade the agent's context).

A Finding closes only when a retest on a simulator passes. A fix ticket closes the same way.

## Fix waves

Fix tickets carry no simulator scenario. They are grouped by area, one agent each, and follow the
repo's seam rules (`docs/test/README.md`, Seam tests). Agents run only their own test files and
`flutter analyze`. The lead merges, runs the one full suite, reviews and commits. `RUNBOOK.md`,
"Fix waves", has the detail.

## Out of scope

- Prod: no test touches it.
- Fixing bugs during a test wave.
- Android (the simulators are iOS; a later round can add it).
- Load and performance testing.
- Changing the QA repo or its skills.
- Adding or re-arming a Codemagic workflow.
