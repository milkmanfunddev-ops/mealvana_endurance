/// Domain models for user authentication and preferences
/// Removed Hive dependencies as part of migration to Drift database

class UserProfile {
  final String id;
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

  UserProfile({
    required this.id,
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

  /// Create UserProfile from JSON (from Supabase)
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['device_id'] as String,
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
    );
  }

  /// Convert UserProfile to JSON (for Supabase)
  Map<String, dynamic> toJson() {
    return {
      'device_id': id,
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
    };
  }

  /// Copy with method for updates
  UserProfile copyWith({
    String? id,
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
  }) {
    return UserProfile(
      id: id ?? this.id,
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
    );
  }
}

enum Gender {
  male,
  female,
  other;

  /// Get string value for API calls
  String get value => name;
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