/// Content key constants that map to the content_defaults.json structure
/// These provide type-safe access to all content strings
class ContentKeys {
  // Pro Version (subscription paywall) — lib/features/subscription
  static const String proVersionTitle = 'pro_version.title';
  static const String proVersionSubtitle = 'pro_version.subtitle';
  static const String proVersionActiveBadge = 'pro_version.active_badge';
  static const String proVersionTrialBadge = 'pro_version.trial_badge';
  static const String proVersionActiveUntil = 'pro_version.active_until';
  static const String proVersionFeaturesTitle = 'pro_version.features_title';
  static const String proVersionFeature1Title = 'pro_version.feature_1_title';
  static const String proVersionFeature1Description =
      'pro_version.feature_1_description';
  static const String proVersionFeature2Title = 'pro_version.feature_2_title';
  static const String proVersionFeature2Description =
      'pro_version.feature_2_description';
  static const String proVersionFeature3Title = 'pro_version.feature_3_title';
  static const String proVersionFeature3Description =
      'pro_version.feature_3_description';
  static const String proVersionPricingTitle = 'pro_version.pricing_title';
  static const String proVersionPricingUnavailable =
      'pro_version.pricing_unavailable';
  static const String proVersionMonthlyLabel = 'pro_version.monthly_label';
  static const String proVersionAnnualLabel = 'pro_version.annual_label';
  static const String proVersionPerMonth = 'pro_version.per_month';
  static const String proVersionPerYear = 'pro_version.per_year';
  static const String proVersionSubscribeButton =
      'pro_version.subscribe_button';
  static const String proVersionPurchaseComingSoon =
      'pro_version.purchase_coming_soon';
  static const String proVersionRestoreButton = 'pro_version.restore_button';
  static const String proVersionRestoreSuccess = 'pro_version.restore_success';
  static const String proVersionRestoreNone = 'pro_version.restore_none';
  static const String proVersionPurchaseSuccess =
      'pro_version.purchase_success';
  static const String proVersionPurchasePending =
      'pro_version.purchase_pending';
  static const String proVersionPurchaseFailed = 'pro_version.purchase_failed';
  static const String proVersionSignInRequired =
      'pro_version.sign_in_required';
  static const String proVersionManageNote = 'pro_version.manage_note';

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
  static const String settingsSignOutButton = 'settings.sign_out_button';
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

  // Meal planning (Vana) — lib/features/meal_planning. Values with `{x}`
  // placeholders are interpolated at the call site with `ContentKeys.format`.
  static const String mpFoodTitle = 'meal_planning.food_title';
  static const String mpTabPlan = 'meal_planning.tab_plan';
  static const String mpTabMeals = 'meal_planning.tab_meals';
  static const String mpTabShopping = 'meal_planning.tab_shopping';
  static const String mpNeedsConnection = 'meal_planning.needs_connection';
  static const String mpVanaOffline = 'meal_planning.vana_offline';
  static const String mpProRequired = 'meal_planning.pro_required';
  static const String mpRateLimited = 'meal_planning.rate_limited';
  static const String mpServerError = 'meal_planning.server_error';
  static const String mpConfirmedToast = 'meal_planning.confirmed_toast';
  static const String mpShoppingShareTitle = 'meal_planning.shopping_share_title';
  static const String mpPlanSectionTitle = 'meal_planning.plan_section_title';
  static const String mpCoverageLine = 'meal_planning.coverage_line';
  static const String mpEmptyPlanTitle = 'meal_planning.empty_plan_title';
  static const String mpEmptyPlanBody = 'meal_planning.empty_plan_body';
  static const String mpBtnAddMeal = 'meal_planning.btn_add_meal';
  static const String mpBtnNewPlan = 'meal_planning.btn_new_plan';
  static const String mpBtnConfirm = 'meal_planning.btn_confirm';
  static const String mpBtnSwap = 'meal_planning.btn_swap';
  static const String mpBtnSwapIn = 'meal_planning.btn_swap_in';
  static const String mpBtnRemove = 'meal_planning.btn_remove';
  static const String mpTodayTargetLine = 'meal_planning.today_target_line';
  static const String mpRemoveUndone = 'meal_planning.remove_undone';
  static const String mpUndo = 'meal_planning.undo';
  static const String mpMealsSearchHint = 'meal_planning.meals_search_hint';
  static const String mpRailRecents = 'meal_planning.rail_recents';
  static const String mpRailMyFoods = 'meal_planning.rail_my_foods';
  static const String mpRailAssemblies = 'meal_planning.rail_assemblies';
  static const String mpRailRecipes = 'meal_planning.rail_recipes';
  static const String mpSeeAll = 'meal_planning.see_all';
  static const String mpRecentsEmpty = 'meal_planning.recents_empty';
  static const String mpRetry = 'meal_planning.retry';
  static const String mpFilterTitle = 'meal_planning.filter_title';
  static const String mpFilterAnyType = 'meal_planning.filter_any_type';
  static const String mpFilterAssemblies = 'meal_planning.filter_assemblies';
  static const String mpFilterRecipes = 'meal_planning.filter_recipes';
  static const String mpFilterClear = 'meal_planning.filter_clear';
  static const String mpSearchEmpty = 'meal_planning.search_empty';
  static const String mpFilterNoRecipe = 'meal_planning.filter_no_recipe';
  static const String mpFilterProtein = 'meal_planning.filter_protein';
  static const String mpFilterUnder20 = 'meal_planning.filter_under_20';
  static const String mpVanaCta = 'meal_planning.vana_cta';
  static const String mpChipLikeThese = 'meal_planning.chip_like_these';
  static const String mpChipNextLabel = 'meal_planning.chip_next';
  static const String mpChipThatsMyWeek = 'meal_planning.chip_thats_my_week';
  static const String mpChipOther = 'meal_planning.chip_other';
  static const String mpChipSomethingElse = 'meal_planning.chip_something_else';
  static const String mpPickerPlaceholderPlanning =
      'meal_planning.picker_placeholder_planning';
  static const String mpPickerPlaceholderGeneral =
      'meal_planning.picker_placeholder_general';
  static const String mpOpenerLoading = 'meal_planning.opener_loading';
  static const String mpStatusThinking = 'meal_planning.status_thinking';
  static const String mpPlanBarReview = 'meal_planning.plan_bar_review';
  static const String mpPlanBarMeals = 'meal_planning.plan_bar_meals';
  static const String mpReviewTitle = 'meal_planning.review_title';
  static const String mpReviewConfirm = 'meal_planning.review_confirm';
  static const String mpReviewConfirmed = 'meal_planning.review_confirmed';
  static const String mpReviewShoppingLink = 'meal_planning.review_shopping_link';
  static const String mpServingsLabel = 'meal_planning.servings_label';
  static const String mpSessionCookSun = 'meal_planning.session_cook_sun';
  static const String mpSessionTopupWed = 'meal_planning.session_topup_wed';
  static const String mpSessionFreshFri = 'meal_planning.session_fresh_fri';
  static const String mpSessionNone = 'meal_planning.session_none';
  static const String mpDetailIngredients = 'meal_planning.detail_ingredients';
  static const String mpDetailOneServing = 'meal_planning.detail_one_serving';
  static const String mpDetailMakes = 'meal_planning.detail_makes';
  static const String mpDetailHowToCook = 'meal_planning.detail_how_to_cook';
  static const String mpDetailStartCooking = 'meal_planning.detail_start_cooking';
  static const String mpDetailSeeOriginal = 'meal_planning.detail_see_original';
  static const String mpDetailYourDirections =
      'meal_planning.detail_your_directions';
  static const String mpDetailYourDirectionsHint =
      'meal_planning.detail_your_directions_hint';
  static const String mpDetailDirectionsSaved =
      'meal_planning.detail_directions_saved';
  static const String mpDetailSaveToMine = 'meal_planning.detail_save_to_mine';
  static const String mpDetailSavedToast = 'meal_planning.detail_saved_toast';
  static const String mpDetailThumbsDownNote =
      'meal_planning.detail_thumbs_down_note';
  static const String mpDetailMacrosNote = 'meal_planning.detail_macros_note';
  static const String mpDetailSwapsTitle = 'meal_planning.detail_swaps_title';
  static const String mpBadgeAiGenerated = 'meal_planning.badge_ai_generated';
  static const String mpBadgeAssemblySimple =
      'meal_planning.badge_assembly_simple';
  static const String mpBadgeAltSource = 'meal_planning.badge_alt_source';
  static const String mpBadgeVerbatim = 'meal_planning.badge_verbatim';
  static const String mpCookStart = 'meal_planning.cook_start';
  static const String mpCookStepOf = 'meal_planning.cook_step_of';
  static const String mpCookStartStep = 'meal_planning.cook_start_step';
  static const String mpCookNext = 'meal_planning.cook_next';
  static const String mpCookBack = 'meal_planning.cook_back';
  static const String mpCookDone = 'meal_planning.cook_done';
  static const String mpCookStartOver = 'meal_planning.cook_start_over';
  static const String mpCookAiDisclaimer = 'meal_planning.cook_ai_disclaimer';
  static const String mpCookIngredients = 'meal_planning.cook_ingredients';
  static const String mpCookNoStepsTitle = 'meal_planning.cook_no_steps_title';
  static const String mpCookNoStepsBody = 'meal_planning.cook_no_steps_body';
  static const String mpCookTimerStart = 'meal_planning.cook_timer_start';
  static const String mpCookTimerNotification =
      'meal_planning.cook_timer_notification';
  static const String mpCookTimerPause = 'meal_planning.cook_timer_pause';
  static const String mpCookTimerReset = 'meal_planning.cook_timer_reset';
  static const String mpCookDoneThanks = 'meal_planning.cook_done_thanks';
  static const String mpShoppingItemCount = 'meal_planning.shopping_item_count';
  static const String mpShoppingTotals = 'meal_planning.shopping_totals';
  static const String mpShoppingAddBack = 'meal_planning.shopping_add_back';
  static const String mpShoppingShare = 'meal_planning.shopping_share';
  static const String mpShoppingHave = 'meal_planning.shopping_have';
  static const String mpShoppingEmptyTitle = 'meal_planning.shopping_empty_title';
  static const String mpShoppingEmptyBody = 'meal_planning.shopping_empty_body';
  static const String mpSettingsVanaTitle = 'meal_planning.settings_vana_title';
  static const String mpSettingsBatch = 'meal_planning.settings_batch';
  static const String mpSettingsBatchSub = 'meal_planning.settings_batch_sub';
  static const String mpSettingsMacros = 'meal_planning.settings_macros';
  static const String mpSettingsMacrosSub = 'meal_planning.settings_macros_sub';
  static const String mpSettingsMemories = 'meal_planning.settings_memories';
  static const String mpSettingsMemoriesBody =
      'meal_planning.settings_memories_body';
  static const String mpSettingsDeleteMemory =
      'meal_planning.settings_delete_memory';
  static const String mpMemoryDeletedToast = 'meal_planning.memory_deleted_toast';
  static const String mpConvTitle = 'meal_planning.conv_title';
  static const String mpConvAsk = 'meal_planning.conv_ask';
  static const String mpConvPlans = 'meal_planning.conv_plans';
  static const String mpConvNew = 'meal_planning.conv_new';
  static const String mpConvEmpty = 'meal_planning.conv_empty';
  static const String mpSwapTitle = 'meal_planning.swap_title';
  static const String mpSwapReplacing = 'meal_planning.swap_replacing';
  static const String mpStaplesTitle = 'meal_planning.staples_title';
  static const String mpStaplesCarbLine = 'meal_planning.staples_carb_line';
  static const String mpLoggedServingsLeft =
      'meal_planning.logged_servings_left';
  static const String mpLoggedRow = 'meal_planning.logged_row';
  static const String mpMemorySavedRow = 'meal_planning.memory_saved_row';
  static const String mpLoggedDoneToast = 'meal_planning.logged_done_toast';
  static const String mpAteIt = 'meal_planning.ate_it';
  static const String mpGeneralExample1 = 'meal_planning.general_example_1';
  static const String mpGeneralExample2 = 'meal_planning.general_example_2';
  static const String mpGeneralExample3 = 'meal_planning.general_example_3';
  static const String mpMealTypeBreakfast = 'meal_planning.meal_type_breakfast';
  static const String mpMealTypeLunch = 'meal_planning.meal_type_lunch';
  static const String mpMealTypeDinner = 'meal_planning.meal_type_dinner';
  static const String mpMealTypeSnack = 'meal_planning.meal_type_snack';

  /// Interpolates `{name}` placeholders in a content value:
  /// `format('Give me {n} seconds', {'n': 30})`.
  static String format(String value, Map<String, Object?> params) {
    var result = value;
    for (final entry in params.entries) {
      result = result.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return result;
  }
}
