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
- `CRED`: `node scripts/testing-wave/cred.mjs`, the only way to the credentials
  (`/Users/leemartin/development/mealvana_endurance/secrets/test_accounts.md`). Never open that file
  in any way; its shape is `scripts/testing-wave/test_accounts.template.md`, and `CRED list` shows
  addresses and states. `CRED type <email> --udid UDID` types a password into the focused field,
  `CRED file <email> SCRATCH/<name>` saves one (mode 600) for an API check, `CRED new` and
  `CRED update` add and change Created accounts rows. None of them prints a password.
- `SCRATCH`: the scratch folder your prompt names, one per ticket (`<scratchpad>/testing-wave-NN/`).
  Helper scripts and temporary files go there and nowhere else; never read or run another ticket's.
- `UDID`: the simulator your prompt names. The wave lead made it for you with the app already
  installed; it is yours for the whole run and nothing else is.

Nothing gets fixed during a run. Every problem, clash or idea is a Finding (step 10).

No Patrol (Lee, 2026-09-24). You test by driving the app yourself; you do not write or run
Patrol flows, whatever an older ticket says.

Never print a secret: no `cat`, `tail` or `bash -x` on anything that reads `secrets/` or `.env*`,
and no read of the credentials file except through `CRED`. Read a value into a variable without
echoing it.

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
echo $! > SCRATCH/logstream.pid                                   # stop this PID only, never pkill
xcrun simctl launch UDID com.milkman.mealvanaendurance.dev
```

`simctl launch` can leave SpringBoard in front. Take a screenshot; if the home screen shows,
launch again with the mobile MCP (`mobile_launch_app`) or tap the app's icon.

The mobile MCP's first command on a fresh simulator can bring its helper app to the front and
send the app to the background (IMPROVEMENTS #50). Make one harmless MCP call first (a
`mobile_take_screenshot`), then take a `simctl io` screenshot; if the home screen shows, `simctl
launch` again (the app keeps its state) before the first tap.

Stop the log stream at step 9.

## 4. Start from what is on the screen

Look first (a `simctl io` screenshot and `idb ui describe-all`). The wave lead cleared the app's data,
so it opens signed out on Welcome with an empty local database, unless your prompt says the
ticket tests the dev simulator's leftover data. Do only the setup your ticket needs: a ticket on
the dev test account logs in with it (`CRED type test@test.com --udid UDID` for the password); a
ticket about signup or purchase makes its own account. Never reinstall or wipe the app unless the
ticket says so.

## 5. Drive the app

- Read the screen with idb: `idb ui describe-all --udid UDID` for the element list, `xcrun simctl io
  UDID screenshot` for the picture. With two wave simulators up, the mobile MCP's element list has
  returned the other simulator's screen (IMPROVEMENTS #39), so never trust it for what is on
  `UDID`. Tap and type with the mobile MCP on `UDID`; `idb ui tap X Y --udid UDID` is the fallback.
- Scroll with slow idb drags (`idb ui swipe X1 Y1 X2 Y2 --duration 1.2 --udid UDID`) whenever the
  run counts rows or chat turns: the mobile MCP's swipe flings past them (IMPROVEMENTS #43).
- Type text with the mobile MCP; `idb ui text "<text>" --udid UDID` is the fallback (it once
  mangled a long address, IMPROVEMENTS #35). Before submitting a long value (an address, a code),
  read it back with `idb ui describe-all --udid UDID`: a field shows only the tail of a long value.
  Passwords go in with `CRED type`, never by hand and never into a Finding, commit or report.
- A new account signs up at `lee+e2e-NN-<UTC time>@rightpathprogramming.com`. Dev asks for the
  6-digit code we email (since 2026-09-24): read it with the Gmail tool
  (`to:lee+e2e-NN-… from:support@mealvana.io`, newest first), type it into the app. Before
  signup, `CRED new <address> --ticket NN --run RUN` makes the password and adds the row (state
  `new`); type it with `CRED type`. Change the row as the run changes the account (`CRED update
  <address> --state paid --bought monthly --when <UTC>`; `--new-password` for a reset, after
  `CRED file` has kept the old one if the run still checks it).
- Before a step that generates a new Vana plan, makes an AI logging call or opens a Vana chat
  (Ask Vana's opener or a chat turn that is not a plan, the only way to Conversations), spend first:

  ```
  COST spend WAVE plan NN          # or: COST spend WAVE logging NN, COST spend WAVE chat NN
  ```

  Exit 3 means the wave's cap is used up: skip the step and write a followup-test Finding for it.
  Everything else reuses the plans already on the dev accounts. An old planning conversation
  opens with no opener and makes no model call; note in `RUNS/notes.md` when a `chat` spend
  bought nothing (no `vana_calls` row in your run's minutes), so the lead can count it back.
- To reach an old conversation (confirm a draft, read its Review sheet) open it by deep link,
  which makes no model call and needs no spend: `xcrun simctl openurl UDID
  "com.milkman.mealvanaendurance:///vana?c=<conversation id>"` (#81). Keep clear of the floating
  Ask Vana button; a stray tap on it opens a new chat and spends.
- A Test Store purchase on dev renews only while the app is signed in: a monthly renews every
  5 minutes and lapses about 5 minutes after sign-out; an Annual has 1-hour periods. A run that
  needs Pro without the paywall coming back buys Annual; a run that needs a lapse buys monthly
  and signs out (#80).
- Screenshots go in `RUNS` with names that say what they show. Take them with
  `xcrun simctl io UDID screenshot RUNS/<name>.png`: the mobile MCP's `save_screenshot` refuses
  paths inside the worktree. After a tap, take a new screenshot before trusting the MCP's element
  list; it has returned the previous screen.
- A web sign-in sheet (Kroger, TrainingPeaks, Garmin) runs out of process: neither the MCP nor
  `idb ui describe-all` lists its fields (IMPROVEMENTS #51). Drive it by coordinate taps read
  off `simctl io` screenshots, one screenshot after every tap, and type with the mobile MCP
  (`CRED type` for the password once the field is focused).
- Offline for your app only: `scripts/testing-wave/netcut/netcut.sh launch UDID SCRATCH` relaunches
  the app with a connect-blocking library injected (network still on); `netcut.sh on SCRATCH` cuts
  it and `netcut.sh off SCRATCH` restores it, no relaunch. A plain `on` blocks new connects only:
  a connection the app opened before the cut stays up, so the first offline tap can still reach
  the server (#74). Before an offline check, cut with `netcut.sh on SCRATCH --relaunch UDID`,
  which relaunches the app with the cut already in force. The host and other simulators keep their
  network. Blocked connects are logged to `SCRATCH/netcut.log`. The app's connectivity check still
  reads "online", so its offline banner needs a device (20-006). Start the log stream first
  (step 3), since `launch` replaces the plain `simctl launch`.
- A step that must be seen live (a renewal, a lapse, a timer): write the clock time before and
  after every wait in `RUNS/notes.md`. When the gap is longer than planned, write "not seen live"
  next to the step and say how it was checked instead.

## 6. Check RevenueCat and the dev database

Read, never write, unless your ticket's criteria name the write (a Grant, for example).

- RevenueCat: the v2 API with the secret key in `secrets/revenuecat.env` (main clone), or the
  RevenueCat MCP.
- Dev database: `SELECT` statements only, through the Management API `database/query` on the dev
  project, as `docs/deployment/supabase-deploy-playbook.md` describes.
  Name the columns, never `SELECT *`: `integrations` holds live access and refresh tokens, and
  a star prints them into your transcript (#85).
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
in `RUNS/notes.md` as known noise, with why. A server error your run did not cause (a push
from Garmin, another run's request in your edge extract) is still filed, kind bug, screen none;
"not this app" is never a reason to skip it.

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
id and quotes its Decision text word for word from `docs/ssot/decisions/`. When the rule it breaks
lives in a spec rather than a decision card, `decision:` is `docs/ssot/spec/<path>.md#<heading text>`
and the quote is copied from that file; the index checks the file, the heading and the quote.
Status stays `open`;
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
   it), and set its state with `CRED update <address> --state deleted` (or `delete-failed`).
   An address that never finished sign-up (an unconfirmed auth user the in-app delete cannot
   reach) is not deleted by you: name it and its auth user id in `RUNS/notes.md` under
   "Leftover accounts", and the wave lead removes it at the close with
   `node scripts/testing-wave/sweep-accounts.mjs delete --id <id> --apply` (IMPROVEMENTS #84).
2. Stop every background process the run started: each helper loop (a watcher, a poller) keeps
   its PID in `SCRATCH/<name>.pid` when started and is killed by that PID here (#67). Then stop your log stream (`kill $(cat SCRATCH/logstream.pid)`; never `pkill`/`killall log`, which
   ends the other run's console too) and terminate the app on the simulator.
3. `LOCK release slot OWNER`. The simulator stays; the wave lead deletes it at the close.
4. Scan the console before committing it: `grep -nE 'eyJ[A-Za-z0-9_-]{10,}|Bearer |sk_|sbp_' RUNS/console.log`.
   Expect hits: the debug stream prints the app's shared preferences, session token included
   (IMPROVEMENTS #40). Cut only those lines and keep the rest as evidence:
   `grep -F '(Flutter)' RUNS/console.log | grep -vE 'eyJ[A-Za-z0-9_-]{10,}|Bearer |sk_|sbp_' > RUNS/console-redacted.log`
   (only the app's own lines: the raw stream is ~80 MB of OS debug lines in half an hour, #88),
   delete `console.log`, run the scan again on the redacted file (it must find nothing), and cite
   `console-redacted.log` in Findings.
5. Commit `.scratch/testing-wave/findings/NN-*.md` and `RUNS` on your branch, explicit paths only.
   Run logs under `RUNS` are not gitignored (the Findings cite them), so a plain `git add` takes
   them after the scan.

`LOCK list` shows what is still held. A claim left by a crashed agent is dropped on the next claim
once it is older than the stale timeout (4 h).

## The wave lead's routine

The wave lead runs one wave per session and the session is cleared between waves; `waves.json` and
the ticket Status lines carry the state from one wave to the next (Lee, 2026-09-25).

The testing wave never writes to the decisions page (Lee, 2026-09-24): no ticket cards, no
proposals, no pictures, no page reseed. Questions about testing itself are settled with Lee in
the terminal. A Finding that raises a real product question (paywall, meal planning, how the app
should behave) goes to the page as an open question, the normal way, and nothing else does.

**Before the wave.**

1. Read `.scratch/testing-wave/IMPROVEMENTS.md`; fix or raise one or two open items.
   Commit those fixes before `wave --open`: the worktrees branch from the wave's base, so a harness
   change made after it never reaches the agents.
2. The app, before `wave --open` (Lee, 2026-09-24: build only when app code changed).
   `.scratch/testing-wave/app-build.json` names the commit the testing app was built from, and the
   dev simulator carries that build. `git diff --name-only <that commit> HEAD -- lib pubspec.yaml
   pubspec.lock ios assets` empty: no build, nothing to install. Anything listed: build once from a
   clean detached worktree at HEAD (never the main clone, which carries other sessions' unfinished
   edits) with `scripts/run_dev.sh -d <dev simulator udid>`, quit it once the app runs (an install
   keeps the dev simulator's data and sign-in), remove that worktree, write the commit to
   `app-build.json` and commit it. Then open the wave. Agents never build.
3. One simulator per ticket: `SYNC simulator claim testing-wave-NN` for each, before spawning. It
   copies the dev simulator, so it carries the testing build, the mobile MCP helper and Lee's app
   data. Then `scripts/testing-wave/clear-app.sh <udid>` on each, so the app opens signed out with
   an empty database (it refuses any simulator not named `wave-*`). Skip the clear only for a
   ticket that tests the leftover data (14-004, 02-001 retests) and say so in its prompt. The name
   and udid go in the ticket's prompt.
4. One worktree per ticket (`git worktree add`), then copy every `.env*` file from the main clone
   into it (`cp .env* <worktree>/`), and make the ticket's scratch folder.
5. The prompt names the worktree, `UDID`, `SCRATCH`, the app's commit, whether the app data was
   cleared, the ticket's full text and its cited decisions, and points at this runbook. The
   prompt's build commit wins over `app-build.json` if they ever differ. When two tickets in the
   wave use the same account, both prompts say so and name what the other run writes, so each
   checks only its own rows and treats the other's as expected (IMPROVEMENTS #44).
   Before writing any prompt, read the code behind every screen the ticket visits: what its Add,
   Save and "+" controls write, and what the screen shows for the state the ticket starts in (a
   connection from another environment, a leftover draft). Never tell an agent another run is
   read-only on a guess; name the conversation or plan each ticket writes into (Lee, 2026-09-25,
   IMPROVEMENTS #47, #53).
   When a prompt names a control, follow its widget up to a screen that mounts it (its route or
   its parent's), not only to the method it calls: a grep can find a widget no screen shows (#83).
   For two runs on one account, name the state each shared-account check starts from, and say
   how the run gets back to it when the other run's writes move it (wave 30: 110's hand-made
   lists become the Shopping tab's newest list, which has no Shop with Kroger button, so 111
   reopens the plan's list from Previous lists). When one run's write destroys a start state
   the other cannot get back to, order the two with a flag file in a shared scratch folder
   (IMPROVEMENTS #72).

**Fix waves: keep them fast (Lee, 2026-09-25).** A fix wave runs no scenario, so it skips most of
the above and follows this instead:

1. No simulators, no app build, no device checks. Agents run only the test files for their own
   change (TDD at the seams), plus `flutter analyze` on what they touched. They never run the full
   suite or a review. Codegen always runs unfiltered (`dart run build_runner build
   --delete-conflicting-outputs`, never `--build-filter`, which deletes every other generated
   file), and the agent checks `git status` for deleted files before staging (Lee, 2026-09-25, #58). A ticket that bumps
   Drift's `schemaVersion` re-pins `_pinnedVersion` and `_pinnedFingerprint` in
   `schema_version_guard_test.dart` and runs that test (#66). An agent that adds a call to a shared
   client (`VanaActionClient`, a repository) greps the tests for fakes of that client and runs
   them too: some assert the exact list of calls (#76). A logic ticket's prompt adds: "for every
   async path you add, write down what happens if it runs twice at once or after a refresh" (#77).
2. No decisions-page writes of any kind during a wave, not even open questions. A product question
   an agent raises goes in its ticket file or a Finding; the SSOT is updated later, in one pass,
   from the testing docs.
3. Batch small work. Copy fixes and one-line guards go to one agent as a list (fable is enough);
   only real logic gets its own agent. Give each ticket that may write a migration its own
   timestamp (`<date>16NN00`, NN = ticket) so two never collide (#60). Tell agents which files
   another open wave is editing and forbid them (#63).
   Two tickets that decide the same thing about the same rows (whether another account's unsent
   data survives a sweep, what counts as dirty) go to one agent. When they cannot, each prompt
   states the other ticket's rule for that data, not only the shared file names (#70).
4. Merge as agents finish. Make the `merge-N` worktree when the first report arrives and merge
   each branch in when its agent reports; do not wait for the slowest.
5. At the end, once: merge `mealplanning` in (it may have moved, #59), one unfiltered codegen,
   `flutter analyze`, deno tests for touched functions, and ONE full CI suite. A failure is fixed
   and re-checked with the affected test folders only, never a second full suite. If
   `mealplanning` moves again before landing, re-merge and run the touched folders only.
6. Review only the logic-heavy tickets (paywall, sync, plans, startup), with one read-only agent
   looking for real bugs; skip review for copy and layout tickets. When the lead's review fixes touch an
   annotated file (`@riverpod`, Drift, freezed), run the unfiltered codegen again before landing
   and commit what it changes, so the next wave does not inherit stale generated files (#71).
7. Deploy once, from the final merged tree: SQL first, then every function the wave changed.
   One real read for any changed PostgREST select (#57).
8. Land with a fast-forward (check `merge-base --is-ancestor` before touching any dirty file,
   #61), close the wave, and push `mealplanning` when Lee has asked for pushes (it triggers no
   Codemagic build). Push credentials: `GIT_ASKPASS` pointing at a script that runs
   `gh auth token --user lbm54`.

**After the wave.**

1. Merge in ticket order, run `flutter analyze` and the CI suite command.
   A fix wave deploys once, from the merged tree: agents deploy nothing (two tickets that touch
   `_shared/` would overwrite each other), and the lead applies the wave's SQL first, then
   redeploys every function the merged diff touched (IMPROVEMENTS #55).
2. Read every ticket's `RUNS/notes.md` for surprises with no Finding and no "known noise", and file
   them (`FINDINGS new …`), noting "filed by the wave lead" in Actual. Then read the tickets'
   edge-log extracts (`RUNS/*edge*`) side by side: a line in one ticket's extract can come from
   the other ticket's run (wave 10: ticket 20's `kroger` 400s sat only in ticket 30's extract).
   Match each error to the run whose minutes and screens produced it, and file any nobody filed.
3. `FINDINGS index` (writes `INDEX.md`; exit 0 only when every Finding is closed or wontfix: the end
   of the loop). `COST status WAVE` shows what the wave spent. Triage follows the spec's "Triage".
   A retest ticket holds about ten checks (Findings to retest plus follow-up tests), grouped by
   screen or area and by the account and starting state they need; more checks become more tickets
   (Lee, 2026-09-25: long runs degrade the agent's context).
   A fix ticket's Touches lists every file the fix will change: `wave --open` holds back a ticket
   whose Touches overlap an open wave's (#63). A fix to how the app reaches a screen greps for the
   route and lists every call site in Touches, not only the button the Finding named (Lee,
   2026-09-25, #64).
4. `SYNC simulator drop <name>` for every wave simulator; `wave --close`; remove the worktrees.
   Delete each run's "Leftover accounts" (`sweep-accounts.mjs delete --id <id> --apply`, #84).
   Pull one edge-log extract for the whole wave's window yourself rather than relying on each
   run's (#86).
5. Append what the wave taught to `IMPROVEMENTS.md` and move anything fixed to Done.
