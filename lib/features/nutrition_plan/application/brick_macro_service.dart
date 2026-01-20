import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/macro_targets.dart';
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
  }) async {
    DebugLogger.info('🧱 BRICK MACRO SERVICE: generateBrickMacros called - ${segments.length} segments');

    // Validate segments
    if (segments.isEmpty) {
      throw BrickMacroGenerationException.invalidSegments();
    }

    try {
      // Build request payload
      final requestData = await _buildBrickRequestData(
        segments: segments,
        segmentOrder: segmentOrder,
      );

      DebugLogger.info('🧱 BRICK MACRO SERVICE: Calling generate-macros edge function...');

      // Call edge function with timeout
      final response = await supabaseClient.functions.invoke(
        'generate-macros',
        body: requestData,
      );

      DebugLogger.info('📥 EDGE FUNCTION: Response status: ${response.status}');

      // Handle HTTP errors
      if (response.status >= 400) {
        final data = response.data as Map<String, dynamic>?;
        final errorMessage = data?['message'] ?? 'Failed to generate brick macro targets';
        DebugLogger.error('❌ EDGE FUNCTION: HTTP error ${response.status}: $errorMessage');
        throw BrickMacroGenerationException.edgeFunctionError(
          errorMessage,
          statusCode: response.status,
        );
      }

      final data = response.data as Map<String, dynamic>;

      // Handle application-level errors
      if (data['success'] != true) {
        final errorMessage = data['message'] ?? 'Failed to generate brick macro targets';
        DebugLogger.error('❌ EDGE FUNCTION: Success=false: $errorMessage');
        throw BrickMacroGenerationException.edgeFunctionError(errorMessage);
      }

      // Parse brick-specific response
      final macroTargets = _parseBrickMacroTargets(data);

      // Cache the macro targets
      await macroRepository.saveMacroTargets(macroTargets);

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

      DebugLogger.info('✅ BRICK MACRO SERVICE: Successfully generated brick macro targets');

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
      DebugLogger.error('❌ BRICK MACRO SERVICE: Unexpected error: $e\n$stackTrace');

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

  /// Build request payload for brick edge function
  Future<Map<String, dynamic>> _buildBrickRequestData({
    required List<BrickSegment> segments,
    required List<String> segmentOrder,
  }) async {
    final userProfile = await authService.getCurrentUser();
    final userMetrics = _getUserMetrics(userProfile);

    // Convert BrickSegment objects to JSON payload format
    final segmentsJson = segments.map((segment) => {
      'sport': segment.sport,
      'order': segment.order,
      'duration_minutes': segment.durationMinutes,
      'intensity': segment.intensity,
      if (segment.distanceMeters != null) 'distance_meters': segment.distanceMeters,
      if (segment.pacePer100mSeconds != null) 'pace_per_100m_seconds': segment.pacePer100mSeconds,
      if (segment.poolOrOpenWater != null) 'pool_or_open_water': segment.poolOrOpenWater,
      if (segment.waterTempC != null) 'water_temp_c': segment.waterTempC,
      if (segment.distanceMiles != null) 'distance_miles': segment.distanceMiles,
      if (segment.speedMph != null) 'speed_mph': segment.speedMph,
      if (segment.terrain != null) 'terrain': segment.terrain,
      if (segment.indoorOutdoor != null) 'indoor_outdoor': segment.indoorOutdoor,
      if (segment.elevationGainFt != null) 'elevation_gain_ft': segment.elevationGainFt,
      if (segment.paceMinutesPerMile != null) 'pace_minutes_per_mile': segment.paceMinutesPerMile,
    }).toList();

    return {
      'activity_type': 'brick',
      'age': userMetrics['age'],
      'gender': userMetrics['gender'],
      'weight': userMetrics['weightKg'],
      'weight_unit': 'kg',
      'height': userMetrics['heightCm'],
      'height_unit': 'cm',
      'segments': segmentsJson,
      'segment_order': segmentOrder,
      'gut_training': userProfile?.gutTraining.name ?? 'moderate',
    };
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
  MacroTargets _parseBrickMacroTargets(Map<String, dynamic> data) {
    final macrosData = data['macros'] as Map<String, dynamic>;
    final phasesData = macrosData['phases'] as Map<String, dynamic>?;

    if (phasesData == null) {
      throw Exception('Invalid brick macro response: missing phases data');
    }

    // Parse before phase
    final beforePhase = phasesData['before'] as Map<String, dynamic>? ?? {};
    final preRunCarbs = _toDouble(beforePhase['carbs_g'], 'before.carbs_g');
    final preRunProtein = _toDouble(beforePhase['protein_g'], 'before.protein_g');
    final preRunFat = _toDouble(beforePhase['fat_g'], 'before.fat_g');
    final preRunFluids = _toDouble(beforePhase['water_ml'], 'before.water_ml');
    final preRunSodium = _toDouble(beforePhase['sodium_mg'], 'before.sodium_mg');

    // Parse after phase
    final afterPhase = phasesData['after'] as Map<String, dynamic>? ?? {};
    final postRunCarbs = _toDouble(afterPhase['carbs_g'], 'after.carbs_g');
    final postRunProtein = _toDouble(afterPhase['protein_g'], 'after.protein_g');
    final postRunFluids = _toDouble(afterPhase['water_ml'], 'after.water_ml');
    final postRunSodium = _toDouble(afterPhase['sodium_mg'], 'after.sodium_mg');

    // Parse during segments and transitions
    // Sum all during phases (segments + transitions) for cumulative totals
    double duringCarbsTotal = 0.0;
    double duringFluidsTotal = 0.0;
    double duringSodiumTotal = 0.0;

    // Sum during segments
    final duringSegments = phasesData['during_segments'] as Map<String, dynamic>? ?? {};
    for (final segmentData in duringSegments.values) {
      if (segmentData is Map<String, dynamic>) {
        duringCarbsTotal += _toDouble(segmentData['carbs_g'], 'during_segment.carbs_g');
        duringFluidsTotal += _toDouble(segmentData['water_ml'], 'during_segment.water_ml');
        duringSodiumTotal += _toDouble(segmentData['sodium_mg'], 'during_segment.sodium_mg');
      }
    }

    // Sum transitions
    final transitions = phasesData['transitions'] as Map<String, dynamic>? ?? {};
    for (final transitionData in transitions.values) {
      if (transitionData is Map<String, dynamic>) {
        duringCarbsTotal += _toDouble(transitionData['carbs_g'], 'transition.carbs_g');
        duringFluidsTotal += _toDouble(transitionData['water_ml'], 'transition.water_ml');
        duringSodiumTotal += _toDouble(transitionData['sodium_mg'], 'transition.sodium_mg');
      }
    }

    // Calculate rate per hour from totals and duration
    final totalDurationH = _toDouble(macrosData['duration_h'], 'duration_h');
    final duringCarbRate = totalDurationH > 0 ? duringCarbsTotal / totalDurationH : 0.0;
    final duringFluidsRate = totalDurationH > 0 ? duringFluidsTotal / totalDurationH : 0.0;
    final duringSodiumRate = totalDurationH > 0 ? duringSodiumTotal / totalDurationH : 0.0;

    // Parse metrics
    final distanceMi = _toDouble(macrosData['distance_mi'], 'distance_mi');
    final distanceKm = _toDouble(macrosData['distance_km'], 'distance_km');
    final durationH = _toDouble(macrosData['duration_h'], 'duration_h');
    final durationMin = _toDouble(macrosData['duration_min'], 'duration_min');
    final caloriesNet = _toDouble(macrosData['calories_net_kcal'], 'calories_net_kcal');
    final caloriesGross = _toDouble(macrosData['calories_gross_kcal'], 'calories_gross_kcal');

    return MacroTargets(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      activityType: ActivityType.brick,
      preRun: PreRunMacros(
        carbsG: preRunCarbs,
        proteinG: preRunProtein,
        fatCapG: preRunFat,
        fluidsMl: preRunFluids,
        sodiumMg: preRunSodium,
      ),
      duringRun: DuringRunMacros(
        carbRateGPerH: duringCarbRate,
        carbTotalG: duringCarbsTotal,
        fluidRateMlPerH: duringFluidsRate,
        fluidTotalMl: duringFluidsTotal,
        sodiumRateMgPerH: duringSodiumRate,
        sodiumTotalMg: duringSodiumTotal,
        massNormRateGPerH: 0.0, // Not applicable for brick (multi-segment)
        absClampRangeGPerH: [30, 90], // Default range
      ),
      postRun: PostRunMacros(
        carbsG: postRunCarbs,
        proteinG: postRunProtein,
        fluidsMl: postRunFluids,
        sodiumMg: postRunSodium,
      ),
      metrics: RunMetrics(
        distanceMi: distanceMi,
        distanceKm: distanceKm,
        durationH: durationH,
        durationMin: durationMin,
        paceMinPerMile: null, // Not applicable for brick
        speedMph: distanceMi > 0 && durationH > 0 ? distanceMi / durationH : 0.0,
        caloriesNetKcal: caloriesNet,
        caloriesGrossKcal: caloriesGross,
        met: 0.0, // Not applicable for brick (multi-segment)
      ),
      calculationRule: 'Brick workout - multi-segment calculation',
      timestamp: DateTime.now(),
      isUserModified: false,
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
