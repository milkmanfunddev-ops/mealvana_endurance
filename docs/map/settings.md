# Settings

domain: 9 Account and app · folders: `lib/features/settings/` (29 files), `lib/features/privacy/`, `lib/features/feedback/`

Route `/settings`, from the gear in the home header.

## What athletes can do here

- **Account.** Signed in: "Signed in with Apple / Google / Email" and the email, "Sign Out", "Delete Account".
  Anonymous: "Not signed in · Create an account to sync your data across devices", "Create an account to save your
  data", "Log into an existing account"; an anonymous athlete cannot sign out (that would throw away the only key
  to their data).
  - Sign out: "Sign out? · You'll need to sign in again to use Mealvana. Your data stays with your account." →
    "Cancel" / "Sign out". Pending changes upload first; the phone's copy of this account is removed except anything
    not yet uploaded; the app returns to Welcome (offline: "You're offline, so your unsynced changes stay on this
    phone and sync the next time you sign in.").
  - Delete account: "Delete Account? · This will permanently delete your account and all associated data. This
    action cannot be undone." → "Cancel" / "Delete". Needs a connection ("Deleting your account needs a connection.
    Nothing was deleted; try again when you're online.", also shown on a server error).
- **Profile & Preferences.** First name, Last name, contact or login email, Gender (Male / Female / Non-binary),
  Birthday (with platform-source badges when TrainingPeaks or Final Surge supplied them); "I run with a water
  bottle"; "Unit System"; "Gut Training Level", "Sweat Rate", "Sweat Profile" (sodium category, a sweat test's
  concentration, date, source, known sweat rate, "How to test"). "Save Changes" → "Preferences saved successfully";
  leaving with edits asks "Discard changes?".
- **Appearance.** "Theme Mode": System / Light / Dark.
- **Diet, Allergies & Formulas.** "Dietary Preference", "Allergies", "Food Likes & Dislikes" (search, "Create Custom
  Food", five-point sliders), "Formula Library" (see `formula_kit.md`).
- **Sport Preferences.** Running / Cycling / Swimming ("FTP: …W", "CSS: …", bottles, aero bottle, bento box,
  wetsuit, swim cap).
- **Body Composition.** Weight, Height, "Body Fat % (optional)", "Daily Activity Level" (desk / mixed / active /
  very active), "Typical Weekly Training Hours", "Carb Cycling" (reduce carbs on easy and rest days), "Training
  Phase" (Base / Build / Peak / Taper / Race week / Off-season). "Save" → "Nutrition profile saved". Garmin or
  TrainingPeaks body data shows a source chip. These feed the daily targets; saving resets today's and future days.
- **Nutrition Targets.** Pre-activity, per-sport during, post-activity targets, hint "Auto"; "During-workout targets
  only apply to activities 90 minutes or longer."; "Why we warn above 120 g/hr"; "Reset All to Defaults".
- **Coach Connection.** "Enter Coach Code" ("ABC123") → "Connect"; "Message Coach"; "Disconnect from Coach"
  ("Disconnect Coach?"). See `coach_mode.md`.
- **Connected Apps.** See `integrations.md`.
- **Privacy.** "Share anonymous usage data" (Mixpanel; screens and features used plus age, gender, weight and
  gut-training level; never meal logs; no advertising SDKs). "Turning this off stops usage data immediately." /
  "Usage data is off. The app works exactly the same." "To run the app" explains what the account stores; "Legal":
  "Privacy Policy", "Terms of Service". Athletes in the EEA, UK or Washington see a consent screen on first run
  ("Your privacy · Share usage data", off by default).
- **Help & Feedback.** "Rate Your Experience" (in-app survey), "Report a Bug" (Wiredash), "Email Support",
  "Website".
- **Version and User ID.** "Version x.y.z (build)"; tapping the version seven times reveals "DEVELOPER / TESTER":
  "Mark this device as internal" (events tagged, tester features such as the $0.99 credit pack), "Device ID", and in
  dev builds "Debug console" (report log, manual sync, Sentry probes).

## What the data means

The `users` profile row: `first_name`, `last_name`, `email`, `gender`, `birthday`, `height_feet/inches`,
`weight_pounds` (+ `_updated_at`), `body_fat_pct` (+ `_updated_at`), `runs_with_water_bottle`, `unit_system`,
`gut_training`, `sweat_rate`, `gi_sensitivity`, `ftp_watts`, `css_pace`, `typical_bike_bottles`, `has_aero_bottle`,
`has_bento_box`, `typical_wetsuit`, swim cap, `dietary_preference`, `allergies`, `nutrition_target_overrides`,
`lifestyle`, `typical_weekly_hours`, `carb_cycle_opt_in`, `training_phase`. Also `food_preferences`, `user_foods`,
`feedback`. Phone only: theme, analytics consent (status, regime, date, version), the internal-device flag
(Keychain), write-back preferences. Units live on the profile, not the phone. Deleting an account calls the
`delete-user` function and only then wipes the phone.

## What already exists to reuse

- `presentation/providers/settings_controller.dart` (profile saves, sign out, delete, cache invalidation),
  screens `settings_screen`, `preferences_screen`, `nutrition_profile_screen` (Body Composition), `sport_preferences_hub_screen`,
  `food_preferences_hub_screen` + `food_preferences_screen`, `nutrition_targets_screen`, `sweat_profile_screen`,
  `coach_connection_screen`, `connected_apps_screen`, `privacy_screen`, `help_screen`, `debug_screen`.
- `privacy/presentation/screens/privacy_consent_screen.dart`; `shared/services/preferences_service.dart`;
  `report_pipeline_probe.dart`; `sign_out_notice.dart`.

Don't add: another profile field store (the `users` row), another consent store. Dead: `search_result_item_widget.dart`,
`_buildCoachModeLink`, the `settings.status_*` content block, feedback `saveSurveyResponse` / `hasRecentSurveyResponse`.
Gardening: `settings_screen.dart:252-254,836`, `settings_controller.dart:1156`.

## Links

- **qa:** no settings, profile or privacy spec yet; `spec/design/surfaces/integrations-data-display.md` (source chips).
- **ops open work:** bugs `cycling-swimming-settings-overflow-390pt`, `sport-prefs-ftp-css-never-persist-locally`,
  `anonymous-profile-reset-invents-150lb-and-5ft8`, `new-anonymous-uid-minted-per-open-and-signout`,
  `profile-email-diverges-from-auth-email`, `profile-save-macro-cache-stale` · feature-requests
  `eng-task-signins-without-app-profile`, `eng-task-mealvana-internal-flag-at-account-creation`, `make-food-preferences-findable-for-the-tuner`.
- **Related map pages:** `integrations.md` · `formula_kit.md` · `coach_mode.md` · `onboarding.md` · `daily_macros.md`.
