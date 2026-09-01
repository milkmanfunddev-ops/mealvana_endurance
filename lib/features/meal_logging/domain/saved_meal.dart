import 'dart:convert';

import 'package:drift/drift.dart'; // Value<T>

import '../../../shared/database/app_database.dart';
import 'meal_component.dart';

/// Immutable domain model for an explicit user favorite ("My Meals").
///
/// Maps 1:1 with [SavedMealEntry] (Drift dataclass). Saved meals hold the same
/// food-component structure as [MealLog] and are surfaced in the meal picker
/// for one-tap re-logging. They are never derived automatically from recent
/// logs — the user must explicitly save a meal.
///
/// Soft delete convention and sync columns follow the same rules as [MealLog].
class SavedMeal {
  const SavedMeal({
    required this.id,
    required this.userId,
    required this.name,
    required this.components,
    this.calories,
    this.carbsG,
    this.proteinG,
    this.fatG,
    this.sodiumMg,
    this.photoPath,
    this.icon,
    this.notes,
    this.mealTypes = const [],
    this.batch,
    this.libraryMealId,
    this.lastUsedAt,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.needsUpload,
    this.localUpdatedAt,
  });

  final String id;
  final String userId;

  /// Display name chosen by the user when saving.
  final String name;

  /// Decoded food components (same shape as [MealLog.components]).
  final List<MealComponent> components;

  // Denormalised totals.
  final int? calories;
  final double? carbsG;
  final double? proteinG;
  final double? fatG;
  final double? sodiumMg;

  /// Object path inside the `meal-photos` storage bucket.
  final String? photoPath;

  // ── Meal-planning columns (Drift v20) ─────────────────────────────────────

  /// `MealIcon` wire key (`saved_meals.icon`); null → classify from name.
  /// Kept as a string so this feature does not depend on meal_planning.
  final String? icon;

  /// The athlete's own directions (`saved_meals.notes`).
  final String? notes;

  /// Meal types this meal suits (`breakfast|lunch|dinner|snack` wire values).
  final List<String> mealTypes;

  /// Batch-cookable; null = unknown.
  final bool? batch;

  /// `meal_library.id` this saved meal was matched/copied from.
  final String? libraryMealId;

  /// Bumped each time the saved meal is re-logged (sorts the picker).
  final DateTime? lastUsedAt;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  /// Drift-only sync flag. Not present in Supabase schema.
  final bool? needsUpload;

  /// Drift-only timestamp set whenever this row was mutated locally.
  final DateTime? localUpdatedAt;

  // ── Drift serialization ───────────────────────────────────────────────────

  static SavedMeal fromDriftEntry(SavedMealEntry entry) {
    return SavedMeal(
      id: entry.id,
      userId: entry.userId,
      name: entry.name,
      components: _decodeComponents(entry.items),
      calories: entry.calories,
      carbsG: entry.carbsG,
      proteinG: entry.proteinG,
      fatG: entry.fatG,
      sodiumMg: entry.sodiumMg,
      photoPath: entry.photoPath,
      icon: entry.icon,
      notes: entry.notes,
      mealTypes: _decodeStringList(entry.mealTypes),
      batch: entry.batch,
      libraryMealId: entry.libraryMealId,
      lastUsedAt: entry.lastUsedAt,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      isDeleted: entry.isDeleted,
      needsUpload: entry.needsUpload,
      localUpdatedAt: entry.localUpdatedAt,
    );
  }

  SavedMealsTableCompanion toDriftCompanion() {
    return SavedMealsTableCompanion.insert(
      id: Value(id),
      userId: userId,
      name: name,
      items: Value(jsonEncode(components.map((c) => c.toJson()).toList())),
      calories: Value(calories),
      carbsG: Value(carbsG),
      proteinG: Value(proteinG),
      fatG: Value(fatG),
      sodiumMg: Value(sodiumMg),
      photoPath: Value(photoPath),
      icon: Value(icon),
      notes: Value(notes),
      mealTypes: Value(jsonEncode(mealTypes)),
      batch: Value(batch),
      libraryMealId: Value(libraryMealId),
      lastUsedAt: Value(lastUsedAt),
      createdAt: createdAt,
      updatedAt: updatedAt,
      isDeleted: Value(isDeleted),
      needsUpload: Value(needsUpload),
      localUpdatedAt: Value(localUpdatedAt),
    );
  }

  // ── Supabase serialization ────────────────────────────────────────────────

  /// JSON payload for Supabase `saved_meals` upsert.
  ///
  /// Excludes Drift-only sync columns ([needsUpload], [localUpdatedAt]).
  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'items': components.map((c) => c.toJson()).toList(),
      if (calories != null) 'calories': calories,
      if (carbsG != null) 'carbs_g': carbsG,
      if (proteinG != null) 'protein_g': proteinG,
      if (fatG != null) 'fat_g': fatG,
      if (sodiumMg != null) 'sodium_mg': sodiumMg,
      'photo_path': photoPath,
      'icon': icon,
      'notes': notes,
      'meal_types': mealTypes,
      'batch': batch,
      'library_meal_id': libraryMealId,
      'last_used_at': lastUsedAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  /// Parse a Supabase row.
  static SavedMeal fromSupabaseJson(Map<String, dynamic> json) {
    return SavedMeal(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      components: _coerceComponents(json['items']),
      calories: (json['calories'] as num?)?.toInt(),
      carbsG: (json['carbs_g'] as num?)?.toDouble(),
      proteinG: (json['protein_g'] as num?)?.toDouble(),
      fatG: (json['fat_g'] as num?)?.toDouble(),
      sodiumMg: (json['sodium_mg'] as num?)?.toDouble(),
      photoPath: json['photo_path'] as String?,
      icon: json['icon'] as String?,
      notes: json['notes'] as String?,
      mealTypes: _coerceStringList(json['meal_types']),
      batch: json['batch'] as bool?,
      libraryMealId: json['library_meal_id'] as String?,
      lastUsedAt: json['last_used_at'] == null
          ? null
          : DateTime.parse(json['last_used_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }

  // ── copyWith ──────────────────────────────────────────────────────────────

  SavedMeal copyWith({
    String? id,
    String? userId,
    String? name,
    List<MealComponent>? components,
    int? calories,
    double? carbsG,
    double? proteinG,
    double? fatG,
    double? sodiumMg,
    String? photoPath,
    String? icon,
    String? notes,
    List<String>? mealTypes,
    bool? batch,
    String? libraryMealId,
    DateTime? lastUsedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? needsUpload,
    DateTime? localUpdatedAt,
  }) {
    return SavedMeal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      components: components ?? this.components,
      calories: calories ?? this.calories,
      carbsG: carbsG ?? this.carbsG,
      proteinG: proteinG ?? this.proteinG,
      fatG: fatG ?? this.fatG,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      photoPath: photoPath ?? this.photoPath,
      icon: icon ?? this.icon,
      notes: notes ?? this.notes,
      mealTypes: mealTypes ?? this.mealTypes,
      batch: batch ?? this.batch,
      libraryMealId: libraryMealId ?? this.libraryMealId,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      needsUpload: needsUpload ?? this.needsUpload,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    );
  }

  // ── JSON helpers ──────────────────────────────────────────────────────────

  static List<MealComponent> _decodeComponents(String? raw) {
    if (raw == null || raw.isEmpty || raw == '[]') return const [];
    try {
      final decoded = jsonDecode(raw);
      return _coerceComponents(decoded);
    } catch (_) {
      return const [];
    }
  }

  /// Decode the Drift TEXT `meal_types` column (a JSON-encoded string array).
  static List<String> _decodeStringList(String? raw) {
    if (raw == null || raw.isEmpty || raw == '[]') return const [];
    try {
      return _coerceStringList(jsonDecode(raw));
    } catch (_) {
      return const [];
    }
  }

  /// Coerce a Supabase `text[]` (decoded List) or a JSON string.
  static List<String> _coerceStringList(Object? raw) {
    if (raw is String) return _decodeStringList(raw);
    if (raw is List) return raw.whereType<String>().toList(growable: false);
    return const [];
  }

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
