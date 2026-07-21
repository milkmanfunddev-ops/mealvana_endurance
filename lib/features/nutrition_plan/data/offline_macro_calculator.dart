import 'dart:math' as math;

/// Offline calculator for macro recommendations when edge function is unavailable.
///
/// Math mirrors the generate-macros-v4 Supabase edge function exactly:
///   supabase/functions/generate-macros-v4/single-sport.ts
///   supabase/functions/generate-macros-v4/pre-workout.ts
///
/// Hydration & sodium (lines below the HYDRATION section header) were already
/// correct and are NOT changed by this update.
class OfflineMacroCalculator {
  static const double _miToKm = 1.60934;
  static const double _mlToFlOz = 0.033814;
  static const double _mphToMPerMin = 26.8224;

  // ============================================================================
  // DURATION CARB BANDS (mirrors getDurationCarbBand in single-sport.ts)
  // ============================================================================

  /// Returns [baseLow, baseHigh] g/hr raw band for a given duration in minutes.
  static List<int> getDurationCarbBand(double durationMin) {
    if (durationMin < 60) return [0, 30];
    if (durationMin < 90) return [30, 60];
    if (durationMin < 150) return [45, 60];
    if (durationMin < 240) return [60, 90];
    return [80, 100];
  }

  /// Gut-training multiplier (mirrors getGutTrainingMultiplier).
  static double getGutTrainingMultiplier(String gutTraining) {
    switch (gutTraining) {
      case 'low':
        return 0.7;
      case 'high':
        return 1.2;
      default:
        return 1.0; // 'moderate' or unknown
    }
  }

  /// Sport carb ceiling g/hr (mirrors getSportCarbCeiling).
  static int getSportCarbCeiling(String activityType) {
    switch (activityType) {
      case 'running':
        return 70;
      case 'cycling':
        return 120;
      case 'swimming':
        return 0;
      default:
        return 70;
    }
  }

  /// Calculate during-workout carb rate (mirrors calculateDuringWorkoutCarbRate).
  ///
  /// Returns a map with keys matching the edge-function response shape:
  ///   rate_gph, band_low, band_high, raw_band_low, raw_band_high,
  ///   gut_multiplier, sport_ceiling.
  static Map<String, dynamic> calculateDuringWorkoutCarbRate({
    required double durationMin,
    required String activityType,
    required String gutTraining,
  }) {
    final band = getDurationCarbBand(durationMin);
    final baseLow = band[0].toDouble();
    final baseHigh = band[1].toDouble();
    final gutMult = getGutTrainingMultiplier(gutTraining);
    final scaledLow = baseLow * gutMult;
    final scaledHigh = baseHigh * gutMult;
    final carbRate = (scaledLow + scaledHigh) / 2.0;
    final sportCeiling = getSportCarbCeiling(activityType);
    final finalRate = math.min(carbRate, sportCeiling.toDouble());

    return {
      'rate_gph': (finalRate * 10).round() / 10.0,
      'band_low': scaledLow.round(),
      'band_high': scaledHigh.round(),
      'raw_band_low': baseLow.round(),
      'raw_band_high': baseHigh.round(),
      'gut_multiplier': gutMult,
      'sport_ceiling': sportCeiling,
    };
  }

  // ============================================================================
  // PRE-WORKOUT TARGETS (mirrors calculatePreWorkoutTargets in pre-workout.ts)
  // ============================================================================

  /// Calculate pre-workout macro targets with low/high ranges.
  ///
  /// Algorithm C (V4):
  ///   - fasted  → all zeros, meal_type='fasted'
  ///   - carbs   = max(0.5, min(hoursBefore, 4.0)) g/kg, ±12.5% band
  ///   - full_meal  (≥2.5h): protein=0.25g/kg [0.15–0.35], fat=0.4g/kg
  ///   - snack      (1–2.5h): protein=0.15g/kg [0–0.25], fat=5g
  ///   - top_up     (<1h):    protein=0 [0–10g], fat=0
  static Map<String, dynamic> calculatePreWorkoutTargets({
    required double weightKg,
    required double hoursBefore,
    required bool isFasted,
    String sweatSodiumCat = 'average',
    String envLabel = 'normal',
  }) {
    if (isFasted) {
      return {
        'carbs_g': 0,
        'carbs_low_g': 0,
        'carbs_high_g': 0,
        'protein_g': 0,
        'protein_low_g': 0,
        'protein_high_g': 0,
        'fat_g': 0,
        'sodium_mg': 0,
        'sodium_low_mg': 0,
        'sodium_high_mg': 0,
        'water_ml': 0,
        'water_low_ml': 0,
        'water_high_ml': 0,
        'meal_type': 'fasted',
      };
    }

    // Carbs: 1 g/kg per hour, capped at 4h, floor 0.5
    final carbPerKg = math.max(0.5, math.min(hoursBefore, 4.0));
    final carbs = (weightKg * carbPerKg).round();
    final carbsLow = (carbs * 0.875).round();
    final carbsHigh = (carbs * 1.125).round();

    // Sodium base by sweat category
    final baseSodium = sweatSodiumCat == 'low'
        ? 300
        : sweatSodiumCat == 'medium'
        ? 450
        : 600;
    final envBump = (envLabel == 'hot' || envLabel == 'very_hot') ? 100 : 0;
    final mealSodium = baseSodium + envBump;
    final snackSodium = ((baseSodium + envBump) * 0.5).round();
    final topUpSodium = envBump + 100;

    int protein;
    int proteinLow;
    int proteinHigh;
    int fat;
    int sodium;
    int sodiumLow;
    int sodiumHigh;
    int hydration;
    int hydrationLow;
    int hydrationHigh;
    String mealType;

    if (hoursBefore >= 2.5) {
      // Full meal
      protein = (weightKg * 0.25).round();
      proteinLow = (weightKg * 0.15).round();
      proteinHigh = (weightKg * 0.35).round();
      fat = (weightKg * 0.4).round();
      sodium = mealSodium + snackSodium + topUpSodium;
      hydration = (weightKg * 6.5).round();
      mealType = 'full_meal';
      sodiumLow = 200;
      sodiumHigh = 2000;
      hydrationLow = math.max(200, (hydration * 0.50).round());
      hydrationHigh = math.max(600, (hydration * 1.50).round());
    } else if (hoursBefore >= 1.0) {
      // Snack
      protein = (weightKg * 0.15).round();
      proteinLow = 0;
      proteinHigh = (weightKg * 0.25).round();
      fat = 5;
      sodium = snackSodium + topUpSodium;
      hydration = (weightKg * 5.5).round();
      mealType = 'snack';
      sodiumLow = 100;
      sodiumHigh = 1000;
      hydrationLow = math.max(150, (hydration * 0.50).round());
      hydrationHigh = math.max(500, (hydration * 1.50).round());
    } else {
      // Top-up
      protein = 0;
      proteinLow = 0;
      proteinHigh = 10;
      fat = 0;
      sodium = topUpSodium;
      hydration = 250;
      mealType = 'top_up';
      sodiumLow = 0;
      sodiumHigh = 400;
      hydrationLow = 0;
      hydrationHigh = 500;
    }

    return {
      'carbs_g': carbs,
      'carbs_low_g': carbsLow,
      'carbs_high_g': carbsHigh,
      'protein_g': protein,
      'protein_low_g': proteinLow,
      'protein_high_g': proteinHigh,
      'fat_g': fat,
      'sodium_mg': sodium,
      'sodium_low_mg': sodiumLow,
      'sodium_high_mg': sodiumHigh,
      'water_ml': hydration,
      'water_low_ml': hydrationLow,
      'water_high_ml': hydrationHigh,
      'meal_type': mealType,
    };
  }

  // ============================================================================
  // POST-WORKOUT (mirrors post-workout functions in single-sport.ts)
  // ============================================================================

  /// Post-workout carbs (mirrors calculatePostWorkoutCarbs).
  static int calculatePostWorkoutCarbs({
    required double weightKg,
    required double durationH,
    required bool isFasted,
  }) {
    final durationMultiplier = durationH > 2 ? 1.2 : 1.0;
    final fastedMultiplier = isFasted ? 1.2 : 1.0;
    return (weightKg * durationMultiplier * fastedMultiplier).round();
  }

  /// Post-workout protein (mirrors calculatePostWorkoutProtein).
  static int calculatePostWorkoutProtein({
    required double weightKg,
    required double durationH,
    required bool isFasted,
  }) {
    double proteinPerKg;
    if (durationH <= 0.75) {
      proteinPerKg = 0.25;
    } else if (durationH <= 1.5) {
      proteinPerKg = 0.30;
    } else if (durationH <= 2.5) {
      proteinPerKg = 0.35;
    } else {
      proteinPerKg = 0.40;
    }
    if (isFasted) proteinPerKg += 0.05;
    return math.min(40, math.max(20, (weightKg * proteinPerKg).round()));
  }

  /// Post-workout fat (mirrors calculatePostWorkoutFat).
  static int calculatePostWorkoutFat(double weightKg) {
    return (weightKg * 0.2).round();
  }

  /// Post-workout hydration (mirrors calculatePostWorkoutHydration).
  ///
  /// Returns {sodium_mg, hydration_ml}.
  static Map<String, int> calculatePostWorkoutHydration({
    required double durationH,
    required double actualSweatRateLph,
    required int sodiumConcMgPerL,
    required int duringHydrationMl,
  }) {
    final totalSodiumLossMg = actualSweatRateLph * sodiumConcMgPerL * durationH;
    final duringSodiumMg =
        (actualSweatRateLph * sodiumConcMgPerL * 0.6 * durationH).round();
    final sodiumDeficitMg = totalSodiumLossMg - duringSodiumMg;
    final postSodiumMg = math.max(
      300,
      math.min(700, (sodiumDeficitMg * 0.5).round()),
    );
    final totalHydrationLossMl = actualSweatRateLph * 1000.0 * durationH;
    final hydrationDeficitMl = totalHydrationLossMl - duringHydrationMl;
    final postHydrationMl = math.max(500, (hydrationDeficitMl * 1.5).round());

    return {'sodium_mg': postSodiumMg, 'hydration_ml': postHydrationMl};
  }

  // ============================================================================
  // MET & ENERGY (mirrors MET/energy functions in single-sport.ts)
  // ============================================================================

  /// Running MET from pace in min/mile (mirrors runningMETFromPace).
  static double runningMETFromPace(double paceMinPerMile) {
    final speedMph = 60.0 / paceMinPerMile;
    final speedMPerMin = speedMph * _mphToMPerMin;
    final vo2 = speedMph >= 4.0
        ? 0.2 * speedMPerMin + 3.5
        : 0.1 * speedMPerMin + 3.5;
    return vo2 / 3.5;
  }

  /// Cycling MET from speed (mirrors cyclingMETFromSpeed).
  static double cyclingMETFromSpeed(double speedKph, String terrain) {
    double met;
    if (speedKph <= 16) {
      met = 6.0;
    } else if (speedKph <= 19) {
      met = 8.0;
    } else if (speedKph <= 22) {
      met = 10.0;
    } else if (speedKph <= 25) {
      met = 12.0;
    } else if (speedKph <= 30) {
      met = 14.0;
    } else {
      met = 16.0;
    }
    if (terrain == 'rolling') {
      met *= 1.1;
    } else if (terrain == 'hilly') {
      met *= 1.25;
    }
    return met;
  }

  /// Swimming MET from pace (mirrors swimmingMETFromPace).
  static double swimmingMETFromPace({
    required double pacePer100m,
    required String poolOrOpenWater,
    required double waterTempC,
  }) {
    double met;
    if (pacePer100m >= 180) {
      met = 6.0;
    } else if (pacePer100m >= 150) {
      met = 8.0;
    } else if (pacePer100m >= 120) {
      met = 10.0;
    } else if (pacePer100m >= 90) {
      met = 11.0;
    } else {
      met = 13.0;
    }
    if (poolOrOpenWater == 'open_water') met *= 1.15;
    if (waterTempC < 20) {
      met *= 1.1;
    } else if (waterTempC > 28) {
      met *= 0.95;
    }
    return met;
  }

  /// Gross calories (mirrors calculateGrossCalories).
  static int calculateGrossCalories({
    required double weightKg,
    required double durationMin,
    required double met,
  }) {
    return (met * 3.5 * weightKg / 200.0 * durationMin).round();
  }

  /// Net calories (mirrors calculateNetCalories).
  static int calculateNetCalories({
    required String activityType,
    required double weightKg,
    required double distanceKm,
    double? speedKph,
  }) {
    if (activityType == 'running') {
      return (1.0 * weightKg * distanceKm).round();
    } else if (activityType == 'cycling') {
      final speed = speedKph ?? 25.0;
      double costPerKgKm;
      if (speed <= 20) {
        costPerKgKm = 0.3;
      } else if (speed <= 25) {
        costPerKgKm = 0.35;
      } else if (speed <= 30) {
        costPerKgKm = 0.4;
      } else {
        costPerKgKm = 0.5;
      }
      return (weightKg * distanceKm * costPerKgKm).round();
    } else if (activityType == 'swimming') {
      return (3.5 * weightKg * distanceKm).round();
    }
    return (1.0 * weightKg * distanceKm).round();
  }

  // ============================================================================
  // SPORT ENTRY POINTS — produce a Map<String, dynamic> matching the edge
  // function's `macros` response object so _parseMacroTargets() can parse it
  // without modification.
  // ============================================================================

  /// Backward-compatible entry point used by the legacy [MacroRepository]
  /// offline path. Parses the string/unit inputs and delegates to the
  /// server-parity [calculateRunningMacros], returning the legacy
  /// `{success, macros}` envelope.
  static Map<String, dynamic> calculateMacros({
    required double weight,
    required String weightUnit,
    required double height, // kept for API compatibility (unused)
    required String heightUnit, // kept for API compatibility (unused)
    required double runDistance,
    required String distanceUnit,
    required String runPace,
    required String paceUnit,
    required double timeBeforeRunMin,
    required String gutTraining,
    required int age, // kept for API compatibility (unused)
    required String gender, // kept for API compatibility (unused)
    bool isFasted = false,
  }) {
    final weightKg = weightUnit.toLowerCase() == 'kg'
        ? weight
        : weight * 0.45359237;
    final distanceMiles = distanceUnit.toLowerCase().startsWith('k')
        ? runDistance / _miToKm
        : runDistance;
    final paceMinPerMile = _parsePaceToMinPerMile(runPace, paceUnit);
    final macros = calculateRunningMacros(
      weightKg: weightKg,
      distanceMiles: distanceMiles,
      paceMinPerMile: paceMinPerMile,
      hoursBefore: timeBeforeRunMin / 60.0,
      isFasted: isFasted,
      gutTraining: gutTraining,
    );
    return {'success': true, 'macros': macros};
  }

  /// Parse a pace string (`"MM:SS"` or decimal minutes) plus its unit into
  /// minutes-per-mile.
  static double _parsePaceToMinPerMile(String pace, String unit) {
    double minutes;
    if (pace.contains(':')) {
      final parts = pace.split(':');
      minutes =
          (double.tryParse(parts[0].trim()) ?? 0) +
          (double.tryParse(parts.length > 1 ? parts[1].trim() : '0') ?? 0) /
              60.0;
    } else {
      minutes = double.tryParse(pace.trim()) ?? 0;
    }
    // min/km → min/mile
    if (unit.toLowerCase().contains('km')) minutes *= _miToKm;
    return minutes;
  }

  /// Offline fallback for running macro calculation.
  static Map<String, dynamic> calculateRunningMacros({
    required double weightKg,
    required double distanceMiles,
    required double paceMinPerMile,
    required double hoursBefore,
    required bool isFasted,
    required String gutTraining,
    String sweatRateCategory = 'medium',
    String sweatSodiumCat = 'average',
    double? tempC,
    double? humidityPct,
    bool isIndoor = false,
    double? knownSweatRateMlPerHour,
    double? knownSodiumConcMgPerL,
  }) {
    const activityType = 'running';
    final distanceKm = distanceMiles * _miToKm;
    final durationMin = distanceMiles * paceMinPerMile;
    final durationH = durationMin / 60.0;
    final speedKph = (60.0 / paceMinPerMile) * _miToKm;
    final met = runningMETFromPace(paceMinPerMile);

    return _buildMacrosMap(
      activityType: activityType,
      weightKg: weightKg,
      distanceKm: distanceKm,
      durationMin: durationMin,
      durationH: durationH,
      met: met,
      speedKph: speedKph,
      hoursBefore: hoursBefore,
      isFasted: isFasted,
      gutTraining: gutTraining,
      sweatRateCategory: sweatRateCategory,
      sweatSodiumCat: sweatSodiumCat,
      tempC: tempC,
      humidityPct: humidityPct,
      isIndoor: isIndoor,
      knownSweatRateMlPerHour: knownSweatRateMlPerHour,
      knownSodiumConcMgPerL: knownSodiumConcMgPerL,
    );
  }

  /// Offline fallback for cycling macro calculation.
  static Map<String, dynamic> calculateCyclingMacros({
    required double weightKg,
    required double distanceMiles,
    required double speedMph,
    required String terrain,
    required double hoursBefore,
    required bool isFasted,
    required String gutTraining,
    String sweatRateCategory = 'medium',
    String sweatSodiumCat = 'average',
    double? tempC,
    double? humidityPct,
    bool isIndoor = false,
    double? knownSweatRateMlPerHour,
    double? knownSodiumConcMgPerL,
  }) {
    const activityType = 'cycling';
    final distanceKm = distanceMiles * _miToKm;
    final speedKph = speedMph * _miToKm;
    final durationMin = (distanceMiles / speedMph) * 60.0;
    final durationH = durationMin / 60.0;
    final met = cyclingMETFromSpeed(speedKph, terrain);

    return _buildMacrosMap(
      activityType: activityType,
      weightKg: weightKg,
      distanceKm: distanceKm,
      durationMin: durationMin,
      durationH: durationH,
      met: met,
      speedKph: speedKph,
      hoursBefore: hoursBefore,
      isFasted: isFasted,
      gutTraining: gutTraining,
      sweatRateCategory: sweatRateCategory,
      sweatSodiumCat: sweatSodiumCat,
      tempC: tempC,
      humidityPct: humidityPct,
      isIndoor: isIndoor,
      knownSweatRateMlPerHour: knownSweatRateMlPerHour,
      knownSodiumConcMgPerL: knownSodiumConcMgPerL,
    );
  }

  /// Offline fallback for swimming macro calculation.
  static Map<String, dynamic> calculateSwimmingMacros({
    required double weightKg,
    required int distanceMeters,
    required int paceSecondsper100m,
    required String poolOrOpenWater,
    required double hoursBefore,
    String sweatRateCategory = 'medium',
    String sweatSodiumCat = 'average',
    double waterTempC = 26.0,
    double? knownSweatRateMlPerHour,
    double? knownSodiumConcMgPerL,
  }) {
    const activityType = 'swimming';
    final distanceKm = distanceMeters / 1000.0;
    final durationMin = (distanceMeters / 100.0) * paceSecondsper100m / 60.0;
    final durationH = durationMin / 60.0;
    final met = swimmingMETFromPace(
      pacePer100m: paceSecondsper100m.toDouble(),
      poolOrOpenWater: poolOrOpenWater,
      waterTempC: waterTempC,
    );
    // Pool = indoor for sweat-rate purposes
    final isIndoor = poolOrOpenWater == 'pool';

    return _buildMacrosMap(
      activityType: activityType,
      weightKg: weightKg,
      distanceKm: distanceKm,
      durationMin: durationMin,
      durationH: durationH,
      met: met,
      speedKph: null,
      // Swimming doesn't support fasted in the service, always false
      hoursBefore: hoursBefore,
      isFasted: false,
      gutTraining: 'moderate',
      sweatRateCategory: sweatRateCategory,
      sweatSodiumCat: sweatSodiumCat,
      tempC: null,
      humidityPct: null,
      isIndoor: isIndoor,
      knownSweatRateMlPerHour: knownSweatRateMlPerHour,
      knownSodiumConcMgPerL: knownSodiumConcMgPerL,
    );
  }

  // ============================================================================
  // SHARED BUILD HELPER
  // ============================================================================

  static Map<String, dynamic> _buildMacrosMap({
    required String activityType,
    required double weightKg,
    required double distanceKm,
    required double durationMin,
    required double durationH,
    required double met,
    required double? speedKph,
    required double hoursBefore,
    required bool isFasted,
    required String gutTraining,
    required String sweatRateCategory,
    required String sweatSodiumCat,
    required double? tempC,
    required double? humidityPct,
    required bool isIndoor,
    required double? knownSweatRateMlPerHour,
    required double? knownSodiumConcMgPerL,
  }) {
    // Pre-workout targets
    final pre = calculatePreWorkoutTargets(
      weightKg: weightKg,
      hoursBefore: hoursBefore,
      isFasted: isFasted,
      sweatSodiumCat: sweatSodiumCat,
    );

    // During-workout carbs
    final duringCarbs = calculateDuringWorkoutCarbRate(
      durationMin: durationMin,
      activityType: activityType,
      gutTraining: gutTraining,
    );
    final duringCarbRate = (duringCarbs['rate_gph'] as num).toDouble();
    final duringCarbTotal = (duringCarbRate * durationH).round();

    // During-workout hydration
    final duringHydration = calculateDuringWorkoutHydration(
      durationMin: durationMin,
      weightKg: weightKg,
      sweatRateCategory: sweatRateCategory,
      sweatSodiumCat: sweatSodiumCat,
      tempC: tempC,
      humidityPct: humidityPct,
      isIndoor: isIndoor,
      sport: activityType,
      knownSweatRateMlPerHour: knownSweatRateMlPerHour,
      knownSodiumConcMgPerL: knownSodiumConcMgPerL,
    );

    // Post-workout
    final postCarbs = calculatePostWorkoutCarbs(
      weightKg: weightKg,
      durationH: durationH,
      isFasted: isFasted,
    );
    final postProtein = calculatePostWorkoutProtein(
      weightKg: weightKg,
      durationH: durationH,
      isFasted: isFasted,
    );
    final postFat = calculatePostWorkoutFat(weightKg);
    final postHydration = calculatePostWorkoutHydration(
      durationH: durationH,
      actualSweatRateLph: duringHydration.sweatRateLph,
      sodiumConcMgPerL: duringHydration.sodiumConcMgPerL,
      duringHydrationMl: duringHydration.hydrationTotalMl,
    );

    // Energy
    final caloriesGross = calculateGrossCalories(
      weightKg: weightKg,
      durationMin: durationMin,
      met: met,
    );
    final caloriesNet = calculateNetCalories(
      activityType: activityType,
      weightKg: weightKg,
      distanceKm: distanceKm,
      speedKph: speedKph,
    );

    // Low/high bands
    final bandLow = duringCarbs['band_low'] as int;
    final bandHigh = duringCarbs['band_high'] as int;
    final postCarbsLow = (postCarbs * 0.8).round();
    final postCarbsHigh = (postCarbs * 1.2).round();
    final postProteinLow = (postProtein * 0.8).round();
    final postProteinHigh = (postProtein * 1.2).round();
    final postSodium = postHydration['sodium_mg']!;
    final postSodiumLow = (postSodium * 0.7).round();
    final postSodiumHigh = (postSodium * 1.3).round();
    final postWater = postHydration['hydration_ml']!;
    final postWaterLow = (postWater * 0.8).round();
    final postWaterHigh = (postWater * 1.2).round();

    final durSodiumRate = duringHydration.sodiumRateMgph;
    final durSodium = (durSodiumRate * durationH).round();
    final durWaterRate = duringHydration.hydrationRateMlph;
    final durWater = (durWaterRate * durationH).round();

    final massNormRate = weightKg > 0
        ? (duringCarbRate / weightKg * 100).round() / 100.0
        : 0.0;

    return {
      'success': true,
      'algorithm_version': 'v4_offline',
      'activity_type': activityType,
      // Duration & distance
      'duration_min': (durationMin * 100).round() / 100.0,
      'duration_h': (durationH * 10000).round() / 10000.0,
      'distance_km': (distanceKm * 1000).round() / 1000.0,
      // Energy
      'calories_gross_kcal': caloriesGross,
      'calories_net_kcal': caloriesNet,
      'MET': (met * 100).round() / 100.0,
      // Pre-workout
      'pre_run_carbs_g': pre['carbs_g'],
      'pre_run_carbs_low_g': pre['carbs_low_g'],
      'pre_run_carbs_high_g': pre['carbs_high_g'],
      'pre_run_protein_g': pre['protein_g'],
      'pre_run_protein_low_g': pre['protein_low_g'],
      'pre_run_protein_high_g': pre['protein_high_g'],
      'pre_run_fat_g': pre['fat_g'],
      'pre_run_sodium_mg': pre['sodium_mg'],
      'pre_run_sodium_low_mg': pre['sodium_low_mg'],
      'pre_run_sodium_high_mg': pre['sodium_high_mg'],
      'pre_run_water_ml': pre['water_ml'],
      'pre_run_water_low_ml': pre['water_low_ml'],
      'pre_run_water_high_ml': pre['water_high_ml'],
      'pre_run_meal_type': pre['meal_type'],
      'pre_run_carbs_rule': 'offline_fallback',
      'pre_run_hydration_tier': null,
      'pre_run_selections': null,
      // During-workout
      'during_rate_g_per_h': duringCarbRate,
      'during_total_g': duringCarbTotal,
      'during_band_low_g_per_h': bandLow,
      'during_band_high_g_per_h': bandHigh,
      'during_raw_band_low_g_per_h': duringCarbs['raw_band_low'],
      'during_raw_band_high_g_per_h': duringCarbs['raw_band_high'],
      'during_gut_multiplier': duringCarbs['gut_multiplier'],
      'during_sport_ceiling_g_per_h': duringCarbs['sport_ceiling'],
      'during_sodium_rate_mg_per_h': durSodiumRate,
      'during_sodium_total_mg': durSodium,
      'during_sodium_low_mg': (durSodium * 0.8).round(),
      'during_sodium_high_mg': (durSodium * 1.2).round(),
      'during_water_rate_ml_per_h': durWaterRate,
      'during_water_total_ml': durWater,
      'during_water_low_ml': (durWater * 0.85).round(),
      'during_water_high_ml': (durWater * 1.15).round(),
      'during_mass_norm_rate_g_per_h': massNormRate,
      'during_abs_clamp_range_g_per_h': [bandLow, bandHigh],
      // Post-workout
      'post_run_carbs_g': postCarbs,
      'post_run_carbs_low_g': postCarbsLow,
      'post_run_carbs_high_g': postCarbsHigh,
      'post_run_protein_g': postProtein,
      'post_run_protein_low_g': postProteinLow,
      'post_run_protein_high_g': postProteinHigh,
      'post_run_fat_g': postFat,
      'post_run_sodium_mg': postSodium,
      'post_run_sodium_low_mg': postSodiumLow,
      'post_run_sodium_high_mg': postSodiumHigh,
      'post_run_water_ml': postWater,
      'post_run_water_low_ml': postWaterLow,
      'post_run_water_high_ml': postWaterHigh,
      // Hydration detail
      'sweat_rate_lph': duringHydration.sweatRateLph,
      'sodium_conc_mg_per_l': duringHydration.sodiumConcMgPerL,
      'effective_sweat_rate_lph': duringHydration.effectiveSweatRateLph,
      'replacement_pct': duringHydration.replacementPct,
      'floor_ml_hr': duringHydration.floorMlHr,
      'ceiling_ml_hr': duringHydration.ceilingMlHr,
      'safety_flags': duringHydration.safetyFlags,
      'is_tested': duringHydration.isTested,
      'is_tested_sodium': false,
      'temp_c': tempC,
      'humidity_pct': humidityPct,
      'is_indoor': isIndoor,
    };
  }

  static double _clamp(double value, double min, double max) {
    return math.max(min, math.min(max, value));
  }

  /// Convert ml to fl oz for display
  static double mlToFlOz(double ml) => ml * _mlToFlOz;

  /// Convert fl oz to ml for storage
  static double flOzToMl(double flOz) => flOz / _mlToFlOz;

  // ===========================================================================
  // HYDRATION & SODIUM — Dart mirror of generate-macros-v4 edge function
  //
  // Sources:
  //   supabase/functions/_shared/nutrition/sweat-hydration.ts
  //   supabase/functions/generate-macros-v4/single-sport.ts
  //   supabase/functions/generate-macros-v4/pre-workout.ts
  //   supabase/functions/generate-macros-v4/brick-workout.ts
  //
  // These functions are pure / dependency-free (no HTTP, no Riverpod, no async).
  // They mirror the edge-function algorithm exactly so offline output matches
  // what the server would return.
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // Constants (mirrors sweat-hydration.ts)
  // ---------------------------------------------------------------------------

  static const Map<String, double> _sweatRateLph = {
    'light': 0.90,
    'medium': 1.28,
    'heavy': 1.66,
  };

  static const Map<String, int> _sodiumConcMgPerL = {
    'low': 650,
    'average': 825,
    'medium': 825, // legacy alias for 'average'
    'high': 1000,
  };

  static const double swimmingSweatModifier = 0.4;

  static const double _tempBaselineC = 22.0;
  static const double _tempCoefficient = 0.04;
  static const double _tempMultMin = 0.50;
  static const double _tempMultMax = 1.80;

  static const double _humidityBaselinePct = 50.0;
  static const double _humidityCoefficient = 0.002;
  static const double _humidityMultMin = 1.0;
  static const double _humidityMultMax = 1.10;

  static const double _indoorMultiplier = 1.30;

  static const double _overallRateMin = 0.3;
  static const double _overallRateMax = 3.0;

  static const Map<String, int> _giCeilingMlHr = {
    'running': 800,
    'cycling': 1200,
    'swimming': 0,
  };

  static const int _transitionFluidMl = 300;

  // ---------------------------------------------------------------------------
  // Base lookups
  // ---------------------------------------------------------------------------

  /// Base sweat rate for a sweater category.
  /// LIGHT=0.90, MEDIUM=1.28, HEAVY=1.66 L/hr. Defaults to MEDIUM.
  static double baseSweatRateFromCategory(String category) {
    return _sweatRateLph[category.toLowerCase()] ?? _sweatRateLph['medium']!;
  }

  /// Sodium concentration for a loss category.
  /// LOW=650, AVERAGE=825 (medium alias), HIGH=1000 mg/L. Defaults to average.
  static int sodiumConcentrationFromCategory(String category) {
    return _sodiumConcMgPerL[category.toLowerCase()] ??
        _sodiumConcMgPerL['average']!;
  }

  // ---------------------------------------------------------------------------
  // Replacement % by total workout duration
  // ---------------------------------------------------------------------------

  /// Duration-scaled replacement percentage lookup.
  ///
  /// <60 min  → 0.30
  /// 60–90    → 0.50  (inclusive of 90, per Example 2)
  /// 91–150   → 0.60
  /// 151–239  → 0.70
  /// 240+     → 0.80
  static double replacementPctForDuration(double durationMin) {
    if (durationMin < 60) return 0.30;
    if (durationMin <= 90) return 0.50;
    if (durationMin <= 150) return 0.60;
    if (durationMin < 240) return 0.70;
    return 0.80;
  }

  // ---------------------------------------------------------------------------
  // Effective sweat rate
  // ---------------------------------------------------------------------------

  /// Calculate effective sweat rate in L/hr, mirroring the edge function.
  ///
  /// Formula:
  ///   base = knownSweatRateMlPerHour/1000  OR  sweatRateLph[baseCategory]
  ///   tempMult     = clamp(1.0 + (tempC - 22)*0.04, 0.50, 1.80)
  ///   humidityMult = clamp(1.0 + max(0, h-50)*0.002, 1.0, 1.10)
  ///   indoorMult   = 1.30 if isIndoor else 1.0
  ///   effective    = round3dp(clamp(base * tempMult * humidityMult * indoorMult, 0.3, 3.0))
  static double calculateActualSweatRate({
    required String baseCategory,
    double? tempC,
    double? humidityPct,
    bool isIndoor = false,
    double? knownSweatRateMlPerHour,
  }) {
    // Base rate: known rate overrides category base (but still gets multipliers)
    final baseRate = knownSweatRateMlPerHour != null
        ? knownSweatRateMlPerHour / 1000.0
        : baseSweatRateFromCategory(baseCategory);

    // Temperature multiplier (baseline 22°C)
    final t = tempC ?? _tempBaselineC;
    final rawTempMult = 1.0 + (t - _tempBaselineC) * _tempCoefficient;
    final tempMult = _clamp(rawTempMult, _tempMultMin, _tempMultMax);

    // Humidity multiplier (baseline 50%)
    final h = humidityPct ?? _humidityBaselinePct;
    final rawHumidityMult =
        1.0 + math.max(0.0, h - _humidityBaselinePct) * _humidityCoefficient;
    final humidityMult = _clamp(
      rawHumidityMult,
      _humidityMultMin,
      _humidityMultMax,
    );

    // Indoor multiplier
    final indoorMult = isIndoor ? _indoorMultiplier : 1.0;

    // Effective rate with overall clamp, rounded to 3 decimal places
    final rawRate = baseRate * tempMult * humidityMult * indoorMult;
    final clamped = _clamp(rawRate, _overallRateMin, _overallRateMax);
    return (clamped * 1000).round() / 1000.0;
  }

  // ---------------------------------------------------------------------------
  // During-workout hydration (single-sport)
  // ---------------------------------------------------------------------------

  /// Result from [calculateDuringWorkoutHydration].
  static const String _shortWorkoutGateFlag =
      'No structured hydration plan needed.';
  static const String _ceilingLtFloorFlag =
      'Even at maximum intake, you will exceed 2% BW loss.';

  /// Calculate during-workout hydration targets for a single-sport session.
  ///
  /// Returns a record with fields matching the edge-function result shape.
  static DuringWorkoutHydrationResult calculateDuringWorkoutHydration({
    required double durationMin,
    required double weightKg,
    required String sweatRateCategory,
    required String sweatSodiumCat,
    double? tempC,
    double? humidityPct,
    bool isIndoor = false,
    String sport = 'running',
    double? knownSweatRateMlPerHour,
    double? knownSodiumConcMgPerL,
  }) {
    final safetyFlags = <String>[];

    // Effective sweat rate
    final effectiveSweatRateLph = calculateActualSweatRate(
      baseCategory: sweatRateCategory,
      tempC: tempC,
      humidityPct: humidityPct,
      isIndoor: isIndoor,
      knownSweatRateMlPerHour: knownSweatRateMlPerHour,
    );
    final effectiveSweatRateMlph = effectiveSweatRateLph * 1000.0;

    // Sodium concentration
    final sodiumConcMgPerL =
        knownSodiumConcMgPerL?.round() ??
        sodiumConcentrationFromCategory(sweatSodiumCat);

    // Swim-only: no drinking possible
    if (sport.toLowerCase() == 'swimming') {
      return DuringWorkoutHydrationResult(
        hydrationRateMlph: 0,
        sodiumRateMgph: 0,
        hydrationTotalMl: 0,
        sodiumTotalMg: 0,
        sweatRateLph: effectiveSweatRateLph,
        sodiumConcMgPerL: sodiumConcMgPerL,
        effectiveSweatRateLph: effectiveSweatRateLph,
        replacementPct: 0,
        floorMlHr: 0,
        ceilingMlHr: 0,
        safetyFlags: const [],
        isTested: knownSweatRateMlPerHour != null,
      );
    }

    final durationH = durationMin / 60.0;
    final giCeiling = _giCeilingMlHr[sport.toLowerCase()] ?? 800;

    // Ceiling = min(sport GI, 100% sweat rate)
    final ceilingMlHr = math.min(giCeiling, effectiveSweatRateMlph).round();

    // Replacement % by total duration
    final replacementPct = replacementPctForDuration(durationMin);

    // Short-workout gate: duration < 60 AND temp < 30
    final temp = tempC ?? 22.0;
    final gateTriggered = durationMin < 60 && temp < 30.0;

    if (gateTriggered) {
      final recommended = (effectiveSweatRateMlph * replacementPct).round();
      safetyFlags.add(_shortWorkoutGateFlag);
      final sodiumRate = ((recommended / 1000.0) * sodiumConcMgPerL).round();
      return DuringWorkoutHydrationResult(
        hydrationRateMlph: recommended,
        sodiumRateMgph: sodiumRate,
        hydrationTotalMl: (recommended * durationH).round(),
        sodiumTotalMg: (sodiumRate * durationH).round(),
        sweatRateLph: effectiveSweatRateLph,
        sodiumConcMgPerL: sodiumConcMgPerL,
        effectiveSweatRateLph: effectiveSweatRateLph,
        replacementPct: replacementPct,
        floorMlHr: 0,
        ceilingMlHr: ceilingMlHr,
        safetyFlags: List.unmodifiable(safetyFlags),
        isTested: knownSweatRateMlPerHour != null,
      );
    }

    // Standard path
    // Total sweat loss over duration
    final totalLossMl = effectiveSweatRateMlph * durationH;

    // 2% BW floor
    final maxDeficitMl = weightKg * 1000.0 * 0.02;
    final rawFloorMlHr = (totalLossMl - maxDeficitMl) / durationH;
    final floorMlHr = math.max(0.0, rawFloorMlHr).round();

    // Pct-based recommendation
    final pctBasedMlHr = (effectiveSweatRateMlph * replacementPct).round();

    // Apply floor
    int recommendedMlHr = math.max(pctBasedMlHr, floorMlHr);

    // Apply ceiling
    if (ceilingMlHr < floorMlHr) {
      safetyFlags.add(_ceilingLtFloorFlag);
    }
    recommendedMlHr = math.min(recommendedMlHr, ceilingMlHr);

    // Safety check: realized deficit
    final totalIntakeMl = recommendedMlHr * durationH;
    final netDeficitMl = totalLossMl - totalIntakeMl;
    if (weightKg > 0) {
      final deficitPct = netDeficitMl / (weightKg * 1000.0);
      if (deficitPct > 0.03) {
        final pctStr = (deficitPct * 100).toStringAsFixed(1);
        safetyFlags.add('Significant dehydration expected (>$pctStr% BW).');
      }
    }

    final sodiumRateMgph = ((recommendedMlHr / 1000.0) * sodiumConcMgPerL)
        .round();

    return DuringWorkoutHydrationResult(
      hydrationRateMlph: recommendedMlHr,
      sodiumRateMgph: sodiumRateMgph,
      // Spec: hydrationTotalMl = fluid rate × duration (was incorrectly
      // using sodiumRateMgph, producing mg-in-ml unit confusion).
      hydrationTotalMl: (recommendedMlHr * durationH).round(),
      sodiumTotalMg: (sodiumRateMgph * durationH).round(),
      sweatRateLph: effectiveSweatRateLph,
      sodiumConcMgPerL: sodiumConcMgPerL,
      effectiveSweatRateLph: effectiveSweatRateLph,
      replacementPct: replacementPct,
      floorMlHr: floorMlHr,
      ceilingMlHr: ceilingMlHr,
      safetyFlags: List.unmodifiable(safetyFlags),
      isTested: knownSweatRateMlPerHour != null,
    );
  }

  // ---------------------------------------------------------------------------
  // Pre-workout hydration
  // ---------------------------------------------------------------------------

  /// Pre-workout hydration targets per spec tiers.
  ///
  /// Gate: workoutDurationMin < 60 AND tempC < 30 → no structured plan.
  ///
  /// Tier 1 (timeBeforeWorkoutMin >= 120):
  ///   fluid = BW×6 ml [BW×5 .. BW×7]; sodium = 450 mg [300 .. 600]
  /// Tier 2 (10 <= timeBeforeWorkoutMin < 120):
  ///   fluid = 250 ml [200 .. 300]; sodium = 150 mg [100 .. 200]
  /// Tier 3 (timeBeforeWorkoutMin < 10):
  ///   all zeros; message = "Too late for structured pre-hydration."
  static PreWorkoutHydrationResult calculatePreWorkoutHydration({
    required double bodyWeightKg,
    required double workoutDurationMin,
    required double timeBeforeWorkoutMin,
    double? tempC,
  }) {
    final temp = tempC ?? 22.0;

    // Gate: duration < 60 AND temp < 30
    final gateTriggered = workoutDurationMin < 60 && temp < 30.0;
    if (gateTriggered) {
      return const PreWorkoutHydrationResult(
        tier: 1,
        gateTriggered: true,
        fluidMl: 0,
        fluidLowMl: 0,
        fluidHighMl: 0,
        sodiumMg: 0,
        sodiumLowMg: 0,
        sodiumHighMg: 0,
        message:
            'No structured pre-hydration needed for short workouts in mild conditions.',
      );
    }

    // Tier 1
    if (timeBeforeWorkoutMin >= 120) {
      final fluid = (bodyWeightKg * 6).round();
      return PreWorkoutHydrationResult(
        tier: 1,
        gateTriggered: false,
        fluidMl: fluid,
        fluidLowMl: (bodyWeightKg * 5).round(),
        fluidHighMl: (bodyWeightKg * 7).round(),
        sodiumMg: 450,
        sodiumLowMg: 300,
        sodiumHighMg: 600,
        message: null,
      );
    }

    // Tier 2
    if (timeBeforeWorkoutMin >= 10) {
      return const PreWorkoutHydrationResult(
        tier: 2,
        gateTriggered: false,
        fluidMl: 250,
        fluidLowMl: 200,
        fluidHighMl: 300,
        sodiumMg: 150,
        sodiumLowMg: 100,
        sodiumHighMg: 200,
        message:
            'Not enough time for full protocol. Sip 250 ml steadily. consider hydrating well the evening before.',
      );
    }

    // Tier 3: too late
    return const PreWorkoutHydrationResult(
      tier: 3,
      gateTriggered: false,
      fluidMl: 0,
      fluidLowMl: 0,
      fluidHighMl: 0,
      sodiumMg: 0,
      sodiumLowMg: 0,
      sodiumHighMg: 0,
      message:
          'Too late for structured pre-hydration. Focus on your during-workout plan.',
    );
  }

  // ---------------------------------------------------------------------------
  // Brick hydration (multi-segment)
  // ---------------------------------------------------------------------------

  /// Segment descriptor for brick hydration calculation.
  /// [sport] is 'running' | 'cycling' | 'swimming'.
  /// [order] is the 0-based segment index (matches segment.order from the API).

  /// Calculate multi-segment (brick) hydration targets per spec.
  ///
  /// Mirrors calculateBrickHydration from brick-workout.ts exactly.
  static BrickHydrationResult calculateBrickHydration({
    required double weightKg,
    required List<BrickSegmentInput> segments,
    required String sweatRateCategory,
    required String sweatSodiumCat,
    double? tempC,
    double? humidityPct,
    bool isIndoor = false,
    double? knownSweatRateMlPerHour,
    double? knownSodiumConcMgPerL,
  }) {
    final safetyFlags = <String>[];

    // Effective sweat rate
    final effectiveSweatRateLph = calculateActualSweatRate(
      baseCategory: sweatRateCategory,
      tempC: tempC,
      humidityPct: humidityPct,
      isIndoor: isIndoor,
      knownSweatRateMlPerHour: knownSweatRateMlPerHour,
    );
    final effectiveSweatRateMlph = effectiveSweatRateLph * 1000.0;

    // Sodium concentration
    final sodiumConcMgPerL =
        knownSodiumConcMgPerL?.round() ??
        sodiumConcentrationFromCategory(sweatSodiumCat);

    // Total duration → replacement %
    final totalDurationMin = segments.fold<double>(
      0.0,
      (s, seg) => s + seg.durationMin,
    );
    final replacementPct = replacementPctForDuration(totalDurationMin);

    // Per-segment sweat losses (swim uses 0.4× modifier)
    double totalLossMl = 0.0;
    for (final seg in segments) {
      final durationH = seg.durationMin / 60.0;
      if (seg.sport.toLowerCase() == 'swimming') {
        totalLossMl +=
            effectiveSweatRateMlph * swimmingSweatModifier * durationH;
      } else {
        totalLossMl += effectiveSweatRateMlph * durationH;
      }
    }

    // Detect transitions
    final transitions = <_BrickTransitionRaw>[];
    for (int i = 0; i < segments.length - 1; i++) {
      final afterSport = segments[i].sport.toLowerCase();
      final beforeSport = segments[i + 1].sport.toLowerCase();
      String transitionName;
      if (afterSport == 'swimming' && beforeSport == 'cycling') {
        transitionName = 'T1';
      } else if (afterSport == 'cycling' && beforeSport == 'running') {
        transitionName = 'T2';
      } else {
        transitionName = 'T${i + 1}';
      }
      transitions.add(
        _BrickTransitionRaw(
          index: i,
          name: transitionName,
          afterSport: afterSport,
          beforeSport: beforeSport,
        ),
      );
    }

    final transitionCount = transitions.length;
    final totalTransitionFluidMl = transitionCount * _transitionFluidMl;

    // Required total based on replacement %
    final requiredTotalMl = totalLossMl * replacementPct;

    // Floor: covers deficit down to 2% BW
    final maxDeficitMl = weightKg * 1000.0 * 0.02;
    final rawFloorTotalMl = totalLossMl - maxDeficitMl;
    final floorTotalMl = math.max(0.0, rawFloorTotalMl);

    // Subtract transition intake
    final remainingRequired = math.max(
      0.0,
      requiredTotalMl - totalTransitionFluidMl,
    );
    final remainingFloor = math.max(0.0, floorTotalMl - totalTransitionFluidMl);

    // Drinkable hours: non-swim segments only
    final drinkableMinutes = segments
        .where((s) => s.sport.toLowerCase() != 'swimming')
        .fold<double>(0.0, (s, seg) => s + seg.durationMin);
    final drinkableHours = drinkableMinutes / 60.0;

    // Recommended ml/hr across drinkable segments
    int recommendedMlHr = drinkableHours > 0
        ? (remainingRequired / drinkableHours).round()
        : 0;
    final floorMlHr = drinkableHours > 0
        ? (remainingFloor / drinkableHours).round()
        : 0;

    // Apply floor
    recommendedMlHr = math.max(recommendedMlHr, floorMlHr);

    // Per-segment ceilings
    final segmentCeilings = <String, int>{
      'cycling': math
          .min(_giCeilingMlHr['cycling']!, effectiveSweatRateMlph)
          .round(),
      'running': math
          .min(_giCeilingMlHr['running']!, effectiveSweatRateMlph)
          .round(),
      'swimming': 0,
    };

    // Assign initial rates per segment, capped by segment ceiling
    final segmentRates = <int, int>{};
    for (final seg in segments) {
      final sport = seg.sport.toLowerCase();
      if (sport == 'swimming') {
        segmentRates[seg.order] = 0;
      } else {
        final ceiling = segmentCeilings[sport] ?? _giCeilingMlHr['running']!;
        segmentRates[seg.order] = math.min(recommendedMlHr, ceiling);
      }
    }

    // Run→bike redistribution
    final nonSwimSegs = segments
        .where((s) => s.sport.toLowerCase() != 'swimming')
        .toList();

    var redistributionFailed = false;
    for (final seg in nonSwimSegs) {
      if (seg.sport.toLowerCase() != 'running') continue;

      final runCeiling = segmentCeilings['running']!;
      if (floorMlHr > runCeiling) {
        // Shortfall from run
        final runDurationH = seg.durationMin / 60.0;
        final shortfallTotal = (floorMlHr - runCeiling) * runDurationH;

        // Distribute to bike segments
        final bikeSegs = nonSwimSegs
            .where((s) => s.sport.toLowerCase() == 'cycling')
            .toList();
        final totalBikeHours = bikeSegs.fold<double>(
          0.0,
          (s, b) => s + b.durationMin / 60.0,
        );

        if (totalBikeHours > 0) {
          final addPerHr = shortfallTotal / totalBikeHours;
          final bikeCeiling = segmentCeilings['cycling']!;
          for (final bikeSeg in bikeSegs) {
            final current = segmentRates[bikeSeg.order]!.toDouble();
            final newRate = math.min(
              current + addPerHr,
              bikeCeiling.toDouble(),
            );
            segmentRates[bikeSeg.order] = newRate.round();
          }
        }

        // Cap run at ceiling
        segmentRates[seg.order] = runCeiling;

        // Check if shortfall remains (compute actual intake)
        final actualBikeIntake = nonSwimSegs
            .where((s) => s.sport.toLowerCase() == 'cycling')
            .fold<double>(
              0.0,
              (s, b) => s + segmentRates[b.order]! * b.durationMin / 60.0,
            );
        final actualRunIntake = segmentRates[seg.order]! * runDurationH;
        final totalActualIntake =
            actualBikeIntake + actualRunIntake + totalTransitionFluidMl;
        final netDeficit = totalLossMl - totalActualIntake;

        if (netDeficit > maxDeficitMl) {
          redistributionFailed = true;
        }
      }
    }

    if (redistributionFailed) {
      safetyFlags.add(
        'Even at maximum intake on all segments, you will exceed 2% BW loss.',
      );
    }

    // Total intake safety check
    double totalIntakeMl = totalTransitionFluidMl.toDouble();
    for (final seg in segments) {
      final rate = segmentRates[seg.order] ?? 0;
      totalIntakeMl += rate * seg.durationMin / 60.0;
    }
    final netDeficitMl = totalLossMl - totalIntakeMl;
    if (weightKg > 0 && netDeficitMl > 0) {
      final deficitPct = netDeficitMl / (weightKg * 1000.0);
      if (deficitPct > 0.03) {
        final pctStr = (deficitPct * 100).toStringAsFixed(1);
        safetyFlags.add('Significant dehydration expected (>$pctStr% BW).');
      }
    }

    // Build result segments
    final resultSegments = segments.map((seg) {
      final rate = segmentRates[seg.order] ?? 0;
      final sport = seg.sport.toLowerCase();
      final ceiling = segmentCeilings[sport] ?? 0;
      final sodiumRate = ((rate / 1000.0) * sodiumConcMgPerL).round();
      final segEffectiveLph = sport == 'swimming'
          ? effectiveSweatRateLph * swimmingSweatModifier
          : effectiveSweatRateLph;
      return BrickHydrationSegmentResult(
        sport: seg.sport,
        order: seg.order,
        durationMin: seg.durationMin,
        hydrationRateMlph: rate,
        sodiumRateMgph: sodiumRate,
        ceilingMlHr: ceiling,
        floorMlHr: sport == 'swimming' ? 0 : floorMlHr,
        effectiveSweatRateLph: ((segEffectiveLph * 1000).round() / 1000.0),
      );
    }).toList();

    // Build result transitions — spec §6.4: sodium_mg = (fluid_ml / 1000) ×
    // sodium_conc_mg_per_l. The phantom 0.3 factor was a ~3.3× under-estimate
    // and has been removed to match the edge function.
    final resultTransitions = transitions.map((t) {
      final sodiumMg = ((_transitionFluidMl / 1000.0) * sodiumConcMgPerL)
          .round();
      return BrickHydrationTransitionResult(
        transitionName: t.name,
        afterSport: t.afterSport,
        beforeSport: t.beforeSport,
        waterMl: _transitionFluidMl,
        sodiumMg: sodiumMg,
      );
    }).toList();

    return BrickHydrationResult(
      segments: resultSegments,
      transitions: resultTransitions,
      safetyFlags: List.unmodifiable(safetyFlags),
      effectiveSweatRateLph: effectiveSweatRateLph,
      sodiumConcMgPerL: sodiumConcMgPerL,
      replacementPct: replacementPct,
      isTested: knownSweatRateMlPerHour != null,
    );
  }
}

// =============================================================================
// Result value types
// =============================================================================

/// Result from [OfflineMacroCalculator.calculateDuringWorkoutHydration].
class DuringWorkoutHydrationResult {
  const DuringWorkoutHydrationResult({
    required this.hydrationRateMlph,
    required this.sodiumRateMgph,
    required this.hydrationTotalMl,
    required this.sodiumTotalMg,
    required this.sweatRateLph,
    required this.sodiumConcMgPerL,
    required this.effectiveSweatRateLph,
    required this.replacementPct,
    required this.floorMlHr,
    required this.ceilingMlHr,
    required this.safetyFlags,
    required this.isTested,
  });

  final int hydrationRateMlph;
  final int sodiumRateMgph;
  final int hydrationTotalMl;
  final int sodiumTotalMg;
  final double sweatRateLph;
  final int sodiumConcMgPerL;
  final double effectiveSweatRateLph;
  final double replacementPct;
  final int floorMlHr;
  final int ceilingMlHr;
  final List<String> safetyFlags;
  final bool isTested;
}

/// Result from [OfflineMacroCalculator.calculatePreWorkoutHydration].
class PreWorkoutHydrationResult {
  const PreWorkoutHydrationResult({
    required this.tier,
    required this.gateTriggered,
    required this.fluidMl,
    required this.fluidLowMl,
    required this.fluidHighMl,
    required this.sodiumMg,
    required this.sodiumLowMg,
    required this.sodiumHighMg,
    required this.message,
  });

  final int tier;
  final bool gateTriggered;
  final int fluidMl;
  final int fluidLowMl;
  final int fluidHighMl;
  final int sodiumMg;
  final int sodiumLowMg;
  final int sodiumHighMg;
  final String? message;
}

/// Segment input for [OfflineMacroCalculator.calculateBrickHydration].
class BrickSegmentInput {
  const BrickSegmentInput({
    required this.sport,
    required this.order,
    required this.durationMin,
  });

  final String sport;
  final int order;
  final double durationMin;
}

/// Per-segment output from [OfflineMacroCalculator.calculateBrickHydration].
class BrickHydrationSegmentResult {
  const BrickHydrationSegmentResult({
    required this.sport,
    required this.order,
    required this.durationMin,
    required this.hydrationRateMlph,
    required this.sodiumRateMgph,
    required this.ceilingMlHr,
    required this.floorMlHr,
    required this.effectiveSweatRateLph,
  });

  final String sport;
  final int order;
  final double durationMin;
  final int hydrationRateMlph;
  final int sodiumRateMgph;
  final int ceilingMlHr;
  final int floorMlHr;
  final double effectiveSweatRateLph;
}

/// Per-transition output from [OfflineMacroCalculator.calculateBrickHydration].
class BrickHydrationTransitionResult {
  const BrickHydrationTransitionResult({
    required this.transitionName,
    required this.afterSport,
    required this.beforeSport,
    required this.waterMl,
    required this.sodiumMg,
  });

  final String transitionName;
  final String afterSport;
  final String beforeSport;
  final int waterMl;
  final int sodiumMg;
}

/// Top-level result from [OfflineMacroCalculator.calculateBrickHydration].
class BrickHydrationResult {
  const BrickHydrationResult({
    required this.segments,
    required this.transitions,
    required this.safetyFlags,
    required this.effectiveSweatRateLph,
    required this.sodiumConcMgPerL,
    required this.replacementPct,
    required this.isTested,
  });

  final List<BrickHydrationSegmentResult> segments;
  final List<BrickHydrationTransitionResult> transitions;
  final List<String> safetyFlags;
  final double effectiveSweatRateLph;
  final int sodiumConcMgPerL;
  final double replacementPct;
  final bool isTested;
}

// Internal helper — not part of public API
class _BrickTransitionRaw {
  const _BrickTransitionRaw({
    required this.index,
    required this.name,
    required this.afterSport,
    required this.beforeSport,
  });

  final int index;
  final String name;
  final String afterSport;
  final String beforeSport;
}
