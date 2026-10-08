import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../features/activities/data/activities_repository.dart';
import '../../../../features/activities/domain/activity.dart';
import '../../../../features/auth/data/user_repository.dart';
import '../../../../features/nutrition_plan/domain/fuel_log_data.dart';
import '../../../../shared/data/syncable_repository.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/report/report.dart';
import '../../../../shared/services/supabase/supabase_client_provider.dart';
import '../../../../shared/services/sync/sync_coordinator.dart';
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
// Repository-level sync, where the data is read
// ============================================================================

/// Ask the coordinator for a fresh copy of [repository]'s table (a no-op
/// while the last sync is under an hour old; dedupes with a sync already in
/// flight). Best-effort: a failure is logged and the reader keeps the local
/// table.
///
/// The timeline, Log a Meal's Recent tab and the Daily Macros bars read
/// `meal_logs` and `saved_meals` straight from Drift; before this, nothing on
/// the way to them asked for a sync, so a returning athlete on a new phone
/// saw an empty day until the Food tab (whose plan sync depends on both
/// tables) happened to open (testing-wave 10-001, 26-001).
Future<void> _ensureSynced(
  SyncCoordinator sync,
  Report report,
  SyncableRepository repository,
  String userId,
) async {
  try {
    await sync.ensureSynced(
      repository.repositoryKey,
      userId,
      repository: repository,
    );
  } catch (e, st) {
    // The reader keeps the local table; the failed ask is still worth
    // seeing (D9).
    unawaited(
      report.degraded(
        e,
        stackTrace: st,
        area: 'sync',
        message: '${repository.repositoryKey} ensureSynced failed (non-fatal)',
        extra: {'repository': repository.repositoryKey},
      ),
    );
  }
}

// ============================================================================
// Stream providers — meal logs for a specific date
// ============================================================================

/// Streams [MealLog] entries for [date] (formatted as `'yyyy-MM-dd'`) for the
/// current user.
///
/// Automatically re-emits whenever the underlying Drift table changes, so the
/// Daily Macros tab always reflects the latest local state (including entries
/// written while offline). Kicks a `meal_logs` sync in the background on
/// build (never blocks on the network): the local table answers first and
/// the server's rows re-emit through the same stream when they land.
///
/// Returns an empty list when there is no authenticated user (no throws —
/// callers handle the empty-state UI).
@riverpod
Stream<List<MealLog>> mealLogsForDate(Ref ref, String date) async* {
  // Read before the first await: the day can change (and this family member
  // be disposed) while the user loads (Sentry MEALVANA-ENDURANCE-DEV-8J).
  final repo = ref.read(mealLogRepositoryProvider);
  final sync = ref.read(syncCoordinatorProvider.notifier);
  final report = ref.read(reportProvider);
  final userRepo = await ref.read(userRepositoryProvider.future);
  final user = await userRepo.getCurrentUser();
  final userId = user?.id;
  if (userId == null) {
    yield const [];
    return;
  }

  unawaited(_ensureSynced(sync, report, repo, userId));
  yield* repo.watchLogsForDate(userId, date);
}

/// Streams the day's completed activities (local calendar day of
/// `scheduledDateTime`), so their logged workout fuel can count as "eaten".
///
/// Empty when there is no authenticated user.
@riverpod
Stream<List<Activity>> completedActivitiesForDate(Ref ref, String date) async* {
  final activitiesRepo = ref.read(activitiesRepositoryProvider);
  final userRepo = await ref.read(userRepositoryProvider.future);
  final user = await userRepo.getCurrentUser();
  final userId = user?.id;
  if (userId == null) {
    yield const [];
    return;
  }

  yield* activitiesRepo.watchCompletedActivitiesForDate(
    userId,
    DateTime.parse(date),
  );
}

/// DURING-section consumed totals from a completed activity's fuel log.
///
/// Only the during-workout items count: the before/after sections describe
/// ordinary meals (breakfast, recovery shake) that users also log in the meal
/// log, so counting them here would double-count the day. Uses
/// [FuelLogItem.actualNutritionalInfo] so skipped items (actual quantity 0)
/// contribute nothing.
ConsumedTotals duringFuelTotalsForActivity(
  Activity activity, {
  Report? report,
}) {
  final raw = activity.fuelLogData;
  if (raw == null) return ConsumedTotals.zero;

  final FuelLogData fuelLog;
  try {
    fuelLog = FuelLogData.fromJson(raw);
  } catch (e, st) {
    // A malformed blob must never take down the Daily Macros tab; it is
    // still a data fault worth seeing.
    (report ?? SentryReport.global).degraded(
      e,
      stackTrace: st,
      area: 'meal_logging',
      message: 'activity fuel_log_data did not decode',
      extra: {'activity_id': activity.id},
    );
    return ConsumedTotals.zero;
  }

  var totals = ConsumedTotals.zero;
  for (final item in fuelLog.items) {
    if (!item.sectionId.contains('during')) continue;
    final info = item.actualNutritionalInfo;
    if (info == null) continue;
    totals =
        totals +
        ConsumedTotals(
          calories: info.calories ?? 0,
          carbsG: (info.carbs ?? 0).toDouble(),
          proteinG: (info.protein ?? 0).toDouble(),
          fatG: (info.fat ?? 0).toDouble(),
          sodiumMg: (info.sodium ?? 0).toDouble(),
        );
  }
  return totals;
}

/// Derived provider: [ConsumedTotals] for [date] — meal logs PLUS the
/// during-workout fuel logged on the day's completed activities.
///
/// This is the single value the Daily Macros progress bars (and the fuel
/// timeline's energy balance) should watch. Re-emits whenever either
/// underlying Drift stream changes.
@riverpod
Stream<ConsumedTotals> consumedTotalsForDate(Ref ref, String date) async* {
  final service = ref.read(mealLoggingServiceProvider);

  // Both watched before either await (a watch after an await throws once
  // this family member is disposed). The second is `ignore()`d so a failure
  // of the first never leaves its error unhandled.
  final logsFuture = ref.watch(mealLogsForDateProvider(date).future);
  final activitiesFuture = ref.watch(
    completedActivitiesForDateProvider(date).future,
  )..ignore();
  final logs = await logsFuture;
  final activities = await activitiesFuture;

  final mealTotals = service.consumedTotalsForLogs(logs);
  final fuelTotals = ConsumedTotals.fold(
    activities.map(duringFuelTotalsForActivity),
  );
  yield mealTotals + fuelTotals;
}

// ============================================================================
// Stream providers — recent meals
// ============================================================================

/// Most recent 25 distinct meal names for the current user.
///
/// Used by the "Recent" section of the meal picker. Streams from Drift, so a
/// meal just logged (re-logged from Recent, or from a recipe) moves to the
/// top at once, whichever write path logged it (testing-wave 26-005: the
/// controller's invalidate was skipped whenever the auto-dispose controller
/// had been disposed mid-write, and `logRecipe` never asked).
///
/// The `meal_logs` sync is awaited before the first emission rather than
/// kicked, so a fresh sign-in shows the spinner, not an empty Recent that
/// fills in under the athlete's finger; a sync that fails answers from the
/// local table.
@riverpod
Stream<List<MealLog>> recentMeals(Ref ref) async* {
  final repo = ref.read(mealLogRepositoryProvider);
  final sync = ref.read(syncCoordinatorProvider.notifier);
  final report = ref.read(reportProvider);
  final userRepo = await ref.read(userRepositoryProvider.future);
  final user = await userRepo.getCurrentUser();
  final userId = user?.id;
  if (userId == null) {
    yield const [];
    return;
  }

  // Bounded like the Plan tab's first read (MealPlanController.firstReadBound):
  // a hanging connection answers from the local table instead of spinning.
  await _ensureSynced(
    sync,
    report,
    repo,
    userId,
  ).timeout(const Duration(seconds: 15), onTimeout: () {});
  yield* repo.watchRecentLogs(userId);
}

// ============================================================================
// Stream providers — saved meals
// ============================================================================

/// Streams all non-deleted saved meals for the current user, ordered by
/// [SavedMeal.lastUsedAt] descending.
///
/// Used by the "My Meals" section of the meal picker. Kicks a `saved_meals`
/// sync in the background on build, like [mealLogsForDate].
@riverpod
Stream<List<SavedMeal>> savedMeals(Ref ref) async* {
  final repo = ref.read(savedMealsRepositoryProvider);
  final sync = ref.read(syncCoordinatorProvider.notifier);
  final report = ref.read(reportProvider);
  final userRepo = await ref.read(userRepositoryProvider.future);
  final user = await userRepo.getCurrentUser();
  final userId = user?.id;
  if (userId == null) {
    yield const [];
    return;
  }

  unawaited(_ensureSynced(sync, report, repo, userId));
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

  Report get _report => ref.report;

  /// Runs [action] inside [AsyncValue.guard], but only writes the result back
  /// to [state] if this provider is still mounted.
  ///
  /// Meal-logging actions routinely outlive the screen that triggered them
  /// (e.g. the user taps "Log" and the picker pops immediately). Because this
  /// is an auto-dispose provider, that pops disposes it while the write is
  /// still in flight. Two failure modes follow, both guarded here:
  /// - assigning [state] after the await throws [UnmountedRefException] — hence
  ///   the [ref.mounted] gate before the write; and
  /// - reading `ref` (e.g. the `MealLoggingService`) *after* an async gap
  ///   inside [action] throws the same exception — so the service is read once,
  ///   before the first await, and passed into [action] (Sentry
  ///   MEALVANA-ENDURANCE-DEV-4X).
  Future<void> _runGuarded(
    Future<void> Function(MealLoggingService service) action,
  ) async {
    final service = ref.read(mealLoggingServiceProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => action(service));
    if (!ref.mounted) return;
    state = result;
  }

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
    MealSlot? slot,
    required String logDate,
    int? calories,
    double? carbsG,
    double? proteinG,
    double? fatG,
    double? sodiumMg,
    String? notes,
    DateTime? eatenAt,
  }) async {
    await _runGuarded((service) async {
      final userId = await _currentUserId();
      if (userId == null) throw StateError('No authenticated user');

      await service.logManualMeal(
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
        if (slot != null) 'slot': slot.wireValue,
        'source': 'manual',
        'method': 'manual',
        'log_date': logDate,
      });
    });
  }

  /// Log a meal from the user's saved favorites.
  Future<void> logSavedMeal({
    required SavedMeal savedMeal,
    MealSlot? slot,
    required String logDate,
    DateTime? eatenAt,
  }) async {
    await _runGuarded((service) async {
      final userId = await _currentUserId();
      if (userId == null) throw StateError('No authenticated user');

      await service.logSavedMeal(
        savedMeal: savedMeal,
        userId: userId,
        slot: slot,
        logDate: logDate,
        eatenAt: eatenAt,
      );

      await _trackEvent('meal_logged', {
        if (slot != null) 'slot': slot.wireValue,
        'source': 'saved',
        'method': 'saved',
        'log_date': logDate,
      });
    });
  }

  /// Bulk-log multiple saved meals to [logDate] in one batch — the multi-log
  /// action. No-op for an empty [savedMeals]. [recentMeals] streams from
  /// Drift and picks the batch up on its own.
  Future<void> logSavedMeals({
    required List<SavedMeal> savedMeals,
    MealSlot? slot,
    required String logDate,
    DateTime? eatenAt,
  }) async {
    if (savedMeals.isEmpty) return;
    await _runGuarded((service) async {
      final userId = await _currentUserId();
      if (userId == null) throw StateError('No authenticated user');

      await service.logSavedMeals(
        savedMeals: savedMeals,
        userId: userId,
        slot: slot,
        logDate: logDate,
        eatenAt: eatenAt,
      );

      await _trackEvent('meals_logged_bulk', {
        'count': savedMeals.length,
        if (slot != null) 'slot': slot.wireValue,
        'source': 'saved',
        'log_date': logDate,
      });
    });
  }

  /// Log a recipe, scaling macros by [servings].
  Future<void> logRecipe({
    required RecipeLogParams params,
    MealSlot? slot,
    required String logDate,
    DateTime? eatenAt,
    String? notes,
  }) async {
    await _runGuarded((service) async {
      final userId = await _currentUserId();
      if (userId == null) throw StateError('No authenticated user');

      await service.logRecipe(
        params: params,
        userId: userId,
        slot: slot,
        logDate: logDate,
        eatenAt: eatenAt,
        notes: notes,
      );

      await _trackEvent('meal_logged', {
        if (slot != null) 'slot': slot.wireValue,
        'source': 'recipe',
        'method': 'recipe',
        'log_date': logDate,
        'recipe_id': params.recipeId,
      });
    });
  }

  /// Log a meal built from individual food components (used by photo, describe,
  /// manual-add, and build-a-meal draft flows).
  ///
  /// Returns the row as written (its id and summed totals), or null when the
  /// write failed; the failure is in the controller state (113-009: Build a
  /// Meal's favourite needs the real log, not a throwaway one).
  Future<MealLog?> logFromComponents({
    required String name,
    MealSlot? slot,
    required String logDate,
    required MealLogSource source,
    required List<MealComponent> components,
    String? photoPath,
    String? notes,
    DateTime? eatenAt,
    // Analytics-only method label. The persisted `source` is constrained by
    // the DB CHECK ('photo'|'manual'|'describe'|'saved'|'recipe'|...), so
    // barcode/build/common-tap all persist as `manual`; this disambiguates
    // them for funnels without a schema migration. Defaults to source.
    String? logMethod,
    // The count [components] were scaled to (a Common ingredient at 1.5),
    // recorded on the row so Recent shows the per-serving base (112-012).
    double servings = 1,
  }) async {
    MealLog? written;
    await _runGuarded((service) async {
      final userId = await _currentUserId();
      if (userId == null) throw StateError('No authenticated user');
      written = await service.logFromComponents(
        userId: userId,
        name: name,
        slot: slot,
        logDate: logDate,
        source: source,
        components: components,
        photoPath: photoPath,
        notes: notes,
        eatenAt: eatenAt,
        servings: servings,
      );
      await _trackEvent('meal_logged', {
        if (slot != null) 'slot': slot.wireValue,
        'source': source.wireValue,
        'method': logMethod ?? source.wireValue,
        'log_date': logDate,
      });
    });
    return written;
  }

  /// Re-log a past meal from Log a Meal → Recent as a copy of [original]
  /// (its items, totals and source; see [MealLoggingService.relogMeal]).
  Future<void> relogMeal({
    required MealLog original,
    double servings = 1,
    MealSlot? slot,
    required String logDate,
    DateTime? eatenAt,
  }) async {
    await _runGuarded((service) async {
      final userId = await _currentUserId();
      if (userId == null) throw StateError('No authenticated user');
      await service.relogMeal(
        original: original,
        userId: userId,
        slot: slot,
        logDate: logDate,
        eatenAt: eatenAt,
        servings: servings,
      );
      await _trackEvent('meal_logged', {
        if (slot != null) 'slot': slot.wireValue,
        'source': original.source.wireValue,
        'method': 'recent',
        'log_date': logDate,
      });
    });
  }

  /// Update an existing meal log entry.
  ///
  /// Passes the full updated [MealLog] to the service which recomputes totals
  /// when components are present, then writes via the repository.
  Future<void> updateLog(MealLog log) async {
    await _runGuarded((service) async {
      await service.updateLog(log);

      _report.info(
        'Meal log updated',
        area: 'meal_logging',
        data: {'logId': log.id},
      );

      await _trackEvent('meal_log_updated', {
        'log_id': log.id,
        if (log.slot != null) 'slot': log.slot!.wireValue,
      });
    });
  }

  /// Restore a previously soft-deleted meal log entry (used by undo-delete).
  Future<void> restoreLog(String logId) async {
    await _runGuarded((service) async {
      // Read the repo, report and tracker before the async gap below so a
      // mid-action disposal can't trigger a `ref.read` on a disposed ref
      // (UnmountedRefException). The Undo snackbar calls this with no
      // listener, so the auto-dispose controller is usually gone by the time
      // the write lands; the event still goes (ticket 41, 31-012).
      final repo = ref.read(mealLogRepositoryProvider);
      final report = _report;
      final analytics = ref.read(appExternalDepsProvider).analytics;
      final userId = await _currentUserId();
      if (userId == null) throw StateError('No authenticated user');

      await repo.restoreLog(id: logId, userId: userId);

      report.info(
        'Meal log restored',
        area: 'meal_logging',
        data: {'logId': logId},
      );
      await analytics.track(
        'meal_log_restored',
        properties: {'log_id': logId},
      );
    });
  }

  /// Soft-delete a meal log entry.
  Future<void> deleteLog(String logId) async {
    await _runGuarded((service) async {
      // Read the repo, report and tracker before the async gap below so a
      // mid-action disposal can't trigger a `ref.read` on a disposed ref
      // (UnmountedRefException). The Timeline and the diary call this with
      // no listener, so the auto-dispose controller is usually gone by the
      // time the write lands; the event still goes (ticket 41, 31-012).
      final repo = ref.read(mealLogRepositoryProvider);
      final report = _report;
      final analytics = ref.read(appExternalDepsProvider).analytics;
      final userId = await _currentUserId();
      if (userId == null) throw StateError('No authenticated user');

      await repo.softDeleteLog(id: logId, userId: userId);

      report.info(
        'Meal log deleted',
        area: 'meal_logging',
        data: {'logId': logId},
      );
      await analytics.track('meal_log_deleted', properties: {'log_id': logId});
    });
  }

  // --------------------------------------------------------------------------
  // Saved meals actions
  // --------------------------------------------------------------------------

  /// Save a log entry as a user favorite. The favourite copies [log]'s name,
  /// items and stored totals, so callers pass the row as written (112-007).
  /// Returns the favourite, or null when the write failed.
  Future<SavedMeal?> saveLogAsFavorite(
    MealLog log, {
    String? customName,
  }) async {
    SavedMeal? saved;
    await _runGuarded((service) async {
      saved = await service.saveLogAsFavorite(log, customName: customName);
      if (ref.mounted) ref.invalidate(savedMealsProvider);

      await _trackEvent('meal_saved_as_favorite', {
        'log_id': log.id,
        'custom_name': customName != null,
      });
    });
    return saved;
  }

  /// Soft-delete a saved meal.
  Future<void> deleteSavedMeal(String mealId) async {
    await _runGuarded((service) async {
      // Read before the await: the row's screen may close mid-action.
      final repo = ref.read(savedMealsRepositoryProvider);
      await repo.softDelete(mealId);
      if (ref.mounted) ref.invalidate(savedMealsProvider);

      await _trackEvent('saved_meal_deleted', {'meal_id': mealId});
    });
  }

  /// Undo [deleteSavedMeal] (the Undo on its snackbar, 112-005).
  Future<void> restoreSavedMeal(String mealId) async {
    await _runGuarded((service) async {
      final repo = ref.read(savedMealsRepositoryProvider);
      await repo.restore(mealId);
      if (ref.mounted) ref.invalidate(savedMealsProvider);

      await _trackEvent('saved_meal_restored', {'meal_id': mealId});
    });
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------

  Future<void> _trackEvent(
    String event,
    Map<String, dynamic> properties,
  ) async {
    // Fire-and-forget analytics: skip if the provider was disposed mid-action
    // (e.g. the triggering screen popped before the write finished).
    if (!ref.mounted) return;
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
  final report = ref.read(reportProvider);
  try {
    final supabase = ref.read(supabaseClientProvider);
    final url = await supabase.storage
        .from('meal-photos')
        .createSignedUrl(photoPath, 3600);
    return url;
  } catch (e, st) {
    report.fault(
      e,
      stackTrace: st,
      area: 'meal_logging',
      message: 'meal photo signed URL failed',
      extra: {'photo_path': photoPath},
    );
    return null;
  }
}
