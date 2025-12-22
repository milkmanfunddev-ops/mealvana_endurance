import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface UploadRequest {
  user_id: string;
  dirty_records?: {
    activities?: any[];
    events?: any[];
    carb_loading_plans?: any[];
    carb_loading_days?: any[];
    carb_loading_day_meals?: any[];
    user_foods?: any[];
    feedback?: any[];
    feature_survey_responses?: any[];
    food_preferences?: any[];
  };
}

interface TableResult {
  success: boolean;
  uploaded: number;
  error?: string;
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Parse request
    const { user_id, dirty_records }: UploadRequest = await req.json();

    if (!user_id) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'user_id is required',
          timestamp: new Date().toISOString(),
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400,
        }
      );
    }

    console.log(`Starting upload for user: ${user_id}`);

    // If no dirty records provided, that's a success (nothing to upload)
    if (!dirty_records || Object.keys(dirty_records).length === 0) {
      console.log('No dirty records to upload - returning success');
      return new Response(
        JSON.stringify({
          success: true,
          timestamp: new Date().toISOString(),
          results: {},
          message: 'No dirty records to upload',
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      );
    }

    // Create Supabase client with SERVICE_ROLE_KEY to bypass RLS
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    // Results for each table
    const results: Record<string, TableResult> = {};

    // Upload activities
    if (dirty_records?.activities && dirty_records.activities.length > 0) {
      try {
        console.log(`Uploading ${dirty_records.activities.length} activities...`);
        const { error } = await supabaseClient
          .from('activities')
          .upsert(dirty_records.activities, { onConflict: 'id' });

        if (error) throw error;

        results.activities = {
          success: true,
          uploaded: dirty_records.activities.length,
        };
        console.log(`✓ Uploaded ${dirty_records.activities.length} activities`);
      } catch (error) {
        console.error(`✗ Failed to upload activities: ${error.message}`);
        results.activities = {
          success: false,
          uploaded: 0,
          error: error.message,
        };
      }
    }

    // Upload events
    if (dirty_records?.events && dirty_records.events.length > 0) {
      try {
        console.log(`Uploading ${dirty_records.events.length} events...`);
        const { error } = await supabaseClient
          .from('events')
          .upsert(dirty_records.events, { onConflict: 'id' });

        if (error) throw error;

        results.events = {
          success: true,
          uploaded: dirty_records.events.length,
        };
        console.log(`✓ Uploaded ${dirty_records.events.length} events`);
      } catch (error) {
        console.error(`✗ Failed to upload events: ${error.message}`);
        results.events = {
          success: false,
          uploaded: 0,
          error: error.message,
        };
      }
    }

    // Upload carb_loading_plans
    if (dirty_records?.carb_loading_plans && dirty_records.carb_loading_plans.length > 0) {
      try {
        console.log(`Uploading ${dirty_records.carb_loading_plans.length} carb_loading_plans...`);
        const { error } = await supabaseClient
          .from('carb_loading_plans')
          .upsert(dirty_records.carb_loading_plans, { onConflict: 'id' });

        if (error) throw error;

        results.carb_loading_plans = {
          success: true,
          uploaded: dirty_records.carb_loading_plans.length,
        };
        console.log(`✓ Uploaded ${dirty_records.carb_loading_plans.length} carb_loading_plans`);
      } catch (error) {
        console.error(`✗ Failed to upload carb_loading_plans: ${error.message}`);
        results.carb_loading_plans = {
          success: false,
          uploaded: 0,
          error: error.message,
        };
      }
    }

    // Upload carb_loading_days
    if (dirty_records?.carb_loading_days && dirty_records.carb_loading_days.length > 0) {
      try {
        console.log(`Uploading ${dirty_records.carb_loading_days.length} carb_loading_days...`);
        const { error } = await supabaseClient
          .from('carb_loading_days')
          .upsert(dirty_records.carb_loading_days, { onConflict: 'id' });

        if (error) throw error;

        results.carb_loading_days = {
          success: true,
          uploaded: dirty_records.carb_loading_days.length,
        };
        console.log(`✓ Uploaded ${dirty_records.carb_loading_days.length} carb_loading_days`);
      } catch (error) {
        console.error(`✗ Failed to upload carb_loading_days: ${error.message}`);
        results.carb_loading_days = {
          success: false,
          uploaded: 0,
          error: error.message,
        };
      }
    }

    // Upload carb_loading_day_meals
    if (dirty_records?.carb_loading_day_meals && dirty_records.carb_loading_day_meals.length > 0) {
      try {
        console.log(`Uploading ${dirty_records.carb_loading_day_meals.length} carb_loading_day_meals...`);
        const { error } = await supabaseClient
          .from('carb_loading_day_meals')
          .upsert(dirty_records.carb_loading_day_meals, { onConflict: 'id' });

        if (error) throw error;

        results.carb_loading_day_meals = {
          success: true,
          uploaded: dirty_records.carb_loading_day_meals.length,
        };
        console.log(`✓ Uploaded ${dirty_records.carb_loading_day_meals.length} carb_loading_day_meals`);
      } catch (error) {
        console.error(`✗ Failed to upload carb_loading_day_meals: ${error.message}`);
        results.carb_loading_day_meals = {
          success: false,
          uploaded: 0,
          error: error.message,
        };
      }
    }

    // Upload user_foods
    if (dirty_records?.user_foods && dirty_records.user_foods.length > 0) {
      try {
        console.log(`Uploading ${dirty_records.user_foods.length} user_foods...`);
        const { error } = await supabaseClient
          .from('user_foods')
          .upsert(dirty_records.user_foods, { onConflict: 'id' });

        if (error) throw error;

        results.user_foods = {
          success: true,
          uploaded: dirty_records.user_foods.length,
        };
        console.log(`✓ Uploaded ${dirty_records.user_foods.length} user_foods`);
      } catch (error) {
        console.error(`✗ Failed to upload user_foods: ${error.message}`);
        results.user_foods = {
          success: false,
          uploaded: 0,
          error: error.message,
        };
      }
    }

    // Upload feedback
    if (dirty_records?.feedback && dirty_records.feedback.length > 0) {
      try {
        console.log(`Uploading ${dirty_records.feedback.length} feedback...`);
        const { error } = await supabaseClient
          .from('feedback')
          .upsert(dirty_records.feedback, { onConflict: 'id' });

        if (error) throw error;

        results.feedback = {
          success: true,
          uploaded: dirty_records.feedback.length,
        };
        console.log(`✓ Uploaded ${dirty_records.feedback.length} feedback`);
      } catch (error) {
        console.error(`✗ Failed to upload feedback: ${error.message}`);
        results.feedback = {
          success: false,
          uploaded: 0,
          error: error.message,
        };
      }
    }

    // Upload feature_survey_responses
    if (dirty_records?.feature_survey_responses && dirty_records.feature_survey_responses.length > 0) {
      try {
        console.log(`Uploading ${dirty_records.feature_survey_responses.length} feature_survey_responses...`);
        const { error } = await supabaseClient
          .from('feature_survey_responses')
          .upsert(dirty_records.feature_survey_responses, { onConflict: 'id' });

        if (error) throw error;

        results.feature_survey_responses = {
          success: true,
          uploaded: dirty_records.feature_survey_responses.length,
        };
        console.log(`✓ Uploaded ${dirty_records.feature_survey_responses.length} feature_survey_responses`);
      } catch (error) {
        console.error(`✗ Failed to upload feature_survey_responses: ${error.message}`);
        results.feature_survey_responses = {
          success: false,
          uploaded: 0,
          error: error.message,
        };
      }
    }

    // Upload food_preferences
    if (dirty_records?.food_preferences && dirty_records.food_preferences.length > 0) {
      try {
        console.log(`Uploading ${dirty_records.food_preferences.length} food_preferences...`);
        const { error } = await supabaseClient
          .from('food_preferences')
          .upsert(dirty_records.food_preferences, { onConflict: 'id' });

        if (error) throw error;

        results.food_preferences = {
          success: true,
          uploaded: dirty_records.food_preferences.length,
        };
        console.log(`✓ Uploaded ${dirty_records.food_preferences.length} food_preferences`);
      } catch (error) {
        console.error(`✗ Failed to upload food_preferences: ${error.message}`);
        results.food_preferences = {
          success: false,
          uploaded: 0,
          error: error.message,
        };
      }
    }

    // Check if at least one table succeeded
    // Success if no tables were processed (empty payload handled above) OR any table succeeded
    const anySuccess = Object.keys(results).length === 0 || Object.values(results).some(r => r.success);
    const totalUploaded = Object.values(results).reduce((sum, r) => sum + r.uploaded, 0);
    const failedTables = Object.entries(results).filter(([_, r]) => !r.success).map(([name, _]) => name);

    console.log(`Upload completed: ${totalUploaded} total records uploaded`);
    if (failedTables.length > 0) {
      console.log(`Failed tables: ${failedTables.join(', ')}`);
    }

    return new Response(
      JSON.stringify({
        success: anySuccess,
        timestamp: new Date().toISOString(),
        results,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: anySuccess ? 200 : 500,
      },
    );
  } catch (error) {
    console.error('Unexpected error in upload-all-data:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Unknown error',
        timestamp: new Date().toISOString(),
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      },
    );
  }
});
