# 86-012 · A rejected upload stops its repository from pulling: ensureSynced throws before the download, retried every 2 minutes

- kind: bug
- status: triaged
- ticket: 86
- run: w25-20260925T1324Z
- screen: none (sync)
- decision: 

**Steps.**
Found by code reading at triage of 86-007 (filed by the triage session, 2026-09-25), not seen in a run.
1. Signed in, leave a row with `needs_upload = 1` that the server rejects every time (for example one
   an RLS policy or a constraint refuses).
2. Let the app sync that repository (`SyncCoordinator.ensureSynced`), and change the same table on dev
   from another device.

**Expected.**
A failed upload is logged and kept for retry, and the repository still pulls the server's rows: one bad
row never stops the phone from receiving everything else.

**Actual.**
`sync_coordinator.dart:210-217` throws a `StateError` when `uploadDirtyRecords` fails, before the
`syncFromRemote` at step 7. The failure is rate-limited (2-minute in-memory cooldown) and retried, and
each retry throws again, so that repository, and every repository that lists it as a dependency
(`:205-208`), never downloads while the row stays rejected.

**Evidence.**
- runs/86/triage-sync-analysis.md (section "A failed upload blocks the pull")

**Decision quote.**
> 

**Triage.**
Fix ticket 103 (Lee, 2026-09-25): a failed upload is logged and the pull still runs. Closed by retest ticket 107 after it merges.
Moved to retest ticket 120 when 107 was split (Lee, 2026-09-25).
