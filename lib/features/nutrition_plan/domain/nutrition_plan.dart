import 'food_item_data.dart';

/// Data model for nutrition plans with before/during/after run sections
class NutritionPlan {
  const NutritionPlan({
    required this.id,
    required this.name,
    required this.sections,
    this.macroTargets,
    this.totalCalories,
    this.notes,
    this.version = 1,
    this.lastModifiedBy,
    this.clientUpdatedAt,
    this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.conflictResolution = 'last_write_wins',
  });

  final String id;
  final String name; // e.g., "Long Run Nutrition Plan"
  final List<PlanSection> sections;
  final MacroTargets? macroTargets;
  final int? totalCalories;
  final String? notes;
  
  // Versioning fields
  final int version;
  final String? lastModifiedBy; // device_id of the modifier
  final DateTime? clientUpdatedAt; // Client-side timestamp
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;
  final String conflictResolution; // 'last_write_wins', 'manual', etc.

  /// Create a copy with updated fields
  NutritionPlan copyWith({
    String? id,
    String? name,
    List<PlanSection>? sections,
    MacroTargets? macroTargets,
    int? totalCalories,
    String? notes,
    int? version,
    String? lastModifiedBy,
    DateTime? clientUpdatedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    String? conflictResolution,
  }) {
    return NutritionPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      sections: sections ?? this.sections,
      macroTargets: macroTargets ?? this.macroTargets,
      totalCalories: totalCalories ?? this.totalCalories,
      notes: notes ?? this.notes,
      version: version ?? this.version,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      conflictResolution: conflictResolution ?? this.conflictResolution,
    );
  }

  /// Create a new version for updates
  NutritionPlan incrementVersion({
    required String modifiedBy,
    DateTime? clientTimestamp,
  }) {
    return copyWith(
      version: version + 1,
      lastModifiedBy: modifiedBy,
      clientUpdatedAt: clientTimestamp ?? DateTime.now(),
    );
  }

  /// Create NutritionPlan from Edge Function JSON response
  factory NutritionPlan.fromJson(Map<String, dynamic> json) {
    return NutritionPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      sections: (json['sections'] as List<dynamic>)
          .map((section) => PlanSection.fromJson(section))
          .toList(),
      macroTargets: json['macroTargets'] != null 
          ? MacroTargets.fromJson(json['macroTargets'])
          : null,
      totalCalories: json['totalCalories'] as int?,
      notes: json['notes'] as String?,
      version: json['version'] as int? ?? 1,
      lastModifiedBy: json['lastModifiedBy'] as String?,
      clientUpdatedAt: json['clientUpdatedAt'] != null 
          ? DateTime.parse(json['clientUpdatedAt'])
          : null,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'])
          : null,
      isDeleted: json['isDeleted'] as bool? ?? false,
      conflictResolution: json['conflictResolution'] as String? ?? 'last_write_wins',
    );
  }

  /// Create NutritionPlan from Supabase database JSON
  factory NutritionPlan.fromSupabaseJson(Map<String, dynamic> json) {
    return NutritionPlan(
      id: json['plan_id'] as String,
      name: json['plan_name'] as String,
      sections: json['plan_data'] != null 
          ? (json['plan_data']['sections'] as List<dynamic>)
              .map((section) => PlanSection.fromJson(section))
              .toList()
          : [],
      macroTargets: json['plan_data'] != null && json['plan_data']['macroTargets'] != null
          ? MacroTargets.fromJson(json['plan_data']['macroTargets'])
          : null,
      totalCalories: json['total_calories'] as int?,
      notes: json['notes'] as String?,
      version: json['version'] as int? ?? 1,
      lastModifiedBy: json['last_modified_by'] as String?,
      clientUpdatedAt: json['client_updated_at'] != null 
          ? DateTime.parse(json['client_updated_at'])
          : null,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'])
          : null,
      isDeleted: json['is_deleted'] as bool? ?? false,
      conflictResolution: json['conflict_resolution'] as String? ?? 'last_write_wins',
    );
  }

  /// Convert to JSON for API calls
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sections': sections.map((s) => s.toJson()).toList(),
      'macroTargets': macroTargets?.toJson(),
      'totalCalories': totalCalories,
      'notes': notes,
      'version': version,
      'lastModifiedBy': lastModifiedBy,
      'clientUpdatedAt': clientUpdatedAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isDeleted': isDeleted,
      'conflictResolution': conflictResolution,
    };
  }

  @override
  String toString() => 'NutritionPlan(id: $id, name: $name, version: $version)';
}

/// Section within a nutrition plan (Before/During/After Run)
class PlanSection {
  const PlanSection({
    required this.id,
    required this.title,
    required this.foodItems,
    this.subtitle,
    this.timing,
  });

  final String id;
  final String title; // "Before Run", "During Run", "After Run"
  final String? subtitle; // "30-60 min pre-run"
  final String? timing;
  final List<FoodItemData> foodItems;

  /// Create PlanSection from JSON
  factory PlanSection.fromJson(Map<String, dynamic> json) {
    return PlanSection(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      timing: json['timing'] as String?,
      foodItems: (json['foodItems'] as List<dynamic>)
          .map((item) => FoodItemData.fromJson(item))
          .toList(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'timing': timing,
      'foodItems': foodItems.map((item) => item.toJson()).toList(),
    };
  }

  @override
  String toString() => 'PlanSection(title: $title, items: ${foodItems.length})';
}

/// Macro targets for nutrition plan
class MacroTargets {
  const MacroTargets({
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
    this.sodium,
    this.sodiumMin,
    this.sodiumMax,
    this.fluids,
    this.fluidsMin,
    this.fluidsMax,
    this.carbsRange,
    this.proteinRange,
    this.fatRange,
  });

  final int calories;
  final int carbs; // grams
  final int protein; // grams  
  final int fat; // grams
  final int? sodium; // mg (average)
  final int? sodiumMin; // mg (minimum)
  final int? sodiumMax; // mg (maximum)
  final int? fluids; // oz (average)
  final int? fluidsMin; // oz (minimum)
  final int? fluidsMax; // oz (maximum)
  final String? carbsRange; // e.g., "45-65%"
  final String? proteinRange; // e.g., "10-15%"
  final String? fatRange; // e.g., "20-35%"

  /// Create MacroTargets from JSON
  factory MacroTargets.fromJson(Map<String, dynamic> json) {
    return MacroTargets(
      calories: json['calories'] as int,
      carbs: json['carbs'] as int,
      protein: json['protein'] as int,
      fat: json['fat'] as int,
      sodium: json['sodium'] as int?,
      sodiumMin: json['sodiumMin'] as int?,
      sodiumMax: json['sodiumMax'] as int?,
      fluids: json['fluids'] as int?,
      fluidsMin: json['fluidsMin'] as int?,
      fluidsMax: json['fluidsMax'] as int?,
      carbsRange: json['carbsRange'] as String?,
      proteinRange: json['proteinRange'] as String?,
      fatRange: json['fatRange'] as String?,
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
      'sodiumMin': sodiumMin,
      'sodiumMax': sodiumMax,
      'fluids': fluids,
      'fluidsMin': fluidsMin,
      'fluidsMax': fluidsMax,
      'carbsRange': carbsRange,
      'proteinRange': proteinRange,
      'fatRange': fatRange,
    };
  }

  @override
  String toString() => 'MacroTargets(cal: $calories, carbs: ${carbs}g, protein: ${protein}g, fat: ${fat}g)';
}

/// Result of a versioned operation that may have conflicts
class NutritionPlanSyncResult {
  const NutritionPlanSyncResult({
    required this.success,
    required this.plan,
    this.conflict = false,
    this.conflictPlan,
    this.operation,
    this.message,
  });

  final bool success;
  final NutritionPlan plan;
  final bool conflict;
  final NutritionPlan? conflictPlan; // Server version in case of conflict
  final String? operation; // 'insert', 'update', 'delete'
  final String? message;

  bool get hasConflict => conflict;
  bool get isSuccess => success && !conflict;
}

/// Enum for conflict resolution strategies
enum ConflictResolution {
  lastWriteWins('last_write_wins'),
  manual('manual'),
  clientWins('client_wins'),
  serverWins('server_wins');

  const ConflictResolution(this.value);
  final String value;

  static ConflictResolution fromString(String value) {
    return ConflictResolution.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ConflictResolution.lastWriteWins,
    );
  }
}