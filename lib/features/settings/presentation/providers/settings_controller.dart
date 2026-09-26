import 'package:flutter/foundation.dart' show visibleForTesting;
import 'dart:async';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../integrations/presentation/providers/athlete_zones_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show FunctionResponse, HttpMethod;
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../../../shared/providers/user_id_provider.dart';
import '../../../activities/data/activities_repository.dart';
import '../../../activities/domain/activity.dart';
import '../../../nutrition_plan/application/resolved_during_target_resolver.dart';
import '../../../nutrition_plan/data/macro_repository.dart';
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
import '../../../formula_kit/data/formula_pins_repository.dart';
import '../../../formula_kit/data/personal_formulas_repository.dart';
import '../../../integrations/presentation/providers/integrations_providers.dart';
import '../../../meal_logging/data/meal_log_repository.dart';
import '../../../meal_logging/data/saved_meals_repository.dart';
import '../../../meal_planning/data/meal_plan_repository.dart';
import '../../../meal_planning/data/user_memory_repository.dart';
import '../../../../shared/data/syncable_repository.dart';
import '../../../nutrition_plan/presentation/providers/macro_targets_controller.dart';
import '../../../onboarding/application/onboarding_snapshot_service.dart';
import '../../domain/account_deletion_exceptions.dart';
import '../../domain/sign_out_source.dart';
import '../../../onboarding/data/onboarding_survey_repository.dart';
import '../../../personal_templates/data/personal_templates_repository.dart';
import '../../../subscription/application/subscription_status_provider.dart';
import '../../../user_foods/data/user_foods_repository.dart';
import '../../application/sign_out_notice.dart';
import '../../domain/account_deletion_entry.dart';
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
    final accountStatusAuthenticated = _contentService.getValue(
      ContentKeys.settingsAccountStatusAuthenticated,
      defaultValue: 'Signed in',
    );
    final accountStatusAnonymous = _contentService.getValue(
      ContentKeys.settingsAccountStatusAnonymous,
      defaultValue: 'Not signed in',
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
    if (displayProfile?.id != null) {
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
        Future.microtask(() async {
          if (ftpEmpty && tpFtp != null) {
            await updateCyclingPreferences(ftpWatts: tpFtp);
          }
          if (cssEmpty && tpCss != null) {
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
      accountStatusAuthenticated: accountStatusAuthenticated,
      accountStatusAnonymous: accountStatusAnonymous,
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
  ///
  /// For the free-text fields ([firstName], [lastName], [email]) null means
  /// "not touched, keep the saved value" and an empty string means "the user
  /// cleared it, save it cleared" (31-004).
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
        firstName: firstName ?? currentState.firstName,
        lastName: lastName ?? currentState.lastName,
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
  /// Bypasses _saveProfile() so it can say "clear", which the rest of the
  /// screen's `??`-shaped save cannot express.
  Future<void> saveNutritionTargetOverrides(
    NutritionTargetOverrides? overrides,
  ) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = await AsyncValue.guard(() async {
      final userRepository = await _userRepository;
      final existingProfile = await userRepository.getCurrentUser();

      if (existingProfile == null) {
        throw Exception('No user profile found to update.');
      }

      // copyWith owns the "clear" case (`clearNutritionTargetOverrides`),
      // because `??` cannot distinguish it from "leave them alone". This
      // used to rebuild UserProfile field by field instead, and that
      // hand-rolled list silently reset every field it did not mention —
      // body fat, lifestyle, training phase, the sweat test, home location.
      final updatedProfile = overrides == null
          ? existingProfile.copyWith(
              updatedAt: DateTime.now(),
              clearNutritionTargetOverrides: true,
            )
          : existingProfile.copyWith(
              updatedAt: DateTime.now(),
              nutritionTargetOverrides: overrides,
            );

      await userRepository.updateUserProfile(updatedProfile);

      // A during rate that just left the settings leaves its stored plans
      // behind (Finding 116-003): flag them so they re-plan without it.
      final removed = removedDuringRates(
        existingProfile.nutritionTargetOverrides,
        overrides,
      );
      if (removed.isNotEmpty && ref.mounted) {
        await _flagPlansBuiltOnRemovedOverrides(
          removed,
          deviceId: existingProfile.deviceId,
        );
      }

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
  }

  /// The during carb rates (g/h, by sport) present in [before] and gone or
  /// changed in [after]. A stored plan built on one of these is stale.
  @visibleForTesting
  static Map<ActivityType, double> removedDuringRates(
    NutritionTargetOverrides? before,
    NutritionTargetOverrides? after,
  ) {
    final removed = <ActivityType, double>{};
    for (final sport in const [
      ActivityType.running,
      ActivityType.cycling,
      ActivityType.swimming,
    ]) {
      final was = before?.getDuring(sport)?.carbRateGPerH;
      if (was == null || was <= 0) continue;
      final now = after?.getDuring(sport)?.carbRateGPerH;
      final kept =
          now != null &&
          (now - was).abs() <=
              ResolvedDuringTargetResolver.defaultToleranceGPerH;
      if (!kept) removed[sport] = was;
    }
    return removed;
  }

  /// Marks every not-yet-done activity whose stored plan carries a removed
  /// override rate `needs_nutrition_refresh`, so the Activity detail shows
  /// its stale-plan notice and the next regeneration plans without the
  /// override. Without this the plan kept 50.4 g/h and the screen showed
  /// 92 g below its band with nothing explaining why (Finding 116-003).
  ///
  /// Runs after the profile save and never fails it: a miss here leaves a
  /// stale plan, which the athlete can still regenerate by hand. Running it
  /// twice (two saves, or a save after a refresh) sets the same flag on the
  /// same rows; the flag is cleared only by a regeneration.
  Future<void> _flagPlansBuiltOnRemovedOverrides(
    Map<ActivityType, double> removed, {
    required String deviceId,
  }) async {
    final logger = ref.read(appLoggerProvider);
    try {
      final userId = await ref.read(userIdProvider.future);
      final activitiesRepo = ref.read(activitiesRepositoryProvider);
      final macroRepo = ref.read(macroRepositoryProvider);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final candidates = await activitiesRepo.getActivitiesForDateRange(
        userId,
        today,
        today.add(const Duration(days: 730)),
      );
      var flagged = 0;
      for (final a in candidates) {
        if (a.status != ActivityStatus.planned) continue;
        if (a.nutritionPlanData == null || a.needsNutritionRefresh) continue;
        final was = removed[a.activityType];
        if (was == null) continue;
        final targets = await macroRepo.getCachedMacroTargetsForActivity(
          a.id,
          expectedActivityType: a.activityType,
        );
        final planRate =
            targets?.duringRun.carbRateGPerH ??
            _duringRateFromPlanData(a.nutritionPlanData);
        if (planRate == null) continue;
        if ((planRate - was).abs() >
            ResolvedDuringTargetResolver.defaultToleranceGPerH) {
          continue;
        }
        await activitiesRepo.updateActivity(
          deviceId: deviceId,
          activity: a.copyWith(needsNutritionRefresh: true),
        );
        flagged++;
      }
      logger.info(
        'Flagged plans built on a removed during override',
        context: 'SETTINGS',
        data: {'removed': removed.toString(), 'flagged': flagged},
      );
    } catch (e, stackTrace) {
      logger.warning(
        'Could not flag plans built on a removed during override',
        context: 'SETTINGS',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// The stored plan's during carb rate, read from the plan JSON the way
  /// ActivityDetailController reads it (`detailedMacroTargets.duringRun`).
  static double? _duringRateFromPlanData(Map<String, dynamic>? planData) {
    final detailed =
        planData?['detailedMacroTargets'] ?? planData?['macroTargetsDetailed'];
    if (detailed is! Map) return null;
    final during = detailed['duringRun'];
    if (during is! Map) return null;
    final rate = during['carbRateGPerH'];
    return rate is num ? rate.toDouble() : null;
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
        // Optional name fields for coach mode athlete identification.
        // An empty string is a field the user cleared (31-004); null is one
        // nobody touched, so the saved value stays.
        firstName: currentState.firstName ?? existingProfile.firstName,
        clearFirstName: currentState.firstName?.isEmpty ?? false,
        lastName: currentState.lastName ?? existingProfile.lastName,
        clearLastName: currentState.lastName?.isEmpty ?? false,
        // Contact information
        email: currentState.email ?? existingProfile.email,
        clearEmail: currentState.email?.isEmpty ?? false,
        // Nutrition target overrides
        nutritionTargetOverrides:
            currentState.nutritionTargetOverrides ??
            existingProfile.nutritionTargetOverrides,
      );

      await userRepository.updateUserProfile(updatedProfile);

      // Ensure other providers see the updated profile immediately.
      // Guard against the notifier being disposed during the async gap above.
      if (ref.mounted) {
        ref.invalidate(currentUserProvider);

        // Q-016: sex / birthday / height / weight are engine inputs — a
        // MANUAL write to any of them invalidates today + future cached
        // daily plans (never past) and refreshes the visible day.
        if (DailyMacroService.engineInputsDiffer(
          existingProfile,
          updatedProfile,
        )) {
          await ref
              .read(dailyMacroServiceProvider)
              .invalidateForManualInputChange(updatedProfile.id);
          if (ref.mounted) ref.invalidate(dailyMacrosControllerProvider);
        }
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

  /// Sign out the current user, leaving nothing the server holds on the phone.
  ///
  /// Order: upload what is still dirty, drop the onboarding prefs, delete the
  /// account's synced local rows, sign out of Supabase (whose `signedOut`
  /// event invalidates the user providers and sends GoRouter to /welcome),
  /// and only then forget the Pro entitlement and log the RevenueCat SDK out.
  ///
  /// The status clears AFTER Supabase (testing-wave 125-001): clearing it
  /// first closed the Gate while the session was still live, so the router
  /// showed the paywall for a moment on the way to Welcome. The clear still
  /// runs on every path, so the next account on this device never reads the
  /// outgoing user's subscription (Findings 03-002, 32-002).
  ///
  /// [source] names the screen that asked (Settings or the paywall), for the
  /// `settings_sign_out_tapped` event only (120-007).
  ///
  /// Ticket 102 (Lee, 2026-09-25): the wipe keeps every row that still needs
  /// upload, so an offline sign-out loses nothing; those rows upload at the
  /// account's next sign-in. When the upload fails the athlete is told so in
  /// one line, through [signOutNoticeProvider], which the Welcome screen
  /// shows. `food_preferences` has no upload flag: it stays only when its
  /// own upload failed.
  ///
  /// **Every `ref.read` happens before the first `await`.** This controller
  /// is auto-dispose; the paywall calls it through a listener-less
  /// `ref.read(...notifier)`, so the Ref is gone by the time the analytics
  /// call returns. Reading it after that threw "Cannot use the Ref of
  /// settingsControllerProvider after it has been disposed", which skipped
  /// the entitlement clear (Finding 02-003) and, silently, the pre-logout
  /// upload. Nothing here touches `ref` or `state` after the first await.
  Future<void> signOut({SignOutSource source = SignOutSource.settings}) async {
    final deps = ref.read(appExternalDepsProvider);
    final supabaseClient = deps.supabaseClient;
    final analytics = deps.analytics;
    final logger = deps.logger;
    final prefs = ref.read(sharedPreferencesProvider);
    final database = ref.read(appDatabaseProvider);
    // keepAlive: the notifier outlives this controller.
    final subscriptionStatus = ref.read(subscriptionStatusProvider.notifier);
    final signOutNotice = ref.read(signOutNoticeProvider.notifier);
    final unsyncedKeptLine = _contentService.getValue(
      ContentKeys.settingsSignOutUnsyncedKept,
    );
    final currentUser = supabaseClient.auth.currentUser;
    // The repository reads run now; only the async providers are awaited
    // later, by which time their futures no longer need the Ref.
    final syncRepos = currentUser == null ? null : _captureSyncRepositories();

    await analytics.track(
      'settings_sign_out_tapped',
      properties: {'source': source.analyticsValue},
    );

    // Upload dirty records BEFORE the local rows are deleted below. What
    // fails to upload stays on the phone (the wipe keeps dirty rows).
    var uploadFailed = <String>{};
    if (currentUser != null && syncRepos != null) {
      try {
        uploadFailed = await _uploadDirtyBeforeLogout(
          currentUser.id,
          await syncRepos,
          logger,
        );
      } catch (e) {
        // Log error but continue with sign-out; nothing was uploaded.
        logger.error('Pre-logout upload failed', context: 'SETTINGS', error: e);
        uploadFailed = {_everyRepository};
      }
    }

    // Clear the temp user ID from SharedPreferences
    await prefs.remove(_onboardingTempUserIdKey);

    // Drop the onboarding recovery snapshot: it exists to restore THIS
    // user's profile after a DB wipe, and surviving a deliberate sign-out
    // would let a later startup resurrect it under a different account.
    await prefs.remove(OnboardingSnapshotService.prefsKey);

    // Delete the account's synced local rows (Finding 14-004). Rows the
    // upload above did not land stay for the next sign-in (ticket 102).
    if (currentUser != null) {
      try {
        await database.clearUserData(
          currentUser.id,
          keepUnsynced: true,
          // The marker, as the sign-in sweep reads it: set while the
          // preferences' last upload has not landed.
          keepFoodPreferences:
              uploadFailed.contains(_everyRepository) ||
              uploadFailed.contains('food_preferences') ||
              FoodPreferencesRepository.isUploadPendingIn(
                prefs,
                currentUser.id,
              ),
        );
      } catch (e) {
        logger.error('Local data clear failed', context: 'SETTINGS', error: e);
      }
    }

    // Say so (Finding 86-007): one line on the Welcome screen.
    signOutNotice.set(uploadFailed.isEmpty ? null : unsyncedKeptLine);

    // Sign out from Supabase (triggers AuthChangeEvent.signedOut). GoTrue
    // drops the local session and fires the event before its server call,
    // so the router is on its way to Welcome by the time the clear below
    // runs, and a failed server call still leaves the phone signed out.
    try {
      await supabaseClient.auth.signOut();
    } finally {
      // Forget the Pro entitlement and return the RevenueCat SDK to an
      // anonymous customer, so the next account on this device never reads
      // the outgoing user's subscription (Findings 03-002, 32-002). After
      // the sign-out on purpose (125-001): the Gate closing first sent the
      // router through /paywall.
      try {
        await subscriptionStatus.clear();
      } catch (e) {
        logger.error(
          'Pro entitlement clear failed',
          context: 'SETTINGS',
          error: e,
        );
      }
    }
  }

  /// Marker in the failed-upload set when the whole pre-logout upload threw.
  static const _everyRepository = '*';

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
    // Meal planning (Phase 4b): local-first plan edits + Vana settings.
    final mealPlanRepo = ref.read(mealPlanRepositoryProvider);
    final userMemoryRepo = ref.read(userMemoryRepositoryProvider);
    // Ticket 102: these six write locally with needs_upload too and were
    // wiped at sign-out with no upload attempt.
    final userFoodsRepoFuture = ref.read(userFoodsRepositoryProvider.future);
    final integrationsRepo = ref.read(integrationsRepositoryProvider);
    final formulaPinsRepo = ref.read(formulaPinsRepositoryProvider);
    final onboardingSurveyRepo = ref.read(onboardingSurveyRepositoryProvider);
    final personalFormulasRepo = ref.read(personalFormulasRepositoryProvider);
    final personalTemplatesRepo = ref.read(personalTemplatesRepositoryProvider);

    return Future.wait([
      foodPrefsRepoFuture,
      userRepoFuture,
      userFoodsRepoFuture,
    ]).then(
      (resolved) => <SyncableRepository>[
        activitiesRepo,
        eventsRepo,
        carbLoadingRepo,
        feedbackRepo,
        resolved[0],
        resolved[1],
        mealLogRepo,
        savedMealsRepo,
        mealPlanRepo,
        userMemoryRepo,
        resolved[2],
        integrationsRepo,
        formulaPinsRepo,
        onboardingSurveyRepo,
        personalFormulasRepo,
        personalTemplatesRepo,
      ],
    );
  }

  /// Upload dirty records from all repositories before logout.
  /// Uses Future.wait for parallel uploads - fast and targeted.
  ///
  /// `uploadDirtyRecords()` swallows exceptions into a silent
  /// `UploadResult.failed()`, so every result is checked here and the
  /// failures logged — an unchecked call looks identical to a success.
  /// Takes its collaborators as arguments: it runs after the controller may
  /// have been disposed (see [signOut]). Returns the keys of the repositories
  /// whose upload failed (empty when everything landed).
  Future<Set<String>> _uploadDirtyBeforeLogout(
    String userId,
    List<SyncableRepository> repos,
    AppLogger logger,
  ) async {
    final results = await Future.wait(
      repos.map((repo) => repo.uploadDirtyRecords(userId)),
    );

    final failed = <String>{};
    for (var i = 0; i < repos.length; i++) {
      final result = results[i];
      if (result.success) continue;
      failed.add(repos[i].repositoryKey);
      logger.error(
        'Pre-logout upload failed for ${repos[i].repositoryKey}',
        context: 'SETTINGS',
        data: {'repository': repos[i].repositoryKey, 'error': result.error},
      );
    }
    return failed;
  }

  /// Delete the current user account
  /// This will:
  /// 1. Call delete-user Edge Function to delete from auth.users and public.users
  /// 2. Clear user's local data (with WHERE user_id filter)
  /// 3. Sign out to trigger auth state change which rebuilds UI
  ///
  /// The server's answer is the ack (testing-wave 121-007, 121-009): when
  /// `delete-user` cannot be reached or answers anything but 200, nothing
  /// else runs. The local rows, the RevenueCat identity and the session all
  /// stay, the state shown is left as it was, and
  /// [AccountDeletionNeedsConnectionException] reaches the screen, which
  /// says the delete needs a connection. This is the one write path that
  /// rethrows past `AsyncValue.guard`: a half-deleted account (rows gone,
  /// account alive) is worse than a delete that did not happen.
  ///
  /// Running twice: a second tap while the first is in flight sends a second
  /// `delete-user`; the function deletes once and the second call answers
  /// 401 (no user for the token), which stops that second run before it
  /// touches anything, while the first finishes the wipe. A retry after a
  /// failure repeats only the function call, which is idempotent.
  ///
  /// After a successful delete the local sign-out still makes one server
  /// call: supabase_flutter has no local-only sign-out (`signOut(scope:
  /// local)` drops the session, fires `signedOut`, then POSTs /logout with
  /// the old token). GoTrue answers that 403 for a deleted user and the SDK
  /// swallows 401/403/404 itself, so the 403 in the logs is expected.
  ///
  /// [from] names the screen that asked, for the analytics event only.
  Future<void> deleteAccount({
    AccountDeletionEntry from = AccountDeletionEntry.settings,
  }) async {
    // Read everything the guarded body needs up front: the awaits below can
    // outlive this notifier (the auth listener invalidates it as soon as
    // signOut lands), and touching ref/state after that throws
    // UnmountedRefException.
    final supabaseClient = ref.read(appExternalDepsProvider).supabaseClient;
    final analytics = ref.read(appExternalDepsProvider).analytics;
    final logger = ref.read(appExternalDepsProvider).logger;
    final database = ref.read(appDatabaseProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    // keepAlive: the notifier outlives this controller.
    final subscriptionStatus = ref.read(subscriptionStatusProvider.notifier);
    final previousState = state;

    final result = await AsyncValue.guard(() async {
      final currentUserId = supabaseClient.auth.currentUser?.id;

      if (currentUserId == null) {
        throw Exception('No user logged in');
      }

      // Track delete account event, named for where it was asked (04-001)
      await analytics.track(from.analyticsEvent);

      // The delete-user Edge Function deletes auth.users and public.users
      // (with CASCADE). Its 200 is the ack everything below waits for.
      logger.info('Calling delete-user Edge Function', context: 'SETTINGS');
      final FunctionResponse response;
      try {
        response = await supabaseClient.functions.invoke(
          'delete-user',
          method: HttpMethod.post,
          body: {}, // No body needed - user ID comes from JWT
        );
      } catch (e) {
        // Unreachable, or the SDK raised the non-2xx itself.
        logger.error(
          'Error calling delete-user Edge Function',
          context: 'SETTINGS',
          error: e,
        );
        throw AccountDeletionNeedsConnectionException(e.toString());
      }

      if (response.status != 200) {
        final errorData = response.data;
        final errorMessage = errorData is Map
            ? errorData['message'] ?? 'Unknown error'
            : 'Unknown error';
        logger.error(
          'delete-user Edge Function failed',
          context: 'SETTINGS',
          data: {'status': response.status, 'message': errorMessage},
        );
        throw AccountDeletionNeedsConnectionException(
          'delete-user answered ${response.status}: $errorMessage',
        );
      }
      logger.info('User deleted from Supabase successfully', context: 'SETTINGS');

      // Forget the Pro entitlement and log the RevenueCat SDK out, as
      // sign-out does: the deleted account's customer must not linger.
      try {
        await subscriptionStatus.clear();
      } catch (e) {
        logger.error(
          'Pro entitlement clear failed',
          context: 'SETTINGS',
          error: e,
        );
      }

      // Delete ONLY this user's local rows, across every user-scoped table.
      await database.clearUserData(currentUserId);

      // Clear the temp user ID from SharedPreferences
      // This ensures a new user won't inherit the previous user's integration status
      await prefs.remove(_onboardingTempUserIdKey);

      // The deleted account's onboarding snapshot must not survive to be
      // restored under the device's next user.
      await prefs.remove(OnboardingSnapshotService.prefsKey);

      // Sign out so the auth listener rebuilds the UI signed out
      try {
        await supabaseClient.auth.signOut();
      } catch (e) {
        // Ignore errors during sign out - user is already deleted
      }

      // Wait a moment for auth state listener to complete
      await Future.delayed(const Duration(milliseconds: 1000));

      // Return current state (will be refreshed)
      return previousState.requireValue;
    });

    // The server did not confirm: nothing local changed, so the shown state
    // stays as it was and the screen hears why (121-007).
    if (result.error case final AccountDeletionNeedsConnectionException e) {
      throw e;
    }

    // The sign-out above invalidates this controller; if that already
    // happened the assignment below would throw UnmountedRefException.
    if (!ref.mounted) return;
    state = result;
  }
}
