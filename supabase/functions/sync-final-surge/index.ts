/**
 * Final Surge Sync Edge Function
 *
 * This function handles synchronization with Final Surge's Partner API:
 * - OAuth token exchange
 * - Fetching upcoming workouts
 * - Storing/retrieving user tokens from Supabase
 *
 * Endpoints (via action parameter):
 * - exchange_token: Exchange OAuth code for access token
 * - get_workouts: Fetch upcoming workouts for a user
 * - get_profile: Fetch user's Final Surge profile info
 *
 * API Docs: /docs/final_surge/Final-Surge-Partner-API-Uploads.pdf
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

// CORS headers for cross-origin requests
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Final Surge API configuration
const FINAL_SURGE_BASE_URL = 'https://log.finalsurge.com';
const FINAL_SURGE_CLIENT_ID = Deno.env.get('FINAL_SURGE_CLIENT_ID') ?? '';
const FINAL_SURGE_CLIENT_SECRET = Deno.env.get('FINAL_SURGE_CLIENT_SECRET') ?? '';

// Response helper
function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function errorResponse(message: string, status = 400, details?: string) {
  return jsonResponse({ success: false, error: message, details }, status);
}

// ============================================================================
// FINAL SURGE API FUNCTIONS
// ============================================================================

/**
 * Exchange OAuth authorization code for access token
 */
async function exchangeToken(code: string): Promise<{
  success: boolean;
  access_token?: string;
  athlete_id?: string;
  firstname?: string;
  lastname?: string;
  error?: string;
}> {
  try {
    const response = await fetch(`${FINAL_SURGE_BASE_URL}/oauth/token`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        'client-id': FINAL_SURGE_CLIENT_ID,
        'client-secret': FINAL_SURGE_CLIENT_SECRET,
        'code': code,
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('Token exchange failed:', response.status, errorText);
      return { success: false, error: `Token exchange failed: ${response.status}` };
    }

    const data = await response.json();
    return {
      success: true,
      access_token: data.access_token,
      athlete_id: data.id,
      firstname: data.firstname,
      lastname: data.lastname,
    };
  } catch (error) {
    console.error('Token exchange error:', error);
    return { success: false, error: error instanceof Error ? error.message : 'Unknown error' };
  }
}

/**
 * Fetch upcoming workouts from Final Surge
 */
async function fetchUpcomingWorkouts(
  accessToken: string,
  numDays = 7,
  numWorkouts = 21
): Promise<{
  success: boolean;
  workouts?: FinalSurgeWorkout[];
  error?: string;
}> {
  try {
    const url = new URL(`${FINAL_SURGE_BASE_URL}/API/v1/UpcomingWorkouts`);
    url.searchParams.set('NumDays', numDays.toString());
    url.searchParams.set('NumWorkouts', numWorkouts.toString());

    const response = await fetch(url.toString(), {
      method: 'GET',
      headers: {
        'client-id': FINAL_SURGE_CLIENT_ID,
        'Authorization': `Bearer ${accessToken}`,
      },
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('Fetch workouts failed:', response.status, errorText);

      // Check for expired/invalid token
      if (response.status === 401) {
        return { success: false, error: 'Token expired or invalid' };
      }

      return { success: false, error: `Failed to fetch workouts: ${response.status}` };
    }

    const data = await response.json();
    return {
      success: true,
      workouts: data.workouts || [],
    };
  } catch (error) {
    console.error('Fetch workouts error:', error);
    return { success: false, error: error instanceof Error ? error.message : 'Unknown error' };
  }
}

/**
 * Fetch user profile info from Final Surge
 */
async function fetchProfileInfo(accessToken: string): Promise<{
  success: boolean;
  uniqueid?: string;
  profile?: string;
  error?: string;
}> {
  try {
    const response = await fetch(`${FINAL_SURGE_BASE_URL}/API/v1/ProfileInfo`, {
      method: 'GET',
      headers: {
        'client-id': FINAL_SURGE_CLIENT_ID,
        'Authorization': `Bearer ${accessToken}`,
      },
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('Fetch profile failed:', response.status, errorText);

      if (response.status === 401) {
        return { success: false, error: 'Token expired or invalid' };
      }

      return { success: false, error: `Failed to fetch profile: ${response.status}` };
    }

    const data = await response.json();
    return {
      success: true,
      uniqueid: data.uniqueid,
      profile: data.profile,
    };
  } catch (error) {
    console.error('Fetch profile error:', error);
    return { success: false, error: error instanceof Error ? error.message : 'Unknown error' };
  }
}

// ============================================================================
// TYPE DEFINITIONS
// ============================================================================

interface FinalSurgeWorkout {
  workoutId: string;
  workoutName: string;
  workoutDate: string;
  sport: 'RUNNING' | 'CYCLING' | 'SWIMMING' | string;
  workoutIcon: number;
  steps?: FinalSurgeStep[];
  // Additional fields from API
  poolLength?: number;
  poolLengthUnit?: string;
}

interface FinalSurgeStep {
  stepType: 'WorkoutStep' | 'WorkoutRampStep' | 'WorkoutRepeatStep';
  intensity?: 'ACTIVE' | 'REST' | 'WARMUP' | 'COOLDOWN';
  durationType?: 'TIME' | 'DISTANCE' | 'OPEN';
  durationValue?: number;
  durationUnit?: string;
  targetType?: 'POWER' | 'HEART_RATE' | 'PACE';
  targetValueLow?: number;
  targetValueHigh?: number;
  // For repeat steps
  repeatCount?: number;
  childSteps?: FinalSurgeStep[];
}

interface RequestBody {
  action: 'exchange_token' | 'get_workouts' | 'get_profile' | 'save_token' | 'get_token';
  code?: string;           // For exchange_token
  access_token?: string;   // For get_workouts, get_profile
  user_id?: string;        // For save_token, get_token
  num_days?: number;       // For get_workouts
  num_workouts?: number;   // For get_workouts
  athlete_id?: string;     // For save_token
  firstname?: string;      // For save_token
  lastname?: string;       // For save_token
}

// ============================================================================
// MAIN HANDLER
// ============================================================================

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Validate configuration
    if (!FINAL_SURGE_CLIENT_ID || !FINAL_SURGE_CLIENT_SECRET) {
      console.error('Missing Final Surge credentials');
      return errorResponse('Server configuration error', 500);
    }

    // Parse request body
    const body: RequestBody = await req.json();
    const { action } = body;

    if (!action) {
      return errorResponse('Missing action parameter');
    }

    // Initialize Supabase client for token storage operations
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { persistSession: false } }
    );

    // Route to appropriate handler
    switch (action) {
      // ======================================================================
      // EXCHANGE TOKEN
      // ======================================================================
      case 'exchange_token': {
        const { code, user_id } = body;

        if (!code) {
          return errorResponse('Missing authorization code');
        }

        const result = await exchangeToken(code);

        if (!result.success) {
          return errorResponse(result.error || 'Token exchange failed', 401);
        }

        // If user_id provided, save the token to Supabase user metadata
        if (user_id && result.access_token) {
          const { error: updateError } = await supabaseClient.auth.admin.updateUserById(
            user_id,
            {
              user_metadata: {
                final_surge_token: result.access_token,
                final_surge_athlete_id: result.athlete_id,
                final_surge_firstname: result.firstname,
                final_surge_lastname: result.lastname,
                final_surge_connected_at: new Date().toISOString(),
              },
            }
          );

          if (updateError) {
            console.error('Failed to save token to user metadata:', updateError);
            // Don't fail the request, token exchange was successful
          }
        }

        return jsonResponse({
          success: true,
          access_token: result.access_token,
          athlete_id: result.athlete_id,
          firstname: result.firstname,
          lastname: result.lastname,
        });
      }

      // ======================================================================
      // GET WORKOUTS
      // ======================================================================
      case 'get_workouts': {
        const { access_token, user_id, num_days = 7, num_workouts = 21 } = body;

        // Get token from parameter or from user metadata
        let token = access_token;

        if (!token && user_id) {
          const { data: userData, error: userError } = await supabaseClient.auth.admin.getUserById(user_id);

          if (userError || !userData?.user) {
            return errorResponse('User not found', 404);
          }

          token = userData.user.user_metadata?.final_surge_token;
        }

        if (!token) {
          return errorResponse('Missing access token or user not connected to Final Surge', 401);
        }

        const result = await fetchUpcomingWorkouts(token, num_days, num_workouts);

        if (!result.success) {
          return errorResponse(result.error || 'Failed to fetch workouts', 500);
        }

        // Transform workouts to Mealvana format (running only for MVP)
        const runningWorkouts = (result.workouts || [])
          .filter((w) => w.sport === 'RUNNING')
          .map((w) => ({
            external_id: w.workoutId,
            source: 'final_surge',
            name: w.workoutName,
            date: w.workoutDate,
            sport_type: 'running',
            // Parse structured workout for duration/distance
            ...parseWorkoutDetails(w),
          }));

        return jsonResponse({
          success: true,
          workouts: runningWorkouts,
          total_count: result.workouts?.length || 0,
          running_count: runningWorkouts.length,
        });
      }

      // ======================================================================
      // GET PROFILE
      // ======================================================================
      case 'get_profile': {
        const { access_token, user_id } = body;

        let token = access_token;

        if (!token && user_id) {
          const { data: userData, error: userError } = await supabaseClient.auth.admin.getUserById(user_id);

          if (userError || !userData?.user) {
            return errorResponse('User not found', 404);
          }

          token = userData.user.user_metadata?.final_surge_token;
        }

        if (!token) {
          return errorResponse('Missing access token or user not connected to Final Surge', 401);
        }

        const result = await fetchProfileInfo(token);

        if (!result.success) {
          return errorResponse(result.error || 'Failed to fetch profile', 500);
        }

        return jsonResponse({
          success: true,
          uniqueid: result.uniqueid,
          profile: result.profile,
        });
      }

      // ======================================================================
      // UNKNOWN ACTION
      // ======================================================================
      default:
        return errorResponse(`Unknown action: ${action}`);
    }
  } catch (error) {
    console.error('Unexpected error:', error);
    return errorResponse(
      'Internal server error',
      500,
      error instanceof Error ? error.message : 'Unknown error'
    );
  }
});

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Parse workout steps to extract total duration/distance
 */
function parseWorkoutDetails(workout: FinalSurgeWorkout): {
  estimated_duration_minutes?: number;
  estimated_distance_meters?: number;
} {
  if (!workout.steps || workout.steps.length === 0) {
    return {};
  }

  let totalDurationSeconds = 0;
  let totalDistanceMeters = 0;

  function processStep(step: FinalSurgeStep, repeatMultiplier = 1) {
    if (step.stepType === 'WorkoutRepeatStep') {
      const repeatCount = step.repeatCount || 1;
      for (const childStep of step.childSteps || []) {
        processStep(childStep, repeatMultiplier * repeatCount);
      }
    } else if (step.durationType === 'TIME' && step.durationValue) {
      // Duration is in seconds
      totalDurationSeconds += step.durationValue * repeatMultiplier;
    } else if (step.durationType === 'DISTANCE' && step.durationValue) {
      // Distance is in meters
      totalDistanceMeters += step.durationValue * repeatMultiplier;
    }
  }

  for (const step of workout.steps) {
    processStep(step);
  }

  const result: {
    estimated_duration_minutes?: number;
    estimated_distance_meters?: number;
  } = {};

  if (totalDurationSeconds > 0) {
    result.estimated_duration_minutes = Math.round(totalDurationSeconds / 60);
  }

  if (totalDistanceMeters > 0) {
    result.estimated_distance_meters = totalDistanceMeters;
  }

  return result;
}
