import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import '../../application/onboarding_service.dart';

/// Controller for managing onboarding flow state
class OnboardingController extends StateNotifier<AsyncValue<void>> {
  OnboardingController(this._onboardingService) : super(const AsyncData(null));

  final OnboardingService _onboardingService;
  UserProfile? _currentUser;

  /// Create user profile (step 1 of onboarding)
  Future<bool> createUserProfile({
    required Gender gender,
    required DateTime birthday,
    required int heightFeet,
    required int heightInches,
    required double weightPounds,
    required bool runsWithWaterBottle,
  }) async {
    state = const AsyncLoading();

    try {
      _currentUser = await _onboardingService.createUserProfile(
        gender: gender,
        birthday: birthday,
        heightFeet: heightFeet,
        heightInches: heightInches,
        weightPounds: weightPounds,
        runsWithWaterBottle: runsWithWaterBottle,
      );

      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  /// Save food preferences (step 2 of onboarding)
  Future<bool> saveFoodPreferences(Map<String, FoodPreference> preferences) async {
    if (_currentUser == null) {
      state = AsyncError('No user profile found', StackTrace.current);
      return false;
    }

    state = const AsyncLoading();

    try {
      await _onboardingService.saveFoodPreferences(_currentUser!.id, preferences);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  /// Check if onboarding is complete
  bool isOnboardingComplete() {
    return _onboardingService.isOnboardingComplete();
  }

  /// Get current onboarding progress
  OnboardingProgress getProgress() {
    return _onboardingService.getOnboardingProgress();
  }

  /// Get current user (if created during this session)
  UserProfile? get currentUser => _currentUser;

  /// Reset onboarding for testing
  Future<void> resetOnboarding() async {
    state = const AsyncLoading();
    try {
      await _onboardingService.resetOnboarding();
      _currentUser = null;
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}

/// Provider for onboarding controller
final onboardingControllerProvider = 
    StateNotifierProvider<OnboardingController, AsyncValue<void>>((ref) {
  final onboardingService = ref.watch(onboardingServiceProvider);
  return OnboardingController(onboardingService);
});

/// Provider for onboarding progress
final onboardingProgressProvider = Provider<OnboardingProgress>((ref) {
  final controller = ref.watch(onboardingControllerProvider.notifier);
  return controller.getProgress();
});