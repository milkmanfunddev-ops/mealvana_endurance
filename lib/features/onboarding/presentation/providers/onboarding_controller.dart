import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../../auth/application/auth_service.dart';
import '../../../nutrition_plan/data/food_repository.dart';
import '../../application/onboarding_service.dart';
import '../../domain/dietary_preference.dart';
import '../../domain/allergy.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';
import 'food_selections_cache_provider.dart';

part 'onboarding_controller.g.dart';

/// Controller for managing onboarding flow state
@riverpod
class OnboardingController extends _$OnboardingController {
  OnboardingService get _onboardingService => ref.read(onboardingServiceProvider);
  ContentService get _contentService => ref.read(contentServiceProvider);
  AuthService get _authService => ref.read(authServiceProvider);
  UserProfile? _currentUser;

  // Cached onboarding data (in-memory only until batch save)
  Map<String, dynamic>? _cachedUserProfileData;
  Set<String> _cachedSelectedSports = {'running'}; // Default: running
  Map<String, dynamic>? _cachedSportPreferences;
  DietaryPreference? _cachedDietaryPreference;
  List<Allergy>? _cachedAllergies;

  @override
  FutureOr<void> build() {
    // Prevent auto-dispose during onboarding navigation
    // Keep all cached onboarding data until onboarding is completed
    ref.keepAlive();

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

  /// Save dietary preference (step 3a of onboarding)
  /// When called from settings, also updates food preferences for excluded foods
  /// Removes auto-avoided foods when dietary preference changes (using preference_source tracking)
  Future<bool> saveDietaryPreference(DietaryPreference? preference) async {
    // Get current user from auth service (works for both session users and restored users)
    final currentUser = _currentUser ?? await _authService.getCurrentUser();

    DebugLogger.debug('👤 Dietary preference - Current user: ${currentUser?.id ?? "null"}');
    DebugLogger.debug('🥗 Dietary preference: ${preference?.name ?? "none"}');

    if (currentUser == null) {
      final errorMsg = _contentService.getValue(ContentKeys.errorGeneric,
          defaultValue: 'No user profile found. Please complete user profile first.');
      DebugLogger.error('❌ Dietary preference - No current user found');
      state = AsyncError(errorMsg, StackTrace.current);
      return false;
    }

    // Get old dietary preference to determine if it changed
    final oldPreference = currentUser.dietaryPreference;
    final preferenceChanged = oldPreference != preference;

    DebugLogger.info('🚀 Dietary preference - Starting save process for user: ${currentUser.id}');
    DebugLogger.debug('📋 Dietary preference - Old: ${oldPreference?.displayName ?? "none"}, New: ${preference?.displayName ?? "none"}');
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      DebugLogger.debug('📞 Dietary preference - Calling onboarding service');
      await _onboardingService.saveDietaryPreference(currentUser.id, preference);
      DebugLogger.info('✅ Dietary preference - Save completed successfully');
      // Update our session user reference
      _currentUser = currentUser;

      // If dietary preference changed, remove old preference-based food avoids
      if (preferenceChanged && oldPreference != null && oldPreference != DietaryPreference.none) {
        final removedCount = await _authService.removeFoodPreferencesBySource(
          currentUser.id,
          'dietary:${oldPreference.dbValue}',
        );
        DebugLogger.info('🗑️ Removed $removedCount food avoids for old diet: ${oldPreference.displayName}');
      }

      // Add food preferences for new dietary preference only
      if (preferenceChanged && preference != null && preference != DietaryPreference.none) {
        await _updateFoodPreferencesForAllergies(
          currentUser.id,
          [], // Don't update allergies in dietary save
          preference,
        );
      }
    });

    if (state.hasError) {
      DebugLogger.error('❌ Dietary preference - Error occurred: ${state.error}');
      DebugLogger.debug('📍 Dietary preference - Stack trace: ${state.stackTrace}');
    } else {
      DebugLogger.info('🎉 Dietary preference - Save operation completed without errors');
    }

    return !state.hasError;
  }

  /// Save allergies (step 3b of onboarding)
  /// When called from settings, also updates food preferences for allergen-containing foods
  /// Removes auto-avoided foods when allergies are removed (using preference_source tracking)
  Future<bool> saveAllergies(List<Allergy> allergies) async {
    // Get current user from auth service (works for both session users and restored users)
    final currentUser = _currentUser ?? await _authService.getCurrentUser();

    DebugLogger.debug('👤 Allergies - Current user: ${currentUser?.id ?? "null"}');
    DebugLogger.debug('⚠️ Allergies count: ${allergies.length}');

    if (currentUser == null) {
      final errorMsg = _contentService.getValue(ContentKeys.errorGeneric,
          defaultValue: 'No user profile found. Please complete user profile first.');
      DebugLogger.error('❌ Allergies - No current user found');
      state = AsyncError(errorMsg, StackTrace.current);
      return false;
    }

    // Get old allergies to determine which ones were removed
    final oldAllergies = currentUser.allergies;
    final newAllergies = allergies.toSet();
    final removedAllergies = oldAllergies.where((a) => !newAllergies.contains(a)).toList();
    final addedAllergies = newAllergies.where((a) => !oldAllergies.contains(a)).toList();

    DebugLogger.info('🚀 Allergies - Starting save process for user: ${currentUser.id}');
    DebugLogger.debug('📋 Allergies - Removed: ${removedAllergies.map((a) => a.displayName).join(', ')}');
    DebugLogger.debug('📋 Allergies - Added: ${addedAllergies.map((a) => a.displayName).join(', ')}');
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      DebugLogger.debug('📞 Allergies - Calling onboarding service');
      await _onboardingService.saveAllergies(currentUser.id, allergies);
      DebugLogger.info('✅ Allergies - Save completed successfully');
      // Update our session user reference
      _currentUser = currentUser;

      // Remove food preferences for allergies that were removed
      for (final removedAllergy in removedAllergies) {
        final removedCount = await _authService.removeFoodPreferencesBySource(
          currentUser.id,
          'allergy:${removedAllergy.dbValue}',
        );
        DebugLogger.info('🗑️ Removed $removedCount food avoids for allergy: ${removedAllergy.displayName}');
      }

      // Add food preferences for new allergies only
      if (addedAllergies.isNotEmpty) {
        await _updateFoodPreferencesForAllergies(
          currentUser.id,
          addedAllergies,
          null, // Don't update dietary in allergy save
        );
      }
    });

    if (state.hasError) {
      DebugLogger.error('❌ Allergies - Error occurred: ${state.error}');
      DebugLogger.debug('📍 Allergies - Stack trace: ${state.stackTrace}');
    } else {
      DebugLogger.info('🎉 Allergies - Save operation completed without errors');
    }

    return !state.hasError;
  }

  /// Update food preferences to "avoid" for foods containing allergens or excluded by dietary preference
  /// Saves each allergy/dietary preference with its own source tag for proper undo support
  Future<void> _updateFoodPreferencesForAllergies(
    String userId,
    List<Allergy> allergies,
    DietaryPreference? dietaryPreference,
  ) async {
    try {
      final foodRepository = ref.read(foodRepositoryProvider);

      // Process each allergy individually with its own source tag
      for (final allergy in allergies) {
        final allergyFoods = await foodRepository.getFoodsToAvoid(
          allergies: [allergy],
        );

        if (allergyFoods.isNotEmpty) {
          final preferences = <String, FoodPreference>{};
          final sliderLevels = <String, int>{};
          for (final foodName in allergyFoods) {
            preferences[foodName] = FoodPreference.dislike;
            sliderLevels[foodName] = 0;
          }

          // Save with allergy-specific source (e.g., 'allergy:gluten')
          await _authService.saveFoodPreferences(
            userId,
            preferences,
            sliderLevels: sliderLevels,
            source: 'allergy:${allergy.dbValue}',
          );

          DebugLogger.info('🍎 Set ${allergyFoods.length} foods to avoid for allergy: ${allergy.displayName}');
        }
      }

      // Process dietary preference if set
      if (dietaryPreference != null && dietaryPreference != DietaryPreference.none) {
        final dietaryFoods = await foodRepository.getFoodsToAvoid(
          dietaryPreference: dietaryPreference,
        );

        if (dietaryFoods.isNotEmpty) {
          final preferences = <String, FoodPreference>{};
          final sliderLevels = <String, int>{};
          for (final foodName in dietaryFoods) {
            preferences[foodName] = FoodPreference.dislike;
            sliderLevels[foodName] = 0;
          }

          // Save with dietary-specific source (e.g., 'dietary:vegan')
          await _authService.saveFoodPreferences(
            userId,
            preferences,
            sliderLevels: sliderLevels,
            source: 'dietary:${dietaryPreference.dbValue}',
          );

          DebugLogger.info('🥗 Set ${dietaryFoods.length} foods to avoid for diet: ${dietaryPreference.displayName}');
        }
      }

      DebugLogger.info('✅ Food preferences updated for allergen/dietary restrictions');
    } catch (e, stackTrace) {
      DebugLogger.error('❌ Failed to update food preferences for allergies: $e');
      DebugLogger.debug('📍 Stack trace: $stackTrace');
      // Don't rethrow - allergy save was successful, this is a best-effort update
    }
  }

  /// Save food preferences (step 4 of onboarding)
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

      // Clear the food selections cache after successful save
      ref.read(foodSelectionsCacheProvider.notifier).clear();
      DebugLogger.debug('🧹 Food preferences - Cache cleared');

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

  // ============================================================================
  // BATCH SAVE METHODS FOR POST-OAUTH ONBOARDING
  // ============================================================================

  /// Cache user profile data (don't save to DB yet)
  void cacheUserProfileData({
    required Gender gender,
    required DateTime birthday,
    required int heightFeet,
    required int heightInches,
    required double weightPounds,
    required bool runsWithWaterBottle,
  }) {
    _cachedUserProfileData = {
      'gender': gender,
      'birthday': birthday,
      'heightFeet': heightFeet,
      'heightInches': heightInches,
      'weightPounds': weightPounds,
      'runsWithWaterBottle': runsWithWaterBottle,
    };
    DebugLogger.debug('📝 Cached user profile data');
  }

  /// Cache sport preferences (don't save to DB yet)
  void cacheSportPreferences({
    bool? giSensitivity,
    int? ftpWatts,
    int? typicalBikeBottles,
    bool? hasAeroBottle,
    bool? hasBentoBox,
    int? cssPacePer100mSeconds,
    bool? typicalWetsuit,
    String? typicalSwimCapType,
  }) {
    _cachedSportPreferences = {
      'giSensitivity': giSensitivity,
      'ftpWatts': ftpWatts,
      'typicalBikeBottles': typicalBikeBottles,
      'hasAeroBottle': hasAeroBottle,
      'hasBentoBox': hasBentoBox,
      'cssPacePer100mSeconds': cssPacePer100mSeconds,
      'typicalWetsuit': typicalWetsuit,
      'typicalSwimCapType': typicalSwimCapType,
    };
    DebugLogger.debug('📝 Cached sport preferences');
  }

  /// Cache dietary preference (don't save to DB yet)
  void cacheDietaryPreference(DietaryPreference? preference) {
    _cachedDietaryPreference = preference;
    DebugLogger.debug('📝 Cached dietary preference: ${preference?.name ?? "none"}');
  }

  /// Cache allergies (don't save to DB yet)
  void cacheAllergies(List<Allergy> allergies) {
    _cachedAllergies = allergies;
    DebugLogger.debug('📝 Cached ${allergies.length} allergies');
  }

  /// Cache selected sports
  void cacheSelectedSports(Set<String> sports) {
    _cachedSelectedSports = sports;
    DebugLogger.debug('📝 Cached ${sports.length} sports: ${sports.join(", ")}');
    // Trigger rebuild to update dynamic pages
    state = const AsyncData(null);
  }

  /// Get cached sports selections
  Set<String> get cachedSelectedSports => _cachedSelectedSports;

  /// Get cached user profile data
  Map<String, dynamic>? get cachedUserProfileData => _cachedUserProfileData;

  /// Get cached sport preferences
  Map<String, dynamic>? get cachedSportPreferences => _cachedSportPreferences;

  /// Get cached dietary preference
  DietaryPreference? get cachedDietaryPreference => _cachedDietaryPreference;

  /// Get cached allergies
  List<Allergy>? get cachedAllergies => _cachedAllergies;

  /// Save all cached onboarding data to DB and Supabase
  /// This is called after OAuth registration to save everything at once
  Future<bool> saveAllOnboardingData() async {
    DebugLogger.info('📦 Starting batch save of all onboarding data');
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      // 1. Create user profile
      if (_cachedUserProfileData != null) {
        final data = _cachedUserProfileData!;
        _currentUser = await _onboardingService.createUserProfile(
          gender: data['gender'] as Gender,
          birthday: data['birthday'] as DateTime,
          heightFeet: data['heightFeet'] as int,
          heightInches: data['heightInches'] as int,
          weightPounds: data['weightPounds'] as double,
          runsWithWaterBottle: data['runsWithWaterBottle'] as bool,
        );
        DebugLogger.info('✅ User profile created: ${_currentUser!.id}');
      } else {
        throw Exception('No user profile data cached');
      }

      final userId = _currentUser!.id;

      // 2. Save sport preferences
      if (_cachedSportPreferences != null) {
        final prefs = _cachedSportPreferences!;
        await _onboardingService.saveSportPreferences(
          userId,
          giSensitivity: prefs['giSensitivity'] as bool?,
          ftpWatts: prefs['ftpWatts'] as int?,
          typicalBikeBottles: prefs['typicalBikeBottles'] as int?,
          hasAeroBottle: prefs['hasAeroBottle'] as bool?,
          hasBentoBox: prefs['hasBentoBox'] as bool?,
          cssPacePer100mSeconds: prefs['cssPacePer100mSeconds'] as int?,
          typicalWetsuit: prefs['typicalWetsuit'] as bool?,
          typicalSwimCapType: prefs['typicalSwimCapType'] as String?,
        );
        DebugLogger.info('✅ Sport preferences saved');
      }

      // 3. Save dietary preference
      if (_cachedDietaryPreference != null) {
        await _onboardingService.saveDietaryPreference(userId, _cachedDietaryPreference);
        DebugLogger.info('✅ Dietary preference saved');
      }

      // 4. Save allergies
      if (_cachedAllergies != null) {
        await _onboardingService.saveAllergies(userId, _cachedAllergies!);
        DebugLogger.info('✅ Allergies saved');
      }

      // 5. Save food preferences
      final foodSelections = ref.read(foodSelectionsCacheProvider);
      if (foodSelections.isNotEmpty) {
        final foodRepository = ref.read(foodRepositoryProvider);
        final allFoods = await foodRepository.getPrimaryFoodsForPreferences();

        final Map<String, FoodPreference> preferences = {};
        final Map<String, int> sliderLevels = {};

        for (final food in allFoods) {
          if (foodSelections.contains(food.id)) {
            preferences[food.name] = FoodPreference.like;
            sliderLevels[food.name] = 3;
          } else {
            preferences[food.name] = FoodPreference.willingToTry;
            sliderLevels[food.name] = 2;
          }
        }

        // Auto-set conflicting foods to "dislike" based on dietary preference and allergies
        if (_cachedDietaryPreference != null || (_cachedAllergies?.isNotEmpty ?? false)) {
          final foodsToAvoid = await foodRepository.getFoodsToAvoid(
            dietaryPreference: _cachedDietaryPreference,
            allergies: _cachedAllergies ?? [],
          );

          for (final foodName in foodsToAvoid) {
            preferences[foodName] = FoodPreference.dislike;
            sliderLevels[foodName] = 0;
          }

          if (foodsToAvoid.isNotEmpty) {
            DebugLogger.info('✅ Auto-set ${foodsToAvoid.length} foods to dislike based on diet/allergies');
          }
        }

        await _onboardingService.saveFoodPreferences(userId, preferences, sliderLevels: sliderLevels);
        DebugLogger.info('✅ Food preferences saved');
      }

      // Clear all caches
      _cachedUserProfileData = null;
      _cachedSportPreferences = null;
      _cachedDietaryPreference = null;
      _cachedAllergies = null;
      ref.read(foodSelectionsCacheProvider.notifier).clear();

      DebugLogger.info('🎉 All onboarding data saved successfully');
    });

    if (state.hasError) {
      DebugLogger.error('❌ Batch save failed: ${state.error}');
      return false;
    }

    return true;
  }

  /// Reset onboarding for testing
  Future<void> resetOnboarding() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await _onboardingService.resetOnboarding();
      _currentUser = null;

      // Clear all cached data
      _cachedUserProfileData = null;
      _cachedSelectedSports = {'running'}; // Reset to default
      _cachedSportPreferences = null;
      _cachedDietaryPreference = null;
      _cachedAllergies = null;

      // Clear the food selections cache
      ref.read(foodSelectionsCacheProvider.notifier).clear();
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
