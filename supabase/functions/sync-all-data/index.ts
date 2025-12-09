import { serve } from 'https://deno.land/std@0.131.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
serve(async (req)=>{
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  try {
    const supabaseClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_ANON_KEY') ?? '', {
      global: {
        headers: {
          Authorization: req.headers.get('Authorization')
        }
      }
    });
    const { user_id, last_sync_timestamp } = await req.json();
    if (!user_id) {
      return new Response(JSON.stringify({
        error: 'user_id is required'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    console.log(`Starting unified sync for user: ${user_id}`);
    if (last_sync_timestamp) {
      console.log(`Incremental sync since: ${last_sync_timestamp}`);
    } else {
      console.log('Full sync (no timestamp provided)');
    }
    // Helper to add timestamp filter
    const addFilter = (query)=>{
      if (last_sync_timestamp) {
        return query.gt('updated_at', last_sync_timestamp);
      }
      return query;
    };
    // Parallel fetch all data (PHASE 1: Added user profile to prevent FK violations)
    const [userProfileResult, nutritionFoodsResult, carbLoadingFoodsResult, activitiesResult, eventsResult, carbLoadingPlansResult, carbLoadingDaysResult, foodPreferencesResult] = await Promise.allSettled([
      // 0. User Profile (PHASE 1: Added to ensure user exists before dependent records)
      // FIXED: Query by 'id' instead of 'device_id' (user_id is now the auth UUID)
      // Note: User profile sync always fetches latest if updated
      addFilter(supabaseClient.from('users').select('*').eq('id', user_id)).maybeSingle(),
      // 1. Nutrition Plan Foods (all foods with categories and activity_types as arrays)
      // Reference data - sync if updated
      addFilter(supabaseClient.from('foods').select('*')),
      // 2. Carb Loading Foods (meal_types is now a text[] column)
      // Reference data - sync if updated
      addFilter(supabaseClient.from('carb_loading_foods').select('*')),
      // 3. Activities (exclude soft-deleted, explicitly include nutrition_plan_data)
      addFilter(supabaseClient.from('activities').select(`
          *,
          nutrition_plan_data
        `).eq('user_id', user_id).is('deleted_at', null).order('scheduled_date_time', {
        ascending: false
      })),
      // 4. Events
      addFilter(supabaseClient.from('events').select('*').eq('user_id', user_id).order('created_at', {
        ascending: false
      })),
      // 5. Carb Loading Plans
      addFilter(supabaseClient.from('carb_loading_plans').select('*').eq('user_id', user_id)),
      // 6. Carb Loading Days
      addFilter(supabaseClient.from('carb_loading_days').select(`
          *,
          carb_loading_plans!inner(user_id)
        `).eq('carb_loading_plans.user_id', user_id)),
      // 7. Food Preferences - user's liked/disliked foods
      addFilter(supabaseClient.from('food_preferences').select('*').eq('user_id', user_id))
    ]);
    // Process results and handle errors gracefully
    const response = {
      success: true,
      timestamp: new Date().toISOString(),
      data: {},
      errors: {}
    };
    // Helper to extract data or log error
    const extractData = (result, key)=>{
      if (result.status === 'fulfilled' && !result.value.error) {
        response.data[key] = result.value.data || [];
      // If incremental and empty, it means no updates
      } else {
        const error = result.status === 'fulfilled' ? result.value.error : result.reason;
        response.errors[key] = error?.message || 'Unknown error';
        response.data[key] = [];
        console.error(`✗ ${key}: ${response.errors[key]}`);
      }
    };
    // Extract all data (PHASE 1: User profile added first)
    // Note: User profile is a single object, not an array
    if (userProfileResult.status === 'fulfilled' && !userProfileResult.value.error) {
      response.data.user_profile = userProfileResult.value.data || null;
    } else {
      const error = userProfileResult.status === 'fulfilled' ? userProfileResult.value.error : userProfileResult.reason;
      response.errors.user_profile = error?.message || 'Unknown error';
      response.data.user_profile = null;
      console.error(`✗ user_profile: ${response.errors.user_profile}`);
    }
    extractData(nutritionFoodsResult, 'nutrition_foods');
    extractData(carbLoadingFoodsResult, 'carb_loading_foods');
    extractData(activitiesResult, 'activities');
    extractData(eventsResult, 'events');
    extractData(carbLoadingPlansResult, 'carb_loading_plans');
    extractData(carbLoadingDaysResult, 'carb_loading_days');
    extractData(foodPreferencesResult, 'food_preferences');
    // Note: carb_loading_foods now has meal_types as a text[] column
    // No transformation needed - the array is already in the correct format
    // Also get essential foods (Water, Salt, etc.) - ONLY if full sync or if updated
    // Since essential foods rarely change, we can apply the same filter
    const { data: essentialFoods, error: essentialError } = await addFilter(supabaseClient.from('foods').select('*').eq('is_essential', true));
    if (!essentialError && essentialFoods && essentialFoods.length > 0) {
      // Merge essential foods with nutrition foods (deduplicate by id)
      const foodsMap = new Map();
      // Add nutrition foods first
      for (const food of response.data.nutrition_foods){
        foodsMap.set(food.id, food);
      }
      // Add essential foods (won't overwrite if already exists)
      for (const food of essentialFoods){
        if (!foodsMap.has(food.id)) {
          foodsMap.set(food.id, food);
        }
      }
      response.data.nutrition_foods = Array.from(foodsMap.values());
    }
    // Log summary
    const totalRecords = Object.values(response.data).reduce((sum, arr)=>sum + (Array.isArray(arr) ? arr.length : arr ? 1 : 0), 0);
    console.log(`Sync completed: ${totalRecords} total records (Incremental: ${!!last_sync_timestamp})`);
    console.log(`Errors: ${Object.keys(response.errors).length}`);
    return new Response(JSON.stringify(response), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  } catch (error) {
    console.error('Unexpected error in sync-all-data:', error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message || 'Unknown error',
      timestamp: new Date().toISOString()
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
});
