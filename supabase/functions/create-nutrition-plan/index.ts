import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface CreateNutritionPlanRequest {
  device_id: string;
  distance_miles: number;
  pace_minutes_per_mile: number;
  time_before_run_hours?: number; // default 2.0
  gut_training_level?: 'low' | 'moderate' | 'high'; // override user's default
}

interface FoodItem {
  id: string;
  name: string;
  serving_amount: number;
  serving_unit: string;
  serving_unit_plural?: string;
  serving_qualifier?: string;
  food_categories: Array<{ category_id: number }>;
  nutritional_info: {
    carbs_per_serving: number;
    protein_per_serving: number;
    fat_per_serving: number;
    calories_per_serving?: number;
    sodium_mg?: number;
    serving_size: string; // Legacy field for compatibility
  };
  description?: string;
  instructions?: string;
}

interface NutritionCalculations {
  bodyWeightKg: number;
  distanceKm: number;
  durationHours: number;
  met: number;
  netCalories: number;
  grossCalories: number;
  preRunCarbsG: number;
  duringCarbsPerHour: number;
  duringTotalCarbs: number;
  duringSodiumPerHour: number;
  duringTotalSodium: number;
  duringFluidsPerHour: number;
  duringTotalFluids: number;
  postRunCarbsG: number;
  postRunProteinG: number;
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const { device_id, distance_miles, pace_minutes_per_mile, time_before_run_hours = 2.0, gut_training_level } = await req.json() as CreateNutritionPlanRequest

    // Validate required fields
    if (!device_id || !distance_miles || !pace_minutes_per_mile) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Missing required fields: device_id, distance_miles, pace_minutes_per_mile' 
        }),
        { 
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      )
    }

    // Get user data
    const { data: user, error: userError } = await supabaseClient
      .from('users')
      .select('*')
      .eq('device_id', device_id)
      .maybeSingle()

    if (userError || !user) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'User not found' 
        }),
        { 
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      )
    }

    // Get user food preferences
    const { data: foodPreferences } = await supabaseClient
      .from('food_preferences')
      .select('food_name, preference')
      .eq('device_id', device_id)

    const likedFoods = foodPreferences?.filter(fp => fp.preference === 'like').map(fp => fp.food_name) ?? []

    // Get all foods from database
    const { data: foods, error: foodsError } = await supabaseClient
      .from('foods')
      .select(`
        id,
        name,
        description,
        instructions,
        nutritional_info,
        serving_amount,
        serving_unit,
        serving_unit_plural,
        serving_qualifier,
        food_categories (
          category_id
        )
      `)
      .order('name', { ascending: true })

    if (foodsError || !foods) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Failed to load food database' 
        }),
        { 
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      )
    }

    // NUTRITION CALCULATIONS (hardcoded values - no more algorithm parameters)
    const calculations = calculateNutrition({
      user,
      distance_miles,
      pace_minutes_per_mile,
      time_before_run_hours,
      gut_training_level: gut_training_level || user.gut_training_level || 'moderate'
    })

    // FOOD SELECTION LOGIC
    const selectedFoods = await selectFoodsForPlan({
      calculations,
      foods: foods as FoodItem[],
      likedFoods,
      distanceMiles: distance_miles,
      durationHours: calculations.durationHours
    })

    // CREATE NUTRITION PLAN
    const planId = `plan-${Date.now()}-${device_id.slice(-4)}`
    const planData = {
      id: planId,
      name: 'Personalized Nutrition Plan',
      totalCalories: calculations.grossCalories,
      notes: `Plan for ${distance_miles.toFixed(1)} miles at ${pace_minutes_per_mile.toFixed(1)} min/mile pace (${calculations.met.toFixed(1)} MET)`,
      macroTargets: {
        calories: calculations.grossCalories,
        carbs: Math.round(calculations.preRunCarbsG + calculations.duringTotalCarbs + calculations.postRunCarbsG),
        protein: calculations.postRunProteinG,
        fat: Math.round(calculations.bodyWeightKg * 0.1), // Conservative fat target
        carbsRange: '80-90%',
        proteinRange: '5-15%',
        fatRange: '5-15%',
      },
      sections: [
        {
          id: 'before-run',
          title: 'Before Run',
          subtitle: time_before_run_hours >= 2.0 ? '2-3h before' : time_before_run_hours >= 1.0 ? '1-2h before' : '30-60min before',
          timing: time_before_run_hours >= 2.0 ? '2-3h before' : time_before_run_hours >= 1.0 ? '1-2h before' : '30-60min before',
          foodItems: selectedFoods.preRun,
        },
        {
          id: 'during-run',
          title: 'During Run',
          subtitle: calculations.durationHours > 1.0 ? 'Every 45-60min' : 'Not needed',
          timing: calculations.durationHours > 1.0 ? 'Every 45-60min' : 'Not needed',
          foodItems: selectedFoods.during,
        },
        {
          id: 'after-run',
          title: 'After Run',
          subtitle: 'Within 30 minutes',
          timing: '30min',
          foodItems: selectedFoods.postRun,
        },
      ],
    }

    // Save nutrition plan to database
    const { data: savedPlan, error: planError } = await supabaseClient
      .from('nutrition_plans')
      .insert({
        device_id,
        plan_id: planId,
        plan_name: planData.name,
        plan_data: planData,
        total_calories: calculations.grossCalories,
        distance_miles,
        pace_minutes_per_mile,
        notes: planData.notes,
        version: 1,
        last_modified_by: device_id,
        client_updated_at: new Date().toISOString(),
        is_deleted: false,
        conflict_resolution: 'last_write_wins'
      })
      .select()
      .single()

    if (planError) {
      console.error('Error saving nutrition plan:', planError)
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: `Failed to save nutrition plan: ${planError.message}` 
        }),
        { 
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      )
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        plan: planData,
        calculations: calculations,
        message: 'Nutrition plan created successfully'
      }),
      { 
        status: 201,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    )

  } catch (error) {
    console.error('Unexpected error:', error)
    return new Response(
      JSON.stringify({ 
        success: false, 
        message: 'Internal server error' 
      }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    )
  }
})

// NUTRITION CALCULATION FUNCTIONS (hardcoded values)
function calculateNutrition({ user, distance_miles, pace_minutes_per_mile, time_before_run_hours, gut_training_level }: {
  user: any;
  distance_miles: number;
  pace_minutes_per_mile: number;
  time_before_run_hours: number;
  gut_training_level: string;
}): NutritionCalculations {
  
  // Unit conversions
  const bodyWeightKg = user.weight_pounds * 0.45359237
  const distanceKm = distance_miles * 1.60934
  const durationHours = (distance_miles * pace_minutes_per_mile) / 60.0

  // Calculate MET using ACSM running equation
  const speedMph = 60.0 / pace_minutes_per_mile
  const speedMPerMin = speedMph * 26.8224
  const vo2 = 0.2 * speedMPerMin + 3.5
  const met = vo2 / 3.5

  // Energy calculations
  const netCalories = Math.round(bodyWeightKg * distanceKm * 1.0) // 1.0 cal/kg/km
  const grossCalories = Math.round(met * bodyWeightKg * durationHours)

  // Pre-run carbs calculation
  let preRunCarbsG: number
  if (time_before_run_hours >= 1.0) {
    const timeEffective = Math.min(Math.max(time_before_run_hours, 1.0), 4.0)
    preRunCarbsG = Math.round(timeEffective * 1.0 * bodyWeightKg) // 1g/kg/hour, capped at 4g/kg
  } else if (time_before_run_hours >= 0.25) {
    preRunCarbsG = Math.round(0.5 * bodyWeightKg) // 0.5g/kg for 15-60min window
  } else {
    preRunCarbsG = Math.round(0.25 * bodyWeightKg) // 0.25g/kg for <15min window
  }

  // During-run calculations
  const gutMultipliers = { low: 0.8, moderate: 1.0, high: 1.2 }
  const gutMultiplier = gutMultipliers[gut_training_level as keyof typeof gutMultipliers] ?? 1.0
  const massNormRate = gutMultiplier * bodyWeightKg
  const duringCarbsPerHour = Math.min(Math.max(massNormRate, 30.0), 60.0) // Clamp 30-60g/hour
  const duringTotalCarbs = duringCarbsPerHour * durationHours

  // Sodium calculations
  const duringSodiumPerHour = durationHours <= 1.0 ? 0.0 : 250.0 // No sodium for runs ≤1 hour
  const duringTotalSodium = duringSodiumPerHour * durationHours

  // Fluid calculations
  let duringFluidsPerHour: number
  if (durationHours <= 1.0) {
    duringFluidsPerHour = 500.0 * 0.8 // 400 mL/h for short runs
  } else if (met >= 8.0) {
    duringFluidsPerHour = 800.0 // High intensity
  } else if (met >= 6.0) {
    duringFluidsPerHour = 600.0 // Moderate intensity
  } else {
    duringFluidsPerHour = 500.0 // Easy pace
  }
  const duringTotalFluids = duringFluidsPerHour * durationHours

  // Post-run nutrition
  const postRunCarbsG = Math.round(bodyWeightKg * 1.0) // 1g/kg for recovery
  const postRunProteinG = Math.round(bodyWeightKg * 0.2) // 0.2g/kg protein

  return {
    bodyWeightKg,
    distanceKm,
    durationHours,
    met,
    netCalories,
    grossCalories,
    preRunCarbsG,
    duringCarbsPerHour,
    duringTotalCarbs,
    duringSodiumPerHour,
    duringTotalSodium,
    duringFluidsPerHour,
    duringTotalFluids,
    postRunCarbsG,
    postRunProteinG,
  }
}

// FOOD SELECTION LOGIC
async function selectFoodsForPlan({ calculations, foods, likedFoods, distanceMiles, durationHours }: {
  calculations: NutritionCalculations;
  foods: FoodItem[];
  likedFoods: string[];
  distanceMiles: number;
  durationHours: number;
}) {
  
  // Helper function to check if food belongs to category
  const foodBelongsToCategory = (food: any, categoryId: number) => {
    return food.food_categories?.some((fc: any) => fc.category_id === categoryId)
  }
  
  // Filter foods by category using the new multi-category system
  const preRunFoods = foods.filter(f => foodBelongsToCategory(f, 1)) // before_run = 1
  const duringRunFoods = foods.filter(f => foodBelongsToCategory(f, 2)) // during_run = 2
  const postRunFoods = foods.filter(f => foodBelongsToCategory(f, 3)) // after_run = 3

  // Select pre-run foods
  const selectedPreRun = selectFoodsForCategory({
    foods: preRunFoods,
    likedFoods,
    carbTarget: calculations.preRunCarbsG,
    category: 'before_run'
  })

  // Select during-run foods (skip for runs under 1 hour)
  const selectedDuring = durationHours > 1.0 ? selectFoodsForCategory({
    foods: duringRunFoods,
    likedFoods,
    carbTarget: calculations.duringTotalCarbs,
    category: 'during_run'
  }) : []

  // Select post-run foods
  const selectedPostRun = selectFoodsForCategory({
    foods: postRunFoods,
    likedFoods,
    carbTarget: calculations.postRunCarbsG,
    category: 'after_run'
  })

  return {
    preRun: selectedPreRun,
    during: selectedDuring,
    postRun: selectedPostRun,
  }
}

function selectFoodsForCategory({ foods, likedFoods, carbTarget, category }: {
  foods: FoodItem[];
  likedFoods: string[];
  carbTarget: number;
  category: string;
}) {
  if (foods.length === 0 || carbTarget <= 0) return []

  // Prioritize liked foods first
  const likedFoodsInCategory = foods.filter(f => likedFoods.includes(f.name))
  const otherFoods = foods.filter(f => !likedFoods.includes(f.name))
  const orderedFoods = [...likedFoodsInCategory, ...otherFoods]

  const selectedFoods = []
  let totalCarbs = 0

  // Special logic for during-run foods
  if (category === 'during_run') {
    // Filter out inappropriate foods for during-run
    const inappropriateFoods = ['Coffee', 'Orange juice'] // These are more pre-run focused
    const appropriateFoods = orderedFoods.filter(f => !inappropriateFoods.includes(f.name))

    if (appropriateFoods.length > 0) {
      // Prioritize gels and sports drinks for during-run
      const gels = appropriateFoods.filter(f => f.name.toLowerCase().includes('gel'))
      const sportsDrinks = appropriateFoods.filter(f => f.name.toLowerCase().includes('sport'))
      const others = appropriateFoods.filter(f => !f.name.toLowerCase().includes('gel') && !f.name.toLowerCase().includes('sport'))

      const prioritizedFoods = [...gels, ...sportsDrinks, ...others]

      // Select foods to meet 80% of carb target (allow for variety)
      for (const food of prioritizedFoods.slice(0, 2)) {
        const carbsPerServing = food.nutritional_info.carbs_per_serving || 0
        if (carbsPerServing > 0) {
          const maxFromThisFood = carbTarget * 0.6 // Max 60% from any one food
          const quantityNeeded = Math.min(Math.max(maxFromThisFood / carbsPerServing, 1), 10)
          
          selectedFoods.push(createFoodItemData(food, quantityNeeded))
          totalCarbs += carbsPerServing * quantityNeeded

          if (totalCarbs >= carbTarget * 0.8) break
        }
      }
    }
  } else {
    // For pre-run and post-run: normal portion calculations
    for (const food of orderedFoods.slice(0, 2)) {
      const remainingCarbs = carbTarget - totalCarbs
      if (remainingCarbs <= 0) break

      const carbsPerServing = food.nutritional_info.carbs_per_serving || 0
      if (carbsPerServing > 0) {
        const quantity = remainingCarbs / carbsPerServing
        const reasonableQuantity = Math.min(Math.max(quantity, 0.5), 3.0) // Keep portions reasonable

        selectedFoods.push(createFoodItemData(food, reasonableQuantity))
        totalCarbs += carbsPerServing * reasonableQuantity

        if (totalCarbs >= carbTarget * 0.9) break
      }
    }
  }

  // If no foods selected, provide defaults
  if (selectedFoods.length === 0 && foods.length > 0) {
    const defaultFood = foods[0]
    const carbsPerServing = defaultFood.nutritional_info.carbs_per_serving || 20
    const quantity = Math.max(carbTarget / carbsPerServing, 1)
    selectedFoods.push(createFoodItemData(defaultFood, quantity))
  }

  return selectedFoods
}

function createFoodItemData(food: FoodItem, quantity: number) {
  const adjustedCarbs = Math.round((food.nutritional_info.carbs_per_serving || 0) * quantity)
  const adjustedProtein = Math.round((food.nutritional_info.protein_per_serving || 0) * quantity)
  const adjustedFat = Math.round((food.nutritional_info.fat_per_serving || 0) * quantity)
  const adjustedCalories = Math.round((food.nutritional_info.calories_per_serving || 0) * quantity)
  const adjustedSodium = food.nutritional_info.sodium_mg ? Math.round(food.nutritional_info.sodium_mg * quantity) : undefined

  // Calculate total amount using structured serving data
  const totalAmount = quantity * food.serving_amount
  
  // Format quantity using structured serving data
  let quantityText: string
  if (totalAmount === 1) {
    quantityText = `1 ${food.serving_unit}`
  } else {
    const unit = food.serving_unit_plural || food.serving_unit
    if (totalAmount % 1 === 0) {
      quantityText = `${totalAmount.toFixed(0)} ${unit}`
    } else {
      quantityText = `${totalAmount.toFixed(1)} ${unit}`
    }
  }
  
  // Add qualifier if present
  if (food.serving_qualifier) {
    quantityText += `, ${food.serving_qualifier}`
  }

  return {
    id: food.id,
    name: food.name,
    quantity: quantityText,
    iconPath: `assets/images/${food.name.toLowerCase().replace(' ', '_')}.png`,
    description: food.description || food.instructions || '',
    nutritionalInfo: {
      calories: adjustedCalories,
      carbs: adjustedCarbs,
      protein: adjustedProtein,
      fat: adjustedFat,
      sodium: adjustedSodium,
    },
  }
}

