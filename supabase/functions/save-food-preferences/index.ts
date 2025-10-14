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
    // Initialize Supabase client
    const supabaseClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');
    const { device_id, food_preferences } = await req.json();
    // Validate required fields
    if (!device_id || !food_preferences || typeof food_preferences !== 'object') {
      return new Response(JSON.stringify({
        success: false,
        message: 'Missing required fields: device_id and food_preferences object'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // Validate that device_id exists in users table
    const { data: user, error: userError } = await supabaseClient.from('users').select('device_id').eq('device_id', device_id).maybeSingle();
    if (userError || !user) {
      return new Response(JSON.stringify({
        success: false,
        message: 'User not found'
      }), {
        status: 404,
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
    // Use the upsert function to save food preferences
    const { data: result, error: upsertError } = await supabaseClient.rpc('upsert_food_preferences', {
      p_device_id: device_id,
      p_preferences: food_preferences
    });
    if (upsertError) {
      console.error('Error saving food preferences:', upsertError);
      return new Response(JSON.stringify({
        success: false,
        message: `Failed to save food preferences: ${upsertError.message}`
      }), {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // Update user's onboarding_completed status
    const { error: userUpdateError } = await supabaseClient.from('users').update({
      onboarding_completed: true,
      updated_at: new Date().toISOString()
    }).eq('device_id', device_id);
    if (userUpdateError) {
      console.error('Error updating user onboarding status:', userUpdateError);
    // Don't fail the request, just log the error
    }
    // Get the saved preferences to return in response
    const { data: savedPreferences, error: fetchError } = await supabaseClient.from('food_preferences').select('food_name, preference').eq('device_id', device_id);
    if (fetchError) {
      console.error('Error fetching saved preferences:', fetchError);
    // Still return success since the save operation succeeded
    }
    return new Response(JSON.stringify({
      success: true,
      message: 'Food preferences saved successfully',
      preferences_count: Object.keys(food_preferences).length,
      saved_preferences: savedPreferences || []
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  } catch (error) {
    console.error('Unexpected error:', error);
    return new Response(JSON.stringify({
      success: false,
      message: 'Internal server error'
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
});
