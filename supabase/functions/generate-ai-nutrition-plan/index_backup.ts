import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};

interface NutritionPlanRequest {
  // User profile
  device_id: string;
  age: number;
  gender: string;
  weight_kg: number;
  height_cm: number;
  gut_training_level: string;
  
  // Run parameters
  distance_miles: number;
  pace_minutes_per_mile: number;
  time_before_run_hours: number;
  
  // Pre-calculated macros from adjust macros screen
  macro_targets: {
    pre_run: {
      carbs_g: number;
      protein_g: number;
      fat_g: number;
      water_ml: number;
      sodium_mg: number;
    };
    during_run: {
      carbs_total_g: number;
      sodium_total_mg: number;
      water_total_ml: number;
    };
    post_run: {
      carbs_g: number;
      protein_g: number;
      fat_g: number;
      water_ml: number;
      sodium_mg: number;
    };
  };
  
  // Food preferences
  liked_foods: string[];
  willing_to_try_foods: string[];
  disliked_foods: string[];
  
  // Optional parameters
  sweat_rate?: string;
}

interface FoodItem {
  id: string;
  name: string;
  phase_suitability: string[];
  calories_per_serving: number;
  carbs_per_serving: number;
  protein_per_serving: number;
  fat_per_serving: number;
  sodium_mg?: number;
  fluid_ml_per_serving?: number;
  serving_unit: string;
  serving_unit_plural?: string;
  serving_qualifier?: string;
  serving_amount: number;
  max_servings_before?: number;
  max_servings_during?: number;
  max_servings_after?: number;
}

// Helper function to generate proper quantity display like the Flutter Food.generateQuantityDisplay() method
function generateQuantityDisplay(food: FoodItem, customAmount?: number): string {
  const amount = customAmount ?? food.serving_amount ?? 1.0;
  const amountStr = amount === Math.floor(amount) ? Math.floor(amount).toString() : amount.toFixed(1);
  
  // Determine unit (singular vs plural)
  const unit = amount > 1 && food.serving_unit_plural && food.serving_unit_plural.trim().length > 0
    ? food.serving_unit_plural
    : food.serving_unit ?? 'serving';
  
  // Build the complete description
  const parts = [amountStr, unit];
  
  if (food.serving_qualifier && food.serving_qualifier.trim().length > 0) {
    parts.push(food.serving_qualifier);
  }
  
  parts.push(food.name.toLowerCase());
  
  return parts.join(' ');
}

// OpenAI API configuration
const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY');
const OPENAI_API_URL = 'https://api.openai.com/v1/chat/completions';

serve(async (req: Request) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Verify OpenAI API key is configured
    if (!OPENAI_API_KEY) {
      console.error('OPENAI_API_KEY is not configured in edge function secrets');
      return new Response(JSON.stringify({
        success: false,
        message: 'AI service not configured. Please contact support.',
        fallback_to_algorithm: true
      }), {
        status: 503,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const requestData: NutritionPlanRequest = await req.json();
    
    // Debug logging
    console.log('🔍 DEBUG: Received request data:', {
      distance_miles: requestData.distance_miles,
      pace_minutes_per_mile: requestData.pace_minutes_per_mile,
      device_id: requestData.device_id?.substring(0, 8) + '...',
      pre_run_carbs: requestData.macro_targets?.pre_run?.carbs_g,
      during_run_carbs: requestData.macro_targets?.during_run?.carbs_total_g,
      post_run_carbs: requestData.macro_targets?.post_run?.carbs_g,
    });

    // Validate required fields
    if (!requestData.device_id || !requestData.macro_targets) {
      return new Response(JSON.stringify({
        success: false,
        message: 'Missing required fields: device_id and macro_targets are required'
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Validate macro targets structure
    if (!requestData.macro_targets.pre_run || !requestData.macro_targets.during_run || !requestData.macro_targets.post_run) {
      return new Response(JSON.stringify({
        success: false,
        message: 'Invalid macro_targets structure: pre_run, during_run, and post_run phases required'
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Fetch user preferences in categorized format
    const { data: userPrefs, error: prefsError } = await supabaseClient
      .from('user_food_preferences_categorized')
      .select('*')
      .eq('device_id', requestData.device_id)
      .maybeSingle();

    if (prefsError) {
      console.error('Error fetching user preferences:', prefsError);
      // Continue without preferences if query fails
    }

    // Extract preference arrays (fallback to request data if view query failed)
    const likedFoods = userPrefs?.liked_foods || requestData.liked_foods;
    const willingToTryFoods = userPrefs?.willing_to_try_foods || requestData.willing_to_try_foods;
    
    console.log('🔍 DEBUG: User preferences:', {
      liked: likedFoods?.length || 0,
      willingToTry: willingToTryFoods?.length || 0,
      disliked: requestData.disliked_foods?.length || 0
    });

    // Fetch foods from the full foods table with all necessary fields for proper quantity display
    const { data: allFoods, error: foodsError } = await supabaseClient
      .from('foods')
      .select(`
        id,
        name,
        calories_per_serving,
        carbs_per_serving,
        protein_per_serving,
        fat_per_serving,
        sodium_mg,
        fluid_ml_per_serving,
        serving_amount,
        serving_unit,
        serving_unit_plural,
        serving_qualifier,
        before_run_suitable,
        during_run_suitable,
        run_portable,
        aid_station_available,
        max_servings_before,
        max_servings_during
      `);

    if (foodsError || !allFoods) {
      console.error('Error fetching foods:', foodsError);
      return new Response(JSON.stringify({
        success: false,
        message: 'Failed to fetch food database'
      }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Categorize foods by phase suitability using direct database flags
    console.log('🔍 DEBUG: Total foods fetched:', allFoods.length);
    
    const beforeFoods = allFoods.filter((f: any) => f.before_run_suitable);
    const duringFoods = allFoods.filter((f: any) => f.during_run_suitable || f.run_portable);
    // For after foods, include all foods that are suitable for recovery (most foods can be used after run)
    const afterFoods = allFoods.filter((f: any) => 
      // Include foods that have protein (good for recovery) or are not specifically limited to before/during only
      (f.protein_per_serving && f.protein_per_serving > 0) || 
      (!f.before_run_suitable && !f.during_run_suitable)
    );
    
    console.log('🔍 DEBUG: Food categorization:', {
      before: beforeFoods.length,
      during: duringFoods.length,
      after: afterFoods.length
    });

    // Filter by user preferences using arrays from view
    const preferredBeforeFoods = beforeFoods.filter((f: any) => 
      likedFoods.includes(f.name) || willingToTryFoods.includes(f.name)
    );
    const preferredDuringFoods = duringFoods.filter((f: any) => 
      likedFoods.includes(f.name) || willingToTryFoods.includes(f.name)
    );
    const preferredAfterFoods = afterFoods.filter((f: any) => 
      likedFoods.includes(f.name) || willingToTryFoods.includes(f.name)
    );
    
    console.log('🔍 DEBUG: Preferred foods:', {
      before: preferredBeforeFoods.length,
      during: preferredDuringFoods.length,
      after: preferredAfterFoods.length
    });

    // Calculate run duration and caloric needs
    const durationHours = (requestData.distance_miles * requestData.pace_minutes_per_mile) / 60;
    const durationMinutes = requestData.distance_miles * requestData.pace_minutes_per_mile;
    
    console.log('🔍 DEBUG: Calculated duration:', {
      distance: requestData.distance_miles,
      pace: requestData.pace_minutes_per_mile,
      durationHours: durationHours.toFixed(1),
      durationMinutes: durationMinutes.toFixed(0)
    });

    // 🚨 CRITICAL DEBUG: Log the exact macro targets being sent to AI
    console.log('🎯 DEBUG: MACRO TARGETS BEING SENT TO AI:', {
      preRun: {
        carbs: requestData.macro_targets.pre_run.carbs_g,
        protein: requestData.macro_targets.pre_run.protein_g,
        fat: requestData.macro_targets.pre_run.fat_g,
        sodium: requestData.macro_targets.pre_run.sodium_mg,
        water: requestData.macro_targets.pre_run.water_ml
      },
      duringRun: {
        carbs: requestData.macro_targets.during_run.carbs_total_g,
        sodium: requestData.macro_targets.during_run.sodium_total_mg,
        water: requestData.macro_targets.during_run.water_total_ml
      },
      postRun: {
        carbs: requestData.macro_targets.post_run.carbs_g,
        protein: requestData.macro_targets.post_run.protein_g,
        fat: requestData.macro_targets.post_run.fat_g,
        sodium: requestData.macro_targets.post_run.sodium_mg,
        water: requestData.macro_targets.post_run.water_ml
      },
      TOTAL_CARBS_EXPECTED: requestData.macro_targets.pre_run.carbs_g + requestData.macro_targets.during_run.carbs_total_g + requestData.macro_targets.post_run.carbs_g
    });

    const systemPrompt = `You are a sports dietitian creating a personalized nutrition plan for an endurance athlete's long run. Solve the constraint problem to hit the carbohydrate targets within ±10g for each phase.`;

    const userPrompt = `Create a nutrition plan for a ${requestData.distance_miles} mile run at ${requestData.pace_minutes_per_mile} min/mile pace.

BEFORE PHASE: Need ${requestData.macro_targets.pre_run.carbs_g}g carbs
Available (name, carbs/serving):
${preferredBeforeFoods.map((f: any) => `- ${f.name}, ${f.carbs_per_serving}g`).join('\n')}

DURING PHASE: Need ${requestData.macro_targets.during_run.carbs_total_g}g carbs  
Available (name, carbs/serving):
${preferredDuringFoods.map((f: any) => `- ${f.name}, ${f.carbs_per_serving}g`).join('\n')}

AFTER PHASE: Need ${requestData.macro_targets.post_run.carbs_g}g carbs
Available (name, carbs/serving):
${preferredAfterFoods.map((f: any) => `- ${f.name}, ${f.carbs_per_serving}g`).join('\n')}

Return servings for each food that sum to the target ±10g. You may use 0-5 servings of any food. Return JSON with this structure:

{
  "detailed_message": "2 paragraphs explaining your food selections for this ${requestData.distance_miles} mile run. Mention the specific carb targets (Before: ${requestData.macro_targets.pre_run.carbs_g}g, During: ${requestData.macro_targets.during_run.carbs_total_g}g, After: ${requestData.macro_targets.post_run.carbs_g}g) and how your selections meet them.",
  "solution": {
    "before": [
      {
        "food_name": "exact name from list",
        "servings": number (0-5+)
      }
    ],
    "during": [
      {
        "food_name": "exact name from list",
        "servings": number (0-5+)
      }
    ],
    "after": [
      {
        "food_name": "exact name from list", 
        "servings": number (0-5+)
      }
    ]
  },
  "carbs_check": {
    "before_total": "sum of before phase carbs",
    "during_total": "sum of during phase carbs",
    "after_total": "sum of after phase carbs"
  }
}`;

    // 🚨 DEBUG: Log the exact prompt being sent to AI
    console.log('📝 PROMPT BEING SENT TO AI (first 1000 chars):', userPrompt.substring(0, 1000) + '...');
    console.log('📝 SYSTEM PROMPT:', systemPrompt);

    // Call OpenAI API
    const openAIResponse = await fetch(OPENAI_API_URL, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt }
        ],
        temperature: 0.0, // Zero temperature for maximum determinism
        max_completion_tokens: 2000,
        response_format: { type: "json_object" }
      })
    });

    if (!openAIResponse.ok) {
      const errorText = await openAIResponse.text();
      console.error('OpenAI API error:', errorText);
      return new Response(JSON.stringify({
        success: false,
        message: 'Failed to generate nutrition plan from AI'
      }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    const aiResponse = await openAIResponse.json();
    console.log('🔍 DEBUG: AI response received successfully');
    
    let aiSolution = JSON.parse(aiResponse.choices[0].message.content);
    console.log('🔍 DEBUG: AI solution parsed:', {
      beforeItems: aiSolution.solution?.before?.length || 0,
      duringItems: aiSolution.solution?.during?.length || 0,
      afterItems: aiSolution.solution?.after?.length || 0
    });

    // Create a lookup map for food objects
    const foodLookup = new Map<string, any>(allFoods.map((food: any) => [food.name, food]));

    // Convert AI's simple solution to full nutrition plan with backend calculations
    const convertSolutionToNutritionPlan = (phase: string, items: any[]) => {
      // Default timing based on phase
      const defaultTiming = phase === 'before' ? '2-3 hours before' : 
                           phase === 'during' ? 'Throughout run' : 
                           'Within 30 minutes';
      
      return items.filter((item: any) => item.servings > 0).map((item: any) => {
        const food = foodLookup.get(item.food_name) as FoodItem | undefined;
        if (!food) {
          console.error(`❌ Food not found: ${item.food_name}`);
          return null;
        }
        
        const servings = item.servings || 1;
        const customAmount = servings * (food.serving_amount || 1);
        
        return {
          food_name: item.food_name,
          description: generateQuantityDisplay(food, customAmount), // Generate proper display
          timing: defaultTiming, // Add timing for frontend
          servings: servings,
          carbs_grams: (food.carbs_per_serving || 0) * servings,
          calories: (food.calories_per_serving || 0) * servings,
          protein_grams: (food.protein_per_serving || 0) * servings,
          fat_grams: (food.fat_per_serving || 0) * servings,
          sodium_mg: (food.sodium_mg || 0) * servings,
          fluids_ml: (food.fluid_ml_per_serving || 0) * servings
        };
      }).filter(item => item !== null);
    };

    // Build full nutrition plan from AI's solution
    let nutritionPlan = {
      detailed_message: aiSolution.detailed_message,
      plan: {
        before: convertSolutionToNutritionPlan('before', aiSolution.solution.before),
        during: convertSolutionToNutritionPlan('during', aiSolution.solution.during),
        after: convertSolutionToNutritionPlan('after', aiSolution.solution.after)
      }
    };

    // Calculate actual carbs achieved with backend calculations
    const aiBeforeCarbs = nutritionPlan.plan.before.reduce((sum: any, item: any) => sum + (item.carbs_grams || 0), 0);
    const aiDuringCarbs = nutritionPlan.plan.during.reduce((sum: any, item: any) => sum + (item.carbs_grams || 0), 0);
    const aiAfterCarbs = nutritionPlan.plan.after.reduce((sum: any, item: any) => sum + (item.carbs_grams || 0), 0);
    
    console.log('🚨 CRITICAL: AI RETURNED MACRO VALUES:', {
      AI_BEFORE_CARBS: aiBeforeCarbs,
      AI_DURING_CARBS: aiDuringCarbs, 
      AI_AFTER_CARBS: aiAfterCarbs,
      AI_TOTAL_CARBS: aiBeforeCarbs + aiDuringCarbs + aiAfterCarbs,
      EXPECTED_BEFORE: requestData.macro_targets.pre_run.carbs_g,
      EXPECTED_DURING: requestData.macro_targets.during_run.carbs_total_g,
      EXPECTED_AFTER: requestData.macro_targets.post_run.carbs_g,
      EXPECTED_TOTAL: requestData.macro_targets.pre_run.carbs_g + requestData.macro_targets.during_run.carbs_total_g + requestData.macro_targets.post_run.carbs_g
    });

    // Log macro target comparison for debugging (but don't reject)
    const expectedTotal = requestData.macro_targets.pre_run.carbs_g + requestData.macro_targets.during_run.carbs_total_g + requestData.macro_targets.post_run.carbs_g;
    const aiTotal = aiBeforeCarbs + aiDuringCarbs + aiAfterCarbs;
    const tolerance = 0.15; // 15% tolerance
    const minAcceptable = expectedTotal * (1 - tolerance);
    const maxAcceptable = expectedTotal * (1 + tolerance);
    
    if (aiTotal < minAcceptable || aiTotal > maxAcceptable) {
      console.warn(`⚠️  AI missed macro targets: Expected ${expectedTotal}g, Got ${aiTotal}g (acceptable range: ${minAcceptable.toFixed(0)}-${maxAcceptable.toFixed(0)}g)`);
    } else {
      console.log(`✅ AI hit macro targets within tolerance: ${aiTotal}g vs ${expectedTotal}g expected`);
    }

    // Validate that all food names exist in our database
    const allPlanFoodNames = [
      ...nutritionPlan.plan.before.map((f: any) => f.food_name),
      ...nutritionPlan.plan.during.map((f: any) => f.food_name),
      ...nutritionPlan.plan.after.map((f: any) => f.food_name)
    ];
    
    const validFoodNames = allFoods.map((f: any) => f.name);
    const invalidNames = allPlanFoodNames.filter((name: any) => !validFoodNames.includes(name));
    
    if (invalidNames.length > 0) {
      console.error('🚨 Invalid food names in AI response:', invalidNames);
      console.error('🚨 Valid food names available:', validFoodNames.slice(0, 10));
      return new Response(JSON.stringify({
        success: false,
        message: 'AI generated invalid food selections',
        fallback_to_algorithm: true,
        debug_invalid_names: invalidNames
      }), {
        status: 422,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Helper function to parse AI quantity from description and calculate serving multiplier
    function parseQuantityFromAIDescription(description: string, foodName: string): { multiplier: number, properDescription: string } {
      const food = foodLookup.get(foodName) as FoodItem | undefined;
      if (!food) {
        return { multiplier: 1, properDescription: description };
      }

      // Parse the numeric amount from the description (now should be just a number like "2" or "1.5")
      const trimmedDescription = description.trim();
      const aiAmount = parseFloat(trimmedDescription);
      
      if (!isNaN(aiAmount) && aiAmount > 0) {
        const baseAmount = food.serving_amount || 1;
        const multiplier = aiAmount / baseAmount;
        const properDescription = generateQuantityDisplay(food, aiAmount);
        return { multiplier, properDescription };
      }

      // Fallback to base serving if parsing fails
      return { 
        multiplier: 1, 
        properDescription: generateQuantityDisplay(food) 
      };
    }

    // Update all food items in the plan with proper quantity displays ONLY
    // The AI provides the correct macro amounts - we must NOT recalculate them!
    nutritionPlan.plan.before = nutritionPlan.plan.before.map((item: any) => {
      const { properDescription } = parseQuantityFromAIDescription(item.description, item.food_name);
      
      // Calculate fluids based on database values for display purposes
      const food = foodLookup.get(item.food_name) as FoodItem | undefined;
      const aiAmount = parseFloat(item.description.trim()) || 1;
      let calculatedFluids = 0;
      
      if (food?.fluid_ml_per_serving && food.fluid_ml_per_serving > 0) {
        const baseAmount = food.serving_amount || 1;
        const multiplier = aiAmount / baseAmount;
        calculatedFluids = Math.round((food.fluid_ml_per_serving || 0) * multiplier);
        console.log(`🥤 DEBUG: ${item.food_name} - Base: ${food.fluid_ml_per_serving}ml, Amount: ${aiAmount}, Final: ${calculatedFluids}ml`);
      }
      
      return {
        ...item,
        description: properDescription,
        // Only override fluids - keep AI's macro calculations
        fluids_ml: calculatedFluids
      };
    });

    nutritionPlan.plan.during = nutritionPlan.plan.during.map((item: any) => {
      const { properDescription } = parseQuantityFromAIDescription(item.description, item.food_name);
      
      // Calculate fluids based on database values for display purposes
      const food = foodLookup.get(item.food_name) as FoodItem | undefined;
      const aiAmount = parseFloat(item.description.trim()) || 1;
      let calculatedFluids = 0;
      
      if (food?.fluid_ml_per_serving && food.fluid_ml_per_serving > 0) {
        const baseAmount = food.serving_amount || 1;
        const multiplier = aiAmount / baseAmount;
        calculatedFluids = Math.round((food.fluid_ml_per_serving || 0) * multiplier);
      }
      
      return {
        ...item,
        description: properDescription,
        // Only override fluids - keep AI's macro calculations
        fluids_ml: calculatedFluids
      };
    });

    nutritionPlan.plan.after = nutritionPlan.plan.after.map((item: any) => {
      const { properDescription } = parseQuantityFromAIDescription(item.description, item.food_name);
      
      // Calculate fluids based on database values for display purposes
      const food = foodLookup.get(item.food_name) as FoodItem | undefined;
      const aiAmount = parseFloat(item.description.trim()) || 1;
      let calculatedFluids = 0;
      
      if (food?.fluid_ml_per_serving && food.fluid_ml_per_serving > 0) {
        const baseAmount = food.serving_amount || 1;
        const multiplier = aiAmount / baseAmount;
        calculatedFluids = Math.round((food.fluid_ml_per_serving || 0) * multiplier);
      }
      
      return {
        ...item,
        description: properDescription,
        // Only override fluids - keep AI's macro calculations
        fluids_ml: calculatedFluids
      };
    });

    // Save the plan to Supabase (let database generate UUID)
    const planId = `ai-plan-${Date.now()}-${requestData.device_id.slice(-6)}`;
    
    const { error: saveError } = await supabaseClient
      .from('nutrition_plans')
      .insert({
        // Don't provide id - let database generate it
        device_id: requestData.device_id,
        plan_id: planId, // Use plan_id for our custom identifier
        plan_name: 'AI-Generated Nutrition Plan',
        plan_data: JSON.stringify(nutritionPlan),
        distance_miles: requestData.distance_miles,
        pace_minutes_per_mile: requestData.pace_minutes_per_mile,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      });

    if (saveError) {
      console.error('Error saving plan to Supabase:', saveError);
      // Don't fail the request, just log the error
    }

    // Return the successful response with correct macro_targets structure
    const response = {
      success: true,
      plan_id: planId,
      detailed_message: nutritionPlan.detailed_message,
      plan: nutritionPlan.plan,
      macro_targets: {
        pre_run: {
          carbs_g: requestData.macro_targets.pre_run.carbs_g,
          protein_g: requestData.macro_targets.pre_run.protein_g,
          fat_g: requestData.macro_targets.pre_run.fat_g,
          water_ml: requestData.macro_targets.pre_run.water_ml,
          sodium_mg: requestData.macro_targets.pre_run.sodium_mg,
        },
        during_run: {
          carbs_total_g: requestData.macro_targets.during_run.carbs_total_g,
          sodium_total_mg: requestData.macro_targets.during_run.sodium_total_mg,
          water_total_ml: requestData.macro_targets.during_run.water_total_ml,
        },
        post_run: {
          carbs_g: requestData.macro_targets.post_run.carbs_g,
          protein_g: requestData.macro_targets.post_run.protein_g,
          fat_g: requestData.macro_targets.post_run.fat_g,
          water_ml: requestData.macro_targets.post_run.water_ml,
          sodium_mg: requestData.macro_targets.post_run.sodium_mg,
        },
      }
    };

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('🚨 UNEXPECTED ERROR in generate-ai-nutrition-plan:', error);
    console.error('🚨 ERROR STACK:', error.stack);
    console.error('🚨 ERROR MESSAGE:', error.message);
    return new Response(JSON.stringify({
      success: false,
      message: `Internal server error: ${error.message}`,
      fallback_to_algorithm: true,
      debug_error: error.toString()
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});