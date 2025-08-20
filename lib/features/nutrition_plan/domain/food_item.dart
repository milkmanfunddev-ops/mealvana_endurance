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
  final List<FoodCategory> categories;

  @HiveField(4)
  final String servingSize; // Legacy field - keep for compatibility

  @HiveField(5)
  final double servingAmount;

  @HiveField(6)
  final String servingUnit;

  @HiveField(11)
  final String? servingUnitPlural;

  @HiveField(12)
  final String? servingQualifier;

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
    required this.categories,
    required this.servingSize,
    required this.servingAmount,
    required this.servingUnit,
    required this.nutrition,
    this.servingUnitPlural,
    this.servingQualifier,
    this.imageUrl,
    this.tags = const [],
    this.additionalInfo,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      categories: json['categories'] != null 
        ? (json['categories'] as List).map((cat) => 
            FoodCategory.fromDbValue(cat as String)
          ).toList()
        : [],
      servingSize: json['servingSize'] ?? '${json['serving_amount'] ?? 1} ${json['serving_unit'] ?? 'serving'}',
      servingAmount: (json['servingAmount'] ?? json['serving_amount'])?.toDouble() ?? 1.0,
      servingUnit: json['servingUnit'] ?? json['serving_unit'] ?? 'serving',
      servingUnitPlural: json['servingUnitPlural'] ?? json['serving_unit_plural'],
      servingQualifier: json['servingQualifier'] ?? json['serving_qualifier'],
      nutrition: NutritionInfo.fromJson(json['nutrition'] ?? json['nutritional_info'] ?? {}),
      imageUrl: json['imageUrl'] ?? json['image_url'],
      tags: List<String>.from(json['tags'] ?? []),
      additionalInfo: json['additionalInfo'] ?? json['instructions'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'categories': categories.map((cat) => cat.dbValue).toList(),
      'servingSize': servingSize,
      'servingAmount': servingAmount,
      'servingUnit': servingUnit,
      'nutrition': nutrition.toJson(),
      'imageUrl': imageUrl,
      'tags': tags,
      'additionalInfo': additionalInfo,
    };
  }
  
  /// Check if this food belongs to a specific category
  bool belongsToCategory(FoodCategory category) {
    return categories.contains(category);
  }
  
  /// Format quantity for display (e.g., "3 cups", "2.3 servings")
  String formatQuantity(double quantity) {
    final totalAmount = quantity * servingAmount;
    final unit = servingUnitPlural ?? servingUnit;
    final qualifier = servingQualifier ?? '';
    
    String quantityText;
    if (totalAmount == 1) {
      quantityText = '1 $servingUnit';
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
}

@HiveType(typeId: 1)
enum FoodCategory {
  @HiveField(0)
  beforeRun('before_run'),

  @HiveField(1)
  duringRun('during_run'),

  @HiveField(2)
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