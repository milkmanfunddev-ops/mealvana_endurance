# Events (races)

domain: 3 Race week · folder: `lib/features/events/` (24 files) · plus `lib/features/race_checklist/` (5 files)

Where an athlete keeps their races. A race can be typed in by hand or arrive from TrainingPeaks or Final Surge. Each
race has a details page that leads to the race-day fuel plan, carb loading and a packing checklist. The "Events" tab
of the home shell (route `/events`).

## What athletes can do here

- **See upcoming and past races.** "My Events": "Upcoming Events" (today onward, soonest first) and "Past Events"
  (newest first). A card shows a source chip ("TrainingPeaks", "Final Surge" or "Manual"), location, "Goal: {time}"
  and a month/day block. A race with no date at all is not listed. Empty state: "No Events Yet" with a "New Event"
  button. Pull down to refresh (so a coach's edits appear).
- **Add a race.** "New Event" → the form: "Sport Category", "Race Distance", "Event Name" (typing three letters
  searches a public race catalogue; picking one fills location, date, time, registration link, sport and distance),
  "Location (optional)" with address suggestions, "Event Date" (today to two years out; the first pick sets 7:00 AM),
  "Start Time", and under "Additional Details (Optional)": "Goal Time" (hours, minutes), goal pace (for cycling a
  single "Goal Speed (mph)" field; otherwise "Goal Pace (per mile)" minutes and seconds), "Registration URL", "Bib
  Number". "Create Event" shows 'Event "{name}" created successfully!' and opens the race's details. The app bar has
  a close button and a "Home" button that leaves for the Timeline.
- **Delete a race.** Swipe a card left, or "More options" → "Delete Event" on the details page. The dialog says the
  race's nutrition plans and carb-loading plan go with it; the linked workout stays.
- **Open a race.** "Event Details": the name, the full date or "Date TBD", a countdown badge ("Today!", "Tomorrow",
  "N days away", "N weeks away", "N months away", "Event completed"), the "Event Information" card (Distance,
  Location, Goal Time, Goal Pace, Registration, Bib Number), then "Nutrition Planning":
  - "Create Nutrition Plan" opens the plan form filled from the race; once the linked workout has a plan the button
    reads "View Nutrition Plan". Finishing that form is what links the race to a workout; there is no separate
    "link" control.
  - The carb row: "Set Up Carb Loading" with the protocols that still fit ("3-, 2- and 1-day protocols" … "1-day
    protocol"), or "Carb Loading Plan" once one exists, or the disabled "Carb loading window has passed" on race
    morning and later. See `carb_loading.md`.
  - "Race Day Checklist" opens the packing list.
  - Footer: "View events list", "Create new event". "Edit Event" is under "More options".
- **Move a race.** Editing the date or time moves the linked workout with it (not a workout synced from a platform,
  nor one already done). The carb-loading days do not move.
- **Race day checklist.** "Race Day Gear Checklist · Tap items to check them off as you pack!", two sections "Race
  Day Gear" (generated per sport and gender) and "Nutrition" (pulled from the race's fuel plan); "Add custom item";
  swipe to delete; "All packed! You're ready for race day! 🎉" when everything is ticked.
- **Races from a platform.** TrainingPeaks races are imported 90 days ahead on every sync; Final Surge race
  candidates too. Editing a date, time, name or goal on an imported race turns it "Manual", so the next sync won't
  overwrite it; editing location, bib or distance keeps it provider-owned.
- **Race-week notification.** "Fuel up for race day · Your carb load for {event} can start now — set up your plan."
  at 6:00 AM three, two and one days before the race, until a carb plan exists. Tapping it opens the race.

Where the buttons live: `events` (list, form, details) · `race_checklist` · `nutrition_plan` (the plan form) ·
`carb_loading` (protocol chooser, plan summary) · `coach_mode` (a coach can create and open an athlete's races).

## What the data means

Supabase `events`, mirrored in a local table (offline first, `needs_upload`): `event_name`, `event_type` (sport),
`event_subtype` (distance), `location`, `registration_url`, `event_date` (re-derived from `start_time` on every
save), `start_time`, `goal_time_minutes`, `goal_pace_minutes_per_mile` (cycling stores 60 ÷ mph), `bib_number`,
`wave_start_time`, `packet_pickup_info`, `predicted_finish_time_minutes`, `actual_finish_time_minutes`,
`final_placement`, `age_group_placement`, `origin` (manual | training_peaks | final_surge), `provider_event_id`,
`activity_id` (the linked workout; written by the plan flow), `has_carb_loading`, `carb_loading_days`,
`carb_loading_start_date` (written by carb loading). `has_nutrition_plan` is obsolete. A row's list date is the
linked workout's date, else `start_time`, else `event_date`. `public_events` is a server-only catalogue read through
the `search-public-events` function. `race_checklist_items` is local only (no sync, no migration).

## What already exists to reuse

- `presentation/providers/events_controller.dart` (create/update/delete, background sync, `eventDetailProvider` =
  event + linked workout, `allEventsProvider` for the nudge sweep), `application/events_service.dart` (coach
  checks, origin rule, moving the linked workout), `data/events_repository.dart` (offline first; deleting a race
  deletes its carb plan and keeps the workout).
- `application/nutrition_plan_navigation.dart` (`buildNutritionPlanExtras`: pre-fill for the plan form),
  `domain/event_countdown.dart`, `domain/event_origin.dart` (`originAfterEdit`), `application/public_events_service.dart`.
- Widgets: `event_list_card`, `event_header_card`, `event_details_card`, `event_action_buttons_card`,
  `event_footer_links`, `events_empty_state`, `event_countdown_badge`; `calendar/.../sport_category_selector.dart`,
  `event_subtype_dropdown.dart`.
- `integrations/application/provider_event_import_service.dart` (TrainingPeaks and Final Surge race import).
- `race_checklist/`: `checklist_controller`, `application/gear_template_service.dart`.

Don't add: another "link a race to a workout" path (the plan flow owns `activity_id`), another countdown. Dead:
`application/active_com_service.dart` + `domain/active_com_event.dart`, `upcoming_event_provider.dart`,
`upcoming_event_widget.dart`, `upcoming_event_card_kyle.dart`, `nextUpcomingEventProvider`.

Gaps for the gardening pass: the form drops "Bib Number" on create (only edit saves it); "View registration" has no
tap handler; the delete dialog says nutrition plans are deleted but the linked workout (which holds the plan) is kept;
a race with only `event_date` set passes the carb eligibility check but fails plan creation with "Event has no date";
stale comments at `events_list_screen.dart:23`, `event_detail_screen.dart:27-29`,
`carb_loading_protocol_selection_screen.dart:258-259`, `public_events_service.dart` ("min 2 characters"; the form
searches at 3).

## Links

- **qa:** `spec/integrations/training-peaks.md`, `field-map.md`, `payload-usage-map.md` (race import) · `spec/fueling/carb-loading-entryway.md`
  (the carb row) · no events or checklist spec yet.
- **ops open work:** bugs `race-move-may-strand-carb-loading-days`, `new-event-start-time-defaults-to-now`,
  `undated-event-detail-and-edit-lose-the-date`, `events-list-skips-rows-without-start-time`,
  `tp-background-sync-discards-imported-events`, `event-page-asks-run-pace-for-rides`, `v127-emits-every-event-three-times`,
  `provider-duplicate-event-escapes-carb-nudge-stop-condition` · feature-requests `post-race-result-prompt-and-whats-next`,
  `fr-post-race-reengagement`, `eng-task-track-race-creation-event` (race creation fires no analytics event),
  `eng-task-instrument-race-creation`.
- **Related map pages:** `carb_loading.md` · `nutrition_plan.md` · `activities.md` · `integrations.md` · `coach_mode.md`.
