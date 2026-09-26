# Autorun: waves back to back in one session (Lee, 2026-09-26)

Lee starts this with `/clear` and then `/loop /implement-lee testing-wave`. Each loop iteration runs
one wave through `/implement-lee` and the RUNBOOK's wave lead's routine, then schedules the next
iteration at once. Lee is not watching, so do not ask him anything mid-run. Anything that needs
him becomes a Finding, a note in the ticket, or a line in the final report. For this run, Lee's rule
of 2026-09-26 replaces the RUNBOOK's "one wave per session, cleared between waves".

## Order

1. **Harness first.** The wave lead does ticket 142 itself (it is harness work, not a wave agent's)
   and commits it before the first `wave --open`, so the worktrees branch from it.
2. **Fix waves.** Tickets 133 to 141, **three per wave** (`--max 3`), in the order the frontier gives.
   The RUNBOOK's "Fix waves: keep them fast" applies: agents run only their own tests, the lead
   runs one suite per wave.
3. **Dev deploys, without asking.** After each fix wave merges, deploy the edge functions, apply
   the migrations and run the dev SQL its tickets name, on DEV (`vlmtsdzpnjnavdgytcmi`) only,
   following `docs/deployment/supabase-deploy-playbook.md`. Never touch prod, prod `app_config`, or
   prod RevenueCat.
4. **Rebuild the testing app** once, after the last fix wave (RUNBOOK "Before the wave" step 2,
   one build at a time, never `flutter build`), and write the commit to `app-build.json`.
5. **Write the retest tickets.** Each re-runs the `triaged` Findings of fix tickets 133 to 141 plus
   the follow-up tests folded in on 2026-09-26 (`triage-20260926.md`), grouped by screen and
   account, about ten checks a ticket. Add Lee's check that deleting an older, replaced plan
   from Previous plans works. Leave out Findings held for Xuan (112-009, 116-009, 117-003).
6. **Retest waves**, **two per wave** (simulator cap), until every retest ticket is done.

## Stop

Stop the loop (`ScheduleWakeup` with `stop: true`) when any of these holds:
- **Done:** every retest ticket is done, and the only open Findings are ones the retests just
  wrote, waiting for Lee's triage.
- **Red suite:** the suite stays red after the lead's fix attempt, per `/implement-lee`.
- **Stuck:** the same ticket has failed in two waves.
- **No device:** the dev simulator or the testing app can't be brought up for the retests.

Then push `mealplanning` once, with `GIT_ASKPASS` running `gh auth token --user lbm54` (see HANDOFF
Gotchas; delete the script afterwards). End with a report: waves run, tickets merged or failed,
what was deployed to dev, new Findings by kind, anything left for Lee.

## Every iteration

- Check `git log` and `waves.json` for a wave another session opened. Never open a second wave on top of it.
- Commit with explicit paths, never `-a`, and never `git stash`. Leave nothing uncommitted in the
  main clone at the end of an iteration.
- Close each wave with `SYNC wave … --close`, so the next iteration's frontier is correct.
