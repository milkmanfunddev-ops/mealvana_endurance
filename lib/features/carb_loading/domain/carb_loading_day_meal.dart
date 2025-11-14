import 'meal_type.dart';

/// Domain model for food selection in a specific meal on a specific day
/// Maps to carb_loading_day_meals database table
class CarbLoadingDayMeal {
  const CarbLoadingDayMeal({
    required this.id,
    required this.carbLoadingDayId,
    required this.mealType,
    this.carbLoadingFoodId,
    this.carbLoadingUserFoodId,
    this.foodDisplayName,
    required this.quantity,
    required this.carbsConsumed,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int carbLoadingDayId; // FK to carb_loading_days
  final MealType mealType;
  final String? carbLoadingFoodId; // FK to carb_loading_foods (null if user food)
  final String? carbLoadingUserFoodId; // FK to carb_loading_user_foods (null if default food)
  final String? foodDisplayName; // Cached for display
  final int quantity; // Number of servings
  final double carbsConsumed; // Calculated: quantity * carbs_per_serving
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Check if this meal uses a default food
  bool get isDefaultFood => carbLoadingFoodId != null;

  /// Check if this meal uses a user food
  bool get isUserFood => carbLoadingUserFoodId != null;

  /// Get the food ID (either default or user food)
  String? get foodId => carbLoadingFoodId ?? carbLoadingUserFoodId;

  /// Calculate carbs per serving
  double get carbsPerServing =>
      quantity > 0 ? carbsConsumed / quantity : carbsConsumed;

  /// Format quantity for display
  String get quantityDisplay => quantity == 1 ? '1 serving' : '$quantity servings';

  /// Format carbs for display
  String get carbsDisplay => '${carbsConsumed.toInt()}g carbs';

  /// Create from Drift database row
  factory CarbLoadingDayMeal.fromDatabase({
    required int id,
    required int carbLoadingDayId,
    required int mealTypeId,
    String? carbLoadingFoodId,
    String? carbLoadingUserFoodId,
    String? foodDisplayName,
    required int quantity,
    required double carbsConsumed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CarbLoadingDayMeal(
      id: id,
      carbLoadingDayId: carbLoadingDayId,
      mealType: MealType.fromId(mealTypeId),
      carbLoadingFoodId: carbLoadingFoodId,
      carbLoadingUserFoodId: carbLoadingUserFoodId,
      foodDisplayName: foodDisplayName,
      quantity: quantity,
      carbsConsumed: carbsConsumed,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Create from JSON
  factory CarbLoadingDayMeal.fromJson(Map<String, dynamic> json) {
    return CarbLoadingDayMeal(
      id: json['id'] as int,
      carbLoadingDayId: json['carb_loading_day_id'] as int,
      mealType: MealType.fromId(json['meal_type_id'] as int),
      carbLoadingFoodId: json['carb_loading_food_id'] as String?,
      carbLoadingUserFoodId: json['carb_loading_user_food_id'] as String?,
      foodDisplayName: json['food_display_name'] as String?,
      quantity: json['quantity'] as int,
      carbsConsumed: (json['carbs_consumed'] as num).toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'carb_loading_day_id': carbLoadingDayId,
      'meal_type_id': mealType.id,
      'carb_loading_food_id': carbLoadingFoodId,
      'carb_loading_user_food_id': carbLoadingUserFoodId,
      'food_display_name': foodDisplayName,
      'quantity': quantity,
      'carbs_consumed': carbsConsumed,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  CarbLoadingDayMeal copyWith({
    int? id,
    int? carbLoadingDayId,
    MealType? mealType,
    String? carbLoadingFoodId,
    String? carbLoadingUserFoodId,
    String? foodDisplayName,
    int? quantity,
    double? carbsConsumed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CarbLoadingDayMeal(
      id: id ?? this.id,
      carbLoadingDayId: carbLoadingDayId ?? this.carbLoadingDayId,
      mealType: mealType ?? this.mealType,
      carbLoadingFoodId: carbLoadingFoodId ?? this.carbLoadingFoodId,
      carbLoadingUserFoodId:
          carbLoadingUserFoodId ?? this.carbLoadingUserFoodId,
      foodDisplayName: foodDisplayName ?? this.foodDisplayName,
      quantity: quantity ?? this.quantity,
      carbsConsumed: carbsConsumed ?? this.carbsConsumed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CarbLoadingDayMeal &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'CarbLoadingDayMeal(id: $id, meal: ${mealType.displayName}, quantity: $quantity, carbs: ${carbsConsumed}g)';
}
