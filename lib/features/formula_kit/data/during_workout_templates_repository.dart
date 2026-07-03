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

/// Repository for during-workout templates (read-only reference data).
///
/// Templates are curated formulas combining one or more foods appropriate for
/// a specific activity type, duration bracket, and gut-training level. They
/// are synced from Supabase `during_workout_templates` and cached in Drift.
///
/// Mirrors [TemplatesRepository] (pre-workout) but kept as a sibling rather
/// than an extension so each table tracks its own staleness independently and
/// the existing pre-workout sync path is untouched.
class DuringWorkoutTemplatesRepository with SyncableRepository {
  DuringWorkoutTemplatesRepository(
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
  String get repositoryKey => 'during_workout_templates';

  @override
  List<String> get dependencies =>
      SyncDependencyGraph.dependenciesFor(repositoryKey);

  @override
  Future<bool> isStale() async {
    final localRows = await (_database.select(
      _database.duringWorkoutTemplatesTable,
    )..where((t) => t.isActive.equals(true))).get();
    if (localRows.isEmpty) {
      _logger.debug(
        'Forcing sync - no local during-workout templates found',
        context: 'DURING_TEMPLATES_REPO',
      );
      return true;
    }
    return await super.isStale();
  }

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    try {
      _logger.info(
        'Syncing during-workout templates from Supabase',
        context: 'DURING_TEMPLATES_REPO',
      );

      final response = await _supabase
          .from('during_workout_templates')
          .select('*')
          .eq('is_active', true)
          .order('template_number', ascending: true);

      await _syncToLocalDatabase(response as List<dynamic>);
      await setLastSyncTime(DateTime.now());

      _logger.info(
        'During-workout templates synced successfully',
        context: 'DURING_TEMPLATES_REPO',
        data: {'count': response.length},
      );

      return SyncResult.successful(response.length);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync during-workout templates from remote',
        context: 'DURING_TEMPLATES_REPO',
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

  /// Get all active during-workout templates from local database, ordered by
  /// template_number ascending.
  Future<List<DuringWorkoutTemplateEntry>> getAll() async {
    return (_database.select(_database.duringWorkoutTemplatesTable)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.templateNumber)]))
        .get();
  }

  /// Get a single template by id.
  Future<DuringWorkoutTemplateEntry?> getById(String id) async {
    return (_database.select(
      _database.duringWorkoutTemplatesTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // ========================================================================
  // Private Methods
  // ========================================================================

  Future<void> _syncToLocalDatabase(List<dynamic> supabaseData) async {
    await _database.delete(_database.duringWorkoutTemplatesTable).go();

    final entries = supabaseData.map((raw) {
      final json = raw as Map<String, dynamic>;
      return DuringWorkoutTemplatesTableCompanion.insert(
        id: json['id'] as String,
        templateNumber: json['template_number'] as int,
        name: json['name'] as String,
        formula: json['formula'] as String,
        foodForm: json['food_form'] as String,
        activityTypes: Value(_arrayToJsonString(json['activity_types'])),
        durationBrackets: Value(_arrayToJsonString(json['duration_brackets'])),
        gutTrainingLevels:
            Value(_arrayToJsonString(json['gut_training_levels'])),
        componentFoodNames:
            Value(_arrayToJsonString(json['component_food_names'])),
        componentCarbRatios: Value(_jsonbToString(json['component_carb_ratios'])),
        primaryToSecondaryRatio:
            Value(json['primary_to_secondary_ratio'] as String?),
        allergens: Value(_arrayToJsonString(json['allergens'])),
        excludedDiets: Value(_arrayToJsonString(json['excluded_diets'])),
        notes: Value(json['notes'] as String?),
        selectionPriority:
            Value((json['selection_priority'] as num?)?.toInt() ?? 0),
        isActive: Value(json['is_active'] as bool? ?? true),
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
        batch.insert(_database.duringWorkoutTemplatesTable, entry);
      }
    });
  }

  /// Convert PostgreSQL array or Dart list to JSON string for SQLite storage.
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

  /// Convert JSONB value (Map / List / String / null) to JSON string.
  /// Returns null when the column is null so the nullable Drift column stays
  /// distinguishable from an explicit empty object.
  String? _jsonbToString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return jsonEncode(value);
  }
}

/// Riverpod provider for [DuringWorkoutTemplatesRepository].
final duringWorkoutTemplatesRepositoryProvider =
    Provider<DuringWorkoutTemplatesRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final logger = ref.watch(appLoggerProvider);
  final supabase = ref.watch(appExternalDepsProvider).supabaseClient;
  return DuringWorkoutTemplatesRepository(supabase, database, logger: logger);
});
