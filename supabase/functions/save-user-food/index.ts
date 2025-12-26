import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
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
    // Parse request body
    const requestData = await req.json();
    console.log('🔄 Save User Food - Request received:', {
      device_id: requestData.device_id,
      food_name: requestData.name,
      categories: requestData.category_ids
    });
    // Validate required fields
    if (!requestData.device_id || !requestData.id || !requestData.name || !requestData.category_ids?.length) {
      console.error('❌ Save User Food - Missing required fields');
      return new Response(JSON.stringify({
        error: 'Missing required fields: device_id, id, name, and category_ids are required'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // Map category IDs to category enum values
    // category_ids: 1 = before_run, 2 = during_run, 3 = after_run
    const categoryIdToEnum: Record<number, string> = {
      1: 'before_run',
      2: 'during_run',
      3: 'after_run'
    };
    const categories = requestData.category_ids
      .map((id: number) => categoryIdToEnum[id])
      .filter((cat: string | undefined) => cat !== undefined);

    // Save user food with categories as array column
    const { data: userFoodData, error: userFoodError } = await supabaseClient.from('user_foods').upsert({
      id: requestData.id,
      device_id: requestData.device_id,
      user_id: requestData.device_id,
      client_food_id: requestData.client_food_id,
      barcode: requestData.barcode,
      name: requestData.name,
      display_name: requestData.display_name,
      display_name_plural: requestData.display_name_plural,
      description: requestData.description,
      image_address: requestData.image_address,
      serving_amount: requestData.serving_amount,
      serving_unit: requestData.serving_unit,
      calories_per_serving: requestData.calories_per_serving,
      carbs_per_serving: requestData.carbs_per_serving,
      protein_per_serving: requestData.protein_per_serving,
      fat_per_serving: requestData.fat_per_serving,
      sodium_mg: requestData.sodium_mg,
      fluid_ml_per_serving: requestData.fluid_ml_per_serving,
      product_type: requestData.product_type,
      categories: categories, // Store categories as array column
      updated_at: new Date().toISOString()
    }).select();
    if (userFoodError) {
      console.error('❌ Save User Food - Error saving user food:', userFoodError);
      return new Response(JSON.stringify({
        error: 'Failed to save user food',
        details: userFoodError.message
      }), {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    console.log('✅ Save User Food - Successfully saved:', {
      food_id: requestData.id,
      categories_saved: requestData.category_ids.length
    });
    return new Response(JSON.stringify({
      success: true,
      message: 'User food saved successfully',
      food_id: requestData.id,
      categories_saved: requestData.category_ids.length
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  } catch (error) {
    console.error('❌ Save User Food - Unexpected error:', error);
    return new Response(JSON.stringify({
      error: 'Internal server error',
      details: error instanceof Error ? error.message : 'Unknown error'
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
});
