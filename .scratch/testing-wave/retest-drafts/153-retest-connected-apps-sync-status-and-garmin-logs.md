# 153: Retest: Connected Apps, sync status, FinalSurge's look-back and Garmin's server logs

**Status:** ready-for-agent
**Blocked by:** 138.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** fix ticket 138 and the 2026-09-26 triage, about ten checks a run.

**What to build:** A retest run on the testing build (`app-build.json`) on test@test.com's real integrations. It re-runs each Finding's steps against ticket 138's fixes, reads the Garmin functions' logs, and runs the folded Connected Apps follow-ups. Nothing is fixed during the run. Follow `RUNBOOK.md`.

**Accounts and start state:** test@test.com, app data cleared. At the start, SELECT `integrations` for it (provider, is_active, sync_status or status, last_sync_at, last_sync_status, updated_at: named columns, never tokens). Expected: TrainingPeaks and V.O2 at `requires_reauth`, FinalSurge and Garmin active. Never disconnect Garmin on this account (Lee's real Garmin feed) and never finish a TrainingPeaks or V.O2 reconnect (no sandbox login in the credentials file).

**Shared account:** test@test.com. Other runs may log meals on it; this run writes only integration sync rows.

**COST:** none.

## Checks

1. **A network error keeps requires_reauth (118-002).** `netcut.sh launch`, then `on --relaunch`: the sign-in sync runs offline. Settings > Connected Apps. *Pass:* TrainingPeaks still shows Reconnect (not Sync Now and the write switch). `integrations` stays `requires_reauth`, and any stored message is plain words with no address, port or URI. *Verify:* screen, SELECT.
2. **A one-time Reconnect notice, and the last good sync (118-007).** Online, cold start: the first sync finds TrainingPeaks and V.O2 need signing in. *Pass:* the Timeline shows one notice naming them, with Reconnect to Connected Apps. A relaunch does not show it again. On the card, "Last synced" is the last successful sync, not the last attempt. *Verify:* screenshots, SELECT last_sync_at vs the attempt time in the console.
3. **Garmin's inactive token says Reconnect (118-016).** Read `garmin-backfill` logs for the sign-in minute. *Pass:* if Garmin answers "Token is not active", the garmin row turns `requires_reauth` and Connected Apps shows Reconnect. A rate limit stays a quiet "try next session". If Garmin answered 200, record "not reproduced today". *Verify:* edge logs, SELECT, screen.
4. **last_sync_at is UTC (117-001).** After the sign-in sync, SELECT last_sync_at for each provider and compare it with the sync's UTC time in the console. *Pass:* within a minute of the real UTC instant, not five hours off. *Verify:* SELECT, console.
5. **The Garmin note names Sync Now (119-008).** Connected Apps > the Garmin card. *Pass:* the note says Sync Now, matching the button. *Verify:* screenshot.
6. **Reconnect opens the sign-in sheet; Sync Now twice (118-010).** Tap Reconnect on TrainingPeaks, then cancel the sheet. Same for V.O2. On a working connection (FinalSurge), tap Sync Now twice fast. *Pass:* each Reconnect opens its provider's sheet, and a cancel leaves Reconnect as it was, with no error snackbar. The double Sync Now runs one sync (one console sync line, one last_sync_at change). *Verify:* screenshots, console, SELECT.
7. **FinalSurge looks back 7 days (100-006, 100-011 rewritten).** Read the FinalSurge fetch in the console at sign-in: its start date. *Pass:* the fetch starts 7 days back. A workout FinalSurge marks completed in that window is done on the Timeline (SELECT `activities` status for the Sep 24 runs 29-002 named, or any past-week workout the payload marks WorkoutCompleted). 100-011 as written needed a completion arriving for today, which the feed cannot be made to send, so it was not run in wave 39. It is folded in here as "any completed workout in the 7-day window lands". Deletions are flagged only from today on (138 item 10). *Verify:* console, SELECT.
8. **Garmin's server logs: skipped, not errors; no headers (112-010, 121-010).** `scripts/edge_logs.sh` for `garmin-push`, `garmin-auth` and `garmin-user-mapping` over the run's window, plus an hour before. *Pass:* pushes for unmapped Garmin users are logged once per request as skipped and are not counted in "Processing complete" errors. No request headers, caller IPs or the expected client id appear in garmin-auth lines. The two dev orphans (`dad6fb42…`, `1df3fb7b…`) no longer push after the lead deregistered them. *Verify:* edge-log extract.

**Not counted (need a login this repo does not hold, or a Garmin account):** 117-013 and 125-006 (the TrainingPeaks sharing sheet on an account whose TrainingPeaks works: Keep Sharing, Turn Off Sharing, swipe-down, and after a reconnect) and 118-010's "finish the reconnect" leg need a TrainingPeaks sandbox login. The Garmin disconnect and account-delete deregistration (112-010, 121-010 items 1-2) need a throwaway account connected to a Garmin test user. Each gets a verdict row "not run: needs <login>" and goes to the lead's report for Lee.

**Findings:** 118-002, 118-007, 118-016, 117-001, 119-008, 100-006, 112-010, 121-010; follow-ups 118-010, 100-011 (rewritten), 117-013 and 125-006 (not counted).

**Decisions:** Lee's rulings in `triage-20260926.md` (118-007, 100-006, 112-010/121-010).

**Touches:** test@test.com's `integrations` rows through normal syncs only. No connection is removed or finished. No account created.

- [ ] Runs by the runbook, with a look-around on every screen, nothing fixed. No RevenueCat or database writes the ticket doesn't name, even on your own account.
- [ ] `RUNS/verdicts.md`: one row per check and Finding id, with evidence under `runs/153/`.
- [ ] Each Finding listed is closed with evidence or a new bug Finding. The not-counted rows say what login they need.
- [ ] test@test.com's integrations end in their start state (SELECT at the end).

Next: /implement-lee testing-wave
