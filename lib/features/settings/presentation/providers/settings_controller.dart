import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../auth/data/user_repository.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../../nutrition_plan/domain/run_parameters.dart';
import '../../domain/settings_state.dart';

part 'settings_controller.g.dart';

/// Controller for settings screen following Andrea Bizzotto FOA patterns
@riverpod
class SettingsController extends _$SettingsController {
  ContentService get _contentService => ref.read(contentServiceProvider);
  Future<UserRepository> get _userRepository async => await ref.read(userRepositoryProvider.future);

  @override
  FutureOr<SettingsState> build() async {
    // Load content synchronously from in-memory cache
    final title = _contentService.getValue(ContentKeys.settingsTitle, defaultValue: 'Settings');
    final profileSectionTitle = _contentService.getValue(ContentKeys.settingsProfileSection, defaultValue: 'Profile');
    final preferenceSectionTitle = _contentService.getValue(ContentKeys.settingsPreferencesSection, defaultValue: 'Preferences');
    final genderLabel = _contentService.getValue(ContentKeys.settingsGenderLabel, defaultValue: 'Gender');
    final birthdayLabel = _contentService.getValue(ContentKeys.settingsBirthdayLabel, defaultValue: 'Birthday');
    final heightLabel = _contentService.getValue(ContentKeys.settingsHeightLabel, defaultValue: 'Height');
    final weightLabel = _contentService.getValue(ContentKeys.settingsWeightLabel, defaultValue: 'Weight');
    final waterBottleLabel = _contentService.getValue(ContentKeys.settingsWaterBottleLabel, defaultValue: 'Run with water bottle');
    final distanceUnitLabel = _contentService.getValue(ContentKeys.settingsDistanceUnitLabel, defaultValue: 'Distance unit');
    final paceUnitLabel = _contentService.getValue(ContentKeys.settingsPaceUnitLabel, defaultValue: 'Pace unit');
    final gutTrainingLabel = _contentService.getValue(ContentKeys.settingsGutTrainingLabel, defaultValue: 'Gut training level');
    final saveButtonText = _contentService.getValue(ContentKeys.settingsSaveButton, defaultValue: 'Save Changes');

    // Load current user profile
    final userRepository = await _userRepository;
    final userProfile = await userRepository.getCurrentUser();

    return SettingsState(
      title: title,
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
      gender: userProfile?.gender,
      birthday: userProfile?.birthday,
      heightFeet: userProfile?.heightFeet,
      heightInches: userProfile?.heightInches,
      weightPounds: userProfile?.weightPounds,
      runsWithWaterBottle: userProfile?.runsWithWaterBottle ?? false,
      // Default preferences - TODO: load from user preferences
      preferredDistanceUnit: DistanceUnit.miles,
      preferredPaceUnit: PaceUnit.minPerMile,
      gutTrainingLevel: userProfile?.gutTraining ?? GutTraining.moderate,
      // Sport preferences
      giSensitivity: userProfile?.giSensitivity,
      ftpWatts: userProfile?.ftpWatts,
      typicalBikeBottles: userProfile?.typicalBikeBottles,
      hasAeroBottle: userProfile?.hasAeroBottle,
      hasBentoBox: userProfile?.hasBentoBox,
      cssPacePer100mSeconds: userProfile?.cssPacePer100mSeconds,
      typicalWetsuit: userProfile?.typicalWetsuit,
      typicalSwimCapType: userProfile?.typicalSwimCapType,
      // User identity fields (needed for database operations)
      userId: userProfile?.id,
      createdAt: userProfile?.createdAt,
      updatedAt: userProfile?.updatedAt,
    );
  }

  /// Update gender
  Future<void> updateGender(Gender gender) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(
      gender: gender,
      isSaving: true,
    ));

    await _saveProfile();
  }

  /// Update birthday
  Future<void> updateBirthday(DateTime birthday) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(
      birthday: birthday,
      isSaving: true,
    ));

    await _saveProfile();
  }

  /// Update height
  Future<void> updateHeight(int feet, int inches) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(
      heightFeet: feet,
      heightInches: inches,
      isSaving: true,
    ));

    await _saveProfile();
  }

  /// Update weight
  Future<void> updateWeight(double pounds) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(
      weightPounds: pounds,
      isSaving: true,
    ));

    await _saveProfile();
  }

  /// Update water bottle preference
  Future<void> updateWaterBottle(bool runsWithWaterBottle) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(
      runsWithWaterBottle: runsWithWaterBottle,
      isSaving: true,
    ));

    await _saveProfile();
  }

  /// Update distance unit preference
  Future<void> updateDistanceUnit(DistanceUnit unit) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(
      preferredDistanceUnit: unit,
      isSaving: true,
    ));

    await _saveProfile();
  }

  /// Update pace unit preference
  Future<void> updatePaceUnit(PaceUnit unit) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(
      preferredPaceUnit: unit,
      isSaving: true,
    ));

    await _saveProfile();
  }

  /// Update gut training level
  Future<void> updateGutTraining(GutTraining level) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(
      gutTrainingLevel: level,
      isSaving: true,
    ));

    await _saveProfile();
  }

  /// Update GI sensitivity
  Future<void> updateGISensitivity(bool giSensitivity) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(
      giSensitivity: giSensitivity,
      isSaving: true,
    ));

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

    state = AsyncData(currentState.copyWith(
      ftpWatts: ftpWatts,
      typicalBikeBottles: typicalBikeBottles,
      hasAeroBottle: hasAeroBottle,
      hasBentoBox: hasBentoBox,
      isSaving: true,
    ));

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

    state = AsyncData(currentState.copyWith(
      cssPacePer100mSeconds: cssPacePer100mSeconds,
      typicalWetsuit: typicalWetsuit,
      typicalSwimCapType: typicalSwimCapType,
      isSaving: true,
    ));

    await _saveProfile();
  }

  /// Save profile changes (both local and Supabase)
  Future<void> _saveProfile() async {
    final currentState = state.value;
    if (currentState == null) return;

    state = await AsyncValue.guard(() async {
      final updatedProfile = UserProfile(
        id: currentState.userId ?? '', // Use stored user ID (which is the device_id)
        gender: currentState.gender ?? Gender.other,
        birthday: currentState.birthday ?? DateTime.now(),
        heightFeet: currentState.heightFeet ?? 5,
        heightInches: currentState.heightInches ?? 8,
        weightPounds: currentState.weightPounds ?? 150.0,
        runsWithWaterBottle: currentState.runsWithWaterBottle,
        createdAt: currentState.createdAt ?? DateTime.now(), // Use stored createdAt
        updatedAt: DateTime.now(), // Update to current time
        gutTraining: currentState.gutTrainingLevel,
        appVersion: '1.0.0', // Default app version
        // Sport preferences
        giSensitivity: currentState.giSensitivity,
        ftpWatts: currentState.ftpWatts,
        typicalBikeBottles: currentState.typicalBikeBottles,
        hasAeroBottle: currentState.hasAeroBottle,
        hasBentoBox: currentState.hasBentoBox,
        cssPacePer100mSeconds: currentState.cssPacePer100mSeconds,
        typicalWetsuit: currentState.typicalWetsuit,
        typicalSwimCapType: currentState.typicalSwimCapType,
      );

      // Update existing profile (not create new one)
      final userRepository = await _userRepository;
      await userRepository.updateUserProfile(updatedProfile);

      // TODO: Add Supabase sync once implemented
      // await _userRepository.syncToSupabase();

      return currentState.copyWith(
        isSaving: false,
        errorMessage: null,
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
    return _contentService.getValue(ContentKeys.errorGeneric, 
        defaultValue: error ?? 'Something went wrong. Please try again.');
  }
}