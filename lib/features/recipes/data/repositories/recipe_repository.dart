import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/data/syncable_repository.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/database/database_provider.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/logging_service.dart';
import '../../domain/recipe.dart';

/// Repository for the curated recipe catalog.
///
/// Implements a read-only mirror pattern identical to [PreWorkoutTemplatesRepository]:
/// - Supabase `recipes` table is the source of truth (service-role writes only).
/// - Drift [RecipesTable] is the local offline cache.
/// - Staleness threshold: 24 hours (recipes change infrequently compared to
///   athlete data, so a longer window is fine).
/// - Hydration is on-demand when the Recipes screen opens via [ensureSynced],
///   NOT part of app-startup sync-all.
/// - Favorites are stored in memory for this MVP; `isFavorite` is always false
///   on [Recipe] objects coming from the cache — the UI can layer its own
///   favourite state on top if needed later.
class RecipeRepository with SyncableRepository {
  RecipeRepository(this._supabase, this._database, {AppLogger? logger})
    : _logger = logger ?? const NoopAppLogger();

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;

  // ========================================================================
  // SyncableRepository Implementation
  // ========================================================================

  @override
  String get repositoryKey => 'recipes';

  @override
  List<String> get dependencies => [];

  /// Override: stale when cache is empty OR last sync is > 24 h ago.
  ///
  /// Recipes change rarely (service-role seeded content), so we use a 24 h
  /// threshold rather than the mixin's default 1 h.
  @override
  Future<bool> isStale() async {
    final localRows = await (_database.select(
      _database.recipesTable,
    )..where((t) => t.isActive.equals(true))).get();
    if (localRows.isEmpty) {
      _logger.debug(
        'Forcing sync — no local recipes found',
        context: 'RECIPE_REPO',
      );
      return true;
    }
    // Legacy-cache detection: rows whose type isn't a current wire value
    // predate the category recategorization (preRun/duringRun/postRun/
    // general → breakfast/mains/snacks/workout_fuel/recovery). Treat the
    // whole cache as stale so the reseeded catalog is picked up immediately
    // instead of after the 24 h window.
    final knownTypes = RecipeType.values.map((t) => t.wireValue).toSet();
    if (localRows.any((row) => !knownTypes.contains(row.type))) {
      _logger.debug(
        'Forcing sync — cached recipes use legacy category values',
        context: 'RECIPE_REPO',
      );
      return true;
    }
    // Custom 24-hour staleness check (override mixin's 1-hour default).
    final lastSync = await getLastSyncTime();
    if (lastSync == null) return true;
    return DateTime.now().difference(lastSync) > const Duration(hours: 24);
  }

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    try {
      _logger.info('Syncing recipes from Supabase', context: 'RECIPE_REPO');

      final response = await _supabase
          .from('recipes')
          .select('*')
          .eq('is_active', true)
          .order('name', ascending: true);

      await _syncToLocalDatabase(response as List<dynamic>);
      await setLastSyncTime(DateTime.now());

      _logger.info(
        'Recipes synced successfully',
        context: 'RECIPE_REPO',
        data: {'count': response.length},
      );

      return SyncResult.successful(response.length);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync recipes from remote',
        context: 'RECIPE_REPO',
        error: e,
        stackTrace: stackTrace,
      );
      return SyncResult.failed(e.toString());
    }
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    // Recipes are read-only reference data — nothing to upload.
    return UploadResult.nothingToUpload();
  }

  // ========================================================================
  // On-Demand Hydration
  // ========================================================================

  /// Ensure the local cache is populated before the caller reads from it.
  ///
  /// Call this when the Recipes screen opens.  It checks staleness and, if
  /// needed, fetches from Supabase.  A [userId] is required to satisfy the
  /// [SyncableRepository] interface (Supabase RLS is `authenticated SELECT`
  /// so the auth session must be active, but the query itself is not
  /// user-scoped).
  ///
  /// [force] bypasses the staleness window — used by pull-to-refresh so a
  /// server-side catalog change (reseed, recategorization) is visible
  /// immediately instead of after the 24h window lapses.
  Future<void> ensureSynced(String userId, {bool force = false}) async {
    if (force || await isStale()) {
      await syncFromRemote(userId);
    }
  }

  // ========================================================================
  // Query Methods
  // ========================================================================

  Future<List<Recipe>> getAllRecipes() async {
    final entries =
        await (_database.select(_database.recipesTable)
              ..where((t) => t.isActive.equals(true))
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .get();
    return entries.map(_entryToRecipe).toList();
  }

  Future<List<Recipe>> getRecipesByType(RecipeType type) async {
    final entries =
        await (_database.select(_database.recipesTable)
              ..where(
                (t) => t.isActive.equals(true) & t.type.equals(type.wireValue),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .get();
    return entries.map(_entryToRecipe).toList();
  }

  Future<Recipe?> getRecipeById(String id) async {
    final entry = await (_database.select(
      _database.recipesTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return entry != null ? _entryToRecipe(entry) : null;
  }

  /// MVP: favorites are not persisted — always returns an empty list.
  ///
  /// The `isFavorite` field on [Recipe] is always false in the current
  /// implementation.  A follow-up ticket should add a local `recipe_favorites`
  /// table (or reuse `saved_meals`) to persist this.
  Future<List<Recipe>> getFavoriteRecipes() async {
    return [];
  }

  /// No-op in MVP — see [getFavoriteRecipes].
  Future<void> toggleFavorite(String recipeId) async {
    // TODO: persist favorites locally (follow-up ticket)
  }

  Future<List<Recipe>> searchRecipes(String query) async {
    final all = await getAllRecipes();
    if (query.isEmpty) return all;
    final lowerQuery = query.toLowerCase();
    return all.where((recipe) {
      return recipe.name.toLowerCase().contains(lowerQuery) ||
          recipe.description.toLowerCase().contains(lowerQuery) ||
          recipe.ingredients.any((i) => i.toLowerCase().contains(lowerQuery)) ||
          (recipe.tags?.any((tag) => tag.toLowerCase().contains(lowerQuery)) ??
              false);
    }).toList();
  }

  // ========================================================================
  // Private helpers
  // ========================================================================

  /// Map a Drift [RecipeEntry] to the domain [Recipe].
  ///
  /// Image URL resolution: the [imageUrl] column stores either a full https://
  /// URL (passed through as-is) or a bare object filename (e.g.
  /// 'overnight-oats.jpg') stored in the public 'recipe-images' Supabase
  /// storage bucket.  In the latter case we resolve it to the public URL via
  /// the Storage SDK so the seed file remains env-portable across dev/prod.
  Recipe _entryToRecipe(RecipeEntry entry) {
    final rawImageUrl = entry.imageUrl;
    final resolvedImageUrl = rawImageUrl == null
        ? null
        : (rawImageUrl.startsWith('http')
              ? rawImageUrl
              : _supabase.storage
                    .from('recipe-images')
                    .getPublicUrl(rawImageUrl));

    return Recipe(
      id: entry.id,
      name: entry.name,
      description: entry.description,
      ingredients: _decodeJsonStringList(entry.ingredients),
      instructions: _decodeJsonStringList(entry.instructions),
      prepTimeMinutes: entry.prepTimeMinutes,
      servings: entry.servings,
      type: RecipeType.fromWire(entry.type),
      nutrition: RecipeNutrition(
        calories: entry.calories,
        carbohydratesGrams: entry.carbsG,
        proteinGrams: entry.proteinG,
        fatGrams: entry.fatG,
        fiberGrams: entry.fiberG,
        sugarGrams: entry.sugarG,
        sodiumMilligrams: entry.sodiumMg,
      ),
      imageUrl: resolvedImageUrl,
      tags: entry.tags != null ? _decodeJsonStringList(entry.tags!) : null,
      // isFavorite is always false in MVP; see getFavoriteRecipes().
      isFavorite: false,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }

  /// Decode a JSON-encoded string array stored in Drift TEXT columns.
  List<String> _decodeJsonStringList(String jsonText) {
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is List) {
        return decoded.cast<String>();
      }
    } catch (_) {
      // Fall through to empty list on malformed data.
    }
    return [];
  }

  /// Upsert a full Supabase response into the local Drift cache.
  ///
  /// Uses a delete-and-reinsert approach (same as template repositories) since
  /// recipes are read-only reference data and the full set is small.
  Future<void> _syncToLocalDatabase(List<dynamic> supabaseData) async {
    await _database.delete(_database.recipesTable).go();

    final entries = supabaseData.map((raw) {
      final json = raw as Map<String, dynamic>;
      return RecipesTableCompanion.insert(
        id: json['id'] as String,
        name: json['name'] as String,
        description: Value(json['description'] as String? ?? ''),
        ingredients: Value(_jsonbToString(json['ingredients'])),
        instructions: Value(_jsonbToString(json['instructions'])),
        prepTimeMinutes: Value(
          (json['prep_time_minutes'] as num?)?.toInt() ?? 0,
        ),
        servings: Value((json['servings'] as num?)?.toInt() ?? 1),
        type: Value(json['type'] as String? ?? 'mains'),
        calories: Value((json['calories'] as num?)?.toDouble() ?? 0),
        carbsG: Value((json['carbs_g'] as num?)?.toDouble() ?? 0),
        proteinG: Value((json['protein_g'] as num?)?.toDouble() ?? 0),
        fatG: Value((json['fat_g'] as num?)?.toDouble() ?? 0),
        fiberG: Value((json['fiber_g'] as num?)?.toDouble() ?? 0),
        sugarG: Value((json['sugar_g'] as num?)?.toDouble() ?? 0),
        sodiumMg: Value((json['sodium_mg'] as num?)?.toDouble() ?? 0),
        imageUrl: Value(json['image_url'] as String?),
        tags: Value(json['tags'] != null ? _jsonbToString(json['tags']) : null),
        isActive: Value(json['is_active'] as bool? ?? true),
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        updatedAt:
            DateTime.tryParse(json['updated_at'] as String? ?? '') ??
            DateTime.now(),
      );
    }).toList();

    await _database.batch((batch) {
      for (final entry in entries) {
        batch.insert(_database.recipesTable, entry);
      }
    });
  }

  /// Convert a Supabase JSONB value (already decoded to `List` or `Map`) back
  /// to a JSON string for storage in a Drift TEXT column.
  String _jsonbToString(dynamic value) {
    if (value == null) return '[]';
    if (value is String) return value;
    return jsonEncode(value);
  }
}

// ============================================================================
// Riverpod Provider
// ============================================================================

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final logger = ref.watch(appLoggerProvider);
  final supabase = ref.watch(appExternalDepsProvider).supabaseClient;
  return RecipeRepository(supabase, database, logger: logger);
});
