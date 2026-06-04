import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../activities/data/activities_repository.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sync/sync_coordinator.dart';
import '../presentation/providers/connect_training_controller.dart';
import '../presentation/providers/integrations_providers.dart';

part 'integration_sync_coordinator.g.dart';

/// Lightweight coordinator for integration staleness checks and dedup.
///
/// Purpose-built for external provider sync (Final Surge, Training Peaks,
/// V.O2). NOT part of the SyncCoordinator dependency graph because integration
/// sync has no dirty-record upload concept.
///
/// Design:
/// - 4-hour staleness threshold (external APIs are slower/less reliable)
/// - 5-minute failure cooldown
/// - Dedup via _syncingNow set
/// - Silent failures (logs only, no snackbars)
@Riverpod(keepAlive: true)
class IntegrationSyncCoordinator extends _$IntegrationSyncCoordinator {
  /// Staleness threshold: sync if last sync was >4 hours ago
  static const _stalenessThreshold = Duration(hours: 4);

  /// Cooldown after a failed sync attempt
  static const _failureCooldown = Duration(minutes: 5);

  /// SharedPreferences key prefix
  static const _keyPrefix = 'integration_';
  static const _keySuffix = '_last_sync';

  /// Track what's currently syncing to prevent concurrent syncs
  final Set<String> _syncingNow = {};

  /// Track last failed attempt per provider (for cooldown)
  final Map<String, DateTime> _lastFailedAttempt = {};

  @override
  void build() {
    // No state to initialize
  }

  AppLogger get _logger => ref.read(appLoggerProvider);

  /// Called from ActivitiesController.build() - respects staleness.
  ///
  /// Checks all active integrations and syncs any that are stale (>4h).
  /// Failures are logged silently with a 5-minute cooldown.
  /// Returns true if any provider actually synced (not skipped).
  Future<bool> ensureIntegrationsSynced(String userId) async {
    // Hydrate integration rows from Supabase first so that, after a Drift
    // schema resync (which wipes the local DB), we restore OAuth tokens
    // before iterating providers. Without this, getActiveIntegrationsForUser
    // returns empty and the user gets silently disconnected.
    await _ensureIntegrationsRowsSynced(userId);

    final integrations = await ref
        .read(integrationsRepositoryProvider)
        .getActiveIntegrationsForUser(userId);

    if (integrations.isEmpty) return false;

    var anySynced = false;
    for (final integration in integrations) {
      final provider = integration.provider;
      final didSync = await _syncProviderIfStale(userId, provider);
      if (didSync) anySynced = true;
    }
    return anySynced;
  }

  /// Run the SyncCoordinator pass for the 'integrations' repository so any
  /// dirty local rows are pushed and any remote rows are hydrated locally.
  /// Best-effort — failures are logged inside SyncCoordinator and ignored.
  Future<void> _ensureIntegrationsRowsSynced(String userId) async {
    try {
      final repo = ref.read(integrationsRepositoryProvider);
      await ref.read(syncCoordinatorProvider.notifier).ensureSynced(
            'integrations',
            userId,
            repository: repo,
          );
    } catch (e, stackTrace) {
      _logger.warning(
        'Integration row sync failed; continuing with local data',
        context: 'INTEGRATION_SYNC',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
    }
  }

  /// Called from ActivitiesController.forceRefresh() - bypasses staleness.
  ///
  /// Syncs all active integrations regardless of when they last synced.
  Future<void> forceSyncIntegrations(String userId) async {
    final integrations = await ref
        .read(integrationsRepositoryProvider)
        .getActiveIntegrationsForUser(userId);

    if (integrations.isEmpty) return;

    for (final integration in integrations) {
      final provider = integration.provider;
      await _syncProvider(userId, provider);
    }
  }

  /// Sync a provider only if data is stale.
  /// Returns true if sync actually ran (not skipped).
  Future<bool> _syncProviderIfStale(String userId, String provider) async {
    // Dedup: skip if already syncing
    if (_syncingNow.contains(provider)) {
      if (kDebugMode) {
        print('🔄 Integration sync skipped ($provider) - already in progress');
      }
      return false;
    }

    // Cooldown: skip if recently failed
    final lastFailed = _lastFailedAttempt[provider];
    if (lastFailed != null &&
        DateTime.now().difference(lastFailed) < _failureCooldown) {
      if (kDebugMode) {
        print('🔄 Integration sync skipped ($provider) - in failure cooldown');
      }
      return false;
    }

    // Staleness: skip if recently synced
    final lastSync = await _getLastSyncTime(provider);
    if (lastSync != null &&
        DateTime.now().difference(lastSync) < _stalenessThreshold) {
      if (kDebugMode) {
        print('🔄 Integration sync skipped ($provider) - data is fresh');
      }
      return false;
    }

    await _syncProvider(userId, provider);
    return true;
  }

  /// Execute the actual sync for a provider
  Future<void> _syncProvider(String userId, String provider) async {
    // Dedup: skip if already syncing in this coordinator
    if (_syncingNow.contains(provider)) {
      if (kDebugMode) {
        print('🔄 Integration sync skipped ($provider) - already in progress');
      }
      return;
    }

    // Dedup: skip if manual sync is in progress via ConnectTrainingController
    try {
      final controller = ref.read(connectTrainingControllerProvider.notifier);
      if (controller.isSyncingProvider(provider)) {
        if (kDebugMode) {
          print('🔄 Integration sync skipped ($provider) - manual sync in progress');
        }
        return;
      }
    } catch (_) {
      // Controller may not be initialized yet - safe to proceed
    }

    _syncingNow.add(provider);

    try {
      if (kDebugMode) {
        print('🔄 Starting integration sync for $provider...');
      }

      switch (provider) {
        case 'final_surge':
          final service = ref.read(finalSurgeSyncServiceProvider);
          await service.syncWorkouts(userId);
          break;
        case 'training_peaks':
          final service =
              await ref.read(trainingPeaksSyncServiceProvider.future);
          await service.syncAll(userId);
          break;
        case 'vdot':
          final service = ref.read(vdotSyncServiceProvider);
          await service.syncWorkouts(userId);
          break;
        case 'garmin':
          // Garmin is push-only — no client-side sync needed.
          // Activities arrive via server-side push when the user syncs
          // their Garmin device.
          if (kDebugMode) {
            print('🔄 Garmin is push-only - no sync needed');
          }
          break;
        default:
          _logger.warning(
            'Unknown integration provider: $provider',
            context: 'INTEGRATION_SYNC',
          );
          return;
      }

      // Success: update timestamp, clear failure tracking
      await _setLastSyncTime(provider, DateTime.now());
      _lastFailedAttempt.remove(provider);

      // Immediately push freshly-synced dirty activities to Supabase.
      // Only applies to client-side-writing providers; Garmin is push-only
      // and writes nothing locally.
      if (provider == 'final_surge' ||
          provider == 'training_peaks' ||
          provider == 'vdot') {
        try {
          final uploadResult = await ref
              .read(activitiesRepositoryProvider)
              .uploadDirtyRecords(userId);
          if (kDebugMode) {
            if (uploadResult.success) {
              print(
                  '☁️  Integration sync uploaded ${uploadResult.count} dirty records for $provider');
            } else {
              print(
                  '⚠️  Integration sync upload had no records or failed for $provider: ${uploadResult.error}');
            }
          }
        } catch (e, stackTrace) {
          _logger.warning(
            'Post-sync upload of dirty activities failed for $provider (best-effort)',
            context: 'INTEGRATION_SYNC',
            error: e,
            stackTrace: stackTrace,
            data: {'userId': userId, 'provider': provider},
          );
          if (kDebugMode) {
            print(
                '⚠️  Integration sync upload failed for $provider (best-effort): $e');
          }
        }
      }

      if (kDebugMode) {
        print('✅ Integration sync complete for $provider');
      }
    } catch (e, stackTrace) {
      // Record failure for cooldown
      _lastFailedAttempt[provider] = DateTime.now();

      _logger.error(
        'Integration sync failed for $provider',
        context: 'INTEGRATION_SYNC',
        error: e,
        stackTrace: stackTrace,
      );

      if (kDebugMode) {
        print('❌ Integration sync failed for $provider: $e');
      }
      // Don't rethrow - silent failure
    } finally {
      _syncingNow.remove(provider);
    }
  }

  /// Record that [provider] was just synced through another path (e.g. the
  /// manual "Sync Now" / connect flow in ConnectTrainingController, which calls
  /// the sync service directly rather than going through this coordinator).
  ///
  /// Without this, a manual sync leaves the coordinator's staleness clock
  /// untouched, so the very next `ensureIntegrationsSynced` (triggered when the
  /// manual sync invalidates the calendar/activities providers and they
  /// rebuild) sees the provider as stale and runs a full SECOND sync back to
  /// back. Stamping the timestamp here makes that follow-up sync skip.
  Future<void> markProviderSynced(String provider) async {
    await _setLastSyncTime(provider, DateTime.now());
    _lastFailedAttempt.remove(provider);
  }

  /// Get the last sync time from SharedPreferences
  Future<DateTime?> _getLastSyncTime(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix${provider}$_keySuffix';
    final millis = prefs.getInt(key);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// Set the last sync time in SharedPreferences
  Future<void> _setLastSyncTime(String provider, DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix${provider}$_keySuffix';
    await prefs.setInt(key, time.millisecondsSinceEpoch);
  }
}
