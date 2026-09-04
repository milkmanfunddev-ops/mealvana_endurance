import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/database/app_database.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../auth/application/auth_service.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../food_preferences/data/food_preferences_repository.dart';
import '../../data/template_foods_repository.dart';
import '../../domain/solver_food.dart';
import '../../domain/solver_types.dart';

/// Assembles and filters the food pool for a given nutrition phase.
///
/// Loads template foods from Drift (with Supabase fallback), food preferences,
/// and the user profile to produce a scored list of [SolverFood] items suitable
/// for the greedy solver.
///
/// FOOD-SOURCE POLICY (2026-07-29): the pool is the curated `template_foods`
/// catalog ONLY. `user_foods` — user-created, barcode-scanned and branded
/// grocery items — are NOT loaded here, and must not be reintroduced. This
/// mirrors the server (`_shared/nutrition/template-food-queries.ts`). The one
/// legitimate user-originating source is a pinned personal formula, which is
/// self-contained: its components carry their own macros and never touch this
/// pool (see `ClientPlanService._tryPinnedPersonalFormula`). The pin backfill
/// does read this pool, but only for `isEssential` water/salt.
///
/// Rows without a classified `product_type` (null or `'import'`) are also
/// excluded, matching the server gate — a curated row that arrives unclassified
/// or flagged as an import never reaches a generated plan.
class ClientFoodPoolService {
  ClientFoodPoolService(this._ref);
  final Ref _ref;

  TemplateFoodsRepository get _templateFoodsRepo =>
      _ref.read(templateFoodsRepositoryProvider);
  AppLogger get _logger => _ref.read(appExternalDepsProvider).logger;

  /// Build a scored and filtered food pool for a specific phase.
  ///
  /// [phase] is one of: 'before', 'during', 'after'.
  Future<List<SolverFood>> getFoodsForPhase({
    required String phase,
    required String userId,
    required ActivityType activityType,
  }) async {
    // 1. Load preferences
    final prefsRepo = await _ref.read(foodPreferencesRepositoryProvider.future);
    final preferences = await prefsRepo.getFoodPreferences(userId);
    final likedSet = <String>{};
    final dislikedSet = <String>{};
    final willingSet = <String>{};
    for (final entry in preferences.entries) {
      switch (entry.value) {
        case FoodPreference.like:
          likedSet.add(entry.key);
        case FoodPreference.dislike:
          dislikedSet.add(entry.key);
        case FoodPreference.willingToTry:
          willingSet.add(entry.key);
      }
    }

    // 2. Load user profile for allergies + dietary preference
    final user = await _ref.read(authServiceProvider).getCurrentUser();
    final allergyDbValues =
        user?.allergies.map((a) => a.dbValue).toSet() ?? <String>{};
    final dietaryPref = user?.dietaryPreference;

    // 3. Load template foods (Drift first, Supabase fallback)
    var templateFoods = await _templateFoodsRepo.getAllTemplateFoods();
    if (templateFoods.isEmpty) {
      _logger.info(
        'No local template foods, fetching from Supabase',
        context: 'CLIENT_FOOD_POOL',
      );
      templateFoods = await _fetchTemplateFoodsFromSupabase();
    }

    // 4. Phase category names for filtering
    final phaseCategories = _phaseCategoryNames(phase);
    final sportName = activityType.dbValue;

    // 5. Build solver food list — curated template foods only.
    final result = <SolverFood>[];

    for (final tf in templateFoods) {
      if (tf.toExcludeFromSolver) continue;

      // Branded / unclassified gate (skip for essentials so water/salt are
      // never lost to a data-entry gap). Mirrors the server's
      // `isClassifiedProductType` in template-food-queries.ts and the SQL gate
      // in before-phase-substitution.ts.
      if (!tf.isEssential && !isClassifiedProductType(tf.productType)) continue;

      // Category filter
      final categories = _parseJsonList(tf.categories);
      if (!categories.any((c) => phaseCategories.contains(c))) continue;

      // Activity type filter
      final activityTypes = _parseJsonList(tf.activityTypes);
      if (activityTypes.isNotEmpty && !activityTypes.contains(sportName)) {
        continue;
      }

      // Allergen filter (skip for essentials)
      if (!tf.isEssential && allergyDbValues.isNotEmpty) {
        final foodAllergens = _parseJsonList(tf.allergens);
        if (foodAllergens.any((a) => allergyDbValues.contains(a))) continue;
      }

      // Dietary preference filter (skip for essentials)
      if (!tf.isEssential && dietaryPref != null) {
        final excludedDiets = _parseJsonList(tf.excludedDiets);
        if (excludedDiets.contains(dietaryPref.dbValue)) continue;
      }

      // Disliked filter (skip for essentials)
      if (!tf.isEssential && dislikedSet.contains(tf.name)) continue;

      // Score
      final score = _scoreFood(tf.name, tf.isEssential, likedSet, willingSet);

      result.add(
        SolverFood.fromTemplateFoodEntry(
          tf,
          phase: phase,
          preferenceScore: score,
        ),
      );
    }

    _logger.info(
      'Food pool for $phase: ${result.length} foods '
      '(${templateFoods.length} curated template foods checked; '
      'user_foods excluded by policy)',
      context: 'CLIENT_FOOD_POOL',
    );

    return result;
  }

  /// True when a food row carries a real, classified product type.
  ///
  /// Null/empty (never classified) or `'import'` (a barcode-scanned or
  /// otherwise imported branded item) is not eligible for plan generation.
  /// Server twin: `isClassifiedProductType` in
  /// `supabase/functions/_shared/nutrition/template-food-queries.ts`.
  @visibleForTesting
  static bool isClassifiedProductType(String? productType) {
    if (productType == null) return false;
    final t = productType.trim().toLowerCase();
    return t.isNotEmpty && t != 'import';
  }

  /// Score a food based on its preference status.
  int _scoreFood(
    String foodName,
    bool isEssential,
    Set<String> likedSet,
    Set<String> willingSet,
  ) {
    if (isEssential) return kPrefScoreEssential;
    if (likedSet.contains(foodName)) return kPrefScoreLiked;
    if (willingSet.contains(foodName)) return kPrefScoreWilling;
    return kPrefScoreNeutral;
  }

  /// Map phase name to the category names used in the DB.
  List<String> _phaseCategoryNames(String phase) {
    switch (phase) {
      case 'before':
        return ['before_run'];
      case 'during':
        return ['during_run_default', 'during_run_all', 'during_run'];
      case 'after':
        return ['after_run', 'post_run', 'recovery'];
      default:
        return [phase];
    }
  }

  /// Fallback: fetch template foods directly from Supabase when Drift is empty.
  Future<List<TemplateFoodEntry>> _fetchTemplateFoodsFromSupabase() async {
    try {
      final supabase = _ref.read(appExternalDepsProvider).supabaseClient;
      final response = await supabase
          .from('template_foods')
          .select('*')
          .eq('is_active', true);

      return (response as List<dynamic>).map((json) {
        return _mapSupabaseToTemplateFoodEntry(json as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      _logger.warning(
        'Failed to fetch template foods from Supabase',
        context: 'CLIENT_FOOD_POOL',
        error: e,
      );
      return [];
    }
  }

  /// Convert a Supabase row into a minimal TemplateFoodEntry for solver use.
  TemplateFoodEntry _mapSupabaseToTemplateFoodEntry(Map<String, dynamic> json) {
    return TemplateFoodEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      displayName: json['display_name'] as String? ?? json['name'] as String,
      servingSize: json['serving_size'] as String? ?? '',
      servingWeightG: (json['serving_weight_g'] as num?)?.toDouble(),
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0,
      proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0,
      fatG: (json['fat_g'] as num?)?.toDouble() ?? 0,
      fiberG: (json['fiber_g'] as num?)?.toDouble(),
      sodiumMg: (json['sodium_mg'] as num?)?.toDouble() ?? 0,
      fluidMl: (json['fluid_ml'] as num?)?.toDouble(),
      allergens: _arrayToJsonString(json['allergens']),
      digestionSpeed: json['digestion_speed'] as String? ?? 'medium',
      isActive: json['is_active'] as bool? ?? true,
      excludedDiets: _arrayToJsonString(json['excluded_diets']),
      productType: json['product_type'] as String? ?? 'real_food',
      activityTypes: _arrayToJsonString(json['activity_types']),
      categories: _arrayToJsonString(json['categories']),
      isElectrolyte: json['is_electrolyte'] as bool? ?? false,
      requiresPreparation: json['requires_preparation'] as bool? ?? false,
      caffeineMg: (json['caffeine_mg'] as num?)?.toDouble(),
      potassiumMg: (json['potassium_mg'] as num?)?.toDouble(),
      isDrinkPool: json['is_drink_pool'] as bool? ?? false,
      drinkPoolPhases: _arrayToJsonString(json['drink_pool_phases']),
      maxServingsBefore: (json['max_servings_before'] as num?)?.toInt() ?? 4,
      maxServingsDuring: (json['max_servings_during'] as num?)?.toInt() ?? 4,
      maxServingsAfter: (json['max_servings_after'] as num?)?.toInt() ?? 4,
      minServingsDuring:
          (json['min_servings_during'] as num?)?.toDouble() ?? 1.0,
      isIndivisible: json['is_indivisible'] as bool? ?? false,
      solventMinMl: (json['solvent_min_ml'] as num?)?.toDouble(),
      toExcludeFromSolver: json['to_exclude_from_solver'] as bool? ?? false,
      isEssential: json['is_essential'] as bool? ?? false,
      showInPreferences: json['show_in_preferences'] as bool? ?? true,
      displayNamePlural: json['display_name_plural'] as String?,
      imageAddress: json['image_address'] as String?,
      description: json['description'] as String?,
      servingAmount: (json['serving_amount'] as num?)?.toDouble(),
      servingUnit: json['serving_unit'] as String?,
      servingQualifier: json['serving_qualifier'] as String?,
      isLiquid: json['is_liquid'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Parse a categories/activityTypes value that may be stored EITHER as a JSON
  /// array (`["before_run","during_run"]`, from Supabase-synced rows) OR as a
  /// PostgreSQL array literal (`{before_run,during_run}`, from locally-created
  /// rows). Handling both is required because user_foods is offline-first and
  /// syncs across clients, so the same field legitimately appears in both forms.
  @visibleForTesting
  List<String> parseCategoryList(String? raw) {
    if (raw == null) return [];
    final s = raw.trim();
    if (s.isEmpty) return [];
    // PostgreSQL array literal: {before_run,during_run}
    if (s.startsWith('{') && s.endsWith('}')) {
      final content = s.substring(1, s.length - 1).trim();
      if (content.isEmpty) return [];
      return content
          .split(',')
          .map((e) => e.trim().replaceAll('"', ''))
          .where((e) => e.isNotEmpty)
          .toList();
    }
    // JSON array: ["before_run","during_run"]
    try {
      final decoded = jsonDecode(s);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {}
    return [];
  }

  List<String> _parseJsonList(String? jsonStr) => parseCategoryList(jsonStr);

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
    }
    return '[]';
  }
}

/// Provider for [ClientFoodPoolService].
final clientFoodPoolServiceProvider = Provider<ClientFoodPoolService>((ref) {
  return ClientFoodPoolService(ref);
});
