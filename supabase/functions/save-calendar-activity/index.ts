import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface SaveActivityRequest {
  device_id: string;
  activity?: any; // Full activity object
  activity_id?: string; // For delete operations
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
    const { device_id, activity, activity_id, operation } = await req.json() as SaveActivityRequest;

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
      // Insert new activity
      const { data, error } = await supabaseClient
        .from('activities')
        .insert({
          id: activity.id,
          user_id: deviceData.id,
          activity_type: activity.activityType,
          title: activity.title,
          scheduled_date_time: activity.scheduledDateTime,
          status: activity.status || 'planned',
          distance_miles: activity.distanceMiles,
          duration_minutes: activity.durationMinutes,
          pace_target_minutes_per_mile: activity.paceTargetMinutesPerMile,
          intensity_level: activity.intensityLevel,
          intensity_target: activity.intensityTarget,
          time_before_minutes: activity.timeBeforeMinutes,
          notes: activity.notes,
          // Cycling fields
          cycling_speed_mph: activity.cyclingSpeedMph,
          cycling_terrain: activity.cyclingTerrain,
          cycling_indoor_outdoor: activity.cyclingIndoorOutdoor,
          cycling_elevation_gain_ft: activity.cyclingElevationGainFt,
          cycling_session_goal: activity.cyclingSessionGoal,
          // Swimming fields
          swimming_pace_per_100m_seconds: activity.swimmingPacePer100mSeconds,
          swimming_pool_or_open_water: activity.swimmingPoolOrOpenWater,
          swimming_water_temp_c: activity.swimmingWaterTempC,
          // Nutrition plan data (embedded JSON)
          nutrition_plan_data: activity.nutritionPlanData || null,
          // Sync tracking
          needs_upload: false,
          local_updated_at: new Date().toISOString(),
          // Timestamps
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .select()
        .single();

      if (error) throw error;
      result = data;

    } else if (operation === 'update') {
      // Update existing activity
      const { data, error } = await supabaseClient
        .from('activities')
        .update({
          activity_type: activity.activityType,
          title: activity.title,
          scheduled_date_time: activity.scheduledDateTime,
          status: activity.status,
          distance_miles: activity.distanceMiles,
          duration_minutes: activity.durationMinutes,
          pace_target_minutes_per_mile: activity.paceTargetMinutesPerMile,
          intensity_level: activity.intensityLevel,
          intensity_target: activity.intensityTarget,
          time_before_minutes: activity.timeBeforeMinutes,
          notes: activity.notes,
          // Cycling fields
          cycling_speed_mph: activity.cyclingSpeedMph,
          cycling_terrain: activity.cyclingTerrain,
          cycling_indoor_outdoor: activity.cyclingIndoorOutdoor,
          cycling_elevation_gain_ft: activity.cyclingElevationGainFt,
          cycling_session_goal: activity.cyclingSessionGoal,
          // Swimming fields
          swimming_pace_per_100m_seconds: activity.swimmingPacePer100mSeconds,
          swimming_pool_or_open_water: activity.swimmingPoolOrOpenWater,
          swimming_water_temp_c: activity.swimmingWaterTempC,
          // Nutrition plan data (embedded JSON)
          nutrition_plan_data: activity.nutritionPlanData !== undefined ? activity.nutritionPlanData : undefined,
          // Completion data (if provided)
          completed_at: activity.completedAt,
          actual_distance_miles: activity.actualDistanceMiles,
          actual_duration_minutes: activity.actualDurationMinutes,
          completion_rating: activity.completionRating,
          completion_notes: activity.completionNotes,
          // Timestamp
          updated_at: new Date().toISOString(),
        })
        .eq('id', activity.id)
        .eq('user_id', deviceData.id)
        .select()
        .single();

      if (error) throw error;
      result = data;

    } else if (operation === 'delete') {
      // Log delete attempt for debugging
      console.log('Delete operation:', { activity_id, user_id: deviceData.id });

      // Hard delete the activity
      const { data, error } = await supabaseClient
        .from('activities')
        .delete()
        .eq('id', activity_id)
        .eq('user_id', deviceData.id)
        .select();

      console.log('Delete result:', { data, error, rowCount: data?.length });

      if (error) throw error;

      // Check if any rows were deleted
      if (!data || data.length === 0) {
        throw new Error(`Activity not found or does not belong to user: ${activity_id}`);
      }

      result = data[0];
    }

    // 5. Return success response
    return new Response(
      JSON.stringify({
        success: true,
        activity: result,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );

  } catch (error) {
    console.error('Error saving activity:', error);
    return new Response(
      JSON.stringify({
        error: error.message,
        code: 'SAVE_ACTIVITY_ERROR',
        timestamp: new Date().toISOString(),
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
