import 'plan_section.dart';
import 'plan_macro_summary.dart';

// Re-export split files for backward compatibility
export 'plan_section.dart';
export 'plan_macro_summary.dart';

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
    this.activityId, // Link to calendar activity
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
  final PlanMacroSummary? macroTargets;
  final int? totalCalories;
  final String? notes;
  final DateTime? runDateTime; // Scheduled run date and time
  final int? planRating; // 1=Could be better, 2=Neutral, 3=Satisfied
  final String? journalNotes; // User's feedback notes about the plan
  final String?
  activityId; // Foreign key to activities table (calendar integration - UUID)

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
    PlanMacroSummary? macroTargets,
    int? totalCalories,
    String? notes,
    DateTime? runDateTime,
    int? planRating,
    String? journalNotes,
    String? activityId,
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
      activityId: activityId ?? this.activityId,
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

  /// Convert to JSON for API calls
  /// Note: Implementation delegated to NutritionPlanMapper in data layer
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
      'activityId': activityId,
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
