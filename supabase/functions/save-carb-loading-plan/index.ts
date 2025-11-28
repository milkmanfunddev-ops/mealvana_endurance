import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
// Helper function to get carb protocol for a specific day
function getCarbProtocolForDay(protocolDays, daysBeforeRace) {
  if (protocolDays === 2) {
    // 2-day protocol
    return daysBeforeRace === 2 ? 9.0 : 11.0; // Day -2: 9g/kg, Day -1: 11g/kg
  } else if (protocolDays === 3) {
    // 3-day protocol
    return daysBeforeRace === 3 || daysBeforeRace === 2 ? 8.0 : 10.0; // Day -3,-2: 8g/kg, Day -1: 10g/kg
  }
  return 8.0; // Default fallback
}
// Helper function to add days to a date
function addDays(date, days) {
  const result = new Date(date);
  result.setDate(result.getDate() + days);
  return result.toISOString().split('T')[0]; // Return YYYY-MM-DD
}
serve(async (req)=>{
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  try {
    // 1. Initialize Supabase client with service role key to bypass RLS
    const supabaseClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');
    // 2. Parse request
    const { device_id, plan, plan_id, operation } = await req.json();
    // 3. Validate device exists
    const { data: deviceData, error: deviceError } = await supabaseClient.from('users').select('id, device_id').eq('device_id', device_id).single();
    if (deviceError || !deviceData) {
      return new Response(JSON.stringify({
        error: 'Invalid device_id'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // 4. Perform operation
    let result;
    if (operation === 'create') {
      // Validate event if provided
      if (plan.eventId) {
        const { data: eventData, error: eventError } = await supabaseClient.from('events').select('id').eq('id', plan.eventId).single();
        if (eventError || !eventData) {
          return new Response(JSON.stringify({
            error: 'Invalid event_id'
          }), {
            status: 400,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json'
            }
          });
        }
      }
      // Calculate plan details
      const protocolDays = plan.protocolDays;
      const bodyWeightKg = plan.bodyWeightPounds * 0.453592;
      const raceDate = new Date(plan.raceDate);
      const startDate = new Date(raceDate);
      startDate.setDate(startDate.getDate() - protocolDays);
      const endDate = new Date(raceDate);
      endDate.setDate(endDate.getDate() - 1);
      // Calculate average daily carb target
      let totalCarbs = 0;
      for(let dayOffset = 0; dayOffset < protocolDays; dayOffset++){
        const daysBeforeRace = protocolDays - dayOffset;
        const carbProtocol = getCarbProtocolForDay(protocolDays, daysBeforeRace);
        totalCarbs += carbProtocol * bodyWeightKg;
      }
      const avgDailyCarbs = Math.round(totalCarbs / protocolDays);
      // Insert carb loading plan
      const { data: planData, error: planError } = await supabaseClient.from('carb_loading_plans').insert({
        id: plan.id,
        event_id: plan.eventId || null,
        user_id: deviceData.id,
        total_days: protocolDays,
        start_date: startDate.toISOString().split('T')[0],
        end_date: endDate.toISOString().split('T')[0],
        daily_carb_target_grams: avgDailyCarbs,
        needs_upload: false,
        local_updated_at: new Date().toISOString(),
        generated_at: new Date().toISOString()
      }).select().single();
      if (planError) throw planError;
      // Generate carb loading day records
      const dayRecords = [];
      for(let dayOffset = 0; dayOffset < protocolDays; dayOffset++){
        const dayDate = addDays(startDate, dayOffset);
        const daysBeforeRace = protocolDays - dayOffset;
        const carbProtocolGPerKg = getCarbProtocolForDay(protocolDays, daysBeforeRace);
        const targetCarbsGrams = Math.round(carbProtocolGPerKg * bodyWeightKg);
        dayRecords.push({
          id: `${plan.id}_day_${dayOffset + 1}`,
          carb_loading_plan_id: plan.id,
          plan_date: dayDate,
          day_number: dayOffset + 1,
          carb_target_grams: targetCarbsGrams,
          carb_protocol_g_per_kg: carbProtocolGPerKg,
          meal_count: 6,
          // Default meal distribution
          breakfast_percent: 0.25,
          morning_snack_percent: 0.10,
          lunch_percent: 0.25,
          afternoon_snack_percent: 0.15,
          dinner_percent: 0.20,
          evening_snack_percent: 0.05,
          logged_carbs_grams: 0,
          logged_calories: 0,
          completed: false
        });
      }
      // Batch insert day records
      const { data: daysData, error: daysError } = await supabaseClient.from('carb_loading_days').insert(dayRecords).select();
      if (daysError) throw daysError;
      result = {
        plan: planData,
        days: daysData
      };
    } else if (operation === 'update') {
      // Update carb loading day (not the plan itself)
      // This is for updating individual day progress
      const { data, error } = await supabaseClient.from('carb_loading_days').update({
        breakfast_percent: plan.breakfastPercent,
        morning_snack_percent: plan.morningSnackPercent,
        lunch_percent: plan.lunchPercent,
        afternoon_snack_percent: plan.afternoonSnackPercent,
        dinner_percent: plan.dinnerPercent,
        evening_snack_percent: plan.eveningSnackPercent,
        logged_carbs_grams: plan.loggedCarbsGrams,
        logged_calories: plan.loggedCalories,
        completed: plan.completed
      }).eq('id', plan.dayId).select().single();
      if (error) throw error;
      result = data;
    } else if (operation === 'delete') {
      // Delete carb loading plan (cascade handled by database)
      // First get all day IDs for cascade delete of meals
      const { data: days } = await supabaseClient.from('carb_loading_days').select('id').eq('carb_loading_plan_id', plan_id);
      if (days && days.length > 0) {
        // Delete all meals for these days
        const dayIds = days.map((d)=>d.id);
        await supabaseClient.from('carb_loading_day_meals').delete().in('carb_loading_day_id', dayIds);
      }
      // Delete days
      await supabaseClient.from('carb_loading_days').delete().eq('carb_loading_plan_id', plan_id);
      // Delete plan
      const { data, error } = await supabaseClient.from('carb_loading_plans').delete().eq('id', plan_id).select().single();
      if (error) throw error;
      result = data;
    }
    // 5. Return success response
    return new Response(JSON.stringify({
      success: true,
      result: result
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  } catch (error) {
    console.error('Error saving carb loading plan:', error);
    return new Response(JSON.stringify({
      error: error.message,
      code: 'SAVE_CARB_LOADING_PLAN_ERROR',
      timestamp: new Date().toISOString()
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
});
