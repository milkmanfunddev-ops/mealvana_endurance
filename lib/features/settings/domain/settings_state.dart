import '../../auth/domain/user_preferences.dart';
import '../../nutrition_plan/domain/run_parameters.dart';
import '../../nutrition_plan/domain/nutrition_target_overrides.dart';
import '../../onboarding/domain/dietary_preference.dart';
import '../../onboarding/domain/allergy.dart';

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
  final UnitSystem unitSystem;

  DistanceUnit get preferredDistanceUnit => unitSystem == UnitSystem.metric
      ? DistanceUnit.kilometers
      : DistanceUnit.miles;
  PaceUnit get preferredPaceUnit =>
      unitSystem == UnitSystem.metric ? PaceUnit.minPerKm : PaceUnit.minPerMile;

  final GutTraining gutTrainingLevel;
  final SweatRateCat sweatRate;

  // Sport preferences
  final bool? giSensitivity;
  final int? ftpWatts;
  final int? typicalBikeBottles;
  final bool? hasAeroBottle;
  final bool? hasBentoBox;
  final int? cssPacePer100mSeconds;
  final bool? typicalWetsuit;
  final String? typicalSwimCapType;

  // Dietary preferences and allergies
  final DietaryPreference? dietaryPreference;
  final List<Allergy> allergies;

  // User identity fields (needed for database operations)
  final String? userId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Auth fields for account section
  final bool isAnonymous;
  final String authProvider; // 'anonymous', 'email', 'google', 'apple'
  final String? authUserId; // Supabase auth.uid()
  final String? email; // User's email (if available)

  // Coach mode
  final bool isCoach;

  // Optional name fields for coach mode athlete identification
  final String? firstName;
  final String? lastName;

  // Nutrition target overrides
  final NutritionTargetOverrides? nutritionTargetOverrides;

  /// Generate a short, shareable athlete code from the user ID
  /// Format: ATH-XXXXXXXX (first 8 chars of UUID, uppercase)
  /// Returns null if no userId
  String? get athleteCode {
    if (userId == null) return null;
    // Remove hyphens and take first 8 characters, uppercase
    final cleanId = userId!.replaceAll('-', '').toUpperCase();
    if (cleanId.length < 8) return null;
    return 'ATH-${cleanId.substring(0, 8)}';
  }

  // Account section labels
  final String accountSectionTitle;
  final String accountStatusAnonymous;
  final String accountStatusAuthenticated;
  final String createAccountButton;
  final String signOutButton;

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
    this.unitSystem = UnitSystem.imperial,
    this.gutTrainingLevel = GutTraining.moderate,
    this.sweatRate = SweatRateCat.medium,
    this.giSensitivity,
    this.ftpWatts,
    this.typicalBikeBottles,
    this.hasAeroBottle,
    this.hasBentoBox,
    this.cssPacePer100mSeconds,
    this.typicalWetsuit,
    this.typicalSwimCapType,
    this.dietaryPreference,
    this.allergies = const [],
    this.userId,
    this.createdAt,
    this.updatedAt,
    this.isAnonymous = true,
    this.authProvider = 'anonymous',
    this.authUserId,
    this.email,
    this.isCoach = false,
    this.firstName,
    this.lastName,
    this.nutritionTargetOverrides,
    this.accountSectionTitle = 'Account',
    this.accountStatusAnonymous = 'Not signed in',
    this.accountStatusAuthenticated = 'Signed in',
    this.createAccountButton = 'Create Account',
    this.signOutButton = 'Sign Out',
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
    UnitSystem? unitSystem,
    GutTraining? gutTrainingLevel,
    SweatRateCat? sweatRate,
    bool? giSensitivity,
    int? ftpWatts,
    int? typicalBikeBottles,
    bool? hasAeroBottle,
    bool? hasBentoBox,
    int? cssPacePer100mSeconds,
    bool? typicalWetsuit,
    String? typicalSwimCapType,
    DietaryPreference? dietaryPreference,
    List<Allergy>? allergies,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isAnonymous,
    String? authProvider,
    String? authUserId,
    String? email,
    bool? isCoach,
    String? firstName,
    String? lastName,
    NutritionTargetOverrides? nutritionTargetOverrides,
    String? accountSectionTitle,
    String? accountStatusAnonymous,
    String? accountStatusAuthenticated,
    String? createAccountButton,
    String? signOutButton,
  }) {
    return SettingsState(
      title: title ?? this.title,
      profileSectionTitle: profileSectionTitle ?? this.profileSectionTitle,
      preferenceSectionTitle:
          preferenceSectionTitle ?? this.preferenceSectionTitle,
      genderLabel: genderLabel ?? this.genderLabel,
      birthdayLabel: birthdayLabel ?? this.birthdayLabel,
      heightLabel: heightLabel ?? this.heightLabel,
      weightLabel: weightLabel ?? this.weightLabel,
      waterBottleLabel: waterBottleLabel ?? this.waterBottleLabel,
      distanceUnitLabel: distanceUnitLabel ?? this.distanceUnitLabel,
      paceUnitLabel: paceUnitLabel ?? this.paceUnitLabel,
      gutTrainingLabel: gutTrainingLabel ?? this.gutTrainingLabel,
      saveButtonText: saveButtonText ?? this.saveButtonText,
      sportSettingsSectionTitle:
          sportSettingsSectionTitle ?? this.sportSettingsSectionTitle,
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
      unitSystem: unitSystem ?? this.unitSystem,
      gutTrainingLevel: gutTrainingLevel ?? this.gutTrainingLevel,
      sweatRate: sweatRate ?? this.sweatRate,
      giSensitivity: giSensitivity ?? this.giSensitivity,
      ftpWatts: ftpWatts ?? this.ftpWatts,
      typicalBikeBottles: typicalBikeBottles ?? this.typicalBikeBottles,
      hasAeroBottle: hasAeroBottle ?? this.hasAeroBottle,
      hasBentoBox: hasBentoBox ?? this.hasBentoBox,
      cssPacePer100mSeconds:
          cssPacePer100mSeconds ?? this.cssPacePer100mSeconds,
      typicalWetsuit: typicalWetsuit ?? this.typicalWetsuit,
      typicalSwimCapType: typicalSwimCapType ?? this.typicalSwimCapType,
      dietaryPreference: dietaryPreference ?? this.dietaryPreference,
      allergies: allergies ?? this.allergies,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      authProvider: authProvider ?? this.authProvider,
      authUserId: authUserId ?? this.authUserId,
      email: email ?? this.email,
      isCoach: isCoach ?? this.isCoach,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      nutritionTargetOverrides:
          nutritionTargetOverrides ?? this.nutritionTargetOverrides,
      accountSectionTitle: accountSectionTitle ?? this.accountSectionTitle,
      accountStatusAnonymous:
          accountStatusAnonymous ?? this.accountStatusAnonymous,
      accountStatusAuthenticated:
          accountStatusAuthenticated ?? this.accountStatusAuthenticated,
      createAccountButton: createAccountButton ?? this.createAccountButton,
      signOutButton: signOutButton ?? this.signOutButton,
    );
  }
}
