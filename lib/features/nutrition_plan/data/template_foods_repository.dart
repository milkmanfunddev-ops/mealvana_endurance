import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/data/syncable_repository.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';

/// Repository for template food ingredients (read-only reference data).
///
/// Template foods are the building blocks for nutrition templates.
/// They are synced from Supabase and cached locally in Drift.
class TemplateFoodsRepository with SyncableRepository {
  TemplateFoodsRepository(this._supabase, this._database, {AppLogger? logger})
      : _logger = logger ?? const NoopAppLogger();

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;

  // ========================================================================
  // SyncableRepository Implementation
  // ========================================================================

  @override
  String get repositoryKey => 'template_foods';

  @override
  List<String> get dependencies => []; // Level 0 - reference data

  @override
  Future<bool> isStale() async {
    // Force sync if local table is empty
    final localCount = await (_database.select(_database.templateFoodsTable)
          ..where((t) => t.isActive.equals(true)))
        .get();
    if (localCount.isEmpty) {
      _logger.debug(
        'Forcing sync - no local template foods found',
        context: 'TEMPLATE_FOODS_REPO',
      );
      return true;
    }
    return await super.isStale();
  }

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    try {
      _logger.info(
        'Syncing template foods from Supabase',
        context: 'TEMPLATE_FOODS_REPO',
      );

      final response = await _supabase
          .from('template_foods')
          .select('*')
          .eq('is_active', true)
          .order('name', ascending: true);

      await _syncToLocalDatabase(response as List<dynamic>);
      await setLastSyncTime(DateTime.now());

      _logger.info(
        'Template foods synced successfully',
        context: 'TEMPLATE_FOODS_REPO',
        data: {'count': response.length},
      );

      return SyncResult.successful(response.length);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync template foods from remote',
        context: 'TEMPLATE_FOODS_REPO',
        error: e,
        stackTrace: stackTrace,
      );
      return SyncResult.failed(e.toString());
    }
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    // Template foods are read-only reference data
    return UploadResult.nothingToUpload();
  }

  // ========================================================================
  // Query Methods
  // ========================================================================

  /// Get all active template foods from local database
  Future<List<TemplateFoodEntry>> getAllTemplateFoods() async {
    return (_database.select(_database.templateFoodsTable)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  /// Get a template food by name
  Future<TemplateFoodEntry?> getTemplateFoodByName(String name) async {
    return (_database.select(_database.templateFoodsTable)
          ..where((t) => t.name.equals(name)))
        .getSingleOrNull();
  }

  /// Get all drink pool items for a given phase
  Future<List<TemplateFoodEntry>> getDrinkPoolForPhase(String phase) async {
    final allDrinks = await (_database.select(_database.templateFoodsTable)
          ..where((t) => t.isDrinkPool.equals(true) & t.isActive.equals(true)))
        .get();

    // Filter by phase (stored as JSON array in drinkPoolPhases)
    return allDrinks.where((drink) {
      try {
        final phases = jsonDecode(drink.drinkPoolPhases) as List<dynamic>;
        return phases.contains(phase);
      } catch (_) {
        return false;
      }
    }).toList();
  }

  // ========================================================================
  // Private Methods
  // ========================================================================

  Future<void> _syncToLocalDatabase(List<dynamic> supabaseData) async {
    // Clear existing and repopulate
    await _database.delete(_database.templateFoodsTable).go();

    final entries = supabaseData.map((json) {
      return TemplateFoodsTableCompanion.insert(
        id: json['id'] as String,
        name: json['name'] as String,
        displayName: json['display_name'] as String,
        servingSize: json['serving_size'] as String,
        servingWeightG: Value((json['serving_weight_g'] as num?)?.toDouble()),
        calories: Value((json['calories'] as num?)?.toInt() ?? 0),
        carbsG: Value((json['carbs_g'] as num?)?.toDouble() ?? 0),
        proteinG: Value((json['protein_g'] as num?)?.toDouble() ?? 0),
        fatG: Value((json['fat_g'] as num?)?.toDouble() ?? 0),
        fiberG: Value((json['fiber_g'] as num?)?.toDouble()),
        sodiumMg: Value((json['sodium_mg'] as num?)?.toDouble() ?? 0),
        fluidMl: Value((json['fluid_ml'] as num?)?.toDouble()),
        allergens: Value(_arrayToJsonString(json['allergens'])),
        digestionSpeed: Value(json['digestion_speed'] as String? ?? 'medium'),
        isActive: Value(json['is_active'] as bool? ?? true),
        excludedDiets: Value(_arrayToJsonString(json['excluded_diets'])),
        productType: Value(json['product_type'] as String? ?? 'real_food'),
        activityTypes: Value(_arrayToJsonString(json['activity_types'])),
        categories: Value(_arrayToJsonString(json['categories'])),
        isElectrolyte: Value(json['is_electrolyte'] as bool? ?? false),
        requiresPreparation: Value(json['requires_preparation'] as bool? ?? false),
        caffeineMg: Value((json['caffeine_mg'] as num?)?.toDouble()),
        potassiumMg: Value((json['potassium_mg'] as num?)?.toDouble()),
        isDrinkPool: Value(json['is_drink_pool'] as bool? ?? false),
        drinkPoolPhases: Value(_arrayToJsonString(json['drink_pool_phases'])),
        createdAt: Value(DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now()),
        updatedAt: Value(DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now()),
      );
    }).toList();

    await _database.batch((batch) {
      for (final entry in entries) {
        batch.insert(_database.templateFoodsTable, entry);
      }
    });
  }

  /// Convert PostgreSQL array or Dart list to JSON string for SQLite storage
  String _arrayToJsonString(dynamic value) {
    if (value == null) return '[]';
    if (value is List) return jsonEncode(value);
    if (value is String) {
      // Handle PostgreSQL array format: {item1,item2}
      if (value.startsWith('{') && value.endsWith('}')) {
        final content = value.substring(1, value.length - 1);
        if (content.isEmpty) return '[]';
        final items = content.split(',').map((s) => s.trim()).toList();
        return jsonEncode(items);
      }
      // Already JSON
      if (value.startsWith('[')) return value;
      return '[]';
    }
    return '[]';
  }
}

/// Riverpod provider for TemplateFoodsRepository
final templateFoodsRepositoryProvider = Provider<TemplateFoodsRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final logger = ref.watch(appLoggerProvider);
  final supabase = ref.watch(appExternalDepsProvider).supabaseClient;
  return TemplateFoodsRepository(supabase, database, logger: logger);
});
