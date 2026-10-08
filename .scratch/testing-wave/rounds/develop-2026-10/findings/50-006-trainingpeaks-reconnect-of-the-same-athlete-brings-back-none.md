# 50-006 · TrainingPeaks reconnect of the same athlete brings back none of the 43 hidden past workouts, though the Disconnect dialog says they come back (32-011)

- kind: bug
- status: triaged
- ticket: 50
- run: w5-20261008T1720Z
- screen: Connected Apps; Timeline
- decision: 

**Steps.**
1. test@test.com, TrainingPeaks connected as athlete "Lee Martin". Long-press TP Sync Now → dialog "Your synced
   workouts will be hidden … They come back if you reconnect." → Disconnect (17:42:43Z).
2. Connect → TP sandbox sheet → lee.tri → Allow → Keep Sharing (17:44:58Z), athlete again "Lee Martin".
3. Sync Now (17:45:16Z). Read local Drift (read-only) and server `activities` for `synced_from_provider='training_peaks'`.

**Expected.**
The workouts hidden at disconnect come back after reconnecting the same athlete, as the dialog promises; local and
server agree.

**Actual.**
Disconnect: console "🧹 Disconnect training_peaks: removed 43 workouts"; Drift: all 43 `hidden_by_disconnect=1,
needs_upload=1`. Reconnect + Sync Now: "TrainingPeaks sync complete: 0 workouts imported", `workouts_synced: 0`;
Drift still 43 hidden (scheduled 2026-02-03 … 2026-09-24). Nothing was unhidden.
From code (unverified): `syncAll` → `syncWorkouts(numDays: 45)` fetches only the next 45 days AHEAD
(`training_peaks_sync_service.dart:116-121, 745-753`), and only a fetched match is revived
(`unhideAndUpdateFromProvider`, `:297, :499`). Every past workout hidden at disconnect therefore stays hidden for
good; only future planned ones within 45 days could return.
Also: the hide never reached the server. 17:42Z through 17:46Z the server still had 40 rows `hidden_by_disconnect
null` and 3 `true` (the 3 from wave 3), while Drift had all 43 hidden with `needs_upload=1`, also after the Sync
Now and after a cold relaunch (17:46:24Z; read again 17:47:03Z: unchanged on both sides). The hides reached the server only at Sign Out (17:49:29Z, which uploads dirty records): then 43 `true`. So after this run the server, too, hides all 43 past TrainingPeaks workouts while TrainingPeaks is connected again. So a second device, or this one after an app clear, would show all 40 workouts again while this phone hides
them.

**Evidence.**
- runs/50/n01-tp-disconnect-dialog.png the dialog's promise
- runs/50/db-tp-activities-before-disconnect.txt server before
- runs/50/db-tp-activities-after-disconnect.txt server after disconnect (unchanged)
- runs/50/drift-tp-activities-after-sync.txt local after reconnect + sync: 43 hidden, needs_upload 1
- runs/50/db-tp-activities-after-sync.txt server after the sync (unchanged)
- runs/50/db-tp-activities-after-relaunch.txt server after a relaunch (unchanged)
- runs/50/db-tp-activities-after-signout.txt server after Sign Out: 43 hidden
- runs/50/n14-tp-after-sync.png Synced!, Last synced: Just now
- runs/50/console-redacted.log 12:42:44 "removed 43 workouts"; 12:45:25 "0 workouts imported"

**Decision quote.**
> 

**Triage.**

