import 'dart:async';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../../../activities/domain/activity.dart' as domain;
import '../../../activities/domain/activity_title_formatter.dart';
import '../../../activities/application/activities_service.dart';
import '../../../activities/data/activities_repository.dart';
import '../../../../shared/providers/user_id_provider.dart';
import '../../domain/run_parameters.dart';
import '../../domain/intensity_distribution.dart';
import '../../domain/macro_targets.dart';
import '../../domain/nutrition_target_overrides.dart';
import '../../data/macro_repository.dart';
import '../../application/macro_generation_service.dart';
import '../../application/brick_macro_service.dart';
import '../../application/nutrition_plan_service.dart';
import '../../application/draft_activity_cleanup_service.dart';
import '../../domain/nutrition_plan.dart';
import '../../../formula_kit/domain/pin_decision.dart';
import '../../../activities/domain/brick_metadata.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../../../shared/domain/write_consistency.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/analytics/analytics_tracker.dart';
import '../../../../shared/services/analytics/analytics_events.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../auth/application/auth_service.dart';
import '../../../events/presentation/providers/events_controller.dart';
import '../../../events/application/events_service.dart';
import '../../../events/data/events_repository.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';
import '../../../integrations/presentation/providers/tp_writeback_providers.dart';
import '../../../coach_mode/presentation/providers/coach_activity_detail_controller.dart';

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
  final String?
  forUserId; // Target athlete user ID when coach is creating for athlete
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
    this.forUserId,
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
    String? forUserId,
    bool overrideActivityId = false,
    bool overrideEventId = false,
    bool overrideForUserId = false,
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
      forUserId: overrideForUserId ? forUserId : forUserId ?? this.forUserId,
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

  /// Tracks the last-resolved userId so onDispose can pass it to cleanup
  /// without touching `ref` after the provider is disposed.
  String? _lastKnownUserId;

  String _resolveActivityOwnerId({
    required String currentUserId,
    String? forUserId,
  }) {
    if (forUserId != null && forUserId.isNotEmpty) {
      return forUserId;
    }
    return currentUserId;
  }

  String? _normalizeTitle(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String _resolveNewActivityTitle({
    required String fallbackTitle,
    String? requestedTitle,
    String? eventName,
  }) {
    return _normalizeTitle(requestedTitle) ??
        _normalizeTitle(eventName) ??
        fallbackTitle;
  }

  String _resolveExistingActivityTitle({
    required domain.Activity existingActivity,
    required String fallbackTitle,
    String? requestedTitle,
  }) {
    return _normalizeTitle(requestedTitle) ??
        _normalizeTitle(existingActivity.title) ??
        fallbackTitle;
  }

  @override
  FutureOr<MacroTargetsState> build() async {
    // Screen views not tracked per README spec

    // Track activityId changes so onDispose can access it safely
    // (accessing state inside onDispose is forbidden by Riverpod)
    listenSelf((previous, next) {
      _lastKnownActivityId = next.value?.activityId;
    });

    // ✨ DRAFT ACTIVITY CLEANUP (Andrea Bizzotto FOA Pattern)
    // Register cleanup when provider is disposed to handle abandoned drafts.
    // Capture the service NOW (while ref is still alive) so the closure
    // never touches ref after disposal.
    final cleanupService = ref.read(draftActivityCleanupServiceProvider);
    ref.onDispose(() {
      _scheduleCleanupIfNeeded(cleanupService);
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
        forUserId: null,
        overrideActivityId: true,
        overrideEventId: true,
        overrideForUserId: true,
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
    String? activityTitle,
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
        activityTitle: activityTitle,
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
        final estimatedDurationMinutes = (distance * paceMinutes).round();

        String finalActivityId = activityId ?? '';
        final activitiesService = ref.read(activitiesServiceProvider);
        final activityOwnerId = _resolveActivityOwnerId(
          currentUserId: deviceId,
          forUserId: forUserId,
        );

        // Look up event name when eventId is provided
        String? eventName;
        if (eventId != null) {
          try {
            final eventsRepo = ref.read(eventsRepositoryProvider);
            final event = await eventsRepo.getEventById(
              activityOwnerId,
              eventId,
            );
            eventName = event?.eventName;
          } catch (e) {
            DebugLogger.warning('Failed to look up event name: $e');
          }
        }

        final fallbackTitle = ActivityTitleFormatter.formatRunningTitle(
          distance,
        );
        final resolvedTitle = _resolveNewActivityTitle(
          fallbackTitle: fallbackTitle,
          requestedTitle: activityTitle,
          eventName: eventName,
        );

        if (finalActivityId.isEmpty) {
          final createdActivity = await activitiesService.createActivity(
            deviceId: deviceId,
            userId: deviceId,
            forUserId: forUserId,
            activityType: ActivityType.running,
            title: resolvedTitle,
            scheduledDateTime: scheduledDateTime,
            distanceMiles: distance,
            durationMinutes: estimatedDurationMinutes,
            paceTargetMinutesPerMile: paceMinutes,
            intensityLevel: domain.IntensityLevel.moderate,
            timeBeforeMinutes: timeBeforeRunMinutes,
            isFasted: isFasted,
            notes: 'Draft activity - nutrition plan being generated',
            status: domain.ActivityStatus.draft,
          );
          finalActivityId = createdActivity.id;
        } else {
          final existingActivity = await activitiesService.getActivityById(
            activityOwnerId,
            finalActivityId,
          );
          if (existingActivity != null) {
            final existingTitle = _resolveExistingActivityTitle(
              existingActivity: existingActivity,
              fallbackTitle: resolvedTitle,
              requestedTitle: activityTitle,
            );
            await activitiesService.updateActivity(
              deviceId: deviceId,
              currentUserId: deviceId,
              activity: existingActivity.copyWith(
                title: existingTitle,
                activityType: ActivityType.running,
                scheduledDateTime: scheduledDateTime,
                distanceMiles: distance,
                durationMinutes: estimatedDurationMinutes,
                paceTargetMinutesPerMile: paceMinutes,
                timeBeforeMinutes: timeBeforeRunMinutes,
                isFasted: isFasted,
                notes: 'Draft activity - nutrition plan being generated',
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

        // Load sport-specific overrides with 90-min gate
        final overrides = await _loadOverridesForEdgeFunction(
          ActivityType.running,
          estimatedDurationMinutes.toDouble(),
        );

        // Call the service to generate macros (overrides sent to edge function)
        var macroTargets = await macroService.generateRunningMacros(
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
          overrides: overrides,
        );

        // Mark as user-modified if overrides were applied
        if (overrides != null && overrides.hasAnyOverride) {
          macroTargets = macroTargets.copyWith(isUserModified: true);
        }
        final repository = ref.read(macroRepositoryProvider);
        await repository.saveMacroTargets(macroTargets);
        if (finalActivityId.isNotEmpty) {
          await repository.saveMacroTargetsForActivity(
            finalActivityId,
            macroTargets,
          );
        }

        // Update state to not generating and include macro targets with finalActivityId
        return currentState.copyWith(
          isGeneratingMacros: false,
          errorMessage: null,
          macroTargets: macroTargets,
          activityId:
              finalActivityId, // Always has a value now (draft created if needed)
          eventId: eventId, // Store event ID for provider invalidation
          forUserId: forUserId, // Store coach target user ID
          overrideActivityId: true,
          overrideEventId: true,
          overrideForUserId: true,
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
    String? activityTitle,
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
          gutTrainingLevel: user?.gutTraining.name ?? 'moderate',
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
        final activitiesService = ref.read(activitiesServiceProvider);
        final activityOwnerId = _resolveActivityOwnerId(
          currentUserId: deviceId,
          forUserId: forUserId,
        );

        // Look up event name when eventId is provided
        String? eventName;
        if (eventId != null) {
          try {
            final eventsRepo = ref.read(eventsRepositoryProvider);
            final event = await eventsRepo.getEventById(
              activityOwnerId,
              eventId,
            );
            eventName = event?.eventName;
          } catch (e) {
            DebugLogger.warning('Failed to look up event name: $e');
          }
        }

        final fallbackTitle = ActivityTitleFormatter.formatCyclingTitle(
          distanceMiles,
        );
        final resolvedTitle = _resolveNewActivityTitle(
          fallbackTitle: fallbackTitle,
          requestedTitle: activityTitle,
          eventName: eventName,
        );

        if (finalActivityId.isEmpty) {
          final createdActivity = await activitiesService.createActivity(
            deviceId: deviceId,
            userId: deviceId,
            forUserId: forUserId,
            activityType: ActivityType.cycling,
            title: resolvedTitle,
            scheduledDateTime: scheduledDateTime,
            distanceMiles: distanceMiles,
            cyclingSpeedMph: speedMph,
            cyclingTerrain: terrain,
            cyclingIndoorOutdoor: indoorOutdoor,
            cyclingElevationGainFt: elevationGainFt,
            cyclingSessionGoal: sessionGoal,
            intensityTarget: intensityTarget,
            intensityLevel: domain.IntensityLevel.moderate,
            timeBeforeMinutes: timeBeforeMinutes,
            isFasted: isFasted,
            notes: 'Draft cycling activity - nutrition plan being generated',
            status: domain.ActivityStatus.draft,
          );
          finalActivityId = createdActivity.id;
        } else {
          final existingActivity = await activitiesService.getActivityById(
            activityOwnerId,
            finalActivityId,
          );
          if (existingActivity != null) {
            final existingTitle = _resolveExistingActivityTitle(
              existingActivity: existingActivity,
              fallbackTitle: resolvedTitle,
              requestedTitle: activityTitle,
            );
            await activitiesService.updateActivity(
              deviceId: deviceId,
              currentUserId: deviceId,
              activity: existingActivity.copyWith(
                title: existingTitle,
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
                isFasted: isFasted,
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

        // Load sport-specific overrides with 90-min gate
        final estimatedCyclingDurationMin = speedMph > 0
            ? (distanceMiles / speedMph) * 60.0
            : 0.0;
        final overrides = await _loadOverridesForEdgeFunction(
          ActivityType.cycling,
          estimatedCyclingDurationMin,
        );

        // Call the service (overrides sent to edge function)
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
          overrides: overrides,
        );

        // Mark as user-modified if overrides were applied
        if (overrides != null && overrides.hasAnyOverride) {
          macroTargets = macroTargets.copyWith(isUserModified: true);
        }

        final repository = ref.read(macroRepositoryProvider);
        await repository.saveMacroTargets(macroTargets);
        if (finalActivityId.isNotEmpty) {
          await repository.saveMacroTargetsForActivity(
            finalActivityId,
            macroTargets,
          );
        }

        return currentState.copyWith(
          isGeneratingMacros: false,
          macroTargets: macroTargets,
          activityId:
              finalActivityId, // Always has a value now (draft created if needed)
          eventId: eventId,
          forUserId: forUserId,
          overrideActivityId: true,
          overrideEventId: true,
          overrideForUserId: true,
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
    String? activityTitle,
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
      activityTitle: activityTitle,
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
    String? activityTitle,
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
          gutTrainingLevel: user?.gutTraining.name ?? 'moderate',
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
        final activitiesService = ref.read(activitiesServiceProvider);
        final activityOwnerId = _resolveActivityOwnerId(
          currentUserId: deviceId,
          forUserId: forUserId,
        );

        // Look up event name when eventId is provided
        String? eventName;
        if (eventId != null) {
          try {
            final eventsRepo = ref.read(eventsRepositoryProvider);
            final event = await eventsRepo.getEventById(
              activityOwnerId,
              eventId,
            );
            eventName = event?.eventName;
          } catch (e) {
            DebugLogger.warning('Failed to look up event name: $e');
          }
        }

        final fallbackTitle = ActivityTitleFormatter.formatSwimmingTitle(
          distanceMeters,
        );
        final resolvedTitle = _resolveNewActivityTitle(
          fallbackTitle: fallbackTitle,
          requestedTitle: activityTitle,
          eventName: eventName,
        );

        if (finalActivityId.isEmpty) {
          final createdActivity = await activitiesService.createActivity(
            deviceId: deviceId,
            userId: deviceId,
            forUserId: forUserId,
            activityType: ActivityType.swimming,
            title: resolvedTitle,
            scheduledDateTime: scheduledDateTime,
            distanceMiles: distanceMiles,
            swimmingPacePer100mSeconds: paceSecondsper100m,
            swimmingPoolOrOpenWater: poolOrOpenWater,
            swimmingWaterTempC: waterTempC,
            intensityTarget: intensityTarget,
            intensityLevel: domain.IntensityLevel.moderate,
            timeBeforeMinutes: timeBeforeMinutes,
            notes: 'Draft swimming activity - nutrition plan being generated',
            status: domain.ActivityStatus.draft,
          );
          finalActivityId = createdActivity.id;
        } else {
          final existingActivity = await activitiesService.getActivityById(
            activityOwnerId,
            finalActivityId,
          );
          if (existingActivity != null) {
            final existingTitle = _resolveExistingActivityTitle(
              existingActivity: existingActivity,
              fallbackTitle: resolvedTitle,
              requestedTitle: activityTitle,
            );
            await activitiesService.updateActivity(
              deviceId: deviceId,
              currentUserId: deviceId,
              activity: existingActivity.copyWith(
                title: existingTitle,
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

        // Load sport-specific overrides with 90-min gate
        final overrides = await _loadOverridesForEdgeFunction(
          ActivityType.swimming,
          durationMinutes,
        );

        // Call the service (overrides sent to edge function)
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
          overrides: overrides,
        );

        // Mark as user-modified if overrides were applied
        if (overrides != null && overrides.hasAnyOverride) {
          macroTargets = macroTargets.copyWith(isUserModified: true);
        }

        final repository = ref.read(macroRepositoryProvider);
        await repository.saveMacroTargets(macroTargets);
        if (finalActivityId.isNotEmpty) {
          await repository.saveMacroTargetsForActivity(
            finalActivityId,
            macroTargets,
          );
        }

        return currentState.copyWith(
          isGeneratingMacros: false,
          macroTargets: macroTargets,
          activityId:
              finalActivityId, // Always has a value now (draft created if needed)
          eventId: eventId,
          forUserId: forUserId,
          overrideActivityId: true,
          overrideEventId: true,
          overrideForUserId: true,
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
    required int preActivityMinutes,
    String? activityTitle,
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
          gutTrainingLevel: user?.gutTraining.name ?? 'moderate',
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
        final activitiesService = ref.read(activitiesServiceProvider);
        final activityOwnerId = _resolveActivityOwnerId(
          currentUserId: deviceId,
          forUserId: forUserId,
        );

        // Look up event name when eventId is provided
        String? eventName;
        if (eventId != null) {
          try {
            final eventsRepo = ref.read(eventsRepositoryProvider);
            final event = await eventsRepo.getEventById(
              activityOwnerId,
              eventId,
            );
            eventName = event?.eventName;
          } catch (e) {
            DebugLogger.warning('Failed to look up event name: $e');
          }
        }

        if (finalActivityId.isEmpty) {
          // Build brick title (e.g., "SWIM/RUN BRICK") or use event name
          final sportNames = segmentOrder.map((s) => s.toUpperCase()).join('/');
          final fallbackTitle = '$sportNames BRICK';
          final brickTitle = _resolveNewActivityTitle(
            fallbackTitle: fallbackTitle,
            requestedTitle: activityTitle,
            eventName: eventName,
          );

          DebugLogger.info('🧱 DEBUG: Creating draft brick activity');
          DebugLogger.info(
            '🧱 DEBUG: segmentOrder=$segmentOrder, totalDurationMinutes=$totalDurationMinutes',
          );

          final createdActivity = await activitiesService.createActivity(
            deviceId: deviceId,
            userId: deviceId,
            forUserId: forUserId,
            activityType: ActivityType.brick,
            title: brickTitle,
            scheduledDateTime: scheduledDateTime,
            intensityLevel: domain.IntensityLevel.moderate,
            durationMinutes: totalDurationMinutes,
            brickMetadata: brickMetadata,
            timeBeforeMinutes: preActivityMinutes,
            isFasted: isFasted,
            notes: 'Draft brick activity - nutrition plan being generated',
            status: domain.ActivityStatus.draft,
          );
          finalActivityId = createdActivity.id;
        } else {
          final existingActivity = await activitiesService.getActivityById(
            activityOwnerId,
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
            final fallbackTitle = '$sportNames BRICK';
            final brickTitle = _resolveExistingActivityTitle(
              existingActivity: existingActivity,
              fallbackTitle: fallbackTitle,
              requestedTitle: activityTitle ?? eventName,
            );
            await activitiesService.updateActivity(
              deviceId: deviceId,
              currentUserId: deviceId,
              activity: existingActivity.copyWith(
                title: brickTitle,
                activityType: ActivityType.brick,
                scheduledDateTime: scheduledDateTime,
                brickMetadata: brickMetadata,
                durationMinutes: totalDurationMinutes,
                timeBeforeMinutes: preActivityMinutes,
                isFasted: isFasted,
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

        final brickSports = _extractBrickSports(segments);

        // Load sport-specific overrides with 90-min gate.
        // For bricks, this checks run/bike/swim overrides (not a brick-specific one).
        final overrides = await _loadOverridesForEdgeFunction(
          ActivityType.brick,
          totalDurationMinutes.toDouble(),
          brickSports: brickSports,
        );

        // Call the service (passes brick-aware sport overrides so segment
        // targets can be overridden by swim/bike/run values).
        var macroTargets = await brickMacroService.generateBrickMacros(
          activityId: finalActivityId,
          deviceId: deviceId,
          segments: segments,
          segmentOrder: segmentOrder,
          isFasted: isFasted,
          preActivityMinutes: preActivityMinutes,
          overrides: overrides,
        );

        // Mark as user-modified if overrides were applied
        if (overrides != null && overrides.hasAnyOverride) {
          macroTargets = macroTargets.copyWith(isUserModified: true);
        }

        final repository = ref.read(macroRepositoryProvider);
        await repository.saveMacroTargets(macroTargets);
        if (finalActivityId.isNotEmpty) {
          await repository.saveMacroTargetsForActivity(
            finalActivityId,
            macroTargets,
          );
        }

        return currentState.copyWith(
          isGeneratingMacros: false,
          macroTargets: macroTargets,
          activityId:
              finalActivityId, // Always has a value now (draft created if needed)
          eventId: eventId,
          forUserId: forUserId,
          overrideActivityId: true,
          overrideEventId: true,
          overrideForUserId: true,
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
    final currentStateSnapshot = state.value;
    final activityId = currentStateSnapshot?.activityId;
    final cachedTargets = activityId != null && activityId.isNotEmpty
        ? await repository.getCachedMacroTargetsForActivity(
            activityId,
            expectedActivityType:
                currentStateSnapshot?.macroTargets?.activityType,
          )
        : await repository.getCachedMacroTargets();

    if (cachedTargets == null) return;

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
      if (activityId != null && activityId.isNotEmpty) {
        await repository.saveMacroTargetsForActivity(
          activityId,
          updatedTargets,
        );
      }

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
    final activityId = state.value?.activityId;
    final cachedTargets = activityId != null && activityId.isNotEmpty
        ? await repository.getCachedMacroTargetsForActivity(
            activityId,
            expectedActivityType: state.value?.macroTargets?.activityType,
          )
        : await repository.getCachedMacroTargets();

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
      final originalTargets = activityId != null && activityId.isNotEmpty
          ? await repository.getOriginalMacroTargetsForActivity(activityId)
          : await repository.getOriginalMacroTargets();

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
        if (activityId != null && activityId.isNotEmpty) {
          await repository.saveMacroTargetsForActivity(
            activityId,
            restoredTargets,
          );
        }

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
        if (activityId != null && activityId.isNotEmpty) {
          await repository.saveMacroTargetsForActivity(
            activityId,
            fallbackTargets,
          );
        }

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
    final appLogger = ref.read(appExternalDepsProvider).logger;
    final repository = ref.read(macroRepositoryProvider);
    final currentState = state.value;
    MacroTargets? macroTargets;
    final activityId = currentState?.activityId;
    if (activityId != null && activityId.isNotEmpty) {
      macroTargets = await repository.getCachedMacroTargetsForActivity(
        activityId,
        expectedActivityType: currentState?.macroTargets?.activityType,
      );
    }
    macroTargets ??= await repository.getCachedMacroTargets();
    macroTargets ??= currentState?.macroTargets;

    if (macroTargets == null) {
      DebugLogger.error(
        '❌ [CREATE-PLAN] No cached macro targets found in SharedPreferences!',
      );
      return null;
    }
    final resolvedMacroTargets = macroTargets;

    if (currentState == null) return null;
    appLogger.warning(
      'Create nutrition plan started',
      context: 'MACRO_TARGETS_CONTROLLER',
      data: {
        'activityId': currentState.activityId,
        'eventId': currentState.eventId,
        'forUserId': currentState.forUserId,
      },
    );

    // Log what we're reading from cache vs state for debugging same-plan issues
    final stateMacros = currentState.macroTargets;
    DebugLogger.info(
      '📋 [CREATE-PLAN] Cache vs State comparison:\n'
      '  Cache: pre_carbs=${resolvedMacroTargets.preRun.carbsG}, during_carbs=${resolvedMacroTargets.duringRun.carbTotalG}, post_carbs=${resolvedMacroTargets.postRun.carbsG}, distance=${resolvedMacroTargets.metrics.distanceMi}, duration=${resolvedMacroTargets.metrics.durationH}h\n'
      '  State: pre_carbs=${stateMacros?.preRun.carbsG}, during_carbs=${stateMacros?.duringRun.carbTotalG}, post_carbs=${stateMacros?.postRun.carbsG}, distance=${stateMacros?.metrics.distanceMi}, duration=${stateMacros?.metrics.durationH}h\n'
      '  ActivityId: state=${currentState.activityId}',
    );

    // Set creating plan state
    state = AsyncData(currentState.copyWith(isCreatingPlan: true));

    final modifiedFieldsCount = _countModifiedFields(resolvedMacroTargets);

    // Track plan creation start
    await _analytics.timeEvent('nutrition_plan_created_from_adjusted_macros');
    await _analytics.track(
      'nutrition_plan_creation_started_from_adjusted_macros',
      properties: {
        'distance_miles': resolvedMacroTargets.metrics.distanceMi,
        'duration_hours': resolvedMacroTargets.metrics.durationH,
        'modified_fields_count': modifiedFieldsCount,
      },
    );

    final createPlanResult = await AsyncValue.guard(() async {
      try {
        // Use the service method that handles fallback automatically
        final nutritionPlanService = ref.read(nutritionPlanServiceProvider);
        final currentStateValue = state.value;
        final userId = await ref.read(userIdProvider.future);
        _lastKnownUserId = userId; // capture for onDispose cleanup
        final activityOwnerUserId = _resolveActivityOwnerId(
          currentUserId: userId,
          forUserId: currentStateValue?.forUserId,
        );

        // Gather V2 parameters: hoursBefore, weightKg, dietary preferences
        final userProfile = await _authService.getCurrentUser();
        final weightKg = userProfile != null
            ? userProfile.weightPounds * 0.453592
            : 70.0;

        // Get hoursBefore from the draft activity's timeBeforeMinutes
        double hoursBefore = 2.0; // default fallback
        domain.Activity? draftActivity;
        if (currentStateValue?.activityId != null) {
          final activitiesService = ref.read(activitiesServiceProvider);
          draftActivity = await activitiesService.getActivityById(
            activityOwnerUserId,
            currentStateValue!.activityId!,
          );
          if (draftActivity?.timeBeforeMinutes != null) {
            hoursBefore = draftActivity!.timeBeforeMinutes! / 60.0;
          }
        }
        final draftDurationMinutes = draftActivity?.durationMinutes;
        final macroDurationMinutes =
            (resolvedMacroTargets.metrics.durationH * 60).round();
        final resolvedDurationMinutes =
            (draftDurationMinutes != null && draftDurationMinutes > 0)
            ? draftDurationMinutes
            : macroDurationMinutes;

        // Log resolved parameters for debugging same-plan issues
        DebugLogger.info(
          '📋 [CREATE-PLAN] Resolved params: '
          'activityId=${currentStateValue?.activityId}, '
          'hoursBefore=$hoursBefore (draft.timeBeforeMinutes=${draftActivity?.timeBeforeMinutes}), '
          'weightKg=$weightKg, '
          'draftDuration=$draftDurationMinutes, macroDuration=$macroDurationMinutes, '
          'resolvedDuration=$resolvedDurationMinutes, '
          'draftDistance=${draftActivity?.distanceMiles}',
        );

        // Get dietary preferences and food preferences
        final dietaryPreference = userProfile?.dietaryPreference?.dbValue;
        final allergies = userProfile?.allergies.map((a) => a.dbValue).toList();
        final likedFoods = activityOwnerUserId.isNotEmpty
            ? await _authService.getLikedFoods(activityOwnerUserId)
            : <String>[];
        final dislikedFoods = activityOwnerUserId.isNotEmpty
            ? await _authService.getDislikedFoods(activityOwnerUserId)
            : <String>[];
        final willingToTryFoods = activityOwnerUserId.isNotEmpty
            ? await _authService.getWillingToTryFoods(activityOwnerUserId)
            : <String>[];

        // Try V2 template-based generation, falls back to V1 internally
        final nutritionPlan = await nutritionPlanService
            .generatePlanFromMacrosV2(
              macroTargets: resolvedMacroTargets,
              hoursBefore: hoursBefore,
              weightKg: weightKg,
              activityId: currentStateValue?.activityId,
              userId: activityOwnerUserId,
              dietaryPreference: dietaryPreference,
              allergies: allergies,
              likedFoods: likedFoods,
              dislikedFoods: dislikedFoods,
              willingToTryFoods: willingToTryFoods,
              durationMinutes: resolvedDurationMinutes,
              gutTrainingLevel: userProfile?.gutTraining.name,
            );

        // Track successful plan creation (the service handles whether it's LLM or algorithmic)
        await _analytics.track(
          'nutrition_plan_created_from_adjusted_macros',
          properties: {
            'distance_miles': resolvedMacroTargets.metrics.distanceMi,
            'duration_hours': resolvedMacroTargets.metrics.durationH,
            'total_calories': resolvedMacroTargets.metrics.caloriesNetKcal
                .round(),
            'pre_run_carbs_g': resolvedMacroTargets.preRun.carbsG,
            'during_run_carbs_g': resolvedMacroTargets.duringRun.carbTotalG,
            'post_run_carbs_g': resolvedMacroTargets.postRun.carbsG,
            'modified_fields_count': modifiedFieldsCount,
            'plan_type': 'v2_template', // Template-based with LP fallback
          },
        );

        // Formula Kit PR 2 substep 7: fire one pin-outcome event per phase /
        // sub-phase that carried a pin_decision. No-op when pins were not
        // supplied to the algorithm (pin_decision absent on all sections).
        if (currentStateValue?.activityId != null &&
            currentStateValue!.activityId!.isNotEmpty) {
          await _trackPinDecisions(
            plan: nutritionPlan,
            activityId: currentStateValue.activityId!,
            deviceId: userProfile?.id ?? 'unknown',
          );
        }

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
          final userId = await ref.read(userIdProvider.future);
          _lastKnownUserId = userId; // capture for onDispose cleanup
          final activitiesService = ref.read(activitiesServiceProvider);
          final existingActivity = await activitiesService.getActivityById(
            activityOwnerUserId,
            finalActivityId,
          );

          if (existingActivity == null) {
            DebugLogger.error(
              '❌ Draft activity $finalActivityId not found in database',
            );
            throw Exception('Draft activity not found - cannot finalize plan');
          }

          // Update the DRAFT activity to PLANNED status with nutrition plan
          final nutritionPlanData = <String, dynamic>{
            ...nutritionPlan.toJson(),
            'detailedMacroTargets': resolvedMacroTargets.toJson(),
          };
          final updatedActivity = existingActivity.copyWith(
            status:
                domain.ActivityStatus.planned, // Promote from draft to planned
            nutritionPlanData: nutritionPlanData,
            durationMinutes: resolvedDurationMinutes,
            paceTargetMinutesPerMile:
                resolvedMacroTargets.metrics.paceMinPerMile ??
                existingActivity.paceTargetMinutesPerMile,
            notes: existingActivity.notes,
            updatedAt: DateTime.now(),
            needsNutritionRefresh:
                false, // Clear stale flag - plan is now current
          );

          await activitiesService.updateActivity(
            deviceId: userId,
            currentUserId: userId,
            activity: updatedActivity,
            consistency:
                currentStateValue?.forUserId != null &&
                    currentStateValue!.forUserId!.isNotEmpty
                ? WriteConsistency.remoteAckRequired
                : WriteConsistency.offlineFirst,
          );

          final isCoachFlow =
              currentStateValue?.forUserId != null &&
              currentStateValue!.forUserId!.isNotEmpty;
          if (isCoachFlow) {
            await _verifyCoachRemotePlanVisibility(
              activityId: finalActivityId,
              expectedOwnerUserId: activityOwnerUserId,
              appLogger: appLogger,
            );
          }

          // Fire-and-forget write-back to TrainingPeaks (never blocks plan creation)
          unawaited(
            _pushToTrainingPeaks(userId, updatedActivity, nutritionPlan),
          );

          // 🔗 Link activity to event if eventId exists
          if (currentStateValue?.eventId != null) {
            // Get the events repository directly to avoid provider lifecycle issues
            final eventsRepository = ref.read(eventsRepositoryProvider);
            final event = await eventsRepository.getEventById(
              activityOwnerUserId,
              currentStateValue!.eventId!,
            );

            if (event != null) {
              await ref
                  .read(eventsServiceProvider)
                  .updateEvent(
                    deviceId: userId,
                    currentUserId: userId,
                    event: event.copyWith(activityId: finalActivityId),
                    consistency:
                        currentStateValue.forUserId != null &&
                            currentStateValue.forUserId!.isNotEmpty
                        ? WriteConsistency.remoteAckRequired
                        : WriteConsistency.offlineFirst,
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

        // Invalidate coach activity detail provider so it re-fetches from Supabase
        // with the new nutrition plan data instead of returning cached stale state.
        if (currentStateValue?.forUserId != null &&
            currentStateValue!.forUserId!.isNotEmpty) {
          ref.invalidate(
            coachActivityDetailControllerProvider(finalActivityId),
          );
        }

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
            'distance_miles': resolvedMacroTargets.metrics.distanceMi,
            'modified_fields_count': modifiedFieldsCount,
          },
        );

        rethrow;
      }
    });

    state = createPlanResult;
    if (createPlanResult.hasError) {
      appLogger.error(
        'Create nutrition plan failed',
        context: 'MACRO_TARGETS_CONTROLLER',
        data: {
          'activityId': currentState.activityId,
          'eventId': currentState.eventId,
          'forUserId': currentState.forUserId,
        },
        error: createPlanResult.error,
        stackTrace: createPlanResult.stackTrace,
      );
      DebugLogger.error(
        '❌ [CREATE-PLAN] createNutritionPlan failed - blocking navigation. error=${createPlanResult.error}',
      );
      return null;
    }

    // Return the activityId from the successful updated state
    return createPlanResult.value?.activityId;
  }

  /// Walks the generated plan and fires one `plan_used_pin` /
  /// `plan_pin_fallthrough` analytics event per phase / sub-phase that
  /// carried a [PinDecision]. Today only During sits at the section level;
  /// Before pins live on each [BeforeSubPhase]. Formula Kit PR 2 substep 7.
  Future<void> _trackPinDecisions({
    required NutritionPlan plan,
    required String activityId,
    required String deviceId,
  }) async {
    for (final section in plan.sections) {
      final phase = _phaseForSectionId(section.id);
      final sectionDecision = section.pinDecision;
      if (sectionDecision != null) {
        await _emitPinEvent(
          decision: sectionDecision,
          activityId: activityId,
          deviceId: deviceId,
          phase: phase,
          subPhase: null,
        );
      }

      final subPhases = section.subPhases;
      if (subPhases == null) continue;
      for (final sub in subPhases) {
        final subDecision = sub.pinDecision;
        if (subDecision == null) continue;
        await _emitPinEvent(
          decision: subDecision,
          activityId: activityId,
          deviceId: deviceId,
          phase: phase,
          subPhase: sub.subPhaseType,
        );
      }
    }
  }

  /// Normalizes plan section IDs (`before_run` / `during_run` / `after_run`)
  /// to the analytics phase vocabulary (`before` / `during` / `after`) so
  /// substep 7 events join cleanly with substep 8 events in Mixpanel.
  /// Unknown IDs are passed through unchanged so future sections (e.g. brick
  /// sub-sections) don't silently lose their phase tag.
  @visibleForTesting
  static String phaseForSectionId(String sectionId) =>
      _phaseForSectionId(sectionId);

  static String _phaseForSectionId(String sectionId) {
    switch (sectionId) {
      case 'before_run':
        return 'before';
      case 'during_run':
        return 'during';
      case 'after_run':
        return 'after';
      default:
        return sectionId;
    }
  }

  Future<void> _emitPinEvent({
    required PinDecision decision,
    required String activityId,
    required String deviceId,
    required String phase,
    required String? subPhase,
  }) async {
    // Ephemeral decisions come from the server-side default-formula safety
    // net, not a real user pin — they must NOT emit `plan_used_pin` (which
    // implies a pin fired) or `plan_pin_fallthrough`. Skip silently so pin
    // analytics stay byte-identical to pre-safety-net behavior. Formula-first
    // flip, 2026-07-03.
    if (decision.ephemeral) return;
    if (decision.usedPin) {
      final id = decision.pinnedTemplateId;
      final name = decision.pinnedTemplateName;
      // Defensive: edge fn guarantees id+name when used_pin=true, but a
      // legacy persisted plan from before substep 9 may lack the name.
      if (id == null || name == null) return;
      await _analytics.trackPlanUsedPin(
        deviceId: deviceId,
        activityId: activityId,
        templateId: id,
        templateName: name,
        phase: phase,
        subPhase: subPhase,
        pinSetSize: decision.pinSetSize,
      );
      return;
    }
    final reason = decision.fallthroughReason?.wireValue;
    // No fall-through reason → pins weren't supplied for this phase. Skip
    // silently rather than emitting a noise event.
    if (reason == null) return;
    await _analytics.trackPlanPinFallthrough(
      deviceId: deviceId,
      activityId: activityId,
      phase: phase,
      subPhase: subPhase,
      reason: reason,
      pinSetSize: decision.pinSetSize,
    );
  }

  Future<void> _verifyCoachRemotePlanVisibility({
    required String activityId,
    required String expectedOwnerUserId,
    required AppLogger appLogger,
  }) async {
    final repository = ref.read(activitiesRepositoryProvider);
    final delays = <Duration>[
      Duration.zero,
      const Duration(milliseconds: 250),
      const Duration(milliseconds: 500),
      const Duration(seconds: 1),
      const Duration(seconds: 2),
    ];

    Object? lastError;

    for (var attempt = 0; attempt < delays.length; attempt++) {
      final delay = delays[attempt];
      if (delay > Duration.zero) {
        await Future.delayed(delay);
      }

      try {
        final remoteActivity = await repository.getRemoteActivityById(
          activityId,
        );
        final hasPlan = remoteActivity?.nutritionPlanData != null;
        final ownerMatches = remoteActivity?.userId == expectedOwnerUserId;

        if (remoteActivity != null && ownerMatches && hasPlan) {
          appLogger.warning(
            'Coach remote activity plan visibility confirmed',
            context: 'MACRO_TARGETS_CONTROLLER',
            data: {
              'activityId': activityId,
              'ownerUserId': remoteActivity.userId,
              'attempt': attempt + 1,
              'hasNutritionPlanData': true,
            },
          );
          return;
        }

        appLogger.warning(
          'Coach remote activity plan visibility pending',
          context: 'MACRO_TARGETS_CONTROLLER',
          data: {
            'activityId': activityId,
            'attempt': attempt + 1,
            'hasRemoteActivity': remoteActivity != null,
            'ownerMatches': ownerMatches,
            'hasNutritionPlanData': hasPlan,
            'expectedOwnerUserId': expectedOwnerUserId,
            'actualOwnerUserId': remoteActivity?.userId,
          },
        );
      } catch (e) {
        lastError = e;
        appLogger.warning(
          'Coach remote activity visibility check failed',
          context: 'MACRO_TARGETS_CONTROLLER',
          error: e,
          data: {'activityId': activityId, 'attempt': attempt + 1},
        );
      }
    }

    throw Exception(
      'Nutrition plan was generated but is not visible in coach mode yet. '
      'Please retry in a few seconds.'
      '${lastError != null ? ' Last error: $lastError' : ''}',
    );
  }

  /// Schedule cleanup of draft activity if provider is being disposed.
  /// This handles the case where user navigates away before finalizing the plan.
  ///
  /// NOTE: Uses [_lastKnownActivityId] and [_lastKnownUserId] instead of
  /// reading from state or ref, because this is called from ref.onDispose()
  /// where both state access and ref.read() are forbidden by Riverpod.
  /// The [cleanupService] is captured BEFORE disposal and passed in so the
  /// closure contains zero ref access.
  void _scheduleCleanupIfNeeded(DraftActivityCleanupService cleanupService) {
    final activityId = _lastKnownActivityId;
    final userId = _lastKnownUserId;

    // If no userId was ever resolved (user never got to macro generation),
    // there is no draft to clean up.
    if (activityId == null || activityId.isEmpty || userId == null) return;

    // DraftActivityCleanupService.scheduleCleanup() owns the Future.delayed
    // internally — no ref access here, safe after disposal.
    cleanupService.scheduleCleanup(activityId: activityId, userId: userId);
  }

  /// Load user overrides for the edge function, applying sport-specific
  /// during selection and the 90-minute gate for during overrides.
  ///
  /// Returns null if the user has no overrides.
  Future<NutritionTargetOverrides?> _loadOverridesForEdgeFunction(
    ActivityType sport,
    double durationMin, {
    Set<ActivityType>? brickSports,
  }) async {
    final user = await _authService.getCurrentUser();
    final overrides = user?.nutritionTargetOverrides;
    if (overrides == null || !overrides.hasAnyOverride) return null;

    // 90-minute gate: strip during overrides for short activities
    if (durationMin < 90) {
      // Return overrides with only pre/post (no during)
      final prePostOnly = NutritionTargetOverrides(
        pre: overrides.pre,
        post: overrides.post,
      );
      return prePostOnly.hasAnyOverride ? prePostOnly : null;
    }

    if (sport == ActivityType.brick) {
      final sports = brickSports == null || brickSports.isEmpty
          ? const {
              ActivityType.running,
              ActivityType.cycling,
              ActivityType.swimming,
            }
          : brickSports;

      final duringRun = sports.contains(ActivityType.running)
          ? (overrides.duringRun ?? overrides.during)
          : null;
      final duringCycling = sports.contains(ActivityType.cycling)
          ? (overrides.duringCycling ?? overrides.during)
          : null;
      final duringSwimming = sports.contains(ActivityType.swimming)
          ? (overrides.duringSwimming ?? overrides.during)
          : null;

      // Legacy flat payload fallback: pick one during override when needed.
      final legacyDuring =
          duringCycling ??
          duringRun ??
          duringSwimming ??
          overrides.duringBrick ??
          overrides.during;

      final brickOverrides = NutritionTargetOverrides(
        pre: overrides.pre,
        during: legacyDuring,
        post: overrides.post,
        duringRun: duringRun,
        duringCycling: duringCycling,
        duringSwimming: duringSwimming,
      );
      return brickOverrides.hasAnyOverride ? brickOverrides : null;
    }

    // Build overrides with the correct sport's during values in the `during`
    // field, since the edge function reads from the flat `during_*` keys.
    final sportDuring = overrides.getDuring(sport);
    return NutritionTargetOverrides(
      pre: overrides.pre,
      during: sportDuring,
      post: overrides.post,
    );
  }

  Set<ActivityType> _extractBrickSports(List<BrickSegment> segments) {
    final sports = <ActivityType>{};
    for (final segment in segments) {
      switch (segment.sport.toLowerCase()) {
        case 'running':
          sports.add(ActivityType.running);
          break;
        case 'cycling':
          sports.add(ActivityType.cycling);
          break;
        case 'swimming':
          sports.add(ActivityType.swimming);
          break;
      }
    }
    return sports;
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

/// Provider for DraftActivityCleanupService.
///
/// keepAlive so the service survives navigate-away (the [MacroTargetsController]
/// schedules cleanup in its onDispose, and the timer must outlive that
/// controller). Its own onDispose cancels any pending cleanup timers, which
/// fires only at scope/app teardown — also keeping widget tests timer-clean.
@Riverpod(keepAlive: true)
DraftActivityCleanupService draftActivityCleanupService(Ref ref) {
  final service = DraftActivityCleanupService(
    activitiesService: ref.read(activitiesServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
}
