---
name: testing-wave
description: Run one wave of a testing round as its lead. Agents drive the dev app on wave simulators, one Opus agent per ticket, and file Findings; the lead merges, triages with Lee in the terminal, runs fix waves, and closes the round into the ledgers. Invoked as "/testing-wave <round> [--only NN,..]", "run the next testing wave", "start a testing round".
---

# Testing wave (the lead)

You are the wave lead. Rules live in `docs/testing-wave/SPEC.md` and `docs/testing-wave/RUNBOOK.md`
("The wave lead's routine" is the authority for every step below; this skill is the order and the
mechanics). Read both, plus `docs/testing-wave/README.md` and `docs/testing-wave/IMPROVEMENTS.md`,
once per session. CLAUDE.md binds you and every agent; this skill repeats none of it.

Names: `ROUND` is `.scratch/testing-wave/rounds/<round>/` in the main clone, `FINDINGS` is
`node scripts/testing-wave/findings.mjs`, `SIM` is `node scripts/testing-wave/simulator.mjs`,
`LOCK` is `node scripts/testing-wave/lock.mjs`, `COST` is `node scripts/testing-wave/cost.mjs`.
Read each script's header for its current commands, caps and exit codes; never assume them.

You are the lead and run on the session's model. Every agent you spawn runs on Opus
(`model: "opus"`). You never drive a simulator yourself during a test wave.

## 1. Open the round

- No `ROUND`: `FINDINGS round new <round>`, then stop and tell Lee the round needs tickets in
  `ROUND/issues/` before a wave can run.
- Read every ticket in `ROUND/issues/`. The wave is the tickets whose Status says ready and whose
  blockers are done, cut to `--only NN,..` when given. Also cut it to the simulator cap in
  `simulator.mjs` and the slot count in `lock.mjs`; the rest wait for the next wave.
- Check `git log` and the wave log at the top of `ROUND/TRIAGE.md` for a wave another session left
  open. Never open a second wave on top of one; continue it at step 5 instead.
- Fix or raise one or two open `IMPROVEMENTS.md` items and commit them now, before any worktree:
  the worktrees branch from this commit.
- Fix tickets go to step 7, not here. A wave is either a test wave or a fix wave.

## 2. Build only if app code changed

```
git diff --name-only <sha in ROUND/app-build.json> HEAD -- lib pubspec.yaml pubspec.lock ios assets
```

Empty: no build. Anything listed: build once from a clean detached worktree at HEAD (never the main
clone) with `scripts/run_dev.sh -d <dev simulator udid>`, quit once the app runs, remove the
worktree, write the new sha to `ROUND/app-build.json`, commit it. No booted dev simulator: stop and
say so; a test wave cannot run without one.

## 3. Hand out simulators, worktrees, scratch folders

Then mark each wave ticket `in-progress (wave N, <date>)`, append the wave (number, base sha,
tickets, start time) to the wave log in `ROUND/TRIAGE.md`, and commit, so another session sees it.

For each ticket, before spawning anything:

1. `SIM claim testing-wave-NN`. It prints the simulator's name and udid. A claim that fails at the
   cap means the wave is too big; shrink it, never wait it out with agents half spawned.
2. `scripts/testing-wave/clear-app.sh <udid>`, unless the ticket tests leftover data.
3. `git worktree add -b testing-wave/<round>/NN ../mealvana_endurance-waves/testing-wave/<round>/NN-<slug> HEAD`
   from the main clone, then `cp .env* <worktree>/`.
4. `mkdir -p <scratchpad>/testing-wave-NN/`.

## 4. One agent per ticket

Read the code behind every screen the ticket visits before writing its prompt (RUNBOOK lead step 5
lists what a prompt must carry and why). Spawn all agents in one message so they run at once:
Agent tool, `subagent_type: "general-purpose"`, `model: "opus"`, `run_in_background: true`.

Each prompt carries, verbatim:

- The worktree path; every command runs there, never in the main clone. `ROUND` inside the worktree.
- `UDID`, the simulator's name, `SCRATCH` (`<scratchpad>/testing-wave-NN/`), the app's build sha,
  and whether the app data was cleared.
- The ticket's full text and the rules it cites, quoted from `docs/ssot/`.
- "Follow `docs/testing-wave/RUNBOOK.md` steps 1 to 9 exactly. It is the procedure; `SPEC.md` is the
  rules." Name the essentials so they cannot be skipped: no Patrol; credentials only through
  `cred.mjs` (`CRED list`; never open `secrets/test_accounts.md`); nothing fixed during the run;
  every problem a Finding (`FINDINGS new NN … --kind bug|ssot-conflict|followup-test|idea
  --round <round>`); spend with `COST` before any capped AI call; drive with the mobile MCP, read the
  screen with idb; console into `ROUND/runs/NN/`, redacted before commit; delete every account it
  created; release its slot (`LOCK release slot testing-wave-NN`) and its simulator (`SIM release
  <name>`); commit `ROUND/findings/NN-*` and `ROUND/runs/NN` on its branch.
- "No RevenueCat or database writes the ticket doesn't name, even on your own account."
- Shared-account notes when two tickets in the wave use one account (RUNBOOK lead step 5).
- What never happens: building the app, `git stash`, a push, a merge, any command in the main
  clone, touching another simulator or the dev simulator, writing to `docs/ssot/`.
- The report: branch and last commit, the Findings filed (file, kind, title), whether the run
  stopped (`STOPPED.md`) and where, leftover accounts, and the device-check status.

Wait for every agent. Do not merge while one runs.

## 5. Merge and close the wave

1. In the main clone, merge each wave branch in ticket order:
   `git merge --no-ff testing-wave/<round>/NN -m "testing-wave <round> wave N ticket NN [skip ci]"`.
   A test wave touches only `ROUND/findings/` and `ROUND/runs/`, so no codegen or suite.
2. `SIM list` and `LOCK list` show nothing held; release anything an agent left. Remove every wave
   simulator (the command is in `simulator.mjs`'s usage line), the worktrees and the merged branches.
3. Delete each run's "Leftover accounts" with `sweep-accounts.mjs delete --id <id> --apply`.
4. Read every `ROUND/runs/NN/notes.md` and file what nobody filed (RUNBOOK, after the wave, step 2).
   Pull one edge-log extract for the whole wave window and match each error to a run.
5. `FINDINGS index --round <round>`, then `COST status N`. Commit `INDEX.md` and the filed Findings.

## 6. Triage with Lee, in the terminal

One open Finding at a time, one decision each, asked with AskUserQuestion (recommended answer
first). Show the Finding's title, kind, actual, and evidence path. Rulings:

- `bug`: a fix ticket in `ROUND/issues/` (Touches lists every file it changes and every call site
  of a route it fixes), or `wontfix` with Lee's ruling written into the Finding.
- `ssot-conflict`: an entry in `.scratch/ssot/review-queue.md` in its format. Never write to the
  SSOT or a decisions page.
- `followup-test`: into the next wave's retest tickets (about ten checks each, grouped by screen,
  account and start state), or rewritten or closed when a run proved it impossible.
- `idea`: an `IMPROVEMENTS.md` entry (process ideas) or `wontfix`.

Write each ruling to `ROUND/TRIAGE.md` and the Finding's status line, then commit.

## 7. Fix waves

Follow RUNBOOK "Fix waves: keep them fast" in full. In short: fix tickets grouped by area, one Opus
agent each in its own worktree, no simulators; agents run `flutter analyze` and their own test files
only, at the repo's seams (`docs/test/README.md`); merge as they finish; then once, in the merge
tree: unfiltered codegen, analyze, the one full suite (the CI gate's command in
`docs/test/README.md`), `/mattpocock-skills:code-review` since the wave's base, fixes, commit. Dev
deploys once from the merged tree, SQL first. A red suite after one fix attempt stops the round:
end with `Next: /diagnosing-bugs`.

A fix ticket stays open until its retest passes on a simulator in the next test wave. Fixes touch
`lib/` or `ios/`, so that wave rebuilds (step 2).

## 8. Close

After each wave, append what it taught to `docs/testing-wave/IMPROVEMENTS.md` (date, round, status)
and mark fixed items done.

When `FINDINGS index --round <round>` exits 0 (every Finding closed or wontfix), the round is over:

```
FINDINGS ledger <round>
```

It appends the round's Findings to `docs/testing-wave/BUGS.md` and `COVERAGE.md`. Commit the
ledgers with explicit paths.

Report:

```
Wave N of <round>: tickets NN, NN; simulators S; Findings F (bug B, ssot-conflict C, followup-test T, idea I)
Triage: X fix tickets, Y queued, Z wontfix; open after triage: O
Next wave: test | fix, tickets NN, NN (or: round over, ledgers updated)
```

End with `Clear: yes` (one wave per session, RUNBOOK) and one `Next:` line naming the command.
