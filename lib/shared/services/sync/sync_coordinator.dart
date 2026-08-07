import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../logging_service.dart';
import '../sentry/sentry_reporter.dart';
import 'data_sync_service.dart';
import 'sync_dependency_graph.dart';
import '../../data/syncable_repository.dart';
import '../app_external_deps.dart';

// Repository imports for per-repo upload
import '../../../features/activities/data/activities_repository.dart';
import '../../../features/events/data/events_repository.dart';
import '../../../features/carb_loading/data/carb_loading_repository.dart';
import '../../../features/feedback/data/feedback_repository.dart';
import '../../../features/food_preferences/data/food_preferences_repository.dart';
import '../../../features/auth/data/user_repository.dart';
import '../../../features/user_foods/data/user_foods_repository.dart';
import '../../../features/meal_logging/data/meal_log_repository.dart';
import '../../../features/meal_logging/data/saved_meals_repository.dart';
import '../../../features/integrations/presentation/providers/integrations_providers.dart';
import '../../../features/formula_kit/data/formula_pins_repository.dart';
import '../../../features/onboarding/data/onboarding_survey_repository.dart';

// Provider imports for invalidation
import '../../../features/activities/presentation/providers/activities_controller.dart';
import '../../../features/events/presentation/providers/events_controller.dart';
import '../../../features/settings/presentation/providers/settings_controller.dart';
import '../../../features/carb_loading/presentation/providers/carb_loading_controller.dart';
import '../../providers/user_id_provider.dart';

part 'sync_coordinator.g.dart';

/// Tracks why sync was triggered (for logging/debugging)
enum SyncTrigger { oauthSignIn, pullToRefresh, manual, preLogout }

/// Internal sync status (no UI exposure)
enum SyncState { idle, syncing }

/// Centralized sync coordinator - SINGLE entry point for ALL sync operations
///
/// Key responsibilities:
/// 1. Prevents concurrent syncs (sync lock)
/// 2. Calls DataSyncService.syncAllData()
/// 3. Invalidates ALL data providers after successful sync
/// 4. Logs sync operations (silent error handling)
///
/// Sync triggers (OAuth-only strategy):
/// - oauthSignIn: After successful OAuth sign-in (new device login, sign back in)
/// - pullToRefresh: Manual user refresh
/// - manual: Any other explicit sync request
///
/// NOT synced on app startup - returning users see cached data until pull-to-refresh
@Riverpod(keepAlive: true)
class SyncCoordinator extends _$SyncCoordinator {
  /// Canonical repository dependency graph for dependency resolution.
  static const Map<String, List<String>> _dependencies =
      SyncDependencyGraph.dependenciesByRepository;

  /// Track what's currently being synced to prevent infinite loops
  final Set<String> _syncingNow = {};

  /// Track in-flight sync futures per repository to dedupe concurrent callers.
  final Map<String, Future<void>> _inFlightSyncs = {};

  /// Track last sync times per repository for staleness checks
  final Map<String, DateTime> _lastSyncTimes = {};

  /// Track last failed sync attempt per repository (for rate limiting)
  final Map<String, DateTime> _lastFailedAttempt = {};

  /// Track consecutive failure count per repository (for rate limiting)
  final Map<String, int> _failureCount = {};

  /// Cooldown period after a sync failure before retrying
  static const _failureCooldown = Duration(minutes: 2);

  /// Sync lock to prevent concurrent syncs
  bool _syncInProgress = false;

  /// Last successful sync time (for debugging)
  DateTime? _lastSyncTime;

  @override
  SyncState build() {
    return SyncState.idle;
  }

  AppLogger get _logger => ref.read(appLoggerProvider);
  DataSyncService get _dataSyncService => ref.read(dataSyncServiceProvider);
  SentryReporter get _sentry => ref.read(sentryReporterProvider);

  /// Ensures a repository's data is fresh (synced within staleness threshold).
  ///
  /// This is the NEW sync pattern for repository-level sync with dependency resolution.
  /// Call this from controllers when they need fresh data:
  ///
  /// ```dart
  /// @override
  /// FutureOr<StateType> build() async {
  ///   await syncCoordinator.ensureSynced('activities', userId);
  ///   // Now safe to query activities
  /// }
  /// ```
  ///
  /// How it works:
  /// 1. Checks if repository data is stale (>1h since last sync)
  /// 2. If fresh, returns immediately (no-op)
  /// 3. If stale, recursively syncs dependencies FIRST
  /// 4. Uploads dirty records for this repository
  /// 5. Syncs fresh data from Supabase
  /// 6. Updates timestamp
  ///
  /// [repoKey] - Repository identifier from dependency graph
  /// [userId] - Current user ID for scoped queries
  /// [repository] - Optional repository instance for actual sync (Phase 3)
  ///
  /// Returns immediately if:
  /// - Already syncing this repository (prevents infinite loops)
  /// - Data is fresh (<1h since last sync)
  Future<void> ensureSynced(
    String repoKey,
    String userId, {
    SyncableRepository? repository,
  }) async {
    // NOTE (2026-07-29 policy change): there is deliberately no "skip sync for
    // a user who just onboarded" short-circuit here any more. We ALWAYS push
    // to Supabase, including for anonymous (skipped-account-creation) users —
    // the old flag suppressed the first upload after onboarding, which was the
    // one upload that carried the onboarding answers. Downloads are additive
    // (every syncFromRemote upserts and preserves locally-dirty rows), so
    // syncing a brand-new user against an empty remote cannot lose data.

    // 1. Prevent infinite loops - if already syncing this repo, return
    if (_syncingNow.contains(repoKey)) {
      _logger.debug(
        'Skipping sync - already in progress',
        context: 'SYNC_COORDINATOR',
        data: {'repoKey': repoKey},
      );
      return;
    }

    final inFlightSync = _inFlightSyncs[repoKey];
    if (inFlightSync != null) {
      _logger.debug(
        'Awaiting in-flight sync',
        context: 'SYNC_COORDINATOR',
        data: {'repoKey': repoKey},
      );
      await inFlightSync;
      return;
    }

    final completer = Completer<void>();
    _inFlightSyncs[repoKey] = completer.future;
    var markedSyncing = false;

    try {
      // 2. Rate limiting - skip if recently failed (cooldown period)
      if (_isInFailureCooldown(repoKey)) {
        _logger.debug(
          'Skipping sync - in failure cooldown',
          context: 'SYNC_COORDINATOR',
          data: {
            'repoKey': repoKey,
            'failureCount': _failureCount[repoKey] ?? 0,
            'cooldownRemaining': _getCooldownRemaining(repoKey),
          },
        );
        return;
      }

      // 3. Check if data is stale - if fresh, return immediately
      if (!await _isStale(repoKey, repository)) {
        _logger.debug(
          'Skipping sync - data is fresh',
          context: 'SYNC_COORDINATOR',
          data: {'repoKey': repoKey},
        );
        return;
      }

      // 4. Mark as syncing
      _syncingNow.add(repoKey);
      markedSyncing = true;

      // 5. Sync dependencies FIRST (recursive)
      //
      // Resolve each dependency's repository. Without it the recursive call has
      // no repository to work with, so it uploads nothing and downloads nothing
      // — it just stamps a timestamp. That made this step a no-op, which is how
      // a dirty event could be uploaded while its activity was still local-only
      // (FK 23503 on events_activity_id_fkey).
      final deps = _dependencies[repoKey] ?? const <String>[];
      for (final dep in deps) {
        await ensureSynced(dep, userId, repository: await _repositoryFor(dep));
      }

      // 6. Upload dirty records (if repository provided)
      if (repository != null) {
        final uploadResult = await repository.uploadDirtyRecords(userId);
        if (!uploadResult.success) {
          throw StateError(
            'Upload failed for $repoKey: ${uploadResult.error ?? 'unknown error'}',
          );
        }
      }

      // 7. Sync this repository (if repository provided)
      if (repository != null) {
        await repository.syncFromRemote(userId);
      }

      // 8. Update timestamp and clear failure tracking on success
      _lastSyncTimes[repoKey] = DateTime.now();
      _clearFailureTracking(repoKey);

      _logger.info(
        'Repository synced successfully',
        context: 'SYNC_COORDINATOR',
        data: {'repoKey': repoKey},
      );
    } catch (e, stackTrace) {
      // Record failure for rate limiting
      _recordFailure(repoKey);

      _logger.error(
        'Repository sync failed',
        context: 'SYNC_COORDINATOR',
        error: e,
        stackTrace: stackTrace,
        data: {
          'repoKey': repoKey,
          'userId': userId,
          'failureCount': _failureCount[repoKey] ?? 1,
        },
      );
      unawaited(
        _sentry.reportCriticalError(
          e,
          stackTrace: stackTrace,
          context: 'sync_ensureSynced_$repoKey',
        ),
      );
      // Don't rethrow - best effort sync
    } finally {
      if (markedSyncing) {
        _syncingNow.remove(repoKey);
      }
      _inFlightSyncs.remove(repoKey);
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  /// Resolve the [SyncableRepository] backing a dependency-graph key.
  ///
  /// Returns null for keys with no syncable repository (e.g. reference data such
  /// as `template_foods`), in which case the caller treats the key as a no-op —
  /// the pre-existing behaviour for those keys.
  ///
  /// Resolution is best-effort: if a repository provider cannot be constructed
  /// we log and return null rather than failing the caller's sync. Falling back
  /// to the old no-op leaves the caller no worse off than before this resolver
  /// existed — an FK violation would still surface as an upload error — whereas
  /// throwing here would take down a sync that could otherwise have succeeded.
  Future<SyncableRepository?> _repositoryFor(String repoKey) async {
    try {
      switch (repoKey) {
        case 'users':
          return await ref.read(userRepositoryProvider.future);
        case 'activities':
          return ref.read(activitiesRepositoryProvider);
        case 'events':
          return ref.read(eventsRepositoryProvider);
        case 'carb_loading_plans':
          return ref.read(carbLoadingRepositoryProvider);
        case 'feedback':
          return ref.read(feedbackRepositoryProvider);
        case 'food_preferences':
          return await ref.read(foodPreferencesRepositoryProvider.future);
        case 'user_foods':
          return await ref.read(userFoodsRepositoryProvider.future);
        case 'meal_logs':
          return ref.read(mealLogRepositoryProvider);
        case 'saved_meals':
          return ref.read(savedMealsRepositoryProvider);
        // Both are written during onboarding — `integrations` by the
        // Connect-Training step, `formula_pins` by the default-formula
        // auto-pin — but neither was resolvable here, so a dirty row that
        // missed its opportunistic inline upload had no retry channel at all.
        case 'integrations':
          return ref.read(integrationsRepositoryProvider);
        case 'formula_pins':
          return ref.read(formulaPinsRepositoryProvider);
        case 'onboarding_surveys':
          return ref.read(onboardingSurveyRepositoryProvider);
        default:
          return null;
      }
    } catch (e) {
      _logger.warning(
        'Could not resolve repository for dependency sync',
        context: 'SYNC_COORDINATOR',
        data: {'repoKey': repoKey, 'error': e.toString()},
      );
      return null;
    }
  }

  /// Repository keys that [_repositoryFor] can resolve, i.e. everything that
  /// participates in dirty-record upload.
  ///
  /// `onboarding_surveys` must stay in this list: its only other upload path
  /// is the opportunistic inline push right after onboarding, so without the
  /// dirty-record walk a survey written offline would never reach Supabase.
  static const List<String> _syncableRepositoryKeys = <String>[
    'users',
    'activities',
    'events',
    'carb_loading_plans',
    'feedback',
    'food_preferences',
    'user_foods',
    'meal_logs',
    'saved_meals',
    'integrations',
    'formula_pins',
    'onboarding_surveys',
  ];

  /// Test-only view of the dirty-record upload roster, so a regression test
  /// can pin repositories (like `onboarding_surveys`) whose absence is
  /// invisible at runtime — uploads just silently never retry.
  @visibleForTesting
  static List<String> get syncableRepositoryKeysForTesting =>
      _syncableRepositoryKeys;

  /// Check if a repository's data is stale and needs syncing.
  ///
  /// Data is stale if:
  /// - Never been synced (no timestamp in memory)
  /// - Last sync was more than 1 hour ago
  ///
  /// If repository instance is provided, delegates to repository.isStale()
  /// which checks SharedPreferences. Otherwise uses in-memory cache.
  Future<bool> _isStale(String repoKey, SyncableRepository? repository) async {
    // If repository provided, use its staleness check (SharedPreferences)
    if (repository != null) {
      return await repository.isStale();
    }

    // Otherwise use in-memory cache (for Phase 2 - before repos implement SyncableRepository)
    final lastSync = _lastSyncTimes[repoKey];
    if (lastSync == null) return true;

    const staleDuration = Duration(hours: 1);
    return DateTime.now().difference(lastSync) > staleDuration;
  }

  // ========================================================================
  // Rate Limiting Helpers (in-memory, resets on app restart)
  // ========================================================================

  /// Check if a repository is in failure cooldown and should skip sync.
  ///
  /// Returns true if:
  /// - Repository has failed at least once
  /// - Last failure was within [_failureCooldown] period
  bool _isInFailureCooldown(String repoKey) {
    final lastFailure = _lastFailedAttempt[repoKey];
    if (lastFailure == null) return false;

    final timeSinceFailure = DateTime.now().difference(lastFailure);
    return timeSinceFailure < _failureCooldown;
  }

  /// Get remaining cooldown time as a human-readable string (for logging).
  String _getCooldownRemaining(String repoKey) {
    final lastFailure = _lastFailedAttempt[repoKey];
    if (lastFailure == null) return 'none';

    final elapsed = DateTime.now().difference(lastFailure);
    final remaining = _failureCooldown - elapsed;
    if (remaining.isNegative) return 'none';

    return '${remaining.inSeconds}s';
  }

  /// Record a sync failure for rate limiting.
  void _recordFailure(String repoKey) {
    _lastFailedAttempt[repoKey] = DateTime.now();
    _failureCount[repoKey] = (_failureCount[repoKey] ?? 0) + 1;
  }

  /// Clear failure tracking after successful sync.
  void _clearFailureTracking(String repoKey) {
    _lastFailedAttempt.remove(repoKey);
    _failureCount.remove(repoKey);
  }

  /// Single entry point for ALL sync operations (LEGACY - kept for backwards compatibility)
  ///
  /// Returns true if sync completed successfully, false otherwise
  /// Silently handles errors (logs only, no UI feedback)
  /// Prevents concurrent syncs - if already syncing, returns immediately
  ///
  /// [skipInvalidation] - If true, caller is responsible for invalidating providers.
  /// This is useful when the caller needs to control the exact timing of invalidation
  /// (e.g., OAuth sign-in where invalidation timing affects UI responsiveness).
  Future<bool> sync({
    required String userId,
    SyncTrigger trigger = SyncTrigger.manual,
    bool skipInvalidation = false,
  }) async {
    // Prevent concurrent syncs
    if (_syncInProgress) {
      return true; // Return true since a sync is happening
    }

    // Check network connectivity before attempting sync
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return false; // Return false since sync was skipped (offline-first: user can continue)
    }

    _syncInProgress = true;
    state = SyncState.syncing;

    try {
      // Step 1: Upload dirty records per-repository
      await _uploadAllDirtyRecords(userId);

      // Step 2: Download fresh data from Supabase
      final success = await _dataSyncService.syncAllData(userId);

      if (success) {
        _lastSyncTime = DateTime.now();

        // Invalidate ALL data providers after successful sync
        // (unless caller wants to handle invalidation themselves)
        if (!skipInvalidation) {
          _invalidateAllProviders();
        }
      }

      return success;
    } catch (e, stackTrace) {
      _logger.error(
        'Sync failed',
        context: 'SYNC_COORDINATOR',
        error: e,
        stackTrace: stackTrace,
        data: {'trigger': trigger.name, 'userId': userId},
      );
      unawaited(
        _sentry.reportCriticalError(
          e,
          stackTrace: stackTrace,
          context: 'sync_full_sync_${trigger.name}',
        ),
      );
      return false;
    } finally {
      _syncInProgress = false;
      state = SyncState.idle;
    }
  }

  /// Upload dirty records from all repositories (public API).
  ///
  /// Best-effort: never throws. Returns the repository keys whose upload did
  /// not succeed (failed outright, or was skipped because a dependency failed)
  /// so callers can surface the failure instead of assuming success —
  /// `uploadDirtyRecords()` swallows exceptions into a silent
  /// `UploadResult.failed()`, so an unchecked call looks identical to a
  /// successful one. An empty list means everything reached Supabase.
  ///
  /// Used by corruption recovery to save data before database deletion, and by
  /// onboarding completion to push the freshly-captured profile.
  Future<List<String>> uploadAllDirtyRecords(String userId) =>
      _uploadAllDirtyRecords(userId);

  /// Upload dirty records from all repositories before download.
  /// Best-effort: logs failures but doesn't block download.
  ///
  /// Uploads in dependency order, one level at a time. Uploading everything at
  /// once (the previous behaviour) raced a child against its parent: a dirty
  /// event could reach Supabase before the activity it references, failing
  /// events_activity_id_fkey with Postgres 23503.
  Future<List<String>> _uploadAllDirtyRecords(String userId) async {
    final failures = <String>[];
    final skipped = <String>[];

    try {
      final levels = SyncDependencyGraph.topologicalLevels(
        _syncableRepositoryKeys,
      );

      for (final level in levels) {
        // A repository whose parent failed to upload cannot succeed — its rows
        // would violate the same FK. Skip it instead of firing a second, noisier
        // failure for the same root cause.
        final runnable = <String>[];
        for (final repoKey in level) {
          final blockedBy = SyncDependencyGraph.dependenciesFor(repoKey)
              .where((d) => failures.contains(d) || skipped.contains(d))
              .toList(growable: false);

          if (blockedBy.isEmpty) {
            runnable.add(repoKey);
            continue;
          }

          skipped.add(repoKey);
          _logger.warning(
            'Skipping dirty record upload for $repoKey - dependency failed',
            context: 'SYNC_COORDINATOR',
            data: {'repository': repoKey, 'blockedBy': blockedBy},
          );
        }

        if (runnable.isEmpty) continue;

        // Independent within a level, so upload them concurrently.
        final results = await Future.wait(
          runnable.map((repoKey) async {
            final repository = await _repositoryFor(repoKey);
            if (repository == null) return UploadResult.nothingToUpload();
            return repository.uploadDirtyRecords(userId);
          }),
        );

        for (var i = 0; i < runnable.length; i++) {
          final repoKey = runnable[i];
          final result = results[i];
          if (result.success) continue;

          failures.add(repoKey);
          _logger.error(
            'Dirty record upload failed for $repoKey',
            context: 'SYNC_COORDINATOR',
            data: {'repository': repoKey, 'error': result.error},
          );
        }
      }

      if (failures.isNotEmpty) {
        _logger.warning(
          'Some dirty record uploads failed before download',
          context: 'SYNC_COORDINATOR',
          data: {
            'failedRepos': failures,
            'skippedRepos': skipped,
            'failedCount': failures.length,
            'totalRepos': _syncableRepositoryKeys.length,
          },
        );
        unawaited(
          _sentry.captureMessage(
            'Dirty record upload failures during sync: ${failures.join(", ")}',
            level: SentryLevel.warning,
            tags: {
              'failed_repos': failures.join(','),
              'failed_count': '${failures.length}',
              if (skipped.isNotEmpty) 'skipped_repos': skipped.join(','),
            },
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upload dirty records before download',
        context: 'SYNC_COORDINATOR',
        error: e,
        stackTrace: stackTrace,
      );
      unawaited(
        _sentry.reportCriticalError(
          e,
          stackTrace: stackTrace,
          context: 'sync_upload_dirty_records',
        ),
      );
      // The orchestration itself blew up, so nothing can be assumed to have
      // landed. Report every repository as unsuccessful rather than handing the
      // caller a misleading empty (== "all good") list.
      return _syncableRepositoryKeys.toList(growable: false);
    }

    return [...failures, ...skipped];
  }

  /// Invalidate ALL data providers after sync
  ///
  /// This is centralized here instead of being scattered across:
  /// - app_startup_service.dart (4 locations)
  /// - oauth_service.dart (1 location)
  /// - activities_list_screen.dart (1 location)
  /// - events_list_screen.dart (1 location)
  void _invalidateAllProviders() {
    // User identity
    ref.invalidate(userIdProvider);

    // Calendar data
    ref.invalidate(activitiesControllerProvider);
    ref.invalidate(allEventsProvider);
    ref.invalidate(nextUpcomingEventProvider);

    // Settings
    ref.invalidate(settingsControllerProvider);

    // Carb loading
    ref.invalidate(carbLoadingControllerProvider);
  }

  /// Check if sync is currently in progress
  bool get isSyncing => _syncInProgress;

  /// Get last successful sync time (for debugging)
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Reset in-memory and persisted repository sync state.
  ///
  /// Called on sign-out so the next sign-in performs a full repository sync
  /// instead of incorrectly reusing stale freshness timestamps.
  Future<void> resetRepositorySyncState() async {
    _syncingNow.clear();
    _inFlightSyncs.clear();
    _lastSyncTimes.clear();
    _lastFailedAttempt.clear();
    _failureCount.clear();
    _lastSyncTime = null;
    _syncInProgress = false;
    state = SyncState.idle;

    final prefs = ref.read(sharedPreferencesProvider);
    for (final repoKey in SyncDependencyGraph.repositoryKeys) {
      await prefs.remove('${repoKey}_last_sync');
    }

    _logger.info('Repository sync state reset', context: 'SYNC_COORDINATOR');
  }

  /// Force sync a repository, bypassing the staleness check.
  ///
  /// Use this for pull-to-refresh when user explicitly wants fresh data,
  /// or when an athlete needs to see coach-made changes immediately.
  ///
  /// This method:
  /// 1. Syncs dependencies first (respecting their staleness)
  /// 2. Uploads dirty records
  /// 3. Force syncs this repository (bypasses staleness check)
  /// 4. Invalidates related providers
  ///
  /// [repoKey] - Repository identifier from dependency graph
  /// [userId] - Current user ID for scoped queries
  /// [repository] - Repository instance for actual sync
  Future<void> forceSyncRepository(
    String repoKey,
    String userId, {
    required SyncableRepository repository,
  }) async {
    // Prevent concurrent syncs of the same repo
    if (_syncingNow.contains(repoKey)) {
      _logger.debug(
        'Force sync skipped - already in progress',
        context: 'SYNC_COORDINATOR',
        data: {'repoKey': repoKey},
      );
      return;
    }

    // Check network connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      _logger.warning(
        'Force sync skipped - no network',
        context: 'SYNC_COORDINATOR',
        data: {'repoKey': repoKey},
      );
      return;
    }

    _syncingNow.add(repoKey);

    try {
      _logger.info(
        'Force sync started',
        context: 'SYNC_COORDINATOR',
        data: {'repoKey': repoKey},
      );

      // 1. Sync dependencies FIRST (these respect staleness)
      final deps = _dependencies[repoKey] ?? [];
      for (final dep in deps) {
        await ensureSynced(dep, userId);
      }

      // 2. Upload dirty records FIRST (protect user data)
      final uploadResult = await repository.uploadDirtyRecords(userId);
      if (!uploadResult.success) {
        throw StateError(
          'Upload failed for $repoKey: ${uploadResult.error ?? 'unknown error'}',
        );
      }

      // 3. Force sync from remote (bypass staleness)
      await repository.syncFromRemote(userId);

      // 4. Update timestamp and clear failure tracking
      _lastSyncTimes[repoKey] = DateTime.now();
      _clearFailureTracking(repoKey);

      _logger.info(
        'Force sync completed successfully',
        context: 'SYNC_COORDINATOR',
        data: {'repoKey': repoKey},
      );
    } catch (e, stackTrace) {
      _recordFailure(repoKey);
      _logger.error(
        'Force sync failed',
        context: 'SYNC_COORDINATOR',
        error: e,
        stackTrace: stackTrace,
        data: {'repoKey': repoKey, 'userId': userId},
      );
      // Don't rethrow - best effort sync
    } finally {
      _syncingNow.remove(repoKey);
    }
  }

  /// Force sync multiple repositories for a full refresh.
  ///
  /// Use this when athlete needs to see all coach changes.
  /// Syncs in dependency order: activities → events → carb_loading_plans
  Future<void> forceFullSync(
    String userId, {
    SyncableRepository? activitiesRepo,
    SyncableRepository? eventsRepo,
    SyncableRepository? carbLoadingPlansRepo,
  }) async {
    _logger.info(
      'Full force sync started',
      context: 'SYNC_COORDINATOR',
      data: {'userId': userId},
    );

    // Sync in dependency order
    if (activitiesRepo != null) {
      await forceSyncRepository(
        'activities',
        userId,
        repository: activitiesRepo,
      );
    }
    if (eventsRepo != null) {
      await forceSyncRepository('events', userId, repository: eventsRepo);
    }
    if (carbLoadingPlansRepo != null) {
      await forceSyncRepository(
        'carb_loading_plans',
        userId,
        repository: carbLoadingPlansRepo,
      );
    }

    // Invalidate all related providers
    _invalidateAllProviders();

    _logger.info(
      'Full force sync completed',
      context: 'SYNC_COORDINATOR',
      data: {'userId': userId},
    );
  }
}
