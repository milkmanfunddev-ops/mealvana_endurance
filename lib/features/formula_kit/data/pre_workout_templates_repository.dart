import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/data/syncable_repository.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sync/sync_dependency_graph.dart';

/// Repository for pre-workout templates (read-only reference data).
///
/// Templates are curated Before-phase formulas with per-serving macros and
/// a serving range. Synced from Supabase `pre_workout_templates` and cached
/// in Drift via [PreWorkoutTemplatesTable].
///
/// This is the source-of-truth table for Formula Kit's Before tab — the
/// legacy `templates` table (filtered by `phase = 'before'`) is no longer
/// used here.
class PreWorkoutTemplatesRepository with SyncableRepository {
  PreWorkoutTemplatesRepository(
    this._supabase,
    this._database, {
    AppLogger? logger,
  }) : _logger = logger ?? const NoopAppLogger();

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;

  // ========================================================================
  // SyncableRepository Implementation
  // ========================================================================

  @override
  String get repositoryKey => 'pre_workout_templates';

  @override
  List<String> get dependencies =>
      SyncDependencyGraph.dependenciesFor(repositoryKey);

  @override
  Future<bool> isStale() async {
    final localRows = await (_database.select(
      _database.preWorkoutTemplatesTable,
    )..where((t) => t.isActive.equals(true))).get();
    if (localRows.isEmpty) {
      _logger.debug(
        'Forcing sync - no local pre-workout templates found',
        context: 'PRE_WORKOUT_TEMPLATES_REPO',
      );
      return true;
    }
    return await super.isStale();
  }

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    try {
      _logger.info(
        'Syncing pre-workout templates from Supabase',
        context: 'PRE_WORKOUT_TEMPLATES_REPO',
      );

      final response = await _supabase
          .from('pre_workout_templates')
          .select('*')
          .eq('is_active', true)
          .order('name', ascending: true);

      await _syncToLocalDatabase(response as List<dynamic>);
      await setLastSyncTime(DateTime.now());

      _logger.info(
        'Pre-workout templates synced successfully',
        context: 'PRE_WORKOUT_TEMPLATES_REPO',
        data: {'count': response.length},
      );

      return SyncResult.successful(response.length);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync pre-workout templates from remote',
        context: 'PRE_WORKOUT_TEMPLATES_REPO',
        error: e,
        stackTrace: stackTrace,
      );
      return SyncResult.failed(e.toString());
    }
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    // Templates are read-only reference data.
    return UploadResult.nothingToUpload();
  }

  // ========================================================================
  // Query Methods
  // ========================================================================

  Future<List<PreWorkoutTemplateEntry>> getAll() async {
    return (_database.select(_database.preWorkoutTemplatesTable)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Future<PreWorkoutTemplateEntry?> getById(String id) async {
    return (_database.select(
      _database.preWorkoutTemplatesTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // ========================================================================
  // Private Methods
  // ========================================================================

  Future<void> _syncToLocalDatabase(List<dynamic> supabaseData) async {
    await _database.delete(_database.preWorkoutTemplatesTable).go();

    final entries = supabaseData.map((raw) {
      final json = raw as Map<String, dynamic>;
      return PreWorkoutTemplatesTableCompanion.insert(
        id: json['id'] as String,
        name: json['name'] as String,
        baseCategory: json['base_category'] as String,
        timeWindow: json['time_window'] as String,
        digestionSpeed: json['digestion_speed'] as String,
        allergens: Value(_arrayToJsonString(json['allergens'])),
        servingUnit: json['serving_unit'] as String,
        minServings: (json['min_servings'] as num).toDouble(),
        maxServings: (json['max_servings'] as num).toDouble(),
        plusBanana: Value(json['plus_banana'] as bool? ?? false),
        plusSportsDrink: Value(json['plus_sports_drink'] as bool? ?? false),
        notes: Value(json['notes'] as String?),
        isActive: Value(json['is_active'] as bool? ?? true),
        carbsPerServing: (json['carbs_per_serving'] as num).toDouble(),
        proteinPerServing: (json['protein_per_serving'] as num).toDouble(),
        fatPerServing: (json['fat_per_serving'] as num).toDouble(),
        sodiumMg: (json['sodium_mg'] as num).toDouble(),
        fluidMl: (json['fluid_ml'] as num).toDouble(),
        templateType: json['template_type'] as String,
        componentFoodNames:
            Value(_arrayToJsonString(json['component_food_names'])),
        componentQuantities: Value(_jsonbToString(json['component_quantities'])),
        excludedDiets: Value(_arrayToJsonString(json['excluded_diets'])),
        createdAt: Value(
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
              DateTime.now(),
        ),
        updatedAt: Value(
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
              DateTime.now(),
        ),
      );
    }).toList();

    await _database.batch((batch) {
      for (final entry in entries) {
        batch.insert(_database.preWorkoutTemplatesTable, entry);
      }
    });
  }

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

  String? _jsonbToString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return jsonEncode(value);
  }
}

final preWorkoutTemplatesRepositoryProvider =
    Provider<PreWorkoutTemplatesRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final logger = ref.watch(appLoggerProvider);
  final supabase = ref.watch(appExternalDepsProvider).supabaseClient;
  return PreWorkoutTemplatesRepository(supabase, database, logger: logger);
});
