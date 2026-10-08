# 72: Event duplicates: the form refuses a same-name same-day event, and the events upload sends rows one at a time

**Status:** ready (round develop-2026-10, fix wave 8)
**Labels:** fix, round:develop-2026-10, area:events, area:sync
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** nothing in code; cut at the wave-6 close from ticket 65's Q3. Prod's `events_user_date_name_unique` index waits for this ticket to ship.
**Next:** `/testing-wave develop-2026-10` (fix wave after test wave 7)
**Model:** opus

**What to build:** Lee, 2026-10-08 (65 Q3): the unique index `(user_id, event_date, event_name)` is live on dev (migration `20261008166500`). Nothing in the app stops an athlete creating a second event with the same name on the same day; its upload fails with 23505, and `EventsRepository.uploadDirtyRecords` (`events_repository.dart:172` at `8dec4583`) upserts every dirty event in one request, so that one row blocks every later event upload for the athlete.

1. **The form refuses a duplicate.** `EventsController.createEvent`/`updateEvent` (and the coach-on-athlete form path, `forUserId`) check Drift for a non-deleted event of the same user, same derived `event_date` and same trimmed name (case as the index compares it: exact) before the write, and the form shows a content-keyed message (`events.form.duplicate_name_day`, default "You already have an event with this name on that day.") instead of saving. Provider imports already dedupe through `findExistingEvent`.
2. **Per-row upload.** `uploadDirtyRecords` sends one upsert per dirty row (or batches but retries the failed batch row by row), so a 23505 on one row marks only that row failed (it stays dirty, `_report.degraded` with the event id and code, D9) and the rest land. Say in the Fix notes whether a 23505 row is retried forever or surfaced; recommended: surfaced once as `degraded` and retried on the next walk, since the form guard makes it rare.
3. Server-side deletes (the sweep) do not reach devices; a later edit to a removed duplicate on an old device hits 23505 too. Item 2 contains it; note it in the Fix notes.

**Findings:** none (ticket 65's Q3).

**Decisions:** Lee, 2026-10-08: form guard + per-row upload; index stays on dev; prod index after this ships.

**Touches:** lib/features/events/presentation/providers/events_controller.dart, lib/features/events/presentation/screens/event_form_screen.dart (message only), lib/features/events/data/events_repository.dart (`uploadDirtyRecords`), lib/features/content/domain/content_keys.dart, assets/config/content_defaults.json, test/features/events/event_duplicate_guard_seam_test.dart (new), test/features/events/events_upload_per_row_test.dart (new), test/new_sync/events_repository_sync_test.dart. About 8 files. `EventsController` is `@riverpod`: unfiltered codegen if a signature changes.

**Overlaps:** 71 and 73 share no file. Ticket 65 (landed) owns the derivation; build on it.

No edge-function or schema change on dev. Prod: the `20261008166500` index migration runs at the bundle that carries this ticket (HANDOFF.md).

- [ ] Seam (real `EventsController`, in-memory Drift, `FakePostgrest`): a second create with the same name and day is refused with the message and writes nothing; a different day saves. Rename to collide on update is refused the same way.
- [ ] Unit: with `FakePostgrest` refusing one of three dirty rows (23505), the other two land, the refused row stays dirty, one `degraded` is recorded; the next walk resends only it.
- [ ] #116, #117 (the degraded is `_report.`), `flutter analyze` clean.
- [ ] Retest on a simulator: create two "Race" events on one day: the second is refused with the message; the first uploads.

Next: /testing-wave develop-2026-10
