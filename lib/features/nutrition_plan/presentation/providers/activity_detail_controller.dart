import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../activities/domain/activity.dart';
import '../../../activities/domain/activity_completion.dart';
import '../../../activities/application/activities_service.dart';
import '../../domain/macro_targets.dart';
import '../../domain/nutrition_plan.dart';
import '../../domain/food_item_data.dart';
import '../../domain/time_slot_assignment.dart';
import '../../application/proportional_scaling_service.dart';
import '../../application/by_hour_sync_service.dart';
import '../../application/macro_generation_service.dart';
import '../../application/brick_macro_service.dart';
import '../../../auth/application/auth_service.dart';
import '../../../activities/domain/activity_reminder.dart';
import '../../../activities/data/activities_repository.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/analytics/analytics_tracker.dart';
import '../../application/resolved_during_target_resolver.dart';
import '../../data/macro_repository.dart';
import '../../data/nutrition_plan_repository.dart';
import '../../data/template_foods_repository.dart';
import '../../../../shared/providers/user_id_provider.dart';
import '../../domain/carb_adjustment_level.dart';
import '../../domain/fuel_log_data.dart';
import '../../domain/nutrition_target_overrides.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../../settings/presentation/providers/settings_controller.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';
import '../../../integrations/presentation/providers/tp_writeback_providers.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../../../calendar/presentation/providers/calendar_controller.dart';
import '../../../events/data/events_repository.dart';
import 'activity_detail_state.dart';
import '../../../../shared/utils/food_display_utils.dart' as food_utils;
import '../../../../shared/utils/category_matcher.dart';
import '../../application/food_operations_service.dart';
import '../utils/activity_detail_helpers.dart';

part 'activity_detail_controller.g.dart';

/// Activity Detail Controller
/// Manages activity viewing, updates, and completion
///
/// SIMPLIFIED: Uses only activityId as the provider family parameter.
/// All data is loaded from the database. This eliminates provider instance
/// mismatches that caused food swap/add operations to not persist.
@riverpod
class ActivityDetailController extends _$ActivityDetailController {
  static const String _detailedMacroTargetsKey = 'detailedMacroTargets';

  AppLogger get _logger => ref.read(appLoggerProvider);
  ActivitiesService get _activitiesService =>
      ref.read(activitiesServiceProvider);
  AuthService get _authService => ref.read(authServiceProvider);
  FoodOperationsService get _foodOpsService =>
      ref.read(foodOperationsServiceProvider);

  Future<NutritionPlanRepository> get _nutritionPlanRepository async =>
      await ref.read(nutritionPlanRepositoryProvider.future);

  @override
  FutureOr<ActivityDetailState> build({
    required String activityId,
    bool isNewActivity = false,
  }) async {
    // CRITICAL FIX: Use userIdProvider (same source as ActivitiesController)
    // This was causing user ID mismatch bug where activities created with one ID
    // were being queried with a different ID
    final userId = await ref.read(userIdProvider.future);

    // DIAGNOSTIC LOGGING: Track user ID source for debugging
    final authUser = await _authService.getCurrentUser();
    _logger.info(
      'Loading activity detail',
      context: 'ACTIVITY_DETAIL_CONTROLLER',
      data: {
        'activityId': activityId,
        'userIdFromProvider': userId,
        'authUserId': authUser?.id ?? 'null',
        'idsMatch': userId == authUser?.id,
      },
    );

    // Sync this specific activity from Supabase before reading local Drift.
    // This ensures coach-created nutrition plans are visible immediately.
    //
    // Skip when opening a just-created activity (`isNewActivity`): the plan was
    // written locally moments ago and has almost certainly not synced to remote
    // yet, so a remote pull here can only surface a staler (plan-less) copy and
    // transiently render "No nutrition plan yet". The local row is authoritative
    // in that case. (`refreshActivityFromRemote` also skips dirty rows, but this
    // avoids the round-trip entirely on the hot create→view path.)
    if (!isNewActivity) {
      try {
        final repo = ref.read(activitiesRepositoryProvider);
        await repo.refreshActivityFromRemote(activityId);
      } catch (e) {
        // Non-fatal: fall back to local data if network unavailable
        _logger.warning(
          'Could not sync activity from remote; using local data',
          context: 'ACTIVITY_DETAIL_CONTROLLER',
          error: e,
        );
      }
    }

    final activity = await _activitiesService.getActivityById(
      userId,
      activityId,
    );

    if (activity == null) {
      _logger.error(
        'Activity not found in database',
        context: 'ACTIVITY_DETAIL_CONTROLLER',
        data: {
          'activityId': activityId,
          'userId': userId,
          'authUserId': authUser?.id,
        },
      );
      throw Exception('Activity not found');
    }

    // Load nutrition plan from activity's nutritionPlanData field
    NutritionPlan? nutritionPlan;
    try {
      final repository = await _nutritionPlanRepository;
      nutritionPlan = await repository.getNutritionPlanByActivityId(
        userId,
        activityId,
      );
      if (nutritionPlan != null) {
        _logger.info('Loaded nutrition plan for activity: ${nutritionPlan.id}');
        // Debug: log section targets from stored plan
        for (final section in nutritionPlan.sections) {
          _logger.info(
            '🎯 OVERRIDE DEBUG [5/5]: Loaded plan section "${section.id}": '
            'carbsTarget=${section.carbsTarget}, proteinTarget=${section.proteinTarget}, '
            'sodiumTarget=${section.sodiumTarget}, fluidsTarget=${section.fluidsTarget}',
          );
        }
        // Enrich food items with displayNamePlural/servingSize from template_foods
        nutritionPlan = await _enrichFoodItemsFromTemplateFoods(nutritionPlan);
      }
    } catch (e) {
      _logger.error('Error loading nutrition plan for activity', error: e);
    }

    // Reverse-lookup event name from linked event
    String? eventName;
    try {
      final eventsRepo = ref.read(eventsRepositoryProvider);
      final event = await eventsRepo.getEventForActivity(activityId);
      eventName = event?.eventName;
    } catch (e) {
      _logger.warning('Failed to look up event for activity: $e');
    }

    // Load completion if exists
    ActivityCompletion? completion;
    if (activity.isCompleted && activity.completedAt != null) {
      // Generate integer IDs from string UUID using hashCode
      final completionId = activity.id.hashCode;
      final activityIdInt = activity.id.hashCode;

      completion = ActivityCompletion(
        id: completionId,
        activityId: activityIdInt,
        userId: activity.userId,
        completedAt: activity.completedAt!,
        overallSatisfaction: activity.completionRating,
        nutritionRating: activity.nutritionRating,
        textNotes: activity.completionNotes,
        actualDistanceMiles: activity.actualDistanceMiles,
        actualDurationMinutes: activity.actualDurationMinutes,
      );
    }

    // Resolve macro targets for this specific activity.
    // Priority: activity-scoped cache -> embedded snapshot -> deterministic derivation.
    MacroTargets? macroTargets;
    try {
      final macroRepo = ref.read(macroRepositoryProvider);
      macroTargets = await macroRepo.getCachedMacroTargetsForActivity(
        activityId,
        expectedActivityType: activity.activityType,
      );
    } catch (e) {
      _logger.warning('Failed to load activity-scoped macro targets: $e');
    }

    macroTargets ??= _extractDetailedMacroTargetsFromPlanData(
      activity.nutritionPlanData,
    );
    macroTargets ??= _deriveMacroTargetsFromActivityPlan(
      activity: activity,
      nutritionPlan: nutritionPlan,
    );
    if (macroTargets != null) {
      try {
        final macroRepo = ref.read(macroRepositoryProvider);
        await macroRepo.saveMacroTargetsForActivity(activityId, macroTargets);
      } catch (e) {
        _logger.warning('Failed to persist activity-scoped macro targets: $e');
      }
    }
    final staleDuringTarget = await _hasStaleDuringTarget(
      activity: activity,
      macroTargets: macroTargets,
    );
    const staleDuringTargetMessage =
        'Nutrition settings changed. Regenerate plan to apply new targets.';

    return ActivityDetailState(
      activity: activity,
      nutritionPlan: nutritionPlan,
      macroTargets: macroTargets,
      completion: completion,
      scheduledDateTime: activity.scheduledDateTime,
      isNewActivity: isNewActivity,
      eventName: eventName,
      hasStaleDuringTarget: staleDuringTarget,
      staleDuringTargetMessage: staleDuringTarget
          ? staleDuringTargetMessage
          : null,
    );
  }

  Future<bool> _hasStaleDuringTarget({
    required Activity activity,
    required MacroTargets? macroTargets,
  }) async {
    if (macroTargets == null) return false;
    if (macroTargets.metrics.durationMin < 90) return false;

    final user = await _authService.getCurrentUser();
    final overrides = user?.nutritionTargetOverrides;
    if (overrides == null || !overrides.hasAnyOverride) return false;

    if (activity.activityType == ActivityType.brick) {
      final segments = macroTargets.brickPhaseTargets?.duringSegments;
      if (segments == null || segments.isEmpty) return false;

      for (final segment in segments) {
        final resolved = ResolvedDuringTargetResolver.resolveForBrickSegment(
          macroTargets: macroTargets,
          segment: segment,
          settingsOverrides: overrides,
        );
        if (resolved.isStaleVsSettings) return true;
      }
      return false;
    }

    final resolved = ResolvedDuringTargetResolver.resolveForSingleSport(
      macroTargets: macroTargets,
      sport: activity.activityType,
      settingsOverrides: overrides,
    );
    return resolved.isStaleVsSettings;
  }

  /// Force refresh activity data from Supabase (for pull-to-refresh).
  Future<void> forceRefresh() async {
    try {
      final repo = ref.read(activitiesRepositoryProvider);
      await repo.refreshActivityFromRemote(activityId);
      ref.invalidateSelf();
    } catch (e) {
      _logger.warning(
        'Force refresh failed',
        context: 'ACTIVITY_DETAIL_CONTROLLER',
        error: e,
      );
      ref.invalidateSelf();
    }
  }

  /// Re-run macro generation for this activity using the latest UserProfile.
  ///
  /// Called after an inline sweat-profile edit so that the new
  /// `knownSweatRateMlPerHour` / `knownSodiumConcentrationMgPerLiter` /
  /// `sweatSodium` values from UserProfile are forwarded to the edge function
  /// and the returned derivation fields (`effectiveSweatRateLPerH`,
  /// `sodiumConcMgPerL`, etc.) are stored in the cached `MacroTargets`.
  ///
  /// Environment inputs (`tempC`, `humidityPct`, `isIndoor`) are recovered
  /// from the echo fields already stored on `DuringRunMacros` in the current
  /// `MacroTargets`. If not present (legacy plan), they default to null / false.
  Future<void> regeneratePlan() async {
    final currentState = state.value;
    if (currentState == null) return;

    final activity = currentState.activity;
    if (activity == null) return;

    final user = await _authService.getCurrentUser();
    if (user == null) return;
    final deviceId = user.id;

    // Recover environment echo from existing stored MacroTargets.
    final storedDuring = currentState.macroTargets?.duringRun;
    final tempC = storedDuring?.tempC;
    final humidityPct = storedDuring?.humidityPct;
    final isIndoor = storedDuring?.isIndoor ?? false;

    final analytics = ref.read(analyticsTrackerProvider);
    final macroRepo = ref.read(macroRepositoryProvider);
    final supabaseClient = ref.read(appExternalDepsProvider).supabaseClient;

    try {
      MacroTargets? freshTargets;

      if (activity.activityType == ActivityType.brick) {
        final brickService = BrickMacroService(
          supabaseClient: supabaseClient,
          macroRepository: macroRepo,
          authService: _authService,
          analytics: analytics,
        );
        final segments = currentState.macroTargets?.brickSegments;
        final segmentOrder = segments?.map((s) => s.sport).toList() ?? const [];
        if (segments != null && segments.isNotEmpty) {
          freshTargets = await brickService.generateBrickMacros(
            activityId: activityId,
            deviceId: deviceId,
            segments: segments,
            segmentOrder: segmentOrder,
            isFasted: false,
            preActivityMinutes: activity.timeBeforeMinutes ?? 60,
          );
        }
      } else if (activity.activityType == ActivityType.running) {
        final macroService = MacroGenerationService(
          supabaseClient: supabaseClient,
          macroRepository: macroRepo,
          authService: _authService,
          analytics: analytics,
        );
        final distanceMiles = activity.distanceMiles ?? 5.0;
        final paceMinPerMile = activity.paceTargetMinutesPerMile ?? 9.0;
        freshTargets = await macroService.generateRunningMacros(
          activityId: activityId,
          deviceId: deviceId,
          distanceMiles: distanceMiles,
          paceMinutesPerMile: paceMinPerMile,
          timeBeforeRunMinutes: activity.timeBeforeMinutes ?? 60,
          gutTraining: user.gutTraining,
          sweatRateCat: user.sweatRate,
          temperatureC: tempC,
          humidityPct: humidityPct,
          indoorOutdoor: isIndoor ? 'indoor' : 'outdoor',
        );
      } else if (activity.activityType == ActivityType.cycling) {
        final macroService = MacroGenerationService(
          supabaseClient: supabaseClient,
          macroRepository: macroRepo,
          authService: _authService,
          analytics: analytics,
        );
        final distanceMiles = activity.distanceMiles ?? 20.0;
        final speedMph = activity.cyclingSpeedMph ?? 15.0;
        final indoorOutdoor = isIndoor
            ? 'indoor'
            : (activity.cyclingIndoorOutdoor ?? 'outdoor');
        freshTargets = await macroService.generateCyclingMacros(
          activityId: activityId,
          deviceId: deviceId,
          distanceMiles: distanceMiles,
          speedMph: speedMph,
          terrain: activity.cyclingTerrain ?? 'flat',
          indoorOutdoor: indoorOutdoor,
          timeBeforeMinutes: activity.timeBeforeMinutes ?? 60,
          elevationGainFt: activity.cyclingElevationGainFt,
          temperatureC: tempC,
          humidityPct: humidityPct,
        );
      }

      if (freshTargets != null) {
        await macroRepo.saveMacroTargetsForActivity(activityId, freshTargets);
        _logger.info(
          'regeneratePlan: fresh MacroTargets saved for activity',
          context: 'ACTIVITY_DETAIL_CONTROLLER',
          data: {
            'activityId': activityId,
            'activityType': activity.activityType.name,
          },
        );
      }
    } catch (e) {
      _logger.warning(
        'regeneratePlan failed; falling back to forceRefresh',
        context: 'ACTIVITY_DETAIL_CONTROLLER',
        error: e,
      );
    }

    // Always invalidate so UI picks up the updated MacroTargets.
    ref.invalidateSelf();
  }

  /// Save activity and any nutrition plan changes
  Future<void> saveActivity() async {
    final currentState = state.value;
    if (currentState == null || currentState.activity == null) return;

    state = AsyncData(currentState.copyWith(isSaving: true));

    state = await AsyncValue.guard(() async {
      try {
        final user = await _authService.getCurrentUser();
        if (user == null || user.id.isEmpty) {
          throw Exception('Cannot save activity: user not authenticated');
        }
        final deviceId = user.id;
        final activity = currentState.activity!;

        // CRITICAL FIX: Always include the current nutrition plan data when saving
        // The state's nutritionPlan may have been updated (e.g., by food swaps) but
        // the activity object still has the old nutritionPlanData from when it was loaded.
        // We must use the current nutritionPlan from state to avoid overwriting changes.
        final updatedActivity = activity.copyWith(
          scheduledDateTime: currentState.scheduledDateTime,
          nutritionPlanData: currentState.nutritionPlan != null
              ? _buildNutritionPlanData(
                  plan: currentState.nutritionPlan!,
                  existingPlanData: activity.nutritionPlanData,
                  macroTargets: currentState.macroTargets,
                )
              : activity.nutritionPlanData,
        );

        await _activitiesService.updateActivity(
          deviceId: deviceId,
          activity: updatedActivity,
        );

        return currentState.copyWith(
          isSaving: false,
          activity: updatedActivity,
          hasUnsavedChanges: false,
          isNewActivity: false, // No longer a new activity after first save
        );
      } catch (error) {
        _logger.error('Error saving activity', error: error);
        rethrow;
      }
    });
  }

  /// Save nutrition plan to activity's nutritionPlanData field
  Future<void> _saveNutritionPlanToActivity(
    String activityId,
    NutritionPlan plan,
  ) async {
    try {
      final user = await _authService.getCurrentUser();
      if (user == null) {
        _logger.warning('Cannot save nutrition plan: no user found');
        return;
      }

      // Get the activity
      final activity = await _activitiesService.getActivityById(
        user.id,
        activityId,
      );
      if (activity == null) {
        _logger.warning('Cannot save nutrition plan: activity not found');
        return;
      }

      // Update activity with nutrition plan JSON and clear stale flag
      final updatedActivity = activity.copyWith(
        nutritionPlanData: _buildNutritionPlanData(
          plan: plan,
          existingPlanData: activity.nutritionPlanData,
          macroTargets: state.value?.macroTargets,
        ),
        needsNutritionRefresh: false,
        updatedAt: DateTime.now(),
      );

      await _activitiesService.updateActivity(
        deviceId: user.id,
        activity: updatedActivity,
      );

      // Fire-and-forget write-back to TrainingPeaks (never blocks save)
      unawaited(_pushToTrainingPeaks(user.id, updatedActivity, plan));

      DebugLogger.info('Nutrition plan saved to activity $activityId');
    } catch (e) {
      _logger.error('Error saving nutrition plan to activity', error: e);
      rethrow;
    }
  }

  Map<String, dynamic> _buildNutritionPlanData({
    required NutritionPlan plan,
    required Map<String, dynamic>? existingPlanData,
    required MacroTargets? macroTargets,
  }) {
    final merged = <String, dynamic>{...plan.toJson()};
    if (macroTargets != null) {
      merged[_detailedMacroTargetsKey] = macroTargets.toJson();
      return merged;
    }

    final existing = existingPlanData?[_detailedMacroTargetsKey];
    if (existing is Map) {
      merged[_detailedMacroTargetsKey] = Map<String, dynamic>.from(existing);
    }
    return merged;
  }

  MacroTargets? _extractDetailedMacroTargetsFromPlanData(
    Map<String, dynamic>? planData,
  ) {
    if (planData == null) return null;

    final candidates = <dynamic>[
      planData[_detailedMacroTargetsKey],
      // Backward-compatible alias if older records used a different key.
      planData['macroTargetsDetailed'],
    ];

    for (final raw in candidates) {
      if (raw is! Map) continue;
      try {
        return MacroTargets.fromJson(Map<String, dynamic>.from(raw));
      } catch (_) {
        // Ignore malformed payloads and continue trying other candidates.
      }
    }
    return null;
  }

  MacroTargets? _deriveMacroTargetsFromActivityPlan({
    required Activity activity,
    required NutritionPlan? nutritionPlan,
  }) {
    if (nutritionPlan == null) return null;

    final beforeSection = nutritionPlan.sections.firstWhere(
      _isBeforeSection,
      orElse: () => const PlanSection(id: '', title: '', foodItems: []),
    );
    final afterSection = nutritionPlan.sections.firstWhere(
      _isAfterSection,
      orElse: () => const PlanSection(id: '', title: '', foodItems: []),
    );

    final hasBefore = beforeSection.id.isNotEmpty;
    final hasAfter = afterSection.id.isNotEmpty;
    final duringTargetTotals = _aggregateDuringTargetsByMacro(nutritionPlan);

    final durationMin = (activity.durationMinutes ?? 0).toDouble();
    final safeDurationH = durationMin > 0 ? durationMin / 60.0 : 1.0;
    final durationBand = _durationBandForMinutes(
      durationMin.round(),
      activity.activityType,
    );

    final beforeCarbs = hasBefore
        ? _getSectionMacroTarget(beforeSection, 'carbs')
        : 0.0;
    final beforeProtein = hasBefore
        ? _getSectionMacroTarget(beforeSection, 'protein')
        : 0.0;
    final beforeFat = hasBefore
        ? _getSectionMacroTarget(beforeSection, 'fat')
        : 0.0;
    final beforeSodium = hasBefore
        ? _getSectionMacroTarget(beforeSection, 'sodium')
        : 0.0;
    final beforeFluids = hasBefore
        ? _getSectionMacroTarget(beforeSection, 'fluids')
        : 0.0;

    final afterCarbs = hasAfter
        ? _getSectionMacroTarget(afterSection, 'carbs')
        : 0.0;
    final afterProtein = hasAfter
        ? _getSectionMacroTarget(afterSection, 'protein')
        : 0.0;
    final afterSodium = hasAfter
        ? _getSectionMacroTarget(afterSection, 'sodium')
        : 0.0;
    final afterFluids = hasAfter
        ? _getSectionMacroTarget(afterSection, 'fluids')
        : 0.0;

    final duringCarbs = duringTargetTotals['carbs'] ?? 0.0;
    final duringSodium = duringTargetTotals['sodium'] ?? 0.0;
    final duringFluids = duringTargetTotals['fluids'] ?? 0.0;

    final distanceMi = activity.distanceMiles ?? 0.0;
    final distanceKm = distanceMi * 1.60934;
    final speedMph =
        activity.cyclingSpeedMph ??
        ((safeDurationH > 0 && distanceMi > 0)
            ? distanceMi / safeDurationH
            : 0.0);

    return MacroTargets(
      id: 'activity-${activity.id}',
      activityType: activity.activityType,
      preRun: PreRunMacros(
        carbsG: beforeCarbs,
        proteinG: beforeProtein,
        fatCapG: beforeFat,
        fluidsMl: beforeFluids,
        sodiumMg: beforeSodium,
      ),
      duringRun: DuringRunMacros(
        carbRateGPerH: duringCarbs / safeDurationH,
        carbTotalG: duringCarbs,
        fluidRateMlPerH: duringFluids / safeDurationH,
        fluidTotalMl: duringFluids,
        sodiumRateMgPerH: duringSodium / safeDurationH,
        sodiumTotalMg: duringSodium,
        massNormRateGPerH: duringCarbs / safeDurationH,
        absClampRangeGPerH: durationBand,
        carbsLowG: durationBand[0] * safeDurationH,
        carbsHighG: durationBand[1] * safeDurationH,
      ),
      postRun: PostRunMacros(
        carbsG: afterCarbs,
        proteinG: afterProtein,
        fluidsMl: afterFluids,
        sodiumMg: afterSodium,
      ),
      metrics: RunMetrics(
        distanceMi: distanceMi,
        distanceKm: distanceKm,
        durationH: durationMin > 0 ? safeDurationH : 0.0,
        durationMin: durationMin,
        paceMinPerMile: activity.paceTargetMinutesPerMile,
        speedMph: speedMph,
        caloriesGrossKcal: 0,
        caloriesNetKcal: 0,
        met: 0,
      ),
      calculationRule: 'Derived from stored activity nutrition plan',
      timestamp: activity.updatedAt,
      isUserModified: false,
      modifiedFields: const [],
    );
  }

  bool _isBeforeSection(PlanSection section) {
    final id = section.id.toLowerCase();
    final title = section.title.toLowerCase();
    return id.startsWith('before') || title.startsWith('before');
  }

  bool _isDuringSection(PlanSection section) {
    final id = section.id.toLowerCase();
    final title = section.title.toLowerCase();
    return id.startsWith('during') || title.startsWith('during');
  }

  bool _isAfterSection(PlanSection section) {
    final id = section.id.toLowerCase();
    final title = section.title.toLowerCase();
    return id.startsWith('after') || title.startsWith('after');
  }

  Map<String, double> _aggregateDuringTargetsByMacro(
    NutritionPlan nutritionPlan,
  ) {
    double carbs = 0;
    double sodium = 0;
    double fluids = 0;
    for (final section in nutritionPlan.sections.where(_isDuringSection)) {
      carbs += section.carbsTarget ?? _sumFoodMacro(section.foodItems, 'carbs');
      sodium +=
          section.sodiumTarget ?? _sumFoodMacro(section.foodItems, 'sodium');
      fluids +=
          section.fluidsTarget ?? _sumFoodMacro(section.foodItems, 'fluids');
    }
    return {'carbs': carbs, 'sodium': sodium, 'fluids': fluids};
  }

  double _getSectionMacroTarget(PlanSection section, String macro) {
    if (section.hasSubPhases) {
      final total = section.subPhases!.fold<double>(
        0.0,
        (sum, subPhase) => sum + _getSubPhaseMacroTarget(subPhase, macro),
      );
      if (total > 0) return total;
    }

    final sectionTarget = _getSectionTargetValue(section, macro);
    if (sectionTarget != null && sectionTarget > 0) return sectionTarget;
    return _sumFoodMacro(section.foodItems, macro);
  }

  double _getSubPhaseMacroTarget(BeforeSubPhase subPhase, String macro) {
    switch (macro) {
      case 'carbs':
        return subPhase.carbsTarget ?? 0.0;
      case 'protein':
        return subPhase.proteinTarget ?? 0.0;
      case 'fat':
        return subPhase.fatTarget ?? 0.0;
      case 'sodium':
        return subPhase.sodiumTarget ?? 0.0;
      case 'fluids':
        return subPhase.fluidsTarget ?? 0.0;
      default:
        return 0.0;
    }
  }

  double? _getSectionTargetValue(PlanSection section, String macro) {
    switch (macro) {
      case 'carbs':
        return section.carbsTarget;
      case 'protein':
        return section.proteinTarget;
      case 'fat':
        return section.fatTarget;
      case 'sodium':
        return section.sodiumTarget;
      case 'fluids':
        return section.fluidsTarget;
      default:
        return null;
    }
  }

  double _sumFoodMacro(List<FoodItemData> foods, String key) {
    double total = 0;
    for (final food in foods) {
      final info = food.nutritionalInfo;
      if (info == null) continue;
      switch (key) {
        case 'carbs':
          total += (info.carbs ?? 0).toDouble();
          break;
        case 'protein':
          total += (info.protein ?? 0).toDouble();
          break;
        case 'sodium':
          total += (info.sodium ?? 0).toDouble();
          break;
        case 'fluids':
          total += info.fluids ?? 0;
          break;
      }
    }
    return total;
  }

  List<double> _durationBandForMinutes(
    int durationMin,
    ActivityType activityType,
  ) {
    if (activityType == ActivityType.swimming) {
      return const [0, 0];
    }
    if (durationMin < 60) return const [0, 30];
    if (durationMin < 90) return const [30, 60];
    if (durationMin < 150) return const [45, 60];
    if (durationMin < 240) return const [60, 90];
    return const [80, 100];
  }

  /// Complete activity with ratings and notes
  Future<void> completeActivity({
    required int overallSatisfaction,
    String? textNotes,
    int? nutritionRating,
  }) async {
    final currentState = state.value;
    if (currentState == null || currentState.activity == null) return;

    state = AsyncData(currentState.copyWith(isCompleting: true));

    state = await AsyncValue.guard(() async {
      try {
        final user = await _authService.getCurrentUser();
        if (user == null || user.id.isEmpty) {
          throw Exception('Cannot complete activity: user not authenticated');
        }

        // Update activity with completion data
        final completedActivity = currentState.activity!.copyWith(
          status: ActivityStatus.completed,
          completedAt: DateTime.now(),
          completionRating: overallSatisfaction,
          nutritionRating: nutritionRating,
          completionNotes: textNotes,
        );

        await _activitiesService.updateActivity(
          deviceId: user.id,
          activity: completedActivity,
        );

        // Fire-and-forget: push feedback to TrainingPeaks
        unawaited(
          _pushFeedbackToTrainingPeaks(
            user.id,
            completedActivity,
            overallSatisfaction,
            textNotes,
          ),
        );

        // Reload activity to get updated completion data
        ref.invalidateSelf();

        return currentState.copyWith(isCompleting: false);
      } catch (error) {
        _logger.error('Error completing activity', error: error);
        rethrow;
      }
    });
  }

  /// Apply carb feedback adjustment to the user's nutrition target overrides.
  ///
  /// This writes an absolute sport-specific override using "latest wins":
  /// newRate = (workoutDuringRate * adjustmentFactor), with sport-aware clamping.
  ///
  /// During overrides only apply to eligible workouts (>= 90 minutes).
  Future<void> applyCarbFeedbackAdjustment(
    CarbAdjustmentLevel level, {
    bool isEdit = false,
  }) async {
    // For first submit, "Just Right" keeps existing settings untouched.
    // In edit mode we do apply factor=1.0 to revert prior adjustments.
    if (level == CarbAdjustmentLevel.justRight && !isEdit) return;

    try {
      final currentState = state.value;
      final activity = currentState?.activity;
      final plan = currentState?.nutritionPlan;
      final baseRate = ActivityDetailHelpers.computeDuringCarbRateGPerH(
        activity: activity,
        nutritionPlan: plan,
      );
      if (baseRate == null) {
        _logger.info('Skipping carb feedback: activity not eligible');
        return;
      }

      final user = await _authService.getCurrentUser();
      if (user == null) {
        _logger.warning('Cannot apply carb feedback: no user');
        return;
      }

      // Determine which sport overrides should be updated.
      final targetSports = _resolveFeedbackTargetSports(activity);

      // Build updated overrides — write to sport-specific fields only.
      final currentOverrides =
          user.nutritionTargetOverrides ?? const NutritionTargetOverrides();
      var updatedOverrides = currentOverrides;
      final updatedRates = <String, double>{};

      for (final sport in targetSports) {
        final sportMax = _maxDuringCarbRateForSport(sport);
        final newRate = (baseRate * level.adjustmentFactor).clamp(
          NutritionTargetGuardrails.duringMinCarbRateGPerH,
          sportMax,
        );
        final existingSportDuring = currentOverrides.getDuring(sport);
        updatedOverrides = updatedOverrides.setDuring(
          sport,
          DuringActivityOverrides(
            carbRateGPerH: newRate,
            sodiumRateMgPerH: existingSportDuring?.sodiumRateMgPerH,
            fluidRateMlPerH: existingSportDuring?.fluidRateMlPerH,
          ),
        );
        updatedRates[sport.name] = newRate;
      }

      // Save via settings controller
      final settingsController = ref.read(settingsControllerProvider.notifier);
      await settingsController.saveNutritionTargetOverrides(updatedOverrides);

      _logger.info(
        'Carb feedback applied',
        context: 'ACTIVITY_DETAIL_CONTROLLER',
        data: {
          'level': level.name,
          'baseRate': baseRate,
          'newRates': updatedRates,
          'factor': level.adjustmentFactor,
          'activityType':
              activity?.activityType.name ?? ActivityType.running.name,
          'targetSports': targetSports.map((sport) => sport.name).toList(),
        },
      );

      _trackAnalytics('carb_feedback_applied', {
        'activity_id': activityId,
        'event_type': isEdit ? 'edited' : 'submitted',
        'level': level.name,
        'adjustment_factor': level.adjustmentFactor,
        'base_rate': baseRate,
        'new_rates': updatedRates,
        'activity_type':
            activity?.activityType.name ?? ActivityType.running.name,
        'target_sports': targetSports.map((sport) => sport.name).join(','),
      });
      _trackAnalytics(
        isEdit ? 'carb_feedback_edited' : 'carb_feedback_submitted',
        {
          'activity_id': activityId,
          'level': level.name,
          'adjustment_factor': level.adjustmentFactor,
          'base_rate': baseRate,
          'new_rates': updatedRates,
          'activity_type':
              activity?.activityType.name ?? ActivityType.running.name,
          'target_sports': targetSports.map((sport) => sport.name).join(','),
        },
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error applying carb feedback',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  double _maxDuringCarbRateForSport(ActivityType activityType) {
    switch (activityType) {
      case ActivityType.running:
        return NutritionTargetGuardrails.duringMaxCarbRateRunning;
      case ActivityType.cycling:
        return NutritionTargetGuardrails.duringMaxCarbRateCycling;
      case ActivityType.swimming:
        return NutritionTargetGuardrails.duringMaxCarbRateSwimming;
      default:
        return NutritionTargetGuardrails.duringMaxCarbRateGPerH;
    }
  }

  List<ActivityType> _resolveFeedbackTargetSports(Activity? activity) {
    final activityType = activity?.activityType;
    if (activityType != ActivityType.brick) {
      return [activityType ?? ActivityType.running];
    }

    final sports = <ActivityType>{};
    for (final segment in activity?.brickMetadata?.segments ?? const []) {
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

    if (sports.isEmpty) {
      sports.addAll(const [
        ActivityType.running,
        ActivityType.cycling,
        ActivityType.swimming,
      ]);
    }

    return sports.toList(growable: false);
  }

  /// Update workout notes for a completed activity
  Future<void> updateWorkoutNotes(String? notes) async {
    final currentState = state.value;
    if (currentState == null ||
        currentState.activity == null ||
        currentState.completion == null) {
      return;
    }

    state = await AsyncValue.guard(() async {
      try {
        final user = await _authService.getCurrentUser();
        if (user == null || user.id.isEmpty) {
          throw Exception(
            'Cannot update workout notes: user not authenticated',
          );
        }

        // Update activity with new completion notes
        final updatedActivity = currentState.activity!.copyWith(
          completionNotes: notes,
        );

        await _activitiesService.updateActivity(
          deviceId: user.id,
          activity: updatedActivity,
        );

        // Reload activity to get updated completion data
        ref.invalidateSelf();

        return currentState;
      } catch (error) {
        _logger.error('Error updating workout notes', error: error);
        rethrow;
      }
    });
  }

  /// Update completion rating for a completed activity
  Future<void> updateCompletionRating(int rating) async {
    final currentState = state.value;
    if (currentState == null ||
        currentState.activity == null ||
        currentState.completion == null) {
      return;
    }

    state = await AsyncValue.guard(() async {
      try {
        final user = await _authService.getCurrentUser();
        if (user == null || user.id.isEmpty) {
          throw Exception(
            'Cannot update completion rating: user not authenticated',
          );
        }

        final updatedActivity = currentState.activity!.copyWith(
          completionRating: rating,
        );

        await _activitiesService.updateActivity(
          deviceId: user.id,
          activity: updatedActivity,
        );

        ref.invalidateSelf();

        return currentState;
      } catch (error) {
        _logger.error('Error updating completion rating', error: error);
        rethrow;
      }
    });
  }

  /// Update completion feedback for an already-completed activity.
  Future<void> updateCompletionFeedback({
    required int rating,
    String? notes,
    CarbAdjustmentLevel? carbAdjustment,
  }) async {
    final currentState = state.value;
    if (currentState == null ||
        currentState.activity == null ||
        currentState.completion == null) {
      return;
    }

    state = await AsyncValue.guard(() async {
      try {
        final user = await _authService.getCurrentUser();
        if (user == null || user.id.isEmpty) {
          throw Exception(
            'Cannot update completion feedback: user not authenticated',
          );
        }

        final updatedActivity = currentState.activity!.copyWith(
          completionRating: rating,
          completionNotes: notes,
          nutritionRating: carbAdjustment?.ratingValue,
        );

        await _activitiesService.updateActivity(
          deviceId: user.id,
          activity: updatedActivity,
        );

        ref.invalidateSelf();
        return currentState;
      } catch (error) {
        _logger.error('Error updating completion feedback', error: error);
        rethrow;
      }
    });
  }

  /// Update scheduled date/time
  /// Auto-saves to database and invalidates activities list and calendar
  Future<void> updateScheduledDateTime(DateTime newDateTime) async {
    final currentState = state.value;
    if (currentState == null || currentState.activity == null) return;

    try {
      final user = await _authService.getCurrentUser();
      if (user == null || user.id.isEmpty) {
        _logger.warning('Cannot update schedule: user not authenticated');
        return;
      }

      // Update the activity with the new scheduled date/time
      final updatedActivity = currentState.activity!.copyWith(
        scheduledDateTime: newDateTime,
        updatedAt: DateTime.now(),
      );

      // Update local state immediately for UI responsiveness
      state = AsyncData(
        currentState.copyWith(
          scheduledDateTime: newDateTime,
          activity: updatedActivity,
          hasUnsavedChanges: false,
        ),
      );

      // Save to database
      await _activitiesService.updateActivity(
        deviceId: user.id,
        activity: updatedActivity,
      );

      // Invalidate activities list and calendar so they reflect the new date
      ref.invalidate(activitiesControllerProvider);
      ref.invalidate(calendarControllerProvider);

      _logger.info(
        'Schedule updated and saved',
        context: 'ACTIVITY_DETAIL_CONTROLLER',
        data: {
          'activityId': activityId,
          'newDateTime': newDateTime.toIso8601String(),
        },
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error updating scheduled date/time',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Update reminder settings
  Future<void> updateReminder(ActivityReminder? reminder) async {
    final currentState = state.value;
    if (currentState == null || currentState.activity == null) return;

    final updatedActivity = currentState.activity!.copyWith(
      reminderEnabled: reminder?.enabled ?? false,
      reminderDaysBefore: reminder?.daysBefore,
      reminderTimeOfDay: reminder?.timeOfDay,
      reminderRecurring: reminder?.recurring ?? false,
    );

    state = AsyncData(
      currentState.copyWith(activity: updatedActivity, hasUnsavedChanges: true),
    );
  }

  /// Mark that the nutrition plan has unsaved changes
  void markAsChanged() {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(hasUnsavedChanges: true));
  }

  /// Clear unsaved changes flag
  void clearChanges() {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(hasUnsavedChanges: false));
  }

  // ============================================================================
  // FOOD ENRICHMENT
  // ============================================================================

  /// Enrich food items in a nutrition plan with displayNamePlural and servingSize
  /// from the local template_foods table.
  Future<NutritionPlan> _enrichFoodItemsFromTemplateFoods(
    NutritionPlan plan,
  ) async {
    try {
      final templateFoodsRepo = ref.read(templateFoodsRepositoryProvider);
      final allTemplateFoods = await templateFoodsRepo.getAllTemplateFoods();

      // Build a lookup map by ID for fast matching
      final foodLookup = <String, dynamic>{};
      for (final tf in allTemplateFoods) {
        foodLookup[tf.id] = tf;
      }

      FoodItemData enrichFood(FoodItemData food) {
        final tf = foodLookup[food.id];
        if (tf == null) return _foodOpsService.normalizeFoodQuantity(food);

        // Derive timingCategory from template_foods DB fields
        final derivedTimingCategory = TimingCategory.fromFoodProperties(
          isLiquid: tf.isLiquid ?? false,
          productType: tf.productType ?? 'real_food',
          isElectrolyte: tf.isElectrolyte ?? false,
          carbsPerServing: tf.carbsG ?? 0,
        );

        // If quantity is a bare number (no unit tail), rebuild it with the
        // serving unit from template_foods so the display reads e.g.
        // "2 cups Oatmeal" instead of "2 Oatmeals".
        final enrichedQuantity = _enrichQuantityWithUnit(
          food.quantity,
          tf.servingUnit,
          food.name,
          servingSize: tf.servingSize,
        );

        return _foodOpsService.normalizeFoodQuantity(
          FoodItemData(
            id: food.id,
            name: food.name,
            quantity: enrichedQuantity,
            imageAddress: food.imageAddress ?? tf.imageAddress,
            description: food.description ?? tf.description,
            timing: food.timing,
            nutritionalInfo: food.nutritionalInfo,
            instructions: food.instructions,
            displayName: food.displayName ?? tf.displayName,
            displayNamePlural: food.displayNamePlural ?? tf.displayNamePlural,
            displayOverride: food.displayOverride,
            servingSize: food.servingSize ?? tf.servingSize,
            isDrink:
                food.isDrink ||
                derivedTimingCategory == TimingCategory.sipThroughout ||
                derivedTimingCategory == TimingCategory.fuelDrink,
            templateId: food.templateId,
            scaleMultiplier: food.scaleMultiplier,
            timingCategory: food.timingCategory ?? derivedTimingCategory,
            isIndivisible: food.isIndivisible,
          ),
        );
      }

      final enrichedSections = plan.sections.map((section) {
        if (section.hasSubPhases) {
          final enrichedSubPhases = section.subPhases!.map((sp) {
            return sp.copyWith(
              foodItems: sp.foodItems.map(enrichFood).toList(),
            );
          }).toList();
          return section.copyWith(subPhases: enrichedSubPhases);
        }
        return section.copyWith(
          foodItems: section.foodItems.map(enrichFood).toList(),
        );
      }).toList();

      return plan.copyWith(sections: enrichedSections);
    } catch (e) {
      _logger.warning('Failed to enrich food items from template_foods: $e');
      return plan;
    }
  }

  /// Rebuild a bare-number quantity string (e.g. "2") to include the serving
  /// unit and food name (e.g. "2 cups Oatmeal").
  ///
  /// If the quantity already has a tail (e.g. "2 cups Oatmeal") or no unit is
  /// available, the original string is returned unchanged.
  String _enrichQuantityWithUnit(
    String rawQuantity,
    String? servingUnit,
    String foodName, {
    String? servingSize,
  }) {
    // Determine the unit — prefer explicit servingUnit, fallback to parsing
    // the unit from servingSize (e.g. "½ cup dry (~40g)" → "cup")
    String? resolvedUnit = servingUnit;
    if ((resolvedUnit == null || resolvedUnit.isEmpty) && servingSize != null) {
      resolvedUnit = _parseUnitFromServingSize(servingSize);
    }
    if (resolvedUnit == null || resolvedUnit.isEmpty) return rawQuantity;

    final trimmed = rawQuantity.trim();
    final numericQty = food_utils.parseLeadingQuantity(trimmed);
    if (numericQty == null) return rawQuantity;

    // Check if there's already a tail (unit/descriptor) after the number
    final tailMatch = RegExp(r'^[\d.]+\s*(.*)$').firstMatch(trimmed);
    final tail = tailMatch?.group(1)?.trim() ?? '';
    if (tail.isNotEmpty) return rawQuantity;

    // Quantity is bare — rebuild with unit + food name
    final qtyStr = food_utils.formatQuantity(numericQty);
    final unit = numericQty != 1 ? _pluralizeUnit(resolvedUnit) : resolvedUnit;
    return '$qtyStr $unit $foodName';
  }

  /// Parse a measurement unit from a servingSize string.
  /// Handles unicode fractions (½, ¼, etc.) and regular numbers.
  /// Returns the raw unit string if recognized, null otherwise.
  static String? _parseUnitFromServingSize(String servingSize) {
    final trimmed = servingSize.trim();
    // Match leading number (digit, unicode fraction, or mixed like "1½")
    // then whitespace, then capture the unit word
    final match = RegExp(
      r'^[\d./½¼¾⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞]+\s+(\S+)',
    ).firstMatch(trimmed);
    final unit = match?.group(1)?.trim();
    if (unit == null) return null;

    const knownUnits = {
      'cup',
      'cups',
      'tbsp',
      'tsp',
      'oz',
      'ml',
      'g',
      'mg',
      'kg',
      'l',
      'slice',
      'slices',
      'piece',
      'pieces',
      'scoop',
      'scoops',
      'tablespoon',
      'tablespoons',
      'teaspoon',
      'teaspoons',
      'packet',
      'packets',
      'serving',
      'servings',
      'pouch',
      'pouches',
      'bottle',
      'bottles',
      'shot',
      'shots',
      'bar',
      'bars',
      'waffle',
      'waffles',
      'sheet',
      'sheets',
    };
    if (!knownUnits.contains(unit.toLowerCase())) return null;
    return unit;
  }

  /// Simple unit pluralization for common serving units.
  static String _pluralizeUnit(String unit) {
    final lower = unit.toLowerCase().trim();
    // Abbreviations don't change
    if (const {
      'tbsp',
      'tsp',
      'oz',
      'ml',
      'g',
      'mg',
      'kg',
      'l',
      'fl oz',
    }.contains(lower)) {
      return unit;
    }
    if (lower.endsWith('s')) return unit;
    if (lower.endsWith('ch') || lower.endsWith('sh') || lower.endsWith('x')) {
      return '${unit}es';
    }
    return '${unit}s';
  }

  // ============================================================================
  // UNIFIED FOOD MODIFICATION METHODS
  // ============================================================================

  /// Check if a category matches a section by ID or title using flexible prefix matching
  ///
  /// Supports all activity types: running, cycling, swimming, brick
  /// Categories: 'before_run', 'during_run', 'during_swim', 'during_cycling', 'transition', 'after_run'
  bool _categoryMatchesSection(
    String category,
    String sectionId,
    String sectionTitle,
  ) {
    return CategoryMatcher.matches(category, sectionId, sectionTitle);
  }

  /// Create a FoodItemData from a food object with optional custom amount
  FoodItemData _createFoodItemData(dynamic food, {double? customAmount}) {
    return _foodOpsService.createFoodItemData(food, customAmount: customAmount);
  }

  /// Unified method to modify food items in a nutrition plan section.
  ///
  /// This consolidates add, swap, and delete operations to ensure consistent
  /// behavior and prevent bugs like losing section targets (uses copyWith).
  ///
  /// [category] - The section category ('before_run', 'during_run', 'after_run')
  /// [transform] - Function that transforms the current food items list
  /// [operationName] - Name of the operation for logging
  Future<void> _updateSectionFoods({
    required String category,
    required List<FoodItemData> Function(List<FoodItemData> currentItems)
    transform,
    required String operationName,
  }) async {
    final currentState = state.value;
    if (currentState?.nutritionPlan == null) {
      _logger.warning('Cannot $operationName: no nutrition plan');
      return;
    }

    final currentPlan = currentState!.nutritionPlan!;

    state = AsyncData(currentState.copyWith(hasUnsavedChanges: true));

    try {
      // Parse sub-phase target from category (e.g., 'before_run:snack' → sectionCategory='before_run', subPhaseType='snack')
      final parts = category.split(':');
      final sectionCategory = parts[0];
      final targetSubPhaseType = parts.length > 1 ? parts[1] : null;

      // Update sections, using copyWith to preserve all section properties (including targets)
      final updatedSections = currentPlan.sections.map((section) {
        if (_categoryMatchesSection(
          sectionCategory,
          section.id,
          section.title,
        )) {
          // If the section has sub-phases (V2 template plans), apply transform to targeted sub-phase only
          if (section.hasSubPhases) {
            final updatedSubPhases = section.subPhases!.map((subPhase) {
              // Only apply transform to the targeted sub-phase, or all if no target specified
              if (targetSubPhaseType != null &&
                  subPhase.subPhaseType != targetSubPhaseType) {
                return subPhase;
              }
              final updatedItems = transform(subPhase.foodItems);
              return subPhase.copyWith(foodItems: updatedItems);
            }).toList();
            return section.copyWith(subPhases: updatedSubPhases);
          }
          final updatedItems = transform(section.foodItems);

          // Keep byHourData in sync when food items change
          ByHourData? updatedByHour = section.byHourData;
          if (updatedByHour != null) {
            final currentIds = updatedItems.map((f) => f.id).toSet();
            final assignedIds = updatedByHour.assignments
                .map((a) => a.foodItemId)
                .toSet();

            // Remove assignments for deleted foods
            for (final removedId in assignedIds.difference(currentIds)) {
              updatedByHour = ByHourSyncService.removeFoodAssignments(
                existing: updatedByHour!,
                removedFoodId: removedId,
              );
            }

            // Adjust assignments for quantity changes
            for (final food in updatedItems) {
              if (assignedIds.contains(food.id)) {
                final newQty = ByHourSyncService.parseQuantity(food);
                updatedByHour =
                    ByHourSyncService.adjustAssignmentsForQuantityChange(
                      existing: updatedByHour!,
                      foodId: food.id,
                      newQty: newQty,
                      isIndivisible: food.isIndivisible,
                    );
              }
            }
          }

          return section.copyWith(
            foodItems: updatedItems,
            byHourData: updatedByHour,
          );
        }
        return section;
      }).toList();

      final updatedPlan = currentPlan.copyWith(
        sections: updatedSections,
        updatedAt: DateTime.now(),
      );

      // Update state first for immediate UI feedback
      state = AsyncData(
        currentState.copyWith(
          nutritionPlan: updatedPlan,
          hasUnsavedChanges: false,
        ),
      );

      // Auto-save to prevent data loss on provider rebuild (e.g., navigation)
      final activity = currentState.activity;
      if (activity != null) {
        await _saveNutritionPlanToActivity(activity.id, updatedPlan);
        _logger.info(
          '$operationName: Auto-saved nutrition plan to prevent data loss',
        );
      }

      _logger.info(
        '$operationName SUCCESS',
        context: 'ActivityDetailController',
        data: {'category': category, 'updatedPlanId': updatedPlan.id},
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Error in $operationName',
        error: error,
        stackTrace: stackTrace,
      );
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Swap a food item in the nutrition plan
  Future<void> swapFoodItem(
    String oldFoodId,
    dynamic newFood,
    String category, {
    double? customAmount,
  }) async {
    _logger.info(
      'swapFoodItem ENTRY',
      context: 'ActivityDetailController',
      data: {
        'oldFoodId': oldFoodId,
        'newFoodName': newFood?.name ?? 'null',
        'category': category,
        'customAmount': customAmount,
      },
    );

    await _updateSectionFoods(
      category: category,
      operationName: 'swapFoodItem',
      transform: (items) => items.map((item) {
        if (item.id == oldFoodId) {
          return _createFoodItemData(newFood, customAmount: customAmount);
        }
        return item;
      }).toList(),
    );
  }

  /// Add a food item to the nutrition plan
  Future<void> addFoodItem(
    dynamic food,
    String category, {
    double? customAmount,
  }) async {
    _logger.info(
      'addFoodItem ENTRY',
      context: 'ActivityDetailController',
      data: {
        'foodName': food?.name ?? 'null',
        'category': category,
        'customAmount': customAmount,
      },
    );

    await _updateSectionFoods(
      category: category,
      operationName: 'addFoodItem',
      transform: (items) => [
        ...items,
        _createFoodItemData(food, customAmount: customAmount),
      ],
    );

    _trackAnalytics('food_added', {
      'food_name': food?.name,
      'food_id': food?.id,
      'section': category,
      'quantity': customAmount,
    });
  }

  /// Delete a food item from the nutrition plan
  Future<void> deleteFoodItem(String foodId, String category) async {
    _logger.info(
      'deleteFoodItem ENTRY',
      context: 'ActivityDetailController',
      data: {'foodId': foodId, 'category': category},
    );

    await _updateSectionFoods(
      category: category,
      operationName: 'deleteFoodItem',
      transform: (items) => items.where((item) => item.id != foodId).toList(),
    );
  }

  /// Update the quantity of an existing food item
  Future<void> updateFoodQuantity(
    String foodId,
    String category,
    double newQuantity,
  ) async {
    _logger.info(
      'updateFoodQuantity ENTRY',
      context: 'ActivityDetailController',
      data: {
        'foodId': foodId,
        'category': category,
        'newQuantity': newQuantity,
      },
    );

    await _updateSectionFoods(
      category: category,
      operationName: 'updateFoodQuantity',
      transform: (items) => items.map((item) {
        if (item.id == foodId) {
          final currentQuantity =
              food_utils.parseLeadingQuantity(item.quantity) ?? 1.0;
          final normalizedQty = _foodOpsService.roundFriendlyQuantity(
            newQuantity,
            isIndivisible: item.isIndivisible,
          );
          final scaleFactor = currentQuantity > 0
              ? normalizedQty / currentQuantity
              : 1.0;
          final newQuantityDisplay = _foodOpsService.buildQuantityLabel(
            item,
            normalizedQty,
          );

          final currentNutrition = item.nutritionalInfo;
          final scaledNutrition = currentNutrition != null
              ? NutritionalInfo(
                  calories: currentNutrition.calories != null
                      ? (currentNutrition.calories! * scaleFactor).round()
                      : null,
                  carbs: currentNutrition.carbs != null
                      ? (currentNutrition.carbs! * scaleFactor).round()
                      : null,
                  protein: currentNutrition.protein != null
                      ? (currentNutrition.protein! * scaleFactor).round()
                      : null,
                  fat: currentNutrition.fat != null
                      ? (currentNutrition.fat! * scaleFactor).round()
                      : null,
                  sodium: currentNutrition.sodium != null
                      ? (currentNutrition.sodium! * scaleFactor).round()
                      : null,
                  fluids: currentNutrition.fluids != null
                      ? currentNutrition.fluids! * scaleFactor
                      : null,
                )
              : null;

          return FoodItemData(
            id: item.id,
            name: item.name,
            quantity: newQuantityDisplay,
            imageAddress: item.imageAddress,
            instructions: item.instructions,
            description: item.description,
            displayName: item.displayName,
            displayNamePlural: item.displayNamePlural,
            displayOverride: item.displayOverride,
            servingSize: item.servingSize,
            isDrink: item.isDrink,
            isIndivisible: item.isIndivisible,
            templateId: item.templateId,
            scaleMultiplier: item.scaleMultiplier,
            timingCategory: item.timingCategory,
            nutritionalInfo: scaledNutrition,
          );
        }
        return item;
      }).toList(),
    );
  }

  /// Update a food quantity within a sub-phase, applying proportional scaling
  /// to all sibling items in the same sub-phase.
  ///
  /// [subPhaseIndex] - Index of the sub-phase within the before section
  /// [foodIndex] - Index of the changed food within the sub-phase
  /// [newQuantity] - New quantity for the changed food
  Future<void> updateSubPhaseQuantityWithScaling(
    int subPhaseIndex,
    int foodIndex,
    double newQuantity,
  ) async {
    final currentState = state.value;
    if (currentState?.nutritionPlan == null) {
      _logger.warning(
        'Cannot updateSubPhaseQuantityWithScaling: no nutrition plan',
      );
      return;
    }

    final currentPlan = currentState!.nutritionPlan!;

    state = AsyncData(currentState.copyWith(hasUnsavedChanges: true));

    try {
      final updatedSections = currentPlan.sections.map((section) {
        if (_categoryMatchesSection('before_run', section.id, section.title) &&
            section.hasSubPhases) {
          final updatedSubPhases = section.subPhases!.asMap().entries.map((
            entry,
          ) {
            if (entry.key == subPhaseIndex) {
              final subPhase = entry.value;
              // Apply proportional scaling to all items in this sub-phase
              final scaledSubPhase = ProportionalScalingService.scaleSubPhase(
                subPhase,
                foodIndex,
                newQuantity,
              );
              return scaledSubPhase;
            }
            return entry.value;
          }).toList();
          return section.copyWith(subPhases: updatedSubPhases);
        }
        return section;
      }).toList();

      final updatedPlan = currentPlan.copyWith(
        sections: updatedSections,
        updatedAt: DateTime.now(),
      );

      state = AsyncData(
        currentState.copyWith(
          nutritionPlan: updatedPlan,
          hasUnsavedChanges: false,
        ),
      );

      // Auto-save
      final activity = currentState.activity;
      if (activity != null) {
        await _saveNutritionPlanToActivity(activity.id, updatedPlan);
        _logger.info(
          'updateSubPhaseQuantityWithScaling: Auto-saved nutrition plan',
        );
      }

      _logger.info(
        'updateSubPhaseQuantityWithScaling SUCCESS',
        context: 'ActivityDetailController',
        data: {
          'subPhaseIndex': subPhaseIndex,
          'foodIndex': foodIndex,
          'newQuantity': newQuantity,
        },
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Error in updateSubPhaseQuantityWithScaling',
        error: error,
        stackTrace: stackTrace,
      );
      state = AsyncValue.error(error, stackTrace);
    }
  }

  // ============================================================================
  // BY-HOUR VIEW METHODS
  // ============================================================================

  /// Initialize byHourData for a during-activity section on first toggle.
  ///
  /// Drinks and electrolytes are auto-placed in the global sip section
  /// (hourIndex == -1). Non-drink foods are left unassigned in the tray.
  ///
  /// [category] - The section category (e.g., 'during_run', 'during_bike')
  /// [durationMinutes] - Duration of the during phase in minutes
  Future<void> initializeByHourData(
    String category,
    int durationMinutes,
  ) async {
    final currentState = state.value;
    if (currentState?.nutritionPlan == null) return;

    final currentPlan = currentState!.nutritionPlan!;

    // Find the target section
    final targetSection = currentPlan.sections.firstWhere(
      (s) => _categoryMatchesSection(category, s.id, s.title),
      orElse: () => currentPlan.sections.first,
    );

    // Already initialized - skip
    if (targetSection.byHourData != null) return;

    // Initialize with global sip section: drinks/electrolytes auto-placed,
    // non-drink foods left in unassigned tray
    final byHourData = ByHourSyncService.initializeByHourWithGlobalSip(
      summaryFoods: targetSection.foodItems,
      durationMinutes: durationMinutes,
    );

    final updatedSections = currentPlan.sections.map((section) {
      if (_categoryMatchesSection(category, section.id, section.title)) {
        return section.copyWith(byHourData: byHourData);
      }
      return section;
    }).toList();

    final updatedPlan = currentPlan.copyWith(
      sections: updatedSections,
      updatedAt: DateTime.now(),
    );

    state = AsyncData(currentState.copyWith(nutritionPlan: updatedPlan));

    // Auto-save to persist byHourData
    final activity = currentState.activity;
    if (activity != null) {
      await _saveNutritionPlanToActivity(activity.id, updatedPlan);
    }

    _logger.info(
      'initializeByHourData SUCCESS',
      context: 'ActivityDetailController',
      data: {
        'category': category,
        'durationMinutes': durationMinutes,
        'assignmentCount': byHourData.assignments.length,
        'globalSipCount': byHourData.globalSipAssignments.length,
      },
    );
  }

  /// Move a food item to a different time slot (drag & drop).
  Future<void> moveFoodToTimeSlot(
    String foodId,
    String category,
    TimeSlot sourceTimeSlot,
    TimeSlot newTimeSlot,
  ) async {
    final currentState = state.value;
    if (currentState?.nutritionPlan == null) return;

    final currentPlan = currentState!.nutritionPlan!;

    final updatedSections = currentPlan.sections.map((section) {
      if (_categoryMatchesSection(category, section.id, section.title) &&
          section.byHourData != null) {
        var moved = false;
        final updatedAssignments = section.byHourData!.assignments.map((a) {
          if (!moved &&
              a.foodItemId == foodId &&
              a.timeSlot == sourceTimeSlot) {
            moved = true;
            return a.copyWith(timeSlot: newTimeSlot);
          }
          return a;
        }).toList();

        return section.copyWith(
          byHourData: section.byHourData!.copyWith(
            assignments: updatedAssignments,
          ),
        );
      }
      return section;
    }).toList();

    final updatedPlan = currentPlan.copyWith(
      sections: updatedSections,
      updatedAt: DateTime.now(),
    );

    state = AsyncData(currentState.copyWith(nutritionPlan: updatedPlan));

    // Auto-save
    final activity = currentState.activity;
    if (activity != null) {
      await _saveNutritionPlanToActivity(activity.id, updatedPlan);
    }
  }

  /// Place a food from the unassigned tray into a specific time slot.
  Future<void> placeFoodInSlot(
    String foodId,
    String category,
    TimeSlot targetSlot,
    double quantity, {
    TimingCategory? timingCategory,
    bool isSipThroughout = false,
  }) async {
    final currentState = state.value;
    if (currentState?.nutritionPlan == null) return;

    final currentPlan = currentState!.nutritionPlan!;

    final updatedSections = currentPlan.sections.map((section) {
      if (_categoryMatchesSection(category, section.id, section.title) &&
          section.byHourData != null) {
        final updatedByHour = ByHourSyncService.placeFoodInSlot(
          existing: section.byHourData!,
          foodId: foodId,
          targetSlot: targetSlot,
          quantity: quantity,
          timingCategory: timingCategory,
          isSipThroughout: isSipThroughout,
        );
        return section.copyWith(byHourData: updatedByHour);
      }
      return section;
    }).toList();

    final updatedPlan = currentPlan.copyWith(
      sections: updatedSections,
      updatedAt: DateTime.now(),
    );

    state = AsyncData(currentState.copyWith(nutritionPlan: updatedPlan));

    final activity = currentState.activity;
    if (activity != null) {
      await _saveNutritionPlanToActivity(activity.id, updatedPlan);
    }
  }

  /// Remove a food from a time slot, returning it to the unassigned tray.
  ///
  /// If the food has zero remaining tray quantity AND zero assignments after
  /// removal, it is auto-removed from the Summary food list.
  Future<void> removeFoodFromSlot(
    String foodId,
    String category,
    TimeSlot sourceSlot,
  ) async {
    final currentState = state.value;
    if (currentState?.nutritionPlan == null) return;

    final currentPlan = currentState!.nutritionPlan!;

    final updatedSections = currentPlan.sections.map((section) {
      if (_categoryMatchesSection(category, section.id, section.title) &&
          section.byHourData != null) {
        final updatedByHour = ByHourSyncService.removeFoodFromSlot(
          existing: section.byHourData!,
          foodId: foodId,
          sourceSlot: sourceSlot,
        );

        // Check if food should be auto-removed from Summary
        if (ByHourSyncService.shouldAutoRemoveFromSummary(
          summaryFoods: section.foodItems,
          byHourData: updatedByHour,
          foodId: foodId,
        )) {
          return section.copyWith(
            foodItems: section.foodItems.where((f) => f.id != foodId).toList(),
            byHourData: updatedByHour,
          );
        }

        return section.copyWith(byHourData: updatedByHour);
      }
      return section;
    }).toList();

    final updatedPlan = currentPlan.copyWith(
      sections: updatedSections,
      updatedAt: DateTime.now(),
    );

    state = AsyncData(currentState.copyWith(nutritionPlan: updatedPlan));

    final activity = currentState.activity;
    if (activity != null) {
      await _saveNutritionPlanToActivity(activity.id, updatedPlan);
    }
  }

  /// Move a portion of a sip-throughout food from global sip into a specific hour slot.
  ///
  /// Atomically decreases the global sip qty and places it in [targetSlot].
  Future<void> moveSipFoodToSlot(
    String foodId,
    String category,
    TimeSlot targetSlot,
    double quantity, {
    TimingCategory? timingCategory,
  }) async {
    final currentState = state.value;
    if (currentState?.nutritionPlan == null) return;

    final currentPlan = currentState!.nutritionPlan!;

    final updatedSections = currentPlan.sections.map((section) {
      if (_categoryMatchesSection(category, section.id, section.title) &&
          section.byHourData != null) {
        final updatedByHour = ByHourSyncService.moveSipFoodToSlot(
          existing: section.byHourData!,
          foodId: foodId,
          targetSlot: targetSlot,
          quantity: quantity,
          timingCategory: timingCategory,
        );
        return section.copyWith(byHourData: updatedByHour);
      }
      return section;
    }).toList();

    final updatedPlan = currentPlan.copyWith(
      sections: updatedSections,
      updatedAt: DateTime.now(),
    );

    state = AsyncData(currentState.copyWith(nutritionPlan: updatedPlan));

    final activity = currentState.activity;
    if (activity != null) {
      await _saveNutritionPlanToActivity(activity.id, updatedPlan);
    }
  }

  /// Adjust a food's slot quantity by [delta], drawing from or returning to unassigned.
  ///
  /// If all unassigned qty is depleted, the summary total is increased.
  /// If slot qty reaches 0, the assignment is removed entirely.
  Future<void> adjustSlotQuantity(
    String foodId,
    String category,
    TimeSlot slot,
    double delta,
  ) async {
    final currentState = state.value;
    if (currentState?.nutritionPlan == null) return;

    final currentPlan = currentState!.nutritionPlan!;

    final updatedSections = currentPlan.sections.map((section) {
      if (_categoryMatchesSection(category, section.id, section.title) &&
          section.byHourData != null) {
        final food = section.foodItems.firstWhere(
          (f) => f.id == foodId,
          orElse: () => section.foodItems.first,
        );
        final summaryQty = ByHourSyncService.parseQuantity(food);
        final isSipType =
            food.isDrink ||
            food.timingCategory == TimingCategory.sipThroughout ||
            food.timingCategory == TimingCategory.fuelDrink ||
            food.timingCategory == TimingCategory.electrolyte;

        var adjustedByHour = section.byHourData!;
        var effectiveDelta = delta;

        // For sip-type foods placed in hour slots, +/- should rebalance against
        // the global SIP THROUGHOUT bucket first (hourIndex == -1), not the tray.
        if (isSipType && slot.hourIndex != -1) {
          if (delta > 0) {
            final sipQty = adjustedByHour.assignments
                .where(
                  (a) => a.foodItemId == foodId && a.timeSlot.hourIndex == -1,
                )
                .fold<double>(0, (sum, a) => sum + (a.adjustedQuantity ?? 0));
            final transferQty = delta <= sipQty ? delta : sipQty;
            if (transferQty > 0.01) {
              adjustedByHour = ByHourSyncService.moveSipFoodToSlot(
                existing: adjustedByHour,
                foodId: foodId,
                targetSlot: slot,
                quantity: transferQty,
                timingCategory: food.timingCategory,
              );
              effectiveDelta -= transferQty;
            }
          } else if (delta < 0) {
            adjustedByHour = ByHourSyncService.moveSlotFoodToSip(
              existing: adjustedByHour,
              foodId: foodId,
              sourceSlot: slot,
              quantity: -delta,
              timingCategory: food.timingCategory,
            );
            effectiveDelta = 0;
          }
        }

        if (effectiveDelta.abs() <= 0.01) {
          return section.copyWith(byHourData: adjustedByHour);
        }

        final result = ByHourSyncService.adjustSlotQuantity(
          existing: adjustedByHour,
          foodId: foodId,
          slot: slot,
          delta: effectiveDelta,
          summaryQty: summaryQty,
          isIndivisible: food.isIndivisible,
        );

        // Determine if summary food needs updating:
        // 1. needsSummaryIncrease: incrementing beyond available unassigned
        // 2. Sip item decrement: reduce summary to match new sip total
        double? newSummaryQty;
        if (result.needsSummaryIncrease) {
          final stepSize = food.isIndivisible ? 1.0 : 0.5;
          newSummaryQty = summaryQty + stepSize;
        } else if (slot.hourIndex == -1 && delta < 0) {
          // Sip item decrement: sync summary qty to new sip total
          final newSipQty = result.data.assignments
              .where(
                (a) => a.foodItemId == foodId && a.timeSlot.hourIndex == -1,
              )
              .fold<double>(0, (sum, a) => sum + (a.adjustedQuantity ?? 0));
          if (newSipQty < summaryQty - 0.01) {
            newSummaryQty = newSipQty;
          }
        }

        if (newSummaryQty != null) {
          final newLabel = _foodOpsService.buildQuantityLabel(
            food,
            newSummaryQty,
          );
          final scaleFactor = summaryQty > 0 ? newSummaryQty / summaryQty : 1.0;
          final ni = food.nutritionalInfo;

          final updatedFood = FoodItemData(
            id: food.id,
            name: food.name,
            quantity: newLabel,
            imageAddress: food.imageAddress,
            description: food.description,
            timing: food.timing,
            instructions: food.instructions,
            displayName: food.displayName,
            displayNamePlural: food.displayNamePlural,
            displayOverride: food.displayOverride,
            servingSize: food.servingSize,
            isDrink: food.isDrink,
            isIndivisible: food.isIndivisible,
            templateId: food.templateId,
            scaleMultiplier: food.scaleMultiplier,
            timingCategory: food.timingCategory,
            nutritionalInfo: ni != null
                ? NutritionalInfo(
                    calories: ni.calories != null
                        ? (ni.calories! * scaleFactor).round()
                        : null,
                    carbs: ni.carbs != null
                        ? (ni.carbs! * scaleFactor).round()
                        : null,
                    protein: ni.protein != null
                        ? (ni.protein! * scaleFactor).round()
                        : null,
                    fat: ni.fat != null
                        ? (ni.fat! * scaleFactor).round()
                        : null,
                    sodium: ni.sodium != null
                        ? (ni.sodium! * scaleFactor).round()
                        : null,
                    fluids: ni.fluids != null ? ni.fluids! * scaleFactor : null,
                  )
                : null,
          );

          return section.copyWith(
            foodItems: section.foodItems.map((f) {
              return f.id == foodId ? updatedFood : f;
            }).toList(),
            byHourData: result.data,
          );
        }

        return section.copyWith(byHourData: result.data);
      }
      return section;
    }).toList();

    final updatedPlan = currentPlan.copyWith(
      sections: updatedSections,
      updatedAt: DateTime.now(),
    );

    state = AsyncData(currentState.copyWith(nutritionPlan: updatedPlan));

    final activity = currentState.activity;
    if (activity != null) {
      await _saveNutritionPlanToActivity(activity.id, updatedPlan);
    }
  }

  // ============================================================================
  // BUSINESS LOGIC METHODS (moved from ActivityDetailScreen for FOA compliance)
  // ============================================================================

  /// Delete the current activity
  /// Returns true on success, false on failure
  Future<bool> deleteActivity() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user == null) return false;

      await _activitiesService.deleteActivity(
        deviceId: user.id,
        activityId: activityId,
      );

      // Invalidate the activities list so dashboards/timelines that watch it
      // (fuel timeline, daily macros, calendar) drop this activity's card
      // immediately instead of showing it until their next unrelated rebuild.
      ref.invalidate(activitiesControllerProvider);

      _trackAnalytics('activity_deleted', {
        'activity_id': activityId,
        'deleted_from': 'activity_detail_screen',
      });

      return true;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to delete activity',
        context: 'ACTIVITY_DETAIL_CONTROLLER',
        error: e,
        stackTrace: stackTrace,
        data: {'activityId': activityId},
      );
      return false;
    }
  }

  /// Track an analytics event
  void _trackAnalytics(String event, Map<String, dynamic> properties) {
    try {
      final analytics = ref.read(appExternalDepsProvider);
      analytics.analytics.track(event, properties: properties);
    } catch (e) {
      // Silently fail analytics
    }
  }

  /// Track a user-facing analytics event (callable from UI)
  void trackEvent(String event, Map<String, dynamic> properties) {
    _trackAnalytics(event, properties);
  }

  // ============================================================================
  // FUEL LOG METHODS
  // ============================================================================

  /// Enter fuel log mode.
  ///
  /// Prefers a previously-saved fuel log (`activity.fuelLogData`) so revisiting
  /// an already-logged workout restores the user's actual quantities. Only when
  /// there is no saved log do we seed a fresh one from the plan (every item's
  /// `actualQuantity = plannedQuantity`). Seeding fresh on every entry was the
  /// root cause of the "reopening resets my edits / shows an inconsistent
  /// carbs/hr" report — the saved actual quantities were discarded on re-entry.
  void enterFuelLogMode() {
    final currentState = state.value;
    if (currentState == null) return;

    final plan = currentState.nutritionPlan;
    if (plan == null) return;

    _trackAnalytics('fuel_log_started', {
      'activity_id': activityId,
      'has_existing_fuel_log':
          _parseSavedFuelLog(currentState.activity) != null,
    });

    final fuelLogData =
        _parseSavedFuelLog(currentState.activity) ??
        FuelLogData.fromNutritionPlan(plan);

    state = AsyncData(
      currentState.copyWith(isFuelLogMode: true, fuelLogData: fuelLogData),
    );
  }

  /// Exit fuel log mode: discard in-memory fuel log data.
  void exitFuelLogMode() {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(
      currentState.copyWith(isFuelLogMode: false, clearFuelLogData: true),
    );
  }

  /// Adjust a fuel log item's actual quantity by delta.
  ///
  /// Matches on foodId + sectionId + subPhaseType + isAdded. FuelLogItem has
  /// no unique id, and foodId + sectionId alone is ambiguous: the same food
  /// can sit in a sub-phase group AND in the "Added" bucket (or in two
  /// sub-phases), so the looser match updated every copy on one +/- tap.
  void updateFuelLogItemQuantity(FuelLogItem target, double delta) {
    final currentState = state.value;
    final fuelLog = currentState?.fuelLogData;
    if (fuelLog == null) return;

    final updatedItems = fuelLog.items.map((item) {
      if (item.foodId == target.foodId &&
          item.sectionId == target.sectionId &&
          item.subPhaseType == target.subPhaseType &&
          item.isAdded == target.isAdded) {
        final step = item.isIndivisible ? 1.0 : 0.5;
        // Use step-aligned delta so indivisible items move by whole units
        final alignedDelta = delta < 0 ? -step : step;
        final newQty = item.actualQuantity + alignedDelta;
        // Snap to step and floor at 0
        final snapped = (newQty / step).round() * step;
        return item.copyWith(actualQuantity: snapped < 0 ? 0.0 : snapped);
      }
      return item;
    }).toList();

    state = AsyncData(
      currentState!.copyWith(
        fuelLogData: fuelLog.copyWith(items: updatedItems),
      ),
    );
  }

  /// Add a food item to the fuel log (e.g. from "Add Food" flow).
  void addFoodToFuelLog(
    FoodItemData food,
    String sectionId, {
    String? subPhaseType,
  }) {
    final currentState = state.value;
    final fuelLog = currentState?.fuelLogData;
    if (fuelLog == null) return;

    final quantity = ByHourSyncService.parseQuantity(food);
    final newItem = FuelLogItem(
      foodId: food.id,
      sectionId: sectionId,
      subPhaseType: subPhaseType,
      plannedQuantity: 0, // Not in original plan
      actualQuantity: quantity,
      // food.nutritionalInfo was built for `quantity` units; without this
      // reference an added item's macros can never be scaled (planned is 0)
      // and it contributes nothing to carbs/hr or coach reports.
      nutritionReferenceQuantity: quantity,
      name: food.name,
      displayName: food.displayName,
      displayNamePlural: food.displayNamePlural,
      imageAddress: food.imageAddress,
      isDrink: food.isDrink,
      isIndivisible: food.isIndivisible,
      isAdded: true,
      nutritionalInfo: food.nutritionalInfo,
      servingSize: food.servingSize,
    );

    state = AsyncData(
      currentState!.copyWith(fuelLogData: fuelLog.addItem(newItem)),
    );
  }

  /// Add a raw food (from the swap/add-food flow) to the in-memory fuel log.
  ///
  /// Used when ADD FOOD is tapped while fuel logging: the fuel log screen
  /// renders from state.fuelLogData, so the write must land there — not in
  /// the nutrition plan (bug 3a3e3fdb). When [category] carries no
  /// ':subPhase' suffix the item keeps a null subPhaseType; sections with
  /// sub-phases render those in a trailing "Added" bucket. We deliberately
  /// do NOT invent a sub-phase, to avoid skewing downstream timing/carb
  /// analysis.
  void addFoodToFuelLogFromRawFood(
    dynamic food,
    String category, {
    double? customAmount,
  }) {
    final foodItemData = _createFoodItemData(food, customAmount: customAmount);
    final parts = category.split(':');
    addFoodToFuelLog(
      foodItemData,
      parts[0],
      subPhaseType: parts.length > 1 ? parts[1] : null,
    );

    _trackAnalytics('food_added_to_fuel_log', {
      'food_name': food?.name,
      'section': category,
    });
  }

  /// Update feedback fields on the in-memory fuel log.
  void updateFuelLogFeedback({
    int? overallSatisfaction,
    int? nutritionRating,
    String? notes,
  }) {
    final currentState = state.value;
    final fuelLog = currentState?.fuelLogData;
    if (fuelLog == null) return;

    state = AsyncData(
      currentState!.copyWith(
        fuelLogData: fuelLog.copyWith(
          overallSatisfaction:
              overallSatisfaction ?? fuelLog.overallSatisfaction,
          nutritionRating: nutritionRating ?? fuelLog.nutritionRating,
          notes: notes ?? fuelLog.notes,
        ),
      ),
    );
  }

  /// Save fuel log data to activity and complete it.
  Future<void> saveFuelLogAndComplete({
    required int overallSatisfaction,
    String? textNotes,
    int? nutritionRating,
  }) async {
    final currentState = state.value;
    if (currentState == null || currentState.activity == null) return;
    if (currentState.fuelLogData == null) return;

    state = AsyncData(currentState.copyWith(isCompleting: true));

    state = await AsyncValue.guard(() async {
      try {
        final user = await _authService.getCurrentUser();
        if (user == null || user.id.isEmpty) {
          throw Exception('Cannot complete activity: user not authenticated');
        }

        // Finalize the fuel log
        final finalFuelLog = currentState.fuelLogData!.copyWith(
          loggedAt: DateTime.now(),
          overallSatisfaction: overallSatisfaction,
          nutritionRating: nutritionRating,
          notes: textNotes,
        );

        // Update activity with fuel log data and completion data
        final completedActivity = currentState.activity!.copyWith(
          status: ActivityStatus.completed,
          completedAt: DateTime.now(),
          completionRating: overallSatisfaction,
          nutritionRating: nutritionRating,
          completionNotes: textNotes,
          fuelLogData: finalFuelLog.toJson(),
        );

        await _activitiesService.updateActivity(
          deviceId: user.id,
          activity: completedActivity,
        );

        // Fire-and-forget: push feedback to TrainingPeaks
        unawaited(
          _pushFeedbackToTrainingPeaks(
            user.id,
            completedActivity,
            overallSatisfaction,
            textNotes,
          ),
        );

        _trackAnalytics('fuel_log_completed', {
          'activity_id': activityId,
          'items_count': finalFuelLog.items.length,
          'added_items': finalFuelLog.items.where((i) => i.isAdded).length,
          'rating': overallSatisfaction,
          'nutrition_rating': nutritionRating,
          'has_notes': textNotes != null && textNotes.isNotEmpty,
        });

        // Reload activity to get updated data
        ref.invalidateSelf();

        // Carry the just-saved activity forward so any display that resolves
        // fuel data from `activity.fuelLogData` (e.g. the carbs/hr card after
        // the in-memory fuelLogData is cleared) shows the edited values
        // immediately, instead of briefly reverting to planned quantities
        // until invalidateSelf's reload resolves.
        return currentState.copyWith(
          activity: completedActivity,
          isCompleting: false,
          isFuelLogMode: false,
          clearFuelLogData: true,
        );
      } catch (error) {
        _logger.error(
          'Error saving fuel log and completing activity',
          error: error,
        );
        rethrow;
      }
    });
  }

  /// Save edits to an already-completed activity's fuel log.
  ///
  /// Unlike [saveFuelLogAndComplete] this does **not** re-stamp `completedAt` /
  /// `status` or re-push feedback to TrainingPeaks — it's an edit of an
  /// activity that was already completed, so the original completion time and
  /// state are preserved. Any edited feedback ([overallSatisfaction],
  /// [nutritionRating], [textNotes]) is folded into both the fuel-log snapshot
  /// and the activity's completion fields.
  Future<void> updateExistingFuelLog({
    int? overallSatisfaction,
    int? nutritionRating,
    String? textNotes,
  }) async {
    final currentState = state.value;
    if (currentState == null || currentState.activity == null) return;
    if (currentState.fuelLogData == null) return;

    state = AsyncData(currentState.copyWith(isSaving: true));

    state = await AsyncValue.guard(() async {
      try {
        final user = await _authService.getCurrentUser();
        if (user == null || user.id.isEmpty) {
          throw Exception('Cannot update fuel log: user not authenticated');
        }

        // Fold any edited feedback into the fuel-log snapshot.
        final base = currentState.fuelLogData!;
        final updatedFuelLog = base.copyWith(
          overallSatisfaction: overallSatisfaction ?? base.overallSatisfaction,
          nutritionRating: nutritionRating ?? base.nutritionRating,
          notes: textNotes ?? base.notes,
        );

        final activity = currentState.activity!;
        final updatedActivity = activity.copyWith(
          fuelLogData: updatedFuelLog.toJson(),
          completionRating: overallSatisfaction ?? activity.completionRating,
          nutritionRating: nutritionRating ?? activity.nutritionRating,
          completionNotes: textNotes ?? activity.completionNotes,
        );

        await _activitiesService.updateActivity(
          deviceId: user.id,
          activity: updatedActivity,
        );

        ref.invalidateSelf();
        return currentState.copyWith(
          activity: updatedActivity,
          isSaving: false,
          isFuelLogMode: false,
          clearFuelLogData: true,
        );
      } catch (error) {
        _logger.error('Error updating fuel log', error: error);
        rethrow;
      }
    });
  }

  /// Toggle between planned and actual view modes for completed activities.
  void toggleFuelLogViewMode() {
    final currentState = state.value;
    if (currentState == null) return;

    final newMode = currentState.fuelLogViewMode == FuelLogViewMode.planned
        ? FuelLogViewMode.actual
        : FuelLogViewMode.planned;

    // When switching to actual, load existing fuel log if not already loaded
    if (newMode == FuelLogViewMode.actual && currentState.fuelLogData == null) {
      loadExistingFuelLog();
    }

    final latestState = state.value;
    if (latestState != null) {
      state = AsyncData(latestState.copyWith(fuelLogViewMode: newMode));
    }
  }

  /// Parse activity.fuelLogData into state for editing.
  void loadExistingFuelLog() {
    final currentState = state.value;
    if (currentState == null) return;

    final fuelLog = _parseSavedFuelLog(currentState.activity);
    if (fuelLog == null) return;
    state = AsyncData(currentState.copyWith(fuelLogData: fuelLog));
  }

  /// Deserialize an activity's saved `fuelLogData` JSON into a [FuelLogData],
  /// or return null when there is none / it can't be parsed. Shared by
  /// [enterFuelLogMode] and [loadExistingFuelLog] so both honour saved edits.
  FuelLogData? _parseSavedFuelLog(Activity? activity) {
    final rawData = activity?.fuelLogData;
    if (rawData == null) return null;
    try {
      return FuelLogData.fromJson(rawData);
    } catch (e) {
      _logger.warning(
        'Failed to parse saved fuel log; falling back to plan defaults',
        context: 'ACTIVITY_DETAIL_CONTROLLER',
        error: e,
      );
      return null;
    }
  }

  // ============================================================================
  // SWIPE HINT STATE MANAGEMENT
  // ============================================================================

  static const String swipeHintShownKey = 'activity_detail_swipe_hint_shown';

  /// Check if the swipe hint has been shown before
  bool checkSwipeHintShown(SharedPreferences prefs) {
    try {
      return prefs.getBool(swipeHintShownKey) ?? false;
    } catch (e) {
      return true; // Assume shown on error
    }
  }

  /// Mark the swipe hint as shown
  Future<void> markSwipeHintShown(SharedPreferences prefs) async {
    try {
      await prefs.setBool(swipeHintShownKey, true);
    } catch (e) {
      // Silently fail
    }
  }

  /// Fire-and-forget push of completion feedback to TrainingPeaks.
  /// Catches all errors — feedback push must never block completion.
  Future<void> _pushFeedbackToTrainingPeaks(
    String userId,
    Activity activity,
    int rating,
    String? notes,
  ) async {
    try {
      final service = await ref.read(tpWritebackServiceProvider.future);
      await service.pushCompletionFeedback(
        userId: userId,
        activity: activity,
        rating: rating,
        notes: notes,
      );
    } catch (e) {
      DebugLogger.error('TP feedback push failed (non-blocking): $e');
    }
  }

  /// Fire-and-forget push of nutrition plan summary to TrainingPeaks.
  /// Catches all errors — write-back must never block plan save.
  Future<void> _pushToTrainingPeaks(
    String userId,
    Activity activity,
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
