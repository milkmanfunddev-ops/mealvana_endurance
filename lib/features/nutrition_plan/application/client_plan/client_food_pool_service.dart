import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/database/app_database.dart';
import '../../../../shared/database/database_provider.dart';
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
/// Loads template foods from Drift (with Supabase fallback), user foods,
/// food preferences, and user profile to produce a scored list of
/// [SolverFood] items suitable for the greedy solver.
class ClientFoodPoolService {
  ClientFoodPoolService(this._ref);
  final Ref _ref;

  TemplateFoodsRepository get _templateFoodsRepo =>
      _ref.read(templateFoodsRepositoryProvider);
  AppDatabase get _database => _ref.read(appDatabaseProvider);
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

    // 4. Load user foods
    final userFoods = await _database.foodsDao.getUserFoods(userId);

    // 5. Phase category names for filtering
    final phaseCategories = _phaseCategoryNames(phase);
    final sportName = activityType.dbValue;

    // 6. Build solver food list
    final result = <SolverFood>[];

    // Process template foods
    for (final tf in templateFoods) {
      if (tf.toExcludeFromSolver) continue;

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

      result.add(SolverFood.fromTemplateFoodEntry(
        tf,
        phase: phase,
        preferenceScore: score,
      ));
    }

    // Process user foods
    for (final uf in userFoods) {
      if (uf.toExcludeFromSolver) continue;

      // Category filter
      final categories = _parseJsonList(uf.categories);
      if (categories.isNotEmpty &&
          !categories.any((c) => phaseCategories.contains(c))) {
        continue;
      }

      // Activity type filter
      final activityTypes = _parseJsonList(uf.activityTypes);
      if (activityTypes.isNotEmpty && !activityTypes.contains(sportName)) {
        continue;
      }

      // User foods always get the highest preference score
      result.add(SolverFood.fromUserFood(
        uf,
        preferenceScore: kPrefScoreUserFood,
      ));
    }

    _logger.info(
      'Food pool for $phase: ${result.length} foods '
      '(${templateFoods.length} templates checked, ${userFoods.length} user foods checked)',
      context: 'CLIENT_FOOD_POOL',
    );

    return result;
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
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  List<String> _parseJsonList(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) return decoded.cast<String>();
    } catch (_) {}
    return [];
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
    }
    return '[]';
  }
}

/// Provider for [ClientFoodPoolService].
final clientFoodPoolServiceProvider = Provider<ClientFoodPoolService>((ref) {
  return ClientFoodPoolService(ref);
});
