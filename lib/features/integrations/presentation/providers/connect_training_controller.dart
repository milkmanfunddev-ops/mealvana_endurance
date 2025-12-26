import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/database/database_provider.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../activities/data/activities_repository.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../../../calendar/application/calendar_service.dart';
import '../../../calendar/presentation/providers/calendar_controller.dart';
import '../../../nutrition_plan/application/bulk_nutrition_plan_service.dart';
import '../../application/final_surge_oauth_service.dart';
import '../../application/final_surge_sync_service.dart';
import '../../application/training_peaks_oauth_service.dart';
import '../../application/training_peaks_sync_service.dart';
import '../../data/integrations_repository.dart';
import 'integrations_providers.dart';

part 'connect_training_controller.g.dart';

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
  TrainingPeaksOAuthService get _trainingPeaksOAuth => ref.read(trainingPeaksOAuthServiceProvider);
  TrainingPeaksSyncService get _trainingPeaksSync => ref.read(trainingPeaksSyncServiceProvider);
  BulkNutritionPlanService get _bulkPlanService => ref.read(bulkNutritionPlanServiceProvider);
  IntegrationsRepository get _integrationsRepo => ref.read(integrationsRepositoryProvider);
  CalendarService get _calendarService => ref.read(calendarServiceProvider);
  ActivitiesRepository get _activitiesRepo => ref.read(activitiesRepositoryProvider);

  String? _currentUserId;

  @override
  FutureOr<ConnectTrainingState> build() async {
    final database = ref.read(appDatabaseProvider);
    final user = await database.getCurrentUserProfile();
    _currentUserId = user?.id;

    if (_currentUserId == null) {
      return const ConnectTrainingState();
    }

    final finalSurgeIntegration = await _integrationsRepo.getIntegration(_currentUserId!, 'final_surge');
    final trainingPeaksIntegration = await _integrationsRepo.getIntegration(_currentUserId!, 'training_peaks');

    return ConnectTrainingState(
      isFinalSurgeConnected: finalSurgeIntegration?.isActive ?? false,
      finalSurgeAthleteName: finalSurgeIntegration?.providerAthleteName,
      isTrainingPeaksConnected: trainingPeaksIntegration?.isActive ?? false,
      trainingPeaksAthleteName: trainingPeaksIntegration?.providerAthleteName,
    );
  }

  Future<bool> connectFinalSurge() async {
    if (_currentUserId == null) return false;

    state = AsyncData(state.value!.copyWith(
      isConnecting: true,
      connectingProvider: 'final_surge',
      errorMessage: null,
    ));

    try {
      _trackEvent('integration_connect_started', {'provider': 'final_surge'});
      final integration = await _finalSurgeOAuth.authenticate(_currentUserId!);

      state = AsyncData(state.value!.copyWith(
        isConnecting: false,
        connectingProvider: null,
        isFinalSurgeConnected: true,
        finalSurgeAthleteName: integration.providerAthleteName,
      ));

      _trackEvent('integration_connect_success', {'provider': 'final_surge'});
      return true;
    } catch (e) {
      state = AsyncData(state.value!.copyWith(
        isConnecting: false,
        connectingProvider: null,
        errorMessage: e.toString(),
      ));
      _trackEvent('integration_connect_error', {'provider': 'final_surge', 'error': e.toString()});
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
      _trackEvent('integration_disconnected', {'provider': 'final_surge'});
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
      _trackEvent('workout_import_started', {'provider': 'final_surge'});
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
          _trackEvent('workout_import_reauth_required', {'provider': 'final_surge'});
          return 0;
        }

        if (result.isNetworkError) {
          // Network error - user can retry
          state = AsyncData(state.value!.copyWith(
            isImporting: false,
            isNetworkError: true,
            errorMessage: result.summary,
          ));
          _trackEvent('workout_import_network_error', {'provider': 'final_surge'});
          return 0;
        }

        // Other error
        state = AsyncData(state.value!.copyWith(
          isImporting: false,
          errorMessage: result.error ?? 'Failed to import workouts',
        ));
        _trackEvent('workout_import_error', {
          'provider': 'final_surge',
          'error': result.error,
          'error_type': result.errorType.name,
        });
        return 0;
      }

      // Phase 1: Generate and SAVE nutrition plans for NEW activities
      if (result.hasNewWorkouts && result.activities.isNotEmpty) {
        if (kDebugMode) {
          print('📋 Generating and saving nutrition plans for ${result.activities.length} new activities');
        }
        await _bulkPlanService.generateAndSavePlansForActivities(
          result.activities,
          onProgress: (progress) {
            if (ref.mounted) {
              state = AsyncData(state.value!.copyWith(importProgress: 0.3 + (progress.fraction * 0.3)));
            }
          },
        );
        if (!ref.mounted) return 0;
      }

      // Phase 2: Generate plans for EXISTING activities without nutrition plans
      if (ref.mounted) {
        state = AsyncData(state.value!.copyWith(importProgress: 0.6));
      }
      await _generatePlansForExistingActivities();
      if (!ref.mounted) return 0;

      // Phase 3: Invalidate calendar to refresh UI
      state = AsyncData(state.value!.copyWith(importProgress: 0.9));
      _invalidateCalendar();

      state = AsyncData(state.value!.copyWith(
        isImporting: false,
        importProgress: 1.0,
        importedWorkoutsCount: result.newWorkouts,
        finalSurgeNeedsReauth: false,
        isNetworkError: false,
        errorMessage: null,
      ));

      _trackEvent('workout_import_success', {
        'provider': 'final_surge',
        'imported_count': result.newWorkouts,
        'skipped_count': result.skipped,
      });
      return result.newWorkouts;
    } catch (e) {
      if (ref.mounted) {
        state = AsyncData(state.value!.copyWith(
          isImporting: false,
          errorMessage: 'Failed to import workouts: $e',
        ));
      }
      _trackEvent('workout_import_error', {'provider': 'final_surge', 'error': e.toString()});
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
      _trackEvent('integration_connect_started', {'provider': 'training_peaks'});
      final integration = await _trainingPeaksOAuth.authenticate(_currentUserId!);

      state = AsyncData(state.value!.copyWith(
        isConnecting: false,
        connectingProvider: null,
        isTrainingPeaksConnected: true,
        trainingPeaksAthleteName: integration.providerAthleteName,
      ));

      _trackEvent('integration_connect_success', {'provider': 'training_peaks'});
      return true;
    } catch (e) {
      state = AsyncData(state.value!.copyWith(
        isConnecting: false,
        connectingProvider: null,
        errorMessage: e.toString(),
      ));
      _trackEvent('integration_connect_error', {'provider': 'training_peaks', 'error': e.toString()});
      return false;
    }
  }

  Future<void> disconnectTrainingPeaks() async {
    if (_currentUserId == null) return;
    try {
      await _trainingPeaksOAuth.disconnect(_currentUserId!);
      state = AsyncData(state.value!.copyWith(
        isTrainingPeaksConnected: false,
        trainingPeaksAthleteName: null,
        hasNextEvent: false,
        nextEventName: null,
      ));
      _trackEvent('integration_disconnected', {'provider': 'training_peaks'});
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
      _trackEvent('workout_import_started', {'provider': 'training_peaks'});
      final result = await _trainingPeaksSync.syncAll(_currentUserId!);

      // Check if still mounted after async operation
      if (!ref.mounted) return 0;

      // Phase 1: Generate and SAVE plans for NEW activities
      if (result.workoutResult.hasNewWorkouts && result.workoutResult.activities.isNotEmpty) {
        if (kDebugMode) {
          print('📋 Generating and saving nutrition plans for ${result.workoutResult.activities.length} new activities');
        }
        await _bulkPlanService.generateAndSavePlansForActivities(
          result.workoutResult.activities,
          onProgress: (progress) {
            if (ref.mounted) {
              state = AsyncData(state.value!.copyWith(importProgress: 0.3 + (progress.fraction * 0.3)));
            }
          },
        );
        if (!ref.mounted) return 0;
      }

      // Phase 2: Generate plans for EXISTING activities without nutrition plans
      // This handles the case where activities were synced previously but plans weren't generated
      if (ref.mounted) {
        state = AsyncData(state.value!.copyWith(importProgress: 0.6));
      }
      await _generatePlansForExistingActivities();
      if (!ref.mounted) return 0;

      // Phase 3: Save event to database if found
      String? savedEventId;
      if (result.eventResult?.hasEvent ?? false) {
        final eventData = result.eventResult!.event!;
        if (kDebugMode) {
          print('💾 Saving TrainingPeaks event to database: ${eventData.eventName}');
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
          savedEventId = savedEvent.id;
          if (kDebugMode) {
            print('✅ Event saved with ID: $savedEventId');
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Failed to save event (may already exist): $e');
          }
        }
        if (!ref.mounted) return 0;
      }

      // Phase 4: Invalidate calendar to refresh UI
      if (ref.mounted) {
        state = AsyncData(state.value!.copyWith(importProgress: 0.9));
        _invalidateCalendar();

        state = AsyncData(state.value!.copyWith(
          isImporting: false,
          importProgress: 1.0,
          importedWorkoutsCount: result.workoutResult.newWorkouts,
          hasNextEvent: result.eventResult?.hasEvent ?? false,
          nextEventName: result.eventResult?.event?.eventName,
          errorMessage: null,
        ));
      }

      _trackEvent('workout_import_success', {
        'provider': 'training_peaks',
        'imported_count': result.workoutResult.newWorkouts,
        'has_event': result.hasEvent,
        'event_saved': savedEventId != null,
      });
      return result.workoutResult.newWorkouts;
    } catch (e) {
      if (ref.mounted) {
        state = AsyncData(state.value!.copyWith(
          isImporting: false,
          errorMessage: 'Failed to import workouts: $e',
        ));
      }
      _trackEvent('workout_import_error', {'provider': 'training_peaks', 'error': e.toString()});
      return 0;
    }
  }

  /// Generate and SAVE nutrition plans for existing activities that don't have them
  Future<void> _generatePlansForExistingActivities() async {
    if (_currentUserId == null || !ref.mounted) return;

    try {
      // Get all activities for this user from the provider (training_peaks or final_surge)
      final allActivities = await _activitiesRepo.getActivities(_currentUserId!);
      if (!ref.mounted) return;

      // Filter to synced activities without nutrition plans
      final activitiesNeedingPlans = allActivities.where((a) =>
          a.syncedFromProvider != null &&
          a.nutritionPlanData == null &&
          a.scheduledDateTime.isAfter(DateTime.now().subtract(const Duration(days: 1)))).toList();

      if (activitiesNeedingPlans.isEmpty) {
        if (kDebugMode) {
          print('✅ All synced activities already have nutrition plans');
        }
        return;
      }

      if (kDebugMode) {
        print('📋 Generating and saving nutrition plans for ${activitiesNeedingPlans.length} existing activities');
      }

      await _bulkPlanService.generateAndSavePlansForActivities(
        activitiesNeedingPlans,
        onProgress: (progress) {
          if (ref.mounted) {
            state = AsyncData(state.value!.copyWith(importProgress: 0.6 + (progress.fraction * 0.2)));
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to generate plans for existing activities: $e');
      }
      // Don't fail the sync if this fails
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

  void trackSkip() => _trackEvent('integration_connect_skipped', {});

  void _trackEvent(String eventName, Map<String, dynamic> properties) {
    if (!ref.mounted) return;
    try {
      ref.read(appExternalDepsProvider).analytics.track(eventName, properties: properties);
    } catch (_) {}
  }
}
