import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/database/database_provider.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/analytics/analytics_events.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../../../calendar/application/calendar_service.dart';
import '../../../calendar/presentation/providers/calendar_controller.dart';
import '../../../events/data/events_repository.dart';
import '../../application/final_surge_oauth_service.dart';
import '../../application/final_surge_sync_service.dart';
import '../../application/training_peaks_oauth_service.dart';
import '../../application/training_peaks_sync_service.dart';
import '../../data/integrations_repository.dart';
import 'integrations_providers.dart';

part 'connect_training_controller.g.dart';

/// Key for storing temporary user ID in shared preferences during onboarding
const _tempUserIdKey = 'onboarding_temp_user_id';

/// State for the Connect Training screen
class ConnectTrainingState {
  const ConnectTrainingState({
    this.isFinalSurgeConnected = false,
    this.finalSurgeAthleteName,
    this.isTrainingPeaksConnected = false,
    this.trainingPeaksAthleteName,
    this.isConnecting = false,
    this.connectingProvider,
    this.importedWorkoutsCount = 0,
    this.isImporting = false,
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
  final bool isTrainingPeaksConnected;
  final String? trainingPeaksAthleteName;
  final bool isConnecting;
  final String? connectingProvider;
  final int importedWorkoutsCount;
  final bool isImporting;
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

  ConnectTrainingState copyWith({
    bool? isFinalSurgeConnected,
    String? finalSurgeAthleteName,
    bool? isTrainingPeaksConnected,
    String? trainingPeaksAthleteName,
    bool? isConnecting,
    String? connectingProvider,
    int? importedWorkoutsCount,
    bool? isImporting,
    double? importProgress,
    String? errorMessage,
    bool? hasNextEvent,
    String? nextEventName,
    bool? finalSurgeNeedsReauth,
    bool? trainingPeaksNeedsReauth,
    bool? isNetworkError,
  }) {
    return ConnectTrainingState(
      isFinalSurgeConnected: isFinalSurgeConnected ?? this.isFinalSurgeConnected,
      finalSurgeAthleteName: finalSurgeAthleteName ?? this.finalSurgeAthleteName,
      isTrainingPeaksConnected: isTrainingPeaksConnected ?? this.isTrainingPeaksConnected,
      trainingPeaksAthleteName: trainingPeaksAthleteName ?? this.trainingPeaksAthleteName,
      isConnecting: isConnecting ?? this.isConnecting,
      connectingProvider: connectingProvider ?? this.connectingProvider,
      importedWorkoutsCount: importedWorkoutsCount ?? this.importedWorkoutsCount,
      isImporting: isImporting ?? this.isImporting,
      importProgress: importProgress ?? this.importProgress,
      errorMessage: errorMessage ?? this.errorMessage,
      hasNextEvent: hasNextEvent ?? this.hasNextEvent,
      nextEventName: nextEventName ?? this.nextEventName,
      finalSurgeNeedsReauth: finalSurgeNeedsReauth ?? this.finalSurgeNeedsReauth,
      trainingPeaksNeedsReauth: trainingPeaksNeedsReauth ?? this.trainingPeaksNeedsReauth,
      isNetworkError: isNetworkError ?? this.isNetworkError,
    );
  }
}

@riverpod
class ConnectTrainingController extends _$ConnectTrainingController {
  FinalSurgeOAuthService get _finalSurgeOAuth => ref.read(finalSurgeOAuthServiceProvider);
  FinalSurgeSyncService get _finalSurgeSync => ref.read(finalSurgeSyncServiceProvider);
  Future<TrainingPeaksOAuthService> get _trainingPeaksOAuth => ref.read(trainingPeaksOAuthServiceProvider.future);
  Future<TrainingPeaksSyncService> get _trainingPeaksSync => ref.read(trainingPeaksSyncServiceProvider.future);
  IntegrationsRepository get _integrationsRepo => ref.read(integrationsRepositoryProvider);
  CalendarService get _calendarService => ref.read(calendarServiceProvider);

  static const _uuid = Uuid();

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
    final user = await database.getCurrentUserProfile(
      currentAuthUserId: currentAuthUserId,
    );

    // Use temp ID if:
    // 1. No user profile exists for current auth session, OR
    // 2. User profile exists but onboarding is NOT completed
    final shouldUseTempId = user == null || !user.onboardingCompleted;

    if (shouldUseTempId) {
      _currentUserId = await _getOrCreateTempUserId();
      _isUsingTempUserId = true;

      if (kDebugMode) {
        print('🔑 ConnectTrainingController: Using temp user ID: $_currentUserId');
        print('   (user profile exists: ${user != null}, onboardingCompleted: ${user?.onboardingCompleted})');
        print('   (current auth: $currentAuthUserId)');
      }
    } else {
      _currentUserId = user.id;
      _isUsingTempUserId = false;

      if (kDebugMode) {
        print('🔑 ConnectTrainingController: Using real user ID: $_currentUserId');
      }
    }

    // Check for existing integrations (may exist from previous onboarding attempt)
    final finalSurgeIntegration = await _integrationsRepo.getIntegration(_currentUserId!, 'final_surge');
    final trainingPeaksIntegration = await _integrationsRepo.getIntegration(_currentUserId!, 'training_peaks');

    return ConnectTrainingState(
      isFinalSurgeConnected: finalSurgeIntegration?.isActive ?? false,
      finalSurgeAthleteName: finalSurgeIntegration?.providerAthleteName,
      isTrainingPeaksConnected: trainingPeaksIntegration?.isActive ?? false,
      trainingPeaksAthleteName: trainingPeaksIntegration?.providerAthleteName,
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

  /// Clear the temporary user ID after successful migration
  Future<void> clearTempUserId() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_tempUserIdKey);

    if (kDebugMode) {
      print('🧹 Cleared temp user ID from preferences');
    }
  }

  Future<bool> connectFinalSurge() async {
    if (_currentUserId == null) {
      if (kDebugMode) {
        print('❌ connectFinalSurge: No current user ID');
      }
      return false;
    }

    if (kDebugMode) {
      print('🔌 connectFinalSurge: Starting connection for user $_currentUserId');
    }

    state = AsyncData(state.value!.copyWith(
      isConnecting: true,
      connectingProvider: 'final_surge',
      errorMessage: null,
    ));

    try {
      _trackIntegrationConnectStarted('final_surge');
      final integration = await _finalSurgeOAuth.authenticate(_currentUserId!);

      if (kDebugMode) {
        print('✅ connectFinalSurge: Authentication successful');
        print('   Athlete Name: ${integration.providerAthleteName}');
        print('   Is Active: ${integration.isActive}');
      }

      state = AsyncData(state.value!.copyWith(
        isConnecting: false,
        connectingProvider: null,
        isFinalSurgeConnected: true,
        finalSurgeAthleteName: integration.providerAthleteName,
      ));

      if (kDebugMode) {
        print('✅ connectFinalSurge: State updated - isFinalSurgeConnected=true');
      }

      _trackIntegrationConnectSuccess('final_surge', athleteName: integration.providerAthleteName);
      return true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ connectFinalSurge: Error occurred');
        print('   Error: $e');
        print('   Stack: $stackTrace');
      }
      state = AsyncData(state.value!.copyWith(
        isConnecting: false,
        connectingProvider: null,
        errorMessage: e.toString(),
      ));
      _trackIntegrationConnectFailed('final_surge', 'authentication_error', errorMessage: e.toString());
      return false;
    }
  }

  Future<void> disconnectFinalSurge() async {
    if (_currentUserId == null) return;
    try {
      await _finalSurgeOAuth.disconnect(_currentUserId!);
      state = AsyncData(state.value!.copyWith(
        isFinalSurgeConnected: false,
        finalSurgeAthleteName: null,
      ));
      _trackIntegrationDisconnected('final_surge', reason: 'user_initiated');
    } catch (e) {
      state = AsyncData(state.value!.copyWith(errorMessage: 'Failed to disconnect: $e'));
    }
  }

  Future<int> importFinalSurgeWorkouts() async {
    if (_currentUserId == null) return 0;

    state = AsyncData(state.value!.copyWith(
      isImporting: true,
      importProgress: 0.0,
      errorMessage: null,
      isNetworkError: false,
    ));

    try {
      _trackIntegrationConnectStarted('final_surge'); // Sync started
      final result = await _finalSurgeSync.syncWorkouts(_currentUserId!);

      // Check if still mounted after async operation
      if (!ref.mounted) return 0;

      // Handle different error types
      if (!result.success) {
        if (result.needsReauth) {
          // Token expired - user must reconnect
          state = AsyncData(state.value!.copyWith(
            isImporting: false,
            finalSurgeNeedsReauth: true,
            isFinalSurgeConnected: false,
            errorMessage: result.summary,
          ));
          _trackIntegrationSyncFailed('final_surge', 'token_expired', errorMessage: 'Requires re-authentication');
          return 0;
        }

        if (result.isNetworkError) {
          // Network error - user can retry
          state = AsyncData(state.value!.copyWith(
            isImporting: false,
            isNetworkError: true,
            errorMessage: result.summary,
          ));
          _trackIntegrationSyncFailed('final_surge', 'network_error', errorMessage: result.error);
          return 0;
        }

        // Other error
        state = AsyncData(state.value!.copyWith(
          isImporting: false,
          errorMessage: result.error ?? 'Failed to import workouts',
        ));
        _trackIntegrationSyncFailed('final_surge', result.errorType.name, errorMessage: result.error);
        return 0;
      }

      // Activities are saved during sync - users will generate nutrition plans manually
      // by tapping activities in the calendar
      if (kDebugMode && result.hasNewWorkouts) {
        print('📋 Synced ${result.activities.length} activities (nutrition plans will be created manually)');
      }

      // Invalidate calendar to refresh UI
      state = AsyncData(state.value!.copyWith(importProgress: 0.8));
      _invalidateCalendar();

      state = AsyncData(state.value!.copyWith(
        isImporting: false,
        importProgress: 1.0,
        importedWorkoutsCount: result.newWorkouts,
        finalSurgeNeedsReauth: false,
        isNetworkError: false,
        errorMessage: null,
      ));

      _trackIntegrationSyncSuccess('final_surge', result.newWorkouts, skippedCount: result.skipped);
      return result.newWorkouts;
    } catch (e) {
      if (ref.mounted) {
        state = AsyncData(state.value!.copyWith(
          isImporting: false,
          errorMessage: 'Failed to import workouts: $e',
        ));
      }
      _trackIntegrationSyncFailed('final_surge', 'exception', errorMessage: e.toString());
      return 0;
    }
  }

  Future<bool> connectTrainingPeaks() async {
    if (_currentUserId == null) return false;

    state = AsyncData(state.value!.copyWith(
      isConnecting: true,
      connectingProvider: 'training_peaks',
      errorMessage: null,
    ));

    try {
      _trackIntegrationConnectStarted('training_peaks');
      final oauthService = await _trainingPeaksOAuth;
      final integration = await oauthService.authenticate(_currentUserId!);

      state = AsyncData(state.value!.copyWith(
        isConnecting: false,
        connectingProvider: null,
        isTrainingPeaksConnected: true,
        trainingPeaksAthleteName: integration.providerAthleteName,
      ));

      _trackIntegrationConnectSuccess('training_peaks', athleteName: integration.providerAthleteName);
      return true;
    } catch (e) {
      state = AsyncData(state.value!.copyWith(
        isConnecting: false,
        connectingProvider: null,
        errorMessage: e.toString(),
      ));
      _trackIntegrationConnectFailed('training_peaks', 'authentication_error', errorMessage: e.toString());
      return false;
    }
  }

  Future<void> disconnectTrainingPeaks() async {
    if (_currentUserId == null) return;
    try {
      final oauthService = await _trainingPeaksOAuth;
      await oauthService.disconnect(_currentUserId!);
      state = AsyncData(state.value!.copyWith(
        isTrainingPeaksConnected: false,
        trainingPeaksAthleteName: null,
        hasNextEvent: false,
        nextEventName: null,
      ));
      _trackIntegrationDisconnected('training_peaks', reason: 'user_initiated');
    } catch (e) {
      state = AsyncData(state.value!.copyWith(errorMessage: 'Failed to disconnect: $e'));
    }
  }

  Future<int> importTrainingPeaksWorkouts() async {
    if (_currentUserId == null) return 0;

    state = AsyncData(state.value!.copyWith(
      isImporting: true,
      importProgress: 0.0,
      errorMessage: null,
    ));

    try {
      _trackIntegrationConnectStarted('training_peaks'); // Sync started
      final syncService = await _trainingPeaksSync;
      final result = await syncService.syncAll(_currentUserId!);

      // Check if still mounted after async operation
      if (!ref.mounted) return 0;

      // Activities are saved during sync - users will generate nutrition plans manually
      // by tapping activities in the calendar
      if (kDebugMode && result.workoutResult.hasNewWorkouts) {
        print('📋 Synced ${result.workoutResult.activities.length} activities (nutrition plans will be created manually)');
      }

      // Update progress
      if (ref.mounted) {
        state = AsyncData(state.value!.copyWith(importProgress: 0.5));
      }

      // Save all events to database if found
      int savedEventsCount = 0;
      int skippedEventsCount = 0;
      if (result.eventResult?.hasEvent ?? false) {
        final eventsRepository = ref.read(eventsRepositoryProvider);

        for (final eventData in result.eventResult!.events) {
          if (kDebugMode) {
            print('💾 Checking TrainingPeaks event: ${eventData.eventName}');
          }

          // Check for existing event (same user + name + date) to prevent duplicates
          final existingEvent = await eventsRepository.findExistingEvent(
            userId: _currentUserId!,
            eventName: eventData.eventName,
            eventDate: eventData.eventDate,
          );

          if (existingEvent != null) {
            skippedEventsCount++;
            if (kDebugMode) {
              print('   ⏭️ Event already exists, skipping: ${eventData.eventName}');
            }
            continue;
          }

          try {
            final savedEvent = await _calendarService.createEvent(
              userId: _currentUserId!,
              eventType: eventData.activityType,
              eventSubtype: eventData.eventType, // Store TP event type as subtype
              eventName: eventData.eventName,
              startTime: eventData.eventDate.toIso8601String(),
              goalTimeMinutes: eventData.goalTimeHours != null
                  ? (eventData.goalTimeHours! * 60).round()
                  : null,
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
          print('✅ Event sync complete: $savedEventsCount new, $skippedEventsCount existing');
        }
        if (!ref.mounted) return 0;
      }

      // Phase 4: Invalidate calendar to refresh UI
      if (ref.mounted) {
        state = AsyncData(state.value!.copyWith(importProgress: 0.9));
        _invalidateCalendar();

        // Get first event name for display (if any events found)
        final firstEventName = (result.eventResult?.events.isNotEmpty ?? false)
            ? result.eventResult!.events.first.eventName
            : null;

        state = AsyncData(state.value!.copyWith(
          isImporting: false,
          importProgress: 1.0,
          importedWorkoutsCount: result.workoutResult.newWorkouts,
          hasNextEvent: result.eventResult?.hasEvent ?? false,
          nextEventName: firstEventName,
          errorMessage: null,
        ));
      }

      _trackIntegrationSyncSuccess(
        'training_peaks',
        result.workoutResult.newWorkouts,
        skippedCount: result.workoutResult.skipped,
        eventsCount: savedEventsCount,
      );
      return result.workoutResult.newWorkouts;
    } catch (e) {
      if (ref.mounted) {
        state = AsyncData(state.value!.copyWith(
          isImporting: false,
          errorMessage: 'Failed to import workouts: $e',
        ));
      }
      _trackIntegrationSyncFailed('training_peaks', 'exception', errorMessage: e.toString());
      return 0;
    }
  }

  /// Invalidate calendar and activities providers to refresh UI
  void _invalidateCalendar() {
    if (!ref.mounted) return;

    try {
      // Invalidate activities controller to refresh the main list
      ref.invalidate(activitiesControllerProvider);
      // Invalidate calendar providers
      ref.invalidate(calendarControllerProvider);
      ref.invalidate(allEventsControllerProvider);
      ref.invalidate(nextUpcomingEventProvider);
      if (kDebugMode) {
        print('🔄 Activities and calendar providers invalidated');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to invalidate providers: $e');
      }
    }
  }

  Future<int> importWorkouts() async {
    if (state.value?.isFinalSurgeConnected == true) return importFinalSurgeWorkouts();
    if (state.value?.isTrainingPeaksConnected == true) return importTrainingPeaksWorkouts();
    return 0;
  }

  void trackSkip() {
    if (!ref.mounted) return;
    try {
      final deps = ref.read(appExternalDepsProvider);
      deps.analytics.track('integration_connect_skipped', properties: {
        'device_id': _currentUserId ?? 'unknown',
        'timestamp': DateTime.now().toIso8601String(),
      });
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

  void _trackIntegrationConnectFailed(String provider, String errorType, {String? errorMessage}) {
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

  void _trackIntegrationSyncSuccess(String provider, int workoutsSynced, {int? skippedCount, int? eventsCount}) {
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

  void _trackIntegrationSyncFailed(String provider, String errorType, {String? errorMessage}) {
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
