import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface SearchRequest {
  query: string;
  limit?: number;
  eventType?: string; // Optional filter by sport type
  state?: string; // Optional filter by state
}

interface PublicEvent {
  id: number;
  event_name: string;
  event_type: string;
  event_subtype: string | null;
  location: string | null;
  city: string | null;
  state: string | null;
  event_date: string | null;
  start_time: string | null;
  registration_url: string | null;
  website_url: string | null;
  description: string | null;
  organizer_name: string | null;
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          persistSession: false,
        },
      }
    );

    const { query, limit = 10, eventType, state }: SearchRequest = await req.json();

    if (!query || query.trim().length < 2) {
      return new Response(
        JSON.stringify({ error: 'Query must be at least 2 characters' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Build the search query
    let dbQuery = supabaseClient
      .from('public_events')
      .select('*')
      .eq('is_active', true)
      .gte('event_date', new Date().toISOString().split('T')[0]) // Only future events
      .order('event_date', { ascending: true });

    // Apply filters
    if (eventType) {
      dbQuery = dbQuery.eq('event_type', eventType);
    }

    if (state) {
      dbQuery = dbQuery.ilike('state', `%${state}%`);
    }

    // Full-text search using the search_vector column
    // Use plainto_tsquery for natural language queries
    dbQuery = dbQuery.textSearch('search_vector', query, {
      type: 'plain',
      config: 'english',
    });

    dbQuery = dbQuery.limit(limit);

    const { data: events, error } = await dbQuery;

    if (error) {
      console.error('Database error:', error);
      return new Response(
        JSON.stringify({ error: 'Failed to search events', details: error.message }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // If full-text search returns no results, try fallback with ILIKE
    let results = events || [];

    if (results.length === 0) {
      console.log('Full-text search returned no results, trying ILIKE fallback');

      let fallbackQuery = supabaseClient
        .from('public_events')
        .select('*')
        .eq('is_active', true)
        .gte('event_date', new Date().toISOString().split('T')[0])
        .or(`event_name.ilike.%${query}%,city.ilike.%${query}%,state.ilike.%${query}%`)
        .order('event_date', { ascending: true })
        .limit(limit);

      if (eventType) {
        fallbackQuery = fallbackQuery.eq('event_type', eventType);
      }

      if (state) {
        fallbackQuery = fallbackQuery.ilike('state', `%${state}%`);
      }

      const { data: fallbackEvents, error: fallbackError } = await fallbackQuery;

      if (fallbackError) {
        console.error('Fallback search error:', fallbackError);
      } else {
        results = fallbackEvents || [];
      }
    }

    // Sort results by date proximity (upcoming events first)
    const sortedResults = results.sort((a, b) => {
      const dateA = new Date(a.event_date || '9999-12-31');
      const dateB = new Date(b.event_date || '9999-12-31');
      return dateA.getTime() - dateB.getTime();
    });

    return new Response(
      JSON.stringify({
        events: sortedResults,
        count: sortedResults.length,
        query,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Unexpected error:', error);
    return new Response(
      JSON.stringify({
        error: 'Internal server error',
        details: error instanceof Error ? error.message : 'Unknown error'
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
