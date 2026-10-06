import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../activities/data/activities_repository.dart';
import '../../../shared/services/report/report.dart';
import '../../../shared/services/sync/sync_coordinator.dart';
import '../../calendar/presentation/providers/calendar_controller.dart'
    show allEventsControllerProvider, nextUpcomingEventProvider;
import '../../events/presentation/providers/events_controller.dart'
    show eventsControllerProvider;
import '../presentation/providers/connect_training_controller.dart';
import 'final_surge_sync_service.dart';
import 'provider_event_import_service.dart';
import 'training_peaks_transformer.dart';
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

  /// Area `sync`: this coordinator's own steps are pipeline steps, so its
  /// Notes are promoted to warnings (rule D9) — intended.
  static const _area = 'sync';

  Report get _r => ref.read(reportProvider);

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

    // Dead-man clause (real-payload-corpus@v1, L-7 item 4): the sweep's own
    // alerting dies with its scheduler, so sweep freshness is watched from
    // here — the one place guaranteed to run while any athlete still syncs.
    // Fire-and-forget and best-effort END TO END: even failing to wire the
    // check (a container without app config, e.g. tests) must never fail a
    // sync.
    try {
      unawaited(ref.read(rawRetentionDeadManCheckProvider).checkDuringSync());
    } catch (e) {
      // best-effort by contract
      await _r.note(
        'raw-retention dead-man check could not be wired; skipped',
        area: _area,
        data: {'error': e.toString()},
      );
    }

    return anySynced;
  }

  /// Run the SyncCoordinator pass for the 'integrations' repository so any
  /// dirty local rows are pushed and any remote rows are hydrated locally.
  /// Best-effort — failures are logged inside SyncCoordinator and ignored.
  Future<void> _ensureIntegrationsRowsSynced(String userId) async {
    try {
      final repo = ref.read(integrationsRepositoryProvider);
      await ref
          .read(syncCoordinatorProvider.notifier)
          .ensureSynced('integrations', userId, repository: repo);
    } catch (e, stackTrace) {
      await _r.degraded(
        e,
        stackTrace: stackTrace,
        area: _area,
        message: 'integration row sync failed; continuing with local data',
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
      _r.debug(
        'integration sync skipped: already in progress',
        area: _area,
        data: {'provider': provider},
      );
      return false;
    }

    // Cooldown: skip if recently failed
    final lastFailed = _lastFailedAttempt[provider];
    if (lastFailed != null &&
        DateTime.now().difference(lastFailed) < _failureCooldown) {
      _r.debug(
        'integration sync skipped: in failure cooldown',
        area: _area,
        data: {'provider': provider},
      );
      return false;
    }

    // Staleness: skip if recently synced
    final lastSync = await _getLastSyncTime(provider);
    if (lastSync != null &&
        DateTime.now().difference(lastSync) < _stalenessThreshold) {
      _r.debug(
        'integration sync skipped: data is fresh',
        area: _area,
        data: {'provider': provider},
      );
      return false;
    }

    await _syncProvider(userId, provider);
    return true;
  }

  /// Execute the actual sync for a provider
  Future<void> _syncProvider(String userId, String provider) async {
    // Dedup: skip if already syncing in this coordinator
    if (_syncingNow.contains(provider)) {
      _r.debug(
        'integration sync skipped: already in progress',
        area: _area,
        data: {'provider': provider},
      );
      return;
    }

    // Dedup: skip if manual sync is in progress via ConnectTrainingController
    try {
      final controller = ref.read(connectTrainingControllerProvider.notifier);
      if (controller.isSyncingProvider(provider)) {
        _r.debug(
          'integration sync skipped: manual sync in progress',
          area: _area,
          data: {'provider': provider},
        );
        return;
      }
    } catch (e) {
      // Controller may not be initialized yet - safe to proceed
      await _r.note(
        'connect-training controller unavailable; sync proceeds without the manual-sync dedup',
        area: _area,
        data: {'provider': provider, 'error': e.toString()},
      );
    }

    _syncingNow.add(provider);

    try {
      _r.debug(
        'integration sync started',
        area: _area,
        data: {'provider': provider},
      );

      // Every sync service catches its own errors and reports the outcome in
      // its result object rather than throwing, so the catch block below never
      // sees an ordinary sync failure. Read `success` off the result — without
      // it a failed sync stamps a fresh timestamp, locking the provider out of
      // retries for the 4h staleness window and never arming the 5m cooldown.
      final bool succeeded;
      final String? failure;
      List<TrainingPeaksEventResult> tpEvents = const [];
      List<FinalSurgeRaceCandidate> fsRaceCandidates = const [];

      switch (provider) {
        case 'final_surge':
          final service = ref.read(finalSurgeSyncServiceProvider);
          final result = await service.syncWorkouts(userId);
          succeeded = result.success;
          failure = result.error;
          fsRaceCandidates = result.raceCandidates;
          break;
        case 'training_peaks':
          final service = await ref.read(
            trainingPeaksSyncServiceProvider.future,
          );
          final result = await service.syncAll(userId);
          succeeded = result.success;
          failure = result.workoutResult.error;
          tpEvents = result.eventResult?.events ?? const [];
          break;
        case 'vdot':
          final service = ref.read(vdotSyncServiceProvider);
          final result = await service.syncWorkouts(userId);
          succeeded = result.success;
          failure = result.error;
          break;
        case 'runna':
          final service = ref.read(runnaSyncServiceProvider);
          final result = await service.syncWorkouts(userId);
          succeeded = result.success;
          failure = result.error;
          break;
        case 'garmin':
          // Garmin is push-only — no client-side sync needed.
          // Activities arrive via server-side push when the user syncs
          // their Garmin device.
          _r.debug('Garmin is push-only; no client sync', area: _area);
          succeeded = true;
          failure = null;
          break;
        default:
          await _r.degraded(
            LoggedFault('unknown integration provider: $provider'),
            area: _area,
            message: 'integration sync skipped: unknown provider',
            extra: {'provider': provider},
          );
          return;
      }

      if (!succeeded) {
        // Arm the cooldown and leave the staleness clock untouched so the next
        // ensureIntegrationsSynced retries instead of reporting "data is fresh".
        _lastFailedAttempt[provider] = DateTime.now();
        // The service already reported the cause at its own severity; this
        // records the coordinator's decision (cooldown armed, clock untouched).
        await _r.note(
          'integration sync reported failure; cooldown armed',
          area: _area,
          data: {'provider': provider, 'error': failure},
        );
        return;
      }

      // Success: update timestamp, clear failure tracking
      await _setLastSyncTime(provider, DateTime.now());
      _lastFailedAttempt.remove(provider);

      // Persist provider events found by THIS sync. Without this the
      // background path fetched events and silently discarded them — races
      // only imported on a manual Sync Now (found live 2026-09-13; ops bug
      // tp-background-sync-discards-imported-events). Same dedupe/D-2c
      // rules as the manual path — one shared application-layer save site.
      if (tpEvents.isNotEmpty || fsRaceCandidates.isNotEmpty) {
        try {
          final importService = ref.read(providerEventImportServiceProvider);
          var imported = 0;
          if (tpEvents.isNotEmpty) {
            imported += await importService.importTrainingPeaksEvents(
              userId,
              tpEvents,
            );
          }
          if (fsRaceCandidates.isNotEmpty) {
            imported += await importService.importFinalSurgeRaceCandidates(
              userId,
              fsRaceCandidates,
            );
          }
          if (imported > 0 && ref.mounted) {
            // Events providers are future-based, not streams — refresh them
            // so an imported race appears without a manual reload.
            ref.invalidate(eventsControllerProvider);
            ref.invalidate(allEventsControllerProvider);
            ref.invalidate(nextUpcomingEventProvider);
          }
        } catch (e, stackTrace) {
          // Best-effort, but a fetched race that never lands is exactly the
          // 2026-09-13 bug this block exists to prevent.
          await _r.fault(
            e,
            stackTrace: stackTrace,
            area: _area,
            message: 'post-sync provider event import failed',
            extra: {'provider': provider},
          );
        }
      }

      // Immediately push freshly-synced dirty activities to Supabase.
      // Only applies to client-side-writing providers; Garmin is push-only
      // and writes nothing locally.
      if (provider == 'final_surge' ||
          provider == 'training_peaks' ||
          provider == 'vdot' ||
          provider == 'runna') {
        try {
          final uploadResult = await ref
              .read(activitiesRepositoryProvider)
              .uploadDirtyRecords(userId);
          if (uploadResult.success) {
            _r.debug(
              'post-sync upload of dirty activities done',
              area: _area,
              data: {'provider': provider, 'count': uploadResult.count},
            );
          } else {
            // uploadDirtyRecords swallows its exceptions into this result;
            // the result is the only place the failure surfaces.
            await _r.note(
              'post-sync upload of dirty activities reported failure',
              area: _area,
              data: {'provider': provider, 'error': uploadResult.error},
            );
          }
        } catch (e, stackTrace) {
          await _r.fault(
            e,
            stackTrace: stackTrace,
            area: _area,
            message: 'post-sync upload of dirty activities threw',
            extra: {'provider': provider},
          );
        }
      }

      _r.debug(
        'integration sync complete',
        area: _area,
        data: {'provider': provider},
      );
    } catch (e, stackTrace) {
      // Record failure for cooldown
      _lastFailedAttempt[provider] = DateTime.now();

      // Sync services report their own failures in result objects, so an
      // exception here is one that escaped that handling.
      await _r.fault(
        e,
        stackTrace: stackTrace,
        area: _area,
        message: 'integration sync threw',
        extra: {'provider': provider},
      );
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
