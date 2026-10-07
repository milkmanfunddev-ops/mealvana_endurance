import 'dart:async';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../integrations/presentation/providers/athlete_zones_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show HttpMethod;
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/report/report.dart';
import '../../../activities/data/activities_repository.dart';
import '../../../ai_credits/data/revenuecat_service.dart';
import '../../../auth/application/supabase_auth_service.dart';
import '../../../auth/data/user_repository.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../content/application/content_service.dart';
import '../../../daily_macros/application/daily_macro_service.dart';
import '../../../daily_macros/presentation/providers/daily_macros_controller.dart';
import '../../../content/domain/content_keys.dart';
import '../../../nutrition_plan/domain/run_parameters.dart';
import '../../../nutrition_plan/domain/nutrition_target_overrides.dart';
import '../../../onboarding/domain/dietary_preference.dart';
import '../../../onboarding/domain/allergy.dart';
import '../../../carb_loading/data/carb_loading_repository.dart';
import '../../../coach_mode/data/coach_repository.dart';
import '../../../events/data/events_repository.dart';
import '../../../feedback/data/feedback_repository.dart';
import '../../../food_preferences/data/food_preferences_repository.dart';
import '../../../meal_logging/data/meal_log_repository.dart';
import '../../../meal_logging/data/saved_meals_repository.dart';
import '../../../../shared/data/syncable_repository.dart';
import '../../../nutrition_plan/presentation/providers/macro_targets_controller.dart';
import '../../../onboarding/application/onboarding_snapshot_service.dart';
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

  /// Check if user is an approved coach by querying the local coaches table.
  ///
  /// [coachRepository] must be captured by the caller *before* any `await` in
  /// build() — this is called at the very end of build(), after several prior
  /// async gaps (profile lookups). Reading `ref.read(coachRepositoryProvider)`
  /// at that point throws UnmountedRefException if the provider was disposed
  /// mid-build (Sentry MEALVANA-ENDURANCE-DEV-5F).
  Future<bool> _checkIsApprovedCoach(
    CoachRepository coachRepository,
    String? userId,
  ) async {
    if (userId == null) return false;
    return await coachRepository.isUserApprovedCoach(userId);
  }

  @override
  FutureOr<SettingsState> build() async {
    // Watch auth state to trigger rebuilds on sign in/out
    final authUserAsync = ref.watch(currentUserProvider);

    // Capture up-front, before any `await` below. build() has several async
    // gaps (profile lookups) and this auto-dispose provider can be disposed
    // mid-build. Reading `ref` again after disposal throws
    // UnmountedRefException — the cause of Sentry MEALVANA-ENDURANCE-DEV-5F.
    final coachRepository = ref.read(coachRepositoryProvider);

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
    // Anonymous sessions never get a plain sign-out: dropping an anonymous
    // session discards its refresh token, which makes the identity — and the
    // athlete's data behind it — permanently unrecoverable (ruling, Xuan
    // 2026-09-21). Both anonymous actions preserve the session instead.
    final createAccountButton = _contentService.getValue(
      ContentKeys.settingsCreateAccountButton,
      defaultValue: 'Create an account to save your data',
    );
    final logInButton = _contentService.getValue(
      ContentKeys.settingsLogInButton,
      defaultValue: 'Log into an existing account',
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

    // Q-INT19 FTP/CSS prefill (RULED with D-2, 2026-09-11): an EMPTY
    // performance field adopts the TrainingPeaks value at load — the field
    // then reads TP-sourced (the ftp-tp-sourced golden state). Manual-wins
    // stands: a non-empty field is never overwritten (that's the inline
    // conflict + tap-to-use instead). Persisted through the normal update
    // path after this build settles; the next build converges (manual ==
    // TP -> no further write).
    // `ref` is read after the profile awaits above: skip the prefill when this
    // auto-dispose build was disposed meanwhile (its result is discarded).
    // Sentry MEALVANA-ENDURANCE-CK / DEV-93.
    if (displayProfile?.id != null && ref.mounted) {
      final zones = await ref.read(
        athleteZonesProvider(displayProfile!.id).future,
      );
      final tpFtp = zones?.ftpWatts;
      final tpCss = zones?.cssSecondsPer100m;
      final ftpEmpty =
          displayProfile.ftpWatts == null || displayProfile.ftpWatts == 0;
      final cssEmpty =
          displayProfile.cssPacePer100mSeconds == null ||
          displayProfile.cssPacePer100mSeconds == 0;
      if ((ftpEmpty && tpFtp != null) || (cssEmpty && tpCss != null)) {
        // The microtask outlives this build: by the time it runs the
        // provider may be gone (Sentry MEALVANA-ENDURANCE-C9 / CA). The next
        // build re-derives the same prefill, so a skipped write is not lost.
        Future.microtask(() async {
          if (ftpEmpty && tpFtp != null && ref.mounted) {
            await updateCyclingPreferences(ftpWatts: tpFtp);
          }
          if (cssEmpty && tpCss != null && ref.mounted) {
            await updateSwimmingPreferences(cssPacePer100mSeconds: tpCss);
          }
        });
      }
    }

    final profileEmail = displayProfile?.email?.trim();
    final authEmail = supabaseUser?.email.trim();
    final effectiveEmail = (profileEmail != null && profileEmail.isNotEmpty)
        ? profileEmail
        : ((authEmail != null && authEmail.isNotEmpty) ? authEmail : null);

    return SettingsState(
      title: title,
      accountSectionTitle: accountSectionTitle,
      accountStatusAnonymous: accountStatusAnonymous,
      accountStatusAuthenticated: accountStatusAuthenticated,
      createAccountButton: createAccountButton,
      logInButton: logInButton,
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
      // Unit preferences
      unitSystem: displayProfile?.unitSystem ?? UnitSystem.imperial,
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
      // Prefer the user-editable profile email. Fall back to auth email only
      // when profile email is missing.
      email: effectiveEmail,
      // Coach mode - check coaches table for approved status
      isCoach: await _checkIsApprovedCoach(coachRepository, displayProfile?.id),
      // Optional name fields for coach mode athlete identification
      firstName: displayProfile?.firstName,
      lastName: displayProfile?.lastName,
      // Nutrition target overrides
      nutritionTargetOverrides: displayProfile?.nutritionTargetOverrides,
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

  /// Update unit system preference
  Future<void> updateUnitSystem(UnitSystem system) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(
      currentState.copyWith(unitSystem: system, isSaving: true),
    );

    await _saveProfile();

    // Guard against the notifier being disposed during the async gap above.
    if (!ref.mounted) return;

    // Invalidate providers that rely on unit settings
    ref.invalidate(macroTargetsControllerProvider);
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
    UnitSystem? unitSystem,
    GutTraining? gutTrainingLevel,
    SweatRateCat? sweatRate,
    String? firstName,
    String? lastName,
    String? email,
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
        runsWithWaterBottle:
            runsWithWaterBottle ?? currentState.runsWithWaterBottle,
        unitSystem: unitSystem ?? currentState.unitSystem,
        gutTrainingLevel: gutTrainingLevel ?? currentState.gutTrainingLevel,
        sweatRate: sweatRate ?? currentState.sweatRate,
        firstName: firstName,
        lastName: lastName,
        email: email ?? currentState.email,
        isSaving: true,
      ),
    );

    // Single save and invalidation
    await _saveProfile();

    // Guard against the notifier being disposed during the async gap above.
    if (!ref.mounted) return;

    // Invalidate providers if unit system changed
    if (unitSystem != null) {
      ref.invalidate(macroTargetsControllerProvider);
    }
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

  /// Save nutrition target overrides (null clears all overrides).
  /// Bypasses _saveProfile() to handle the null/clearing case directly,
  /// since copyWith with `??` would preserve existing values when null is passed.
  Future<void> saveNutritionTargetOverrides(
    NutritionTargetOverrides? overrides,
  ) async {
    final currentState = state.value;
    if (currentState == null) return;

    final result = await AsyncValue.guard(() async {
      final userRepository = await _userRepository;
      final existingProfile = await userRepository.getCurrentUser();

      if (existingProfile == null) {
        throw Exception('No user profile found to update.');
      }

      // Use a sentinel empty override to distinguish "set to null" from "don't change"
      // We create the profile with a non-null value first, then null it out manually
      final updatedProfile = UserProfile(
        id: existingProfile.id,
        deviceId: existingProfile.deviceId,
        authUserId: existingProfile.authUserId,
        authProvider: existingProfile.authProvider,
        isAnonymous: existingProfile.isAnonymous,
        gender: existingProfile.gender,
        birthday: existingProfile.birthday,
        heightFeet: existingProfile.heightFeet,
        heightInches: existingProfile.heightInches,
        weightPounds: existingProfile.weightPounds,
        runsWithWaterBottle: existingProfile.runsWithWaterBottle,
        createdAt: existingProfile.createdAt,
        updatedAt: DateTime.now(),
        gutTraining: existingProfile.gutTraining,
        sweatRate: existingProfile.sweatRate,
        onboardingCompleted: existingProfile.onboardingCompleted,
        appVersion: existingProfile.appVersion,
        swipeHintShown: existingProfile.swipeHintShown,
        unitSystem: existingProfile.unitSystem,
        giSensitivity: existingProfile.giSensitivity,
        ftpWatts: existingProfile.ftpWatts,
        typicalBikeBottles: existingProfile.typicalBikeBottles,
        hasAeroBottle: existingProfile.hasAeroBottle,
        hasBentoBox: existingProfile.hasBentoBox,
        cssPacePer100mSeconds: existingProfile.cssPacePer100mSeconds,
        typicalWetsuit: existingProfile.typicalWetsuit,
        typicalSwimCapType: existingProfile.typicalSwimCapType,
        defaultRunningPaceMinPerMile:
            existingProfile.defaultRunningPaceMinPerMile,
        defaultCyclingSpeedMph: existingProfile.defaultCyclingSpeedMph,
        defaultSwimmingPacePer100Sec:
            existingProfile.defaultSwimmingPacePer100Sec,
        dietaryPreference: existingProfile.dietaryPreference,
        allergies: existingProfile.allergies,
        senderName: existingProfile.senderName,
        firstName: existingProfile.firstName,
        lastName: existingProfile.lastName,
        email: existingProfile.email,
        nutritionTargetOverrides: overrides, // Explicitly set (can be null)
      );

      await userRepository.updateUserProfile(updatedProfile);

      // Guard against the notifier being disposed during the async gap above.
      if (ref.mounted) {
        ref.invalidate(currentUserProvider);
      }

      return currentState.copyWith(
        nutritionTargetOverrides: overrides,
        isSaving: false,
        errorMessage: null,
      );
    });
    // The save above completed; only the UI state is dropped when this
    // auto-dispose controller was disposed during it.
    if (ref.mounted) state = result;
  }

  /// Save profile changes (both local and Supabase)
  Future<void> _saveProfile() async {
    final currentState = state.value;
    if (currentState == null) return;

    final result = await AsyncValue.guard(() async {
      // Read before the first await, inside the guard so a failed read is an
      // AsyncError like any other save failure.
      final dailyMacroService = ref.read(dailyMacroServiceProvider);
      final userRepository = await _userRepository;
      final existingProfile = await userRepository.getCurrentUser();

      if (existingProfile == null) {
        throw Exception('No user profile found to update.');
      }

      final newWeightPounds =
          currentState.weightPounds ?? existingProfile.weightPounds;
      final weightChanged = newWeightPounds != existingProfile.weightPounds;

      final updatedProfile = existingProfile.copyWith(
        gender: currentState.gender ?? existingProfile.gender,
        birthday: currentState.birthday ?? existingProfile.birthday,
        heightFeet: currentState.heightFeet ?? existingProfile.heightFeet,
        heightInches: currentState.heightInches ?? existingProfile.heightInches,
        weightPounds: newWeightPounds,
        weightPoundsUpdatedAt: weightChanged
            ? DateTime.now().toUtc()
            : existingProfile.weightPoundsUpdatedAt,
        runsWithWaterBottle: currentState.runsWithWaterBottle,
        unitSystem: currentState.unitSystem,
        gutTraining: currentState.gutTrainingLevel,
        sweatRate: currentState.sweatRate,
        giSensitivity:
            currentState.giSensitivity ?? existingProfile.giSensitivity,
        ftpWatts: currentState.ftpWatts ?? existingProfile.ftpWatts,
        typicalBikeBottles:
            currentState.typicalBikeBottles ??
            existingProfile.typicalBikeBottles,
        hasAeroBottle:
            currentState.hasAeroBottle ?? existingProfile.hasAeroBottle,
        hasBentoBox: currentState.hasBentoBox ?? existingProfile.hasBentoBox,
        cssPacePer100mSeconds:
            currentState.cssPacePer100mSeconds ??
            existingProfile.cssPacePer100mSeconds,
        typicalWetsuit:
            currentState.typicalWetsuit ?? existingProfile.typicalWetsuit,
        typicalSwimCapType:
            currentState.typicalSwimCapType ??
            existingProfile.typicalSwimCapType,
        dietaryPreference:
            currentState.dietaryPreference ?? existingProfile.dietaryPreference,
        allergies: currentState.allergies.isNotEmpty
            ? currentState.allergies
            : existingProfile.allergies,
        // Optional name fields for coach mode athlete identification
        firstName: currentState.firstName ?? existingProfile.firstName,
        lastName: currentState.lastName ?? existingProfile.lastName,
        // Contact information
        email: currentState.email ?? existingProfile.email,
        // Nutrition target overrides
        nutritionTargetOverrides:
            currentState.nutritionTargetOverrides ??
            existingProfile.nutritionTargetOverrides,
      );

      await userRepository.updateUserProfile(updatedProfile);

      // Ensure other providers see the updated profile immediately.
      // Guard against the notifier being disposed during the async gap above.
      if (ref.mounted) ref.invalidate(currentUserProvider);

      // Q-016: sex / birthday / height / weight are engine inputs — a
      // MANUAL write to any of them invalidates today + future cached
      // daily plans (never past) and refreshes the visible day. The cache
      // invalidation runs even when this controller was disposed mid-save.
      if (DailyMacroService.engineInputsDiffer(
        existingProfile,
        updatedProfile,
      )) {
        await dailyMacroService.invalidateForManualInputChange(
          updatedProfile.id,
        );
        if (ref.mounted) ref.invalidate(dailyMacrosControllerProvider);
      }

      return currentState.copyWith(
        isSaving: false,
        errorMessage: null,
        updatedAt: updatedProfile.updatedAt,
        isAnonymous: updatedProfile.isAnonymous,
        authProvider: updatedProfile.authProvider,
        authUserId: updatedProfile.authUserId,
      );
    });
    // The save above completed; only the UI state is dropped when this
    // auto-dispose controller was disposed during it.
    if (ref.mounted) state = result;
  }

  /// Refresh content from backend
  Future<void> refreshContent() async {
    await _contentService.refreshFromBackend();

    // Guard against the notifier being disposed during the async gap above.
    if (!ref.mounted) return;

    ref.invalidateSelf();
  }

  /// Get content-driven error message
  String getErrorMessage(String? error) {
    return _contentService.getValue(
      ContentKeys.errorGeneric,
      defaultValue: error ?? 'Something went wrong. Please try again.',
    );
  }

  /// Sign out the current user, leaving nothing of the account on the phone.
  ///
  /// Order: upload what is still dirty, drop the onboarding prefs, log the
  /// RevenueCat SDK out, delete the account's local rows, then sign out of
  /// Supabase (whose `signedOut` event invalidates the user providers and
  /// sends GoRouter to /welcome).
  ///
  /// **Every `ref.read` happens before the first `await`.** This controller
  /// is auto-dispose; a caller holding only `ref.read(...notifier)` loses the
  /// Ref by the time the analytics call returns, and reading it after that
  /// threw "Cannot use the Ref of settingsControllerProvider after it has
  /// been disposed", silently skipping the pre-logout upload (Finding 02-003
  /// on mealplanning). Nothing here touches `ref` or `state` after the first
  /// await.
  Future<void> signOut() async {
    final deps = ref.read(appExternalDepsProvider);
    final supabaseClient = deps.supabaseClient;
    final analytics = deps.analytics;
    final report = ref.read(reportProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    final database = ref.read(appDatabaseProvider);
    // keepAlive: the service outlives this controller.
    final revenueCat = ref.read(revenueCatServiceProvider);
    final currentUser = supabaseClient.auth.currentUser;
    // The repository reads run now; only the two async providers are awaited
    // later, by which time their futures no longer need the Ref.
    final syncRepos = currentUser == null ? null : _captureSyncRepositories();

    await analytics.track('settings_sign_out_tapped');

    // Upload dirty records BEFORE the local rows are deleted below.
    if (currentUser != null && syncRepos != null) {
      try {
        await _uploadDirtyBeforeLogout(currentUser.id, await syncRepos, report);
      } catch (e) {
        // Log error but continue with sign-out
        report.fault(e, area: 'settings', message: 'Pre-logout upload failed');
      }
    }

    // Clear the temp user ID from SharedPreferences
    await prefs.remove(_onboardingTempUserIdKey);

    // Drop the onboarding recovery snapshot: it exists to restore THIS
    // user's profile after a DB wipe, and surviving a deliberate sign-out
    // would let a later startup resurrect it under a different account.
    await prefs.remove(OnboardingSnapshotService.prefsKey);

    // Return the RevenueCat SDK (identified for AI credits) to an anonymous
    // customer, so the next account on this device never reads the outgoing
    // user's customer (Finding 03-002). logOut reports its own failures.
    await revenueCat.logOut();

    // Delete the account's local rows (Finding 14-004). After the upload
    // above nothing is lost; the next sign-in syncs from the server.
    if (currentUser != null) {
      try {
        await database.clearUserData(currentUser.id);
      } catch (e, st) {
        await report.fault(
          e,
          stackTrace: st,
          area: 'settings',
          message: 'Local data clear failed',
        );
      }
    }

    // Sign out from Supabase (triggers AuthChangeEvent.signedOut)
    await supabaseClient.auth.signOut();
  }

  /// Reads every syncable repository synchronously (no `await` before the
  /// reads) so the list can be awaited after this controller is disposed.
  Future<List<SyncableRepository>> _captureSyncRepositories() {
    final activitiesRepo = ref.read(activitiesRepositoryProvider);
    final eventsRepo = ref.read(eventsRepositoryProvider);
    final carbLoadingRepo = ref.read(carbLoadingRepositoryProvider);
    final feedbackRepo = ref.read(feedbackRepositoryProvider);
    final foodPrefsRepoFuture = ref.read(
      foodPreferencesRepositoryProvider.future,
    );
    final userRepoFuture = ref.read(userRepositoryProvider.future);
    final mealLogRepo = ref.read(mealLogRepositoryProvider);
    final savedMealsRepo = ref.read(savedMealsRepositoryProvider);

    return Future.wait([foodPrefsRepoFuture, userRepoFuture]).then(
      (resolved) => <SyncableRepository>[
        activitiesRepo,
        eventsRepo,
        carbLoadingRepo,
        feedbackRepo,
        resolved[0],
        resolved[1],
        mealLogRepo,
        savedMealsRepo,
      ],
    );
  }

  /// Upload dirty records from all repositories before logout.
  /// Uses Future.wait for parallel uploads - fast and targeted.
  ///
  /// `uploadDirtyRecords()` swallows exceptions into a silent
  /// `UploadResult.failed()`, so every result is checked here and the
  /// failures reported — an unchecked call looks identical to a success.
  /// Takes its collaborators as arguments: it runs after the controller may
  /// have been disposed (see [signOut]).
  Future<void> _uploadDirtyBeforeLogout(
    String userId,
    List<SyncableRepository> repos,
    Report report,
  ) async {
    final results = await Future.wait(
      repos.map((repo) => repo.uploadDirtyRecords(userId)),
    );

    for (var i = 0; i < repos.length; i++) {
      final result = results[i];
      // A deferral is not a failure (DEV-A2): the repository left its Note
      // and the rows wait for their owner's session.
      if (!result.failed) continue;
      report.fault(
        LoggedFault(
          'Pre-logout upload failed for ${repos[i].repositoryKey}',
          context: 'SETTINGS',
        ),
        area: 'settings',
        extra: {'repository': repos[i].repositoryKey, 'error': result.error},
      );
    }
  }

  /// Delete the current user account
  /// This will:
  /// 1. Call delete-user Edge Function to delete from auth.users and public.users
  /// 2. Clear user's local data (with WHERE user_id filter)
  /// 3. Sign out to trigger auth state change which rebuilds UI
  Future<void> deleteAccount() async {
    final result = await AsyncValue.guard(() async {
      final supabaseClient = ref.read(appExternalDepsProvider).supabaseClient;
      final analytics = ref.read(appExternalDepsProvider).analytics;
      final report = ref.read(reportProvider);
      final database = ref.read(appDatabaseProvider);
      final prefs = ref.read(sharedPreferencesProvider);
      // keepAlive: the service outlives this controller.
      final revenueCat = ref.read(revenueCatServiceProvider);
      final stateBefore = state;
      final currentUserId = supabaseClient.auth.currentUser?.id;

      if (currentUserId == null) {
        throw Exception('No user logged in');
      }

      // Track delete account event
      await analytics.track('settings_delete_account_tapped');

      // If authenticated, call the delete-user Edge Function
      // This deletes from both auth.users and public.users (with CASCADE)
      try {
        report.info('Calling delete-user Edge Function', area: 'settings');

        final response = await supabaseClient.functions.invoke(
          'delete-user',
          method: HttpMethod.post,
          body: {}, // No body needed - user ID comes from JWT
        );

        if (response.status != 200) {
          final errorData = response.data;
          final errorMessage = errorData?['message'] ?? 'Unknown error';
          report.fault(
            LoggedFault(
              'delete-user Edge Function failed',
              context: 'SETTINGS',
            ),
            area: 'settings',
            extra: {'status': response.status, 'message': errorMessage},
          );
          // Continue with local cleanup even if server deletion fails
        } else {
          report.info(
            'User deleted from Supabase successfully',
            area: 'settings',
          );
        }
      } catch (e) {
        report.fault(
          e,
          area: 'settings',
          message: 'Error calling delete-user Edge Function',
        );
        // Continue with local cleanup even if edge function call fails
      }

      // Log the RevenueCat SDK out, as sign-out does: the deleted account's
      // customer must not linger. logOut reports its own failures.
      await revenueCat.logOut();

      // Delete ONLY this user's local rows, across every user-scoped table.
      await database.clearUserData(currentUserId);

      // Clear the temp user ID from SharedPreferences
      // This ensures a new user won't inherit the previous user's integration status
      await prefs.remove(_onboardingTempUserIdKey);

      // The deleted account's onboarding snapshot must not survive to be
      // restored under the device's next user.
      await prefs.remove(OnboardingSnapshotService.prefsKey);

      // Sign out to trigger auth state listener to create a new anonymous user
      try {
        await supabaseClient.auth.signOut();
      } catch (e, stackTrace) {
        // The account is already gone server-side, so a failed sign-out is
        // survivable; the auth listener still needs to see it, so say so.
        await report.degraded(
          e,
          stackTrace: stackTrace,
          area: 'auth',
          message: 'Sign-out after account deletion failed',
        );
      }

      // Wait a moment for auth state listener to complete
      await Future.delayed(const Duration(milliseconds: 1000));

      // Return current state (will be refreshed). Sign-out usually disposes
      // this controller by now (Sentry MEALVANA-ENDURANCE-BZ), so fall back
      // to the state captured before the first await.
      return ref.mounted ? state.requireValue : stateBefore.requireValue;
    });
    // The save above completed; only the UI state is dropped when this
    // auto-dispose controller was disposed during it.
    if (ref.mounted) state = result;
  }
}
