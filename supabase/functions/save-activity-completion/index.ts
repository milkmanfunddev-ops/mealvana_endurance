import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface SaveActivityCompletionRequest {
  device_id: string;
  completion: any; // Full completion object
  operation: 'create' | 'update';
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
    const { device_id, completion, operation } = await req.json() as SaveActivityCompletionRequest;

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

    // 4. Validate activity exists and belongs to user
    const { data: activityData, error: activityError } = await supabaseClient
      .from('activities')
      .select('id')
      .eq('id', completion.activityId)
      .eq('user_id', deviceData.id)
      .single();

    if (activityError || !activityData) {
      return new Response(
        JSON.stringify({ error: 'Invalid activity_id or activity does not belong to user' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 5. Upsert completion metadata directly onto activities table
    const completionPayload = {
      status: 'completed',
      completed_at: completion.completedAt,
      completion_type: completion.completionType || 'manual',
      actual_distance_miles: completion.actualDistanceMiles,
      actual_duration_minutes: completion.actualDurationMinutes,
      average_pace_minutes_per_mile: completion.averagePaceMinutesPerMile,
      max_heart_rate: completion.maxHeartRate,
      average_heart_rate: completion.averageHeartRate,
      calories_burned: completion.caloriesBurned,
      effort_rating: completion.effortRating,
      nutrition_rating: completion.nutritionRating,
      overall_satisfaction: completion.overallSatisfaction,
      completion_notes: completion.textNotes,
      voice_note_id: completion.voiceNoteId,
      has_voice_recording: completion.hasVoiceRecording ?? false,
      weather_conditions: completion.weatherConditions,
      temperature_fahrenheit: completion.temperatureFahrenheit,
      humidity_percent: completion.humidityPercent,
      nutrition_adherence_score: completion.nutritionAdherenceScore,
      performance_vs_target: completion.performanceVsTarget,
      needs_upload: false,
      local_updated_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    const { data: updatedActivity, error: updateError } = await supabaseClient
      .from('activities')
      .update(completionPayload)
      .eq('id', completion.activityId)
      .eq('user_id', deviceData.id)
      .select()
      .single();

    if (updateError) {
      throw updateError;
    }

    // 6. Return success response
    return new Response(
      JSON.stringify({
        success: true,
        completion: updatedActivity,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );

  } catch (error) {
    console.error('Error saving activity completion:', error);
    return new Response(
      JSON.stringify({
        error: error.message,
        code: 'SAVE_ACTIVITY_COMPLETION_ERROR',
        timestamp: new Date().toISOString(),
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
