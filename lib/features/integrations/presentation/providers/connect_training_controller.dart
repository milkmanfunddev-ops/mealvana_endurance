import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/database/database_provider.dart';
import '../../../../shared/providers/user_id_provider.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/analytics/analytics_events.dart';
import '../../../../shared/services/preferences_service.dart';
import '../../../activities/data/activities_repository.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../../../daily_macros/presentation/providers/daily_macros_controller.dart';
import '../../../calendar/presentation/providers/calendar_controller.dart';
import '../../../events/data/events_repository.dart';
import '../../../events/domain/event.dart' as domain;
import '../../../events/presentation/providers/events_controller.dart'
    hide nextUpcomingEventProvider;
import '../../application/final_surge_oauth_service.dart';
import '../../application/final_surge_sync_service.dart';
import '../../application/garmin_oauth_service.dart';
import '../../application/training_peaks_oauth_service.dart';
import '../../application/training_peaks_sync_service.dart';
import '../../application/vdot_oauth_service.dart';
import '../../application/vdot_sync_service.dart';
import '../../data/integrations_repository.dart';
import 'integrations_providers.dart';

part 'connect_training_controller.g.dart';

/// Key for storing temporary user ID in shared preferences during onboarding
const _tempUserIdKey = 'onboarding_temp_user_id';

/// Wrapper class for TrainingPeaks combined sync result
/// Used internally to adapt the combined result to the generic _importWorkouts helper
class _TPCombinedResultWrapper {
  _TPCombinedResultWrapper(this.fullResult);
  _TPCombinedResultWrapper.error(TrainingPeaksSyncResult workoutResult)
    : fullResult = TrainingPeaksFullSyncResult(
        workoutResult: workoutResult,
        eventResult: null,
      );

  final TrainingPeaksFullSyncResult fullResult;
}

/// State for the Connect Training screen
class ConnectTrainingState {
  const ConnectTrainingState({
    this.isFinalSurgeConnected = false,
    this.finalSurgeAthleteName,
    this.finalSurgeLastSyncAt,
    this.isTrainingPeaksConnected = false,
    this.trainingPeaksAthleteName,
    this.trainingPeaksLastSyncAt,
    this.isGarminConnected = false,
    this.garminAthleteName,
    this.isVdotConnected = false,
    this.vdotAthleteName,
    this.vdotLastSyncAt,
    this.isConnecting = false,
    this.connectingProvider,
    this.importedWorkoutsCount = 0,
    this.isImporting = false,
    this.syncingProvider,
    this.importProgress = 0.0,
    this.errorMessage,
    this.hasNextEvent = false,
    this.nextEventName,
    this.finalSurgeNeedsReauth = false,
    this.trainingPeaksNeedsReauth = false,
    this.isNetworkError = false,
  });

  final bool isFinalSurgeConnected;
  final String? finalSurgeAthleteName;
  final DateTime? finalSurgeLastSyncAt;
  final bool isTrainingPeaksConnected;
  final String? trainingPeaksAthleteName;
  final DateTime? trainingPeaksLastSyncAt;
  final bool isGarminConnected;
  final String? garminAthleteName;
  final bool isVdotConnected;
  final String? vdotAthleteName;
  final DateTime? vdotLastSyncAt;
  final bool isConnecting;
  final String? connectingProvider;
  final int importedWorkoutsCount;
  final bool isImporting;

  /// Which provider is currently syncing ('final_surge' or 'training_peaks')
  final String? syncingProvider;

  final double importProgress;
  final String? errorMessage;
  final bool hasNextEvent;
  final String? nextEventName;

  /// True if Final Surge tokens expired and user needs to reconnect
  final bool finalSurgeNeedsReauth;

  /// True if TrainingPeaks tokens expired and user needs to reconnect
  final bool trainingPeaksNeedsReauth;

  /// True if the last error was a network error (transient, can retry)
  final bool isNetworkError;

  /// Creates a copy of this state with specified fields replaced.
  ///
  /// Note: For nullable fields that need to be explicitly cleared to null,
  /// use the corresponding `clear*` parameter (e.g., `clearSyncingProvider: true`).
  ConnectTrainingState copyWith({
    bool? isFinalSurgeConnected,
    String? finalSurgeAthleteName,
    DateTime? finalSurgeLastSyncAt,
    bool? isTrainingPeaksConnected,
    String? trainingPeaksAthleteName,
    DateTime? trainingPeaksLastSyncAt,
    bool? isGarminConnected,
    String? garminAthleteName,
    bool clearGarminAthleteName = false,
    bool? isVdotConnected,
    String? vdotAthleteName,
    bool clearVdotAthleteName = false,
    DateTime? vdotLastSyncAt,
    bool? isConnecting,
    String? connectingProvider,
    bool clearConnectingProvider = false,
    int? importedWorkoutsCount,
    bool? isImporting,
    String? syncingProvider,
    bool clearSyncingProvider = false,
    double? importProgress,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? hasNextEvent,
    String? nextEventName,
    bool? finalSurgeNeedsReauth,
    bool? trainingPeaksNeedsReauth,
    bool? isNetworkError,
  }) {
    return ConnectTrainingState(
      isFinalSurgeConnected:
          isFinalSurgeConnected ?? this.isFinalSurgeConnected,
      finalSurgeAthleteName:
          finalSurgeAthleteName ?? this.finalSurgeAthleteName,
      finalSurgeLastSyncAt: finalSurgeLastSyncAt ?? this.finalSurgeLastSyncAt,
      isTrainingPeaksConnected:
          isTrainingPeaksConnected ?? this.isTrainingPeaksConnected,
      trainingPeaksAthleteName:
          trainingPeaksAthleteName ?? this.trainingPeaksAthleteName,
      trainingPeaksLastSyncAt:
          trainingPeaksLastSyncAt ?? this.trainingPeaksLastSyncAt,
      isGarminConnected: isGarminConnected ?? this.isGarminConnected,
      garminAthleteName: clearGarminAthleteName
          ? null
          : (garminAthleteName ?? this.garminAthleteName),
      isVdotConnected: isVdotConnected ?? this.isVdotConnected,
      vdotAthleteName: clearVdotAthleteName
          ? null
          : (vdotAthleteName ?? this.vdotAthleteName),
      vdotLastSyncAt: vdotLastSyncAt ?? this.vdotLastSyncAt,
      isConnecting: isConnecting ?? this.isConnecting,
      connectingProvider: clearConnectingProvider
          ? null
          : (connectingProvider ?? this.connectingProvider),
      importedWorkoutsCount:
          importedWorkoutsCount ?? this.importedWorkoutsCount,
      isImporting: isImporting ?? this.isImporting,
      syncingProvider: clearSyncingProvider
          ? null
          : (syncingProvider ?? this.syncingProvider),
      importProgress: importProgress ?? this.importProgress,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      hasNextEvent: hasNextEvent ?? this.hasNextEvent,
      nextEventName: nextEventName ?? this.nextEventName,
      finalSurgeNeedsReauth:
          finalSurgeNeedsReauth ?? this.finalSurgeNeedsReauth,
      trainingPeaksNeedsReauth:
          trainingPeaksNeedsReauth ?? this.trainingPeaksNeedsReauth,
      isNetworkError: isNetworkError ?? this.isNetworkError,
    );
  }
}

@riverpod
class ConnectTrainingController extends _$ConnectTrainingController {
  FinalSurgeOAuthService get _finalSurgeOAuth =>
      ref.read(finalSurgeOAuthServiceProvider);
  FinalSurgeSyncService get _finalSurgeSync =>
      ref.read(finalSurgeSyncServiceProvider);
  Future<TrainingPeaksOAuthService> get _trainingPeaksOAuth =>
      ref.read(trainingPeaksOAuthServiceProvider.future);
  Future<TrainingPeaksSyncService> get _trainingPeaksSync =>
      ref.read(trainingPeaksSyncServiceProvider.future);
  GarminOAuthService get _garminOAuth => ref.read(garminOAuthServiceProvider);
  VdotOAuthService get _vdotOAuth => ref.read(vdotOAuthServiceProvider);
  VdotSyncService get _vdotSync => ref.read(vdotSyncServiceProvider);
  IntegrationsRepository get _integrationsRepo =>
      ref.read(integrationsRepositoryProvider);
  ActivitiesRepository get _activitiesRepo =>
      ref.read(activitiesRepositoryProvider);
  static const _uuid = Uuid();

  /// Prevents concurrent sync operations from causing duplicate inserts.
  /// Shared across both manual and automatic sync paths.
  final Set<String> _syncingProviders = {};

  /// Instance-scoped flag: have we already kicked a Garmin backfill on this
  /// controller instance? Garmin's Health API is push-only, so on app open
  /// we proactively ask Garmin to re-push the last 90 days of body comp +
  /// user metrics.
  ///
  /// This flag alone is NOT enough: this controller is `@riverpod`
  /// (autoDispose), so every rebuild after disposal — and every hot restart —
  /// creates a fresh instance with the flag reset to false. Left unguarded,
  /// that fires a fresh backfill (2 Garmin requests) on each rebuild and trips
  /// Garmin's "100 requests / minute" rate limit. The durable guard is the
  /// persisted cooldown timestamp below ([_shouldTriggerGarminBackfill]).
  bool _garminBackfillTriggeredThisSession = false;

  /// SharedPreferences key prefix (suffixed with the user ID) recording the
  /// last time we auto-triggered a Garmin backfill. Survives controller
  /// rebuilds and hot restarts so the cooldown actually holds.
  static const _garminBackfillLastAtKeyPrefix = 'garmin_backfill_last_at_';

  /// Minimum spacing between automatic Garmin backfills. Body comp / user
  /// metrics change slowly and a 90-day backfill is heavy, so once every few
  /// hours is plenty. The manual "refresh from Garmin" path is not throttled.
  static const _garminBackfillCooldown = Duration(hours: 6);

  String? _currentUserId;

  /// Whether we're using a temporary user ID (during onboarding before profile creation)
  bool _isUsingTempUserId = false;

  @override
  FutureOr<ConnectTrainingState> build() async {
    final database = ref.read(appDatabaseProvider);
    final supabaseClient = ref.read(appExternalDepsProvider).supabaseClient;
    final currentAuthUserId = supabaseClient.auth.currentUser?.id;

    // Get user profile for current auth session
    // Returns null if no auth session or no matching profile
    final user = await database.userDao.getCurrentUserProfile(
      currentAuthUserId: currentAuthUserId,
    );

    // Resolve canonical user ID from auth session when possible.
    // This avoids false "Connect" states after relogin when local profile
    // hydration lags behind auth restoration.
    String? resolvedUserIdFromAuth;
    if (currentAuthUserId != null) {
      // Start with auth ID so we can proceed even if provider resolution stalls.
      resolvedUserIdFromAuth = currentAuthUserId;
      try {
        resolvedUserIdFromAuth = await ref
            .read(userIdProvider.future)
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        // Fall back to temp ID logic below.
      }
    }

    final candidateRealUserId = user?.id ?? resolvedUserIdFromAuth;
    var useRealUserId = user?.onboardingCompleted == true;

    // If onboarding flag is false/missing but integrations already exist for this
    // user, prefer real ID so connection state remains stable across sessions.
    if (!useRealUserId && candidateRealUserId != null) {
      final existingIntegrations = await _integrationsRepo
          .getIntegrationsForUser(candidateRealUserId);
      useRealUserId = existingIntegrations.isNotEmpty;
    }

    if (useRealUserId && candidateRealUserId != null) {
      _currentUserId = candidateRealUserId;
      _isUsingTempUserId = false;
    } else {
      _currentUserId = await _getOrCreateTempUserId();
      _isUsingTempUserId = true;
    }

    if (kDebugMode) {
      print(
        '🔑 ConnectTrainingController: Using ${_isUsingTempUserId ? 'temp' : 'real'} user ID: $_currentUserId',
      );
      print(
        '   (user profile exists: ${user != null}, onboardingCompleted: ${user?.onboardingCompleted})',
      );
      print(
        '   (auth user: $currentAuthUserId, resolved user: $resolvedUserIdFromAuth)',
      );
    }

    // Check for existing integrations (may exist from previous onboarding attempt)
    final finalSurgeIntegration = await _integrationsRepo.getIntegration(
      _currentUserId!,
      'final_surge',
    );
    final trainingPeaksIntegration = await _integrationsRepo.getIntegration(
      _currentUserId!,
      'training_peaks',
    );
    final garminIntegration = await _integrationsRepo.getIntegration(
      _currentUserId!,
      'garmin',
    );
    final vdotIntegration = await _integrationsRepo.getIntegration(
      _currentUserId!,
      'vdot',
    );

    final isGarminActive = garminIntegration?.isActive ?? false;

    // Fire-and-forget a Garmin backfill on the first build of each app
    // session when Garmin is connected. Without this, weight/body fat
    // changes the user made in Garmin Connect won't show up until their
    // device organically syncs — which may be hours away. We don't await
    // it because Garmin replies 202 and the data lands later via webhook.
    if (isGarminActive &&
        !_garminBackfillTriggeredThisSession &&
        !_isUsingTempUserId &&
        _shouldTriggerGarminBackfill()) {
      _garminBackfillTriggeredThisSession = true;
      // Stamp the cooldown immediately (before the async work) so concurrent
      // rebuilds and hot restarts within the window don't each fire again.
      unawaited(_markGarminBackfillTriggered());
      Future<void>(() async {
        await triggerGarminBackfill();
      });
    }

    return ConnectTrainingState(
      isFinalSurgeConnected: finalSurgeIntegration?.isActive ?? false,
      finalSurgeAthleteName: finalSurgeIntegration?.providerAthleteName,
      finalSurgeLastSyncAt: finalSurgeIntegration?.lastSyncAt,
      isTrainingPeaksConnected: trainingPeaksIntegration?.isActive ?? false,
      trainingPeaksAthleteName: trainingPeaksIntegration?.providerAthleteName,
      trainingPeaksLastSyncAt: trainingPeaksIntegration?.lastSyncAt,
      isGarminConnected: isGarminActive,
      garminAthleteName: garminIntegration?.providerAthleteName,
      isVdotConnected: vdotIntegration?.isActive ?? false,
      vdotAthleteName: vdotIntegration?.providerAthleteName,
      vdotLastSyncAt: vdotIntegration?.lastSyncAt,
    );
  }

  /// Whether enough time has passed since the last automatic Garmin backfill
  /// to fire another one. Backed by a persisted timestamp so the cooldown
  /// survives controller disposal/rebuild and hot restarts (see
  /// [_garminBackfillTriggeredThisSession] for why an in-memory flag isn't
  /// sufficient).
  bool _shouldTriggerGarminBackfill() {
    final userId = _currentUserId;
    if (userId == null) return false;
    final prefs = ref.read(sharedPreferencesProvider);
    final lastMs = prefs.getInt('$_garminBackfillLastAtKeyPrefix$userId');
    if (lastMs == null) return true;
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    return DateTime.now().difference(last) >= _garminBackfillCooldown;
  }

  /// Persist the current time as the last automatic Garmin backfill timestamp.
  Future<void> _markGarminBackfillTriggered() async {
    final userId = _currentUserId;
    if (userId == null) return;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(
      '$_garminBackfillLastAtKeyPrefix$userId',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Get or create a temporary user ID for use during onboarding
  /// This ID will be migrated to the real user ID when onboarding completes
  Future<String> _getOrCreateTempUserId() async {
    final prefs = ref.read(sharedPreferencesProvider);

    // Check if we already have a temp user ID from a previous session
    var tempUserId = prefs.getString(_tempUserIdKey);

    if (tempUserId == null) {
      // Generate a new temp user ID
      tempUserId = _uuid.v4();
      await prefs.setString(_tempUserIdKey, tempUserId);

      if (kDebugMode) {
        print('🆕 Generated new temp user ID for onboarding: $tempUserId');
      }
    } else if (kDebugMode) {
      print('♻️ Reusing existing temp user ID: $tempUserId');
    }

    return tempUserId;
  }

  /// Get the current user ID (real or temporary)
  /// This is exposed so the OnboardingController can use it for migration
  String? get currentUserId => _currentUserId;

  /// Whether we're using a temporary user ID
  bool get isUsingTempUserId => _isUsingTempUserId;

  /// Whether a sync is currently in progress for the given provider.
  /// Used by IntegrationSyncCoordinator to avoid concurrent syncs.
  bool isSyncingProvider(String provider) =>
      _syncingProviders.contains(provider);

  /// Clear the temporary user ID after successful migration
  Future<void> clearTempUserId() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_tempUserIdKey);

    if (kDebugMode) {
      print('🧹 Cleared temp user ID from preferences');
    }
  }

  /// Generic provider connection helper to reduce duplication
  Future<bool> _connectProvider({
    required String providerId,
    required Future<dynamic> Function() authenticate,
    required ConnectTrainingState Function(String? athleteName) updateState,
  }) async {
    if (_currentUserId == null) {
      if (kDebugMode) {
        print('❌ connect$providerId: No current user ID');
      }
      return false;
    }

    if (kDebugMode) {
      print(
        '🔌 connect$providerId: Starting connection for user $_currentUserId',
      );
    }

    state = AsyncData(
      state.value!.copyWith(
        isConnecting: true,
        connectingProvider: providerId,
        clearErrorMessage: true,
      ),
    );

    try {
      _trackIntegrationConnectStarted(providerId);
      final integration = await authenticate();

      if (kDebugMode) {
        print('✅ connect$providerId: Authentication successful');
        print('   Athlete Name: ${integration.providerAthleteName}');
        print('   Is Active: ${integration.isActive}');
      }

      state = AsyncData(updateState(integration.providerAthleteName));

      if (kDebugMode) {
        print('✅ connect$providerId: State updated - connected=true');
      }

      _trackIntegrationConnectSuccess(
        providerId,
        athleteName: integration.providerAthleteName,
      );
      return true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ connect$providerId: Error occurred');
        print('   Error: $e');
        print('   Stack: $stackTrace');
      }
      state = AsyncData(
        state.value!.copyWith(
          isConnecting: false,
          clearConnectingProvider: true,
          errorMessage: e.toString(),
        ),
      );
      _trackIntegrationConnectFailed(
        providerId,
        'authentication_error',
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> connectFinalSurge() async {
    return _connectProvider(
      providerId: 'final_surge',
      authenticate: () => _finalSurgeOAuth.authenticate(_currentUserId!),
      updateState: (athleteName) => state.value!.copyWith(
        isConnecting: false,
        clearConnectingProvider: true,
        isFinalSurgeConnected: true,
        finalSurgeAthleteName: athleteName,
      ),
    );
  }

  /// Generic provider disconnect helper to reduce duplication
  Future<void> _disconnectProvider({
    required String providerId,
    required Future<void> Function() disconnect,
    required ConnectTrainingState Function() updateState,
  }) async {
    if (_currentUserId == null) return;
    try {
      await disconnect();
      state = AsyncData(updateState());
      _trackIntegrationDisconnected(providerId, reason: 'user_initiated');
    } catch (e) {
      state = AsyncData(
        state.value!.copyWith(errorMessage: 'Failed to disconnect: $e'),
      );
    }
  }

  Future<void> disconnectFinalSurge() async {
    await _disconnectProvider(
      providerId: 'final_surge',
      disconnect: () => _finalSurgeOAuth.disconnect(_currentUserId!),
      updateState: () => state.value!.copyWith(
        isFinalSurgeConnected: false,
        finalSurgeAthleteName: null,
      ),
    );
  }

  Future<bool> connectGarmin() async {
    return _connectProvider(
      providerId: 'garmin',
      authenticate: () => _garminOAuth.authenticate(
        _currentUserId!,
        skipRemoteMapping: _isUsingTempUserId,
      ),
      updateState: (athleteName) => state.value!.copyWith(
        isConnecting: false,
        clearConnectingProvider: true,
        isGarminConnected: true,
        garminAthleteName: athleteName,
      ),
    );
  }

  Future<void> disconnectGarmin() async {
    await _disconnectProvider(
      providerId: 'garmin',
      disconnect: () => _garminOAuth.disconnect(_currentUserId!),
      updateState: () => state.value!.copyWith(
        isGarminConnected: false,
        clearGarminAthleteName: true,
      ),
    );
  }

  /// Trigger Garmin's backfill API to retroactively push body composition +
  /// user metrics (VO2 max, fitness age) into our `garmin-push` webhook.
  ///
  /// Garmin's Health API is push-only with no pull endpoint — without
  /// backfill, weight from a manual Garmin Connect entry sits on Garmin's
  /// side until the user's device organically syncs and triggers a push.
  /// This call asks Garmin to deliver the last 90 days of body comp +
  /// user metrics to us right now.
  ///
  /// Returns true if at least one summary type was queued successfully.
  /// Returns false (and surfaces an error via snackbar in the caller) on
  /// auth failure / network error / Garmin refusal.
  Future<bool> triggerGarminBackfill() async {
    final supabaseClient = ref.read(appExternalDepsProvider).supabaseClient;
    final session = supabaseClient.auth.currentSession;
    final supabaseAccessToken = session?.accessToken;
    if (supabaseAccessToken == null || supabaseAccessToken.isEmpty) {
      if (kDebugMode) {
        print('[syncGarmin] No Supabase session; cannot trigger backfill');
      }
      return false;
    }

    try {
      final response = await supabaseClient.functions.invoke(
        'garmin-backfill',
        headers: {'Authorization': 'Bearer $supabaseAccessToken'},
        body: {
          'summary_types': ['body_composition', 'user_metrics'],
          'window_days': 90,
        },
      );

      if (response.status < 200 || response.status >= 300) {
        if (kDebugMode) {
          print(
            '[syncGarmin] backfill HTTP ${response.status}: ${response.data}',
          );
        }
        return false;
      }

      final data = response.data;
      final success = data is Map && data['success'] == true;
      if (!success) {
        if (kDebugMode) {
          print('[syncGarmin] backfill returned no success flag: $data');
        }
        return false;
      }

      // Garmin pushes the requested data asynchronously to our webhook.
      // Invalidate the Supabase-backed body-comp provider so any consumers
      // (Preferences auto-fill, Nutrition Diary attribution, body comp
      // breakdown) re-read once the push lands. We give Garmin a few
      // seconds to deliver before invalidating, then again after a longer
      // delay in case the first push was slow.
      Future<void>(() async {
        await Future.delayed(const Duration(seconds: 5));
        if (_currentUserId != null) {
          ref.invalidate(garminLastBodyCompProvider(_currentUserId!));
        }
        await Future.delayed(const Duration(seconds: 15));
        if (_currentUserId != null) {
          ref.invalidate(garminLastBodyCompProvider(_currentUserId!));
        }
      });

      return true;
    } catch (e, st) {
      if (kDebugMode) {
        print('[syncGarmin] backfill invoke failed: $e\n$st');
      }
      return false;
    }
  }

  Future<bool> connectVdot() async {
    return _connectProvider(
      providerId: 'vdot',
      authenticate: () => _vdotOAuth.authenticate(_currentUserId!),
      updateState: (athleteName) => state.value!.copyWith(
        isConnecting: false,
        clearConnectingProvider: true,
        isVdotConnected: true,
        vdotAthleteName: athleteName,
      ),
    );
  }

  Future<void> disconnectVdot() async {
    await _disconnectProvider(
      providerId: 'vdot',
      disconnect: () => _vdotOAuth.disconnect(_currentUserId!),
      updateState: () => state.value!.copyWith(
        isVdotConnected: false,
        clearVdotAthleteName: true,
      ),
    );
  }

  /// Sync workouts from V.O2 into the local activities table.
  ///
  /// Mirrors the FS / TP sync flow: uses the shared `_importWorkouts`
  /// pipeline only loosely (VDOT's result shape diverges enough that we
  /// inline the state management), and pushes dirty rows to Supabase
  /// immediately after sync to avoid the duplicate-on-relogin trap.
  Future<VdotSyncResult> importVdotWorkouts() async {
    if (_currentUserId == null) {
      return VdotSyncResult.error('Missing user ID');
    }
    if (_syncingProviders.contains('vdot')) {
      if (kDebugMode) {
        print('⚠️ vdot sync already in progress, skipping');
      }
      return const VdotSyncResult(success: true);
    }
    _syncingProviders.add('vdot');

    state = AsyncData(
      state.value!.copyWith(
        isImporting: true,
        syncingProvider: 'vdot',
        importProgress: 0.0,
        clearErrorMessage: true,
        isNetworkError: false,
      ),
    );

    try {
      _trackIntegrationConnectStarted('vdot');
      final result = await _vdotSync.syncWorkouts(_currentUserId!);

      if (!ref.mounted) return result;

      if (!result.success) {
        if (result.needsReauth) {
          // Don't flip isVdotConnected to false here — the DB integration
          // row is still active (sync service only updated last_sync_status
          // to 'requires_reauth'). Flipping the in-memory bool would create
          // a mismatch between the visible button state ("Connect") and the
          // DB state, so navigating away and back would revert to "Sync Now".
          // Just surface the error and let the user manually disconnect if
          // they actually need to re-OAuth.
          state = AsyncData(
            state.value!.copyWith(
              isImporting: false,
              clearSyncingProvider: true,
              errorMessage: result.summary,
            ),
          );
          _trackIntegrationSyncFailed(
            'vdot',
            'token_expired',
            errorMessage: 'Requires re-authentication',
          );
          return result;
        }
        if (result.isNetworkError) {
          state = AsyncData(
            state.value!.copyWith(
              isImporting: false,
              clearSyncingProvider: true,
              isNetworkError: true,
              errorMessage: result.summary,
            ),
          );
          _trackIntegrationSyncFailed(
            'vdot',
            'network_error',
            errorMessage: result.error,
          );
          return result;
        }
        state = AsyncData(
          state.value!.copyWith(
            isImporting: false,
            clearSyncingProvider: true,
            errorMessage: result.error ?? 'Failed to import workouts',
          ),
        );
        _trackIntegrationSyncFailed(
          'vdot',
          result.errorType.name,
          errorMessage: result.error,
        );
        return result;
      }

      // Upload dirty activities to Supabase immediately so duplicates don't
      // appear after logout/relogin/resync (same pattern as FS/TP).
      if ((result.newWorkouts > 0 || result.updated > 0) && !_isUsingTempUserId) {
        try {
          final uploadResult =
              await _activitiesRepo.uploadDirtyRecords(_currentUserId!);
          if (kDebugMode) {
            if (uploadResult.success) {
              print('☁️ Uploaded ${uploadResult.count} synced VDOT activities');
            } else {
              print('⚠️ VDOT activity upload failed: ${uploadResult.error}');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Failed to upload synced VDOT activities: $e');
          }
        }
      }

      state = AsyncData(state.value!.copyWith(importProgress: 0.8));
      _invalidateCalendar();

      state = AsyncData(
        state.value!.copyWith(
          isImporting: false,
          clearSyncingProvider: true,
          importProgress: 1.0,
          importedWorkoutsCount: result.newWorkouts,
          isNetworkError: false,
          clearErrorMessage: true,
          vdotLastSyncAt: DateTime.now(),
        ),
      );

      _trackIntegrationSyncSuccess(
        'vdot',
        result.newWorkouts,
        skippedCount: result.skipped,
      );
      return result;
    } catch (e) {
      if (ref.mounted) {
        state = AsyncData(
          state.value!.copyWith(
            isImporting: false,
            clearSyncingProvider: true,
            errorMessage: 'Failed to import workouts: $e',
          ),
        );
      }
      _trackIntegrationSyncFailed('vdot', 'exception', errorMessage: e.toString());
      return VdotSyncResult.error(e.toString());
    } finally {
      _syncingProviders.remove('vdot');
    }
  }

  /// Generic workout import helper to reduce duplication
  Future<T> _importWorkouts<T>({
    required String providerId,
    required Future<T> Function() syncWorkouts,
    required bool Function(T result) checkSuccess,
    required bool Function(T result) checkNeedsReauth,
    required bool Function(T result)? checkIsNetworkError,
    required String? Function(T result) getError,
    required String Function(T result) getSummary,
    required String Function(T result) getErrorType,
    required List<dynamic> Function(T result) getActivities,
    required int Function(T result) getNewWorkouts,
    required int Function(T result) getUpdated,
    required int Function(T result) getSkipped,
    required List<dynamic> Function(T result)? getRaceCandidates,
    required List<dynamic> Function(T result)? getEventData,
    required T Function(String error) createError,
  }) async {
    if (_currentUserId == null) {
      return createError('Missing user ID');
    }

    // Prevent concurrent syncs that could cause duplicate inserts
    if (_syncingProviders.contains(providerId)) {
      if (kDebugMode) {
        print('⚠️ $providerId sync already in progress, skipping');
      }
      return createError(''); // Return successful empty result
    }
    _syncingProviders.add(providerId);

    state = AsyncData(
      state.value!.copyWith(
        isImporting: true,
        syncingProvider: providerId,
        importProgress: 0.0,
        clearErrorMessage: true,
        isNetworkError: false,
      ),
    );

    try {
      _trackIntegrationConnectStarted(providerId); // Sync started
      final result = await syncWorkouts();

      // Check if still mounted after async operation
      if (!ref.mounted) return result;

      // Handle different error types
      if (!checkSuccess(result)) {
        if (checkNeedsReauth(result)) {
          // Token expired - user must reconnect
          final stateUpdate = providerId == 'final_surge'
              ? state.value!.copyWith(
                  isImporting: false,
                  clearSyncingProvider: true,
                  finalSurgeNeedsReauth: true,
                  isFinalSurgeConnected: false,
                  errorMessage: getSummary(result),
                )
              : state.value!.copyWith(
                  isImporting: false,
                  clearSyncingProvider: true,
                  trainingPeaksNeedsReauth: true,
                  isTrainingPeaksConnected: false,
                  errorMessage: getSummary(result),
                );
          state = AsyncData(stateUpdate);
          _trackIntegrationSyncFailed(
            providerId,
            'token_expired',
            errorMessage: 'Requires re-authentication',
          );
          return result;
        }

        if (checkIsNetworkError != null && checkIsNetworkError(result)) {
          // Network error - user can retry
          state = AsyncData(
            state.value!.copyWith(
              isImporting: false,
              clearSyncingProvider: true,
              isNetworkError: true,
              errorMessage: getSummary(result),
            ),
          );
          _trackIntegrationSyncFailed(
            providerId,
            'network_error',
            errorMessage: getError(result),
          );
          return result;
        }

        // Other error
        state = AsyncData(
          state.value!.copyWith(
            isImporting: false,
            clearSyncingProvider: true,
            errorMessage: getError(result) ?? 'Failed to import workouts',
          ),
        );
        _trackIntegrationSyncFailed(
          providerId,
          getErrorType(result),
          errorMessage: getError(result),
        );
        return result;
      }

      // Activities are saved during sync - users will generate nutrition plans manually
      // by tapping activities in the calendar
      final activities = getActivities(result);
      if (kDebugMode && activities.isNotEmpty) {
        print(
          '📋 Synced ${activities.length} activities (nutrition plans will be created manually)',
        );
      }

      // CRITICAL: Upload dirty activities to Supabase immediately after sync.
      // This prevents duplicates on logout→login→re-sync because remote
      // hydration will find the activities in Supabase.
      final newWorkouts = getNewWorkouts(result);
      final updated = getUpdated(result);
      if (newWorkouts > 0 || updated > 0) {
        if (_isUsingTempUserId) {
          if (kDebugMode) {
            print(
              '⏸️ Skipping Supabase activity upload during onboarding (temp user ID)',
            );
          }
        } else {
          try {
            final uploadResult = await _activitiesRepo.uploadDirtyRecords(
              _currentUserId!,
            );
            if (kDebugMode) {
              if (uploadResult.success) {
                print(
                  '☁️ Uploaded ${uploadResult.count} synced activities to Supabase',
                );
              } else {
                print('⚠️ Upload to Supabase failed: ${uploadResult.error}');
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Failed to upload synced activities: $e');
            }
          }
        }
      }

      // Handle provider-specific event creation
      int savedEventsCount = 0;
      final raceCandidates = getRaceCandidates?.call(result);
      final eventData = getEventData?.call(result);

      if (raceCandidates != null && raceCandidates.isNotEmpty) {
        savedEventsCount = await _saveRaceCandidates(raceCandidates);
      } else if (eventData != null && eventData.isNotEmpty) {
        savedEventsCount = await _saveTrainingPeaksEvents(eventData);
      }

      // Invalidate calendar to refresh UI
      state = AsyncData(state.value!.copyWith(importProgress: 0.8));
      _invalidateCalendar();

      final stateUpdate = providerId == 'final_surge'
          ? state.value!.copyWith(
              isImporting: false,
              clearSyncingProvider: true,
              importProgress: 1.0,
              importedWorkoutsCount: newWorkouts,
              finalSurgeNeedsReauth: false,
              isNetworkError: false,
              clearErrorMessage: true,
            )
          : state.value!.copyWith(
              isImporting: false,
              clearSyncingProvider: true,
              importProgress: 1.0,
              importedWorkoutsCount: newWorkouts,
              trainingPeaksNeedsReauth: false,
              isNetworkError: false,
              clearErrorMessage: true,
            );
      state = AsyncData(stateUpdate);

      _trackIntegrationSyncSuccess(
        providerId,
        newWorkouts,
        skippedCount: getSkipped(result),
        eventsCount: savedEventsCount,
      );
      return result;
    } catch (e) {
      if (ref.mounted) {
        state = AsyncData(
          state.value!.copyWith(
            isImporting: false,
            clearSyncingProvider: true,
            errorMessage: 'Failed to import workouts: $e',
          ),
        );
      }
      _trackIntegrationSyncFailed(
        providerId,
        'exception',
        errorMessage: e.toString(),
      );
      return createError(e.toString());
    } finally {
      _syncingProviders.remove(providerId);
    }
  }

  /// Save Final Surge race candidates as events
  Future<int> _saveRaceCandidates(List<dynamic> raceCandidates) async {
    int savedEventsCount = 0;
    final eventsRepository = ref.read(eventsRepositoryProvider);

    for (final candidate in raceCandidates) {
      final activityId = candidate.activityId;
      if (activityId == null || activityId.isEmpty) {
        continue;
      }

      // Skip if an event already exists for this activity
      final existingByActivity = await eventsRepository.getEventForActivity(
        activityId,
      );
      if (existingByActivity != null) {
        continue;
      }

      final eventName = candidate.eventName.trim().isNotEmpty
          ? candidate.eventName
          : 'Race';
      final existingByName = await eventsRepository.findExistingEvent(
        userId: _currentUserId!,
        eventName: eventName,
        eventDate: candidate.scheduledAt,
      );
      if (existingByName != null) {
        continue;
      }

      try {
        final now = DateTime.now();
        await eventsRepository.createEvent(
          deviceId: _currentUserId!,
          event: domain.Event(
            id: '', // Let DB auto-generate
            userId: _currentUserId!,
            activityId: activityId,
            eventType: candidate.eventType,
            eventName: eventName,
            eventDate: candidate.scheduledAt,
            startTime: candidate.scheduledAt.toIso8601String(),
            goalTimeMinutes: candidate.goalTimeMinutes,
            goalPaceMinutesPerMile: candidate.goalPaceMinutesPerMile,
            createdAt: now,
            updatedAt: now,
          ),
        );
        savedEventsCount++;
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to save Final Surge race event: $e');
        }
      }
    }

    return savedEventsCount;
  }

  /// Save TrainingPeaks events
  Future<int> _saveTrainingPeaksEvents(List<dynamic> eventData) async {
    int savedEventsCount = 0;
    int skippedEventsCount = 0;
    final eventsRepository = ref.read(eventsRepositoryProvider);

    for (final event in eventData) {
      if (kDebugMode) {
        print('💾 Checking TrainingPeaks event: ${event.eventName}');
      }

      // Check for existing event (same user + name + date) to prevent duplicates
      final existingEvent = await eventsRepository.findExistingEvent(
        userId: _currentUserId!,
        eventName: event.eventName,
        eventDate: event.eventDate,
      );

      if (existingEvent != null) {
        skippedEventsCount++;
        if (kDebugMode) {
          print('   ⏭️ Event already exists, skipping: ${event.eventName}');
        }
        continue;
      }

      try {
        final now = DateTime.now();
        final savedEvent = await eventsRepository.createEvent(
          deviceId: _currentUserId!,
          event: domain.Event(
            id: '', // Let DB auto-generate
            userId: _currentUserId!,
            eventType: event.activityType,
            eventSubtype: null,
            eventName: event.eventName,
            eventDate: event.eventDate,
            startTime: event.eventDate.toIso8601String(),
            goalTimeMinutes: event.goalTimeHours != null
                ? (event.goalTimeHours! * 60).round()
                : null,
            createdAt: now,
            updatedAt: now,
          ),
        );
        savedEventsCount++;
        if (kDebugMode) {
          print('✅ Event saved with ID: ${savedEvent.id}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to save event: $e');
        }
      }
    }

    if (kDebugMode) {
      print(
        '✅ Event sync complete: $savedEventsCount new, $skippedEventsCount existing',
      );
    }

    return savedEventsCount;
  }

  Future<SyncResult> importFinalSurgeWorkouts() async {
    return _importWorkouts<SyncResult>(
      providerId: 'final_surge',
      syncWorkouts: () => _finalSurgeSync.syncWorkouts(_currentUserId!),
      checkSuccess: (result) => result.success,
      checkNeedsReauth: (result) => result.needsReauth,
      checkIsNetworkError: (result) => result.isNetworkError,
      getError: (result) => result.error,
      getSummary: (result) => result.summary,
      getErrorType: (result) => result.errorType.name,
      getActivities: (result) => result.activities,
      getNewWorkouts: (result) => result.newWorkouts,
      getUpdated: (result) => result.updated,
      getSkipped: (result) => result.skipped,
      getRaceCandidates: (result) => result.raceCandidates,
      getEventData: null,
      createError: (error) => SyncResult.error(error),
    );
  }

  Future<bool> connectTrainingPeaks() async {
    final connected = await _connectProvider(
      providerId: 'training_peaks',
      authenticate: () async {
        final oauthService = await _trainingPeaksOAuth;
        return oauthService.authenticate(_currentUserId!);
      },
      updateState: (athleteName) => state.value!.copyWith(
        isConnecting: false,
        clearConnectingProvider: true,
        isTrainingPeaksConnected: true,
        trainingPeaksAthleteName: athleteName,
      ),
    );

    // Clear stale local block state when TP OAuth succeeds.
    // We will re-apply the block later only if TP confirms non-premium.
    if (connected) {
      final prefs = ref.read(preferencesServiceProvider);
      await prefs.setTpWritebackPremiumBlocked(false);
      ref.invalidate(preferencesServiceProvider);
    }

    return connected;
  }

  Future<void> disconnectTrainingPeaks() async {
    await _disconnectProvider(
      providerId: 'training_peaks',
      disconnect: () async {
        final oauthService = await _trainingPeaksOAuth;
        await oauthService.disconnect(_currentUserId!);
      },
      updateState: () => state.value!.copyWith(
        isTrainingPeaksConnected: false,
        trainingPeaksAthleteName: null,
        hasNextEvent: false,
        nextEventName: null,
      ),
    );
  }

  Future<TrainingPeaksSyncResult> importTrainingPeaksWorkouts() async {
    if (_currentUserId == null) {
      return TrainingPeaksSyncResult.error('Missing user ID');
    }

    final syncService = await _trainingPeaksSync;

    // Use a wrapper class to handle the combined result from TrainingPeaks
    final _TPCombinedResultWrapper combinedResult =
        await _importWorkouts<_TPCombinedResultWrapper>(
          providerId: 'training_peaks',
          syncWorkouts: () async {
            final result = await syncService.syncAll(_currentUserId!);
            return _TPCombinedResultWrapper(result);
          },
          checkSuccess: (wrapper) => wrapper.fullResult.workoutResult.success,
          checkNeedsReauth: (wrapper) =>
              wrapper.fullResult.workoutResult.tokenExpired,
          checkIsNetworkError: null,
          getError: (wrapper) => wrapper.fullResult.workoutResult.error,
          getSummary: (wrapper) => wrapper.fullResult.workoutResult.summary,
          getErrorType: (wrapper) => 'sync_error',
          getActivities: (wrapper) =>
              wrapper.fullResult.workoutResult.activities,
          getNewWorkouts: (wrapper) =>
              wrapper.fullResult.workoutResult.newWorkouts,
          getUpdated: (wrapper) => wrapper.fullResult.workoutResult.updated,
          getSkipped: (wrapper) => wrapper.fullResult.workoutResult.unchanged,
          getRaceCandidates: null,
          getEventData: (wrapper) =>
              wrapper.fullResult.eventResult?.hasEvent ?? false
              ? wrapper.fullResult.eventResult!.events
              : [],
          createError: (error) => _TPCombinedResultWrapper.error(
            TrainingPeaksSyncResult.error(error),
          ),
        );

    return combinedResult.fullResult.workoutResult;
  }

  /// Invalidate calendar and activities providers to refresh UI
  void _invalidateCalendar() {
    if (!ref.mounted) return;

    try {
      // Invalidate activities controller to refresh the main list
      ref.invalidate(activitiesControllerProvider);
      // Invalidate daily macros (activities changed → stale macro cache)
      ref.invalidate(dailyMacrosControllerProvider);
      // Invalidate calendar providers
      ref.invalidate(calendarControllerProvider);
      ref.invalidate(allEventsControllerProvider);
      ref.invalidate(nextUpcomingEventProvider);
      // Invalidate events providers (events list screen watches these)
      ref.invalidate(eventsControllerProvider);
      ref.invalidate(allEventsProvider);
      if (kDebugMode) {
        print(
          '🔄 Activities, calendar, events, and daily macros providers invalidated',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to invalidate providers: $e');
      }
    }
  }

  Future<int> importWorkouts() async {
    if (state.value?.isFinalSurgeConnected == true) {
      final result = await importFinalSurgeWorkouts();
      return result.newWorkouts;
    }
    if (state.value?.isTrainingPeaksConnected == true) {
      final result = await importTrainingPeaksWorkouts();
      return result.newWorkouts;
    }
    if (state.value?.isVdotConnected == true) {
      final result = await importVdotWorkouts();
      return result.newWorkouts;
    }
    return 0;
  }

  void trackNotifyMe({required String provider, required String source}) {
    if (!ref.mounted) return;
    try {
      final deps = ref.read(appExternalDepsProvider);
      deps.analytics.track(
        'integration_notify_requested',
        properties: {
          'provider': provider,
          'source': source,
          'device_id': _currentUserId ?? 'unknown',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {}
  }

  void trackSkip() {
    if (!ref.mounted) return;
    try {
      final deps = ref.read(appExternalDepsProvider);
      deps.analytics.track(
        'integration_connect_skipped',
        properties: {
          'device_id': _currentUserId ?? 'unknown',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {}
  }

  /// Helper to get analytics tracker with device ID
  /// Uses _currentUserId which is set from the database user profile
  void _trackIntegrationConnectStarted(String provider) {
    if (!ref.mounted) return;
    try {
      final deps = ref.read(appExternalDepsProvider);
      deps.analytics.trackIntegrationConnectStarted(
        provider: provider,
        deviceId: _currentUserId ?? 'unknown',
      );
    } catch (_) {}
  }

  void _trackIntegrationConnectSuccess(String provider, {String? athleteName}) {
    if (!ref.mounted) return;
    try {
      final deps = ref.read(appExternalDepsProvider);
      deps.analytics.trackIntegrationConnectSuccess(
        provider: provider,
        deviceId: _currentUserId ?? 'unknown',
        athleteName: athleteName,
      );
    } catch (_) {}
  }

  void _trackIntegrationConnectFailed(
    String provider,
    String errorType, {
    String? errorMessage,
  }) {
    if (!ref.mounted) return;
    try {
      final deps = ref.read(appExternalDepsProvider);
      deps.analytics.trackIntegrationConnectFailed(
        provider: provider,
        deviceId: _currentUserId ?? 'unknown',
        errorType: errorType,
        errorMessage: errorMessage,
      );
    } catch (_) {}
  }

  void _trackIntegrationDisconnected(String provider, {String? reason}) {
    if (!ref.mounted) return;
    try {
      final deps = ref.read(appExternalDepsProvider);
      deps.analytics.trackIntegrationDisconnected(
        provider: provider,
        deviceId: _currentUserId ?? 'unknown',
        reason: reason,
      );
    } catch (_) {}
  }

  void _trackIntegrationSyncSuccess(
    String provider,
    int workoutsSynced, {
    int? skippedCount,
    int? eventsCount,
  }) {
    if (!ref.mounted) return;
    try {
      final deps = ref.read(appExternalDepsProvider);
      deps.analytics.trackIntegrationSyncSuccess(
        provider: provider,
        deviceId: _currentUserId ?? 'unknown',
        workoutsSynced: workoutsSynced,
        skippedCount: skippedCount,
        eventsCount: eventsCount,
      );
    } catch (_) {}
  }

  void _trackIntegrationSyncFailed(
    String provider,
    String errorType, {
    String? errorMessage,
  }) {
    if (!ref.mounted) return;
    try {
      final deps = ref.read(appExternalDepsProvider);
      deps.analytics.trackIntegrationSyncFailed(
        provider: provider,
        deviceId: _currentUserId ?? 'unknown',
        errorType: errorType,
        errorMessage: errorMessage,
      );
    } catch (_) {}
  }
}
