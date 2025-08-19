/// Content key constants that map to the content_defaults.json structure
/// These provide type-safe access to all content strings
class ContentKeys {
  // Main Screen
  static const String mainScreenTitle = 'main_screen.title';
  static const String mainScreenDistanceLabel = 'main_screen.distance_label';
  static const String mainScreenPaceLabel = 'main_screen.pace_label';
  static const String mainScreenPreRunLabel = 'main_screen.pre_run_label';
  static const String mainScreenGutTrainingLabel = 'main_screen.gut_training_label';
  static const String mainScreenGenerateButton = 'main_screen.generate_button';
  static const String mainScreenTipsText = 'main_screen.tips_text';

  // Plan Screen
  static const String planScreenTitle = 'plan_screen.title';
  static const String planScreenBeforeRun = 'plan_screen.before_run';
  static const String planScreenDuringRun = 'plan_screen.during_run';
  static const String planScreenAfterRun = 'plan_screen.after_run';
  static const String planScreenSaveButton = 'plan_screen.save_button';
  static const String planScreenSavedButton = 'plan_screen.saved_button';
  static const String planScreenMacroTargets = 'plan_screen.macro_targets';
  static const String planScreenFeedbackSuccess = 'plan_screen.feedback_success_message';
  static const String planScreenFeedbackFailure = 'plan_screen.feedback_failure_message';
  static const String planScreenNoPlan = 'plan_screen.no_plan_message';
  static const String planScreenNoPlanDescription = 'plan_screen.no_plan_description';
  static const String planScreenGeneratePlanButton = 'plan_screen.generate_plan_button';
  static const String planScreenError = 'plan_screen.error_message';
  static const String planScreenTryAgainButton = 'plan_screen.try_again_button';

  // Welcome Screen
  static const String welcomeScreenTitle = 'welcome_screen.title';
  static const String welcomeScreenSubtitle = 'welcome_screen.subtitle';
  static const String welcomeScreenFeature1Title = 'welcome_screen.feature_1_title';
  static const String welcomeScreenFeature1Description = 'welcome_screen.feature_1_description';
  static const String welcomeScreenFeature2Title = 'welcome_screen.feature_2_title';
  static const String welcomeScreenFeature2Description = 'welcome_screen.feature_2_description';
  static const String welcomeScreenFeature3Title = 'welcome_screen.feature_3_title';
  static const String welcomeScreenFeature3Description = 'welcome_screen.feature_3_description';
  static const String welcomeScreenGetStartedButton = 'welcome_screen.get_started_button';
  static const String welcomeScreenSkipButton = 'welcome_screen.skip_button';

  // User Profile Screen
  static const String userProfileTitle = 'user_profile.title';
  static const String userProfileSubtitle = 'user_profile.subtitle';
  static const String userProfileDescription = 'user_profile.description';
  static const String userProfileGenderLabel = 'user_profile.gender_label';
  static const String userProfileBirthdayLabel = 'user_profile.birthday_label';
  static const String userProfileBirthdayHint = 'user_profile.birthday_hint';
  static const String userProfileHeightLabel = 'user_profile.height_label';
  static const String userProfileWeightLabel = 'user_profile.weight_label';
  static const String userProfileRunningHabitsLabel = 'user_profile.running_habits_label';
  static const String userProfileWaterBottleLabel = 'user_profile.water_bottle_label';
  static const String userProfileWaterBottleSubtitle = 'user_profile.water_bottle_subtitle';
  static const String userProfileContinueButton = 'user_profile.continue_button';

  // Food Preferences Screen
  static const String foodPreferencesTitle = 'food_preferences.title';

  // Settings Screen
  static const String settingsTitle = 'settings.title';
  static const String settingsProfileSection = 'settings.profile_section';
  static const String settingsPreferencesSection = 'settings.preferences_section';
  static const String settingsGenderLabel = 'settings.gender_label';
  static const String settingsBirthdayLabel = 'settings.birthday_label';
  static const String settingsHeightLabel = 'settings.height_label';
  static const String settingsWeightLabel = 'settings.weight_label';
  static const String settingsWaterBottleLabel = 'settings.water_bottle_label';
  static const String settingsDistanceUnitLabel = 'settings.distance_unit_label';
  static const String settingsPaceUnitLabel = 'settings.pace_unit_label';
  static const String settingsGutTrainingLabel = 'settings.gut_training_label';
  static const String settingsSaveButton = 'settings.save_button';

  // Gender Labels
  static const String genderMale = 'gender.male';
  static const String genderFemale = 'gender.female';
  static const String genderOther = 'gender.other';

  // Units
  static const String unitsMiles = 'units.miles';
  static const String unitsKilometers = 'units.kilometers';
  static const String unitsMinPerMile = 'units.min_per_mile';
  static const String unitsMinPerKm = 'units.min_per_km';
  static const String unitsFeet = 'units.feet';
  static const String unitsInches = 'units.inches';
  static const String unitsPounds = 'units.pounds';

  // Gut Training
  static const String gutTrainingLow = 'gut_training.low';
  static const String gutTrainingModerate = 'gut_training.moderate';
  static const String gutTrainingHigh = 'gut_training.high';
  static const String gutTrainingLowDescription = 'gut_training.low_description';
  static const String gutTrainingModerateDescription = 'gut_training.moderate_description';
  static const String gutTrainingHighDescription = 'gut_training.high_description';

  // Pre-run Timing
  static const String preRunTiming1Hour = 'pre_run_timing.1_hour';
  static const String preRunTiming2Hours = 'pre_run_timing.2_hours';
  static const String preRunTiming3Hours = 'pre_run_timing.3_hours';

  // Feedback
  static const String feedbackTypeSuggestions = 'feedback.type_suggestions';

  // Validation Messages
  static const String validationRequired = 'validation.required';
  static const String validationInvalidNumber = 'validation.invalid_number';
  static const String validationDistanceRange = 'validation.distance_range';
  static const String validationPaceFormat = 'validation.pace_format';
  static const String validationHeightFeet = 'validation.height_feet';
  static const String validationHeightInches = 'validation.height_inches';
  static const String validationWeightRange = 'validation.weight_range';
  static const String validationFillAllFields = 'validation.fill_all_fields';

  // Error Messages
  static const String errorNetwork = 'error.network';
  static const String errorGeneric = 'error.generic';
  static const String errorPlanGeneration = 'error.plan_generation';
  static const String errorFeedbackSubmission = 'error.feedback_submission';

  // Success Messages
  static const String successFeedbackSubmitted = 'success.feedback_submitted';
  static const String successProfileSaved = 'success.profile_saved';
}