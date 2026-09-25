# Testing-wave improvements

A running list of ways to make the testing loop itself better: the harness, the runbook, the
tickets, the wave lead's routine. App bugs are not listed here; they are Findings.

**How to use it.** The wave lead reads this file before opening a wave and appends to it after
the review, one entry per lesson. Pick one or two open items to fix between waves, or ask Lee
which are worth it. When an item is fixed, move it to Done with the commit.

Each entry: what went wrong or cost time, where it was seen, and the suggested fix.

## Open

- **#74 `netcut on` leaves open connections up (wave 30).** Ticket 111's first tap after the cut
  (21-007) went out over a connection that was already open; a retry 40 s later was blocked
  (Finding 111-004). Suggested fix: after `netcut on`, wait for idle connections to drop or
  relaunch the app before the first offline check, and say so in runbook step 5.

## Done

- **#73 three-digit tickets had no Findings (wave 30).** `findings.mjs` read and made Findings
  only for two-digit tickets, so `111-*` files were skipped by `index` and `new` refused
  ticket 111 (Finding 111-003). Fixed by the wave 30 lead: tickets are two or three digits,
  with a test.

- **#72 two runs on one account need an order, not just a warning (wave 29).** 88 and 89 shared
  test@test.com, and 89's 19-009 needed plan be6abf2f confirmed with no list, which 88's confirms
  and Browse picks would destroy. A flag file in a shared scratch folder (`testing-wave-w29-shared/`)
  worked: 89 wrote it at 20:06Z, 88 held every confirm and be6abf2f write until 20:07Z. The wave's
  chat cap (5) was used up by the two runs, so some of 88's legs went unrun (88-024). Suggested fix:
  wave-lead step 5 names the state each shared-account check starts from and orders them with a
  flag when one run destroys another's start state; split tickets (Lee 09-25) should keep
  chat-heavy checks apart so one pair does not exhaust the cap.
  Done (wave 30 lead): wave-lead step 5 now names each shared-account check's start state and
  the way back to it, and keeps the flag file for a start state that cannot be rebuilt. The
  split tickets (110-125) already keep chat-heavy checks apart.

- **#70 two parallel tickets each made their own rule for the same data (wave 27).** 102 (sign-in
  sweep) and 103 (pull after a failed upload) both had to decide when another account's food
  preferences are still unsent. 103 added an upload-pending marker; 102 kept them only while the
  account had other dirty rows, so the sweep deleted unsent preferences. The prompts named the
  shared files, not the shared state. Only the lead's review caught it, along with 102's sweep
  deleting the signed-in coach's own coach-mode rows. Suggested fix: when two tickets in one wave
  decide the same thing about the same rows, give both to one agent, or tell each agent the other
  ticket's rule in its prompt. Done 09-25: fix-wave step 3.

- **#71 generated files left stale by a closed wave (wave 28).** The unfiltered codegen after
  wave 28's merge rewrote five `.g.dart` files that 108 never touched (`pro_gate.g.dart` doc comment
  from wave 27's review fix, four provider hashes): wave 27's review fixes landed after its last
  codegen. Suggested fix: when the lead's review fixes touch an annotated file, run the codegen
  again before landing, and commit what it changes. Done 09-25: fix-wave step 6.
- **#68 three-digit tickets read as unblocked (wave 26).** `sync.mjs` read `Blocked by` with
  `\b\d{2}\b`, so 100 ("Blocked by: 101.") showed on the frontier. Now `\d{2,3}`, with a test
  (`dcbf75fa`).
- **#69 a review found a path the ticket's own tests missed (wave 26).** 101 deleted a draft's list on
  archive, but a pick still reaching the archived draft (mp-683) re-created it through
  `syncPlanList`. Fixed by the lead (`1dfcb06c`). A ticket that deletes something should test every
  write path that can make it again, not only the ones that delete it.
- **#66 a Drift bump passed the agent's tests but not the suite (wave 25).** Ticket 99 moved Drift to
  v23 and its migration test passed, but `schema_version_guard_test.dart` still pinned v22, so the
  full suite went red at the lead. Suggested fix: a ticket that bumps `schemaVersion` lists the guard
  test in Touches, and the agent prompt says to re-pin `_pinnedVersion` and `_pinnedFingerprint`.
  Done in wave 26: the lead's fix-wave prompt carries the rule (runbook fix-wave step 1).
- **#67 a retest agent's helper loop outlived its agent (wave 25).** Ticket 87 wrote `watch.sh` (polls
  the simulator every 20 s for the paywall across the lapse) and ended without stopping it; the
  lead killed it. Suggested fix: runbook step 9 says to stop every background loop the run started
  (keep their PIDs in SCRATCH, like the log stream).
  Done before wave 26: runbook step 9.2 says so.

- **#37 spec clashes had no id.** `findings.mjs`: `decision:` also takes
  `docs/ssot/spec/<path>.md#<heading>`; `index` checks the file, the heading and the quote
  (`a5ac3bfe`, Lee 09-25).
- **#63 two waves open at once.** `wave --open` holds back any ticket whose Touches overlap an open
  wave's, and says which files; `--only` does not override it (`5a5b25f4`, Lee 09-25: fix the root,
  file overlap, not a warning).

- **#41 settings can't be cleared (Lee 09-25: fix the bug).** Fixed at the root: clearing First
  name, Last name or Email on Profile & Preferences now saves it cleared (`5ba1fa05`, 31-004; Email
  had the same bug). 31-004 stays open until a retest runs it.
- **#47, #53 prompts guessed what a screen writes or shows.** Wave lead step 5: read the code behind
  every screen the ticket visits before writing prompts, and name the conversation or plan each
  ticket writes into (Lee 09-25).
- **#52 no Kroger certification shopper.** Lee 09-25: test matching only. Ticket 22 now runs
  matching unconnected (22-004); the cart hand-off is out of scope on dev.
- **#56, #61 landing over another session's dirty files.** Lee 09-25: stop the cause, not script
  around it. CLAUDE.md: no session leaves edits uncommitted in the main clone.
- **#58 filtered codegen.** Fix waves step 1: codegen always unfiltered, `git status` before staging
  (Lee 09-25).
- **#62 `/design-sync`.** Lee 09-25: rule dropped from CLAUDE.md. The design widgets are not synced
  to claude.ai/design.
- **#64 a fix left sibling call sites.** After-the-wave step 3: a navigation fix ticket greps the
  route and lists every call site in Touches (Lee 09-25).
- **#57, #59, #60 and #61's landing order.** Already in the fix-wave steps (`f8aee35e`); marked done
  by Lee 09-25.

- **#65 fix waves took 40-60 minutes of lead time (waves 19-22).** Three full-suite runs in wave
  22, page cards, waiting for the slowest agent, and a landing dance. **Done (Lee, 2026-09-25,
  wave 24):** RUNBOOK "Fix waves: keep them fast" (no devices, no page writes, merge as agents
  finish, one full suite, targeted re-runs, review only logic tickets, deploy once). Wave 24 took
  27 minutes for 12 tickets.

- **#54 CF-2 conformance goes red in the early morning (wave 19).** At 04:40 local the CF-2
  clamp-bound stepper test reads "1 h — early start" where it expects "Capped: session in …"; it
  was red at the wave's base too and green in the afternoon waves. The test depends on the clock.
  Suggested fix: pin the test's clock (a fixed `now` override) and file it as a Finding.
  Done 09-25 (wave 22 prep): the caption test starts the session 45 min out, under the 60-min
  early-start window, so the clamp binds at any hour.

- **#55 fix waves deploy once, from the merged tree (wave 19).** Tickets 34, 37, 38 and 55 all
  changed `_shared/vana/`, so a deploy from one worktree would have overwritten another's. The lead
  told agents to deploy nothing and deployed the union once after the merge (SQL first). Worth a
  line in the runbook's wave-lead routine for fix waves.
  **Done (before wave 21):** the wave lead's routine says a fix wave deploys once, after the merge.

- **#50 the mobile MCP's first command sends the app to the background (wave 17).** On a fresh wave
  simulator, ticket 21's first MCP tap brought the MCP's helper app to the front and SpringBoard
  showed; `simctl launch` brought the app back with its state kept. Suggested fix: runbook step 3
  says to make one harmless MCP call (a screenshot) before the first tap, then relaunch if the home
  screen shows.
  **Done (before wave 18):** runbook step 3 makes one harmless MCP call and relaunches before the first tap.

- **#51 a web sign-in sheet has no element list (wave 17).** Kroger's `login.kroger.com` page runs in
  an out-of-process ASWebAuthenticationSession; neither the MCP nor `idb ui describe-all` lists its
  fields. Ticket 21 drove it by coordinate taps read off screenshots. Suggested fix: one line in
  runbook step 5 for any OAuth sheet (Kroger, TrainingPeaks, Garmin).
  **Done (before wave 18):** runbook step 5 says how to drive an out-of-process sign-in sheet.

- **#49 server-side pushes land in every edge extract (wave 16).** Garmin's fan-out to dev
  `garmin-push` failed 45 of 45 epochs at 16:13 local, in the middle of the wave. Ticket 18 noted it
  as "not this app" but filed nothing, so the lead filed 18-012. Suggested fix: runbook step 7 says
  that a server error the run did not cause is still filed (kind bug, screen none), not skipped.
  **Done (before wave 17):** runbook step 7 says a server error the run did not cause is still filed.

- **#48 the chat spend is counted before the chat is known to cost anything (wave 16).** Ticket 18
  spent `COST chat` (1/5) to reach a chat, but that chat opened with no opener and made no model
  call. Suggested fix: a `COST refund WAVE chat NN` the agent runs when `vana_calls` shows no row
  for its run, or runbook step 5 notes that an old planning conversation opens without an opener.
  **Done (before wave 17):** runbook step 5 notes a chat spend that bought nothing.

- **#45 reaching Conversations costs an opener (wave 12).** The only way to the conversation list
  is Ask Vana, which spends a general opener ($0.02) that no COST kind counts (12-004 raised the
  gap). Suggested fix: a `COST spend WAVE chat NN` kind with its own cap.
  **Done (before wave 15):** `cost.mjs` has a `chat` kind, cap 5 a wave; runbook step 5 names it.

- **#46 a harness fix made after `wave --open` misses the wave (wave 14).** The lead built netcut
  (#36) before opening but committed it at the close, so the worktrees, cut from the wave's base, did
  not carry it and the prompts had to say so. **Done:** wave-lead step 1 now says to commit
  between-wave fixes before `wave --open`.

- **#36 no offline tool (wave 10).** Ticket 20 had to write its own per-app network cut:
  `netcut.dylib`, injected with `SIMCTL_CHILD_DYLD_INSERT_LIBRARIES`. It cuts `connect` while a flag
  file exists, and `vmmap` confirmed only that app's process loaded it. Proxy variables do nothing,
  because Dart ignores them. The library stayed in that ticket's scratch folder. Suggested fix: move it
  to `scripts/testing-wave/netcut/` with an `on`/`off` wrapper, and add a line to runbook step 5. Limit:
  `connectivity_plus` still reads "online", so the app's own offline banner path needs a device
  (20-006). Finding 20-007.
  **Done (wave 14 lead):** `scripts/testing-wave/netcut/{netcut.c,netcut.sh}` (flag and log paths from
  `NETCUT_FLAG`/`NETCUT_LOG`, passed as `SIMCTL_CHILD_*`), checked live on wave-pool-1: 158 connects
  blocked in 32 s, library mapped only in the app; runbook step 5 names it.

- **#42 simulator copy died mid-rsync (wave 13).** `capture.mjs` copies app data with
  `copyAppData`, which skips `Library/SplashBoard`, and `createSimulator` installs the mobile MCP
  helper before the data copy.
- **#43 MCP swipe skipped chat turns (wave 13).** Runbook step 5: slow idb drags with a duration
  whenever a run counts rows or turns.
- **#44 two tickets on one account (wave 13).** Wave lead step 5: both prompts name the shared
  account and what the other run writes.
  Wave 15 confirmed it: 27 and 28 shared test@test.com, 28 was sent to the day before, and each
  run's SQL extracts named the other's rows and edge requests without a clash.
- **#39 mobile MCP read another simulator.** Runbook step 4 and 5: idb reads the screen
  (`describe-all`, `simctl io` screenshot), the MCP only taps and types. The helper-port cause is
  not looked into. Before wave 12.
- **#40 token in every console.** Runbook step 9 expects the hit, cuts only the matching lines into
  `console-redacted.log`, rescans it and keeps the rest as evidence. Before wave 12.

- **#38 edge extracts cross tickets.** Runbook, after the wave step 2: the lead reads the
  tickets' edge-log extracts side by side and matches each error to the run that made it. Wave 11.

**Lee's second walk-through, 2026-09-24** (after wave 9). Each item, what he chose, and where it landed:

- **#30 passwords printed.** `scripts/testing-wave/cred.mjs` (`type`, `file`, `new`, `update`,
  `list`) is the only way agents reach the credentials; none of its commands prints a password
  (tested). No password change (Lee): the leak stayed in a local transcript. Runbook names and
  step 5.
- **#31 copied simulators carry Lee's data.** The lead runs `scripts/testing-wave/clear-app.sh
  <udid>` on each copy: the app's data folder is emptied, the build stays, the app opens signed out
  with a fresh database (checked: 430 KB new database against the dev simulator's 3 MB). It refuses
  a simulator not named `wave-*`. Tickets that test the leftover data skip it. Lee wanted no extra
  reinstalls or rebuilds; this has neither.
- **#32 copies carried an old app.** A build now goes onto the dev simulator itself, so every copy
  inherits it; the wave-9 build (`52c68764`) was installed there, data kept. Build only when app
  code changed since `app-build.json` (Lee).
- **#33 `app-build.json` lagged.** The build check and any build happen before `wave --open`, and
  the prompt's commit wins if the two differ.
- **#35 idb typing.** Type with the mobile MCP, idb as fallback; read long values back with
  `idb ui describe-all` before submitting. Address format unchanged.

- **#34 one run's stop ended the other run's console (wave 9).** Ticket 16 stopped its log stream
  at 14:56:02Z and ticket 32's stream died the same second (SIGTERM). Runbook step 3 now saves
  the stream's PID in SCRATCH and step 9 kills only that PID.

- **#27 launch, #28 screenshots.** Runbook step 3 checks for SpringBoard after `simctl launch`
  and relaunches; step 5 names `simctl io screenshot` and the stale element list. Before wave 9.
- **#29 `app-build.json` null in worktrees.** Moot while no build is needed: wave 8 committed it
  (`742d2f16`) before wave 9 opened; a wave that builds commits it before spawning.

**Lee's walk-through, 2026-09-24** (wave 7). Each item, what he chose, and where it landed:

- **#3 evidence.** `findings.mjs index` fails on an Evidence path that exists neither under the
  testing-wave folder nor in the repo. `383a2753`.
- **#4 build lock.** Removed; two builds may run at once (Lee). `lock.mjs` keeps only the slot.
  `383a2753`.
- **#5 edge_logs.sh.** Reads the unified `logs` table through `/analytics/endpoints/logs`, fails on any
  answer that is not rows. `383a2753`.
- **#6 mobile MCP.** Its helper app (`com.mobilenext.devicekit-iosUITests.xctrunner`, not
  WebDriverAgent) is copied from the dev simulator onto every wave simulator; checked live on a new
  pool device. `383a2753`.
- **#7 env files.** The wave lead copies every `.env*` file into each worktree (Lee: agents see
  everything the main clone sees). Runbook, wave lead step 4.
- **#8 picture refresh, #9 drawings.** Moot: the testing wave writes nothing to the decisions page
  (Lee). The 31 ticket cards and three test-setup questions (mp-653, 657, 658) were removed from the
  record, the proposals and the page; the five paywall questions stay.
- **#12 accounts.** The Patrol account (`secrets/integration_test.env`) is an admin on dev with no
  Pro, so the nightly job gets past the paywall (mp-658 settled here). test@test.com keeps its
  three Grants (Lee).
- **#13 email.** Dev now asks for the emailed code and allows 30 auth emails an hour; prod allows 30
  an hour and still confirms on its own until Lee rules on mp-667. Ticket 32 tests signup and
  forgot password through the Gmail tool. Resend's `mealvana.io` domain is verified.
- **#14 notes without Findings.** The wave lead reads every `notes.md` at the close and files what
  the agent did not (wave 7: 09-013). Runbook, after the wave step 2.
- **#15 decision quote.** Already enforced by `index` before today; the part no check can see
  (filing a clash as an idea) stays with the prompt.
- **#16 live timing.** The rule is in the runbook (step 5): times around every wait, "not seen live"
  when missed.
- **#17, #23, #24, #25 Patrol.** No Patrol in testing waves (Lee). The seven wave-added flows,
  their exclusion-list rows and admin_bypass's Codemagic targets were removed; the older flows and
  the nightly runner are unchanged. `f2c7d8ac`.
- **#18 tickets.** Tickets 10–31 re-read: Patrol criteria and flow blockers gone, and five
  shared-account clashes made into blockers (16 after 14, 17 after 16, 19 after 20, 27 after 26, 31
  after 30).
- **#20, #22 simulators.** The wave lead makes one simulator per ticket before spawning and drops
  them at the close; agents never claim.
- **#21 builds.** The wave lead builds only when app code changed since `app-build.json`'s commit,
  from a clean worktree, once; agents never build.
- **#26 shared scratch folder (wave 7).** Each ticket gets its own scratch folder, and the runbook
  bars printing anything that reads a secret. The RevenueCat key that reached ticket 08's local
  transcript is not rotated (Lee).
- **`timeout` missing on this Mac (wave 7).** Moot with Patrol gone.

- **#24, flows copied each other's helpers (part).** `buyMonthlyInTestStore`, `dismissWhatsNew`,
  `openSettings`, `signOutFromSettings`, `logInWithEmail` and `entitlementRows` moved from the
  relogin and restore flows into `integration_test/helpers/e2e_account.dart` before 08 and 09.
  Still open: the three noSettle copies of `deleteFromPaywallMenu`. 09-24, this commit.
- **Cleanup that can't take another run's account.** `sweep-accounts.mjs delete --id <id,id>
  --apply` deletes only the named throwaway accounts; the three flow headers point at it, since a
  bare sweep would also delete another agent's live account. Wave 6.
- **ssot-conflict quoting (#15), partly.** With the rule in the prompt, both of wave 6's
  ssot-conflicts (06-002, 07-002) quoted their decision word for word. The `index` check is still
  open.

- **#10, tickets 06–09 chained on a paid account that lapses.** 06, 07 and 08 each sign up and
  buy their own Test Store Monthly and finish within 20 minutes; 09 buys, cancels or lets the
  25-minute lapse stand in, and keeps the lapsed account for 10. Ticket 05's account and two
  wave-3 leftovers swept. Lesson for ticket writing: chain tickets only on account states that
  do not expire (lapsed, deleted), never on a paid one. 09-24, `43fdae9a`.
- **#2, run logs gitignored.** `.gitignore` now keeps `.scratch/testing-wave/runs/**/*.log`;
  the token scan still runs before the commit. 09-24, `43fdae9a`.
- **#1, `wave --open` had no ticket filter.** `sync.mjs wave ... --only NN,NN` or `--max N`
  (refuses a ticket off the frontier); the implement-lee skill says to use it when a feature
  caps its waves. 09-24, `43fdae9a`.
- **#19, the two suite tests red before the waves.** The ci_config contract test now asserts
  pr-validation is PR-only (Lee 08-21), and the wave lead runs the CI gate's own command
  (`flutter test --exclude-tags="integration || e2e"`), which leaves out the live-token
  TrainingPeaks test. 09-24, `35b706ac`.
- **#11, dev had no code fixtures.** `scripts/testing-wave/seed-codes.mjs` (`seed`, `list`,
  `own <user id>`) and the runbook's step 8 note; seeded on dev 09-24. Retests of 11-001 and
  11-008 can run now. 09-24, this commit.
- Patrol reported a skipped flow as passed; the runner now fails on skips
  (`PATROL_FAIL_ON_SKIP`, `skipFlow()`). Wave 3, `ff1baafc`.
- The redeem flow's header now says what a thrown wait leaves on dev and how to sweep it. Wave 5,
  `fe14603c`.
