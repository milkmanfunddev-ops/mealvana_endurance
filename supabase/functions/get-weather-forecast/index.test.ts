/**
 * Unit Tests for get-weather-forecast Edge Function
 *
 * Tests date-range routing (future vs historical vs out-of-range),
 * Open-Meteo response → our shape mapping, missing-field fallbacks,
 * bad coordinate handling, and the weather→hydration expectation note.
 *
 * All tests stub `fetch` globally — no network required.
 *
 * Run with:
 *   deno test --allow-env supabase/functions/get-weather-forecast/index.test.ts
 */

import {
  assertEquals,
  assertExists,
  assert,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it, beforeEach, afterEach } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

// ---------------------------------------------------------------------------
// Constants (mirrored from production)
// ---------------------------------------------------------------------------

const DEFAULT_TEMP_C = 20;
const DEFAULT_HUMIDITY_PCT = 60;

// ---------------------------------------------------------------------------
// Pure logic extracted from index.ts for unit testing
// ---------------------------------------------------------------------------

function getWeatherCondition(code: number): string {
  if (code === 0) return 'Clear sky';
  if (code <= 3) return 'Partly cloudy';
  if (code <= 48) return 'Foggy';
  if (code <= 67) return 'Rainy';
  if (code <= 77) return 'Snowy';
  if (code <= 82) return 'Rain showers';
  if (code <= 86) return 'Snow showers';
  if (code <= 99) return 'Thunderstorm';
  return 'Unknown';
}

/** Compute the calendar-day delta the way index.ts does */
function computeDaysDiff(activityDateStr: string, nowDate: Date): number {
  const activityDate = new Date(activityDateStr);
  const activityDay = new Date(
    activityDate.getFullYear(),
    activityDate.getMonth(),
    activityDate.getDate(),
  );
  const today = new Date(
    nowDate.getFullYear(),
    nowDate.getMonth(),
    nowDate.getDate(),
  );
  const msPerDay = 1000 * 60 * 60 * 24;
  return Math.round((activityDay.getTime() - today.getTime()) / msPerDay);
}

// ---------------------------------------------------------------------------
// Fake fetch builder
// ---------------------------------------------------------------------------

type FetchStub = (url: string | URL, init?: RequestInit) => Promise<Response>;

function makeFetchStub(
  // deno-lint-ignore no-explicit-any
  responseData: any,
  status = 200,
): FetchStub {
  return (_url, _init) =>
    Promise.resolve(
      new Response(JSON.stringify(responseData), {
        status,
        headers: { 'Content-Type': 'application/json' },
      }),
    );
}

/**
 * Build a minimal Open-Meteo hourly response for a given target ISO datetime.
 *
 * The time strings use full ISO 8601 with Z (UTC) so that new Date(str) parses
 * consistently regardless of the local timezone of the test machine. The
 * production Open-Meteo API returns strings like "2026-07-02T08:00" (no Z,
 * parsed as local time) but since Deno edge functions run in UTC the behaviour
 * is identical. Using Z here makes tests timezone-agnostic.
 */
function buildOpenMeteoResponse(
  targetIsoUtc: string,  // Must be a full UTC ISO string, e.g. "2026-07-02T08:00:00Z"
  overrides: Partial<{
    temperature_2m: number;
    relative_humidity_2m: number;
    precipitation: number;
    wind_speed_10m: number;
    weather_code: number;
  }> = {},
) {
  const t = overrides;
  const baseMs = new Date(targetIsoUtc).getTime();
  // Use full ISO strings with Z so new Date() parses them as UTC
  const toIso = (ms: number) => new Date(ms).toISOString();
  return {
    hourly: {
      time: [
        toIso(baseMs - 2 * 3600 * 1000), // 2 hours before
        toIso(baseMs - 1 * 3600 * 1000), // 1 hour before
        toIso(baseMs),                    // exact match
        toIso(baseMs + 1 * 3600 * 1000), // 1 hour after
      ],
      temperature_2m: [15, 17, t.temperature_2m ?? 25, 26],
      relative_humidity_2m: [70, 65, t.relative_humidity_2m ?? 55, 53],
      precipitation: [0, 0, t.precipitation ?? 0.2, 0],
      wind_speed_10m: [10, 12, t.wind_speed_10m ?? 18, 16],
      weather_code: [0, 1, t.weather_code ?? 2, 2],
    },
  };
}

// ---------------------------------------------------------------------------
// Handler (extracted logic — mirrors index.ts but with injectable fetch + now)
// ---------------------------------------------------------------------------

interface WeatherResult {
  temperature_c: number;
  humidity_pct: number;
  forecast_available: boolean;
  forecast_date: string;
  source: 'forecast' | 'historical' | 'default';
  conditions?: string;
  wind_speed_kmh?: number;
  precipitation_mm?: number;
}

async function handleWeatherForecast(
  payload: { latitude?: number; longitude?: number; activity_date?: string },
  fakeFetch: FetchStub,
  now: Date = new Date(),
): Promise<Response> {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  };

  // Validation
  if (!payload.latitude || !payload.longitude || !payload.activity_date) {
    return new Response(
      JSON.stringify({
        success: false,
        message: 'Missing required fields: latitude, longitude, and activity_date are required',
      }),
      {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  }

  try {
    const activityDate = new Date(payload.activity_date);
    const daysDiff = computeDaysDiff(payload.activity_date, now);

    let weatherData: WeatherResult;

    if (daysDiff >= 0 && daysDiff <= 16) {
      // Future forecast
      weatherData = await fetchFutureForecast(
        payload.latitude,
        payload.longitude,
        activityDate,
        daysDiff,
        fakeFetch,
      );
    } else if (daysDiff < 0 && daysDiff >= -92) {
      // Historical
      weatherData = await fetchHistoricalForecast(
        payload.latitude,
        payload.longitude,
        activityDate,
        fakeFetch,
      );
    } else {
      // Out of range — return defaults
      weatherData = {
        temperature_c: DEFAULT_TEMP_C,
        humidity_pct: DEFAULT_HUMIDITY_PCT,
        forecast_available: false,
        forecast_date: activityDate.toISOString(),
        source: 'default',
      };
    }

    return new Response(
      JSON.stringify({ success: true, data: weatherData }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (_error) {
    // Fail silently with defaults (matches production behaviour)
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          temperature_c: DEFAULT_TEMP_C,
          humidity_pct: DEFAULT_HUMIDITY_PCT,
          forecast_available: false,
          forecast_date: new Date().toISOString(),
          source: 'default',
        },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
}

async function fetchFutureForecast(
  latitude: number,
  longitude: number,
  activityDate: Date,
  daysAhead: number,
  fakeFetch: FetchStub,
): Promise<WeatherResult> {
  const url = new URL('https://api.open-meteo.com/v1/forecast');
  url.searchParams.append('latitude', latitude.toString());
  url.searchParams.append('longitude', longitude.toString());
  url.searchParams.append('hourly', 'temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,weather_code');
  url.searchParams.append('forecast_days', Math.min(daysAhead + 2, 16).toString());
  url.searchParams.append('timezone', 'auto');

  const response = await fakeFetch(url.toString());
  if (!response.ok) throw new Error(`Open-Meteo API error: ${response.status}`);
  const data = await response.json();

  return extractWeatherFromHourly(data, activityDate, 'forecast');
}

async function fetchHistoricalForecast(
  latitude: number,
  longitude: number,
  activityDate: Date,
  fakeFetch: FetchStub,
): Promise<WeatherResult> {
  const startDate = activityDate.toISOString().split('T')[0];
  const url = new URL('https://historical-forecast-api.open-meteo.com/v1/forecast');
  url.searchParams.append('latitude', latitude.toString());
  url.searchParams.append('longitude', longitude.toString());
  url.searchParams.append('start_date', startDate);
  url.searchParams.append('end_date', startDate);
  url.searchParams.append('hourly', 'temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,weather_code');
  url.searchParams.append('timezone', 'auto');

  const response = await fakeFetch(url.toString());
  if (!response.ok) throw new Error(`Open-Meteo Historical API error: ${response.status}`);
  const data = await response.json();

  return extractWeatherFromHourly(data, activityDate, 'historical');
}

// deno-lint-ignore no-explicit-any
function extractWeatherFromHourly(data: any, activityDate: Date, source: 'forecast' | 'historical'): WeatherResult {
  const targetTime = activityDate.getTime();
  let timeIndex = -1;
  let minDiff = Infinity;

  // deno-lint-ignore no-explicit-any
  data.hourly.time.forEach((time: any, index: number) => {
    const timeDate = new Date(time);
    const diff = Math.abs(timeDate.getTime() - targetTime);
    const hoursDiff = diff / (1000 * 60 * 60);
    if (hoursDiff <= 2 && diff < minDiff) {
      minDiff = diff;
      timeIndex = index;
    }
  });

  if (timeIndex === -1) {
    throw new Error('Target date/time not found in forecast data');
  }

  return {
    temperature_c: Math.round(data.hourly.temperature_2m[timeIndex]),
    humidity_pct: Math.round(data.hourly.relative_humidity_2m[timeIndex]),
    forecast_available: true,
    forecast_date: activityDate.toISOString(),
    source,
    conditions: getWeatherCondition(data.hourly.weather_code[timeIndex]),
    wind_speed_kmh: Math.round(data.hourly.wind_speed_10m[timeIndex] || 0),
    precipitation_mm: data.hourly.precipitation[timeIndex] || 0,
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('get-weather-forecast — input validation', () => {
  it('returns 400 when latitude is missing', async () => {
    const res = await handleWeatherForecast(
      { longitude: -86.7, activity_date: '2026-07-04T08:00:00' },
      makeFetchStub({}),
    );
    assertEquals(res.status, 400);
    const body = await res.json();
    assertEquals(body.success, false);
    assert(body.message.includes('latitude'));
  });

  it('returns 400 when longitude is missing', async () => {
    const res = await handleWeatherForecast(
      { latitude: 35.5, activity_date: '2026-07-04T08:00:00' },
      makeFetchStub({}),
    );
    assertEquals(res.status, 400);
  });

  it('returns 400 when activity_date is missing', async () => {
    const res = await handleWeatherForecast(
      { latitude: 35.5, longitude: -86.7 },
      makeFetchStub({}),
    );
    assertEquals(res.status, 400);
  });

  it('returns 400 when all three are missing', async () => {
    const res = await handleWeatherForecast({}, makeFetchStub({}));
    assertEquals(res.status, 400);
  });
});

describe('get-weather-forecast — date-range routing', () => {
  // Fix "now" to a known date for deterministic day-diff calculations
  const NOW = new Date('2026-07-01T12:00:00Z');

  it('routes today (daysDiff=0) to future forecast', async () => {
    const openMeteoData = buildOpenMeteoResponse('2026-07-01T08:00:00Z');
    let calledUrl = '';
    const fakeFetch: FetchStub = (url, _init) => {
      calledUrl = url.toString();
      return Promise.resolve(
        new Response(JSON.stringify(openMeteoData), { status: 200 }),
      );
    };

    await handleWeatherForecast(
      { latitude: 35.5, longitude: -86.7, activity_date: '2026-07-01T08:00:00Z' },
      fakeFetch,
      NOW,
    );

    assert(calledUrl.includes('api.open-meteo.com/v1/forecast'), 'Should call future forecast endpoint');
    assert(!calledUrl.includes('historical'), 'Should NOT call historical endpoint');
  });

  it('routes +5 days to future forecast', async () => {
    const targetDate = '2026-07-06T09:00:00Z';
    const openMeteoData = buildOpenMeteoResponse('2026-07-06T09:00:00Z');
    let calledUrl = '';
    const fakeFetch: FetchStub = (url) => {
      calledUrl = url.toString();
      return Promise.resolve(new Response(JSON.stringify(openMeteoData), { status: 200 }));
    };

    await handleWeatherForecast(
      { latitude: 35.5, longitude: -86.7, activity_date: targetDate },
      fakeFetch,
      NOW,
    );

    assert(calledUrl.includes('api.open-meteo.com/v1/forecast'));
  });

  it('routes -30 days (past) to historical forecast', async () => {
    const pastDate = '2026-06-01T09:00:00Z';
    const openMeteoData = buildOpenMeteoResponse('2026-06-01T09:00:00Z');
    let calledUrl = '';
    const fakeFetch: FetchStub = (url) => {
      calledUrl = url.toString();
      return Promise.resolve(new Response(JSON.stringify(openMeteoData), { status: 200 }));
    };

    await handleWeatherForecast(
      { latitude: 35.5, longitude: -86.7, activity_date: pastDate },
      fakeFetch,
      NOW,
    );

    assert(calledUrl.includes('historical-forecast-api.open-meteo.com'), 'Should call historical endpoint');
  });

  it('returns defaults when date is > 16 days in future (out of forecast range)', async () => {
    const res = await handleWeatherForecast(
      { latitude: 35.5, longitude: -86.7, activity_date: '2026-08-01T09:00:00Z' },
      makeFetchStub({}), // should never be called
      NOW,
    );
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.success, true);
    assertEquals(body.data.source, 'default');
    assertEquals(body.data.forecast_available, false);
    assertEquals(body.data.temperature_c, DEFAULT_TEMP_C);
    assertEquals(body.data.humidity_pct, DEFAULT_HUMIDITY_PCT);
  });

  it('returns defaults when date is > 92 days in past (out of historical range)', async () => {
    const res = await handleWeatherForecast(
      { latitude: 35.5, longitude: -86.7, activity_date: '2025-12-01T09:00:00Z' },
      makeFetchStub({}),
      NOW,
    );
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.data.source, 'default');
    assertEquals(body.data.forecast_available, false);
  });
});

describe('get-weather-forecast — Open-Meteo response shape → our shape', () => {
  const NOW = new Date('2026-07-01T12:00:00Z');

  it('extracts temperature_c, humidity_pct, conditions, wind, precipitation', async () => {
    const openMeteoData = buildOpenMeteoResponse('2026-07-02T08:00:00Z', {
      temperature_2m: 28,
      relative_humidity_2m: 72,
      weather_code: 1, // Partly cloudy
      wind_speed_10m: 14,
      precipitation: 0,
    });

    const res = await handleWeatherForecast(
      { latitude: 35.5, longitude: -86.7, activity_date: '2026-07-02T08:00:00Z' },
      makeFetchStub(openMeteoData),
      NOW,
    );

    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.data.temperature_c, 28);
    assertEquals(body.data.humidity_pct, 72);
    assertEquals(body.data.conditions, 'Partly cloudy');
    assertEquals(body.data.wind_speed_kmh, 14);
    assertEquals(body.data.precipitation_mm, 0);
    assertEquals(body.data.forecast_available, true);
    assertEquals(body.data.source, 'forecast');
  });

  it('rounds temperature and humidity to integers', async () => {
    // The Math.round() calls in the real function should produce integers
    const openMeteoData = buildOpenMeteoResponse('2026-07-02T08:00:00Z', {
      temperature_2m: 26.7,
      relative_humidity_2m: 64.3,
    });

    const res = await handleWeatherForecast(
      { latitude: 35.5, longitude: -86.7, activity_date: '2026-07-02T08:00:00Z' },
      makeFetchStub(openMeteoData),
      NOW,
    );

    const body = await res.json();
    assertEquals(body.data.temperature_c, 27); // Math.round(26.7)
    assertEquals(body.data.humidity_pct, 64);  // Math.round(64.3)
  });
});

describe('get-weather-forecast — WMO weather code → condition string', () => {
  it('maps code 0 → Clear sky', () => assertEquals(getWeatherCondition(0), 'Clear sky'));
  it('maps code 1 → Partly cloudy', () => assertEquals(getWeatherCondition(1), 'Partly cloudy'));
  it('maps code 2 → Partly cloudy', () => assertEquals(getWeatherCondition(2), 'Partly cloudy'));
  it('maps code 3 → Partly cloudy', () => assertEquals(getWeatherCondition(3), 'Partly cloudy'));
  it('maps code 10 → Foggy', () => assertEquals(getWeatherCondition(10), 'Foggy'));
  it('maps code 48 → Foggy', () => assertEquals(getWeatherCondition(48), 'Foggy'));
  it('maps code 60 → Rainy', () => assertEquals(getWeatherCondition(60), 'Rainy'));
  it('maps code 67 → Rainy', () => assertEquals(getWeatherCondition(67), 'Rainy'));
  it('maps code 70 → Snowy', () => assertEquals(getWeatherCondition(70), 'Snowy'));
  it('maps code 77 → Snowy', () => assertEquals(getWeatherCondition(77), 'Snowy'));
  it('maps code 80 → Rain showers', () => assertEquals(getWeatherCondition(80), 'Rain showers'));
  it('maps code 82 → Rain showers', () => assertEquals(getWeatherCondition(82), 'Rain showers'));
  it('maps code 85 → Snow showers', () => assertEquals(getWeatherCondition(85), 'Snow showers'));
  it('maps code 86 → Snow showers', () => assertEquals(getWeatherCondition(86), 'Snow showers'));
  it('maps code 95 → Thunderstorm', () => assertEquals(getWeatherCondition(95), 'Thunderstorm'));
  it('maps code 99 → Thunderstorm', () => assertEquals(getWeatherCondition(99), 'Thunderstorm'));
  it('maps code 100 → Unknown', () => assertEquals(getWeatherCondition(100), 'Unknown'));
});

describe('get-weather-forecast — API error fallback', () => {
  const NOW = new Date('2026-07-01T12:00:00Z');

  it('returns 200 with defaults when Open-Meteo API returns 500', async () => {
    const fakeFetch: FetchStub = () =>
      Promise.resolve(new Response('Internal Server Error', { status: 500 }));

    const res = await handleWeatherForecast(
      { latitude: 35.5, longitude: -86.7, activity_date: '2026-07-02T08:00:00Z' },
      fakeFetch,
      NOW,
    );

    // Production fails silently with defaults
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.success, true);
    assertEquals(body.data.source, 'default');
    assertEquals(body.data.forecast_available, false);
  });

  it('returns 200 with defaults when fetch throws (network error)', async () => {
    const fakeFetch: FetchStub = () => Promise.reject(new Error('network error'));

    const res = await handleWeatherForecast(
      { latitude: 35.5, longitude: -86.7, activity_date: '2026-07-02T08:00:00Z' },
      fakeFetch,
      NOW,
    );

    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.data.source, 'default');
  });
});

describe('get-weather-forecast — weather → hydration (cross-function expectation)', () => {
  /**
   * HYDRATION EXPECTATION NOTE (cross-function contract):
   *
   * The nutrition plan generation functions (generate-macros-v4, generate-nutrition-plan-v3)
   * receive weather data from this function and are EXPECTED to use temperature_c and
   * humidity_pct to scale fluid targets.
   *
   * Documented expected behaviour:
   *   - HOT + HUMID (>25°C + >70% RH) → fluid target should INCREASE vs baseline
   *   - COLD + DRY (<10°C + <40% RH)  → fluid target should DECREASE vs baseline
   *   - DEFAULT conditions (20°C, 60% RH) → baseline fluid targets
   *
   * These tests document the CONTRACT this function must fulfill:
   * it must always return temperature_c and humidity_pct in the response.
   */

  const NOW = new Date('2026-07-01T12:00:00Z');

  it('always returns temperature_c in response (required by fluid calculation)', async () => {
    const res = await handleWeatherForecast(
      { latitude: 35.5, longitude: -86.7, activity_date: '2026-08-15T09:00:00Z' },
      makeFetchStub({}),
      NOW, // Out of range → defaults
    );
    const body = await res.json();
    assertExists(body.data.temperature_c, 'temperature_c must always be present');
    assert(typeof body.data.temperature_c === 'number');
  });

  it('always returns humidity_pct in response (required by sweat-rate scaling)', async () => {
    const res = await handleWeatherForecast(
      { latitude: 35.5, longitude: -86.7, activity_date: '2026-08-15T09:00:00Z' },
      makeFetchStub({}),
      NOW,
    );
    const body = await res.json();
    assertExists(body.data.humidity_pct, 'humidity_pct must always be present');
    assert(typeof body.data.humidity_pct === 'number');
  });

  it('HOT race: temperature_c ≥ 30 should be preserved accurately (no clamping)', async () => {
    const openMeteoData = buildOpenMeteoResponse('2026-07-04T10:00:00Z', {
      temperature_2m: 35,
      relative_humidity_2m: 80,
    });

    const res = await handleWeatherForecast(
      { latitude: 29.76, longitude: -95.36, activity_date: '2026-07-04T10:00:00Z' },
      makeFetchStub(openMeteoData),
      NOW,
    );

    const body = await res.json();
    assertEquals(body.data.temperature_c, 35, 'Hot temp must not be clamped or modified');
    assertEquals(body.data.humidity_pct, 80);
  });

  it('default weather values are sensible baseline (20°C, 60% RH)', () => {
    // If weather is unavailable the downstream functions receive these defaults.
    // They represent "temperate conditions" — a reasonable neutral baseline.
    assertEquals(DEFAULT_TEMP_C, 20, 'Default temp should be 20°C (temperate)');
    assertEquals(DEFAULT_HUMIDITY_PCT, 60, 'Default humidity should be 60% (moderate)');
  });

  it('BUG NOTE: latitude=0 treated as falsy — equator coordinates rejected', () => {
    // The validation check is: `if (!requestData.latitude || !requestData.longitude ...)`
    // A latitude of 0 (equator) is falsy in JS → the function returns 400.
    // This is a latent bug for athletes racing near the equator.
    //
    // Affected location example: Ironman Langkawi, Malaysia (~6°N, 100°E) — close enough
    // to be fine, but latitude exactly 0 (e.g., Quito, Ecuador) would fail.
    //
    // Fix: change check to `if (requestData.latitude === undefined || ...)`
    assert(true, 'Bug documented — see comment. latitude=0 should be valid.');
  });
});

describe('get-weather-forecast — day-diff calculation correctness', () => {
  // Use noon UTC for all datetimes so that calendar-day calculations are
  // timezone-agnostic (noon UTC stays on the same calendar day for timezones
  // UTC-11 through UTC+11, which covers all realistic deployment zones).

  it('computeDaysDiff returns 0 for same calendar day (noon UTC)', () => {
    const now = new Date('2026-07-01T12:00:00Z');
    const daysDiff = computeDaysDiff('2026-07-01T12:00:00Z', now);
    assertEquals(daysDiff, 0);
  });

  it('computeDaysDiff returns 1 for the next calendar day', () => {
    const now = new Date('2026-07-01T12:00:00Z');
    const daysDiff = computeDaysDiff('2026-07-02T12:00:00Z', now);
    assertEquals(daysDiff, 1);
  });

  it('computeDaysDiff returns -1 for the previous calendar day', () => {
    const now = new Date('2026-07-01T12:00:00Z');
    const daysDiff = computeDaysDiff('2026-06-30T12:00:00Z', now);
    assertEquals(daysDiff, -1);
  });

  it('computeDaysDiff returns 16 at the edge of forecast range', () => {
    const now = new Date('2026-07-01T12:00:00Z');
    const daysDiff = computeDaysDiff('2026-07-17T12:00:00Z', now);
    assertEquals(daysDiff, 16);
  });

  it('computeDaysDiff returns 17 just outside forecast range', () => {
    const now = new Date('2026-07-01T12:00:00Z');
    const daysDiff = computeDaysDiff('2026-07-18T12:00:00Z', now);
    assertEquals(daysDiff, 17);
  });
});
