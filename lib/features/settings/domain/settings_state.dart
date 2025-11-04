import '../../auth/domain/user_preferences.dart';
import '../../nutrition_plan/domain/run_parameters.dart';

/// State for the settings screen
class SettingsState {
  final String title;
  final String profileSectionTitle;
  final String preferenceSectionTitle;
  final String genderLabel;
  final String birthdayLabel;
  final String heightLabel;
  final String weightLabel;
  final String waterBottleLabel;
  final String distanceUnitLabel;
  final String paceUnitLabel;
  final String gutTrainingLabel;
  final String saveButtonText;
  final bool isSaving;
  final String? errorMessage;

  // Sport settings section labels
  final String sportSettingsSectionTitle;
  final String giSensitivityLabel;
  final String cyclingSectionTitle;
  final String swimmingSectionTitle;

  // User data
  final Gender? gender;
  final DateTime? birthday;
  final int? heightFeet;
  final int? heightInches;
  final double? weightPounds;
  final bool runsWithWaterBottle;
  final DistanceUnit preferredDistanceUnit;
  final PaceUnit preferredPaceUnit;
  final GutTraining gutTrainingLevel;

  // Sport preferences
  final bool? giSensitivity;
  final int? ftpWatts;
  final int? typicalBikeBottles;
  final bool? hasAeroBottle;
  final bool? hasBentoBox;
  final int? cssPacePer100mSeconds;
  final bool? typicalWetsuit;
  final String? typicalSwimCapType;

  const SettingsState({
    required this.title,
    required this.profileSectionTitle,
    required this.preferenceSectionTitle,
    required this.genderLabel,
    required this.birthdayLabel,
    required this.heightLabel,
    required this.weightLabel,
    required this.waterBottleLabel,
    required this.distanceUnitLabel,
    required this.paceUnitLabel,
    required this.gutTrainingLabel,
    required this.saveButtonText,
    this.sportSettingsSectionTitle = 'Sport Settings',
    this.giSensitivityLabel = 'GI Sensitivity',
    this.cyclingSectionTitle = 'Cycling',
    this.swimmingSectionTitle = 'Swimming',
    this.isSaving = false,
    this.errorMessage,
    this.gender,
    this.birthday,
    this.heightFeet,
    this.heightInches,
    this.weightPounds,
    this.runsWithWaterBottle = false,
    this.preferredDistanceUnit = DistanceUnit.miles,
    this.preferredPaceUnit = PaceUnit.minPerMile,
    this.gutTrainingLevel = GutTraining.moderate,
    this.giSensitivity,
    this.ftpWatts,
    this.typicalBikeBottles,
    this.hasAeroBottle,
    this.hasBentoBox,
    this.cssPacePer100mSeconds,
    this.typicalWetsuit,
    this.typicalSwimCapType,
  });

  SettingsState copyWith({
    String? title,
    String? profileSectionTitle,
    String? preferenceSectionTitle,
    String? genderLabel,
    String? birthdayLabel,
    String? heightLabel,
    String? weightLabel,
    String? waterBottleLabel,
    String? distanceUnitLabel,
    String? paceUnitLabel,
    String? gutTrainingLabel,
    String? saveButtonText,
    String? sportSettingsSectionTitle,
    String? giSensitivityLabel,
    String? cyclingSectionTitle,
    String? swimmingSectionTitle,
    bool? isSaving,
    String? errorMessage,
    Gender? gender,
    DateTime? birthday,
    int? heightFeet,
    int? heightInches,
    double? weightPounds,
    bool? runsWithWaterBottle,
    DistanceUnit? preferredDistanceUnit,
    PaceUnit? preferredPaceUnit,
    GutTraining? gutTrainingLevel,
    bool? giSensitivity,
    int? ftpWatts,
    int? typicalBikeBottles,
    bool? hasAeroBottle,
    bool? hasBentoBox,
    int? cssPacePer100mSeconds,
    bool? typicalWetsuit,
    String? typicalSwimCapType,
  }) {
    return SettingsState(
      title: title ?? this.title,
      profileSectionTitle: profileSectionTitle ?? this.profileSectionTitle,
      preferenceSectionTitle: preferenceSectionTitle ?? this.preferenceSectionTitle,
      genderLabel: genderLabel ?? this.genderLabel,
      birthdayLabel: birthdayLabel ?? this.birthdayLabel,
      heightLabel: heightLabel ?? this.heightLabel,
      weightLabel: weightLabel ?? this.weightLabel,
      waterBottleLabel: waterBottleLabel ?? this.waterBottleLabel,
      distanceUnitLabel: distanceUnitLabel ?? this.distanceUnitLabel,
      paceUnitLabel: paceUnitLabel ?? this.paceUnitLabel,
      gutTrainingLabel: gutTrainingLabel ?? this.gutTrainingLabel,
      saveButtonText: saveButtonText ?? this.saveButtonText,
      sportSettingsSectionTitle: sportSettingsSectionTitle ?? this.sportSettingsSectionTitle,
      giSensitivityLabel: giSensitivityLabel ?? this.giSensitivityLabel,
      cyclingSectionTitle: cyclingSectionTitle ?? this.cyclingSectionTitle,
      swimmingSectionTitle: swimmingSectionTitle ?? this.swimmingSectionTitle,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      heightFeet: heightFeet ?? this.heightFeet,
      heightInches: heightInches ?? this.heightInches,
      weightPounds: weightPounds ?? this.weightPounds,
      runsWithWaterBottle: runsWithWaterBottle ?? this.runsWithWaterBottle,
      preferredDistanceUnit: preferredDistanceUnit ?? this.preferredDistanceUnit,
      preferredPaceUnit: preferredPaceUnit ?? this.preferredPaceUnit,
      gutTrainingLevel: gutTrainingLevel ?? this.gutTrainingLevel,
      giSensitivity: giSensitivity ?? this.giSensitivity,
      ftpWatts: ftpWatts ?? this.ftpWatts,
      typicalBikeBottles: typicalBikeBottles ?? this.typicalBikeBottles,
      hasAeroBottle: hasAeroBottle ?? this.hasAeroBottle,
      hasBentoBox: hasBentoBox ?? this.hasBentoBox,
      cssPacePer100mSeconds: cssPacePer100mSeconds ?? this.cssPacePer100mSeconds,
      typicalWetsuit: typicalWetsuit ?? this.typicalWetsuit,
      typicalSwimCapType: typicalSwimCapType ?? this.typicalSwimCapType,
    );
  }
}