# Testing-wave runbook

How one testing-wave ticket runs, start to finish, and the wave lead's routine around it. Moved from
`mealplanning`'s `.scratch/testing-wave/RUNBOOK.md`; the `#NN` numbers cite entries in
`IMPROVEMENTS.md`, and `NN-NNN` numbers cite Findings of round `mealplanning-2026-09`. The rules
behind the steps live in `SPEC.md` (what a run checks, Findings, accounts, cost caps, triage) and
`CLAUDE.md` (repo rules, deploys, prod). Read both before the first run. Your ticket file lists the
records it expects in RevenueCat and the dev database; step 1 writes them down before you touch the
app.

Names used below:

- `NN`: your ticket number, two or three digits. `OWNER` is `testing-wave-NN`.
- `<round>`: the round's name, from your prompt (`develop-2026-10`). `ROUND`:
  `.scratch/testing-wave/rounds/<round>/` in your worktree. Your ticket is
  `ROUND/issues/NN-*.md`; Findings go in `ROUND/findings/`.
- `WAVE`: the wave number on your ticket's Status line (`in-progress (wave N)`).
- `RUN`: `w<WAVE>-<UTC time>`, made once at the start: `echo "w$WAVE-$(date -u +%Y%m%dT%H%MZ)"`.
- `RUNS`: `ROUND/runs/NN/`. Everything the run produces goes here.
- `LOCK`: `node scripts/testing-wave/lock.mjs`. `COST`: `node scripts/testing-wave/cost.mjs`.
  `FINDINGS`: `node scripts/testing-wave/findings.mjs`. `SIM`: `node scripts/testing-wave/simulator.mjs`.
- `CRED`: `node scripts/testing-wave/cred.mjs`, the only way to the credentials
  (`/Users/leemartin/development/mealvana_endurance/secrets/test_accounts.md`). Never open that file
  in any way; its shape is `scripts/testing-wave/test_accounts.template.md`, and `CRED list` shows
  addresses and states. `CRED type <email> --udid UDID` types a password into the focused field
  (`--section <words>` when one address sits in two sections, as the Patrol account does),
  `CRED file <email> SCRATCH/<name>` saves one (mode 600) for an API check, and `CRED new` and
  `CRED update` add and change Created accounts rows. None of them prints a password.
- `SCRATCH`: the scratch folder your prompt names, one per ticket (`<scratchpad>/testing-wave-NN/`).
  Helper scripts and temporary files go there and nowhere else; never read or run another ticket's.
- `UDID`: the simulator your prompt names. The wave lead made it for you with the app already
  installed; it is yours for the whole run and nothing else is.

Nothing gets fixed during a run. Every problem, clash or idea is a Finding (step 8).

No Patrol (Lee, 2026-09-24). You test by driving the app yourself; you do not write or run
Patrol flows, whatever an older ticket says.

Never print a secret: no `cat`, `tail` or `bash -x` on anything that reads `secrets/` or `.env*`,
and no read of the credentials file except through `CRED`. Read a value into a variable without
echoing it.

## 1. Claim a slot

```
LOCK claim slot OWNER            # waits up to 90 min; exit 3 = every slot still held
```

Exit 3: report the ticket as not run. Then `mkdir -p RUNS` and write `RUNS/expected.md`: the
RevenueCat and database records the ticket expects before and after, copied from its criteria. The
run is judged against this file.

## 2. Your simulator and the app on it

The wave lead gave you `UDID` with the dev app installed, built from the commit named in your
prompt (`ROUND/app-build.json`). Write that commit in `RUNS/notes.md`: every Finding ties to it.
You do not build the app. If the app on `UDID` is missing or will not launch, write a bug Finding
and report the device check as not run.

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
send the app to the background (#50). Make one harmless MCP call first (a
`mobile_take_screenshot`), then take a `simctl io` screenshot; if the home screen shows, `simctl
launch` again (the app keeps its state) before the first tap.

Stop the log stream at step 9.

## 4. Start from what is on the screen

Look first (a `simctl io` screenshot and `idb ui describe-all`). The wave lead cleared the app's
data, so it opens signed out on Welcome with an empty local database, unless your prompt says the
ticket tests the dev simulator's leftover data. Do only the setup your ticket needs: a ticket on
the dev test account logs in with it (`CRED type test@test.com --udid UDID` for the password); a
ticket about signup makes its own account. Never reinstall or wipe the app unless the ticket says
so.

## 5. Drive the app

- Drive with idb (Lee, 2026-10-07, #103): `idb ui describe-all --udid UDID` for the element list,
  `xcrun simctl io UDID screenshot` for the picture, `idb ui tap X Y --udid UDID` to tap, `idb ui
  text` to type. The mobile MCP stays an option for what idb lacks (screen recording, tapping by
  element reference, batched commands, device logs and crash lists), on `UDID` only: its helper
  failed to start on two of three clones in wave 1 and, with two simulators up, its element list
  has returned the other simulator's screen (#39), so never trust it for what is on `UDID`.
- Scroll with slow idb drags (`idb ui swipe X1 Y1 X2 Y2 --duration 1.2 --udid UDID`) whenever the
  run counts rows or list items: the mobile MCP's swipe flings past them (#43).
- The dev overlay buttons (red accessibility, blue testing tools, x ~367, y ~695 and ~756) sit on
  the Timeline rows' ⋯ and the Recipes rows' +: scroll a row out of y 650-790 before tapping its
  menu, and read the tap target back from the element list (#98).
- Type text with `idb ui text "<text>" --udid UDID` (it once mangled a long address, #35; the
  mobile MCP's `type_keys` is the alternative when it does). After `idb ui text`, wait 2 s before tapping the next field and
  read the value back: a tap sooner drops the tail. Backspace deletes forward from the tap point,
  so clear a prefilled field with forward delete (`idb ui key 76`) from its start. zsh does not
  split `$var` (`set -- $t` and `F="node …"; $F` both fail), so wrap a repeated command in a shell
  function. A control whose position depends on text width (a title's Next arrow, for one) moves:
  read its position from the element list each time, never reuse a coordinate.
- Deep links use the three-slash form, `xcrun simctl openurl UDID "com.milkman.mealvanaendurance:///<path>"`;
  the two-slash form reads the first segment as a host and lands on Page Not Found (#104).
- Before submitting a long value (an address, a code), read it back with `idb ui describe-all
  --udid UDID`: a field shows only the tail of a long value.
- Passwords go in with `CRED type`, never by hand and never into a Finding, commit or report.
  Before `CRED type`, take a fresh screenshot and confirm the focused field is the password field
  (secure entry shows dots); a web sign-in sheet that zoomed on focus moves its fields, so
  re-screenshot after every tap in it (#112, wave 3: a password was typed into a username field).
- Nothing a run sends off this machine carries a personal address (#112): a helper that fetches
  anything uses a neutral User-Agent, and a food photo comes from the repo's fixtures or is generated
  in SCRATCH, never downloaded.
- Simulator prefs: `simctl spawn UDID defaults delete <bundle id> <key>` does nothing (#113). Read
  and edit `Library/Preferences/com.milkman.mealvanaendurance.dev.plist` in the app's data container
  with `plistlib`, app terminated; print key names and only the values the ticket names.
  Never tap the eye (show password) icon on a password field: the element list and screenshots
  then carry the password (#89). Read a password field back only as a count of dots, and check the
  count against the password's length before submitting. `CRED type` waits a second after the
  focus tap, since typing sooner dropped characters (#93), and 2 s after typing, since iOS shows
  the last character for a moment and one screenshot caught it (120-010). A screenshot right after
  a submit tap can still carry the last character (#100), so take the next one after the screen
  changes.
- A new account signs up at `lee+e2e-NN-<UTC time>@rightpathprogramming.com`. Dev asks for the
  6-digit code we email: read it with the Gmail tool (`to:lee+e2e-NN-… from:support@mealvana.io`,
  newest first) and type it into the app. Before signup, `CRED new <address> --ticket NN --run RUN`
  makes the password and adds the row (state `new`); type it with `CRED type`. Change the row as
  the run changes the account (`CRED update <address> --state <state> --when <UTC>`;
  `--new-password` for a reset, after `CRED file` has kept the old one if the run still checks it).
- Before a step that makes an AI call the caps count (a new Vana plan, an AI logging call, a Vana
  chat call), spend first, before any tap that can start the call, never after it (#95):

  ```
  COST spend WAVE plan NN          # or: COST spend WAVE logging NN, COST spend WAVE chat NN
  ```

  Exit 3 means the wave's cap is used up: skip the step and write a followup-test Finding for it.
  When a spend bought nothing (the call never happened), say so in `RUNS/notes.md` so the lead can
  count it back (#48).
- Screenshots go in `RUNS` with names that say what they show. Take them with
  `xcrun simctl io UDID screenshot RUNS/<name>.png`: the mobile MCP's `save_screenshot` refuses
  paths inside the worktree. After a tap, take a new screenshot before trusting the MCP's element
  list; it has returned the previous screen.
- A web sign-in sheet (TrainingPeaks, Garmin, any OAuth provider) runs out of process: neither the
  MCP nor `idb ui describe-all` lists its fields (#51). Drive it by coordinate taps read off
  `simctl io` screenshots, one screenshot after every tap, and type with the mobile MCP (`CRED type`
  for the password once the field is focused).
- Offline or slow for your app only: `scripts/testing-wave/netcut/netcut.sh launch UDID SCRATCH`
  relaunches the app with a connect-blocking library injected (network still on); `netcut.sh on
  SCRATCH` cuts it and `netcut.sh off SCRATCH` restores it, no relaunch. `on` also shuts down every
  connection the app already had open, so the first offline tap is offline too (111-004);
  `on SCRATCH --relaunch UDID` stays as the fallback. `netcut.sh slow <ms> SCRATCH` makes the app's
  traffic answer `<ms>` late but succeed (a host proxy holds each reply; `--only <host>` slows one
  host alone, `--relaunch UDID` so connections opened before it are slowed too, #92). The host and
  other simulators keep their network. Events go to `SCRATCH/netcut.log` and
  `SCRATCH/slowproxy.log`; the proxy's PID is in `SCRATCH/slowproxy.pid` (step 9). The app's
  connectivity check still reads "online", so its offline banner needs a device (20-006). Start the
  log stream first (step 3), since `launch` replaces the plain `simctl launch`.
- A step that must be seen live (a renewal, a lapse, a timer): write the clock time before and
  after every wait in `RUNS/notes.md`. When the gap is longer than planned, write "not seen live"
  next to the step and say how it was checked instead.

## 6. Check RevenueCat and the dev database

Read, never write, unless your ticket's criteria name the write: no RevenueCat or database writes
the ticket doesn't name, even on your own account (#97). A cancel, a grant or an SQL fix to force a
state is a Finding, not a step.

- RevenueCat: the v2 API with the secret key in `secrets/revenuecat.env` (main clone), or the
  RevenueCat MCP.
- Dev database: `SELECT` statements only, through the Management API `database/query` on the dev
  project, as `docs/deployment/supabase-deploy-playbook.md` describes. Name the columns, never
  `SELECT *`: `integrations` holds live access and refresh tokens, and a star prints them into your
  transcript (#85).
- Edge-function logs for the functions the scenario touched: the Supabase MCP's `query_logs` on the dev
  project (`select timestamp, event_message, log_attributes['level'] from logs where source =
  'function_edge_logs'` for request lines, `'function_logs'` for console lines, with the run's window as
  `iso_timestamp_start/end`). A metered call is confirmed by its `token_ledger` debit and its `function_logs` lines; a
  missing `function_edge_logs` request line alone does not mean the call was never made (31-013: analyze-meal-photo
  never gets one). `scripts/edge_logs.sh` is gone (#102): it answered "(no rows in window)" for
  every query after Supabase removed its endpoint. Save the rows to `RUNS/edge-*.txt`.

Both the SQL and the logs need a Management API token. Read it from the main clone without
printing it, once per shell:

```
export SUPABASE_PAT="$(sed -n 's/^SUPABASE_MANAGEMENT_TOKEN=//p' /Users/leemartin/development/mealvana_endurance/secrets/supabase_management_api.env)"
export SUPABASE_ACCESS_TOKEN="$SUPABASE_PAT"
```

Save each extract to `RUNS` (`revenuecat-<what>.json`, `db-<what>.txt`) and compare it with
`RUNS/expected.md`. Every mismatch is a Finding.

Fixtures, dev only, never written by hand:

- Start states are written on an account this run made, never on another run's account, which
  that run's step 9 deletes (#87): through the app where it can, otherwise with a seed script the
  ticket names (a round whose branch needs one adds it under `scripts/testing-wave/` with a header
  listing what it writes and a read-only `show`; mealplanning's `seed-states.mjs` and
  `seed-codes.mjs` are the pattern). The state goes with the account when step 9 deletes it.

## 7. Look around on every screen

On each screen you visit, stop and list other paths through it (other buttons, back, swipe, empty
and error states, offline, a second tap) and other ways it could break. Each one is a
followup-test Finding naming the screen. Do not run them now; the next waves pick from them.
Also read `console.log` after each screen: every error or exception line is a Finding or is noted
in `RUNS/notes.md` as known noise, with why. A server error your run did not cause (a push from
Garmin, another run's request in your edge extract) is still filed, kind bug, screen none (#49);
"not this app" is never a reason to skip it.

A note that says an old Finding is still true (or already fixed) is checked in this run, or says
"not re-checked" (#95).

Anything unexpected you write in `RUNS/notes.md` is also a Finding, or carries "known noise:
<why>" beside it. The wave lead reads every notes file at the close and files what you did not.

## 8. Write Findings

One file each, made with:

```
FINDINGS new NN "<what happened, one line>" --kind bug|ssot-conflict|followup-test|idea --run RUN --round <round>
```

It lands in `ROUND/findings/NN-<next number>-<slug>.md`, filled from
`scripts/testing-wave/finding.template.md`. Fill in screen, steps, expected, actual and
evidence (paths under `runs/NN/`, relative to `ROUND`, first word of each Evidence bullet).
An ssot-conflict cites the rule it breaks and quotes it word for word: a
decision id with its Decision text, or, when the rule lives in a spec, `decision:
docs/ssot/spec/<path>.md#<heading text>` with the quote copied from that file. The index checks the
file, the heading and the quote. Status stays `open`; triage moves it. Check your files parse and
their evidence exists:

```
FINDINGS index --round <round> --out "$TMPDIR/testing-wave-index.md"   # exit 2 names a malformed Finding or a missing evidence file
```

Do not commit `INDEX.md`; the wave lead regenerates it after merging.

Keep going after a Finding. Stop only when a Finding makes the rest of the scenario meaningless
(`SPEC.md` says when): say so in that Finding (`**Actual.**` ends with "Ticket stopped here:
<why>"), then mark the run stopped in `RUNS/STOPPED.md`: the Finding's file name, why, and the
step or criterion the retest resumes from. Go to step 9. A run with no `STOPPED.md` ran to the end.

## 9. Release everything

At the end of every run, stopped or not, in this order:

1. Delete every account you created through the app's delete-account flow (unless the ticket keeps
   it), and set its state with `CRED update <address> --state deleted` (or `delete-failed`). An
   address that never finished sign-up (an unconfirmed auth user the in-app delete cannot reach) is
   not deleted by you: name it and its auth user id in `RUNS/notes.md` under "Leftover accounts",
   and the wave lead removes it at the close (#84).
2. Stop every background process the run started: each helper loop (a watcher, a poller) keeps
   its PID in `SCRATCH/<name>.pid` when started and is killed by that PID here (#67). Then stop
   your log stream (`kill $(cat SCRATCH/logstream.pid)`; never `pkill`/`killall log`, which ends
   the other runs' consoles too) and terminate the app on the simulator.
3. `LOCK release slot OWNER`, then `SIM release <your simulator's name>`. The simulator itself
   stays; the wave lead removes it at the close.
4. Scan the console before committing it: `grep -nE 'eyJ[A-Za-z0-9_-]{10,}|Bearer |sk_|sbp_' RUNS/console.log`.
   Expect hits: the debug stream prints the app's shared preferences, session token included
   (#40). Cut only those lines and keep the rest as evidence:
   `grep -F '(Flutter)' RUNS/console.log | grep -vE 'eyJ[A-Za-z0-9_-]{10,}|Bearer |sk_|sbp_' > RUNS/console-redacted.log`
   (only the app's own lines: the raw stream is ~80 MB of OS debug lines in half an hour, #88),
   delete `console.log`, run the scan again on the redacted file (it must find nothing), and cite
   `console-redacted.log` in Findings. Over 5 MB, collapse repeated logger boxes (an offline loop
   logs thousands, #94): `node scripts/testing-wave/collapse-console.mjs RUNS/console-redacted.log`
   keeps the first three and the last copy of each and writes one count line where the rest were;
   quote that count in the Finding.
5. Commit `ROUND/findings/NN-*.md` and `RUNS` on your wave branch, explicit paths only. The
   Findings cite the run logs, so they are committed; the repo's `*.log` ignore rule can hide them,
   so check `git status` and `git add -f RUNS/console-redacted.log` when it is not listed.

`LOCK list` shows what is still held. A claim left by a crashed agent is dropped on the next claim
once it is older than the stale timeout. `SIM list` shows who holds each simulator.

## The wave lead's routine

`/testing-wave <round> [--only NN,..]` runs this routine; the skill carries the mechanics and this
section the rules. The lead runs one wave per session, and the session is cleared between waves;
the ticket Status lines and the wave log at the top of `ROUND/TRIAGE.md` carry the state from one
wave to the next (Lee, 2026-09-25). Waves run back to back in one session only when Lee asks for it.

The testing wave never writes to the SSOT or a decisions page (Lee, 2026-09-24): no ticket cards,
no proposals, no pictures. Questions about testing itself are settled with Lee in the terminal. A
Finding that raises a real product question goes to the review queue
(`.scratch/ssot/review-queue.md`) at triage, and nothing else does.

**Before the wave.**

1. Read `docs/testing-wave/IMPROVEMENTS.md`; fix or raise one or two open items. Commit those fixes
   before cutting the worktrees: they branch from the wave's base, so a tool change made after it
   never reaches the agents (#46).
2. The app (Lee, 2026-09-24: build only when app code changed). `ROUND/app-build.json` names the
   commit the testing app was built from, and the dev simulator carries that build. `git diff
   --name-only <that commit> HEAD -- lib pubspec.yaml pubspec.lock ios assets` empty: no build,
   nothing to install. Anything listed: build once from a clean detached worktree at HEAD (never
   the main clone, which carries other sessions' unfinished edits) with `scripts/run_dev.sh -d <dev
   simulator udid>`, quit it once the app runs (an install keeps the dev simulator's data and
   sign-in), remove that worktree, write the commit to `app-build.json` and commit it. Agents never
   build.
3. One simulator per ticket, at most three at once: `SIM claim testing-wave-NN` for each, before
   spawning. It copies the dev simulator, so it carries the testing build, the mobile MCP helper and
   Lee's app data. Then `scripts/testing-wave/clear-app.sh <udid>` on each, so the app opens signed
   out with an empty database (it refuses any simulator not named `wave-*`). Skip the clear only
   for a ticket that tests leftover data, and say so in its prompt. The name and udid go in the
   ticket's prompt.
4. One worktree per ticket (`git worktree add`), then copy every `.env*` file from the main clone
   into it (`cp .env* <worktree>/`), and make the ticket's scratch folder.
5. The prompt names the worktree, `ROUND`, `UDID`, `SCRATCH`, the app's commit, whether the app
   data was cleared, the ticket's full text and the rules it cites, and points at this runbook. The
   prompt's build commit wins over `app-build.json` if they ever differ.
   - Every prompt repeats: "no RevenueCat or database writes the ticket doesn't name, even on your
     own account" (#97). A start state the ticket needs is written by the run itself on its own
     account, never planned on another run's account (#87).
   - Every line of a code map in a prompt says "from code, unverified", and anything a Finding's
     verdict hangs on is checked on the screen, never taken from the map (#91).
   - Before writing any prompt, read the code behind every screen the ticket visits: what its Add,
     Save and "+" controls write, and what the screen shows for the state the ticket starts in.
     Never tell an agent another run is read-only on a guess; name what each ticket writes into
     (Lee, 2026-09-25, #47, #53).
   - When a prompt names a control, follow its widget up to a screen that mounts it (its route or
     its parent's), not only to the method it calls: a grep can find a widget no screen shows (#83).
   - When two tickets in the wave use the same account, both prompts say so and name what the other
     run writes, so each checks only its own rows and treats the other's as expected (#44). Name the
     state each shared-account check starts from, and how the run gets back to it when the other
     run's writes move it. When one run's write destroys a start state the other cannot get back
     to, order the two with a flag file in a shared scratch folder (#72).
   - A ticket that touches notifications, scheduling or deep links follows CLAUDE.md's notification
     rule.

**Fix waves: keep them fast (Lee, 2026-09-25).** A fix wave runs no scenario, so it skips most of
the above and follows this instead:

1. No simulators, no app build, no device checks. Agents run only the test files for their own
   change (TDD at the seams), plus `flutter analyze` on what they touched. They never run the full
   suite or a review. Codegen always runs unfiltered (`dart run build_runner build
   --delete-conflicting-outputs`, never `--build-filter`, which deletes every other generated
   file), and the agent checks `git status` for deleted files before staging (#58). A ticket that
   bumps Drift's `schemaVersion` re-pins `_pinnedVersion` and `_pinnedFingerprint` in
   `schema_version_guard_test.dart` and runs that test (#66). An agent that adds a call to a shared
   client (a repository, an edge-function client) greps the tests for fakes of that client and runs
   them too: some assert the exact list of calls (#76). A logic ticket's prompt adds: "for every
   async path you add, write down what happens if it runs twice at once or after a refresh" (#77).
   A test that starts a timer cancels it inside the test body or with `addTearDown` before the pump,
   never in a `tearDown` alone: flutter_test checks pending timers before `tearDown` runs (#110).
   Before committing, `grep -rl` each changed class and method name under `test/` and run every file it
   names, not only the ticket's list (#116). A ticket that adds a reporting helper or a by-contract silent
   catch adds it to `source_guard.dart`'s `reportCalls` or a reasoned `allow_list.md` entry in the same
   commit and runs `test/shared/source_guard/` itself (#117).
2. No SSOT or decisions-page writes during a wave, not even open questions. A product question an
   agent raises goes in its ticket file under a `**Questions for Lee.**` heading, never only in a
   commit body (#111); the lead's close-out lists them and takes them to Lee, then to the review queue.
3. Batch small work. Copy fixes and one-line guards go to one agent as a list; only real logic gets
   its own agent. Give each ticket that may write a migration its own timestamp (`<date>16NN00`,
   NN = ticket) so two never collide (#60). Tell agents which files another open wave is editing
   and forbid them (#63). Two tickets that decide the same thing about the same rows (whether
   another account's unsent data survives a sweep, what counts as dirty) go to one agent. When they
   cannot, each prompt states the other ticket's rule for that data, not only the shared file names
   (#70). A ticket whose items share generated files or a schema bump (a backport, a Drift version)
   runs as sequential agents by area in one worktree; only independent areas run at once (#108).
4. Merge as agents finish. Make the merge worktree when the first report arrives and merge each
   branch in when its agent reports; do not wait for the slowest.
5. At the end, once: merge the working branch in (it may have moved, #59), one unfiltered codegen,
   `flutter analyze`, deno tests for touched functions (`deno test --allow-all <files>`, never `--allow-sys`: the garmin and discard-signup suites read env and hrtime, #109), and ONE full suite (the CI gate's command,
   `docs/test/README.md`). A failure is fixed and re-checked with the affected test folders only,
   never a second full suite. If the working branch moves again before landing, re-merge and run
   the touched folders only.
6. Review the merged result with `/mattpocock-skills:code-review` since the wave's base. When the
   lead's review fixes touch an annotated file (`@riverpod`, Drift, freezed), run the unfiltered
   codegen again before landing and commit what it changes, so the next wave does not inherit
   stale generated files (#71).
7. Deploy once, to dev, from the final merged tree: SQL first, then every function the wave
   changed (#55). Agents deploy nothing. One real read for any changed PostgREST select (#57).
8. Close-out names which of the wave's fixes touch code another branch shares and which branch owes
   them; the owing branch's next round gets a backport ticket (#105, Lee 2026-10-07; ticket 29 is the
   first).
9. Land with a fast-forward (check `merge-base --is-ancestor` before touching any dirty file, #61)
   and commit. Pushing follows CLAUDE.md and waits for Lee's go.

A fix ticket closes when its retest passes on a simulator in the next wave.

**After the wave.**

1. Merge each wave branch in ticket order. A test wave changes only `ROUND/findings/` and
   `ROUND/runs/`, so it needs no codegen or suite.
2. Read every ticket's `RUNS/notes.md` for surprises with no Finding and no "known noise", and file
   them (`FINDINGS new …`), noting "filed by the wave lead" in Actual (#14). Then read the tickets'
   edge-log extracts (`RUNS/*edge*`) side by side: a line in one ticket's extract can come from
   another ticket's run. Match each error to the run whose minutes and screens produced it, and
   file any nobody filed (#38). Pull one edge-log extract for the whole wave's window yourself
   rather than relying on each run's (#86).
3. `FINDINGS index --round <round>` (writes `INDEX.md`; exit 0 only when every Finding is closed or
   wontfix: the end of the round). `COST status WAVE` shows what the wave spent. Triage follows
   `SPEC.md`, "Triage": with Lee in the terminal, one Finding at a time, each ruling written to
   `ROUND/TRIAGE.md` and the Finding's status line.
   - Findings with one cause (the same screen, the same root, one fix) are one question, not one each
     (#107): wave 1 needed 25 questions for 56 Findings that way.
   - A retest ticket holds about ten checks (Findings to retest plus follow-up tests), grouped by
     screen or area and by the account and starting state they need; more checks become more
     tickets (Lee, 2026-09-25, #78).
   - A follow-up test a run proved impossible as written is rewritten or closed at triage, never
     carried forward as it stands (#99).
   - A ticket that adds a timeout or a retry lists each write it covers and says whether repeating
     that write is safe; a write that is not safe gets an idempotency key or no timeout (#82).
   - A fix ticket's Touches lists every file the fix will change; two tickets whose Touches overlap
     never run in the same fix wave (#63). A fix to how the app reaches a screen greps for the route
     and lists every call site in Touches, not only the button the Finding named (Lee, 2026-09-25,
     #64).
4. Check `SIM list` and `LOCK list` show nothing held; release what an agent left. Remove every
   wave simulator (the command is in `simulator.mjs`'s usage line) and the worktrees. Delete each
   run's "Leftover accounts" with `node scripts/testing-wave/sweep-accounts.mjs delete --id <id>
   --apply` (#84).
5. Append what the wave taught to `docs/testing-wave/IMPROVEMENTS.md` and mark anything fixed done.

**End of the round.** When `FINDINGS index` exits 0: `FINDINGS ledger <round>` appends the round's
Findings to `BUGS.md` and `COVERAGE.md`, and `IMPROVEMENTS.md` gets the round's last entries.
