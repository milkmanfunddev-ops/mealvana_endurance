import { serve } from 'https://deno.land/std@0.131.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    );

    // Get request parameters
    const { meal_type_id } = await req.json();

    // Build query for carb loading foods with meal type associations
    let query = supabaseClient
      .from('carb_loading_foods')
      .select(`
        *,
        carb_loading_food_meal_types!inner(meal_type_id)
      `);

    // Filter by meal type if provided
    if (meal_type_id) {
      query = query.eq('carb_loading_food_meal_types.meal_type_id', meal_type_id);
    }

    const { data: foods, error } = await query;

    if (error) {
      throw error;
    }

    // Get all meal types for reference
    const { data: mealTypes, error: mealTypesError } = await supabaseClient
      .from('meal_types')
      .select('*')
      .order('id', { ascending: true });

    if (mealTypesError) {
      throw mealTypesError;
    }

    // Format the response
    const formattedFoods = foods?.map((food) => ({
      id: food.id,
      name: food.name,
      display_name: food.display_name,
      display_name_plural: food.display_name_plural,
      carbs_per_serving: food.carbs_per_serving,
      image_address: food.image_address || '',
      is_default: food.is_default,
      created_at: food.created_at,
      // Include meal type IDs for this food
      meal_type_ids: food.carb_loading_food_meal_types?.map((mt: any) => mt.meal_type_id) || [],
    })) || [];

    return new Response(
      JSON.stringify({
        foods: formattedFoods,
        meal_types: mealTypes || [],
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    );
  } catch (error) {
    console.error('Error fetching carb loading foods:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return new Response(
      JSON.stringify({ error: errorMessage }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    );
  }
});
