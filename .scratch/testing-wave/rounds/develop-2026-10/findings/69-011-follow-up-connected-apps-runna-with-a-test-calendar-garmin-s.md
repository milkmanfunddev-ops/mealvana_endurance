# 69-011 · Follow-up: Connected Apps, Runna with a test calendar, Garmin Sync Now after a reconnect, Last synced text after a reconnect, Delete synced data on a disposable account

- kind: followup-test
- status: open
- ticket: 69
- run: w7-20261008T2311Z
- screen: Connected Apps
- decision: 

**Steps.**
1. Runna: add a test Runna calendar URL to the credentials file (CRED has none today), then Connect → sync → Disconnect;
   check the `integrations` runna row appears and is deleted, and that no console line, screenshot or Sentry event
   carries the URL (`feed_validation_error` passes `e.toString()`).
2. Garmin: reconnect the dev Garmin link (it is requires_reauth since 23:38:08Z), then Sync Now: record what it
   re-pulls (code: the whole activities table plus a 90-day Garmin backfill) and the snackbars.
3. After a TrainingPeaks reconnect the card showed "Last synced: 16 minutes ago" (the pre-disconnect time) while the
   server row read pending with last_sync_at null; after reopening, no time showed. Check what the card should say.
4. Delete synced data on a disposable account with its own provider link (hard-deletes server rows).
5. Turn Off Sharing, then terminate and relaunch: the toggle and `flutter.tp_writeback_enabled` should both stay off,
   and no fuel plan should be written to TrainingPeaks while off.

**Expected.**
Every connect, sync and disconnect leaves the card, the row and the console in agreement, with no credential printed.

**Actual.**
Not run (Runna: no test calendar URL; Garmin: link expired; Delete synced data: not run by the ticket).

**Evidence.**
- runs/69/k01-connected-apps.png card states at the section's start
- runs/69/k15-after-turn-off.png "Last synced: 16 minutes ago" right after the reconnect

**Decision quote.**
> 

**Triage.**

