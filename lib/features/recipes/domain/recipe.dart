class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.ingredients,
    required this.instructions,
    required this.prepTimeMinutes,
    required this.servings,
    required this.type,
    required this.nutrition,
    this.imageUrl,
    this.tags,
    this.isFavorite = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final List<String> ingredients;
  final List<String> instructions;
  final int prepTimeMinutes;
  final int servings;
  final RecipeType type;
  final RecipeNutrition nutrition;
  final String? imageUrl;
  final List<String>? tags;
  final bool isFavorite;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Recipe copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? ingredients,
    List<String>? instructions,
    int? prepTimeMinutes,
    int? servings,
    RecipeType? type,
    RecipeNutrition? nutrition,
    String? imageUrl,
    List<String>? tags,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Recipe(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      servings: servings ?? this.servings,
      type: type ?? this.type,
      nutrition: nutrition ?? this.nutrition,
      imageUrl: imageUrl ?? this.imageUrl,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      ingredients: List<String>.from(json['ingredients'] as List),
      instructions: List<String>.from(json['instructions'] as List),
      prepTimeMinutes: json['prepTimeMinutes'] as int,
      servings: json['servings'] as int,
      type: RecipeType.fromWire(json['type'] as String? ?? ''),
      nutrition: RecipeNutrition.fromJson(
        json['nutrition'] as Map<String, dynamic>,
      ),
      imageUrl: json['imageUrl'] as String?,
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List)
          : null,
      isFavorite: json['isFavorite'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'ingredients': ingredients,
      'instructions': instructions,
      'prepTimeMinutes': prepTimeMinutes,
      'servings': servings,
      'type': type.wireValue,
      'nutrition': nutrition.toJson(),
      'imageUrl': imageUrl,
      'tags': tags,
      'isFavorite': isFavorite,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() => 'Recipe(id: $id, name: $name, type: ${type.name})';
}

class RecipeNutrition {
  const RecipeNutrition({
    required this.calories,
    required this.carbohydratesGrams,
    required this.proteinGrams,
    required this.fatGrams,
    required this.fiberGrams,
    required this.sugarGrams,
    required this.sodiumMilligrams,
  });

  final double calories;
  final double carbohydratesGrams;
  final double proteinGrams;
  final double fatGrams;
  final double fiberGrams;
  final double sugarGrams;
  final double sodiumMilligrams;

  RecipeNutrition copyWith({
    double? calories,
    double? carbohydratesGrams,
    double? proteinGrams,
    double? fatGrams,
    double? fiberGrams,
    double? sugarGrams,
    double? sodiumMilligrams,
  }) {
    return RecipeNutrition(
      calories: calories ?? this.calories,
      carbohydratesGrams: carbohydratesGrams ?? this.carbohydratesGrams,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      fatGrams: fatGrams ?? this.fatGrams,
      fiberGrams: fiberGrams ?? this.fiberGrams,
      sugarGrams: sugarGrams ?? this.sugarGrams,
      sodiumMilligrams: sodiumMilligrams ?? this.sodiumMilligrams,
    );
  }

  factory RecipeNutrition.fromJson(Map<String, dynamic> json) {
    return RecipeNutrition(
      calories: (json['calories'] as num).toDouble(),
      carbohydratesGrams: (json['carbohydratesGrams'] as num).toDouble(),
      proteinGrams: (json['proteinGrams'] as num).toDouble(),
      fatGrams: (json['fatGrams'] as num).toDouble(),
      fiberGrams: (json['fiberGrams'] as num).toDouble(),
      sugarGrams: (json['sugarGrams'] as num).toDouble(),
      sodiumMilligrams: (json['sodiumMilligrams'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'carbohydratesGrams': carbohydratesGrams,
      'proteinGrams': proteinGrams,
      'fatGrams': fatGrams,
      'fiberGrams': fiberGrams,
      'sugarGrams': sugarGrams,
      'sodiumMilligrams': sodiumMilligrams,
    };
  }

  @override
  String toString() =>
      'RecipeNutrition(calories: $calories, carbs: ${carbohydratesGrams}g)';
}

enum RecipeType {
  breakfast,
  mains,
  snacks,
  workoutFuel,
  recovery;

  /// The string value stored in Supabase / Drift (snake_case for multi-word).
  String get wireValue {
    switch (this) {
      case RecipeType.breakfast:
        return 'breakfast';
      case RecipeType.mains:
        return 'mains';
      case RecipeType.snacks:
        return 'snacks';
      case RecipeType.workoutFuel:
        return 'workout_fuel';
      case RecipeType.recovery:
        return 'recovery';
    }
  }

  /// Human-readable label for display in filter chips and UI.
  String get displayLabel {
    switch (this) {
      case RecipeType.breakfast:
        return 'Breakfast';
      case RecipeType.mains:
        return 'Mains';
      case RecipeType.snacks:
        return 'Snacks';
      case RecipeType.workoutFuel:
        return 'Workout Fuel';
      case RecipeType.recovery:
        return 'Recovery';
    }
  }

  /// Parse a wire value from Supabase/Drift. Unknown values fall back to [mains].
  static RecipeType fromWire(String value) {
    switch (value) {
      case 'breakfast':
        return RecipeType.breakfast;
      case 'mains':
        return RecipeType.mains;
      case 'snacks':
        return RecipeType.snacks;
      case 'workout_fuel':
        return RecipeType.workoutFuel;
      case 'recovery':
        return RecipeType.recovery;
      default:
        return RecipeType.mains;
    }
  }
}
