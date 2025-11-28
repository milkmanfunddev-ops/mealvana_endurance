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
    // Start a transaction to save user food and categories
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
    // Delete existing category associations first
    const { error: deleteError } = await supabaseClient.from('user_food_categories').delete().eq('user_food_id', requestData.id);
    if (deleteError) {
      console.error('❌ Save User Food - Error deleting existing categories:', deleteError);
    // Continue anyway - this might be a new food with no existing categories
    }
    // Insert new category associations
    const categoryInserts = requestData.category_ids.map((categoryId)=>({
        user_food_id: requestData.id,
        category_id: categoryId
      }));
    const { error: categoryError } = await supabaseClient.from('user_food_categories').insert(categoryInserts);
    if (categoryError) {
      console.error('❌ Save User Food - Error saving categories:', categoryError);
      return new Response(JSON.stringify({
        error: 'Failed to save food categories',
        details: categoryError.message
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
