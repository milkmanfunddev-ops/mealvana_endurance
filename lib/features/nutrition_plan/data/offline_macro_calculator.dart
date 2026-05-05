import 'dart:math' as math;

/// Offline calculator for macro recommendations when edge function is unavailable
/// Based on ISSN Position Stand recommendations for running nutrition
class OfflineMacroCalculator {
  static const double _lbToKg = 0.45359237;
  static const double _miToKm = 1.60934;
  static const double _mlToFlOz = 0.033814;
  static const double _mphToMPerMin = 26.8224;

  /// Calculate macro recommendations offline based on ISSN research
  static Map<String, dynamic> calculateMacros({
    required double weight,
    required String weightUnit,
    required double height, 
    required String heightUnit,
    required double runDistance,
    required String distanceUnit,
    required String runPace, // Format: "MM:SS" or minutes as double
    required String paceUnit,
    required double timeBeforeRunMin,
    required String gutTraining,
    required int age,
    required String gender,
  }) {
    // Convert to standard units
    final weightKg = weightUnit == 'kg' ? weight : weight * _lbToKg;
    final distanceMi = distanceUnit == 'mi' ? runDistance : runDistance / _miToKm;
    final distanceKm = distanceMi * _miToKm;
    
    // Parse pace to minutes per mile
    final paceMinPerMile = _parsePaceToMinPerMile(runPace, paceUnit);
    
    // Calculate run metrics
    final durationMin = distanceMi * paceMinPerMile;
    final durationH = durationMin / 60.0;
    final speedMph = 60.0 / paceMinPerMile;
    
    // Calculate energy expenditure using ACSM formula
    final met = _calculateMET(paceMinPerMile);
    final caloriesNet = weightKg * distanceKm; // 1 kcal per kg per km
    final caloriesGross = met * weightKg * durationH;
    
    // Pre-run nutrition calculations
    final preRunMacros = _calculatePreRunMacros(
      weightKg: weightKg,
      timeBeforeH: timeBeforeRunMin / 60.0,
    );
    
    // During-run nutrition calculations
    final duringRunMacros = _calculateDuringRunMacros(
      weightKg: weightKg,
      durationH: durationH,
      gutTraining: gutTraining,
      met: met,
    );
    
    // Post-run nutrition calculations
    final postRunMacros = _calculatePostRunMacros(
      weightKg: weightKg,
      durationH: durationH,
      duringWaterMl: (duringRunMacros['water_total_ml'] as num).toDouble(),
    );
    
    return {
      'success': true,
      'macros': {
        // Run metrics
        'duration_min': durationMin,
        'duration_h': durationH,
        'pace_min_per_mile': paceMinPerMile,
        'speed_mph': speedMph,
        'distance_mi': distanceMi,
        'distance_km': distanceKm,
        'calories_net_kcal': caloriesNet.round(),
        'calories_gross_kcal': caloriesGross.round(),
        'MET': met,
        
        // Pre-run
        'pre_run_carbs_g': preRunMacros['carbs_g'],
        'pre_run_carbs_rule': preRunMacros['rule'],
        'pre_run_protein_g_optional': preRunMacros['protein_g'],
        'pre_run_fat_g_cap': preRunMacros['fat_cap_g'],
        'pre_run_water_ml': preRunMacros['water_ml'],
        'pre_run_sodium_mg': preRunMacros['sodium_mg'],
        'pre_run_hydration_tier': preRunMacros['hydration_tier'],
        
        // During-run
        'during_rate_g_per_h': duringRunMacros['carb_rate_g_h'],
        'during_total_g': duringRunMacros['carb_total_g'],
        'during_mass_norm_rate_g_per_h': duringRunMacros['mass_norm_rate'],
        'during_abs_clamp_range_g_per_h': [30, 60],
        'during_water_rate_ml_per_h': duringRunMacros['water_rate_ml_h'],
        'during_water_total_ml': duringRunMacros['water_total_ml'],
        'during_sodium_rate_mg_per_h': duringRunMacros['sodium_rate_mg_h'],
        'during_sodium_total_mg': duringRunMacros['sodium_total_mg'],
        
        // Post-run
        'post_run_carbs_g': postRunMacros['carbs_g'],
        'post_run_protein_g': postRunMacros['protein_g'],
        'post_run_water_ml': postRunMacros['water_ml'],
        'post_run_sodium_mg': postRunMacros['sodium_mg'],
      }
    };
  }
  
  static double _parsePaceToMinPerMile(String pace, String unit) {
    double minutes;
    
    if (pace.contains(':')) {
      final parts = pace.split(':');
      minutes = double.parse(parts[0]) + double.parse(parts[1]) / 60.0;
    } else {
      minutes = double.parse(pace);
    }
    
    return unit == 'min_per_mile' ? minutes : minutes * _miToKm;
  }
  
  static double _calculateMET(double paceMinPerMile) {
    // ACSM running equation for level ground
    final mph = 60.0 / paceMinPerMile;
    final vMPerMin = mph * _mphToMPerMin;
    final vo2 = 0.2 * vMPerMin + 3.5;
    return vo2 / 3.5;
  }
  
  static Map<String, dynamic> _calculatePreRunMacros({
    required double weightKg,
    required double timeBeforeH,
  }) {
    double carbsG;
    String rule;
    
    // ISSN recommendations based on timing
    if (timeBeforeH >= 4.0) {
      carbsG = 4.0 * weightKg;
      rule = '4 g/kg (4+ hours before)';
    } else if (timeBeforeH >= 3.0) {
      carbsG = 3.0 * weightKg;
      rule = '3 g/kg (3 hours before)';
    } else if (timeBeforeH >= 2.0) {
      carbsG = 2.0 * weightKg;
      rule = '2 g/kg (2 hours before)';
    } else if (timeBeforeH >= 1.0) {
      carbsG = 1.0 * weightKg;
      rule = '1 g/kg (1 hour before)';
    } else if (timeBeforeH >= 0.25) {
      carbsG = 0.5 * weightKg;
      rule = '0.5 g/kg (15-60 min window)';
    } else {
      carbsG = 0.25 * weightKg;
      rule = '<15 min → 0.25 g/kg top-up';
    }
    
    // Other macros based on ISSN guidelines
    final proteinG = 0.2 * weightKg; // Optional pre-run protein
    final fatCapG = timeBeforeH > 2.0 ? 0.2 * weightKg : 0.1 * weightKg;
    
    // Hydration: 5-7 ml/kg
    final waterMl = timeBeforeH >= 2.0 
        ? (6.0 * weightKg).round()
        : timeBeforeH >= 1.0
            ? (5.0 * weightKg).round()
            : (3.0 * weightKg).round();
    
    // Sodium
    final sodiumMg = timeBeforeH >= 2.0 ? 400 : 200;

    // Hydration tier mirrors edge-function semantics so UI explanation can
    // branch on tier instead of inferring from fluid magnitude:
    //   tier 1: >= 2 h before (body-weight scaled)
    //   tier 2: 10 min - 2 h before (fixed top-up)
    //   tier 3: < 10 min before
    final int hydrationTier = timeBeforeH >= 2.0
        ? 1
        : timeBeforeH >= (10.0 / 60.0)
            ? 2
            : 3;

    return {
      'carbs_g': carbsG.round(),
      'rule': rule,
      'protein_g': proteinG.round(),
      'fat_cap_g': (fatCapG * 10).round() / 10,
      'water_ml': waterMl,
      'sodium_mg': sodiumMg,
      'hydration_tier': hydrationTier,
    };
  }
  
  static Map<String, dynamic> _calculateDuringRunMacros({
    required double weightKg,
    required double durationH,
    required String gutTraining,
    required double met,
  }) {
    // Gut training affects carb absorption capacity
    final gutRate = {
      'low': 0.7,
      'moderate': 1.0,
      'high': 1.2,
    }[gutTraining] ?? 1.0;
    
    // ISSN: 30-60g/h for runs >2.5h, scaled by gut training
    final massNormRate = gutRate * weightKg;
    final carbRateGH = _clamp(massNormRate, 30, 60);
    final carbTotalG = carbRateGH * durationH;
    
    // Hydration based on duration and intensity (ISSN: 450-750 ml/h)
    double waterRateMlH;
    if (durationH <= 1.0) {
      waterRateMlH = 400; // Lower for shorter runs
    } else if (met >= 8.0) {
      waterRateMlH = 750; // Higher for intense efforts
    } else if (met >= 6.0) {
      waterRateMlH = 600;
    } else {
      waterRateMlH = 500;
    }
    
    // Sodium: 500-700 mg/L for runs >1h
    final sodiumRateMgH = durationH <= 1.0 ? 0 : 250;
    
    return {
      'carb_rate_g_h': (carbRateGH * 10).round() / 10,
      'carb_total_g': carbTotalG.round(),
      'mass_norm_rate': (massNormRate * 10).round() / 10,
      'water_rate_ml_h': waterRateMlH.round(),
      'water_total_ml': (waterRateMlH * durationH).round(),
      'sodium_rate_mg_h': sodiumRateMgH,
      'sodium_total_mg': (sodiumRateMgH * durationH).round(),
    };
  }
  
  static Map<String, dynamic> _calculatePostRunMacros({
    required double weightKg,
    required double durationH,
    required double duringWaterMl,
  }) {
    // ISSN recommendations for recovery
    final carbsG = _clamp(weightKg * 1.0, 30, 140);

    // Duration-tiered protein: shorter workouts need less, longer need more
    // Clamped to 20–40g (evidence-based range)
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
    final proteinG = _clamp(weightKg * proteinPerKg, 20, 40);
    
    // 150% of fluid lost (estimated from during-run needs)
    final waterMl = _clamp(duringWaterMl * 1.5, 500, 1200);
    
    // Fixed sodium for recovery
    final sodiumMg = 500;
    
    return {
      'carbs_g': carbsG.round(),
      'protein_g': proteinG.round(),
      'water_ml': waterMl.round(),
      'sodium_mg': sodiumMg,
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
    final humidityMult = _clamp(rawHumidityMult, _humidityMultMin, _humidityMultMax);

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
  static const String _shortWorkoutGateFlag = 'No structured hydration plan needed.';
  static const String _ceilingLtFloorFlag = 'Even at maximum intake, you will exceed 2% BW loss.';

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
    final sodiumConcMgPerL = knownSodiumConcMgPerL?.round() ??
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

    final sodiumRateMgph =
        ((recommendedMlHr / 1000.0) * sodiumConcMgPerL).round();

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
        message: 'No structured pre-hydration needed for short workouts in mild conditions.',
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
      message: 'Too late for structured pre-hydration. Focus on your during-workout plan.',
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
    final sodiumConcMgPerL = knownSodiumConcMgPerL?.round() ??
        sodiumConcentrationFromCategory(sweatSodiumCat);

    // Total duration → replacement %
    final totalDurationMin =
        segments.fold<double>(0.0, (s, seg) => s + seg.durationMin);
    final replacementPct = replacementPctForDuration(totalDurationMin);

    // Per-segment sweat losses (swim uses 0.4× modifier)
    double totalLossMl = 0.0;
    for (final seg in segments) {
      final durationH = seg.durationMin / 60.0;
      if (seg.sport.toLowerCase() == 'swimming') {
        totalLossMl += effectiveSweatRateMlph * swimmingSweatModifier * durationH;
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
      transitions.add(_BrickTransitionRaw(
        index: i,
        name: transitionName,
        afterSport: afterSport,
        beforeSport: beforeSport,
      ));
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
    final remainingRequired =
        math.max(0.0, requiredTotalMl - totalTransitionFluidMl);
    final remainingFloor =
        math.max(0.0, floorTotalMl - totalTransitionFluidMl);

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
      'cycling': math.min(
              _giCeilingMlHr['cycling']!, effectiveSweatRateMlph)
          .round(),
      'running': math.min(
              _giCeilingMlHr['running']!, effectiveSweatRateMlph)
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
    final nonSwimSegs =
        segments.where((s) => s.sport.toLowerCase() != 'swimming').toList();

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
        final totalBikeHours =
            bikeSegs.fold<double>(0.0, (s, b) => s + b.durationMin / 60.0);

        if (totalBikeHours > 0) {
          final addPerHr = shortfallTotal / totalBikeHours;
          final bikeCeiling = segmentCeilings['cycling']!;
          for (final bikeSeg in bikeSegs) {
            final current = segmentRates[bikeSeg.order]!.toDouble();
            final newRate = math.min(current + addPerHr, bikeCeiling.toDouble());
            segmentRates[bikeSeg.order] = newRate.round();
          }
        }

        // Cap run at ceiling
        segmentRates[seg.order] = runCeiling;

        // Check if shortfall remains (compute actual intake)
        final actualBikeIntake = nonSwimSegs
            .where((s) => s.sport.toLowerCase() == 'cycling')
            .fold<double>(
                0.0, (s, b) => s + segmentRates[b.order]! * b.durationMin / 60.0);
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
          'Even at maximum intake on all segments, you will exceed 2% BW loss.');
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
        effectiveSweatRateLph:
            ((segEffectiveLph * 1000).round() / 1000.0),
      );
    }).toList();

    // Build result transitions — spec §6.4: sodium_mg = (fluid_ml / 1000) ×
    // sodium_conc_mg_per_l. The phantom 0.3 factor was a ~3.3× under-estimate
    // and has been removed to match the edge function.
    final resultTransitions = transitions.map((t) {
      final sodiumMg =
          ((_transitionFluidMl / 1000.0) * sodiumConcMgPerL).round();
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