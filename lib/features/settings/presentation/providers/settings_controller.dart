import 'dart:async';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show HttpMethod;
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/sync/sync_coordinator.dart';
import '../../../auth/application/supabase_auth_service.dart';
import '../../../auth/data/user_repository.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../../nutrition_plan/domain/run_parameters.dart';
import '../../../onboarding/domain/dietary_preference.dart';
import '../../../onboarding/domain/allergy.dart';
import '../../../coach_mode/data/coach_repository.dart';
import '../../domain/settings_state.dart';

part 'settings_controller.g.dart';

/// Key for storing temporary user ID in shared preferences during onboarding
/// Must match the key in connect_training_controller.dart and onboarding_controller.dart
const _onboardingTempUserIdKey = 'onboarding_temp_user_id';

/// Controller for settings screen following Andrea Bizzotto FOA patterns
@riverpod
class SettingsController extends _$SettingsController {
  ContentService get _contentService => ref.read(contentServiceProvider);
  Future<UserRepository> get _userRepository async =>
      await ref.read(userRepositoryProvider.future);
  CoachRepository get _coachRepository => ref.read(coachRepositoryProvider);

  /// Check if user is an approved coach by querying the local coaches table
  Future<bool> _checkIsApprovedCoach(String? userId) async {
    if (userId == null) return false;
    return await _coachRepository.isUserApprovedCoach(userId);
  }

  @override
  FutureOr<SettingsState> build() async {
    // Watch auth state to trigger rebuilds on sign in/out
    final authUserAsync = ref.watch(currentUserProvider);

    // Load content synchronously from in-memory cache
    final title = _contentService.getValue(
      ContentKeys.settingsTitle,
      defaultValue: 'Settings',
    );
    final accountSectionTitle = _contentService.getValue(
      ContentKeys.settingsAccountSection,
      defaultValue: 'Account',
    );
    final accountStatusAnonymous = _contentService.getValue(
      ContentKeys.settingsAccountStatusAnonymous,
      defaultValue: 'Not signed in',
    );
    final accountStatusAuthenticated = _contentService.getValue(
      ContentKeys.settingsAccountStatusAuthenticated,
      defaultValue: 'Signed in',
    );
    final createAccountButton = _contentService.getValue(
      ContentKeys.settingsCreateAccountButton,
      defaultValue: 'Create Account',
    );
    final signOutButton = _contentService.getValue(
      ContentKeys.settingsSignOutButton,
      defaultValue: 'Sign Out',
    );
    final profileSectionTitle = _contentService.getValue(
      ContentKeys.settingsProfileSection,
      defaultValue: 'Profile',
    );
    final preferenceSectionTitle = _contentService.getValue(
      ContentKeys.settingsPreferencesSection,
      defaultValue: 'Preferences',
    );
    final genderLabel = _contentService.getValue(
      ContentKeys.settingsGenderLabel,
      defaultValue: 'Gender',
    );
    final birthdayLabel = _contentService.getValue(
      ContentKeys.settingsBirthdayLabel,
      defaultValue: 'Birthday',
    );
    final heightLabel = _contentService.getValue(
      ContentKeys.settingsHeightLabel,
      defaultValue: 'Height',
    );
    final weightLabel = _contentService.getValue(
      ContentKeys.settingsWeightLabel,
      defaultValue: 'Weight',
    );
    final waterBottleLabel = _contentService.getValue(
      ContentKeys.settingsWaterBottleLabel,
      defaultValue: 'Run with water bottle',
    );
    final distanceUnitLabel = _contentService.getValue(
      ContentKeys.settingsDistanceUnitLabel,
      defaultValue: 'Distance unit',
    );
    final paceUnitLabel = _contentService.getValue(
      ContentKeys.settingsPaceUnitLabel,
      defaultValue: 'Pace unit',
    );
    final gutTrainingLabel = _contentService.getValue(
      ContentKeys.settingsGutTrainingLabel,
      defaultValue: 'Gut training level',
    );
    final saveButtonText = _contentService.getValue(
      ContentKeys.settingsSaveButton,
      defaultValue: 'Save Changes',
    );

    // Load current user profile
    final userRepository = await _userRepository;
    final userProfile = await userRepository.getCurrentUser();

    // Get Supabase user for email from the watched provider if available
    final supabaseUser = authUserAsync.asData?.value;

    UserProfile? displayProfile = userProfile;

    if (supabaseUser != null) {
      final profileMatchesAuth =
          displayProfile != null &&
          (displayProfile.authUserId == supabaseUser.id ||
              displayProfile.id == supabaseUser.id);

      if (!profileMatchesAuth) {
        // Prefer a direct lookup by auth_user_id when user is authenticated.
        final profileByAuthId = await userRepository.getUserProfileByAuthUserId(
          supabaseUser.id,
        );

        if (profileByAuthId != null) {
          displayProfile = profileByAuthId;
        } else {
          // Fall back to matching on the primary key (id == Supabase user id),
          // which is how anonymous users are stored.
          final profileById = await userRepository.getUserProfileById(
            supabaseUser.id,
          );
          if (profileById != null) {
            displayProfile = profileById;
          }
        }
      }

      // As a final fallback (e.g. during sync races) refresh the latest local user.
      final needsFreshProfile =
          displayProfile == null ||
          (displayProfile.authUserId != null &&
              displayProfile.authUserId != supabaseUser.id);

      if (needsFreshProfile) {
        final freshProfile = await userRepository.getCurrentUser();
        if (freshProfile != null) {
          displayProfile = freshProfile;
        }
      }
    }

    return SettingsState(
      title: title,
      accountSectionTitle: accountSectionTitle,
      accountStatusAnonymous: accountStatusAnonymous,
      accountStatusAuthenticated: accountStatusAuthenticated,
      createAccountButton: createAccountButton,
      signOutButton: signOutButton,
      profileSectionTitle: profileSectionTitle,
      preferenceSectionTitle: preferenceSectionTitle,
      genderLabel: genderLabel,
      birthdayLabel: birthdayLabel,
      heightLabel: heightLabel,
      weightLabel: weightLabel,
      waterBottleLabel: waterBottleLabel,
      distanceUnitLabel: distanceUnitLabel,
      paceUnitLabel: paceUnitLabel,
      gutTrainingLabel: gutTrainingLabel,
      saveButtonText: saveButtonText,
      // User data
      gender: displayProfile?.gender,
      birthday: displayProfile?.birthday,
      heightFeet: displayProfile?.heightFeet,
      heightInches: displayProfile?.heightInches,
      weightPounds: displayProfile?.weightPounds,
      runsWithWaterBottle: displayProfile?.runsWithWaterBottle ?? false,
      // Default preferences - TODO: load from user preferences
      preferredDistanceUnit: DistanceUnit.miles,
      preferredPaceUnit: PaceUnit.minPerMile,
      gutTrainingLevel: displayProfile?.gutTraining ?? GutTraining.moderate,
      sweatRate: displayProfile?.sweatRate ?? SweatRateCat.medium,
      // Sport preferences
      giSensitivity: displayProfile?.giSensitivity,
      ftpWatts: displayProfile?.ftpWatts,
      typicalBikeBottles: displayProfile?.typicalBikeBottles,
      hasAeroBottle: displayProfile?.hasAeroBottle,
      hasBentoBox: displayProfile?.hasBentoBox,
      cssPacePer100mSeconds: displayProfile?.cssPacePer100mSeconds,
      typicalWetsuit: displayProfile?.typicalWetsuit,
      typicalSwimCapType: displayProfile?.typicalSwimCapType,
      // Dietary preferences and allergies
      dietaryPreference: displayProfile?.dietaryPreference,
      allergies: displayProfile?.allergies ?? [],
      // User identity fields (needed for database operations)
      userId: displayProfile?.id,
      createdAt: displayProfile?.createdAt,
      updatedAt: displayProfile?.updatedAt,
      // Auth fields
      isAnonymous: displayProfile?.isAnonymous ?? true,
      authProvider: displayProfile?.authProvider ?? 'anonymous',
      authUserId: displayProfile?.authUserId,
      email: supabaseUser?.email,
      // Coach mode - check coaches table for approved status
      isCoach: await _checkIsApprovedCoach(displayProfile?.id),
      // Optional name fields for coach mode athlete identification
      firstName: displayProfile?.firstName,
      lastName: displayProfile?.lastName,
    );
  }

  /// Update gender
  Future<void> updateGender(Gender gender) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(gender: gender, isSaving: true));

    await _saveProfile();
  }

  /// Update birthday
  Future<void> updateBirthday(DateTime birthday) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(
      currentState.copyWith(birthday: birthday, isSaving: true),
    );

    await _saveProfile();
  }

  /// Update height
  Future<void> updateHeight(int feet, int inches) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(
      currentState.copyWith(
        heightFeet: feet,
        heightInches: inches,
        isSaving: true,
      ),
    );

    await _saveProfile();
  }

  /// Update weight
  Future<void> updateWeight(double pounds) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(
      currentState.copyWith(weightPounds: pounds, isSaving: true),
    );

    await _saveProfile();
  }

  /// Update water bottle preference
  Future<void> updateWaterBottle(bool runsWithWaterBottle) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(
      currentState.copyWith(
        runsWithWaterBottle: runsWithWaterBottle,
        isSaving: true,
      ),
    );

    await _saveProfile();
  }

  /// Update distance unit preference
  Future<void> updateDistanceUnit(DistanceUnit unit) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(
      currentState.copyWith(preferredDistanceUnit: unit, isSaving: true),
    );

    await _saveProfile();
  }

  /// Update pace unit preference
  Future<void> updatePaceUnit(PaceUnit unit) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(
      currentState.copyWith(preferredPaceUnit: unit, isSaving: true),
    );

    await _saveProfile();
  }

  /// Update gut training level
  Future<void> updateGutTraining(GutTraining level) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(
      currentState.copyWith(gutTrainingLevel: level, isSaving: true),
    );

    await _saveProfile();
  }

  /// Update sweat rate
  Future<void> updateSweatRate(SweatRateCat sweatRate) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(
      currentState.copyWith(sweatRate: sweatRate, isSaving: true),
    );

    await _saveProfile();
  }

  /// Save all preferences in a single batch operation
  /// This avoids multiple invalidations that cause excessive UI refreshes
  Future<void> saveAllPreferences({
    Gender? gender,
    DateTime? birthday,
    int? heightFeet,
    int? heightInches,
    double? weightPounds,
    bool? runsWithWaterBottle,
    DistanceUnit? preferredDistanceUnit,
    PaceUnit? preferredPaceUnit,
    GutTraining? gutTrainingLevel,
    SweatRateCat? sweatRate,
    String? firstName,
    String? lastName,
  }) async {
    final currentState = state.value;
    if (currentState == null) return;

    // Update state with all changes at once
    state = AsyncData(
      currentState.copyWith(
        gender: gender ?? currentState.gender,
        birthday: birthday ?? currentState.birthday,
        heightFeet: heightFeet ?? currentState.heightFeet,
        heightInches: heightInches ?? currentState.heightInches,
        weightPounds: weightPounds ?? currentState.weightPounds,
        runsWithWaterBottle: runsWithWaterBottle ?? currentState.runsWithWaterBottle,
        preferredDistanceUnit: preferredDistanceUnit ?? currentState.preferredDistanceUnit,
        preferredPaceUnit: preferredPaceUnit ?? currentState.preferredPaceUnit,
        gutTrainingLevel: gutTrainingLevel ?? currentState.gutTrainingLevel,
        sweatRate: sweatRate ?? currentState.sweatRate,
        firstName: firstName,
        lastName: lastName,
        isSaving: true,
      ),
    );

    // Single save and invalidation
    await _saveProfile();
  }

  /// Update GI sensitivity
  Future<void> updateGISensitivity(bool giSensitivity) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(
      currentState.copyWith(giSensitivity: giSensitivity, isSaving: true),
    );

    await _saveProfile();
  }

  /// Update cycling preferences
  Future<void> updateCyclingPreferences({
    int? ftpWatts,
    int? typicalBikeBottles,
    bool? hasAeroBottle,
    bool? hasBentoBox,
  }) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(
      currentState.copyWith(
        ftpWatts: ftpWatts,
        typicalBikeBottles: typicalBikeBottles,
        hasAeroBottle: hasAeroBottle,
        hasBentoBox: hasBentoBox,
        isSaving: true,
      ),
    );

    await _saveProfile();
  }

  /// Update swimming preferences
  Future<void> updateSwimmingPreferences({
    int? cssPacePer100mSeconds,
    bool? typicalWetsuit,
    String? typicalSwimCapType,
  }) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(
      currentState.copyWith(
        cssPacePer100mSeconds: cssPacePer100mSeconds,
        typicalWetsuit: typicalWetsuit,
        typicalSwimCapType: typicalSwimCapType,
        isSaving: true,
      ),
    );

    await _saveProfile();
  }

  /// Save all sport settings (consolidated save for sport settings screen)
  /// This is called when the user clicks the "Save" button on the sport settings screen
  Future<void> saveSportSettings() async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isSaving: true));

    // The individual update methods already save to local database
    // Just need to trigger a final save to ensure everything is persisted
    await _saveProfile();
  }

  /// Update dietary preference
  Future<void> updateDietaryPreference(DietaryPreference? preference) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(
      currentState.copyWith(dietaryPreference: preference, isSaving: true),
    );

    await _saveProfile();
  }

  /// Update allergies
  Future<void> updateAllergies(List<Allergy> allergies) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(
      currentState.copyWith(allergies: allergies, isSaving: true),
    );

    await _saveProfile();
  }

  /// Save profile changes (both local and Supabase)
  Future<void> _saveProfile() async {
    final currentState = state.value;
    if (currentState == null) return;

    state = await AsyncValue.guard(() async {
      final userRepository = await _userRepository;
      final existingProfile = await userRepository.getCurrentUser();

      if (existingProfile == null) {
        throw Exception('No user profile found to update.');
      }

      final updatedProfile = existingProfile.copyWith(
        gender: currentState.gender ?? existingProfile.gender,
        birthday: currentState.birthday ?? existingProfile.birthday,
        heightFeet: currentState.heightFeet ?? existingProfile.heightFeet,
        heightInches: currentState.heightInches ?? existingProfile.heightInches,
        weightPounds: currentState.weightPounds ?? existingProfile.weightPounds,
        runsWithWaterBottle: currentState.runsWithWaterBottle,
        gutTraining: currentState.gutTrainingLevel,
        sweatRate: currentState.sweatRate,
        giSensitivity: currentState.giSensitivity ?? existingProfile.giSensitivity,
        ftpWatts: currentState.ftpWatts ?? existingProfile.ftpWatts,
        typicalBikeBottles: currentState.typicalBikeBottles ?? existingProfile.typicalBikeBottles,
        hasAeroBottle: currentState.hasAeroBottle ?? existingProfile.hasAeroBottle,
        hasBentoBox: currentState.hasBentoBox ?? existingProfile.hasBentoBox,
        cssPacePer100mSeconds: currentState.cssPacePer100mSeconds ?? existingProfile.cssPacePer100mSeconds,
        typicalWetsuit: currentState.typicalWetsuit ?? existingProfile.typicalWetsuit,
        typicalSwimCapType: currentState.typicalSwimCapType ?? existingProfile.typicalSwimCapType,
        dietaryPreference: currentState.dietaryPreference ?? existingProfile.dietaryPreference,
        allergies: currentState.allergies.isNotEmpty ? currentState.allergies : existingProfile.allergies,
        // Optional name fields for coach mode athlete identification
        firstName: currentState.firstName ?? existingProfile.firstName,
        lastName: currentState.lastName ?? existingProfile.lastName,
      );

      await userRepository.updateUserProfile(updatedProfile);

      // Ensure other providers see the updated profile immediately
      ref.invalidate(currentUserProvider);

      // TODO: Add Supabase sync once implemented
      // await _userRepository.syncToSupabase();

      return currentState.copyWith(
        isSaving: false,
        errorMessage: null,
        updatedAt: updatedProfile.updatedAt,
        isAnonymous: updatedProfile.isAnonymous,
        authProvider: updatedProfile.authProvider,
        authUserId: updatedProfile.authUserId,
      );
    });
  }

  /// Refresh content from backend
  Future<void> refreshContent() async {
    await _contentService.refreshFromBackend();
    ref.invalidateSelf();
  }

  /// Get content-driven error message
  String getErrorMessage(String? error) {
    return _contentService.getValue(
      ContentKeys.errorGeneric,
      defaultValue: error ?? 'Something went wrong. Please try again.',
    );
  }

  /// Sign out the current user
  /// This triggers the auth state listener which will:
  /// 1. Sync all local changes to Supabase (to prevent data loss)
  /// 2. Create a new anonymous session
  /// 3. Reset local database (preserve food prefs, clear biometric data)
  /// 4. Invalidate this controller to refresh UI
  Future<void> signOut() async {
    state = await AsyncValue.guard(() async {
      final supabaseClient = ref.read(appExternalDepsProvider).supabaseClient;
      final analytics = ref.read(appExternalDepsProvider).analytics;

      // Track sign out event
      await analytics.track('settings_sign_out_tapped');

      // CRITICAL: Sync all local changes to Supabase BEFORE sign-out
      // This prevents data loss when local database is cleared
      final currentUser = supabaseClient.auth.currentUser;
      if (currentUser != null) {
        try {
          await ref.read(syncCoordinatorProvider.notifier).sync(
            userId: currentUser.id,
            trigger: SyncTrigger.preLogout,
          );
        } catch (e) {
          // Log error but continue with sign-out
          // User has likely already confirmed they want to sign out
          final logger = ref.read(appExternalDepsProvider).logger;
          logger.error('Pre-logout sync failed', context: 'SETTINGS', error: e);
        }
      }

      // Clear the temp user ID from SharedPreferences
      // This ensures the next user gets a fresh onboarding experience
      // without inheriting the previous user's integration state
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.remove(_onboardingTempUserIdKey);

      // Sign out from Supabase (triggers AuthChangeEvent.signedOut)
      await supabaseClient.auth.signOut();

      // Wait a moment for auth state listener to complete
      // The listener will create new anonymous session and invalidate this controller
      await Future.delayed(const Duration(milliseconds: 1000));

      // Return a new state that will be replaced by invalidation
      // This is temporary - invalidateSelf will trigger rebuild
      return state.requireValue;
    });
  }

  /// Delete the current user account
  /// This will:
  /// 1. Call delete-user Edge Function to delete from auth.users and public.users
  /// 2. Clear user's local data (with WHERE user_id filter)
  /// 3. Sign out to trigger auth state change which rebuilds UI
  Future<void> deleteAccount() async {
    state = await AsyncValue.guard(() async {
      final supabaseClient = ref.read(appExternalDepsProvider).supabaseClient;
      final analytics = ref.read(appExternalDepsProvider).analytics;
      final logger = ref.read(appExternalDepsProvider).logger;
      final database = ref.read(appDatabaseProvider);
      final currentUserId = supabaseClient.auth.currentUser?.id;

      if (currentUserId == null) {
        throw Exception('No user logged in');
      }

      // Track delete account event
      await analytics.track('settings_delete_account_tapped');

      // If authenticated, call the delete-user Edge Function
      // This deletes from both auth.users and public.users (with CASCADE)
      try {
        logger.info('Calling delete-user Edge Function', context: 'SETTINGS');

        final response = await supabaseClient.functions.invoke(
          'delete-user',
          method: HttpMethod.post,
          body: {}, // No body needed - user ID comes from JWT
        );

        if (response.status != 200) {
          final errorData = response.data;
          final errorMessage = errorData?['message'] ?? 'Unknown error';
          logger.error(
            'delete-user Edge Function failed',
            context: 'SETTINGS',
            data: {'status': response.status, 'message': errorMessage},
          );
          // Continue with local cleanup even if server deletion fails
        } else {
          logger.info('User deleted from Supabase successfully', context: 'SETTINGS');
        }
      } catch (e) {
        logger.error(
          'Error calling delete-user Edge Function',
          context: 'SETTINGS',
          error: e,
        );
        // Continue with local cleanup even if edge function call fails
      }

      // Clear user's local data with forceDelete = true
      // This deletes ONLY this user's data (WHERE user_id = currentUserId)
      await database.diagnosticDao.clearUserScopedData(
        userId: currentUserId,
        forceDelete: true,
      );

      // Clear the temp user ID from SharedPreferences
      // This ensures a new user won't inherit the previous user's integration status
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.remove(_onboardingTempUserIdKey);

      // Sign out to trigger auth state listener to create a new anonymous user
      try {
        await supabaseClient.auth.signOut();
      } catch (e) {
        // Ignore errors during sign out - user is already deleted
      }

      // Wait a moment for auth state listener to complete
      await Future.delayed(const Duration(milliseconds: 1000));

      // Return current state (will be refreshed)
      return state.requireValue;
    });
  }
}
