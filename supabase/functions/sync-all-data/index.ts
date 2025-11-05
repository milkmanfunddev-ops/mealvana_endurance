import { serve } from 'https://deno.land/std@0.131.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    );

    const { user_id } = await req.json();

    if (!user_id) {
      return new Response(
        JSON.stringify({ error: 'user_id is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`Starting unified sync for user: ${user_id}`);

    // Parallel fetch all data
    const [
      nutritionFoodsResult,
      carbLoadingFoodsResult,
      mealTypesResult,
      activitiesResult,
      eventsResult,
      carbLoadingPlansResult,
      carbLoadingDaysResult,
      activityCompletionsResult,
    ] = await Promise.allSettled([
      // 1. Nutrition Plan Foods (all foods, with or without categories)
      // Using left join (no !inner) to include uncategorized foods
      supabaseClient
        .from('foods')
        .select(`
          *,
          food_categories(category_id),
          categories(*)
        `),

      // 2. Carb Loading Foods
      supabaseClient
        .from('carb_loading_foods')
        .select(`
          *,
          carb_loading_food_meal_types!inner(
            meal_type_id,
            meal_types(*)
          )
        `),

      // 3. Meal Types
      supabaseClient
        .from('meal_types')
        .select('*'),

      // 4. Activities (exclude soft-deleted)
      supabaseClient
        .from('activities')
        .select('*')
        .eq('user_id', user_id)
        .is('deleted_at', null)
        .order('scheduled_date_time', { ascending: false }),

      // 5. Events
      supabaseClient
        .from('events')
        .select('*')
        .eq('user_id', user_id)
        .order('created_at', { ascending: false }),

      // 6. Carb Loading Plans
      supabaseClient
        .from('carb_loading_plans')
        .select('*')
        .eq('user_id', user_id),

      // 7. Carb Loading Days
      supabaseClient
        .from('carb_loading_days')
        .select(`
          *,
          carb_loading_plans!inner(user_id)
        `)
        .eq('carb_loading_plans.user_id', user_id),

      // 8. Activity Completions
      supabaseClient
        .from('activity_completions')
        .select('*')
        .eq('user_id', user_id),
    ]);

    // Process results and handle errors gracefully
    const response: any = {
      success: true,
      timestamp: new Date().toISOString(),
      data: {},
      errors: {},
    };

    // Helper to extract data or log error
    const extractData = (result: PromiseSettledResult<any>, key: string) => {
      if (result.status === 'fulfilled' && !result.value.error) {
        response.data[key] = result.value.data || [];
        console.log(`✓ ${key}: ${response.data[key].length} records`);
      } else {
        const error = result.status === 'fulfilled' ? result.value.error : result.reason;
        response.errors[key] = error?.message || 'Unknown error';
        response.data[key] = [];
        console.error(`✗ ${key}: ${response.errors[key]}`);
      }
    };

    // Extract all data
    extractData(nutritionFoodsResult, 'nutrition_foods');
    extractData(carbLoadingFoodsResult, 'carb_loading_foods');
    extractData(mealTypesResult, 'meal_types');
    extractData(activitiesResult, 'activities');
    extractData(eventsResult, 'events');
    extractData(carbLoadingPlansResult, 'carb_loading_plans');
    extractData(carbLoadingDaysResult, 'carb_loading_days');
    extractData(activityCompletionsResult, 'activity_completions');

    // Transform carb loading foods to include meal_type_ids array
    // The query returns nested carb_loading_food_meal_types objects,
    // but the Flutter app expects a flat meal_type_ids array
    if (response.data.carb_loading_foods && Array.isArray(response.data.carb_loading_foods)) {
      response.data.carb_loading_foods = response.data.carb_loading_foods.map((food: any) => {
        const mealTypeIds = food.carb_loading_food_meal_types?.map((mt: any) => mt.meal_type_id) || [];

        // Return food without the nested junction table data
        const { carb_loading_food_meal_types, ...foodData } = food;

        return {
          ...foodData,
          meal_type_ids: mealTypeIds
        };
      });
      console.log(`✓ Transformed ${response.data.carb_loading_foods.length} carb loading foods with meal_type_ids`);
    }

    // Also get essential foods (Water, Salt, etc.)
    const { data: essentialFoods, error: essentialError } = await supabaseClient
      .from('foods')
      .select('*')
      .eq('is_essential', true);

    if (!essentialError && essentialFoods) {
      // Merge essential foods with nutrition foods (deduplicate by id)
      const foodsMap = new Map();

      // Add nutrition foods first
      for (const food of response.data.nutrition_foods) {
        foodsMap.set(food.id, food);
      }

      // Add essential foods (won't overwrite if already exists)
      for (const food of essentialFoods) {
        if (!foodsMap.has(food.id)) {
          foodsMap.set(food.id, food);
        }
      }

      response.data.nutrition_foods = Array.from(foodsMap.values());
      console.log(`✓ Added ${essentialFoods.length} essential foods (total: ${response.data.nutrition_foods.length})`);
    }

    // Log summary
    const totalRecords = Object.values(response.data).reduce(
      (sum: number, arr: any) => sum + (Array.isArray(arr) ? arr.length : 0),
      0
    );

    console.log(`Sync completed: ${totalRecords} total records`);
    console.log(`Errors: ${Object.keys(response.errors).length}`);

    return new Response(
      JSON.stringify(response),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Unexpected error in sync-all-data:', error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Unknown error',
        timestamp: new Date().toISOString(),
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
