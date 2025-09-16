import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import '../../auth/application/auth_service.dart';
import '../../../shared/services/analytics_service.dart';

/// Application service for managing the onboarding flow
/// Coordinates user creation and food preference collection
class OnboardingService {
  OnboardingService(this.ref);
  final Ref ref;

  /// Track onboarding start time for duration calculation
  DateTime? _onboardingStartTime;

  /// Get auth service for user operations
  AuthService get _authService => ref.read(authServiceProvider);


  /// Complete user profile creation step
  Future<UserProfile> createUserProfile({
    required Gender gender,
    required DateTime birthday,
    required int heightFeet,
    required int heightInches,
    required double weightPounds,
    required bool runsWithWaterBottle,
  }) async {
    // Mark onboarding start time
    _onboardingStartTime = DateTime.now();

    // Track onboarding step completion
    await AnalyticsService.trackOnboardingStepCompleted('User Profile');
    
    final user = await _authService.createUser(
      gender: gender,
      birthday: birthday,
      heightFeet: heightFeet,
      heightInches: heightInches,
      weightPounds: weightPounds,
      runsWithWaterBottle: runsWithWaterBottle,
    );
    
    // Identify the user in analytics with all their properties
    await AnalyticsService.identifyUser(
      user.id,
      properties: {
        'Gender': gender.name,
        'Age': user.age,
        'Weight (lbs)': weightPounds,
        'Height (in)': user.heightFeet * 12 + user.heightInches,
        'Runs With Water Bottle': runsWithWaterBottle,
        'Has Completed Onboarding': false, // Will be true after food preferences
      },
    );
    
    return user;
  }

  /// Complete food preferences step
  Future<void> saveFoodPreferences(
    String userId, 
    Map<String, FoodPreference> preferences
  ) async {
    // Track onboarding step completion
    await AnalyticsService.trackOnboardingStepCompleted('Food Preferences');
    
    await _authService.saveFoodPreferences(userId, preferences);
    
    // Track onboarding completion
    final user = await _authService.getCurrentUser();
    if (user != null) {
      // Update user profile to mark onboarding as complete
      await AnalyticsService.identifyUser(
        user.id,
        properties: {
          'Has Completed Onboarding': true,
          'Gut Training': user.gutTraining.name,
          'Food Preferences Count': preferences.length,
        },
      );
      
      // Calculate onboarding duration
      final onboardingDuration = _onboardingStartTime != null
          ? DateTime.now().difference(_onboardingStartTime!)
          : Duration.zero;

      await AnalyticsService.trackOnboardingCompleted(
        timeTaken: onboardingDuration,
        gender: user.gender.name,
        age: user.age,
        weightPounds: user.weightPounds,
        runsWithWaterBottle: user.runsWithWaterBottle,
        gutTrainingLevel: user.gutTraining.name,
        foodPreferencesSelected: preferences.length,
      );
    }
  }

  /// Check if onboarding is complete
  Future<bool> isOnboardingComplete() async {
    return await _authService.hasCompletedOnboarding();
  }

  /// Get onboarding progress
  Future<OnboardingProgress> getOnboardingProgress() async {
    final user = await _authService.getCurrentUser();
    final hasPreferences = user != null ? 
        _authService.getFoodPreferences(user.id) != null : false;

    if (user == null) {
      return OnboardingProgress.notStarted;
    } else if (!hasPreferences) {
      return OnboardingProgress.profileComplete;
    } else {
      return OnboardingProgress.complete;
    }
  }

  /// Reset onboarding (for testing or re-onboarding)
  Future<void> resetOnboarding() async {
    await _authService.resetUserData();
  }
}

/// Enum for tracking onboarding progress
enum OnboardingProgress {
  notStarted,      // No user profile
  profileComplete, // User profile created, but no food preferences
  complete,        // Both profile and preferences complete
}

/// Provider for OnboardingService
final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return OnboardingService(ref);
});

/// Provider for onboarding progress
final onboardingProgressProvider = FutureProvider<OnboardingProgress>((ref) async {
  final service = ref.watch(onboardingServiceProvider);
  return await service.getOnboardingProgress();
});