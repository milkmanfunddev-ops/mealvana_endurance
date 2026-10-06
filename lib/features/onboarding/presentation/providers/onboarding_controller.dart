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
import '../../../../shared/services/report/report.dart';

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
  Report get _report => ref.read(reportProvider);
  UserProfile? _currentUser;

  /// The immutable accumulator for everything the redesigned flow collects.
  /// Screens mutate it through the typed updaters below; saveAllOnboardingData
  /// persists it in one batch after auth.
  OnboardingDraft _draft = const OnboardingDraft();

  @override
  FutureOr<void> build() {
    // Prevent auto-dispose during onboarding navigation
    // Keep all cached onboarding data until onboarding is completed
    ref.keepAlive();

    // Initialize controller - no initial async work needed
    return null;
  }

  /// Save sport preferences (Settings sport-detail screens)
  Future<bool> saveSportPreferences({
    bool? runsWithWaterBottle,
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

    _report.debug(
      '👤 Sport preferences - Current user: ${currentUser?.id ?? "null"}',
      area: 'onboarding',
    );

    if (currentUser == null) {
      final errorMsg = _contentService.getValue(
        ContentKeys.errorGeneric,
        defaultValue:
            'No user profile found. Please complete user profile first.',
      );
      unawaited(
        _report.fault(
          const LoggedFault(
            'Sport preferences - No current user found',
            context: 'onboarding',
          ),
          area: 'onboarding',
        ),
      );
      state = AsyncError(errorMsg, StackTrace.current);
      return false;
    }

    _report.info(
      '🚀 Sport preferences - Starting save process for user: ${currentUser.id}',
      area: 'onboarding',
    );
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _report.debug(
        '📞 Sport preferences - Calling onboarding service',
        area: 'onboarding',
      );
      await _onboardingService.saveSportPreferences(
        currentUser.id,
        runsWithWaterBottle: runsWithWaterBottle,
        giSensitivity: giSensitivity,
        ftpWatts: ftpWatts,
        typicalBikeBottles: typicalBikeBottles,
        hasAeroBottle: hasAeroBottle,
        hasBentoBox: hasBentoBox,
        cssPacePer100mSeconds: cssPacePer100mSeconds,
        typicalWetsuit: typicalWetsuit,
        typicalSwimCapType: typicalSwimCapType,
      );
      _report.info(
        '✅ Sport preferences - Save completed successfully',
        area: 'onboarding',
      );
      // Update our session user reference
      _currentUser = currentUser;
    });

    if (state.hasError) {
      unawaited(
        _report.fault(
          state.error!,
          stackTrace: state.stackTrace,
          area: 'onboarding',
          message: 'Sport preferences save failed',
        ),
      );
    } else {
      _report.info(
        '🎉 Sport preferences - Save operation completed without errors',
        area: 'onboarding',
      );
    }

    return !state.hasError;
  }

  /// Save dietary preference (Settings dual-mode screen; onboarding writes
  /// its omnivore default through saveAllOnboardingData instead)
  /// Also updates food preferences for excluded foods
  /// Removes auto-avoided foods when dietary preference changes (using preference_source tracking)
  Future<bool> saveDietaryPreference(DietaryPreference? preference) async {
    // Get current user from auth service (works for both session users and restored users)
    final currentUser = _currentUser ?? await _authService.getCurrentUser();

    _report.debug(
      '👤 Dietary preference - Current user: ${currentUser?.id ?? "null"}',
      area: 'onboarding',
    );
    _report.debug(
      '🥗 Dietary preference: ${preference?.name ?? "none"}',
      area: 'onboarding',
    );

    if (currentUser == null) {
      final errorMsg = _contentService.getValue(
        ContentKeys.errorGeneric,
        defaultValue:
            'No user profile found. Please complete user profile first.',
      );
      unawaited(
        _report.fault(
          const LoggedFault(
            'Dietary preference - No current user found',
            context: 'onboarding',
          ),
          area: 'onboarding',
        ),
      );
      state = AsyncError(errorMsg, StackTrace.current);
      return false;
    }

    // Get old dietary preference to determine if it changed
    final oldPreference = currentUser.dietaryPreference;
    final preferenceChanged = oldPreference != preference;

    _report.info(
      '🚀 Dietary preference - Starting save process for user: ${currentUser.id}',
      area: 'onboarding',
    );
    _report.debug(
      '📋 Dietary preference - Old: ${oldPreference?.displayName ?? "none"}, New: ${preference?.displayName ?? "none"}',
      area: 'onboarding',
    );
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _report.debug(
        '📞 Dietary preference - Calling onboarding service',
        area: 'onboarding',
      );
      await _onboardingService.saveDietaryPreference(
        currentUser.id,
        preference,
      );
      _report.info(
        '✅ Dietary preference - Save completed successfully',
        area: 'onboarding',
      );
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
        _report.info(
          '🗑️ Removed $removedCount food avoids for old diet: ${oldPreference.displayName}',
          area: 'onboarding',
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
      unawaited(
        _report.fault(
          state.error!,
          stackTrace: state.stackTrace,
          area: 'onboarding',
          message: 'Dietary preference save failed',
        ),
      );
    } else {
      _report.info(
        '🎉 Dietary preference - Save operation completed without errors',
        area: 'onboarding',
      );
    }

    return !state.hasError;
  }

  /// Save allergies (Settings dual-mode screen; onboarding writes its
  /// no-allergies default through saveAllOnboardingData instead)
  /// Also updates food preferences for allergen-containing foods
  /// Removes auto-avoided foods when allergies are removed (using preference_source tracking)
  Future<bool> saveAllergies(List<Allergy> allergies) async {
    // Get current user from auth service (works for both session users and restored users)
    final currentUser = _currentUser ?? await _authService.getCurrentUser();

    _report.debug(
      '👤 Allergies - Current user: ${currentUser?.id ?? "null"}',
      area: 'onboarding',
    );
    _report.debug(
      '⚠️ Allergies count: ${allergies.length}',
      area: 'onboarding',
    );

    if (currentUser == null) {
      final errorMsg = _contentService.getValue(
        ContentKeys.errorGeneric,
        defaultValue:
            'No user profile found. Please complete user profile first.',
      );
      unawaited(
        _report.fault(
          const LoggedFault(
            'Allergies - No current user found',
            context: 'onboarding',
          ),
          area: 'onboarding',
        ),
      );
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

    _report.info(
      '🚀 Allergies - Starting save process for user: ${currentUser.id}',
      area: 'onboarding',
    );
    _report.debug(
      '📋 Allergies - Removed: ${removedAllergies.map((a) => a.displayName).join(', ')}',
      area: 'onboarding',
    );
    _report.debug(
      '📋 Allergies - Added: ${addedAllergies.map((a) => a.displayName).join(', ')}',
      area: 'onboarding',
    );
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _report.debug(
        '📞 Allergies - Calling onboarding service',
        area: 'onboarding',
      );
      await _onboardingService.saveAllergies(currentUser.id, allergies);
      _report.info(
        '✅ Allergies - Save completed successfully',
        area: 'onboarding',
      );
      // Update our session user reference
      _currentUser = currentUser;

      // Remove food preferences for allergies that were removed
      for (final removedAllergy in removedAllergies) {
        final removedCount = await _authService.removeFoodPreferencesBySource(
          currentUser.id,
          'allergy:${removedAllergy.dbValue}',
        );
        _report.info(
          '🗑️ Removed $removedCount food avoids for allergy: ${removedAllergy.displayName}',
          area: 'onboarding',
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
      unawaited(
        _report.fault(
          state.error!,
          stackTrace: state.stackTrace,
          area: 'onboarding',
          message: 'Allergies save failed',
        ),
      );
    } else {
      _report.info(
        '🎉 Allergies - Save operation completed without errors',
        area: 'onboarding',
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

          _report.info(
            '🍎 Set ${allergyFoods.length} foods to avoid for allergy: ${allergy.displayName}',
            area: 'onboarding',
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

          _report.info(
            '🥗 Set ${dietaryFoods.length} foods to avoid for diet: ${dietaryPreference.displayName}',
            area: 'onboarding',
          );
        }
      }

      _report.info(
        '✅ Food preferences updated for allergen/dietary restrictions',
        area: 'onboarding',
      );
    } catch (e, stackTrace) {
      unawaited(
        _report.fault(
          e,
          stackTrace: stackTrace,
          area: 'onboarding',
          message: 'Failed to update food preferences for allergies',
        ),
      );
      // Don't rethrow - allergy save was successful, this is a best-effort update
    }
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
    // The draft lives outside `state`, so re-assigning an identical
    // `AsyncData(null)` alone would NOT notify (updateShouldNotify compares
    // equal) — force the notification so watchers such as
    // `onboardingPlanPreviewProvider` recompute on every draft change.
    state = const AsyncData(null);
    ref.notifyListeners();
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
    // A passed-but-blank value CLEARS the field (the screens call this per
    // keystroke, so backspacing to empty must not leave the last non-blank
    // fragment behind — a stale draft email would later override the real
    // auth email in saveAllOnboardingData). Only an omitted (null) argument
    // keeps the existing value.
    _updateDraft(
      _draft.copyWith(
        firstName: firstName != null ? () => _nullIfBlank(firstName) : null,
        lastName: lastName != null ? () => _nullIfBlank(lastName) : null,
        email: email != null ? () => _nullIfBlank(email) : null,
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

  /// Fields that were pre-filled from a connected platform and which the
  /// athlete has not since edited. Recorded by the personal-info and
  /// body-composition steps so [clearIntegrationAutofill] can undo exactly
  /// what a disconnect should undo — never an answer the athlete typed.
  final Set<String> _integrationAutofilledFields = {};

  void recordIntegrationAutofill(Set<String> fields) =>
      _integrationAutofilledFields.addAll(fields);

  /// The athlete took ownership of a field; a later disconnect must leave
  /// it alone.
  void releaseIntegrationAutofill(String field) =>
      _integrationAutofilledFields.remove(field);

  bool isIntegrationAutofilled(String field) =>
      _integrationAutofilledFields.contains(field);

  /// Bumped every time [clearIntegrationAutofill] runs. Screens watch this
  /// rather than inferring a disconnect from a field going null: draft
  /// writes are interleaved (the birth-year wheel notifies mid-autofill,
  /// before the names have been written), so "null" cannot distinguish
  /// "cleared" from "not written yet".
  int get autofillClearedTick => _autofillClearedTick;
  int _autofillClearedTick = 0;

  /// Clears the answers a connected platform supplied, on disconnect.
  ///
  /// Only touches fields still recorded as autofilled — anything the
  /// athlete typed or picked over the top is theirs and survives.
  void clearIntegrationAutofill() {
    if (_integrationAutofilledFields.isEmpty) return;
    final fields = Set<String>.from(_integrationAutofilledFields);
    _integrationAutofilledFields.clear();
    _autofillClearedTick++;

    _updateDraft(
      _draft.copyWith(
        firstName: fields.contains('firstName') ? () => null : null,
        lastName: fields.contains('lastName') ? () => null : null,
        email: fields.contains('email') ? () => null : null,
        gender: fields.contains('gender') ? () => null : null,
        birthYear: fields.contains('birthYear') ? () => null : null,
        weightPounds: fields.contains('weightPounds') ? () => null : null,
      ),
    );
  }

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
  // BATCH SAVE (post-onboarding auth)
  // ============================================================================

  /// Save the accumulated draft to DB and Supabase
  /// This is called after auth (registered or anonymous) to save everything at once
  /// [authProvider] - 'anonymous', 'email', 'google', 'apple'
  /// [isAnonymous] - false when user signs up with email/OAuth
  Future<bool> saveAllOnboardingData({
    String authProvider = 'anonymous',
    bool isAnonymous = true,
  }) async {
    _report.info(
      '📦 Starting batch save of all onboarding data (authProvider: $authProvider, isAnonymous: $isAnonymous)',
      area: 'onboarding',
    );

    // Guard the invalid state where the user reached the post-onboarding screen
    // without a completed profile draft (e.g. the app was relaunched
    // mid-onboarding and the in-memory draft was lost). Previously this threw
    // inside AsyncValue.guard, surfacing as an AsyncError that the Sentry
    // ProviderObserver reported (MEALVANA-ENDURANCE-DEV-4M). There is nothing to
    // save and retrying can't help, so fail cleanly and let the caller route the
    // user back to finish onboarding.
    if (!hasCompletedProfileDraft) {
      _report.info(
        '⚠️ saveAllOnboardingData: profile draft incomplete — cannot create '
        'user; returning failure without throwing.',
        area: 'onboarding',
      );
      state = const AsyncData(null);
      return false;
    }

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

      _report.breadcrumb(
        'saveAllOnboardingData: creating user profile',
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
      _report.info(
        '✅ User profile created: ${_currentUser!.id}',
        area: 'onboarding',
      );

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
      _report.breadcrumb(
        'saveAllOnboardingData: defaulting diet/allergies',
        category: 'onboarding',
      );
      await _onboardingService.saveDietaryPreference(
        userId,
        DietaryPreference.omnivore,
      );
      await _onboardingService.saveAllergies(userId, const []);
      _report.info(
        '✅ Diet/allergy defaults saved (omnivore / none)',
        area: 'onboarding',
      );

      // 3. Persist the survey row (sports/goals/pitfalls + payload flags).
      // The repository reports Drift constraint failures to Sentry and
      // rethrows — a failed survey write fails the save visibly.
      _report.breadcrumb(
        'saveAllOnboardingData: writing survey',
        category: 'onboarding',
      );
      await ref
          .read(onboardingSurveyRepositoryProvider)
          .saveSurveyFromDraft(userId: userId, draft: draft);
      _report.info('✅ Onboarding survey saved', area: 'onboarding');

      // 4. Persist plan-reveal edits as NutritionTargetOverrides — only the
      // fields the user actually touched (null = algorithm default, per the
      // overrides contract).
      if (draft.planEdits.hasAnyEdit) {
        _report.breadcrumb(
          'saveAllOnboardingData: writing plan-edit overrides',
          category: 'onboarding',
        );
        await _savePlanEditOverrides(userId, draft.planEdits);
        _report.info('✅ Plan-edit overrides saved', area: 'onboarding');
      }

      // NOTE: onboarding no longer pre-computes or writes "default" formula
      // pins. The default formula is resolved at generation time by the
      // nutrition-plan edge function (`emit_ephemeral_default_formula`), so
      // there is nothing to seed here. Only user-created pins live in
      // `formula_pins`.

      // Best-effort local snapshot OUTSIDE Drift (SharedPreferences), so the
      // delete-and-recreate upgrade path can restore an anonymous user whose
      // data never reached Supabase (plan §7). Never fails the save.
      //
      // Re-read the profile first: `_currentUser` was captured at step 1,
      // BEFORE the diet/allergy defaults and the plan-edit overrides were
      // written — snapshotting that stale copy meant a restore silently
      // dropped dietary_preference, allergies and nutrition_target_overrides.
      final userRepository = await ref.read(userRepositoryProvider.future);
      final finishedProfile = await userRepository.getUserProfileById(userId);
      if (finishedProfile != null) {
        _currentUser = finishedProfile;
      }
      await ref
          .read(onboardingSnapshotServiceProvider)
          .writeSnapshot(profile: _currentUser!, draft: draft);

      // Clear the draft.
      _draft = const OnboardingDraft();

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
      _report.info(
        '🎉 All onboarding data saved successfully',
        area: 'onboarding',
      );
    });

    if (state.hasError) {
      // No silent failures: the batch save is the moment onboarding data
      // becomes durable — its failure must reach Sentry even though the UI
      // also surfaces the AsyncError.
      await _report.fault(
        state.error!,
        stackTrace: state.stackTrace,
        area: 'onboarding',
        tags: {
          'feature': 'onboarding',
          'step': 'batch_save',
          'auth_provider': authProvider,
        },
        message: 'saveAllOnboardingData failed',
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
      _report.info(
        '📤 Onboarding data uploaded to Supabase',
        area: 'onboarding',
      );
    } else {
      unawaited(
        _report.fault(
          const LoggedFault(
            'Onboarding data upload incomplete; rows stay needs_upload and '
            'retry on the next sync',
            context: 'onboarding',
          ),
          area: 'onboarding',
          extra: {'failed_repositories': failedRepos, 'userId': userId},
        ),
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

      // Clear the draft
      _draft = const OnboardingDraft();
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
  /// This method uses the consolidated `migrateUserData` in the diagnostic
  /// DAO, which re-keys ALL user-scoped tables (activities, events, food
  /// preferences, user foods, carb loading, integrations, surveys, meal logs,
  /// saved meals, formula kit, race checklists, daily macro targets, TP
  /// writeback log) — see `DiagnosticDao.migrateUserData` for the canonical
  /// list rather than restating it here.
  Future<void> _migrateOnboardingDataToNewUser(String newUserId) async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final database = ref.read(appDatabaseProvider);

      // Get the temp user ID that was used during onboarding
      final tempUserId = prefs.getString(_onboardingTempUserIdKey);

      if (tempUserId == null) {
        _report.info(
          'ℹ️ No temp user ID found - skipping migration',
          area: 'onboarding',
        );
        return;
      }

      if (tempUserId == newUserId) {
        _report.info(
          'ℹ️ Temp user ID matches new user ID - no migration needed',
          area: 'onboarding',
        );
        await prefs.remove(_onboardingTempUserIdKey);
        return;
      }

      _report.info(
        '🔄 Migrating ALL onboarding data from temp user $tempUserId to new user $newUserId',
        area: 'onboarding',
      );

      // Use the consolidated migration method that handles ALL user-scoped tables
      await database.diagnosticDao.migrateUserData(tempUserId, newUserId);

      // Clear the temp user ID from preferences
      await prefs.remove(_onboardingTempUserIdKey);

      _report.info(
        '✅ Migration complete - all user data migrated and temp user ID cleared',
        area: 'onboarding',
      );
    } catch (e, stackTrace) {
      // Don't fail onboarding if migration fails - log and continue
      unawaited(
        _report.fault(
          e,
          stackTrace: stackTrace,
          area: 'onboarding',
          message: 'Failed to migrate onboarding data',
        ),
      );
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
    } catch (e, stackTrace) {
      // Don't fail onboarding — push data will just queue on Garmin's side
      unawaited(
        _report.fault(
          e,
          stackTrace: stackTrace,
          area: 'onboarding',
          message: 'Failed to sync Garmin user mapping',
        ),
      );
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
        unawaited(
          _report.degraded(
            const LoggedFault(
              'No user profile found to upload',
              context: 'onboarding',
            ),
            area: 'onboarding',
          ),
        );
        return false;
      }

      _report.info(
        '📤 Uploading user profile to Supabase...',
        area: 'onboarding',
      );
      await userSyncHandler.uploadUserProfile(userProfile);

      // uploadUserProfile() clears needs_upload only on a successful upsert, so
      // a still-dirty row means the push failed even though nothing threw.
      final uploaded = (await readProfile())?.needsUpload == false;
      if (uploaded) {
        _report.info(
          '✅ User profile uploaded to Supabase successfully',
          area: 'onboarding',
        );
      } else {
        unawaited(
          _report.fault(
            const LoggedFault(
              'User profile upload did not reach Supabase (still dirty); '
              'deferring to post-onboarding upload',
              context: 'onboarding',
            ),
            area: 'onboarding',
            extra: {'userId': userId},
          ),
        );
      }
      return uploaded;
    } catch (e, stackTrace) {
      // Don't fail onboarding if upload fails - the post-save upload and later
      // syncs retry it. But log it, as this may cause FK violations meanwhile.
      unawaited(
        _report.fault(
          e,
          stackTrace: stackTrace,
          area: 'onboarding',
          message:
              'Failed to upload user profile to Supabase; this may cause FK '
              'violations when syncing activities',
        ),
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
