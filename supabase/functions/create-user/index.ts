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
    const { device_id, gender, birthday, height_feet, height_inches, weight_pounds, runs_with_water_bottle, gut_training_level, food_preferences, app_version } = await req.json();
    // Validate required fields
    if (!device_id || !gender || !birthday || !height_feet || height_inches === undefined || !weight_pounds || !app_version) {
      return new Response(JSON.stringify({
        success: false,
        message: 'Missing required fields: device_id, gender, birthday, height_feet, height_inches, weight_pounds, app_version'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // Validate gender
    if (![
      'male',
      'female',
      'other'
    ].includes(gender)) {
      return new Response(JSON.stringify({
        success: false,
        message: 'Invalid gender. Must be male, female, or other.'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // Validate gut training level
    if (![
      'low',
      'moderate',
      'high'
    ].includes(gut_training_level)) {
      return new Response(JSON.stringify({
        success: false,
        message: 'Invalid gut_training_level. Must be low, moderate, or high.'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // Check if user already exists
    const { data: existingUser } = await supabaseClient.from('users').select('*').eq('device_id', device_id).maybeSingle();
    if (existingUser) {
      return new Response(JSON.stringify({
        success: false,
        message: 'User already exists with this device_id'
      }), {
        status: 409,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // Create user record
    const { data: newUser, error: userError } = await supabaseClient.from('users').insert({
      device_id,
      gender,
      birthday,
      height_feet,
      height_inches,
      weight_pounds,
      runs_with_water_bottle: runs_with_water_bottle ?? false,
      gut_training_level: gut_training_level ?? 'moderate',
      onboarding_completed: food_preferences ? true : false,
      app_version,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    }).select().single();
    if (userError) {
      console.error('Error creating user:', userError);
      return new Response(JSON.stringify({
        success: false,
        message: `Failed to create user: ${userError.message}`
      }), {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // Create food preferences if provided
    if (food_preferences && Object.keys(food_preferences).length > 0) {
      const foodPreferenceRecords = Object.entries(food_preferences).map(([food_name, preference])=>({
          device_id,
          food_name,
          preference,
          created_at: new Date().toISOString()
        }));
      const { error: preferencesError } = await supabaseClient.from('food_preferences').insert(foodPreferenceRecords);
      if (preferencesError) {
        console.error('Error creating food preferences:', preferencesError);
        // Don't fail the entire request, just log the error
        console.log('User created successfully but food preferences failed to save');
      }
    }
    return new Response(JSON.stringify({
      success: true,
      user: newUser,
      message: 'User created successfully'
    }), {
      status: 201,
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
