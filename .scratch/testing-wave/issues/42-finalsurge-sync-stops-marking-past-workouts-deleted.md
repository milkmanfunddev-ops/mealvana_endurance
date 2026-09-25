# 42: FinalSurge sync stops marking past workouts deleted

**Status:** in-progress (wave 19, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** fable

**What to build:** The FinalSurge sync fetches upcoming workouts only, so a local row that fell out of that window is not "deleted upstream": only rows inside the fetched window can be flagged. `last_synced_at` (and any timestamptz the sync writes) is written as UTC with its offset, not as local wall-clock time.

**Findings:** 30-001, 30-002 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/features/integrations/application/final_surge_sync_service.dart, lib/features/integrations/application/change_detection_service.dart, lib/features/activities/data/activity_mapper.dart, lib/shared/services/sync/entity_sync/activity_sync_handler.dart

- [x] Unit test: a past workout missing from the upcoming list keeps `provider_deleted_at` null; a workout inside the window that vanished is flagged.
- [x] Unit test: `last_synced_at` serialises with a UTC offset.
- [x] Past FinalSurge rows already flagged on dev are cleared (one idempotent SQL, dev only), or the ticket says why not.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
