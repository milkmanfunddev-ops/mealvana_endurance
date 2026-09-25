# 103: A rejected upload no longer stops the repository from pulling

**Status:** in-progress (wave 27, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** `SyncCoordinator.ensureSynced` throws when `uploadDirtyRecords` fails (`sync_coordinator.dart:210-217`), before `syncFromRemote`. One row the server always rejects therefore stops that repository, and every repository that depends on it, from ever downloading. Make a failed upload log (with the repo key and error), keep the rows dirty for the next try, and still run the pull. Before letting the pull run after a failed upload, check each repository's `syncFromRemote` keeps `needs_upload` rows (the analysis found meal logs and meal plans do; confirm the rest, and fix any that would overwrite a dirty row). Keep the failure tracking and rate limit for the upload itself. Offline, the pull fails as it does today.

**Findings:** 86-012 (read it and `runs/86/triage-sync-analysis.md`). Retest ticket 107 closes it; this ticket does not.

**Decisions:** Lee's ruling (2026-09-25, in the terminal): file and fix. No page writes.

**Touches:** lib/shared/services/sync/sync_coordinator.dart, any repository under lib/features/*/data/ whose `syncFromRemote` overwrites a dirty row, test/ for the coordinator.

- [ ] Coordinator test: a repository whose upload returns `UploadResult.failed()` still has `syncFromRemote` called, its dirty row stays dirty, and the failure is logged.
- [ ] Test: a dependency whose upload fails does not stop the dependent repository's pull.
- [ ] For each repository the coordinator syncs, a test (or a named existing one) that a pull keeps a `needs_upload` row.
- [ ] `flutter analyze` clean on touched files, the touched tests green.

Next: /implement-lee testing-wave
