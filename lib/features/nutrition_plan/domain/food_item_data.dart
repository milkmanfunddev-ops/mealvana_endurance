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
    this.origin,
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

  /// Who put this row on the plan, when it was not the athlete or the
  /// generator: `hydration_check` tags the water row the hydration check adds
  /// (feeding-card FC-6) so the card can label it and Change answer can find
  /// it. Null for every ordinary row.
  final String? origin;

  /// Build a complete display string for this food at the given [qtyStr].
  ///
  /// Resolution order:
  /// 1. [buildDisplayQuantity] — derives unit from [displayNamePlural]
  /// 2. Tail extracted from the stored [quantity] field
  /// 3. Fallback to [displayName] or [name]
  ///
  /// Example: `food.displayAtQuantity('0.5')` → `"0.5 packets Energy Chews"`
  String displayAtQuantity(String qtyStr) {
    final built = buildDisplayQuantity(
      rawQty: qtyStr,
      displayName: displayName ?? name,
      displayNamePlural: displayNamePlural,
    );
    // If buildDisplayQuantity produced a full string (not just the number), use it.
    if (built != qtyStr) return built;

    // Fall back to tail from stored quantity
    final match = RegExp(r'^[\d.]+\s+(.+)$').firstMatch(quantity);
    final tail = match?.group(1)?.trim();
    if (tail != null && tail.isNotEmpty) return '$qtyStr $tail';

    // Last resort: just use display name
    return '$qtyStr ${displayName ?? name}';
  }

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
      origin: json['origin'] as String?,
    );
  }

  /// Build a self-contained display quantity string that includes the numeric
  /// quantity, an optional serving-unit word, and the food name.
  ///
  /// Examples: "1 packet Energy Chews", "2 bottles Sports Drink", "0.5 cups Oatmeal".
  ///
  /// Resolution order:
  /// 1. Explicit [servingUnit] → "$qty $servingUnit $displayName"
  /// 2. Unit prefix extracted from [displayNamePlural] (e.g. "packets Energy Chews"
  ///    ends with "Energy Chews" → unit = "packets") → singularised for qty == 1.
  /// 3. Fallback → just the raw numeric string (widgets append displayName).
  static String buildDisplayQuantity({
    required String rawQty,
    String? servingUnit,
    String? displayName,
    String? displayNamePlural,
  }) {
    // Path 1: Explicit serving unit
    if (servingUnit != null && servingUnit.isNotEmpty && displayName != null) {
      final cleanName = _stripParens(displayName);
      return '$rawQty $servingUnit $cleanName';
    }

    // Path 2: Derive unit from displayNamePlural
    if (displayNamePlural != null && displayName != null) {
      final pluralTrimmed = displayNamePlural.trim();
      // Strip parenthetical content from displayName for comparison.
      // e.g. "Oatmeal (½ cup dry)" → "Oatmeal" so it matches "cups Oatmeal".
      final nameClean = _stripParens(displayName);
      final pluralLower = pluralTrimmed.toLowerCase();
      final nameCleanLower = nameClean.toLowerCase();

      // Check if plural has a unit prefix: "cups Oatmeal" ends with "Oatmeal"
      if (pluralLower.endsWith(nameCleanLower) &&
          pluralLower.length > nameCleanLower.length + 1) {
        // Extract the unit and the clean food name from displayNamePlural.
        // Using displayNamePlural's food name keeps parenthetical content out.
        final unitPlural = pluralTrimmed
            .substring(0, pluralTrimmed.length - nameClean.length)
            .trim();
        final foodName = pluralTrimmed.substring(unitPlural.length).trim();
        final numQty = double.tryParse(rawQty) ?? 1;

        if ((numQty - 1.0).abs() < 0.01) {
          // Singularise: "packets" → "packet", "bottles" → "bottle"
          final unitSingular =
              unitPlural.endsWith('s') && !unitPlural.endsWith('ss')
              ? unitPlural.substring(0, unitPlural.length - 1)
              : unitPlural;
          return '$rawQty $unitSingular $foodName';
        }
        return '$rawQty $pluralTrimmed';
      }
    }

    // Path 3: displayNamePlural is just a plural form (no unit prefix).
    // e.g. "Energy Gels" for "Energy Gel", "Bananas" for "Banana"
    // Path 2 misses these because "energy gels".endsWith("energy gel") is false.
    if (displayNamePlural != null &&
        displayNamePlural.isNotEmpty &&
        displayName != null) {
      final numQty = double.tryParse(rawQty) ?? 1;
      if ((numQty - 1.0).abs() < 0.01) {
        return '$rawQty ${_stripParens(displayName)}';
      }
      return '$rawQty ${_stripParens(displayNamePlural)}';
    }

    // Path 4: No display info available – return raw number only
    return rawQty;
  }

  /// Strip parenthetical content from a string.
  /// "Oatmeal (½ cup dry)" → "Oatmeal"
  static String _stripParens(String value) {
    return value.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
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

    // Build self-contained quantity string: "1 packet Energy Chews"
    // Widgets display the tail (everything after the leading number) as-is,
    // so it must include serving unit + food name.
    final rawQty = json['quantity']?.toString() ?? '1';
    final servingUnit = json['serving_unit'] as String?;
    final displayName =
        json['display_name'] as String? ?? json['food_name'] as String?;
    final displayNamePlural = json['display_name_plural'] as String?;

    final quantity = buildDisplayQuantity(
      rawQty: rawQty,
      servingUnit: servingUnit,
      displayName: displayName,
      displayNamePlural: displayNamePlural,
    );

    return FoodItemData(
      id: json['food_id'] as String,
      name:
          json['display_name'] as String? ??
          json['food_name'] as String? ??
          'Unknown Food',
      quantity: quantity,
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
      if (origin != null) 'origin': origin,
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
