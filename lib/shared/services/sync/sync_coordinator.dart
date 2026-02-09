import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../logging_service.dart';
import 'data_sync_service.dart';
import '../../data/syncable_repository.dart';
import '../app_external_deps.dart';

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
  /// Repository dependency graph for dependency resolution
  static const Map<String, List<String>> _dependencies = {
    'users': [],
    'foods': [],
    'carb_loading_foods': [],
    'activities': ['users'],
    'events': ['users'],
    'food_preferences': ['users', 'foods'],
    'user_foods': ['users'],
    'coaches': ['users'],
    'coach_athlete_relationships': ['coaches', 'users'],
    'carb_loading_plans': ['users', 'events'],
    'carb_loading_days': ['carb_loading_plans'],
    'carb_loading_day_meals': ['carb_loading_days', 'carb_loading_foods'],
    'coach_messages': ['coach_athlete_relationships'],
  };

  /// Track what's currently being synced to prevent infinite loops
  final Set<String> _syncingNow = {};

  /// Track last sync times per repository for staleness checks
  final Map<String, DateTime> _lastSyncTimes = {};

  /// Track last failed sync attempt per repository (for rate limiting)
  final Map<String, DateTime> _lastFailedAttempt = {};

  /// Skip sync for users who just completed onboarding (in-memory, self-clearing)
  bool _skipSyncForNewUser = false;

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
    // 0. Skip sync for users who just completed onboarding
    // New users have all data locally - nothing to download from Supabase
    // Their data will be uploaded via background sync later
    if (_shouldSkipSyncForNewUser()) {
      _logger.info(
        'Skipping sync - user just completed onboarding',
        context: 'SYNC_COORDINATOR',
        data: {'repoKey': repoKey},
      );
      return;
    }

    // 1. Prevent infinite loops - if already syncing this repo, return
    if (_syncingNow.contains(repoKey)) {
      _logger.debug(
        'Skipping sync - already in progress',
        context: 'SYNC_COORDINATOR',
        data: {'repoKey': repoKey},
      );
      return;
    }

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

    try {
      // 5. Sync dependencies FIRST (recursive)
      final deps = _dependencies[repoKey] ?? [];
      for (final dep in deps) {
        await ensureSynced(dep, userId);
      }

      // 6. Upload dirty records (if repository provided)
      if (repository != null) {
        await repository.uploadDirtyRecords(userId);
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
      // Don't rethrow - best effort sync
    } finally {
      _syncingNow.remove(repoKey);
    }
  }

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

  // ========================================================================
  // New User (Post-Onboarding) Sync Skip
  // ========================================================================

  /// Check if sync should be skipped for a user who just completed onboarding.
  ///
  /// New users have all data locally - nothing to download from Supabase.
  /// Their user profile is already uploaded during onboarding completion.
  /// Skipping sync prevents unnecessary network calls and potential FK errors.
  ///
  /// Uses in-memory flag - self-clearing on first check.
  bool _shouldSkipSyncForNewUser() {
    if (_skipSyncForNewUser) {
      _skipSyncForNewUser = false; // Clear immediately (self-clearing)
      return true;
    }
    return false;
  }

  /// Set flag to skip sync for new users (called from onboarding completion)
  void setSkipSyncForNewUser() {
    _skipSyncForNewUser = true;
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
      // STEP 1: Upload dirty records FIRST (protect user data)
      await _dataSyncService.uploadDirtyRecords(userId);

      // STEP 2: Download fresh data from Supabase (includes user profile sync)
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
      return false;
    } finally {
      _syncInProgress = false;
      state = SyncState.idle;
    }
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
    _lastSyncTimes.clear();
    _lastFailedAttempt.clear();
    _failureCount.clear();
    _lastSyncTime = null;
    _syncInProgress = false;
    state = SyncState.idle;

    final prefs = ref.read(sharedPreferencesProvider);
    for (final repoKey in _dependencies.keys) {
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
      await repository.uploadDirtyRecords(userId);

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
