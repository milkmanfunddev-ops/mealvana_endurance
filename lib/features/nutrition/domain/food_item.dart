/// Simplified food item for nutrition data
///
/// Replaces FoodItemData with a cleaner, minimal structure.
/// Only includes fields needed for nutrition plans.
class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.quantity,
    this.displayName,
    this.displayNamePlural,
    this.imageAddress,
    this.description,
    this.timing,
    this.instructions,
    this.servingSize,
    this.calories,
    this.carbsGrams,
    this.proteinGrams,
    this.fatGrams,
    this.sodiumMg,
    this.fluidsMl,
  });

  final String id;
  final String name;
  final String quantity; // e.g., "1 cup", "4", "30m before"

  // Display names
  final String? displayName;
  final String? displayNamePlural;

  // Additional info
  final String? imageAddress;
  final String? description;
  final String? timing; // When to consume (e.g., "30-60 min pre-run")
  final String? instructions;
  final String? servingSize;

  // Nutrition facts
  final int? calories;
  final double? carbsGrams;
  final double? proteinGrams;
  final double? fatGrams;
  final int? sodiumMg;
  final double? fluidsMl;

  /// Get the full image URL for this food item
  String? get imageUrl {
    if (imageAddress == null || imageAddress!.isEmpty) {
      return null;
    }

    // Open Food Facts URLs
    if (imageAddress!.startsWith('https://images.openfoodfacts.org/') ||
        imageAddress!.startsWith('https://static.openfoodfacts.org/')) {
      return imageAddress;
    }

    // S3 URLs for legacy/existing foods
    return 'https://milkman-dev.s3.us-east-2.amazonaws.com/foods/$imageAddress';
  }

  /// Create from JSON (from Edge Function or database)
  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'] as String? ?? json['food_id'] as String,
      name:
          json['name'] as String? ?? json['food_name'] as String? ?? 'Unknown',
      quantity: json['quantity']?.toString() ?? '1',
      displayName:
          json['displayName'] as String? ?? json['display_name'] as String?,
      displayNamePlural:
          json['displayNamePlural'] as String? ??
          json['display_name_plural'] as String?,
      imageAddress:
          json['imageAddress'] as String? ?? json['image_address'] as String?,
      description: json['description'] as String?,
      timing: json['timing'] as String?,
      instructions: json['instructions'] as String?,
      servingSize:
          json['servingSize'] as String? ?? json['serving_size'] as String?,
      calories: _parseIntOrNull(json['calories']),
      carbsGrams: _parseDoubleOrNull(
        json['carbsGrams'] ?? json['carbs_grams'] ?? json['carbs'],
      ),
      proteinGrams: _parseDoubleOrNull(
        json['proteinGrams'] ?? json['protein_grams'] ?? json['protein'],
      ),
      fatGrams: _parseDoubleOrNull(
        json['fatGrams'] ?? json['fat_grams'] ?? json['fat'],
      ),
      sodiumMg: _parseIntOrNull(
        json['sodiumMg'] ?? json['sodium_mg'] ?? json['sodium'],
      ),
      fluidsMl: _parseDoubleOrNull(
        json['fluidsMl'] ?? json['fluids_ml'] ?? json['fluids'],
      ),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'displayName': displayName,
      'displayNamePlural': displayNamePlural,
      'imageAddress': imageAddress,
      'description': description,
      'timing': timing,
      'instructions': instructions,
      'servingSize': servingSize,
      'calories': calories,
      'carbsGrams': carbsGrams,
      'proteinGrams': proteinGrams,
      'fatGrams': fatGrams,
      'sodiumMg': sodiumMg,
      'fluidsMl': fluidsMl,
    };
  }

  /// Create a copy with updated values
  FoodItem copyWith({
    String? id,
    String? name,
    String? quantity,
    String? displayName,
    String? displayNamePlural,
    String? imageAddress,
    String? description,
    String? timing,
    String? instructions,
    String? servingSize,
    int? calories,
    double? carbsGrams,
    double? proteinGrams,
    double? fatGrams,
    int? sodiumMg,
    double? fluidsMl,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      displayName: displayName ?? this.displayName,
      displayNamePlural: displayNamePlural ?? this.displayNamePlural,
      imageAddress: imageAddress ?? this.imageAddress,
      description: description ?? this.description,
      timing: timing ?? this.timing,
      instructions: instructions ?? this.instructions,
      servingSize: servingSize ?? this.servingSize,
      calories: calories ?? this.calories,
      carbsGrams: carbsGrams ?? this.carbsGrams,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      fatGrams: fatGrams ?? this.fatGrams,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      fluidsMl: fluidsMl ?? this.fluidsMl,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FoodItem &&
        other.id == id &&
        other.name == name &&
        other.quantity == quantity &&
        other.displayName == displayName &&
        other.displayNamePlural == displayNamePlural &&
        other.imageAddress == imageAddress &&
        other.description == description &&
        other.timing == timing &&
        other.instructions == instructions &&
        other.servingSize == servingSize &&
        other.calories == calories &&
        other.carbsGrams == carbsGrams &&
        other.proteinGrams == proteinGrams &&
        other.fatGrams == fatGrams &&
        other.sodiumMg == sodiumMg &&
        other.fluidsMl == fluidsMl;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    quantity,
    displayName,
    displayNamePlural,
    imageAddress,
    description,
    timing,
    instructions,
    servingSize,
    calories,
    carbsGrams,
    proteinGrams,
    fatGrams,
    sodiumMg,
    fluidsMl,
  );

  @override
  String toString() => 'FoodItem(id: $id, name: $name, quantity: $quantity)';

  // Helper parsing functions
  static int? _parseIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
