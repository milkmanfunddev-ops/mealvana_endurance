/**
 * Create User Edge Function
 *
 * Creates a new user with biometric data and optional food preferences.
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { jsonResponse, errorResponse, validationError, serverError } from '../_shared/responses.ts';
import { createServiceClient } from '../_shared/supabase-client.ts';

serve(async (req) => {
  // Handle CORS preflight
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const supabaseClient = createServiceClient();

    const {
      device_id,
      gender,
      birthday,
      height_feet,
      height_inches,
      weight_pounds,
      runs_with_water_bottle,
      gut_training_level,
      food_preferences,
      app_version,
    } = await req.json();

    // Validate required fields
    if (
      !device_id ||
      !gender ||
      !birthday ||
      !height_feet ||
      height_inches === undefined ||
      !weight_pounds ||
      !app_version
    ) {
      return validationError(
        'Missing required fields: device_id, gender, birthday, height_feet, height_inches, weight_pounds, app_version'
      );
    }

    // Validate gender
    if (!['male', 'female', 'other'].includes(gender)) {
      return validationError('Invalid gender. Must be male, female, or other.');
    }

    // Validate gut training level
    if (!['low', 'moderate', 'high'].includes(gut_training_level)) {
      return validationError('Invalid gut_training_level. Must be low, moderate, or high.');
    }

    // Check if user already exists
    const { data: existingUser } = await supabaseClient
      .from('users')
      .select('*')
      .eq('device_id', device_id)
      .maybeSingle();

    if (existingUser) {
      return errorResponse('User already exists with this device_id', 409);
    }

    // Create user record
    const { data: newUser, error: userError } = await supabaseClient
      .from('users')
      .insert({
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
        updated_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (userError) {
      console.error('Error creating user:', userError);
      return errorResponse(`Failed to create user: ${userError.message}`, 500);
    }

    // Create food preferences if provided
    if (food_preferences && Object.keys(food_preferences).length > 0) {
      const foodPreferenceRecords = Object.entries(food_preferences).map(
        ([food_name, preference]) => ({
          device_id,
          food_name,
          preference,
          created_at: new Date().toISOString(),
        })
      );

      const { error: preferencesError } = await supabaseClient
        .from('food_preferences')
        .insert(foodPreferenceRecords);

      if (preferencesError) {
        console.error('Error creating food preferences:', preferencesError);
        // Don't fail the entire request, just log the error
        console.log('User created successfully but food preferences failed to save');
      }
    }

    return jsonResponse(
      {
        success: true,
        user: newUser,
        message: 'User created successfully',
      },
      201
    );
  } catch (error) {
    console.error('Unexpected error:', error);
    return serverError(error);
  }
});
