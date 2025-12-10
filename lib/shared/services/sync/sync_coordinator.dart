import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../logging_service.dart';
import 'data_sync_service.dart';

// Provider imports for invalidation
import '../../../features/activities/presentation/providers/activities_controller.dart';
import '../../../features/events/presentation/providers/events_controller.dart';
import '../../../features/settings/presentation/providers/settings_controller.dart';
import '../../../features/carb_loading/presentation/providers/carb_loading_controller.dart';
import '../../providers/user_id_provider.dart';

part 'sync_coordinator.g.dart';

/// Tracks why sync was triggered (for logging/debugging)
enum SyncTrigger {
  oauthSignIn,
  pullToRefresh,
  manual,
}

/// Internal sync status (no UI exposure)
enum SyncState {
  idle,
  syncing,
}

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

  /// Single entry point for ALL sync operations
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
      _logger.info(
        'Sync already in progress, skipping duplicate request',
        context: 'SYNC_COORDINATOR',
        data: {'trigger': trigger.name, 'userId': userId},
      );
      return true; // Return true since a sync is happening
    }

    _syncInProgress = true;
    state = SyncState.syncing;

    _logger.info(
      'Starting sync',
      context: 'SYNC_COORDINATOR',
      data: {'trigger': trigger.name, 'userId': userId},
    );

    try {
      // Delegate to DataSyncService for actual sync work
      final success = await _dataSyncService.syncAllData(userId);

      if (success) {
        _lastSyncTime = DateTime.now();

        // Invalidate ALL data providers after successful sync
        // (unless caller wants to handle invalidation themselves)
        if (!skipInvalidation) {
          _invalidateAllProviders();
        }

        _logger.info(
          'Sync completed successfully',
          context: 'SYNC_COORDINATOR',
          data: {
            'trigger': trigger.name,
            'userId': userId,
            'lastSyncTime': _lastSyncTime?.toIso8601String(),
            'skippedInvalidation': skipInvalidation,
          },
        );
      } else {
        _logger.warning(
          'Sync completed with errors',
          context: 'SYNC_COORDINATOR',
          data: {'trigger': trigger.name, 'userId': userId},
        );
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
    _logger.info(
      'Invalidating all data providers',
      context: 'SYNC_COORDINATOR',
    );

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
}
