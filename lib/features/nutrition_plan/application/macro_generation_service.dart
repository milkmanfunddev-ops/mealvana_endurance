import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/macro_targets.dart';
import '../domain/nutrition_target_overrides.dart';
import '../domain/intensity_distribution.dart';
import '../data/macro_repository.dart';
import '../data/offline_macro_calculator.dart';
import '../../auth/application/auth_service.dart';
import '../../auth/domain/user_preferences.dart';
import '../../../shared/domain/activity_type.dart';
import '../../../shared/services/analytics/analytics_tracker.dart';
import '../../../shared/services/analytics/analytics_events.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';

/// Service responsible for generating macro targets by calling edge functions.
///
/// This service encapsulates all the business logic for:
/// - Calling Supabase edge functions
/// - Parsing responses
/// - Converting data types
/// - Caching macro targets
/// - Analytics tracking

class MacroGenerationService {
  MacroGenerationService({
    required this.supabaseClient,
    required this.macroRepository,
    required this.authService,
    required this.analytics,
  });

  final SupabaseClient supabaseClient;
  final MacroRepository macroRepository;
  final AuthService authService;
  final AnalyticsTracker analytics;

  /// Generate running macro targets
  Future<MacroTargets> generateRunningMacros({
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
    NutritionTargetOverrides? overrides,
    // Optional treadmill/indoor-run flag. Default 'outdoor' preserves existing
    // behavior for callers that don't yet surface the toggle.
    String indoorOutdoor = 'outdoor',
  }) async {
    final requestData = await _buildRunningRequestData(
      distanceMiles: distanceMiles,
      paceMinutesPerMile: paceMinutesPerMile,
      timeBeforeRunMinutes: timeBeforeRunMinutes,
      gutTraining: gutTraining,
      sweatRateCat: sweatRateCat,
      temperatureC: temperatureC,
      humidityPct: humidityPct,
      isFasted: isFasted,
      intensity: intensity,
      indoorOutdoor: indoorOutdoor,
    );
    // device_id is read by the edge function to look up active formula pins
    // (Formula Kit PR 2 substep 5b-followup, 2026-05-22).
    requestData['device_id'] = deviceId;

    final macroTargets = await _callGenerateMacrosEdgeFunction(
      requestData: requestData,
      expectedActivityType: ActivityType.running,
      overrides: overrides,
    );

    await _cacheMacroTargets(macroTargets, activityId: activityId);

    await analytics.trackPlanGenerated(
      deviceId: deviceId,
      activityId: activityId,
      activityType: 'running',
      distanceMiles: distanceMiles,
      paceMinutesPerMile: paceMinutesPerMile,
      totalCalories: macroTargets.metrics.caloriesNetKcal.round(),
      totalCarbs: _calculateTotalCarbs(macroTargets),
      beforeRunItems: 1,
      duringRunItems: 1,
      afterRunItems: 1,
      isFirstPlan: true,
    );

    return macroTargets;
  }

  /// Generate cycling macro targets
  Future<MacroTargets> generateCyclingMacros({
    String? activityId,
    required String deviceId,
    required double distanceMiles,
    required double speedMph,
    required String terrain,
    required String indoorOutdoor,
    required int timeBeforeMinutes,
    int? elevationGainFt,
    String? intensityTarget,
    String? sessionGoal,
    double? temperatureC,
    double? humidityPct,
    bool isFasted = false,
    IntensityDistribution? intensity,
    NutritionTargetOverrides? overrides,
  }) async {
    DebugLogger.info(
      '🚴 MACRO SERVICE: generateCyclingMacros called - distance: ${distanceMiles}mi, speed: ${speedMph}mph',
    );

    DebugLogger.info('🚴 MACRO SERVICE: Building request data...');
    final requestData = await _buildCyclingRequestData(
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
    // device_id is read by the edge function to look up active formula pins
    // (Formula Kit PR 2 substep 5b-followup, 2026-05-22).
    requestData['device_id'] = deviceId;
    DebugLogger.info(
      '🚴 MACRO SERVICE: Request data built, calling edge function...',
    );

    final macroTargets = await _callGenerateMacrosEdgeFunction(
      requestData: requestData,
      expectedActivityType: ActivityType.cycling,
      overrides: overrides,
    );
    DebugLogger.info(
      '🚴 MACRO SERVICE: Edge function returned, caching targets...',
    );

    await _cacheMacroTargets(macroTargets, activityId: activityId);
    DebugLogger.info('🚴 MACRO SERVICE: Targets cached, tracking analytics...');

    await analytics.trackPlanGenerated(
      deviceId: deviceId,
      activityId: activityId,
      activityType: 'cycling',
      distanceMiles: distanceMiles,
      paceMinutesPerMile: speedMph,
      totalCalories: macroTargets.metrics.caloriesNetKcal.round(),
      totalCarbs: _calculateTotalCarbs(macroTargets),
      beforeRunItems: 1,
      duringRunItems: 1,
      afterRunItems: 1,
      isFirstPlan: true,
    );
    DebugLogger.info(
      '🚴 MACRO SERVICE: Analytics tracked, returning macro targets',
    );

    return macroTargets;
  }

  /// Generate swimming macro targets
  Future<MacroTargets> generateSwimmingMacros({
    String? activityId,
    required String deviceId,
    required int distanceMeters,
    required int paceSecondsper100m,
    required String poolOrOpenWater,
    required int timeBeforeMinutes,
    String? intensityTarget,
    String? sessionGoal,
    double? waterTempC,
    IntensityDistribution? intensity,
    NutritionTargetOverrides? overrides,
  }) async {
    DebugLogger.info(
      '🏊 MACRO SERVICE: generateSwimmingMacros called - distance: ${distanceMeters}m, pace: ${paceSecondsper100m}s/100m',
    );

    DebugLogger.info('🏊 MACRO SERVICE: Building request data...');
    final requestData = await _buildSwimmingRequestData(
      distanceMeters: distanceMeters,
      paceSecondsper100m: paceSecondsper100m,
      poolOrOpenWater: poolOrOpenWater,
      timeBeforeMinutes: timeBeforeMinutes,
      intensityTarget: intensityTarget,
      sessionGoal: sessionGoal,
      waterTempC: waterTempC,
      intensity: intensity,
    );
    // device_id is read by the edge function to look up active formula pins
    // (Formula Kit PR 2 substep 5b-followup, 2026-05-22).
    requestData['device_id'] = deviceId;
    DebugLogger.info(
      '🏊 MACRO SERVICE: Request data built, calling edge function...',
    );

    final macroTargets = await _callGenerateMacrosEdgeFunction(
      requestData: requestData,
      expectedActivityType: ActivityType.swimming,
      overrides: overrides,
    );
    DebugLogger.info(
      '🏊 MACRO SERVICE: Edge function returned, caching targets...',
    );

    await _cacheMacroTargets(macroTargets, activityId: activityId);
    DebugLogger.info('🏊 MACRO SERVICE: Targets cached, tracking analytics...');

    await analytics.trackPlanGenerated(
      deviceId: deviceId,
      activityId: activityId,
      activityType: 'swimming',
      distanceMiles: distanceMeters / 1609.34,
      paceMinutesPerMile: paceSecondsper100m / 60,
      totalCalories: macroTargets.metrics.caloriesNetKcal.round(),
      totalCarbs: _calculateTotalCarbs(macroTargets),
      beforeRunItems: 1,
      duringRunItems: 1,
      afterRunItems: 1,
      isFirstPlan: true,
    );
    DebugLogger.info(
      '🏊 MACRO SERVICE: Analytics tracked, returning macro targets',
    );

    return macroTargets;
  }

  // ========================================
  // Private Helper Methods
  // ========================================

  Future<Map<String, dynamic>> _buildRunningRequestData({
    required double distanceMiles,
    required double paceMinutesPerMile,
    required int timeBeforeRunMinutes,
    required GutTraining gutTraining,
    SweatRateCat? sweatRateCat,
    double? temperatureC,
    double? humidityPct,
    bool isFasted = false,
    IntensityDistribution? intensity,
    String indoorOutdoor = 'outdoor',
  }) async {
    final userProfile = await authService.getCurrentUser();
    final userMetrics = _getUserMetrics(userProfile);
    final preferencePayload = await _buildPreWorkoutPreferencePayload(
      userProfile,
    );

    // V3: Normalize intensity distribution to fractions (0-1)
    final zoneLow = (intensity?.conversationalPct ?? 70) / 100.0;
    final zoneMid = (intensity?.tempoPct ?? 20) / 100.0;
    final zoneHigh = (intensity?.allOutPct ?? 10) / 100.0;

    // Sweat profile: read from UserProfile; map SweatSodiumCat → edge fn enum.
    // 'medium' is accepted as an alias on the edge function side but we always
    // send the canonical value ('low'|'average'|'high').
    final sweatSodiumValue =
        (userProfile?.sweatSodium ?? SweatSodiumCat.average).value;

    // Known sweat-test overrides (null = use algorithmic estimate)
    final knownSweatRateMlHr = userProfile?.knownSweatRateMlPerHour;
    final knownSodiumConcMgL = userProfile?.knownSodiumConcentrationMgPerLiter;

    // Treadmill runs: callers pass indoorOutdoor='indoor'. The edge function
    // applies the 1.30× sweat rate multiplier per spec when is_indoor=true.
    final isIndoor = indoorOutdoor.toLowerCase() == 'indoor';

    return {
      'age': userMetrics['age'],
      'gender': userMetrics['gender'],
      'weight': userMetrics['weightKg'],
      'weight_unit': 'kg',
      'height': userMetrics['heightCm'],
      'height_unit': 'cm',
      'run_pace': paceMinutesPerMile,
      'run_distance': distanceMiles,
      'run_pace_unit': 'min_per_mile',
      'run_distance_unit': 'mi',
      // V3 params
      'hours_before': timeBeforeRunMinutes / 60.0,
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
      // Sweat profile (Phase 6: read from UserProfile instead of hardcoding)
      'sweat_sodium': sweatSodiumValue,
      'sweat_rate_category':
          sweatRateCat?.name ?? userProfile?.sweatRate.name ?? 'medium',
      'is_indoor': isIndoor,
      if (knownSweatRateMlHr != null)
        'known_sweat_rate_ml_hr': knownSweatRateMlHr,
      if (knownSodiumConcMgL != null)
        'known_sodium_concentration_mg_l': knownSodiumConcMgL,
      'temp_c': temperatureC,
      'humidity_pct': humidityPct,
      ...preferencePayload,
    };
  }

  Future<Map<String, dynamic>> _buildCyclingRequestData({
    required double distanceMiles,
    required double speedMph,
    required String terrain,
    required String indoorOutdoor,
    required int timeBeforeMinutes,
    int? elevationGainFt,
    String? intensityTarget,
    String? sessionGoal,
    double? temperatureC,
    double? humidityPct,
    bool isFasted = false,
    IntensityDistribution? intensity,
  }) async {
    final userProfile = await authService.getCurrentUser();
    final userMetrics = _getUserMetrics(userProfile);
    final preferencePayload = await _buildPreWorkoutPreferencePayload(
      userProfile,
    );

    // V3: Normalize intensity distribution to fractions (0-1)
    final zoneLow = (intensity?.conversationalPct ?? 70) / 100.0;
    final zoneMid = (intensity?.tempoPct ?? 20) / 100.0;
    final zoneHigh = (intensity?.allOutPct ?? 10) / 100.0;

    // Derive is_indoor from the indoorOutdoor form field.
    final isIndoor = indoorOutdoor.toLowerCase() == 'indoor';

    // Sweat profile: read from UserProfile.
    final sweatSodiumValue =
        (userProfile?.sweatSodium ?? SweatSodiumCat.average).value;
    final knownSweatRateMlHr = userProfile?.knownSweatRateMlPerHour;
    final knownSodiumConcMgL = userProfile?.knownSodiumConcentrationMgPerLiter;

    return {
      'activity_type': 'cycling',
      'age': userMetrics['age'],
      'gender': userMetrics['gender'],
      'weight': userMetrics['weightKg'],
      'weight_unit': 'kg',
      'height': userMetrics['heightCm'],
      'height_unit': 'cm',
      'distance_miles': distanceMiles,
      'speed_mph': speedMph,
      'terrain': terrain,
      'indoor_outdoor': indoorOutdoor,
      // V3 params
      'hours_before': timeBeforeMinutes / 60.0,
      'is_fasted': isFasted,
      'intensity_distribution': {
        'zone_low': zoneLow,
        'zone_mid': zoneMid,
        'zone_high': zoneHigh,
      },
      // Legacy param
      'time_before_min': timeBeforeMinutes,
      'gut_training': userProfile?.gutTraining.name ?? 'moderate',
      // Sweat profile (Phase 6: read from UserProfile instead of hardcoding)
      'sweat_sodium': sweatSodiumValue,
      'sweat_rate_category': userProfile?.sweatRate.name ?? 'medium',
      'is_indoor': isIndoor,
      if (knownSweatRateMlHr != null)
        'known_sweat_rate_ml_hr': knownSweatRateMlHr,
      if (knownSodiumConcMgL != null)
        'known_sodium_concentration_mg_l': knownSodiumConcMgL,
      if (elevationGainFt != null) 'elevation_gain_ft': elevationGainFt,
      if (intensityTarget != null) 'intensity_target': intensityTarget,
      if (sessionGoal != null) 'session_goal': sessionGoal,
      if (temperatureC != null) 'temp_c': temperatureC,
      if (humidityPct != null) 'humidity_pct': humidityPct,
      ...preferencePayload,
    };
  }

  Future<Map<String, dynamic>> _buildSwimmingRequestData({
    required int distanceMeters,
    required int paceSecondsper100m,
    required String poolOrOpenWater,
    required int timeBeforeMinutes,
    String? intensityTarget,
    String? sessionGoal,
    double? waterTempC,
    IntensityDistribution? intensity,
  }) async {
    final userProfile = await authService.getCurrentUser();
    final userMetrics = _getUserMetrics(userProfile);
    final preferencePayload = await _buildPreWorkoutPreferencePayload(
      userProfile,
    );

    // V3: Normalize intensity distribution to fractions (0-1)
    final zoneLow = (intensity?.conversationalPct ?? 70) / 100.0;
    final zoneMid = (intensity?.tempoPct ?? 20) / 100.0;
    final zoneHigh = (intensity?.allOutPct ?? 10) / 100.0;

    final sweatSodiumValue =
        (userProfile?.sweatSodium ?? SweatSodiumCat.average).value;

    // Open-water swims expose users to ambient air-temperature/humidity loads
    // for warm-ups, transitions, and post-swim. Treat pool swims as indoor for
    // sweat-rate purposes.
    final isIndoor = poolOrOpenWater == 'pool';

    final knownSweatRateMlHr = userProfile?.knownSweatRateMlPerHour;
    final knownSodiumConcMgL = userProfile?.knownSodiumConcentrationMgPerLiter;

    return {
      'activity_type': 'swimming',
      'age': userMetrics['age'],
      'gender': userMetrics['gender'],
      'weight': userMetrics['weightKg'],
      'weight_unit': 'kg',
      'height': userMetrics['heightCm'],
      'height_unit': 'cm',
      'distance_meters': distanceMeters,
      'pace_per_100m_seconds': paceSecondsper100m,
      'pool_or_open_water': poolOrOpenWater,
      // V3 params
      'hours_before': timeBeforeMinutes / 60.0,
      'is_fasted': false, // Swimming doesn't support fasted
      'intensity_distribution': {
        'zone_low': zoneLow,
        'zone_mid': zoneMid,
        'zone_high': zoneHigh,
      },
      'gut_training': userProfile?.gutTraining.name ?? 'moderate',
      'sweat_sodium': sweatSodiumValue,
      'sweat_rate_category': userProfile?.sweatRate.name ?? 'medium',
      'is_indoor': isIndoor,
      if (knownSweatRateMlHr != null)
        'known_sweat_rate_ml_hr': knownSweatRateMlHr,
      if (knownSodiumConcMgL != null)
        'known_sodium_concentration_mg_l': knownSodiumConcMgL,
      // Legacy param
      'time_before_min': timeBeforeMinutes,
      if (intensityTarget != null) 'intensity_target': intensityTarget,
      if (sessionGoal != null) 'session_goal': sessionGoal,
      if (waterTempC != null) 'water_temp_c': waterTempC,
      ...preferencePayload,
    };
  }

  Future<Map<String, dynamic>> _buildPreWorkoutPreferencePayload(
    UserProfile? userProfile,
  ) async {
    if (userProfile == null) return {};

    final payload = <String, dynamic>{};
    final diet = userProfile.dietaryPreference?.dbValue;
    if (diet != null && diet.isNotEmpty && diet != 'none') {
      payload['diet'] = diet;
    }

    final allergies = userProfile.allergies
        .map((a) => a.dbValue)
        .where((a) => a.isNotEmpty && a != 'none')
        .toList();
    if (allergies.isNotEmpty) {
      payload['allergies'] = allergies;
    }

    final likedFoods = await authService.getLikedFoods(userProfile.id);
    if (likedFoods.isNotEmpty) {
      payload['liked_foods'] = likedFoods;
    }

    final dislikedFoods = await authService.getDislikedFoods(userProfile.id);
    if (dislikedFoods.isNotEmpty) {
      payload['disliked_foods'] = dislikedFoods;
    }

    final willingToTryFoods = await authService.getWillingToTryFoods(
      userProfile.id,
    );
    if (willingToTryFoods.isNotEmpty) {
      payload['willing_to_try_foods'] = willingToTryFoods;
    }

    return payload;
  }

  Map<String, dynamic> _getUserMetrics(UserProfile? userProfile) {
    final age = userProfile?.age ?? 30;
    final gender = userProfile?.gender.name ?? 'other';
    final weightKg = userProfile != null
        ? userProfile.weightPounds * 0.453592
        : 70.0;
    final heightCm = userProfile != null
        ? userProfile.totalHeightInches * 2.54
        : 170.0;

    return {
      'age': age,
      'gender': gender,
      'weightKg': weightKg,
      'heightCm': heightCm,
    };
  }

  Future<MacroTargets> _callGenerateMacrosEdgeFunction({
    required Map<String, dynamic> requestData,
    required ActivityType expectedActivityType,
    NutritionTargetOverrides? overrides,
  }) async {
    // Include overrides in request payload if provided
    if (overrides != null && overrides.hasAnyOverride) {
      final clamped = NutritionTargetGuardrails.clampAll(overrides);
      requestData['overrides'] = clamped.toEdgeFunctionPayload(
        sport: expectedActivityType,
      );
    }

    // Opt in to the ephemeral default-formula safety net for the before phase
    // (formula-first flip). This client keeps ephemeral pin decisions
    // invisible in the pin banner + pin analytics, so it's safe to receive
    // them; old clients omit this flag and get byte-identical telemetry.
    requestData['emit_ephemeral_default_formula'] = true;

    DebugLogger.info(
      '🌐 EDGE FUNCTION: Calling generate-macros-v4 for ${expectedActivityType.name}...',
    );
    DebugLogger.info(
      '📤 EDGE FUNCTION: Request payload: ${requestData.toString().substring(0, 200)}...',
    );

    Map<String, dynamic> macrosData;
    ActivityType activityType = expectedActivityType;
    String calculationRule;

    try {
      final response = await supabaseClient.functions.invoke(
        'generate-macros-v4',
        body: requestData,
      );

      DebugLogger.info('📥 EDGE FUNCTION: Response status: ${response.status}');

      if (response.status >= 400) {
        final data = response.data as Map<String, dynamic>?;
        final errorMessage =
            data?['message'] ?? 'Failed to generate macro targets';
        DebugLogger.error(
          '❌ EDGE FUNCTION: HTTP error ${response.status}: $errorMessage',
        );
        throw Exception(errorMessage);
      }

      final data = response.data as Map<String, dynamic>;
      DebugLogger.info(
        '📊 EDGE FUNCTION: Response data keys: ${data.keys.toList()}',
      );

      if (data['success'] != true) {
        final errorMessage =
            data['message'] ?? 'Failed to generate macro targets';
        DebugLogger.error('❌ EDGE FUNCTION: Success=false: $errorMessage');
        throw Exception(errorMessage);
      }

      macrosData = data['macros'] as Map<String, dynamic>;
      final activityTypeString =
          data['activity_type'] as String? ?? expectedActivityType.name;
      DebugLogger.info(
        '✅ EDGE FUNCTION: Got macros data with ${macrosData.keys.length} keys',
      );

      try {
        activityType = ActivityType.values.byName(activityTypeString);
      } catch (e) {
        DebugLogger.warning(
          '⚠️ EDGE FUNCTION: Could not parse activity type "$activityTypeString", using $expectedActivityType',
        );
      }

      calculationRule =
          macrosData['pre_run_carbs_rule'] ?? 'Generated from edge function';
    } on SocketException catch (e) {
      DebugLogger.warning(
        '📵 EDGE FUNCTION: Network unavailable (SocketException: $e) — using offline fallback',
      );
      macrosData = _computeOfflineMacros(requestData, expectedActivityType);
      calculationRule = 'offline_fallback';
    } on TimeoutException catch (e) {
      DebugLogger.warning(
        '⏱️ EDGE FUNCTION: Timeout ($e) — using offline fallback',
      );
      macrosData = _computeOfflineMacros(requestData, expectedActivityType);
      calculationRule = 'offline_fallback';
    } catch (e) {
      // Re-check: if the error message suggests a host-lookup / network failure,
      // fall back offline. Otherwise rethrow (HTTP 4xx / logic errors must propagate).
      final msg = e.toString().toLowerCase();
      if (msg.contains('failed host lookup') ||
          msg.contains('network is unreachable') ||
          msg.contains('connection refused') ||
          msg.contains('no address associated') ||
          msg.contains('clientexception')) {
        DebugLogger.warning(
          '📵 EDGE FUNCTION: Network failure ($e) — using offline fallback',
        );
        macrosData = _computeOfflineMacros(requestData, expectedActivityType);
        calculationRule = 'offline_fallback';
      } else {
        rethrow;
      }
    }

    final macroTargets = _parseMacroTargets(macrosData, activityType);
    DebugLogger.info(
      '✅ EDGE FUNCTION: Successfully parsed macro targets - preRun carbs: ${macroTargets.preRun.carbsG}g, total burn: ${macroTargets.metrics.caloriesNetKcal}kcal, rule: $calculationRule',
    );

    if (calculationRule == 'offline_fallback') {
      return MacroTargets(
        id: macroTargets.id,
        activityType: macroTargets.activityType,
        preRun: macroTargets.preRun,
        duringRun: macroTargets.duringRun,
        postRun: macroTargets.postRun,
        metrics: macroTargets.metrics,
        calculationRule: 'offline_fallback',
        timestamp: macroTargets.timestamp,
        isUserModified: macroTargets.isUserModified,
        modifiedFields: macroTargets.modifiedFields,
        preRunSelections: null,
        brickSegments: macroTargets.brickSegments,
        brickPhaseTargets: macroTargets.brickPhaseTargets,
      );
    }

    return macroTargets;
  }

  /// Compute macro targets offline from the already-assembled [requestData].
  ///
  /// Dispatches to the correct [OfflineMacroCalculator] entry point based on
  /// [activityType] and returns the raw macros map (same shape as the edge
  /// function's `macros` object) so [_parseMacroTargets] can parse it unchanged.
  Map<String, dynamic> _computeOfflineMacros(
    Map<String, dynamic> requestData,
    ActivityType activityType,
  ) {
    final weightKg = (requestData['weight'] as num?)?.toDouble() ?? 70.0;
    final hoursBefore =
        (requestData['hours_before'] as num?)?.toDouble() ?? 2.0;
    final isFasted = requestData['is_fasted'] as bool? ?? false;
    final gutTraining = requestData['gut_training'] as String? ?? 'moderate';
    final sweatRateCategory =
        requestData['sweat_rate_category'] as String? ?? 'medium';
    final sweatSodiumCat = requestData['sweat_sodium'] as String? ?? 'average';
    final tempC = (requestData['temp_c'] as num?)?.toDouble();
    final humidityPct = (requestData['humidity_pct'] as num?)?.toDouble();
    final isIndoor = requestData['is_indoor'] as bool? ?? false;
    final knownSweatRateMlHr = (requestData['known_sweat_rate_ml_hr'] as num?)
        ?.toDouble();
    final knownSodiumConcMgL =
        (requestData['known_sodium_concentration_mg_l'] as num?)?.toDouble();

    switch (activityType) {
      case ActivityType.running:
        final distanceMiles =
            (requestData['run_distance'] as num?)?.toDouble() ?? 0.0;
        final paceMinPerMile =
            (requestData['run_pace'] as num?)?.toDouble() ?? 10.0;
        return OfflineMacroCalculator.calculateRunningMacros(
          weightKg: weightKg,
          distanceMiles: distanceMiles,
          paceMinPerMile: paceMinPerMile,
          hoursBefore: hoursBefore,
          isFasted: isFasted,
          gutTraining: gutTraining,
          sweatRateCategory: sweatRateCategory,
          sweatSodiumCat: sweatSodiumCat,
          tempC: tempC,
          humidityPct: humidityPct,
          isIndoor: isIndoor,
          knownSweatRateMlPerHour: knownSweatRateMlHr,
          knownSodiumConcMgPerL: knownSodiumConcMgL,
        );

      case ActivityType.cycling:
        final distanceMiles =
            (requestData['distance_miles'] as num?)?.toDouble() ?? 0.0;
        final speedMph = (requestData['speed_mph'] as num?)?.toDouble() ?? 20.0;
        final terrain = requestData['terrain'] as String? ?? 'flat';
        return OfflineMacroCalculator.calculateCyclingMacros(
          weightKg: weightKg,
          distanceMiles: distanceMiles,
          speedMph: speedMph,
          terrain: terrain,
          hoursBefore: hoursBefore,
          isFasted: isFasted,
          gutTraining: gutTraining,
          sweatRateCategory: sweatRateCategory,
          sweatSodiumCat: sweatSodiumCat,
          tempC: tempC,
          humidityPct: humidityPct,
          isIndoor: isIndoor,
          knownSweatRateMlPerHour: knownSweatRateMlHr,
          knownSodiumConcMgPerL: knownSodiumConcMgL,
        );

      case ActivityType.swimming:
        final distanceMeters =
            (requestData['distance_meters'] as num?)?.toInt() ?? 0;
        final paceSecondsper100m =
            (requestData['pace_per_100m_seconds'] as num?)?.toInt() ?? 120;
        final poolOrOpenWater =
            requestData['pool_or_open_water'] as String? ?? 'pool';
        final waterTempC =
            (requestData['water_temp_c'] as num?)?.toDouble() ?? 26.0;
        return OfflineMacroCalculator.calculateSwimmingMacros(
          weightKg: weightKg,
          distanceMeters: distanceMeters,
          paceSecondsper100m: paceSecondsper100m,
          poolOrOpenWater: poolOrOpenWater,
          hoursBefore: hoursBefore,
          sweatRateCategory: sweatRateCategory,
          sweatSodiumCat: sweatSodiumCat,
          waterTempC: waterTempC,
          knownSweatRateMlPerHour: knownSweatRateMlHr,
          knownSodiumConcMgPerL: knownSodiumConcMgL,
        );

      default:
        // Brick/unknown — brick workouts have their own edge function path.
        return OfflineMacroCalculator.calculateRunningMacros(
          weightKg: weightKg,
          distanceMiles: 0,
          paceMinPerMile: 10,
          hoursBefore: hoursBefore,
          isFasted: isFasted,
          gutTraining: gutTraining,
        );
    }
  }

  MacroTargets _parseMacroTargets(
    Map<String, dynamic> macrosData,
    ActivityType activityType,
  ) {
    return MacroTargets(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      activityType: activityType,
      preRun: PreRunMacros(
        carbsG: _toDouble(macrosData['pre_run_carbs_g'], 'pre_run_carbs_g'),
        proteinG: _toDouble(
          macrosData['pre_run_protein_g'],
          'pre_run_protein_g',
        ),
        fatCapG: _toDouble(macrosData['pre_run_fat_g'], 'pre_run_fat_g'),
        fluidsMl: _toDouble(macrosData['pre_run_water_ml'], 'pre_run_water_ml'),
        sodiumMg: _toDouble(
          macrosData['pre_run_sodium_mg'],
          'pre_run_sodium_mg',
        ),
        carbsLowG: _toDoubleOrNull(macrosData['pre_run_carbs_low_g']),
        carbsHighG: _toDoubleOrNull(macrosData['pre_run_carbs_high_g']),
        proteinLowG: _toDoubleOrNull(macrosData['pre_run_protein_low_g']),
        proteinHighG: _toDoubleOrNull(macrosData['pre_run_protein_high_g']),
        sodiumLowMg: _toDoubleOrNull(macrosData['pre_run_sodium_low_mg']),
        sodiumHighMg: _toDoubleOrNull(macrosData['pre_run_sodium_high_mg']),
        fluidsLowMl: _toDoubleOrNull(macrosData['pre_run_water_low_ml']),
        fluidsHighMl: _toDoubleOrNull(macrosData['pre_run_water_high_ml']),
        hydrationTier: (macrosData['pre_run_hydration_tier'] as num?)?.toInt(),
      ),
      preRunSelections: _toMapListOrNull(macrosData['pre_run_selections']),
      duringRun: () {
        final durationH = _toDouble(macrosData['duration_h'], 'duration_h');
        final bandLow = _toDoubleOrNull(macrosData['during_band_low_g_per_h']);
        final bandHigh = _toDoubleOrNull(
          macrosData['during_band_high_g_per_h'],
        );
        return DuringRunMacros(
          carbRateGPerH: _toDouble(
            macrosData['during_rate_g_per_h'],
            'during_rate_g_per_h',
          ),
          carbTotalG: _toDouble(macrosData['during_total_g'], 'during_total_g'),
          fluidRateMlPerH: _toDouble(
            macrosData['during_water_rate_ml_per_h'],
            'during_water_rate_ml_per_h',
          ),
          fluidTotalMl: _toDouble(
            macrosData['during_water_total_ml'],
            'during_water_total_ml',
          ),
          sodiumRateMgPerH: _toDouble(
            macrosData['during_sodium_rate_mg_per_h'],
            'during_sodium_rate_mg_per_h',
          ),
          sodiumTotalMg: _toDouble(
            macrosData['during_sodium_total_mg'],
            'during_sodium_total_mg',
          ),
          massNormRateGPerH: _toDouble(
            macrosData['during_mass_norm_rate_g_per_h'],
            'during_mass_norm_rate_g_per_h',
          ),
          absClampRangeGPerH: _toDoubleList(
            macrosData['during_abs_clamp_range_g_per_h'],
          ),
          carbsLowG: bandLow != null ? bandLow * durationH : null,
          carbsHighG: bandHigh != null ? bandHigh * durationH : null,
          sodiumLowMg: _toDoubleOrNull(macrosData['during_sodium_low_mg']),
          sodiumHighMg: _toDoubleOrNull(macrosData['during_sodium_high_mg']),
          fluidsLowMl: _toDoubleOrNull(macrosData['during_water_low_ml']),
          fluidsHighMl: _toDoubleOrNull(macrosData['during_water_high_ml']),
          gutMultiplier: _toDoubleOrNull(macrosData['during_gut_multiplier']),
          sportCeilingGPerH: _toDoubleOrNull(
            macrosData['during_sport_ceiling_g_per_h'],
          ),
          rawBandLowGPerH: _toDoubleOrNull(
            macrosData['during_raw_band_low_g_per_h'],
          ),
          rawBandHighGPerH: _toDoubleOrNull(
            macrosData['during_raw_band_high_g_per_h'],
          ),
          // Hydration/sodium derivation fields (Phase 6 — read from edge fn response)
          effectiveSweatRateLPerH: _toDoubleOrNull(
            macrosData['effective_sweat_rate_lph'],
          ),
          sodiumConcMgPerL: macrosData['sodium_conc_mg_per_l'] != null
              ? _toDouble(macrosData['sodium_conc_mg_per_l']).round()
              : null,
          replacementPercent: _toDoubleOrNull(macrosData['replacement_pct']),
          floorMlPerH: macrosData['floor_ml_hr'] != null
              ? _toDouble(macrosData['floor_ml_hr']).round()
              : null,
          ceilingMlPerH: macrosData['ceiling_ml_hr'] != null
              ? _toDouble(macrosData['ceiling_ml_hr']).round()
              : null,
          safetyFlags: _toStringList(macrosData['safety_flags']),
          isTested: macrosData['is_tested'] as bool? ?? false,
          isTestedSodium: macrosData['is_tested_sodium'] as bool? ?? false,
          // Environment echo fields
          tempC: _toDoubleOrNull(macrosData['temp_c']),
          humidityPct: _toDoubleOrNull(macrosData['humidity_pct']),
          isIndoor: macrosData['is_indoor'] as bool?,
        );
      }(),
      postRun: PostRunMacros(
        carbsG: _toDouble(macrosData['post_run_carbs_g'], 'post_run_carbs_g'),
        proteinG: _toDouble(
          macrosData['post_run_protein_g'],
          'post_run_protein_g',
        ),
        fluidsMl: _toDouble(
          macrosData['post_run_water_ml'],
          'post_run_water_ml',
        ),
        sodiumMg: _toDouble(
          macrosData['post_run_sodium_mg'],
          'post_run_sodium_mg',
        ),
        carbsLowG: _toDoubleOrNull(macrosData['post_run_carbs_low_g']),
        carbsHighG: _toDoubleOrNull(macrosData['post_run_carbs_high_g']),
        proteinLowG: _toDoubleOrNull(macrosData['post_run_protein_low_g']),
        proteinHighG: _toDoubleOrNull(macrosData['post_run_protein_high_g']),
        sodiumLowMg: _toDoubleOrNull(macrosData['post_run_sodium_low_mg']),
        sodiumHighMg: _toDoubleOrNull(macrosData['post_run_sodium_high_mg']),
        fluidsLowMl: _toDoubleOrNull(macrosData['post_run_water_low_ml']),
        fluidsHighMl: _toDoubleOrNull(macrosData['post_run_water_high_ml']),
      ),
      metrics: () {
        // Compute derived metrics client-side since the edge function
        // only returns distance_km, duration_h, and duration_min
        final distanceKm = _toDouble(macrosData['distance_km'], 'distance_km');
        final durationH = _toDouble(macrosData['duration_h'], 'duration_h');
        final durationMin = _toDouble(
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
          caloriesNetKcal: _toDouble(
            macrosData['calories_net_kcal'],
            'calories_net_kcal',
          ),
          caloriesGrossKcal: _toDouble(
            macrosData['calories_gross_kcal'],
            'calories_gross_kcal',
          ),
          met: _toDouble(macrosData['MET'], 'MET'),
        );
      }(),
      calculationRule:
          macrosData['pre_run_carbs_rule'] ?? 'Generated from edge function',
      timestamp: DateTime.now(),
      isUserModified: false,
    );
  }

  double _toDouble(dynamic value, [String fieldName = 'unknown']) {
    try {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return (value as num).toDouble();
    } catch (e) {
      DebugLogger.error(
        '❌ DEBUG: Error converting field "$fieldName" with value "$value" '
        '(${value.runtimeType}) to double: $e',
      );
      return 0.0;
    }
  }

  double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    try {
      return (value as num).toDouble();
    } catch (_) {
      return null;
    }
  }

  List<double> _toDoubleList(
    dynamic value, [
    List<double> defaultValue = const [30, 60],
  ]) {
    if (value == null) return defaultValue;
    if (value is List) {
      return value.map((e) => _toDouble(e)).toList();
    }
    return defaultValue;
  }

  List<Map<String, dynamic>>? _toMapListOrNull(dynamic value) {
    if (value is! List) return null;

    final results = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is Map) {
        results.add(Map<String, dynamic>.from(item));
      }
    }
    return results;
  }

  List<String> _toStringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).toList();
  }

  Future<void> _cacheMacroTargets(
    MacroTargets macroTargets, {
    String? activityId,
  }) async {
    await macroRepository.saveMacroTargets(macroTargets);
    if (activityId != null && activityId.trim().isNotEmpty) {
      await macroRepository.saveMacroTargetsForActivity(
        activityId,
        macroTargets,
      );
    }
  }

  int _calculateTotalCarbs(MacroTargets macroTargets) {
    return (macroTargets.preRun.carbsG +
            macroTargets.duringRun.carbTotalG +
            macroTargets.postRun.carbsG)
        .round();
  }
}
