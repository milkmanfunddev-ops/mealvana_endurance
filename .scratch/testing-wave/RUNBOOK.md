# Testing-wave runbook

How one testing-wave ticket runs, start to finish. The rules behind it live elsewhere and are not
repeated here: read `.scratch/testing-wave/spec.md` (what a run checks, Findings, accounts, cost
caps, what is out of scope) and `CLAUDE.md` (repo rules, deploys, prod) before the first run.
Your ticket file lists the records it expects in RevenueCat and the dev database; step 1 writes
them down before you touch the app.

Names used below:

- `NN`: your ticket number, two digits. `OWNER` is `testing-wave-NN`.
- `WAVE`: the wave number on your ticket's Status line (`in-progress (wave N)`).
- `RUN`: `w<WAVE>-<UTC time>`, made once at the start: `echo "w$WAVE-$(date -u +%Y%m%dT%H%MZ)"`.
- `RUNS`: `.scratch/testing-wave/runs/NN/` in your worktree. Everything the run produces goes here.
- `LOCK`: `node scripts/testing-wave/lock.mjs`. `COST`: `node scripts/testing-wave/cost.mjs`.
  `FINDINGS`: `node scripts/testing-wave/findings.mjs`. `SYNC`: `node docs/ssot/decisions/_page/sync.mjs`.
- Credentials: `/Users/leemartin/development/mealvana_endurance/secrets/test_accounts.md`, always by
  that absolute path, from every worktree. Its shape is `scripts/testing-wave/test_accounts.template.md`.

Nothing gets fixed during a run. Every problem, clash or idea is a Finding (step 10).

## 1. Claim a slot

```
LOCK claim slot OWNER            # waits up to 90 min; exit 3 = still two runs going
```

Two runs at a time, whatever the simulator pool allows. Exit 3: report the ticket as not run.
Then `mkdir -p RUNS` and write `RUNS/expected.md`: the RevenueCat and database records the ticket
expects before and after, copied from its criteria. The run is judged against this file.

## 2. Claim a simulator

```
SYNC simulator claim OWNER --wait 90     # prints {udid, name, reused}
```

Use that `udid` and nothing else for the whole run. Exit 3 or no dev simulator booted: release the
slot and report the device check as not run.

## 3. Terminate the old app

```
xcrun simctl terminate <udid> com.milkman.mealvanaendurance.dev
```

Frees its memory before the build. "found nothing to terminate" is fine.

## 4. Take the build lock

```
LOCK claim build OWNER           # waits up to 45 min; one build on the Mac at a time
```

## 5. Run the dev debug build, console to the run folder

In the background (the Bash tool's `run_in_background`), from your worktree:

```
scripts/run_dev.sh -d <udid> > .scratch/testing-wave/runs/NN/console.log 2>&1
```

`run_dev.sh` is `flutter run` with the dev flavor and the dev entry point. Leave it running for the
whole run; the console is evidence.

## 6. Release the build lock once the app runs

As soon as `console.log` shows the app launched (`Flutter run key commands` or the first frame on
screen), and before driving anything:

```
LOCK release build OWNER
```

A build that fails: release the lock, write a bug Finding with the console excerpt, go to step 11.

## 7. Drive the app

- See and tap with the mobile MCP, on your `udid` only.
- Type text with idb: `idb ui text "<text>" --udid <udid>`. Passwords come from the credentials
  file; type them, never echo them into a Finding, commit or report.
- A new account signs up at `lee+e2e-NN-<UTC time>@rightpathprogramming.com`; read its code with
  the Gmail tool. Add its row to the credentials file's Created accounts table the moment signup
  succeeds (re-read the file first, append one row), and update its state as the run changes it.
- Before a step that generates a new Vana plan or makes an AI logging call, spend first:

  ```
  COST spend WAVE plan NN          # or: COST spend WAVE logging NN
  ```

  Exit 3 means the wave's cap is used up: skip the step and write a followup-test Finding for it.
  Everything else reuses the plans already on the dev accounts.
- Screenshots go in `RUNS` with names that say what they show.

## 8. Check RevenueCat and the dev database

Read, never write, unless your ticket's criteria name the write (a Grant, for example).

- RevenueCat: the v2 API with the secret key in `secrets/revenuecat.env` (main clone), or the
  RevenueCat MCP.
- Dev database: `SELECT` statements only, through the Management API `database/query` on the dev
  project, as `docs/deployment/supabase-deploy-playbook.md` describes.
- Edge-function logs for the functions the scenario touched: `scripts/edge_logs.sh`.

Both the SQL and the logs need a Management API token. Read it from the main clone without
printing it, once per shell:

```
export SUPABASE_PAT="$(sed -n 's/^SUPABASE_MANAGEMENT_TOKEN=//p' /Users/leemartin/development/mealvana_endurance/secrets/supabase_management_api.env)"
export SUPABASE_ACCESS_TOKEN="$SUPABASE_PAT"
```

Save each extract to `RUNS` (`revenuecat-<what>.json`, `db-<what>.txt`) and compare it with
`RUNS/expected.md`. Every mismatch is a Finding.

## 9. Look around on every screen

On each screen you visit, stop and list other paths through it (other buttons, back, swipe, empty
and error states, offline, a second tap) and other ways it could break. Each one is a
followup-test Finding naming the screen. Do not run them now; the next rounds pick from them.
Also read `console.log` after each screen: every error or exception line is a Finding or is noted
in `RUNS/notes.md` as known noise, with why.

## 10. Write Findings

One file each, made with:

```
FINDINGS new NN "<what happened, one line>" --kind bug|ssot-conflict|followup-test|idea --run RUN
```

It lands in `.scratch/testing-wave/findings/NN-<next number>-<slug>.md`, filled from `TEMPLATE.md`.
Fill in screen, steps, expected, actual and evidence (paths under `runs/NN/`, relative to
`.scratch/testing-wave/`). An ssot-conflict cites the decision id and quotes its Decision text from
`docs/ssot/decisions/`. Status stays `open`; triage moves it. Check your files parse:

```
FINDINGS index --out "$TMPDIR/testing-wave-index.md"   # exit 2 names a malformed Finding
```

Do not commit `INDEX.md`; the wave lead regenerates it after merging.

Keep going after a Finding. Stop only when a Finding makes the rest of the scenario meaningless
(the spec says when): say so in that Finding (`**Actual.**` ends with "Ticket stopped here:
<why>"), then mark the run stopped in `RUNS/STOPPED.md`: the Finding's file name, why, and the
step or criterion the retest resumes from. Go to step 11. A run with no `STOPPED.md` ran to the end.

## 11. Release everything

At the end of every run, stopped or not, in this order:

1. Delete the account you created through the app's delete-account flow (unless the ticket keeps
   it), and set its state in the credentials file (`deleted` or `delete-failed`).
2. Stop `flutter run` (kill the background task) and terminate the app on the simulator.
3. `SYNC simulator release <name>`
4. `LOCK release build OWNER` (harmless if already released), then `LOCK release slot OWNER`.
5. Scan the console before committing it: `grep -nE 'eyJ[A-Za-z0-9_-]{10,}|Bearer |sk_|sbp_' RUNS/console.log`.
   Any hit: delete `console.log` and commit `console-excerpts.log` with only the lines your
   Findings cite, the hits cut out.
6. Commit `.scratch/testing-wave/findings/NN-*.md` and `RUNS` on your branch, explicit paths only.

`LOCK list` shows what is still held. A claim left by a crashed agent is dropped on the next claim
once it is older than the stale timeout (slot 4 h, build 30 min).

## Before and after the wave (wave lead)

Before opening a wave, read `.scratch/testing-wave/IMPROVEMENTS.md`, the running list of ways to
make this loop better, and fix or raise one or two of its open items. After the review, append
what the wave taught (one entry per lesson) and move anything fixed to Done.

`FINDINGS index` writes `.scratch/testing-wave/findings/INDEX.md`, grouped by kind and status, and
exits 0 only when every Finding is closed or wontfix: that is the end of the loop. `COST status WAVE`
shows what the wave spent. Triage follows the spec's "Triage" section.
