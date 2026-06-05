import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../../shared/database/app_database.dart';
import 'before_sub_phase.dart';
import 'formula_phase.dart';
import 'formula_view.dart';

/// A single component of a [PersonalFormula] — the persisted shape of a
/// [BeforeComponent] (food identity + per-serving macros + quantity).
///
/// [userFoodId] references `user_foods.id` when the component was swapped to a
/// user-created food (PR 5b); null for stock template foods.
@immutable
class PersonalFormulaComponent {
  const PersonalFormulaComponent({
    required this.foodKey,
    required this.quantity,
    required this.carbsPerServing,
    required this.proteinPerServing,
    required this.fatPerServing,
    required this.sodiumMgPerServing,
    required this.fluidMlPerServing,
    this.userFoodId,
    this.displayName,
    this.displayNamePlural,
    this.servingUnit,
  });

  final String foodKey;
  final String? userFoodId;
  final String? displayName;
  final String? displayNamePlural;
  final String? servingUnit;
  final double quantity;
  final double carbsPerServing;
  final double proteinPerServing;
  final double fatPerServing;
  final double sodiumMgPerServing;
  final double fluidMlPerServing;

  /// Build from the edit-state [BeforeComponent]. There is no [userFoodId] yet
  /// — swap-to-user-food lands in PR 5b.
  factory PersonalFormulaComponent.fromBeforeComponent(BeforeComponent c) {
    return PersonalFormulaComponent(
      foodKey: c.foodKey,
      displayName: c.displayName,
      displayNamePlural: c.displayNamePlural,
      servingUnit: c.servingUnit,
      quantity: c.quantity,
      carbsPerServing: c.carbsPerServing,
      proteinPerServing: c.proteinPerServing,
      fatPerServing: c.fatPerServing,
      sodiumMgPerServing: c.sodiumMgPerServing,
      fluidMlPerServing: c.fluidMlPerServing,
    );
  }

  Map<String, dynamic> toJson() => {
        'food_key': foodKey,
        'user_food_id': userFoodId,
        'display_name': displayName,
        'display_name_plural': displayNamePlural,
        'serving_unit': servingUnit,
        'quantity': quantity,
        'carbs_per_serving': carbsPerServing,
        'protein_per_serving': proteinPerServing,
        'fat_per_serving': fatPerServing,
        'sodium_mg_per_serving': sodiumMgPerServing,
        'fluid_ml_per_serving': fluidMlPerServing,
      };

  static PersonalFormulaComponent fromJson(Map<String, dynamic> json) {
    double d(Object? v) => (v as num?)?.toDouble() ?? 0;
    return PersonalFormulaComponent(
      foodKey: json['food_key'] as String? ?? '',
      userFoodId: json['user_food_id'] as String?,
      displayName: json['display_name'] as String?,
      displayNamePlural: json['display_name_plural'] as String?,
      servingUnit: json['serving_unit'] as String?,
      quantity: d(json['quantity']),
      carbsPerServing: d(json['carbs_per_serving']),
      proteinPerServing: d(json['protein_per_serving']),
      fatPerServing: d(json['fat_per_serving']),
      sodiumMgPerServing: d(json['sodium_mg_per_serving']),
      fluidMlPerServing: d(json['fluid_ml_per_serving']),
    );
  }
}

/// A user's edited/forked copy of a system Before/During formula, persisted via
/// the "Make this mine" save on the formula detail screen (Formula Kit PR 5).
///
/// Mirrors the Supabase `personal_formulas` table. Offline-first: writes set
/// [needsUpload] and a non-blocking upload follows; soft-deleted via
/// [isDeleted] so deletions propagate across devices.
@immutable
class PersonalFormula {
  const PersonalFormula({
    required this.id,
    required this.userId,
    required this.name,
    required this.phase,
    required this.components,
    required this.totalCarbsG,
    required this.totalProteinG,
    required this.totalFatG,
    required this.totalSodiumMg,
    required this.totalFluidMl,
    required this.totalCalories,
    required this.createdAt,
    required this.updatedAt,
    this.sourceTemplateId,
    this.subPhase,
    this.digestionSpeed,
    this.templateType,
    this.activityTypes,
    this.durationBrackets,
    this.gutTrainingLevels,
    this.isDeleted = false,
    this.needsUpload,
    this.localUpdatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final FormulaPhase phase;
  final String? sourceTemplateId;

  // Before-phase context.
  final BeforeSubPhase? subPhase;
  final String? digestionSpeed;
  final String? templateType;

  // During-phase context.
  final List<String>? activityTypes;
  final List<String>? durationBrackets;
  final List<String>? gutTrainingLevels;

  final List<PersonalFormulaComponent> components;

  final double totalCarbsG;
  final double totalProteinG;
  final double totalFatG;
  final double totalSodiumMg;
  final double totalFluidMl;
  final int totalCalories;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  /// Drift-only sync flag (not present in Supabase).
  final bool? needsUpload;

  /// Drift-only timestamp set when the local row was last mutated.
  final DateTime? localUpdatedAt;

  /// Decode a Drift row. Returns null if [PersonalFormulaEntry.phase] holds an
  /// unrecognized value (forward-compat — skip + log rather than crash).
  static PersonalFormula? fromDriftEntry(PersonalFormulaEntry entry) {
    final phase = _phaseFromWire(entry.phase);
    if (phase == null) return null;
    return PersonalFormula(
      id: entry.id,
      userId: entry.userId,
      name: entry.name,
      phase: phase,
      sourceTemplateId: entry.sourceTemplateId,
      subPhase: BeforeSubPhase.fromStorageValue(entry.subPhase),
      digestionSpeed: entry.digestionSpeed,
      templateType: entry.templateType,
      activityTypes: _decodeStringList(entry.activityTypes),
      durationBrackets: _decodeStringList(entry.durationBrackets),
      gutTrainingLevels: _decodeStringList(entry.gutTrainingLevels),
      components: _decodeComponents(entry.components),
      totalCarbsG: entry.totalCarbsG,
      totalProteinG: entry.totalProteinG,
      totalFatG: entry.totalFatG,
      totalSodiumMg: entry.totalSodiumMg,
      totalFluidMl: entry.totalFluidMl,
      totalCalories: entry.totalCalories,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      isDeleted: entry.isDeleted,
      needsUpload: entry.needsUpload,
      localUpdatedAt: entry.localUpdatedAt,
    );
  }

  PersonalFormulasTableCompanion toDriftCompanion() {
    return PersonalFormulasTableCompanion(
      id: Value(id),
      userId: Value(userId),
      name: Value(name),
      phase: Value(phase.analyticsValue),
      sourceTemplateId: Value(sourceTemplateId),
      subPhase: Value(subPhase?.storageValue),
      digestionSpeed: Value(digestionSpeed),
      templateType: Value(templateType),
      activityTypes: Value(_encodeStringList(activityTypes)),
      durationBrackets: Value(_encodeStringList(durationBrackets)),
      gutTrainingLevels: Value(_encodeStringList(gutTrainingLevels)),
      components: Value(jsonEncode(components.map((c) => c.toJson()).toList())),
      totalCarbsG: Value(totalCarbsG),
      totalProteinG: Value(totalProteinG),
      totalFatG: Value(totalFatG),
      totalSodiumMg: Value(totalSodiumMg),
      totalFluidMl: Value(totalFluidMl),
      totalCalories: Value(totalCalories),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
      needsUpload: Value(needsUpload),
      localUpdatedAt: Value(localUpdatedAt),
    );
  }

  /// JSON payload for the Supabase `personal_formulas` table. Excludes the
  /// Drift-only sync columns. `components` is sent as a List (Supabase JSONB);
  /// during arrays are sent as `List<String>` (Postgres `text[]`).
  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'phase': phase.analyticsValue,
      'source_template_id': sourceTemplateId,
      'sub_phase': subPhase?.storageValue,
      'digestion_speed': digestionSpeed,
      'template_type': templateType,
      'activity_types': activityTypes,
      'duration_brackets': durationBrackets,
      'gut_training_levels': gutTrainingLevels,
      'components': components.map((c) => c.toJson()).toList(),
      'total_carbs_g': totalCarbsG,
      'total_protein_g': totalProteinG,
      'total_fat_g': totalFatG,
      'total_sodium_mg': totalSodiumMg,
      'total_fluid_ml': totalFluidMl,
      'total_calories': totalCalories,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  /// Build a Drift companion from a Supabase row (used by the remote-upsert
  /// path). Sets [needsUpload] to false since the row just came from remote.
  static PersonalFormulasTableCompanion companionFromSupabaseJson(
    Map<String, dynamic> json,
  ) {
    double d(Object? v) => (v as num?)?.toDouble() ?? 0;
    int i(Object? v) => (v as num?)?.toInt() ?? 0;
    return PersonalFormulasTableCompanion.insert(
      id: Value(json['id'] as String),
      userId: json['user_id'] as String,
      name: json['name'] as String? ?? '',
      phase: json['phase'] as String? ?? FormulaPhase.before.analyticsValue,
      sourceTemplateId: Value(json['source_template_id'] as String?),
      subPhase: Value(json['sub_phase'] as String?),
      digestionSpeed: Value(json['digestion_speed'] as String?),
      templateType: Value(json['template_type'] as String?),
      activityTypes: Value(_encodeRemoteList(json['activity_types'])),
      durationBrackets: Value(_encodeRemoteList(json['duration_brackets'])),
      gutTrainingLevels: Value(_encodeRemoteList(json['gut_training_levels'])),
      components: Value(jsonEncode(json['components'] ?? const [])),
      totalCarbsG: Value(d(json['total_carbs_g'])),
      totalProteinG: Value(d(json['total_protein_g'])),
      totalFatG: Value(d(json['total_fat_g'])),
      totalSodiumMg: Value(d(json['total_sodium_mg'])),
      totalFluidMl: Value(d(json['total_fluid_ml'])),
      totalCalories: Value(i(json['total_calories'])),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isDeleted: Value(json['is_deleted'] as bool? ?? false),
      needsUpload: const Value(false),
      localUpdatedAt: Value(DateTime.now()),
    );
  }

  PersonalFormula copyWith({
    String? name,
    List<PersonalFormulaComponent>? components,
    double? totalCarbsG,
    double? totalProteinG,
    double? totalFatG,
    double? totalSodiumMg,
    double? totalFluidMl,
    int? totalCalories,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? needsUpload,
    DateTime? localUpdatedAt,
  }) {
    return PersonalFormula(
      id: id,
      userId: userId,
      name: name ?? this.name,
      phase: phase,
      sourceTemplateId: sourceTemplateId,
      subPhase: subPhase,
      digestionSpeed: digestionSpeed,
      templateType: templateType,
      activityTypes: activityTypes,
      durationBrackets: durationBrackets,
      gutTrainingLevels: gutTrainingLevels,
      components: components ?? this.components,
      totalCarbsG: totalCarbsG ?? this.totalCarbsG,
      totalProteinG: totalProteinG ?? this.totalProteinG,
      totalFatG: totalFatG ?? this.totalFatG,
      totalSodiumMg: totalSodiumMg ?? this.totalSodiumMg,
      totalFluidMl: totalFluidMl ?? this.totalFluidMl,
      totalCalories: totalCalories ?? this.totalCalories,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      needsUpload: needsUpload ?? this.needsUpload,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    );
  }

  static FormulaPhase? _phaseFromWire(String value) {
    for (final p in FormulaPhase.values) {
      if (p.analyticsValue == value) return p;
    }
    return null;
  }

  static List<PersonalFormulaComponent> _decodeComponents(String raw) {
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) =>
              PersonalFormulaComponent.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static List<String>? _decodeStringList(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded.whereType<String>().toList();
    } catch (_) {
      return null;
    }
  }

  static String? _encodeStringList(List<String>? list) {
    if (list == null) return null;
    return jsonEncode(list);
  }

  static String? _encodeRemoteList(Object? value) {
    if (value == null) return null;
    if (value is List) {
      return jsonEncode(value.whereType<String>().toList());
    }
    return null;
  }
}
