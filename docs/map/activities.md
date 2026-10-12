# Activities (workouts)

domain: 1 Fuel a workout · folder: `lib/features/activities/` (41 files)

A workout is the thing an athlete fuels. This folder holds the model, storage, sync and brick logic; **it has no
screens of its own**. Every button that acts on a workout lives in another folder (see section 1).

## What athletes can do here

- **Add a workout.** Home (Timeline tab) → "+ Add Activity" → the "Create New Activity Plan" form → "Generate
  Plan" → "Adjust Your Macros" → "Create Plan" → the plan screen → "Save Workout" (or "Save as Routine"). The workout
  exists only after that last tap. Workouts also arrive on their own from a connected training platform (Final
  Surge, TrainingPeaks, Runna, V.O2) or from Garmin. TriDot and Strava are listed under Connected Apps as "coming
  soon" with a "Notify Me" button.
- **Open a workout and its fuel plan.** Tap the workout card on the home timeline. A workout with a fuel plan, one
  already done, or an imported "other" workout opens the detail screen; any other opens the form pre-filled.
- **Move it to another day or time.** Detail screen → date/time picker. Moving an event's date also moves the
  workout linked to it, unless the workout came from a platform or has already happened.
- **Mark done / undo, skip / unskip.** Swipe the workout card right to mark it done ("self-reported"); swipe right
  again to undo. Swipe left to reveal a Skip button (Unskip on a skipped card); both show a snackbar with Undo.
  A card is locked (no swipes either way) once Garmin verified it or a platform reported it done.
- **Build or ungroup a brick.** The "Brick" pill appears when the day has two or more swim/bike/run workouts not
  already in a brick and not skipped (hidden under the Meals filter). Tap it, tap the legs in order ("Pick legs to
  link"), swap them if needed, "Create Brick"; a snackbar offers Undo. The brick row's "⋯" menu has "Ungroup legs"
  (after a confirmation: the legs come back as separate workouts, the brick and its fuel plan go) and "Delete brick".
- **After the workout:** log what was eaten (fuel log), rate how it went and how the fueling felt, see Garmin's
  measured distance, duration and calories.
- **See workouts on the calendar.** Tap the date in the home header for the month sheet. Filled dot = a workout
  done that day, hollow ring = one planned, no dot if everything that day was skipped. A tinted day has a meal log.
  Tap a day to open it; "Today" jumps back.
- **Delete.** Detail screen → trash icon → "Delete Activity" confirmation (cannot be undone). A coach can create,
  edit or delete an athlete's workouts from the coach portal.

Where the buttons live: `macro_dashboard` (card, done/skip, brick pill, "+ Add Activity") · `nutrition_plan` (form,
detail, move, delete, fuel log) · `home_shell` + `shared/widgets/kyle_design` (calendar sheet, dots) · `events`
(event-date move) · `coach_mode` (portal).

### Synced workouts

- **When they refresh.** Opening the app checks each connected platform and pulls one that hasn't synced in four hours.
  Pull down on the Timeline to force a pull of all of them. "Sync Now" sits on each platform's card under Settings →
  Connected Apps, with "Last synced … ago" beneath (long-press "Sync Now" to disconnect). Garmin is never pulled: the
  watch upload reaches our server, which writes the workout and sends a notification. Nothing syncs on a timer or in
  the background.
- **How far they look.** Final Surge: 7 days back, 13 ahead. TrainingPeaks: today to 45 days ahead (races 90), nothing
  past. V.O2: 14 back, 45 ahead. Runna: whatever its calendar link holds, about two weeks. Garmin: a resend request
  covers the last 30 days.
- **What the platform controls.** Sport, title, distance, duration, pace, intensity, TSS and the coach's notes, and the
  date and time unless the athlete moved the workout in the app. Edits to those fields in the app are replaced on the
  next sync. **What the athlete keeps:** the fuel plan, fuel log, ratings, completion notes, reminders, brick grouping
  and a mark-done (unless the platform reports its own completion).
- **A moved workout.** If the athlete moves a synced workout in the app, it stays on the athlete's day after a
  re-sync. If the coach then moves it on the platform, the athlete's day still wins and the coach's new date is only
  recorded; a coach move to exactly the athlete's time re-converges and follows the platform again. A workout with no
  recorded platform date yet follows the platform once, after which the date is recorded.
- **The coach changes it.** A move of more than 30 minutes or to another day, a duration change over 15 minutes or a
  distance change over 10% updates the workout and marks its fuel plan out of date: the detail screen shows a
  "Schedule Changed" banner with "Regenerate Plan". The Timeline card shows nothing, and the plan is never rewritten
  by itself. Smaller changes update the workout quietly.
- **The coach deletes it.** The workout is marked deleted on the platform but stays visible to the athlete, fuel plan
  and completion included; only the coach portal hides it.
- **The athlete deletes it.** It stays gone through later syncs and Garmin uploads. It returns as done if Final Surge
  or TrainingPeaks later reports it completed.
- **The platform says it's done.** Final Surge: the card reads "verified · Final Surge" and locks (no undo or skip),
  with the actual time, distance and duration filled in. TrainingPeaks: never marks a workout done; only actual TSS,
  IF and calories arrive. V.O2: only a workout new to the app arrives as done. Runna: never.
- **Garmin.** A recorded activity completes the planned workout of the same sport that day (closest start time wins;
  a skipped workout within 15 minutes is revived; an activity under two minutes or under a fifth of the planned
  duration is refused). With no planned workout that day it becomes a new completed workout, including strength and
  walks, which never get a fuel plan. It adds the actual start, duration and distance, heart rate, calories, pace,
  power and the device name; the card reads "verified · Garmin" and locks; the phone gets a notification. A multisport
  recording completes a planned brick leg by leg; without one it lands as a parent workout plus legs.
- **Duplicates.** A workout planned in the app and then arriving from a platform is merged when the sport matches
  within a day and the distance within 10%; the platform takes it over and the fuel plan is kept. The same workout
  from two planning platforms is never merged: two cards.
- **Connect and disconnect.** Connecting imports at once over the window above. Disconnecting offers "Disconnect",
  which hides the workouts with their plans intact and restores them on reconnecting the same account, or "Delete
  synced data", which removes them for good.
- **Telling them apart.** A planned synced workout looks like any other card; the platform is named only once it is
  verified done, and the card then shows the measured distance and time while the detail screen still shows the
  planned ones. The detail screen shows a Garmin badge for Garmin data and no label for the rest. When a platform
  needs a fresh sign-in, the Timeline shows "needs you to sign in again" with a Reconnect button, and its card under
  Connected Apps reads "Reconnect". A failed background sync is silent; a failed "Sync Now" shows an error.

## What the data means

Model `domain/activity.dart` · local table `lib/shared/database/tables/activities_table.dart` · Supabase `activities`
(times are local time, no zone). Column meanings: `docs/schema/activities.md` (not generated yet).

**The time fields:**

| Field | Means | Written by |
|---|---|---|
| `provider_scheduled_at` | what the platform says | every sync, insert and provider update |
| `planned_time` | when the athlete plans to do it | insert (from scheduled); the detail-screen date edit, an event-date move, plan regenerate; a platform reschedule unless the athlete had moved it |
| `actual_time` | when it really happened | Garmin start, or mark-done (= planned, else scheduled, else "now"); cleared by undo and by skip |
| `scheduled_date_time` | the original plan time; **legacy, double meaning** (Q-INT11) | the date edit, sync, and the Garmin start on a Garmin completion |

"Moved by the athlete" = `planned_time` (falling back to `scheduled_date_time` for old rows) differs from the last
recorded `provider_scheduled_at`, to the instant. `Activity.movedTo` is the one way to move a workout in code; it
sets scheduled and planned together and never touches actual.

`Activity.displayTime` = actual ?? planned ?? scheduled: which day a workout shows on. Use it; never read
`scheduledDateTime` for display.

**Status:** draft · planned · inProgress · completed · skipped · archivedForBrick (a leg folded into a brick) · deleted
(kept on purpose so sync never re-imports it; never shown).

**Completion:** `completed_at`, `completion_rating` (1–5), `completion_notes`, `actual_distance_miles`,
`actual_duration_minutes`, `calories_burned` (Garmin), `completion_type` (null or `manual` = the athlete, `provider` = a
training platform; locks undo and skip), `is_fasted` (plan was made for fasted training). `nutrition_rating` (1–5) is
a Supabase column; locally it rides inside `nutrition_plan_data`. `duration_source` = `estimated` when the importer
derived the duration from distance × usual pace (never overwrite a row whose source is not `estimated`);
`Activity.isDurationEstimated` reads it.

**Platform origin:** `synced_from_provider`, `provider_workout_id` (unique per user + provider), `provider_workout_url`,
`last_synced_at`, `provider_deleted_at`, `hidden_by_disconnect` (returns on re-sync), `schedule_changed_at`,
`needs_nutrition_refresh` (schedule moved, fuel plan stale), `workout_subtype`, `pace_min/max`, `garmin_summary_id`
(set = Garmin verified), `garmin_device_name`, `parent_summary_id` / `is_parent` (Garmin multisport legs), `tss`,
`tss_planned`, `tss_actual`, `if_planned`, `if_actual`, `tp_calories`, `tp_calories_planned`.

**Brick:** `brick_metadata` (ordered legs, JSON) on the parent; `brick_id` on each archived leg.

**Also on the row:** the plan inputs (`distance_miles`, `distance_meters`, `duration_minutes`, `pace_target_minutes_per_mile`,
`intensity_level`, `intensity_target`, `intensity_z1_z2_pct` / `z3_z4` / `z5`, `time_before_minutes`, `cycling_*`,
`swimming_*`), `nutrition_plan_data` (the fuel plan, JSON), `fuel_log_data` (what was eaten, JSON), reminder fields,
`needs_upload` / `local_updated_at` (offline sync), `notes`, `deleted_at`.

## What already exists to reuse

- `data/activities_repository.dart`: local-first repo with sync, mark done/undo, skip, platform merge
  (`_mergeProviderUpdate` holds the athlete-wins rule), dedup, brick build/ungroup. Built on
  `lib/shared/data/syncable_repository.dart`; driven by `lib/shared/services/sync/sync_coordinator.dart`.
- `data/activity_mapper.dart`: Drift ↔ Supabase JSON ↔ model; fills `planned_time` on insert; hides `nutrition_rating`
  inside the plan JSON locally.
- `application/activities_service.dart`: create / update / delete, `rescheduleActivity`, date-range queries, draft cleanup.
- `application/activity_deduplication_service.dart`: duplicate removal by matching key.
- `presentation/providers/activities_controller.dart`: Riverpod controller, optimistic writes with rollback (done,
  skip, restore); `activityDetail`, `allActivities`.
- Domain: `activity.dart` (`movedTo`, `displayTime`, `isProviderCompleted`, `isDurationEstimated`), `activity_completion.dart`,
  `activity_reminder.dart`, `activity_title_formatter.dart`, `usual_pace.dart`, `provider_completion_is_final.dart`
  (the refusal thrown by undo and skip), `brick_eligibility.dart`, `brick_metadata.dart`, `brick_exceptions.dart`,
  `brick_session_legs.dart` (the one place a brick splits into legs for pricing).
- Brick providers: `brick_actions_controller`, `brick_selection_controller`, `brick_creation_available_provider`.
- `presentation/navigation/open_activity_fuel.dart`: where a card tap goes, plus `buildGeneratePlanExtras`.
- Outside the folder: `macro_dashboard/.../workout_card.dart` (the card in use), `macro_dashboard/domain/workout_state_resolver.dart`
  (card states incl. the lock), `macro_dashboard/application/dashboard_assembler.dart` (sort), `home_shell/.../home_shell_calendar_assembler.dart`
  (day dots, keyed by `displayTime`), `calendar/.../calendar_{month,week}_view_kyle.dart`, `fuel_timeline/.../timeline_brick_tile.dart`,
  `events/application/events_service.dart` (event-date move), `coach_mode/.../coach_activity_detail_controller.dart`.
- Sync (in `integrations/`): `application/integration_sync_coordinator.dart` (the four-hour rule, who pulls what),
  `application/change_detection_service.dart` (what counts as a schedule change, provider-deleted flagging), per-platform
  `*_sync_service.dart` + `*_transformer.dart`, `presentation/providers/connect_training_controller.dart` (connect,
  disconnect, hide/restore, Garmin resend).
- Server side: `supabase/functions/_shared/garmin/matcher.ts` + `matcher_executor.ts` (which planned workout a Garmin
  activity completes), `activity_completion.ts` (what it writes), `garmin-push/index.ts` (the webhook).
- Tests that pin the rules: `test/features/activities/data/activities_repository_local_reschedule_test.dart`,
  `test/features/activities/domain/activity_moved_to_test.dart`, `activity_detail_date_edit_seam_test.dart`.

Don't add: another plan-time field (use `planned_time`), another "which day" rule (use `displayTime`), another way to
move a workout (use `movedTo`), another workout card or calendar grid (the live ones are above; the 14 widgets in
`presentation/widgets/` are dead except `brick_ungroup_dialog` and `brick_validation_error_dialog`), another coach
create dialog (`coach_mode/.../create_activity_dialog.dart` is dead; the portal pushes the New Activity form).

## Links

- **qa:** `spec/daily-macros/platform-resolution.md` (two-time model, deleted-row rule) · `spec/domain/brick.md` ·
  `spec/integrations/{matching,field-map,lifecycle,final-surge,training-peaks,garmin}.md` ·
  `spec/design/surfaces/create-activity-plan.md` · `spec/design/components/brick-leg-builder.md` · intake
  `three-times-model`, `local-reschedule-beats-provider-resync`, `activity-editor-0{1,3,4,5,7}`.
- **ops open work:** eng-tasks `three-times-model`, `heal-pre-fix-event-activity-date-mismatches` · bugs
  `brick-pill-ignores-moved-workout`, `fueling-synced-past-workout-marks-skipped`, `brick-ungroup-regroup-strands-plan-and-segments`,
  `garmin-day-wide-matcher-overwrites-planned-workout`.
- **Related map pages:** `integrations.md` (matching keys, per-platform quirks, connect flow) · `nutrition_plan.md` (form,
  detail, fuel log) · `macro_dashboard.md` · `calendar.md` · `events.md` · `daily_macros.md` · `fuel_timeline.md` ·
  `coach_mode.md` (none written yet).
