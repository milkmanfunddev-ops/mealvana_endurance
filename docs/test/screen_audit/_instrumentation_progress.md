# ValueKey Instrumentation Progress

### 01_welcome_auth (done) — 14 keys added across 3 files

Files changed:
- `lib/features/onboarding/presentation/screens/welcome_screen.dart` (5 keys: welcome.title, welcome.subtitle, welcome.description, welcome.get_started_button, welcome.log_in_button)
- `lib/features/auth/presentation/screens/post_onboarding_auth_screen.dart` (6 keys: login_options.title/subtitle/apple_button/google_button/email_button/back_button — dynamic keys based on isLogin flag; post_onboarding.* variants for signup mode)
- `lib/features/auth/presentation/screens/email_login_screen.dart` (8 keys: login.title, login.subtitle, login.email_field, login.password_field, login.password_visibility_button, login.forgot_password_button, login.log_in_button, login.back_button, login.back_button_appbar)

Notes:
- `_buildOAuthButton` helper gained a `Key? key` parameter and passes it to the inner `ElevatedButton`
- Title/subtitle in post_onboarding_auth_screen use non-const ValueKey (dynamic based on isLogin mode)
- Pre-existing `use_build_context_synchronously` info in post_onboarding_auth_screen confirmed not introduced by this PR


### 02_onboarding (done) — ~85 keys added across 12 files

Files changed:
- `lib/shared/widgets/navigation/figma_onboarding_footer.dart` — added continueButtonKey/backButtonKey params; passes to inner ElevatedButton/IconButton
- `lib/shared/widgets/kyle_design/buttons/segmented_control.dart` — added segmentKeyPrefix param; auto-keys _SegmentButton; added super.key to _SegmentButton
- `lib/shared/widgets/selection/figma_radio_option_card.dart` — added valueKey field to FigmaRadioOptionItem; passes to FigmaRadioOptionCard
- `lib/shared/widgets/selection/figma_food_chip.dart` — FigmaFoodChipGrid auto-keys each FigmaFoodChip by slug
- `lib/features/settings/presentation/screens/connected_apps_screen.dart` — header text, skip button, FigmaOnboardingFooter keys, IntegrationProviderCard keys (FS, TP, Garmin, coming-soon dynamic)
- `lib/features/onboarding/presentation/screens/user_profile_screen.dart` — profile.title, all form fields via _buildTextField/fieldKey, gender buttons via _buildRadioOption/optionKey, birth_year InkWell, height/weight fields, unit segmented control, FigmaOnboardingFooter keys
- `lib/features/onboarding/presentation/screens/sports_selection_screen.dart` — title, running/cycling/swimming chips, FigmaOnboardingFooter keys
- `lib/features/onboarding/presentation/screens/dietary_preference_screen.dart` — title, diet options via FigmaRadioOptionItem.valueKey (dynamic enum slugs), FigmaOnboardingFooter keys
- `lib/features/onboarding/presentation/screens/allergies_screen.dart` — title, no-allergies chip, allergy chips (dynamic enum slugs), FigmaOnboardingFooter keys
- `lib/features/onboarding/presentation/screens/food_preferences_v2_screen.dart` — title, search field, common_section label, FigmaOnboardingFooter keys; chip keys auto-generated in FigmaFoodChipGrid
- `lib/features/auth/presentation/screens/post_onboarding_auth_screen.dart` — create_account.skip_button, _buildAppBar now mode-aware (login_options.back_button vs create_account.back_button)

Notes:
- Pre-existing analyze issues: 32 (no regressions introduced)
- `IntegrationProviderCard` coming-soon keys are dynamic ValueKey (not const) since they use runtime string interpolation
- Food chip slugs are computed at build time: lower-case name with non-alphanumeric chars replaced by underscore


### 06_activity_create (done) — ~35 keys added across 12 files

Files changed:
- `lib/features/nutrition_plan/presentation/screens/new_activity_screen.dart` — generate_plan_button, use_template_button (previously added)
- `lib/features/nutrition_plan/presentation/widgets/new_activity/shared/new_activity_app_bar.dart` — activity_create.title, activity_create.back_button (previously added)
- `lib/features/nutrition_plan/presentation/widgets/new_activity/shared/new_activity_date_time_section.dart` — datetime_labels, datetime_display, edit_datetime_button (previously added)
- `lib/features/nutrition_plan/presentation/widgets/new_activity/shared/sport_selector.dart` — tab_running/biking/swimming/brick (previously added)
- `lib/features/nutrition_plan/presentation/widgets/new_activity/running_tab_content.dart` — workout_name_field, view_forecast_link, temp_minus/plus/value, humidity_control, fueling_window_minus/plus/value; _ControlButton gained super.key
- `lib/features/nutrition_plan/presentation/widgets/new_activity/cycling_tab_content.dart` — workout_name_field, fueling_window_control
- `lib/features/nutrition_plan/presentation/widgets/new_activity/swimming_tab_content.dart` — workout_name_field, fueling_window_control
- `lib/features/nutrition_plan/presentation/widgets/new_activity/shared/workout_details_widget.dart` — details_heading, distance_field; _DistanceInput gained super.key; _DualSegmentField gained firstFieldKey/secondFieldKey → duration_hr_field, duration_mins_field
- `lib/features/nutrition_plan/presentation/widgets/new_activity/shared/fasted_toggle.dart` — fasted_toggle on KyleSwitch
- `lib/shared/widgets/kyle_design/inputs/two_option_pill_slider.dart` — added leftKey/rightKey params; _SliderSegmentLabel gained super.key
- `lib/shared/widgets/kyle_design/inputs/duration_pace_toggle.dart` — passes by_duration_toggle/by_pace_toggle keys to TwoOptionPillSlider
- `lib/shared/widgets/kyle_design/inputs/intensity_distribution_widget.dart` — intensity_heading, intensity_mode_toggle; _EstimatePreciseToggle gained super.key
- `lib/shared/widgets/kyle_design/inputs/intensity_preset_chips.dart` — auto-keys each GestureDetector as activity_create.intensity_${preset.name}_chip

Notes:
- Date picker CANCEL/OK buttons are from `calendar_date_picker2` package — cannot key without modifying third-party code (unresolved)
- WorkoutPreset enum .name gives camelCase (e.g. racePace) so key is activity_create.intensity_racePace_chip not race_pace_chip
- analyze: 78 issues (all pre-existing info/warnings)


### 07_nutrition_plan (done) — ~30 keys added across 9 files

Files changed:
- `lib/features/nutrition_plan/presentation/screens/adjust_macros_screen.dart` — adjust_macros.back_button, title, activity_summary, edit_macros_button, reset_all_button, create_plan_button; paceStatKey/burnStatKey passed to PaceBurnDisplay
- `lib/features/nutrition_plan/presentation/widgets/adjust_macros/edit_macros_dialog_widget.dart` — edit_macros.title, cancel_button, save_button; all 12 TextField widgets auto-keyed via switch in _buildTextField (carbs_pre/during/post, protein_*, fluids_*, sodium_*)
- `lib/features/nutrition_plan/presentation/widgets/activity_detail/activity_detail_app_bar.dart` — plan_detail.back_button, plan_detail.title
- `lib/features/nutrition_plan/presentation/widgets/activity_detail/activity_detail_action_buttons.dart` — plan_detail.save_workout_button, plan_detail.save_template_button
- `lib/features/nutrition_plan/presentation/widgets/activity_detail/nutrition_sections_builder.dart` — plan_detail.${category}_section heading Text, plan_detail.${category}_add_food_button (dynamic, category = before_run/during_run/after_run)
- `lib/features/nutrition_plan/presentation/widgets/activity_detail/activity_schedule_info.dart` — plan_detail.summary_label, plan_detail.date_label, plan_detail.time_label
- `lib/shared/widgets/kyle_design/cards/macro_targets_table.dart` — adjust_macros.targets_heading, adjust_macros.help_button, adjust_macros.row_carbs/protein/fluids/sodium
- `lib/shared/widgets/kyle_design/data/large_stat.dart` — LargeStatDisplay gained firstStatKey/secondStatKey params; PaceBurnDisplay gained paceStatKey/burnStatKey

Notes:
- analyze: no new errors/warnings introduced
- plan_detail.during_add_food_button in README maps to actual key plan_detail.during_run_add_food_button (category string includes _run suffix)


### 03_calendar (done) — ~25 keys added across 9 files

Files changed:
- `lib/features/calendar/presentation/widgets/calendar_view_toggle.dart` — by_week_toggle/by_month_toggle keys on GestureDetector; _buildToggleOption gained Key optionKey param
- `lib/shared/widgets/tabs_screen.dart` — calendar.settings_button on GestureDetector (both mobile and rail layouts)
- `lib/shared/widgets/kyle_design/navigation/floating_action_buttons_bar.dart` — bottom_nav.calendar_tab/diary_tab/events_tab/learn_tab on CircularActionButton; calendar.create_activity_fab on GestureDetector
- `lib/features/calendar/presentation/widgets/calendar_week_view_kyle.dart` — prev/next week GestureDetectors (calendar.prev_month_button/next_month_button); calendar.month_label on Text; dynamic calendar.day_cell_<yyyy_mm_dd> on each day GestureDetector
- `lib/features/calendar/presentation/widgets/calendar_month_view_kyle.dart` — same nav keys; same day cell pattern
- `lib/features/activities/presentation/widgets/no_fueling_plans_widget.dart` — calendar.empty_title, calendar.empty_subtitle
- `lib/features/activities/presentation/widgets/activity_card.dart` — dynamic calendar.activity_card_${activity.id} on InkWell
- `lib/features/events/presentation/widgets/upcoming_event_card_kyle.dart` — dynamic calendar.event_card_${event.id} on InkWell (event case); calendar.create_event_card (null/create case)
- `lib/features/activities/presentation/screens/activities_list_screen.dart` — calendar.upcoming_races_heading (SectionHeaderText, inlined from _buildUpcomingRacesHeader); calendar.todays_activities_heading (SectionHeaderText)

Notes:
- _buildUpcomingRacesHeader method is now unused (replaced by inline SectionHeaderText); produces one new unused_element warning (not an error)
- Day cell keys use padded month/day format: calendar.day_cell_2026_05_12
- Navigation key names use "month" consistently (prev_month_button/next_month_button) for both week and month views per README spec


### 04_event_create (done) — ~20 keys added across 4 files

Files changed:
- `lib/features/events/presentation/screens/event_form_screen.dart` — close_button (IconButton), home_button (IconButton), title (Text), name_field (TextFormField), location_field (TextFormField), date_button (OutlinedButton.icon), time_button (OutlinedButton.icon), additional_heading (ExpansionTile), create_button (KylePrimaryButton)
- `lib/features/calendar/presentation/widgets/sport_category_selector.dart` — sport_category_heading (Text); dynamic event_create.sport_${category.name}_chip on _SportCategoryButton (super.key added); keys: sport_running_chip, sport_cycling_chip, sport_swimming_chip, sport_triathlon_chip, sport_duathlon_chip, sport_multisport_chip, sport_brick_chip
- `lib/features/calendar/presentation/widgets/event_subtype_dropdown.dart` — race_distance_heading (Text), race_distance_dropdown (DropdownButtonFormField), dynamic event_create.race_distance_option_${subtype.name} on each DropdownMenuItem

Notes:
- Sport chip keys use full ActivityType enum names (running/cycling/swimming) not README short slugs (run/ride/swim) — README says "proposals not contracts"
- analyze: no new errors introduced


### 05_event_details (done) — ~30 keys added across 9 files

Files changed:
- `lib/features/events/presentation/screens/events_list_screen.dart` — my_events.title, my_events.upcoming_heading, my_events.new_event_button
- `lib/features/events/presentation/widgets/events_empty_state.dart` — my_events.empty_title, my_events.empty_subtitle, my_events.new_event_button
- `lib/features/events/presentation/widgets/event_list_card.dart` — dynamic my_events.event_card_${event.id} on BaseCard
- `lib/features/events/presentation/screens/event_detail_screen.dart` — event_details.back_button (CustomAppBarBackButton), event_details.title, event_details.home_button, event_details.more_button (PopupMenuButton), event_details.menu_edit (PopupMenuItem), event_details.menu_delete (PopupMenuItem)
- `lib/features/events/presentation/widgets/event_header_card.dart` — event_details.event_name, event_details.event_date, event_details.event_countdown (both branches of EventCountdownBadge)
- `lib/features/events/presentation/widgets/event_action_buttons_card.dart` — event_details.nutrition_heading, event_details.create_nutrition_button, event_details.create_carb_loading_button, event_details.checklist_button
- `lib/features/events/presentation/widgets/event_footer_links.dart` — event_details.view_events_link, event_details.create_new_event_link
- `lib/features/race_checklist/presentation/screens/race_checklist_screen.dart` — checklist.back_button (CustomAppBarBackButton), checklist.title, checklist.intro_card (BaseCard), checklist.gear_section (BaseCard via cardKey param), checklist.nutrition_section (BaseCard via cardKey param); dynamic checklist.gear_item_${item.id} on InkWell in _buildChecklistItem (itemKey param added); dynamic checklist.add_custom_button_${category} on add-custom InkWell

Notes:
- ChecklistItem domain model has no slug field; using item.id (UUID) for checklist.gear_item_* keys — stable and unique per item
- _buildChecklistItem gained optional itemKey param; _buildCategoryCard gained optional cardKey param
- Add-custom button keyed as checklist.add_custom_button_gear / checklist.add_custom_button_nutrition to distinguish sections
- README spec shows checklist.add_custom_button (singular); actual implementation has one per category — README keys are proposals not contracts
- analyze: 2046 issues (no regressions — same count as after area 04)


### 08_carb_loading (done) — ~25 keys added across 2 files

Files changed:
- `lib/features/carb_loading/presentation/screens/carb_loading_protocol_selection_screen.dart`
  - carb_loading.title (AppBar Text), carb_loading.subheading, carb_loading.description
  - _ProtocolCard gained super.key, selectButtonKey, tagKeyPrefix params
  - carb_loading.protocol_3_day_card / protocol_2_day_card (ValueKey on _ProtocolCard)
  - carb_loading.select_3_day_button / select_2_day_button (ElevatedButton via selectButtonKey)
  - Dynamic carb_loading.protocol_3_day_tag_<slug> / protocol_2_day_tag_<slug> on tag Containers (slug from tag string)
- `lib/features/carb_loading/presentation/screens/carb_loading_day_detail_page.dart`
  - carb_plan_day.back_button (CustomAppBarBackButton), carb_plan_day.title (Text), carb_plan_day.date_label (Text)
  - carb_plan_day.done_button (TextButton), carb_plan_day.menu_button (PopupMenuButton)
  - carb_plan_day.menu_reset_progress / menu_mark_complete (PopupMenuItem)
  - carb_plan_day.daily_total_card (BaseCard), carb_plan_day.edit_target_button (TextButton.icon)
  - Dynamic carb_plan_day.section_${mealType.name} on meal section BaseCard
  - Dynamic carb_plan_day.food_chip_<slug> on _buildQuickAddFoodButton GestureDetector (chipKey param added)
  - Dynamic carb_plan_day.add_food_${mealType.name} on add-food InkWell

Notes:
- Protocol selection AppBar has no explicit leading widget; auto-generated back button cannot be keyed without more invasive changes — noted as unresolved
- MealType.name gives camelCase enum names (breakfast/morningSnack/lunch/afternoonSnack/dinner/eveningSnack)
- Food chip slugs derived from food.displayName via lowercase + non-alphanumeric replacement
- analyze: 2046 issues (no regressions)


### 09_settings (done) — ~60 keys added across 5 files

Files changed:
- `lib/features/settings/presentation/screens/settings_screen.dart`
  - settings.back_button (IconButton), settings.title (Text), settings.account_section (Text)
  - settings.account_status (Text, anonymous branch), settings.create_account_button (KylePrimaryButton), settings.log_in_button (KyleSecondaryButton), settings.sign_out_button (TextButton)
  - signout_dialog.cancel_button, signout_dialog.create_account_button, signout_dialog.sign_out_anyway_button (AlertDialog TextButton children)
  - _buildQuickLink gained rowKey param; all 8 hub rows keyed: settings.profile_row / appearance_row / food_prefs_row / sport_prefs_row / nutrition_profile_row / nutrition_targets_row / coach_connection_row / connected_apps_row / help_row
  - settings.version_label (FutureBuilder Text), settings.user_id_label (GestureDetector)
  - appearance.system_button / light_button / dark_button (RadioListTile via switch+ValueKey in ThemeMode.values.map)
- `lib/features/settings/presentation/screens/sport_preferences_hub_screen.dart`
  - sport_prefs.back_button (CustomAppBarBackButton), sport_prefs.title (Text)
  - _buildHubTile gained tileKey param; sport_prefs.running_row / cycling_row / swimming_row on InkWell
- `lib/features/settings/presentation/screens/nutrition_profile_screen.dart`
  - nutrition_profile.back_button, nutrition_profile.title
  - _buildSectionLabel gained labelKey param; section labels keyed: body_fat_section / activity_level_section / training_hours_section / training_phase_section
  - nutrition_profile.body_fat_field (KyleInputField), nutrition_profile.training_hours_field (KyleInputField), nutrition_profile.carb_cycling_toggle (KyleSwitch)
  - _buildRadioTile gained tileKey param; lifestyle tiles: nutrition_profile.activity_${lifestyle.name}_button; training phase tiles: nutrition_profile.phase_${phase.name}_button
- `lib/features/settings/presentation/screens/nutrition_targets_screen.dart`
  - nutrition_targets.back_button, nutrition_targets.title, nutrition_targets.help_button (IconButton)
  - nutrition_targets.info_card (BaseCard), nutrition_targets.pre_section (via cardKey param on _buildSectionCard)
  - Pre-activity fields keyed via fieldKey param on _buildField: pre_carbs_field / pre_protein_field / pre_fat_field / pre_sodium_field / pre_fluids_field
  - During section keys on DuringSportOverrideSection: during_run_section / during_bike_section / during_swim_section
- `lib/features/settings/presentation/screens/coach_connection_screen.dart`
  - coach_connection.back_button, coach_connection.title, coach_connection.subheading, coach_connection.description
  - coach_connection.code_field (TextField), coach_connection.connect_button (ElevatedButton)

Notes:
- During Run/Bike/Swim per-field keys (nutrition_targets.during_run_carbs_field etc.) are unresolved — they live inside DuringSportOverrideSection._buildField which has no key param exposed; adding would require modifying that shared widget
- Lifestyle enum names (desk/mixed/active/veryActive) produce keys like nutrition_profile.activity_desk_button (not "desk-based" as in README — README keys are proposals)
- Training phase enum names (base/build/peak/taper/raceWeek/offSeason) produce keys like nutrition_profile.phase_raceWeek_button
- analyze: 2046 issues (no regressions)

## Session 2 (continued)

### Area 09 (settings) — gap fill: profile_edit / running_prefs / cycling_prefs / swimming_prefs
- `lib/features/settings/presentation/screens/preferences_screen.dart`
  - profile_edit.first_name_field / last_name_field / email_field (via fieldKey param on _buildTextField)
  - profile_edit.gender_male_button / gender_female_button / gender_non_binary_button (via radioKey param on _buildRadioOption)
  - profile_edit.birthday_button (InkWell)
  - profile_edit.height_ft_field / height_in_field / weight_field (via fieldKey param)
  - profile_edit.save_button / back_button (via continueButtonKey / backButtonKey on FigmaOnboardingFooter)
- `lib/features/onboarding/presentation/screens/running_details_screen.dart`
  - running_prefs.back_button (GestureDetector, settings mode only)
  - running_prefs.title / subheading (Text)
  - running_prefs.water_bottle_toggle (FigmaToggleCard)
  - running_prefs.save_button (via continueButtonKey on FigmaOnboardingFooter)
- `lib/features/onboarding/presentation/screens/cycling_details_screen.dart`
  - cycling_prefs.back_button (GestureDetector, settings mode only)
  - cycling_prefs.title (Text)
  - cycling_prefs.ftp_field (TextFormField via ftpFieldKey param on _FTPSection)
  - cycling_prefs.bottles_control (KylePlusMinusControl outer widget)
  - cycling_prefs.aero_bottles_toggle / bento_box_toggle (FigmaToggleCard)
  - cycling_prefs.save_button (via continueButtonKey on FigmaOnboardingFooter)
- `lib/features/onboarding/presentation/screens/swimming_details_screen.dart`
  - swimming_prefs.back_button (GestureDetector, settings mode only)
  - swimming_prefs.title (Text)
  - swimming_prefs.css_minutes_field / css_seconds_field (TextFormField via minutesFieldKey/secondsFieldKey params on _CSSSection)
  - swimming_prefs.wetsuit_toggle (FigmaToggleCard)
  - swimming_prefs.cap_none_button / cap_latex_button / cap_silicone_button / cap_neoprene_button (via FigmaRadioOptionItem.valueKey)
  - swimming_prefs.save_button (via continueButtonKey on FigmaOnboardingFooter)

### Area 13 (brick)
- `lib/features/nutrition_plan/presentation/widgets/new_activity/brick/brick_sport_toggle_selector.dart`
  - Added super.key to _SportToggleButton
  - brick.discipline_swim_chip / brick.discipline_bike_chip / brick.discipline_run_chip (keyed call sites)
- `lib/features/nutrition_plan/presentation/widgets/new_activity/brick/brick_tab_content.dart`
  - brick.workout_name_field (ActivityNameField)
  - brick.fueling_window_control (KylePlusMinusControl outer widget)
  - brick.fasted_toggle (FastedToggle)
  - brick.segment_card_$index (updated from ValueKey(sport) to ValueKey('brick.segment_card_$index'))
  - brick.segment_expand_${order-1} (GestureDetector header in _ExpandableSegmentCard)
  - brick.segment_reorder_${order-1} (ReorderableDragStartListener)
  - brick.total_duration_label (Text)
Notes:
  - brick.back_button / brick.title already exist as activity_create.back_button / activity_create.title (from area 06 new_activity_app_bar.dart)
  - brick.generate_plan_button already exists as activity_create.generate_plan_button (new_activity_screen.dart)
  - brick.datetime_labels / brick.datetime_display / brick.edit_datetime_button already exist as activity_create.* (new_activity_date_time_section.dart)
  - brick.fueling_window_heading / brick.fueling_window_minus / brick.fueling_window_plus / brick.fueling_window_value are internal to KylePlusMinusControl; outer widget keyed as brick.fueling_window_control instead

### Area 14 (other/help)
- `lib/features/education/presentation/screens/education_screen.dart`
  - learn.title (Text)
  - learn.mealvana_101_section / learn.pro_videos_section / learn.courses_section (_SectionHeader, added super.key)
  - learn.mealvana_101_subtitle (Text)
  - learn.lesson_card_$index (_CompactVideoCard, added super.key)
  - learn.pro_videos_card / learn.courses_card (ComingSoonSectionWidget)
  - learn.pro_videos_notify_button / learn.courses_notify_button (via notifyButtonKey param on ComingSoonSectionWidget)
- `lib/features/education/presentation/widgets/coming_soon_section_widget.dart`
  - Added notifyButtonKey param; KylePrimaryButton keyed with notifyButtonKey
- `lib/features/education/presentation/screens/video_player_screen.dart`
  - lesson.back_button (CustomAppBarBackButton in AppBar.leading)
  - lesson.title (Text in AppBar.title)
  - lesson.video_player (Chewie widget)
- `lib/features/settings/presentation/screens/help_feedback_screen.dart`
  - help.back_button (CustomAppBarBackButton in AppBar.leading)
  - help.title (Text in AppBar.title)
  - help.feedback_section / help.contact_section (Text headings)
  - help.rate_row (InkWell via rowKey param on _buildFeedbackOption)
  - help.report_bug_row (InkWell via rowKey param on _buildBugReportOption)
  - help.email_row / help.website_row (InkWell via rowKey param on _buildContactOption)
Notes:
  - learn.settings_button not found — no settings gear in education_screen.dart; may be in parent scaffold
  - rate_experience (Wiredash NPS) and report_bug (Wiredash) overlays are third-party; feedback.* / bug_report.* keys cannot be applied to Flutter widgets
  - lesson.fullscreen_button / lesson.mute_button / lesson.play_button / lesson.progress_bar / lesson.elapsed_label / lesson.remaining_label are internal to Chewie (third-party); not keyable from Flutter side
- analyze: 2046 issues (no regressions)
