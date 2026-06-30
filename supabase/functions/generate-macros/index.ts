import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { initSentry, withSentry } from "../_shared/sentry.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};

// Initialise Sentry once per cold-start. No-op when SENTRY_DSN is not set.
initSentry();
const LB_TO_KG = 0.45359237;
const IN_TO_CM = 2.54;
const MI_TO_KM = 1.60934;
const MPH_TO_M_PER_MIN = 26.8224;
function toKg(weight, unit) {
  return unit === "kg" ? weight : weight * LB_TO_KG;
}
function toCm(height, unit) {
  return unit === "cm" ? height : height * IN_TO_CM;
}
function toMiles(distance, unit) {
  return unit === "mi" ? distance : distance / MI_TO_KM;
}
function parsePaceToMinPerMile(pace, paceUnit = "min_per_mile") {
  function asMinutes(v) {
    if (typeof v === 'number') {
      return v;
    }
    const parts = v.split(":").map((p)=>p.trim());
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
function metFromPace(minPerMile) {
  const mph = 60.0 / minPerMile;
  const v = mph * MPH_TO_M_PER_MIN;
  // Walk/run switch at ~4.0 mph
  const vo2 = mph >= 4.0 ? 0.2 * v + 3.5 : 0.1 * v + 3.5;
  return vo2 / 3.5;
}
// Exact ACSM gross kcal calculation (from v2)
function grossKcal(weightKg, durationMin, met) {
  return met * 3.5 * weightKg / 200.0 * durationMin;
}
// Net transport cost (from v2)
function netKcalTransportCost(weightKg, distanceMiles) {
  return 1.0 * weightKg * (distanceMiles * MI_TO_KM);
}
function durationHours(distanceMiles, paceMinPerMile) {
  return distanceMiles * paceMinPerMile / 60.0;
}
// Duration-based carb bands (from v2)
function carbsBandByDuration(durationH) {
  if (durationH <= 1.0) return [
    0,
    30
  ];
  if (durationH <= 2.0) return [
    30,
    45
  ];
  if (durationH <= 3.0) return [
    45,
    60
  ];
  if (durationH <= 4.0) return [
    60,
    75
  ];
  return [
    75,
    90
  ];
}
// Absorption caps (from v2)
function absorptionCapGph(gut, source) {
  if (source === "glucose_only") {
    return gut === "high" ? 65 : 60;
  }
  return gut === "low" ? 80 : gut === "moderate" ? 90 : 100;
}
// Intensity nudge (from v2)
function intensityNudgeFromMet(met) {
  return met < 7 ? -5 : met > 9 ? 5 : 0;
}
// Mass tilt within band (from v2)
function massTiltWithinBand(weightKg, low, high) {
  return weightKg < 50 ? low : weightKg > 80 ? high : Math.round((low + high) / 2);
}
// Complete carb recommendation (from v2)
function recommendCarbsPerHour(durationH, met, weightKg, gut, source) {
  const [low, high] = carbsBandByDuration(durationH);
  // Floor condition for moderate duration + high intensity
  let adjustedLow = low;
  if (durationH > 1.1 && met > 8 && low < 30) {
    adjustedLow = 30;
  }
  const gutNudge = gut === "low" ? -5 : gut === "high" ? 5 : 0;
  const raw = Math.max(adjustedLow, Math.min(high, massTiltWithinBand(weightKg, adjustedLow, high) + intensityNudgeFromMet(met) + gutNudge));
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
function envMultiplier(tempC, humidityPct) {
  if (tempC === null && humidityPct === null) {
    return [
      1.0,
      "moderate"
    ];
  }
  const t = tempC ?? 20.0;
  const h = humidityPct ?? 60.0;
  if (t <= 10) return [
    0.85,
    "cool"
  ];
  if (10 < t && t <= 20 && h <= 60) return [
    1.0,
    "temperate"
  ];
  if (20 < t && t <= 25 || 60 < h && h <= 75) return [
    1.1,
    "warm"
  ];
  if (25 < t && t <= 30 || 75 < h && h <= 85) return [
    1.2,
    "hot"
  ];
  return [
    1.3,
    "very_hot"
  ];
}
// Fluid band calculation (from v2)
function fluidBandLph(weightKg, met, tempC, humidityPct) {
  let low = 0.4, high = 0.8;
  if (weightKg < 50) high -= 0.1;
  else if (weightKg > 80) low += 0.1;
  if (met > 9) {
    low += 0.05;
    high += 0.05;
  }
  if (met < 7) {
    low -= 0.05;
    high -= 0.05;
  }
  const [mult, label] = envMultiplier(tempC, humidityPct);
  low *= mult;
  high *= mult;
  // Running practicality clamps
  low = Math.max(0.3, Math.min(low, 1.0));
  high = Math.max(low + 0.05, Math.min(high, 1.2));
  return [
    Math.round(low * 100) / 100,
    Math.round(high * 100) / 100,
    mult,
    label
  ];
}
// Sweat rate from category (from v2)
function typicalSweatRateFromCategory(cat) {
  return cat === "light" ? 0.45 : cat === "medium" ? 0.75 : 1.1;
}
// Sodium concentration from category (from v2)
function sodiumConcentrationFromCategory(sweatSodium) {
  return sweatSodium === "low" ? 400 : sweatSodium === "medium" ? 800 : 1200;
}
// Pre-run hydration (from v2)
function preRunHydration(weightKg, minutesBefore, sweatCat, envLabel) {
  let mainMlPerKg = minutesBefore >= 150 ? 6.0 : 4.0;
  if (envLabel === "hot" || envLabel === "very_hot") mainMlPerKg += 1.0;
  const mainMl = mainMlPerKg * weightKg;
  const topoffMl = envLabel === "hot" || envLabel === "very_hot" ? 300.0 : minutesBefore >= 45 ? 250.0 : 150.0;
  let preNa = sweatCat === "low" ? 300 : sweatCat === "medium" ? 450 : 600;
  if (envLabel === "hot" || envLabel === "very_hot") preNa += 100;
  return {
    mainMl: Math.round(mainMl),
    topoffMl: Math.round(topoffMl),
    sodiumMg: preNa
  };
}
// Dynamic sodium target (from v2)
function sodiumTargetDynamic(sweatSodiumCat, sweatRateLph, envLabel) {
  if (sweatRateLph !== null) {
    const conc = sodiumConcentrationFromCategory(sweatSodiumCat);
    const lossMgph = conc * sweatRateLph;
    const low = Math.max(300, Math.round(lossMgph * 0.5));
    const high = Math.min(1200, Math.round(lossMgph * 0.7));
    const target = Math.min(high, Math.max(low, Math.round(lossMgph * 0.6)));
    return [
      low,
      high,
      target,
      "measured"
    ];
  }
  // Category-based
  const [baseLow, baseHigh, baseTarget] = sweatSodiumCat === "low" ? [
    300,
    500,
    400
  ] : sweatSodiumCat === "medium" ? [
    500,
    800,
    650
  ] : [
    800,
    1200,
    1000
  ];
  let bump = 0;
  if (envLabel === "warm") bump = 50;
  else if (envLabel === "hot") bump = 100;
  else if (envLabel === "very_hot") bump = 150;
  const low = baseLow + bump;
  const high = Math.min(baseHigh + bump, 1200);
  const target = Math.min(baseTarget + bump, 1200);
  return [
    low,
    high,
    target,
    "category"
  ];
}
// During run hydration (from v2)
function duringRunHydration(weightKg, met, durationH, sweatCat, drinkNaMgPerL, tempC, humidityPct, sweatRateLph, sweatRateCategory) {
  const [lowLph, highLph, mult, envLabel] = fluidBandLph(weightKg, met, tempC, humidityPct);
  let planLph = Math.round((lowLph + highLph) / 2 * 100) / 100;
  let usedSweatRate = null;
  let sweatMethod;
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
function afterRunRehydration(durationH, duringLph, sweatRateLph, drinkNaMgPerL) {
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
function preRunMacros(weightKg, timeBeforeMin) {
  const hours = Math.min(timeBeforeMin / 60.0, 4.0);
  const choPerKg = Math.min(3.0, Math.max(0.5, hours));
  const carbsG = choPerKg * weightKg;
  let proteinG, fatG;
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
function duringRunMacros(durationH, met, weightKg, gut, source) {
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
function afterRunMacros(weightKg, durationH) {
  const choPerKg = durationH > 2 ? 1.2 : 1.0;
  return {
    carbG: Math.round(choPerKg * weightKg * 10) / 10,
    proteinG: Math.round(0.3 * weightKg * 10) / 10,
    fatG: Math.round(0.2 * weightKg * 10) / 10
  };
}
function computeRunFueling(params) {
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
  const gutTraining = params.gut_training || "high";
  const carbSource = params.carb_source || "dual";
  const timeBeforeMin = params.time_before_run_min || 120;
  const sweatSodium = params.sweat_sodium || "medium";
  const drinkSodiumMgPerL = params.drink_sodium_mg_per_l || 500;
  const sweatRateCategory = params.sweat_rate_category || "medium";
  // Pre-run nutrition (v2)
  const pre = preRunMacros(weightKg, timeBeforeMin);
  // During-run nutrition (v2)
  const durMac = duringRunMacros(durationH, met, weightKg, gutTraining, carbSource);
  // After-run nutrition (v2)
  const aft = afterRunMacros(weightKg, durationH);
  // Hydration & sodium (v2)
  const [lowLph, highLph, mult, envLabel] = fluidBandLph(weightKg, met, params.temp_c || null, params.humidity_pct || null);
  const preHyd = preRunHydration(weightKg, timeBeforeMin, sweatSodium, envLabel);
  const durHyd = duringRunHydration(weightKg, met, durationH, sweatSodium, drinkSodiumMgPerL, params.temp_c || null, params.humidity_pct || null, params.optional_sweat_rate_lph || null, sweatRateCategory);
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
    pre_run_carbs_rule: `${Math.round(timeBeforeMin / 60 * 10) / 10}h × ${Math.round(pre.carbG / weightKg * 10) / 10} g/kg`,
    pre_run_protein_g_optional: Math.round(pre.proteinG),
    pre_run_fat_g_cap: Math.round(pre.fatG * 10) / 10,
    during_rate_g_per_h: Math.round(durMac.carbPerHG * 10) / 10,
    during_total_g: Math.round(durMac.carbPerHG * durationH),
    during_mass_norm_rate_g_per_h: Math.round(durMac.carbPerHG * 10) / 10,
    during_abs_clamp_range_g_per_h: [
      durMac.bandLow,
      durMac.bandHigh
    ],
    during_mass_norm_total_range_g: [
      Math.round(durMac.bandLow * durationH),
      Math.round(durMac.bandHigh * durationH)
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
    post_run_sodium_mg: aftHyd.rehydrationSodiumMg || 625
  };
}
// ============================================================================
// CYCLING FORMULAS (NEW - Multi-Sport Support)
// Based on docs/features/cycling_swimming/formulas.md
// ============================================================================
// Cycling MET calculation from speed
function cyclingMETFromSpeed(speedKph, terrain) {
  // Base MET from speed (flat terrain, outdoor)
  let met;
  if (speedKph <= 16) {
    // Leisure pace (~10 mph)
    met = 6.0;
  } else if (speedKph <= 19) {
    // Light effort (~12 mph)
    met = 8.0;
  } else if (speedKph <= 22) {
    // Moderate effort (~14 mph)
    met = 10.0;
  } else if (speedKph <= 25) {
    // Vigorous effort (~16 mph)
    met = 12.0;
  } else if (speedKph <= 30) {
    // Very vigorous (~19 mph)
    met = 14.0;
  } else {
    // Racing pace (>19 mph)
    met = 16.0;
  }
  // Terrain adjustment
  if (terrain === 'rolling') {
    met *= 1.1; // 10% increase for rolling hills
  } else if (terrain === 'hilly') {
    met *= 1.25; // 25% increase for hilly terrain
  }
  return Math.round(met * 10) / 10;
}
// Adjust MET for elevation gain
function adjustMETForElevation(baseMET, elevationGainFt, distanceMiles) {
  // Calculate vertical meters per kilometer
  const elevationGainM = elevationGainFt * 0.3048;
  const distanceKm = distanceMiles * MI_TO_KM;
  const verticalMPerKm = elevationGainM / distanceKm;
  // Add MET based on climbing rate
  let elevationMETBonus = 0;
  if (verticalMPerKm > 100) {
    // Extreme climbing (>100m/km = ~10% grade)
    elevationMETBonus = 4.0;
  } else if (verticalMPerKm > 60) {
    // Severe climbing (60-100m/km = ~6-10% grade)
    elevationMETBonus = 3.0;
  } else if (verticalMPerKm > 30) {
    // Moderate climbing (30-60m/km = ~3-6% grade)
    elevationMETBonus = 2.0;
  } else if (verticalMPerKm > 10) {
    // Light climbing (10-30m/km = ~1-3% grade)
    elevationMETBonus = 1.0;
  }
  return baseMET + elevationMETBonus;
}
// Adjust MET for indoor vs outdoor
function adjustMETForIndoorOutdoor(baseMET, isIndoor) {
  if (isIndoor) {
    // Indoor cycling is slightly easier due to no wind resistance
    return baseMET * 0.95;
  }
  return baseMET;
}
// Cycling gross energy expenditure
function cyclingGrossCalories(weightKg, durationMin, met) {
  // Same formula as running: MET × 3.5 × body weight (kg) / 200 × duration (min)
  return grossKcal(weightKg, durationMin, met);
}
// Cycling net energy expenditure
function cyclingNetCalories(weightKg, distanceKm, speedKph) {
  // Cycling net cost varies with speed due to air resistance
  let costPerKgKm;
  if (speedKph <= 20) {
    costPerKgKm = 0.3;
  } else if (speedKph <= 25) {
    costPerKgKm = 0.35;
  } else if (speedKph <= 30) {
    costPerKgKm = 0.4;
  } else {
    costPerKgKm = 0.5;
  }
  return weightKg * distanceKm * costPerKgKm;
}
// Cycling duration calculations
function cyclingDuration(distanceMiles, speedMph) {
  return distanceMiles / speedMph;
}
function cyclingDurationMinutes(distanceMiles, speedMph) {
  return cyclingDuration(distanceMiles, speedMph) * 60;
}
// Pre-ride carbohydrates
function cyclingPreRideCarbs(weightKg, hoursBeforeRide) {
  const hoursEffective = Math.min(hoursBeforeRide, 4.0);
  if (hoursEffective >= 1.0) {
    // 1 g/kg per hour available (cap at 4 g/kg)
    return hoursEffective * weightKg;
  } else if (hoursEffective >= 0.25) {
    // 0.5 g/kg for 15-60 min window
    return 0.5 * weightKg;
  } else {
    // <15 min: small top-up
    return 0.25 * weightKg;
  }
}
// During-ride carbohydrates (cyclists can tolerate more than runners)
function cyclingDuringRideCarbs(durationH, met, weightKg, gutTraining) {
  // Carb bands by duration (cyclists can go higher than runners)
  let carbMin, carbMax;
  if (durationH <= 1.0) {
    carbMin = 0;
    carbMax = 30;
  } else if (durationH <= 2.0) {
    carbMin = 30;
    carbMax = 60;
  } else if (durationH <= 3.0) {
    carbMin = 60;
    carbMax = 90;
  } else if (durationH <= 4.0) {
    carbMin = 75;
    carbMax = 100;
  } else {
    carbMin = 90;
    carbMax = 120; // Elite cyclists can absorb 120 g/h
  }
  // Gut training adjustment
  let gutMultiplier = 1.0;
  if (gutTraining === 'low') {
    gutMultiplier = 0.85;
  } else if (gutTraining === 'high') {
    gutMultiplier = 1.1;
  }
  // Intensity adjustment from MET
  let intensityBonus = 0;
  if (met >= 12) {
    intensityBonus = 10; // High intensity = more carbs needed
  } else if (met >= 10) {
    intensityBonus = 5;
  }
  // Calculate target
  const baseTarget = (carbMin + carbMax) / 2;
  const adjusted = baseTarget * gutMultiplier + intensityBonus;
  // Cap at max absorption rate
  const maxAbsorption = gutTraining === 'high' ? 100 : 90;
  return Math.min(Math.round(adjusted), maxAbsorption);
}
// Post-ride carbohydrates
function cyclingPostRideCarbs(weightKg, durationH) {
  const carbPerKg = durationH > 2.0 ? 1.2 : 1.0;
  return carbPerKg * weightKg;
}
// Post-ride protein
function cyclingPostRideProtein(weightKg) {
  return 0.3 * weightKg;
}
// During-ride protein (only for ultra-endurance)
function cyclingDuringRideProtein(durationH) {
  return durationH > 3.5 ? 5.0 : 0.0;
}
// Cycling hydration rate
function cyclingHydrationRate(weightKg, met, tempC, humidityPct) {
  // Base rate: 0.5-0.75 L/h (slightly higher than running)
  let baseLph = 0.60;
  // Weight adjustment
  if (weightKg < 50) {
    baseLph = 0.50;
  } else if (weightKg > 80) {
    baseLph = 0.70;
  }
  // Intensity adjustment
  if (met >= 12) {
    baseLph += 0.1;
  }
  // Environmental adjustment (reuse shared function)
  const [envMult] = envMultiplier(tempC, humidityPct);
  baseLph *= envMult;
  // Cap at 1.0 L/h for cyclists
  return Math.min(baseLph, 1.0);
}
// Cycling sodium rate
function cyclingSodiumRate(durationH, sweatSodiumCat, envLabel) {
  // Base sodium by sweat category
  let sodiumMgph = 500;
  if (sweatSodiumCat === 'low') {
    sodiumMgph = 400;
  } else if (sweatSodiumCat === 'medium') {
    sodiumMgph = 650;
  } else if (sweatSodiumCat === 'high') {
    sodiumMgph = 1000;
  }
  // Environmental bump
  if (envLabel === 'hot') {
    sodiumMgph += 100;
  } else if (envLabel === 'very_hot') {
    sodiumMgph += 150;
  }
  // Cap at 1200 mg/h
  return Math.min(sodiumMgph, 1200);
}
// Complete cycling macro calculator
function calculateCyclingMacros(input) {
  // 1. Duration
  const durationH = cyclingDuration(input.distanceMiles, input.speedMph);
  const durationMin = durationH * 60;
  const distanceKm = input.distanceMiles * MI_TO_KM;
  const speedKph = input.speedMph * MI_TO_KM;
  // 2. MET and Energy
  let baseMET = cyclingMETFromSpeed(speedKph, input.terrain);
  baseMET = adjustMETForElevation(baseMET, input.elevationGainFt, input.distanceMiles);
  const finalMET = adjustMETForIndoorOutdoor(baseMET, input.indoorOutdoor === 'indoor');
  const caloriesGross = cyclingGrossCalories(input.weightKg, durationMin, finalMET);
  const caloriesNet = cyclingNetCalories(input.weightKg, distanceKm, speedKph);
  // 3. Carbohydrates
  const hoursBeforeRide = input.timeBeforeMinutes / 60.0;
  const preCarbs = cyclingPreRideCarbs(input.weightKg, hoursBeforeRide);
  const duringCarbsPerH = cyclingDuringRideCarbs(durationH, finalMET, input.weightKg, input.gutTraining);
  const duringCarbsTotal = duringCarbsPerH * durationH;
  const postCarbs = cyclingPostRideCarbs(input.weightKg, durationH);
  // 4. Protein
  const preProtein = 0.25 * input.weightKg;
  const duringProtein = cyclingDuringRideProtein(durationH);
  const postProtein = cyclingPostRideProtein(input.weightKg);
  // 5. Fat
  const preFat = hoursBeforeRide > 2.0 ? 0.2 * input.weightKg : 0.1 * input.weightKg;
  // 6. Hydration
  const [envMult, envLabel] = envMultiplier(input.tempC, input.humidityPct);
  const preWater = preRunHydration(input.weightKg, input.timeBeforeMinutes, input.sweatSodiumCat, envLabel);
  const duringWaterPerH = cyclingHydrationRate(input.weightKg, finalMET, input.tempC || 20, input.humidityPct || 60);
  const duringWaterTotal = duringWaterPerH * 1000 * durationH;
  // 7. Sodium
  const preSodium = preWater.sodiumMg;
  const duringSodiumPerH = cyclingSodiumRate(durationH, input.sweatSodiumCat, envLabel);
  const duringSodiumTotal = duringSodiumPerH * durationH;
  return {
    duration_min: Math.round(durationMin * 100) / 100,
    duration_h: Math.round(durationH * 10000) / 10000,
    speed_mph: input.speedMph,
    distance_mi: input.distanceMiles,
    distance_km: Math.round(distanceKm * 1000) / 1000,
    calories_net_kcal: Math.round(caloriesNet),
    calories_gross_kcal: Math.round(caloriesGross),
    MET: Math.round(finalMET * 100) / 100,
    pre_ride_carbs_g: Math.round(preCarbs),
    pre_ride_protein_g: Math.round(preProtein),
    pre_ride_fat_g: Math.round(preFat * 10) / 10,
    during_ride_carbs_per_h: Math.round(duringCarbsPerH),
    during_ride_carbs_total: Math.round(duringCarbsTotal),
    during_ride_protein_per_h: duringProtein,
    post_ride_carbs_g: Math.round(postCarbs),
    post_ride_protein_g: Math.round(postProtein),
    pre_ride_water_ml: preWater.mainMl + preWater.topoffMl,
    during_ride_water_per_h_ml: Math.round(duringWaterPerH * 1000),
    during_ride_water_total_ml: Math.round(duringWaterTotal),
    pre_ride_sodium_mg: preSodium,
    during_ride_sodium_per_h_mg: duringSodiumPerH,
    during_ride_sodium_total_mg: Math.round(duringSodiumTotal)
  };
}
// ============================================================================
// SWIMMING FORMULAS (NEW - Multi-Sport Support)
// Based on docs/features/cycling_swimming/formulas.md
// ============================================================================
// Swimming MET calculation from pace
function swimmingMETFromPace(paceSecondsper100m, poolOrOpenWater, waterTempC) {
  let met;
  if (paceSecondsper100m >= 180) {
    met = 6.0;
  } else if (paceSecondsper100m >= 150) {
    met = 8.0;
  } else if (paceSecondsper100m >= 120) {
    met = 10.0;
  } else if (paceSecondsper100m >= 90) {
    met = 11.0;
  } else {
    met = 13.0;
  }
  if (poolOrOpenWater === 'open_water') {
    met *= 1.15;
  }
  if (waterTempC < 20) {
    met *= 1.1;
  } else if (waterTempC > 28) {
    met *= 0.95;
  }
  return Math.round(met * 10) / 10;
}
// Swimming MET from intensity zone
function swimmingMETFromIntensity(intensity) {
  const intensityMETs = {
    zone_1: 6.0,
    zone_2: 8.0,
    zone_3: 10.0,
    zone_4: 12.0
  };
  return intensityMETs[intensity];
}
// Swimming gross energy expenditure
function swimmingGrossCalories(weightKg, durationMin, met) {
  return grossKcal(weightKg, durationMin, met);
}
// Swimming net energy expenditure
function swimmingNetCalories(weightKg, distanceKm) {
  const costPerKgKm = 3.5;
  return weightKg * distanceKm * costPerKgKm;
}
// Swimming duration calculations
function swimmingDuration(distanceMeters, paceSecondsper100m) {
  const num100mSegments = distanceMeters / 100;
  const totalSeconds = num100mSegments * paceSecondsper100m;
  return totalSeconds / 60;
}
function swimmingDurationHours(distanceMeters, paceSecondsper100m) {
  return swimmingDuration(distanceMeters, paceSecondsper100m) / 60;
}
// Pre-swim carbohydrates
function swimmingPreSwimCarbs(weightKg, hoursBeforeSwim) {
  const hoursEffective = Math.min(hoursBeforeSwim, 4.0);
  if (hoursEffective >= 1.0) {
    return hoursEffective * weightKg;
  } else if (hoursEffective >= 0.25) {
    return 0.5 * weightKg;
  } else {
    return 0.25 * weightKg;
  }
}
// During-swim carbohydrates (lower than cycling due to feeding difficulty)
function swimmingDuringSwimCarbs(durationH, poolOrOpenWater, gutTraining) {
  let carbMin, carbMax;
  if (durationH <= 1.0) {
    carbMin = 0;
    carbMax = 0;
  } else if (durationH <= 1.5) {
    carbMin = 0;
    carbMax = 30;
  } else if (durationH <= 2.5) {
    carbMin = 30;
    carbMax = 60;
  } else {
    carbMin = 45;
    carbMax = 75;
  }
  if (poolOrOpenWater === 'open_water' && durationH > 1.5) {
    carbMax += 10;
  }
  let gutMultiplier = 1.0;
  if (gutTraining === 'low') {
    gutMultiplier = 0.85;
  } else if (gutTraining === 'high') {
    gutMultiplier = 1.1;
  }
  const baseTarget = (carbMin + carbMax) / 2;
  const adjusted = baseTarget * gutMultiplier;
  const maxAbsorption = 60; // Swimmers struggle to consume >60 g/h
  return Math.min(Math.round(adjusted), maxAbsorption);
}
// Post-swim carbohydrates
function swimmingPostSwimCarbs(weightKg, durationH) {
  const carbPerKg = durationH > 2.0 ? 1.2 : 1.0;
  return carbPerKg * weightKg;
}
// Post-swim protein
function swimmingPostSwimProtein(weightKg) {
  return 0.3 * weightKg;
}
// During-swim protein (only for ultra-endurance)
function swimmingDuringSwimProtein(durationH) {
  return durationH > 3.5 ? 3.0 : 0.0;
}
// Swimming hydration rate
function swimmingHydrationRate(weightKg, met, waterTempC, poolDeckTempC, poolDeckHumidityPct) {
  let baseLph = 0.45;
  if (weightKg < 50) {
    baseLph = 0.35;
  } else if (weightKg > 80) {
    baseLph = 0.55;
  }
  if (met >= 11) {
    baseLph += 0.1;
  }
  if (waterTempC > 28) {
    baseLph *= 1.2;
  } else if (waterTempC < 20) {
    baseLph *= 0.8;
  }
  if (poolDeckTempC !== null && poolDeckHumidityPct !== null) {
    const [deckEnvMultiplier] = envMultiplier(poolDeckTempC, poolDeckHumidityPct);
    baseLph *= deckEnvMultiplier;
  }
  return Math.min(baseLph, 0.8);
}
// Swimming sodium rate
function swimmingSodiumRate(durationH, sweatSodiumCat, waterTempC) {
  let sodiumMgph = 400;
  if (sweatSodiumCat === 'low') {
    sodiumMgph = 300;
  } else if (sweatSodiumCat === 'medium') {
    sodiumMgph = 500;
  } else if (sweatSodiumCat === 'high') {
    sodiumMgph = 700;
  }
  if (waterTempC > 28) {
    sodiumMgph += 50;
  } else if (waterTempC < 20) {
    sodiumMgph -= 50;
  }
  return Math.min(sodiumMgph, 800);
}
// Complete swimming macro calculator
function calculateSwimmingMacros(input) {
  // 1. Duration
  const durationMin = swimmingDuration(input.distanceMeters, input.paceSecondsper100m);
  const durationH = durationMin / 60;
  const distanceKm = input.distanceMeters / 1000;
  // 2. MET and Energy
  const finalMET = swimmingMETFromPace(input.paceSecondsper100m, input.poolOrOpenWater, input.waterTempC);
  const caloriesGross = swimmingGrossCalories(input.weightKg, durationMin, finalMET);
  const caloriesNet = swimmingNetCalories(input.weightKg, distanceKm);
  // 3. Carbohydrates
  const hoursBeforeSwim = input.timeBeforeMinutes / 60.0;
  const preCarbs = swimmingPreSwimCarbs(input.weightKg, hoursBeforeSwim);
  const duringCarbsPerH = swimmingDuringSwimCarbs(durationH, input.poolOrOpenWater, input.gutTraining);
  const duringCarbsTotal = duringCarbsPerH * durationH;
  const postCarbs = swimmingPostSwimCarbs(input.weightKg, durationH);
  // 4. Protein
  const preProtein = 0.2 * input.weightKg;
  const duringProtein = swimmingDuringSwimProtein(durationH);
  const postProtein = swimmingPostSwimProtein(input.weightKg);
  // 5. Fat
  const preFat = hoursBeforeSwim > 2.0 ? 0.15 * input.weightKg : 0.1 * input.weightKg;
  // 6. Hydration
  const [envMult, envLabel] = envMultiplier(input.poolDeckTempC, input.poolDeckHumidityPct);
  const preWater = preRunHydration(input.weightKg, input.timeBeforeMinutes, input.sweatSodiumCat, envLabel);
  const duringWaterPerH = swimmingHydrationRate(input.weightKg, finalMET, input.waterTempC, input.poolDeckTempC, input.poolDeckHumidityPct);
  const duringWaterTotal = duringWaterPerH * 1000 * durationH;
  // 7. Sodium
  const preSodium = preWater.sodiumMg;
  const duringSodiumPerH = swimmingSodiumRate(durationH, input.sweatSodiumCat, input.waterTempC);
  const duringSodiumTotal = duringSodiumPerH * durationH;
  return {
    duration_min: Math.round(durationMin * 100) / 100,
    duration_h: Math.round(durationH * 10000) / 10000,
    pace_per_100m_seconds: input.paceSecondsper100m,
    distance_meters: input.distanceMeters,
    distance_km: Math.round(distanceKm * 1000) / 1000,
    calories_net_kcal: Math.round(caloriesNet),
    calories_gross_kcal: Math.round(caloriesGross),
    MET: Math.round(finalMET * 100) / 100,
    pre_swim_carbs_g: Math.round(preCarbs),
    pre_swim_protein_g: Math.round(preProtein),
    pre_swim_fat_g: Math.round(preFat * 10) / 10,
    during_swim_carbs_per_h: Math.round(duringCarbsPerH),
    during_swim_carbs_total: Math.round(duringCarbsTotal),
    during_swim_protein_per_h: duringProtein,
    post_swim_carbs_g: Math.round(postCarbs),
    post_swim_protein_g: Math.round(postProtein),
    pre_swim_water_ml: preWater.mainMl + preWater.topoffMl,
    during_swim_water_per_h_ml: Math.round(duringWaterPerH * 1000),
    during_swim_water_total_ml: Math.round(duringWaterTotal),
    pre_swim_sodium_mg: preSodium,
    during_swim_sodium_per_h_mg: duringSodiumPerH,
    during_swim_sodium_total_mg: Math.round(duringSodiumTotal)
  };
}
// ============================================================================
// BRICK WORKOUT FORMULAS (NEW)
// Based on docs/brick/nutrition-algorithm.md
// ============================================================================

// Calculate total duration from all segments
function calculateTotalBrickDuration(segments) {
  return segments.reduce((sum, segment) => sum + segment.duration_minutes, 0);
}

// Get base carb rate based on total duration
function getBaseBrickCarbRate(totalDurationMinutes) {
  if (totalDurationMinutes < 60) {
    return 0; // Mouth rinse only for <1 hour
  } else if (totalDurationMinutes < 90) {
    return 30; // 30g/hr for 1-1.5 hours
  } else if (totalDurationMinutes < 150) {
    return 45; // 45g/hr for 1.5-2.5 hours
  } else if (totalDurationMinutes < 180) {
    return 60; // 60g/hr for 2.5-3 hours
  } else {
    return 75; // 75-90g/hr for 3+ hours
  }
}

// Adjust for weighted average intensity across segments
function adjustBrickCarbRateForIntensity(baseCarbRate, segments) {
  const totalDuration = calculateTotalBrickDuration(segments);
  let weightedIntensity = 0;

  const intensityMultipliers = {
    easy: 0.7,
    moderate: 1.0,
    hard: 1.2,
    race: 1.3,
  };

  for (const segment of segments) {
    const multiplier = intensityMultipliers[segment.intensity] || 1.0;
    weightedIntensity += (segment.duration_minutes / totalDuration) * multiplier;
  }

  return Math.round(baseCarbRate * weightedIntensity);
}

// Get MET for a brick segment based on sport
function getMETForBrickSegment(segment) {
  const sport = segment.sport;

  if (sport === 'swimming') {
    // Use swimming MET calculation
    if (segment.pace_per_100m_seconds) {
      return swimmingMETFromPace(
        segment.pace_per_100m_seconds,
        segment.pool_or_open_water || 'pool',
        segment.water_temp_c || 26
      );
    }
    // Fallback: assume moderate intensity swimming
    return 10.0;
  } else if (sport === 'cycling') {
    // Use cycling MET calculation
    if (segment.speed_mph) {
      const speedKph = segment.speed_mph * MI_TO_KM;
      let met = cyclingMETFromSpeed(speedKph, segment.terrain || 'flat');

      // Adjust for elevation if provided
      if (segment.elevation_gain_ft && segment.distance_miles) {
        met = adjustMETForElevation(met, segment.elevation_gain_ft, segment.distance_miles);
      }

      // Adjust for indoor/outdoor
      met = adjustMETForIndoorOutdoor(met, segment.indoor_outdoor === 'indoor');

      return met;
    }
    // Fallback: assume moderate intensity cycling
    return 10.0;
  } else if (sport === 'running') {
    // Use running MET calculation
    if (segment.pace_minutes_per_mile) {
      return metFromPace(segment.pace_minutes_per_mile);
    }
    // Fallback: assume moderate intensity running
    return 8.0;
  }

  // Default fallback
  return 8.0;
}

// Calculate energy expenditure for brick workout
function calculateBrickEnergyExpenditure(segments, weightKg) {
  let totalKcal = 0;

  for (const segment of segments) {
    const met = getMETForBrickSegment(segment);
    const kcal = grossKcal(weightKg, segment.duration_minutes, met);
    totalKcal += kcal;
  }

  return Math.round(totalKcal);
}

// Calculate phase breakdown for brick workout
function calculateBrickPhaseBreakdown(segments, weightKg, duringCarbs, beforeCarbs, afterCarbs, beforeProtein, afterProtein, totalSodium, totalWater, envLabel) {
  const phases = {
    before: {
      carbs_g: Math.round(beforeCarbs),
      protein_g: beforeProtein,
      fat_g: 5,
      sodium_mg: 200,
      water_ml: 300,
    },
    during_segments: [],
    transitions: [],
    after: {
      carbs_g: Math.round(afterCarbs),
      protein_g: Math.round(afterProtein),
      fat_g: 10,
      sodium_mg: 625,
      water_ml: 1250,
    },
  };

  // Calculate remaining during carbs (after transitions)
  let remainingDuringCarbs = duringCarbs;

  // Account for transitions
  const transitionCount = segments.length - 1;
  if (transitionCount >= 1) {
    remainingDuringCarbs -= 20; // T1
  }
  if (transitionCount >= 2) {
    remainingDuringCarbs -= 25; // T2
  }

  // Allocate carbs to each segment
  for (let i = 0; i < segments.length; i++) {
    const segment = segments[i];
    const sport = segment.sport;
    const durationH = segment.duration_minutes / 60;

    let segmentCarbs = 0;
    let segmentSodium = 0;
    let segmentWater = 0;

    if (sport === 'swimming') {
      // Swimming: Cannot eat while swimming
      segmentCarbs = 0;
      segmentSodium = 0;
      segmentWater = 0;
    } else if (sport === 'cycling') {
      // Cycling: Higher gastric tolerance - maximize intake
      // Boost bike intake by 20% if followed by run (pre-load strategy)
      const nextSegmentIsRun = i < segments.length - 1 && segments[i + 1].sport === 'running';
      const preLoadBoost = nextSegmentIsRun ? 1.2 : 1.0;

      // Calculate proportion of remaining carbs
      const totalNonSwimDuration = segments
        .filter(s => s.sport !== 'swimming')
        .reduce((sum, s) => sum + s.duration_minutes, 0);

      const bikeProportion = segment.duration_minutes / totalNonSwimDuration;
      segmentCarbs = Math.round(remainingDuringCarbs * bikeProportion * preLoadBoost);

      segmentSodium = Math.round(500 * durationH);
      segmentWater = Math.round(600 * durationH);
    } else if (sport === 'running') {
      // Running: Reduced gastric tolerance - conservative intake
      const maxRunCarbsPerHour = 35;
      const maxRunCarbs = maxRunCarbsPerHour * durationH;

      // Calculate proportion of remaining carbs
      const totalNonSwimDuration = segments
        .filter(s => s.sport !== 'swimming')
        .reduce((sum, s) => sum + s.duration_minutes, 0);

      const runProportion = segment.duration_minutes / totalNonSwimDuration;
      const allocatedCarbs = remainingDuringCarbs * runProportion;

      segmentCarbs = Math.min(Math.round(allocatedCarbs), maxRunCarbs);

      segmentSodium = Math.round(400 * durationH);
      segmentWater = Math.round(500 * durationH);
    }

    phases.during_segments.push({
      segment_order: segment.order,
      sport: sport,
      duration_minutes: segment.duration_minutes,
      carbs_g: segmentCarbs,
      protein_g: 0,
      fat_g: 0,
      sodium_mg: segmentSodium,
      water_ml: segmentWater,
      food_categories: [`during_${sport}`],
    });

    // Add transition after this segment (if not last)
    if (i < segments.length - 1) {
      const transitionName = i === 0 ? 'T1' : 'T2';
      const transitionCarbs = i === 0 ? 20 : 25;
      const transitionSodium = i === 0 ? 150 : 100;
      const transitionWater = i === 0 ? 200 : 150;

      phases.transitions.push({
        transition_name: transitionName,
        after_sport: sport,
        before_sport: segments[i + 1].sport,
        carbs_g: transitionCarbs,
        protein_g: 0,
        fat_g: 0,
        sodium_mg: transitionSodium,
        water_ml: transitionWater,
        timing_note: transitionName === 'T1' ? 'Within first 5-10 minutes after swim' : 'Final 5-10 minutes of bike leg',
        food_categories: ['transition'],
      });
    }
  }

  return phases;
}

// Main brick macro calculation function
function calculateBrickMacros(input) {
  const { weightKg, brickSegments, gutTraining, timeBeforeMinutes, tempC, humidityPct, sweatSodiumCat } = input;

  // 1. Calculate total duration
  const totalDurationMin = calculateTotalBrickDuration(brickSegments);
  const totalDurationH = totalDurationMin / 60;

  // 2. Get base carb rate based on TOTAL duration (cumulative approach)
  const baseCarbRate = getBaseBrickCarbRate(totalDurationMin);

  // 3. Adjust for weighted average intensity
  const adjustedCarbRate = adjustBrickCarbRateForIntensity(baseCarbRate, brickSegments);

  // 4. Apply gut training multiplier
  const gutMultiplier = {
    low: 0.6,
    untrained: 0.6,
    moderate: 0.85,
    high: 1.0,
    trained: 1.0,
  }[gutTraining] || 0.85;

  const finalCarbRate = Math.min(adjustedCarbRate * gutMultiplier, 90); // Max 90g/hr

  // 5. Calculate total macros
  const duringCarbs = finalCarbRate * totalDurationH;
  const beforeCarbs = weightKg * 1.5; // 1-2g/kg, use 1.5
  const afterCarbs = totalDurationH > 2 ? weightKg * 1.2 : weightKg * 1.0; // 1-1.2g/kg for recovery

  const beforeProtein = 10; // Light protein before
  const afterProtein = weightKg * 0.3; // 0.3g/kg post

  // 6. Sodium and hydration
  const sodiumPerHour = 500; // Default mid-range
  const totalSodium = Math.round(sodiumPerHour * totalDurationH);

  const waterPerHour = 600; // Default mid-range (ml)
  const totalWater = Math.round(waterPerHour * totalDurationH);

  // 7. Energy expenditure
  const energyExpenditure = calculateBrickEnergyExpenditure(brickSegments, weightKg);

  // 8. Environment
  const [envMult, envLabel] = envMultiplier(tempC, humidityPct);

  // 9. Phase breakdown
  const phases = calculateBrickPhaseBreakdown(
    brickSegments,
    weightKg,
    duringCarbs,
    beforeCarbs,
    afterCarbs,
    beforeProtein,
    afterProtein,
    totalSodium,
    totalWater,
    envLabel
  );

  // 10. Calculate total macros across all phases
  let totalCarbs = phases.before.carbs_g;
  let totalProtein = phases.before.protein_g;
  let totalFat = phases.before.fat_g;
  let totalSodiumFinal = phases.before.sodium_mg;
  let totalWaterFinal = phases.before.water_ml;

  phases.during_segments.forEach(seg => {
    totalCarbs += seg.carbs_g;
    totalProtein += seg.protein_g;
    totalFat += seg.fat_g;
    totalSodiumFinal += seg.sodium_mg;
    totalWaterFinal += seg.water_ml;
  });

  phases.transitions.forEach(trans => {
    totalCarbs += trans.carbs_g;
    totalProtein += trans.protein_g;
    totalFat += trans.fat_g;
    totalSodiumFinal += trans.sodium_mg;
    totalWaterFinal += trans.water_ml;
  });

  totalCarbs += phases.after.carbs_g;
  totalProtein += phases.after.protein_g;
  totalFat += phases.after.fat_g;
  totalSodiumFinal += phases.after.sodium_mg;
  totalWaterFinal += phases.after.water_ml;

  // 11. Generate brick type string
  const sportNames = brickSegments.map(s => s.sport.toUpperCase());
  const brickType = sportNames.join('_');

  return {
    activity_type: 'brick',
    brick_type: brickType,
    total_carbs_g: Math.round(totalCarbs),
    total_protein_g: Math.round(totalProtein),
    total_fat_g: Math.round(totalFat),
    total_sodium_mg: Math.round(totalSodiumFinal),
    total_water_ml: Math.round(totalWaterFinal),
    phases: phases,
    total_duration_minutes: totalDurationMin,
    energy_expenditure_kcal: energyExpenditure,
    carb_rate_g_per_hour: Math.round(finalCarbRate * 10) / 10,
  };
}

serve(withSentry(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  try {
    const requestData = await req.json();
    // Determine activity type (default to running for backward compatibility)
    const activityType = requestData.activity_type || 'running';
    console.log('🔍 DEBUG: Received macro calculation request:', {
      activity_type: activityType,
      weight: requestData.weight,
      weight_unit: requestData.weight_unit,
      temp_c: requestData.temp_c,
      humidity_pct: requestData.humidity_pct,
      gut_training: requestData.gut_training,
      sweat_rate_category: requestData.sweat_rate_category
    });
    let macros;
    // Route to appropriate calculation function based on activity type
    if (activityType === 'running') {
      // Validate running-specific fields
      if (!requestData.weight || !requestData.run_distance || !requestData.run_pace) {
        return new Response(JSON.stringify({
          success: false,
          message: 'Missing required fields for running: weight, run_distance, and run_pace are required'
        }), {
          status: 400,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        });
      }
      // Calculate running macros
      macros = computeRunFueling(requestData);
      console.log('✅ DEBUG: Calculated running macros successfully:', {
        duration_h: macros.duration_h,
        calories_net: macros.calories_net_kcal,
        calories_gross: macros.calories_gross_kcal,
        pre_run_carbs_g: macros.pre_run_carbs_g,
        during_total_g: macros.during_total_g,
        MET: macros.MET
      });
    } else if (activityType === 'cycling') {
      // Validate cycling-specific fields
      if (!requestData.weight || !requestData.distance_miles || !requestData.speed_mph) {
        return new Response(JSON.stringify({
          success: false,
          message: 'Missing required fields for cycling: weight, distance_miles, and speed_mph are required'
        }), {
          status: 400,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        });
      }
      // Convert weight to kg if needed
      const weightKg = toKg(requestData.weight, requestData.weight_unit || 'kg');
      // Prepare cycling input
      const timeBeforeMinutes = requestData.time_before_min || 120;
      const cyclingInput = {
        weightKg: weightKg,
        distanceMiles: requestData.distance_miles,
        speedMph: requestData.speed_mph,
        terrain: requestData.terrain || 'flat',
        elevationGainFt: requestData.elevation_gain_ft || 0,
        indoorOutdoor: requestData.indoor_outdoor || 'outdoor',
        timeBeforeMinutes: timeBeforeMinutes,
        gutTraining: requestData.gut_training || 'moderate',
        tempC: requestData.temp_c || null,
        humidityPct: requestData.humidity_pct || null,
        sweatSodiumCat: requestData.sweat_sodium || 'medium'
      };
      // Calculate cycling macros
      const cyclingMacros = calculateCyclingMacros(cyclingInput);
      // Normalize cycling field names to match running format (for consistent Dart parsing)
      macros = {
        duration_min: cyclingMacros.duration_min,
        duration_h: cyclingMacros.duration_h,
        pace_min_per_mile: 0,
        speed_mph: cyclingMacros.speed_mph,
        distance_mi: cyclingMacros.distance_mi,
        distance_km: cyclingMacros.distance_km,
        calories_net_kcal: cyclingMacros.calories_net_kcal,
        calories_gross_kcal: cyclingMacros.calories_gross_kcal,
        MET: cyclingMacros.MET,
        // Pre-activity (normalize pre_ride_* to pre_run_*)
        pre_run_carbs_g: cyclingMacros.pre_ride_carbs_g,
        pre_run_carbs_rule: `${Math.round(timeBeforeMinutes / 60 * 10) / 10}h × ${Math.round(cyclingMacros.pre_ride_carbs_g / weightKg * 10) / 10} g/kg`,
        pre_run_protein_g_optional: cyclingMacros.pre_ride_protein_g,
        pre_run_fat_g_cap: cyclingMacros.pre_ride_fat_g,
        pre_run_water_ml: cyclingMacros.pre_ride_water_ml,
        pre_run_sodium_mg: cyclingMacros.pre_ride_sodium_mg,
        // During-activity (normalize during_ride_* to during_*)
        during_rate_g_per_h: cyclingMacros.during_ride_carbs_per_h,
        during_total_g: cyclingMacros.during_ride_carbs_total,
        during_mass_norm_rate_g_per_h: cyclingMacros.during_ride_carbs_per_h,
        during_abs_clamp_range_g_per_h: [
          30,
          90
        ],
        during_water_rate_ml_per_h: cyclingMacros.during_ride_water_per_h_ml,
        during_water_total_ml: cyclingMacros.during_ride_water_total_ml,
        during_sodium_rate_mg_per_h: cyclingMacros.during_ride_sodium_per_h_mg,
        during_sodium_total_mg: cyclingMacros.during_ride_sodium_total_mg,
        // Post-activity (normalize post_ride_* to post_run_*)
        post_run_carbs_g: cyclingMacros.post_ride_carbs_g,
        post_run_protein_g: cyclingMacros.post_ride_protein_g,
        post_run_water_ml: 1250,
        post_run_sodium_mg: 625
      };
      console.log('✅ DEBUG: Calculated cycling macros successfully:', {
        duration_h: macros.duration_h,
        calories_net: macros.calories_net_kcal,
        calories_gross: macros.calories_gross_kcal,
        pre_run_carbs_g: macros.pre_run_carbs_g,
        during_total_g: macros.during_total_g,
        MET: macros.MET
      });
    } else if (activityType === 'swimming') {
      // Validate swimming-specific fields
      if (!requestData.weight || !requestData.distance_meters || !requestData.pace_per_100m_seconds) {
        return new Response(JSON.stringify({
          success: false,
          message: 'Missing required fields for swimming: weight, distance_meters, and pace_per_100m_seconds are required'
        }), {
          status: 400,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        });
      }
      // Convert weight to kg if needed
      const weightKg = toKg(requestData.weight, requestData.weight_unit || 'kg');
      // Prepare swimming input
      const swimmingInput = {
        weightKg: weightKg,
        distanceMeters: requestData.distance_meters,
        paceSecondsper100m: requestData.pace_per_100m_seconds,
        poolOrOpenWater: requestData.pool_or_open_water || 'pool',
        waterTempC: requestData.water_temp_c || 26,
        poolDeckTempC: requestData.pool_deck_temp_c || null,
        poolDeckHumidityPct: requestData.pool_deck_humidity_pct || null,
        timeBeforeMinutes: requestData.time_before_min || 120,
        gutTraining: requestData.gut_training || 'moderate',
        sweatSodiumCat: requestData.sweat_sodium || 'medium'
      };
      // Calculate swimming macros
      const swimmingMacros = calculateSwimmingMacros(swimmingInput);
      // Normalize swimming field names to match running format (for consistent Dart parsing)
      macros = {
        duration_min: swimmingMacros.duration_min,
        duration_h: swimmingMacros.duration_h,
        pace_min_per_mile: 0,
        pace_per_100m_seconds: swimmingMacros.pace_per_100m_seconds,
        speed_mph: 0,
        distance_mi: swimmingMacros.distance_meters * 0.000621371,
        distance_km: swimmingMacros.distance_km,
        distance_meters: swimmingMacros.distance_meters,
        calories_net_kcal: swimmingMacros.calories_net_kcal,
        calories_gross_kcal: swimmingMacros.calories_gross_kcal,
        MET: swimmingMacros.MET,
        // Pre-activity (normalize pre_swim_* to pre_run_*)
        pre_run_carbs_g: swimmingMacros.pre_swim_carbs_g,
        pre_run_carbs_rule: `${Math.round(swimmingInput.timeBeforeMinutes / 60 * 10) / 10}h × ${Math.round(swimmingMacros.pre_swim_carbs_g / weightKg * 10) / 10} g/kg`,
        pre_run_protein_g_optional: swimmingMacros.pre_swim_protein_g,
        pre_run_fat_g_cap: swimmingMacros.pre_swim_fat_g,
        pre_run_water_ml: swimmingMacros.pre_swim_water_ml,
        pre_run_sodium_mg: swimmingMacros.pre_swim_sodium_mg,
        // During-activity (normalize during_swim_* to during_*)
        during_rate_g_per_h: swimmingMacros.during_swim_carbs_per_h,
        during_total_g: swimmingMacros.during_swim_carbs_total,
        during_mass_norm_rate_g_per_h: swimmingMacros.during_swim_carbs_per_h,
        during_abs_clamp_range_g_per_h: [
          0,
          60
        ],
        during_water_rate_ml_per_h: swimmingMacros.during_swim_water_per_h_ml,
        during_water_total_ml: swimmingMacros.during_swim_water_total_ml,
        during_sodium_rate_mg_per_h: swimmingMacros.during_swim_sodium_per_h_mg,
        during_sodium_total_mg: swimmingMacros.during_swim_sodium_total_mg,
        // Post-activity (normalize post_swim_* to post_run_*)
        post_run_carbs_g: swimmingMacros.post_swim_carbs_g,
        post_run_protein_g: swimmingMacros.post_swim_protein_g,
        post_run_water_ml: 1250,
        post_run_sodium_mg: 625
      };
      console.log('✅ DEBUG: Calculated swimming macros successfully:', {
        duration_h: macros.duration_h,
        calories_net: macros.calories_net_kcal,
        calories_gross: macros.calories_gross_kcal,
        distance_mi: macros.distance_mi,
        pre_run_carbs_g: macros.pre_run_carbs_g,
        during_total_g: macros.during_total_g,
        MET: macros.MET
      });
    } else if (activityType === 'brick') {
      // Validate brick-specific fields
      if (!requestData.weight || !requestData.brick_segments || !Array.isArray(requestData.brick_segments)) {
        return new Response(JSON.stringify({
          success: false,
          message: 'Missing required fields for brick: weight and brick_segments array are required'
        }), {
          status: 400,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        });
      }

      // Validate segment count
      if (requestData.brick_segments.length < 2 || requestData.brick_segments.length > 3) {
        return new Response(JSON.stringify({
          success: false,
          message: 'Brick workouts must have 2-3 segments'
        }), {
          status: 400,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        });
      }

      // Convert weight to kg if needed
      const weightKg = toKg(requestData.weight, requestData.weight_unit || 'kg');

      // Prepare brick input
      const brickInput = {
        weightKg: weightKg,
        brickSegments: requestData.brick_segments,
        gutTraining: requestData.gut_training || 'moderate',
        timeBeforeMinutes: requestData.time_before_min || 120,
        tempC: requestData.temp_c || null,
        humidityPct: requestData.humidity_pct || null,
        sweatSodiumCat: requestData.sweat_sodium || 'medium'
      };

      // Calculate brick macros
      const brickMacros = calculateBrickMacros(brickInput);

      // Calculate total distance across all segments
      let totalDistanceMiles = 0;
      for (const segment of requestData.brick_segments) {
        if (segment.distance_miles) {
          totalDistanceMiles += segment.distance_miles;
        } else if (segment.distance_meters) {
          totalDistanceMiles += segment.distance_meters * 0.000621371;
        }
      }

      // Normalize brick response to match expected field names
      macros = {
        ...brickMacros,
        // Add normalized time/distance fields for BrickMacroService
        duration_h: brickMacros.total_duration_minutes / 60,
        duration_min: brickMacros.total_duration_minutes,
        distance_mi: Math.round(totalDistanceMiles * 100) / 100,
        distance_km: Math.round(totalDistanceMiles * 1.60934 * 100) / 100,
        calories_net_kcal: brickMacros.energy_expenditure_kcal,
        calories_gross_kcal: brickMacros.energy_expenditure_kcal * 1.1, // Approximate gross
      };

      console.log('✅ DEBUG: Calculated brick macros successfully:', {
        brick_type: macros.brick_type,
        duration_h: macros.duration_h,
        duration_min: macros.duration_min,
        distance_mi: macros.distance_mi,
        carb_rate_g_per_hour: macros.carb_rate_g_per_hour,
        total_carbs_g: macros.total_carbs_g,
        phases_count: macros.phases.before ? 1 : 0 + macros.phases.during_segments.length + macros.phases.transitions.length + (macros.phases.after ? 1 : 0)
      });
    } else {
      // Invalid activity type
      return new Response(JSON.stringify({
        success: false,
        message: `Invalid activity_type: "${activityType}". Must be "running", "cycling", "swimming", or "brick".`
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    return new Response(JSON.stringify({
      success: true,
      activity_type: activityType,
      macros
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  } catch (error) {
    console.error('Error calculating macros:', error);
    return new Response(JSON.stringify({
      success: false,
      message: 'Failed to calculate macros',
      error: error.message
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
}));
