import { serve } from 'https://deno.land/std@0.131.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
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
    )

    const { category } = await req.json()

    // Get category ID based on category name
    let categoryId: number | null = null
    if (category === 'before_run') {
      categoryId = 1 // Assuming 1 is before_run category
    } else if (category === 'during_run') {
      categoryId = 2 // Assuming 2 is during_run category  
    } else if (category === 'after_run') {
      categoryId = 3 // Assuming 3 is after_run category
    }

    // Build the query
    let query = supabaseClient
      .from('foods')
      .select(`
        *,
        food_categories!inner(category_id),
        categories!inner(*)
      `)

    // Filter by category if provided
    if (categoryId) {
      query = query.eq('food_categories.category_id', categoryId)
    }

    // Execute query
    const { data: foods, error } = await query

    if (error) {
      throw error
    }

    // Format the response
    const formattedFoods = foods?.map(food => ({
      id: food.id,
      name: food.name,
      icon_path: food.icon_path,
      description: food.description,
      instructions: food.instructions,
      carbs_per_serving: food.carbs_per_serving || 0,
      sodium_mg: food.sodium_mg || 0,
      fluid_ml_per_serving: food.fluid_ml_per_serving || 0,
      calories_per_serving: food.calories_per_serving || 0,
      protein_per_serving: food.protein_per_serving || 0,
      fat_per_serving: food.fat_per_serving || 0,
      serving_size: food.serving_size,
      serving_amount: food.serving_amount,
      serving_unit: food.serving_unit,
      serving_unit_plural: food.serving_unit_plural,
      serving_qualifier: food.serving_qualifier,
      before_run_suitable: food.before_run_suitable,
      during_run_suitable: food.during_run_suitable,
      run_portable: food.run_portable,
      requires_preparation: food.requires_preparation,
      aid_station_available: food.aid_station_available,
      max_servings_before: food.max_servings_before,
      max_servings_during: food.max_servings_during,
      caffeine_mg: food.caffeine_mg,
      potassium_mg: food.potassium_mg
    })) || []

    return new Response(
      JSON.stringify({ foods: formattedFoods }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    console.error('Error fetching foods:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})