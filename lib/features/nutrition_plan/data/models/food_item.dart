import 'package:hive/hive.dart';

part 'food_item.g.dart';

@HiveType(typeId: 0)
class FoodItem extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final FoodCategory category;

  @HiveField(4)
  final String servingSize;

  @HiveField(5)
  final double servingAmount;

  @HiveField(6)
  final String servingUnit;

  /// Nutritional information per serving
  @HiveField(7)
  final NutritionInfo nutrition;

  @HiveField(8)
  final String? imageUrl;

  @HiveField(9)
  final List<String> tags;

  /// Information shown when user wants to know more
  @HiveField(10)
  final String? additionalInfo;

  FoodItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.servingSize,
    required this.servingAmount,
    required this.servingUnit,
    required this.nutrition,
    this.imageUrl,
    this.tags = const [],
    this.additionalInfo,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      category: FoodCategory.values.firstWhere(
        (e) => e.toString().split('.').last == json['category'],
      ),
      servingSize: json['servingSize'],
      servingAmount: json['servingAmount'].toDouble(),
      servingUnit: json['servingUnit'],
      nutrition: NutritionInfo.fromJson(json['nutrition']),
      imageUrl: json['imageUrl'],
      tags: List<String>.from(json['tags'] ?? []),
      additionalInfo: json['additionalInfo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category.toString().split('.').last,
      'servingSize': servingSize,
      'servingAmount': servingAmount,
      'servingUnit': servingUnit,
      'nutrition': nutrition.toJson(),
      'imageUrl': imageUrl,
      'tags': tags,
      'additionalInfo': additionalInfo,
    };
  }
}

@HiveType(typeId: 1)
enum FoodCategory {
  @HiveField(0)
  preRun,

  @HiveField(1)
  duringRun,

  @HiveField(2)
  postRun,
}

@HiveType(typeId: 2)
class NutritionInfo extends HiveObject {
  /// Calories per serving
  @HiveField(0)
  final double calories;

  /// Carbohydrates in grams per serving
  @HiveField(1)
  final double carbs;

  /// Protein in grams per serving
  @HiveField(2)
  final double protein;

  /// Fat in grams per serving
  @HiveField(3)
  final double fat;

  /// Fiber in grams per serving
  @HiveField(4)
  final double fiber;

  /// Sodium in milligrams per serving
  @HiveField(5)
  final double sodium;

  /// Sugar in grams per serving
  @HiveField(6)
  final double sugar;

  /// Fluid content in fluid ounces per serving
  @HiveField(7)
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