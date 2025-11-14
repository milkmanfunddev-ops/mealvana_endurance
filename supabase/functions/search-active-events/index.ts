import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};

interface SearchRequest {
  query: string; // User's search keyword
}

interface ActiveComEvent {
  eventName: string;
  location?: string;
  eventDate?: string; // ISO 8601 format
  startTime?: string; // ISO 8601 format
  sportType?: string; // running, cycling, swimming, triathlon, duathlon, multisport
  eventSubtype?: string; // half_marathon, marathon, 5k, etc.
  registrationUrl?: string;
}

interface SearchResponse {
  success: boolean;
  events?: ActiveComEvent[];
  message?: string;
  error?: string;
}

/**
 * Searches RunSignup for endurance sports events
 * Returns event details including name, location, date, and sport type
 * No authentication required for public race searches
 */
serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const requestData: SearchRequest = await req.json();

    console.log('🔍 RunSignup event search request:', {
      query: requestData.query
    });

    // Validate input
    if (!requestData.query || requestData.query.trim().length === 0) {
      return new Response(JSON.stringify({
        success: false,
        message: 'Missing required field: query is required'
      } as SearchResponse), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Build RunSignup API URL
    // Docs: https://runsignup.com/API
    // No API key needed for public race searches!
    const url = new URL('https://api.runsignup.com/rest/races');
    url.searchParams.append('format', 'json');
    url.searchParams.append('name', requestData.query);
    url.searchParams.append('results_per_page', '15'); // Show more results
    url.searchParams.append('events', 'T'); // Include event details (distances)

    // Only show future races with registration open or recently ended
    const today = new Date();
    const formattedDate = today.toISOString().split('T')[0];
    url.searchParams.append('start_date', formattedDate);

    console.log('🌐 RunSignup API URL:', url.toString());

    const response = await fetch(url.toString());

    if (!response.ok) {
      console.error(`❌ RunSignup API error: ${response.status}`);
      // Fail silently - return empty results
      return new Response(JSON.stringify({
        success: true,
        events: []
      } as SearchResponse), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    const data = await response.json();

    console.log(`📊 RunSignup returned ${data.races?.length || 0} races`);

    // Log first result for debugging (if available)
    if (data.races && data.races.length > 0) {
      const firstRace = data.races[0].race;
      console.log('🔍 Sample result:', {
        name: firstRace.name,
        next_date: firstRace.next_date,
        city: firstRace.address?.city,
        state: firstRace.address?.state,
        events: firstRace.events?.length || 0
      });
    }

    // Parse RunSignup response into our event format
    const events: ActiveComEvent[] = [];

    if (data.races && Array.isArray(data.races)) {
      for (const raceWrapper of data.races) {
        const event = parseRunSignupResult(raceWrapper.race);
        if (event) {
          events.push(event);
        }
      }
    }

    console.log(`✅ Parsed ${events.length} events from RunSignup`);

    return new Response(JSON.stringify({
      success: true,
      events
    } as SearchResponse), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('❌ Error searching Active.com:', error);

    // Fail silently - return empty results
    return new Response(JSON.stringify({
      success: true,
      events: []
    } as SearchResponse), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});

/**
 * Parse RunSignup API result into our event format
 */
function parseRunSignupResult(race: any): ActiveComEvent | null {
  try {
    // Extract event name
    const eventName = race.name;
    if (!eventName) {
      return null;
    }

    // Extract location
    let location: string | undefined;
    if (race.address) {
      const city = race.address.city;
      const state = race.address.state;
      if (city && state) {
        location = `${city}, ${state}`;
      } else if (city) {
        location = city;
      }
    }

    // Extract event date/time
    // RunSignup returns dates in MM/DD/YYYY format, need to convert to ISO
    let eventDate: string | undefined;
    let startTime: string | undefined;
    if (race.next_date) {
      try {
        // Parse MM/DD/YYYY format and convert to ISO
        const [month, day, year] = race.next_date.split('/');
        eventDate = `${year}-${month.padStart(2, '0')}-${day.padStart(2, '0')}`;
        // Create ISO timestamp (using noon as default time)
        startTime = `${eventDate}T12:00:00`;
      } catch (e) {
        console.error('Error parsing date:', race.next_date);
      }
    }

    // Extract sport type from events (race distances)
    const sportType = parseSportTypeFromEvents(race.events || [], eventName);

    // Try to parse event subtype from event name or events
    const eventSubtype = parseEventSubtypeFromEvents(race.events || [], eventName, sportType);

    // Extract registration URL
    const registrationUrl = race.url;

    return {
      eventName,
      location,
      eventDate,
      startTime,
      sportType,
      eventSubtype,
      registrationUrl
    };

  } catch (error) {
    console.error('❌ Error parsing RunSignup result:', error);
    return null;
  }
}

/**
 * Map RunSignup event types and race name to our sport types
 */
function parseSportTypeFromEvents(events: any[], raceName: string): string | undefined {
  const nameLower = raceName.toLowerCase();

  // Check race name first for obvious keywords
  if (nameLower.includes('triathlon')) {
    return 'triathlon';
  }
  if (nameLower.includes('duathlon')) {
    return 'duathlon';
  }

  // Check events for sport type hints
  if (Array.isArray(events) && events.length > 0) {
    // Look at event names to determine sport type
    const eventNames = events.map((e: any) =>
      (e.event?.name || '').toLowerCase()
    );

    // Check for triathlon indicators
    if (eventNames.some(n => n.includes('swim') || n.includes('bike') || n.includes('tri'))) {
      return 'triathlon';
    }

    // Check for cycling indicators
    if (eventNames.some(n => n.includes('bike') || n.includes('cycling') || n.includes('ride'))) {
      return 'cycling';
    }

    // Check for swimming indicators
    if (eventNames.some(n => n.includes('swim'))) {
      return 'swimming';
    }
  }

  // Default to running (most common)
  if (nameLower.includes('marathon') || nameLower.includes('run') ||
      nameLower.includes('5k') || nameLower.includes('10k') ||
      nameLower.includes('trail') || nameLower.includes('ultra')) {
    return 'running';
  }

  // If we have multiple sport indicators, call it multisport
  const sportsDetected = [
    nameLower.includes('run') || nameLower.includes('marathon'),
    nameLower.includes('bike') || nameLower.includes('cycling'),
    nameLower.includes('swim')
  ].filter(Boolean).length;

  if (sportsDetected > 1) {
    return 'multisport';
  }

  return 'running'; // Default to running
}

/**
 * Try to parse event subtype from events array and event name
 * Examples: "Boston Marathon" -> "marathon", "NYC Half Marathon" -> "half_marathon"
 */
function parseEventSubtypeFromEvents(events: any[], eventName: string, sportType?: string): string | undefined {
  const nameLower = eventName.toLowerCase();

  // Running event subtypes
  if (sportType === 'running' || !sportType) {
    if (nameLower.includes('ultra') || nameLower.includes('100k') || nameLower.includes('100 mile')) {
      return 'ultra';
    }
    if (nameLower.includes('marathon') && !nameLower.includes('half')) {
      return 'marathon';
    }
    if (nameLower.includes('half marathon') || nameLower.includes('half-marathon')) {
      return 'half_marathon';
    }
    if (nameLower.includes('10 mile') || nameLower.includes('10-mile')) {
      return 'ten_mile';
    }
    if (nameLower.includes('15k')) {
      return 'fifteen_k';
    }
    if (nameLower.includes('10k')) {
      return 'ten_k';
    }
    if (nameLower.includes('5k')) {
      return 'five_k';
    }
    if (nameLower.includes('5 mile') || nameLower.includes('5-mile')) {
      return 'five_mile';
    }

    // Check events array for distance hints
    if (Array.isArray(events) && events.length > 0) {
      const eventNames = events.map((e: any) => (e.event?.name || '').toLowerCase());

      if (eventNames.some(n => n.includes('marathon') && !n.includes('half'))) {
        return 'marathon';
      }
      if (eventNames.some(n => n.includes('half'))) {
        return 'half_marathon';
      }
    }
  }

  // Triathlon event subtypes
  if (sportType === 'triathlon') {
    if (nameLower.includes('ironman') && !nameLower.includes('70.3')) {
      return 'ironman';
    }
    if (nameLower.includes('70.3') || nameLower.includes('half ironman')) {
      return 'half_ironman';
    }
    if (nameLower.includes('olympic')) {
      return 'olympic';
    }
    if (nameLower.includes('sprint')) {
      return 'sprint';
    }
  }

  // Cycling event subtypes
  if (sportType === 'cycling') {
    if (nameLower.includes('century') || nameLower.includes('100 mile')) {
      return 'century';
    }
    if (nameLower.includes('gran fondo') || nameLower.includes('granfondo')) {
      return 'gran_fondo';
    }
  }

  return undefined;
}
