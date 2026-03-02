/// Timing category for by-hour apportionment algorithm.
///
/// Derived from template_foods DB fields (productType, isElectrolyte, isLiquid).
/// Controls placement rules: quiet zone, spacing, end cutoff, etc.
enum TimingCategory {
  /// Zero/low-carb liquids sipped throughout the hour (water)
  sipThroughout,

  /// Carb-contributing liquids (sports drink) — placed like sipThroughout
  /// at :00, but displayed as fuel with a carb badge in the timeline.
  fuelDrink,

  /// Quick-consume items (gels, chews) - placed after quiet zone
  quickConsume,

  /// Slow-consume items (bars, real food) - placed after quiet zone
  slowConsume,

  /// Electrolyte supplements - only for activities >= 90 min
  electrolyte;

  /// Derive timing category from template_foods DB fields.
  ///
  /// Priority: Supplements first, then liquids (fuel_drink vs sip_throughout),
  /// then electrolytes, then gels/chews, then everything else.
  static TimingCategory fromFoodProperties({
    required bool isLiquid,
    required String productType,
    required bool isElectrolyte,
    double carbsPerServing = 0,
  }) {
    // Supplements (tablet/shot/salt) are discrete electrolyte events.
    if (productType == 'supplement') {
      return TimingCategory.electrolyte;
    }
    // Liquids: fuel_drink if >5g carbs, sip_throughout otherwise.
    if (isLiquid ||
        productType == 'sports_drink' ||
        productType == 'beverage') {
      return carbsPerServing > 5
          ? TimingCategory.fuelDrink
          : TimingCategory.sipThroughout;
    }
    // Non-supplement electrolyte items.
    if (isElectrolyte) return TimingCategory.electrolyte;
    // Quick-consume
    if (productType == 'gel' || productType == 'chew') {
      return TimingCategory.quickConsume;
    }
    // Everything else is slow-consume
    return TimingCategory.slowConsume;
  }
}

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
    this.servingSize,
    this.isDrink = false,
    this.isIndivisible = false,
    this.templateId,
    this.scaleMultiplier,
    this.timingCategory,
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
  final String? servingSize; // Serving size information (e.g., "1 cup", "100g")

  /// Whether this item is a drink (vs food) - used for UI distinction
  final bool isDrink;

  /// Whether this item is indivisible (sealed packets, tablets, etc.)
  /// When true, quantity must always be a whole number.
  final bool isIndivisible;

  /// Template ID this food came from (for tracking in template-based plans)
  final String? templateId;

  /// Scale multiplier applied during proportional scaling (for UX)
  final double? scaleMultiplier;

  /// Timing category for by-hour placement. Derived from template_foods fields.
  /// Nullable for backward compat with old saved plans (falls back to isDrink heuristic).
  final TimingCategory? timingCategory;

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
      imageAddress:
          json['imageAddress'] as String? ?? json['image_address'] as String?,
      description: json['description'] as String?,
      timing: json['timing'] as String?,
      instructions: json['instructions'] as String?,
      nutritionalInfo: json['nutritionalInfo'] != null
          ? NutritionalInfo.fromJson(json['nutritionalInfo'])
          : null,
      displayName: json['displayName'] as String?,
      displayNamePlural: json['displayNamePlural'] as String?,
      displayOverride: json['displayOverride'] as String?,
      servingSize:
          json['servingSize'] as String? ?? json['serving_size'] as String?,
      isDrink: json['isDrink'] as bool? ?? json['is_drink'] as bool? ?? false,
      isIndivisible:
          json['isIndivisible'] as bool? ??
          json['is_indivisible'] as bool? ??
          false,
      templateId:
          json['templateId'] as String? ?? json['template_id'] as String?,
      scaleMultiplier:
          (json['scaleMultiplier'] as num?)?.toDouble() ??
          (json['scale_multiplier'] as num?)?.toDouble(),
      timingCategory: _timingCategoryFromJson(
        json['timingCategory'] as String?,
      ),
    );
  }

  /// Create FoodItemData from Edge Function JSON format
  factory FoodItemData.fromEdgeFunctionJson(Map<String, dynamic> json) {
    // Edge function returns: food_id, quantity, carbs_grams, protein_grams, fat_grams,
    // sodium_mg, fluids_ml, calories, timing, display_name, display_name_plural,
    // description, image_address

    final nutritionalInfo = NutritionalInfo(
      calories: (json['calories'] as num?)?.toInt(),
      carbs: (json['carbs_grams'] as num?)?.toInt(),
      protein: (json['protein_grams'] as num?)?.toInt(),
      fat: (json['fat_grams'] as num?)?.toInt(),
      sodium: (json['sodium_mg'] as num?)?.toInt(),
      fluids: (json['fluids_ml'] as num?)?.toDouble(),
    );

    return FoodItemData(
      id: json['food_id'] as String,
      name:
          json['display_name'] as String? ??
          json['food_name'] as String? ??
          'Unknown Food',
      quantity: json['quantity']?.toString() ?? '1',
      imageAddress: json['image_address'] as String?,
      description: json['description'] as String?,
      timing: json['timing'] as String?,
      nutritionalInfo: nutritionalInfo,
      displayName: json['display_name'] as String?,
      displayNamePlural: json['display_name_plural'] as String?,
      servingSize: json['serving_size'] as String?,
      isDrink: json['is_drink'] as bool? ?? false,
      isIndivisible: json['is_indivisible'] as bool? ?? false,
      templateId: json['template_id'] as String?,
      scaleMultiplier: (json['scale_multiplier'] as num?)?.toDouble(),
      timingCategory: _timingCategoryFromJson(
        json['timing_category'] as String?,
      ),
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
      'servingSize': servingSize,
      'isDrink': isDrink,
      'isIndivisible': isIndivisible,
      'templateId': templateId,
      'scaleMultiplier': scaleMultiplier,
      if (timingCategory != null) 'timingCategory': timingCategory!.name,
    };
  }

  @override
  String toString() =>
      'FoodItemData(id: $id, name: $name, quantity: $quantity)';
}

/// Parse TimingCategory from JSON string.
/// Handles both camelCase ('sipThroughout') and snake_case ('sip_throughout').
TimingCategory? _timingCategoryFromJson(String? value) {
  if (value == null) return null;
  // Try exact match first (camelCase from client)
  for (final tc in TimingCategory.values) {
    if (tc.name == value) return tc;
  }
  // Try snake_case match (from server edge function)
  switch (value) {
    case 'sip_throughout':
      return TimingCategory.sipThroughout;
    case 'fuel_drink':
      return TimingCategory.fuelDrink;
    case 'quick_consume':
      return TimingCategory.quickConsume;
    case 'slow_consume':
      return TimingCategory.slowConsume;
    case 'electrolyte':
      return TimingCategory.electrolyte;
  }
  return null;
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
