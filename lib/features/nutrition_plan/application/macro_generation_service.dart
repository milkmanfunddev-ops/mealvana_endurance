import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/macro_targets.dart';
import '../data/macro_repository.dart';
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
  final Future<MacroRepository> macroRepository;
  final AuthService authService;
  final AnalyticsTracker analytics;

  /// Generate running macro targets
  Future<MacroTargets> generateRunningMacros({
    int? activityId,
    required String deviceId,
    required double distanceMiles,
    required double paceMinutesPerMile,
    required int timeBeforeRunMinutes,
    required GutTraining gutTraining,
    SweatRateCat? sweatRateCat,
    double? temperatureC,
    double? humidityPct,
  }) async {
    final requestData = await _buildRunningRequestData(
      distanceMiles: distanceMiles,
      paceMinutesPerMile: paceMinutesPerMile,
      timeBeforeRunMinutes: timeBeforeRunMinutes,
      gutTraining: gutTraining,
      sweatRateCat: sweatRateCat,
      temperatureC: temperatureC,
      humidityPct: humidityPct,
    );

    final macroTargets = await _callGenerateMacrosEdgeFunction(
      requestData: requestData,
      expectedActivityType: ActivityType.running,
    );

    await _cacheMacroTargets(macroTargets);

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
    int? activityId,
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
  }) async {
    DebugLogger.info('🚴 MACRO SERVICE: generateCyclingMacros called - distance: ${distanceMiles}mi, speed: ${speedMph}mph');

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
    );
    DebugLogger.info('🚴 MACRO SERVICE: Request data built, calling edge function...');

    final macroTargets = await _callGenerateMacrosEdgeFunction(
      requestData: requestData,
      expectedActivityType: ActivityType.cycling,
    );
    DebugLogger.info('🚴 MACRO SERVICE: Edge function returned, caching targets...');

    await _cacheMacroTargets(macroTargets);
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
    DebugLogger.info('🚴 MACRO SERVICE: Analytics tracked, returning macro targets');

    return macroTargets;
  }

  /// Generate swimming macro targets
  Future<MacroTargets> generateSwimmingMacros({
    int? activityId,
    required String deviceId,
    required int distanceMeters,
    required int paceSecondsper100m,
    required String poolOrOpenWater,
    required int timeBeforeMinutes,
    String? intensityTarget,
    String? sessionGoal,
    double? waterTempC,
  }) async {
    DebugLogger.info('🏊 MACRO SERVICE: generateSwimmingMacros called - distance: ${distanceMeters}m, pace: ${paceSecondsper100m}s/100m');

    DebugLogger.info('🏊 MACRO SERVICE: Building request data...');
    final requestData = await _buildSwimmingRequestData(
      distanceMeters: distanceMeters,
      paceSecondsper100m: paceSecondsper100m,
      poolOrOpenWater: poolOrOpenWater,
      timeBeforeMinutes: timeBeforeMinutes,
      intensityTarget: intensityTarget,
      sessionGoal: sessionGoal,
      waterTempC: waterTempC,
    );
    DebugLogger.info('🏊 MACRO SERVICE: Request data built, calling edge function...');

    final macroTargets = await _callGenerateMacrosEdgeFunction(
      requestData: requestData,
      expectedActivityType: ActivityType.swimming,
    );
    DebugLogger.info('🏊 MACRO SERVICE: Edge function returned, caching targets...');

    await _cacheMacroTargets(macroTargets);
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
    DebugLogger.info('🏊 MACRO SERVICE: Analytics tracked, returning macro targets');

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
  }) async {
    final userProfile = await authService.getCurrentUser();
    final userMetrics = _getUserMetrics(userProfile);

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
      'time_before_run_min': timeBeforeRunMinutes,
      'gut_training': userProfile?.gutTraining.name ?? gutTraining.name,
      'carb_source': 'dual',
      'sweat_sodium': 'medium',
      'drink_sodium_mg_per_l': 500,
      'optional_sweat_rate_lph': null,
      'sweat_rate_category': sweatRateCat?.name ?? 'medium',
      'temp_c': temperatureC,
      'humidity_pct': humidityPct,
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
  }) async {
    final userProfile = await authService.getCurrentUser();
    final userMetrics = _getUserMetrics(userProfile);

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
      'time_before_min': timeBeforeMinutes,
      'gut_training': userProfile?.gutTraining.name ?? 'moderate',
      if (elevationGainFt != null) 'elevation_gain_ft': elevationGainFt,
      if (intensityTarget != null) 'intensity_target': intensityTarget,
      if (sessionGoal != null) 'session_goal': sessionGoal,
      if (temperatureC != null) 'temp_c': temperatureC,
      if (humidityPct != null) 'humidity_pct': humidityPct,
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
  }) async {
    final userProfile = await authService.getCurrentUser();
    final userMetrics = _getUserMetrics(userProfile);

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
      'time_before_min': timeBeforeMinutes,
      if (intensityTarget != null) 'intensity_target': intensityTarget,
      if (sessionGoal != null) 'session_goal': sessionGoal,
      if (waterTempC != null) 'water_temp_c': waterTempC,
    };
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
  }) async {
    DebugLogger.info('🌐 EDGE FUNCTION: Calling generate-macros for ${expectedActivityType.name}...');
    DebugLogger.info('📤 EDGE FUNCTION: Request payload: ${requestData.toString().substring(0, 200)}...');

    final response = await supabaseClient.functions.invoke(
      'generate-macros',
      body: requestData,
    );

    DebugLogger.info('📥 EDGE FUNCTION: Response status: ${response.status}');

    if (response.status >= 400) {
      final data = response.data as Map<String, dynamic>?;
      final errorMessage = data?['message'] ?? 'Failed to generate macro targets';
      DebugLogger.error('❌ EDGE FUNCTION: HTTP error ${response.status}: $errorMessage');
      throw Exception(errorMessage);
    }

    final data = response.data as Map<String, dynamic>;
    DebugLogger.info('📊 EDGE FUNCTION: Response data keys: ${data.keys.toList()}');

    if (data['success'] != true) {
      final errorMessage = data['message'] ?? 'Failed to generate macro targets';
      DebugLogger.error('❌ EDGE FUNCTION: Success=false: $errorMessage');
      throw Exception(errorMessage);
    }

    final macrosData = data['macros'] as Map<String, dynamic>;
    final activityTypeString = data['activity_type'] as String? ?? expectedActivityType.name;
    DebugLogger.info('✅ EDGE FUNCTION: Got macros data with ${macrosData.keys.length} keys');

    ActivityType activityType = expectedActivityType;
    try {
      activityType = ActivityType.values.byName(activityTypeString);
    } catch (e) {
      DebugLogger.warning('⚠️ EDGE FUNCTION: Could not parse activity type "$activityTypeString", using $expectedActivityType');
    }

    final macroTargets = _parseMacroTargets(macrosData, activityType);
    DebugLogger.info('✅ EDGE FUNCTION: Successfully parsed macro targets - preRun carbs: ${macroTargets.preRun.carbsG}g, total burn: ${macroTargets.metrics.caloriesNetKcal}kcal');

    return macroTargets;
  }

  MacroTargets _parseMacroTargets(Map<String, dynamic> macrosData, ActivityType activityType) {

    return MacroTargets(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      activityType: activityType,
      preRun: PreRunMacros(
        carbsG: _toDouble(macrosData['pre_run_carbs_g'], 'pre_run_carbs_g'),
        proteinG: _toDouble(macrosData['pre_run_protein_g_optional'], 'pre_run_protein_g_optional'),
        fatCapG: _toDouble(macrosData['pre_run_fat_g_cap'], 'pre_run_fat_g_cap'),
        fluidsMl: _toDouble(macrosData['pre_run_water_ml'], 'pre_run_water_ml'),
        sodiumMg: _toDouble(macrosData['pre_run_sodium_mg'], 'pre_run_sodium_mg'),
      ),
      duringRun: DuringRunMacros(
        carbRateGPerH: _toDouble(macrosData['during_rate_g_per_h'], 'during_rate_g_per_h'),
        carbTotalG: _toDouble(macrosData['during_total_g'], 'during_total_g'),
        fluidRateMlPerH: _toDouble(macrosData['during_water_rate_ml_per_h'], 'during_water_rate_ml_per_h'),
        fluidTotalMl: _toDouble(macrosData['during_water_total_ml'], 'during_water_total_ml'),
        sodiumRateMgPerH: _toDouble(macrosData['during_sodium_rate_mg_per_h'], 'during_sodium_rate_mg_per_h'),
        sodiumTotalMg: _toDouble(macrosData['during_sodium_total_mg'], 'during_sodium_total_mg'),
        massNormRateGPerH: _toDouble(macrosData['during_mass_norm_rate_g_per_h'], 'during_mass_norm_rate_g_per_h'),
        absClampRangeGPerH: _toDoubleList(macrosData['during_abs_clamp_range_g_per_h']),
      ),
      postRun: PostRunMacros(
        carbsG: _toDouble(macrosData['post_run_carbs_g'], 'post_run_carbs_g'),
        proteinG: _toDouble(macrosData['post_run_protein_g'], 'post_run_protein_g'),
        fluidsMl: _toDouble(macrosData['post_run_water_ml'], 'post_run_water_ml'),
        sodiumMg: _toDouble(macrosData['post_run_sodium_mg'], 'post_run_sodium_mg'),
      ),
      metrics: RunMetrics(
        distanceMi: _toDouble(macrosData['distance_mi'], 'distance_mi'),
        distanceKm: _toDouble(macrosData['distance_km'], 'distance_km'),
        durationH: _toDouble(macrosData['duration_h'], 'duration_h'),
        durationMin: _toDouble(macrosData['duration_min'], 'duration_min'),
        paceMinPerMile: macrosData['pace_min_per_mile'] != null &&
                _toDouble(macrosData['pace_min_per_mile'], 'pace_min_per_mile') > 0
            ? _toDouble(macrosData['pace_min_per_mile'], 'pace_min_per_mile')
            : null,
        speedMph: _toDouble(macrosData['speed_mph'], 'speed_mph'),
        caloriesNetKcal: _toDouble(macrosData['calories_net_kcal'], 'calories_net_kcal'),
        caloriesGrossKcal: _toDouble(macrosData['calories_gross_kcal'], 'calories_gross_kcal'),
        met: _toDouble(macrosData['MET'], 'MET'),
      ),
      calculationRule: macrosData['pre_run_carbs_rule'] ?? 'Generated from edge function',
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

  List<double> _toDoubleList(dynamic value, [List<double> defaultValue = const [30, 60]]) {
    if (value == null) return defaultValue;
    if (value is List) {
      return value.map((e) => _toDouble(e)).toList();
    }
    return defaultValue;
  }

  Future<void> _cacheMacroTargets(MacroTargets macroTargets) async {
    final repository = await macroRepository;
    await repository.saveMacroTargets(macroTargets);
  }

  int _calculateTotalCarbs(MacroTargets macroTargets) {
    return (macroTargets.preRun.carbsG +
            macroTargets.duringRun.carbTotalG +
            macroTargets.postRun.carbsG)
        .round();
  }
}
