import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;
import 'package:uuid/uuid.dart';

import '../../../../shared/database/database_provider.dart';
import '../../../../shared/providers/user_id_provider.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/device_info_service.dart';
import '../../../../shared/services/analytics/analytics_events.dart';
import '../../../../shared/services/analytics/analytics_tracker.dart';
import '../../../../shared/services/preferences_service.dart';
import '../../../../shared/services/report/report.dart';
import '../../../activities/data/activities_repository.dart';
import '../../../daily_macros/data/daily_macro_targets_repository.dart';
import 'tp_writeback_providers.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../../../daily_macros/presentation/providers/daily_macros_controller.dart';
import '../../../calendar/presentation/providers/calendar_controller.dart';
import '../../../events/presentation/providers/events_controller.dart'
    hide nextUpcomingEventProvider;
import '../../application/final_surge_oauth_service.dart';
import '../../application/final_surge_sync_service.dart';
import '../../application/provider_event_import_service.dart';
import '../../application/training_peaks_transformer.dart';
import '../../application/garmin_oauth_service.dart';
import '../../application/integration_sync_coordinator.dart';
import '../../application/runna_sync_service.dart';
import '../../application/training_peaks_oauth_service.dart';
import '../../application/training_peaks_sync_service.dart';
import '../../application/vdot_oauth_service.dart';
import '../../application/vdot_sync_service.dart';
import '../../data/integrations_repository.dart';
import '../../data/runna_ics_client.dart';
import '../../domain/integration.dart';
import '../../domain/integration_exceptions.dart';
import '../../../onboarding/presentation/providers/onboarding_controller.dart';
import '../../domain/runna_defaults.dart';
import 'integrations_providers.dart';

part 'connect_training_controller.g.dart';

/// Key for storing temporary user ID in shared preferences during onboarding
const _tempUserIdKey = 'onboarding_temp_user_id';

/// True when garmin-backfill answered that the athlete's Garmin token is dead
/// (409, `code: garmin_reauth_required`; see
/// `supabase/functions/garmin-backfill/outcome.ts`). [details] is the decoded
/// response body: a map for JSON, else the raw text.
bool isGarminReauthRequired(int status, Object? details) {
  if (status != 409) return false;
  if (details is Map) return details['code'] == 'garmin_reauth_required';
  return '$details'.contains('garmin_reauth_required');
}

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
    this.errorProvider,
    this.hasNextEvent = false,
    this.nextEventName,
    this.finalSurgeNeedsReauth = false,
    this.trainingPeaksNeedsReauth = false,
    this.vdotNeedsReauth = false,
    this.garminNeedsReauth = false,
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

  /// Ticket 37: the provider id whose sync failed. A failed sync leaves a
  /// wire code (`SyncErrorCode`) in [errorMessage]; the screen maps it to
  /// content text with this provider's name. Cleared with [errorMessage].
  final String? errorProvider;
  final bool hasNextEvent;
  final String? nextEventName;

  /// True if Final Surge tokens expired and user needs to reconnect
  final bool finalSurgeNeedsReauth;

  /// True if TrainingPeaks tokens expired and user needs to reconnect
  final bool trainingPeaksNeedsReauth;

  /// True if V.O2 refused the token refresh and the user needs to reconnect
  final bool vdotNeedsReauth;

  /// True if Garmin answered "Token is not active" and the user needs to
  /// reconnect (ticket 138, Finding 118-016)
  final bool garminNeedsReauth;

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
    String? errorProvider,
    bool clearErrorMessage = false,
    bool? hasNextEvent,
    String? nextEventName,
    bool? finalSurgeNeedsReauth,
    bool? trainingPeaksNeedsReauth,
    bool? vdotNeedsReauth,
    bool? garminNeedsReauth,
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
      errorProvider: clearErrorMessage
          ? null
          : (errorProvider ?? this.errorProvider),
      hasNextEvent: hasNextEvent ?? this.hasNextEvent,
      nextEventName: nextEventName ?? this.nextEventName,
      finalSurgeNeedsReauth:
          finalSurgeNeedsReauth ?? this.finalSurgeNeedsReauth,
      trainingPeaksNeedsReauth:
          trainingPeaksNeedsReauth ?? this.trainingPeaksNeedsReauth,
      vdotNeedsReauth: vdotNeedsReauth ?? this.vdotNeedsReauth,
      garminNeedsReauth: garminNeedsReauth ?? this.garminNeedsReauth,
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
      } catch (e) {
        // Fall back to the auth id captured above.
        _report.note(
          'userId resolution failed; using auth id',
          area: 'integrations',
          data: {'error': e.toString()},
        );
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
      // Ticket 64: a refresh the provider refused for good is stored on the
      // row, so the Reconnect state survives the login sync that found it.
      finalSurgeNeedsReauth: finalSurgeIntegration?.needsReconnect ?? false,
      trainingPeaksNeedsReauth:
          trainingPeaksIntegration?.needsReconnect ?? false,
      vdotNeedsReauth: vdotIntegration?.needsReconnect ?? false,
      garminNeedsReauth: garminIntegration?.needsReconnect ?? false,
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

  /// The app's `Report`. Several paths here outlive this auto-dispose
  /// provider (OAuth round trips, delayed invalidations); reading `ref` after
  /// disposal throws, so a stale controller reports through the global.
  Report get _report => ref.report;

  /// Analytics must never block a connect/import, but a tracker that throws
  /// is still a bug; the one catch here reports it instead of eight silent
  /// `catch (_) {}` blocks.
  void _trackSafely(
    String event,
    void Function(AnalyticsTracker analytics) track,
  ) {
    if (!ref.mounted) return;
    try {
      track(ref.read(appExternalDepsProvider).analytics);
    } catch (e, stackTrace) {
      _report.degraded(
        e,
        stackTrace: stackTrace,
        area: 'integrations',
        message: 'Analytics track failed: $event',
      );
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

    // Ticket 63: captured before the awaits so the reconnect unhide below
    // completes even if this provider is disposed during OAuth.
    final userId = _currentUserId!;
    final deps = _providerDataDeps(providerId);
    final integrationsRepo = ref.read(integrationsRepositoryProvider);

    try {
      _trackIntegrationConnectStarted(providerId);
      // The athlete the disconnected row belonged to, read before the OAuth
      // upsert overwrites it (deactivateIntegration keeps the id).
      final previousAthleteId = await _previousAthleteId(
        integrationsRepo,
        userId,
        providerId,
      );
      final integration = await authenticate();

      await _unhideProviderData(
        providerId: providerId,
        userId: userId,
        previousAthleteId: previousAthleteId,
        newAthleteId: integration.providerAthleteId as String?,
        deps: deps,
      );

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
      _report.integrationFailure(providerId, 'connect', e, stackTrace);
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
        finalSurgeNeedsReauth: false,
      ),
    );
  }

  /// Generic provider disconnect helper to reduce duplication.
  ///
  /// Q-INT2 disconnect redesign (RULED 2026-09-10): the DEFAULT disconnect
  /// clears the tokens and SOFT-HIDES what the provider gave us —
  /// hidden-by-disconnect rows leave display and the engine but revive on a
  /// matching re-sync after reconnect. The explicit "also delete my synced
  /// data" choice ([alsoDeleteData]) keeps the old hard purge. Either way
  /// the plan re-runs (F27) because the engine inputs changed.
  Future<void> _disconnectProvider({
    required String providerId,
    required Future<void> Function() disconnect,
    required ConnectTrainingState Function() updateState,
    bool alsoDeleteData = false,
  }) async {
    if (_currentUserId == null) return;
    // Captured before the awaits: the hide/purge below runs after the
    // disconnect round trip and must still complete if this provider was
    // disposed meanwhile.
    final deps = _providerDataDeps(providerId);
    try {
      await disconnect();
      final removedWorkouts = alsoDeleteData
          ? await _purgeProviderData(providerId, deps)
          : await _hideProviderData(providerId, deps);
      // The awaits above are async gaps on an auto-dispose provider —
      // writing state through a stale ref throws UnmountedRefException
      // (Sentry MEALVANA-ENDURANCE-AV family). The disconnect and the purge
      // already persisted; only the (now-invisible) UI update is skipped.
      if (!ref.mounted) return;
      state = AsyncData(updateState());
      _trackIntegrationDisconnected(providerId, reason: 'user_initiated');
      if (kDebugMode) {
        print('🧹 Disconnect $providerId: removed $removedWorkouts workouts');
      }
    } catch (e, stackTrace) {
      _report.integrationFailure(providerId, 'disconnect', e, stackTrace);
      if (ref.mounted) {
        state = AsyncData(
          state.value!.copyWith(errorMessage: 'Failed to disconnect: $e'),
        );
      }
    }
  }

  _ProviderDataDeps _providerDataDeps(String providerId) {
    // The macro-window step is best effort (see _invalidateMacroWindows): a
    // repository that cannot be built is reported now and the step skipped,
    // and the disconnect itself goes on.
    DailyMacroTargetsRepository? macroTargetsRepo;
    try {
      macroTargetsRepo = ref.read(dailyMacroTargetsRepositoryProvider);
    } catch (e, stackTrace) {
      _report.integrationFailure(
        providerId,
        'invalidate_macros',
        e,
        stackTrace,
      );
    }
    return (
      activitiesRepo: _activitiesRepo,
      externalDeps: ref.read(appExternalDepsProvider),
      macroTargetsRepo: macroTargetsRepo,
    );
  }

  /// Q-INT2 default path: soft-hide the provider's rows (and, for Garmin,
  /// best-effort flag the server-side wellness store), then invalidate the
  /// cached macro windows so the plan re-runs without the hidden sessions.
  Future<int> _hideProviderData(
    String providerId,
    _ProviderDataDeps deps,
  ) async {
    final userId = _currentUserId;
    if (userId == null) return 0;

    var hidden = 0;
    try {
      hidden = await deps.activitiesRepo.hideActivitiesForProviderDisconnect(
        userId: userId,
        provider: providerId,
      );
    } catch (e, stackTrace) {
      _report.integrationFailure(providerId, 'hide_workouts', e, stackTrace);
    }

    // Ticket 63: the hide reaches the server now, not at the next upload
    // chance (Sign Out, in run 50).
    if (hidden > 0) {
      await _uploadProviderVisibility(
        providerId: providerId,
        userId: userId,
        activitiesRepo: deps.activitiesRepo,
        step: 'disconnect_hide',
        rows: hidden,
      );
    }

    if (providerId == 'garmin') {
      // Wellness rows live only server-side; hide them there. Best effort —
      // a network failure must not fail the disconnect (the tokens are
      // already gone), and the flag is re-appliable.
      try {
        final supabaseClient = deps.externalDeps.supabaseClient;
        await supabaseClient
            .from('garmin_health_data')
            .update({'hidden_by_disconnect': true})
            .eq('user_id', userId);
      } catch (e, stackTrace) {
        _report.integrationFailure(providerId, 'hide_wellness', e, stackTrace);
      }
    }

    // The provider's identity prefill leaves with it, same as the purge
    // path — onboarding-only, a no-op after onboarding completes.
    try {
      if (ref.mounted) {
        ref
            .read(onboardingControllerProvider.notifier)
            .clearIntegrationAutofill();
      }
    } catch (e, stackTrace) {
      _report.integrationFailure(providerId, 'hide_autofill', e, stackTrace);
    }

    await _invalidateMacroWindows(userId, providerId, deps);
    return hidden;
  }

  /// Ticket 63: the athlete id on [providerId]'s existing row (active or
  /// not), or null when there is no row. A failed read counts as unknown,
  /// which the reconnect treats like the same athlete.
  Future<String?> _previousAthleteId(
    IntegrationsRepository integrationsRepo,
    String userId,
    String providerId,
  ) async {
    try {
      final existing = await integrationsRepo.getIntegration(
        userId,
        providerId,
      );
      return existing?.providerAthleteId;
    } catch (e, stackTrace) {
      _report.integrationFailure(
        providerId,
        'read_previous_athlete',
        e,
        stackTrace,
      );
      return null;
    }
  }

  /// Ticket 63 (Finding 50-006): a successful connect unhides every row this
  /// provider's disconnect hid, and uploads the unhide at once. Lee
  /// (2026-10-08): only a same-athlete reconnect, or one whose previous
  /// athlete id is unknown or absent, unhides; a different athlete leaves the
  /// first athlete's rows hidden. Never fails the connect.
  Future<void> _unhideProviderData({
    required String providerId,
    required String userId,
    required String? previousAthleteId,
    required String? newAthleteId,
    required _ProviderDataDeps deps,
  }) async {
    final previous = previousAthleteId?.trim() ?? '';
    final current = newAthleteId?.trim() ?? '';
    if (previous.isNotEmpty && previous != current) {
      var stillHidden = 0;
      try {
        stillHidden = await deps.activitiesRepo
            .countActivitiesHiddenByDisconnect(
              userId: userId,
              provider: providerId,
            );
      } catch (e, stackTrace) {
        _report.integrationFailure(providerId, 'count_hidden', e, stackTrace);
      }
      // D9: a skipped step on a sync path.
      await _report.note(
        'Reconnect as a different athlete; hidden workouts stay hidden',
        area: providerId,
        data: {'hidden': stillHidden},
      );
      return;
    }

    var unhidden = 0;
    try {
      unhidden = await deps.activitiesRepo.unhideActivitiesForProviderReconnect(
        userId: userId,
        provider: providerId,
      );
    } catch (e, stackTrace) {
      _report.integrationFailure(providerId, 'unhide_workouts', e, stackTrace);
    }

    if (providerId == 'garmin') {
      // The mirror of the disconnect's wellness hide. Best effort: the flag
      // is re-appliable and must not fail the connect.
      try {
        await deps.externalDeps.supabaseClient
            .from('garmin_health_data')
            .update({'hidden_by_disconnect': false})
            .eq('user_id', userId);
      } catch (e, stackTrace) {
        _report.integrationFailure(
          providerId,
          'unhide_wellness',
          e,
          stackTrace,
        );
      }
    }

    if (unhidden > 0) {
      await _uploadProviderVisibility(
        providerId: providerId,
        userId: userId,
        activitiesRepo: deps.activitiesRepo,
        step: 'reconnect_unhide',
        rows: unhidden,
      );
      // F27: the sessions are back in the engine's inputs.
      await _invalidateMacroWindows(userId, providerId, deps);
    }
  }

  /// Ticket 63: upload a disconnect hide or reconnect unhide at once, and
  /// check the result (`uploadDirtyRecords` swallows errors into a failed
  /// result). A failure leaves the rows dirty for the next upload pass and is
  /// recorded (D9). Deferred during onboarding: the users row is not remote
  /// yet, so the upload would hit FK 23503.
  Future<void> _uploadProviderVisibility({
    required String providerId,
    required String userId,
    required ActivitiesRepository activitiesRepo,
    required String step,
    required int rows,
  }) async {
    if (_isUsingTempUserId || _isOnboardingInProgress) {
      await _report.note(
        'Provider visibility upload deferred until onboarding completes',
        area: 'sync',
        data: {
          'provider': providerId,
          'step': step,
          'rows': rows,
          'tempUserId': _isUsingTempUserId,
        },
      );
      return;
    }
    final message = step == 'disconnect_hide'
        ? 'Disconnect hide upload failed; rows stay dirty for retry'
        : 'Reconnect unhide upload failed; rows stay dirty for retry';
    try {
      final result = await activitiesRepo.uploadDirtyRecords(userId);
      if (!result.success) {
        _report.degraded(
          LoggedFault(message),
          area: 'sync',
          message: message,
          extra: {
            'provider': providerId,
            'step': step,
            'rows': rows,
            'error': result.error,
          },
        );
      }
    } catch (e, stackTrace) {
      _report.degraded(
        e,
        stackTrace: stackTrace,
        area: 'sync',
        message: message,
        extra: {'provider': providerId, 'step': step, 'rows': rows},
      );
    }
  }

  /// F27: the engine inputs changed (sessions hidden or purged) — drop the
  /// cached macro windows so the next read recalculates.
  Future<void> _invalidateMacroWindows(
    String userId,
    String providerId,
    _ProviderDataDeps deps,
  ) async {
    final macroTargetsRepo = deps.macroTargetsRepo;
    if (macroTargetsRepo == null) return; // reported when deps were read
    try {
      await macroTargetsRepo.invalidateAllForUser(userId);
    } catch (e, stackTrace) {
      _report.integrationFailure(
        providerId,
        'invalidate_macros',
        e,
        stackTrace,
      );
    }
  }

  /// Deletes everything [providerId] contributed: its imported workouts,
  /// and the onboarding draft answers it pre-filled.
  ///
  /// Deletes are the repository's normal soft-delete, so they sync like any
  /// other user deletion rather than silently diverging from the server.
  /// Failures here are reported but never fail the disconnect itself — the
  /// integration is already gone by this point, and leaving the user
  /// "still connected" would be worse than leaving stale rows.
  Future<int> _purgeProviderData(
    String providerId,
    _ProviderDataDeps deps,
  ) async {
    final userId = _currentUserId;
    if (userId == null) return 0;

    var removed = 0;
    try {
      final activities = await deps.activitiesRepo
          .getActivitiesByUserAndProvider(userId, providerId);
      for (final activity in activities) {
        // Hard delete, deliberately NOT the tombstone path: a disconnect
        // wipe must not leave status='deleted' rows around, or the matcher
        // would suppress re-import when the athlete reconnects later.
        await deps.activitiesRepo.hardDeleteActivityForProviderPurge(
          userId: userId,
          activityId: activity.id,
        );
        removed++;
      }
    } catch (e, stackTrace) {
      _report.integrationFailure(providerId, 'purge_workouts', e, stackTrace);
    }

    if (providerId == 'garmin') {
      // Explicit "also delete my synced data": the wellness store and the
      // users mirrors go too (Q-INT2 hard-purge half). Best effort.
      try {
        final supabaseClient = deps.externalDeps.supabaseClient;
        await supabaseClient
            .from('garmin_health_data')
            .delete()
            .eq('user_id', userId);
        await supabaseClient
            .from('users')
            .update({'weight_pounds': null, 'body_fat_pct': null})
            .eq('id', userId);
      } catch (e, stackTrace) {
        _report.integrationFailure(providerId, 'purge_wellness', e, stackTrace);
      }
    }

    if (providerId == 'final_surge' || providerId == 'training_peaks') {
      // Raw payload retention (real-payload-corpus@v1, W3): the hard purge
      // covers provider_raw_payloads too — an application of ruled Q-INT2
      // ("removes what the provider gave us"). Best effort, same contract
      // as the garmin wellness block above. The soft-hide path deliberately
      // leaves these rows: they surface nowhere and age out via the 90-day
      // TTL regardless.
      try {
        final supabaseClient = deps.externalDeps.supabaseClient;
        await supabaseClient
            .from('provider_raw_payloads')
            .delete()
            .eq('user_id', userId)
            .eq('provider', providerId);
      } catch (e, stackTrace) {
        _report.integrationFailure(
          providerId,
          'purge_raw_payloads',
          e,
          stackTrace,
        );
      }
    }

    await _invalidateMacroWindows(userId, providerId, deps);

    // Onboarding-only: drop the personal details this provider pre-filled.
    // No-op once onboarding is over — by then the values live on the saved
    // profile and are the athlete's to edit in Settings.
    try {
      if (ref.mounted) {
        ref
            .read(onboardingControllerProvider.notifier)
            .clearIntegrationAutofill();
      }
    } catch (e, stackTrace) {
      _report.integrationFailure(providerId, 'purge_autofill', e, stackTrace);
    }

    return removed;
  }

  Future<void> disconnectFinalSurge({bool alsoDeleteData = false}) async {
    await _disconnectProvider(
      alsoDeleteData: alsoDeleteData,
      providerId: 'final_surge',
      disconnect: () => _finalSurgeOAuth.disconnect(_currentUserId!),
      updateState: () => state.value!.copyWith(
        isFinalSurgeConnected: false,
        finalSurgeAthleteName: null,
        // Ticket 47 (32-005): a disconnected card shows Connect at once.
        finalSurgeNeedsReauth: false,
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

  Future<void> disconnectGarmin({bool alsoDeleteData = false}) async {
    await _disconnectProvider(
      alsoDeleteData: alsoDeleteData,
      providerId: 'garmin',
      disconnect: () => _garminOAuth.disconnect(_currentUserId!),
      updateState: () => state.value!.copyWith(
        isGarminConnected: false,
        clearGarminAthleteName: true,
        // Ticket 47 (32-005): a disconnected card shows Connect at once.
        garminNeedsReauth: false,
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
  /// user metrics, plus the last 30 days of activities (Q-INT27), right now.
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
          // Q-INT27 (RULED 2026-09-11): connect-time backfill also requests
          // `activities` — ONE window at Garmin's 30-day Activity max (the
          // edge function clamps activities to 30 days per-type; the health
          // types keep the 90-day window). No chaining — that stays a future
          // option pending the insight-engine live test.
          'summary_types': ['body_composition', 'user_metrics', 'activities'],
          'window_days': 90,
        },
      );

      if (response.status < 200 || response.status >= 300) {
        if (kDebugMode) {
          print(
            '[syncGarmin] backfill HTTP ${response.status}: ${response.data}',
          );
        }
        if (_isBackfillReauth(response.status, response.data)) {
          await _markGarminNeedsReauth();
          return false;
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
      // garmin-backfill answers 409 `garmin_reauth_required` when Garmin says
      // the stored token is dead and the refresh grant failed (ticket 19;
      // prod logs 2026-10-01/02). Only a reconnect fixes that: an expected
      // failure, not a code fault, and retrying soon is pointless.
      if (e is FunctionException &&
          isGarminReauthRequired(e.status, e.details)) {
        _report.degraded(
          e,
          stackTrace: st,
          area: 'garmin',
          message:
              'garmin-backfill 409: Garmin token expired, athlete must '
              'reconnect Garmin',
        );
        await _markGarminNeedsReauth();
        return false;
      }
      // Garmin's backfill API is frequently flaky: it returns 502 (Bad gateway)
      // and 429 "rate limit quota violation" responses that are transient and
      // self-heal. Treat those calmly (expected, not a code fault) and let the
      // next app session retry soon instead of blocking for the full cooldown
      // (the data never got queued, so waiting 6h would needlessly delay the
      // user's weight/body-fat backfill). Genuinely unexpected errors keep the
      // full stack trace.
      final transient = _isTransientBackfillFailure(null, '$e');
      if (transient) {
        _report.degraded(
          e,
          stackTrace: st,
          area: 'garmin',
          message:
              'Garmin backfill temporarily unavailable (502/rate limit); '
              'retry scheduled for next session',
        );
        await _scheduleGarminBackfillRetrySoon();
      } else {
        _report.fault(
          e,
          stackTrace: st,
          area: 'garmin',
          message: 'Garmin backfill invoke failed',
        );
      }
      return false;
    }
  }

  /// garmin-backfill answers 409 `garmin_reauth_required` (ticket 19), with
  /// `requires_reauth: true` since ticket 138, when Garmin said "Token is not
  /// active" (Finding 118-016): the athlete must sign in again, so this is
  /// never a transient retry. mealplanning's server answers 401 with the
  /// flag instead; develop keeps ticket 19's 409.
  bool _isBackfillReauth(int status, Object? data) =>
      isGarminReauthRequired(status, data) ||
      (status == 401 && data is Map && data['requires_reauth'] == true);

  /// Mirrors the server's `requires_reauth` on the local garmin row (the
  /// server stamped its own), so Connected Apps shows Reconnect now and the
  /// Reconnect notice fires through the repository hook. Repeating it is
  /// safe: the same status is written again and the notice is remembered.
  Future<void> _markGarminNeedsReauth() async {
    if (!ref.mounted) return;
    final userId = _currentUserId;
    if (userId == null) {
      // D9: the server row is marked; only the local mirror is skipped.
      await _report.note(
        'Garmin requires_reauth not mirrored locally: no current user',
        area: 'garmin',
      );
      return;
    }
    await ref
        .read(integrationsRepositoryProvider)
        .updateSyncStatus(
          userId,
          'garmin',
          status: requiresReauthStatus,
          // Ticket 37: the row holds the code; the text is content.
          error: reauthRequiredCode,
        );
    if (!ref.mounted) return;
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(garminNeedsReauth: true));
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
        vdotNeedsReauth: false,
      ),
    );
  }

  Future<void> disconnectVdot({bool alsoDeleteData = false}) async {
    await _disconnectProvider(
      alsoDeleteData: alsoDeleteData,
      providerId: 'vdot',
      disconnect: () => _vdotOAuth.disconnect(_currentUserId!),
      updateState: () => state.value!.copyWith(
        isVdotConnected: false,
        clearVdotAthleteName: true,
        // Ticket 47 (32-005): a disconnected card shows Connect at once.
        vdotNeedsReauth: false,
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
      _trackIntegrationSyncStarted('vdot');
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
              errorMessage: reauthRequiredCode, // ticket 37
              errorProvider: 'vdot',
              vdotNeedsReauth: true,
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
              errorMessage: SyncErrorCode.network.wire, // ticket 37
              errorProvider: 'vdot',
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
            // Ticket 37: a wire code; English from a result reads `unknown`.
            errorMessage: syncFailureCode(error: result.error),
            errorProvider: 'vdot',
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
        } catch (e, stackTrace) {
          uploadFailed = true;
          _report.fault(
            e,
            stackTrace: stackTrace,
            area: 'sync',
            message: 'Upload of synced VDOT activities threw',
          );
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
          vdotNeedsReauth: false,
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
            // Ticket 37: a wire code, never the raw exception text.
            errorMessage: syncErrorCode(e),
            errorProvider: 'vdot',
          ),
        );
      }
      _report.integrationFailure('vdot', 'import', e, stackTrace);
      _trackIntegrationSyncFailed(
        'vdot',
        'exception',
        errorMessage: e.toString(),
      );
      return VdotSyncResult.error(syncErrorCode(e)); // ticket 37
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
    final integrationsRepo = ref.read(integrationsRepositoryProvider);
    // Ticket 63: captured before the awaits (see _connectProvider).
    final userId = _currentUserId!;
    final deps = _providerDataDeps('runna');

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

      // Ticket 63: Runna's disconnect deletes its row, so there is no
      // previous athlete to compare; a reconnect unhides every hidden Runna
      // row (the ticket's Decisions).
      await _unhideProviderData(
        providerId: 'runna',
        userId: userId,
        previousAthleteId: null,
        newAthleteId: null,
        deps: deps,
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
      // User-supplied URL rejected before any network call; shown inline.
      _report.note(
        'Runna feed URL rejected',
        area: 'runna',
        data: {'reason': 'invalid_url'},
      );
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
      _report.integrationFailure('runna', 'connect', e, stackTrace);
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

  Future<void> disconnectRunna({bool alsoDeleteData = false}) async {
    await _disconnectProvider(
      alsoDeleteData: alsoDeleteData,
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
      _trackIntegrationSyncStarted('runna');
      final result = await _runnaSync.syncWorkouts(_currentUserId!);

      if (!ref.mounted) return result;

      if (!result.success) {
        if (result.isNetworkError) {
          state = AsyncData(
            state.value!.copyWith(
              isImporting: false,
              clearSyncingProvider: true,
              isNetworkError: true,
              errorMessage: SyncErrorCode.network.wire, // ticket 37
              errorProvider: 'runna',
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
            // Ticket 37: a wire code; English from a result reads `unknown`.
            errorMessage: syncFailureCode(error: result.error),
            errorProvider: 'runna',
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
        } catch (e, stackTrace) {
          uploadFailed = true;
          _report.fault(
            e,
            stackTrace: stackTrace,
            area: 'sync',
            message: 'Upload of synced Runna activities threw',
          );
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
            // Ticket 37: a wire code, never the raw exception text.
            errorMessage: syncErrorCode(e),
            errorProvider: 'runna',
          ),
        );
      }
      _report.integrationFailure('runna', 'import', e, stackTrace);
      _trackIntegrationSyncFailed(
        'runna',
        'exception',
        errorMessage: e.toString(),
      );
      return RunnaSyncResult.error(syncErrorCode(e)); // ticket 37
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
      _trackIntegrationSyncStarted(providerId);
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
                  errorMessage: reauthRequiredCode, // ticket 37
                  errorProvider: providerId,
                )
              : state.value!.copyWith(
                  isImporting: false,
                  clearSyncingProvider: true,
                  trainingPeaksNeedsReauth: true,
                  isTrainingPeaksConnected: false,
                  errorMessage: reauthRequiredCode, // ticket 37
                  errorProvider: providerId,
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
              errorMessage: SyncErrorCode.network.wire, // ticket 37
              errorProvider: providerId,
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
            // Ticket 37: a wire code; English from a result reads `unknown`.
            errorMessage: syncFailureCode(error: getError(result)),
            errorProvider: providerId,
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
      //
      // Ticket 63: every time, not only when this sync imported or updated
      // something. uploadDirtyRecords is also the retry path for rows an
      // earlier write left dirty (a hide or unhide whose upload failed), the
      // same reasoning as the V.O2 sync's upload.
      final newWorkouts = getNewWorkouts(result);
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
          if (!uploadResult.success) {
            // D9: was a kDebugMode-only print, so a failed upload left no
            // PROD trace.
            _report.degraded(
              LoggedFault('Upload of synced $providerId activities failed'),
              area: 'sync',
              message: 'Upload of synced activities failed; rows stay dirty',
              extra: {'provider': providerId, 'error': uploadResult.error},
            );
          } else if (kDebugMode) {
            print(
              '☁️ Uploaded ${uploadResult.count} synced activities to Supabase',
            );
          }
        } catch (e, stackTrace) {
          _report.fault(
            e,
            stackTrace: stackTrace,
            area: 'sync',
            message: 'Upload of synced $providerId activities threw',
          );
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
      if (!ref.mounted) return result;

      // Invalidate calendar to refresh UI
      state = AsyncData(state.value!.copyWith(importProgress: 0.8));
      _invalidateCalendar();

      final stateUpdate = providerId == 'final_surge'
          ? state.value!.copyWith(
              isImporting: false,
              clearSyncingProvider: true,
              importProgress: 1.0,
              importedWorkoutsCount: newWorkouts,
              // Ticket 47 (32-006): the card's "Last synced" updates at once;
              // the service stamped the row at the same moment.
              finalSurgeLastSyncAt: DateTime.now(),
              finalSurgeNeedsReauth: false,
              isNetworkError: false,
              clearErrorMessage: true,
            )
          : state.value!.copyWith(
              isImporting: false,
              clearSyncingProvider: true,
              importProgress: 1.0,
              importedWorkoutsCount: newWorkouts,
              // Ticket 47 (32-006): see the Final Surge branch above.
              trainingPeaksLastSyncAt: DateTime.now(),
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
            // Ticket 37: a wire code, never the raw exception text.
            errorMessage: syncErrorCode(e),
            errorProvider: providerId,
          ),
        );
      }
      _report.integrationFailure(providerId, 'import', e, stackTrace);
      _trackIntegrationSyncFailed(
        providerId,
        'exception',
        errorMessage: e.toString(),
      );
      return createError(syncErrorCode(e)); // ticket 37
    } finally {
      _syncingProviders.remove(providerId);
    }
  }

  /// Save Final Surge race candidates as events
  Future<int> _saveRaceCandidates(List<dynamic> raceCandidates) async {
    // Persistence (dedupe + D-2c origin rules) lives in the application
    // layer so the coordinator's background sync saves the same way.
    return ref
        .read(providerEventImportServiceProvider)
        .importFinalSurgeRaceCandidates(
          _currentUserId!,
          raceCandidates.cast<FinalSurgeRaceCandidate>(),
        );
  }

  /// Save TrainingPeaks events
  Future<int> _saveTrainingPeaksEvents(List<dynamic> eventData) async {
    // Same application-layer funnel as _saveRaceCandidates.
    return ref
        .read(providerEventImportServiceProvider)
        .importTrainingPeaksEvents(
          _currentUserId!,
          eventData.cast<TrainingPeaksEventResult>(),
        );
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
        trainingPeaksNeedsReauth: false,
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

  Future<void> disconnectTrainingPeaks({bool alsoDeleteData = false}) async {
    await _disconnectProvider(
      alsoDeleteData: alsoDeleteData,
      providerId: 'training_peaks',
      disconnect: () async {
        // Read before the awaits below; awaited after the write-back cleanup.
        final oauthServiceFuture = _trainingPeaksOAuth..ignore();
        // Q-INT16: strip the pushed [Mealvana ...] blocks and purge the
        // write-back ledger BEFORE the tokens go (the strip needs them).
        // Best effort — never blocks the disconnect.
        try {
          final writeback = await ref.read(tpWritebackServiceProvider.future);
          await writeback.handleDisconnect(userId: _currentUserId!);
        } catch (e, stackTrace) {
          // handleDisconnect never throws; this guards provider resolution.
          _report.degraded(
            e,
            stackTrace: stackTrace,
            area: 'training_peaks',
            message: 'TP write-back cleanup skipped on disconnect',
          );
        }
        final oauthService = await oauthServiceFuture;
        await oauthService.disconnect(_currentUserId!);
      },
      updateState: () => state.value!.copyWith(
        isTrainingPeaksConnected: false,
        trainingPeaksAthleteName: null,
        hasNextEvent: false,
        nextEventName: null,
        // Ticket 47 (32-005): a disconnected card shows Connect at once.
        trainingPeaksNeedsReauth: false,
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
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'integrations',
        message: 'Post-import provider invalidation failed',
      );
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
    _trackSafely(
      'integration_notify_requested',
      (analytics) => analytics.track(
        'integration_notify_requested',
        properties: {
          'provider': provider,
          'source': source,
          'device_id': _analyticsDeviceId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      ),
    );
  }

  void trackSkip() {
    _trackSafely(
      'integration_connect_skipped',
      (analytics) => analytics.track(
        'integration_connect_skipped',
        properties: {
          'device_id': _analyticsDeviceId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      ),
    );
  }

  /// The device id every integration event sends as `device_id`: the same id
  /// `app_opened` sends, never the user id (ticket 60). Read inside
  /// [_trackSafely]'s callback, after its `ref.mounted` check.
  String get _analyticsDeviceId => ref.read(deviceInfoServiceProvider).deviceId;

  void _trackIntegrationConnectStarted(String provider) {
    _trackSafely(
      'integration_connect_started',
      (analytics) => analytics.trackIntegrationConnectStarted(
        provider: provider,
        deviceId: _analyticsDeviceId,
      ),
    );
  }

  /// A sync (Sync Now or a background import), not a connect: the connect
  /// funnel must not count it (ticket 60, 50-010).
  void _trackIntegrationSyncStarted(String provider) {
    _trackSafely(
      'integration_sync_started',
      (analytics) => analytics.trackIntegrationSyncStarted(
        provider: provider,
        deviceId: _analyticsDeviceId,
      ),
    );
  }

  void _trackIntegrationConnectSuccess(String provider, {String? athleteName}) {
    _trackSafely(
      'integration_connect_success',
      (analytics) => analytics.trackIntegrationConnectSuccess(
        provider: provider,
        deviceId: _analyticsDeviceId,
        athleteName: athleteName,
      ),
    );
  }

  void _trackIntegrationConnectFailed(
    String provider,
    String errorType, {
    String? errorMessage,
  }) {
    _trackSafely(
      'integration_connect_failed',
      (analytics) => analytics.trackIntegrationConnectFailed(
        provider: provider,
        deviceId: _analyticsDeviceId,
        errorType: errorType,
        errorMessage: errorMessage,
      ),
    );
  }

  void _trackIntegrationDisconnected(String provider, {String? reason}) {
    _trackSafely(
      'integration_disconnected',
      (analytics) => analytics.trackIntegrationDisconnected(
        provider: provider,
        deviceId: _analyticsDeviceId,
        reason: reason,
      ),
    );
  }

  void _trackIntegrationSyncSuccess(
    String provider,
    int workoutsSynced, {
    int? skippedCount,
    int? eventsCount,
  }) {
    _trackSafely(
      'integration_sync_success',
      (analytics) => analytics.trackIntegrationSyncSuccess(
        provider: provider,
        deviceId: _analyticsDeviceId,
        workoutsSynced: workoutsSynced,
        skippedCount: skippedCount,
        eventsCount: eventsCount,
      ),
    );
  }

  void _trackIntegrationSyncFailed(
    String provider,
    String errorType, {
    String? errorMessage,
  }) {
    _trackSafely(
      'integration_sync_failed',
      (analytics) => analytics.trackIntegrationSyncFailed(
        provider: provider,
        deviceId: _analyticsDeviceId,
        errorType: errorType,
        errorMessage: errorMessage,
      ),
    );
  }
}

/// The Sentry side of a connect/disconnect/import failure. The state and
/// snackbar already show the user; this makes sure the failure also leaves
/// the device (onboarding redesign §6: no silent failures). `fault`
/// downgrades expected network and cancelled-OAuth errors by itself.
extension _IntegrationFailureReport on Report {
  void integrationFailure(
    String provider,
    String phase,
    Object error,
    StackTrace stackTrace,
  ) {
    fault(
      error,
      stackTrace: stackTrace,
      area: provider,
      message: '$provider $phase failed',
      tags: {'feature': 'integrations', 'provider': provider, 'phase': phase},
    );
  }
}

/// The dependencies a disconnect's hide/purge needs, read before the
/// disconnect round trip so the removal survives this provider's disposal.
typedef _ProviderDataDeps = ({
  ActivitiesRepository activitiesRepo,
  AppExternalDeps externalDeps,
  DailyMacroTargetsRepository? macroTargetsRepo,
});
