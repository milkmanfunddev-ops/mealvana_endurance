import 'dart:async';

import 'package:uuid/uuid.dart';

import '../data/meal_log_repository.dart';
import '../data/saved_meals_repository.dart';
import '../domain/consumed_totals.dart';
import '../domain/meal_component.dart';
import '../domain/meal_log.dart';
import '../domain/meal_log_source.dart';
import '../domain/meal_slot.dart';
import '../domain/saved_meal.dart';

/// Lightweight parameter object used by [MealLoggingService.logRecipe] so the
/// service does not depend on the [recipes] feature's domain model.
///
/// The caller passes only the fields needed to create a log entry; the service
/// handles scaling and totals computation.
class RecipeLogParams {
  const RecipeLogParams({
    required this.recipeId,
    required this.recipeName,
    required this.servings,
    required this.caloriesPerServing,
    required this.carbsGPerServing,
    required this.proteinGPerServing,
    required this.fatGPerServing,
    this.sodiumMgPerServing,
  });

  final String recipeId;
  final String recipeName;

  /// How many servings the user is logging (may be fractional).
  final double servings;

  // Per-serving nutrition (from RecipesTable / Supabase `recipes` row).
  final double caloriesPerServing;
  final double carbsGPerServing;
  final double proteinGPerServing;
  final double fatGPerServing;
  final double? sodiumMgPerServing;
}

/// Application-layer business logic for meal logging.
///
/// **Responsibilities.**
/// - Constructs [MealLog] objects with correct timestamps, totals, and
///   provenance fields.
/// - Delegates all persistence to [MealLogRepository] and
///   [SavedMealsRepository] (offline-first).
/// - Does **not** know about Riverpod; the controller wires up dependencies.
///
/// **No UI concerns** — this class must not import Flutter or contain
/// user-facing strings.
class MealLoggingService {
  MealLoggingService({
    required MealLogRepository mealLogRepository,
    required SavedMealsRepository savedMealsRepository,
  })  : _mealLogRepo = mealLogRepository,
        _savedMealsRepo = savedMealsRepository;

  final MealLogRepository _mealLogRepo;
  final SavedMealsRepository _savedMealsRepo;

  static const _uuid = Uuid();

  // ========================================================================
  // Logging Methods
  // ========================================================================

  /// Log a meal via the manual-entry flow (name + optional total macros, no
  /// component detail).
  ///
  /// Use [logFromComponents] when individual food components are available.
  Future<MealLog> logManualMeal({
    required String userId,
    required String name,
    required MealSlot slot,
    required String logDate,
    int? calories,
    double? carbsG,
    double? proteinG,
    double? fatG,
    double? sodiumMg,
    String? notes,
    DateTime? eatenAt,
  }) {
    final now = DateTime.now();
    final log = MealLog(
      id: _uuid.v4(),
      userId: userId,
      logDate: logDate,
      slot: slot,
      name: name,
      source: MealLogSource.manual,
      components: const [],
      calories: calories,
      carbsG: carbsG,
      proteinG: proteinG,
      fatG: fatG,
      sodiumMg: sodiumMg,
      notes: notes,
      eatenAt: eatenAt,
      createdAt: now,
      updatedAt: now,
    );
    return _mealLogRepo.insertLog(log);
  }

  /// Log a meal built from individual food components (used by the photo,
  /// describe-to-AI, and detailed-manual flows).
  ///
  /// Totals are computed by summing [components] so the caller does not need to
  /// aggregate them manually.
  Future<MealLog> logFromComponents({
    required String userId,
    required String name,
    required MealSlot slot,
    required String logDate,
    required MealLogSource source,
    required List<MealComponent> components,
    String? photoPath,
    String? notes,
    DateTime? eatenAt,
    String? savedMealId,
    String? recipeId,
  }) {
    final totals = _sumComponents(components);
    final now = DateTime.now();
    final log = MealLog(
      id: _uuid.v4(),
      userId: userId,
      logDate: logDate,
      slot: slot,
      name: name,
      source: source,
      components: components,
      calories: totals.calories,
      carbsG: totals.carbsG,
      proteinG: totals.proteinG,
      fatG: totals.fatG,
      sodiumMg: totals.sodiumMg,
      photoPath: photoPath,
      recipeId: recipeId,
      savedMealId: savedMealId,
      notes: notes,
      eatenAt: eatenAt,
      createdAt: now,
      updatedAt: now,
    );
    return _mealLogRepo.insertLog(log);
  }

  /// Log a meal from the user's saved favorites.
  ///
  /// Copies the component data from [savedMeal], sets [savedMealId] for
  /// provenance, and bumps [SavedMeal.lastUsedAt] so the favorites list stays
  /// sorted by recency.
  Future<MealLog> logSavedMeal({
    required SavedMeal savedMeal,
    required String userId,
    required MealSlot slot,
    required String logDate,
    DateTime? eatenAt,
  }) async {
    final log = await logFromComponents(
      userId: userId,
      name: savedMeal.name,
      slot: slot,
      logDate: logDate,
      source: MealLogSource.saved,
      components: savedMeal.components,
      photoPath: savedMeal.photoPath,
      savedMealId: savedMeal.id,
      eatenAt: eatenAt,
    );

    // Non-blocking — failure just means the sort order is slightly off.
    unawaited(_savedMealsRepo.touchLastUsed(savedMeal.id));

    return log;
  }

  /// Log a meal from the recipe catalog, scaling macros by [params.servings].
  ///
  /// Builds a single [MealComponent] representing the whole recipe (rather than
  /// individual ingredients) so the log entry is concise. Sets [recipeId] for
  /// provenance so the source recipe can be re-visited from the log.
  Future<MealLog> logRecipe({
    required RecipeLogParams params,
    required String userId,
    required MealSlot slot,
    required String logDate,
    DateTime? eatenAt,
    String? notes,
  }) {
    final s = params.servings;
    final component = MealComponent(
      name: params.recipeName,
      portion: '${_formatServings(s)} ${s == 1 ? 'serving' : 'servings'}',
      calories: (params.caloriesPerServing * s).round(),
      carbG: params.carbsGPerServing * s,
      proteinG: params.proteinGPerServing * s,
      fatG: params.fatGPerServing * s,
      sodiumMg: params.sodiumMgPerServing != null
          ? params.sodiumMgPerServing! * s
          : null,
    );

    return logFromComponents(
      userId: userId,
      name: params.recipeName,
      slot: slot,
      logDate: logDate,
      source: MealLogSource.recipe,
      components: [component],
      recipeId: params.recipeId,
      notes: notes,
      eatenAt: eatenAt,
    );
  }

  /// Update an existing meal log entry in place.
  ///
  /// For component-based logs, totals are recomputed from [log.components].
  /// For manual logs (empty component list), the caller's macro values on
  /// [log] are used directly.
  Future<MealLog> updateLog(MealLog log) {
    if (log.components.isNotEmpty) {
      final totals = _sumComponents(log.components);
      final updated = log.copyWith(
        calories: totals.calories,
        carbsG: totals.carbsG,
        proteinG: totals.proteinG,
        fatG: totals.fatG,
        sodiumMg: totals.sodiumMg,
      );
      return _mealLogRepo.updateLog(updated);
    }
    return _mealLogRepo.updateLog(log);
  }

  /// Save a meal log entry as an explicit user favorite.
  ///
  /// [customName] overrides the log's display name (useful when the user wants
  /// a friendlier label for their saved meal). If omitted, the log's [name] is
  /// used.
  Future<SavedMeal> saveLogAsFavorite(
    MealLog log, {
    String? customName,
  }) {
    final now = DateTime.now();
    final meal = SavedMeal(
      id: _uuid.v4(),
      userId: log.userId,
      name: customName ?? log.name,
      components: log.components,
      calories: log.calories,
      carbsG: log.carbsG,
      proteinG: log.proteinG,
      fatG: log.fatG,
      sodiumMg: log.sodiumMg,
      photoPath: log.photoPath,
      lastUsedAt: now,
      createdAt: now,
      updatedAt: now,
    );
    return _savedMealsRepo.saveMeal(meal);
  }

  // ========================================================================
  // Consumed Totals
  // ========================================================================

  /// Compute [ConsumedTotals] for a calendar day from a list of log entries.
  ///
  /// Sums the denormalised calorie/macro columns (the fast path). Components
  /// are not re-parsed here — the DB columns are always kept in sync with the
  /// component list by [insertLog]/[updateLog].
  ///
  /// Call this with the result of [MealLogRepository.watchLogsForDate] via a
  /// derived provider.
  ConsumedTotals consumedTotalsForLogs(List<MealLog> logs) {
    return logs.fold(const ConsumedTotals(), (acc, log) {
      return ConsumedTotals(
        calories: acc.calories + (log.calories ?? 0),
        carbsG: acc.carbsG + (log.carbsG ?? 0),
        proteinG: acc.proteinG + (log.proteinG ?? 0),
        fatG: acc.fatG + (log.fatG ?? 0),
        sodiumMg: acc.sodiumMg + (log.sodiumMg ?? 0),
      );
    });
  }

  // ========================================================================
  // Private Helpers
  // ========================================================================

  ConsumedTotals _sumComponents(List<MealComponent> components) {
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

  /// Format a servings multiplier for the portion string.
  String _formatServings(double servings) {
    if (servings == servings.truncateToDouble()) {
      return servings.truncate().toString();
    }
    return servings.toStringAsFixed(1);
  }
}

