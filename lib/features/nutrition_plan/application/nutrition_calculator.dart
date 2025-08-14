import '../data/models/nutrition_plan.dart';
import '../../auth/data/models/user_preferences.dart';

/// Service for calculating nutrition requirements for endurance athletes
/// Based on evidence-based research documented in docs/business_logic/nutrition_algorithms.md
class NutritionCalculator {
  /// Calculate carbohydrate requirements per hour
  /// 
  /// Formula based on duration and body weight:
  /// - Short events (<3 hours): 30-60g carbs/hour
  /// - Long events (3+ hours): 60-90g carbs/hour
  /// - Body weight adjustments: +5g for >180lbs, -5g for <140lbs
  static double calculateCarbsPerHour(double durationHours, double bodyWeightLbs) {
    // Base carb rate based on duration
    double baseCarbs;
    if (durationHours < 3.0) {
      baseCarbs = 45; // Middle of 30-60g range
    } else {
      baseCarbs = 75; // Middle of 60-90g range
    }
    
    // Body weight adjustments
    if (bodyWeightLbs > 180) {
      baseCarbs += 5;
    } else if (bodyWeightLbs < 140) {
      baseCarbs -= 5;
    }
    
    return baseCarbs.clamp(30, 90); // Keep within safe ranges
  }

  /// Calculate sodium requirements per hour
  /// 
  /// Formula based on sweat rate and duration:
  /// - Standard recommendation: 200-500mg sodium per hour
  /// - High sweat rate athletes: 500-700mg per hour
  /// - Default target: 400mg sodium per hour (middle range)
  static double calculateSodiumPerHour(double durationHours, bool runsWithWaterBottle) {
    double baseSodium = 400; // mg per hour
    
    // Adjustment for longer events (more sweat loss)
    if (durationHours > 3.0) {
      baseSodium += 100;
    }
    
    // Adjustment for hydration habits (proxy for sweat rate awareness)
    if (!runsWithWaterBottle) {
      baseSodium += 50; // May be a heavier sweater who needs water bottle
    }
    
    return baseSodium.clamp(200, 700); // Keep within recommended ranges
  }

  /// Calculate fluid requirements per hour
  /// 
  /// Formula based on body weight and duration:
  /// - Standard recommendation: 400-800mL (13-27 fl oz) per hour
  /// - Target range: 16-24 fl oz per hour for most athletes
  /// - Body weight adjustment: Larger athletes need more fluids
  static double calculateFluidsPerHour(double bodyWeightLbs, double durationHours) {
    // Base fluid requirement in fl oz
    double baseFluidOz = 20; // Middle of 13-27 oz range
    
    // Body weight adjustment
    if (bodyWeightLbs > 180) {
      baseFluidOz += 3;
    } else if (bodyWeightLbs < 140) {
      baseFluidOz -= 2;
    }
    
    // Longer events may need slightly more due to cumulative losses
    if (durationHours > 4.0) {
      baseFluidOz += 2;
    }
    
    return baseFluidOz.clamp(13, 27); // Keep within research recommendations
  }

  /// Main nutrition plan calculation
  /// 
  /// Takes user profile and run parameters to generate complete nutrition plan
  static NutritionPlan calculateNutritionPlan({
    required double distanceMiles,
    required double paceMinutesPerMile,
    required UserProfile userProfile,
    String? planId,
  }) {
    // Calculate total duration
    double durationHours = (distanceMiles * paceMinutesPerMile) / 60.0;
    
    // Calculate hourly requirements
    double carbsPerHour = calculateCarbsPerHour(durationHours, userProfile.weightPounds);
    double sodiumPerHour = calculateSodiumPerHour(durationHours, userProfile.runsWithWaterBottle);
    double fluidsPerHour = calculateFluidsPerHour(userProfile.weightPounds, durationHours);
    
    // Calculate total requirements
    double totalCarbs = carbsPerHour * durationHours;
    double totalSodium = sodiumPerHour * durationHours;
    double totalFluids = fluidsPerHour * durationHours;
    
    return NutritionPlan(
      id: planId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userProfile.id,
      distanceMiles: distanceMiles,
      paceMinutesPerMile: paceMinutesPerMile,
      durationHours: durationHours,
      totalCarbs: totalCarbs,
      totalSodium: totalSodium,
      totalFluids: totalFluids,
      carbsPerHour: carbsPerHour,
      sodiumPerHour: sodiumPerHour,
      fluidsPerHour: fluidsPerHour,
      preRunMeals: [], // Will be populated by meal planning service
      duringRunMeals: [], // Will be populated by meal planning service  
      postRunMeals: [], // Will be populated by meal planning service
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Calculate pre-run nutrition timing and requirements
  /// 
  /// Based on timing guidelines:
  /// - 1-3 hours before: 1-4g carbs per kg body weight
  /// - Focus on easily digestible carbs
  static Map<String, dynamic> calculatePreRunNutrition(UserProfile userProfile, double durationHours) {
    // Convert weight from lbs to kg
    double bodyWeightKg = userProfile.weightPounds * 0.453592;
    
    // Calculate carb needs: 1-4g per kg body weight
    double preRunCarbsMin = bodyWeightKg * 1.0;
    double preRunCarbsMax = bodyWeightKg * 4.0;
    double preRunCarbsTarget = bodyWeightKg * 2.5; // Middle range
    
    return {
      'carbsMinGrams': preRunCarbsMin,
      'carbsMaxGrams': preRunCarbsMax,
      'carbsTargetGrams': preRunCarbsTarget,
      'timingMinutes': durationHours > 2 ? -180 : -120, // 3 hours for long runs, 2 for shorter
      'recommendations': [
        'Focus on easily digestible carbohydrates',
        'Avoid high fiber, high fat, or new foods',
        'Include small amount of caffeine if desired',
      ],
    };
  }

  /// Calculate post-run recovery nutrition
  /// 
  /// Based on recovery guidelines:
  /// - Carbohydrates: 1-1.2g per kg body weight
  /// - Protein: 0.25-0.3g per kg body weight  
  /// - Fluids: 1.2-1.5L per kg body weight lost
  static Map<String, dynamic> calculatePostRunNutrition(UserProfile userProfile) {
    // Convert weight from lbs to kg
    double bodyWeightKg = userProfile.weightPounds * 0.453592;
    
    double postRunCarbs = bodyWeightKg * 1.1; // Middle of 1-1.2g range
    double postRunProtein = bodyWeightKg * 0.275; // Middle of 0.25-0.3g range
    
    return {
      'carbsGrams': postRunCarbs,
      'proteinGrams': postRunProtein,
      'fluidReplacement': 'Drink 1.2-1.5L per kg of body weight lost',
      'timingMinutes': 30, // Within 30-60 minutes
      'recommendations': [
        'Consume within 30-60 minutes post-run',
        'Combine carbohydrates with protein',
        'Prioritize hydration and electrolyte replacement',
      ],
    };
  }

  /// Safety check for nutrition plan values
  /// 
  /// Ensures all calculated values are within safe limits
  static bool validateNutritionPlan(NutritionPlan plan) {
    // Check maximum safe limits per hour
    if (plan.carbsPerHour > 90) return false; // GI distress risk
    if (plan.sodiumPerHour > 1000) return false; // Without medical guidance
    if (plan.fluidsPerHour > 28) return false; // Hyponatremia risk
    
    // Check minimum requirements
    if (plan.carbsPerHour < 30) return false;
    if (plan.sodiumPerHour < 200) return false;
    if (plan.fluidsPerHour < 13) return false;
    
    // Duration checks
    if (plan.durationHours <= 0) return false;
    if (plan.distanceMiles <= 0) return false;
    if (plan.paceMinutesPerMile <= 0) return false;
    
    return true;
  }

  /// Get nutrition recommendations based on plan values
  /// 
  /// Provides user-friendly feedback about their nutrition plan
  static List<String> getNutritionRecommendations(NutritionPlan plan, UserProfile userProfile) {
    List<String> recommendations = [];
    
    // Carb recommendations
    if (plan.carbsPerHour < 40) {
      recommendations.add('Consider increasing carbohydrate intake for sustained energy');
    } else if (plan.carbsPerHour > 80) {
      recommendations.add('Monitor for GI distress with higher carbohydrate amounts');
    }
    
    // Sodium recommendations
    if (plan.sodiumPerHour < 300) {
      recommendations.add('Consider adding electrolyte supplements for longer runs');
    }
    
    // Fluid recommendations
    if (plan.fluidsPerHour > 24) {
      recommendations.add('Be careful not to overhydrate - risk of hyponatremia');
    }
    
    // Duration-specific recommendations
    if (plan.durationHours > 3) {
      recommendations.add('For runs over 3 hours, practice your nutrition plan during training');
      recommendations.add('Start fueling within the first 30-45 minutes');
    }
    
    // Personal recommendations
    if (!userProfile.runsWithWaterBottle && plan.fluidsPerHour > 20) {
      recommendations.add('Consider carrying a water bottle for adequate hydration');
    }
    
    return recommendations;
  }
}