/// Data model for food items in nutrition plans
/// Used for expandable food items with details
class FoodItemData {
  const FoodItemData({
    required this.id,
    required this.name,
    required this.quantity,
    this.imageAddress,
    this.description,
    this.timing,
    this.nutritionalInfo,
    this.instructions,
    this.displayName,
    this.displayNamePlural,
    this.displayOverride,
  });

  final String id;
  final String name;
  final String quantity; // e.g., "1 cup", "4", "30m before"
  final String? imageAddress; // Online image URL
  final String? description; // Detailed nutritional advice
  final String? timing; // When to consume (e.g., "30-60 min pre-run")
  final NutritionalInfo? nutritionalInfo;
  final String? instructions; // Special preparation instructions
  final String? displayName; // Display name for singular quantities
  final String? displayNamePlural; // Display name for plural quantities
  final String? displayOverride; // Override display name

  /// Get the full image URL for this food item data
  /// Returns Open Food Facts URLs directly, or constructs S3 URL for other images
  String? get imageUrl {
    if (imageAddress == null || imageAddress!.isEmpty) {
      return null;
    }

    // If the image address is already a full Open Food Facts URL, return it directly
    if (imageAddress!.startsWith('https://images.openfoodfacts.org/') ||
        imageAddress!.startsWith('https://static.openfoodfacts.org/')) {
      return imageAddress;
    }

    // Otherwise, construct S3 URL for legacy/existing foods
    return 'https://milkman-dev.s3.us-east-2.amazonaws.com/foods/$imageAddress';
  }

  /// Create FoodItemData from JSON
  factory FoodItemData.fromJson(Map<String, dynamic> json) {
    return FoodItemData(
      id: json['id'] as String,
      name: json['name'] as String,
      quantity: json['quantity'] as String,
      imageAddress: json['imageAddress'] as String? ?? json['image_address'] as String?,
      description: json['description'] as String?,
      timing: json['timing'] as String?,
      instructions: json['instructions'] as String?,
      nutritionalInfo: json['nutritionalInfo'] != null
          ? NutritionalInfo.fromJson(json['nutritionalInfo'])
          : null,
      displayName: json['displayName'] as String?,
      displayNamePlural: json['displayNamePlural'] as String?,
      displayOverride: json['displayOverride'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'imageAddress': imageAddress,
      'description': description,
      'timing': timing,
      'instructions': instructions,
      'nutritionalInfo': nutritionalInfo?.toJson(),
      'displayName': displayName,
      'displayNamePlural': displayNamePlural,
      'displayOverride': displayOverride,
    };
  }

  @override
  String toString() => 'FoodItemData(id: $id, name: $name, quantity: $quantity)';
}

/// Nutritional information for food items
class NutritionalInfo {
  const NutritionalInfo({
    this.calories,
    this.carbs,
    this.protein,
    this.fat,
    this.sodium,
    this.sugar,
    this.fluids,
  });

  final int? calories;
  final int? carbs; // grams
  final int? protein; // grams
  final int? fat; // grams
  final int? sodium; // mg
  final int? sugar; // grams
  final double? fluids; // ml

  /// Create NutritionalInfo from JSON
  factory NutritionalInfo.fromJson(Map<String, dynamic> json) {
    return NutritionalInfo(
      calories: json['calories'] as int?,
      carbs: json['carbs'] as int?,
      protein: json['protein'] as int?,
      fat: json['fat'] as int?,
      sodium: json['sodium'] as int?,
      sugar: json['sugar'] as int?,
      fluids: (json['fluids'] as num?)?.toDouble(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'carbs': carbs,
      'protein': protein,
      'fat': fat,
      'sodium': sodium,
      'sugar': sugar,
      'fluids': fluids,
    };
  }

  @override
  String toString() => 'NutritionalInfo(calories: $calories, carbs: ${carbs}g)';
}