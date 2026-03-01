import 'dart:async';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../../../activities/domain/activity.dart' as domain;
import '../../../activities/application/activities_service.dart';
import '../../../../shared/providers/user_id_provider.dart';
import '../../domain/run_parameters.dart';
import '../../domain/intensity_distribution.dart';
import '../../domain/macro_targets.dart';
import '../../domain/nutrition_target_overrides.dart';
import '../../data/macro_repository.dart';
import '../../application/macro_generation_service.dart';
import '../../application/brick_macro_service.dart';
import '../../application/nutrition_plan_service.dart';
import '../../domain/nutrition_plan.dart';
import '../../../activities/domain/brick_metadata.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/analytics/analytics_tracker.dart';
import '../../../../shared/services/analytics/analytics_events.dart';
import '../../../auth/application/auth_service.dart';
import '../../../events/presentation/providers/events_controller.dart';
import '../../../events/data/events_repository.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';
import '../../../integrations/presentation/providers/tp_writeback_providers.dart';

part 'macro_targets_controller.g.dart';

/// State for both distance page and adjust macros screens
class MacroTargetsState {
  // Distance page fields
  final String title;
  final String distanceLabel;
  final String paceLabel;
  final String preRunLabel;
  final String gutTrainingLabel;
  final String generateButtonText;
  final String tipsText;
  final String distanceValidationRequired;
  final String distanceValidationNumber;
  final String distanceValidationRange;
  final String paceValidationRequired;
  final String paceValidationFormat;
  final String errorGeneric;
  final bool isGenerating;
  final bool isGeneratingMacros;

  // Adjust macros screen fields
  final String adjustMacrosTitle;
  final String shortRunBanner;
  final String longRunBanner;
  final String preRunSectionTitle;
  final String duringRunSectionTitle;
  final String postRunSectionTitle;
  final String createPlanButton;
  final String resetAllButton;
  final String helpTitle;
  final String helpOverview;
  final String helpPreRun;
  final String helpDuringRun;
  final String helpPostRun;
  final String helpValidation;
  final bool isCreatingPlan;
  final MacroTargets? macroTargets;
  final Map<String, String> validationMessages;

  // Shared fields
  final String? errorMessage;
  final String?
  activityId; // Calendar activity ID (links nutrition plan to activity) - ALWAYS exists after macro generation
  final String?
  eventId; // Calendar event ID (for provider invalidation after plan creation)
  final UnitSystem unitSystem;

  const MacroTargetsState({
    // Distance page fields
    required this.title,
    required this.distanceLabel,
    required this.paceLabel,
    required this.preRunLabel,
    required this.gutTrainingLabel,
    required this.generateButtonText,
    required this.tipsText,
    required this.distanceValidationRequired,
    required this.distanceValidationNumber,
    required this.distanceValidationRange,
    required this.paceValidationRequired,
    required this.paceValidationFormat,
    required this.errorGeneric,
    required this.isGenerating,
    required this.isGeneratingMacros,

    // Adjust macros fields
    required this.adjustMacrosTitle,
    required this.shortRunBanner,
    required this.longRunBanner,
    required this.preRunSectionTitle,
    required this.duringRunSectionTitle,
    required this.postRunSectionTitle,
    required this.createPlanButton,
    required this.resetAllButton,
    required this.helpTitle,
    required this.helpOverview,
    required this.helpPreRun,
    required this.helpDuringRun,
    required this.helpPostRun,
    required this.helpValidation,
    required this.isCreatingPlan,
    this.macroTargets,
    this.validationMessages = const {},

    // Shared fields
    this.errorMessage,
    this.activityId,
    this.eventId,
    this.unitSystem = UnitSystem.imperial,
  });

  MacroTargetsState copyWith({
    // Distance page fields
    String? title,
    String? distanceLabel,
    String? paceLabel,
    String? preRunLabel,
    String? gutTrainingLabel,
    String? generateButtonText,
    String? tipsText,
    String? distanceValidationRequired,
    String? distanceValidationNumber,
    String? distanceValidationRange,
    String? paceValidationRequired,
    String? paceValidationFormat,
    String? errorGeneric,
    bool? isGenerating,
    bool? isGeneratingMacros,

    // Adjust macros fields
    String? adjustMacrosTitle,
    String? shortRunBanner,
    String? longRunBanner,
    String? preRunSectionTitle,
    String? duringRunSectionTitle,
    String? postRunSectionTitle,
    String? createPlanButton,
    String? resetAllButton,
    String? helpTitle,
    String? helpOverview,
    String? helpPreRun,
    String? helpDuringRun,
    String? helpPostRun,
    String? helpValidation,
    bool? isCreatingPlan,
    MacroTargets? macroTargets,
    Map<String, String>? validationMessages,

    // Shared fields
    String? errorMessage,
    String? activityId,
    String? eventId,
    bool overrideActivityId = false,
    bool overrideEventId = false,
    UnitSystem? unitSystem,
  }) {
    return MacroTargetsState(
      title: title ?? this.title,
      distanceLabel: distanceLabel ?? this.distanceLabel,
      paceLabel: paceLabel ?? this.paceLabel,
      preRunLabel: preRunLabel ?? this.preRunLabel,
      gutTrainingLabel: gutTrainingLabel ?? this.gutTrainingLabel,
      generateButtonText: generateButtonText ?? this.generateButtonText,
      tipsText: tipsText ?? this.tipsText,
      distanceValidationRequired:
          distanceValidationRequired ?? this.distanceValidationRequired,
      distanceValidationNumber:
          distanceValidationNumber ?? this.distanceValidationNumber,
      distanceValidationRange:
          distanceValidationRange ?? this.distanceValidationRange,
      paceValidationRequired:
          paceValidationRequired ?? this.paceValidationRequired,
      paceValidationFormat: paceValidationFormat ?? this.paceValidationFormat,
      errorGeneric: errorGeneric ?? this.errorGeneric,
      isGenerating: isGenerating ?? this.isGenerating,
      isGeneratingMacros: isGeneratingMacros ?? this.isGeneratingMacros,

      // Adjust macros fields
      adjustMacrosTitle: adjustMacrosTitle ?? this.adjustMacrosTitle,
      shortRunBanner: shortRunBanner ?? this.shortRunBanner,
      longRunBanner: longRunBanner ?? this.longRunBanner,
      preRunSectionTitle: preRunSectionTitle ?? this.preRunSectionTitle,
      duringRunSectionTitle:
          duringRunSectionTitle ?? this.duringRunSectionTitle,
      postRunSectionTitle: postRunSectionTitle ?? this.postRunSectionTitle,
      createPlanButton: createPlanButton ?? this.createPlanButton,
      resetAllButton: resetAllButton ?? this.resetAllButton,
      helpTitle: helpTitle ?? this.helpTitle,
      helpOverview: helpOverview ?? this.helpOverview,
      helpPreRun: helpPreRun ?? this.helpPreRun,
      helpDuringRun: helpDuringRun ?? this.helpDuringRun,
      helpPostRun: helpPostRun ?? this.helpPostRun,
      helpValidation: helpValidation ?? this.helpValidation,
      isCreatingPlan: isCreatingPlan ?? this.isCreatingPlan,
      macroTargets: macroTargets ?? this.macroTargets,
      validationMessages: validationMessages ?? this.validationMessages,

      // Shared fields
      errorMessage: errorMessage ?? this.errorMessage,
      activityId: overrideActivityId
          ? activityId
          : activityId ?? this.activityId,
      eventId: overrideEventId ? eventId : eventId ?? this.eventId,
      unitSystem: unitSystem ?? this.unitSystem,
    );
  }
}

/// Controller for distance page gut entry screen
/// FOA COMPLIANT: Contains ALL business logic, no UI concerns
@Riverpod(keepAlive: true)
class MacroTargetsController extends _$MacroTargetsController {
  ContentService get _contentService => ref.read(contentServiceProvider);
  AnalyticsTracker get _analytics =>
      ref.read(appExternalDepsProvider).analytics;
  AuthService get _authService => ref.read(authServiceProvider);

  /// Tracks the current activityId outside of state so onDispose can access it
  /// without reading `state` (which is forbidden inside Riverpod lifecycle callbacks).
  String? _lastKnownActivityId;

  @override
  FutureOr<MacroTargetsState> build() async {
    // Screen views not tracked per README spec

    // Track activityId changes so onDispose can access it safely
    // (accessing state inside onDispose is forbidden by Riverpod)
    listenSelf((previous, next) {
      _lastKnownActivityId = next.value?.activityId;
    });

    // ✨ DRAFT ACTIVITY CLEANUP (Andrea Bizzotto FOA Pattern)
    // Register cleanup when provider is disposed to handle abandoned drafts
    ref.onDispose(() {
      _scheduleCleanupIfNeeded();
    });

    // Load content synchronously from in-memory cache
    final title = _contentService.getValue(
      ContentKeys.mainScreenTitle,
      defaultValue: 'Mealvana Endurance',
    );
    final distanceLabel = _contentService.getValue(
      ContentKeys.mainScreenDistanceLabel,
      defaultValue: 'Distance',
    );
    final paceLabel = _contentService.getValue(
      ContentKeys.mainScreenPaceLabel,
      defaultValue: 'Average pace',
    );
    final preRunLabel = _contentService.getValue(
      ContentKeys.mainScreenPreRunLabel,
      defaultValue: 'Time before run',
    );
    final gutTrainingLabel = _contentService.getValue(
      ContentKeys.mainScreenGutTrainingLabel,
      defaultValue: 'Gut training level',
    );
    final generateButtonText = _contentService.getValue(
      ContentKeys.mainScreenGenerateButton,
      defaultValue: 'Generate Plan',
    );
    final tipsText = _contentService.getValue(
      ContentKeys.mainScreenTipsText,
      defaultValue:
          'We will create a personalized nutrition plan based on your run details',
    );

    // Validation messages
    final distanceValidationRequired = _contentService.getValue(
      ContentKeys.validationRequired,
      defaultValue: 'Required',
    );
    final distanceValidationNumber = _contentService.getValue(
      ContentKeys.validationInvalidNumber,
      defaultValue: 'Please enter a valid number',
    );
    final distanceValidationRange = _contentService.getValue(
      ContentKeys.validationDistanceRange,
      defaultValue: 'Distance must be between 0 and 200',
    );
    final paceValidationRequired = _contentService.getValue(
      ContentKeys.validationRequired,
      defaultValue: 'Required',
    );
    final paceValidationFormat = _contentService.getValue(
      ContentKeys.validationPaceFormat,
      defaultValue: 'Format: 8:30 or 8.5',
    );
    final errorGeneric = _contentService.getValue(
      ContentKeys.errorGeneric,
      defaultValue: 'Something went wrong. Please try again.',
    );

    // Adjust macros content
    final adjustMacrosTitle = _contentService.getValue(
      'adjust_macros.screen_title',
      defaultValue: 'Adjust Your Macros',
    );
    final shortRunBanner = _contentService.getValue(
      'adjust_macros.banner.short_run',
      defaultValue: 'For this duration, during-run carbs are optional',
    );
    final longRunBanner = _contentService.getValue(
      'adjust_macros.banner.long_run',
      defaultValue: 'Target at least {amount}g carbs during your run',
    );
    final preRunSectionTitle = _contentService.getValue(
      'adjust_macros.sections.pre_run',
      defaultValue: 'Pre-Run',
    );
    final duringRunSectionTitle = _contentService.getValue(
      'adjust_macros.sections.during_run',
      defaultValue: 'During Run',
    );
    final postRunSectionTitle = _contentService.getValue(
      'adjust_macros.sections.post_run',
      defaultValue: 'Post-Run (within 30 min)',
    );
    final createPlanButton = _contentService.getValue(
      'adjust_macros.actions.create_plan',
      defaultValue: 'Create Plan',
    );
    final resetAllButton = _contentService.getValue(
      'adjust_macros.actions.reset_all',
      defaultValue: 'Reset All',
    );
    final helpTitle = _contentService.getValue(
      'adjust_macros.help_content.title',
      defaultValue: 'Nutrition Science & Guidance',
    );
    final helpOverview = _contentService.getValue(
      'adjust_macros.help_content.overview',
      defaultValue:
          'These targets are based on ISSN guidelines and sports nutrition research tailored to your run parameters.',
    );
    final helpPreRun = _contentService.getValue(
      'adjust_macros.help_content.pre_run',
      defaultValue:
          'Pre-run fueling optimizes energy stores and prevents GI distress during exercise.',
    );
    final helpDuringRun = _contentService.getValue(
      'adjust_macros.help_content.during_run',
      defaultValue:
          'During-run nutrition maintains blood glucose and delays fatigue during longer efforts.',
    );
    final helpPostRun = _contentService.getValue(
      'adjust_macros.help_content.post_run',
      defaultValue:
          'Post-run nutrition accelerates glycogen replenishment and muscle protein synthesis.',
    );
    final helpValidation = _contentService.getValue(
      'adjust_macros.help_content.validation',
      defaultValue:
          'Warning indicators show values outside research-backed ranges but won\'t prevent plan creation.',
    );

    // Load cached macro targets
    final repository = ref.read(macroRepositoryProvider);
    final cachedTargets = await repository.getCachedMacroTargets();

    // Load user preferences for unit system
    final user = await _authService.getCurrentUser();
    final unitSystem = user?.unitSystem ?? UnitSystem.imperial;

    return MacroTargetsState(
      title: title,
      distanceLabel: distanceLabel,
      paceLabel: paceLabel,
      preRunLabel: preRunLabel,
      gutTrainingLabel: gutTrainingLabel,
      generateButtonText: generateButtonText,
      tipsText: tipsText,
      distanceValidationRequired: distanceValidationRequired,
      distanceValidationNumber: distanceValidationNumber,
      distanceValidationRange: distanceValidationRange,
      paceValidationRequired: paceValidationRequired,
      paceValidationFormat: paceValidationFormat,
      errorGeneric: errorGeneric,
      isGenerating: false,
      isGeneratingMacros: false,

      adjustMacrosTitle: adjustMacrosTitle,
      shortRunBanner: shortRunBanner,
      longRunBanner: longRunBanner,
      preRunSectionTitle: preRunSectionTitle,
      duringRunSectionTitle: duringRunSectionTitle,
      postRunSectionTitle: postRunSectionTitle,
      createPlanButton: createPlanButton,
      resetAllButton: resetAllButton,
      helpTitle: helpTitle,
      helpOverview: helpOverview,
      helpPreRun: helpPreRun,
      helpDuringRun: helpDuringRun,
      helpPostRun: helpPostRun,
      helpValidation: helpValidation,
      isCreatingPlan: false,
      macroTargets: cachedTargets,
      unitSystem: unitSystem,
    );
  }

  /// Load user preferences from the user profile
  Future<void> loadUserPreferences() async {
    // TODO: Load user profile when auth service method is available
    // For now, use default gut training level
  }

  /// Clear cached macro targets
  /// Called when switching sports to ensure stale data doesn't persist
  Future<void> clearCachedMacros() async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(
      currentState.copyWith(
        macroTargets: null,
        activityId: null,
        eventId: null,
        overrideActivityId: true,
        overrideEventId: true,
      ),
    );

    // Also clear from repository cache
    final repository = ref.read(macroRepositoryProvider);
    await repository.clearCachedMacroTargets();
  }

  /// Generate macro targets by calling the generate-macros edge function
  /// Also creates the activity in the calendar database
  Future<void> generateMacros({
    required String distanceText,
    required String paceText,
    required int timeBeforeRunMinutes,
    required GutTraining gutTraining,
    required DistanceUnit distanceUnit,
    required PaceUnit paceUnit,
    required DateTime scheduledDate,
    required TimeOfDay scheduledTime,
    SweatRateCat? sweatRateCat,
    double? temperatureC,
    double? humidityPct,
    bool isFasted = false,
    IntensityDistribution? intensity,
    String? activityId, // Link to calendar activity/event
    String? eventId, // Link to calendar event (for provider invalidation)
    String?
    forUserId, // NEW: If provided, create activity for this user (coach creating for athlete)
  }) async {
    // CRITICAL FIX: Ensure state is loaded before proceeding
    // state.value can be null if build() hasn't completed yet
    final currentState = state.value;
    if (currentState == null) {
      DebugLogger.error(
        '❌ MAIN CONTROLLER: state.value is NULL - state not loaded yet! Waiting for state...',
      );
      // Wait for the async build to complete
      await future;
      // Now recursively call with loaded state
      return generateMacros(
        distanceText: distanceText,
        paceText: paceText,
        timeBeforeRunMinutes: timeBeforeRunMinutes,
        gutTraining: gutTraining,
        distanceUnit: distanceUnit,
        paceUnit: paceUnit,
        scheduledDate: scheduledDate,
        scheduledTime: scheduledTime,
        sweatRateCat: sweatRateCat,
        temperatureC: temperatureC,
        humidityPct: humidityPct,
        isFasted: isFasted,
        intensity: intensity,
        activityId: activityId,
        eventId: eventId,
        forUserId: forUserId,
      );
    }

    // Set loading state
    state = AsyncData(
      currentState.copyWith(isGeneratingMacros: true, errorMessage: null),
    );

    state = await AsyncValue.guard(() async {
      String deviceId = 'unknown';
      try {
        // Parse and validate input
        final distance = double.tryParse(distanceText) ?? 5.0;
        final paceString = paceText.trim();

        // Parse pace (e.g., "8:30" -> 8.5 minutes per mile)
        final paceParts = paceString.split(':');
        final paceMinutes = paceParts.length == 2
            ? (double.tryParse(paceParts[0]) ?? 8.0) +
                  ((double.tryParse(paceParts[1]) ?? 30.0) / 60.0)
            : double.tryParse(paceString) ?? 8.5;

        // Track plan generation started - entry point for North-Star metrics
        final user = await _authService.getCurrentUser();
        deviceId = user?.id ?? 'unknown';

        await _analytics.trackPlanGenerationStarted(
          deviceId: deviceId,
          activityId: activityId,
          distanceMiles: distance,
          paceMinutesPerMile: paceMinutes,
          gutTrainingLevel: gutTraining.name,
        );

        // 🆕 CREATE DRAFT ACTIVITY IMMEDIATELY if activityId doesn't exist
        final scheduledDateTime = DateTime(
          scheduledDate.year,
          scheduledDate.month,
          scheduledDate.day,
          scheduledTime.hour,
          scheduledTime.minute,
        );

        String finalActivityId = activityId ?? '';
        final activitiesController = ref.read(
          activitiesControllerProvider.notifier,
        );

        if (finalActivityId.isEmpty) {
          finalActivityId = await activitiesController.createActivity(
            title: "$distance mi Run",
            scheduledDateTime: scheduledDateTime,
            forUserId:
                forUserId, // NEW: Pass through forUserId for coach-created activities
            activityType: ActivityType.running,
            distanceMiles: distance,
            paceTargetMinutesPerMile: paceMinutes,
            intensityLevel: domain.IntensityLevel.moderate, // Default
            timeBeforeMinutes: timeBeforeRunMinutes,
            notes: 'Draft activity - nutrition plan being generated',
          );
        } else {
          final existingActivity = await activitiesController.getActivityById(
            finalActivityId,
          );
          if (existingActivity != null) {
            await activitiesController.updateActivity(
              existingActivity.copyWith(
                title: "$distance mi Run",
                activityType: ActivityType.running,
                scheduledDateTime: scheduledDateTime,
                distanceMiles: distance,
                paceTargetMinutesPerMile: paceMinutes,
                timeBeforeMinutes: timeBeforeRunMinutes,
                notes: 'Draft activity - nutrition plan being generated',
              ),
            );
          }
        }

        // Call generate-macros-v3 edge function directly
        await _generateMacroTargets(
          activityId: finalActivityId,
          deviceId: deviceId,
          distanceMiles: distance,
          paceMinutesPerMile: paceMinutes,
          timeBeforeRunMinutes: timeBeforeRunMinutes,
          gutTraining: gutTraining,
          sweatRateCat: sweatRateCat,
          temperatureC: temperatureC,
          humidityPct: humidityPct,
          isFasted: isFasted,
          intensity: intensity,
        );

        // Get the generated macro targets from cache to track analytics
        final repository = ref.read(macroRepositoryProvider);
        var macroTargets = await repository.getCachedMacroTargets();

        // Apply user profile nutrition target overrides (if any)
        if (macroTargets != null) {
          macroTargets = await _maybeApplyOverrides(macroTargets);
          await repository.saveMacroTargets(macroTargets);
        }

        // Update state to not generating and include macro targets with finalActivityId
        return currentState.copyWith(
          isGeneratingMacros: false,
          errorMessage: null,
          macroTargets: macroTargets,
          activityId:
              finalActivityId, // Always has a value now (draft created if needed)
          eventId: eventId, // Store event ID for provider invalidation
          overrideActivityId: true,
          overrideEventId: true,
        );
      } catch (error) {
        DebugLogger.error('❌ DEBUG: Error generating macro targets: $error');

        // Track the error
        await _analytics.track(
          'app_error',
          properties: {
            'error_type': 'Macro Targets Generation Error',
            'error_message': error.toString(),
            'screen_name': 'Distance Page Gut Entry',
            'distance': distanceText,
            'pace': paceText,
          },
        );

        // Track macro generation failed
        await _analytics.trackPlanGenerationFailed(
          deviceId: deviceId,
          activityId: activityId,
          distanceMiles: double.tryParse(distanceText) ?? 5.0,
          paceMinutesPerMile: double.tryParse(paceText) ?? 8.5,
          errorMessage: error.toString(),
        );

        rethrow; // Re-throw so the screen can handle it
      }
    });
  }

  /// Generate cycling macro targets - delegates to MacroGenerationService
  Future<void> generateCyclingMacros({
    required double distanceMiles,
    required double speedMph,
    required String terrain,
    required String indoorOutdoor,
    required int elevationGainFt,
    required String sessionGoal,
    required String intensityTarget,
    required int timeBeforeMinutes,
    required DateTime scheduledDate,
    required TimeOfDay scheduledTime,
    required double temperatureC,
    required double humidityPct,
    bool isFasted = false,
    IntensityDistribution? intensity,
    String? activityId,
    String? eventId,
    String? forUserId,
  }) async {
    final currentState = state.value;
    if (currentState == null) return;

    // Set loading state
    state = AsyncData(
      currentState.copyWith(isGeneratingMacros: true, errorMessage: null),
    );

    state = await AsyncValue.guard(() async {
      String deviceId = 'unknown';

      try {
        // Track plan generation started
        final user = await _authService.getCurrentUser();
        deviceId = user?.id ?? 'unknown';

        await _analytics.trackPlanGenerationStarted(
          deviceId: deviceId,
          activityId: activityId,
          distanceMiles: distanceMiles,
          paceMinutesPerMile:
              60.0 / speedMph, // Convert speed to pace equivalent
          gutTrainingLevel: user?.gutTraining.name ?? 'medium',
        );

        // 🆕 CREATE DRAFT ACTIVITY IMMEDIATELY if activityId doesn't exist
        final scheduledDateTime = DateTime(
          scheduledDate.year,
          scheduledDate.month,
          scheduledDate.day,
          scheduledTime.hour,
          scheduledTime.minute,
        );

        String finalActivityId = activityId ?? '';
        final activitiesController = ref.read(
          activitiesControllerProvider.notifier,
        );

        if (finalActivityId.isEmpty) {
          finalActivityId = await activitiesController.createActivity(
            title: "$distanceMiles mi Ride",
            scheduledDateTime: scheduledDateTime,
            forUserId:
                forUserId, // NEW: Pass through forUserId for coach-created activities
            activityType: ActivityType.cycling,
            distanceMiles: distanceMiles,
            cyclingSpeedMph: speedMph,
            cyclingTerrain: terrain,
            cyclingIndoorOutdoor: indoorOutdoor,
            cyclingElevationGainFt: elevationGainFt,
            cyclingSessionGoal: sessionGoal,
            intensityTarget: intensityTarget,
            intensityLevel: domain.IntensityLevel.moderate, // Default
            timeBeforeMinutes: timeBeforeMinutes,
            notes: 'Draft cycling activity - nutrition plan being generated',
          );
        } else {
          final existingActivity = await activitiesController.getActivityById(
            finalActivityId,
          );
          if (existingActivity != null) {
            await activitiesController.updateActivity(
              existingActivity.copyWith(
                title: "$distanceMiles mi Ride",
                activityType: ActivityType.cycling,
                scheduledDateTime: scheduledDateTime,
                distanceMiles: distanceMiles,
                cyclingSpeedMph: speedMph,
                cyclingTerrain: terrain,
                cyclingIndoorOutdoor: indoorOutdoor,
                cyclingElevationGainFt: elevationGainFt,
                cyclingSessionGoal: sessionGoal,
                intensityTarget: intensityTarget,
                timeBeforeMinutes: timeBeforeMinutes,
                notes:
                    'Draft cycling activity - nutrition plan being generated',
              ),
            );
          }
        }

        // Create the service instance
        final macroService = MacroGenerationService(
          supabaseClient: ref.read(appExternalDepsProvider).supabaseClient,
          macroRepository: ref.read(macroRepositoryProvider),
          authService: _authService,
          analytics: _analytics,
        );

        // Call the service
        var macroTargets = await macroService.generateCyclingMacros(
          activityId: finalActivityId,
          deviceId: deviceId,
          distanceMiles: distanceMiles,
          speedMph: speedMph,
          terrain: terrain,
          indoorOutdoor: indoorOutdoor,
          timeBeforeMinutes: timeBeforeMinutes,
          elevationGainFt: elevationGainFt,
          intensityTarget: intensityTarget,
          sessionGoal: sessionGoal,
          temperatureC: temperatureC,
          humidityPct: humidityPct,
          isFasted: isFasted,
          intensity: intensity,
        );

        // Apply user profile nutrition target overrides (if any)
        macroTargets = await _maybeApplyOverrides(macroTargets);

        return currentState.copyWith(
          isGeneratingMacros: false,
          macroTargets: macroTargets,
          activityId:
              finalActivityId, // Always has a value now (draft created if needed)
          eventId: eventId,
          overrideActivityId: true,
          overrideEventId: true,
        );
      } catch (error) {
        DebugLogger.error(
          '❌ DEBUG: Error generating cycling macro targets: $error',
        );

        // Track the error
        await _analytics.track(
          'app_error',
          properties: {
            'error_type': 'Cycling Macro Targets Generation Error',
            'error_message': error.toString(),
            'screen_name': 'Cycling Input',
            'distance': distanceMiles,
            'speed': speedMph,
          },
        );

        // Track macro generation failed
        await _analytics.trackPlanGenerationFailed(
          deviceId: deviceId,
          activityId: activityId,
          distanceMiles: distanceMiles,
          paceMinutesPerMile: 60.0 / speedMph,
          errorMessage: error.toString(),
        );

        rethrow; // Re-throw so the screen can handle it
      }
    });
  }

  /// Generate macro targets by calling the generate-macros-v3 edge function
  Future<void> _generateMacroTargets({
    String? activityId,
    required String deviceId,
    required double distanceMiles,
    required double paceMinutesPerMile,
    required int timeBeforeRunMinutes,
    required GutTraining gutTraining,
    SweatRateCat? sweatRateCat,
    double? temperatureC,
    double? humidityPct,
    bool isFasted = false,
    IntensityDistribution? intensity,
  }) async {
    // Get user profile data
    final userProfile = await _authService.getCurrentUser();

    // Calculate user metrics with fallbacks to reasonable defaults
    final age = userProfile?.age ?? 30;
    final gender = userProfile?.gender.name ?? 'other';
    final weightKg = userProfile != null
        ? userProfile.weightPounds *
              0.453592 // Convert lbs to kg
        : 70.0; // Default 70kg if no profile
    final heightCm = userProfile != null
        ? userProfile.totalHeightInches *
              2.54 // Convert inches to cm
        : 170.0; // Default 170cm if no profile

    // V3: Convert minutes to hours for the new edge function
    final hoursBefore = timeBeforeRunMinutes / 60.0;

    // V3: Normalize intensity distribution to fractions (0-1)
    final zoneLow = (intensity?.conversationalPct ?? 70) / 100.0;
    final zoneMid = (intensity?.tempoPct ?? 20) / 100.0;
    final zoneHigh = (intensity?.allOutPct ?? 10) / 100.0;

    final requestData = {
      'activity_type': 'running',
      'age': age,
      'gender': gender,
      'weight': weightKg,
      'weight_unit': 'kg',
      'height': heightCm,
      'height_unit': 'cm',
      'run_pace': paceMinutesPerMile,
      'run_distance': distanceMiles,
      'run_pace_unit': 'min_per_mile',
      'run_distance_unit': 'mi',
      // V3 params
      'hours_before': hoursBefore,
      'is_fasted': isFasted,
      'intensity_distribution': {
        'zone_low': zoneLow,
        'zone_mid': zoneMid,
        'zone_high': zoneHigh,
      },
      // Legacy param kept for backward compat
      'time_before_run_min': timeBeforeRunMinutes,
      'gut_training': gutTraining.name,
      'carb_source': 'dual',
      'sweat_sodium': 'medium',
      'drink_sodium_mg_per_l': 500,
      'optional_sweat_rate_lph': null,
      'sweat_rate_category': sweatRateCat?.name ?? 'medium',
      'temp_c': temperatureC,
      'humidity_pct': humidityPct,
    };

    // Call the generate-macros-v3 edge function
    final supabase = ref.read(appExternalDepsProvider).supabaseClient;
    final response = await supabase.functions.invoke(
      'generate-macros-v3',
      body: requestData,
    );

    if (response.status >= 400) {
      final data = response.data as Map<String, dynamic>?;
      throw Exception(data?['message'] ?? 'Failed to generate macro targets');
    }

    // Parse the response
    final data = response.data as Map<String, dynamic>;

    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to generate macro targets');
    }

    final macrosData = data['macros'] as Map<String, dynamic>;

    // Helper function to safely convert to double
    double toDouble(dynamic value, [String fieldName = 'unknown']) {
      try {
        if (value == null) return 0.0;
        if (value is double) return value;
        if (value is int) return value.toDouble();
        if (value is String) return double.tryParse(value) ?? 0.0;
        return (value as num).toDouble();
      } catch (e) {
        DebugLogger.error(
          '❌ DEBUG: Error converting field "$fieldName" with value "$value" (${value.runtimeType}) to double: $e',
        );
        return 0.0;
      }
    }

    // Helper function to safely convert list to List<double>
    List<double> toDoubleList(
      dynamic value, [
      List<double> defaultValue = const [30, 60],
    ]) {
      if (value == null) return defaultValue;
      if (value is List) {
        return value.map((e) => toDouble(e)).toList();
      }
      return defaultValue;
    }

    // Convert edge function response to MacroTargets with correct field names
    final macroTargets = MacroTargets(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      activityType: ActivityType.running,
      preRun: PreRunMacros(
        carbsG: toDouble(macrosData['pre_run_carbs_g'], 'pre_run_carbs_g'),
        proteinG: toDouble(
          macrosData['pre_run_protein_g_optional'],
          'pre_run_protein_g_optional',
        ),
        fatCapG: toDouble(macrosData['pre_run_fat_g_cap'], 'pre_run_fat_g_cap'),
        fluidsMl: toDouble(macrosData['pre_run_water_ml'], 'pre_run_water_ml'),
        sodiumMg: toDouble(
          macrosData['pre_run_sodium_mg'],
          'pre_run_sodium_mg',
        ),
      ),
      duringRun: DuringRunMacros(
        carbRateGPerH: toDouble(
          macrosData['during_rate_g_per_h'],
          'during_rate_g_per_h',
        ),
        carbTotalG: toDouble(macrosData['during_total_g'], 'during_total_g'),
        fluidRateMlPerH: toDouble(
          macrosData['during_water_rate_ml_per_h'],
          'during_water_rate_ml_per_h',
        ),
        fluidTotalMl: toDouble(
          macrosData['during_water_total_ml'],
          'during_water_total_ml',
        ),
        sodiumRateMgPerH: toDouble(
          macrosData['during_sodium_rate_mg_per_h'],
          'during_sodium_rate_mg_per_h',
        ),
        sodiumTotalMg: toDouble(
          macrosData['during_sodium_total_mg'],
          'during_sodium_total_mg',
        ),
        massNormRateGPerH: toDouble(
          macrosData['during_mass_norm_rate_g_per_h'],
          'during_mass_norm_rate_g_per_h',
        ),
        absClampRangeGPerH: toDoubleList(
          macrosData['during_abs_clamp_range_g_per_h'],
        ),
      ),
      postRun: PostRunMacros(
        carbsG: toDouble(macrosData['post_run_carbs_g'], 'post_run_carbs_g'),
        proteinG: toDouble(
          macrosData['post_run_protein_g'],
          'post_run_protein_g',
        ),
        fluidsMl: toDouble(
          macrosData['post_run_water_ml'],
          'post_run_water_ml',
        ),
        sodiumMg: toDouble(
          macrosData['post_run_sodium_mg'],
          'post_run_sodium_mg',
        ),
      ),
      metrics: () {
        // Compute derived metrics client-side since the edge function
        // only returns distance_km, duration_h, and duration_min
        final distanceKm = toDouble(macrosData['distance_km'], 'distance_km');
        final durationH = toDouble(macrosData['duration_h'], 'duration_h');
        final durationMin = toDouble(
          macrosData['duration_min'],
          'duration_min',
        );
        final distanceMi = distanceKm > 0 ? distanceKm / 1.60934 : 0.0;
        final speedMph = (distanceMi > 0 && durationH > 0)
            ? distanceMi / durationH
            : 0.0;
        final paceMinPerMile = (distanceMi > 0 && durationMin > 0)
            ? durationMin / distanceMi
            : null;

        return RunMetrics(
          distanceMi: distanceMi,
          distanceKm: distanceKm,
          durationH: durationH,
          durationMin: durationMin,
          paceMinPerMile: paceMinPerMile,
          speedMph: speedMph,
          caloriesNetKcal: toDouble(
            macrosData['calories_net_kcal'],
            'calories_net_kcal',
          ),
          caloriesGrossKcal: toDouble(
            macrosData['calories_gross_kcal'],
            'calories_gross_kcal',
          ),
          met: toDouble(macrosData['MET'], 'MET'),
        );
      }(),
      calculationRule:
          macrosData['pre_run_carbs_rule'] ?? 'Generated from edge function',
      timestamp: DateTime.now(),
      isUserModified: false,
    );

    // Cache the macro targets
    final repository = ref.read(macroRepositoryProvider);
    await repository.saveMacroTargets(macroTargets);

    await _analytics.trackPlanGenerated(
      deviceId: deviceId,
      activityId: activityId,
      activityType: 'running',
      distanceMiles: distanceMiles,
      paceMinutesPerMile: paceMinutesPerMile,
      totalCalories: macroTargets.metrics.caloriesNetKcal.round(),
      totalCarbs:
          (macroTargets.preRun.carbsG +
                  macroTargets.duringRun.carbTotalG +
                  macroTargets.postRun.carbsG)
              .round(),
      beforeRunItems: 1,
      duringRunItems: 1,
      afterRunItems: 1,
      isFirstPlan: true,
    );
  }

  /// Generate macros for running (wrapper around main generateMacros)
  Future<void> generateRunningMacros({
    required String distanceText,
    required String paceText,
    required int timeBeforeRunMinutes,
    required GutTraining gutTraining,
    required DistanceUnit distanceUnit,
    required PaceUnit paceUnit,
    required DateTime scheduledDate,
    required TimeOfDay scheduledTime,
    SweatRateCat? sweatRateCat,
    double? temperatureC,
    double? humidityPct,
    bool isFasted = false,
    IntensityDistribution? intensity,
    String? activityId,
    String? eventId,
    String?
    forUserId, // NEW: If provided, create activity for this user (coach creating for athlete)
  }) async {
    // Delegate to the main generateMacros method
    await generateMacros(
      distanceText: distanceText,
      paceText: paceText,
      timeBeforeRunMinutes: timeBeforeRunMinutes,
      gutTraining: gutTraining,
      distanceUnit: distanceUnit,
      paceUnit: paceUnit,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      sweatRateCat: sweatRateCat,
      temperatureC: temperatureC,
      humidityPct: humidityPct,
      isFasted: isFasted,
      intensity: intensity,
      activityId: activityId,
      eventId: eventId,
      forUserId: forUserId, // NEW: Pass through forUserId
    );
  }

  /// Generate macros for swimming
  Future<void> generateSwimmingMacros({
    required int distanceMeters,
    required int paceSecondsper100m,
    required String poolOrOpenWater,
    required double waterTempC,
    required String intensityTarget,
    required String sessionGoal,
    required int timeBeforeMinutes,
    IntensityDistribution? intensity,
    required DateTime scheduledDate,
    required TimeOfDay scheduledTime,
    String? activityId,
    String? eventId,
    String? forUserId,
  }) async {
    final currentState = state.value;
    if (currentState == null) return;

    // Set loading state
    state = AsyncData(
      currentState.copyWith(isGeneratingMacros: true, errorMessage: null),
    );

    state = await AsyncValue.guard(() async {
      String deviceId = 'unknown';

      try {
        // Track plan generation started
        final user = await _authService.getCurrentUser();
        deviceId = user?.id ?? 'unknown';

        // Calculate approximate pace in min/mile for analytics
        final distanceMiles = distanceMeters / 1609.34;
        final durationMinutes =
            (distanceMeters / 100.0) * (paceSecondsper100m / 60.0);
        final approximatePaceMinPerMile = durationMinutes / distanceMiles;

        await _analytics.trackPlanGenerationStarted(
          deviceId: deviceId,
          activityId: activityId,
          distanceMiles: distanceMiles,
          paceMinutesPerMile: approximatePaceMinPerMile,
          gutTrainingLevel: user?.gutTraining.name ?? 'medium',
        );

        // 🆕 CREATE DRAFT ACTIVITY IMMEDIATELY if activityId doesn't exist
        final scheduledDateTime = DateTime(
          scheduledDate.year,
          scheduledDate.month,
          scheduledDate.day,
          scheduledTime.hour,
          scheduledTime.minute,
        );

        String finalActivityId = activityId ?? '';
        final activitiesController = ref.read(
          activitiesControllerProvider.notifier,
        );

        if (finalActivityId.isEmpty) {
          finalActivityId = await activitiesController.createActivity(
            title: "$distanceMeters m Swim",
            scheduledDateTime: scheduledDateTime,
            forUserId:
                forUserId, // NEW: Pass through forUserId for coach-created activities
            activityType: ActivityType.swimming,
            distanceMiles: distanceMiles,
            swimmingPacePer100mSeconds: paceSecondsper100m,
            swimmingPoolOrOpenWater: poolOrOpenWater,
            swimmingWaterTempC: waterTempC,
            intensityTarget: intensityTarget,
            intensityLevel: domain.IntensityLevel.moderate, // Default
            timeBeforeMinutes: timeBeforeMinutes,
            notes: 'Draft swimming activity - nutrition plan being generated',
          );
        } else {
          final existingActivity = await activitiesController.getActivityById(
            finalActivityId,
          );
          if (existingActivity != null) {
            await activitiesController.updateActivity(
              existingActivity.copyWith(
                title: "$distanceMeters m Swim",
                activityType: ActivityType.swimming,
                scheduledDateTime: scheduledDateTime,
                distanceMiles: distanceMiles,
                swimmingPacePer100mSeconds: paceSecondsper100m,
                swimmingPoolOrOpenWater: poolOrOpenWater,
                swimmingWaterTempC: waterTempC,
                intensityTarget: intensityTarget,
                timeBeforeMinutes: timeBeforeMinutes,
                notes:
                    'Draft swimming activity - nutrition plan being generated',
              ),
            );
          }
        }

        // Create the service instance
        final macroService = MacroGenerationService(
          supabaseClient: ref.read(appExternalDepsProvider).supabaseClient,
          macroRepository: ref.read(macroRepositoryProvider),
          authService: _authService,
          analytics: _analytics,
        );

        // Call the service
        var macroTargets = await macroService.generateSwimmingMacros(
          activityId: finalActivityId,
          deviceId: deviceId,
          distanceMeters: distanceMeters,
          paceSecondsper100m: paceSecondsper100m,
          poolOrOpenWater: poolOrOpenWater,
          timeBeforeMinutes: timeBeforeMinutes,
          intensityTarget: intensityTarget,
          sessionGoal: sessionGoal,
          waterTempC: waterTempC,
          intensity: intensity,
        );

        // Apply user profile nutrition target overrides (if any)
        macroTargets = await _maybeApplyOverrides(macroTargets);

        return currentState.copyWith(
          isGeneratingMacros: false,
          macroTargets: macroTargets,
          activityId:
              finalActivityId, // Always has a value now (draft created if needed)
          eventId: eventId,
          overrideActivityId: true,
          overrideEventId: true,
        );
      } catch (error) {
        DebugLogger.error(
          '❌ DEBUG: Error generating swimming macro targets: $error',
        );

        // Track the error
        await _analytics.track(
          'app_error',
          properties: {
            'error_type': 'Swimming Macro Targets Generation Error',
            'error_message': error.toString(),
            'screen_name': 'Swimming Input',
            'distance': distanceMeters,
            'pace': paceSecondsper100m,
          },
        );

        // Track macro generation failed
        await _analytics.trackPlanGenerationFailed(
          deviceId: deviceId,
          activityId: activityId,
          distanceMiles: distanceMeters / 1609.34,
          paceMinutesPerMile:
              (distanceMeters / 100.0) *
              (paceSecondsper100m / 60.0) /
              (distanceMeters / 1609.34),
          errorMessage: error.toString(),
        );

        rethrow; // Re-throw so the screen can handle it
      }
    });
  }

  /// Generate macros for brick workouts
  Future<void> generateBrickMacros({
    required List<BrickSegment> segments,
    required List<String> segmentOrder,
    required DateTime scheduledDate,
    required TimeOfDay scheduledTime,
    required bool isFasted,
    String? activityId,
    String? eventId,
    String?
    forUserId, // If provided, create activity for this user (coach creating for athlete)
  }) async {
    final currentState = state.value;
    if (currentState == null) return;

    // Set loading state
    state = AsyncData(
      currentState.copyWith(isGeneratingMacros: true, errorMessage: null),
    );

    state = await AsyncValue.guard(() async {
      String deviceId = 'unknown';

      try {
        // Track plan generation started
        final user = await _authService.getCurrentUser();
        deviceId = user?.id ?? 'unknown';

        // Calculate total distance for analytics
        double totalDistanceMiles = 0.0;
        for (final segment in segments) {
          if (segment.distanceMiles != null) {
            totalDistanceMiles += segment.distanceMiles!;
          }
        }

        await _analytics.trackPlanGenerationStarted(
          deviceId: deviceId,
          activityId: activityId,
          distanceMiles: totalDistanceMiles,
          paceMinutesPerMile: 0.0, // Not applicable for brick
          gutTrainingLevel: user?.gutTraining.name ?? 'medium',
        );

        // 🆕 CREATE DRAFT ACTIVITY IMMEDIATELY if activityId doesn't exist
        final scheduledDateTime = DateTime(
          scheduledDate.year,
          scheduledDate.month,
          scheduledDate.day,
          scheduledTime.hour,
          scheduledTime.minute,
        );

        final totalDurationMinutes = segments.fold<int>(
          0,
          (total, segment) => total + segment.durationMinutes,
        );

        final brickMetadata = BrickMetadata(
          segmentOrder: segmentOrder,
          segments: segments,
          originalActivityIds: null,
          createdFromExisting: false,
          totalDurationMinutes: totalDurationMinutes,
        );

        String finalActivityId = activityId ?? '';
        final activitiesController = ref.read(
          activitiesControllerProvider.notifier,
        );

        if (finalActivityId.isEmpty) {
          // Build brick title (e.g., "SWIM/RUN BRICK")
          final sportNames = segmentOrder.map((s) => s.toUpperCase()).join('/');
          final brickTitle = '$sportNames BRICK';

          DebugLogger.info('🧱 DEBUG: Creating draft brick activity');
          DebugLogger.info(
            '🧱 DEBUG: segmentOrder=$segmentOrder, totalDurationMinutes=$totalDurationMinutes',
          );

          finalActivityId = await activitiesController.createActivity(
            title: brickTitle,
            scheduledDateTime: scheduledDateTime,
            forUserId: forUserId,
            activityType: ActivityType.brick,
            intensityLevel: domain.IntensityLevel.moderate, // Default
            durationMinutes: totalDurationMinutes,
            brickMetadata: brickMetadata,
            notes: 'Draft brick activity - nutrition plan being generated',
          );
        } else {
          final existingActivity = await activitiesController.getActivityById(
            finalActivityId,
          );
          if (existingActivity != null) {
            final hasSegments =
                existingActivity.brickMetadata?.segments.isNotEmpty ?? false;
            if (!hasSegments) {
              DebugLogger.info(
                '🧱 DEBUG: Backfilling brick metadata for activityId=$finalActivityId',
              );
            }

            final sportNames = segmentOrder
                .map((s) => s.toUpperCase())
                .join('/');
            final brickTitle = '$sportNames BRICK';
            await activitiesController.updateActivity(
              existingActivity.copyWith(
                title: brickTitle,
                activityType: ActivityType.brick,
                scheduledDateTime: scheduledDateTime,
                brickMetadata: brickMetadata,
                durationMinutes: totalDurationMinutes,
                notes: 'Draft brick activity - nutrition plan being generated',
              ),
            );
          }
        }

        // Create the service instance
        final brickMacroService = BrickMacroService(
          supabaseClient: ref.read(appExternalDepsProvider).supabaseClient,
          macroRepository: ref.read(macroRepositoryProvider),
          authService: _authService,
          analytics: _analytics,
        );

        // Call the service
        var macroTargets = await brickMacroService.generateBrickMacros(
          activityId: finalActivityId,
          deviceId: deviceId,
          segments: segments,
          segmentOrder: segmentOrder,
          isFasted: isFasted,
        );

        // Apply user profile nutrition target overrides (if any)
        macroTargets = await _maybeApplyOverrides(macroTargets);

        return currentState.copyWith(
          isGeneratingMacros: false,
          macroTargets: macroTargets,
          activityId:
              finalActivityId, // Always has a value now (draft created if needed)
          eventId: eventId,
          overrideActivityId: true,
          overrideEventId: true,
        );
      } catch (error) {
        DebugLogger.error(
          '❌ DEBUG: Error generating brick macro targets: $error',
        );

        // Track the error
        await _analytics.track(
          'app_error',
          properties: {
            'error_type': 'Brick Macro Targets Generation Error',
            'error_message': error.toString(),
            'screen_name': 'Brick Input',
            'segment_count': segments.length,
          },
        );

        // Track macro generation failed
        await _analytics.trackPlanGenerationFailed(
          deviceId: deviceId,
          activityId: activityId,
          distanceMiles: 0.0,
          paceMinutesPerMile: 0.0,
          errorMessage: error.toString(),
        );

        rethrow; // Re-throw so the screen can handle it
      }
    });
  }

  /// Update a specific macro value and recalculate linked values
  Future<void> updateMacroValue({
    required MacroSection section,
    required MacroField field,
    required double newValue,
  }) async {
    final repository = ref.read(macroRepositoryProvider);
    final cachedTargets = await repository.getCachedMacroTargets();

    if (cachedTargets == null) return;
    final currentStateSnapshot = state.value;
    final activityId = currentStateSnapshot?.activityId;

    // Track macro adjustment using documented macros_changed event
    final oldValue = _getFieldCurrentValue(cachedTargets, field);
    await _analytics.track(
      'macros_changed',
      properties: {
        if (activityId != null) 'activity_id': activityId,
        'screen': 'adjust_macros_screen',
        'experiment_variant': 'auto_items_v1',
        'macro': '${section.name}_${field.name}',
        'old_value': oldValue ?? 0.0,
        'new_value': newValue,
      },
    );

    try {
      final updatedTargets = await repository.updateMacroTargets(
        cachedTargets,
        section,
        field,
        newValue,
      );

      // Track successful update
      await _analytics.track(
        'macro_value_updated_successfully',
        properties: {
          'section': section.name,
          'field': field.name,
          'final_value': newValue,
        },
      );

      // Refresh state with updated targets
      final currentState = state.value;
      if (currentState != null) {
        state = AsyncData(currentState.copyWith(macroTargets: updatedTargets));
      }
    } catch (error) {
      // Track error
      await _analytics.track(
        'app_error',
        properties: {
          'error_type': 'Macro Update Error',
          'error_message': error.toString(),
          'screen_name': 'Adjust Macros',
          'section': section.name,
          'field': field.name,
          'attempted_value': newValue,
        },
      );

      rethrow;
    }
  }

  /// Reset all values to the original recommended values
  Future<void> resetToRecommended() async {
    final repository = ref.read(macroRepositoryProvider);
    final cachedTargets = await repository.getCachedMacroTargets();

    if (cachedTargets == null) return;

    // Track reset action
    await _analytics.track(
      'macro_values_reset',
      properties: {
        if (state.value?.activityId != null)
          'activity_id': state.value!.activityId,
        'previous_modifications_count': _countModifiedFields(cachedTargets),
      },
    );

    try {
      // Get the original macro targets that were stored when first generated
      final originalTargets = await repository.getOriginalMacroTargets();

      if (originalTargets != null) {
        // Use the original targets with updated ID and timestamp to replace current
        final restoredTargets = originalTargets.copyWith(
          id: cachedTargets.id, // Keep the current ID
          timestamp: DateTime.now(), // Update timestamp
          isUserModified: false,
          modifiedFields: [],
        );

        // Save the restored targets back to cache
        await repository.saveMacroTargets(restoredTargets);

        // Track successful reset
        await _analytics.track('macro_values_reset_successfully');

        // Update state with the restored targets
        final currentState = state.value;
        if (currentState != null) {
          state = AsyncData(
            currentState.copyWith(macroTargets: restoredTargets),
          );
        }
      } else {
        // Fallback: if no original targets found, just clear modification flags
        final fallbackTargets = cachedTargets.copyWith(
          isUserModified: false,
          modifiedFields: [],
        );

        await repository.saveMacroTargets(fallbackTargets);

        final currentState = state.value;
        if (currentState != null) {
          state = AsyncData(
            currentState.copyWith(macroTargets: fallbackTargets),
          );
        }
      }
    } catch (error) {
      // Track error
      await _analytics.track(
        'app_error',
        properties: {
          'error_type': 'Macro Reset Error',
          'error_message': error.toString(),
          'screen_name': 'Adjust Macros',
        },
      );

      rethrow;
    }
  }

  /// Save all macro changes from the adjust macros screen
  Future<void> saveAllMacroChanges({
    // Pre-run values
    required double preRunCarbs,
    required double preRunProtein,
    required double preRunFluids,
    required double preRunSodium,
    // During-run values
    required double duringRunCarbs,
    required double duringRunFluids,
    required double duringRunSodium,
    // Post-run values
    required double postRunCarbs,
    required double postRunProtein,
    required double postRunFluids,
    required double postRunSodium,
  }) async {
    try {
      // Update all values in sequence
      await updateMacroValue(
        section: MacroSection.preRun,
        field: MacroField.preRunCarbs,
        newValue: preRunCarbs,
      );
      await updateMacroValue(
        section: MacroSection.preRun,
        field: MacroField.preRunProtein,
        newValue: preRunProtein,
      );
      await updateMacroValue(
        section: MacroSection.preRun,
        field: MacroField.preRunFluids,
        newValue: preRunFluids,
      );
      await updateMacroValue(
        section: MacroSection.preRun,
        field: MacroField.preRunSodium,
        newValue: preRunSodium,
      );

      // During-run values
      await updateMacroValue(
        section: MacroSection.duringRun,
        field: MacroField.duringRunCarbTotal,
        newValue: duringRunCarbs,
      );
      await updateMacroValue(
        section: MacroSection.duringRun,
        field: MacroField.duringRunFluidTotal,
        newValue: duringRunFluids,
      );
      await updateMacroValue(
        section: MacroSection.duringRun,
        field: MacroField.duringRunSodiumTotal,
        newValue: duringRunSodium,
      );

      // Post-run values
      await updateMacroValue(
        section: MacroSection.postRun,
        field: MacroField.postRunCarbs,
        newValue: postRunCarbs,
      );
      await updateMacroValue(
        section: MacroSection.postRun,
        field: MacroField.postRunProtein,
        newValue: postRunProtein,
      );
      await updateMacroValue(
        section: MacroSection.postRun,
        field: MacroField.postRunFluids,
        newValue: postRunFluids,
      );
      await updateMacroValue(
        section: MacroSection.postRun,
        field: MacroField.postRunSodium,
        newValue: postRunSodium,
      );

      // Track successful save
      await _analytics.track('all_macro_changes_saved_successfully');
    } catch (error) {
      // Track error
      await _analytics.track(
        'app_error',
        properties: {
          'error_type': 'Save All Macros Error',
          'error_message': error.toString(),
          'screen_name': 'Adjust Macros',
        },
      );

      rethrow;
    }
  }

  /// Create nutrition plan with adjusted values
  /// Returns the activityId of the created/updated activity
  Future<String?> createNutritionPlan() async {
    final repository = ref.read(macroRepositoryProvider);
    final macroTargets = await repository.getCachedMacroTargets();

    if (macroTargets == null) return null;

    final currentState = state.value;
    if (currentState == null) return null;

    // Set creating plan state
    state = AsyncData(currentState.copyWith(isCreatingPlan: true));

    final modifiedFieldsCount = _countModifiedFields(macroTargets);

    // Track plan creation start
    await _analytics.timeEvent('nutrition_plan_created_from_adjusted_macros');
    await _analytics.track(
      'nutrition_plan_creation_started_from_adjusted_macros',
      properties: {
        'distance_miles': macroTargets.metrics.distanceMi,
        'duration_hours': macroTargets.metrics.durationH,
        'modified_fields_count': modifiedFieldsCount,
      },
    );

    state = await AsyncValue.guard(() async {
      try {
        // Use the service method that handles fallback automatically
        final nutritionPlanService = ref.read(nutritionPlanServiceProvider);
        final currentStateValue = state.value;
        final userId = await ref.read(userIdProvider.future);

        // Gather V2 parameters: hoursBefore, weightKg, dietary preferences
        final userProfile = await _authService.getCurrentUser();
        final weightKg = userProfile != null
            ? userProfile.weightPounds * 0.453592
            : 70.0;

        // Get hoursBefore from the draft activity's timeBeforeMinutes
        double hoursBefore = 2.0; // default fallback
        if (currentStateValue?.activityId != null) {
          final activitiesService = ref.read(activitiesServiceProvider);
          final draftActivity = await activitiesService.getActivityById(
            userId,
            currentStateValue!.activityId!,
          );
          if (draftActivity?.timeBeforeMinutes != null) {
            hoursBefore = draftActivity!.timeBeforeMinutes! / 60.0;
          }
        }

        // Get dietary preferences and food preferences
        final dietaryPreference = userProfile?.dietaryPreference?.dbValue;
        final allergies = userProfile?.allergies.map((a) => a.dbValue).toList();
        final likedFoods = userId.isNotEmpty
            ? await _authService.getLikedFoods(userId)
            : <String>[];
        final dislikedFoods = userId.isNotEmpty
            ? await _authService.getDislikedFoods(userId)
            : <String>[];

        // Try V2 template-based generation, falls back to V1 internally
        final nutritionPlan = await nutritionPlanService
            .generatePlanFromMacrosV2(
              macroTargets: macroTargets,
              hoursBefore: hoursBefore,
              weightKg: weightKg,
              activityId: currentStateValue?.activityId,
              userId: userId,
              dietaryPreference: dietaryPreference,
              allergies: allergies,
              likedFoods: likedFoods,
              dislikedFoods: dislikedFoods,
              durationMinutes: (macroTargets.metrics.durationH * 60).round(),
              gutTrainingLevel: userProfile?.gutTraining.name,
            );

        // Track successful plan creation (the service handles whether it's LLM or algorithmic)
        await _analytics.track(
          'nutrition_plan_created_from_adjusted_macros',
          properties: {
            'distance_miles': macroTargets.metrics.distanceMi,
            'duration_hours': macroTargets.metrics.durationH,
            'total_calories': macroTargets.metrics.caloriesNetKcal.round(),
            'pre_run_carbs_g': macroTargets.preRun.carbsG,
            'during_run_carbs_g': macroTargets.duringRun.carbTotalG,
            'post_run_carbs_g': macroTargets.postRun.carbsG,
            'modified_fields_count': modifiedFieldsCount,
            'plan_type': 'v2_template', // Template-based with LP fallback
          },
        );

        // activityId should ALWAYS exist now (created during macro generation as draft)
        String? finalActivityId = currentStateValue?.activityId;

        if (finalActivityId == null || finalActivityId.isEmpty) {
          DebugLogger.error('❌ No draft activity found - cannot finalize plan');
          throw Exception(
            'No draft activity found - cannot finalize plan. This should not happen.',
          );
        }

        // Get the existing draft activity and update it
        try {
          final activitiesController = ref.read(
            activitiesControllerProvider.notifier,
          );
          final userId = await ref.read(userIdProvider.future);
          final activitiesService = ref.read(activitiesServiceProvider);
          final existingActivity = await activitiesService.getActivityById(
            userId,
            finalActivityId,
          );

          if (existingActivity == null) {
            DebugLogger.error(
              '❌ Draft activity $finalActivityId not found in database',
            );
            throw Exception('Draft activity not found - cannot finalize plan');
          }

          // Update the DRAFT activity to PLANNED status with nutrition plan
          final updatedActivity = existingActivity.copyWith(
            status:
                domain.ActivityStatus.planned, // Promote from draft to planned
            nutritionPlanData: nutritionPlan.toJson(),
            notes: 'Finalized nutrition plan',
            updatedAt: DateTime.now(),
          );

          await activitiesController.updateActivity(updatedActivity);

          // Fire-and-forget write-back to TrainingPeaks (never blocks plan creation)
          unawaited(
            _pushToTrainingPeaks(userId, updatedActivity, nutritionPlan),
          );

          // 🔗 Link activity to event if eventId exists
          if (currentStateValue?.eventId != null) {
            // Get the events repository directly to avoid provider lifecycle issues
            final eventsRepository = ref.read(eventsRepositoryProvider);
            final event = await eventsRepository.getEventById(
              userId,
              currentStateValue!.eventId!,
            );

            if (event != null) {
              await eventsRepository.updateEvent(
                deviceId:
                    event.userId, // Using userId as deviceId for event updates
                event: event.copyWith(activityId: finalActivityId),
              );
            }
          }
        } catch (e) {
          DebugLogger.error('❌ Failed to update draft activity: $e');
          rethrow;
        }

        // Invalidate eventDetailProvider if eventId exists (to refresh "Create Nutrition Plan" button)
        if (currentStateValue?.eventId != null) {
          ref.invalidate(eventDetailProvider(currentStateValue!.eventId!));
        }

        // Invalidate activities provider to refresh the list with the newly created activity
        ref.invalidate(activitiesControllerProvider);

        // Return the updated state with the activity ID
        return currentState.copyWith(
          isCreatingPlan: false,
          activityId: finalActivityId,
          overrideActivityId: true,
        );
      } catch (error) {
        // Track error
        await _analytics.track(
          'app_error',
          properties: {
            'error_type': 'Plan Creation Error',
            'error_message': error.toString(),
            'screen_name': 'Adjust Macros',
            'distance_miles': macroTargets.metrics.distanceMi,
            'modified_fields_count': modifiedFieldsCount,
          },
        );

        rethrow;
      }
    });

    // Return the activityId from the updated state
    return state.value?.activityId;
  }

  /// Schedule cleanup of draft activity if provider is being disposed
  /// This handles the case where user navigates away before finalizing the plan
  ///
  /// NOTE: Uses [_lastKnownActivityId] instead of [state.value] because this
  /// is called from ref.onDispose(), where accessing state is forbidden by Riverpod.
  void _scheduleCleanupIfNeeded() {
    final activityId = _lastKnownActivityId;

    // Only cleanup if we have a draft activity ID
    if (activityId != null && activityId.isNotEmpty) {
      // Schedule cleanup after a delay to allow navigation to complete
      Future.delayed(const Duration(seconds: 2), () async {
        await _cleanupDraftActivityIfNeeded(activityId);
      });
    }
  }

  /// Clean up draft activity if it's still in draft status
  /// This is safe to call from ref.onDispose() because we're using Future.delayed
  Future<void> _cleanupDraftActivityIfNeeded(String activityId) async {
    try {
      // Safe to use ref.read here - we're in a delayed Future, not dispose() itself
      final userId = await ref.read(userIdProvider.future);
      final activitiesService = ref.read(activitiesServiceProvider);

      final activity = await activitiesService.getActivityById(
        userId,
        activityId,
      );

      if (activity != null && activity.status == domain.ActivityStatus.draft) {
        await ref
            .read(activitiesControllerProvider.notifier)
            .deleteActivity(activityId);
      }
    } catch (e) {
      DebugLogger.error('Failed to cleanup draft activity: $e');
      // Don't rethrow - cleanup failure is acceptable
    }
  }

  /// Apply user profile nutrition target overrides to generated macro targets.
  /// Non-null override fields replace the algorithm-generated values.
  /// During-activity rate overrides are multiplied by duration to compute totals.
  MacroTargets _applyUserOverrides(
    MacroTargets targets,
    NutritionTargetOverrides overrides,
  ) {
    final clamped = NutritionTargetGuardrails.clampAll(overrides);
    final durationH = targets.metrics.durationH;
    final modifiedFields = <String>[...targets.modifiedFields];

    // Pre-activity overrides
    var preRun = targets.preRun;
    if (clamped.pre != null) {
      final pre = clamped.pre!;
      if (pre.carbsG != null) {
        preRun = preRun.copyWith(carbsG: pre.carbsG);
        modifiedFields.add('preRunCarbs');
      }
      if (pre.proteinG != null) {
        preRun = preRun.copyWith(proteinG: pre.proteinG);
        modifiedFields.add('preRunProtein');
      }
      if (pre.fatG != null) {
        preRun = preRun.copyWith(fatCapG: pre.fatG);
        modifiedFields.add('preRunFatCap');
      }
      if (pre.sodiumMg != null) {
        preRun = preRun.copyWith(sodiumMg: pre.sodiumMg);
        modifiedFields.add('preRunSodium');
      }
      if (pre.fluidMl != null) {
        preRun = preRun.copyWith(fluidsMl: pre.fluidMl);
        modifiedFields.add('preRunFluids');
      }
    }

    // During-activity overrides (rates → totals using duration)
    var duringRun = targets.duringRun;
    if (clamped.during != null) {
      final during = clamped.during!;
      if (during.carbRateGPerH != null) {
        duringRun = duringRun.copyWith(
          carbRateGPerH: during.carbRateGPerH,
          carbTotalG: during.carbRateGPerH! * durationH,
        );
        modifiedFields.add('duringRunCarbRate');
      }
      if (during.sodiumRateMgPerH != null) {
        duringRun = duringRun.copyWith(
          sodiumRateMgPerH: during.sodiumRateMgPerH,
          sodiumTotalMg: during.sodiumRateMgPerH! * durationH,
        );
        modifiedFields.add('duringRunSodiumRate');
      }
      if (during.fluidRateMlPerH != null) {
        duringRun = duringRun.copyWith(
          fluidRateMlPerH: during.fluidRateMlPerH,
          fluidTotalMl: during.fluidRateMlPerH! * durationH,
        );
        modifiedFields.add('duringRunFluidRate');
      }
    }

    // Post-activity overrides
    var postRun = targets.postRun;
    if (clamped.post != null) {
      final post = clamped.post!;
      if (post.carbsG != null) {
        postRun = postRun.copyWith(carbsG: post.carbsG);
        modifiedFields.add('postRunCarbs');
      }
      if (post.proteinG != null) {
        postRun = postRun.copyWith(proteinG: post.proteinG);
        modifiedFields.add('postRunProtein');
      }
      if (post.sodiumMg != null) {
        postRun = postRun.copyWith(sodiumMg: post.sodiumMg);
        modifiedFields.add('postRunSodium');
      }
      if (post.fluidMl != null) {
        postRun = postRun.copyWith(fluidsMl: post.fluidMl);
        modifiedFields.add('postRunFluids');
      }
    }

    return targets.copyWith(
      preRun: preRun,
      duringRun: duringRun,
      postRun: postRun,
      isUserModified: modifiedFields.isNotEmpty,
      modifiedFields: modifiedFields.toSet().toList(), // deduplicate
    );
  }

  /// Load user profile overrides and apply them to macro targets if present.
  /// Returns the (potentially modified) macro targets.
  Future<MacroTargets> _maybeApplyOverrides(MacroTargets macroTargets) async {
    final user = await _authService.getCurrentUser();
    if (user?.nutritionTargetOverrides?.hasAnyOverride == true) {
      return _applyUserOverrides(macroTargets, user!.nutritionTargetOverrides!);
    }
    return macroTargets;
  }

  /// Helper method to get current value of a field
  double? _getFieldCurrentValue(MacroTargets? macroTargets, MacroField field) {
    if (macroTargets == null) return null;

    switch (field) {
      // Pre-run fields
      case MacroField.preRunCarbs:
        return macroTargets.preRun.carbsG;
      case MacroField.preRunProtein:
        return macroTargets.preRun.proteinG;
      case MacroField.preRunFatCap:
        return macroTargets.preRun.fatCapG;
      case MacroField.preRunFluids:
        return macroTargets.preRun.fluidsFlOz;
      case MacroField.preRunSodium:
        return macroTargets.preRun.sodiumMg;

      // During-run fields
      case MacroField.duringRunCarbTotal:
        return macroTargets.duringRun.carbTotalG;
      case MacroField.duringRunFluidTotal:
        return macroTargets.duringRun.fluidTotalFlOz;
      case MacroField.duringRunSodiumTotal:
        return macroTargets.duringRun.sodiumTotalMg;

      // Post-run fields
      case MacroField.postRunCarbs:
        return macroTargets.postRun.carbsG;
      case MacroField.postRunProtein:
        return macroTargets.postRun.proteinG;
      case MacroField.postRunFluids:
        return macroTargets.postRun.fluidsFlOz;
      case MacroField.postRunSodium:
        return macroTargets.postRun.sodiumMg;

      // Unused fields for this implementation
      default:
        return null;
    }
  }

  /// Helper method to count modified fields
  int _countModifiedFields(MacroTargets macroTargets) {
    return macroTargets.modifiedFields.length;
  }

  /// Refresh content from backend
  Future<void> refreshContent() async {
    await _contentService.refreshFromBackend();
    ref.invalidateSelf();
  }

  /// Fire-and-forget push of nutrition plan summary to TrainingPeaks.
  /// Catches all errors — write-back must never block plan generation.
  Future<void> _pushToTrainingPeaks(
    String userId,
    domain.Activity activity,
    NutritionPlan plan,
  ) async {
    try {
      final service = await ref.read(tpWritebackServiceProvider.future);
      await service.pushPlanToWorkout(
        userId: userId,
        activity: activity,
        plan: plan,
      );
    } catch (e) {
      DebugLogger.error('TP write-back failed (non-blocking): $e');
    }
  }
}
