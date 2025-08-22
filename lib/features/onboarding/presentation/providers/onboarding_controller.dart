import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../../auth/application/auth_service.dart';
import '../../application/onboarding_service.dart';

part 'onboarding_controller.g.dart';

/// Controller for managing onboarding flow state
@riverpod
class OnboardingController extends _$OnboardingController {
  OnboardingService get _onboardingService => ref.read(onboardingServiceProvider);
  ContentService get _contentService => ref.read(contentServiceProvider);
  AuthService get _authService => ref.read(authServiceProvider);
  UserProfile? _currentUser;

  @override
  FutureOr<void> build() {
    // Initialize controller - no initial async work needed
    return null;
  }

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

    state = await AsyncValue.guard(() async {
      _currentUser = await _onboardingService.createUserProfile(
        gender: gender,
        birthday: birthday,
        heightFeet: heightFeet,
        heightInches: heightInches,
        weightPounds: weightPounds,
        runsWithWaterBottle: runsWithWaterBottle,
      );
    });

    return !state.hasError;
  }

  /// Save food preferences (step 2 of onboarding)
  Future<bool> saveFoodPreferences(Map<String, FoodPreference> preferences) async {
    // Get current user from auth service (works for both session users and restored users)
    final currentUser = _currentUser ?? await _authService.getCurrentUser();
    
    print('👤 Food preferences - Current user: ${currentUser?.id ?? "null"}');
    print('🍎 Food preferences - Count: ${preferences.length}');
    
    if (currentUser == null) {
      final errorMsg = _contentService.getValue(ContentKeys.errorGeneric, 
          defaultValue: 'No user profile found. Please complete user profile first.');
      state = AsyncError(errorMsg, StackTrace.current);
      return false;
    }

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await _onboardingService.saveFoodPreferences(currentUser.id, preferences);
      // Update our session user reference
      _currentUser = currentUser;
    });

    return !state.hasError;
  }

  /// Check if onboarding is complete
  Future<bool> isOnboardingComplete() async {
    return await _onboardingService.isOnboardingComplete();
  }

  /// Get current onboarding progress
  Future<OnboardingProgress> getProgress() async {
    return await _onboardingService.getOnboardingProgress();
  }

  /// Get current user (if created during this session)
  UserProfile? get currentUser => _currentUser;

  /// Reset onboarding for testing
  Future<void> resetOnboarding() async {
    state = const AsyncLoading();
    
    state = await AsyncValue.guard(() async {
      await _onboardingService.resetOnboarding();
      _currentUser = null;
    });
  }
  
  /// Get content-driven error message
  String getErrorMessage(String? error) {
    return _contentService.getValue(ContentKeys.errorGeneric, 
        defaultValue: error ?? 'Something went wrong. Please try again.');
  }
}

/// Provider for onboarding progress
@riverpod
Future<OnboardingProgress> onboardingProgress(Ref ref) async {
  final controller = ref.watch(onboardingControllerProvider.notifier);
  return await controller.getProgress();
}