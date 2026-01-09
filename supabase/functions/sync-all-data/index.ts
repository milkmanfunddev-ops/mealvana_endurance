import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
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
    // NOTE: Coach messages are now synced on-demand in the ActivityCoachFeedbackWidget
    // This reduces payload size and ensures athletes see feedback immediately when viewing activities
    const [userProfileResult, nutritionFoodsResult, carbLoadingFoodsResult, activitiesResult, eventsResult, carbLoadingPlansResult, carbLoadingDaysResult, foodPreferencesResult, coachStatusResult, relationshipsResult] = await Promise.allSettled([
      // 0. User Profile (PHASE 1: Added to ensure user exists before dependent records)
      // FIXED: Query by 'id' instead of 'device_id' (user_id is now the auth UUID)
      // Note: User profile sync always fetches latest if updated
      // Includes: dietary_preference, allergies, and all sport-specific fields
      addFilter(supabaseClient.from('users').select('*').eq('id', user_id)).maybeSingle(),
      // 1. Nutrition Plan Foods (all foods with categories and activity_types as arrays)
      // CRITICAL FIX: Always fetch ALL nutrition foods (reference data, not user-specific)
      // Bug: Was using addFilter() which caused empty results for incremental syncs
      supabaseClient.from('foods').select('*'),
      // 2. Carb Loading Foods (meal_types is now a text[] column)
      // CRITICAL FIX: Always fetch ALL carb loading foods (reference data, not user-specific)
      // Bug: Was using addFilter() which caused empty results for incremental syncs
      // since the 27 default foods haven't been updated since 2025-12-04
      supabaseClient.from('carb_loading_foods').select('*'),
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
      addFilter(supabaseClient.from('food_preferences').select('*').eq('user_id', user_id)),
      // 8. Coach Record - get the full coach record if user is an approved coach
      // Returns the complete coach record for syncing to local database
      supabaseClient.from('coaches').select('*').eq('user_id', user_id).eq('application_status', 'approved').maybeSingle(),
      // 9. Coach-Athlete Relationships - get all relationships where user is coach OR athlete
      addFilter(supabaseClient.from('coach_athlete_relationships').select('*').or(`coach_user_id.eq.${user_id},athlete_user_id.eq.${user_id}`).order('created_at', { ascending: false }))
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
    extractData(relationshipsResult, 'coach_athlete_relationships');
    // NOTE: coach_messages removed - now synced on-demand in ActivityCoachFeedbackWidget

    // Coach record - returns full coach record if user is an approved coach
    // This syncs to local coaches table for offline access
    if (coachStatusResult.status === 'fulfilled' && !coachStatusResult.value.error) {
      // Return the full coach record (null if user is not an approved coach)
      response.data.coach_record = coachStatusResult.value.data;
    } else {
      // On error, return null (don't grant coach access on error)
      response.data.coach_record = null;
      const error = coachStatusResult.status === 'fulfilled' ? coachStatusResult.value.error : coachStatusResult.reason;
      if (error) {
        console.error(`✗ coach_record: ${error?.message || 'Unknown error'}`);
      }
    }

    // COACH DATA SYNC: OPTIMIZATION (2026-01-09)
    // Previously: Synced ALL athlete data for ALL relationships on every OAuth sign-in
    // Problem: Coach with 50 athletes = 600-2350 records on EVERY sync (slow, wasteful)
    // Solution: Use on-demand sync when coach views specific athlete details
    //
    // BACKWARDS COMPATIBILITY: Older app versions expect these fields, so we return empty arrays
    // Newer app versions (with on-demand sync) will use syncAthleteData() instead
    if (response.data.coach_record && response.data.coach_athlete_relationships?.length > 0) {
      console.log(`User is a coach with ${response.data.coach_athlete_relationships.length} relationships`);
      console.log('Skipping bulk athlete data sync - use on-demand sync per athlete instead');

      // Return empty arrays for backwards compatibility with older app versions
      response.data.athlete_events = [];
      response.data.athlete_activities = [];
      response.data.athlete_profiles = [];
      response.data.athlete_carb_loading_plans = [];
    }

    // ATHLETE DATA SYNC: If user is an athlete with coaches, fetch coach profiles
    // This allows athletes to see their coaches' names instead of "Coach 607F9DD5..."
    if (!response.data.coach_record && response.data.coach_athlete_relationships?.length > 0) {
      console.log(`User is an athlete with ${response.data.coach_athlete_relationships.length} relationships, fetching coach profiles...`);

      // Get unique coach user IDs from relationships
      const coachUserIds = response.data.coach_athlete_relationships
        .filter((r: any) => r.athlete_user_id === user_id)
        .map((r: any) => r.coach_user_id);

      if (coachUserIds.length > 0) {
        console.log(`Fetching profiles for ${coachUserIds.length} coaches`);

        // Fetch coach profiles (basic info for display names)
        const coachProfilesResult = await supabaseClient
          .from('users')
          .select('id, first_name, last_name, sender_name')
          .in('id', coachUserIds);

        if (coachProfilesResult.error) {
          console.error(`✗ coach_profiles: ${coachProfilesResult.error.message}`);
          response.data.coach_profiles = [];
        } else {
          response.data.coach_profiles = coachProfilesResult.data || [];
          console.log(`✓ coach_profiles: ${response.data.coach_profiles.length} records`);
        }
      }
    }

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
