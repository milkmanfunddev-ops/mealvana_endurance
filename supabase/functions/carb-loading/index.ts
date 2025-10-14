// Carb Loading Calculator Edge Function
// Implements FeatherStone methodology for endurance race preparation
// Returns structured 3-day carb loading plan with detailed macro breakdowns
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
// Race distance options for carb loading calculations
const RACE_DISTANCES = {
  half_marathon: {
    name: 'Half Marathon',
    distanceKm: 21.1,
    multiplier: 0.8
  },
  marathon: {
    name: 'Marathon',
    distanceKm: 42.2,
    multiplier: 1.0
  },
  '50k': {
    name: '50K',
    distanceKm: 50.0,
    multiplier: 1.1
  },
  '50_mile': {
    name: '50 Mile',
    distanceKm: 80.5,
    multiplier: 1.2
  },
  '100k': {
    name: '100K',
    distanceKm: 100.0,
    multiplier: 1.3
  },
  '100_mile': {
    name: '100 Mile',
    distanceKm: 161.0,
    multiplier: 1.4
  }
};
// Training volume multipliers
const TRAINING_VOLUMES = {
  low: {
    name: 'Low',
    description: '<30 miles/week',
    multiplier: 0.9
  },
  moderate: {
    name: 'Moderate',
    description: '30-50 miles/week',
    multiplier: 1.0
  },
  high: {
    name: 'High',
    description: '>50 miles/week',
    multiplier: 1.1
  }
};
// FeatherStone methodology constants
const CARB_LOADING_CONFIG = {
  // Base carbohydrate target: 8-12g per kg body weight
  baseCarbsPerKg: 10.0,
  // Macro distribution percentages
  carbsPercentageNormal: 70.0,
  carbsPercentageRaceDay: 85.0,
  proteinPercentageNormal: 15.0,
  proteinPercentageRaceDay: 10.0,
  fatPercentageNormal: 15.0,
  fatPercentageRaceDay: 5.0,
  // Day intensity multipliers
  dayMinusTwoIntensity: 0.85,
  dayMinusOneIntensity: 1.0,
  raceDayIntensity: 0.6,
  // Calories per gram
  carbsCalPerG: 4,
  proteinCalPerG: 4,
  fatCalPerG: 9
};
function calculateCarbLoadingPlan(request) {
  // Convert weight from pounds to kg
  const bodyWeightKg = request.bodyWeightPounds * 0.453592;
  // Get distance and volume multipliers
  const distanceInfo = RACE_DISTANCES[request.raceDistance];
  const volumeInfo = TRAINING_VOLUMES[request.trainingVolume];
  // Calculate target carbs per kg using FeatherStone methodology
  const targetCarbsGPerKg = CARB_LOADING_CONFIG.baseCarbsPerKg * volumeInfo.multiplier * distanceInfo.multiplier;
  // Calculate daily plans
  const dayMinusTwo = calculateDayPlan('Day -2', bodyWeightKg, targetCarbsGPerKg * CARB_LOADING_CONFIG.dayMinusTwoIntensity, false);
  const dayMinusOne = calculateDayPlan('Day -1', bodyWeightKg, targetCarbsGPerKg * CARB_LOADING_CONFIG.dayMinusOneIntensity, false);
  const raceDay = calculateDayPlan('Race Day', bodyWeightKg, targetCarbsGPerKg * CARB_LOADING_CONFIG.raceDayIntensity, true);
  return {
    dayMinusTwo,
    dayMinusOne,
    raceDay,
    bodyWeightKg,
    targetCarbsGPerKg,
    notes: generatePlanNotes(request.raceDistance, request.trainingVolume)
  };
}
function calculateDayPlan(dayLabel, bodyWeightKg, carbsGPerKg, isRaceDay) {
  const totalCarbsG = bodyWeightKg * carbsGPerKg;
  // Macro distribution
  const carbsPercentage = isRaceDay ? CARB_LOADING_CONFIG.carbsPercentageRaceDay : CARB_LOADING_CONFIG.carbsPercentageNormal;
  const proteinPercentage = isRaceDay ? CARB_LOADING_CONFIG.proteinPercentageRaceDay : CARB_LOADING_CONFIG.proteinPercentageNormal;
  const fatPercentage = isRaceDay ? CARB_LOADING_CONFIG.fatPercentageRaceDay : CARB_LOADING_CONFIG.fatPercentageNormal;
  // Calculate total calories based on carbs
  const carbsCalories = totalCarbsG * CARB_LOADING_CONFIG.carbsCalPerG;
  const totalCalories = carbsCalories / (carbsPercentage / 100);
  const totalProteinG = totalCalories * proteinPercentage / 100 / CARB_LOADING_CONFIG.proteinCalPerG;
  const totalFatG = totalCalories * fatPercentage / 100 / CARB_LOADING_CONFIG.fatCalPerG;
  // Generate meals
  const meals = generateMeals(dayLabel, totalCalories, totalCarbsG, totalProteinG, totalFatG, isRaceDay);
  return {
    dayLabel,
    totalCalories: Math.round(totalCalories),
    totalCarbsG: Math.round(totalCarbsG),
    totalProteinG: Math.round(totalProteinG),
    totalFatG: Math.round(totalFatG),
    carbsPercentage,
    proteinPercentage,
    fatPercentage,
    carbsGPerKg,
    meals
  };
}
function generateMeals(dayLabel, totalCalories, totalCarbsG, totalProteinG, totalFatG, isRaceDay) {
  if (isRaceDay) {
    // Race day: pre-race meal only
    return [
      {
        mealName: 'Pre-Race Meal (2-3 hours before)',
        calories: Math.round(totalCalories),
        carbsG: Math.round(totalCarbsG),
        proteinG: Math.round(totalProteinG),
        fatG: Math.round(totalFatG),
        foodSuggestions: [
          'Oatmeal with banana and honey',
          'White rice with soy sauce',
          'White bread with jam',
          'Sports drink',
          'Bagel with small amount of peanut butter'
        ]
      }
    ];
  } else {
    // Regular carb loading days: 3 meals + snacks
    return [
      {
        mealName: 'Breakfast',
        calories: Math.round(totalCalories * 0.3),
        carbsG: Math.round(totalCarbsG * 0.3),
        proteinG: Math.round(totalProteinG * 0.3),
        fatG: Math.round(totalFatG * 0.3),
        foodSuggestions: [
          'Pancakes with syrup',
          'Cereal with banana',
          'Toast with jam',
          'Orange juice',
          'French toast'
        ]
      },
      {
        mealName: 'Lunch',
        calories: Math.round(totalCalories * 0.35),
        carbsG: Math.round(totalCarbsG * 0.35),
        proteinG: Math.round(totalProteinG * 0.35),
        fatG: Math.round(totalFatG * 0.35),
        foodSuggestions: [
          'Pasta with marinara sauce',
          'White rice with chicken',
          'Bagel with turkey',
          'Sports drink',
          'Baked potato with lean protein'
        ]
      },
      {
        mealName: 'Dinner',
        calories: Math.round(totalCalories * 0.25),
        carbsG: Math.round(totalCarbsG * 0.25),
        proteinG: Math.round(totalProteinG * 0.25),
        fatG: Math.round(totalFatG * 0.25),
        foodSuggestions: [
          'Rice with vegetables',
          'Pasta with light sauce',
          'White bread rolls',
          'Sweet potato',
          'Quinoa with lean protein'
        ]
      },
      {
        mealName: 'Snacks',
        calories: Math.round(totalCalories * 0.1),
        carbsG: Math.round(totalCarbsG * 0.1),
        proteinG: Math.round(totalProteinG * 0.1),
        fatG: Math.round(totalFatG * 0.1),
        foodSuggestions: [
          'Banana',
          'Pretzels',
          'Graham crackers',
          'Sports drink',
          'Energy bars'
        ]
      }
    ];
  }
}
function generatePlanNotes(raceDistance, trainingVolume) {
  const distanceInfo = RACE_DISTANCES[raceDistance];
  const volumeInfo = TRAINING_VOLUMES[trainingVolume];
  return `Carb Loading Plan for ${distanceInfo.name}

This plan follows the FeatherStone methodology for maximizing glycogen stores before your race. Key guidelines:

• Start 2 days before your race
• Reduce training volume while increasing carbohydrate intake
• Focus on familiar, easily digestible foods
• Stay hydrated throughout the loading period
• Avoid high-fiber foods that may cause GI distress

Training Volume: ${volumeInfo.name} (${volumeInfo.description})

Remember: Practice this plan during training to ensure it works for your body!`;
}
serve(async (req)=>{
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  try {
    const startTime = Date.now();
    // Parse request
    const requestData = await req.json();
    // Validate input
    if (!requestData.raceDate || !requestData.raceDistance || !requestData.trainingVolume || !requestData.bodyWeightPounds) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Missing required fields: raceDate, raceDistance, trainingVolume, bodyWeightPounds'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // Validate race distance
    if (!(requestData.raceDistance in RACE_DISTANCES)) {
      return new Response(JSON.stringify({
        success: false,
        error: `Invalid race distance. Must be one of: ${Object.keys(RACE_DISTANCES).join(', ')}`
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // Validate training volume
    if (!(requestData.trainingVolume in TRAINING_VOLUMES)) {
      return new Response(JSON.stringify({
        success: false,
        error: `Invalid training volume. Must be one of: ${Object.keys(TRAINING_VOLUMES).join(', ')}`
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // Validate body weight
    if (requestData.bodyWeightPounds <= 0 || requestData.bodyWeightPounds > 1000) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Body weight must be between 1 and 1000 pounds'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // Calculate carb loading plan
    const plan = calculateCarbLoadingPlan(requestData);
    const calculationTime = Date.now() - startTime;
    const response = {
      success: true,
      plan,
      metadata: {
        calculationTime,
        methodology: 'FeatherStone',
        raceInfo: {
          distance: RACE_DISTANCES[requestData.raceDistance].name,
          trainingVolume: TRAINING_VOLUMES[requestData.trainingVolume].name,
          bodyWeight: {
            pounds: requestData.bodyWeightPounds,
            kg: Math.round(requestData.bodyWeightPounds * 0.453592 * 10) / 10
          }
        }
      }
    };
    return new Response(JSON.stringify(response), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  } catch (error) {
    console.error('Carb loading calculation error:', error);
    return new Response(JSON.stringify({
      success: false,
      error: 'Internal server error during carb loading calculation',
      metadata: {
        calculationTime: 0,
        methodology: 'FeatherStone',
        raceInfo: null
      }
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
});
