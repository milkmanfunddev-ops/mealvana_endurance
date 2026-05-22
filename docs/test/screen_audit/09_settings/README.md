# 09 Settings

App settings hub. Reached from any tab via the gear icon (top-right).

---

## settings_root_anonymous
**Screenshots:** `screenshots/01_settings_anon.png`, `screenshots/03_settings_scrolled.png`
**Reached by:** Any main screen → tap gear icon at top right (~x=405, y=75).

### Visible elements
| Role             | Label / Text                                | mobile-mcp coords  | Proposed ValueKey                          |
|------------------|---------------------------------------------|--------------------|--------------------------------------------|
| Button (back)    | Arrow circle (top-left)                     | (4, 63)            | `settings.back_button`                     |
| Heading          | "Settings"                                  | center top         | `settings.title`                           |
| Section heading  | "ACCOUNT"                                   | (32, 151, 128x22)  | `settings.account_section`                 |
| Status           | "Not signed in / Create an account…"        | (72, 189)          | `settings.account_status`                  |
| Button (primary) | "Create Account"                            | (32, 276, 366x56)  | `settings.create_account_button`           |
| Button (outline) | "Log In"                                    | (32, 348, 366x56)  | `settings.log_in_button`                   |
| Button (text)    | "Sign Out"                                  | (32, 420, 366x48)  | `settings.sign_out_button`                 |
| Row              | "Profile & Preferences / Edit your profile, units, and preferences" | (32, 520, 366x103) | `settings.profile_row` |
| Row              | "Appearance / Theme mode (light/dark/system)" | (32, 635, 366x82) | `settings.appearance_row`               |
| Row              | "Food Preferences / Diet, allergies, and food choices" | (32, 729, 366x82) | `settings.food_prefs_row`     |
| Row              | "Sport Preferences / Running, cycling, and swimming" | (32, 823, 366x75) | `settings.sport_prefs_row`     |
| Row              | "Nutrition Profile / Body composition, training phase, lifestyle" | scroll | `settings.nutrition_profile_row` |
| Row              | "Nutrition Targets / Set default macro targets" | scroll          | `settings.nutrition_targets_row`           |
| Row              | "Coach Connection / Connect with your coach…" | scroll           | `settings.coach_connection_row`            |
| Row              | "Connected Apps / Final Surge, TrainingPeaks, Garmin Connect" | scroll | `settings.connected_apps_row`     |
| Row              | "Help & Feedback / Get help and send feedback" | scroll          | `settings.help_row`                        |
| Label            | "Version 1.18.1 (80)"                       | (165, 817)         | `settings.version_label`                   |
| Label            | "User ID: c18d3737-…"                       | (92, 843)          | `settings.user_id_label`                   |

### Notes
- When signed in, the ACCOUNT section presumably swaps "Create Account / Log In / Sign Out" for "Email / Sign Out" only (not exercised because login is blocked).

---

## sign_out_dialog
**Screenshot:** `screenshots/02_signout_dialog.png`
**Reached by:** Settings → tap **Sign Out**.

### Visible elements
| Role          | Label / Text                                        | mobile-mcp coords  | Proposed ValueKey                       |
|---------------|-----------------------------------------------------|--------------------|-----------------------------------------|
| Dialog title  | "Sign Out?"                                         | (64, 300, 302x26)  | `signout_dialog.title`                  |
| Body          | "Your data is only saved on this device. Create an account first to back up your data and sync across devices. …" | (64, 342, 302x147) | `signout_dialog.body` |
| Button (text) | "Cancel"                                            | (298, 513, 67x48)  | `signout_dialog.cancel_button`          |
| Button (text) | "Create Account"                                    | (242, 561, 123x48) | `signout_dialog.create_account_button`  |
| Button (text) | "Sign Out Anyway"                                   | (238, 609, 127x48) | `signout_dialog.sign_out_anyway_button` |

---

## profile_edit
**Screenshot:** `screenshots/08_profile_edit.png`
**Reached by:** Settings → tap **Profile & Preferences**.

### Visible elements
| Role             | Label / Text                       | Proposed ValueKey                       |
|------------------|------------------------------------|-----------------------------------------|
| Field            | First name                         | `profile_edit.first_name_field`         |
| Field            | Last name                          | `profile_edit.last_name_field`          |
| Field            | Email                              | `profile_edit.email_field`              |
| Selector         | Gender MALE/FEMALE/NON-BINARY      | `profile_edit.gender_<value>_button`    |
| Selector         | Birthday "1/1/1990"                | `profile_edit.birthday_button`          |
| Field (number)   | Height ft / in                     | `profile_edit.height_ft_field`, `profile_edit.height_in_field` |
| Field (number)   | Weight                             | `profile_edit.weight_field`             |
| Button (back)    | Arrow circle                       | `profile_edit.back_button`              |
| Button (primary) | "Save Changes"                     | `profile_edit.save_button`              |

### Notes
- Same scaffold as onboarding profile form, but Email is now a separate row (with label), and the field is "Birthday" (full date) rather than "Birth Year".
- IMPERIAL/METRIC toggle still present (not screenshotted scrolled — same `profile_edit.units_*_button`).

---

## appearance (theme dialog)
**Screenshot:** `screenshots/09_appearance.png`
**Reached by:** Settings → tap **Appearance**.

### Visible elements
| Role          | Label / Text     | Proposed ValueKey                   |
|---------------|------------------|-------------------------------------|
| Dialog title  | "Theme Mode"     | `appearance.dialog_title`           |
| Radio         | System           | `appearance.system_button`          |
| Radio         | Light            | `appearance.light_button`           |
| Radio (selected)| Dark           | `appearance.dark_button`            |

### Notes
- Appears as a CupertinoActionSheet-style modal. Tap outside dismisses.

---

## sport_preferences
**Screenshot:** `screenshots/04_sport_preferences.png`
**Reached by:** Settings → tap **Sport Preferences**.

### Visible elements
| Role          | Label / Text  | mobile-mcp coords  | Proposed ValueKey                       |
|---------------|---------------|--------------------|-----------------------------------------|
| Button (back) | Arrow circle  | (4, 63)            | `sport_prefs.back_button`               |
| Heading       | "Sport Preferences" | center        | `sport_prefs.title`                     |
| Row           | "Running Preferences / Water bottle: No" | (16, 240, 398x70) | `sport_prefs.running_row` |
| Row           | "Cycling Preferences / Not configured"   | (16, 380, 398x70) | `sport_prefs.cycling_row` |
| Row           | "Swimming Preferences / Not configured"  | (16, 520, 398x70) | `sport_prefs.swimming_row` |

---

## running_preferences
**Screenshot:** `screenshots/05_running_preferences.png`

### Visible elements
| Role             | Label / Text                  | Proposed ValueKey                       |
|------------------|-------------------------------|-----------------------------------------|
| Heading          | "Running Details"             | `running_prefs.title`                   |
| Subheading       | "Running details / Help us estimate your hydration needs." | `running_prefs.subheading` |
| Toggle           | "I run with a water bottle"   | `running_prefs.water_bottle_toggle`     |
| Button (primary) | "Save"                        | `running_prefs.save_button`             |
| Button (back)    | Arrow circle                  | `running_prefs.back_button`             |

---

## cycling_preferences
**Screenshot:** `screenshots/06_cycling_preferences.png`

### Visible elements
| Role             | Label / Text                       | Proposed ValueKey                       |
|------------------|------------------------------------|-----------------------------------------|
| Heading          | "Cycling Details"                  | `cycling_prefs.title`                   |
| Field            | FTP (watts)                        | `cycling_prefs.ftp_field`               |
| Stepper          | Bottles minus                      | `cycling_prefs.bottles_minus`           |
| Stepper          | Bottles plus                       | `cycling_prefs.bottles_plus`            |
| Label            | "2 BOTTLES / 1 bottle = 20 oz (591 mL)" | `cycling_prefs.bottles_label`      |
| Toggle           | "I use Aero Bottles"               | `cycling_prefs.aero_bottles_toggle`     |
| Toggle           | "I use a Bento Box for food"       | `cycling_prefs.bento_box_toggle`        |
| Button (primary) | "Save"                             | `cycling_prefs.save_button`             |
| Button (back)    | Arrow circle                       | `cycling_prefs.back_button`             |

---

## swimming_preferences
**Screenshot:** `screenshots/07_swimming_preferences.png`

### Visible elements
| Role             | Label / Text                       | Proposed ValueKey                       |
|------------------|------------------------------------|-----------------------------------------|
| Heading          | "Swimming Details"                 | `swimming_prefs.title`                  |
| Field            | CSS minutes                        | `swimming_prefs.css_minutes_field`      |
| Field            | CSS seconds                        | `swimming_prefs.css_seconds_field`      |
| Toggle           | "I typically wear a wetsuit"       | `swimming_prefs.wetsuit_toggle`         |
| Radio            | None / Latex / Silicone / Neoprene | `swimming_prefs.cap_<value>_button`     |
| Button (primary) | "Save"                             | `swimming_prefs.save_button`            |
| Button (back)    | Arrow circle                       | `swimming_prefs.back_button`            |

---

## nutrition_profile
**Screenshot:** `screenshots/10_nutrition_profile.png`, `screenshots/10b_nutrition_profile_scrolled.png`
**Reached by:** Settings → tap **Nutrition Profile**.

### Visible elements
| Role             | Label / Text                       | Proposed ValueKey                       |
|------------------|------------------------------------|-----------------------------------------|
| Heading          | "Nutrition Profile"                | `nutrition_profile.title`               |
| Section heading  | "BODY FAT % (OPTIONAL)"            | `nutrition_profile.body_fat_section`    |
| Field            | "e.g., 15.0" (%)                   | `nutrition_profile.body_fat_field`      |
| Section heading  | "DAILY ACTIVITY LEVEL"             | `nutrition_profile.activity_level_section` |
| Radio            | Desk-based / Mostly sitting (office work) | `nutrition_profile.activity_desk_button` |
| Radio (selected) | Mixed / Some movement throughout the day  | `nutrition_profile.activity_mixed_button` |
| Radio            | Active / On your feet most of the day     | `nutrition_profile.activity_active_button` |
| Radio            | Very Active / Physically demanding job or very active | `nutrition_profile.activity_very_active_button` |
| Section heading  | "TYPICAL WEEKLY TRAINING HOURS"    | `nutrition_profile.training_hours_section` |
| Field            | "e.g., 10.0" (hrs/week)            | `nutrition_profile.training_hours_field` |
| Section heading  | "CARB CYCLING"                     | `nutrition_profile.carb_cycling_section` |
| Toggle           | Carb Cycling                       | `nutrition_profile.carb_cycling_toggle` |
| Section heading  | "TRAINING PHASE"                   | `nutrition_profile.training_phase_section` |
| Radio (selected) | Base / Building aerobic fitness    | `nutrition_profile.phase_base_button`   |
| Radio            | Build / Increasing intensity       | `nutrition_profile.phase_build_button`  |
| Radio            | Peak / Race-specific training      | `nutrition_profile.phase_peak_button`   |
| Radio            | Taper / Reduced volume before race | `nutrition_profile.phase_taper_button`  |
| Radio            | Race Week / Final preparation      | `nutrition_profile.phase_race_week_button` |
| Radio            | Off Season / Recovery and base maintenance | `nutrition_profile.phase_off_season_button` |

---

## nutrition_targets
**Screenshot:** `screenshots/11_nutrition_targets.png`
**Reached by:** Settings → tap **Nutrition Targets**.

### Visible elements
| Role             | Label / Text                       | Proposed ValueKey                       |
|------------------|------------------------------------|-----------------------------------------|
| Heading          | "Nutrition Targets"                | `nutrition_targets.title`               |
| Button (icon)    | Help "?" (top-right)               | `nutrition_targets.help_button`         |
| Info card        | "Set your preferred macro targets…" | `nutrition_targets.info_card`          |
| Section heading  | "PRE-ACTIVITY"                     | `nutrition_targets.pre_section`         |
| Field (number)   | Carbs (g)                          | `nutrition_targets.pre_carbs_field`     |
| Field (number)   | Protein (g)                        | `nutrition_targets.pre_protein_field`   |
| Field (number)   | Fat (g)                            | `nutrition_targets.pre_fat_field`       |
| Field (number)   | Sodium (mg)                        | `nutrition_targets.pre_sodium_field`    |
| Field (number)   | Fluids (ml)                        | `nutrition_targets.pre_fluids_field`    |
| Section heading  | "DURING RUN (per hour)"            | `nutrition_targets.during_run_section`  |
| Field (number)   | Carbs (g/hr)                       | `nutrition_targets.during_run_carbs_field` |
| Field (number)   | Sodium (mg/hr)                     | `nutrition_targets.during_run_sodium_field` |
| Field (number)   | Fluids (ml/hr)                     | `nutrition_targets.during_run_fluids_field` |
| Section heading  | "DURING BIKE (per hour)"           | `nutrition_targets.during_bike_section` |
| Field (number)   | Carbs (g/hr)                       | `nutrition_targets.during_bike_carbs_field` |
| (presumed)       | DURING SWIM section also exists    | `nutrition_targets.during_swim_*`       |

### Notes
- All fields show "Auto" placeholder until user types a value.
- "Auto" filling means the algorithm chooses based on profile.

---

## coach_connection
**Screenshot:** `screenshots/12_coach_connection.png`
**Reached by:** Settings → tap **Coach Connection**.

### Visible elements
| Role             | Label / Text                       | Proposed ValueKey                       |
|------------------|------------------------------------|-----------------------------------------|
| Heading          | "Coach Connection"                 | `coach_connection.title`                |
| Subheading       | "Connect with Your Coach"          | `coach_connection.subheading`           |
| Body             | "Enter the pairing code your coach gave you. …" | `coach_connection.description` |
| Field            | "Enter Coach Code" (placeholder "A B C 1 2 3") | (40, 480, 365x100) | `coach_connection.code_field` |
| Button (primary) | "Connect"                          | (40, 620, 365x90)  | `coach_connection.connect_button`       |

### Notes
- When connected, this screen will show coach info + disconnect; not exercised.

---

## connected_apps
See `/Users/leemartin/development/mealvana_endurance/docs/test/screen_audit/10_integrations/README.md` — Connected Apps is documented there.

---

## help_feedback
See `/Users/leemartin/development/mealvana_endurance/docs/test/screen_audit/14_other/README.md` for Help & Feedback, Rate Your Experience, Report a Bug.
