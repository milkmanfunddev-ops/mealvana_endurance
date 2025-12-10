import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../../auth/application/auth_service.dart';
import '../../application/onboarding_service.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';

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

  /// Save sport preferences (step 2 of onboarding)
  Future<bool> saveSportPreferences({
    bool? giSensitivity,
    int? ftpWatts,
    int? typicalBikeBottles,
    bool? hasAeroBottle,
    bool? hasBentoBox,
    int? cssPacePer100mSeconds,
    bool? typicalWetsuit,
    String? typicalSwimCapType,
  }) async {
    // Get current user from auth service (works for both session users and restored users)
    final currentUser = _currentUser ?? await _authService.getCurrentUser();

    DebugLogger.debug('👤 Sport preferences - Current user: ${currentUser?.id ?? "null"}');

    if (currentUser == null) {
      final errorMsg = _contentService.getValue(ContentKeys.errorGeneric,
          defaultValue: 'No user profile found. Please complete user profile first.');
      DebugLogger.error('❌ Sport preferences - No current user found');
      state = AsyncError(errorMsg, StackTrace.current);
      return false;
    }

    DebugLogger.info('🚀 Sport preferences - Starting save process for user: ${currentUser.id}');
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      DebugLogger.debug('📞 Sport preferences - Calling onboarding service');
      await _onboardingService.saveSportPreferences(
        currentUser.id,
        giSensitivity: giSensitivity,
        ftpWatts: ftpWatts,
        typicalBikeBottles: typicalBikeBottles,
        hasAeroBottle: hasAeroBottle,
        hasBentoBox: hasBentoBox,
        cssPacePer100mSeconds: cssPacePer100mSeconds,
        typicalWetsuit: typicalWetsuit,
        typicalSwimCapType: typicalSwimCapType,
      );
      DebugLogger.info('✅ Sport preferences - Save completed successfully');
      // Update our session user reference
      _currentUser = currentUser;
    });

    if (state.hasError) {
      DebugLogger.error('❌ Sport preferences - Error occurred: ${state.error}');
      DebugLogger.debug('📍 Sport preferences - Stack trace: ${state.stackTrace}');
    } else {
      DebugLogger.info('🎉 Sport preferences - Save operation completed without errors');
    }

    return !state.hasError;
  }

  /// Save food preferences (step 3 of onboarding)
  Future<bool> saveFoodPreferences(
    Map<String, FoodPreference> preferences,
    Map<String, int> sliderLevels,
  ) async {
    // Get current user from auth service (works for both session users and restored users)
    final currentUser = _currentUser ?? await _authService.getCurrentUser();

    DebugLogger.debug('👤 Food preferences - Current user: ${currentUser?.id ?? "null"}');
    DebugLogger.debug('🍎 Food preferences - Count: ${preferences.length}');

    if (currentUser == null) {
      final errorMsg = _contentService.getValue(ContentKeys.errorGeneric,
          defaultValue: 'No user profile found. Please complete user profile first.');
      DebugLogger.error('❌ Food preferences - No current user found');
      state = AsyncError(errorMsg, StackTrace.current);
      return false;
    }

    DebugLogger.info('🚀 Food preferences - Starting save process for user: ${currentUser.id}');
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      DebugLogger.debug('📞 Food preferences - Calling onboarding service');
      await _onboardingService.saveFoodPreferences(
        currentUser.id,
        preferences,
        sliderLevels: sliderLevels,
      );
      DebugLogger.info('✅ Food preferences - Save completed successfully');
      // Update our session user reference
      _currentUser = currentUser;

      // NOTE: Sync is NOT triggered here - new users don't need to sync yet
      // (they have no data on server). OAuth-only sync strategy means sync
      // only happens after OAuth sign-in for existing users on new devices.
      DebugLogger.info('📥 Food preferences saved');
    });

    if (state.hasError) {
      DebugLogger.error('❌ Food preferences - Error occurred: ${state.error}');
      DebugLogger.debug('📍 Food preferences - Stack trace: ${state.stackTrace}');
    } else {
      DebugLogger.info('🎉 Food preferences - Save operation completed without errors');
    }

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
