import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../../application/integration_sync_coordinator.dart';
import '../../application/runna_sync_service.dart';
import '../../application/training_peaks_oauth_service.dart';
import '../../application/training_peaks_sync_service.dart';
import '../../application/vdot_oauth_service.dart';
import '../../application/vdot_sync_service.dart';
import '../../data/runna_ics_client.dart';
import '../../domain/integration.dart';
import '../../domain/runna_defaults.dart';
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
    this.isRunnaConnected = false,
    this.runnaLastSyncAt,
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
  final bool isRunnaConnected;
  final DateTime? runnaLastSyncAt;
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
    bool? isRunnaConnected,
    DateTime? runnaLastSyncAt,
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
      isRunnaConnected: isRunnaConnected ?? this.isRunnaConnected,
      runnaLastSyncAt: runnaLastSyncAt ?? this.runnaLastSyncAt,
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
  RunnaSyncService get _runnaSync => ref.read(runnaSyncServiceProvider);
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

  /// Whether we have a real auth session but onboarding hasn't completed yet,
  /// meaning the public.users profile row doesn't exist in Supabase and
  /// activity uploads would fail with FK 23503.
  bool _isOnboardingInProgress = false;

  @override
  FutureOr<ConnectTrainingState> build() async {
    final database = ref.read(appDatabaseProvider);
    final supabaseClient = ref.read(appExternalDepsProvider).supabaseClient;
    final currentAuthUserId = supabaseClient.auth.currentUser?.id;

    // Capture the repository up-front, before any `await`. build() has several
    // async gaps and this auto-dispose provider can be disposed mid-build (e.g.
    // the user navigates away). Reading `ref` again after disposal throws
    // UnmountedRefException — the cause of Sentry MEALVANA-ENDURANCE-A0. Holding
    // a plain reference lets the remaining work finish without touching `ref`.
    final integrationsRepo = ref.read(integrationsRepositoryProvider);

    // Same reasoning for SharedPreferences: it's needed by helpers further
    // below (_getOrCreateTempUserId, _shouldTriggerGarminBackfill,
    // _markGarminBackfillTriggered) that only run after several more
    // `await`s. Those helpers used to call `ref.read(sharedPreferencesProvider)`
    // themselves, which threw UnmountedRefException once the provider was
    // disposed mid-build (Sentry MEALVANA-ENDURANCE-DEV-5J). Capture it here
    // and thread it through as a parameter instead.
    final SharedPreferences prefs = ref.read(sharedPreferencesProvider);

    // Get user profile for current auth session
    // Returns null if no auth session or no matching profile
    final user = await database.userDao.getCurrentUserProfile(
      currentAuthUserId: currentAuthUserId,
    );

    // Guard the first async gap: `getCurrentUserProfile` above can outlive
    // this auto-dispose provider (onboarding syncs invalidate it), and the
    // `ref.read(userIdProvider.future)` below throws UnmountedRefException on
    // a stale ref (Sentry MEALVANA-ENDURANCE-AV family).
    if (!ref.mounted) return const ConnectTrainingState();

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

    // If the user already has a REAL (non-anonymous) Supabase session, use their
    // real user id for onboarding data too — don't fall back to a throwaway temp
    // id. The temp id is only meant for truly anonymous onboarding (no session),
    // where the temp->real migration at sign-in later rebases the data. For an
    // already-signed-in user that migration has already run, so temp-id data
    // never gets rebased: integration upserts fail the `integrations` RLS/FK
    // (user_id must equal auth.uid) and imported activities stay invisible
    // because the rest of the app reads under the real id. (Root cause of the
    // 42501 "violates row-level security" upload error + missing imported
    // workouts during onboarding.)
    final isAnonymousSession =
        supabaseClient.auth.currentUser?.isAnonymous ?? false;
    if (!useRealUserId &&
        candidateRealUserId != null &&
        currentAuthUserId != null &&
        !isAnonymousSession) {
      useRealUserId = true;
    }

    // If onboarding flag is false/missing but integrations already exist for this
    // user, prefer real ID so connection state remains stable across sessions.
    if (!useRealUserId && candidateRealUserId != null) {
      final existingIntegrations = await integrationsRepo
          .getIntegrationsForUser(candidateRealUserId);
      useRealUserId = existingIntegrations.isNotEmpty;
    }

    if (useRealUserId && candidateRealUserId != null) {
      _currentUserId = candidateRealUserId;
      _isUsingTempUserId = false;
    } else if (currentAuthUserId != null) {
      // An (anonymous) Supabase session exists — onboarding before the profile
      // is created/sign-up is completed. Use the anonymous auth.uid rather than
      // a throwaway client-generated temp UUID. An anonymous session has a real
      // auth.uid(), so:
      //   - integration + activity uploads pass RLS (user_id == auth.uid), and
      //   - the first-class anonymous->real migration at sign-in rebases the
      //     data (vs. the brittle temp-UUID->real fallback path).
      // A throwaway temp UUID can NEVER upload (RLS rejects it) and is only
      // rebased by the temp->real migration, so anything written under it is
      // invisible everywhere except this device until/unless that migration
      // runs. Reserve the temp UUID strictly for the genuine no-session case
      // below.
      _currentUserId = currentAuthUserId;
      _isUsingTempUserId = false;
    } else {
      _currentUserId = await _getOrCreateTempUserId(prefs);
      _isUsingTempUserId = true;
    }

    _isOnboardingInProgress =
        !_isUsingTempUserId && (user?.onboardingCompleted != true);

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

    // If the provider was disposed during the async work above, bail out with a
    // default (all-disconnected) state rather than continuing to query and
    // rebuild for a controller nobody is listening to.
    if (!ref.mounted) return const ConnectTrainingState();

    // Check for existing integrations (may exist from previous onboarding attempt)
    final finalSurgeIntegration = await integrationsRepo.getIntegration(
      _currentUserId!,
      'final_surge',
    );
    final trainingPeaksIntegration = await integrationsRepo.getIntegration(
      _currentUserId!,
      'training_peaks',
    );
    final garminIntegration = await integrationsRepo.getIntegration(
      _currentUserId!,
      'garmin',
    );
    final vdotIntegration = await integrationsRepo.getIntegration(
      _currentUserId!,
      'vdot',
    );
    final runnaIntegration = await integrationsRepo.getIntegration(
      _currentUserId!,
      'runna',
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
        _shouldTriggerGarminBackfill(prefs)) {
      _garminBackfillTriggeredThisSession = true;
      // Stamp the cooldown immediately (before the async work) so concurrent
      // rebuilds and hot restarts within the window don't each fire again.
      unawaited(_markGarminBackfillTriggered(prefs));
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
      isRunnaConnected: runnaIntegration?.isActive ?? false,
      runnaLastSyncAt: runnaIntegration?.lastSyncAt,
    );
  }

  /// Whether enough time has passed since the last automatic Garmin backfill
  /// to fire another one. Backed by a persisted timestamp so the cooldown
  /// survives controller disposal/rebuild and hot restarts (see
  /// [_garminBackfillTriggeredThisSession] for why an in-memory flag isn't
  /// sufficient).
  ///
  /// [prefs] must be captured by the caller before any `await` in build() —
  /// this is called after several prior async gaps (the `getIntegration`
  /// lookups above), so reading `ref.read(sharedPreferencesProvider)` at this
  /// point throws UnmountedRefException if the provider was disposed
  /// mid-build (Sentry MEALVANA-ENDURANCE-DEV-5J).
  bool _shouldTriggerGarminBackfill(SharedPreferences prefs) {
    final userId = _currentUserId;
    if (userId == null) return false;
    final lastMs = prefs.getInt('$_garminBackfillLastAtKeyPrefix$userId');
    if (lastMs == null) return true;
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    return DateTime.now().difference(last) >= _garminBackfillCooldown;
  }

  /// Persist the current time as the last automatic Garmin backfill timestamp.
  ///
  /// [prefs] must be captured by the caller before any `await` in build() —
  /// see [_shouldTriggerGarminBackfill] for why (Sentry
  /// MEALVANA-ENDURANCE-DEV-5J).
  Future<void> _markGarminBackfillTriggered(SharedPreferences prefs) async {
    final userId = _currentUserId;
    if (userId == null) return;
    await prefs.setInt(
      '$_garminBackfillLastAtKeyPrefix$userId',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Get or create a temporary user ID for use during onboarding
  /// This ID will be migrated to the real user ID when onboarding completes
  ///
  /// [prefs] must be captured by the caller before any `await` in build() —
  /// this method runs after several prior async gaps (auth/user-id
  /// resolution above), so reading `ref.read(sharedPreferencesProvider)` at
  /// this point risks UnmountedRefException if the provider was disposed
  /// mid-build (Sentry MEALVANA-ENDURANCE-DEV-5J).
  Future<String> _getOrCreateTempUserId(SharedPreferences prefs) async {
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

  /// Report an integration failure to Sentry in addition to the state/
  /// snackbar surface — connect/import failures used to reach only
  /// DebugLogger/kDebugMode prints (onboarding redesign §6: no silent
  /// failures). Never throws; guarded against provider disposal.
  void _reportFailureToSentry(
    String provider,
    String phase,
    Object error,
    StackTrace stackTrace,
  ) {
    if (!ref.mounted) return;
    try {
      unawaited(
        ref
            .read(appExternalDepsProvider)
            .sentry
            .reportCriticalError(
              error,
              stackTrace: stackTrace,
              context: 'connect_training',
              tags: {
                'feature': 'integrations',
                'provider': provider,
                'phase': phase,
              },
            ),
      );
    } catch (_) {
      // Reporting must never cascade into a second failure.
    }
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

      // OAuth easily outlives this auto-dispose provider (user backgrounds
      // the app / navigates away). The integration row is already persisted
      // by the service — just skip the state/analytics updates rather than
      // throwing UnmountedRefException (Sentry MEALVANA-ENDURANCE-AV family).
      if (!ref.mounted) return true;

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
      _reportFailureToSentry(providerId, 'connect', e, stackTrace);
      if (ref.mounted) {
        state = AsyncData(
          state.value!.copyWith(
            isConnecting: false,
            clearConnectingProvider: true,
            errorMessage: e.toString(),
          ),
        );
      }
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
      // The disconnect await is an async gap on an auto-dispose provider —
      // writing state through a stale ref throws UnmountedRefException
      // (Sentry MEALVANA-ENDURANCE-AV family). The disconnect itself already
      // persisted; only the (now-invisible) UI update is skipped.
      if (!ref.mounted) return;
      state = AsyncData(updateState());
      _trackIntegrationDisconnected(providerId, reason: 'user_initiated');
    } catch (e, stackTrace) {
      _reportFailureToSentry(providerId, 'disconnect', e, stackTrace);
      if (ref.mounted) {
        state = AsyncData(
          state.value!.copyWith(errorMessage: 'Failed to disconnect: $e'),
        );
      }
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

  /// Connect Garmin.
  ///
  /// [isOnboarding] must be `true` when called from the onboarding flow: at that
  /// point the user's `users` row does not exist yet (it's created when
  /// onboarding is finalized), so writing `garmin_user_mappings` now would
  /// FK-violate `garmin_user_mappings_user_id_fkey` and the edge function
  /// returns 500 (Sentry MEALVANA-ENDURANCE-AF). The mapping is instead deferred
  /// to onboarding completion (`upsertUserMapping`, via
  /// `_syncGarminMappingIfNeeded`). From settings the row already exists, so the
  /// mapping is written immediately.
  Future<bool> connectGarmin({bool isOnboarding = false}) async {
    return _connectProvider(
      providerId: 'garmin',
      authenticate: () => _garminOAuth.authenticate(
        _currentUserId!,
        skipRemoteMapping: _isUsingTempUserId || isOnboarding,
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
    // This is invoked from build()'s fire-and-forget kick via
    // `Future<void>(() async { await triggerGarminBackfill(); })`, which runs
    // in a later microtask — by the time it executes, the controller may
    // already have been disposed (e.g. the user navigated away). Bail out
    // before touching `ref` at all rather than crashing with
    // UnmountedRefException (Sentry MEALVANA-ENDURANCE-DEV-5J family).
    if (!ref.mounted) return false;
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
        if (_isTransientBackfillFailure(response.status, '${response.data}')) {
          await _scheduleGarminBackfillRetrySoon();
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
        // Guard against invalidating after this controller has been disposed
        // (Sentry MEALVANA-ENDURANCE-A0 UnmountedRefException family) — the
        // 5s/15s delays easily outlive a screen the user navigated away from.
        if (ref.mounted && _currentUserId != null) {
          ref.invalidate(garminLastBodyCompProvider(_currentUserId!));
        }
        await Future.delayed(const Duration(seconds: 15));
        if (ref.mounted && _currentUserId != null) {
          ref.invalidate(garminLastBodyCompProvider(_currentUserId!));
        }
      });

      return true;
    } catch (e, st) {
      // Garmin's backfill API is frequently flaky: it returns 502 (Bad gateway)
      // and 429-style "rate limit quota violation" responses that are transient
      // and self-heal. Treat those calmly — they're expected, not a code fault —
      // and let the next app session retry soon instead of blocking for the full
      // cooldown (the data never got queued, so waiting 6h would needlessly delay
      // the user's weight/body-fat backfill). Genuinely unexpected errors keep
      // the full stack trace.
      final transient = _isTransientBackfillFailure(null, '$e');
      if (kDebugMode) {
        if (transient) {
          print(
            '[syncGarmin] backfill temporarily unavailable '
            '(Garmin 502/rate-limit) — will retry next session: $e',
          );
        } else {
          print('[syncGarmin] backfill invoke failed: $e\n$st');
        }
      }
      if (transient) {
        await _scheduleGarminBackfillRetrySoon();
      }
      return false;
    }
  }

  /// Whether a failed Garmin backfill is a transient/server-side condition
  /// (gateway 502, 503, or 429 rate-limit) worth retrying soon rather than a
  /// hard failure. Matched on status when available, else the error text.
  bool _isTransientBackfillFailure(int? status, String message) {
    if (status == 502 || status == 503 || status == 429) return true;
    final m = message.toLowerCase();
    return m.contains('502') ||
        m.contains('503') ||
        m.contains('429') ||
        m.contains('bad gateway') ||
        m.contains('rate limit') ||
        m.contains('too many request');
  }

  /// Roll the persisted backfill cooldown back so the next app session retries
  /// after a short delay (~30 min) instead of waiting the full cooldown. Used
  /// only on transient failures — the in-session guard
  /// ([_garminBackfillTriggeredThisSession]) still prevents re-firing within
  /// the current session, so this can't spam Garmin.
  Future<void> _scheduleGarminBackfillRetrySoon() async {
    // Called from triggerGarminBackfill() after an `await` (the backfill
    // network call) — by the time we get here the controller may have been
    // disposed (fire-and-forget path from build()). Guard before touching
    // `ref` (Sentry MEALVANA-ENDURANCE-DEV-5J family).
    if (!ref.mounted) return;
    final userId = _currentUserId;
    if (userId == null) return;
    const retryDelay = Duration(minutes: 30);
    if (retryDelay >= _garminBackfillCooldown) return;
    final prefs = ref.read(sharedPreferencesProvider);
    final retryAt = DateTime.now().subtract(
      _garminBackfillCooldown - retryDelay,
    );
    await prefs.setInt(
      '$_garminBackfillLastAtKeyPrefix$userId',
      retryAt.millisecondsSinceEpoch,
    );
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
      //
      // Always attempt the upload for a real (non-temp) user — even when this
      // sync produced no new/updated workouts. A *previous* sync may have
      // inserted rows whose upload failed (network/RLS/missing-remote-user),
      // leaving them dirty. Gating the upload on newWorkouts/updated would never
      // retry those, stranding them local-only: visible on this device but
      // missing from Supabase (and therefore from other devices / after a
      // reinstall). uploadDirtyRecords() pushes ALL dirty rows, so it doubles as
      // the retry path. (Temp users can't pass RLS, so they're skipped and rely
      // on the post-sign-in migration + sync to upload.)
      var uploadFailed = false;
      if (!_isUsingTempUserId) {
        try {
          final uploadResult = await _activitiesRepo.uploadDirtyRecords(
            _currentUserId!,
          );
          // success covers both a real upload and "nothing to upload" (count 0).
          uploadFailed = !uploadResult.success;
          if (kDebugMode) {
            if (uploadResult.success) {
              print('☁️ Uploaded ${uploadResult.count} synced VDOT activities');
            } else {
              print('⚠️ VDOT activity upload failed: ${uploadResult.error}');
            }
          }
        } catch (e) {
          uploadFailed = true;
          if (kDebugMode) {
            print('⚠️ Failed to upload synced VDOT activities: $e');
          }
        }
      }

      // Record this manual sync in the coordinator's staleness clock BEFORE
      // invalidating providers below — otherwise the activities controller
      // rebuilds, calls ensureIntegrationsSynced, sees vdot as stale, and runs
      // an immediate duplicate full sync.
      //
      // EXCEPTION: if the upload failed, deliberately do NOT stamp the clock.
      // The rows are still dirty; leaving vdot "stale" lets the next
      // ensureIntegrationsSynced re-run the sync and retry the upload promptly
      // (instead of waiting out the full staleness window). The coordinator
      // stamps its own clock once that retry completes, so this can't storm.
      //
      // Re-check `ref.mounted` here: the `uploadDirtyRecords` await above is
      // another async gap since the last check, and reading `ref` after
      // disposal throws UnmountedRefException (same pattern as
      // MEALVANA-ENDURANCE-DEV-5J).
      if (!uploadFailed && ref.mounted) {
        await ref
            .read(integrationSyncCoordinatorProvider.notifier)
            .markProviderSynced('vdot');
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
          // Surface an upload failure instead of swallowing it: the workouts
          // are saved locally but did NOT reach Supabase, so they'd silently go
          // missing on other devices / after reinstall. Keep it non-alarming —
          // the retry above will pick them up.
          errorMessage: uploadFailed
              ? 'Workouts saved, but syncing to your account didn\'t finish. '
                    'We\'ll retry automatically.'
              : null,
          clearErrorMessage: !uploadFailed,
          vdotLastSyncAt: DateTime.now(),
        ),
      );

      _trackIntegrationSyncSuccess(
        'vdot',
        result.newWorkouts,
        skippedCount: result.skipped,
      );
      return result;
    } catch (e, stackTrace) {
      if (ref.mounted) {
        state = AsyncData(
          state.value!.copyWith(
            isImporting: false,
            clearSyncingProvider: true,
            errorMessage: 'Failed to import workouts: $e',
          ),
        );
      }
      _reportFailureToSentry('vdot', 'import', e, stackTrace);
      _trackIntegrationSyncFailed(
        'vdot',
        'exception',
        errorMessage: e.toString(),
      );
      return VdotSyncResult.error(e.toString());
    } finally {
      _syncingProviders.remove('vdot');
    }
  }

  /// Connect Runna via its calendar-subscription (.ics) URL.
  ///
  /// No OAuth — the user pastes the link from Runna app → Settings →
  /// Calendar sync. URL-shape validation is deliberately permissive; the real
  /// validation is an initial fetch+parse of the feed ([RunnaSyncService.probeFeed]).
  ///
  /// Integration-row storage choice (documented here, at the creation site):
  /// the feed URL is stored in the row's `accessToken` field — it IS the
  /// credential (the token is embedded in the URL), it's the closest existing
  /// slot, and it gets the same Supabase backup treatment as every other
  /// provider secret. `providerAthleteId` (required text, but Runna's feed
  /// carries no athlete identity) is 'runna-' + a short stable hash of the
  /// URL.
  Future<bool> connectRunna(String feedUrl) async {
    if (_currentUserId == null) {
      if (kDebugMode) {
        print('❌ connectRunna: No current user ID');
      }
      return false;
    }

    state = AsyncData(
      state.value!.copyWith(
        isConnecting: true,
        connectingProvider: 'runna',
        clearErrorMessage: true,
      ),
    );

    try {
      _trackIntegrationConnectStarted('runna');

      final normalized = RunnaIcsClient.normalizeFeedUrl(feedUrl);
      final uri = Uri.tryParse(normalized);
      final looksLikeFeed =
          uri != null &&
          uri.host.isNotEmpty &&
          (uri.isScheme('https') || uri.isScheme('http'));
      if (!looksLikeFeed) {
        throw const FormatException(
          'That doesn\'t look like a calendar link. '
          '${RunnaDefaults.feedUrlInstructions}',
        );
      }

      // Real validation: the URL must actually serve parseable ICS. Zero
      // events is fine (a fresh plan may be empty); non-ICS content throws.
      await _runnaSync.probeFeed(normalized);

      final integrationsRepo = ref.read(integrationsRepositoryProvider);
      await integrationsRepo.upsertIntegration(
        IntegrationModel(
          userId: _currentUserId!,
          provider: 'runna',
          // Feed URL in accessToken — see method docs.
          accessToken: normalized,
          providerAthleteId:
              'runna-${RunnaSyncService.stableFeedFingerprint(normalized)}',
          isActive: true,
        ),
      );

      if (!ref.mounted) return true;

      state = AsyncData(
        state.value!.copyWith(
          isConnecting: false,
          clearConnectingProvider: true,
          isRunnaConnected: true,
        ),
      );
      _trackIntegrationConnectSuccess('runna');
      return true;
    } on FormatException catch (e) {
      if (ref.mounted) {
        state = AsyncData(
          state.value!.copyWith(
            isConnecting: false,
            clearConnectingProvider: true,
            errorMessage: e.message,
          ),
        );
      }
      _trackIntegrationConnectFailed(
        'runna',
        'invalid_url',
        errorMessage: e.message,
      );
      return false;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ connectRunna: $e');
      }
      _reportFailureToSentry('runna', 'connect', e, stackTrace);
      if (ref.mounted) {
        state = AsyncData(
          state.value!.copyWith(
            isConnecting: false,
            clearConnectingProvider: true,
            errorMessage: e.toString(),
          ),
        );
      }
      _trackIntegrationConnectFailed(
        'runna',
        'feed_validation_error',
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<void> disconnectRunna() async {
    await _disconnectProvider(
      providerId: 'runna',
      // Delete (not just deactivate) so the stored feed URL is removed both
      // locally and from Supabase — a reconnect always starts from a freshly
      // pasted link.
      disconnect: () => ref
          .read(integrationsRepositoryProvider)
          .deleteIntegration(_currentUserId!, 'runna'),
      updateState: () => state.value!.copyWith(isRunnaConnected: false),
    );
  }

  /// Sync workouts from the Runna calendar feed into the local activities
  /// table. Mirrors [importVdotWorkouts]: local-first writes during sync, then
  /// an immediate uploadDirtyRecords push (result CHECKED — it swallows
  /// failures into UploadResult.failed) to avoid the duplicate-on-relogin
  /// trap.
  Future<RunnaSyncResult> importRunnaWorkouts() async {
    if (_currentUserId == null) {
      return RunnaSyncResult.error('Missing user ID');
    }
    if (_syncingProviders.contains('runna')) {
      if (kDebugMode) {
        print('⚠️ runna sync already in progress, skipping');
      }
      return const RunnaSyncResult(success: true);
    }
    _syncingProviders.add('runna');

    state = AsyncData(
      state.value!.copyWith(
        isImporting: true,
        syncingProvider: 'runna',
        importProgress: 0.0,
        clearErrorMessage: true,
        isNetworkError: false,
      ),
    );

    try {
      _trackIntegrationConnectStarted('runna');
      final result = await _runnaSync.syncWorkouts(_currentUserId!);

      if (!ref.mounted) return result;

      if (!result.success) {
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
            'runna',
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
          'runna',
          result.errorType.name,
          errorMessage: result.error,
        );
        return result;
      }

      // Upload dirty activities to Supabase immediately so duplicates don't
      // appear after logout/relogin/resync. Always attempt for a real user —
      // uploadDirtyRecords doubles as the retry path for rows a previous sync
      // left dirty. (Same reasoning as the VDOT path; see importVdotWorkouts.)
      var uploadFailed = false;
      if (!_isUsingTempUserId) {
        try {
          final uploadResult = await _activitiesRepo.uploadDirtyRecords(
            _currentUserId!,
          );
          uploadFailed = !uploadResult.success;
          if (kDebugMode) {
            if (uploadResult.success) {
              print(
                '☁️ Uploaded ${uploadResult.count} synced Runna activities',
              );
            } else {
              print('⚠️ Runna activity upload failed: ${uploadResult.error}');
            }
          }
        } catch (e) {
          uploadFailed = true;
          if (kDebugMode) {
            print('⚠️ Failed to upload synced Runna activities: $e');
          }
        }
      }

      // Stamp the coordinator's staleness clock BEFORE invalidating providers
      // so the rebuild doesn't kick a duplicate sync — but only when the
      // upload succeeded, so a failed upload retries promptly. (Same pattern
      // as VDOT; see importVdotWorkouts for the full reasoning.)
      if (!uploadFailed && ref.mounted) {
        await ref
            .read(integrationSyncCoordinatorProvider.notifier)
            .markProviderSynced('runna');
      }

      if (!ref.mounted) return result;

      state = AsyncData(state.value!.copyWith(importProgress: 0.8));
      _invalidateCalendar();

      state = AsyncData(
        state.value!.copyWith(
          isImporting: false,
          clearSyncingProvider: true,
          importProgress: 1.0,
          importedWorkoutsCount: result.newWorkouts,
          isNetworkError: false,
          errorMessage: uploadFailed
              ? 'Workouts saved, but syncing to your account didn\'t finish. '
                    'We\'ll retry automatically.'
              : null,
          clearErrorMessage: !uploadFailed,
          runnaLastSyncAt: DateTime.now(),
        ),
      );

      _trackIntegrationSyncSuccess(
        'runna',
        result.newWorkouts,
        skippedCount: result.skipped,
      );
      return result;
    } catch (e, stackTrace) {
      if (ref.mounted) {
        state = AsyncData(
          state.value!.copyWith(
            isImporting: false,
            clearSyncingProvider: true,
            errorMessage: 'Failed to import workouts: $e',
          ),
        );
      }
      _reportFailureToSentry('runna', 'import', e, stackTrace);
      _trackIntegrationSyncFailed(
        'runna',
        'exception',
        errorMessage: e.toString(),
      );
      return RunnaSyncResult.error(e.toString());
    } finally {
      _syncingProviders.remove('runna');
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
        if (_isUsingTempUserId || _isOnboardingInProgress) {
          if (kDebugMode) {
            print(
              '⏸️ Skipping Supabase activity upload during onboarding (${_isUsingTempUserId ? "temp user ID" : "profile not yet uploaded"})',
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

      // Re-check `ref.mounted`: the `uploadDirtyRecords` await above is
      // another async gap since the last check, and both the event-save
      // helpers below and `markProviderSynced` read `ref` — doing so after
      // disposal throws UnmountedRefException (same pattern as
      // MEALVANA-ENDURANCE-DEV-5J).
      if (!ref.mounted) return result;

      // Handle provider-specific event creation
      int savedEventsCount = 0;
      final raceCandidates = getRaceCandidates?.call(result);
      final eventData = getEventData?.call(result);

      if (raceCandidates != null && raceCandidates.isNotEmpty) {
        savedEventsCount = await _saveRaceCandidates(raceCandidates);
      } else if (eventData != null && eventData.isNotEmpty) {
        savedEventsCount = await _saveTrainingPeaksEvents(eventData);
      }

      // Re-check again: the event-save helpers above have their own internal
      // awaits (one per candidate/event), another gap since the check above.
      if (!ref.mounted) return result;

      // Record this manual sync in the coordinator's staleness clock BEFORE
      // invalidating providers — otherwise the activities controller rebuilds,
      // calls ensureIntegrationsSynced, sees this provider as stale, and runs
      // an immediate duplicate full sync.
      await ref
          .read(integrationSyncCoordinatorProvider.notifier)
          .markProviderSynced(providerId);

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
    } catch (e, stackTrace) {
      if (ref.mounted) {
        state = AsyncData(
          state.value!.copyWith(
            isImporting: false,
            clearSyncingProvider: true,
            errorMessage: 'Failed to import workouts: $e',
          ),
        );
      }
      _reportFailureToSentry(providerId, 'import', e, stackTrace);
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
    // Guard against disposal during the `_connectProvider` await above
    // (UnmountedRefException family — same pattern as MEALVANA-ENDURANCE-DEV-5J).
    if (connected && ref.mounted) {
      final prefs = ref.read(preferencesServiceProvider);
      await prefs.setTpWritebackPremiumBlocked(false);
      if (ref.mounted) {
        ref.invalidate(preferencesServiceProvider);
      }
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
    if (state.value?.isRunnaConnected == true) {
      final result = await importRunnaWorkouts();
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
