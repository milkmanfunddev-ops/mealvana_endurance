import 'package:hive/hive.dart';

part 'user_preferences.g.dart';

@HiveType(typeId: 3)
class UserProfile extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final Gender gender;

  @HiveField(2)
  final DateTime birthday;

  @HiveField(3)
  final int heightFeet;

  @HiveField(4)
  final int heightInches;

  @HiveField(5)
  final double weightPounds;

  @HiveField(6)
  final bool runsWithWaterBottle;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final DateTime updatedAt;

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
    );
  }
}

@HiveType(typeId: 4)
enum Gender {
  @HiveField(0)
  male,

  @HiveField(1)
  female,

  @HiveField(2)
  other,
}

@HiveType(typeId: 5)
class FoodPreferences extends HiveObject {
  @HiveField(0)
  final String userId;

  @HiveField(1)
  final Map<String, FoodPreference> preferences;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  final DateTime updatedAt;

  FoodPreferences({
    required this.userId,
    required this.preferences,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get preference for a specific food item
  FoodPreference getPreference(String foodId) {
    return preferences[foodId] ?? FoodPreference.neutral;
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

  /// Get all foods willing to try
  List<String> get willingToTryFoods {
    return preferences.entries
        .where((entry) => entry.value == FoodPreference.willingToTry)
        .map((entry) => entry.key)
        .toList();
  }
}

@HiveType(typeId: 6)
enum FoodPreference {
  @HiveField(0)
  like,

  @HiveField(1)
  dislike,

  @HiveField(2)
  willingToTry,

  @HiveField(3)
  neutral, // Default state
}