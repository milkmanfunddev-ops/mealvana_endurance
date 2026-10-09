# 90: Retest: Connected Apps, dead tokens and the imported event after wave 8 (ticket C, part 2)

**Status:** ready (round develop-2026-10, test wave 9, after the wave-8 rebuild)
**Labels:** retest, round:develop-2026-10, area:integrations, area:events, area:privacy, area:sync
**Branch:** `develop-next` (worktree per ticket, branched from the round's base after fix wave 8 lands)
**Source:** TRIAGE.md rulings of 2026-10-09 (wave 7 triage) and the wave-8 fix tickets' retest lines: followup 69-011, 69-005 step 3; fix retests for tickets 73, 76 (69-012), 77 (68-008, 69-010), 80 (69-004 and Q3, provider_event_id), 82 item 4 (69-009), 84; ticket 52 only if a Runna calendar URL is in `CRED list` (none on 2026-10-09).
**Blocked by:** fix wave 8 (landed 4b146f27) and its rebuild; the lead's start SQL (Lead notes); runs in wave 9 only if the three-simulator cap allows (85, 86 and 87 take the three slots, so 90 waits for a free one), never beside 87, and only after tickets 85 and 86 have finished with Connected Apps on test@test.com (the start SQL kills the TrainingPeaks and Garmin tokens their devices also read).
**Next:** `/testing-wave develop-2026-10 --only 90`
**Model:** opus

**Runs by:** `docs/testing-wave/RUNBOOK.md`. RUNS = `.scratch/testing-wave/rounds/develop-2026-10/runs/90/`, Findings in `.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on every screen capped at ONE followup-test Finding per screen (IMPROVEMENTS #115), every problem a Finding, nothing fixed. Edge logs through the Supabase MCP `query_logs` on dev (ruling 02-004); Sentry through the Sentry MCP, read-only, dev project. Every quoted string below was re-read against `lib/`, `supabase/functions/` and `assets/config/content_defaults.json` at `4b146f27` (#130); if the screen or the log shows other words, the screen decides and the check records it. Note the clock time the run starts; check 9 reads logs and Sentry from that minute.

**Retest rule.** A check that passes closes the Finding named beside it: `PASS <id>` in `RUNS/notes.md` with evidence; a fix ticket closes when every check under it passes. A check that fails files a new Finding citing the old id (`Retest of NN-NNN`).

**Secrets (#112).** Before every `CRED type`, a fresh screenshot shows the focused field is the password field; nothing fetched from the web; no personal address in any header. A Runna calendar URL is a credential: never in a screenshot, note or console extract. The start SQL's stand-in link (`https://example.com/`) and dead refresh value (`tw90-dead-refresh-5f2c`) are fakes, not credentials; they may be quoted.

**Accounts and integration credentials:** the dev test account (test@test.com, user `607f9dd5-…`) only; TrainingPeaks through `CRED list`'s "TrainingPeaks test login" (`lee.tri`, `CRED type lee.tri`). No Garmin, V.O2, Final Surge or Runna login is in `CRED list`: no check signs in to those. This run writes only what a check names: the TrainingPeaks reconnect and its sharing toggle, a Final Surge sync, the Runna stand-in row (deleted by its Disconnect), and "IM NC 70.3" (`3e874ee3-…`) Location and name, both restored. **App data:** cleared by the lead, after the start SQL. **Cost:** none.

**Start state (the lead's SQL, Lead notes):** Garmin row active, `success`, token expired (its refresh token has been dead since September); TrainingPeaks row active with an expired access token and the dead refresh value; a Runna row whose link answers HTML.

## Checks (9)

1. **Fix 84 + fix 73 (TrainingPeaks refresh refused) + fix 77 (any provider's notice).** Log in as test@test.com (`CRED type`). The login sync refreshes TrainingPeaks with the dead token. Passes when:
   - the TrainingPeaks row reads `is_active true`, `last_sync_status requires_reauth`, `last_sync_error reauth_required` (SQL, named columns);
   - the console's report for it (`TrainingPeaks token refresh failed; reconnect required` or `TrainingPeaks token refresh failed`) carries `extra` `{statusCode: <n>, errorCode: <code or null>}` and no `responseBody`, and its error text reads `TrainingPeaksApiException: Token refresh failed (status: <n>…)` with no `Body:`; no console line contains `error_description`, `tw90-dead-refresh-5f2c` or a JSON body;
   - the Timeline shows "TrainingPeaks needs you to sign in again to keep syncing." with Reconnect and an X (the Garmin row says `success`, so TrainingPeaks is the first needing it).
   If the login sync did not try TrainingPeaks (no refresh line once the Timeline settles), run check 2 first, then TrainingPeaks Sync Now, and judge the same three points. Record the Runna and Final Surge rows after the login sync too (the login sync may already sync the stand-in Runna link; check 6 reads it).
2. **Fix 77 item 8 / 69-010 (second half) + fix 76 / 69-012 (the minute).** Settings → Connected Apps, first open of this launch (note the clock time to the second). The app fires garmin-backfill by itself (Garmin row `success`, cooldown clear on a cleared app). Passes when the console shows `expected_failure {area: garmin, reason: token_expired}`, no `error_reported` for area garmin and no `⚠️ [garmin]` box; the Garmin row reads `requires_reauth` / `reauth_required`; and the Garmin card shows "Sign in again to keep your workouts syncing." with Reconnect, no Sync Now. TrainingPeaks' card shows Reconnect too. The edge-log half of 69-012 is read in check 9.
3. **Fix 82 item 4 / 69-009, fix 73 + 64 (reconnect clears), 69-011 steps 3 and 5.** TrainingPeaks Reconnect → sign-in sheet → `lee.tri` (username typed, password `CRED type lee.tri` after a fresh screenshot) → Allow → the write-back sheet → Turn Off Sharing. Passes when:
   - without leaving the screen, the "Write fuel plan to TrainingPeaks" toggle reads off (AX value 0) at once;
   - the TrainingPeaks row reads `is_active true`, `last_sync_status` `pending` or `success`, `last_sync_error` null, `provider_athlete_id` `2687398` (SQL);
   - the Timeline's TrainingPeaks notice is gone (back to the Timeline; the Garmin one may show now, check 4 owns it).
   69-011 step 3: record the card's "Last synced:" text right after the reconnect and the row's `last_sync_at`. 69-011 step 5: terminate (read `flutter.tp_writeback_enabled` from the prefs plist: passes at 0), relaunch, Connected Apps: the toggle still reads off. Then turn the toggle on: card on, pref 1 (app terminated for the read). Leave sharing on.
4. **Fix 77 items 2–7 / 69-010 (first half), 68-008 (one device).** Long-press the "Connected Apps" title (Launch trail). Open Connected Apps twice more (Back, reopen). Passes when no garmin-backfill request from this user appears in the dev edge logs for these minutes, the console has no `garmin-backfill` call and no `error_reported` for garmin, and the Launch trail holds `garmin auto backfill skipped: requires_reauth` exactly once for this launch. Terminate, relaunch: passes when the Timeline shows "Garmin needs you to sign in again to keep syncing." with Reconnect and X. X: gone; switch to another tab and back: still gone; terminate and relaunch: back. Then the row-from-server half (68-008): write the flag `90-garmin-success` in the shared folder the lead names; the lead sets the Garmin row to `success` and writes `90-garmin-success-done`. Relaunch (inside the hour): passes when there is no Garmin notice and the Garmin card shows Sync Now (no automatic backfill: the 6 h cooldown from check 2 holds; record any garmin-backfill call). Write `90-garmin-reauth`; the lead sets `requires_reauth` / `reauth_required` back and writes `90-garmin-reauth-done`. Relaunch: passes when the notice is back and the card shows Reconnect. Closes 69-010 (with check 2) and 68-008.
5. **Fix 73 (offline writes `network`, success clears).** V.O2 is not connected and has no login, so this uses Final Surge, the provider on the same shared step (Lead notes). `netcut.sh launch UDID SCRATCH`, Connected Apps, `netcut.sh on SCRATCH`, Final Surge Sync Now. Passes when the snackbar and the error line under the cards read "Could not reach Final Surge. Check your connection and try again.", and a read-only Drift copy of `integrations` reads final_surge `last_sync_status error`, `last_sync_error network`. Record the console (`Final Surge sync failed: network` is a degraded report by design). `netcut.sh off SCRATCH`; read the server row (record whether `network` reached it). Final Surge Sync Now again: passes when the error line clears and both Drift and the server read `success` with `last_sync_error` null.
6. **Fix 73 item 2 (Runna `not_a_calendar`).** The Runna card shows connected (the stand-in row). Runna Sync Now. Passes when the snackbar and the error line read "This link isn't a Runna calendar. Copy a fresh link from Runna and connect again.", and the server row reads `last_sync_status error`, `last_sync_error not_a_calendar` (never a sentence, never the link). Long-press Sync Now → Disconnect: "Runna disconnected", card on Connect, the row deleted on the server (SQL count 0). Then Connect → paste `not a link`: record the line shown (code: "That doesn't look like a calendar link. …"); Connect → paste `https://example.com/`: record the snackbar text and any `error_reported` (ticket 77's open question: the connect error still shows the exception text). No Runna row after either (SQL).
7. **Fix 52 / 69-011 step 1 (conditional).** Only if `CRED list` shows a Runna calendar URL row. If it does not: write "not run: no Runna calendar URL in CRED" and stop (the lead skips it; 52 stays open). If it does: Connect through CRED (never typed by hand, never in a screenshot), sync, record the workouts imported; then Disconnect: the row is deleted; no console line, screenshot or Sentry event holds the URL. 69-011 steps 2 (Garmin Sync Now after a reconnect: no Garmin login) and 4 (Delete synced data: needs a disposable account with its own provider link): not run, with those reasons. 69-011 closes when steps 3 and 5 (check 3) pass and 1, 2, 4 are recorded.
8. **Fix 80 item 2, item 4 and Q3 / 69-004, 69-005 step 3 ("IM NC 70.3", after check 3's reconnect).** SQL first: `select id, event_name, event_date, start_time, origin, location, event_subtype, provider_event_id from events where id = '3e874ee3-fd74-49ed-a92b-bf27efc6c06e'` (run 69: origin `training_peaks`, location null, subtype null). My Events → "IM NC 70.3" → Edit Event → Location `Raleigh` → pick "Raleigh, North Carolina" → Save Changes. Passes when it saves with no "Please select a race distance", and the row reads the new `location`, `event_subtype` null, `origin` still `training_peaks`. Connected Apps → TrainingPeaks Sync Now. Passes when the row keeps its Location and origin, no second "IM NC 70.3" row exists (SQL count by name), and `provider_event_id` is now set (the sync's name-and-date match stores the TrainingPeaks id). Then Edit Event → name `IM NC 70.3 tw90` → Save: `origin` becomes `manual`. TrainingPeaks Sync Now: passes when no new "IM NC 70.3" row appears (the sync now matches on `provider_event_id`). Restore: name back to `IM NC 70.3`, Location cleared, Save; record the final row (origin stays `manual`: Lead notes).
9. **Fixes 76 and 84 / 69-012, the run's log and Sentry check (LAST).** Dev edge logs (`query_logs`, function_logs for garmin-backfill, check 2's minute ±2 min): passes when the refresh line reads `[garmin-backfill] Token refresh failed { status: <n>, error_code: <code or null> }` (Deno prints the object in its inspect form; match on `Token refresh failed`; run 69 saw 400 / `invalid_grant`), and no garmin-backfill line holds `error_description`, `Invalid refresh token`, `eyJ` or a base64 run of 40+ characters. If Sentry has a `[garmin-backfill] <type> backfill rejected` warning for that minute, its `extra` holds `userId`, `summaryType`, `status`, `error_code`, `token_inactive` and no `body`. Dev Sentry events from this run's device between the run's start and now: passes when every TrainingPeaks refresh event holds `statusCode` and `errorCode` in `extra` and no `responseBody`, and no event's message, exception value or `extra` contains `error_description`, `Invalid refresh token`, `eyJ` or `tw90-dead-refresh-5f2c`, and there is no Sentry event for check 2's Garmin 409. `grep` `RUNS/console-redacted.log` for the same four strings: none. Ticket 84's other paths (V.O2, Final Surge and Garmin code exchanges with a stale code) need provider logins: not run, covered by `provider_error_redaction_seam_test.dart`. Closes 69-012 and fix 76; fix 84 with check 1.
## Exit
- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 90 … --round develop-2026-10`; index exits clean.
- [ ] `RUNS/notes.md` lists each check with `PASS <id>`, the new Finding's id, or "not run" with its reason; the run's start time and check 2's second.
- [ ] TrainingPeaks left connected with sharing on; Garmin left `requires_reauth` (as the round found it); Final Surge `success`; no Runna row; "IM NC 70.3" name restored, Location cleared. `netcut.sh off SCRATCH`; helpers stopped by PID; log stream stopped; app terminated; `LOCK release slot testing-wave-90`; simulator released. Shared flag files removed.
- [ ] Console redacted. `findings/90-*.md` and `runs/90/` committed on the ticket branch, explicit paths.

## Lead notes

**Start SQL (dev, the lead, before the app clear; the agent never runs a write):**
```sql
-- Garmin: active, success, access token expired; the refresh token is already dead (69-010, 69-012)
update integrations set last_sync_status = 'success', last_sync_error = null,
       token_expires_at = now() - interval '1 day'
 where user_id = '607f9dd5-6fa7-48ee-a628-720d4a0506a1' and provider = 'garmin';
-- TrainingPeaks: expired access token, dead refresh value (fix 84's refusal)
update integrations set token_expires_at = now() - interval '1 day',
       refresh_token = 'tw90-dead-refresh-5f2c'
 where user_id = '607f9dd5-6fa7-48ee-a628-720d4a0506a1' and provider = 'training_peaks';
-- Runna: a link that answers 200 with HTML, so the sync stores not_a_calendar (fix 73)
insert into integrations (user_id, provider, access_token, provider_athlete_id, is_active)
values ('607f9dd5-6fa7-48ee-a628-720d4a0506a1', 'runna', 'https://example.com/', 'runna-tw90', true);
```
**Mid-run flips (check 4), on the agent's flag files:**
```sql
update integrations set last_sync_status = 'success', last_sync_error = null
 where user_id = '607f9dd5-6fa7-48ee-a628-720d4a0506a1' and provider = 'garmin';   -- on 90-garmin-success
update integrations set last_sync_status = 'requires_reauth', last_sync_error = 'reauth_required'
 where user_id = '607f9dd5-6fa7-48ee-a628-720d4a0506a1' and provider = 'garmin';   -- on 90-garmin-reauth
```
**Close SQL, if wanted:** `update events set origin = 'training_peaks' where id = '3e874ee3-fd74-49ed-a92b-bf27efc6c06e';` (check 8's rename leaves it `manual`; the stored `provider_event_id` keeps the sync from importing it twice either way).

Questions for the lead:
1. **Order.** Check 8 needs check 3's reconnect (a working TrainingPeaks token); check 9 reads everything from the run's start, so it stays last.
2. **V.O2 for fix 73's offline line.** The vdot row is inactive with its tokens emptied, and `CRED list` has no V.O2 login, so the ticket's "offline Sync Now on V.O2" cannot run. Check 5 uses Final Surge, which goes through the same `recordSyncFailure`. Accept, or add a V.O2 login to CRED?
3. **The Runna stand-in.** `https://example.com/` answers HTML, which is the not-a-calendar path. A real Runna link that has died may instead answer 404 (`http_404`, "Runna sync failed (status 404)."). Accept the stand-in for 73's line?
4. **Shared account.** The start SQL changes rows every device signed in as test@test.com reads. A ticket 85 or 86 simulator that signs in, syncs TrainingPeaks or opens Connected Apps after it gets the dead-token paths too. Run 90 after 85 and 86 are done with those, or tell them.
5. **68-008 across two devices.** Check 4 proves the launch pull on one device with your two flips. The original case (another device moves the row) can also be had for free: a ticket 86 simulator, signed in before check 2, relaunched after it, should show the Garmin notice. Use it if 86 is still up.
6. **TrainingPeaks' real answer** to the dead refresh is not known from code; checks 1 and 9 pass on the shape (status, code or null, no body), not on `invalid_grant`.
7. **Ticket 52** stays open: `CRED list` on 2026-10-09 has no Runna calendar URL (Lee owes one, TRIAGE wave 7 close).
8. **Ticket 77's open question** (the Runna connect error shows exception text) and ticket 72's question 2 (`CarbLoadingService` ignores `uploadDirtyRecords` results) are not checked here; check 6 records the connect text.

Next: /testing-wave develop-2026-10 (wave 9)

## Lead rulings at the wave-8 close (2026-10-09)

- Runs in wave 10, alone with respect to test@test.com's integration rows (no 85/86/87 simulator up), after the lead's start SQL above; the lead runs the mid-run flips on the agent's flag files and the close SQL.
- Note 2: Final Surge stands in for V.O2 on 73's offline line; accepted.
- Note 3: the `https://example.com/` stand-in is accepted for `not_a_calendar`.
- Note 5: use a still-up simulator for the two-device case only if one is available; otherwise check 4 stands.
- Notes 1, 6, 7, 8: as written.
