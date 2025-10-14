import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import '../../auth/application/auth_service.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/analytics/analytics_events.dart';
import '../../../shared/services/analytics/analytics_tracker.dart';

/// Application service for managing the onboarding flow
/// Coordinates user creation and food preference collection
class OnboardingService {
  OnboardingService(this.ref);
  final Ref ref;

  /// Get auth service for user operations
  AuthService get _authService => ref.read(authServiceProvider);
  AnalyticsTracker get _analytics => ref.read(appExternalDepsProvider).analytics;


  /// Complete user profile creation step
  Future<UserProfile> createUserProfile({
    required Gender gender,
    required DateTime birthday,
    required int heightFeet,
    required int heightInches,
    required double weightPounds,
    required bool runsWithWaterBottle,
  }) async {

    final user = await _authService.createUser(
      gender: gender,
      birthday: birthday,
      heightFeet: heightFeet,
      heightInches: heightInches,
      weightPounds: weightPounds,
      runsWithWaterBottle: runsWithWaterBottle,
    );

    // Track user registration
    await _analytics.trackUserRegistered(deviceId: user.id);

    // Identify the user in analytics with all their properties
    await _analytics.identifyUser(
      user.id,
      gender: gender.name,
      age: user.age,
      weightPounds: weightPounds,
      runsWithWaterBottle: runsWithWaterBottle,
      gutTrainingLevel: user.gutTraining.name,
    );

    return user;
  }

  /// Complete food preferences step
  Future<void> saveFoodPreferences(
    String userId,
    Map<String, FoodPreference> preferences
  ) async {
    await _authService.saveFoodPreferences(userId, preferences);

    // No need to track onboarding completion as we only track the events in README
    // User registration was already tracked when profile was created
  }

  /// Check if onboarding is complete
  Future<bool> isOnboardingComplete() async {
    return await _authService.hasCompletedOnboarding();
  }

  /// Get onboarding progress
  Future<OnboardingProgress> getOnboardingProgress() async {
    final user = await _authService.getCurrentUser();

    if (user == null) {
      return OnboardingProgress.notStarted;
    }

    final hasPreferences = await _authService.getFoodPreferences(user.id) != null;

    if (!hasPreferences) {
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
