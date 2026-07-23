import 'food_item_data.dart';
import 'nutrition_plan.dart';
import '../application/by_hour_sync_service.dart';

/// A single food item in a fuel log with planned vs actual quantities.
class FuelLogItem {
  FuelLogItem({
    required this.foodId,
    required this.sectionId,
    required this.plannedQuantity,
    required this.actualQuantity,
    required this.name,
    this.subPhaseType,
    this.displayName,
    this.displayNamePlural,
    this.imageAddress,
    this.isDrink = false,
    this.isIndivisible = false,
    this.isAdded = false,
    this.nutritionalInfo,
    this.servingSize,
    this.nutritionReferenceQuantity,
  });

  final String foodId;
  final String sectionId; // 'before_run', 'during_run', 'after_run'
  final String? subPhaseType; // 'meal', 'snack', 'top_up'
  final double plannedQuantity;
  double actualQuantity;
  final String name;
  final String? displayName;
  final String? displayNamePlural;
  final String? imageAddress;
  final bool isDrink;
  final bool isIndivisible;
  final bool isAdded; // true if added during logging (not in plan)
  final NutritionalInfo? nutritionalInfo;
  final String? servingSize;

  /// The quantity [nutritionalInfo] was captured at. Null for plan-seeded
  /// items, whose info corresponds to [plannedQuantity] units. Added items
  /// have plannedQuantity 0 ("not in the plan"), so they carry the add-time
  /// quantity here instead — without it their macros could never be scaled
  /// and they'd contribute zero to carbs/hr and coach reports.
  final double? nutritionReferenceQuantity;

  double get stepSize => isIndivisible ? 1.0 : 0.5;

  /// Compute actual macros by scaling the stored nutritional info by the
  /// ratio of actual quantity to the quantity that info corresponds to
  /// ([nutritionReferenceQuantity], falling back to [plannedQuantity]).
  NutritionalInfo? get actualNutritionalInfo {
    final referenceQuantity = nutritionReferenceQuantity ?? plannedQuantity;
    if (nutritionalInfo == null || referenceQuantity <= 0) return null;
    final scale = actualQuantity / referenceQuantity;
    return NutritionalInfo(
      calories: nutritionalInfo!.calories != null
          ? (nutritionalInfo!.calories! * scale).round()
          : null,
      carbs: nutritionalInfo!.carbs != null
          ? (nutritionalInfo!.carbs! * scale).round()
          : null,
      protein: nutritionalInfo!.protein != null
          ? (nutritionalInfo!.protein! * scale).round()
          : null,
      fat: nutritionalInfo!.fat != null
          ? (nutritionalInfo!.fat! * scale).round()
          : null,
      sodium: nutritionalInfo!.sodium != null
          ? (nutritionalInfo!.sodium! * scale).round()
          : null,
      fluids: nutritionalInfo!.fluids != null
          ? nutritionalInfo!.fluids! * scale
          : null,
    );
  }

  FuelLogItem copyWith({
    String? foodId,
    String? sectionId,
    String? subPhaseType,
    double? plannedQuantity,
    double? actualQuantity,
    String? name,
    String? displayName,
    String? displayNamePlural,
    String? imageAddress,
    bool? isDrink,
    bool? isIndivisible,
    bool? isAdded,
    NutritionalInfo? nutritionalInfo,
    String? servingSize,
    double? nutritionReferenceQuantity,
  }) {
    return FuelLogItem(
      foodId: foodId ?? this.foodId,
      sectionId: sectionId ?? this.sectionId,
      subPhaseType: subPhaseType ?? this.subPhaseType,
      plannedQuantity: plannedQuantity ?? this.plannedQuantity,
      actualQuantity: actualQuantity ?? this.actualQuantity,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      displayNamePlural: displayNamePlural ?? this.displayNamePlural,
      imageAddress: imageAddress ?? this.imageAddress,
      isDrink: isDrink ?? this.isDrink,
      isIndivisible: isIndivisible ?? this.isIndivisible,
      isAdded: isAdded ?? this.isAdded,
      nutritionalInfo: nutritionalInfo ?? this.nutritionalInfo,
      servingSize: servingSize ?? this.servingSize,
      nutritionReferenceQuantity:
          nutritionReferenceQuantity ?? this.nutritionReferenceQuantity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'foodId': foodId,
      'sectionId': sectionId,
      if (subPhaseType != null) 'subPhaseType': subPhaseType,
      'plannedQuantity': plannedQuantity,
      'actualQuantity': actualQuantity,
      'name': name,
      if (displayName != null) 'displayName': displayName,
      if (displayNamePlural != null) 'displayNamePlural': displayNamePlural,
      if (imageAddress != null) 'imageAddress': imageAddress,
      'isDrink': isDrink,
      'isIndivisible': isIndivisible,
      'isAdded': isAdded,
      if (nutritionalInfo != null) 'nutritionalInfo': nutritionalInfo!.toJson(),
      if (servingSize != null) 'servingSize': servingSize,
      if (nutritionReferenceQuantity != null)
        'nutritionReferenceQuantity': nutritionReferenceQuantity,
    };
  }

  factory FuelLogItem.fromJson(Map<String, dynamic> json) {
    return FuelLogItem(
      foodId: json['foodId'] as String,
      sectionId: json['sectionId'] as String,
      subPhaseType: json['subPhaseType'] as String?,
      plannedQuantity: (json['plannedQuantity'] as num).toDouble(),
      actualQuantity: (json['actualQuantity'] as num).toDouble(),
      name: json['name'] as String,
      displayName: json['displayName'] as String?,
      displayNamePlural: json['displayNamePlural'] as String?,
      imageAddress: json['imageAddress'] as String?,
      isDrink: json['isDrink'] as bool? ?? false,
      isIndivisible: json['isIndivisible'] as bool? ?? false,
      isAdded: json['isAdded'] as bool? ?? false,
      nutritionalInfo: json['nutritionalInfo'] != null
          ? NutritionalInfo.fromJson(json['nutritionalInfo'])
          : null,
      servingSize: json['servingSize'] as String?,
      nutritionReferenceQuantity: (json['nutritionReferenceQuantity'] as num?)
          ?.toDouble(),
    );
  }
}

/// Container for the full fuel log associated with an activity.
class FuelLogData {
  FuelLogData({
    required this.items,
    this.loggedAt,
    this.overallSatisfaction,
    this.nutritionRating,
    this.notes,
  });

  final List<FuelLogItem> items;
  final DateTime? loggedAt;
  int? overallSatisfaction; // 1-5 star rating
  int? nutritionRating; // 1-5 carb feedback (maps to CarbAdjustmentLevel)
  String? notes;

  /// Get items for a specific section.
  List<FuelLogItem> itemsForSection(String sectionId) {
    return items.where((item) => item.sectionId == sectionId).toList();
  }

  /// Get items for a specific sub-phase within a section.
  List<FuelLogItem> itemsForSubPhase(String sectionId, String subPhaseType) {
    return items
        .where(
          (item) =>
              item.sectionId == sectionId && item.subPhaseType == subPhaseType,
        )
        .toList();
  }

  /// Build FuelLogData from a NutritionPlan, pre-filling all items
  /// with actualQuantity = plannedQuantity.
  factory FuelLogData.fromNutritionPlan(NutritionPlan plan) {
    final items = <FuelLogItem>[];

    for (final section in plan.sections) {
      final sectionId = section.id;

      if (section.hasSubPhases) {
        // Before section with sub-phases (meal, snack, top_up)
        for (final subPhase in section.subPhases!) {
          for (final food in subPhase.foodItems) {
            items.add(
              _foodItemToLogItem(
                food: food,
                sectionId: sectionId,
                subPhaseType: subPhase.subPhaseType,
              ),
            );
          }
        }
      } else if (section.supportsByHour && section.byHourData != null) {
        // During section with by-hour data — flatten to per-food totals
        final foodTotals = <String, double>{};
        final foodMap = <String, FoodItemData>{};

        for (final food in section.foodItems) {
          foodMap[food.id] = food;
          foodTotals[food.id] = ByHourSyncService.parseQuantity(food);
        }

        for (final entry in foodTotals.entries) {
          final food = foodMap[entry.key];
          if (food == null) continue;
          items.add(
            _foodItemToLogItem(
              food: food,
              sectionId: sectionId,
              overrideQuantity: entry.value,
            ),
          );
        }
      } else {
        // Standard section (summary foods list)
        for (final food in section.foodItems) {
          items.add(_foodItemToLogItem(food: food, sectionId: sectionId));
        }
      }
    }

    return FuelLogData(items: items);
  }

  /// Create from an existing FuelLogItem added during logging.
  FuelLogData addItem(FuelLogItem item) {
    return FuelLogData(
      items: [...items, item],
      loggedAt: loggedAt,
      overallSatisfaction: overallSatisfaction,
      nutritionRating: nutritionRating,
      notes: notes,
    );
  }

  FuelLogData copyWith({
    List<FuelLogItem>? items,
    DateTime? loggedAt,
    int? overallSatisfaction,
    int? nutritionRating,
    String? notes,
  }) {
    return FuelLogData(
      items: items ?? this.items,
      loggedAt: loggedAt ?? this.loggedAt,
      overallSatisfaction: overallSatisfaction ?? this.overallSatisfaction,
      nutritionRating: nutritionRating ?? this.nutritionRating,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(),
      if (loggedAt != null) 'loggedAt': loggedAt!.toIso8601String(),
      if (overallSatisfaction != null)
        'overallSatisfaction': overallSatisfaction,
      if (nutritionRating != null) 'nutritionRating': nutritionRating,
      if (notes != null) 'notes': notes,
    };
  }

  factory FuelLogData.fromJson(Map<String, dynamic> json) {
    return FuelLogData(
      items: (json['items'] as List<dynamic>)
          .map((item) => FuelLogItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      loggedAt: json['loggedAt'] != null
          ? DateTime.parse(json['loggedAt'] as String)
          : null,
      overallSatisfaction: (json['overallSatisfaction'] as num?)?.toInt(),
      nutritionRating: (json['nutritionRating'] as num?)?.toInt(),
      notes: json['notes'] as String?,
    );
  }

  /// Convert a FoodItemData to a FuelLogItem.
  static FuelLogItem _foodItemToLogItem({
    required FoodItemData food,
    required String sectionId,
    String? subPhaseType,
    double? overrideQuantity,
  }) {
    final quantity = overrideQuantity ?? ByHourSyncService.parseQuantity(food);
    return FuelLogItem(
      foodId: food.id,
      sectionId: sectionId,
      subPhaseType: subPhaseType,
      plannedQuantity: quantity,
      actualQuantity: quantity,
      name: food.name,
      displayName: food.displayName,
      displayNamePlural: food.displayNamePlural,
      imageAddress: food.imageAddress,
      isDrink: food.isDrink,
      isIndivisible: food.isIndivisible,
      nutritionalInfo: food.nutritionalInfo,
      servingSize: food.servingSize,
    );
  }
}
