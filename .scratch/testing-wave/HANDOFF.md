# Testing-wave handoff (2026-09-25, after wave 24)

Read this, then `RUNBOOK.md` (both "The wave lead's routine" and its "Fix waves: keep them fast"
block) and `IMPROVEMENTS.md`. `mealplanning` is pushed at `f8aee35e`; the main clone is clean
except `docs/BEVEL.MP4` (20 MB, left out on purpose) and `docs/ssot/.claude/` (stray, left out).

## Where the loop stands

- Every bug and SSOT-conflict Finding is fixed (fix tickets 33-85, waves 19-24, all merged and on
  dev), closed, or won't-fix. **Nothing fixed has been retested on a device yet.** 104 Findings sit
  at `triaged` waiting for a retest (75 bugs, 10 ssot-conflicts, 18 ideas, 1 follow-up). Only a
  passing retest closes a Finding (spec, Triage).
- Open and not ticketed: 138 follow-up tests, 26 ideas (list below).
- Test tickets still open: 13 (Apple sandbox on Lee's iPhone, `ready-for-human`) and 22 (Kroger
  match and hand-off; needs a Kroger certification shopper login, IMPROVEMENTS #52).
- Waiting on Xuan (QA repo owns the spec): Finding 30-005 (pre-workout timing label; SSOT B-2, I6
  and PW-021 forbid a clock-relative label) and the during-run band clamp (3 vectors skipped, ticket 63).
- Open on the decisions page: mp-660, mp-669, mp-680, mp-681, mp-682, mp-683. Do not add more
  during waves (Lee, 09-25); product questions go in ticket files or Findings.

## Do next, in this order

### 1. Rebuild the testing app (lead only)

`app-build.json` names `52c68764`; `lib/`, `ios/` (Info.plist, wave 19) and `assets/` changed a lot
since. Build once from a clean detached worktree at `mealplanning` HEAD with
`scripts/run_dev.sh -d <dev simulator udid>`, quit once it runs, remove the worktree, write the
commit to `app-build.json`, commit. Never `flutter build`, never build in the main clone.

### 2. Write the retest tickets (86-93) and one leftover fix ticket (94)

Retest tickets are test tickets (a scenario run on a wave simulator, Findings out), not fix
tickets. Each re-runs the steps of the Findings it lists, checks they pass, and turns each into
`closed` (pass, with evidence) or a new bug Finding. Each also carries up to ~1-2 of Lee's chosen
follow-up tests (step 3). Group by screen and account:

| Ticket | Area | Findings to retest | Setup notes |
|---|---|---|---|
| 86 R1 | Sign-in, sign-out, onboarding, settings copy | 02-001 02-002 02-003 02-006 03-002 03-004 03-009 06-003 09-004 09-013 12-003 14-003 14-004 31-001 31-014 32-001 32-002 04-008 | New accounts; two accounts on one device for 33's leak checks (14-004 runs on the dev simulator's leftover data: skip clear-app for it) |
| 87 R2 | Paywall and subscription | 05-004 05-005 06-002 07-002 08-001 09-001 09-009 10-002 11-003 11-004 11-012 02-004 32-007 | Test Store monthly purchase (lapses 25 min after purchase: plan waits). 07-002: cold launch offline >15 min after a period end. 05-005: app left open across the expiry. `seed-codes.mjs seed` first |
| 88 R3 | Meal-plan chat | 14-001 14-002 15-001 15-002 15-003 16-001 16-002 16-004 16-005 18-001 18-003 29-001 61-001 | test@test.com; one `COST spend WAVE plan` |
| 89 R4 | Previous plans, lists, Browse search | 17-001 17-002 17-003 18-004 19-003 73-001 | test@test.com; dev lists 4 of its 27 plans now (pre-09-16 archived plans dropped, known) |
| 90 R5 | Shopping and Kroger | 16-007 18-002 18-006 19-001 19-005 19-006 20-001 20-002 20-008 21-002 21-003 21-010 22-003 | netcut for 20-001/20-002; 22-003's Kroger screen half needs the certification login (else followup) |
| 91 R6 | Meal logging | 04-001 10-001 16-003 19-004 20-003 23-002 24-001 24-002 25-001 26-001 26-002 26-003 26-004 26-005 27-002 27-003 28-001 28-002 | `COST spend WAVE logging` for 23-002/24-001; 28-001/28-002 camera legs need a device (report not run) |
| 92 R7 | Timeline and fuelling | 09-002 27-001 27-006 30-001 30-002 30-003 30-004 | Clear test@test.com's `nutrition_target_overrides.during` (50.4 g/h) before 30-003, or expect override behaviour (mp-680). 30-005 is NOT retestable (waits on Xuan) |
| 93 R8 | Accessibility, layout, connections, dev button | 03-007 08-002 11-005 12-002 18-005 21-004 23-001 28-006 31-002 64-001 | VoiceOver labels via `idb ui describe-all`; 21-004/64-001 need a TrainingPeaks token the API refuses |

No device needed, the lead closes these from code, logs or SQL when writing the tickets:
05-006, 11-011, 02-007 (harness, fixed by 57), 18-012 (`garmin-push` now logs each failed record:
read the next fan-out's log lines), 09-003 (AD-001 photo cleared, verified by SQL on 09-25).

Ticket 94 (fix, one fable agent, batched list; see RUNBOOK "Fix waves"):
- Swap screen asks `search_meals` for 20 then drops blank-number meals, so it can show a short
  list: ask for more or filter server-side (ticket 74 note).
- Plan reveal's "Connect now" nudge still shows after "I don't use training plan apps"
  (`plan_reveal_screen.dart:243`, same guard as ticket 80's `declinedTrainingApps`).
- Emailed-code screens: auto-submit on the sixth digit (32-007 steps 2-3; ticket 81 added only
  the autofill hint).
- `RevenueCatService`: `_configureSettled` completes after a FAILED first configure, so a later
  `logIn` skips instead of waiting for the retry (ticket 85 review note).
- Settings' "Profile & Preferences" tile is a hardcoded string (`settings_screen.dart:817`).
- The iOS Speech Recognition / Microphone purpose strings still talk about voice notes about the
  nutrition plan; say it is for talking to Vana (ticket 79 note).

Commit the ticket files, then `/implement-lee testing-wave` runs them: retests at most two at a
time (one simulator each, RUNBOOK wave lead steps 2-5), 94 alongside as a fix ticket.

### 3. Ask Lee, in the terminal, before step 2's tickets are final

**Follow-up tests to ride along (Lee picks up to 10).** Suggested, all exercising code waves 19-24
changed: 17-005, 17-006 (earlier plan view and Previous plans sheet edges), 16-011 (confirm a draft
while the week has another confirmed plan), 19-009 (a deleted plan list rebuilds), 09-006 (Review
plan offline or tapped twice), 06-001 (paid account's offline cold launch), 08-004 (Subscription
screen for cancelled, ended and Grant plans), 11-006 (redeem offline), 27-004 (timeline Edit/Remove
paths), 18-008 (Browse untried paths).

**The 26 open ideas.** Suggest closing these as known limits of the Test Store, RevenueCat or the
harness (one line each in Triage): 05-001, 05-002, 05-003, 05-011, 06-010, 07-001, 07-003, 07-004,
07-005, 07-010, 08-007, 09-010, 20-007 (netcut is already a script, #36), 12-004 (its cost-kind half
is done, #45; the "opener spends a turn" half is a product call). Need Lee:
02-005 (delete the RevenueCat customer on account delete?), 11-002 (mp-660), 19-002 (mp-669),
12-005 and 14-005 (Vana's voice: evals, not tickets?), 16-006 and 18-007 (conversation titles,
partly done by 48), 17-004 (plans look alike: rename from 73 enough?), 17-007 (Back from an
earlier plan should land on the sheet?), 24-007 (photo preview on Review & Log), 28-004 (typed
barcode), 29-002 (FinalSurge completed workouts: a question for Xuan's spec).

## Gotchas

- Push: `mealplanning` pushes trigger no Codemagic build. git has no stored credentials; push with
  `GIT_ASKPASS` pointing at a script that runs `gh auth token --user lbm54` (the remote URL names
  lbm54; gh's active account is RPPLee). Delete the script after.
- Another session may be running waves on the same branch (#63): check `git log` and
  `waves.json` for an open wave before `--open`, forbid its files in your prompts, and merge
  `mealplanning` into your merge worktree before landing (#59).
- zsh does not word-split `$F`; use arrays. Never `git stash`.
- Dev test account test@test.com is vegetarian (a "salmon" search returns nothing for it).
- Prod needs, before any of these functions ship there: 38's two migrations (in order), 39's, and
  wave 22's two (`20260925150000`, `20260925150100` before `vana-action`). The cutover README lists them.
