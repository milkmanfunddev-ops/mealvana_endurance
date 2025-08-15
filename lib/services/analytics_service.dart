import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:flutter/foundation.dart';

/// Analytics service using Mixpanel for tracking user events and properties
class AnalyticsService {
  static AnalyticsService? _instance;
  static AnalyticsService get instance => _instance ??= AnalyticsService._();
  AnalyticsService._();

  Mixpanel? _mixpanel;
  bool _isInitialized = false;

  /// Initialize Mixpanel with your project token
  Future<void> initialize({required String projectToken}) async {
    try {
      _mixpanel = await Mixpanel.init(
        projectToken,
        trackAutomaticEvents: true,
        optOutTrackingDefault: false,
      );
      _isInitialized = true;
      
      if (kDebugMode) {
        print('Analytics service initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize analytics: $e');
      }
    }
  }

  /// Check if analytics is initialized
  bool get isInitialized => _isInitialized && _mixpanel != null;

  /// Track an event with optional properties
  Future<void> track(String eventName, [Map<String, dynamic>? properties]) async {
    if (!isInitialized) {
      if (kDebugMode) {
        print('Analytics not initialized. Skipping event: $eventName');
      }
      return;
    }

    try {
      _mixpanel!.track(eventName, properties: properties ?? {});
      if (kDebugMode) {
        print('Tracked event: $eventName with properties: $properties');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to track event $eventName: $e');
      }
    }
  }

  /// Identify a user with their unique ID
  Future<void> identify(String userId) async {
    if (!isInitialized) return;

    try {
      await _mixpanel!.identify(userId);
      if (kDebugMode) {
        print('Identified user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to identify user $userId: $e');
      }
    }
  }

  /// Set user properties
  Future<void> setUserProperties(Map<String, dynamic> properties) async {
    if (!isInitialized) return;

    try {
      for (final entry in properties.entries) {
        _mixpanel!.getPeople().set(entry.key, entry.value);
      }
      if (kDebugMode) {
        print('Set user properties: $properties');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to set user properties: $e');
      }
    }
  }

  /// Set user property once (won't overwrite existing value)
  Future<void> setUserPropertyOnce(String property, dynamic value) async {
    if (!isInitialized) return;

    try {
      _mixpanel!.getPeople().setOnce(property, value);
      if (kDebugMode) {
        print('Set user property once: $property = $value');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to set user property once $property: $e');
      }
    }
  }

  /// Increment a numeric user property
  Future<void> incrementUserProperty(String property, [num value = 1]) async {
    if (!isInitialized) return;

    try {
      _mixpanel!.getPeople().increment(property, value.toDouble());
      if (kDebugMode) {
        print('Incremented user property: $property by $value');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to increment user property $property: $e');
      }
    }
  }

  /// Reset user data (for logout)
  Future<void> reset() async {
    if (!isInitialized) return;

    try {
      await _mixpanel!.reset();
      if (kDebugMode) {
        print('Reset user data');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to reset user data: $e');
      }
    }
  }

  /// Flush events (send immediately)
  Future<void> flush() async {
    if (!isInitialized) return;

    try {
      await _mixpanel!.flush();
      if (kDebugMode) {
        print('Flushed analytics events');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to flush events: $e');
      }
    }
  }

  // Predefined events for the nutrition app

  /// Track app launch
  Future<void> trackAppLaunch() async {
    await track('App Launched', {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Track user registration
  Future<void> trackUserRegistration({
    required String method, // 'email', 'google', etc.
    String? referralSource,
  }) async {
    await track('User Registered', {
      'registration_method': method,
      if (referralSource != null) 'referral_source': referralSource,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Track user login
  Future<void> trackUserLogin({required String method}) async {
    await track('User Logged In', {
      'login_method': method,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Track nutrition plan generation
  Future<void> trackPlanGenerated({
    required String planType,
    required int totalCalories,
    required int duration,
    Map<String, dynamic>? additionalData,
  }) async {
    await track('Nutrition Plan Generated', {
      'plan_type': planType,
      'total_calories': totalCalories,
      'duration_minutes': duration,
      'timestamp': DateTime.now().toIso8601String(),
      ...?additionalData,
    });
  }

  /// Track feedback submission
  Future<void> trackFeedbackSubmitted({
    required String feedbackType,
    required int rating,
    bool hasComments = false,
  }) async {
    await track('Feedback Submitted', {
      'feedback_type': feedbackType,
      'rating': rating,
      'has_comments': hasComments,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Track food item interaction
  Future<void> trackFoodItemInteraction({
    required String foodName,
    required String action, // 'viewed', 'expanded', 'selected'
    String? planSection,
  }) async {
    await track('Food Item Interaction', {
      'food_name': foodName,
      'action': action,
      if (planSection != null) 'plan_section': planSection,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Track screen view
  Future<void> trackScreenView({required String screenName}) async {
    await track('Screen Viewed', {
      'screen_name': screenName,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Track error occurrence
  Future<void> trackError({
    required String errorType,
    required String errorMessage,
    String? screenName,
    Map<String, dynamic>? additionalContext,
  }) async {
    await track('Error Occurred', {
      'error_type': errorType,
      'error_message': errorMessage,
      if (screenName != null) 'screen_name': screenName,
      'timestamp': DateTime.now().toIso8601String(),
      ...?additionalContext,
    });
  }

  /// Track user preferences update
  Future<void> trackPreferencesUpdated({
    required Map<String, dynamic> updatedPreferences,
  }) async {
    await track('User Preferences Updated', {
      'updated_preferences': updatedPreferences.keys.toList(),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}