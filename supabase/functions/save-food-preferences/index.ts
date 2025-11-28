import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
serve(async (req)=>{
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  try {
    // Initialize Supabase client with service role key
    const supabaseClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');
    const { user_id, food_preferences } = await req.json();
    console.log(`[save-food-preferences] Processing request for user_id: ${user_id}`);
    console.log(`[save-food-preferences] Food preferences count: ${Object.keys(food_preferences || {}).length}`);
    // Validate required fields
    if (!user_id || !food_preferences || typeof food_preferences !== 'object') {
      console.error('[save-food-preferences] Missing required fields');
      return new Response(JSON.stringify({
        success: false,
        message: 'Missing required fields: user_id and food_preferences object'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // Validate food preferences values
    const validPreferences = [
      'like',
      'dislike',
      'willing_to_try'
    ];
    for (const [foodName, preference] of Object.entries(food_preferences)){
      if (!validPreferences.includes(preference)) {
        console.error(`[save-food-preferences] Invalid preference value: ${preference} for food: ${foodName}`);
        return new Response(JSON.stringify({
          success: false,
          message: `Invalid preference value: ${preference}. Must be 'like', 'dislike', or 'willing_to_try'`
        }), {
          status: 400,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        });
      }
    }
    // STEP 1: Verify user exists in users table
    // This prevents foreign key constraint violations
    const { data: user, error: userError } = await supabaseClient.from('users').select('id').eq('id', user_id).maybeSingle();
    if (userError) {
      console.error('[save-food-preferences] Error checking user existence:', userError);
      return new Response(JSON.stringify({
        success: false,
        message: `Database error: ${userError.message}`
      }), {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    if (!user) {
      console.error(`[save-food-preferences] User not found: ${user_id}`);
      return new Response(JSON.stringify({
        success: false,
        message: 'User not found. Please ensure user profile exists before saving food preferences.'
      }), {
        status: 404,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    console.log(`[save-food-preferences] User verified: ${user_id}`);
    // STEP 2: Prepare food preferences rows for upsert
    // Use direct upsert instead of RPC function (which doesn't exist in prod schema)
    const rows = Object.entries(food_preferences).map(([foodName, preference])=>({
        user_id: user_id,
        food_name: foodName,
        preference: preference,
        updated_at: new Date().toISOString()
      }));
    console.log(`[save-food-preferences] Upserting ${rows.length} food preferences`);
    // STEP 3: Upsert food preferences (insert or update)
    // The unique constraint on (user_id, food_name) ensures proper upsert behavior
    const { error: upsertError } = await supabaseClient.from('food_preferences').upsert(rows, {
      onConflict: 'user_id,food_name',
      ignoreDuplicates: false // Update on conflict
    });
    if (upsertError) {
      console.error('[save-food-preferences] Error upserting food preferences:', upsertError);
      return new Response(JSON.stringify({
        success: false,
        message: `Failed to save food preferences: ${upsertError.message}`,
        error_details: upsertError
      }), {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    console.log(`[save-food-preferences] Food preferences saved successfully`);
    // STEP 4: Update user's onboarding_completed status
    const { error: userUpdateError } = await supabaseClient.from('users').update({
      onboarding_completed: true,
      updated_at: new Date().toISOString()
    }).eq('id', user_id);
    if (userUpdateError) {
      console.error('[save-food-preferences] Error updating user onboarding status:', userUpdateError);
    // Don't fail the request - preferences are saved, this is just a flag
    } else {
      console.log(`[save-food-preferences] User onboarding_completed flag set to true`);
    }
    // STEP 5: Fetch saved preferences to return in response
    const { data: savedPreferences, error: fetchError } = await supabaseClient.from('food_preferences').select('food_name, preference').eq('user_id', user_id);
    if (fetchError) {
      console.error('[save-food-preferences] Error fetching saved preferences:', fetchError);
    // Still return success since the save operation succeeded
    }
    console.log(`[save-food-preferences] Successfully completed for user: ${user_id}`);
    return new Response(JSON.stringify({
      success: true,
      message: 'Food preferences saved successfully',
      preferences_count: rows.length,
      saved_preferences: savedPreferences || []
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  } catch (error) {
    console.error('[save-food-preferences] Unexpected error:', error);
    return new Response(JSON.stringify({
      success: false,
      message: 'Internal server error',
      error_details: error instanceof Error ? error.message : String(error)
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
});
