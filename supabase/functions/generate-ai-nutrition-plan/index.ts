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
  serving_amount: number;
  max_servings_before?: number;
  max_servings_during?: number;
  max_servings_after?: number;
}

// OpenAI API configuration
const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY');
const OPENAI_API_URL = 'https://api.openai.com/v1/chat/completions';

serve(async (req) => {
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

    // Validate required fields
    if (!requestData.device_id || !requestData.weight_kg || !requestData.distance_miles) {
      return new Response(JSON.stringify({
        success: false,
        message: 'Missing required fields: device_id, weight_kg, and distance_miles are required'
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

    // Fetch foods using optimized view
    const { data: allFoods, error: foodsError } = await supabaseClient
      .from('llm_food_selection')
      .select('*');

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

    // Categorize foods by phase suitability using view flags
    const beforeFoods = allFoods.filter(f => f.suitable_before);
    const duringFoods = allFoods.filter(f => f.suitable_during);
    const afterFoods = allFoods.filter(f => f.suitable_after);

    // Filter by user preferences using arrays from view
    const preferredBeforeFoods = beforeFoods.filter(f => 
      likedFoods.includes(f.name) || willingToTryFoods.includes(f.name)
    );
    const preferredDuringFoods = duringFoods.filter(f => 
      likedFoods.includes(f.name) || willingToTryFoods.includes(f.name)
    );
    const preferredAfterFoods = afterFoods.filter(f => 
      likedFoods.includes(f.name) || willingToTryFoods.includes(f.name)
    );

    // Calculate run duration and caloric needs
    const durationHours = (requestData.distance_miles * requestData.pace_minutes_per_mile) / 60;
    const durationMinutes = requestData.distance_miles * requestData.pace_minutes_per_mile;

    // Build the prompt for GPT-4o-mini
    const systemPrompt = `You are an expert sports nutritionist specializing in endurance running. Your task is to create personalized nutrition plans based on scientific guidelines including ACSM recommendations.

Key Principles:
1. Pre-run nutrition (0.25-4g carbs/kg based on time window):
   - <15 min before: 0.25g/kg
   - 15-60 min: 0.5g/kg  
   - 60-120 min: 1g/kg
   - 120-240 min: 2-4g/kg
2. During-run nutrition:
   - Gut training levels: Low (40g/h), Moderate (50g/h), High (60g/h)
   - Hydration: 400-800ml/hour
   - Sodium: 300-600mg/hour for runs >60min
3. Post-run recovery (within 30 min):
   - Carbs: 1.0-1.2g/kg
   - Protein: 0.25g/kg
   - Rehydration: 150% of fluid losses

You must ONLY select foods from the provided lists. Each food item has an ID that must be used in the response.`;

    const userPrompt = `Create a nutrition plan for this runner:

RUNNER PROFILE:
- Age: ${requestData.age} years
- Gender: ${requestData.gender}
- Weight: ${requestData.weight_kg} kg
- Height: ${requestData.height_cm} cm
- Gut training: ${requestData.gut_training_level}
- User has ${userPrefs?.liked_foods?.length || 0} liked foods, ${userPrefs?.willing_to_try_foods?.length || 0} foods they're willing to try

RUN DETAILS:
- Distance: ${requestData.distance_miles} miles
- Pace: ${requestData.pace_minutes_per_mile} min/mile
- Duration: ${durationMinutes.toFixed(0)} minutes
- Time before run: ${requestData.time_before_run_hours} hours

AVAILABLE FOODS:

BEFORE RUN (Preferred foods marked with *):
${preferredBeforeFoods.map(f => `* ${f.name} - ${f.carbs_per_serving}g carbs, ${f.serving_amount} ${f.serving_unit}`).join('\n')}
${beforeFoods.filter(f => !preferredBeforeFoods.includes(f)).slice(0, 8).map(f => `  ${f.name} - ${f.carbs_per_serving}g carbs, ${f.serving_amount} ${f.serving_unit}`).join('\n')}

DURING RUN (Preferred foods marked with *):
${preferredDuringFoods.map(f => `* ${f.name} - ${f.carbs_per_serving}g carbs, ${f.serving_amount} ${f.serving_unit}, ${f.sodium_mg || 0}mg sodium`).join('\n')}
${duringFoods.filter(f => !preferredDuringFoods.includes(f)).slice(0, 8).map(f => `  ${f.name} - ${f.carbs_per_serving}g carbs, ${f.serving_amount} ${f.serving_unit}`).join('\n')}

AFTER RUN (Preferred foods marked with *):
${preferredAfterFoods.map(f => `* ${f.name} - ${f.carbs_per_serving}g carbs, ${f.protein_per_serving}g protein, ${f.serving_amount} ${f.serving_unit}`).join('\n')}
${afterFoods.filter(f => !preferredAfterFoods.includes(f)).slice(0, 8).map(f => `  ${f.name} - ${f.carbs_per_serving}g carbs, ${f.protein_per_serving}g protein, ${f.serving_amount} ${f.serving_unit}`).join('\n')}

IMPORTANT: You MUST use the exact food names provided above. Prioritize foods marked with * (user's preferred foods).

Create a nutrition plan prioritizing your client's preferred foods (marked with *). For each food item, calculate the nutrition facts based on the serving size and carb content provided above. Return a JSON response with this exact structure:

{
  "overview_message": "A brief 1-2 sentence summary speaking directly to your client using 'you' and 'your'. Highlight the key benefits of this personalized plan.",
  "detailed_message": "A professional 2-3 paragraph detailed explanation as a sports dietitian speaking directly to your client. Use 'you' and 'your' throughout. Use proper paragraph breaks (\\n\\n between paragraphs). Explain why specific foods were chosen based on their preferences, the science behind the timing, and how this supports their specific run goals. Be encouraging and educational.",
  "plan": {
    "before": [
      {
        "food_name": "exact food name from list above",
        "description": "e.g., 1 cup cooked oatmeal",
        "carbs_grams": number,
        "calories": number,
        "protein_grams": number,
        "fat_grams": number,
        "timing": "e.g., 2 hours before"
      }
    ],
    "during": [
      {
        "food_name": "exact food name from list above",
        "description": "e.g., 2 energy gels", 
        "carbs_grams": number,
        "calories": number,
        "protein_grams": number,
        "fat_grams": number,
        "sodium_mg": number,
        "timing": "e.g., every 30 minutes"
      }
    ],
    "after": [
      {
        "food_name": "exact food name from list above",
        "description": "e.g., 1 cup chocolate milk",
        "carbs_grams": number,
        "calories": number,
        "protein_grams": number,
        "fat_grams": number,
        "timing": "e.g., within 30 minutes"
      }
    ]
  },
  "macro_targets": {
    "pre_run": {
      "calories": number,
      "carbs_grams": number,
      "protein_grams": number,
      "fat_grams": number
    },
    "during_run": {
      "carbs_per_hour": number,
      "sodium_per_hour_mg": number,
      "fluids_per_hour_ml": number
    },
    "post_run": {
      "calories": number,
      "carbs_grams": number,
      "protein_grams": number,
      "fat_grams": number
    }
  }
}`;

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
        temperature: 0.7,
        max_tokens: 2000,
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
    const nutritionPlan = JSON.parse(aiResponse.choices[0].message.content);

    // Validate that all food names exist in our database
    const allPlanFoodNames = [
      ...nutritionPlan.plan.before.map(f => f.food_name),
      ...nutritionPlan.plan.during.map(f => f.food_name),
      ...nutritionPlan.plan.after.map(f => f.food_name)
    ];

    const validFoodNames = allFoods.map(f => f.name);
    const invalidNames = allPlanFoodNames.filter(name => !validFoodNames.includes(name));

    if (invalidNames.length > 0) {
      console.error('Invalid food names in AI response:', invalidNames);
      return new Response(JSON.stringify({
        success: false,
        message: 'AI generated invalid food selections',
        fallback_to_algorithm: true
      }), {
        status: 422,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Save the plan to Supabase
    const planId = `ai-plan-${Date.now()}-${requestData.device_id.slice(-6)}`;
    
    const { error: saveError } = await supabaseClient
      .from('nutrition_plans')
      .insert({
        id: planId,
        device_id: requestData.device_id,
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

    // Return the successful response
    return new Response(JSON.stringify({
      success: true,
      plan_id: planId,
      ...nutritionPlan
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('Unexpected error:', error);
    return new Response(JSON.stringify({
      success: false,
      message: 'Internal server error',
      fallback_to_algorithm: true
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});