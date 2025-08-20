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
        'App Version': '1.1.0',
        'Platform': Platform.isIOS ? 'iOS' : 'Android',
      };
      
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        superProps.addAll({
          'OS Version': iosInfo.systemVersion,
          'Device Model': iosInfo.model,
        });
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        superProps.addAll({
          'OS Version': androidInfo.version.release,
          'Device Model': androidInfo.model,
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
        track('User Identified', properties: properties);
      } else if (gender != null || age != null || weightPounds != null) {
        // Backward compatibility - use individual parameters
        if (gender != null) people.set('Gender', gender);
        if (age != null) people.set('Age', age);
        if (weightPounds != null) people.set('Weight (lbs)', weightPounds);
        if (runsWithWaterBottle != null) people.set('Runs With Water Bottle', runsWithWaterBottle);
        if (gutTrainingLevel != null) people.set('Gut Training Level', gutTrainingLevel);
        people.setOnce('First Seen', DateTime.now().toIso8601String());
        
        track('User Identified', properties: {
          'Gender': gender,
          'Age': age,
          'Weight (lbs)': weightPounds,
          'Runs With Water Bottle': runsWithWaterBottle,
          'Gut Training Level': gutTrainingLevel,
        });
      } else {
        // Just identifying with ID, no properties (anonymous user)
        people.setOnce('First Seen', DateTime.now().toIso8601String());
        people.set('User Type', 'Anonymous');
        
        track('Anonymous User Identified', properties: {
          'Device ID': userId,
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
      track('User Reset');
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
  
  // MARK: - App Lifecycle Events
  
  /// Track app launch
  Future<void> trackAppLaunched() async {
    await track('App Launched');
  }
  
  /// Track app backgrounded
  Future<void> trackAppBackgrounded() async {
    await track('App Backgrounded');
  }
  
  // MARK: - Onboarding Events
  
  /// Track onboarding started
  Future<void> trackOnboardingStarted() async {
    await track('Onboarding Started');
  }
  
  /// Track onboarding step completed
  Future<void> trackOnboardingStepCompleted(String step) async {
    await track('Onboarding Step Completed', properties: {
      'Step': step,
    });
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
  
  /// Track nutrition plan generation started
  Future<void> trackNutritionPlanGenerationStarted({
    required double distanceMiles,
    required double paceMinutesPerMile,
    required double timeBeforeRunHours,
    String? gutTrainingLevel,
  }) async {
    await timeEvent('Nutrition Plan Generated');
    await track('Nutrition Plan Generation Started', properties: {
      'Distance (miles)': distanceMiles,
      'Pace (min/mile)': paceMinutesPerMile,
      'Time Before Run (hours)': timeBeforeRunHours,
      'Gut Training Level': gutTrainingLevel,
    });
  }
  
  /// Track nutrition plan generated successfully
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
    await track('Nutrition Plan Generated', properties: {
      'Distance (miles)': distanceMiles,
      'Pace (min/mile)': paceMinutesPerMile,
      'Total Calories': totalCalories,
      'Total Carbs (g)': totalCarbs,
      'Before Run Items': beforeRunItems,
      'During Run Items': duringRunItems,
      'After Run Items': afterRunItems,
      'Is First Plan': isFirstPlan,
    });
  }
  
  /// Track nutrition plan generation failed
  Future<void> trackNutritionPlanGenerationFailed({
    required String errorMessage,
    required double distanceMiles,
    required double paceMinutesPerMile,
  }) async {
    await track('Nutrition Plan Generation Failed', properties: {
      'Error': errorMessage,
      'Distance (miles)': distanceMiles,
      'Pace (min/mile)': paceMinutesPerMile,
    });
  }
  
  /// Track nutrition plan saved
  Future<void> trackNutritionPlanSaved({
    required String planId,
    required double distanceMiles,
    required int totalCalories,
  }) async {
    await track('Nutrition Plan Saved', properties: {
      'Plan ID': planId,
      'Distance (miles)': distanceMiles,
      'Total Calories': totalCalories,
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
  
  // MARK: - User Engagement Events
  
  /// Track screen viewed
  Future<void> trackScreenViewed(String screenName) async {
    await track('Screen Viewed', properties: {
      'Screen Name': screenName,
    });
  }
  
  /// Track food preference changed
  Future<void> trackFoodPreferenceChanged({
    required String foodItem,
    required String preference,
  }) async {
    await track('Food Preference Changed', properties: {
      'Food Item': foodItem,
      'Preference': preference,
    });
  }
  
  /// Track settings changed
  Future<void> trackSettingsChanged({
    required String setting,
    required String oldValue,
    required String newValue,
  }) async {
    await track('Settings Changed', properties: {
      'Setting': setting,
      'Old Value': oldValue,
      'New Value': newValue,
    });
  }
  
  /// Track search performed
  Future<void> trackSearchPerformed({
    required String query,
    required int resultsCount,
  }) async {
    await track('Search Performed', properties: {
      'Query': query,
      'Results Count': resultsCount,
    });
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
  
  // MARK: - Performance Events
  
  /// Track app startup time
  Future<void> trackAppStartupTime(Duration startupTime) async {
    await track('App Startup', properties: {
      'Startup Time (ms)': startupTime.inMilliseconds,
    });
  }
  
  /// Track Edge Function performance
  Future<void> trackEdgeFunctionPerformance({
    required String functionName,
    required Duration responseTime,
    required bool success,
    String? errorMessage,
  }) async {
    await track('Edge Function Performance', properties: {
      'Function Name': functionName,
      'Response Time (ms)': responseTime.inMilliseconds,
      'Success': success,
      'Error Message': errorMessage,
    });
  }
}

/// Provider for AnalyticsService
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(ref);
});