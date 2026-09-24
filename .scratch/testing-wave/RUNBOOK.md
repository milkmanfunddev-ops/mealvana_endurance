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
- `SCRATCH`: the scratch folder your prompt names, one per ticket (`<scratchpad>/testing-wave-NN/`).
  Helper scripts and temporary files go there and nowhere else; never read or run another ticket's.
- `UDID`: the simulator your prompt names. The wave lead made it for you with the app already
  installed; it is yours for the whole run and nothing else is.

Nothing gets fixed during a run. Every problem, clash or idea is a Finding (step 10).

No Patrol (Lee, 2026-09-24). You test by driving the app yourself; you do not write or run
Patrol flows, whatever an older ticket says.

Never print a secret: no `cat`, `tail` or `bash -x` on anything that reads `secrets/`, `.env*` or
the credentials file. Read a value into a variable without echoing it.

## 1. Claim a slot

```
LOCK claim slot OWNER            # waits up to 90 min; exit 3 = still two runs going
```

Two runs at a time. Exit 3: report the ticket as not run. Then `mkdir -p RUNS` and write
`RUNS/expected.md`: the RevenueCat and database records the ticket expects before and after,
copied from its criteria. The run is judged against this file.

## 2. Your simulator and the app on it

The wave lead gave you `UDID` with the dev app installed, built from the commit named in your
prompt (`.scratch/testing-wave/app-build.json`). Write that commit in `RUNS/notes.md`: every
Finding ties to it. You do not build the app. If the app on `UDID` is missing or will not launch,
write a bug Finding and report the device check as not run.

Your worktree has every `.env` file the main clone has (the wave lead copied them). Use the dev
ones; nothing in a run touches prod.

## 3. Launch it with the console going to the run folder

```
xcrun simctl terminate UDID com.milkman.mealvanaendurance.dev
xcrun simctl spawn UDID log stream --level debug \
  --predicate 'process == "Runner"' > RUNS/console.log 2>&1 &     # background; the console is evidence
xcrun simctl launch UDID com.milkman.mealvanaendurance.dev
```

Stop the log stream at step 11.

## 4. Start from what is on the screen

Look first (the mobile MCP's screenshot and element list). The simulator opens in whatever state
the dev simulator was in when it was copied: usually signed in as the entitled dev test account,
with its plans and logs. Do only the setup your ticket needs. Signed out and your ticket uses the
dev test account: log in with it from the credentials file. A ticket about signup or purchase signs
out and makes its own account. Never reinstall
or wipe the app unless the ticket says so.

## 5. Drive the app

- See and tap with the mobile MCP, on `UDID` only. It works on wave simulators (the wave lead's
  simulator setup installs its helper app). idb is the fallback: `idb ui describe-all --udid UDID`,
  `idb ui tap X Y --udid UDID`.
- Type text with the MCP or `idb ui text "<text>" --udid UDID`. Passwords come from the credentials
  file; type them, never echo them into a Finding, commit or report.
- A new account signs up at `lee+e2e-NN-<UTC time>@rightpathprogramming.com`. Dev asks for the
  6-digit code we email (since 2026-09-24): read it with the Gmail tool
  (`to:lee+e2e-NN-… from:support@mealvana.io`, newest first), type it into the app. Add the
  account's row to the credentials file's Created accounts table the moment signup succeeds
  (re-read the file first, append one row), and update its state as the run changes it.
- Before a step that generates a new Vana plan or makes an AI logging call, spend first:

  ```
  COST spend WAVE plan NN          # or: COST spend WAVE logging NN
  ```

  Exit 3 means the wave's cap is used up: skip the step and write a followup-test Finding for it.
  Everything else reuses the plans already on the dev accounts.
- Screenshots go in `RUNS` with names that say what they show.
- A step that must be seen live (a renewal, a lapse, a timer): write the clock time before and
  after every wait in `RUNS/notes.md`. When the gap is longer than planned, write "not seen live"
  next to the step and say how it was checked instead.

## 6. Check RevenueCat and the dev database

Read, never write, unless your ticket's criteria name the write (a Grant, for example).

- RevenueCat: the v2 API with the secret key in `secrets/revenuecat.env` (main clone), or the
  RevenueCat MCP.
- Dev database: `SELECT` statements only, through the Management API `database/query` on the dev
  project, as `docs/deployment/supabase-deploy-playbook.md` describes.
- Edge-function logs for the functions the scenario touched: `scripts/edge_logs.sh` (`-s
  function_edge_logs` for request lines). It exits 1 on any answer that is not rows, so "(no rows
  in window)" really means none.

Both the SQL and the logs need a Management API token. Read it from the main clone without
printing it, once per shell:

```
export SUPABASE_PAT="$(sed -n 's/^SUPABASE_MANAGEMENT_TOKEN=//p' /Users/leemartin/development/mealvana_endurance/secrets/supabase_management_api.env)"
export SUPABASE_ACCESS_TOKEN="$SUPABASE_PAT"
```

Save each extract to `RUNS` (`revenuecat-<what>.json`, `db-<what>.txt`) and compare it with
`RUNS/expected.md`. Every mismatch is a Finding.

Code fixtures for the redeem scenarios (dev only, never written by hand):
`node scripts/testing-wave/seed-codes.mjs seed` resets the `E2E*` codes (a once-in-total giveaway,
a many-use giveaway, an influencer code, an expired one, a not-yet-valid one and a used-up one) and
clears their redemptions; `seed-codes.mjs list` shows them with their counts. For the coach's own
code, sign up first, then `seed-codes.mjs own <your account's user id>` prints a coach code your
account owns; it is deleted with the account. Run `seed` at the start of a redeem run, since an
earlier run may have spent the once-in-total giveaway.

## 7. Look around on every screen

On each screen you visit, stop and list other paths through it (other buttons, back, swipe, empty
and error states, offline, a second tap) and other ways it could break. Each one is a
followup-test Finding naming the screen. Do not run them now; the next rounds pick from them.
Also read `console.log` after each screen: every error or exception line is a Finding or is noted
in `RUNS/notes.md` as known noise, with why.

Anything unexpected you write in `RUNS/notes.md` is also a Finding, or carries "known noise:
<why>" beside it. The wave lead reads every notes file at the close and files what you did not.

## 8. Write Findings

One file each, made with:

```
FINDINGS new NN "<what happened, one line>" --kind bug|ssot-conflict|followup-test|idea --run RUN
```

It lands in `.scratch/testing-wave/findings/NN-<next number>-<slug>.md`, filled from `TEMPLATE.md`.
Fill in screen, steps, expected, actual and evidence (paths under `runs/NN/`, relative to
`.scratch/testing-wave/`, first word of each Evidence bullet). An ssot-conflict cites the decision
id and quotes its Decision text word for word from `docs/ssot/decisions/`. Status stays `open`;
triage moves it. Check your files parse and their evidence exists:

```
FINDINGS index --out "$TMPDIR/testing-wave-index.md"   # exit 2 names a malformed Finding or a missing evidence file
```

Do not commit `INDEX.md`; the wave lead regenerates it after merging.

Keep going after a Finding. Stop only when a Finding makes the rest of the scenario meaningless
(the spec says when): say so in that Finding (`**Actual.**` ends with "Ticket stopped here:
<why>"), then mark the run stopped in `RUNS/STOPPED.md`: the Finding's file name, why, and the
step or criterion the retest resumes from. Go to step 9. A run with no `STOPPED.md` ran to the end.

## 9. Release everything

At the end of every run, stopped or not, in this order:

1. Delete the account you created through the app's delete-account flow (unless the ticket keeps
   it), and set its state in the credentials file (`deleted` or `delete-failed`).
2. Stop the log stream and terminate the app on the simulator.
3. `LOCK release slot OWNER`. The simulator stays; the wave lead deletes it at the close.
4. Scan the console before committing it: `grep -nE 'eyJ[A-Za-z0-9_-]{10,}|Bearer |sk_|sbp_' RUNS/console.log`.
   Any hit: delete `console.log` and commit `console-excerpts.log` with only the lines your
   Findings cite, the hits cut out.
5. Commit `.scratch/testing-wave/findings/NN-*.md` and `RUNS` on your branch, explicit paths only.
   Run logs under `RUNS` are not gitignored (the Findings cite them), so a plain `git add` takes
   them after the scan.

`LOCK list` shows what is still held. A claim left by a crashed agent is dropped on the next claim
once it is older than the stale timeout (4 h).

## The wave lead's routine

The testing wave never writes to the decisions page (Lee, 2026-09-24): no ticket cards, no
proposals, no pictures, no page reseed. Questions about testing itself are settled with Lee in
the terminal. A Finding that raises a real product question (paywall, meal planning, how the app
should behave) goes to the page as an open question, the normal way, and nothing else does.

**Before the wave.**

1. Read `.scratch/testing-wave/IMPROVEMENTS.md`; fix or raise one or two open items.
2. The app. `.scratch/testing-wave/app-build.json` names the commit the testing app was built from.
   `git diff --name-only <that commit> <base> -- lib pubspec.yaml pubspec.lock ios assets` empty:
   no build. Anything listed: build once from a clean worktree at the base (never the main clone,
   which carries other sessions' unfinished edits): `scripts/run_dev.sh -d <first wave simulator>`,
   quit it once the app runs, `xcrun simctl install` the same `build/ios/iphonesimulator/Runner.app`
   on the other wave simulator, and write the base commit to `app-build.json`. Agents never build.
3. One simulator per ticket: `SYNC simulator claim testing-wave-NN` for each, before spawning. It
   copies the dev simulator's app, signed-in data and the mobile MCP helper. Install the freshly
   built app on each when step 2 built one. The name and udid go in the ticket's prompt.
4. One worktree per ticket (`git worktree add`), then copy every `.env*` file from the main clone
   into it (`cp .env* <worktree>/`), and make the ticket's scratch folder.
5. The prompt names the worktree, `UDID`, `SCRATCH`, the app's commit, the ticket's full text and
   its cited decisions, and points at this runbook.

**After the wave.**

1. Merge in ticket order, run `flutter analyze` and the CI suite command.
2. Read every ticket's `RUNS/notes.md` for surprises with no Finding and no "known noise", and file
   them (`FINDINGS new …`), noting "filed by the wave lead" in Actual.
3. `FINDINGS index` (writes `INDEX.md`; exit 0 only when every Finding is closed or wontfix: the end
   of the loop). `COST status WAVE` shows what the wave spent. Triage follows the spec's "Triage".
4. `SYNC simulator drop <name>` for every wave simulator; `wave --close`; remove the worktrees.
5. Append what the wave taught to `IMPROVEMENTS.md` and move anything fixed to Done.
