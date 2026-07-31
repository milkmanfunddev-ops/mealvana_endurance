import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';
import '../../auth/application/auth_service.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/analytics/analytics_events.dart';
import '../../../shared/services/analytics/analytics_tracker.dart';
import '../domain/dietary_preference.dart';
import '../domain/allergy.dart';

/// Application service for managing the onboarding flow
/// Coordinates user creation and food preference collection
class OnboardingService {
  OnboardingService(this.ref);
  final Ref ref;

  /// Get auth service for user operations
  AuthService get _authService => ref.read(authServiceProvider);
  AnalyticsTracker get _analytics =>
      ref.read(appExternalDepsProvider).analytics;

  /// Complete user profile creation step
  Future<UserProfile> createUserProfile({
    required Gender gender,
    required DateTime birthday,
    required int heightFeet,
    required int heightInches,
    required double weightPounds,
    required bool runsWithWaterBottle,
    String authProvider =
        'anonymous', // 'anonymous', 'email', 'google', 'apple'
    bool isAnonymous = true, // false when user signs up with email/OAuth
    String? firstName,
    String? lastName,
    String? email,
    UnitSystem unitSystem = UnitSystem.imperial,
  }) async {
    final user = await _authService.createUser(
      gender: gender,
      birthday: birthday,
      heightFeet: heightFeet,
      heightInches: heightInches,
      weightPounds: weightPounds,
      runsWithWaterBottle: runsWithWaterBottle,
      authProvider: authProvider,
      isAnonymous: isAnonymous,
      firstName: firstName,
      lastName: lastName,
      email: email,
      unitSystem: unitSystem,
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

  /// Complete sport preferences step
  Future<void> saveSportPreferences(
    String userId, {
    bool? giSensitivity,
    int? ftpWatts,
    int? typicalBikeBottles,
    bool? hasAeroBottle,
    bool? hasBentoBox,
    int? cssPacePer100mSeconds,
    bool? typicalWetsuit,
    String? typicalSwimCapType,
  }) async {
    // Get current user once to avoid redundant DB reads
    final currentUser = await _authService.getCurrentUser();

    await _authService.updateSportPreferences(
      userId,
      currentUser: currentUser,
      giSensitivity: giSensitivity,
      ftpWatts: ftpWatts,
      typicalBikeBottles: typicalBikeBottles,
      hasAeroBottle: hasAeroBottle,
      hasBentoBox: hasBentoBox,
      cssPacePer100mSeconds: cssPacePer100mSeconds,
      typicalWetsuit: typicalWetsuit,
      typicalSwimCapType: typicalSwimCapType,
    );

    // Track sport preferences saved
    await _analytics.track(
      'sport_preferences_saved',
      properties: {
        'gi_sensitivity': giSensitivity,
        'has_cycling': ftpWatts != null,
        'has_swimming': cssPacePer100mSeconds != null,
      },
    );
  }

  /// Complete dietary preference step
  Future<void> saveDietaryPreference(
    String userId,
    DietaryPreference? dietaryPreference,
  ) async {
    await _authService.updateDietaryPreference(userId, dietaryPreference);

    // Track dietary preference saved
    await _analytics.track(
      'dietary_preference_saved',
      properties: {
        'preference': dietaryPreference?.name ?? 'none',
        'skipped': dietaryPreference == null,
      },
    );
  }

  /// Complete allergies step
  Future<void> saveAllergies(String userId, List<Allergy> allergies) async {
    await _authService.updateAllergies(userId, allergies);

    // Track allergies saved
    await _analytics.track(
      'allergies_saved',
      properties: {
        'allergies': allergies.map((a) => a.name).toList(),
        'count': allergies.length,
        'skipped': allergies.isEmpty,
      },
    );
  }

  /// Complete food preferences step
  Future<void> saveFoodPreferences(
    String userId,
    Map<String, FoodPreference> preferences, {
    Map<String, int>? sliderLevels,
  }) async {
    await _authService.saveFoodPreferences(
      userId,
      preferences,
      sliderLevels: sliderLevels,
    );

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

    // Food preferences are no longer collected during onboarding (2026-06-25),
    // so completion is gated on the explicit onboarding_completed flag rather
    // than the presence of food preferences.
    final completed = await _authService.hasCompletedOnboarding();

    return completed
        ? OnboardingProgress.complete
        : OnboardingProgress.profileComplete;
  }

  /// Reset onboarding (for testing or re-onboarding)
  Future<void> resetOnboarding() async {
    await _authService.resetUserData();
  }
}

/// Enum for tracking onboarding progress
enum OnboardingProgress {
  notStarted, // No user profile
  profileComplete, // User profile created, but no food preferences
  complete, // Both profile and preferences complete
}

/// Provider for OnboardingService
final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return OnboardingService(ref);
});

/// Provider for onboarding progress
final onboardingProgressProvider = FutureProvider<OnboardingProgress>((
  ref,
) async {
  final service = ref.watch(onboardingServiceProvider);
  return await service.getOnboardingProgress();
});
