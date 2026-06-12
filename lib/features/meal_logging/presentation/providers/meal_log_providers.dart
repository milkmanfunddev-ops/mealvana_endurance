import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../features/auth/data/user_repository.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../../shared/services/supabase/supabase_client_provider.dart';
import '../../application/meal_logging_service.dart';
import '../../data/meal_log_repository.dart';
import '../../data/saved_meals_repository.dart';
import '../../domain/consumed_totals.dart';
import '../../domain/meal_component.dart';
import '../../domain/meal_log.dart';
import '../../domain/meal_log_source.dart';
import '../../domain/meal_slot.dart';
import '../../domain/saved_meal.dart';

part 'meal_log_providers.g.dart';

// ============================================================================
// Service provider
// ============================================================================

/// Application-layer service wired with both repositories.
@riverpod
MealLoggingService mealLoggingService(Ref ref) {
  return MealLoggingService(
    mealLogRepository: ref.read(mealLogRepositoryProvider),
    savedMealsRepository: ref.read(savedMealsRepositoryProvider),
  );
}

// ============================================================================
// Stream providers — meal logs for a specific date
// ============================================================================

/// Streams [MealLog] entries for [date] (formatted as `'yyyy-MM-dd'`) for the
/// current user.
///
/// Automatically re-emits whenever the underlying Drift table changes, so the
/// Daily Macros tab always reflects the latest local state (including entries
/// written while offline).
///
/// Returns an empty list when there is no authenticated user (no throws —
/// callers handle the empty-state UI).
@riverpod
Stream<List<MealLog>> mealLogsForDate(Ref ref, String date) async* {
  final userRepo = await ref.read(userRepositoryProvider.future);
  final user = await userRepo.getCurrentUser();
  final userId = user?.id;
  if (userId == null) {
    yield const [];
    return;
  }

  final repo = ref.read(mealLogRepositoryProvider);
  yield* repo.watchLogsForDate(userId, date);
}

/// Derived provider: [ConsumedTotals] for [date], recomputed whenever the
/// underlying [mealLogsForDateProvider] stream emits.
///
/// This is the single value the Daily Macros progress bars should watch.
/// Derives directly from the same repository stream so it shares the same
/// Drift subscription lifecycle.
@riverpod
Stream<ConsumedTotals> consumedTotalsForDate(Ref ref, String date) async* {
  final userRepo = await ref.read(userRepositoryProvider.future);
  final user = await userRepo.getCurrentUser();
  final userId = user?.id;
  if (userId == null) {
    yield const ConsumedTotals();
    return;
  }

  final repo = ref.read(mealLogRepositoryProvider);
  final service = ref.read(mealLoggingServiceProvider);

  await for (final logs in repo.watchLogsForDate(userId, date)) {
    yield service.consumedTotalsForLogs(logs);
  }
}

// ============================================================================
// Stream providers — recent meals
// ============================================================================

/// Most recent 25 distinct meal names for the current user.
///
/// Used by the "Recent" section of the meal picker. Rebuilds on invalidation
/// (not a stream — recents don't need real-time updates within a session).
@riverpod
Future<List<MealLog>> recentMeals(Ref ref) async {
  final userRepo = await ref.read(userRepositoryProvider.future);
  final user = await userRepo.getCurrentUser();
  final userId = user?.id;
  if (userId == null) return const [];

  return ref.read(mealLogRepositoryProvider).getRecentLogs(userId);
}

// ============================================================================
// Stream providers — saved meals
// ============================================================================

/// Streams all non-deleted saved meals for the current user, ordered by
/// [SavedMeal.lastUsedAt] descending.
///
/// Used by the "My Meals" section of the meal picker.
@riverpod
Stream<List<SavedMeal>> savedMeals(Ref ref) async* {
  final userRepo = await ref.read(userRepositoryProvider.future);
  final user = await userRepo.getCurrentUser();
  final userId = user?.id;
  if (userId == null) {
    yield const [];
    return;
  }

  final repo = ref.read(savedMealsRepositoryProvider);
  yield* repo.watchSavedMeals(userId);
}

// ============================================================================
// Mutation controller
// ============================================================================

/// Controller for meal log mutations.
///
/// State is `AsyncValue<void>` — callers check [state] for loading/error
/// feedback after calling any action method. On success the relevant stream
/// providers update automatically (Drift stream re-emits).
///
/// Uses [AsyncValue.guard] so errors surface as [AsyncError] rather than
/// uncaught exceptions.
@riverpod
class MealLogController extends _$MealLogController {
  @override
  FutureOr<void> build() {
    // No async initialization needed — repositories are fully offline-capable
    // and stream providers handle their own sync gates.
    return null;
  }

  MealLoggingService get _service => ref.read(mealLoggingServiceProvider);

  AppLogger get _logger => ref.read(appLoggerProvider);

  Future<String?> _currentUserId() async {
    final userRepo = await ref.read(userRepositoryProvider.future);
    final user = await userRepo.getCurrentUser();
    return user?.id;
  }

  // --------------------------------------------------------------------------
  // Log actions
  // --------------------------------------------------------------------------

  /// Log a manual meal entry and invalidate the date's stream provider.
  Future<void> logManualMeal({
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
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userId = await _currentUserId();
      if (userId == null) throw StateError('No authenticated user');

      await _service.logManualMeal(
        userId: userId,
        name: name,
        slot: slot,
        logDate: logDate,
        calories: calories,
        carbsG: carbsG,
        proteinG: proteinG,
        fatG: fatG,
        sodiumMg: sodiumMg,
        notes: notes,
        eatenAt: eatenAt,
      );

      await _trackEvent('meal_logged', {
        'slot': slot.wireValue,
        'source': 'manual',
        'log_date': logDate,
      });
    });
  }

  /// Log a meal from the user's saved favorites.
  Future<void> logSavedMeal({
    required SavedMeal savedMeal,
    required MealSlot slot,
    required String logDate,
    DateTime? eatenAt,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userId = await _currentUserId();
      if (userId == null) throw StateError('No authenticated user');

      await _service.logSavedMeal(
        savedMeal: savedMeal,
        userId: userId,
        slot: slot,
        logDate: logDate,
        eatenAt: eatenAt,
      );
      ref.invalidate(recentMealsProvider);

      await _trackEvent('meal_logged', {
        'slot': slot.wireValue,
        'source': 'saved',
        'log_date': logDate,
      });
    });
  }

  /// Log a recipe, scaling macros by [servings].
  Future<void> logRecipe({
    required RecipeLogParams params,
    required MealSlot slot,
    required String logDate,
    DateTime? eatenAt,
    String? notes,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userId = await _currentUserId();
      if (userId == null) throw StateError('No authenticated user');

      await _service.logRecipe(
        params: params,
        userId: userId,
        slot: slot,
        logDate: logDate,
        eatenAt: eatenAt,
        notes: notes,
      );

      await _trackEvent('meal_logged', {
        'slot': slot.wireValue,
        'source': 'recipe',
        'log_date': logDate,
        'recipe_id': params.recipeId,
      });
    });
  }

  /// Log a meal built from individual food components (used by photo, describe,
  /// and AI-review flows).
  Future<void> logFromComponents({
    required String name,
    required MealSlot slot,
    required String logDate,
    required MealLogSource source,
    required List<MealComponent> components,
    String? photoPath,
    String? notes,
    DateTime? eatenAt,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userId = await _currentUserId();
      if (userId == null) throw StateError('No authenticated user');
      await _service.logFromComponents(
        userId: userId,
        name: name,
        slot: slot,
        logDate: logDate,
        source: source,
        components: components,
        photoPath: photoPath,
        notes: notes,
        eatenAt: eatenAt,
      );
      ref.invalidate(recentMealsProvider);
      await _trackEvent('meal_logged', {
        'slot': slot.wireValue,
        'source': source.wireValue,
        'log_date': logDate,
      });
    });
  }

  /// Update an existing meal log entry.
  ///
  /// Passes the full updated [MealLog] to the service which recomputes totals
  /// when components are present, then writes via the repository.
  Future<void> updateLog(MealLog log) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _service.updateLog(log);

      _logger.info(
        'Meal log updated',
        context: 'MEAL_LOG_CONTROLLER',
        data: {'logId': log.id},
      );

      await _trackEvent('meal_log_updated', {
        'log_id': log.id,
        'slot': log.slot.wireValue,
      });
    });
  }

  /// Restore a previously soft-deleted meal log entry (used by undo-delete).
  Future<void> restoreLog(String logId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userId = await _currentUserId();
      if (userId == null) throw StateError('No authenticated user');

      await ref
          .read(mealLogRepositoryProvider)
          .restoreLog(id: logId, userId: userId);

      _logger.info(
        'Meal log restored',
        context: 'MEAL_LOG_CONTROLLER',
        data: {'logId': logId},
      );

      await _trackEvent('meal_log_restored', {'log_id': logId});
    });
  }

  /// Soft-delete a meal log entry.
  Future<void> deleteLog(String logId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userId = await _currentUserId();
      if (userId == null) throw StateError('No authenticated user');

      await ref
          .read(mealLogRepositoryProvider)
          .softDeleteLog(id: logId, userId: userId);

      _logger.info(
        'Meal log deleted',
        context: 'MEAL_LOG_CONTROLLER',
        data: {'logId': logId},
      );

      await _trackEvent('meal_log_deleted', {'log_id': logId});
    });
  }

  // --------------------------------------------------------------------------
  // Saved meals actions
  // --------------------------------------------------------------------------

  /// Save a log entry as a user favorite.
  Future<void> saveLogAsFavorite(MealLog log, {String? customName}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _service.saveLogAsFavorite(log, customName: customName);
      ref.invalidate(savedMealsProvider);

      await _trackEvent('meal_saved_as_favorite', {
        'log_id': log.id,
        'custom_name': customName != null,
      });
    });
  }

  /// Soft-delete a saved meal.
  Future<void> deleteSavedMeal(String mealId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(savedMealsRepositoryProvider).softDelete(mealId);
      ref.invalidate(savedMealsProvider);

      await _trackEvent('saved_meal_deleted', {'meal_id': mealId});
    });
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------

  Future<void> _trackEvent(
    String event,
    Map<String, dynamic> properties,
  ) async {
    final analytics = ref.read(appExternalDepsProvider).analytics;
    await analytics.track(event, properties: properties);
  }
}

// ============================================================================
// Photo signed URL provider
// ============================================================================

/// Generates a 1-hour signed URL for a meal photo stored in the `meal-photos`
/// bucket. Returns `null` when [photoPath] is null/empty or on any error.
@riverpod
Future<String?> mealPhotoSignedUrl(Ref ref, String? photoPath) async {
  if (photoPath == null || photoPath.isEmpty) return null;
  try {
    final supabase = ref.read(supabaseClientProvider);
    final url = await supabase.storage
        .from('meal-photos')
        .createSignedUrl(photoPath, 3600);
    return url;
  } catch (_) {
    return null;
  }
}
