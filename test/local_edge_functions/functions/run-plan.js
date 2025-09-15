// Local adaptation of run-plan edge function
// Simplified algorithmic fallback for nutrition planning

// ACSM constants for energy calculations
const ACSM_CONSTANTS = {
  HORIZONTAL: 0.2,  // ml O2/kg/min per m/min horizontal
  VERTICAL: 0.9,    // ml O2/kg/min per m/min vertical (grade)
  RESTING: 3.5      // ml O2/kg/min resting metabolic rate
};

// Nutrition guidelines based on research
const NUTRITION_GUIDELINES = {
  // Pre-run carbs (g/kg body weight) based on timing
  PRE_RUN_CARBS_TIMING: {
    4: { min: 3, max: 4 },    // 4+ hours before
    3: { min: 2, max: 3 },    // 3-4 hours before  
    2: { min: 1, max: 2 },    // 2-3 hours before
    1: { min: 0.5, max: 1 }   // 1-2 hours before
  },
  
  // During-run carbs based on duration and gut training
  DURING_RUN_CARBS: {
    beginner: { min: 30, max: 45 }, // g/hour
    intermediate: { min: 45, max: 60 },
    advanced: { min: 60, max: 90 }
  },
  
  // Post-run recovery
  POST_RUN: {
    carbs_per_kg: 1.0,    // g/kg body weight
    protein_per_kg: 0.2   // g/kg body weight
  },
  
  // Hydration (ml/hour during exercise)
  HYDRATION: {
    base: 400,            // Base hydration need
    per_kg_bodyweight: 6, // Additional ml per kg
    max: 800             // Maximum per hour
  },
  
  // Sodium replacement during exercise >1 hour
  SODIUM_PER_HOUR: 250   // mg/hour
};

/**
 * Calculate energy expenditure using ACSM running equation
 */
function calculateEnergyExpenditure(weightKg, paceMinPerMile, distanceMiles) {
  // Convert pace to speed (m/min)
  const speedMphPerMin = 1 / paceMinPerMile;  // mph per minute
  const speedMPerMin = speedMphPerMin * 1609.34; // m/min
  
  // ACSM running equation (assuming 0% grade for simplicity)
  const vo2MlKgMin = ACSM_CONSTANTS.RESTING + 
                     (ACSM_CONSTANTS.HORIZONTAL * speedMPerMin);
  
  // Calculate duration and total energy
  const durationMinutes = distanceMiles * paceMinPerMile;
  const totalKcal = (vo2MlKgMin * weightKg * durationMinutes * 5) / 1000;
  
  return {
    vo2_ml_kg_min: vo2MlKgMin,
    duration_minutes: durationMinutes,
    duration_hours: durationMinutes / 60,
    total_kcal: totalKcal
  };
}

/**
 * Calculate pre-run nutrition needs
 */
function calculatePreRunNeeds(weightKg, timeBeforeRunHours) {
  const timingHours = Math.ceil(timeBeforeRunHours);
  const carbsRange = NUTRITION_GUIDELINES.PRE_RUN_CARBS_TIMING[timingHours] || 
                     NUTRITION_GUIDELINES.PRE_RUN_CARBS_TIMING[1];
  
  return {
    carbs_g: Math.round(weightKg * carbsRange.max),
    protein_g: Math.round(weightKg * 0.1), // Light protein
    water_ml: 200, // Light hydration
    sodium_mg: 100 // Minimal sodium
  };
}

/**
 * Calculate during-run nutrition needs
 */
function calculateDuringRunNeeds(weightKg, gutTrainingLevel, durationHours) {
  // Only provide during-run nutrition for runs >1 hour
  if (durationHours < 1) {
    return {
      carbs_total_g: 0,
      sodium_total_mg: 0,
      water_total_ml: Math.round(300 * durationHours) // Light hydration even for short runs
    };
  }
  
  const carbsPerHour = NUTRITION_GUIDELINES.DURING_RUN_CARBS[gutTrainingLevel] || 
                       NUTRITION_GUIDELINES.DURING_RUN_CARBS.beginner;
  
  const hydrationPerHour = Math.min(
    NUTRITION_GUIDELINES.HYDRATION.base + (weightKg * NUTRITION_GUIDELINES.HYDRATION.per_kg_bodyweight),
    NUTRITION_GUIDELINES.HYDRATION.max
  );
  
  return {
    carbs_total_g: Math.round(carbsPerHour.max * durationHours),
    sodium_total_mg: Math.round(NUTRITION_GUIDELINES.SODIUM_PER_HOUR * durationHours),
    water_total_ml: Math.round(hydrationPerHour * durationHours)
  };
}

/**
 * Calculate post-run recovery needs
 */
function calculatePostRunNeeds(weightKg) {
  return {
    carbs_g: Math.round(weightKg * NUTRITION_GUIDELINES.POST_RUN.carbs_per_kg),
    protein_g: Math.round(weightKg * NUTRITION_GUIDELINES.POST_RUN.protein_per_kg),
    water_ml: 400, // Rehydration
    sodium_mg: 200 // Electrolyte replacement
  };
}

/**
 * Main function to generate algorithmic nutrition plan
 */
export async function generateRunPlan(requestData) {
  try {
    // Extract required data
    const {
      device_id,
      weight_kg,
      gut_training_level = 'beginner',
      distance_miles,
      pace_minutes_per_mile,
      time_before_run_hours = 2
    } = requestData;
    
    // Validate required fields
    if (!device_id || !weight_kg || !distance_miles || !pace_minutes_per_mile) {
      throw new Error('Missing required fields: device_id, weight_kg, distance_miles, pace_minutes_per_mile');
    }
    
    // Calculate energy expenditure
    const energyInfo = calculateEnergyExpenditure(weight_kg, pace_minutes_per_mile, distance_miles);
    
    // Calculate nutrition needs for each phase
    const preRunNeeds = calculatePreRunNeeds(weight_kg, time_before_run_hours);
    const duringRunNeeds = calculateDuringRunNeeds(weight_kg, gut_training_level, energyInfo.duration_hours);
    const postRunNeeds = calculatePostRunNeeds(weight_kg);
    
    // Build macro targets object
    const macro_targets = {
      pre_run: preRunNeeds,
      during_run: duringRunNeeds,
      post_run: postRunNeeds
    };
    
    return {
      success: true,
      macro_targets,
      energy_info: energyInfo,
      algorithm_used: 'ACSM_based',
      detailed_message: `Algorithmic plan for ${distance_miles} mile run at ${pace_minutes_per_mile} min/mile pace`
    };
    
  } catch (error) {
    console.error('Error generating run plan:', error);
    return {
      success: false,
      error: error.message,
      detailed_message: `Algorithmic planning error: ${error.message}`
    };
  }
}

/**
 * HTTP handler function
 */
export async function handleRequest(request) {
  try {
    const requestData = typeof request === 'object' && request.body 
      ? request.body 
      : request;
      
    const response = await generateRunPlan(requestData);
    
    return {
      status: response.success ? 200 : 400,
      data: response
    };
  } catch (error) {
    return {
      status: 500,
      data: {
        success: false,
        error: error.message
      }
    };
  }
}