# Analytics Implementation - Mealvana Endurance

## Overview

Analytics implementation for tracking user behavior and improving the nutrition planning experience for endurance athletes. We'll track key events throughout the user journey from onboarding through plan generation and feedback collection.

## Analytics Service Architecture

### Centralized Analytics Layer

Create a dedicated analytics service that abstracts Mixpanel implementation from the rest of the app:

```dart
// lib/shared/services/analytics_service.dart
import 'package:mixpanel_flutter/mixpanel_flutter.dart';

class AnalyticsService {
  static Mixpanel? _mixpanel;
  static bool _isInitialized = false;
  
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    _mixpanel = await Mixpanel.init(
      "YOUR_MIXPANEL_TOKEN", 
      trackAutomaticEvents: false
    );
    _isInitialized = true;
  }
  
  static void track(String eventName, [Map<String, dynamic>? properties]) {
    if (!_isInitialized) return;
    _mixpanel?.track(eventName, properties: properties);
  }
  
  static void identify(String userId, [Map<String, dynamic>? userProperties]) {
    if (!_isInitialized) return;
    _mixpanel?.identify(userId);
    if (userProperties != null) {
      _mixpanel?.getPeople().set(userProperties);
    }
  }
  
  static void setUserProperties(Map<String, dynamic> properties) {
    if (!_isInitialized) return;
    _mixpanel?.getPeople().set(properties);
  }
  
  static void incrementProperty(String property, [int value = 1]) {
    if (!_isInitialized) return;
    _mixpanel?.getPeople().increment(property, value);
  }
}
```

### Riverpod Analytics Provider

Integrate analytics with our Riverpod architecture:

```dart
// lib/shared/services/analytics_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'analytics_provider.g.dart';

@riverpod
class Analytics extends _$Analytics {
  @override
  bool build() => false;

  Future<void> initialize() async {
    await AnalyticsService.initialize();
    state = true;
  }

  void trackEvent(String event, [Map<String, dynamic>? properties]) {
    AnalyticsService.track(event, properties);
  }

  void identifyUser(String userId, Map<String, dynamic> userProperties) {
    AnalyticsService.identify(userId, userProperties);
  }
}
```

## Key Event Tracking

### 1. Onboarding Flow Events

Track the multi-step onboarding process to understand drop-off points:

```dart
// lib/features/onboarding/presentation/controllers/onboarding_controller.dart
@riverpod
class OnboardingController extends _$OnboardingController {
  @override
  OnboardingStep build() => OnboardingStep.welcome;

  void startOnboarding() {
    ref.read(analyticsProvider.notifier).trackEvent('onboarding_started');
    state = OnboardingStep.basicInfo;
  }

  void completeBasicInfo({
    required Gender gender,
    required DateTime birthday,
    required double heightFeet,
    required double heightInches,
    required double weight,
  }) {
    // Track completion with anonymized demographics
    ref.read(analyticsProvider.notifier).trackEvent('onboarding_basic_info_completed', {
      'gender': gender.name,
      'age_group': _getAgeGroup(birthday),
      'bmi_range': _getBMIRange(heightFeet, heightInches, weight),
    });
    
    state = OnboardingStep.runningHabits;
  }

  void completeRunningHabits({required bool runsWithWaterBottle}) {
    ref.read(analyticsProvider.notifier).trackEvent('onboarding_running_habits_completed', {
      'runs_with_water_bottle': runsWithWaterBottle,
    });
    
    state = OnboardingStep.foodPreferences;
  }

  void completeFoodPreferences(Map<String, FoodPreference> preferences) {
    // Analyze preference patterns
    final likedCount = preferences.values.where((p) => p == FoodPreference.like).length;
    final dislikedCount = preferences.values.where((p) => p == FoodPreference.dislike).length;
    final openToTryCount = preferences.values.where((p) => p == FoodPreference.openToTry).length;

    ref.read(analyticsProvider.notifier).trackEvent('onboarding_food_preferences_completed', {
      'total_foods_reviewed': preferences.length,
      'liked_count': likedCount,
      'disliked_count': dislikedCount,
      'open_to_try_count': openToTryCount,
      'completion_rate': preferences.length / totalFoodsAvailable,
    });
    
    state = OnboardingStep.complete;
  }

  void completeOnboarding() {
    ref.read(analyticsProvider.notifier).trackEvent('onboarding_completed');
  }

  String _getAgeGroup(DateTime birthday) {
    final age = DateTime.now().year - birthday.year;
    if (age < 25) return '18-24';
    if (age < 35) return '25-34';
    if (age < 45) return '35-44';
    if (age < 55) return '45-54';
    return '55+';
  }

  String _getBMIRange(double feet, double inches, double weight) {
    final heightInches = (feet * 12) + inches;
    final bmi = (weight / (heightInches * heightInches)) * 703;
    
    if (bmi < 18.5) return 'underweight';
    if (bmi < 25) return 'normal';
    if (bmi < 30) return 'overweight';
    return 'obese';
  }
}
```

### 2. Food Preference Tracking

Track individual food preferences to understand patterns:

```dart
// lib/features/onboarding/presentation/controllers/food_preferences_controller.dart
@riverpod
class FoodPreferencesController extends _$FoodPreferencesController {
  @override
  Map<String, FoodPreference> build() => {};

  void setPreference(String foodName, FoodPreference preference) {
    state = {...state, foodName: preference};
    
    // Track individual food preference
    ref.read(analyticsProvider.notifier).trackEvent('food_preference_set', {
      'food_name': foodName,
      'preference': preference.name,
      'food_category': _getFoodCategory(foodName),
      'total_preferences_set': state.length,
    });
  }

  void requestMoreInfo(String foodName) {
    ref.read(analyticsProvider.notifier).trackEvent('food_info_requested', {
      'food_name': foodName,
      'food_category': _getFoodCategory(foodName),
    });
  }

  String _getFoodCategory(String foodName) {
    // Categorize foods as defined in requirements
    const preRunFoods = ['oatmeal', 'waffle', 'pancakes', 'bagel', 'bread', 
                        'peanut butter', 'banana', 'apple', 'juice', 
                        'granola bars', 'coffee'];
    const duringRunFoods = ['sports drink', 'gel', 'chews', 'sport drink mix',
                           'dates', 'dried fruits', 'electrolyte tablets'];
    const afterRunFoods = ['coconut water', 'protein shake', 'protein bars'];

    if (preRunFoods.contains(foodName.toLowerCase())) return 'pre_run';
    if (duringRunFoods.contains(foodName.toLowerCase())) return 'during_run';
    if (afterRunFoods.contains(foodName.toLowerCase())) return 'after_run';
    return 'unknown';
  }
}
```

### 3. Nutrition Plan Generation Tracking

Track plan generation usage patterns and success metrics:

```dart
// lib/features/nutrition_plan/application/nutrition_plan_service.dart
@riverpod
class NutritionPlanService extends _$NutritionPlanService {
  @override
  void build() {}

  Future<NutritionPlan> generatePlan({
    required double distanceMiles,
    required Duration averagePace,
  }) async {
    final startTime = DateTime.now();
    
    // Track plan generation start
    ref.read(analyticsProvider.notifier).trackEvent('nutrition_plan_generation_started', {
      'distance_miles': distanceMiles,
      'average_pace_minutes': averagePace.inMinutes,
      'estimated_duration_minutes': (distanceMiles * averagePace.inMinutes).round(),
    });

    try {
      final userProfile = await ref.read(userProfileProvider.future);
      final preferences = await ref.read(foodPreferencesProvider.future);
      
      // Generate the plan (your business logic here)
      final plan = await _generateNutritionPlan(
        userProfile, 
        preferences, 
        distanceMiles, 
        averagePace
      );
      
      final generationTime = DateTime.now().difference(startTime);
      
      // Track successful generation
      ref.read(analyticsProvider.notifier).trackEvent('nutrition_plan_generated', {
        'distance_miles': distanceMiles,
        'average_pace_minutes': averagePace.inMinutes,
        'generation_time_ms': generationTime.inMilliseconds,
        'total_carbs_grams': plan.macros.carbs,
        'total_sodium_mg': plan.macros.sodium,
        'total_fluids_oz': plan.macros.fluids,
        'pre_run_items_count': plan.preRunItems.length,
        'during_run_items_count': plan.duringRunItems.length,
        'after_run_items_count': plan.afterRunItems.length,
      });
      
      // Increment user's total plans generated
      ref.read(analyticsProvider.notifier).incrementProperty('total_plans_generated');
      
      return plan;
      
    } catch (error) {
      // Track generation failure
      ref.read(analyticsProvider.notifier).trackEvent('nutrition_plan_generation_failed', {
        'distance_miles': distanceMiles,
        'average_pace_minutes': averagePace.inMinutes,
        'error_type': error.runtimeType.toString(),
        'generation_time_ms': DateTime.now().difference(startTime).inMilliseconds,
      });
      
      rethrow;
    }
  }
}
```

### 4. Feedback Collection Tracking

Track user feedback to understand plan satisfaction and app potential:

```dart
// lib/features/feedback/presentation/controllers/feedback_controller.dart
@riverpod
class FeedbackController extends _$FeedbackController {
  @override
  FeedbackState build() => const FeedbackState.initial();

  void submitPlanFeedback(PlanFeedbackType feedback) {
    ref.read(analyticsProvider.notifier).trackEvent('plan_feedback_submitted', {
      'feedback_type': feedback.name, // 'close', 'much_more', 'much_less'
      'current_plan_id': _getCurrentPlanId(),
    });
    
    state = FeedbackState.planFeedbackComplete(feedback);
  }

  void submitAppFeedback(AppFeedbackType feedback, [String? suggestion]) {
    final properties = {
      'feedback_type': feedback.name, // 'like_it', 'has_potential', 'not_interested'
    };
    
    if (suggestion != null) {
      properties['suggestion_provided'] = true;
      properties['suggestion_length'] = suggestion.length;
      // Don't send actual suggestion text for privacy
    }
    
    ref.read(analyticsProvider.notifier).trackEvent('app_feedback_submitted', properties);
    
    if (feedback == AppFeedbackType.likeIt) {
      _trackReminderInterest();
    }
    
    state = FeedbackState.complete(feedback, suggestion);
  }

  void _trackReminderInterest() {
    ref.read(analyticsProvider.notifier).trackEvent('reminder_interest_expressed');
  }
}
```

## User Property Tracking

### Profile Properties

Set user properties for segmentation and analysis:

```dart
// lib/features/user/application/user_service.dart
@riverpod
class UserService extends _$UserService {
  @override
  void build() {}

  Future<void> createUserProfile(UserProfile profile) async {
    // Save profile locally and sync
    await _saveProfile(profile);
    
    // Set user properties for analytics
    ref.read(analyticsProvider.notifier).identifyUser(profile.id, {
      'age_group': _getAgeGroup(profile.birthday),
      'gender': profile.gender.name,
      'runs_with_water_bottle': profile.runsWithWaterBottle,
      'signup_date': DateTime.now().toIso8601String(),
      'total_food_preferences': profile.foodPreferences.length,
      'liked_foods_count': profile.foodPreferences.values
          .where((p) => p == FoodPreference.like).length,
    });
  }

  Future<void> updateUserProperties() async {
    final profile = await ref.read(userProfileProvider.future);
    final totalPlans = await _getTotalGeneratedPlans(profile.id);
    
    ref.read(analyticsProvider.notifier).setUserProperties({
      'total_plans_generated': totalPlans,
      'last_plan_date': await _getLastPlanDate(profile.id),
      'is_active_user': await _isActiveUser(profile.id),
    });
  }
}
```

## Session and Engagement Tracking

### App Lifecycle Events

Track app usage patterns:

```dart
// lib/shared/core/app_lifecycle_observer.dart
class AppLifecycleObserver with WidgetsBindingObserver {
  final WidgetRef ref;
  DateTime? _sessionStart;

  AppLifecycleObserver(this.ref);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _startSession();
        break;
      case AppLifecycleState.paused:
        _endSession();
        break;
      case AppLifecycleState.detached:
        _endSession();
        break;
      default:
        break;
    }
  }

  void _startSession() {
    _sessionStart = DateTime.now();
    ref.read(analyticsProvider.notifier).trackEvent('session_started');
  }

  void _endSession() {
    if (_sessionStart != null) {
      final sessionDuration = DateTime.now().difference(_sessionStart!);
      
      ref.read(analyticsProvider.notifier).trackEvent('session_ended', {
        'session_duration_seconds': sessionDuration.inSeconds,
      });
      
      _sessionStart = null;
    }
  }
}
```

## Funnel Analysis Events

### Onboarding to Plan Generation Funnel

Track the critical user journey:

```dart
// Funnel events in order:
// 1. onboarding_started
// 2. onboarding_basic_info_completed  
// 3. onboarding_running_habits_completed
// 4. onboarding_food_preferences_completed
// 5. onboarding_completed
// 6. nutrition_plan_generation_started
// 7. nutrition_plan_generated
// 8. plan_feedback_submitted
// 9. app_feedback_submitted
```

### Retention Events

Track user return patterns:

```dart
// lib/features/analytics/application/retention_tracker.dart
@riverpod
class RetentionTracker extends _$RetentionTracker {
  @override
  void build() {}

  Future<void> trackAppOpen() async {
    final lastOpenDate = await _getLastOpenDate();
    final daysSinceLastOpen = lastOpenDate != null 
        ? DateTime.now().difference(lastOpenDate).inDays 
        : null;

    ref.read(analyticsProvider.notifier).trackEvent('app_opened', {
      'days_since_last_open': daysSinceLastOpen,
      'is_returning_user': daysSinceLastOpen != null && daysSinceLastOpen > 0,
    });

    await _setLastOpenDate(DateTime.now());
  }

  Future<void> trackWeeklyRetention() async {
    final installDate = await _getInstallDate();
    if (installDate == null) return;

    final daysSinceInstall = DateTime.now().difference(installDate).inDays;
    final week = (daysSinceInstall / 7).floor() + 1;

    ref.read(analyticsProvider.notifier).trackEvent('weekly_retention', {
      'week_number': week,
      'days_since_install': daysSinceInstall,
    });
  }
}
```

## Privacy and Consent

### GDPR Compliance

Handle analytics consent:

```dart
// lib/shared/services/consent_service.dart
@riverpod
class ConsentService extends _$ConsentService {
  @override
  bool build() => false; // Default: no consent

  void grantAnalyticsConsent() {
    state = true;
    // Initialize analytics only after consent
    ref.read(analyticsProvider.notifier).initialize();
  }

  void revokeAnalyticsConsent() {
    state = false;
    // Clear any stored data
    AnalyticsService.reset();
  }
}

// Modify AnalyticsService to check consent
static void track(String eventName, [Map<String, dynamic>? properties]) {
  if (!_isInitialized || !ConsentService.hasConsent) return;
  _mixpanel?.track(eventName, properties: properties);
}
```

This analytics implementation provides comprehensive tracking for understanding user behavior, optimizing the nutrition planning experience, and making data-driven product decisions while respecting user privacy.