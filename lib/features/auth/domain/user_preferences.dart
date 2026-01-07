import 'package:mealvana_endurance/features/onboarding/domain/dietary_preference.dart';
import 'package:mealvana_endurance/features/onboarding/domain/allergy.dart';

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
  final bool onboardingCompleted;
  final String appVersion;
  final bool swipeHintShown;

  // Sport-specific preferences
  final bool? giSensitivity;
  final int? ftpWatts;
  final int? typicalBikeBottles;
  final bool? hasAeroBottle;
  final bool? hasBentoBox;
  final int? cssPacePer100mSeconds;
  final bool? typicalWetsuit;
  final String? typicalSwimCapType;

  // Dietary preference and allergies (for onboarding revamp)
  final DietaryPreference? dietaryPreference;
  final List<Allergy> allergies;

  // Coach mode flag (set by admin/backend)
  final bool isCoach;

  // Sharing preferences
  final String? senderName; // Display name used when sharing plans

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
    this.gutTraining = GutTraining.high,
    this.onboardingCompleted = false,
    required this.appVersion,
    this.swipeHintShown = false,
    // Sport preferences
    this.giSensitivity,
    this.ftpWatts,
    this.typicalBikeBottles,
    this.hasAeroBottle,
    this.hasBentoBox,
    this.cssPacePer100mSeconds,
    this.typicalWetsuit,
    this.typicalSwimCapType,
    // Dietary preference and allergies
    this.dietaryPreference,
    this.allergies = const [],
    // Coach mode
    this.isCoach = false,
    // Sharing preferences
    this.senderName,
  });

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
      id: json['id'] as String? ?? json['device_id'] as String, // Support both id and device_id
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
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
      appVersion: json['app_version'] as String? ?? '1.0.0',
      swipeHintShown: false, // Drift-only field, always default to false from Supabase
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
      dietaryPreference: DietaryPreference.fromDbValue(json['dietary_preference'] as String?),
      allergies: _parseAllergiesFromJson(json['allergies']),
      // Coach mode
      isCoach: json['is_coach'] as bool? ?? false,
      // Sharing preferences
      senderName: json['sender_name'] as String?,
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
      'onboarding_completed': onboardingCompleted,
      'app_version': appVersion,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      // Sport preferences (only include fields that exist in production Supabase)
      'cycling_ftp_watts': ftpWatts,
      'swimming_css_seconds_per_100m': cssPacePer100mSeconds,
      // Dietary preference and allergies (synced to Supabase)
      // Convert 'none' to null since Supabase dietary_preference_enum doesn't include 'none'
      'dietary_preference': dietaryPreference?.dbValue == 'none' ? null : dietaryPreference?.dbValue,
      'allergies': Allergy.toDbArray(allergies),
      // Sharing preferences
      'sender_name': senderName,
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
    bool? onboardingCompleted,
    String? appVersion,
    bool? swipeHintShown,
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
    // Coach mode
    bool? isCoach,
    // Sharing preferences
    String? senderName,
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
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      appVersion: appVersion ?? this.appVersion,
      swipeHintShown: swipeHintShown ?? this.swipeHintShown,
      // Sport preferences
      giSensitivity: giSensitivity ?? this.giSensitivity,
      ftpWatts: ftpWatts ?? this.ftpWatts,
      typicalBikeBottles: typicalBikeBottles ?? this.typicalBikeBottles,
      hasAeroBottle: hasAeroBottle ?? this.hasAeroBottle,
      hasBentoBox: hasBentoBox ?? this.hasBentoBox,
      cssPacePer100mSeconds: cssPacePer100mSeconds ?? this.cssPacePer100mSeconds,
      typicalWetsuit: typicalWetsuit ?? this.typicalWetsuit,
      typicalSwimCapType: typicalSwimCapType ?? this.typicalSwimCapType,
      // Dietary preference and allergies
      dietaryPreference: dietaryPreference ?? this.dietaryPreference,
      allergies: allergies ?? this.allergies,
      // Coach mode
      isCoach: isCoach ?? this.isCoach,
      // Sharing preferences
      senderName: senderName ?? this.senderName,
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
