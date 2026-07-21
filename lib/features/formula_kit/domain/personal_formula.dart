import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../shared/database/app_database.dart';
import 'formula_phase.dart';
import 'formula_pin.dart' show TemplateKind;

/// How a [PersonalFormula] was authored.
///
/// Distinct from `personal_templates` provenance — there is no `legacy_plan`
/// here; saved nutrition-plan snapshots stay in `personal_templates`.
///
/// Forward-compat: [fromWireValue] returns `null` for unknown/null values so
/// an older binary reading a value written by a newer client skips the row
/// instead of crashing (mirrors [TemplateKind.fromWireValue]).
enum FormulaProvenance {
  /// Copied from a system formula via "Make this mine"; carries a source.
  forkedFormula('forked_formula'),

  /// Built from a blank slate.
  fromScratchFormula('from_scratch_formula');

  const FormulaProvenance(this.wireValue);

  /// String stored in Drift + Supabase.
  final String wireValue;

  static FormulaProvenance? fromWireValue(String? value) {
    if (value == null) return null;
    for (final p in FormulaProvenance.values) {
      if (p.wireValue == value) return p;
    }
    return null;
  }
}

/// Domain model for a Formula Kit personal formula — a user-authored,
/// reusable fueling recipe tied to a workout phase.
///
/// A distinct concept from [PersonalTemplate]: a formula is a recipe
/// (components + scope), not a saved nutrition-plan snapshot. Persisted in the
/// dedicated `personal_formulas` table with the same offline-first dirty
/// tracking + soft-delete convention as `formula_pins`.
///
/// [components] is stored opaque (a JSON array of component objects) until the
/// PR 4 edit UI finalizes the shape; readers should treat each element as a
/// `Map<String, dynamic>` with at least `food_name` and `quantity`.
class PersonalFormula {
  const PersonalFormula({
    required this.id,
    required this.userId,
    required this.name,
    required this.provenance,
    required this.phase,
    this.sourceTemplateId,
    this.sourceTemplateKind,
    this.subPhase,
    this.digestSpeed,
    this.activities,
    this.durations,
    this.gutTraining,
    this.travelFriendliness,
    this.components = const [],
    this.notes,
    this.coachInsightText,
    this.coachInsightMarker,
    this.totalCarbsG,
    this.totalProteinG,
    this.totalFatG,
    this.totalSodiumMg,
    this.totalFluidsMl,
    this.totalCalories,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.needsUpload,
    this.localUpdatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final FormulaProvenance provenance;
  final FormulaPhase phase;

  /// Forked-only: the system template this was copied from (polymorphic).
  final String? sourceTemplateId;
  final TemplateKind? sourceTemplateKind;

  // Phase-specific scope metadata.
  final String? subPhase;
  final String? digestSpeed;
  final List<String>? activities;
  final List<String>? durations;
  final String? gutTraining;
  final String? travelFriendliness;

  /// The formula body. Opaque component objects (see class doc).
  final List<Map<String, dynamic>> components;

  final String? notes;

  /// Persisted coach AI insight text (persist-unless-edited).
  final String? coachInsightText;

  /// FNV-1a hash of the draft state when the insight was generated.
  final String? coachInsightMarker;

  final int? totalCarbsG;
  final int? totalProteinG;
  final int? totalFatG;
  final int? totalSodiumMg;
  final int? totalFluidsMl;
  final int? totalCalories;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  /// Drift-only sync flag (not present in Supabase).
  final bool? needsUpload;

  /// Drift-only timestamp set when local row was last mutated.
  final DateTime? localUpdatedAt;

  /// Decode a Drift row into a [PersonalFormula].
  ///
  /// Returns `null` if [provenance] or [phase] holds a wire value this binary
  /// doesn't recognize (forward-compat). Callers should skip null results and
  /// log the unknown value. `source_template_kind`, when present but
  /// unrecognized, decodes to `null` (it's optional metadata, not a gate).
  static PersonalFormula? fromDriftEntry(PersonalFormulaEntry entry) {
    final provenance = FormulaProvenance.fromWireValue(entry.provenance);
    final phase = FormulaPhase.fromWireValue(entry.phase);
    if (provenance == null || phase == null) return null;

    return PersonalFormula(
      id: entry.id,
      userId: entry.userId,
      name: entry.name,
      provenance: provenance,
      phase: phase,
      sourceTemplateId: entry.sourceTemplateId,
      sourceTemplateKind: TemplateKind.fromWireValue(entry.sourceTemplateKind),
      subPhase: entry.subPhase,
      digestSpeed: entry.digestSpeed,
      activities: _decodeStringList(entry.activities),
      durations: _decodeStringList(entry.durations),
      gutTraining: entry.gutTraining,
      travelFriendliness: entry.travelFriendliness,
      components: _decodeComponents(entry.components),
      notes: entry.notes,
      coachInsightText: entry.coachInsightText,
      coachInsightMarker: entry.coachInsightMarker,
      totalCarbsG: entry.totalCarbsG,
      totalProteinG: entry.totalProteinG,
      totalFatG: entry.totalFatG,
      totalSodiumMg: entry.totalSodiumMg,
      totalFluidsMl: entry.totalFluidsMl,
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
      provenance: Value(provenance.wireValue),
      phase: Value(phase.wireValue),
      sourceTemplateId: Value(sourceTemplateId),
      sourceTemplateKind: Value(sourceTemplateKind?.wireValue),
      subPhase: Value(subPhase),
      digestSpeed: Value(digestSpeed),
      activities: Value(activities == null ? null : jsonEncode(activities)),
      durations: Value(durations == null ? null : jsonEncode(durations)),
      gutTraining: Value(gutTraining),
      travelFriendliness: Value(travelFriendliness),
      components: Value(jsonEncode(components)),
      notes: Value(notes),
      coachInsightText: Value(coachInsightText),
      coachInsightMarker: Value(coachInsightMarker),
      totalCarbsG: Value(totalCarbsG),
      totalProteinG: Value(totalProteinG),
      totalFatG: Value(totalFatG),
      totalSodiumMg: Value(totalSodiumMg),
      totalFluidsMl: Value(totalFluidsMl),
      totalCalories: Value(totalCalories),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
      needsUpload: Value(needsUpload),
      localUpdatedAt: Value(localUpdatedAt),
    );
  }

  /// JSON payload sent to Supabase `personal_formulas`. Excludes the
  /// Drift-only sync columns (`needs_upload`, `local_updated_at`). JSON columns
  /// are sent as native structures (not re-encoded strings) so Postgres stores
  /// them as JSONB.
  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'provenance': provenance.wireValue,
      'phase': phase.wireValue,
      'source_template_id': sourceTemplateId,
      'source_template_kind': sourceTemplateKind?.wireValue,
      'sub_phase': subPhase,
      'digest_speed': digestSpeed,
      'activities': activities,
      'durations': durations,
      'gut_training': gutTraining,
      'travel_friendliness': travelFriendliness,
      'components': components,
      'notes': notes,
      'coach_insight_text': coachInsightText,
      'coach_insight_marker': coachInsightMarker,
      'total_carbs_g': totalCarbsG,
      'total_protein_g': totalProteinG,
      'total_fat_g': totalFatG,
      'total_sodium_mg': totalSodiumMg,
      'total_fluids_ml': totalFluidsMl,
      'total_calories': totalCalories,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  /// Parse a Supabase row into a [PersonalFormula].
  ///
  /// Returns `null` on unrecognized provenance/phase (forward-compat), matching
  /// [fromDriftEntry].
  static PersonalFormula? fromSupabaseJson(Map<String, dynamic> json) {
    final provenance = FormulaProvenance.fromWireValue(
      json['provenance'] as String?,
    );
    final phase = FormulaPhase.fromWireValue(json['phase'] as String?);
    if (provenance == null || phase == null) return null;

    return PersonalFormula(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      provenance: provenance,
      phase: phase,
      sourceTemplateId: json['source_template_id'] as String?,
      sourceTemplateKind: TemplateKind.fromWireValue(
        json['source_template_kind'] as String?,
      ),
      subPhase: json['sub_phase'] as String?,
      digestSpeed: json['digest_speed'] as String?,
      activities: _coerceStringList(json['activities']),
      durations: _coerceStringList(json['durations']),
      gutTraining: json['gut_training'] as String?,
      travelFriendliness: json['travel_friendliness'] as String?,
      components: _coerceComponents(json['components']),
      notes: json['notes'] as String?,
      coachInsightText: json['coach_insight_text'] as String?,
      coachInsightMarker: json['coach_insight_marker'] as String?,
      totalCarbsG: (json['total_carbs_g'] as num?)?.toInt(),
      totalProteinG: (json['total_protein_g'] as num?)?.toInt(),
      totalFatG: (json['total_fat_g'] as num?)?.toInt(),
      totalSodiumMg: (json['total_sodium_mg'] as num?)?.toInt(),
      totalFluidsMl: (json['total_fluids_ml'] as num?)?.toInt(),
      totalCalories: (json['total_calories'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }

  static const _sentinel = Object();

  PersonalFormula copyWith({
    String? id,
    String? userId,
    String? name,
    FormulaProvenance? provenance,
    FormulaPhase? phase,
    String? sourceTemplateId,
    TemplateKind? sourceTemplateKind,
    String? subPhase,
    String? digestSpeed,
    List<String>? activities,
    List<String>? durations,
    String? gutTraining,
    String? travelFriendliness,
    List<Map<String, dynamic>>? components,
    String? notes,
    Object? coachInsightText = _sentinel,
    Object? coachInsightMarker = _sentinel,
    int? totalCarbsG,
    int? totalProteinG,
    int? totalFatG,
    int? totalSodiumMg,
    int? totalFluidsMl,
    int? totalCalories,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? needsUpload,
    DateTime? localUpdatedAt,
  }) {
    return PersonalFormula(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      provenance: provenance ?? this.provenance,
      phase: phase ?? this.phase,
      sourceTemplateId: sourceTemplateId ?? this.sourceTemplateId,
      sourceTemplateKind: sourceTemplateKind ?? this.sourceTemplateKind,
      subPhase: subPhase ?? this.subPhase,
      digestSpeed: digestSpeed ?? this.digestSpeed,
      activities: activities ?? this.activities,
      durations: durations ?? this.durations,
      gutTraining: gutTraining ?? this.gutTraining,
      travelFriendliness: travelFriendliness ?? this.travelFriendliness,
      components: components ?? this.components,
      notes: notes ?? this.notes,
      coachInsightText: coachInsightText == _sentinel
          ? this.coachInsightText
          : coachInsightText as String?,
      coachInsightMarker: coachInsightMarker == _sentinel
          ? this.coachInsightMarker
          : coachInsightMarker as String?,
      totalCarbsG: totalCarbsG ?? this.totalCarbsG,
      totalProteinG: totalProteinG ?? this.totalProteinG,
      totalFatG: totalFatG ?? this.totalFatG,
      totalSodiumMg: totalSodiumMg ?? this.totalSodiumMg,
      totalFluidsMl: totalFluidsMl ?? this.totalFluidsMl,
      totalCalories: totalCalories ?? this.totalCalories,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      needsUpload: needsUpload ?? this.needsUpload,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    );
  }

  // ── JSON helpers ─────────────────────────────────────────────────────────

  static List<String>? _decodeStringList(String? raw) {
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).toList();
    } catch (_) {
      return null;
    }
  }

  static List<String>? _coerceStringList(Object? raw) {
    if (raw == null) return null;
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String) return _decodeStringList(raw);
    return null;
  }

  static List<Map<String, dynamic>> _decodeComponents(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      return _coerceComponents(decoded);
    } catch (_) {
      return const [];
    }
  }

  static List<Map<String, dynamic>> _coerceComponents(Object? raw) {
    if (raw is String) return _decodeComponents(raw);
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }
}
