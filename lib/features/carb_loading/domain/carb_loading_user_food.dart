import 'meal_type.dart';

/// Domain model for user-created carb loading foods
/// Maps to carb_loading_user_foods database table
class CarbLoadingUserFood {
  const CarbLoadingUserFood({
    required this.id,
    required this.deviceId,
    this.clientFoodId,
    required this.name,
    required this.displayName,
    this.displayNamePlural,
    required this.carbsPerServing,
    this.imageAddress,
    this.barcode,
    this.sourceFoodId,
    this.sourceUserFoodId,
    this.isDeleted = false,
    required this.mealTypes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String deviceId;
  final String? clientFoodId; // For sync tracking
  final String name;
  final String displayName;
  final String? displayNamePlural;
  final double carbsPerServing;
  final String? imageAddress;
  final String? barcode; // If scanned
  final String? sourceFoodId; // FK to foods table (if imported from nutrition plan)
  final String? sourceUserFoodId; // FK to user_foods (if imported)
  final bool isDeleted; // Soft delete
  final List<MealType> mealTypes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
    return 'https://milkman-dev.s3.us-east-2.amazonaws.com/user-carb-foods/$imageAddress';
  }

  /// Check if this food is suitable for a specific meal type
  bool isSuitableForMeal(MealType mealType) {
    return mealTypes.contains(mealType);
  }

  /// Format carbs for display
  String get carbsDisplay => '${carbsPerServing.toInt()}g carbs';

  /// Check if this food was imported from another source
  bool get isImported => sourceFoodId != null || sourceUserFoodId != null;

  /// Check if this food was scanned via barcode
  bool get isScanned => barcode != null && barcode!.isNotEmpty;

  /// Create from Drift database row
  factory CarbLoadingUserFood.fromDatabase({
    required String id,
    required String deviceId,
    String? clientFoodId,
    required String name,
    required String displayName,
    String? displayNamePlural,
    required double carbsPerServing,
    String? imageAddress,
    String? barcode,
    String? sourceFoodId,
    String? sourceUserFoodId,
    bool isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<int> mealTypeIds = const [],
  }) {
    return CarbLoadingUserFood(
      id: id,
      deviceId: deviceId,
      clientFoodId: clientFoodId,
      name: name,
      displayName: displayName,
      displayNamePlural: displayNamePlural,
      carbsPerServing: carbsPerServing,
      imageAddress: imageAddress,
      barcode: barcode,
      sourceFoodId: sourceFoodId,
      sourceUserFoodId: sourceUserFoodId,
      isDeleted: isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt,
      mealTypes: mealTypeIds.map((id) => MealType.fromId(id)).toList(),
    );
  }

  /// Create from JSON
  factory CarbLoadingUserFood.fromJson(Map<String, dynamic> json) {
    return CarbLoadingUserFood(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      clientFoodId: json['client_food_id'] as String?,
      name: json['name'] as String,
      displayName: json['display_name'] as String,
      displayNamePlural: json['display_name_plural'] as String?,
      carbsPerServing: (json['carbs_per_serving'] as num).toDouble(),
      imageAddress: json['image_address'] as String?,
      barcode: json['barcode'] as String?,
      sourceFoodId: json['source_food_id'] as String?,
      sourceUserFoodId: json['source_user_food_id'] as String?,
      isDeleted: json['is_deleted'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      mealTypes: (json['meal_types'] as List<dynamic>?)
              ?.map((id) => MealType.fromId(id as int))
              .toList() ??
          [],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'client_food_id': clientFoodId,
      'name': name,
      'display_name': displayName,
      'display_name_plural': displayNamePlural,
      'carbs_per_serving': carbsPerServing,
      'image_address': imageAddress,
      'barcode': barcode,
      'source_food_id': sourceFoodId,
      'source_user_food_id': sourceUserFoodId,
      'is_deleted': isDeleted,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'meal_types': mealTypes.map((type) => type.id).toList(),
    };
  }

  /// Create a copy with updated fields
  CarbLoadingUserFood copyWith({
    String? id,
    String? deviceId,
    String? clientFoodId,
    String? name,
    String? displayName,
    String? displayNamePlural,
    double? carbsPerServing,
    String? imageAddress,
    String? barcode,
    String? sourceFoodId,
    String? sourceUserFoodId,
    bool? isDeleted,
    List<MealType>? mealTypes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CarbLoadingUserFood(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      clientFoodId: clientFoodId ?? this.clientFoodId,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      displayNamePlural: displayNamePlural ?? this.displayNamePlural,
      carbsPerServing: carbsPerServing ?? this.carbsPerServing,
      imageAddress: imageAddress ?? this.imageAddress,
      barcode: barcode ?? this.barcode,
      sourceFoodId: sourceFoodId ?? this.sourceFoodId,
      sourceUserFoodId: sourceUserFoodId ?? this.sourceUserFoodId,
      isDeleted: isDeleted ?? this.isDeleted,
      mealTypes: mealTypes ?? this.mealTypes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CarbLoadingUserFood &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'CarbLoadingUserFood(id: $id, name: $name, carbs: ${carbsPerServing}g)';
}
