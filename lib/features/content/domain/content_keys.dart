/// Content key constants that map to the content_defaults.json structure
/// These provide type-safe access to all content strings
class ContentKeys {
  // Log In errors, one line under the form that stays until the next edit
  // (testing-wave 125-002, 125-007).
  static const String loginErrorWrongCredentials =
      'auth.login.error_wrong_credentials';
  static const String loginErrorNoConnection = 'auth.login.error_no_connection';
  static const String loginErrorFailed = 'auth.login.error_failed';
  // Verify your email (121-001, 121-002, 124-002): the Resend countdown, an
  // old code after a Resend, and the hint that the address may be an account.
  static const String verifyEmailResendIn = 'auth.verify_email.resend_in';
  static const String verifyEmailResend = 'auth.verify_email.resend';
  static const String verifyEmailResent = 'auth.verify_email.resent';
  static const String verifyEmailCodeSuperseded =
      'auth.verify_email.code_superseded';
  static const String verifyEmailMaybeAccountHint =
      'auth.verify_email.maybe_account_hint';
  static const String verifyEmailLogIn = 'auth.verify_email.log_in';
  // Verify your email's lines for a refused code and a failed Resend
  // (develop-2026-10 ticket 21, 01-002 and 01-003): one per reason.
  static const String verifyEmailErrorWrongCode =
      'auth.verify_email.error_wrong_code';
  static const String verifyEmailErrorExpired =
      'auth.verify_email.error_expired';
  static const String verifyEmailErrorMalformed =
      'auth.verify_email.error_malformed';
  static const String verifyEmailErrorTooManyTries =
      'auth.verify_email.error_too_many_tries';
  static const String verifyEmailErrorGeneric =
      'auth.verify_email.error_generic';
  static const String verifyEmailErrorResendFailed =
      'auth.verify_email.error_resend_failed';
  // Enter Reset Code (124-004): the same countdown on the reset screen.
  static const String verifyCodeResendIn = 'auth.verify_code.resend_in';
  static const String verifyCodeResent = 'auth.verify_code.resent';
  static const String verifyCodeResendFailed = 'auth.verify_code.resend_failed';
  // The password eye's spoken name on Log In and Create Account (118-005,
  // 119-005): one pair for every password field.
  static const String authShowPassword = 'auth.show_password';
  static const String authHidePassword = 'auth.hide_password';
  // The food search bar's icon buttons, named for a screen reader (28-006).
  static const String foodSearchScanBarcode = 'food_search.scan_barcode';
  static const String foodSearchSearch = 'food_search.search';
  // A logged food with no serving description: "1 serving" / "1.5 servings"
  // (112-002). The word is written into the logged row's portion.
  static const String mealLogServingSingular = 'meal_log.serving_singular';
  static const String mealLogServingPlural = 'meal_log.serving_plural';

  // Main Screen
  static const String mainScreenTitle = 'main_screen.title';
  static const String mainScreenDistanceLabel = 'main_screen.distance_label';
  static const String mainScreenPaceLabel = 'main_screen.pace_label';
  static const String mainScreenPreRunLabel = 'main_screen.pre_run_label';
  static const String mainScreenGutTrainingLabel =
      'main_screen.gut_training_label';
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
  static const String planScreenFeedbackSuccess =
      'plan_screen.feedback_success_message';
  static const String planScreenFeedbackFailure =
      'plan_screen.feedback_failure_message';
  static const String planScreenNoPlan = 'plan_screen.no_plan_message';
  static const String planScreenNoPlanDescription =
      'plan_screen.no_plan_description';
  static const String planScreenGeneratePlanButton =
      'plan_screen.generate_plan_button';
  static const String planScreenError = 'plan_screen.error_message';
  static const String planScreenTryAgainButton = 'plan_screen.try_again_button';

  // Welcome Screen
  static const String welcomeScreenTitle = 'welcome_screen.title';
  static const String welcomeScreenSubtitle = 'welcome_screen.subtitle';
  static const String welcomeScreenFeature1Title =
      'welcome_screen.feature_1_title';
  static const String welcomeScreenFeature1Description =
      'welcome_screen.feature_1_description';
  static const String welcomeScreenFeature2Title =
      'welcome_screen.feature_2_title';
  static const String welcomeScreenFeature2Description =
      'welcome_screen.feature_2_description';
  static const String welcomeScreenFeature3Title =
      'welcome_screen.feature_3_title';
  static const String welcomeScreenFeature3Description =
      'welcome_screen.feature_3_description';
  static const String welcomeScreenGetStartedButton =
      'welcome_screen.get_started_button';
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
  static const String userProfileRunningHabitsLabel =
      'user_profile.running_habits_label';
  static const String userProfileWaterBottleLabel =
      'user_profile.water_bottle_label';
  static const String userProfileWaterBottleSubtitle =
      'user_profile.water_bottle_subtitle';
  static const String userProfileContinueButton =
      'user_profile.continue_button';

  // Food Preferences Screen
  static const String foodPreferencesTitle = 'food_preferences.title';
  static const String foodPreferencesOptionLike =
      'food_preferences.option_like';
  static const String foodPreferencesOptionWillingToTry =
      'food_preferences.option_willing_to_try';
  static const String foodPreferencesOptionDislike =
      'food_preferences.option_dislike';
  static const String foodPreferencesCompleteButton =
      'food_preferences.complete_button';

  // Settings Screen
  static const String settingsTitle = 'settings.title';
  static const String settingsAccountSection = 'settings.account_section';
  static const String settingsAccountStatusAnonymous =
      'settings.account_status_anonymous';
  static const String settingsAccountStatusAuthenticated =
      'settings.account_status_authenticated';
  static const String settingsCreateAccountButton =
      'settings.create_account_button';
  static const String settingsLogInButton = 'settings.log_in_button';
  static const String settingsSignOutButton = 'settings.sign_out_button';
  // The account card's confirms (mp-508, ticket 47): no guest mode, so the
  // sign-out body says the athlete signs in again. On mealplanning the title,
  // buttons and delete confirm reuse the paywall's keys; develop has no
  // paywall, so they live under settings with the same text.
  static const String settingsSignOutConfirmTitle =
      'settings.sign_out_confirm_title';
  static const String settingsSignOutConfirmBody =
      'settings.sign_out_confirm_body';
  // The Profile & Preferences screen's own title (31-014): the settings
  // screen, not onboarding's "Tell us about yourself".
  static const String settingsProfilePreferencesTitle =
      'settings.profile_preferences_title';
  // The Settings tile that opens it: same title, its own subtitle.
  static const String settingsProfilePreferencesSubtitle =
      'settings.profile_preferences_subtitle';
  static const String settingsSignOutConfirmAction =
      'settings.sign_out_confirm_action';
  static const String settingsConfirmCancel = 'settings.confirm_cancel';
  static const String settingsDeleteAccountButton =
      'settings.delete_account_button';
  static const String settingsDeleteConfirmTitle =
      'settings.delete_confirm_title';
  static const String settingsDeleteConfirmBody =
      'settings.delete_confirm_body';
  static const String settingsDeleteConfirmAction =
      'settings.delete_confirm_action';
  // Sign-out with the pre-logout upload failing (ticket 102, Finding 86-007):
  // the athlete's unsynced changes stay on the phone for the next sign-in.
  static const String settingsSignOutUnsyncedKept =
      'settings.sign_out_unsynced_kept';
  // Delete account when `delete-user` gave no 200 (testing-wave 121-007):
  // nothing was deleted, the athlete stays signed in.
  static const String settingsDeleteNeedsConnection =
      'settings.delete_needs_connection';
  static const String settingsProfileSection = 'settings.profile_section';
  static const String settingsPreferencesSection =
      'settings.preferences_section';
  static const String settingsGenderLabel = 'settings.gender_label';
  static const String settingsBirthdayLabel = 'settings.birthday_label';
  static const String settingsHeightLabel = 'settings.height_label';
  static const String settingsWeightLabel = 'settings.weight_label';
  static const String settingsWaterBottleLabel = 'settings.water_bottle_label';
  static const String settingsDistanceUnitLabel =
      'settings.distance_unit_label';
  static const String settingsPaceUnitLabel = 'settings.pace_unit_label';
  static const String settingsGutTrainingLabel = 'settings.gut_training_label';
  static const String settingsSaveButton = 'settings.save_button';
  // A connection whose token refresh the provider refused for good
  // (ticket 64): the Reconnect action and the line under the card.
  static const String settingsConnectionReconnectButton =
      'settings.connection_reconnect_button';
  static const String settingsConnectionNeedsReconnect =
      'settings.connection_needs_reconnect';

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
  static const String gutTrainingLowDescription =
      'gut_training.low_description';
  static const String gutTrainingModerateDescription =
      'gut_training.moderate_description';
  static const String gutTrainingHighDescription =
      'gut_training.high_description';

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

  // Profile & Preferences (testing-wave 138: 119-002 read-only email,
  // 119-010 Discard changes? on leaving)
  static const String profileEditEmailLoginLabel =
      'profile_edit.email_login_label';
  // Ticket 36: editable contact email when auth has no readable address.
  static const String profileEditContactEmailLabel =
      'profile_edit.contact_email_label';
  static const String profileEditContactEmailHint =
      'profile_edit.contact_email_hint';
  static const String profileEditDiscardTitle = 'profile_edit.discard_title';
  static const String profileEditDiscardBody = 'profile_edit.discard_body';
  static const String profileEditDiscard = 'profile_edit.discard';
  static const String profileEditKeepEditing = 'profile_edit.keep_editing';

  // Connected apps (testing-wave 138: 118-007 Reconnect notice, 119-008
  // the Garmin note names Sync Now)
  static const String connectionsGarminSyncNote =
      'connections.garmin_sync_note';
  static const String connectionsReconnectNotice =
      'connections.reconnect_notice';
  static const String connectionsReconnectNoticeAction =
      'connections.reconnect_notice_action';

  // Barcode scanner (testing-wave 28-004: the no-camera path)
  static const String barcodeScannerNoCamera = 'barcode_scanner.no_camera';
  static const String barcodeScannerPermissionDenied =
      'barcode_scanner.permission_denied';
  static const String barcodeScannerCameraFailed =
      'barcode_scanner.camera_failed';
  static const String barcodeScannerSearchInstead =
      'barcode_scanner.search_instead';
  static const String barcodeScannerEnterLabel = 'barcode_scanner.enter_label';
  static const String barcodeScannerEnterTitle = 'barcode_scanner.enter_title';
  static const String barcodeScannerEnterBody = 'barcode_scanner.enter_body';
  static const String barcodeScannerEnterHint = 'barcode_scanner.enter_hint';
  static const String barcodeScannerEnterSubmit =
      'barcode_scanner.enter_submit';

  // Barcode entry sheet (testing-wave 136: 113-006 typed length and words)
  static const String barcodeScannerEnterLength =
      'barcode_scanner.enter_length';
  static const String barcodeScannerTypedInvalid =
      'barcode_scanner.typed_invalid';
  static const String barcodeScannerFlash = 'barcode_scanner.flash';

  // Logged and saved meal actions (testing-wave 136: 112-005, 112-008)
  static const String mealLogActionsSavedMealRemoved =
      'meal_log_actions.saved_meal_removed';
  static const String mealLogActionsUndo = 'meal_log_actions.undo';
  static const String mealLogActionsSaveAsFavorite =
      'meal_log_actions.save_as_favorite';
  static const String mealLogActionsSavedAsFavorite =
      'meal_log_actions.saved_as_favorite';
  static const String mealLogActionsSaveAsFavoriteFailed =
      'meal_log_actions.save_as_favorite_failed';

  // Build a Meal leave guard (testing-wave 136: 113-007)
  static const String buildMealDiscardTitle = 'build_meal.discard_title';
  static const String buildMealDiscardBody = 'build_meal.discard_body';
  static const String buildMealDiscard = 'build_meal.discard';
  static const String buildMealKeepBuilding = 'build_meal.keep_building';

  // Learn (testing-wave 141: 117-006 Notify Me answers, 117-008 offline)
  static const String learnNotifyMe = 'learn.notify_me';
  static const String learnNotifyMeNoted = 'learn.notify_me_noted';
  static const String learnNotifyMeConfirm = 'learn.notify_me_confirm';
  static const String learnOfflineMessage = 'learn.offline_message';
  static const String learnRetry = 'learn.retry';

  // Out of AI credits dialog (testing-wave develop-2026-10 ticket 23: 02-001)
  static const String aiCreditsOutTitle = 'ai_credits.out_title';
  static const String aiCreditsOutBody = 'ai_credits.out_body';
  static const String aiCreditsOutNotNow = 'ai_credits.out_not_now';
  static const String aiCreditsOutGetCredits = 'ai_credits.out_get_credits';

  /// Interpolates `{name}` placeholders in a content value:
  /// `format('Give me {n} seconds', {'n': 30})`. (From mealplanning 7b206f04;
  /// the code screens' countdown reads it.)
  static String format(String value, Map<String, Object?> params) {
    var result = value;
    for (final entry in params.entries) {
      result = result.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return result;
  }
}
