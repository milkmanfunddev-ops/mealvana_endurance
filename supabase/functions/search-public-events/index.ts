import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
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
    const supabaseClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '', {
      auth: {
        persistSession: false
      }
    });
    const { query, limit = 10, eventType, state } = await req.json();
    if (!query || query.trim().length < 2) {
      return new Response(JSON.stringify({
        error: 'Query must be at least 2 characters'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // Call the hybrid search stored procedure
    // This combines full-text search (exact matches) with fuzzy matching (typo tolerance)
    const { data: events, error } = await supabaseClient.rpc('search_public_events_hybrid', {
      search_term: query.trim(),
      limit_count: limit,
      event_type_filter: eventType || null,
      state_filter: state || null,
      min_similarity: 0.2
    });
    if (error) {
      console.error('Search error:', error);
      return new Response(JSON.stringify({
        error: 'Failed to search events',
        details: error.message
      }), {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    const results = events || [];
    return new Response(JSON.stringify({
      events: results,
      count: results.length,
      query,
      // Include search quality metrics
      has_exact_matches: results.some((e)=>e.match_type === 'exact'),
      has_fuzzy_matches: results.some((e)=>e.match_type === 'fuzzy')
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  } catch (error) {
    console.error('Unexpected error:', error);
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
