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
      duringWaterMl: duringRunMacros['water_total_ml'],
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
    
    return {
      'carbs_g': carbsG.round(),
      'rule': rule,
      'protein_g': proteinG.round(),
      'fat_cap_g': (fatCapG * 10).round() / 10,
      'water_ml': waterMl,
      'sodium_mg': sodiumMg,
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
      'moderate': 0.8,
      'high': 1.0,
    }[gutTraining] ?? 0.8;
    
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
}