# 86-007 · Sign out offline with an unsynced meal log: does the new local wipe lose it?

- kind: followup-test
- status: open
- ticket: 86
- run: w25-20260925T1324Z
- screen: Settings
- decision: 

**Steps.**
1. Signed in as test@test.com; `scripts/testing-wave/netcut/netcut.sh launch`, then `on` (network cut for the app).
2. Log a meal by Manual (no AI call); check the local `meal_logs` row has `needs_upload = 1`.
3. Settings → Sign Out → Sign out (still offline).
4. `netcut.sh off`, log back in, and look for the meal on the Timeline and in dev `meal_logs`.

**Expected.**
Either sign-out uploads the pending row first, or it refuses / warns while unsynced rows exist. The meal is
never silently lost.

**Actual.**
Not run. Ticket 33 now deletes all of the account's local rows on sign-out (`clearUserData`); the upload
before it can fail offline.

**Evidence.**
- runs/86/local-drift-02-after-settings-signout.txt (every row of the signed-out account is deleted)

**Decision quote.**
> 

**Triage.**
