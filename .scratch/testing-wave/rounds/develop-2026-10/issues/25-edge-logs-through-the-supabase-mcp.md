# 25: Edge-function logs through the Supabase MCP; delete `scripts/edge_logs.sh`

**Status:** done 2026-10-08: wave 3's three runs and the lead's wave extract all read edge logs through the Supabase MCP
**Labels:** fix, round:develop-2026-10, area:harness
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** none (no code overlap)
**Next:** `/testing-wave develop-2026-10` (fix wave)
**Model:** opus

**What to build:** Lee ruled (TRIAGE 02-004, 01-013, 2026-10-07) that edge-function logs are read through the
Supabase MCP's `query_logs` from now on, and `scripts/edge_logs.sh` is deleted so nothing passes silently
again. The script calls `/v1/projects/<ref>/analytics/endpoints/logs.all`, which Supabase removed; its
formatter reads the "endpoint has been removed" answer as zero rows and exits 0. Every caller moves to the
MCP. From code at `f2e8576e`.

Background: mealplanning repaired its copy of the script in `383a2753` (IMPROVEMENTS #5, 2026-09-24). That
commit is not on develop-next and is not backported: the ruling is to delete, not repair.

The SQL every caller uses (verified 2026-10-07 against dev `vlmtsdzpnjnavdgytcmi` with `query_logs`, window
11:08Z to 11:40Z, which returned the delete-user request line and its console lines). These are the queries
behind `runs/wave-1-edge-logs.txt` and the 02-004 helper (`select … from logs where source = …`, fields under
`log_attributes[…]`):

```sql
-- Request lines (one per call: method, status, URL, duration)
select timestamp, event_message,
       log_attributes['response.status_code'] as status,
       log_attributes['execution_time_ms']    as ms
from logs
where source = 'function_edge_logs'
  and log_attributes['request.pathname'] = '/functions/v1/garmin-push'   -- drop to see every function
order by timestamp desc
limit 200

-- Console lines (console.log / warn / error). function_logs rows carry no function name, only
-- function_id, so pick the function through its request lines:
select timestamp, log_attributes['level'] as level, event_message
from logs
where source = 'function_logs'
  and log_attributes['function_id'] in (
    select log_attributes['function_id'] from logs
    where source = 'function_edge_logs'
      and log_attributes['request.pathname'] = '/functions/v1/garmin-push')
  -- and event_message like '%OneSignal notification sent%'
order by timestamp desc
limit 300
```

Call it as `query_logs(project_id = <ref>, sql = …, iso_timestamp_start = …Z, iso_timestamp_end = …Z)`. The
window is at most 24 h. Without one, the tool defaults to the last 24 h. Dev ref `vlmtsdzpnjnavdgytcmi`, prod
`wvmvsodrvbkxfydabqed`. An empty `result` array is a real "none" only when the same window returns rows for
`select count() from logs where source = 'function_edge_logs'`. If that count is 0, say "could not read logs"
and don't report "no rows".

1. **Delete the script (02-004, 01-013).** `git rm scripts/edge_logs.sh` (120 lines). Nothing in `lib/`,
   `test/`, `.github/`, `codemagic.yaml` or `.claude/` calls it (grep `edge_logs` at `f2e8576e`: only the files
   below).
2. **`scripts/test_activity_push.sh:29` and `:133`.** Both lines tell the person who sent the test push to run
   `./scripts/edge_logs.sh -m 5 garmin-push`. Replace each with a note: "Edge logs: from a Claude session, the
   Supabase MCP `query_logs` on the project (dev `vlmtsdzpnjnavdgytcmi`, prod `wvmvsodrvbkxfydabqed`), console
   lines of garmin-push for the last 5 minutes. SQL in `docs/integration/garmin_push_copy_rollout.md`." Keep
   the `Expect: "OneSignal notification sent for activity <id>"` and the `[mixpanel] … missing` hint under it.
   **Choice: the MCP note, not a `curl` on `/analytics/endpoints/logs`.** A curl block inside the script is the
   same thing that broke here: a hand-rolled HTTP call whose failure answer can read as "no rows". It also needs
   the Management PAT exported in that shell. The script already hands this step to a person or a session
   ("After it returns, verify"), so pointing at the MCP adds no new dependency.
3. **`docs/integration/garmin_push_copy_rollout.md:23` and `:124`.** Replace both `./scripts/edge_logs.sh -m 5
   garmin-push` references with "the Supabase MCP `query_logs`, garmin-push console lines, last 5 minutes".
   Add the console-lines SQL above once, with the `event_message like '%OneSignal notification sent%'` filter
   switched on, so `recipients=N` (line 24) and the `OneSignal notification sent for activity <id>` check
   (line 124) read straight off it.
4. **`scripts/testing-wave/findings.mjs:101`.** Only a doc-comment example of an Evidence path
   (`scripts/edge_logs.sh`) in `evidencePaths`. Swap it for `runs/02/edge-requests.txt` so the comment doesn't
   name a deleted file. No behaviour change.
5. **Round tickets that still name the script.** `ROUND/issues/02-logging-a-meal-by-describing-it.md:62` (step
   5) and `ROUND/issues/14-a-dead-garmin-token-and-the-trainingpeaks-edit-window.md:77` (step 4): replace
   `scripts/edge_logs.sh` (and 14's `-s function_edge_logs`) with "the Supabase MCP `query_logs`, per RUNBOOK
   step 6" (request lines for 14's 409, console lines for 02's describe-meal). 02 is in progress from wave 1:
   edit only the step text, not its Status. 14 has not run yet.
6. **Leave alone.** `docs/testing-wave/RUNBOOK.md:172-177` (the lead already switched step 6 to `query_logs`).
   `docs/testing-wave/IMPROVEMENTS.md:54`, `:382` and `docs/testing-wave/BUGS.md:31` are ledgers and stay as
   history. Run evidence under `ROUND/runs/` and the Findings stay as they are.

**Findings:** 02-004, 01-013.

**Decisions:** Lee, 2026-10-07 (TRIAGE): logs through the MCP `query_logs`, script deleted. Shell callers get
an MCP note, not a curl (item 2, reason given there).

**Touches:** scripts/edge_logs.sh (deleted), scripts/test_activity_push.sh,
docs/integration/garmin_push_copy_rollout.md, scripts/testing-wave/findings.mjs (comment only),
.scratch/testing-wave/rounds/develop-2026-10/issues/02-logging-a-meal-by-describing-it.md,
.scratch/testing-wave/rounds/develop-2026-10/issues/14-a-dead-garmin-token-and-the-trainingpeaks-edit-window.md

**Overlaps:** none of 21–29 (no shared file).

- [ ] `grep -rn edge_logs.sh scripts docs .claude supabase lib test` returns only the ledger lines
      (IMPROVEMENTS, BUGS) and RUNBOOK's "is gone (#102)" sentence.
- [ ] `bash -n scripts/test_activity_push.sh` passes.
- [ ] Both SQL blocks in the rollout doc are run once through `query_logs` on dev, over a window holding a
      garmin-push call, and return rows. Paste the row count into the commit body.
- [ ] No Node test: `findings.mjs` changes only in a comment, and develop-next has no findings.mjs test file.

**Lead note (2026-10-07):** the "return rows" box is accepted as a real zero: no push was sent that day, so an empty result was right.
