# 68-008 · Retest of 49-004: Garmin is active and requires_reauth on the server, but neither the Timeline notice nor the Connected Apps Garmin card tells the athlete to sign in again

- kind: bug
- status: triaged
- ticket: 68
- run: w7-20261008T2309Z
- screen: Timeline (macro dashboard) and Settings > Connected Apps
- decision: 

**Steps.**
1. Observe-only check 12 (49-004). integrations at sign-in (23:10Z): garmin is_active true, last_sync_status success.
2. At 23:44:17Z integrations read garmin is_active true, last_sync_status requires_reauth, last_sync_error reauth_required, updated_at 23:38:08Z (written during ticket 69's Garmin work on another device of the same account; expected per the prompt).
3. Looked at this device's Timeline (23:44Z), relaunched the app (23:44:39Z), pulled to refresh, then opened Settings > Connected Apps.

**Expected.**
Some surface tells the athlete Garmin needs them to sign in again: the Timeline notice 'Garmin needs you to sign in again to keep syncing.' with Reconnect and X, or at least the Connected Apps card's 'Sign in again to keep your workouts syncing.' with Reconnect.


**Actual.**
Nothing. No notice on the Timeline before or after the relaunch and the pull-to-refresh (12n, 12o, 12p); no Garmin line in the console. The Connected Apps Garmin card shows only Sync Now and 'Garmin syncs automatically when your watch uploads…' (12q). From code (unverified), the notice fires only when this device writes the status, and Garmin is push-only, so a phone never writes it: an athlete whose Garmin token died on the server is never told. Words, Reconnect, X and relaunch of the notice: not run, the notice never appeared. Sync Now was not tapped (ticket 69's area, and a write on integrations).


**Evidence.**
- runs/68/db-integrations-start.txt: garmin success at the start.
- runs/68/db-integrations-check12.txt: garmin requires_reauth at 23:44:17Z.
- runs/68/12p-after-pull-refresh.png: Timeline with no notice after relaunch and refresh.
- runs/68/12q-connected-apps-garmin.png: Garmin card with no sign-in-again line.

**Decision quote.**
> 

**Triage.**
- triaged · fix ticket 77 (Garmin reauth read from the integrations row on every device; a dead token on the automatic backfill is an expected_failure), fix wave 8 · Lee, 2026-10-09
