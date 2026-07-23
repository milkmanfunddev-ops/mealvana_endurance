import 'package:mealvana_endurance/features/onboarding/domain/dietary_preference.dart';
import 'package:mealvana_endurance/features/onboarding/domain/allergy.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_target_overrides.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/enums.dart';

/// Domain models for user authentication and preferences
/// Removed Hive dependencies as part of migration to Drift database
class UserProfile {
  final String id;

  // Auth fields for Supabase authentication migration
  final String deviceId; // Legacy device identifier
  final String? authUserId; // Supabase auth.uid() - canonical user ID
  final String authProvider; // 'anonymous', 'email', 'google', 'apple'
  final bool isAnonymous; // True until account is linked

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTH STATE DOCUMENTATION
  // ═══════════════════════════════════════════════════════════════════════════
  // The auth state is determined by THREE fields that MUST be kept in sync:
  //
  // ANONYMOUS USER:
  //   isAnonymous = true
  //   authProvider = 'anonymous'
  //   authUserId = null
  //
  // AUTHENTICATED USER (email/google/apple):
  //   isAnonymous = false
  //   authProvider = 'email' | 'google' | 'apple'
  //   authUserId = <supabase auth.uid()>
  //
  // CANONICAL CHECK: Always use `isAnonymousUser` getter (not raw field checks)
  // ═══════════════════════════════════════════════════════════════════════════

  final Gender gender;
  final DateTime birthday;
  final int heightFeet;
  final int heightInches;
  final double weightPounds;
  final bool runsWithWaterBottle;
  final DateTime createdAt;
  final DateTime updatedAt;
  final GutTraining gutTraining;
  final SweatRateCat sweatRate;
  final bool onboardingCompleted;
  final String appVersion;
  final bool swipeHintShown;

  // Unit preferences
  final UnitSystem unitSystem;

  DistanceUnit get preferredDistanceUnit => unitSystem == UnitSystem.metric
      ? DistanceUnit.kilometers
      : DistanceUnit.miles;
  PaceUnit get preferredPaceUnit =>
      unitSystem == UnitSystem.metric ? PaceUnit.minPerKm : PaceUnit.minPerMile;

  // Sport-specific preferences
  final bool? giSensitivity;
  final int? ftpWatts;
  final int? typicalBikeBottles;
  final bool? hasAeroBottle;
  final bool? hasBentoBox;
  final int? cssPacePer100mSeconds;
  final bool? typicalWetsuit;
  final String? typicalSwimCapType;

  // Default pace/speed for workout estimation
  final double? defaultRunningPaceMinPerMile;
  final double? defaultCyclingSpeedMph;
  final int? defaultSwimmingPacePer100Sec;

  // Dietary preference and allergies (for onboarding revamp)
  final DietaryPreference? dietaryPreference;
  final List<Allergy> allergies;

  // NOTE: isCoach field removed - coach status is now determined by
  // checking the coaches table for an approved record.
  // Use CoachRepository.isUserApprovedCoach(userId) instead.

  // Sharing preferences
  final String? senderName; // Display name used when sharing plans

  // User identity - optional for coach mode athlete identification
  final String? firstName;
  final String? lastName;

  // Contact information
  final String? email;

  // Nutrition target overrides - user-configured default macro targets
  final NutritionTargetOverrides? nutritionTargetOverrides;

  // Daily macro calculation fields
  final double? bodyFatPct;
  final Lifestyle lifestyle;
  final double? typicalWeeklyHours;
  final bool carbCycleOptIn;
  final TrainingPhase trainingPhase;

  // Sweat profile fields (Phase 2 — hydration/sodium transparency)
  /// Sodium concentration category for sweat; null means use algorithmic default ('average').
  final SweatSodiumCat? sweatSodium;

  /// Known sweat rate (ml/hr) from a personal sweat test; null = algorithmic estimate.
  final int? knownSweatRateMlPerHour;

  /// Known sodium concentration (mg/L) from a personal sweat test; null = algorithmic estimate.
  final int? knownSodiumConcentrationMgPerLiter;

  /// Date the sweat test was performed.
  final DateTime? sweatTestDate;

  /// Source of the sweat test data.
  /// Values: 'self_calculated', 'commercial_test', 'gatorade_gx', 'estimated', 'other'
  final String? sweatTestSource;

  /// Timestamp of the last weight_pounds update. Used by the macro edge
  /// function to resolve precedence between user-entered and Garmin values.
  final DateTime? weightPoundsUpdatedAt;

  /// Timestamp of the last body_fat_pct update. Used by the macro edge
  /// function to resolve precedence between user-entered and Garmin values.
  final DateTime? bodyFatPctUpdatedAt;

  UserProfile({
    required this.id,
    required this.deviceId,
    this.authUserId,
    this.authProvider = 'anonymous',
    this.isAnonymous = true,
    required this.gender,
    required this.birthday,
    required this.heightFeet,
    required this.heightInches,
    required this.weightPounds,
    required this.runsWithWaterBottle,
    required this.createdAt,
    required this.updatedAt,
    this.gutTraining = GutTraining.moderate,
    this.sweatRate = SweatRateCat.medium,
    this.onboardingCompleted = false,
    required this.appVersion,
    this.swipeHintShown = false,
    // Unit preferences
    this.unitSystem = UnitSystem.imperial,
    // Sport preferences
    this.giSensitivity,
    this.ftpWatts,
    this.typicalBikeBottles,
    this.hasAeroBottle,
    this.hasBentoBox,
    this.cssPacePer100mSeconds,
    this.typicalWetsuit,
    this.typicalSwimCapType,
    // Default pace/speed for workout estimation
    this.defaultRunningPaceMinPerMile,
    this.defaultCyclingSpeedMph,
    this.defaultSwimmingPacePer100Sec,
    // Dietary preference and allergies
    this.dietaryPreference,
    this.allergies = const [],
    // Sharing preferences
    this.senderName,
    // User identity
    this.firstName,
    this.lastName,
    // Contact information
    this.email,
    // Nutrition target overrides
    this.nutritionTargetOverrides,
    // Daily macro calculation fields
    this.bodyFatPct,
    this.lifestyle = Lifestyle.mixed,
    this.typicalWeeklyHours,
    this.carbCycleOptIn = false,
    this.trainingPhase = TrainingPhase.base,
    // Sweat profile fields
    this.sweatSodium,
    this.knownSweatRateMlPerHour,
    this.knownSodiumConcentrationMgPerLiter,
    this.sweatTestDate,
    this.sweatTestSource,
    // Garmin precedence timestamps
    this.weightPoundsUpdatedAt,
    this.bodyFatPctUpdatedAt,
  });

  /// Returns the best available display name for the user.
  /// Priority: firstName > lastName > userId fallback
  String get displayName {
    if (firstName != null && firstName!.isNotEmpty) {
      if (lastName != null && lastName!.isNotEmpty) {
        return '$firstName $lastName';
      }
      return firstName!;
    }
    if (lastName != null && lastName!.isNotEmpty) {
      return lastName!;
    }
    // Fallback to shortened user ID
    return 'Athlete ${id.substring(0, 8).toUpperCase()}';
  }

  /// Returns just the first name if available, otherwise a shorter fallback
  String get shortDisplayName {
    if (firstName != null && firstName!.isNotEmpty) {
      return firstName!;
    }
    if (lastName != null && lastName!.isNotEmpty) {
      return lastName!;
    }
    return 'Athlete ${id.substring(0, 6).toUpperCase()}';
  }

  /// Calculate age from birthday
  int get age {
    final now = DateTime.now();
    int age = now.year - birthday.year;
    if (now.month < birthday.month ||
        (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }
    return age;
  }

  /// Calculate total height in inches
  int get totalHeightInches => (heightFeet * 12) + heightInches;

  /// Get gut training level as string value
  GutTrainingLevel get gutTrainingLevel {
    switch (gutTraining) {
      case GutTraining.low:
        return GutTrainingLevel.low;
      case GutTraining.moderate:
        return GutTrainingLevel.moderate;
      case GutTraining.high:
        return GutTrainingLevel.high;
    }
  }

  /// CANONICAL CHECK: Whether this user is anonymous (not linked to email/OAuth)
  ///
  /// Use this getter instead of checking `isAnonymous`, `authProvider`, or
  /// `authUserId` individually to ensure consistent behavior across the app.
  bool get isAnonymousUser => isAnonymous;

  /// Whether this user has linked their account to a permanent auth provider
  bool get isAuthenticatedUser => !isAnonymous;

  /// Debug helper: Check if auth state fields are consistent
  /// Returns null if consistent, or an error message if inconsistent
  String? get authStateInconsistency {
    final isAnon = isAnonymous;
    final providerIsAnon = authProvider == 'anonymous';
    final hasAuthUserId = authUserId != null;

    // Anonymous user should have: isAnonymous=true, authProvider='anonymous', authUserId=null
    if (isAnon && providerIsAnon && !hasAuthUserId) return null;

    // Authenticated user should have: isAnonymous=false, authProvider!='anonymous', authUserId!=null
    if (!isAnon && !providerIsAnon && hasAuthUserId) return null;

    // Inconsistent state detected
    return 'Auth state inconsistent: isAnonymous=$isAnon, authProvider=$authProvider, authUserId=${authUserId != null ? "set" : "null"}';
  }

  /// Parse allergies from JSON - handles both String and List formats
  /// - PostgreSQL returns arrays as `List<dynamic>`
  /// - Drift may return as String in legacy format
  static List<Allergy> _parseAllergiesFromJson(dynamic allergiesData) {
    if (allergiesData == null) return [];

    // If it's a List (from Supabase PostgreSQL array)
    if (allergiesData is List) {
      return allergiesData
          .map((item) => Allergy.fromDbValue(item.toString()))
          .whereType<Allergy>()
          .toList();
    }

    // If it's a String (from Drift or legacy format)
    if (allergiesData is String) {
      return Allergy.fromDbArray(allergiesData);
    }

    return [];
  }

  /// Create UserProfile from JSON (from Supabase)
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id:
          json['id'] as String? ??
          json['device_id'] as String, // Support both id and device_id
      deviceId: json['device_id'] as String,
      authUserId: json['auth_user_id'] as String?,
      authProvider: json['auth_provider'] as String? ?? 'anonymous',
      isAnonymous: json['is_anonymous'] as bool? ?? true,
      gender: Gender.values.firstWhere(
        (g) => g.name == json['gender'],
        orElse: () => Gender.other,
      ),
      birthday: DateTime.parse(json['birthday'] as String),
      heightFeet: json['height_feet'] as int,
      heightInches: json['height_inches'] as int,
      weightPounds: (json['weight_pounds'] as num).toDouble(),
      runsWithWaterBottle: json['runs_with_water_bottle'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      gutTraining: GutTraining.values.firstWhere(
        (gt) => gt.name == json['gut_training_level'],
        orElse: () => GutTraining.moderate,
      ),
      sweatRate: SweatRateCat.values.firstWhere(
        (sr) => sr.name == json['sweat_rate'],
        orElse: () => SweatRateCat.medium,
      ),
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
      appVersion: json['app_version'] as String? ?? '1.0.0',
      swipeHintShown:
          false, // Drift-only field, always default to false from Supabase
      // Unit preferences
      unitSystem: UnitSystem.values.firstWhere(
        (u) => u.name == json['unit_system'],
        orElse: () => UnitSystem.imperial,
      ),
      // Sport preferences (use correct production Supabase column names)
      ftpWatts: json['cycling_ftp_watts'] as int?,
      cssPacePer100mSeconds: json['swimming_css_seconds_per_100m'] as int?,
      // Drift-only fields - always default to null from Supabase
      giSensitivity: null,
      typicalBikeBottles: null,
      hasAeroBottle: null,
      hasBentoBox: null,
      typicalWetsuit: null,
      typicalSwimCapType: null,
      // Dietary preference and allergies
      dietaryPreference: DietaryPreference.fromDbValue(
        json['dietary_preference'] as String?,
      ),
      allergies: _parseAllergiesFromJson(json['allergies']),
      // Coach mode
      // isCoach: json['is_coach'] as bool? ?? false,
      // Sharing preferences
      senderName: json['sender_name'] as String?,
      // User identity
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      // Contact information
      email: json['email'] as String?,
      // Nutrition target overrides
      nutritionTargetOverrides: json['nutrition_target_overrides'] != null
          ? NutritionTargetOverrides.fromJson(
              json['nutrition_target_overrides'] as Map<String, dynamic>,
            )
          : null,
      // Daily macro calculation fields
      bodyFatPct: (json['body_fat_pct'] as num?)?.toDouble(),
      lifestyle: Lifestyle.fromDbValue(json['lifestyle'] as String?),
      typicalWeeklyHours: (json['typical_weekly_hours'] as num?)?.toDouble(),
      carbCycleOptIn: json['carb_cycle_opt_in'] as bool? ?? false,
      trainingPhase: TrainingPhase.fromDbValue(
        json['training_phase'] as String?,
      ),
      // Sweat profile fields
      sweatSodium: SweatSodiumCat.fromDbValue(json['sweat_sodium'] as String?),
      knownSweatRateMlPerHour: json['known_sweat_rate_ml_per_hour'] as int?,
      knownSodiumConcentrationMgPerLiter:
          json['known_sodium_concentration_mg_per_liter'] as int?,
      sweatTestDate: json['sweat_test_date'] != null
          ? DateTime.tryParse(json['sweat_test_date'] as String)
          : null,
      sweatTestSource: json['sweat_test_source'] as String?,
      weightPoundsUpdatedAt: json['weight_pounds_updated_at'] != null
          ? DateTime.tryParse(json['weight_pounds_updated_at'] as String)
          : null,
      bodyFatPctUpdatedAt: json['body_fat_pct_updated_at'] != null
          ? DateTime.tryParse(json['body_fat_pct_updated_at'] as String)
          : null,
    );
  }

  /// Convert UserProfile to JSON (for Supabase)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'auth_user_id': authUserId,
      'auth_provider': authProvider,
      'is_anonymous': isAnonymous,
      'gender': gender.name,
      'birthday': birthday.toIso8601String().split('T')[0],
      'height_feet': heightFeet,
      'height_inches': heightInches,
      'weight_pounds': weightPounds,
      'runs_with_water_bottle': runsWithWaterBottle,
      'gut_training_level': gutTraining.name,
      'sweat_rate': sweatRate.name,
      'onboarding_completed': onboardingCompleted,
      'app_version': appVersion,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'unit_system': unitSystem.name,
      // Sport preferences (only include fields that exist in production Supabase)
      'cycling_ftp_watts': ftpWatts,
      'swimming_css_seconds_per_100m': cssPacePer100mSeconds,
      // Dietary preference and allergies (synced to Supabase)
      // Convert 'none' to null since Supabase dietary_preference_enum doesn't include 'none'
      'dietary_preference': dietaryPreference?.dbValue == 'none'
          ? null
          : dietaryPreference?.dbValue,
      // Supabase column is `allergy_enum[]` — must send a JSON array, not the
      // PG-literal string `"{dairy}"` (PostgREST silently drops that form).
      'allergies': Allergy.toJsonList(allergies),
      // Sharing preferences
      'sender_name': senderName,
      // User identity
      'first_name': firstName,
      'last_name': lastName,
      // Contact information
      'email': email,
      // Nutrition target overrides
      'nutrition_target_overrides': nutritionTargetOverrides?.toJson(),
      // Daily macro calculation fields
      'body_fat_pct': bodyFatPct,
      'lifestyle': lifestyle.dbValue,
      'typical_weekly_hours': typicalWeeklyHours,
      'carb_cycle_opt_in': carbCycleOptIn,
      'training_phase': trainingPhase.dbValue,
      // Sweat profile fields
      'sweat_sodium': sweatSodium?.value,
      'known_sweat_rate_ml_per_hour': knownSweatRateMlPerHour,
      'known_sodium_concentration_mg_per_liter':
          knownSodiumConcentrationMgPerLiter,
      'sweat_test_date': sweatTestDate?.toIso8601String(),
      'sweat_test_source': sweatTestSource,
      'weight_pounds_updated_at': weightPoundsUpdatedAt
          ?.toUtc()
          .toIso8601String(),
      'body_fat_pct_updated_at': bodyFatPctUpdatedAt?.toUtc().toIso8601String(),
      // Note: is_coach is NOT synced to Supabase - coach status lives in coaches table
      // Note: swipe_hint_shown, gi_sensitivity, typical_bike_bottles, has_aero_bottle,
      // has_bento_box, typical_wetsuit, typical_swim_cap_type are Drift-only fields
      // and should not be synced to Supabase production
    };
  }

  /// Copy with method for updates
  UserProfile copyWith({
    String? id,
    String? deviceId,
    String? authUserId,
    String? authProvider,
    bool? isAnonymous,
    Gender? gender,
    DateTime? birthday,
    int? heightFeet,
    int? heightInches,
    double? weightPounds,
    bool? runsWithWaterBottle,
    DateTime? updatedAt,
    GutTraining? gutTraining,
    SweatRateCat? sweatRate,
    bool? onboardingCompleted,
    String? appVersion,
    bool? swipeHintShown,
    // Unit preferences
    UnitSystem? unitSystem,
    // Sport preferences
    bool? giSensitivity,
    int? ftpWatts,
    int? typicalBikeBottles,
    bool? hasAeroBottle,
    bool? hasBentoBox,
    int? cssPacePer100mSeconds,
    bool? typicalWetsuit,
    String? typicalSwimCapType,
    // Dietary preference and allergies
    DietaryPreference? dietaryPreference,
    List<Allergy>? allergies,
    // Sharing preferences
    String? senderName,
    // User identity
    String? firstName,
    String? lastName,
    // Contact information
    String? email,
    // Nutrition target overrides
    NutritionTargetOverrides? nutritionTargetOverrides,
    // Daily macro calculation fields
    double? bodyFatPct,
    Lifestyle? lifestyle,
    double? typicalWeeklyHours,
    bool? carbCycleOptIn,
    TrainingPhase? trainingPhase,
    // Sweat profile fields
    SweatSodiumCat? sweatSodium,
    int? knownSweatRateMlPerHour,
    int? knownSodiumConcentrationMgPerLiter,
    DateTime? sweatTestDate,
    String? sweatTestSource,
    // Default pace/speed for workout estimation
    double? defaultRunningPaceMinPerMile,
    double? defaultCyclingSpeedMph,
    int? defaultSwimmingPacePer100Sec,
    // Garmin precedence timestamps
    DateTime? weightPoundsUpdatedAt,
    DateTime? bodyFatPctUpdatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      authUserId: authUserId ?? this.authUserId,
      authProvider: authProvider ?? this.authProvider,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      heightFeet: heightFeet ?? this.heightFeet,
      heightInches: heightInches ?? this.heightInches,
      weightPounds: weightPounds ?? this.weightPounds,
      runsWithWaterBottle: runsWithWaterBottle ?? this.runsWithWaterBottle,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      gutTraining: gutTraining ?? this.gutTraining,
      sweatRate: sweatRate ?? this.sweatRate,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      appVersion: appVersion ?? this.appVersion,
      swipeHintShown: swipeHintShown ?? this.swipeHintShown,
      // Unit preferences
      unitSystem: unitSystem ?? this.unitSystem,
      // Sport preferences
      giSensitivity: giSensitivity ?? this.giSensitivity,
      ftpWatts: ftpWatts ?? this.ftpWatts,
      typicalBikeBottles: typicalBikeBottles ?? this.typicalBikeBottles,
      hasAeroBottle: hasAeroBottle ?? this.hasAeroBottle,
      hasBentoBox: hasBentoBox ?? this.hasBentoBox,
      cssPacePer100mSeconds:
          cssPacePer100mSeconds ?? this.cssPacePer100mSeconds,
      typicalWetsuit: typicalWetsuit ?? this.typicalWetsuit,
      typicalSwimCapType: typicalSwimCapType ?? this.typicalSwimCapType,
      // Default pace/speed for workout estimation
      defaultRunningPaceMinPerMile:
          defaultRunningPaceMinPerMile ?? this.defaultRunningPaceMinPerMile,
      defaultCyclingSpeedMph:
          defaultCyclingSpeedMph ?? this.defaultCyclingSpeedMph,
      defaultSwimmingPacePer100Sec:
          defaultSwimmingPacePer100Sec ?? this.defaultSwimmingPacePer100Sec,
      // Dietary preference and allergies
      dietaryPreference: dietaryPreference ?? this.dietaryPreference,
      allergies: allergies ?? this.allergies,
      // Sharing preferences
      senderName: senderName ?? this.senderName,
      // User identity
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      // Contact information
      email: email ?? this.email,
      // Nutrition target overrides
      nutritionTargetOverrides:
          nutritionTargetOverrides ?? this.nutritionTargetOverrides,
      // Daily macro calculation fields
      bodyFatPct: bodyFatPct ?? this.bodyFatPct,
      lifestyle: lifestyle ?? this.lifestyle,
      typicalWeeklyHours: typicalWeeklyHours ?? this.typicalWeeklyHours,
      carbCycleOptIn: carbCycleOptIn ?? this.carbCycleOptIn,
      trainingPhase: trainingPhase ?? this.trainingPhase,
      // Sweat profile fields
      sweatSodium: sweatSodium ?? this.sweatSodium,
      knownSweatRateMlPerHour:
          knownSweatRateMlPerHour ?? this.knownSweatRateMlPerHour,
      knownSodiumConcentrationMgPerLiter:
          knownSodiumConcentrationMgPerLiter ??
          this.knownSodiumConcentrationMgPerLiter,
      sweatTestDate: sweatTestDate ?? this.sweatTestDate,
      sweatTestSource: sweatTestSource ?? this.sweatTestSource,
      // Garmin precedence timestamps
      weightPoundsUpdatedAt:
          weightPoundsUpdatedAt ?? this.weightPoundsUpdatedAt,
      bodyFatPctUpdatedAt: bodyFatPctUpdatedAt ?? this.bodyFatPctUpdatedAt,
    );
  }
}

enum Gender {
  male,
  female,
  other;

  /// Get string value for API calls
  String get value => name;

  /// Get display name for UI
  String get displayName {
    switch (this) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
      case Gender.other:
        return 'Non-binary';
    }
  }
}

class FoodPreferences {
  final String userId;
  final Map<String, FoodPreference> preferences;
  final DateTime createdAt;
  final DateTime updatedAt;

  FoodPreferences({
    required this.userId,
    required this.preferences,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get preference for a specific food item
  FoodPreference getPreference(String foodId) {
    return preferences[foodId] ?? FoodPreference.dislike;
  }

  /// Update preference for a food item
  FoodPreferences updatePreference(String foodId, FoodPreference preference) {
    final updatedPreferences = Map<String, FoodPreference>.from(preferences);
    updatedPreferences[foodId] = preference;

    return FoodPreferences(
      userId: userId,
      preferences: updatedPreferences,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Get all liked foods
  List<String> get likedFoods {
    return preferences.entries
        .where((entry) => entry.value == FoodPreference.like)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get all disliked foods
  List<String> get dislikedFoods {
    return preferences.entries
        .where((entry) => entry.value == FoodPreference.dislike)
        .map((entry) => entry.key)
        .toList();
  }
}

enum FoodPreference {
  like,
  dislike,
  willingToTry;

  /// Get string value for API calls
  String get value => name == 'willingToTry' ? 'willing_to_try' : name;
}

int sliderLevelForPreference(FoodPreference preference) {
  switch (preference) {
    case FoodPreference.dislike:
      return 1;
    case FoodPreference.willingToTry:
      return 2;
    case FoodPreference.like:
      return 3;
  }
}

enum GutTraining {
  low,
  moderate,
  high;

  /// Get string value for API calls
  String get value => name;
}

/// Sweat sodium concentration category (Baker 2016).
/// Used by generate-macros-v4 to derive per-litre sodium targets.
/// 'medium' is accepted as a legacy alias for 'average' when reading from storage.
enum SweatSodiumCat {
  low,
  average,
  high;

  /// DB/API string value
  String get value => name;

  /// Display name for UI
  String get displayName {
    switch (this) {
      case SweatSodiumCat.low:
        return 'Low';
      case SweatSodiumCat.average:
        return 'Average';
      case SweatSodiumCat.high:
        return 'High';
    }
  }

  /// Parse from a DB string, treating 'medium' as an alias for 'average'.
  static SweatSodiumCat fromDbValue(String? value) {
    if (value == null) return SweatSodiumCat.average;
    final normalised = value == 'medium' ? 'average' : value;
    return SweatSodiumCat.values.firstWhere(
      (e) => e.name == normalised,
      orElse: () => SweatSodiumCat.average,
    );
  }
}

enum SweatRateCat {
  light,
  medium,
  heavy;

  /// Get string value for API calls
  String get value => name;

  /// Display name for UI
  String get displayName {
    switch (this) {
      case SweatRateCat.light:
        return 'Light';
      case SweatRateCat.medium:
        return 'Medium';
      case SweatRateCat.heavy:
        return 'Heavy';
    }
  }
}

/// Enum for gut training level API compatibility
enum GutTrainingLevel {
  low,
  moderate,
  high;

  /// Get string value for API calls
  String get value => name;
}
