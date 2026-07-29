# Calendar Sync Retirement Roadmap
*Updated: 2025-11-13*

**Status:** ✅ `CalendarSyncService` has been removed. `DataSyncService` now merges calendar data directly (activities, events, carb loading plans/days), and the upload path no longer references the deleted `activity_completions`/`nutrition_plans` tables. Remaining tasks are to finish the Wave 0 ID alignments in the UI/controllers and verify via `flutter analyze` once the Flutter SDK cache permissions are fixed.

## Context
`CalendarSyncService` predates the unified `sync-all-data` edge function and still assumes:

- Activities/events/completions use string IDs.
- `activity_completions` is a real table rather than embedded fields.
- Macro targets/workout notes live in standalone Drift tables.

Because the app already calls `sync-all-data` on startup, **every data type can be synced by its own repository**. Keeping a calendar-specific sync layer only prolongs the migration (Wave 0) and masks schema mismatches.

## Goals
1. Remove `CalendarSyncService` and `calendarSyncServiceProvider`.
2. Let `DataSyncService` orchestrate by delegating to entity repositories (activities, events, carb loading, nutrition, foods).
3. Ensure uploads/downloads still follow the offline-first pattern (merge downloaded data into Drift, upload dirty rows per entity).
4. Eliminate the last references to deleted tables (`activity_completions`, `macro_targets_table`, `workout_notes`).

## Work Plan

### Phase 1 – Extract Responsibilities
1. **Download path**
   - Update `DataSyncService._mergeDownloadedData` to call:
     - `ActivitiesRepository.mergeDownloaded(List<dynamic> activities)`
     - `EventsRepository.mergeDownloaded(...)`
     - `CarbLoadingRepository.mergeDownloaded(...)`
   - Each repository handles its own `insertOrReplace` and dirtiness logic.
2. **Upload path**
   - Rename `DataSyncService._uploadDirtyRecords` → iterate dirty records per repository (`activities`, `events`, `carb_loading_plans/days`, etc.).
   - Delete helper methods that proxy through `CalendarSyncService`.

### Phase 2 – Remove Calendar Sync Service
1. Delete `lib/features/activities/application/calendar_sync_service.dart` and its provider.
2. Remove all imports/providers from controllers or services.
3. Migrate any remaining helper methods (e.g., completion transfers) to the relevant repositories.

### Phase 3 – Cleanup & Verification
1. Run `flutter analyze` (after fixing the Flutter SDK permissions) to confirm no references remain.
2. Update docs (`PHASE-3-ROADMAP.md`, `COMPLETE-MIGRATION-ROADMAP.md`) to note the removal.
3. Add regression tests ensuring `DataSyncService` only handles supported entities (no calendar-wide abstractions).

## Dependencies / Risks
- **Analyzer access:** still blocked by `/Users/leemartin/development/flutter/bin/cache/engine.stamp` permissions; fix to validate progress.
- **Wave 0 tie-in:** the ID alignment work benefits immediately once calendar sync is gone (fewer files to convert).
- **Edge function contract:** unchanged; we still call `sync-all-data` once and merge results per repository.

## References
- [Phase 3 Burndown](PHASE-3-ROADMAP.md)
- [Complete Migration Roadmap](COMPLETE-MIGRATION-ROADMAP.md)
- `lib/shared/services/sync/data_sync_service.dart`
