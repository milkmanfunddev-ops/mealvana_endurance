import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';
import '../../../../shared/database/database_provider.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/sync/entity_sync/user_sync_handler.dart';
import '../../../../shared/services/sync/sync_coordinator.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../../auth/application/auth_service.dart';
import '../../../nutrition_plan/data/food_repository.dart';
import '../../../integrations/presentation/providers/integrations_providers.dart';
import '../../../formula_kit/application/formula_library_controller.dart';
import '../../application/onboarding_formula_pin_service.dart';
import '../../application/onboarding_service.dart';
import '../../domain/dietary_preference.dart';
import '../../domain/allergy.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';
import 'food_selections_cache_provider.dart';

part 'onboarding_controller.g.dart';

/// Key for storing temporary user ID in shared preferences during onboarding
/// Must match the key in connect_training_controller.dart
const _onboardingTempUserIdKey = 'onboarding_temp_user_id';

/// Controller for managing onboarding flow state
@riverpod
class OnboardingController extends _$OnboardingController {
  OnboardingService get _onboardingService =>
      ref.read(onboardingServiceProvider);
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
    String authProvider =
        'anonymous', // 'anonymous', 'email', 'google', 'apple'
    bool isAnonymous = true, // false when user signs up with email/OAuth
    UnitSystem unitSystem = UnitSystem.imperial,
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
        authProvider: authProvider,
        isAnonymous: isAnonymous,
        unitSystem: unitSystem,
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

    DebugLogger.debug(
      '👤 Sport preferences - Current user: ${currentUser?.id ?? "null"}',
    );

    if (currentUser == null) {
      final errorMsg = _contentService.getValue(
        ContentKeys.errorGeneric,
        defaultValue:
            'No user profile found. Please complete user profile first.',
      );
      DebugLogger.error('❌ Sport preferences - No current user found');
      state = AsyncError(errorMsg, StackTrace.current);
      return false;
    }

    DebugLogger.info(
      '🚀 Sport preferences - Starting save process for user: ${currentUser.id}',
    );
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
      DebugLogger.debug(
        '📍 Sport preferences - Stack trace: ${state.stackTrace}',
      );
    } else {
      DebugLogger.info(
        '🎉 Sport preferences - Save operation completed without errors',
      );
    }

    return !state.hasError;
  }

  /// Save dietary preference (step 3a of onboarding)
  /// When called from settings, also updates food preferences for excluded foods
  /// Removes auto-avoided foods when dietary preference changes (using preference_source tracking)
  Future<bool> saveDietaryPreference(DietaryPreference? preference) async {
    // Get current user from auth service (works for both session users and restored users)
    final currentUser = _currentUser ?? await _authService.getCurrentUser();

    DebugLogger.debug(
      '👤 Dietary preference - Current user: ${currentUser?.id ?? "null"}',
    );
    DebugLogger.debug('🥗 Dietary preference: ${preference?.name ?? "none"}');

    if (currentUser == null) {
      final errorMsg = _contentService.getValue(
        ContentKeys.errorGeneric,
        defaultValue:
            'No user profile found. Please complete user profile first.',
      );
      DebugLogger.error('❌ Dietary preference - No current user found');
      state = AsyncError(errorMsg, StackTrace.current);
      return false;
    }

    // Get old dietary preference to determine if it changed
    final oldPreference = currentUser.dietaryPreference;
    final preferenceChanged = oldPreference != preference;

    DebugLogger.info(
      '🚀 Dietary preference - Starting save process for user: ${currentUser.id}',
    );
    DebugLogger.debug(
      '📋 Dietary preference - Old: ${oldPreference?.displayName ?? "none"}, New: ${preference?.displayName ?? "none"}',
    );
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      DebugLogger.debug('📞 Dietary preference - Calling onboarding service');
      await _onboardingService.saveDietaryPreference(
        currentUser.id,
        preference,
      );
      DebugLogger.info('✅ Dietary preference - Save completed successfully');
      // Update our session user reference
      _currentUser = currentUser;

      // If dietary preference changed, remove old preference-based food avoids
      if (preferenceChanged &&
          oldPreference != null &&
          oldPreference != DietaryPreference.none) {
        final removedCount = await _authService.removeFoodPreferencesBySource(
          currentUser.id,
          'dietary:${oldPreference.dbValue}',
        );
        DebugLogger.info(
          '🗑️ Removed $removedCount food avoids for old diet: ${oldPreference.displayName}',
        );
      }

      // Add food preferences for new dietary preference only
      if (preferenceChanged &&
          preference != null &&
          preference != DietaryPreference.none) {
        await _updateFoodPreferencesForAllergies(
          currentUser.id,
          [], // Don't update allergies in dietary save
          preference,
        );
      }
    });

    if (state.hasError) {
      DebugLogger.error(
        '❌ Dietary preference - Error occurred: ${state.error}',
      );
      DebugLogger.debug(
        '📍 Dietary preference - Stack trace: ${state.stackTrace}',
      );
    } else {
      DebugLogger.info(
        '🎉 Dietary preference - Save operation completed without errors',
      );
    }

    return !state.hasError;
  }

  /// Save allergies (step 3b of onboarding)
  /// When called from settings, also updates food preferences for allergen-containing foods
  /// Removes auto-avoided foods when allergies are removed (using preference_source tracking)
  Future<bool> saveAllergies(List<Allergy> allergies) async {
    // Get current user from auth service (works for both session users and restored users)
    final currentUser = _currentUser ?? await _authService.getCurrentUser();

    DebugLogger.debug(
      '👤 Allergies - Current user: ${currentUser?.id ?? "null"}',
    );
    DebugLogger.debug('⚠️ Allergies count: ${allergies.length}');

    if (currentUser == null) {
      final errorMsg = _contentService.getValue(
        ContentKeys.errorGeneric,
        defaultValue:
            'No user profile found. Please complete user profile first.',
      );
      DebugLogger.error('❌ Allergies - No current user found');
      state = AsyncError(errorMsg, StackTrace.current);
      return false;
    }

    // Get old allergies to determine which ones were removed
    final oldAllergies = currentUser.allergies;
    final newAllergies = allergies.toSet();
    final removedAllergies = oldAllergies
        .where((a) => !newAllergies.contains(a))
        .toList();
    final addedAllergies = newAllergies
        .where((a) => !oldAllergies.contains(a))
        .toList();

    DebugLogger.info(
      '🚀 Allergies - Starting save process for user: ${currentUser.id}',
    );
    DebugLogger.debug(
      '📋 Allergies - Removed: ${removedAllergies.map((a) => a.displayName).join(', ')}',
    );
    DebugLogger.debug(
      '📋 Allergies - Added: ${addedAllergies.map((a) => a.displayName).join(', ')}',
    );
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
        DebugLogger.info(
          '🗑️ Removed $removedCount food avoids for allergy: ${removedAllergy.displayName}',
        );
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
      DebugLogger.info(
        '🎉 Allergies - Save operation completed without errors',
      );
      // Invalidate the Formula Library so it picks up the new user.allergies
      // on next watch. The controller's build() reads user.allergies once and
      // caches it; without this invalidation, the library keeps showing
      // formulas the user is allergic to until the next cold start.
      ref.invalidate(formulaLibraryControllerProvider);
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

          DebugLogger.info(
            '🍎 Set ${allergyFoods.length} foods to avoid for allergy: ${allergy.displayName}',
          );
        }
      }

      // Process dietary preference if set
      if (dietaryPreference != null &&
          dietaryPreference != DietaryPreference.none) {
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

          DebugLogger.info(
            '🥗 Set ${dietaryFoods.length} foods to avoid for diet: ${dietaryPreference.displayName}',
          );
        }
      }

      DebugLogger.info(
        '✅ Food preferences updated for allergen/dietary restrictions',
      );
    } catch (e, stackTrace) {
      DebugLogger.error(
        '❌ Failed to update food preferences for allergies: $e',
      );
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

    DebugLogger.debug(
      '👤 Food preferences - Current user: ${currentUser?.id ?? "null"}',
    );
    DebugLogger.debug('🍎 Food preferences - Count: ${preferences.length}');

    if (currentUser == null) {
      final errorMsg = _contentService.getValue(
        ContentKeys.errorGeneric,
        defaultValue:
            'No user profile found. Please complete user profile first.',
      );
      DebugLogger.error('❌ Food preferences - No current user found');
      state = AsyncError(errorMsg, StackTrace.current);
      return false;
    }

    DebugLogger.info(
      '🚀 Food preferences - Starting save process for user: ${currentUser.id}',
    );
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
      DebugLogger.debug(
        '📍 Food preferences - Stack trace: ${state.stackTrace}',
      );
    } else {
      DebugLogger.info(
        '🎉 Food preferences - Save operation completed without errors',
      );
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
    String? firstName,
    String? lastName,
    String? email,
    UnitSystem unitSystem = UnitSystem.imperial,
  }) {
    _cachedUserProfileData = {
      'gender': gender,
      'birthday': birthday,
      'heightFeet': heightFeet,
      'heightInches': heightInches,
      'weightPounds': weightPounds,
      'runsWithWaterBottle': runsWithWaterBottle,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'unitSystem': unitSystem,
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
    DebugLogger.debug(
      '📝 Cached dietary preference: ${preference?.name ?? "none"}',
    );
  }

  /// Cache allergies (don't save to DB yet)
  void cacheAllergies(List<Allergy> allergies) {
    _cachedAllergies = allergies;
    DebugLogger.debug('📝 Cached ${allergies.length} allergies');
  }

  /// Cache selected sports
  void cacheSelectedSports(Set<String> sports) {
    _cachedSelectedSports = sports;
    DebugLogger.debug(
      '📝 Cached ${sports.length} sports: ${sports.join(", ")}',
    );
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
  /// [authProvider] - 'anonymous', 'email', 'google', 'apple'
  /// [isAnonymous] - false when user signs up with email/OAuth
  Future<bool> saveAllOnboardingData({
    String authProvider = 'anonymous',
    bool isAnonymous = true,
  }) async {
    DebugLogger.info(
      '📦 Starting batch save of all onboarding data (authProvider: $authProvider, isAnonymous: $isAnonymous)',
    );

    // Guard the invalid state where the user reached the post-onboarding screen
    // without a cached profile (e.g. the app was relaunched mid-onboarding and
    // the in-memory cache was lost). Previously this threw inside
    // AsyncValue.guard, surfacing as an AsyncError that the Sentry
    // ProviderObserver reported (MEALVANA-ENDURANCE-DEV-4M). There is nothing to
    // save and retrying can't help, so fail cleanly and let the caller route the
    // user back to finish onboarding.
    if (_cachedUserProfileData == null) {
      DebugLogger.info(
        '⚠️ saveAllOnboardingData: no cached user profile — cannot create '
        'user; returning failure without throwing.',
      );
      state = const AsyncData(null);
      return false;
    }

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      // 1. Create user profile
      {
        final data = _cachedUserProfileData!;
        // Auto-populate email from Supabase auth if not manually provided
        final cachedEmail = (data['email'] as String?)?.trim();
        final authEmail = ref
            .read(appExternalDepsProvider)
            .supabaseClient
            .auth
            .currentUser
            ?.email
            ?.trim();
        final email = (cachedEmail != null && cachedEmail.isNotEmpty)
            ? cachedEmail
            : ((authEmail != null && authEmail.isNotEmpty) ? authEmail : null);
        _currentUser = await _onboardingService.createUserProfile(
          gender: data['gender'] as Gender,
          birthday: data['birthday'] as DateTime,
          heightFeet: data['heightFeet'] as int,
          heightInches: data['heightInches'] as int,
          weightPounds: data['weightPounds'] as double,
          runsWithWaterBottle: data['runsWithWaterBottle'] as bool,
          authProvider: authProvider,
          isAnonymous: isAnonymous,
          firstName: data['firstName'] as String?,
          lastName: data['lastName'] as String?,
          email: email,
          unitSystem: data['unitSystem'] as UnitSystem? ?? UnitSystem.imperial,
        );
        DebugLogger.info('✅ User profile created: ${_currentUser!.id}');
      }

      final userId = _currentUser!.id;

      // 1.5. Migrate any activities/integrations created during onboarding
      // This handles the case where TrainingPeaks was connected before the
      // user profile was finalized, resulting in activities under a different user_id
      await _migrateOnboardingDataToNewUser(userId);

      // 1.6. Upload user profile to Supabase IMMEDIATELY
      // This ensures user exists in Supabase before any sync can occur
      // Prevents FK violations when activities are uploaded later
      await _uploadUserProfileToSupabase(userId);

      // 1.7. If Garmin was connected during onboarding, upsert the
      // garmin_user_mappings row now that the user profile exists in Supabase.
      await _syncGarminMappingIfNeeded(userId);

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
        await _onboardingService.saveDietaryPreference(
          userId,
          _cachedDietaryPreference,
        );
        DebugLogger.info('✅ Dietary preference saved');
      }

      // 4. Save allergies
      if (_cachedAllergies != null) {
        await _onboardingService.saveAllergies(userId, _cachedAllergies!);
        DebugLogger.info('✅ Allergies saved');
      }

      // 4.5. Auto-pin default system formulas for the user's primary sport so
      // a new user starts out formula-first with owned, editable formulas
      // (plan Phase 1 #3). Best-effort — the service swallows failures so it
      // can never block onboarding; the generation-time ephemeral safety net
      // covers anyone this skips.
      {
        final diet =
            (_cachedDietaryPreference != null &&
                _cachedDietaryPreference != DietaryPreference.none)
            ? _cachedDietaryPreference!.dbValue
            : null;
        final allergies =
            _cachedAllergies?.map((a) => a.dbValue).toList(growable: false) ??
            const <String>[];
        await ref
            .read(onboardingFormulaPinServiceProvider)
            .autoPinDefaults(
              userId: userId,
              selectedSports: cachedSelectedSports,
              diet: diet,
              allergies: allergies,
            );
        DebugLogger.info('✅ Default formulas auto-pin attempted');
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
        if (_cachedDietaryPreference != null ||
            (_cachedAllergies?.isNotEmpty ?? false)) {
          final foodsToAvoid = await foodRepository.getFoodsToAvoid(
            dietaryPreference: _cachedDietaryPreference,
            allergies: _cachedAllergies ?? [],
          );

          for (final foodName in foodsToAvoid) {
            preferences[foodName] = FoodPreference.dislike;
            sliderLevels[foodName] = 0;
          }

          if (foodsToAvoid.isNotEmpty) {
            DebugLogger.info(
              '✅ Auto-set ${foodsToAvoid.length} foods to dislike based on diet/allergies',
            );
          }
        }

        await _onboardingService.saveFoodPreferences(
          userId,
          preferences,
          sliderLevels: sliderLevels,
        );
        DebugLogger.info('✅ Food preferences saved');
      }

      // Clear all caches
      _cachedUserProfileData = null;
      _cachedSportPreferences = null;
      _cachedDietaryPreference = null;
      _cachedAllergies = null;
      ref.read(foodSelectionsCacheProvider.notifier).clear();

      // Set flag to skip sync on first navigation to main
      // New users have all data locally - nothing to download from Supabase
      ref.read(syncCoordinatorProvider.notifier).setSkipSyncForNewUser();
      DebugLogger.info(
        '🚫 Set skip sync flag - sync will be skipped for new user',
      );

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
    return _contentService.getValue(
      ContentKeys.errorGeneric,
      defaultValue: error ?? 'Something went wrong. Please try again.',
    );
  }

  /// Migrate all data created during onboarding to the new user profile
  ///
  /// During onboarding, a user might connect TrainingPeaks before their profile
  /// is finalized. Activities, events, food preferences, integrations, etc. are
  /// saved with a temporary user ID generated by ConnectTrainingController.
  ///
  /// This method uses the consolidated `migrateUserData` in AppDatabase which
  /// handles migration for ALL user-scoped tables:
  /// - Activities
  /// - Events
  /// - Food preferences
  /// - User foods (custom foods)
  /// - Carb loading plans
  /// - Survey responses
  /// - Integrations
  Future<void> _migrateOnboardingDataToNewUser(String newUserId) async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final database = ref.read(appDatabaseProvider);

      // Get the temp user ID that was used during onboarding
      final tempUserId = prefs.getString(_onboardingTempUserIdKey);

      if (tempUserId == null) {
        DebugLogger.info('ℹ️ No temp user ID found - skipping migration');
        return;
      }

      if (tempUserId == newUserId) {
        DebugLogger.info(
          'ℹ️ Temp user ID matches new user ID - no migration needed',
        );
        await prefs.remove(_onboardingTempUserIdKey);
        return;
      }

      DebugLogger.info(
        '🔄 Migrating ALL onboarding data from temp user $tempUserId to new user $newUserId',
      );

      // Use the consolidated migration method that handles ALL user-scoped tables
      await database.diagnosticDao.migrateUserData(tempUserId, newUserId);

      // Clear the temp user ID from preferences
      await prefs.remove(_onboardingTempUserIdKey);

      DebugLogger.info(
        '✅ Migration complete - all user data migrated and temp user ID cleared',
      );
    } catch (e) {
      // Don't fail onboarding if migration fails - log and continue
      DebugLogger.error('⚠️ Failed to migrate onboarding data: $e');
    }
  }

  /// Upsert garmin_user_mappings in Supabase if Garmin was connected during onboarding.
  ///
  /// During onboarding the remote mapping upsert is skipped (temp user ID
  /// doesn't satisfy RLS / FK constraints). Now that the real user profile
  /// exists in Supabase, we can create the mapping so the push handler
  /// can route incoming Garmin data.
  Future<void> _syncGarminMappingIfNeeded(String userId) async {
    try {
      final garminOAuth = ref.read(garminOAuthServiceProvider);
      await garminOAuth.upsertUserMapping(userId);
    } catch (e) {
      // Don't fail onboarding — push data will just queue on Garmin's side
      DebugLogger.error('⚠️ Failed to sync Garmin user mapping: $e');
    }
  }

  /// Upload user profile to Supabase immediately after creation
  ///
  /// This ensures the user exists in Supabase BEFORE navigating to main screen.
  /// Prevents FK violations when activities/integrations are uploaded later.
  Future<void> _uploadUserProfileToSupabase(String userId) async {
    try {
      final userSyncHandler = ref.read(userSyncHandlerProvider);
      final database = ref.read(appDatabaseProvider);

      // Get the user profile entry from the database using direct query
      final userProfiles = await (database.select(
        database.userProfilesTable,
      )..where((t) => t.id.equals(userId))).get();

      if (userProfiles.isEmpty) {
        DebugLogger.warning('⚠️ No user profile found to upload');
        return;
      }

      final userProfile = userProfiles.first;
      DebugLogger.info('📤 Uploading user profile to Supabase...');
      await userSyncHandler.uploadUserProfile(userProfile);
      DebugLogger.info('✅ User profile uploaded to Supabase successfully');
    } catch (e) {
      // Don't fail onboarding if upload fails - sync will handle it later
      // But log it as this may cause FK violations
      DebugLogger.error('⚠️ Failed to upload user profile to Supabase: $e');
      DebugLogger.warning(
        '⚠️ This may cause FK violations when syncing activities',
      );
    }
  }
}

/// Provider for onboarding progress
@riverpod
Future<OnboardingProgress> onboardingProgress(Ref ref) async {
  final controller = ref.watch(onboardingControllerProvider.notifier);
  return await controller.getProgress();
}
