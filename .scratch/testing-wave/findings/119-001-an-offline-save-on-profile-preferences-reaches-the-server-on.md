# 119-001 · An offline save on Profile & Preferences reaches the server only at sign-out, not when the app is back online

- kind: bug
- status: open
- ticket: 119
- run: w36-20260926T0031Z
- screen: Profile & Preferences
- decision: 

**Steps.**
Retest of 31-008 (Profile & Preferences: save while offline), on test@test.com.
1. `netcut.sh on SCRATCH --relaunch UDID` (00:36:30Z). Settings > Profile & Preferences, tick "I run with a water bottle", Save Changes (00:37:11Z).
2. Relaunch offline (00:37:26Z), reopen the screen.
3. `netcut.sh off` (00:37:49Z), relaunch online, wait; open Settings rows, the Timeline and Food tabs; read `public.users.runs_with_water_bottle` by SQL several times.
4. Sign out (00:45:59Z) and read the column again.

**Expected.**
The change is saved locally and uploaded when the app is back online (offline-first rule), with no success message that hides a failed save.

**Actual.**
1. "Preferences saved successfully" shows at once while offline, and the local value is kept across the offline relaunch (ticked). That part holds.
2. Back online, the dev column stayed `false` at 00:38:10Z, 00:38:57Z, 00:39:50Z, 00:43:20Z and 00:45:56Z (8 minutes online, one relaunch, nine screens opened) while the app showed the box ticked and Sport Preferences read "Water bottle: Yes".
3. It reached the server only when I signed out: `true` at 00:46:00Z, 1 s after the Sign out tap.

Cause, from the code: `UserRepository.updateUserProfile` catches the failed write-through and marks the row `needs_upload`, but nothing asks for a retry. The `users` repository is uploaded only as a dependency inside `SyncCoordinator.ensureSynced`, which skips it while its last sync is under the 1-hour staleness window (`_isStale`, `staleDuration = Duration(hours: 1)`); `_uploadRetryOwed` is set only for failures inside the coordinator, not for this repository-level write-through failure. The sign-in sync at 00:33:29Z had just stamped it fresh, so the retry would have waited until about 01:33Z. Sign-out's own upload is what finally sent it. A second device or the web coach reading this athlete in that hour sees the old value, and the Sign out dialog's "Your data stays with your account" depends on sign-out's upload succeeding.

Old Finding: 31-008.

**Evidence.**
- runs/119/12-offline-save-1s.png: the success snackbar while offline
- runs/119/14-offline-relaunch-profile.png: ticked after the offline relaunch
- runs/119/db-31-008-offline-after-save.txt: dev `false` after the offline save
- runs/119/db-31-008-after-online-relaunch.txt: dev `false` 20 s after the online relaunch
- runs/119/db-31-008-online-6min.txt: dev `false` 6 min online, local still ticked
- runs/119/db-31-008-after-signout.txt: dev `true` at 00:46:00Z, right after sign-out
- runs/119/notes.md: the times

**Decision quote.**
> 

**Triage.**
