import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'logging_service.dart';

/// Analytics service implementing Mealvana Endurance tracking plan
/// Based on mixpanel_tracking_plan.csv - tracks ONLY approved events
class AnalyticsService {
  static Mixpanel? _mixpanel;
  static bool _isInitialized = false;
  static LoggingService get _logger => AppLogger.instance;
  
  /// Initialize Mixpanel with project token from environment
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Get project token from environment - fallback for development
      const projectToken = String.fromEnvironment(
        'MIXPANEL_PROJECT_TOKEN',
        defaultValue: 'bd8fe50bb67b1dd0860351e6297347db' // TODO: Move to .env
      );
      
      _mixpanel = await Mixpanel.init(
        projectToken,
        trackAutomaticEvents: false, // Manual tracking per tracking plan
      );
      
      // Set up super properties (properties attached to every event)
      await _setupSuperProperties();
      
      _isInitialized = true;
      _logger.info('Analytics service initialized', context: 'ANALYTICS');
    } catch (e) {
      _logger.error('Failed to initialize Mixpanel',
        context: 'ANALYTICS',
        error: e
      );
    }
  }
  
  /// Set up super properties that will be attached to every event
  static Future<void> _setupSuperProperties() async {
    if (_mixpanel == null) return;
    
    try {
      final deviceInfo = DeviceInfoPlugin();
      Map<String, dynamic> superProps = {
        'app_version': '1.3.0',
        'platform': Platform.isIOS ? 'iOS' : 'Android',
      };
      
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        superProps.addAll({
          'os_version': iosInfo.systemVersion,
          'device_model': iosInfo.model,
        });
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        superProps.addAll({
          'os_version': androidInfo.version.release,
          'device_model': androidInfo.model,
        });
      }
      
      _mixpanel!.registerSuperProperties(superProps);
    } catch (e) {
      _logger.error('Failed to set super properties',
        context: 'ANALYTICS',
        error: e
      );
    }
  }
  
  /// Identify a user (call when user completes onboarding or logs in)
  /// Can be called with just device ID for anonymous users
  static Future<void> identifyUser(String userId, {
    Map<String, dynamic>? properties,
    String? gender,
    int? age,
    double? weightPounds,
    bool? runsWithWaterBottle,
    String? gutTrainingLevel,
  }) async {
    if (_mixpanel == null) return;
    
    try {
      // Identify the user with their ID (could be device ID or user ID)
      _mixpanel!.identify(userId);
      
      // Set user profile properties if provided
      final people = _mixpanel!.getPeople();
      
      // Use properties map if provided, otherwise use individual params
      if (properties != null && properties.isNotEmpty) {
        // Set all properties from map
        properties.forEach((key, value) {
          if (value != null) {
            people.set(key, value);
          }
        });
        
        // Set first seen date if not already set
        people.setOnce('First Seen', DateTime.now().toIso8601String());
        
        // Track identification event
        track('user_identified', properties: properties);
      } else if (gender != null || age != null || weightPounds != null) {
        // Backward compatibility - use individual parameters
        if (gender != null) people.set('Gender', gender);
        if (age != null) people.set('Age', age);
        if (weightPounds != null) people.set('Weight (lbs)', weightPounds);
        if (runsWithWaterBottle != null) people.set('Runs With Water Bottle', runsWithWaterBottle);
        if (gutTrainingLevel != null) people.set('Gut Training Level', gutTrainingLevel);
        people.setOnce('First Seen', DateTime.now().toIso8601String());
        
        track('user_identified', properties: {
          'gender': gender,
          'age': age,
          'weight_lbs': weightPounds,
          'runs_with_water_bottle': runsWithWaterBottle,
          'gut_training_level': gutTrainingLevel,
        });
      } else {
        // Just identifying with ID, no properties (anonymous user)
        people.setOnce('First Seen', DateTime.now().toIso8601String());
        people.set('User Type', 'Anonymous');
        
        track('anonymous_user_identified', properties: {
          'device_id': userId,
        });
      }
    } catch (e) {
      _logger.error('Failed to identify user', context: 'ANALYTICS', error: e);
    }
  }
  
  /// Reset user identity (call on logout or data reset)
  static Future<void> resetUser() async {
    if (_mixpanel == null) return;
    
    try {
      track('user_reset');
      _mixpanel!.reset();
    } catch (e) {
      _logger.error('Failed to reset user', context: 'ANALYTICS', error: e);
    }
  }
  
  /// Track a custom event with optional properties
  static Future<void> track(String eventName, {Map<String, dynamic>? properties}) async {
    if (_mixpanel == null) return;
    
    try {
      _mixpanel!.track(eventName, properties: properties);
    } catch (e) {
      _logger.error('Failed to track event $eventName', context: 'ANALYTICS', error: e);
    }
  }
  
  /// Time an event (useful for measuring how long operations take)
  static Future<void> timeEvent(String eventName) async {
    if (_mixpanel == null) return;
    
    try {
      _mixpanel!.timeEvent(eventName);
    } catch (e) {
      _logger.error('Failed to time event $eventName', context: 'ANALYTICS', error: e);
    }
  }
  
  /// Flush events to Mixpanel servers immediately
  static Future<void> flush() async {
    if (_mixpanel == null) return;
    
    try {
      _mixpanel!.flush();
    } catch (e) {
      _logger.error('Failed to flush events', context: 'ANALYTICS', error: e);
    }
  }
  
  // MARK: - App Lifecycle Events - DEPRECATED
  // These events are not part of the North-Star metric
  
  /// Track app launch - DEPRECATED
  @Deprecated('Not required for North-Star metric')
  static Future<void> trackAppLaunched() async {
    // Removed - not part of North-Star metric
  }
  
  /// Track app backgrounded - DEPRECATED  
  @Deprecated('Not required for North-Star metric')
  static Future<void> trackAppBackgrounded() async {
    // Removed - not part of North-Star metric
  }
  
  // MARK: - Onboarding Events - PARTIALLY DEPRECATED
  
  
  /// Track onboarding step completed - DEPRECATED
  @Deprecated('Not required for North-Star metric')
  static Future<void> trackOnboardingStepCompleted(String step) async {
    // Removed - not part of North-Star metric
  }
  
  /// Track onboarding completed
  static Future<void> trackOnboardingCompleted({
    required Duration timeTaken,
    required String gender,
    required int age,
    required double weightPounds,
    required bool runsWithWaterBottle,
    required String gutTrainingLevel,
    required int foodPreferencesSelected,
  }) async {
    await track('Onboarding Completed', properties: {
      'Time Taken (seconds)': timeTaken.inSeconds,
      'Gender': gender,
      'Age': age,
      'Weight (lbs)': weightPounds,
      'Runs With Water Bottle': runsWithWaterBottle,
      'Gut Training Level': gutTrainingLevel,
      'Food Preferences Selected': foodPreferencesSelected,
    });
  }
  
  /// Track onboarding abandoned
  static Future<void> trackOnboardingAbandoned(String lastStep) async {
    await track('Onboarding Abandoned', properties: {
      'Last Step': lastStep,
    });
  }
  
  // MARK: - Nutrition Plan Events
  
  /// Track nutrition plan generation started - DEPRECATED
  /// Use plan_flow_started instead for North-Star metric
  @Deprecated('Use plan_flow_started instead')
  static Future<void> trackNutritionPlanGenerationStarted({
    required double distanceMiles,
    required double paceMinutesPerMile,
    required double timeBeforeRunHours,
    String? gutTrainingLevel,
  }) async {
    await timeEvent('plan_generated');
    await track('plan_generation_started', properties: {
      'distance_mi': distanceMiles,
      'pace_min_per_mile': paceMinutesPerMile,
      'time_before_run_hours': timeBeforeRunHours,
      'gut_training_level': gutTrainingLevel,
    });
  }
  
  /// Track nutrition plan generated successfully - DEPRECATED
  /// Use plan_saved instead for North-Star metric
  @Deprecated('Use plan_saved instead')
  static Future<void> trackNutritionPlanGenerated({
    required double distanceMiles,
    required double paceMinutesPerMile,
    required int totalCalories,
    required int totalCarbs,
    required int beforeRunItems,
    required int duringRunItems,
    required int afterRunItems,
    bool isFirstPlan = false,
  }) async {
    await track('plan_generated', properties: {
      'distance_mi': distanceMiles,
      'pace_min_per_mile': paceMinutesPerMile,
      'total_calories': totalCalories,
      'carbs_total_g': totalCarbs,
      'items_pre_count': beforeRunItems,
      'items_during_count': duringRunItems,
      'items_post_count': afterRunItems,
      'is_first_plan': isFirstPlan,
    });
  }
  
  /// Track nutrition plan generation failed - DEPRECATED
  /// Use error_shown instead
  @Deprecated('Use error_shown instead')
  static Future<void> trackNutritionPlanGenerationFailed({
    required String errorMessage,
    required double distanceMiles,
    required double paceMinutesPerMile,
  }) async {
    await track('plan_generation_failed', properties: {
      'error_message': errorMessage,
      'distance_mi': distanceMiles,
      'pace_min_per_mile': paceMinutesPerMile,
    });
  }
  
  /// Track nutrition plan saved - DEPRECATED
  /// Use plan_saved instead for North-Star metric
  @Deprecated('Use plan_saved instead')
  static Future<void> trackNutritionPlanSaved({
    required String planId,
    required double distanceMiles,
    required int totalCalories,
  }) async {
    await track('plan_saved_old', properties: {
      'plan_id': planId,
      'distance_mi': distanceMiles,
      'total_calories': totalCalories,
    });
  }
  
  /// Track nutrition plan viewed
  static Future<void> trackNutritionPlanViewed({
    required String planId,
    required double distanceMiles,
    required int totalCalories,
  }) async {
    await track('Nutrition Plan Viewed', properties: {
      'Plan ID': planId,
      'Distance (miles)': distanceMiles,
      'Total Calories': totalCalories,
    });
  }
  
  /// Track nutrition plan shared
  static Future<void> trackNutritionPlanShared({
    required String planId,
    required String shareMethod,
  }) async {
    await track('Nutrition Plan Shared', properties: {
      'Plan ID': planId,
      'Share Method': shareMethod,
    });
  }
  
  // MARK: - User Engagement Events - DEPRECATED
  // These events are not part of the North-Star metric
  
  /// Track screen viewed - DEPRECATED
  @Deprecated('Not required for North-Star metric - use specific events instead')
  static Future<void> trackScreenViewed(String screenName) async {
    // Removed - not part of North-Star metric
  }
  
  /// Track food preference changed - DEPRECATED
  @Deprecated('Not required for North-Star metric')
  static Future<void> trackFoodPreferenceChanged({
    required String foodItem,
    required String preference,
  }) async {
    // Removed - not part of North-Star metric
  }
  
  /// Track settings changed - DEPRECATED
  @Deprecated('Not required for North-Star metric')
  static Future<void> trackSettingsChanged({
    required String setting,
    required String oldValue,
    required String newValue,
  }) async {
    // Removed - not part of North-Star metric
  }
  
  /// Track search performed - DEPRECATED
  @Deprecated('Not required for North-Star metric')
  static Future<void> trackSearchPerformed({
    required String query,
    required int resultsCount,
  }) async {
    // Removed - not part of North-Star metric
  }
  
  // MARK: - Feedback Events
  
  /// Track feedback submitted
  static Future<void> trackFeedbackSubmitted({
    required String type,
    required String message,
    int? rating,
  }) async {
    await track('Feedback Submitted', properties: {
      'Type': type,
      'Message Length': message.length,
      'Rating': rating,
    });
  }
  
  /// Track survey completed
  static Future<void> trackSurveyCompleted({
    required int confidenceLevel,
    required String reuseIntent,
    required bool reminderRequested,
    String? missedReason,
  }) async {
    await track('Survey Completed', properties: {
      'Confidence Level': confidenceLevel,
      'Reuse Intent': reuseIntent,
      'Reminder Requested': reminderRequested,
      'Missed Reason': missedReason,
    });
  }
  
  // MARK: - Error Events
  
  /// Track app error
  static Future<void> trackError({
    required String errorType,
    required String errorMessage,
    String? screenName,
    Map<String, dynamic>? additionalContext,
  }) async {
    final properties = {
      'Error Type': errorType,
      'Error Message': errorMessage,
      'Screen Name': screenName,
      ...?additionalContext,
    };
    
    await track('App Error', properties: properties);
  }
  
  // MARK: - Performance Events - DEPRECATED
  // These events are not part of the North-Star metric
  
  /// Track app startup time - DEPRECATED
  @Deprecated('Not required for North-Star metric')
  static Future<void> trackAppStartupTime(Duration startupTime) async {
    // Removed - not part of North-Star metric
  }
  
  /// Track Edge Function performance - DEPRECATED
  @Deprecated('Not required for North-Star metric')
  static Future<void> trackEdgeFunctionPerformance({
    required String functionName,
    required Duration responseTime,
    required bool success,
    String? errorMessage,
  }) async {
    // Removed - not part of North-Star metric
  }

  // MARK: - Tracking Plan Events (CSV-based)
  
  /// Track app opened/brought to foreground
  static Future<void> trackAppOpen({
    String? source, // cold_start, background, etc.
  }) async {
    await track('app_open', properties: {
      if (source != null) 'source': source,
    });
  }
  
  /// Track onboarding started
  static Future<void> trackOnboardingStarted({
    String? screen,
  }) async {
    await track('onboarding_started', properties: {
      if (screen != null) 'screen': screen,
    });
  }
  
  /// Track user profile saved in settings
  static Future<void> trackProfileSaved({
    String? gender,
    int? age,
    double? heightCm,
    double? weightKg,
    bool? runWithBottle,
  }) async {
    await track('profile_saved', properties: {
      if (gender != null) 'gender': gender,
      if (age != null) 'age': age,
      if (heightCm != null) 'height_cm': heightCm,
      if (weightKg != null) 'weight_kg': weightKg,
      if (runWithBottle != null) 'run_with_bottle': runWithBottle,
    });
  }
  
  /// Track food preferences saved
  static Future<void> trackPreferencesSaved({
    required int loveCount,
    required int avoidCount,
  }) async {
    await track('preferences_saved', properties: {
      'love_count': loveCount,
      'avoid_count': avoidCount,
    });
  }
  
  /// Track create plan button clicked
  static Future<void> trackCreatePlanClicked({
    required String planId,
    String? screen,
    String? experimentVariant,
    required String activityType,
    required double distanceMi,
    required double durationMin,
    required double paceSecPerMile,
    required double timeBeforeRunMin,
    required String gutTrainingLevel,
    required String sweatRateLevel,
    required double temperatureC,
    required double humidityPct,
    required bool runWithBottle,
    // Macro targets
    required double carbsPreG,
    required double carbsDuringG,
    required double carbsPostG,
    required double proteinPreG,
    required double proteinPostG,
    required double fluidsPreMl,
    required double fluidsDuringMl,
    required double fluidsPostMl,
    required double sodiumPreMg,
    required double sodiumDuringMg,
    required double sodiumPostMg,
  }) async {
    await track('create_plan_clicked', properties: {
      'plan_id': planId,
      if (screen != null) 'screen': screen,
      if (experimentVariant != null) 'experiment_variant': experimentVariant,
      'activity_type': activityType,
      'distance_mi': distanceMi,
      'duration_min': durationMin,
      'pace_sec_per_mile': paceSecPerMile,
      'time_before_run_min': timeBeforeRunMin,
      'gut_training_level': gutTrainingLevel,
      'sweat_rate_level': sweatRateLevel,
      'temperature_c': temperatureC,
      'humidity_pct': humidityPct,
      'run_with_bottle': runWithBottle,
      'carbs_pre_g': carbsPreG,
      'carbs_during_g': carbsDuringG,
      'carbs_post_g': carbsPostG,
      'protein_pre_g': proteinPreG,
      'protein_post_g': proteinPostG,
      'fluids_pre_ml': fluidsPreMl,
      'fluids_during_ml': fluidsDuringMl,
      'fluids_post_ml': fluidsPostMl,
      'sodium_pre_mg': sodiumPreMg,
      'sodium_during_mg': sodiumDuringMg,
      'sodium_post_mg': sodiumPostMg,
    });
  }
  
  /// Track plan generated successfully (updated with CSV schema)
  static Future<void> trackPlanGeneratedNew({
    required String planId,
    String? screen,
    String? experimentVariant,
    required String activityType,
    required double distanceMi,
    required double durationMin,
    required double paceSecPerMile,
    required double timeBeforeRunMin,
    required String gutTrainingLevel,
    required String sweatRateLevel,
    required double temperatureC,
    required double humidityPct,
    required bool runWithBottle,
    // Macro targets
    required double carbsPreG,
    required double carbsDuringG,
    required double carbsPostG,
    required double proteinPreG,
    required double proteinPostG,
    required double fluidsPreMl,
    required double fluidsDuringMl,
    required double fluidsPostMl,
    required double sodiumPreMg,
    required double sodiumDuringMg,
    required double sodiumPostMg,
    // Plan results
    required int itemsPreCount,
    required int itemsDuringCount,
    required int itemsPostCount,
    required double carbsTotalG,
    required double sodiumTotalMg,
    required double fluidsTotalMl,
    required double carbsCoveragePct,
    required double sodiumCoveragePct,
    required double fluidsCoveragePct,
  }) async {
    await track('plan_generated', properties: {
      'plan_id': planId,
      if (screen != null) 'screen': screen,
      if (experimentVariant != null) 'experiment_variant': experimentVariant,
      'activity_type': activityType,
      'distance_mi': distanceMi,
      'duration_min': durationMin,
      'pace_sec_per_mile': paceSecPerMile,
      'time_before_run_min': timeBeforeRunMin,
      'gut_training_level': gutTrainingLevel,
      'sweat_rate_level': sweatRateLevel,
      'temperature_c': temperatureC,
      'humidity_pct': humidityPct,
      'run_with_bottle': runWithBottle,
      'carbs_pre_g': carbsPreG,
      'carbs_during_g': carbsDuringG,
      'carbs_post_g': carbsPostG,
      'protein_pre_g': proteinPreG,
      'protein_post_g': proteinPostG,
      'fluids_pre_ml': fluidsPreMl,
      'fluids_during_ml': fluidsDuringMl,
      'fluids_post_ml': fluidsPostMl,
      'sodium_pre_mg': sodiumPreMg,
      'sodium_during_mg': sodiumDuringMg,
      'sodium_post_mg': sodiumPostMg,
      'items_pre_count': itemsPreCount,
      'items_during_count': itemsDuringCount,
      'items_post_count': itemsPostCount,
      'carbs_total_g': carbsTotalG,
      'sodium_total_mg': sodiumTotalMg,
      'fluids_total_ml': fluidsTotalMl,
      'carbs_coverage_pct': carbsCoveragePct,
      'sodium_coverage_pct': sodiumCoveragePct,
      'fluids_coverage_pct': fluidsCoveragePct,
    });
  }
  
  /// Track plan screen viewed
  static Future<void> trackPlanViewed({
    required String planId,
    String? screen,
    String? experimentVariant,
    String? section, // pre, during, post
  }) async {
    await track('plan_viewed', properties: {
      'plan_id': planId,
      if (screen != null) 'screen': screen,
      if (experimentVariant != null) 'experiment_variant': experimentVariant,
      if (section != null) 'section': section,
    });
  }

  // MARK: - North-Star Metric Events (Mixpanel Requirements)
  
  /// Track plan flow started - generates plan_id and starts the North-Star funnel
  /// This is the entry point for the successful fueling plan metric
  static Future<void> trackPlanFlowStarted({
    required String planId, // UUID v4 generated at this point
    required String screen,
    required String activityType,
    required double distanceMi,
    required double durationMin,
    required double timeBeforeRunMin,
    required String gutTrainingLevel,
    required String sweatRateLevel,
    required double temperatureC,
    required double humidityPct,
    String? experimentVariant,
  }) async {
    await track('plan_flow_started', properties: {
      'plan_id': planId,
      'screen': screen,
      'activity_type': activityType,
      'distance_mi': distanceMi,
      'duration_min': durationMin,
      'time_before_run_min': timeBeforeRunMin,
      'gut_training_level': gutTrainingLevel,
      'sweat_rate_level': sweatRateLevel,
      'temperature_c': temperatureC,
      'humidity_pct': humidityPct,
      'experiment_variant': experimentVariant,
    });
  }
  
  /// Track plan saved - second step in North-Star funnel
  static Future<void> trackPlanSaved({
    required String planId,
    required double carbsTotalG,
    required double sodiumTotalMg,
    required double fluidsTotalMl,
    required double carbsCoveragePct,
    required double sodiumCoveragePct,
    required double fluidsCoveragePct,
    required int itemsPreCount,
    required int itemsDuringCount,
    required int itemsPostCount,
    required double secondsToSave, // Time since plan_flow_started
  }) async {
    await track('plan_saved', properties: {
      'plan_id': planId,
      'carbs_total_g': carbsTotalG,
      'sodium_total_mg': sodiumTotalMg,
      'fluids_total_ml': fluidsTotalMl,
      'carbs_coverage_pct': carbsCoveragePct,
      'sodium_coverage_pct': sodiumCoveragePct,
      'fluids_coverage_pct': fluidsCoveragePct,
      'items_pre_count': itemsPreCount,
      'items_during_count': itemsDuringCount,
      'items_post_count': itemsPostCount,
      'seconds_to_save': secondsToSave,
    });
  }
  
  /// Track reminder set - optional but recommended
  static Future<void> trackReminderSet({
    required String planId,
    String? screen,
    String? experimentVariant,
    required String remindAtIso, // ISO-8601 string with timezone
  }) async {
    await track('reminder_set', properties: {
      'plan_id': planId,
      if (screen != null) 'screen': screen,
      if (experimentVariant != null) 'experiment_variant': experimentVariant,
      'remind_at_iso': remindAtIso,
    });
  }
  
  /// Track reminder fired - third step in North-Star funnel
  /// Called when local push notification is delivered
  static Future<void> trackReminderFired({
    required String planId,
    String? screen,
    String? experimentVariant,
  }) async {
    await track('reminder_fired', properties: {
      'plan_id': planId,
      if (screen != null) 'screen': screen,
      if (experimentVariant != null) 'experiment_variant': experimentVariant,
    });
  }
  
  /// Track plan opened from reminder - final step in North-Star funnel
  /// Called when user taps notification and lands on the plan
  static Future<void> trackPlanOpenedFromReminder({
    required String planId,
    required String screen,
    String? experimentVariant,
  }) async {
    await track('plan_opened_from_reminder', properties: {
      'plan_id': planId,
      'screen': screen,
      if (experimentVariant != null) 'experiment_variant': experimentVariant,
    });
  }
  
  // MARK: - Quality Events (CSV-based)
  
  /// Track when user views macro targets (updated to match CSV schema)
  static Future<void> trackTargetsViewed({
    required String planId,
    String? screen,
    String? experimentVariant,
    required double carbsPreG,
    required double carbsDuringG,
    required double carbsPostG,
    required double proteinPreG,
    required double proteinPostG,
    required double fluidsPreMl,
    required double fluidsDuringMl,
    required double fluidsPostMl,
    required double sodiumPreMg,
    required double sodiumDuringMg,
    required double sodiumPostMg,
  }) async {
    await track('targets_viewed', properties: {
      'plan_id': planId,
      if (screen != null) 'screen': screen,
      if (experimentVariant != null) 'experiment_variant': experimentVariant,
      'carbs_pre_g': carbsPreG,
      'carbs_during_g': carbsDuringG,
      'carbs_post_g': carbsPostG,
      'protein_pre_g': proteinPreG,
      'protein_post_g': proteinPostG,
      'fluids_pre_ml': fluidsPreMl,
      'fluids_during_ml': fluidsDuringMl,
      'fluids_post_ml': fluidsPostMl,
      'sodium_pre_mg': sodiumPreMg,
      'sodium_during_mg': sodiumDuringMg,
      'sodium_post_mg': sodiumPostMg,
    });
  }
  
  /// Track when edit all macros dialog is opened
  static Future<void> trackEditAllMacrosOpened({
    required String planId,
    String? screen,
    String? experimentVariant,
  }) async {
    await track('edit_all_macros_opened', properties: {
      'plan_id': planId,
      if (screen != null) 'screen': screen,
      if (experimentVariant != null) 'experiment_variant': experimentVariant,
    });
  }
  
  /// Track when a specific macro value is changed
  static Future<void> trackMacrosChanged({
    required String planId,
    String? screen,
    String? experimentVariant,
    required String macro,
    required dynamic oldValue,
    required dynamic newValue,
  }) async {
    await track('macros_changed', properties: {
      'plan_id': planId,
      if (screen != null) 'screen': screen,
      if (experimentVariant != null) 'experiment_variant': experimentVariant,
      'macro': macro,
      'old_value': oldValue,
      'new_value': newValue,
    });
  }
  
  /// Track when a food item is added to a plan
  static Future<void> trackItemAdded({
    required String planId,
    String? screen,
    String? experimentVariant,
    required String section, // pre, during, post
    required String itemName,
    required String itemSource, // generic, user_added, etc.
    required double carbsG,
    required double proteinG,
    required double fluidsMl,
    required double sodiumMg,
  }) async {
    await track('item_added', properties: {
      'plan_id': planId,
      if (screen != null) 'screen': screen,
      if (experimentVariant != null) 'experiment_variant': experimentVariant,
      'section': section,
      'item_name': itemName,
      'item_source': itemSource,
      'carbs_g': carbsG,
      'protein_g': proteinG,
      'fluids_ml': fluidsMl,
      'sodium_mg': sodiumMg,
    });
  }
  
  /// Track when a food item is removed from a plan
  static Future<void> trackItemRemoved({
    required String planId,
    String? screen,
    String? experimentVariant,
    required String section,
    required String itemName,
  }) async {
    await track('item_removed', properties: {
      'plan_id': planId,
      if (screen != null) 'screen': screen,
      if (experimentVariant != null) 'experiment_variant': experimentVariant,
      'section': section,
      'item_name': itemName,
    });
  }
  
  /// Track when food item quantity is changed
  static Future<void> trackItemQuantityChanged({
    required String planId,
    String? screen,
    String? experimentVariant,
    required String section,
    required String itemName,
    required double oldQty,
    required double newQty,
    required String qtyUnit, // oz, g, ml, etc.
  }) async {
    await track('item_quantity_changed', properties: {
      'plan_id': planId,
      if (screen != null) 'screen': screen,
      if (experimentVariant != null) 'experiment_variant': experimentVariant,
      'section': section,
      'item_name': itemName,
      'old_qty': oldQty,
      'new_qty': newQty,
      'qty_unit': qtyUnit,
    });
  }
  
  /// Track when guidelines/help content is opened
  static Future<void> trackGuidelinesOpened({
    required String planId,
    String? screen,
    String? experimentVariant,
    required String topic,
  }) async {
    await track('guidelines_opened', properties: {
      'plan_id': planId,
      if (screen != null) 'screen': screen,
      if (experimentVariant != null) 'experiment_variant': experimentVariant,
      'topic': topic,
    });
  }
  
  /// Track when feedback prompt is shown to user
  static Future<void> trackFeedbackPromptShown({
    required String planId,
    String? screen,
    String? experimentVariant,
  }) async {
    await track('feedback_prompt_shown', properties: {
      'plan_id': planId,
      if (screen != null) 'screen': screen,
      if (experimentVariant != null) 'experiment_variant': experimentVariant,
    });
  }
  
  /// Track feedback submitted (from CSV schema)
  static Future<void> trackFeedbackSubmittedNew({
    required String planId,
    String? screen,
    String? experimentVariant,
    required int planMatchRating, // 1-5 scale
    required String appIntent, // like_it | has_potential | not_interested | remind_me
  }) async {
    await track('feedback_submitted', properties: {
      'plan_id': planId,
      if (screen != null) 'screen': screen,
      if (experimentVariant != null) 'experiment_variant': experimentVariant,
      'plan_match_rating': planMatchRating,
      'app_intent': appIntent,
    });
  }

  /// Track when plan is exported/shared
  static Future<void> trackPlanExported({
    required String planId,
    String? screen,
    String? experimentVariant,
    required String channel, // share_sheet, email, etc.
    required String format, // pdf, text, json, etc.
  }) async {
    await track('plan_exported', properties: {
      'plan_id': planId,
      if (screen != null) 'screen': screen,
      if (experimentVariant != null) 'experiment_variant': experimentVariant,
      'channel': channel,
      'format': format,
    });
  }
  
  /// Track when error is shown to user
  static Future<void> trackErrorShown({
    required String errorCode,
    required String message,
    required String screen,
  }) async {
    await track('error_shown', properties: {
      'error_code': errorCode,
      'message': message,
      'screen': screen,
    });
  }
}

