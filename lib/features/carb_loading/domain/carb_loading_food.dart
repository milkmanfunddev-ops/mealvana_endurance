import 'meal_type.dart';

/// Domain model for global default carb loading foods
/// Maps to carb_loading_foods database table
class CarbLoadingFood {
  const CarbLoadingFood({
    required this.id,
    required this.name,
    required this.displayName,
    this.displayNamePlural,
    required this.carbsPerServing,
    this.imageAddress,
    this.isDefault = true,
    required this.mealTypes,
    this.createdAt,
  });

  final String id;
  final String name; // Internal name: 'cereal', 'pasta_marinara'
  final String displayName; // Display with serving: 'Cereal (1/2 cup dry)'
  final String? displayNamePlural; // Plural form
  final double carbsPerServing; // Carbs in grams
  final String? imageAddress;
  final bool isDefault; // Pre-seeded vs admin-added
  final List<MealType> mealTypes; // Suitable for which meals
  final DateTime? createdAt;

  /// Get the full image URL
  String? get imageUrl {
    if (imageAddress == null || imageAddress!.isEmpty) {
      return null;
    }

    // If already a full URL, return it
    if (imageAddress!.startsWith('http')) {
      return imageAddress;
    }

    // Otherwise construct S3 URL
    return 'https://milkman-dev.s3.us-east-2.amazonaws.com/carb-foods/$imageAddress';
  }

  /// Check if this food is suitable for a specific meal type
  bool isSuitableForMeal(MealType mealType) {
    return mealTypes.contains(mealType);
  }

  /// Format carbs for display
  String get carbsDisplay => '${carbsPerServing.toInt()}g carbs';

  /// Create from Drift database row
  factory CarbLoadingFood.fromDatabase({
    required String id,
    required String name,
    required String displayName,
    String? displayNamePlural,
    required double carbsPerServing,
    String? imageAddress,
    bool isDefault = true,
    DateTime? createdAt,
    List<int> mealTypeIds = const [],
  }) {
    return CarbLoadingFood(
      id: id,
      name: name,
      displayName: displayName,
      displayNamePlural: displayNamePlural,
      carbsPerServing: carbsPerServing,
      imageAddress: imageAddress,
      isDefault: isDefault,
      createdAt: createdAt,
      mealTypes: mealTypeIds.map((id) => MealType.fromId(id)).toList(),
    );
  }

  /// Create from JSON
  factory CarbLoadingFood.fromJson(Map<String, dynamic> json) {
    return CarbLoadingFood(
      id: json['id'] as String,
      name: json['name'] as String,
      displayName: json['display_name'] as String,
      displayNamePlural: json['display_name_plural'] as String?,
      carbsPerServing: (json['carbs_per_serving'] as num).toDouble(),
      imageAddress: json['image_address'] as String?,
      isDefault: json['is_default'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      mealTypes:
          (json['meal_types'] as List<dynamic>?)
              ?.map((id) => MealType.fromId(id as int))
              .toList() ??
          [],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
      'display_name_plural': displayNamePlural,
      'carbs_per_serving': carbsPerServing,
      'image_address': imageAddress,
      'is_default': isDefault,
      'created_at': createdAt?.toIso8601String(),
      'meal_types': mealTypes.map((type) => type.id).toList(),
    };
  }

  /// Create a copy with updated fields
  CarbLoadingFood copyWith({
    String? id,
    String? name,
    String? displayName,
    String? displayNamePlural,
    double? carbsPerServing,
    String? imageAddress,
    bool? isDefault,
    List<MealType>? mealTypes,
    DateTime? createdAt,
  }) {
    return CarbLoadingFood(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      displayNamePlural: displayNamePlural ?? this.displayNamePlural,
      carbsPerServing: carbsPerServing ?? this.carbsPerServing,
      imageAddress: imageAddress ?? this.imageAddress,
      isDefault: isDefault ?? this.isDefault,
      mealTypes: mealTypes ?? this.mealTypes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CarbLoadingFood &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'CarbLoadingFood(id: $id, name: $name, carbs: ${carbsPerServing}g)';
}
