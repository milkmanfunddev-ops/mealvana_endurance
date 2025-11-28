import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
// Default weather values (matches current app defaults)
const DEFAULT_TEMP_C = 20;
const DEFAULT_HUMIDITY_PCT = 60;
/**
 * Fetches weather data from Open-Meteo API
 * Supports:
 * - Future forecasts (0-16 days ahead)
 * - Historical forecasts (0-92 days back)
 * - Graceful fallback to defaults
 */ serve(async (req)=>{
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  try {
    const requestData = await req.json();
    console.log('🌤️ Weather forecast request:', {
      latitude: requestData.latitude,
      longitude: requestData.longitude,
      activity_date: requestData.activity_date
    });
    // Validate input
    if (!requestData.latitude || !requestData.longitude || !requestData.activity_date) {
      return new Response(JSON.stringify({
        success: false,
        message: 'Missing required fields: latitude, longitude, and activity_date are required'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // Parse dates
    const activityDate = new Date(requestData.activity_date);
    const now = new Date();
    // Calculate days difference
    const daysDiff = Math.floor((activityDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
    console.log('📅 Date analysis:', {
      activity_date: activityDate.toISOString(),
      current_date: now.toISOString(),
      days_diff: daysDiff,
      is_future: daysDiff >= 0,
      within_forecast_range: daysDiff >= 0 && daysDiff <= 16,
      within_historical_range: daysDiff < 0 && daysDiff >= -92
    });
    let weatherData;
    // Determine which API to use based on date
    if (daysDiff >= 0 && daysDiff <= 16) {
      // Future forecast (0-16 days ahead)
      console.log('🔮 Fetching future forecast...');
      weatherData = await fetchFutureForecast(requestData.latitude, requestData.longitude, activityDate, daysDiff);
    } else if (daysDiff < 0 && daysDiff >= -92) {
      // Historical forecast (0-92 days back)
      console.log('📜 Fetching historical forecast...');
      weatherData = await fetchHistoricalForecast(requestData.latitude, requestData.longitude, activityDate);
    } else {
      // Outside forecast range - use defaults
      console.log('⚠️ Date outside forecast range, using defaults');
      weatherData = {
        temperature_c: DEFAULT_TEMP_C,
        humidity_pct: DEFAULT_HUMIDITY_PCT,
        forecast_available: false,
        forecast_date: activityDate.toISOString(),
        source: 'default'
      };
    }
    console.log('✅ Weather data retrieved:', weatherData);
    return new Response(JSON.stringify({
      success: true,
      data: weatherData
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  } catch (error) {
    console.error('❌ Error fetching weather:', error);
    // Return defaults on error (fail silently)
    return new Response(JSON.stringify({
      success: true,
      data: {
        temperature_c: DEFAULT_TEMP_C,
        humidity_pct: DEFAULT_HUMIDITY_PCT,
        forecast_available: false,
        forecast_date: new Date().toISOString(),
        source: 'default'
      }
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
});
/**
 * Fetch future weather forecast from Open-Meteo
 */ async function fetchFutureForecast(latitude, longitude, activityDate, daysAhead) {
  // Build Open-Meteo API URL
  // Docs: https://open-meteo.com/en/docs
  const url = new URL('https://api.open-meteo.com/v1/forecast');
  url.searchParams.append('latitude', latitude.toString());
  url.searchParams.append('longitude', longitude.toString());
  url.searchParams.append('hourly', 'temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,weather_code');
  url.searchParams.append('forecast_days', Math.min(daysAhead + 2, 16).toString());
  url.searchParams.append('timezone', 'auto');
  console.log('🌐 Open-Meteo API URL:', url.toString());
  const response = await fetch(url.toString());
  if (!response.ok) {
    throw new Error(`Open-Meteo API error: ${response.status}`);
  }
  const data = await response.json();
  // Find the closest hour to activity time
  const targetTime = activityDate.getTime();
  // Find index for closest time (within 2 hours tolerance)
  let timeIndex = -1;
  let minDiff = Infinity;
  data.hourly.time.forEach((time, index)=>{
    const timeDate = new Date(time);
    const diff = Math.abs(timeDate.getTime() - targetTime);
    const hoursDiff = diff / (1000 * 60 * 60);
    // Only consider times within 2 hours of target
    if (hoursDiff <= 2 && diff < minDiff) {
      minDiff = diff;
      timeIndex = index;
    }
  });
  if (timeIndex === -1) {
    console.error('❌ Target date/time not found. Activity date:', activityDate.toISOString());
    console.error('Available times:', data.hourly.time.slice(0, 5));
    throw new Error('Target date/time not found in forecast data');
  }
  console.log(`✅ Found closest time index ${timeIndex} for ${activityDate.toISOString()}: ${data.hourly.time[timeIndex]}`);
  // Extract weather data for the target hour
  const temperature_c = Math.round(data.hourly.temperature_2m[timeIndex]);
  const humidity_pct = Math.round(data.hourly.relative_humidity_2m[timeIndex]);
  const precipitation_mm = data.hourly.precipitation[timeIndex] || 0;
  const wind_speed_kmh = Math.round(data.hourly.wind_speed_10m[timeIndex] || 0);
  const weather_code = data.hourly.weather_code[timeIndex];
  return {
    temperature_c,
    humidity_pct,
    forecast_available: true,
    forecast_date: activityDate.toISOString(),
    source: 'forecast',
    conditions: getWeatherCondition(weather_code),
    wind_speed_kmh,
    precipitation_mm
  };
}
/**
 * Fetch historical weather forecast from Open-Meteo
 */ async function fetchHistoricalForecast(latitude, longitude, activityDate) {
  // Build Open-Meteo Historical API URL
  // Docs: https://open-meteo.com/en/docs/historical-forecast-api
  const startDate = activityDate.toISOString().split('T')[0];
  const endDate = startDate; // Same day
  const url = new URL('https://historical-forecast-api.open-meteo.com/v1/forecast');
  url.searchParams.append('latitude', latitude.toString());
  url.searchParams.append('longitude', longitude.toString());
  url.searchParams.append('start_date', startDate);
  url.searchParams.append('end_date', endDate);
  url.searchParams.append('hourly', 'temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,weather_code');
  url.searchParams.append('timezone', 'auto');
  console.log('🌐 Open-Meteo Historical API URL:', url.toString());
  const response = await fetch(url.toString());
  if (!response.ok) {
    throw new Error(`Open-Meteo Historical API error: ${response.status}`);
  }
  const data = await response.json();
  // Find the closest hour to activity time
  const targetTime = activityDate.getTime();
  // Find index for closest time (within 2 hours tolerance)
  let timeIndex = -1;
  let minDiff = Infinity;
  data.hourly.time.forEach((time, index)=>{
    const timeDate = new Date(time);
    const diff = Math.abs(timeDate.getTime() - targetTime);
    const hoursDiff = diff / (1000 * 60 * 60);
    // Only consider times within 2 hours of target
    if (hoursDiff <= 2 && diff < minDiff) {
      minDiff = diff;
      timeIndex = index;
    }
  });
  if (timeIndex === -1) {
    console.error('❌ Target date/time not found in historical data. Activity date:', activityDate.toISOString());
    console.error('Available times:', data.hourly.time.slice(0, 5));
    throw new Error('Target hour not found in historical data');
  }
  console.log(`✅ Found closest historical time index ${timeIndex} for ${activityDate.toISOString()}: ${data.hourly.time[timeIndex]}`);
  // Extract weather data for the target hour
  const temperature_c = Math.round(data.hourly.temperature_2m[timeIndex]);
  const humidity_pct = Math.round(data.hourly.relative_humidity_2m[timeIndex]);
  const precipitation_mm = data.hourly.precipitation[timeIndex] || 0;
  const wind_speed_kmh = Math.round(data.hourly.wind_speed_10m[timeIndex] || 0);
  const weather_code = data.hourly.weather_code[timeIndex];
  return {
    temperature_c,
    humidity_pct,
    forecast_available: true,
    forecast_date: activityDate.toISOString(),
    source: 'historical',
    conditions: getWeatherCondition(weather_code),
    wind_speed_kmh,
    precipitation_mm
  };
}
/**
 * Convert WMO weather code to human-readable condition
 * WMO Codes: https://open-meteo.com/en/docs
 */ function getWeatherCondition(code) {
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
