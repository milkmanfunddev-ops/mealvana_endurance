import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Type definitions for request payload
interface UpsertUserProfileRequest {
  user_id: string;
  device_id: string; // REQUIRED - NOT NULL constraint in database
  // Basic profile fields
  gender?: 'male' | 'female' | 'other';
  birthday?: string;
  height_feet?: number;
  height_inches?: number;
  weight_pounds?: number;
  runs_with_water_bottle?: boolean;
  gut_training_level?: 'low' | 'moderate' | 'high';

  // Food preferences (handled separately in food_preferences table)
  food_preferences?: Record<string, 'like' | 'dislike' | 'willing_to_try'>;
  preference_levels?: Record<string, number>;

  // Dietary preference and allergies (v2 schema columns - not in production yet)
  dietary_preference?: string | null;
  allergies?: string[];

  // Sport-specific fields
  gi_sensitivity?: boolean;
  cycling_ftp_watts?: number;
  typical_bike_bottles?: number;
  has_aero_bottle?: boolean;
  has_bento_box?: boolean;
  swimming_css_seconds_per_100m?: number;
  typical_wetsuit?: boolean;
  typical_swim_cap_type?: string;

  // Onboarding flag
  onboarding_completed?: boolean;

  // App version (for analytics)
  app_version?: string;
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Initialize Supabase client with service role key
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const payload: UpsertUserProfileRequest = await req.json();
    const {
      user_id,
      device_id,
      food_preferences,
      preference_levels,
      dietary_preference,
      allergies,
      ...otherFields
    } = payload;

    console.log(`[upsert-user-profile] Processing request for user_id: ${user_id}, device_id: ${device_id}`);

    // Validate required fields
    if (!user_id) {
      console.error('[upsert-user-profile] Missing user_id');
      return new Response(
        JSON.stringify({
          success: false,
          message: 'Missing required field: user_id',
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    if (!device_id) {
      console.error('[upsert-user-profile] Missing device_id');
      return new Response(
        JSON.stringify({
          success: false,
          message: 'Missing required field: device_id (required by database NOT NULL constraint)',
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Validate gender if provided
    if (otherFields.gender && !['male', 'female', 'other'].includes(otherFields.gender)) {
      return new Response(
        JSON.stringify({
          success: false,
          message: 'Invalid gender. Must be male, female, or other.',
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Validate gut_training_level if provided
    if (otherFields.gut_training_level && !['low', 'moderate', 'high'].includes(otherFields.gut_training_level)) {
      return new Response(
        JSON.stringify({
          success: false,
          message: 'Invalid gut_training_level. Must be low, moderate, or high.',
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Validate dietary_preference if provided (nullable field)
    if (dietary_preference !== undefined && dietary_preference !== null) {
      const validDietaryPreferences = [
        'omnivore',
        'vegetarian',
        'pescatarian',
        'vegan',
        'mediterranean',
        'paleo',
        'keto',
        'low_carb',
      ];
      if (!validDietaryPreferences.includes(dietary_preference)) {
        return new Response(
          JSON.stringify({
            success: false,
            message: `Invalid dietary_preference. Must be one of: ${validDietaryPreferences.join(', ')}`,
          }),
          {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }
    }

    // Validate allergies if provided
    if (allergies !== undefined) {
      if (!Array.isArray(allergies)) {
        return new Response(
          JSON.stringify({
            success: false,
            message: 'allergies must be an array of strings',
          }),
          {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }

      const validAllergies = [
        'dairy',
        'eggs',
        'fish',
        'gluten',
        'peanuts',
        'sesame',
        'shellfish',
        'soy',
        'tree_nuts',
      ];
      const invalidAllergies = allergies.filter(
        (allergy) => !validAllergies.includes(allergy)
      );
      if (invalidAllergies.length > 0) {
        return new Response(
          JSON.stringify({
            success: false,
            message: `Invalid allergies: ${invalidAllergies.join(', ')}. Valid options: ${validAllergies.join(', ')}`,
          }),
          {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }
    }

    // Validate typical_bike_bottles range if provided
    if (otherFields.typical_bike_bottles !== undefined) {
      if (otherFields.typical_bike_bottles < 0 || otherFields.typical_bike_bottles > 6) {
        return new Response(
          JSON.stringify({
            success: false,
            message: 'typical_bike_bottles must be between 0 and 6',
          }),
          {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }
    }

    // Validate typical_swim_cap_type if provided
    if (otherFields.typical_swim_cap_type !== undefined && otherFields.typical_swim_cap_type !== null) {
      const validCapTypes = ['none', 'latex', 'silicone', 'neoprene'];
      if (!validCapTypes.includes(otherFields.typical_swim_cap_type)) {
        return new Response(
          JSON.stringify({
            success: false,
            message: `Invalid typical_swim_cap_type. Must be one of: ${validCapTypes.join(', ')}`,
          }),
          {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }
    }

    // Build update data object with only provided fields
    const updateData: Record<string, unknown> = {
      updated_at: new Date().toISOString(),
    };

    // Add optional fields if provided
    if (otherFields.gender !== undefined) updateData.gender = otherFields.gender;
    if (otherFields.birthday !== undefined) updateData.birthday = otherFields.birthday;
    if (otherFields.height_feet !== undefined) updateData.height_feet = otherFields.height_feet;
    if (otherFields.height_inches !== undefined) updateData.height_inches = otherFields.height_inches;
    if (otherFields.weight_pounds !== undefined) updateData.weight_pounds = otherFields.weight_pounds;
    if (otherFields.runs_with_water_bottle !== undefined) updateData.runs_with_water_bottle = otherFields.runs_with_water_bottle;
    if (otherFields.gut_training_level !== undefined) updateData.gut_training_level = otherFields.gut_training_level;
    if (otherFields.gi_sensitivity !== undefined) updateData.gi_sensitivity = otherFields.gi_sensitivity;
    if (otherFields.cycling_ftp_watts !== undefined) updateData.cycling_ftp_watts = otherFields.cycling_ftp_watts;
    if (otherFields.typical_bike_bottles !== undefined) updateData.typical_bike_bottles = otherFields.typical_bike_bottles;
    if (otherFields.has_aero_bottle !== undefined) updateData.has_aero_bottle = otherFields.has_aero_bottle;
    if (otherFields.has_bento_box !== undefined) updateData.has_bento_box = otherFields.has_bento_box;
    if (otherFields.swimming_css_seconds_per_100m !== undefined) updateData.swimming_css_seconds_per_100m = otherFields.swimming_css_seconds_per_100m;
    if (otherFields.typical_wetsuit !== undefined) updateData.typical_wetsuit = otherFields.typical_wetsuit;
    if (otherFields.typical_swim_cap_type !== undefined) updateData.typical_swim_cap_type = otherFields.typical_swim_cap_type;
    if (otherFields.onboarding_completed !== undefined) updateData.onboarding_completed = otherFields.onboarding_completed;
    if (otherFields.app_version !== undefined) updateData.app_version = otherFields.app_version;

    // Add dietary_preference and allergies if provided (v2 schema - will be ignored in production until migration)
    if (dietary_preference !== undefined) updateData.dietary_preference = dietary_preference;
    if (allergies !== undefined) updateData.allergies = allergies;

    // STEP 1: Upsert user profile in users table
    console.log(`[upsert-user-profile] Upserting user profile for user_id: ${user_id}, device_id: ${device_id}`);

    const { data: upsertedUser, error: upsertError } = await supabaseClient
      .from('users')
      .upsert(
        {
          id: user_id,
          device_id: device_id, // REQUIRED - NOT NULL constraint
          ...updateData,
        },
        {
          onConflict: 'id',
          ignoreDuplicates: false, // Always update on conflict
        }
      )
      .select()
      .single();

    if (upsertError) {
      console.error('[upsert-user-profile] Error upserting user profile:', upsertError);
      return new Response(
        JSON.stringify({
          success: false,
          message: `Failed to upsert user profile: ${upsertError.message}`,
          error_details: upsertError,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    console.log(`[upsert-user-profile] User profile upserted successfully`);

    // STEP 2: Handle food_preferences if provided
    let preferencesCount = 0;
    let savedPreferences = [];

    if (food_preferences && Object.keys(food_preferences).length > 0) {
      console.log(`[upsert-user-profile] Processing ${Object.keys(food_preferences).length} food preferences`);

      // Validate food preferences values
      const validPreferences = ['like', 'dislike', 'willing_to_try'];
      for (const [foodName, preference] of Object.entries(food_preferences)) {
        if (!validPreferences.includes(preference)) {
          console.error(`[upsert-user-profile] Invalid preference value: ${preference} for food: ${foodName}`);
          return new Response(
            JSON.stringify({
              success: false,
              message: `Invalid preference value: ${preference}. Must be 'like', 'dislike', or 'willing_to_try'`,
            }),
            {
              status: 400,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            }
          );
        }
      }

      // Prepare food preferences rows for upsert
      const rows = Object.entries(food_preferences).map(([foodName, preference]) => {
        const row: Record<string, unknown> = {
          user_id: user_id,
          food_name: foodName,
          preference: preference,
          updated_at: new Date().toISOString(),
        };

        // Add preference_level if provided in preference_levels map
        if (preference_levels && preference_levels[foodName] !== undefined) {
          row.preference_level = preference_levels[foodName];
        }

        return row;
      });

      // Upsert food preferences (insert or update)
      const { error: preferencesError } = await supabaseClient
        .from('food_preferences')
        .upsert(rows, {
          onConflict: 'user_id,food_name',
          ignoreDuplicates: false, // Update on conflict
        });

      if (preferencesError) {
        console.error('[upsert-user-profile] Error upserting food preferences:', preferencesError);
        // Don't fail the entire request - user profile was saved successfully
        console.log('[upsert-user-profile] User profile saved but food preferences failed to save');
      } else {
        console.log(`[upsert-user-profile] Food preferences upserted successfully`);
        preferencesCount = rows.length;

        // Fetch saved preferences to return in response
        const { data: fetchedPreferences, error: fetchError } = await supabaseClient
          .from('food_preferences')
          .select('food_name, preference, preference_level')
          .eq('user_id', user_id);

        if (!fetchError && fetchedPreferences) {
          savedPreferences = fetchedPreferences;
        }
      }
    }

    // Return success response
    console.log(`[upsert-user-profile] Successfully completed for user: ${user_id}`);
    return new Response(
      JSON.stringify({
        success: true,
        message: 'User profile updated successfully',
        user: upsertedUser,
        preferences_count: preferencesCount,
        saved_preferences: savedPreferences,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('[upsert-user-profile] Unexpected error:', error);
    return new Response(
      JSON.stringify({
        success: false,
        message: 'Internal server error',
        error_details: error instanceof Error ? error.message : String(error),
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
