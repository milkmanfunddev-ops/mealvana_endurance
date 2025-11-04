import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface SaveEventRequest {
  device_id: string;
  event?: any; // Full event object
  event_id?: string; // For delete operations
  operation: 'create' | 'update' | 'delete';
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. Initialize Supabase client with service role key to bypass RLS
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    // 2. Parse request
    const { device_id, event, event_id, operation } = await req.json() as SaveEventRequest;

    // 3. Validate device exists
    const { data: deviceData, error: deviceError } = await supabaseClient
      .from('users')
      .select('id, device_id')
      .eq('device_id', device_id)
      .single();

    if (deviceError || !deviceData) {
      return new Response(
        JSON.stringify({ error: 'Invalid device_id' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 4. Perform operation
    let result;

    if (operation === 'create') {
      // Validate linked activity if provided
      if (event.activityId) {
        const { data: activityData, error: activityError } = await supabaseClient
          .from('activities')
          .select('id')
          .eq('id', event.activityId)
          .eq('user_id', deviceData.id)
          .single();

        if (activityError || !activityData) {
          return new Response(
            JSON.stringify({ error: 'Invalid activity_id or activity does not belong to user' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }
      }

      // Insert new event
      const { data, error } = await supabaseClient
        .from('events')
        .insert({
          id: event.id,
          device_id: device_id,
          user_id: deviceData.id,
          activity_id: event.activityId || null,
          event_type: event.eventType,
          event_subtype: event.eventSubtype,
          event_name: event.eventName,
          location: event.location,
          registration_url: event.registrationUrl,
          start_time: event.startTime,
          goal_time_minutes: event.goalTimeMinutes,
          goal_pace_minutes_per_mile: event.goalPaceMinutesPerMile,
          predicted_finish_time_minutes: event.predictedFinishTimeMinutes,
          has_carb_loading: event.hasCarbLoading || false,
          carb_loading_days: event.carbLoadingDays,
          carb_loading_start_date: event.carbLoadingStartDate,
          has_nutrition_plan: event.hasNutritionPlan || false,
          bib_number: event.bibNumber,
          wave_start_time: event.waveStartTime,
          packet_pickup_info: event.packetPickupInfo,
          actual_finish_time_minutes: event.actualFinishTimeMinutes,
          final_placement: event.finalPlacement,
          age_group_placement: event.ageGroupPlacement,
          needs_upload: false,
          local_updated_at: new Date().toISOString(),
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .select()
        .single();

      if (error) throw error;
      result = data;

    } else if (operation === 'update') {
      // Validate linked activity if provided
      if (event.activityId) {
        const { data: activityData, error: activityError } = await supabaseClient
          .from('activities')
          .select('id')
          .eq('id', event.activityId)
          .eq('user_id', deviceData.id)
          .single();

        if (activityError || !activityData) {
          return new Response(
            JSON.stringify({ error: 'Invalid activity_id or activity does not belong to user' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }
      }

      // Update existing event
      const { data, error } = await supabaseClient
        .from('events')
        .update({
          activity_id: event.activityId || null,
          event_type: event.eventType,
          event_subtype: event.eventSubtype,
          event_name: event.eventName,
          location: event.location,
          registration_url: event.registrationUrl,
          start_time: event.startTime,
          goal_time_minutes: event.goalTimeMinutes,
          goal_pace_minutes_per_mile: event.goalPaceMinutesPerMile,
          predicted_finish_time_minutes: event.predictedFinishTimeMinutes,
          has_carb_loading: event.hasCarbLoading,
          carb_loading_days: event.carbLoadingDays,
          carb_loading_start_date: event.carbLoadingStartDate,
          has_nutrition_plan: event.hasNutritionPlan,
          bib_number: event.bibNumber,
          wave_start_time: event.waveStartTime,
          packet_pickup_info: event.packetPickupInfo,
          actual_finish_time_minutes: event.actualFinishTimeMinutes,
          final_placement: event.finalPlacement,
          age_group_placement: event.ageGroupPlacement,
          updated_at: new Date().toISOString(),
        })
        .eq('id', event.id)
        .select()
        .single();

      if (error) throw error;
      result = data;

    } else if (operation === 'delete') {
      // Hard delete event (cascade handled by database)
      const { data, error } = await supabaseClient
        .from('events')
        .delete()
        .eq('id', event_id)
        .select()
        .single();

      if (error) throw error;
      result = data;
    }

    // 5. Return success response
    return new Response(
      JSON.stringify({
        success: true,
        event: result,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );

  } catch (error) {
    console.error('Error saving event:', error);
    return new Response(
      JSON.stringify({
        error: error.message,
        code: 'SAVE_EVENT_ERROR',
        timestamp: new Date().toISOString(),
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
