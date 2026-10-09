# 72: Event duplicates: the form refuses a same-name same-day event, and the events upload sends rows one at a time

**Status:** landed-pending-merge (wave 8, 2026-10-09, `3f6b18fa9`)
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

- [x] Seam (real `EventsController`, in-memory Drift, `FakePostgrest`): a second create with the same name and day is refused with the message and writes nothing; a different day saves. Rename to collide on update is refused the same way.
- [x] Unit: with `FakePostgrest` refusing one of three dirty rows (23505), the other two land, the refused row stays dirty, one `degraded` is recorded; the next walk resends only it.
- [x] #116, #117 (the degraded is `_report.`), `flutter analyze` clean.
- [ ] Retest on a simulator: create two "Race" events on one day: the second is refused with the message; the first uploads.

## Fix notes

**What changed** (`3f6b18fa9`):
- `EventsRepository.findSameNameSameDayEvent` (new): the owner's other local event whose trimmed name equals the new trimmed name, with `eventDate` inside the same calendar day; skips the event being edited. It never swallows a read error (a failed read must not let a duplicate through).
- `EventsController._refuseSameNameSameDay` (new), called first in `createEvent` (owner = `forUserId ?? signed-in user`, day = `Event.dateFromStartTime(startTime)`) and `updateEvent` (owner = `event.userId`, day = `event.withDerivedEventDate().eventDate`, excluding `event.id`). On a clash it writes `report.info('Event write refused: same name on the same day')` and throws `DuplicateEventNameOnDayException` (new, `lib/features/events/domain/duplicate_event_name_on_day.dart`). Both write paths rethrow it without a `fault`. No name or no date: no check (nulls are distinct in the index). No signature change, so no codegen.
- `EventFormScreen._handleSave`: on that exception, no `fault`; `MealvanaSnackbar.showWarning` with `ContentKeys.eventFormDuplicateNameDay` (the lead's `event_form.duplicate_name_day`). Every other error is unchanged.
- `EventsRepository.uploadDirtyRecords` now calls `_uploadDirtyRowsOneByOne`: one `upsert(json, onConflict: 'id')` per dirty row. A `PostgrestException` on a row (23505, 23503, 22P02, 42501) leaves that row dirty, records `_report.degraded` with `extra: {eventId, code}` and `tags: {method: UPSERT, code}` (D9), and the walk continues; the 23503 missing-users-row case is `info`, as in `createEvent`. Any other error (network, timeout) stops the walk and reaches the existing `fault` + `UploadResult.failed`. A walk with any refused row returns `UploadResult(success: false, count: <landed>, error: 'N of M events failed to upload (codes)')`, so callers that check `.failed` keep the retry owed.
- `_clearDirtyFlagIfUnchanged`: the dirty flag clears only where `localUpdatedAt` still equals the value that was sent.
- `test/helpers/fakes/fake_postgrest.dart`: `uniqueViolations[table]` predicate; a write carrying a matching row gets 409 / 23505 (additive; no existing test sets it).
- Two existing tests adjusted to the change: `event_date_write_paths_seam_test.dart` (the dirty upload body is now one map, not a one-row list) and `events_controller_invalidates_activities_test.dart` (its mock repository stubs `findSameNameSameDayEvent` -> null).

**The 23505 row policy.** Retried on every walk and written down once per walk as `degraded` (event id + code). It is never dropped and never marked clean: the row is the athlete's real edit, and the fix is a rename or delete on the device. Sentry groups the warnings under one issue. The form guard makes a new one rare; the remaining source is item 3 below.

**Item 3 (server-side deletes do not reach devices).** The duplicate sweep deleted rows on the server only. An old device still holds the deleted duplicate in Drift; the pull's upsert never deletes it. If the athlete edits it, the per-row upload refuses it with 23505 on every walk (degraded each time), but every other event still lands. The form guard would also catch the edit if the kept row has been pulled to that device (both rows are local then). Not fixed here.

**#77, twice at once / after a refresh.**
- Two creates at once (double tap, or two forms): both checks read Drift before either insert, so both can pass and the second row is created. The form's `_isSaving` flag disables the save button during the save, which closes the double tap; anything that slips past is contained by the per-row upload (23505 on the second row only). A refresh (`invalidateSelf`) between check and write does not matter: the check reads Drift, not the provider state.
- Two `uploadDirtyRecords` walks at once (coordinator walk + carb-loading's direct call): both read the same dirty rows and upsert each on `id`. The second upsert rewrites the same row; both clear the flag. The `localUpdatedAt` guard means a row edited during either walk stays dirty.
- A walk during an edit: the edit bumps `localUpdatedAt`, so the walk's clear does not apply and the edit uploads next walk. Drift stores DateTimes in whole seconds, so an edit in the same second as the read is still cleared (as before this ticket).

**#82, writes the per-row upload repeats.**
| Write | Repeat safe? |
|---|---|
| `events` upsert per dirty row, `onConflict: 'id'` | Yes: upsert on the primary key rewrites the same row. A 23505 row is refused again and changes nothing. |
| Drift `needsUpload = false` for a landed row, guarded by `localUpdatedAt` | Yes: idempotent; the guard skips rows edited since the read. |
| `_report.degraded` per refused row | Repeats once per walk by design (the policy above). |

**Tests run (wave 8, this worktree):**
- `test/features/events/event_duplicate_guard_seam_test.dart` (new): 8/8 pass.
- `test/features/events/events_upload_per_row_test.dart` (new): 4/4 pass.
- `test/new_sync/events_repository_sync_test.dart`: 15/15 pass.
- `test/shared/source_guard/`: 20/20 pass.
- #116: every test file naming `EventsRepository`, `EventsController`, `eventsControllerProvider`, `eventsRepositoryProvider`, `EventFormScreen`, `FakePostgrest`, `findSameNameSameDayEvent` or `DuplicateEventNameOnDay` (45 files): 380 pass, 0 fail. The first run failed 2 (the two tests adjusted above); both pass now. `integration_test/flows/carb_loading_ripple_flow_test.dart` names `EventsRepository` too; it is a Patrol test and was not run (no simulators this wave).
- `flutter analyze` on the 9 touched files: no issues.
- Not covered by a test: the snackbar text itself (the form is not pumped; the simulator retest shows it), the network-error stop of the walk (FakePostgrest has no network-failure mode), and the edit-during-upload guard (no hook to interleave an edit).

**Questions for Lee.**
1. A 23505 row retries and warns on every walk until the athlete renames or deletes it. Do you want that, or should the app stop retrying after some number of walks (or tell the athlete on the event)? I left it retrying, as the ticket recommends.
2. `CarbLoadingService` calls `_eventsRepository.uploadDirtyRecords` twice without checking the result (it only catches throws, and the method never throws). It was outside this ticket's files, so I left it. Cut a ticket?

Next: /testing-wave develop-2026-10
