import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const {
      user_id,
      dietary_preference,
      allergies,
      // Sport-specific fields
      gi_sensitivity,
      cycling_ftp_watts,
      typical_bike_bottles,
      has_aero_bottle,
      has_bento_box,
      swimming_css_seconds_per_100m,
      typical_wetsuit,
      typical_swim_cap_type,
    } = await req.json();

    // Validate required fields
    if (!user_id) {
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

    // Build update object with only provided fields
    const updateData: Record<string, unknown> = {
      updated_at: new Date().toISOString(),
    };

    // Dietary preference (nullable - user can skip)
    if (dietary_preference !== undefined) {
      if (dietary_preference !== null) {
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
      updateData.dietary_preference = dietary_preference;
    }

    // Allergies (array of strings)
    if (allergies !== undefined) {
      if (Array.isArray(allergies)) {
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
        updateData.allergies = allergies;
      } else {
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
    }

    // Sport-specific fields (all nullable)
    if (gi_sensitivity !== undefined) updateData.gi_sensitivity = gi_sensitivity;
    if (cycling_ftp_watts !== undefined) updateData.cycling_ftp_watts = cycling_ftp_watts;
    if (typical_bike_bottles !== undefined) updateData.typical_bike_bottles = typical_bike_bottles;
    if (has_aero_bottle !== undefined) updateData.has_aero_bottle = has_aero_bottle;
    if (has_bento_box !== undefined) updateData.has_bento_box = has_bento_box;
    if (swimming_css_seconds_per_100m !== undefined) {
      updateData.swimming_css_seconds_per_100m = swimming_css_seconds_per_100m;
    }
    if (typical_wetsuit !== undefined) updateData.typical_wetsuit = typical_wetsuit;
    if (typical_swim_cap_type !== undefined) {
      updateData.typical_swim_cap_type = typical_swim_cap_type;
    }

    // Update user record in Supabase
    const { data: updatedUser, error: updateError } = await supabaseClient
      .from('users')
      .update(updateData)
      .eq('id', user_id)
      .select()
      .single();

    if (updateError) {
      console.error('Error updating user preferences:', updateError);
      return new Response(
        JSON.stringify({
          success: false,
          message: `Failed to update user preferences: ${updateError.message}`,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    console.log(`User preferences updated successfully for user: ${user_id}`);
    return new Response(
      JSON.stringify({
        success: true,
        user: updatedUser,
        message: 'User preferences updated successfully',
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Unexpected error:', error);
    return new Response(
      JSON.stringify({
        success: false,
        message: 'Internal server error',
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
