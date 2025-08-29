import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};

type Gender = "female" | "male" | "other";
type PaceUnit = "min_per_mile" | "min_per_km";
type DistanceUnit = "mi" | "km";
type WeightUnit = "kg" | "lb";
type HeightUnit = "cm" | "in";
type GutTraining = "low" | "moderate" | "high";
type CarbSource = "glucose_only" | "dual";
type SweatSodium = "low" | "medium" | "high";
type SweatRateCat = "light" | "medium" | "heavy";

interface MacrosRequest {
  age: number;
  gender: Gender;
  weight: number;
  weight_unit: WeightUnit;
  height: number;
  height_unit: HeightUnit;
  run_pace: string | number;
  run_distance: number;
  run_pace_unit?: PaceUnit;
  run_distance_unit?: DistanceUnit;
  time_before_run_min?: number;
  gut_training?: GutTraining;
  carb_source?: CarbSource;
  sweat_sodium?: SweatSodium;
  drink_sodium_mg_per_l?: number;
  optional_sweat_rate_lph?: number;
  sweat_rate_category?: SweatRateCat;
  temp_c?: number;
  humidity_pct?: number;
}

interface MacrosOutput {
  duration_min: number;
  duration_h: number;
  pace_min_per_mile: number;
  speed_mph: number;
  distance_mi: number;
  distance_km: number;
  calories_net_kcal: number;
  calories_gross_kcal: number;
  MET: number;
  pre_run_carbs_g: number;
  pre_run_carbs_rule: string;
  pre_run_protein_g_optional: number;
  pre_run_fat_g_cap: number;
  during_rate_g_per_h: number;
  during_total_g: number;
  during_mass_norm_rate_g_per_h: number;
  during_abs_clamp_range_g_per_h: [number, number];
  during_mass_norm_total_range_g: [number, number];
  pre_run_water_ml: number;
  during_water_rate_ml_per_h: number;
  during_water_total_ml: number;
  pre_run_sodium_mg: number;
  during_sodium_rate_mg_per_h: number;
  during_sodium_total_mg: number;
  post_run_carbs_g: number;
  post_run_protein_g: number;
  post_run_water_ml: number;
  post_run_sodium_mg: number;
}

const LB_TO_KG = 0.45359237;
const IN_TO_CM = 2.54;
const MI_TO_KM = 1.60934;
const MPH_TO_M_PER_MIN = 26.8224;

function toKg(weight: number, unit: WeightUnit): number {
  return unit === "kg" ? weight : weight * LB_TO_KG;
}

function toCm(height: number, unit: HeightUnit): number {
  return unit === "cm" ? height : height * IN_TO_CM;
}

function toMiles(distance: number, unit: DistanceUnit): number {
  return unit === "mi" ? distance : distance / MI_TO_KM;
}

function parsePaceToMinPerMile(pace: string | number, paceUnit: PaceUnit = "min_per_mile"): number {
  function asMinutes(v: string | number): number {
    if (typeof v === 'number') {
      return v;
    }
    const parts = v.split(":").map(p => p.trim());
    if (parts.length === 1) {
      return parseFloat(parts[0]);
    }
    const mm = parseFloat(parts[0] || "0");
    const ss = parseFloat(parts[1] || "0");
    return mm + ss / 60.0;
  }
  
  const p = asMinutes(pace);
  return paceUnit === "min_per_mile" ? p : p * MI_TO_KM;
}

// ACSM level-ground equations with walk/run switch (from v2)
function metFromPace(minPerMile: number): number {
  const mph = 60.0 / minPerMile;
  const v = mph * MPH_TO_M_PER_MIN;
  // Walk/run switch at ~4.0 mph
  const vo2 = (mph >= 4.0) ? (0.2 * v + 3.5) : (0.1 * v + 3.5);
  return vo2 / 3.5;
}

// Exact ACSM gross kcal calculation (from v2)
function grossKcal(weightKg: number, durationMin: number, met: number): number {
  return (met * 3.5 * weightKg / 200.0) * durationMin;
}

// Net transport cost (from v2)
function netKcalTransportCost(weightKg: number, distanceMiles: number): number {
  return 1.0 * weightKg * (distanceMiles * MI_TO_KM);
}

function durationHours(distanceMiles: number, paceMinPerMile: number): number {
  return (distanceMiles * paceMinPerMile) / 60.0;
}

// Duration-based carb bands (from v2)
function carbsBandByDuration(durationH: number): [number, number] {
  if (durationH <= 1.0) return [0, 30];
  if (durationH <= 2.0) return [30, 45];
  if (durationH <= 3.0) return [45, 60];
  if (durationH <= 4.0) return [60, 75];
  return [75, 90];
}

// Absorption caps (from v2)
function absorptionCapGph(gut: GutTraining, source: CarbSource): number {
  if (source === "glucose_only") {
    return gut === "high" ? 65 : 60;
  }
  return gut === "low" ? 80 : (gut === "moderate" ? 90 : 100);
}

// Intensity nudge (from v2)
function intensityNudgeFromMet(met: number): number {
  return met < 7 ? -5 : (met > 9 ? 5 : 0);
}

// Mass tilt within band (from v2)
function massTiltWithinBand(weightKg: number, low: number, high: number): number {
  return weightKg < 50 ? low : (weightKg > 80 ? high : Math.round((low + high) / 2));
}

// Complete carb recommendation (from v2)
function recommendCarbsPerHour(durationH: number, met: number, weightKg: number, gut: GutTraining, source: CarbSource) {
  const [low, high] = carbsBandByDuration(durationH);
  // Floor condition for moderate duration + high intensity
  let adjustedLow = low;
  if (durationH > 1.1 && met > 8 && low < 30) {
    adjustedLow = 30;
  }
  
  const gutNudge = gut === "low" ? -5 : (gut === "high" ? 5 : 0);
  const raw = Math.max(adjustedLow, Math.min(high, 
    massTiltWithinBand(weightKg, adjustedLow, high) + 
    intensityNudgeFromMet(met) + 
    gutNudge
  ));
  
  const cap = absorptionCapGph(gut, source);
  return {
    gphLow: adjustedLow,
    gphHigh: high,
    gphCap: cap,
    gphRaw: raw,
    gphFinal: Math.min(raw, cap)
  };
}

// Environment multiplier (from v2)
function envMultiplier(tempC: number | null, humidityPct: number | null): [number, string] {
  if (tempC === null && humidityPct === null) {
    return [1.0, "moderate"];
  }
  const t = tempC ?? 20.0;
  const h = humidityPct ?? 60.0;
  
  if (t <= 10) return [0.85, "cool"];
  if (10 < t && t <= 20 && h <= 60) return [1.0, "temperate"];
  if ((20 < t && t <= 25) || (60 < h && h <= 75)) return [1.1, "warm"];
  if ((25 < t && t <= 30) || (75 < h && h <= 85)) return [1.2, "hot"];
  return [1.3, "very_hot"];
}

// Fluid band calculation (from v2)
function fluidBandLph(weightKg: number, met: number, tempC: number | null, humidityPct: number | null): [number, number, number, string] {
  let low = 0.4, high = 0.8;
  
  if (weightKg < 50) high -= 0.1;
  else if (weightKg > 80) low += 0.1;
  
  if (met > 9) { low += 0.05; high += 0.05; }
  if (met < 7) { low -= 0.05; high -= 0.05; }
  
  const [mult, label] = envMultiplier(tempC, humidityPct);
  low *= mult; high *= mult;
  
  // Running practicality clamps
  low = Math.max(0.3, Math.min(low, 1.0));
  high = Math.max(low + 0.05, Math.min(high, 1.2));
  
  return [Math.round(low * 100) / 100, Math.round(high * 100) / 100, mult, label];
}

// Sweat rate from category (from v2)
function typicalSweatRateFromCategory(cat: SweatRateCat): number {
  return cat === "light" ? 0.45 : (cat === "medium" ? 0.75 : 1.1);
}

// Sodium concentration from category (from v2)
function sodiumConcentrationFromCategory(sweatSodium: SweatSodium): number {
  return sweatSodium === "low" ? 400 : (sweatSodium === "medium" ? 800 : 1200);
}

// Pre-run hydration (from v2)
function preRunHydration(weightKg: number, minutesBefore: number, sweatCat: SweatSodium, envLabel: string) {
  let mainMlPerKg = minutesBefore >= 150 ? 6.0 : 4.0;
  if (envLabel === "hot" || envLabel === "very_hot") mainMlPerKg += 1.0;
  
  const mainMl = mainMlPerKg * weightKg;
  const topoffMl = (envLabel === "hot" || envLabel === "very_hot") ? 300.0 : 
                   (minutesBefore >= 45 ? 250.0 : 150.0);
  
  let preNa = sweatCat === "low" ? 300 : (sweatCat === "medium" ? 450 : 600);
  if (envLabel === "hot" || envLabel === "very_hot") preNa += 100;
  
  return {
    mainMl: Math.round(mainMl),
    topoffMl: Math.round(topoffMl),
    sodiumMg: preNa
  };
}

// Dynamic sodium target (from v2)
function sodiumTargetDynamic(sweatSodiumCat: SweatSodium, sweatRateLph: number | null, envLabel: string): [number, number, number, string] {
  if (sweatRateLph !== null) {
    const conc = sodiumConcentrationFromCategory(sweatSodiumCat);
    const lossMgph = conc * sweatRateLph;
    const low = Math.max(300, Math.round(lossMgph * 0.5));
    const high = Math.min(1200, Math.round(lossMgph * 0.7));
    const target = Math.min(high, Math.max(low, Math.round(lossMgph * 0.6)));
    return [low, high, target, "measured"];
  }
  
  // Category-based
  const [baseLow, baseHigh, baseTarget] = sweatSodiumCat === "low" ? [300, 500, 400] :
                                         (sweatSodiumCat === "medium" ? [500, 800, 650] : [800, 1200, 1000]);
  
  let bump = 0;
  if (envLabel === "warm") bump = 50;
  else if (envLabel === "hot") bump = 100;
  else if (envLabel === "very_hot") bump = 150;
  
  const low = baseLow + bump;
  const high = Math.min(baseHigh + bump, 1200);
  const target = Math.min(baseTarget + bump, 1200);
  
  return [low, high, target, "category"];
}

// During run hydration (from v2)
function duringRunHydration(weightKg: number, met: number, durationH: number, sweatCat: SweatSodium, 
                           drinkNaMgPerL: number, tempC: number | null, humidityPct: number | null,
                           sweatRateLph: number | null, sweatRateCategory: SweatRateCat) {
  const [lowLph, highLph, mult, envLabel] = fluidBandLph(weightKg, met, tempC, humidityPct);
  let planLph = Math.round(((lowLph + highLph) / 2) * 100) / 100;

  let usedSweatRate: number | null = null;
  let sweatMethod: string;

  if (sweatRateLph === null) {
    const estRate = typicalSweatRateFromCategory(sweatRateCategory) * mult;
    planLph = Math.max(lowLph, Math.min(highLph, Math.round(estRate * 0.8 * 100) / 100));
    sweatMethod = "category_estimate";
  } else {
    planLph = Math.max(lowLph, Math.min(highLph, Math.round(sweatRateLph * 0.7 * 100) / 100));
    usedSweatRate = Math.round(sweatRateLph * 100) / 100;
    sweatMethod = "measured";
  }

  const [naLow, naHigh, naTarget] = sodiumTargetDynamic(sweatCat, usedSweatRate, envLabel);
  const naFromDrink = Math.round(planLph * drinkNaMgPerL);
  const naGap = Math.max(0, naTarget - naFromDrink);

  return {
    environment: envLabel,
    envMultiplier: mult,
    fluidLphLow: lowLph,
    fluidLphHigh: highLph,
    fluidLphPlan: planLph,
    sweatRateLphUsed: usedSweatRate,
    sweatRateMethod: sweatMethod,
    drinkNaMgPerL: drinkNaMgPerL,
    sodiumMgphLow: naLow,
    sodiumMgphHigh: naHigh,
    sodiumMgphTarget: naTarget,
    sodiumFromDrinkMgph: naFromDrink,
    sodiumGapMgph: naGap
  };
}

// After run rehydration (from v2)
function afterRunRehydration(durationH: number, duringLph: number, sweatRateLph: number | null, drinkNaMgPerL: number) {
  if (sweatRateLph !== null) {
    const deficitL = Math.max(0.0, (sweatRateLph - duringLph) * durationH);
    const replaceL = Math.round(deficitL * 1.25 * 100) / 100;
    const sodiumMg = Math.round(replaceL * Math.max(500, Math.min(700, drinkNaMgPerL)));
    return {
      deficitL: Math.round(deficitL * 100) / 100,
      rehydrationL: replaceL,
      rehydrationSodiumMg: sodiumMg
    };
  }
  
  const defaultL = 1.25;
  const sodiumMg = Math.round(defaultL * Math.max(500, Math.min(700, drinkNaMgPerL)));
  return {
    rehydrationL: defaultL,
    rehydrationSodiumMg: sodiumMg
  };
}

// Pre-run macros (from v2)
function preRunMacros(weightKg: number, timeBeforeMin: number) {
  const hours = Math.min(timeBeforeMin / 60.0, 4.0);
  const choPerKg = Math.min(3.0, Math.max(0.5, hours));
  const carbsG = choPerKg * weightKg;
  
  let proteinG: number, fatG: number;
  if (timeBeforeMin <= 60) {
    proteinG = 0.15 * weightKg;
    fatG = 0.1 * weightKg;
  } else if (timeBeforeMin <= 90) {
    proteinG = 0.2 * weightKg;
    fatG = 0.15 * weightKg;
  } else {
    proteinG = 0.25 * weightKg;
    fatG = 0.2 * weightKg;
  }
  
  return {
    carbG: Math.round(carbsG * 10) / 10,
    proteinG: Math.round(proteinG * 10) / 10,
    fatG: Math.round(fatG * 10) / 10
  };
}

// During-run macros (from v2)
function duringRunMacros(durationH: number, met: number, weightKg: number, gut: GutTraining, source: CarbSource) {
  const c = recommendCarbsPerHour(durationH, met, weightKg, gut, source);
  const proteinPerH = durationH <= 3.5 ? 0.0 : 3.0;
  const fatPerH = durationH <= 3.5 ? 0.0 : 2.0;
  
  return {
    carbPerHG: c.gphFinal,
    proteinPerHG: proteinPerH,
    fatPerHG: fatPerH,
    bandLow: c.gphLow,
    bandHigh: c.gphHigh,
    cap: c.gphCap,
    raw: c.gphRaw
  };
}

// After-run macros (from v2)
function afterRunMacros(weightKg: number, durationH: number) {
  const choPerKg = durationH > 2 ? 1.2 : 1.0;
  return {
    carbG: Math.round(choPerKg * weightKg * 10) / 10,
    proteinG: Math.round(0.3 * weightKg * 10) / 10,
    fatG: Math.round(0.2 * weightKg * 10) / 10
  };
}

function computeRunFueling(params: MacrosRequest): MacrosOutput {
  const weightKg = toKg(params.weight, params.weight_unit);
  const distanceMi = toMiles(params.run_distance, params.run_distance_unit || "mi");
  const paceMinPerMile = parsePaceToMinPerMile(params.run_pace, params.run_pace_unit || "min_per_mile");
  const durationMin = distanceMi * paceMinPerMile;
  const durationH = durationMin / 60.0;
  const speedMph = 60.0 / paceMinPerMile;
  const distanceKm = distanceMi * MI_TO_KM;
  
  // Energy calculations (v2)
  const met = metFromPace(paceMinPerMile);
  const caloriesGross = grossKcal(weightKg, durationMin, met);
  const caloriesNet = netKcalTransportCost(weightKg, distanceMi);
  
  // Parameters with defaults
  const gutTraining: GutTraining = params.gut_training || "high";
  const carbSource: CarbSource = params.carb_source || "dual";
  const timeBeforeMin = params.time_before_run_min || 120;
  const sweatSodium: SweatSodium = params.sweat_sodium || "medium";
  const drinkSodiumMgPerL = params.drink_sodium_mg_per_l || 500;
  const sweatRateCategory: SweatRateCat = params.sweat_rate_category || "medium";
  
  // Pre-run nutrition (v2)
  const pre = preRunMacros(weightKg, timeBeforeMin);
  
  // During-run nutrition (v2)
  const durMac = duringRunMacros(durationH, met, weightKg, gutTraining, carbSource);
  
  // After-run nutrition (v2)
  const aft = afterRunMacros(weightKg, durationH);
  
  // Hydration & sodium (v2)
  const [lowLph, highLph, mult, envLabel] = fluidBandLph(weightKg, met, params.temp_c || null, params.humidity_pct || null);
  const preHyd = preRunHydration(weightKg, timeBeforeMin, sweatSodium, envLabel);
  const durHyd = duringRunHydration(weightKg, met, durationH, sweatSodium, drinkSodiumMgPerL, 
                                   params.temp_c || null, params.humidity_pct || null, 
                                   params.optional_sweat_rate_lph || null, sweatRateCategory);
  const aftHyd = afterRunRehydration(durationH, durHyd.fluidLphPlan, params.optional_sweat_rate_lph || null, drinkSodiumMgPerL);
  
  return {
    duration_min: Math.round(durationMin * 100) / 100,
    duration_h: Math.round(durationH * 10000) / 10000,
    pace_min_per_mile: Math.round(paceMinPerMile * 100) / 100,
    speed_mph: Math.round(speedMph * 1000) / 1000,
    distance_mi: Math.round(distanceMi * 1000) / 1000,
    distance_km: Math.round(distanceKm * 1000) / 1000,
    
    calories_net_kcal: Math.round(caloriesNet),
    calories_gross_kcal: Math.round(caloriesGross),
    MET: Math.round(met * 100) / 100,
    
    pre_run_carbs_g: Math.round(pre.carbG),
    pre_run_carbs_rule: `${Math.round((timeBeforeMin/60)*10)/10}h × ${Math.round((pre.carbG/weightKg)*10)/10} g/kg`,
    pre_run_protein_g_optional: Math.round(pre.proteinG),
    pre_run_fat_g_cap: Math.round(pre.fatG * 10) / 10,
    
    during_rate_g_per_h: Math.round(durMac.carbPerHG * 10) / 10,
    during_total_g: Math.round(durMac.carbPerHG * durationH),
    during_mass_norm_rate_g_per_h: Math.round(durMac.carbPerHG * 10) / 10, // Simplified for now
    during_abs_clamp_range_g_per_h: [durMac.bandLow, durMac.bandHigh],
    during_mass_norm_total_range_g: [
      Math.round(durMac.bandLow * durationH),
      Math.round(durMac.bandHigh * durationH),
    ],
    
    pre_run_water_ml: preHyd.mainMl + preHyd.topoffMl,
    during_water_rate_ml_per_h: Math.round(durHyd.fluidLphPlan * 1000),
    during_water_total_ml: Math.round(durHyd.fluidLphPlan * 1000 * durationH),
    
    pre_run_sodium_mg: preHyd.sodiumMg,
    during_sodium_rate_mg_per_h: durHyd.sodiumMgphTarget,
    during_sodium_total_mg: Math.round(durHyd.sodiumMgphTarget * durationH),
    
    post_run_carbs_g: Math.round(aft.carbG),
    post_run_protein_g: Math.round(aft.proteinG),
    post_run_water_ml: Math.round((aftHyd.rehydrationL || 1.25) * 1000),
    post_run_sodium_mg: aftHyd.rehydrationSodiumMg || 625,
  };
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const requestData: MacrosRequest = await req.json();
    
    console.log('🔍 DEBUG: Received macro calculation request:', {
      distance: requestData.run_distance,
      pace: requestData.run_pace,
      weight: requestData.weight,
      weight_unit: requestData.weight_unit,
      temp_c: requestData.temp_c,
      humidity_pct: requestData.humidity_pct,
      gut_training: requestData.gut_training,
      sweat_rate_category: requestData.sweat_rate_category,
    });

    // Validate required fields
    if (!requestData.weight || !requestData.run_distance || !requestData.run_pace) {
      return new Response(JSON.stringify({
        success: false,
        message: 'Missing required fields: weight, run_distance, and run_pace are required'
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Calculate macros using the complete v2 algorithm
    const macros = computeRunFueling(requestData);

    console.log('✅ DEBUG: Calculated macros successfully:', {
      duration_h: macros.duration_h,
      calories_net: macros.calories_net_kcal,
      calories_gross: macros.calories_gross_kcal,
      pre_run_carbs_g: macros.pre_run_carbs_g,
      during_total_g: macros.during_total_g,
      MET: macros.MET
    });

    return new Response(JSON.stringify({
      success: true,
      macros
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('Error calculating macros:', error);
    return new Response(JSON.stringify({
      success: false,
      message: 'Failed to calculate macros',
      error: error.message
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});