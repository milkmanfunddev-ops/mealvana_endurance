import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
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
    const { device_id, completion, operation } = await req.json();
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
    // 4. Validate activity exists and belongs to user
    const { data: activityData, error: activityError } = await supabaseClient.from('activities').select('id').eq('id', completion.activityId).eq('user_id', deviceData.id).single();
    if (activityError || !activityData) {
      return new Response(JSON.stringify({
        error: 'Invalid activity_id or activity does not belong to user'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // 5. Perform operation
    let result;
    if (operation === 'create') {
      // Insert new completion record
      const { data, error } = await supabaseClient.from('activity_completions').insert({
        id: completion.id,
        device_id: device_id,
        activity_id: completion.activityId,
        user_id: deviceData.id,
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
        text_notes: completion.textNotes,
        voice_note_id: completion.voiceNoteId,
        has_voice_recording: completion.hasVoiceRecording || false,
        weather_conditions: completion.weatherConditions,
        temperature_fahrenheit: completion.temperatureFahrenheit,
        humidity_percent: completion.humidityPercent,
        nutrition_adherence_score: completion.nutritionAdherenceScore,
        performance_vs_target: completion.performanceVsTarget,
        needs_upload: false,
        local_updated_at: new Date().toISOString(),
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      }).select().single();
      if (error) throw error;
      result = data;
      // Update activity status to completed
      await supabaseClient.from('activities').update({
        status: 'completed',
        completed_at: completion.completedAt,
        actual_distance_miles: completion.actualDistanceMiles,
        actual_duration_minutes: completion.actualDurationMinutes,
        updated_at: new Date().toISOString()
      }).eq('id', completion.activityId);
    } else if (operation === 'update') {
      // Update existing completion record
      const { data, error } = await supabaseClient.from('activity_completions').update({
        completed_at: completion.completedAt,
        completion_type: completion.completionType,
        actual_distance_miles: completion.actualDistanceMiles,
        actual_duration_minutes: completion.actualDurationMinutes,
        average_pace_minutes_per_mile: completion.averagePaceMinutesPerMile,
        max_heart_rate: completion.maxHeartRate,
        average_heart_rate: completion.averageHeartRate,
        calories_burned: completion.caloriesBurned,
        effort_rating: completion.effortRating,
        nutrition_rating: completion.nutritionRating,
        overall_satisfaction: completion.overallSatisfaction,
        text_notes: completion.textNotes,
        voice_note_id: completion.voiceNoteId,
        has_voice_recording: completion.hasVoiceRecording,
        weather_conditions: completion.weatherConditions,
        temperature_fahrenheit: completion.temperatureFahrenheit,
        humidity_percent: completion.humidityPercent,
        nutrition_adherence_score: completion.nutritionAdherenceScore,
        performance_vs_target: completion.performanceVsTarget
      }).eq('id', completion.id).eq('user_id', deviceData.id).select().single();
      if (error) throw error;
      result = data;
      // Update activity completion data
      await supabaseClient.from('activities').update({
        actual_distance_miles: completion.actualDistanceMiles,
        actual_duration_minutes: completion.actualDurationMinutes,
        updated_at: new Date().toISOString()
      }).eq('id', completion.activityId);
    }
    // 6. Return success response
    return new Response(JSON.stringify({
      success: true,
      completion: result
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  } catch (error) {
    console.error('Error saving activity completion:', error);
    return new Response(JSON.stringify({
      error: error.message,
      code: 'SAVE_ACTIVITY_COMPLETION_ERROR',
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
