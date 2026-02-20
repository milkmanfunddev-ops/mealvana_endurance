import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/data/syncable_repository.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';

/// Repository for nutrition templates (read-only reference data).
///
/// Templates are curated pre-workout food combinations that can be
/// scaled to hit macro targets. They are synced from Supabase and
/// cached locally in Drift.
class TemplatesRepository with SyncableRepository {
  TemplatesRepository(this._supabase, this._database, {AppLogger? logger})
      : _logger = logger ?? const NoopAppLogger();

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;

  // ========================================================================
  // SyncableRepository Implementation
  // ========================================================================

  @override
  String get repositoryKey => 'templates';

  @override
  List<String> get dependencies => ['template_foods'];

  @override
  Future<bool> isStale() async {
    final localCount = await (_database.select(_database.templatesTable)
          ..where((t) => t.isActive.equals(true)))
        .get();
    if (localCount.isEmpty) {
      _logger.debug(
        'Forcing sync - no local templates found',
        context: 'TEMPLATES_REPO',
      );
      return true;
    }
    return await super.isStale();
  }

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    try {
      _logger.info(
        'Syncing templates from Supabase',
        context: 'TEMPLATES_REPO',
      );

      final response = await _supabase
          .from('templates')
          .select('*')
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      await _syncToLocalDatabase(response as List<dynamic>);
      await setLastSyncTime(DateTime.now());

      _logger.info(
        'Templates synced successfully',
        context: 'TEMPLATES_REPO',
        data: {'count': response.length},
      );

      return SyncResult.successful(response.length);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync templates from remote',
        context: 'TEMPLATES_REPO',
        error: e,
        stackTrace: stackTrace,
      );
      return SyncResult.failed(e.toString());
    }
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    // Templates are read-only reference data
    return UploadResult.nothingToUpload();
  }

  // ========================================================================
  // Query Methods
  // ========================================================================

  /// Get all active templates from local database
  Future<List<TemplateEntry>> getAllTemplates() async {
    return (_database.select(_database.templatesTable)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  /// Get templates filtered by meal type
  Future<List<TemplateEntry>> getTemplatesByMealType(String mealType) async {
    return (_database.select(_database.templatesTable)
          ..where((t) =>
              t.isActive.equals(true) & t.mealType.equals(mealType))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  /// Get a template by ID
  Future<TemplateEntry?> getTemplateById(String id) async {
    return (_database.select(_database.templatesTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get a template by slug
  Future<TemplateEntry?> getTemplateBySlug(String slug) async {
    return (_database.select(_database.templatesTable)
          ..where((t) => t.slug.equals(slug)))
        .getSingleOrNull();
  }

  // ========================================================================
  // Private Methods
  // ========================================================================

  Future<void> _syncToLocalDatabase(List<dynamic> supabaseData) async {
    await _database.delete(_database.templatesTable).go();

    final entries = supabaseData.map((json) {
      // Handle JSONB foods - convert to JSON string for SQLite
      final foodsValue = json['foods'];
      String foodsJson;
      if (foodsValue is List) {
        foodsJson = jsonEncode(foodsValue);
      } else if (foodsValue is String) {
        foodsJson = foodsValue;
      } else {
        foodsJson = '[]';
      }

      return TemplatesTableCompanion.insert(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        phase: Value(json['phase'] as String? ?? 'before'),
        timingWindow: json['timing_window'] as String,
        timingMinMinutes: json['timing_min_minutes'] as int,
        timingMaxMinutes: json['timing_max_minutes'] as int,
        mealType: Value(json['meal_type'] as String? ?? 'snack'),
        baseCategory: json['base_category'] as String,
        digestionSpeed: Value(json['digestion_speed'] as String? ?? 'medium'),
        allergens: Value(_arrayToJsonString(json['allergens'])),
        excludedDiets: Value(_arrayToJsonString(json['excluded_diets'])),
        notes: Value(json['notes'] as String?),
        foods: Value(foodsJson),
        totalCarbsG: Value((json['total_carbs_g'] as num?)?.toDouble() ?? 0),
        totalProteinG: Value((json['total_protein_g'] as num?)?.toDouble() ?? 0),
        totalFatG: Value((json['total_fat_g'] as num?)?.toDouble() ?? 0),
        totalSodiumMg: Value((json['total_sodium_mg'] as num?)?.toDouble() ?? 0),
        totalFluidMl: Value((json['total_fluid_ml'] as num?)?.toDouble() ?? 0),
        totalCalories: Value((json['total_calories'] as num?)?.toInt() ?? 0),
        validationStatus: Value(json['validation_status'] as String? ?? 'unvalidated'),
        isActive: Value(json['is_active'] as bool? ?? true),
        sortOrder: Value(json['sort_order'] as int? ?? 0),
        foodNames: Value(_arrayToJsonString(json['food_names'])),
        createdAt: Value(DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now()),
        updatedAt: Value(DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now()),
      );
    }).toList();

    await _database.batch((batch) {
      for (final entry in entries) {
        batch.insert(_database.templatesTable, entry);
      }
    });
  }

  /// Convert PostgreSQL array or Dart list to JSON string for SQLite storage
  String _arrayToJsonString(dynamic value) {
    if (value == null) return '[]';
    if (value is List) return jsonEncode(value);
    if (value is String) {
      if (value.startsWith('{') && value.endsWith('}')) {
        final content = value.substring(1, value.length - 1);
        if (content.isEmpty) return '[]';
        final items = content.split(',').map((s) => s.trim()).toList();
        return jsonEncode(items);
      }
      if (value.startsWith('[')) return value;
      return '[]';
    }
    return '[]';
  }
}

/// Riverpod provider for TemplatesRepository
final templatesRepositoryProvider = Provider<TemplatesRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final logger = ref.watch(appLoggerProvider);
  final supabase = ref.watch(appExternalDepsProvider).supabaseClient;
  return TemplatesRepository(supabase, database, logger: logger);
});
