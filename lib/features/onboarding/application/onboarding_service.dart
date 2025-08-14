import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_service.dart';
import '../../auth/data/models/user_preferences.dart';

/// Application service for managing the onboarding flow
/// Coordinates user creation and food preference collection
class OnboardingService {
  OnboardingService(this.ref);
  final Ref ref;

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
    return await _authService.createUser(
      gender: gender,
      birthday: birthday,
      heightFeet: heightFeet,
      heightInches: heightInches,
      weightPounds: weightPounds,
      runsWithWaterBottle: runsWithWaterBottle,
    );
  }

  /// Complete food preferences step
  Future<void> saveFoodPreferences(
    String userId, 
    Map<String, FoodPreference> preferences
  ) async {
    await _authService.saveFoodPreferences(userId, preferences);
  }

  /// Check if onboarding is complete
  bool isOnboardingComplete() {
    return _authService.hasCompletedOnboarding();
  }

  /// Get onboarding progress
  OnboardingProgress getOnboardingProgress() {
    final user = _authService.getCurrentUser();
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
final onboardingProgressProvider = Provider<OnboardingProgress>((ref) {
  final service = ref.watch(onboardingServiceProvider);
  return service.getOnboardingProgress();
});