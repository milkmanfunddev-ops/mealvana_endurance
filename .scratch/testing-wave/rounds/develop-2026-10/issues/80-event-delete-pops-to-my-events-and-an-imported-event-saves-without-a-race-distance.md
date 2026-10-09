# 80: Event delete leaves Event Details and cancels its carb-load reminders; an imported event saves without a race distance

**Status:** ready (round develop-2026-10, fix wave 8)
**Labels:** fix, round:develop-2026-10, area:events, area:notifications
**Branch:** `develop-next` (fix-wave worktree)
**Source:** Findings 69-002, 69-004 (and 69-005 steps 2–4, answered from code below); TRIAGE.md rulings of 2026-10-09.
**Blocked by:** nothing in code. **Never in the same wave as 72**: both edit `events_controller.dart` and `event_form_screen.dart` (Overlaps). Ticket 65 (landed, wave 6) owns the date derivation this ticket keeps.
**Next:** `/testing-wave develop-2026-10` (fix wave 8)
**Model:** opus

**What to build:** Lee, 2026-10-09:
- After a delete the app pops to My Events.
- An imported event keeps an empty race distance as valid on save; the import never set one.
- The edit does not flip origin unless a field the sync owns changes.
- If the delete does not cancel the event's carb-load notifications, that goes in the Fix and the Retest.

From code: the delete does not cancel them (item 3). **The notification rule in CLAUDE.md applies to item 3:** the agent invokes the `notification-testing` skill first and reads the push-stack fact sheet `ops/docs/messaging-relay-and-testing.md` before writing. Neither exists in this clone at drafting (`.claude/skills/` holds device-sweep, drive-device and shorebird-patch; no `ops/` directory). The lead points the agent at them, or rules item 3 may go ahead without them, before the wave. Line numbers are from code at `84615131`.

## Findings

- **69-002 · Deleting an event from Event Details shows "Event deleted successfully" but leaves the deleted event's detail on screen.** Run 69, 23:31:43Z, event "Tw69 2330" (Nov 7 2026, no linked activity), More options → Delete Event → Delete. The server row was gone at once (hard delete) and the snackbar showed. The screen stayed on the deleted event's Event Details for at least 25 s, with its name, date, "5 weeks away", Create Nutrition Plan, Set Up Carb Loading and Race Day Checklist all live, until Back. Back went to My Events without the event. No console line was printed for the delete.
  Evidence: `runs/69/h05-after-delete.png`, `runs/69/h06-after-delete-2.png`, `runs/69/h07-back-after-delete.png`, `runs/69/db-tw69-after-delete.txt`, `runs/69/db-tw69-before-delete.txt`.
- **69-004 · An imported TrainingPeaks event cannot be edited: Save Changes demands a race distance the import never set.** Run 69, "IM NC 70.3" (origin `training_peaks`, `location` null, `db-imnc-before.txt`). Edit Event opens with Sport Category Triathlon and an empty Race Distance. The tester changed only Location (to "Raleigh, North Carolina") and tapped Save Changes. The save was refused with "Please select a race distance". Nothing saved: the row still has origin `training_peaks` and location null.
  Evidence: `runs/69/i01-imnc-edit-form.png`, `runs/69/i03-location-picked.png`, `runs/69/i04-after-save.png`, `runs/69/db-imnc-after-x.txt`.
- **69-005 (follow-up, steps 2–4) · Carb-load reminders after delete, imported-event edit then TrainingPeaks sync, swipe delete with checklist and plan.** Not run in wave 7. Tw69's create logged `notif_scheduled` for days 3/2/1 (`runs/69/notes.md:100`). Answered from code under "What a delete does" and in Retest.

## Why, from code

- **69-002.**
  - The delete handler (`lib/features/events/presentation/screens/event_detail_screen.dart:251-332`) shows the snackbar and calls `context.go('/main')` (`:315`).
  - Every in-app entry into Event Details but one pushes a pageless `MaterialPageRoute` with `Navigator.of(context).push` (list below), on top of go_router's `/main` page. `go('/main')` asks for the location the router already shows, so go_router's page list does not change, and a pageless route above an unchanged page stays.
  - The finding's entry was My Events' card (`event_list_card.dart:113-117`).
  - The app bar's Home button calls the same `context.go('/main')` (`:70`), so it is probably a no-op from those entries too (not seen in a run; Retest checks it).
- **69-004.**
  - The import creates the event with `eventSubtype: null` (TrainingPeaks, `lib/features/integrations/application/provider_event_import_service.dart:72-87`; Final Surge sets none either, `:150-165`). `_toSupabaseJson` also nulls any subtype the enum does not know (`events_repository.dart:735-742`).
  - The edit form keeps `_selectedEventSubtype` null when the stored one is null (`event_form_screen.dart:139-147`).
  - `EventSubtypeDropdown`'s validator (`lib/features/calendar/presentation/widgets/event_subtype_dropdown.dart:102-107`) refuses null, and `_handleSave` stops on `validate()` (`event_form_screen.dart:531-533`).
- **Origin.**
  - `EventsService.updateEvent` flips any `training_peaks`/`final_surge` row to `manual` on every edit (`lib/features/events/application/events_service.dart:301-312`). It cites D-2c.
  - D-2c's ratified text says a local edit **to a provider-sourced field** flips that field manual and exempts it from re-sync overwrite (`docs/ssot/spec/design/surfaces/integrations-data-display.md:96-100`, Xuan, 2026-09-11; the summary row at `:207` says "edit flips field manual").
  - The provider-sourced fields are the ones the import writes:
    - TrainingPeaks (`provider_event_import_service.dart:71-87`): `eventType`, `eventName`, `eventDate`, `startTime` and `goalTimeMinutes`.
    - Final Surge (`:150-165`): those plus `activityId` and `goalPaceMinutesPerMile`.
  - The import's dedupe key is (user, name, date) (`:52-56`, `:133-137`). A matched row is never overwritten at any origin; only a null origin is flipped (`:59-65`, `:139-145`).
  - So a Location edit touches no field the sync owns. Under D-2c's own words the origin need not flip, and keeping `training_peaks` changes nothing the import does. The flip stays for the fields the sync owns (item 4). The SSOT is not edited (no SSOT writes in a wave).

## What a delete does, from code (69-005)

- **Linked activity.** `EventsRepository.deleteEvent` (`lib/features/events/data/events_repository.dart:388-458`) deletes the linked activity from Drift only (`:411-421`). It marks nothing dirty and sends no server delete. Only the event row is deleted on the server (`_uploadEventDeletion`, `:722-731`). The server FK runs the other way: `events.activity_id → activities ON DELETE CASCADE` (`docs/dev_schema.txt:5590`). So the server activity survives an event delete, and a later activities pull can bring it back locally (not checked in a run). Today an event gets a linked activity mainly from the Final Surge import (`provider_event_import_service.dart:155`), which means a provider workout (Questions 2).
- **Carb-loading plan.** Deleted locally first (`deleteCarbLoadingPlanByEventId`, `:404-409`). On the server it goes by FK cascade (`carb_loading_plans_event_id_fkey … ON DELETE CASCADE`, `dev_schema.txt:5470`).
- **Race checklist items.** These are Drift-only (`raceChecklistItemsTable`, `lib/features/race_checklist/data/checklist_repository.dart`), and nothing in the delete path removes them, so they are left orphaned on the device. They are invisible, since nothing lists them without the event. Not in this ticket; 69-005 step 4's retest will show it.
- **The three carb-load notifications are NOT cancelled.**
  - Creating an event runs the nudge sweep (`events_controller.dart:135`). `CarbLoadNudgeService.armEvent` schedules up to three local notifications, ids `CarbNudgeEngine.notificationId(eventId, daysBefore)` (`lib/features/carb_loading/application/carb_load_nudge_service.dart:127-176`, `lib/features/carb_loading/domain/carb_nudge_engine.dart:66-73`), and records `carb_nudge_armed_<eventId>` in SharedPreferences.
  - `EventsController.deleteEvent` (`events_controller.dart:189-227`) never calls `disarmEvent`. `disarmEvent`'s reason vocabulary even lists `event_deleted` (`carb_load_nudge_service.dart:178-184`), but nothing passes it (grep).
  - The open/resume sweep (`evaluateOnOpen`, `:201-…`, via `CarbNudgeCoordinator.run`, `carb_nudge_coordinator.dart:25-69`) loops only over the events that still exist, so it never disarms a deleted one.
  - The OS therefore fires "carb load" reminders at 06:00 on days 3, 2 and 1 for a race that no longer exists, and the tap deep-links to `/events/<deleted id>` (`notification_intent_routes.dart:49-50`).
  - The swipe delete on My Events (`events_list_screen.dart:312-330`) uses the same controller method, so it has the same gap.

## Fix

1. **Delete leaves Event Details.**
   - In `_showDeleteConfirmation` (`event_detail_screen.dart:308-316`), after `deleteEvent` resolves and the success snackbar shows (the root `ScaffoldMessenger` keeps it through the pop): `final navigator = Navigator.of(context); if (navigator.canPop()) { navigator.pop(); } else { context.go('/events'); }`. `/events` is My Events (`app_router.dart:688-692`).
   - `Navigator.pop` removes both a pageless route and a go_router page pushed with `router.push`, so one call covers every entry below.
   - From My Events (the finding's path, and the post-create pushes) the pop lands on My Events. From other entries it lands on the screen that opened the event (Questions 1).
   - The Home button (`:70`) is not changed here (not ruled). Retest reads it.
   - Every route into Event Details, by grep for `EventDetailScreen(` and `/events/`:
     | Entry | Code | How | After the fix, delete lands on |
     |---|---|---|---|
     | My Events card tap | `lib/features/events/presentation/widgets/event_list_card.dart:113-117` | `Navigator.push` | My Events |
     | My Events after New Event | `lib/features/events/presentation/screens/events_list_screen.dart:301-306` | `Navigator.push` | My Events |
     | Timeline upcoming-event card | `lib/features/events/presentation/widgets/upcoming_event_card_kyle.dart:160-164` | `Navigator.push` | Timeline |
     | Timeline card after New Event | `upcoming_event_card_kyle.dart:68-73` | `Navigator.push` | Timeline |
     | Events upcoming widget | `lib/features/events/presentation/widgets/upcoming_event_widget.dart:86-90` | `Navigator.push` | the host screen |
     | Calendar upcoming widget | `lib/features/calendar/presentation/widgets/upcoming_event_widget.dart:82-86` | `Navigator.push` | the host screen |
     | Event Details footer "Create new event" | `lib/features/events/presentation/widgets/event_footer_links.dart:48-53` | `pushReplacement` (replaces the detail it sits on) | whatever was under the first detail |
     | Coach portal athlete panel, tap / after create | `lib/features/coach_mode/presentation/widgets/portal_athlete_detail_panel.dart:317-323`, `:412-418` | `Navigator.push` (`forUserId`) | the portal panel |
     | Carb-load nudge tap / deep link | `lib/shared/widgets/root_app_widget.dart:530-533` (`router.go('/')` then `router.push('/events/<id>')`), route `lib/shared/core/app_router.dart:707-714`, destination `lib/shared/services/notification_intent_routes.dart:49-50` | go_router page | home (`/`) |
     | Web or direct URL `/events/<id>` with nothing beneath | `app_router.dart:707-714` | go_router page | My Events (the `canPop` fallback) |
   - Every caller of the delete, by grep for `deleteEvent(`: Event Details (`event_detail_screen.dart:308`), the My Events swipe (`events_list_screen.dart:323`), both through `EventsController.deleteEvent` (`events_controller.dart:189`) → `EventsService.deleteEvent` (`events_service.dart:445-510`) → `EventsRepository.deleteEvent` (`events_repository.dart:388`). The swipe stays on My Events already, so only item 3 applies to it.
2. **An event stored without a race distance saves without one.**
   - Add `final bool isRequired;` (default `true`) to `EventSubtypeDropdown` (`event_subtype_dropdown.dart:12-21`). The validator (`:102-107`) returns null when it is false.
   - In `event_form_screen.dart`, compute once in `initState` (`:133-148`): `_storedWithoutDistance = isEditMode && widget.event!.eventSubtype == null`. Pass `isRequired: !(_storedWithoutDistance && _selectedSportType == widget.event!.eventType)` at `:747-755`.
   - Changing the sport category still resets to the new category's first distance (`:729-740`) and requires one.
   - The save already sends `eventSubtype: _selectedEventSubtype?.name` (`:587`), so null stays null.
   - This is scoped to "stored empty" rather than to origin: a row the import made and a row flipped to manual by an earlier name edit both keep an empty distance. A manual event created through the form always has one (the validator).
3. **The delete disarms the event's carb-load reminders, and the sweep disarms orphans** (notification rule: see the top).
   - In `EventsController.deleteEvent` (`events_controller.dart:189-227`), read `ref.read(carbLoadNudgeServiceProvider)` with the other ref values before the first await (`:192-193`; the provider is `carb_load_nudge_service.dart:284-289`). After `service.deleteEvent` succeeds, `await nudges.disarmEvent(eventId, reason: 'event_deleted')` in its own try. A failure there records `report.degraded(e, stackTrace: st, area: 'carb_loading', message: 'Carb nudge disarm after event delete failed', extra: {'eventId': eventId})` (CLAUDE.md D9: a schedule path whose failure no user would notice) and does not fail the delete. `disarmEvent` cancels all three ids and sends `notif_cancelled {reason: event_deleted}` only if the event was armed (`:184-199`).
   - In `CarbLoadNudgeService.evaluateOnOpen` (`:201-…`), before the per-event loop, disarm every armed record whose event is not in `events`: for each SharedPreferences key starting `carb_nudge_armed_` whose suffix is not an id in `events`, `disarmEvent(id, reason: 'event_deleted')`. This covers deletes that never pass through this device's controller: a coach deleting on the portal, another device, a sync removal. The sweep already runs on open and resume (`root_app_widget.dart:388`, `:432`).
   - `allEventsProvider` throwing leaves the sweep in its catch (`carb_nudge_coordinator.dart:59-65`) and nothing is disarmed. An empty list means no events, and then disarming every armed record is right.
4. **Origin flips only when a field the sync owns changes.**
   - New pure helper `lib/features/events/domain/event_origin.dart`: `String? originAfterEdit({required Event before, required Event after})`.
   - It returns `'manual'` when `before.origin` is `training_peaks` or `final_surge` and any of these changed: the trimmed `eventName`, the derived event date (`eventDateFromStartTime(after.startTime)` vs `before.eventDate`, ticket 65's helper), `startTime` (compared as parsed instants, not strings), `eventType` or `goalTimeMinutes`. For `final_surge` the list also includes `goalPaceMinutesPerMile` and `activityId`. Otherwise it returns `before.origin`.
   - In `EventsService.updateEvent` (`events_service.dart:301-312`), read the stored row (`_eventsRepository.getEventById(event.userId, event.id)`, `events_repository.dart:483`) and use `originAfterEdit(before: stored, after: event)`. When the stored row is not found (a coach editing an athlete's event the coach's Drift does not hold), keep today's flip for provider rows: the conservative D-2c reading.
   - The comment at `:301-304` is rewritten to D-2c's field wording.

## Touches

- lib/features/events/presentation/screens/event_detail_screen.dart
- lib/features/events/presentation/screens/event_form_screen.dart
- lib/features/calendar/presentation/widgets/event_subtype_dropdown.dart
- lib/features/events/presentation/providers/events_controller.dart (`deleteEvent` body only)
- lib/features/events/application/events_service.dart (`updateEvent`'s origin lines only)
- lib/features/events/domain/event_origin.dart (new)
- lib/features/carb_loading/application/carb_load_nudge_service.dart (`evaluateOnOpen` only)
- test/features/events/event_delete_pops_test.dart (new)
- test/features/events/event_form_imported_without_distance_test.dart (new)
- test/features/events/event_delete_disarms_carb_nudges_seam_test.dart (new)
- test/features/events/event_origin_d2c_test.dart
- test/features/carb_loading/g27_carb_nudge_test.dart

No codegen expected: `EventsController` (`@riverpod`) changes only a method body, and `carbLoadNudgeService` keeps its signature. Run the unfiltered codegen if a signature slips. No Drift change, no migration, no edge function, no content key (no new user-facing words; the existing hardcoded delete strings are not moved here).

**Call sites read, not changed:** every Event Details entry and every delete caller in item 1's table and list; `CarbNudgeCoordinator.run` (`carb_nudge_coordinator.dart:25-69`); `ProviderEventImportService` (`provider_event_import_service.dart:44-…`; its dedupe and legacy flip are unchanged).

**Overlaps:** **72** lists `events_controller.dart` and `event_form_screen.dart`. They never run in the same wave: one agent takes both in sequence, or 80 runs after 72 merges (#63). 72 also edits `events_repository.dart`, which 80 reads but does not edit. 73 shares no file. 69-015 (sign-out leaves an armed nudge) touches the same armed-record bookkeeping if it becomes a ticket; item 3's orphan sweep would also catch that case once the next user's events load. The ticket that takes 69-015 states that rule.

## Tests

- [ ] **Seam, through the real notifier** (`event_delete_disarms_carb_nudges_seam_test.dart`: `ProviderContainer`, real `EventsController`, `EventsService` and `EventsRepository` over in-memory Drift with `FakePostgrest`, a real `CarbLoadNudgeService` over a recording `CarbNudgeGateway` fake and mock SharedPreferences, as `g27_carb_nudge_test.dart` builds it).
  - Seed an event 30 days out and run the sweep: three fires are scheduled.
  - `deleteEvent`: the gateway records `cancel` for all three `CarbNudgeEngine.allNotificationIds(id)`, `carb_nudge_armed_<id>` is gone, `notif_cancelled {reason: event_deleted}` fires once, and the event row is gone.
  - With the gateway's `cancel` throwing: the delete still completes and one `degraded` in area `carb_loading` is recorded.
- [ ] **Unit** (`g27_carb_nudge_test.dart`, new case): an armed record for an id absent from `events` is disarmed by `evaluateOnOpen` with `event_deleted`. An armed record for an id still present is untouched.
- [ ] **Widget** (`event_delete_pops_test.dart`, on `event_detail_narrow_viewport_test.dart`'s harness):
  - A host screen pushes `EventDetailScreen` with `Navigator.push(MaterialPageRoute)`, as `event_list_card.dart:113` does, under a `GoRouter` at `/main`. More options → Delete Event → Delete returns to the host, and the "Event deleted successfully" snackbar is visible.
  - Second case: a `GoRouter` with only `/events/:eventId` on the stack (nothing to pop) ends at `/events`.
- [ ] **Widget** (`event_form_imported_without_distance_test.dart`, on `event_form_goal_pace_by_sport_test.dart`'s harness): an `Event(origin: 'training_peaks', eventType: triathlon, eventSubtype: null)` in edit mode.
  - Type a Location and Save Changes: `updateEvent` is called with `eventSubtype` null and no "Please select a race distance" line.
  - Change the sport category to Running and clear nothing: a distance is preselected (today's reset).
  - Create mode still refuses a null distance.
- [ ] **Unit** (`event_origin_d2c_test.dart`): replace the mirrored `editOrigin` with the real `originAfterEdit`.
  - A Location-only, bib-only or distance-only edit of a `training_peaks` row keeps `training_peaks`.
  - A name, date, start-time, sport or goal-time edit flips it to `manual`.
  - A `final_surge` pace edit flips it.
  - `manual` and null-origin rows keep their origin.
  - The re-sync exemption case stays.
  - Fixtures are producer-shaped: the TrainingPeaks import's `startTime` is `eventDate.toIso8601String()` (local midnight, no `Z`, `provider_event_import_service.dart:80`), and the form re-serialises the parsed value (`event_form_screen.dart:585`). The comparison must not flip on that round trip.
- [ ] `flutter analyze` clean on touched files.
- [ ] #116: `grep -rl` under `test/` for `EventDetailScreen`, `EventFormScreen`, `EventSubtypeDropdown`, `EventsController`, `eventsControllerProvider`, `deleteEvent`, `EventsService`, `updateEvent`, `CarbLoadNudgeService`, `evaluateOnOpen`, `disarmEvent` and `carbLoadNudgeServiceProvider`, and run every file named (today that includes `events_controller_invalidates_activities_test.dart`, `events_providers_dispose_during_await_test.dart`, `events_service_update_event_date_test.dart`, `event_date_write_paths_seam_test.dart`, `events_repository_crud_test.dart`, `event_form_back_button_test.dart`, `event_form_goal_pace_by_sport_test.dart`, `g29_carb_nudge_telemetry_test.dart`, `test/smoke_tests/events_meal_logging_smoke_test.dart`, `test/seeded_tests/events_meal_logging_content_test.dart`).
- [ ] #117: the new catch's report is `report.degraded`, already in `reportCalls`. Run `test/shared/source_guard/`.
- [ ] #118: a failed disarm is not written into notifier state.
- [ ] Async paths, written down in Fix notes:
  - Delete tapped twice: the dialog closes on the first confirm; the second tap lands on the popped screen.
  - The sweep running while a delete disarms: both cancel the same ids; `disarmEvent` is idempotent and the second sends no `notif_cancelled`, because the armed record is already gone.
  - A delete whose server ack fails (the background upload, `events_repository.dart:428-447`): the local row is gone, so the reminders are rightly cancelled.
  - The detail screen popped while `deleteEvent` is still awaiting: `context.mounted` guards the pop, and the disarm belongs to the controller (`keepAlive` link, `:190`).
- [ ] Timeouts/retries: none added.

## Deploy

None. Client-only: no SQL, no function.

## Retest

On a simulator, in the retest ticket after fix wave 8, as test@test.com:

- **69-002:**
  - My Events → New Event 30+ days out → its Event Details → More options → Delete Event → Delete. The screen returns to My Events at once with "Event deleted successfully", and the row is gone on the server.
  - Repeat from the Timeline's upcoming-event card: the delete returns to the Timeline (or to My Events, if Questions 1 rules so).
  - From any Event Details, the Home button lands on the Timeline. If it does not, file it.
- **69-004:**
  - My Events → "IM NC 70.3" (origin `training_peaks`) → Edit Event → change only Location → Save Changes. It saves with no distance demanded. The server row shows the new `location`, `event_subtype` still null, and **`origin` still `training_peaks`**.
  - Edit the name: `origin` becomes `manual`.
- **69-005 step 2 (reminders after delete):**
  - Create an event 4+ weeks out: the console shows three `notif_scheduled {cta: carb_load, event_id}`.
  - Delete it: the console shows one `notif_cancelled {reason: event_deleted}` for that id, and the pending list holds no `carb_event:<id>` request. Read it the way the `notification-testing` skill says; if it is still missing, use the app container plist read run 69 used for `plist-after-tap-coldstart.txt`.
  - Repeat with the My Events swipe delete.
- **69-005 step 3:** after the 69-004 Location edit, Connected Apps → TrainingPeaks → Sync Now. The row keeps its Location and its origin, and no second "IM NC 70.3" row appears (from code the import skips a matched row).
- **69-005 step 4:** swipe-delete an event with race-checklist items and a carb-loading plan. On the server the event and its plan are gone. Report what the device keeps: from code the checklist rows stay in Drift.

## Questions for Lee

1. The ruling says "pops to My Events". From My Events that is where the pop lands. From the Timeline's upcoming-event card and from a carb-load reminder tap, Event Details was opened over the Timeline or home. Should a delete there return to the screen it came from, or always go to My Events? Recommended: the screen it came from. That is what Back does, and it is what item 1 builds.
2. Deleting an event deletes its linked activity on the phone only (`events_repository.dart:411-421`). The server keeps it, so it can reappear after a pull. A linked activity is usually a Final Surge workout. Should an event delete stop deleting the linked activity (keep the workout), or delete it on the server too? Recommended: keep the workout. Drop the local cascade and keep the activities invalidation. It goes into this ticket if ruled before the wave.
3. Editing an imported event's name or date flips it to `manual`, and the next TrainingPeaks sync no longer matches it on (name, date). From code the sync then imports the provider's version as a second event (`provider_event_import_service.dart:52-87`). Accept that for now, or match imports on a provider id in a later ticket? Recommended: a later ticket. The events table has no provider-id column today, so it needs a migration.

Next: /testing-wave develop-2026-10 (fix wave 8)

**Rulings (Lee, 2026-10-09, wave 7 close).**
- Q1: after a delete the app goes back to where it came from (pop), My Events as the fallback.
- Q2: the linked activity stays on the server; the delete removes only the event row remotely.
- Q3: FOLD INTO 80: store the TrainingPeaks event id on import and match the sync on it, so a renamed or re-dated imported event is not imported again. Add the item to Fix, its files to Touches, and a seam test (producer-shaped import payload with the provider id).
