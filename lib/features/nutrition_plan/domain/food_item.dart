/// Domain model for food items
/// Updated to match enhanced database structure with suitability flags and explicit nutritional data
class FoodItem {
  final String id;
  final String name;
  final String? iconPath;
  final String? description;
  final String? instructions;
  final List<FoodCategory> categories;
  
  // Serving Information
  final String? servingSize; // Legacy field - keep for compatibility
  final double? servingAmount;
  final String? servingUnit;
  final String? servingUnitPlural;
  final String? servingQualifier;

  // Suitability Flags
  final bool beforeRunSuitable;
  final bool duringRunSuitable;
  final bool runPortable;
  final bool requiresPreparation;
  final bool aidStationAvailable;

  // Serving Constraints
  final int? maxServingsBefore;
  final int? maxServingsDuring;

  // Explicit Nutritional Data (per serving)
  final double? carbsPerServing;
  final double? proteinPerServing;
  final double? fatPerServing;
  final int? caloriesPerServing;
  final double? fluidMlPerServing;

  // Micronutrients
  final int? sodiumMg;
  final int? caffeineMg;
  final int? potassiumMg;

  /// Legacy nutritional information - deprecated, use explicit fields
  final NutritionInfo? nutrition;
  final List<String> tags;

  FoodItem({
    required this.id,
    required this.name,
    this.iconPath,
    this.description,
    this.instructions,
    this.categories = const [],
    this.servingSize,
    this.servingAmount,
    this.servingUnit,
    this.servingUnitPlural,
    this.servingQualifier,
    this.beforeRunSuitable = false,
    this.duringRunSuitable = false,
    this.runPortable = false,
    this.requiresPreparation = false,
    this.aidStationAvailable = false,
    this.maxServingsBefore,
    this.maxServingsDuring,
    this.carbsPerServing,
    this.proteinPerServing,
    this.fatPerServing,
    this.caloriesPerServing,
    this.fluidMlPerServing,
    this.sodiumMg,
    this.caffeineMg,
    this.potassiumMg,
    this.nutrition,
    this.tags = const [],
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      iconPath: json['icon_path']?.toString(),
      description: json['description']?.toString(),
      instructions: json['instructions']?.toString(),
      categories: json['categories'] != null 
        ? (json['categories'] as List).map((cat) => 
            FoodCategory.fromDbValue(cat as String)
          ).toList()
        : [],
      servingSize: json['serving_size']?.toString(),
      servingAmount: (json['serving_amount'] as num?)?.toDouble(),
      servingUnit: json['serving_unit']?.toString(),
      servingUnitPlural: json['serving_unit_plural']?.toString(),
      servingQualifier: json['serving_qualifier']?.toString(),
      beforeRunSuitable: json['before_run_suitable'] == true,
      duringRunSuitable: json['during_run_suitable'] == true,
      runPortable: json['run_portable'] == true,
      requiresPreparation: json['requires_preparation'] == true,
      aidStationAvailable: json['aid_station_available'] == true,
      maxServingsBefore: json['max_servings_before'] as int?,
      maxServingsDuring: json['max_servings_during'] as int?,
      carbsPerServing: (json['carbs_per_serving'] as num?)?.toDouble(),
      proteinPerServing: (json['protein_per_serving'] as num?)?.toDouble(),
      fatPerServing: (json['fat_per_serving'] as num?)?.toDouble(),
      caloriesPerServing: json['calories_per_serving'] as int?,
      fluidMlPerServing: (json['fluid_ml_per_serving'] as num?)?.toDouble(),
      sodiumMg: json['sodium_mg'] as int?,
      caffeineMg: json['caffeine_mg'] as int?,
      potassiumMg: json['potassium_mg'] as int?,
      nutrition: json['nutritional_info'] != null 
        ? NutritionInfo.fromJson(json['nutritional_info'] as Map<String, dynamic>)
        : null,
      tags: List<String>.from(json['tags'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon_path': iconPath,
      'description': description,
      'instructions': instructions,
      'categories': categories.map((cat) => cat.dbValue).toList(),
      'serving_size': servingSize,
      'serving_amount': servingAmount,
      'serving_unit': servingUnit,
      'serving_unit_plural': servingUnitPlural,
      'serving_qualifier': servingQualifier,
      'before_run_suitable': beforeRunSuitable,
      'during_run_suitable': duringRunSuitable,
      'run_portable': runPortable,
      'requires_preparation': requiresPreparation,
      'aid_station_available': aidStationAvailable,
      'max_servings_before': maxServingsBefore,
      'max_servings_during': maxServingsDuring,
      'carbs_per_serving': carbsPerServing,
      'protein_per_serving': proteinPerServing,
      'fat_per_serving': fatPerServing,
      'calories_per_serving': caloriesPerServing,
      'fluid_ml_per_serving': fluidMlPerServing,
      'sodium_mg': sodiumMg,
      'caffeine_mg': caffeineMg,
      'potassium_mg': potassiumMg,
      'nutritional_info': nutrition?.toJson(),
      'tags': tags,
    };
  }
  
  /// Check if this food belongs to a specific category
  bool belongsToCategory(FoodCategory category) {
    return categories.contains(category);
  }
  
  /// Format quantity for display (e.g., "3 cups", "2.3 servings")
  String formatQuantity(double quantity) {
    final baseAmount = servingAmount ?? 1.0;
    final totalAmount = quantity * baseAmount;
    final unit = servingUnitPlural ?? servingUnit ?? 'serving';
    final qualifier = servingQualifier ?? '';
    
    String quantityText;
    if (totalAmount == 1) {
      quantityText = '1 ${servingUnit ?? 'serving'}';
    } else if (totalAmount % 1 == 0) {
      quantityText = '${totalAmount.toInt()} $unit';
    } else {
      quantityText = '${totalAmount.toStringAsFixed(1)} $unit';
    }
    
    if (qualifier.isNotEmpty) {
      quantityText += ', $qualifier';
    }
    
    return quantityText;
  }

  /// Get effective carbs per serving (from explicit field or legacy nutrition)
  double get effectiveCarbsPerServing {
    return carbsPerServing ?? nutrition?.carbs ?? 0.0;
  }

  /// Get effective protein per serving (from explicit field or legacy nutrition)
  double get effectiveProteinPerServing {
    return proteinPerServing ?? nutrition?.protein ?? 0.0;
  }

  /// Get effective fat per serving (from explicit field or legacy nutrition)
  double get effectiveFatPerServing {
    return fatPerServing ?? nutrition?.fat ?? 0.0;
  }

  /// Get effective calories per serving (from explicit field or legacy nutrition)
  double get effectiveCaloriesPerServing {
    return caloriesPerServing?.toDouble() ?? nutrition?.calories ?? 0.0;
  }

  /// Get effective sodium in mg (from explicit field or legacy nutrition)
  double get effectiveSodiumMg {
    return sodiumMg?.toDouble() ?? nutrition?.sodium ?? 0.0;
  }

  /// Check if food is suitable for the given timing
  bool isSuitableForTiming(FoodCategory category) {
    switch (category) {
      case FoodCategory.beforeRun:
        return beforeRunSuitable;
      case FoodCategory.duringRun:
        return duringRunSuitable;
      case FoodCategory.afterRun:
        return true; // Assuming after run is generally more flexible
    }
  }
}

enum FoodCategory {
  beforeRun('before_run'),
  duringRun('during_run'),
  afterRun('after_run');
  
  const FoodCategory(this.dbValue);
  final String dbValue;
  
  static FoodCategory fromDbValue(String value) {
    return FoodCategory.values.firstWhere(
      (cat) => cat.dbValue == value,
      orElse: () => FoodCategory.beforeRun,
    );
  }
}

class NutritionInfo {
  /// Calories per serving
  final double calories;

  /// Carbohydrates in grams per serving
  final double carbs;

  /// Protein in grams per serving
  final double protein;

  /// Fat in grams per serving
  final double fat;

  /// Fiber in grams per serving
  final double fiber;

  /// Sodium in milligrams per serving
  final double sodium;

  /// Sugar in grams per serving
  final double sugar;

  /// Fluid content in fluid ounces per serving
  final double fluids;

  NutritionInfo({
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.fiber,
    required this.sodium,
    required this.sugar,
    required this.fluids,
  });

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      calories: json['calories'].toDouble(),
      carbs: json['carbs'].toDouble(),
      protein: json['protein'].toDouble(),
      fat: json['fat'].toDouble(),
      fiber: json['fiber'].toDouble(),
      sodium: json['sodium'].toDouble(),
      sugar: json['sugar'].toDouble(),
      fluids: json['fluids'].toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'carbs': carbs,
      'protein': protein,
      'fat': fat,
      'fiber': fiber,
      'sodium': sodium,
      'sugar': sugar,
      'fluids': fluids,
    };
  }
}