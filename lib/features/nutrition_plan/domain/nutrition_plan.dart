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

/// Per-phase food item counts, for analytics.
///
/// Reported on `nutrition_plan_created_from_adjusted_macros`, which is the
/// first point at which a food plan actually exists. `plan_generated` fires
/// earlier, at macro generation, where there is nothing to count — it used to
/// carry hardcoded `1`s for these.
extension NutritionPlanItemCounts on NutritionPlan {
  /// Foods in the before phase, **including sub-phase items**.
  ///
  /// The V2 format puts before-phase foods under `subPhases` (meal / snack /
  /// top_up) and leaves the section's own `foodItems` empty, so counting only
  /// `foodItems` reports 0 for most real plans.
  int get beforeItemCount => _countFor('before');

  int get duringItemCount => _countFor('during');

  int get afterItemCount => _countFor('after');

  /// Classifies on `section.id` (`before_run` / `during_run` / `after_run`),
  /// matching how the UI groups phases. Deliberately **not** on `title`: titles
  /// are display strings that vary by sport — a brick renders "BEFORE BRICK"
  /// and "DURING BIKE", so title matching would silently return 0 for every
  /// non-running plan.
  int _countFor(String phase) {
    var total = 0;
    for (final section in sections) {
      if (_phaseOf(section.id) != phase) continue;
      total += section.foodItems.length;
      final subPhases = section.subPhases;
      if (subPhases != null) {
        for (final subPhase in subPhases) {
          total += subPhase.foodItems.length;
        }
      }
    }
    return total;
  }

  /// Same precedence the widgets use: during, then after, else before.
  static String _phaseOf(String sectionId) {
    if (sectionId.contains('during')) return 'during';
    if (sectionId.contains('after')) return 'after';
    return 'before';
  }
}
