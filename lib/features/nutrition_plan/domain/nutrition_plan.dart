import 'dart:convert';
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
    this.runDateTime,
    this.planRating,
    this.journalNotes,
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
  final DateTime? runDateTime; // Scheduled run date and time
  final int? planRating; // 1=Could be better, 2=Neutral, 3=Satisfied
  final String? journalNotes; // User's feedback notes about the plan
  
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
    DateTime? runDateTime,
    int? planRating,
    String? journalNotes,
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
      runDateTime: runDateTime ?? this.runDateTime,
      planRating: planRating ?? this.planRating,
      journalNotes: journalNotes ?? this.journalNotes,
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
      runDateTime: json['runDateTime'] != null 
          ? DateTime.parse(json['runDateTime'])
          : null,
      planRating: json['planRating'] as int?,
      journalNotes: json['journalNotes'] as String?,
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
    // Handle plan_data which might be a string, Map, or null
    Map<String, dynamic>? planData;
    if (json['plan_data'] is String) {
      try {
        final parsedData = jsonDecode(json['plan_data']);
        planData = parsedData is Map<String, dynamic> ? parsedData : null;
      } catch (e) {
        print('Error parsing plan_data string: $e');
        planData = null;
      }
    } else if (json['plan_data'] is Map<String, dynamic>) {
      planData = json['plan_data'] as Map<String, dynamic>;
    } else {
      planData = null;
    }

    // Parse sections with error handling
    List<PlanSection> sections = [];
    if (planData != null && planData['sections'] is List) {
      try {
        sections = (planData['sections'] as List<dynamic>)
            .map((section) => PlanSection.fromJson(section as Map<String, dynamic>))
            .toList();
      } catch (e) {
        print('Error parsing sections: $e');
        sections = [];
      }
    }

    // Parse macro targets with error handling
    MacroTargets? macroTargets;
    if (planData != null && planData['macroTargets'] is Map) {
      try {
        macroTargets = MacroTargets.fromJson(planData['macroTargets'] as Map<String, dynamic>);
      } catch (e) {
        print('Error parsing macroTargets: $e');
        macroTargets = null;
      }
    }

    return NutritionPlan(
      id: json['plan_id'] as String,
      name: json['plan_name'] as String,
      sections: sections,
      macroTargets: macroTargets,
      totalCalories: json['total_calories'] is num ? (json['total_calories'] as num).toInt() : null,
      notes: json['notes'] as String?,
      runDateTime: json['run_date_time'] is String 
          ? DateTime.tryParse(json['run_date_time'])
          : null,
      planRating: json['plan_rating'] is num ? (json['plan_rating'] as num).toInt() : null,
      journalNotes: json['journal_notes'] as String?,
      version: json['version'] is num ? (json['version'] as num).toInt() : 1,
      lastModifiedBy: json['last_modified_by'] as String?,
      clientUpdatedAt: json['client_updated_at'] is String 
          ? DateTime.tryParse(json['client_updated_at'])
          : null,
      createdAt: json['created_at'] is String 
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] is String 
          ? DateTime.tryParse(json['updated_at'])
          : null,
      isDeleted: json['is_deleted'] is bool ? json['is_deleted'] as bool : false,
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
      'runDateTime': runDateTime?.toIso8601String(),
      'planRating': planRating,
      'journalNotes': journalNotes,
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
    this.proteinTarget,
    this.fatTarget,
    this.carbsTarget,
    this.sodiumTarget,
    this.fluidsTarget,
  });

  final String id;
  final String title; // "Before Run", "During Run", "After Run"
  final String? subtitle; // "30-60 min pre-run"
  final String? timing;
  final List<FoodItemData> foodItems;
  
  // Macro targets for this section (nullable with defaults)
  final double? proteinTarget; // grams
  final double? fatTarget; // grams
  final double? carbsTarget; // grams
  final double? sodiumTarget; // milligrams
  final double? fluidsTarget; // milliliters

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
      proteinTarget: json['proteinTarget'] as double?,
      fatTarget: json['fatTarget'] as double?,
      carbsTarget: json['carbsTarget'] as double?,
      sodiumTarget: json['sodiumTarget'] as double?,
      fluidsTarget: json['fluidsTarget'] as double?,
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
      'proteinTarget': proteinTarget,
      'fatTarget': fatTarget,
      'carbsTarget': carbsTarget,
      'sodiumTarget': sodiumTarget,
      'fluidsTarget': fluidsTarget,
    };
  }

  /// Create a copy with updated values
  PlanSection copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? timing,
    List<FoodItemData>? foodItems,
    double? proteinTarget,
    double? fatTarget,
    double? carbsTarget,
    double? sodiumTarget,
    double? fluidsTarget,
  }) {
    return PlanSection(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      timing: timing ?? this.timing,
      foodItems: foodItems ?? this.foodItems,
      proteinTarget: proteinTarget ?? this.proteinTarget,
      fatTarget: fatTarget ?? this.fatTarget,
      carbsTarget: carbsTarget ?? this.carbsTarget,
      sodiumTarget: sodiumTarget ?? this.sodiumTarget,
      fluidsTarget: fluidsTarget ?? this.fluidsTarget,
    );
  }

  /// Get default macro targets for this section type
  static PlanSection withDefaults({
    required String id,
    required String title,
    String? subtitle,
    String? timing,
    List<FoodItemData>? foodItems,
  }) {
    // Default values based on section type
    double? defaultProtein, defaultFat, defaultCarbs, defaultSodium, defaultFluids;
    
    switch (id) {
      case 'before-run':
      case 'pre-run':
        defaultCarbs = 30.0;
        defaultProtein = 5.0;
        defaultFat = 5.0;
        defaultSodium = 200.0;
        defaultFluids = 500.0;
        break;
      case 'during-run':
        defaultCarbs = 45.0;
        defaultProtein = 0.0;
        defaultFat = 0.0;
        defaultSodium = 250.0;
        defaultFluids = 600.0;
        break;
      case 'after-run':
      case 'post-run':
        defaultCarbs = 40.0;
        defaultProtein = 20.0;
        defaultFat = 10.0;
        defaultSodium = 300.0;
        defaultFluids = 500.0;
        break;
      default:
        defaultCarbs = 30.0;
        defaultProtein = 10.0;
        defaultFat = 5.0;
        defaultSodium = 200.0;
        defaultFluids = 500.0;
    }

    return PlanSection(
      id: id,
      title: title,
      subtitle: subtitle,
      timing: timing,
      foodItems: foodItems ?? [],
      proteinTarget: defaultProtein,
      fatTarget: defaultFat,
      carbsTarget: defaultCarbs,
      sodiumTarget: defaultSodium,
      fluidsTarget: defaultFluids,
    );
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