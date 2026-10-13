# Connected apps (integrations)

domain: 6 Connect your training · folder: `lib/features/integrations/` (51 files) · screen `settings/.../connected_apps_screen.dart`

How a training platform's workouts reach the app, and how a plan goes back to the coach. What happens to a synced
workout once it is here (moves, completions, deletions, Garmin matching) is on `activities.md`, "Synced workouts".

## What athletes can do here

- **Open Connected Apps.** Settings → "Connected Apps" (route `/settings/connected-apps`), also a step of
  onboarding ("Your training changes daily. Your fueling should too.") and the "Connect now" nudges. Intro:
  "Connect your training platforms to automatically import workouts and generate nutrition plans."
- **Connect a platform.** Each card has "Connect". Final Surge, TrainingPeaks, Garmin Connect and V.O2 open the
  platform's own sign-in in a secure in-app browser; the app never shows a password form. Runna has no sign-in:
  "Connect Runna" asks for the calendar link ("In the Runna app, tap your profile picture → Connected Apps & Devices
  → Connect Calendar → Other, then copy the calendar URL") and checks it is a calendar ("That doesn't look like a
  calendar link…", "This link isn't a Runna calendar…"). Closing a sign-in sheet is not an error. Success:
  "{Platform} connected!" then an import; in onboarding "importing workouts…". TriDot and Strava are "Coming soon"
  with "Notify Me" → "Notified!" / "Noted!".
- **Garmin's extra step.** In onboarding a sheet first says "ONE QUICK STEP · Turn on Historical Data · So your first
  plan is built on your real training, not an average." with "Continue to Garmin" / "Not now". After connecting:
  "Garmin Connect connected! Activity upload alerts are enabled." and a request for notification permission.
- **Read a connected card.** The athlete's name as the platform knows them ("Xuan Huang"), "Last synced: Just now /
  N minutes ago / Oct 3 at 3:42 PM", a green border, "Sync Now" ("Syncing…", then "Synced!" for the visit), and
  under it "Last sync: N workouts imported" (TrainingPeaks adds "Next event: {name}"). Garmin's card says "Garmin
  syncs automatically when your watch uploads to Garmin Connect. Tap Sync Now to pull any activities that arrived
  while the app was closed." and its Sync Now re-reads our server and asks Garmin to resend recent data
  ("Checking for new activities…", "Refreshed. Weight and activity data may take a few seconds to land.").
- **Share the plan with a coach (TrainingPeaks only).** A toggle on the card, "Write fuel plan to TrainingPeaks", on
  by default. After every TrainingPeaks connect, and once at launch for already-connected athletes, a sheet
  explains: "Your fuel plan goes to your coach · Mealvana writes your plan to each TrainingPeaks workout so your
  coach can review it. You can turn it off here or in Settings." with "Keep Sharing" / "Turn Off Sharing" ("Closing
  this leaves sharing on."). What the coach sees in the workout description: a "[Mealvana Fuel Plan]" block with
  "Pre: 60g carb, 16oz water (2-3h before)" and, for workouts of an hour or more, "During: …g/h carb, …ml/h water,
  …mg/h sodium"; after the fuel log the same block shows "planned · consumed"; after completion a "[Mealvana
  Feedback]" block with "Rating: N/5" and notes. If TrainingPeaks refuses (not a Premium account) the toggle is
  replaced by "Unavailable for your TrainingPeaks plan. Your coach sees nothing from Mealvana until TrainingPeaks
  allows it." with "Re-check". Final Surge, V.O2, Runna and Garmin receive nothing.
- **Reconnect.** When a platform needs a new sign-in the card button reads "Reconnect" ("Sign in again to keep your
  workouts syncing.") and the Timeline shows "{platform} needs you to sign in again to keep syncing." with
  "Reconnect" and "×" (dismissed for this launch only). Runna never asks.
- **Disconnect.** Long-press "Sync Now" (the tip at the bottom says so): "Disconnect {Platform}? · Your synced
  workouts will be hidden and your plan will update. They come back if you reconnect. Choose "Delete synced data" to
  permanently remove them instead." → "Cancel" / "Delete synced data" / "Disconnect". Disconnecting TrainingPeaks
  also removes every Mealvana block from the coach's workouts. Reconnecting as the same athlete brings hidden
  workouts back; Runna needs a fresh link.
- **Reset push notifications.** "Not getting workout alerts? Tap to re-register this device with Mealvana's push
  service." → "Push notifications reset. Restart the app to complete."
- **Errors** are plain sentences: "Could not reach {platform}. Check your connection and try again.", "{platform}
  is busy. Try again later.", "{platform} needs you to sign in again. Please reconnect.", "{platform} sync failed.
  Please try again." A failed connect, though, can show raw error text ("Could not connect TrainingPeaks:
  TrainingPeaksOAuthException…").

Where the buttons live: `settings` (Connected Apps screen) · `integrations` (cards, dialogs, notice, controllers) ·
`onboarding` (the connect step, Garmin primer) · `macro_dashboard` (the reconnect notice).

## What the data means

Local table `integrations`, synced to Supabase: `provider`, `access_token` / `refresh_token` / `token_expires_at`
(Runna stores its calendar link as the token), `provider_athlete_id` / `_name` / `_email`,
`provider_athlete_weight_kg`, `birth_month`, `gender`, `body_fat_pct`, `athlete_zones_json` (training zones, used by
the form's "your usual" pace), `athlete_metrics_json`, `provider_is_premium`, `is_active`, `last_sync_at`,
`last_sync_status` (success | error | pending | requires_reauth = needs reconnect), `last_sync_error`. Server only:
`garmin_user_mappings`, `garmin_health_data` (dailies, sleep, body composition, stress, VO2 max; the newest
body-composition reading is copied to `users.weight_pounds` / `body_fat_pct`), `tp_writeback_ledger` (one row per
push; no row, no push), `provider_raw_payloads`. Garmin arrives through the server: `garmin-push` (the webhook),
`garmin-backfill` (resend request: 30 days of activities, 90 of body data; at most every six hours),
`garmin-oauth-callback`, `garmin-user-mapping`, `garmin-deregistration`. The other platforms are pulled by the phone
(windows on `activities.md`). Phone preferences: the write-back toggle, the consent-shown flag, the premium block.
Analytics: `integration_connect_started/success/failed`, `integration_disconnected`, `integration_sync_started/success/failed`,
`integration_notify_requested`, `connect_training_declined`, `reconnect_notice_shown/tapped/dismissed`, `expected_failure`.

## What already exists to reuse

- `presentation/providers/connect_training_controller.dart`: connect, disconnect (hide or purge), import per
  platform, Garmin backfill, analytics. `application/integration_sync_coordinator.dart` (who pulls what, the
  four-hour rule), `integration_sync_helpers.dart` (Sync Now messages, error-code → text), `provider_event_import_service.dart`
  (races). Per platform: `*_oauth_service`, `*_api_client`, `*_sync_service`, `*_transformer`; `change_detection_service.dart`.
- `presentation/widgets/integration_provider_card.dart` (every card state), `reconnect_notice.dart` +
  `reconnect_notice_controller.dart`, `tp_writeback_toggle_row.dart`; `application/tp_writeback_service.dart` +
  `tp_writeback_formatter.dart`; `shared/widgets/kyle_design/sheets/tp_writeback_consent_sheet.dart`;
  `data/integrations_repository.dart`; `athlete_zones_provider.dart`; `onboarding/.../garmin_historical_primer_sheet.dart`;
  `garmin_attribution.dart`.

Don't add: another sync trigger (the coordinator), another per-platform window, another write-back path. Dead:
`garmin_connect_banner.dart`, `import_progress_dialog.dart`, `sync_status_widget.dart`, `trackSkip()` and
`importWorkouts()` in the controller, `IntegrationProviderCard.windowCaption` / `comingSoonText`. Gardening: the
write-back premium block can never clear by itself (a 403 sets it; only a fresh connect clears it); stale comments
at `connected_apps_screen.dart:38-42,87-89,304,438,1597,1616-1623,1711`, `preferences_service.dart:56-58`,
`tp_writeback_formatter.dart:11-12`, `tp_writeback_service.dart:765-766`, `synced_workout_analytics.dart:12`,
`garmin_oauth_service.dart:18`, `final_surge_sync_service.dart:22-25` ("MANUAL SYNC ONLY"), `garmin-push/index.ts:10-15`.

## Links

- **qa:** `spec/integrations/{README,lifecycle,training-peaks,final-surge,garmin,matching,field-map,payload-usage-map,performance-data,OPEN-QUESTIONS}.md`
  · `spec/design/surfaces/integrations-data-display.md` · renderings `tp-writeback-consent@v1.html`, `ftp-source-provenance@v1.html`.
- **ops open work:** bugs `tp-writeback-blocked-by-unreliable-ispremium-flag`, `trainingpeaks-reconnect-inserts-duplicate-connection-rows`,
  `tp-token-expiry-stored-in-local-time`, `tp-background-sync-discards-imported-events`, `final-surge-completed-workouts-import-as-planned`,
  `garmin-swims-never-imported-22P02`, `garmin-activitydetails-capture-frozen-and-runs-elided`, `oauth-second-provider-creates-empty-account`,
  `connection-status-save-resends-sign-in-keys` · feature-requests `connected-apps-split-and-copy`,
  `reconnect-notice-let-athletes-opt-out`, `eng-task-reconnect-notice-instrumentation`, `garmin-historical-data-off-by-default`,
  `eng-task-final-surge-structured-workout-steps`, `eng-task-garmin-activity-files-swim-lengths`, `eng-task-garmin-token-expiry-column-is-dead`.
- **Related map pages:** `activities.md` (what sync does to workouts) · `settings.md` · `onboarding.md` · `events.md` (race import) ·
  `nutrition_plan/activity-detail.md` (Garmin attribution, write-back on save and completion).
