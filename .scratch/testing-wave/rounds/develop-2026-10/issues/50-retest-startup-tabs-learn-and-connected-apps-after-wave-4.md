# 50: Retest: startup, tabs, learn and connected apps after wave 4

**Status:** in-progress (wave 5, 2026-10-08)
**Labels:** retest, round:develop-2026-10, area:startup, area:integrations
**Branch:** `develop-next` (worktree per ticket, branched from the round's base after fix wave 4 lands)
**Source:** TRIAGE.md rulings of 2026-10-08 (wave 3 triage): followups 32-010, 32-011, 32-012, 32-013; fix retests for tickets 34 (22-001 resume tap, 32-008), 37 (sync error codes), 40 (32-001), 41 (32-007, 32-015), 44 (30-004 preview numbers), 46 (32-002, 32-003, 32-004), 47 (32-005, 32-006); 29-001 (override save keeps profile fields)
**Blocked by:** fix wave 4 (34, 37, 40, 41, 44, 46, 47) and its rebuild; runs in wave 5
**Next:** `/testing-wave develop-2026-10 --only 50`
**Model:** opus

**Runs by:** `docs/testing-wave/RUNBOOK.md`. RUNS = `.scratch/testing-wave/rounds/develop-2026-10/runs/50/`, Findings in `.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on every screen capped at ONE followup-test Finding per screen (IMPROVEMENTS #115), every problem a Finding, nothing fixed.

**Retest rule.** A check that passes closes the Finding named beside it: `PASS <id>` in `RUNS/notes.md` with evidence; a fix ticket closes when every check under it passes. A check that fails files a new Finding citing the old id (`Retest of NN-NNN`).

**Secrets (#112).** Before every `CRED type`, a fresh screenshot shows the focused field is the password field; nothing fetched from the web; no personal address in any header.

**Accounts:** the dev test account; ticket 49 logs and deletes meals on it in the same wave (a meal card that moves is theirs). This run writes only what a check names: the Connected Apps section (last) and one nutrition-target override that it reverts. **App data:** cleared by the lead. **Cost:** none.

## Checks (12; the lead may cut 50a = 1–6, 50b = 7–12)

1. **40 / 32-001.** Log In, Timeline, Learn, Settings, the Sign Out dialog and Connected Apps read as words, no raw key anywhere. Screenshot each.
2. **34 / 22-001.** Signed in, schedule a local notification the app can fire (an activity reminder; read `NotificationService` for the shortest path), background the app, tap the notification when it arrives: the app resumes onto the activity; `ios_un_response_payload` is cleared (plist read, app terminated afterwards). If no local notification can be made to fire on a simulator, write "not run" and leave it to ticket 51.
3. **34 / 32-008.** Background, let the native side write a trail line, resume: the line is in the trail on the same resume, three of three tries.
4. **46 / 32-002.** Open `com.milkman.mealvanaendurance://athlete/feedback` (two slashes) signed in: Page Not Found, Go Home lands on the Timeline. Signed out (after step 12): Go Home lands on Welcome.
5. **46 / 32-003, 32-004.** `/buy-credits` by deep link: a close/back control works; the copy names describe, photo and formula-kit calls, no "conversations".
6. **44 / 30-004.** Settings → Nutrition targets (or the daily-plan preview reachable signed in): a Workout day with a session over 1 h shows protein 1.6 g/kg where applicable (cite the screen and the inputs). **29-001:** save an override and reopen Profile: body fat, lifestyle, training phase, sweat test and the Garmin timestamps are unchanged (SQL on `users`, named columns); revert the override.
7. **41 / 32-007.** `netcut.sh on`: offline login, offline cold start, an offline lesson: breadcrumbs, no `error_reported`; `netcut.sh off`. **41 / 32-015:** exit a lesson at 15 %: no `education_video_completed`; at the end: one.
8. **32-010.** Event "Test": `event_date` vs `start_time` on the row and what the app shows; read the events repository for which column rules.
9. **32-012 + 32-013.** Welcome reached while signed in (deep link `/welcome`); Events, Learn and Log a Meal untried paths. One Finding per screen.
10. **47 / 32-005 (Connected Apps, LAST).** Disconnect V.O2: the card shows disconnected, not "needs reconnect"; the console shows no refresh attempt on the dead token.
11. **47 / 32-006 + 37.** Disconnect TrainingPeaks, reconnect with the test login (#112: confirm the focused field before `CRED type`), Sync Now: no `TokenExpiredException` on the first sync; the card's sync date updates without leaving the screen; `integrations.last_sync_error` is null or a code (`reauth_required`, never an English sentence); a relaunch logs no refresh failure.
12. **32-011.** Connected Apps untried paths: hidden workouts after reconnect, Delete synced data (read what it writes first; skip if it deletes server rows the ticket does not name), V.O2 connect has no test login (note it).

## Exit
- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 50 … --round develop-2026-10`; index exits clean.
- [ ] `RUNS/notes.md` lists each check with `PASS <id>` or the new Finding's id; the clock time the Connected Apps section started.
- [ ] Override reverted; TrainingPeaks left connected; nothing else written. `netcut.sh off SCRATCH`; helpers stopped by PID; log stream stopped; app terminated; `LOCK release slot testing-wave-50`; simulator released.
- [ ] Console redacted. `findings/50-*.md` and `runs/50/` committed on the ticket branch, explicit paths.

Next: /testing-wave develop-2026-10 (wave 5)
