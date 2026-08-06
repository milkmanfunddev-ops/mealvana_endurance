import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/database/database_provider.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/sync/entity_sync/user_sync_handler.dart';
import '../../../../shared/services/sync/sync_coordinator.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../../auth/application/auth_service.dart';
import '../../../auth/data/user_repository.dart';
import '../../../nutrition_plan/data/food_repository.dart';
import '../../../nutrition_plan/domain/nutrition_target_overrides.dart';
import '../../../integrations/presentation/providers/integrations_providers.dart';
import '../../../formula_kit/application/formula_library_controller.dart';
import '../../application/onboarding_service.dart';
import '../../application/onboarding_snapshot_service.dart';
import '../../data/onboarding_survey_repository.dart';
import '../../domain/dietary_preference.dart';
import '../../domain/allergy.dart';
import '../../domain/onboarding_draft.dart';
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

  /// The immutable accumulator for everything the redesigned flow collects.
  /// Screens mutate it through the typed updaters below; saveAllOnboardingData
  /// persists it in one batch after auth.
  OnboardingDraft _draft = const OnboardingDraft();

  // Legacy caches, kept only until the old screens are deleted (redesign
  // phases 4–7). cacheUserProfileData/cacheSelectedSports bridge into the
  // draft so the old flow keeps working through the new save path.
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

      // Policy (2026-07-29): we always push to Supabase, for anonymous users
      // too. This used to be a deliberate no-op ("new users don't need to sync
      // yet"), which left food preferences local-only until some unrelated sync
      // happened to run.
      //
      // Fire-and-forget so an offline device doesn't stall the save (the row is
      // already committed to Drift with needs_upload = true and retries), but
      // the upload result IS inspected and logged inside
      // [uploadOnboardingDataToSupabase] — never silently dropped.
      unawaited(uploadOnboardingDataToSupabase(currentUser.id));
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
  // DRAFT API (redesigned flow)
  // ============================================================================

  /// Current onboarding draft (immutable snapshot).
  OnboardingDraft get draft => _draft;

  /// True once the profile-bearing steps (personal info + body composition)
  /// have produced enough data to create a user. The post-onboarding auth
  /// screen uses this to distinguish "finishing onboarding" from the
  /// Settings anonymous→registered upgrade (where there is nothing to save).
  bool get hasCompletedProfileDraft =>
      _draft.gender != null &&
      _draft.birthYear != null &&
      _draft.weightPounds != null;

  void _updateDraft(OnboardingDraft next) {
    _draft = next;
    // Trigger rebuild so dependent widgets (progress, previews) refresh.
    state = const AsyncData(null);
  }

  void updateSports(Set<OnboardingSport> sports) =>
      _updateDraft(_draft.copyWith(sports: sports));

  void updateGoals(Set<OnboardingGoal> goals) =>
      _updateDraft(_draft.copyWith(goals: goals));

  void updatePitfalls(Set<OnboardingPitfall> pitfalls) =>
      _updateDraft(_draft.copyWith(pitfalls: pitfalls));

  void updatePersonalInfo({
    String? firstName,
    String? lastName,
    String? email,
    Gender? gender,
    int? birthYear,
  }) {
    _updateDraft(
      _draft.copyWith(
        firstName: () => _nullIfBlank(firstName) ?? _draft.firstName,
        lastName: () => _nullIfBlank(lastName) ?? _draft.lastName,
        email: () => _nullIfBlank(email) ?? _draft.email,
        gender: gender != null ? () => gender : null,
        birthYear: birthYear != null ? () => birthYear : null,
      ),
    );
  }

  void updateBodyComposition({
    bool? useMetricUnits,
    int? heightFeet,
    int? heightInches,
    double? weightPounds,
  }) {
    _updateDraft(
      _draft.copyWith(
        useMetricUnits: useMetricUnits,
        heightFeet: heightFeet != null ? () => heightFeet : null,
        heightInches: heightInches != null ? () => heightInches : null,
        weightPounds: weightPounds != null ? () => weightPounds : null,
      ),
    );
  }

  void updateNutritionSettings({
    GutTraining? gutTraining,
    SweatRateCat? sweatRate,
  }) {
    _updateDraft(
      _draft.copyWith(gutTraining: gutTraining, sweatRate: sweatRate),
    );
  }

  void applyPlanEdits(OnboardingPlanEdits edits) =>
      _updateDraft(_draft.copyWith(planEdits: edits));

  void recordConnectedProvider(String? provider) =>
      _updateDraft(_draft.copyWith(connectedProvider: () => provider));

  void recordDeclinedTrainingApps() =>
      _updateDraft(_draft.copyWith(declinedTrainingApps: true));

  void recordTridotNotifyRequested() =>
      _updateDraft(_draft.copyWith(tridotNotifyRequested: true));

  void recordSweatTestInterest() =>
      _updateDraft(_draft.copyWith(sweatTestInterest: true));

  static String? _nullIfBlank(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

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
    // Bridge into the draft so the old screens keep working through the new
    // draft-based save path during the redesign transition.
    _draft = _draft.copyWith(
      gender: () => gender,
      birthYear: () => birthday.year,
      heightFeet: () => heightFeet,
      heightInches: () => heightInches,
      weightPounds: () => weightPounds,
      firstName: () => firstName ?? _draft.firstName,
      lastName: () => lastName ?? _draft.lastName,
      email: () => email ?? _draft.email,
      useMetricUnits: unitSystem == UnitSystem.metric,
    );
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
    // Bridge into the draft (unknown legacy strings are dropped).
    _draft = _draft.copyWith(
      sports: {
        for (final s in sports)
          if (OnboardingSport.fromDbValue(s) case final OnboardingSport sport)
            sport,
      },
    );
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
    // without a completed profile draft (e.g. the app was relaunched
    // mid-onboarding and the in-memory draft was lost). Previously this threw
    // inside AsyncValue.guard, surfacing as an AsyncError that the Sentry
    // ProviderObserver reported (MEALVANA-ENDURANCE-DEV-4M). There is nothing to
    // save and retrying can't help, so fail cleanly and let the caller route the
    // user back to finish onboarding.
    if (!hasCompletedProfileDraft) {
      DebugLogger.info(
        '⚠️ saveAllOnboardingData: profile draft incomplete — cannot create '
        'user; returning failure without throwing.',
      );
      state = const AsyncData(null);
      return false;
    }

    final sentry = ref.read(appExternalDepsProvider).sentry;

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final draft = _draft;

      // 1. Create user profile from the draft.
      // Auto-populate email from Supabase auth if not manually provided.
      final authEmail = ref
          .read(appExternalDepsProvider)
          .supabaseClient
          .auth
          .currentUser
          ?.email
          ?.trim();
      final email =
          draft.email ??
          ((authEmail != null && authEmail.isNotEmpty) ? authEmail : null);

      sentry.addBreadcrumb(
        message: 'saveAllOnboardingData: creating user profile',
        category: 'onboarding',
      );
      _currentUser = await _onboardingService.createUserProfile(
        gender: draft.gender!,
        // Year-only birthday, documented mid-year convention (age error
        // ≤6 months ≈ ±2.5 kcal RMR).
        birthday: draft.birthday!,
        heightFeet: draft.heightFeet ?? 0,
        heightInches: draft.heightInches ?? 0,
        weightPounds: draft.weightPounds!,
        // No longer asked in the redesigned flow; keep the column populated.
        runsWithWaterBottle: false,
        gutTraining: draft.gutTraining,
        sweatRate: draft.sweatRate,
        authProvider: authProvider,
        isAnonymous: isAnonymous,
        firstName: draft.firstName,
        lastName: draft.lastName,
        email: email,
        unitSystem: draft.useMetricUnits
            ? UnitSystem.metric
            : UnitSystem.imperial,
      );
      DebugLogger.info('✅ User profile created: ${_currentUser!.id}');

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

      // 2. Default dietary preference + allergies.
      // Onboarding no longer collects diet/allergies (2026-08 redesign):
      // default omnivore/none unconditionally so downstream food filtering
      // (`getFoodsToAvoid`, FormulaLibrary allergy filter) keeps a defined
      // value; the user edits later in Settings
      // (`/settings/dietary-preference`, `/settings/allergies`).
      sentry.addBreadcrumb(
        message: 'saveAllOnboardingData: defaulting diet/allergies',
        category: 'onboarding',
      );
      await _onboardingService.saveDietaryPreference(
        userId,
        DietaryPreference.omnivore,
      );
      await _onboardingService.saveAllergies(userId, const []);
      DebugLogger.info('✅ Diet/allergy defaults saved (omnivore / none)');

      // 3. Persist the survey row (sports/goals/pitfalls + payload flags).
      // The repository reports Drift constraint failures to Sentry and
      // rethrows — a failed survey write fails the save visibly.
      sentry.addBreadcrumb(
        message: 'saveAllOnboardingData: writing survey',
        category: 'onboarding',
      );
      await ref
          .read(onboardingSurveyRepositoryProvider)
          .saveSurveyFromDraft(userId: userId, draft: draft);
      DebugLogger.info('✅ Onboarding survey saved');

      // 4. Persist plan-reveal edits as NutritionTargetOverrides — only the
      // fields the user actually touched (null = algorithm default, per the
      // overrides contract).
      if (draft.planEdits.hasAnyEdit) {
        sentry.addBreadcrumb(
          message: 'saveAllOnboardingData: writing plan-edit overrides',
          category: 'onboarding',
        );
        await _savePlanEditOverrides(userId, draft.planEdits);
        DebugLogger.info('✅ Plan-edit overrides saved');
      }

      // NOTE: onboarding no longer pre-computes or writes "default" formula
      // pins. The default formula is resolved at generation time by the
      // nutrition-plan edge function (`emit_ephemeral_default_formula`), so
      // there is nothing to seed here. Only user-created pins live in
      // `formula_pins`.

      // Best-effort local snapshot OUTSIDE Drift (SharedPreferences), so the
      // delete-and-recreate upgrade path can restore an anonymous user whose
      // data never reached Supabase (plan §7). Never fails the save.
      await ref
          .read(onboardingSnapshotServiceProvider)
          .writeSnapshot(profile: _currentUser!, draft: draft);

      // Clear the draft and legacy caches.
      _draft = const OnboardingDraft();
      _cachedUserProfileData = null;
      _cachedSportPreferences = null;
      _cachedDietaryPreference = null;
      _cachedAllergies = null;
      ref.read(foodSelectionsCacheProvider.notifier).clear();

      // Policy (2026-07-29): onboarding data ALWAYS goes to Supabase, whether
      // the user created a real account or skipped and stayed anonymous. The
      // anonymous user has a genuine Supabase anonymous-auth session (see
      // AuthService.createUser), so `auth.uid()` == `users.id` and every RLS
      // policy in 20260727120000_rls_baseline_dev.sql admits the write.
      //
      // The remaining dirty rows (allergies/diet/sport prefs written above,
      // food preferences, formula pins, integrations) are pushed by the
      // caller's post-save upload — see PostOnboardingAuthScreen. The old
      // `setSkipSyncForNewUser()` call used to live here and suppressed exactly
      // that first upload, which is why anonymous onboarding could stay local.
      DebugLogger.info('🎉 All onboarding data saved successfully');
    });

    if (state.hasError) {
      DebugLogger.error('❌ Batch save failed: ${state.error}');
      // No silent failures: the batch save is the moment onboarding data
      // becomes durable — its failure must reach Sentry even though the UI
      // also surfaces the AsyncError.
      await sentry.captureMessage(
        'saveAllOnboardingData failed',
        tags: {
          'feature': 'onboarding',
          'step': 'batch_save',
          'auth_provider': authProvider,
        },
        extra: {'error': state.error.toString()},
      );
      return false;
    }

    return true;
  }

  /// Persist the plan-reveal edits onto the user profile's
  /// `nutrition_target_overrides` JSON, merged over any existing overrides
  /// and clamped by the shared guardrails. Fluid/sodium edits apply to both
  /// run and ride contexts (one dial on the reveal screen).
  Future<void> _savePlanEditOverrides(
    String userId,
    OnboardingPlanEdits edits,
  ) async {
    final userRepository = await ref.read(userRepositoryProvider.future);
    final profile = await userRepository.getCurrentUser();
    if (profile == null) {
      throw StateError('No user profile found to attach plan edits to');
    }

    final clamped = mergedOverridesForEdits(
      profile.nutritionTargetOverrides,
      edits,
    );
    await userRepository.updateUserProfile(
      profile.copyWith(nutritionTargetOverrides: clamped),
    );
  }

  /// Pure merge of plan-reveal [edits] over [existing] overrides, clamped by
  /// the shared guardrails. Only edited fields are written; fluid/sodium
  /// apply to both run and ride contexts (one dial on the reveal screen).
  static NutritionTargetOverrides mergedOverridesForEdits(
    NutritionTargetOverrides? existing,
    OnboardingPlanEdits edits,
  ) {
    final base = existing ?? const NutritionTargetOverrides();
    final baseRun = base.duringRun ?? const DuringActivityOverrides();
    final baseRide = base.duringCycling ?? const DuringActivityOverrides();

    final updated = base.copyWith(
      duringRun: () => baseRun.copyWith(
        carbRateGPerH: edits.longRunCarbGph != null
            ? () => edits.longRunCarbGph
            : null,
        fluidRateMlPerH: edits.fluidMlPerHr != null
            ? () => edits.fluidMlPerHr
            : null,
        sodiumRateMgPerH: edits.sodiumMgPerHr != null
            ? () => edits.sodiumMgPerHr
            : null,
      ),
      duringCycling: () => baseRide.copyWith(
        carbRateGPerH: edits.longRideCarbGph != null
            ? () => edits.longRideCarbGph
            : null,
        fluidRateMlPerH: edits.fluidMlPerHr != null
            ? () => edits.fluidMlPerHr
            : null,
        sodiumRateMgPerH: edits.sodiumMgPerHr != null
            ? () => edits.sodiumMgPerHr
            : null,
      ),
    );

    return NutritionTargetGuardrails.clampAll(updated);
  }

  /// Push everything captured during onboarding up to Supabase.
  ///
  /// Called by the post-onboarding auth screen *after* it has navigated to
  /// `/main`, so it never sits between the user and the app. Runs identically
  /// for anonymous (skipped account creation) and registered users — per the
  /// 2026-07-29 policy, onboarding data always reaches Supabase.
  ///
  /// Uses the sanctioned offline-first path: every row was already written to
  /// Drift with `needs_upload = true`, and this walks the repository dependency
  /// graph pushing dirty records in FK-safe order. The result is CHECKED —
  /// `uploadDirtyRecords()` swallows exceptions into a silent
  /// `UploadResult.failed()`, so an unchecked call cannot tell success from
  /// total failure. Rows that fail stay dirty and retry on the next sync.
  ///
  /// Returns the repository keys that did not make it (empty == everything
  /// uploaded).
  Future<List<String>> uploadOnboardingDataToSupabase(String userId) async {
    final coordinator = ref.read(syncCoordinatorProvider.notifier);

    final failedRepos = await coordinator.uploadAllDirtyRecords(userId);

    if (failedRepos.isEmpty) {
      DebugLogger.info('📤 Onboarding data uploaded to Supabase');
    } else {
      DebugLogger.error(
        '⚠️ Onboarding data upload incomplete — repositories still dirty: '
        '${failedRepos.join(", ")} (userId=$userId). '
        'Rows remain marked needs_upload and will retry on the next sync.',
      );
    }

    return failedRepos;
  }

  /// Reset onboarding for testing
  Future<void> resetOnboarding() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await _onboardingService.resetOnboarding();
      _currentUser = null;

      // Clear the draft and all cached data
      _draft = const OnboardingDraft();
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

  /// Upload user profile to Supabase immediately after creation.
  ///
  /// This ensures the user exists in Supabase BEFORE navigating to main screen.
  /// Prevents FK violations when activities/integrations are uploaded later.
  ///
  /// Runs for anonymous users too — an anonymous user is a real Supabase auth
  /// user, so this row is what makes every dependent upload (activities,
  /// integrations, food preferences, formula pins) satisfy both its FK and its
  /// `id = auth.uid()` RLS check.
  ///
  /// Returns true when the row is known to be in Supabase. Failure is
  /// non-fatal (the local row keeps `needs_upload = true` and the caller's
  /// post-save upload retries) but is reported rather than swallowed:
  /// [UserSyncHandler.uploadUserProfile] deliberately does not rethrow, so the
  /// only reliable success signal is whether the dirty flag got cleared.
  Future<bool> _uploadUserProfileToSupabase(String userId) async {
    try {
      final userSyncHandler = ref.read(userSyncHandlerProvider);
      final database = ref.read(appDatabaseProvider);

      Future<UserProfileEntry?> readProfile() => (database.select(
        database.userProfilesTable,
      )..where((t) => t.id.equals(userId))).getSingleOrNull();

      final userProfile = await readProfile();
      if (userProfile == null) {
        DebugLogger.warning('⚠️ No user profile found to upload');
        return false;
      }

      DebugLogger.info('📤 Uploading user profile to Supabase...');
      await userSyncHandler.uploadUserProfile(userProfile);

      // uploadUserProfile() clears needs_upload only on a successful upsert, so
      // a still-dirty row means the push failed even though nothing threw.
      final uploaded = (await readProfile())?.needsUpload == false;
      if (uploaded) {
        DebugLogger.info('✅ User profile uploaded to Supabase successfully');
      } else {
        DebugLogger.error(
          '⚠️ User profile upload did not reach Supabase (still dirty) '
          '— deferring to post-onboarding upload. userId=$userId',
        );
      }
      return uploaded;
    } catch (e) {
      // Don't fail onboarding if upload fails - the post-save upload and later
      // syncs retry it. But log it, as this may cause FK violations meanwhile.
      DebugLogger.error('⚠️ Failed to upload user profile to Supabase: $e');
      DebugLogger.warning(
        '⚠️ This may cause FK violations when syncing activities',
      );
      return false;
    }
  }
}

/// Provider for onboarding progress
@riverpod
Future<OnboardingProgress> onboardingProgress(Ref ref) async {
  final controller = ref.watch(onboardingControllerProvider.notifier);
  return await controller.getProgress();
}
