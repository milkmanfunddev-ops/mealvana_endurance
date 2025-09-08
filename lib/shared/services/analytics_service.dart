import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

/// Comprehensive analytics service for tracking user engagement and app usage
/// Designed specifically for Mealvana Endurance nutrition app
class AnalyticsService {
  AnalyticsService(this.ref);
  final Ref ref;
  
  Mixpanel? _mixpanel;
  bool _isInitialized = false;
  
  /// Initialize Mixpanel with your project token
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Mealvana Endurance Mixpanel project token
      const projectToken = 'bd8fe50bb67b1dd0860351e6297347db';
      
      _mixpanel = await Mixpanel.init(
        projectToken,
        trackAutomaticEvents: false, // We'll track events manually for better control
      );
      
      // Set up super properties (properties attached to every event)
      await _setupSuperProperties();
      
      _isInitialized = true;
      print('✅ Mixpanel Analytics initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize Mixpanel: $e');
    }
  }
  
  /// Set up super properties that will be attached to every event
  Future<void> _setupSuperProperties() async {
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
      print('Failed to set super properties: $e');
    }
  }
  
  /// Identify a user (call when user completes onboarding or logs in)
  /// Can be called with just device ID for anonymous users
  Future<void> identifyUser(String userId, {
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
      print('Failed to identify user: $e');
    }
  }
  
  /// Reset user identity (call on logout or data reset)
  Future<void> resetUser() async {
    if (_mixpanel == null) return;
    
    try {
      track('user_reset');
      _mixpanel!.reset();
    } catch (e) {
      print('Failed to reset user: $e');
    }
  }
  
  /// Track a custom event with optional properties
  Future<void> track(String eventName, {Map<String, dynamic>? properties}) async {
    if (_mixpanel == null) return;
    
    try {
      _mixpanel!.track(eventName, properties: properties);
    } catch (e) {
      print('Failed to track event $eventName: $e');
    }
  }
  
  /// Time an event (useful for measuring how long operations take)
  Future<void> timeEvent(String eventName) async {
    if (_mixpanel == null) return;
    
    try {
      _mixpanel!.timeEvent(eventName);
    } catch (e) {
      print('Failed to time event $eventName: $e');
    }
  }
  
  /// Flush events to Mixpanel servers immediately
  Future<void> flush() async {
    if (_mixpanel == null) return;
    
    try {
      _mixpanel!.flush();
    } catch (e) {
      print('Failed to flush events: $e');
    }
  }
  
  // MARK: - App Lifecycle Events - DEPRECATED
  // These events are not part of the North-Star metric
  
  /// Track app launch - DEPRECATED
  @Deprecated('Not required for North-Star metric')
  Future<void> trackAppLaunched() async {
    // Removed - not part of North-Star metric
  }
  
  /// Track app backgrounded - DEPRECATED  
  @Deprecated('Not required for North-Star metric')
  Future<void> trackAppBackgrounded() async {
    // Removed - not part of North-Star metric
  }
  
  // MARK: - Onboarding Events - PARTIALLY DEPRECATED
  
  /// Track onboarding started - DEPRECATED
  @Deprecated('Not required for North-Star metric')
  Future<void> trackOnboardingStarted() async {
    // Removed - not part of North-Star metric
  }
  
  /// Track onboarding step completed - DEPRECATED
  @Deprecated('Not required for North-Star metric')
  Future<void> trackOnboardingStepCompleted(String step) async {
    // Removed - not part of North-Star metric
  }
  
  /// Track onboarding completed
  Future<void> trackOnboardingCompleted({
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
  Future<void> trackOnboardingAbandoned(String lastStep) async {
    await track('Onboarding Abandoned', properties: {
      'Last Step': lastStep,
    });
  }
  
  // MARK: - Nutrition Plan Events
  
  /// Track nutrition plan generation started - DEPRECATED
  /// Use plan_flow_started instead for North-Star metric
  @Deprecated('Use plan_flow_started instead')
  Future<void> trackNutritionPlanGenerationStarted({
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
  Future<void> trackNutritionPlanGenerated({
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
  Future<void> trackNutritionPlanGenerationFailed({
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
  Future<void> trackNutritionPlanSaved({
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
  Future<void> trackNutritionPlanViewed({
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
  Future<void> trackNutritionPlanShared({
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
  Future<void> trackScreenViewed(String screenName) async {
    // Removed - not part of North-Star metric
  }
  
  /// Track food preference changed - DEPRECATED
  @Deprecated('Not required for North-Star metric')
  Future<void> trackFoodPreferenceChanged({
    required String foodItem,
    required String preference,
  }) async {
    // Removed - not part of North-Star metric
  }
  
  /// Track settings changed - DEPRECATED
  @Deprecated('Not required for North-Star metric')
  Future<void> trackSettingsChanged({
    required String setting,
    required String oldValue,
    required String newValue,
  }) async {
    // Removed - not part of North-Star metric
  }
  
  /// Track search performed - DEPRECATED
  @Deprecated('Not required for North-Star metric')
  Future<void> trackSearchPerformed({
    required String query,
    required int resultsCount,
  }) async {
    // Removed - not part of North-Star metric
  }
  
  // MARK: - Feedback Events
  
  /// Track feedback submitted
  Future<void> trackFeedbackSubmitted({
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
  Future<void> trackSurveyCompleted({
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
  Future<void> trackError({
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
  Future<void> trackAppStartupTime(Duration startupTime) async {
    // Removed - not part of North-Star metric
  }
  
  /// Track Edge Function performance - DEPRECATED
  @Deprecated('Not required for North-Star metric')
  Future<void> trackEdgeFunctionPerformance({
    required String functionName,
    required Duration responseTime,
    required bool success,
    String? errorMessage,
  }) async {
    // Removed - not part of North-Star metric
  }

  // MARK: - North-Star Metric Events (Mixpanel Requirements)
  
  /// Track plan flow started - generates plan_id and starts the North-Star funnel
  /// This is the entry point for the successful fueling plan metric
  Future<void> trackPlanFlowStarted({
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
  Future<void> trackPlanSaved({
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
  Future<void> trackReminderSet({
    required String planId,
    required String remindAtIso, // ISO-8601 string with timezone
  }) async {
    await track('reminder_set', properties: {
      'plan_id': planId,
      'remind_at_iso': remindAtIso,
    });
  }
  
  /// Track reminder fired - third step in North-Star funnel
  /// Called when local push notification is delivered
  Future<void> trackReminderFired({
    required String planId,
  }) async {
    await track('reminder_fired', properties: {
      'plan_id': planId,
    });
  }
  
  /// Track plan opened from reminder - final step in North-Star funnel
  /// Called when user taps notification and lands on the plan
  Future<void> trackPlanOpenedFromReminder({
    required String planId,
    required String screen,
  }) async {
    await track('plan_opened_from_reminder', properties: {
      'plan_id': planId,
      'screen': screen,
    });
  }
  
  // MARK: - Quality Events (Mixpanel Recommended)
  
  /// Track when user views macro targets
  Future<void> trackTargetsViewed() async {
    await track('targets_viewed');
  }
  
  /// Track when edit all macros dialog is opened
  Future<void> trackEditAllMacrosOpened() async {
    await track('edit_all_macros_opened');
  }
  
  /// Track when a specific macro value is changed
  Future<void> trackMacrosChanged({
    required String macro,
    required dynamic oldValue,
    required dynamic newValue,
  }) async {
    await track('macros_changed', properties: {
      'macro': macro,
      'old_value': oldValue,
      'new_value': newValue,
    });
  }
  
  /// Track when a food item is added to a plan
  Future<void> trackItemAdded({
    required String itemName,
    required String section, // pre_run, during_run, post_run
  }) async {
    await track('item_added', properties: {
      'item_name': itemName,
      'section': section,
    });
  }
  
  /// Track when a food item is removed from a plan
  Future<void> trackItemRemoved({
    required String itemName,
    required String section,
  }) async {
    await track('item_removed', properties: {
      'item_name': itemName,
      'section': section,
    });
  }
  
  /// Track when food item quantity is changed
  Future<void> trackItemQuantityChanged({
    required String itemName,
    required String section,
    required double oldQuantity,
    required double newQuantity,
  }) async {
    await track('item_quantity_changed', properties: {
      'item_name': itemName,
      'section': section,
      'old_quantity': oldQuantity,
      'new_quantity': newQuantity,
    });
  }
  
  /// Track when guidelines/help content is opened
  Future<void> trackGuidelinesOpened({
    required String topic,
  }) async {
    await track('guidelines_opened', properties: {
      'topic': topic,
    });
  }
  
  /// Track when feedback prompt is shown to user
  Future<void> trackFeedbackPromptShown() async {
    await track('feedback_prompt_shown');
  }
  
  /// Track when plan is exported/shared
  Future<void> trackPlanExported({
    required String channel, // email, text, copy, etc.
    required String format, // pdf, text, json, etc.
  }) async {
    await track('plan_exported', properties: {
      'channel': channel,
      'format': format,
    });
  }
  
  /// Track when error is shown to user
  Future<void> trackErrorShown({
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

/// Provider for AnalyticsService
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(ref);
});