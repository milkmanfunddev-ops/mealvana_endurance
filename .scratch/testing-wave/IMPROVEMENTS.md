# Testing-wave improvements

A running list of ways to make the testing loop itself better: the harness, the runbook, the
tickets, the wave lead's routine. App bugs are not listed here; they are Findings.

**How to use it.** The wave lead reads this file before opening a wave and appends to it after
the review, one entry per lesson. Pick one or two open items to fix between waves, or ask Lee
which are worth it. When an item is fixed, move it to Done with the commit.

Each entry: what went wrong or cost time, where it was seen, and the suggested fix.

## Open

- **#37 an SSOT clash with a ratified spec rule has no decision id (wave 10).** 30-003 contradicts
  "The math (RATIFIED)" in `docs/ssot/spec/fueling/during-workout-carbs.md`. `findings.mjs` accepts an
  ssot-conflict only with an `mp-NNN` id, so the agent filed it as a bug that quotes the spec.
  Suggested fix: let `decision:` take a `docs/ssot/spec/...` path plus a heading, and have `index`
  check that the quote appears in that file.

- **#41 a setting that starts empty can't be put back (wave 11).** Saving Profile & Preferences with
  an empty field keeps the old value (31-004), so a ticket that changes a setting and restores it
  must pick one that is not null. Suggested fix: one line in ticket 31's retest and in the
  ticket-writing notes.

## Done

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
