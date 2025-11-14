// Simplified carb loading plan models - carbs only tracking with 50g increments
// Based on Featherstone Nutrition methodology (8g carbs/kg body weight)

/// Race distance options for carb loading calculations
enum RaceDistance {
  halfMarathon('half_marathon', 'Half Marathon', 21.1),
  marathon('marathon', 'Marathon', 42.2),
  ultramarathon50k('50k', '50K', 50.0),
  ultramarathon50mile('50_mile', '50 Mile', 80.5),
  ultramarathon100k('100k', '100K', 100.0),
  ultramarathon100mile('100_mile', '100 Mile', 161.0);

  const RaceDistance(this.value, this.displayName, this.distanceKm);

  final String value;
  final String displayName;
  final double distanceKm;
}

/// Training volume options for carb loading calculations
enum TrainingVolume {
  low('low', 'Low', '<30 miles/week'),
  moderate('moderate', 'Moderate', '30-50 miles/week'),
  high('high', 'High', '>50 miles/week');

  const TrainingVolume(this.value, this.displayName, this.description);

  final String value;
  final String displayName;
  final String description;
}

/// Simplified carb loading plan focused on carbs-only tracking
class CarbLoadingPlan {
  final int id;
  final String userId;
  final DateTime raceDate;
  final RaceDistance raceDistance;
  final TrainingVolume trainingVolume;
  final int dailyCarbTargetG;        // e.g., 500g
  final int dailyServingsTarget;     // e.g., 10 servings (500g ÷ 50g)
  final double bodyWeightKg;
  final double carbsPerKgTarget;     // 8g/kg from Featherstone guide
  final Map<int, DayFoodSelections> daySelections; // Day -2, -1, 0
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  const CarbLoadingPlan({
    required this.id,
    required this.userId,
    required this.raceDate,
    required this.raceDistance,
    required this.trainingVolume,
    required this.dailyCarbTargetG,
    required this.dailyServingsTarget,
    required this.bodyWeightKg,
    required this.carbsPerKgTarget,
    required this.daySelections,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  /// Create default plan based on user weight
  factory CarbLoadingPlan.createDefault({
    required String userId,
    required DateTime raceDate,
    required RaceDistance raceDistance,
    required TrainingVolume trainingVolume,
    required double bodyWeightKg,
  }) {
    // Calculate daily carb target using 8g/kg formula with multipliers
    final baseCarbs = 8.0;
    final raceMultiplier = getRaceDistanceMultiplier(raceDistance);
    final volumeMultiplier = getTrainingVolumeMultiplier(trainingVolume);
    final carbsPerKg = baseCarbs * raceMultiplier * volumeMultiplier;
    final dailyCarbTargetG = (bodyWeightKg * carbsPerKg).round();
    final dailyServingsTarget = (dailyCarbTargetG / 50).round();

    return CarbLoadingPlan(
      id: DateTime.now().millisecondsSinceEpoch,
      userId: userId,
      raceDate: raceDate,
      raceDistance: raceDistance,
      trainingVolume: trainingVolume,
      dailyCarbTargetG: dailyCarbTargetG,
      dailyServingsTarget: dailyServingsTarget,
      bodyWeightKg: bodyWeightKg,
      carbsPerKgTarget: carbsPerKg,
      daySelections: {
        -2: DayFoodSelections.empty(),
        -1: DayFoodSelections.empty(),
        0: DayFoodSelections.empty(),
      },
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Get race distance multiplier from carb_loading.md
  static double getRaceDistanceMultiplier(RaceDistance distance) {
    switch (distance) {
      case RaceDistance.halfMarathon:
        return 0.8;
      case RaceDistance.marathon:
        return 1.0;
      case RaceDistance.ultramarathon50k:
      case RaceDistance.ultramarathon100k:
        return 1.1;
      case RaceDistance.ultramarathon50mile:
      case RaceDistance.ultramarathon100mile:
        return 1.2;
    }
  }

  /// Get training volume multiplier from carb_loading.md
  static double getTrainingVolumeMultiplier(TrainingVolume volume) {
    switch (volume) {
      case TrainingVolume.low:
        return 0.9;
      case TrainingVolume.moderate:
        return 1.0;
      case TrainingVolume.high:
        return 1.1;
    }
  }

  /// Create from JSON
  factory CarbLoadingPlan.fromJson(Map<String, dynamic> json) {
    final daySelectionsJson = json['daySelections'] as Map<String, dynamic>? ?? {};
    final daySelections = <int, DayFoodSelections>{};

    for (final entry in daySelectionsJson.entries) {
      final day = int.parse(entry.key);
      daySelections[day] = DayFoodSelections.fromJson(entry.value as Map<String, dynamic>);
    }

    return CarbLoadingPlan(
      id: json['id'] ?? 0,
      userId: json['userId'] ?? '',
      raceDate: DateTime.parse(json['raceDate']),
      raceDistance: RaceDistance.values.firstWhere(
        (e) => e.value == json['raceDistance'],
        orElse: () => RaceDistance.marathon,
      ),
      trainingVolume: TrainingVolume.values.firstWhere(
        (e) => e.value == json['trainingVolume'],
        orElse: () => TrainingVolume.moderate,
      ),
      dailyCarbTargetG: json['dailyCarbTargetG'] ?? 0,
      dailyServingsTarget: json['dailyServingsTarget'] ?? 0,
      bodyWeightKg: (json['bodyWeightKg'] as num?)?.toDouble() ?? 0.0,
      carbsPerKgTarget: (json['carbsPerKgTarget'] as num?)?.toDouble() ?? 8.0,
      daySelections: daySelections,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      isActive: json['isActive'] ?? true,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    final daySelectionsJson = <String, dynamic>{};
    for (final entry in daySelections.entries) {
      daySelectionsJson[entry.key.toString()] = entry.value.toJson();
    }

    return {
      'id': id,
      'userId': userId,
      'raceDate': raceDate.toIso8601String(),
      'raceDistance': raceDistance.value,
      'trainingVolume': trainingVolume.value,
      'dailyCarbTargetG': dailyCarbTargetG,
      'dailyServingsTarget': dailyServingsTarget,
      'bodyWeightKg': bodyWeightKg,
      'carbsPerKgTarget': carbsPerKgTarget,
      'daySelections': daySelectionsJson,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  /// Create a copy with updated fields
  CarbLoadingPlan copyWith({
    int? id,
    String? userId,
    DateTime? raceDate,
    RaceDistance? raceDistance,
    TrainingVolume? trainingVolume,
    int? dailyCarbTargetG,
    int? dailyServingsTarget,
    double? bodyWeightKg,
    double? carbsPerKgTarget,
    Map<int, DayFoodSelections>? daySelections,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return CarbLoadingPlan(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      raceDate: raceDate ?? this.raceDate,
      raceDistance: raceDistance ?? this.raceDistance,
      trainingVolume: trainingVolume ?? this.trainingVolume,
      dailyCarbTargetG: dailyCarbTargetG ?? this.dailyCarbTargetG,
      dailyServingsTarget: dailyServingsTarget ?? this.dailyServingsTarget,
      bodyWeightKg: bodyWeightKg ?? this.bodyWeightKg,
      carbsPerKgTarget: carbsPerKgTarget ?? this.carbsPerKgTarget,
      daySelections: daySelections ?? this.daySelections,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Get days until race
  int get daysUntilRace {
    final now = DateTime.now();
    return raceDate.difference(now).inDays;
  }

  /// Get days until carb loading starts (2 days before race)
  int get daysUntilCarbLoadingStarts {
    final carbLoadingStartDate = raceDate.subtract(const Duration(days: 2));
    final now = DateTime.now();
    return carbLoadingStartDate.difference(now).inDays;
  }

  /// Check if carb loading is currently active
  bool get isCarbLoadingActive {
    final now = DateTime.now();
    final carbLoadingStartDate = raceDate.subtract(const Duration(days: 2));
    return now.isAfter(carbLoadingStartDate) && now.isBefore(raceDate);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CarbLoadingPlan &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Food selections for a single day
class DayFoodSelections {
  final Map<String, MealFoods> meals; // breakfast, lunch, snack1, etc.

  const DayFoodSelections({
    required this.meals,
  });

  /// Create empty day with default meals
  factory DayFoodSelections.empty() {
    return DayFoodSelections(
      meals: {
        'breakfast': MealFoods.empty(),
        'lunch': MealFoods.empty(),
        'snack1': MealFoods.empty(),
        'dinner': MealFoods.empty(),
        'snack2': MealFoods.empty(),
      },
    );
  }

  /// Create from JSON
  factory DayFoodSelections.fromJson(Map<String, dynamic> json) {
    final mealsJson = json['meals'] as Map<String, dynamic>? ?? {};
    final meals = <String, MealFoods>{};

    for (final entry in mealsJson.entries) {
      meals[entry.key] = MealFoods.fromJson(entry.value as Map<String, dynamic>);
    }

    return DayFoodSelections(meals: meals);
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    final mealsJson = <String, dynamic>{};
    for (final entry in meals.entries) {
      mealsJson[entry.key] = entry.value.toJson();
    }
    return {'meals': mealsJson};
  }

  /// Get total carbs for the day
  int get totalCarbs {
    return meals.values.fold(0, (sum, meal) => sum + meal.totalCarbs);
  }

  /// Get total calories for the day (simple 4 cal/g carb estimate)
  int get totalCalories {
    return totalCarbs * 4;
  }

  /// Create a copy with updated meal
  DayFoodSelections copyWith({
    Map<String, MealFoods>? meals,
  }) {
    return DayFoodSelections(
      meals: meals ?? this.meals,
    );
  }

  /// Update specific meal
  DayFoodSelections updateMeal(String mealName, MealFoods mealFoods) {
    final updatedMeals = Map<String, MealFoods>.from(meals);
    updatedMeals[mealName] = mealFoods;
    return copyWith(meals: updatedMeals);
  }
}

/// Food selections for a single meal
class MealFoods {
  final Map<String, int> selectedFoods; // {foodName: quantity}

  const MealFoods({
    required this.selectedFoods,
  });

  /// Create empty meal
  factory MealFoods.empty() {
    return const MealFoods(selectedFoods: {});
  }

  /// Create from JSON
  factory MealFoods.fromJson(Map<String, dynamic> json) {
    final selectedFoodsJson = json['selectedFoods'] as Map<String, dynamic>? ?? {};
    final selectedFoods = <String, int>{};

    for (final entry in selectedFoodsJson.entries) {
      selectedFoods[entry.key] = entry.value as int;
    }

    return MealFoods(selectedFoods: selectedFoods);
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {'selectedFoods': selectedFoods};
  }

  /// Get total carbs (each food provides 50g carbs)
  int get totalCarbs {
    return selectedFoods.values.fold(0, (sum, qty) => sum + (qty * 50));
  }

  /// Get total calories (simple 4 cal/g carb estimate)
  int get totalCalories {
    return totalCarbs * 4;
  }

  /// Add food item
  MealFoods addFood(String foodName) {
    final updatedFoods = Map<String, int>.from(selectedFoods);
    updatedFoods[foodName] = (updatedFoods[foodName] ?? 0) + 1;
    return MealFoods(selectedFoods: updatedFoods);
  }

  /// Remove food item
  MealFoods removeFood(String foodName) {
    final updatedFoods = Map<String, int>.from(selectedFoods);
    final currentQty = updatedFoods[foodName] ?? 0;

    if (currentQty <= 1) {
      updatedFoods.remove(foodName);
    } else {
      updatedFoods[foodName] = currentQty - 1;
    }

    return MealFoods(selectedFoods: updatedFoods);
  }

  /// Update food quantity
  MealFoods updateFoodQuantity(String foodName, int quantity) {
    final updatedFoods = Map<String, int>.from(selectedFoods);

    if (quantity <= 0) {
      updatedFoods.remove(foodName);
    } else {
      updatedFoods[foodName] = quantity;
    }

    return MealFoods(selectedFoods: updatedFoods);
  }

  /// Create a copy with updated foods
  MealFoods copyWith({
    Map<String, int>? selectedFoods,
  }) {
    return MealFoods(
      selectedFoods: selectedFoods ?? this.selectedFoods,
    );
  }
}

/// 50g carb food item from Featherstone Nutrition guide
class CarbFood {
  final String name;
  final String displayName;
  final String category;
  final String description; // e.g., "1 large", "1 cup cooked"

  const CarbFood({
    required this.name,
    required this.displayName,
    required this.category,
    required this.description,
  });

  /// Create from JSON
  factory CarbFood.fromJson(Map<String, dynamic> json) {
    return CarbFood(
      name: json['name'] ?? '',
      displayName: json['displayName'] ?? '',
      category: json['category'] ?? '',
      description: json['description'] ?? '',
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'displayName': displayName,
      'category': category,
      'description': description,
    };
  }
}