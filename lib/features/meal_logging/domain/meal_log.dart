import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../shared/database/app_database.dart';
import 'consumed_totals.dart';
import 'macro_rounding.dart';
import 'meal_component.dart';
import 'meal_log_source.dart';
import 'meal_relog.dart';
import 'meal_slot.dart';

/// Immutable domain model for a single meal log entry.
///
/// Maps 1:1 with [MealLogEntry] (Drift dataclass) but exposes:
/// - Typed enums ([slot], [source]) instead of raw wire strings.
/// - A decoded [components] list instead of a raw JSON string.
/// - A convenience [totalsFromComponents] helper for when the denormalised
///   calorie/macro columns are absent (e.g. partial manual entry).
///
/// **Soft delete convention.** [isDeleted] rows are tombstones; all read paths
/// filter `WHERE NOT is_deleted`. Never hard-delete rows — the tombstone must
/// propagate through upsert-only sync.
///
/// **Sync columns.** [needsUpload] and [localUpdatedAt] are Drift-only; they
/// are excluded from [toSupabaseJson]. `created_at` goes up only when the row
/// is new to the server; see [toSupabaseUpdateJson].
class MealLog {
  const MealLog({
    required this.id,
    required this.userId,
    required this.logDate,
    this.slot,
    required this.name,
    required this.source,
    required this.components,
    this.calories,
    this.carbsG,
    this.proteinG,
    this.fatG,
    this.sodiumMg,
    this.photoPath,
    this.recipeId,
    this.savedMealId,
    this.planMealId,
    this.notes,
    this.servings = 1,
    this.eatenAt,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.needsUpload,
    this.localUpdatedAt,
  });

  final String id;
  final String userId;

  /// Calendar day the meal counts toward, as `'yyyy-MM-dd'` (matches the
  /// Supabase DATE column stored as TEXT in Drift to avoid timezone drift).
  final String logDate;

  /// Which meal period this entry belongs to. Optional (2026-07 redesign) —
  /// the user may leave a logged meal untagged and rely on [eatenAt] /
  /// [createdAt] for ordering instead. Downstream readers (Fuel Timeline,
  /// grouped daily views) must tolerate `null` here.
  final MealSlot? slot;

  /// Display title, e.g. "Oatmeal + banana".
  final String name;

  final MealLogSource source;

  /// Decoded food components. May be empty when the entry was created without
  /// component detail (e.g. quick manual entry with just a name + total).
  final List<MealComponent> components;

  // Denormalised totals — sourced directly from the database columns.
  final int? calories;
  final double? carbsG;
  final double? proteinG;
  final double? fatG;
  final double? sodiumMg;

  /// Object path inside the `meal-photos` storage bucket (not a URL).
  final String? photoPath;

  /// Provenance pointer to the originating recipe (if source == recipe).
  final String? recipeId;

  /// Provenance pointer to the saved meal this was logged from (if source ==
  /// saved).
  final String? savedMealId;

  /// Provenance pointer to the `plan_meals` row this was logged from (if
  /// source == plan). Set server-side by `plan_log_from_plan`.
  final String? planMealId;

  final String? notes;

  /// How many servings this row holds: 1 unless a quick log or a Recent
  /// re-log was made at another count. [components] and the totals are the
  /// amount eaten (already multiplied); [perServing] divides them back out
  /// so Recent's 1 serving always means the original amount (112-012).
  final double servings;

  /// When the user ate this meal (user-adjustable; distinct from [createdAt]).
  final DateTime? eatenAt;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  /// Drift-only sync flag — `true` when the row has local edits not yet
  /// uploaded to Supabase. Not present in Supabase schema.
  final bool? needsUpload;

  /// Drift-only timestamp set whenever this row was mutated locally.
  final DateTime? localUpdatedAt;

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Compute [ConsumedTotals] from the decoded [components] list.
  ///
  /// Prefer the denormalised calorie/macro columns for display; use this helper
  /// when those columns are null (partial entry) or when re-aggregating after
  /// component edits before the DB write.
  ConsumedTotals totalsFromComponents() {
    if (components.isEmpty) {
      return ConsumedTotals(
        calories: calories ?? 0,
        carbsG: carbsG ?? 0,
        proteinG: proteinG ?? 0,
        fatG: fatG ?? 0,
        sodiumMg: sodiumMg ?? 0,
      );
    }
    return components.fold(const ConsumedTotals(), (acc, c) {
      return ConsumedTotals(
        calories: acc.calories + (c.calories ?? 0),
        carbsG: acc.carbsG + (c.carbG ?? 0),
        proteinG: acc.proteinG + (c.proteinG ?? 0),
        fatG: acc.fatG + (c.fatG ?? 0),
        sodiumMg: acc.sodiumMg + (c.sodiumMg ?? 0),
      );
    });
  }

  /// This log at one serving: items and totals divided by [servings], rounded
  /// like every stored number, with `servings` 1. A 1-serving log is
  /// returned as is. Recent lists, previews and re-logs this base.
  MealLog perServing() {
    if (servings == 1 || servings <= 0) return this;
    final factor = 1 / servings;
    return copyWith(
      components: [
        for (final c in components) scaleComponentForRelog(c, factor),
      ],
      calories: calories == null ? null : (calories! * factor).round(),
      carbsG: roundMacro(carbsG == null ? null : carbsG! * factor),
      proteinG: roundMacro(proteinG == null ? null : proteinG! * factor),
      fatG: roundMacro(fatG == null ? null : fatG! * factor),
      sodiumMg: roundSodium(sodiumMg == null ? null : sodiumMg! * factor),
      servings: 1,
    );
  }

  // ── Drift serialization ───────────────────────────────────────────────────

  /// Decode a Drift row into a [MealLog].
  ///
  /// [slot] is optional: a `null` column value means "untagged" (valid data,
  /// not an error). Returns `null` (skip the row) only when [source] is
  /// unrecognised, or when [slot] holds a non-null but unparseable wire value
  /// (forward-compat — an older binary skips rather than crashing).
  static MealLog? fromDriftEntry(MealLogEntry entry) {
    final rawSlot = entry.slot;
    final slot = rawSlot == null ? null : MealSlot.fromWireValue(rawSlot);
    if (rawSlot != null && slot == null) return null;
    final source = MealLogSource.fromWireValue(entry.source);
    if (source == null) return null;

    return MealLog(
      id: entry.id,
      userId: entry.userId,
      logDate: entry.logDate,
      slot: slot,
      name: entry.name,
      source: source,
      components: _decodeComponents(entry.items),
      calories: entry.calories,
      carbsG: entry.carbsG,
      proteinG: entry.proteinG,
      fatG: entry.fatG,
      sodiumMg: entry.sodiumMg,
      photoPath: entry.photoPath,
      recipeId: entry.recipeId,
      savedMealId: entry.savedMealId,
      planMealId: entry.planMealId,
      notes: entry.notes,
      servings: entry.servings,
      eatenAt: entry.eatenAt,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      isDeleted: entry.isDeleted,
      needsUpload: entry.needsUpload,
      localUpdatedAt: entry.localUpdatedAt,
    );
  }

  /// Convert to a Drift companion for insert/update operations.
  MealLogsTableCompanion toDriftCompanion() {
    return MealLogsTableCompanion.insert(
      id: Value(id),
      userId: userId,
      logDate: logDate,
      slot: Value(slot?.wireValue),
      name: name,
      source: source.wireValue,
      items: Value(jsonEncode(components.map((c) => c.toJson()).toList())),
      calories: Value(calories),
      carbsG: Value(carbsG),
      proteinG: Value(proteinG),
      fatG: Value(fatG),
      sodiumMg: Value(sodiumMg),
      photoPath: Value(photoPath),
      recipeId: Value(recipeId),
      savedMealId: Value(savedMealId),
      planMealId: Value(planMealId),
      notes: Value(notes),
      servings: Value(servings),
      eatenAt: Value(eatenAt),
      createdAt: createdAt,
      updatedAt: updatedAt,
      isDeleted: Value(isDeleted),
      needsUpload: Value(needsUpload),
      localUpdatedAt: Value(localUpdatedAt),
    );
  }

  // ── Supabase serialization ────────────────────────────────────────────────

  /// JSON payload for Supabase `meal_logs` upsert.
  ///
  /// Excludes Drift-only sync columns ([needsUpload], [localUpdatedAt]).
  /// The `items` column is sent as a native JSON array (not re-encoded string)
  /// so Postgres stores it as JSONB.
  ///
  /// `servings` goes up only when it is not 1: the server's column default
  /// is 1, and a build that reaches a project before migration 20260926163500
  /// then keeps uploading every ordinary log (PostgREST rejects an unknown
  /// column, PGRST204), failing only the scaled ones until the column lands.
  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'user_id': userId,
      'log_date': logDate, // DATE column: Supabase accepts 'yyyy-MM-dd' strings
      'slot': slot?.wireValue,
      'name': name,
      'source': source.wireValue,
      'items': components.map((c) => c.toJson()).toList(),
      if (calories != null) 'calories': calories,
      if (carbsG != null) 'carbs_g': carbsG,
      if (proteinG != null) 'protein_g': proteinG,
      if (fatG != null) 'fat_g': fatG,
      if (sodiumMg != null) 'sodium_mg': sodiumMg,
      'photo_path': photoPath,
      'recipe_id': recipeId,
      'saved_meal_id': savedMealId,
      'plan_meal_id': planMealId,
      'notes': notes,
      'servings': servings,
      'eaten_at': eatenAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  /// JSON payload for a `meal_logs` upsert that may land on a row the server
  /// already holds (an edit, a delete, a restore, a retried upload).
  ///
  /// Same as [toSupabaseJson] without `created_at`: the server's created time
  /// is the one it first wrote. The local copy holds it to whole seconds
  /// (Drift), so sending it back rewrote the server's value on every edit
  /// (testing-wave 27-002). A row the server never saw gets its created time
  /// from the insert-if-missing step before this upsert.
  Map<String, dynamic> toSupabaseUpdateJson() =>
      toSupabaseJson()..remove('created_at');

  /// Parse a Supabase row into a [MealLog].
  ///
  /// [slot] is optional (see [fromDriftEntry]). Returns `null` (skip the row)
  /// only when [source] is unrecognised, or [slot] holds a non-null but
  /// unparseable wire value.
  static MealLog? fromSupabaseJson(Map<String, dynamic> json) {
    final rawSlot = json['slot'] as String?;
    final slot = rawSlot == null ? null : MealSlot.fromWireValue(rawSlot);
    if (rawSlot != null && slot == null) return null;
    final source = MealLogSource.fromWireValue(json['source'] as String?);
    if (source == null) return null;

    return MealLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      logDate: json['log_date'] as String,
      slot: slot,
      name: json['name'] as String,
      source: source,
      components: _coerceComponents(json['items']),
      calories: (json['calories'] as num?)?.toInt(),
      carbsG: (json['carbs_g'] as num?)?.toDouble(),
      proteinG: (json['protein_g'] as num?)?.toDouble(),
      fatG: (json['fat_g'] as num?)?.toDouble(),
      sodiumMg: (json['sodium_mg'] as num?)?.toDouble(),
      photoPath: json['photo_path'] as String?,
      recipeId: json['recipe_id'] as String?,
      savedMealId: json['saved_meal_id'] as String?,
      planMealId: json['plan_meal_id'] as String?,
      notes: json['notes'] as String?,
      servings: (json['servings'] as num?)?.toDouble() ?? 1,
      eatenAt: json['eaten_at'] == null
          ? null
          : DateTime.parse(json['eaten_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }

  // ── copyWith ──────────────────────────────────────────────────────────────

  MealLog copyWith({
    String? id,
    String? userId,
    String? logDate,
    MealSlot? slot,

    /// When true, sets [slot] to `null` regardless of the [slot] argument
    /// (the plain `slot ?? this.slot` pattern can't express "clear it").
    bool clearSlot = false,
    String? name,
    MealLogSource? source,
    List<MealComponent>? components,
    int? calories,
    double? carbsG,
    double? proteinG,
    double? fatG,
    double? sodiumMg,

    /// Each `clear*` sets that total to `null` (unknown) regardless of the
    /// matching argument: `x ?? this.x` cannot express "the user emptied the
    /// field" (testing-wave 113-002).
    bool clearCalories = false,
    bool clearCarbsG = false,
    bool clearProteinG = false,
    bool clearFatG = false,
    bool clearSodiumMg = false,
    String? photoPath,
    String? recipeId,
    String? savedMealId,
    String? planMealId,
    String? notes,
    double? servings,
    DateTime? eatenAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? needsUpload,
    DateTime? localUpdatedAt,
  }) {
    return MealLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      logDate: logDate ?? this.logDate,
      slot: clearSlot ? null : (slot ?? this.slot),
      name: name ?? this.name,
      source: source ?? this.source,
      components: components ?? this.components,
      calories: clearCalories ? null : (calories ?? this.calories),
      carbsG: clearCarbsG ? null : (carbsG ?? this.carbsG),
      proteinG: clearProteinG ? null : (proteinG ?? this.proteinG),
      fatG: clearFatG ? null : (fatG ?? this.fatG),
      sodiumMg: clearSodiumMg ? null : (sodiumMg ?? this.sodiumMg),
      photoPath: photoPath ?? this.photoPath,
      recipeId: recipeId ?? this.recipeId,
      savedMealId: savedMealId ?? this.savedMealId,
      planMealId: planMealId ?? this.planMealId,
      notes: notes ?? this.notes,
      servings: servings ?? this.servings,
      eatenAt: eatenAt ?? this.eatenAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      needsUpload: needsUpload ?? this.needsUpload,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    );
  }

  // ── JSON helpers ──────────────────────────────────────────────────────────

  /// Decode the Drift TEXT `items` column (a JSON-encoded string).
  static List<MealComponent> _decodeComponents(String? raw) {
    if (raw == null || raw.isEmpty || raw == '[]') return const [];
    try {
      final decoded = jsonDecode(raw);
      return _coerceComponents(decoded);
    } catch (_) {
      return const [];
    }
  }

  /// Coerce a Supabase JSONB value (already decoded as a Dart List) or a raw
  /// JSON string into a list of [MealComponent].
  static List<MealComponent> _coerceComponents(Object? raw) {
    if (raw is String) return _decodeComponents(raw);
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => MealComponent.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }
}
