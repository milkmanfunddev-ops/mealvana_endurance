import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/macro_targets.dart';
import '../domain/nutrition_target_overrides.dart';
import '../data/macro_repository.dart';
import '../../auth/application/auth_service.dart';
import '../../auth/domain/user_preferences.dart';
import '../../activities/domain/brick_metadata.dart';
import '../../activities/domain/brick_exceptions.dart';
import '../../../shared/domain/activity_type.dart';
import '../../../shared/services/analytics/analytics_tracker.dart';
import '../../../shared/services/analytics/analytics_events.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';

/// Service responsible for generating brick macro targets by calling edge functions.
///
/// This service encapsulates all the business logic for:
/// - Calling Supabase edge functions with brick-specific payload
/// - Parsing brick responses (with multi-phase structure)
/// - Converting data types
/// - Caching macro targets
/// - Analytics tracking
///
/// FOA COMPLIANT: Contains ALL business logic, no UI concerns
class BrickMacroService {
  BrickMacroService({
    required this.supabaseClient,
    required this.macroRepository,
    required this.authService,
    required this.analytics,
  });

  final SupabaseClient supabaseClient;
  final MacroRepository macroRepository;
  final AuthService authService;
  final AnalyticsTracker analytics;
  static const double _overrideMatchToleranceGPerH = 0.5;
  static const bool _enableTemporaryBrickClientFallback = true;

  /// Generate brick macro targets
  ///
  /// Returns macro targets with the standardized 3-phase structure:
  /// - preRun (before phase)
  /// - duringRun (cumulative across all segments + transitions)
  /// - postRun (after phase)
  ///
  /// The edge function returns a detailed multi-phase breakdown, but we
  /// normalize it to the standard 3-phase format for the adjust macros screen.
  ///
  /// Throws:
  /// - BrickMacroGenerationException if macro generation fails
  Future<MacroTargets> generateBrickMacros({
    String? activityId,
    required String deviceId,
    required List<BrickSegment> segments,
    required List<String> segmentOrder,
    required bool isFasted,
    required int preActivityMinutes,
    NutritionTargetOverrides? overrides,
  }) async {
    DebugLogger.info(
      '🧱 BRICK MACRO SERVICE: generateBrickMacros called - ${segments.length} segments',
    );

    // Validate segments
    if (segments.isEmpty) {
      throw BrickMacroGenerationException.invalidSegments();
    }

    try {
      // Build request payload
      final requestData = await _buildBrickRequestData(
        segments: segments,
        segmentOrder: segmentOrder,
        isFasted: isFasted,
        preActivityMinutes: preActivityMinutes,
        overrides: overrides,
      );

      DebugLogger.info(
        '🧱 BRICK MACRO SERVICE: Calling generate-macros edge function...',
      );

      // Call edge function with timeout
      final response = await supabaseClient.functions.invoke(
        'generate-macros-v4',
        body: requestData,
      );

      DebugLogger.info('📥 EDGE FUNCTION: Response status: ${response.status}');

      // Handle HTTP errors
      if (response.status >= 400) {
        final data = response.data as Map<String, dynamic>?;
        final errorMessage =
            data?['message'] ?? 'Failed to generate brick macro targets';
        DebugLogger.error(
          '❌ EDGE FUNCTION: HTTP error ${response.status}: $errorMessage',
        );
        throw BrickMacroGenerationException.edgeFunctionError(
          errorMessage,
          statusCode: response.status,
        );
      }

      final data = response.data as Map<String, dynamic>;

      // Handle application-level errors
      if (data['success'] != true) {
        final errorMessage =
            data['message'] ?? 'Failed to generate brick macro targets';
        DebugLogger.error('❌ EDGE FUNCTION: Success=false: $errorMessage');
        throw BrickMacroGenerationException.edgeFunctionError(errorMessage);
      }

      // Parse brick-specific response (pass segments to store in MacroTargets)
      var macroTargets = _parseBrickMacroTargets(data, segments);

      final usedClientFallback =
          _enableTemporaryBrickClientFallback &&
          _shouldApplyClientFallback(
            macroTargets: macroTargets,
            overrides: overrides,
          );
      if (usedClientFallback) {
        DebugLogger.warning(
          '🧱 BRICK MACRO SERVICE: Using temporary client fallback for brick during overrides.',
        );
        macroTargets = _applyDuringOverridesForBrick(
          macroTargets: macroTargets,
          overrides: overrides,
        );
      }

      // Cache the macro targets
      await macroRepository.saveMacroTargets(macroTargets);
      if (activityId != null && activityId.trim().isNotEmpty) {
        await macroRepository.saveMacroTargetsForActivity(
          activityId,
          macroTargets,
        );
      }

      // Track analytics
      await analytics.trackPlanGenerated(
        deviceId: deviceId,
        activityId: activityId,
        activityType: 'brick',
        distanceMiles: macroTargets.metrics.distanceMi,
        paceMinutesPerMile: 0.0, // Not applicable for brick
        totalCalories: macroTargets.metrics.caloriesNetKcal.round(),
        totalCarbs: _calculateTotalCarbs(macroTargets),
        beforeRunItems: 1,
        duringRunItems: segments.length, // One item per segment
        afterRunItems: 1,
        isFirstPlan: true,
      );

      DebugLogger.info(
        '✅ BRICK MACRO SERVICE: Successfully generated brick macro targets',
      );

      return macroTargets;
    } on BrickMacroGenerationException {
      // Re-throw brick-specific exceptions as-is
      rethrow;
    } on FunctionException catch (e) {
      // Supabase function invocation error
      DebugLogger.error('❌ BRICK MACRO SERVICE: Function exception: $e');
      throw BrickMacroGenerationException.networkError(e);
    } catch (e, stackTrace) {
      // Network or parsing errors
      DebugLogger.error(
        '❌ BRICK MACRO SERVICE: Unexpected error: $e\n$stackTrace',
      );

      if (e.toString().contains('network') ||
          e.toString().contains('connection') ||
          e.toString().contains('timeout')) {
        throw BrickMacroGenerationException.networkError(e);
      } else {
        throw BrickMacroGenerationException.parsingError(e);
      }
    }
  }

  // ========================================
  // Private Helper Methods
  // ========================================

  MacroTargets _applyDuringOverridesForBrick({
    required MacroTargets macroTargets,
    NutritionTargetOverrides? overrides,
  }) {
    final phaseTargets = macroTargets.brickPhaseTargets;
    if (overrides == null || phaseTargets == null) return macroTargets;

    var hasSegmentOverride = false;
    final updatedSegments = phaseTargets.duringSegments
        .map((segment) {
          final sportOverride = _duringOverrideForSport(
            overrides,
            segment.sport,
          );
          if (sportOverride == null || !sportOverride.hasAnyOverride) {
            return segment;
          }

          hasSegmentOverride = true;
          final durationH = segment.durationMinutes / 60.0;

          final carbs = sportOverride.carbRateGPerH != null
              ? (sportOverride.carbRateGPerH! * durationH).roundToDouble()
              : segment.carbsG;
          final sodium = sportOverride.sodiumRateMgPerH != null
              ? (sportOverride.sodiumRateMgPerH! * durationH).roundToDouble()
              : segment.sodiumMg;
          final water = sportOverride.fluidRateMlPerH != null
              ? (sportOverride.fluidRateMlPerH! * durationH).roundToDouble()
              : segment.waterMl;

          return BrickSegmentMacroTarget(
            segmentOrder: segment.segmentOrder,
            sport: segment.sport,
            durationMinutes: segment.durationMinutes,
            carbsG: carbs,
            carbsLowG: sportOverride.carbRateGPerH != null
                ? (carbs * 0.8).roundToDouble()
                : segment.carbsLowG,
            carbsHighG: sportOverride.carbRateGPerH != null
                ? (carbs * 1.2).roundToDouble()
                : segment.carbsHighG,
            sodiumMg: sodium,
            sodiumLowMg: sportOverride.sodiumRateMgPerH != null
                ? (sodium * 0.8).roundToDouble()
                : segment.sodiumLowMg,
            sodiumHighMg: sportOverride.sodiumRateMgPerH != null
                ? (sodium * 1.2).roundToDouble()
                : segment.sodiumHighMg,
            waterMl: water,
            waterLowMl: sportOverride.fluidRateMlPerH != null
                ? (water * 0.85).roundToDouble()
                : segment.waterLowMl,
            waterHighMl: sportOverride.fluidRateMlPerH != null
                ? (water * 1.15).roundToDouble()
                : segment.waterHighMl,
          );
        })
        .toList(growable: false);

    if (!hasSegmentOverride) {
      return macroTargets;
    }

    final transitions = phaseTargets.transitions;
    final totalDurationH = macroTargets.metrics.durationH > 0
        ? macroTargets.metrics.durationH
        : updatedSegments.fold<double>(
            0,
            (sum, segment) => sum + (segment.durationMinutes / 60.0),
          );

    final totalCarbs =
        updatedSegments.fold<double>(
          0,
          (sum, segment) => sum + segment.carbsG,
        ) +
        transitions.fold<double>(
          0,
          (sum, transition) => sum + transition.carbsG,
        );
    final totalSodium =
        updatedSegments.fold<double>(
          0,
          (sum, segment) => sum + segment.sodiumMg,
        ) +
        transitions.fold<double>(
          0,
          (sum, transition) => sum + transition.sodiumMg,
        );
    final totalWater =
        updatedSegments.fold<double>(
          0,
          (sum, segment) => sum + segment.waterMl,
        ) +
        transitions.fold<double>(
          0,
          (sum, transition) => sum + transition.waterMl,
        );

    final totalCarbsLow = _sumNullable([
      ...updatedSegments.map((segment) => segment.carbsLowG),
      ...transitions.map((transition) => transition.carbsLowG),
    ]);
    final totalCarbsHigh = _sumNullable([
      ...updatedSegments.map((segment) => segment.carbsHighG),
      ...transitions.map((transition) => transition.carbsHighG),
    ]);
    final totalSodiumLow = _sumNullable([
      ...updatedSegments.map((segment) => segment.sodiumLowMg),
      ...transitions.map((transition) => transition.sodiumLowMg),
    ]);
    final totalSodiumHigh = _sumNullable([
      ...updatedSegments.map((segment) => segment.sodiumHighMg),
      ...transitions.map((transition) => transition.sodiumHighMg),
    ]);
    final totalWaterLow = _sumNullable([
      ...updatedSegments.map((segment) => segment.waterLowMl),
      ...transitions.map((transition) => transition.waterLowMl),
    ]);
    final totalWaterHigh = _sumNullable([
      ...updatedSegments.map((segment) => segment.waterHighMl),
      ...transitions.map((transition) => transition.waterHighMl),
    ]);

    final updatedDuring = macroTargets.duringRun.copyWith(
      carbTotalG: totalCarbs,
      carbRateGPerH: totalDurationH > 0
          ? totalCarbs / totalDurationH
          : macroTargets.duringRun.carbRateGPerH,
      fluidTotalMl: totalWater,
      fluidRateMlPerH: totalDurationH > 0
          ? totalWater / totalDurationH
          : macroTargets.duringRun.fluidRateMlPerH,
      sodiumTotalMg: totalSodium,
      sodiumRateMgPerH: totalDurationH > 0
          ? totalSodium / totalDurationH
          : macroTargets.duringRun.sodiumRateMgPerH,
      carbsLowG: totalCarbsLow,
      carbsHighG: totalCarbsHigh,
      sodiumLowMg: totalSodiumLow,
      sodiumHighMg: totalSodiumHigh,
      fluidsLowMl: totalWaterLow,
      fluidsHighMl: totalWaterHigh,
    );

    return macroTargets.copyWith(
      duringRun: updatedDuring,
      brickPhaseTargets: BrickPhaseTargets(
        duringSegments: updatedSegments,
        transitions: transitions,
      ),
    );
  }

  DuringActivityOverrides? _duringOverrideForSport(
    NutritionTargetOverrides overrides,
    String sport,
  ) {
    switch (sport.toLowerCase()) {
      case 'running':
        return overrides.duringRun ?? overrides.during;
      case 'cycling':
        return overrides.duringCycling ?? overrides.during;
      case 'swimming':
        return overrides.duringSwimming ?? overrides.during;
      default:
        return overrides.during;
    }
  }

  double? _sumNullable(List<double?> values) {
    final present = values.whereType<double>().toList(growable: false);
    if (present.isEmpty) return null;
    return present.fold<double>(0, (sum, value) => sum + value);
  }

  /// Build request payload for brick edge function
  Future<Map<String, dynamic>> _buildBrickRequestData({
    required List<BrickSegment> segments,
    required List<String> segmentOrder,
    required bool isFasted,
    required int preActivityMinutes,
    NutritionTargetOverrides? overrides,
  }) async {
    final userProfile = await authService.getCurrentUser();
    final userMetrics = _getUserMetrics(userProfile);
    final preferencePayload = await _buildPreWorkoutPreferencePayload(
      userProfile,
    );

    // Convert BrickSegment objects to JSON payload format
    final segmentsJson = segments.map((segment) {
      return <String, dynamic>{
        'sport': segment.sport,
        'order': segment.order,
        'duration_minutes': segment.durationMinutes,
        'intensity': segment.intensity,
        if (segment.distanceMeters != null)
          'distance_meters': segment.distanceMeters,
        if (segment.pacePer100mSeconds != null)
          'pace_per_100m_seconds': segment.pacePer100mSeconds,
        if (segment.poolOrOpenWater != null)
          'pool_or_open_water': segment.poolOrOpenWater,
        if (segment.waterTempC != null) 'water_temp_c': segment.waterTempC,
        if (segment.distanceMiles != null)
          'distance_miles': segment.distanceMiles,
        if (segment.speedMph != null) 'speed_mph': segment.speedMph,
        if (segment.terrain != null) 'terrain': segment.terrain,
        if (segment.indoorOutdoor != null)
          'indoor_outdoor': segment.indoorOutdoor,
        if (segment.elevationGainFt != null)
          'elevation_gain_ft': segment.elevationGainFt,
        if (segment.paceMinutesPerMile != null)
          'pace_minutes_per_mile': segment.paceMinutesPerMile,
      };
    }).toList();

    // Sweat profile: read from UserProfile.
    final sweatSodiumValue =
        (userProfile?.sweatSodium ?? SweatSodiumCat.average).value;
    final knownSweatRateMlHr = userProfile?.knownSweatRateMlPerHour;
    final knownSodiumConcMgL =
        userProfile?.knownSodiumConcentrationMgPerLiter;

    // Derive is_indoor from any cycling segment that specifies indoor_outdoor.
    // If any segment is explicitly 'indoor', treat the whole brick as indoor for
    // the sweat calculation. Falls back to false when no segment sets this.
    // TODO: wire isIndoor from a top-level brick form field if added in future.
    final isIndoor = segments.any(
      (s) => s.indoorOutdoor?.toLowerCase() == 'indoor',
    );

    final requestData = {
      'activity_type': 'brick',
      'age': userMetrics['age'],
      'gender': userMetrics['gender'],
      'weight': userMetrics['weightKg'],
      'weight_unit': 'kg',
      'height': userMetrics['heightCm'],
      'height_unit': 'cm',
      'brick_segments': segmentsJson,
      'segment_order': segmentOrder,
      'gut_training': userProfile?.gutTraining.name ?? 'moderate',
      'sweat_rate_category': userProfile?.sweatRate.name ?? 'medium',
      // Sweat profile (Phase 6: read from UserProfile instead of hardcoding)
      'sweat_sodium': sweatSodiumValue,
      'is_indoor': isIndoor,
      if (knownSweatRateMlHr != null)
        'known_sweat_rate_ml_hr': knownSweatRateMlHr,
      if (knownSodiumConcMgL != null)
        'known_sodium_concentration_mg_l': knownSodiumConcMgL,
      'hours_before': preActivityMinutes / 60.0,
      'is_fasted': isFasted,
      'intensity_distribution': {
        'zone_low': 0.7,
        'zone_mid': 0.2,
        'zone_high': 0.1,
      },
      ...preferencePayload,
    };

    if (overrides != null && overrides.hasAnyOverride) {
      final clamped = NutritionTargetGuardrails.clampAll(overrides);
      requestData['overrides'] = clamped.toBrickEdgeFunctionPayload(
        sports: _extractBrickSports(segments),
      );
    }

    return requestData;
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

  bool _shouldApplyClientFallback({
    required MacroTargets macroTargets,
    NutritionTargetOverrides? overrides,
  }) {
    if (overrides == null) return false;
    final phaseTargets = macroTargets.brickPhaseTargets;
    if (phaseTargets == null || phaseTargets.duringSegments.isEmpty) {
      return false;
    }

    for (final segment in phaseTargets.duringSegments) {
      final sportOverride = _duringOverrideForSport(overrides, segment.sport);
      final targetRate = sportOverride?.carbRateGPerH;
      if (targetRate == null || targetRate <= 0) {
        continue;
      }

      final durationH = segment.durationMinutes > 0
          ? segment.durationMinutes / 60.0
          : 0.0;
      final observedRate =
          segment.carbsRateGPerH ??
          (durationH > 0 ? segment.carbsG / durationH : 0.0);
      if ((observedRate - targetRate).abs() > _overrideMatchToleranceGPerH) {
        return true;
      }
    }

    return false;
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

    return payload;
  }

  /// Parse brick macro targets from edge function response
  ///
  /// The edge function returns a multi-phase structure with:
  /// - before (pre-workout)
  /// - during_segments (array of segment-specific macros)
  /// - transitions (T1, T2)
  /// - after (post-workout)
  ///
  /// We normalize this to the standard 3-phase format by:
  /// - preRun = before phase
  /// - duringRun = sum of all during_segments + transitions
  /// - postRun = after phase
  ///
  /// [segments] - Original brick segments to store for nutrition plan generation
  MacroTargets _parseBrickMacroTargets(
    Map<String, dynamic> data,
    List<BrickSegment> segments,
  ) {
    final macrosData = data['macros'] as Map<String, dynamic>;
    final phasesData = macrosData['phases'] as Map<String, dynamic>?;

    if (phasesData == null) {
      throw Exception('Invalid brick macro response: missing phases data');
    }

    // Parse before phase
    final beforePhase = phasesData['before'] as Map<String, dynamic>? ?? {};
    final preRunCarbs = _toDouble(beforePhase['carbs_g'], 'before.carbs_g');
    final preRunProtein = _toDouble(
      beforePhase['protein_g'],
      'before.protein_g',
    );
    final preRunFat = _toDouble(beforePhase['fat_g'], 'before.fat_g');
    final preRunFluids = _toDouble(beforePhase['water_ml'], 'before.water_ml');
    final preRunSodium = _toDouble(
      beforePhase['sodium_mg'],
      'before.sodium_mg',
    );
    // V4 range fields
    final preRunCarbsLow = _toDoubleOrNull(beforePhase['carbs_low_g']);
    final preRunCarbsHigh = _toDoubleOrNull(beforePhase['carbs_high_g']);
    final preRunProteinLow = _toDoubleOrNull(beforePhase['protein_low_g']);
    final preRunProteinHigh = _toDoubleOrNull(beforePhase['protein_high_g']);
    final preRunSodiumLow = _toDoubleOrNull(beforePhase['sodium_low_mg']);
    final preRunSodiumHigh = _toDoubleOrNull(beforePhase['sodium_high_mg']);
    final preRunFluidsLow = _toDoubleOrNull(beforePhase['water_low_ml']);
    final preRunFluidsHigh = _toDoubleOrNull(beforePhase['water_high_ml']);

    // Parse after phase
    final afterPhase = phasesData['after'] as Map<String, dynamic>? ?? {};
    final postRunCarbs = _toDouble(afterPhase['carbs_g'], 'after.carbs_g');
    final postRunProtein = _toDouble(
      afterPhase['protein_g'],
      'after.protein_g',
    );
    final postRunFluids = _toDouble(afterPhase['water_ml'], 'after.water_ml');
    final postRunSodium = _toDouble(afterPhase['sodium_mg'], 'after.sodium_mg');
    // V4 range fields for post-run
    final postRunCarbsLow = _toDoubleOrNull(afterPhase['carbs_low_g']);
    final postRunCarbsHigh = _toDoubleOrNull(afterPhase['carbs_high_g']);
    final postRunProteinLow = _toDoubleOrNull(afterPhase['protein_low_g']);
    final postRunProteinHigh = _toDoubleOrNull(afterPhase['protein_high_g']);
    final postRunSodiumLow = _toDoubleOrNull(afterPhase['sodium_low_mg']);
    final postRunSodiumHigh = _toDoubleOrNull(afterPhase['sodium_high_mg']);
    final postRunFluidsLow = _toDoubleOrNull(afterPhase['water_low_ml']);
    final postRunFluidsHigh = _toDoubleOrNull(afterPhase['water_high_ml']);

    // Parse during segments and transitions
    // Sum all during phases (segments + transitions) for cumulative totals
    double duringCarbsTotal = 0.0;
    double duringFluidsTotal = 0.0;
    double duringSodiumTotal = 0.0;
    double duringSodiumLowTotal = 0.0;
    double duringSodiumHighTotal = 0.0;
    double duringFluidsLowTotal = 0.0;
    double duringFluidsHighTotal = 0.0;
    bool hasDuringRanges = false;

    // Sum during segments (edge function returns as List, not Map)
    final duringSegments =
        phasesData['during_segments'] as List<dynamic>? ?? [];
    final parsedDuringSegments = <BrickSegmentMacroTarget>[];
    double duringCarbsLowTotal = 0.0;
    double duringCarbsHighTotal = 0.0;
    for (final segmentData in duringSegments) {
      if (segmentData is Map<String, dynamic>) {
        duringCarbsTotal += _toDouble(
          segmentData['carbs_g'],
          'during_segment.carbs_g',
        );
        duringFluidsTotal += _toDouble(
          segmentData['water_ml'],
          'during_segment.water_ml',
        );
        duringSodiumTotal += _toDouble(
          segmentData['sodium_mg'],
          'during_segment.sodium_mg',
        );
        final segCarbsLow = _toDoubleOrNull(segmentData['carbs_low_g']);
        final segCarbsHigh = _toDoubleOrNull(segmentData['carbs_high_g']);
        final segSodiumLow = _toDoubleOrNull(segmentData['sodium_low_mg']);
        final segSodiumHigh = _toDoubleOrNull(segmentData['sodium_high_mg']);
        final segFluidsLow = _toDoubleOrNull(segmentData['water_low_ml']);
        final segFluidsHigh = _toDoubleOrNull(segmentData['water_high_ml']);
        if (segCarbsLow != null) {
          duringCarbsLowTotal += segCarbsLow;
          hasDuringRanges = true;
        }
        if (segCarbsHigh != null) {
          duringCarbsHighTotal += segCarbsHigh;
          hasDuringRanges = true;
        }
        if (segSodiumLow != null) {
          duringSodiumLowTotal += segSodiumLow;
          hasDuringRanges = true;
        }
        if (segSodiumHigh != null) {
          duringSodiumHighTotal += segSodiumHigh;
          hasDuringRanges = true;
        }
        if (segFluidsLow != null) {
          duringFluidsLowTotal += segFluidsLow;
          hasDuringRanges = true;
        }
        if (segFluidsHigh != null) {
          duringFluidsHighTotal += segFluidsHigh;
          hasDuringRanges = true;
        }

        parsedDuringSegments.add(
          BrickSegmentMacroTarget(
            segmentOrder:
                (segmentData['segment_order'] as num?)?.toInt() ??
                (segmentData['order'] as num?)?.toInt() ??
                parsedDuringSegments.length + 1,
            sport: segmentData['sport'] as String? ?? 'unknown',
            durationMinutes:
                (segmentData['duration_minutes'] as num?)?.toInt() ?? 0,
            carbsG: _toDouble(segmentData['carbs_g'], 'during_segment.carbs_g'),
            carbsLowG: _toDoubleOrNull(segmentData['carbs_low_g']),
            carbsHighG: _toDoubleOrNull(segmentData['carbs_high_g']),
            sodiumMg: _toDouble(
              segmentData['sodium_mg'],
              'during_segment.sodium_mg',
            ),
            sodiumLowMg: segSodiumLow,
            sodiumHighMg: segSodiumHigh,
            waterMl: _toDouble(
              segmentData['water_ml'],
              'during_segment.water_ml',
            ),
            waterLowMl: segFluidsLow,
            waterHighMl: segFluidsHigh,
            carbsRateGPerH: _toDoubleOrNull(segmentData['carbs_rate_g_per_h']),
            rawBandLowGPerH: _toDoubleOrNull(
              segmentData['raw_band_low_g_per_h'],
            ),
            rawBandHighGPerH: _toDoubleOrNull(
              segmentData['raw_band_high_g_per_h'],
            ),
            scaledBandLowGPerH: _toDoubleOrNull(
              segmentData['scaled_band_low_g_per_h'],
            ),
            scaledBandHighGPerH: _toDoubleOrNull(
              segmentData['scaled_band_high_g_per_h'],
            ),
            gutMultiplier: _toDoubleOrNull(segmentData['gut_multiplier']),
            sportCeilingGPerH: _toDoubleOrNull(
              segmentData['sport_ceiling_g_per_h'],
            ),
            brickPenalty: _toDoubleOrNull(segmentData['brick_penalty']),
            cumulativeDurationMin: _toDoubleOrNull(
              segmentData['cumulative_duration_min'],
            ),
            // Hydration/sodium derivation fields (Phase 6 — read from edge fn)
            effectiveSweatRateLPerH: _toDoubleOrNull(
              segmentData['effective_sweat_rate_lph'],
            ),
            sodiumConcMgPerL: segmentData['sodium_conc_mg_per_l'] != null
                ? _toDouble(segmentData['sodium_conc_mg_per_l']).round()
                : null,
            replacementPercent: _toDoubleOrNull(
              segmentData['replacement_pct'],
            ),
            floorMlPerH: segmentData['floor_ml_hr'] != null
                ? _toDouble(segmentData['floor_ml_hr']).round()
                : null,
            ceilingMlPerH: segmentData['ceiling_ml_hr'] != null
                ? _toDouble(segmentData['ceiling_ml_hr']).round()
                : null,
            safetyFlags: _toStringList(segmentData['safety_flags']),
            isTested: segmentData['is_tested'] as bool? ?? false,
          ),
        );
      }
    }

    // Sum transitions (edge function returns as List, not Map)
    final transitions = phasesData['transitions'] as List<dynamic>? ?? [];
    final parsedTransitions = <BrickTransitionMacroTarget>[];
    for (final transitionData in transitions) {
      if (transitionData is Map<String, dynamic>) {
        duringCarbsTotal += _toDouble(
          transitionData['carbs_g'],
          'transition.carbs_g',
        );
        duringFluidsTotal += _toDouble(
          transitionData['water_ml'],
          'transition.water_ml',
        );
        duringSodiumTotal += _toDouble(
          transitionData['sodium_mg'],
          'transition.sodium_mg',
        );
        final trSodiumLow = _toDoubleOrNull(transitionData['sodium_low_mg']);
        final trSodiumHigh = _toDoubleOrNull(transitionData['sodium_high_mg']);
        final trFluidsLow = _toDoubleOrNull(transitionData['water_low_ml']);
        final trFluidsHigh = _toDoubleOrNull(transitionData['water_high_ml']);
        if (trSodiumLow != null) duringSodiumLowTotal += trSodiumLow;
        if (trSodiumHigh != null) duringSodiumHighTotal += trSodiumHigh;
        if (trFluidsLow != null) duringFluidsLowTotal += trFluidsLow;
        if (trFluidsHigh != null) duringFluidsHighTotal += trFluidsHigh;

        parsedTransitions.add(
          BrickTransitionMacroTarget(
            transitionName:
                transitionData['transition_name'] as String? ??
                transitionData['transition_id'] as String? ??
                'T${parsedTransitions.length + 1}',
            carbsG: _toDouble(transitionData['carbs_g'], 'transition.carbs_g'),
            carbsLowG: _toDoubleOrNull(transitionData['carbs_low_g']),
            carbsHighG: _toDoubleOrNull(transitionData['carbs_high_g']),
            sodiumMg: _toDouble(
              transitionData['sodium_mg'],
              'transition.sodium_mg',
            ),
            sodiumLowMg: trSodiumLow,
            sodiumHighMg: trSodiumHigh,
            waterMl: _toDouble(
              transitionData['water_ml'],
              'transition.water_ml',
            ),
            waterLowMl: trFluidsLow,
            waterHighMl: trFluidsHigh,
            // Hydration/sodium derivation fields (Phase 6 — read from edge fn)
            effectiveSweatRateLPerH: _toDoubleOrNull(
              transitionData['effective_sweat_rate_lph'],
            ),
            sodiumConcMgPerL: transitionData['sodium_conc_mg_per_l'] != null
                ? _toDouble(transitionData['sodium_conc_mg_per_l']).round()
                : null,
            replacementPercent: _toDoubleOrNull(
              transitionData['replacement_pct'],
            ),
            floorMlPerH: transitionData['floor_ml_hr'] != null
                ? _toDouble(transitionData['floor_ml_hr']).round()
                : null,
            ceilingMlPerH: transitionData['ceiling_ml_hr'] != null
                ? _toDouble(transitionData['ceiling_ml_hr']).round()
                : null,
            safetyFlags: _toStringList(transitionData['safety_flags']),
            isTested: transitionData['is_tested'] as bool? ?? false,
          ),
        );
      }
    }

    // Calculate rate per hour from totals and duration
    final totalDurationH = _toDouble(macrosData['duration_h'], 'duration_h');
    final duringCarbRate = totalDurationH > 0
        ? duringCarbsTotal / totalDurationH
        : 0.0;
    final duringFluidsRate = totalDurationH > 0
        ? duringFluidsTotal / totalDurationH
        : 0.0;
    final duringSodiumRate = totalDurationH > 0
        ? duringSodiumTotal / totalDurationH
        : 0.0;

    // Parse metrics
    final distanceMi = _toDouble(macrosData['distance_mi'], 'distance_mi');
    final distanceKm = _toDouble(macrosData['distance_km'], 'distance_km');
    final durationH = _toDouble(macrosData['duration_h'], 'duration_h');
    final durationMin = _toDouble(macrosData['duration_min'], 'duration_min');
    final caloriesNet = _toDouble(
      macrosData['calories_net_kcal'],
      'calories_net_kcal',
    );
    final caloriesGross = _toDouble(
      macrosData['calories_gross_kcal'],
      'calories_gross_kcal',
    );

    return MacroTargets(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      activityType: ActivityType.brick,
      preRun: PreRunMacros(
        carbsG: preRunCarbs,
        proteinG: preRunProtein,
        fatCapG: preRunFat,
        fluidsMl: preRunFluids,
        sodiumMg: preRunSodium,
        carbsLowG: preRunCarbsLow,
        carbsHighG: preRunCarbsHigh,
        proteinLowG: preRunProteinLow,
        proteinHighG: preRunProteinHigh,
        sodiumLowMg: preRunSodiumLow,
        sodiumHighMg: preRunSodiumHigh,
        fluidsLowMl: preRunFluidsLow,
        fluidsHighMl: preRunFluidsHigh,
      ),
      preRunSelections: _toMapListOrNull(macrosData['pre_run_selections']),
      duringRun: DuringRunMacros(
        carbRateGPerH: duringCarbRate,
        carbTotalG: duringCarbsTotal,
        fluidRateMlPerH: duringFluidsRate,
        fluidTotalMl: duringFluidsTotal,
        sodiumRateMgPerH: duringSodiumRate,
        sodiumTotalMg: duringSodiumTotal,
        massNormRateGPerH: 0.0, // Not applicable for brick (multi-segment)
        absClampRangeGPerH: [
          30,
          90,
        ], // Placeholder — per-segment bands in brickPhaseTargets
        carbsLowG: hasDuringRanges && duringCarbsLowTotal > 0
            ? duringCarbsLowTotal
            : null,
        carbsHighG: hasDuringRanges && duringCarbsHighTotal > 0
            ? duringCarbsHighTotal
            : null,
        sodiumLowMg: hasDuringRanges ? duringSodiumLowTotal : null,
        sodiumHighMg: hasDuringRanges ? duringSodiumHighTotal : null,
        fluidsLowMl: hasDuringRanges ? duringFluidsLowTotal : null,
        fluidsHighMl: hasDuringRanges ? duringFluidsHighTotal : null,
      ),
      postRun: PostRunMacros(
        carbsG: postRunCarbs,
        proteinG: postRunProtein,
        fluidsMl: postRunFluids,
        sodiumMg: postRunSodium,
        carbsLowG: postRunCarbsLow,
        carbsHighG: postRunCarbsHigh,
        proteinLowG: postRunProteinLow,
        proteinHighG: postRunProteinHigh,
        sodiumLowMg: postRunSodiumLow,
        sodiumHighMg: postRunSodiumHigh,
        fluidsLowMl: postRunFluidsLow,
        fluidsHighMl: postRunFluidsHigh,
      ),
      metrics: RunMetrics(
        distanceMi: distanceMi,
        distanceKm: distanceKm,
        durationH: durationH,
        durationMin: durationMin,
        paceMinPerMile: null, // Not applicable for brick
        speedMph: distanceMi > 0 && durationH > 0
            ? distanceMi / durationH
            : 0.0,
        caloriesNetKcal: caloriesNet,
        caloriesGrossKcal: caloriesGross,
        met: 0.0, // Not applicable for brick (multi-segment)
      ),
      calculationRule: 'Brick workout - multi-segment calculation',
      timestamp: DateTime.now(),
      isUserModified: false,
      brickSegments: segments, // Store segments for nutrition plan generation
      brickPhaseTargets: BrickPhaseTargets(
        duringSegments: parsedDuringSegments,
        transitions: parsedTransitions,
      ),
    );
  }

  /// Get user metrics with fallbacks
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

  /// Safely convert to nullable double
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

  /// Safely convert to list of string-keyed maps.
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

  /// Safely convert a JSON list to a list of strings.
  List<String> _toStringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).toList();
  }

  /// Safely convert to double
  double _toDouble(dynamic value, [String fieldName = 'unknown']) {
    try {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return (value as num).toDouble();
    } catch (e) {
      DebugLogger.error(
        '❌ BRICK MACRO SERVICE: Error converting field "$fieldName" with value "$value" '
        '(${value.runtimeType}) to double: $e',
      );
      return 0.0;
    }
  }

  /// Calculate total carbs across all phases
  int _calculateTotalCarbs(MacroTargets macroTargets) {
    return (macroTargets.preRun.carbsG +
            macroTargets.duringRun.carbTotalG +
            macroTargets.postRun.carbsG)
        .round();
  }
}
