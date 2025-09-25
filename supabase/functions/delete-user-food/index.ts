import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};

interface DeleteUserFoodRequest {
  device_id: string;
  food_id: string;
}

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

    // Parse request body
    const requestData: DeleteUserFoodRequest = await req.json();

    console.log('🔄 Delete User Food - Request received:', {
      device_id: requestData.device_id,
      food_id: requestData.food_id,
    });

    // Validate required fields
    if (!requestData.device_id || !requestData.food_id) {
      console.error('❌ Delete User Food - Missing required fields');
      return new Response(
        JSON.stringify({
          error: 'Missing required fields: device_id and food_id are required'
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    // Verify the food belongs to the device before deletion (security check)
    const { data: existingFood, error: fetchError } = await supabaseClient
      .from('user_foods')
      .select('id, name')
      .eq('id', requestData.food_id)
      .eq('device_id', requestData.device_id)
      .single();

    if (fetchError || !existingFood) {
      console.error('❌ Delete User Food - Food not found or access denied:', fetchError);
      return new Response(
        JSON.stringify({
          error: 'Food not found or access denied',
          details: fetchError?.message || 'Food does not exist or does not belong to this device'
        }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    // Delete category associations first (foreign key constraint)
    const { error: categoryError } = await supabaseClient
      .from('user_food_categories')
      .delete()
      .eq('user_food_id', requestData.food_id);

    if (categoryError) {
      console.error('❌ Delete User Food - Error deleting categories:', categoryError);
      return new Response(
        JSON.stringify({
          error: 'Failed to delete food categories',
          details: categoryError.message
        }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    // Delete the user food record
    const { error: deleteError } = await supabaseClient
      .from('user_foods')
      .delete()
      .eq('id', requestData.food_id)
      .eq('device_id', requestData.device_id);

    if (deleteError) {
      console.error('❌ Delete User Food - Error deleting food:', deleteError);
      return new Response(
        JSON.stringify({
          error: 'Failed to delete user food',
          details: deleteError.message
        }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    console.log('✅ Delete User Food - Successfully deleted:', {
      food_id: requestData.food_id,
      food_name: existingFood.name,
      device_id: requestData.device_id,
    });

    return new Response(
      JSON.stringify({
        success: true,
        message: 'User food deleted successfully',
        food_id: requestData.food_id,
        food_name: existingFood.name,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );

  } catch (error) {
    console.error('❌ Delete User Food - Unexpected error:', error);
    return new Response(
      JSON.stringify({
        error: 'Internal server error',
        details: error instanceof Error ? error.message : 'Unknown error'
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );
  }
});