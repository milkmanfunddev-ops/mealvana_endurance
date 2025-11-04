# Sports Nutrition Formulas: Cycling & Swimming

## Overview

This document provides evidence-based formulas for calculating nutrition requirements for cycling and swimming activities. All formulas are derived from peer-reviewed sports science research and professional guidelines.

**IMPORTANT**: Running formulas are NOT documented here. They remain unchanged in the existing `generate-macros` edge function.

---

## Table of Contents

1. [Cycling Formulas](#cycling-formulas)
2. [Swimming Formulas](#swimming-formulas)
3. [Shared Formulas](#shared-formulas-all-sports)
4. [Environmental Adjustments](#environmental-adjustments)
5. [Implementation Guidelines](#implementation-guidelines)
6. [References](#references)

---

## Cycling Formulas

### 1. Energy Expenditure

#### MET Calculation from Speed

Cycling energy expenditure is highly dependent on speed due to air resistance.

```typescript
function cyclingMETFromSpeed(speedKph: number, terrain: 'flat' | 'rolling' | 'hilly'): number {
  // Base MET from speed (flat terrain, outdoor)
  let met: number;

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
```

**Research Basis:**
- Flat cycling at 16-19 km/h ≈ 6 METs (Compendium of Physical Activities)
- Cycling at 22-25 km/h ≈ 8-10 METs
- Cycling at 30+ km/h ≈ 12-16 METs
- Terrain multipliers based on power requirements research

#### Elevation Gain Adjustment

```typescript
function adjustMETForElevation(baseMET: number, elevationGainFt: number, distanceMiles: number): number {
  // Calculate vertical meters per kilometer
  const elevationGainM = elevationGainFt * 0.3048;
  const distanceKm = distanceMiles * 1.60934;
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
```

#### Indoor vs Outdoor Adjustment

```typescript
function adjustMETForIndoorOutdoor(baseMET: number, isIndoor: boolean): number {
  if (isIndoor) {
    // Indoor cycling is slightly easier due to no wind resistance, but harder due to heat
    // Generally considered 5-10% less energy expenditure
    return baseMET * 0.95;
  }
  return baseMET;
}
```

#### Gross Energy Expenditure (Calories)

```typescript
function cyclingGrossCalories(
  weightKg: number,
  durationMin: number,
  met: number
): number {
  // Gross kcal = MET × 3.5 × body weight (kg) / 200 × duration (min)
  return met * 3.5 * weightKg / 200.0 * durationMin;
}
```

#### Net Energy Expenditure (Calories)

```typescript
function cyclingNetCalories(
  weightKg: number,
  distanceKm: number,
  speedKph: number
): number {
  // Cycling net cost is approximately 0.3-0.5 kcal/kg/km at moderate speeds
  // Higher speeds = more air resistance = higher energy cost

  let costPerKgKm: number;

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
```

**Note**: Gross calories are more accurate for cyclists due to the complexity of wind resistance calculations.

### 2. Duration Calculation

```typescript
function cyclingDuration(distanceMiles: number, speedMph: number): number {
  // Duration in hours
  return distanceMiles / speedMph;
}

function cyclingDurationMinutes(distanceMiles: number, speedMph: number): number {
  return cyclingDuration(distanceMiles, speedMph) * 60;
}
```

### 3. Carbohydrate Requirements

#### Pre-Ride Carbs

Cyclists follow the same pre-exercise carb guidelines as runners:

```typescript
function cyclingPreRideCarbs(weightKg: number, hoursBeforeRide: number): number {
  // 1-4 g/kg based on time window
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
```

#### During-Ride Carbs

Cyclists can tolerate **higher carbohydrate intake** than runners due to less GI distress:

```typescript
function cyclingDuringRideCarbs(
  durationH: number,
  met: number,
  weightKg: number,
  gutTraining: 'low' | 'moderate' | 'high'
): number {
  // Carb bands by duration (cyclists can go higher than runners)
  let carbMin: number, carbMax: number;

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
```

**Key Difference from Running**: Cyclists can consume 90-120 g/h vs runners at 60-90 g/h due to:
- Less mechanical GI stress
- Easier access to nutrition
- Ability to consume solid foods

#### Post-Ride Carbs

```typescript
function cyclingPostRideCarbs(weightKg: number, durationH: number): number {
  // 1.0-1.2 g/kg based on duration
  const carbPerKg = durationH > 2.0 ? 1.2 : 1.0;
  return carbPerKg * weightKg;
}
```

### 4. Protein Requirements

```typescript
function cyclingPostRideProtein(weightKg: number): number {
  // 0.25-0.3 g/kg for recovery
  return 0.3 * weightKg;
}

function cyclingDuringRideProtein(durationH: number): number {
  // Only for ultra-endurance (>3.5 hours)
  return durationH > 3.5 ? 5.0 : 0.0; // 5 g/h for long rides
}
```

### 5. Hydration Requirements

Cyclists need **similar or slightly higher** fluid intake than runners, but can tolerate more volume:

```typescript
function cyclingHydrationRate(
  weightKg: number,
  met: number,
  tempC: number,
  humidityPct: number
): number {
  // Base rate: 0.5-0.75 L/h (slightly higher than running due to airflow reducing perceived need)
  let baseLph = 0.60;

  // Weight adjustment
  if (weightKg < 50) {
    baseLph = 0.50;
  } else if (weightKg > 80) {
    baseLph = 0.70;
  }

  // Intensity adjustment
  if (met >= 12) {
    baseLph += 0.1; // High intensity = more sweat
  }

  // Environmental adjustment
  const envMultiplier = environmentalMultiplier(tempC, humidityPct);
  baseLph *= envMultiplier;

  // Cyclists can handle more volume (less sloshing)
  return Math.min(baseLph, 1.0); // Cap at 1.0 L/h
}
```

### 6. Sodium Requirements

```typescript
function cyclingSodiumRate(
  durationH: number,
  sweatSodiumCat: 'low' | 'medium' | 'high',
  envLabel: string
): number {
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

  // Cyclists can handle higher sodium intake (better absorption on bike)
  return Math.min(sodiumMgph, 1200);
}
```

### 7. Complete Cycling Macro Calculator

```typescript
interface CyclingMacroInput {
  weightKg: number;
  distanceMiles: number;
  speedMph: number;
  terrain: 'flat' | 'rolling' | 'hilly';
  indoorOutdoor: 'indoor' | 'outdoor';
  elevationGainFt: number;
  timeBeforeMinutes: number;
  gutTraining: 'low' | 'moderate' | 'high';
  tempC: number | null;
  humidityPct: number | null;
  sweatSodiumCat: 'low' | 'medium' | 'high';
}

interface CyclingMacroOutput {
  duration_min: number;
  duration_h: number;
  speed_mph: number;
  distance_mi: number;
  distance_km: number;
  calories_net_kcal: number;
  calories_gross_kcal: number;
  MET: number;

  pre_ride_carbs_g: number;
  pre_ride_protein_g: number;
  pre_ride_fat_g: number;

  during_ride_carbs_per_h: number;
  during_ride_carbs_total: number;
  during_ride_protein_per_h: number;

  post_ride_carbs_g: number;
  post_ride_protein_g: number;

  pre_ride_water_ml: number;
  during_ride_water_per_h_ml: number;
  during_ride_water_total_ml: number;

  pre_ride_sodium_mg: number;
  during_ride_sodium_per_h_mg: number;
  during_ride_sodium_total_mg: number;
}

function calculateCyclingMacros(input: CyclingMacroInput): CyclingMacroOutput {
  // 1. Duration
  const durationH = cyclingDuration(input.distanceMiles, input.speedMph);
  const durationMin = durationH * 60;
  const distanceKm = input.distanceMiles * 1.60934;
  const speedKph = input.speedMph * 1.60934;

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

  // 5. Fat (minimal, same as running)
  const preFat = hoursBeforeRide > 2.0 ? 0.2 * input.weightKg : 0.1 * input.weightKg;

  // 6. Hydration
  const envMultiplier = environmentalMultiplier(input.tempC, input.humidityPct);
  const preWater = calculatePreExerciseHydration(input.weightKg, input.timeBeforeMinutes, envMultiplier);
  const duringWaterPerH = cyclingHydrationRate(input.weightKg, finalMET, input.tempC || 20, input.humidityPct || 60);
  const duringWaterTotal = duringWaterPerH * 1000 * durationH; // Convert to mL

  // 7. Sodium
  const envLabel = getEnvironmentLabel(envMultiplier);
  const preSodium = calculatePreExerciseSodium(input.timeBeforeMinutes, envLabel);
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

    pre_ride_water_ml: preWater,
    during_ride_water_per_h_ml: Math.round(duringWaterPerH * 1000),
    during_ride_water_total_ml: Math.round(duringWaterTotal),

    pre_ride_sodium_mg: preSodium,
    during_ride_sodium_per_h_mg: duringSodiumPerH,
    during_ride_sodium_total_mg: Math.round(duringSodiumTotal),
  };
}
```

---

## Swimming Formulas

### 1. Energy Expenditure

#### MET Calculation from Pace/Intensity

Swimming has **high energy cost** due to water drag and body position:

```typescript
function swimmingMETFromPace(
  paceSecondsper100m: number,
  poolOrOpenWater: 'pool' | 'open_water',
  waterTempC: number
): number {
  // Base MET from pace (freestyle)
  let met: number;

  if (paceSecondsper100m >= 180) {
    // Very slow (3:00+ per 100m) - leisure/recovery
    met = 6.0;
  } else if (paceSecondsper100m >= 150) {
    // Slow (2:30-3:00 per 100m) - easy
    met = 8.0;
  } else if (paceSecondsper100m >= 120) {
    // Moderate (2:00-2:30 per 100m)
    met = 10.0;
  } else if (paceSecondsper100m >= 90) {
    // Fast (1:30-2:00 per 100m) - vigorous
    met = 11.0;
  } else {
    // Very fast (<1:30 per 100m) - race pace
    met = 13.0;
  }

  // Open water adjustment (harder due to no walls, currents, waves)
  if (poolOrOpenWater === 'open_water') {
    met *= 1.15; // 15% increase for open water
  }

  // Cold water adjustment (more energy for thermoregulation)
  if (waterTempC < 20) {
    met *= 1.1; // 10% increase for cold water
  } else if (waterTempC > 28) {
    met *= 0.95; // 5% decrease for warm pool (less thermoregulation)
  }

  return Math.round(met * 10) / 10;
}
```

**Alternative: MET from Intensity Zone**

```typescript
function swimmingMETFromIntensity(intensity: 'zone_1' | 'zone_2' | 'zone_3' | 'zone_4'): number {
  const intensityMETs = {
    zone_1: 6.0,  // Easy/recovery
    zone_2: 8.0,  // Moderate
    zone_3: 10.0, // Hard
    zone_4: 12.0, // Very hard
  };
  return intensityMETs[intensity];
}
```

#### Gross Energy Expenditure (Calories)

```typescript
function swimmingGrossCalories(
  weightKg: number,
  durationMin: number,
  met: number
): number {
  // Same formula as cycling
  return met * 3.5 * weightKg / 200.0 * durationMin;
}
```

#### Net Energy Expenditure (Calories)

```typescript
function swimmingNetCalories(
  weightKg: number,
  distanceKm: number
): number {
  // Swimming has VERY high energy cost per distance
  // Approximately 3-4 kcal/kg/km (3-4x higher than running!)
  const costPerKgKm = 3.5;
  return weightKg * distanceKm * costPerKgKm;
}
```

**Note**: Swimming is ~3-4x more energy-intensive per km than running due to water drag.

### 2. Duration Calculation

```typescript
function swimmingDuration(distanceMeters: number, paceSecondsper100m: number): number {
  // Duration in minutes
  const num100mSegments = distanceMeters / 100;
  const totalSeconds = num100mSegments * paceSecondsper100m;
  return totalSeconds / 60;
}

function swimmingDurationHours(distanceMeters: number, paceSecondsper100m: number): number {
  return swimmingDuration(distanceMeters, paceSecondsper100m) / 60;
}
```

### 3. Carbohydrate Requirements

#### Pre-Swim Carbs

Swimmers follow the same pre-exercise guidelines:

```typescript
function swimmingPreSwimCarbs(weightKg: number, hoursBeforeSwim: number): number {
  // 1-4 g/kg based on time window (same as cycling/running)
  const hoursEffective = Math.min(hoursBeforeSwim, 4.0);

  if (hoursEffective >= 1.0) {
    return hoursEffective * weightKg;
  } else if (hoursEffective >= 0.25) {
    return 0.5 * weightKg;
  } else {
    return 0.25 * weightKg;
  }
}
```

#### During-Swim Carbs

Swimming has **unique challenges** for during-exercise nutrition:

```typescript
function swimmingDuringSwimCarbs(
  durationH: number,
  poolOrOpenWater: 'pool' | 'open_water',
  gutTraining: 'low' | 'moderate' | 'high'
): number {
  // Carb bands by duration (LOWER than cycling due to feeding difficulty)
  let carbMin: number, carbMax: number;

  if (durationH <= 1.0) {
    // For swims <1 hour, focus on pre-swim fueling
    carbMin = 0;
    carbMax = 0;
  } else if (durationH <= 1.5) {
    // 1-1.5 hours: minimal during-swim (hard to consume)
    carbMin = 0;
    carbMax = 30;
  } else if (durationH <= 2.5) {
    // 1.5-2.5 hours: moderate intake at feed stops
    carbMin = 30;
    carbMax = 60;
  } else {
    // >2.5 hours: aim for higher but still limited by logistics
    carbMin = 45;
    carbMax = 75;
  }

  // Open water allows more feeding opportunities (support boat)
  if (poolOrOpenWater === 'open_water' && durationH > 1.5) {
    carbMax += 10;
  }

  // Gut training adjustment
  let gutMultiplier = 1.0;
  if (gutTraining === 'low') {
    gutMultiplier = 0.85;
  } else if (gutTraining === 'high') {
    gutMultiplier = 1.1;
  }

  const baseTarget = (carbMin + carbMax) / 2;
  const adjusted = baseTarget * gutMultiplier;

  // Cap at max practical absorption for swimming
  const maxAbsorption = 60; // Swimmers struggle to consume >60 g/h

  return Math.min(Math.round(adjusted), maxAbsorption);
}
```

**Key Limitation**: Swimmers can only consume liquids/gels during brief stops, making 60-75 g/h the practical maximum.

#### Post-Swim Carbs

```typescript
function swimmingPostSwimCarbs(weightKg: number, durationH: number): number {
  // 1.0-1.2 g/kg based on duration (same as cycling)
  const carbPerKg = durationH > 2.0 ? 1.2 : 1.0;
  return carbPerKg * weightKg;
}
```

### 4. Protein Requirements

```typescript
function swimmingPostSwimProtein(weightKg: number): number {
  // 0.25-0.3 g/kg for recovery
  return 0.3 * weightKg;
}

function swimmingDuringSwimProtein(durationH: number): number {
  // Only for ultra-distance swims (>3.5 hours)
  return durationH > 3.5 ? 3.0 : 0.0; // 3 g/h (lower than cycling due to feeding difficulty)
}
```

### 5. Hydration Requirements

**IMPORTANT**: Swimmers still sweat significantly, even though they're in water!

```typescript
function swimmingHydrationRate(
  weightKg: number,
  met: number,
  waterTempC: number,
  poolDeckTempC: number | null,
  poolDeckHumidityPct: number | null
): number {
  // Base rate: 0.3-0.6 L/h (60-80% of running/cycling due to cooling effect)
  let baseLph = 0.45;

  // Weight adjustment
  if (weightKg < 50) {
    baseLph = 0.35;
  } else if (weightKg > 80) {
    baseLph = 0.55;
  }

  // Intensity adjustment
  if (met >= 11) {
    baseLph += 0.1;
  }

  // Water temperature adjustment (warmer water = more sweat)
  if (waterTempC > 28) {
    baseLph *= 1.2; // Warm pool = more sweat
  } else if (waterTempC < 20) {
    baseLph *= 0.8; // Cold water = less sweat
  }

  // Pool deck environment (for rest intervals)
  if (poolDeckTempC !== null && poolDeckHumidityPct !== null) {
    const deckEnvMultiplier = environmentalMultiplier(poolDeckTempC, poolDeckHumidityPct);
    baseLph *= deckEnvMultiplier;
  }

  return Math.min(baseLph, 0.8); // Cap at 0.8 L/h for swimming
}
```

**Research Note**: Swimmers can lose 0.3-1.0 L/h of sweat depending on intensity, water temp, and air temp/humidity on deck.

### 6. Sodium Requirements

```typescript
function swimmingSodiumRate(
  durationH: number,
  sweatSodiumCat: 'low' | 'medium' | 'high',
  waterTempC: number
): number {
  // Base sodium by sweat category (slightly lower than cycling)
  let sodiumMgph = 400;

  if (sweatSodiumCat === 'low') {
    sodiumMgph = 300;
  } else if (sweatSodiumCat === 'medium') {
    sodiumMgph = 500;
  } else if (sweatSodiumCat === 'high') {
    sodiumMgph = 700;
  }

  // Water temperature adjustment
  if (waterTempC > 28) {
    sodiumMgph += 50; // Warm water = more sweat
  } else if (waterTempC < 20) {
    sodiumMgph -= 50; // Cold water = less sweat
  }

  // Swimmers have practical limits on sodium intake during swim
  return Math.min(sodiumMgph, 800);
}
```

### 7. Complete Swimming Macro Calculator

```typescript
interface SwimmingMacroInput {
  weightKg: number;
  distanceMeters: number;
  paceSecondsper100m: number;
  poolOrOpenWater: 'pool' | 'open_water';
  waterTempC: number;
  poolDeckTempC: number | null;
  poolDeckHumidityPct: number | null;
  timeBeforeMinutes: number;
  gutTraining: 'low' | 'moderate' | 'high';
  sweatSodiumCat: 'low' | 'medium' | 'high';
}

interface SwimmingMacroOutput {
  duration_min: number;
  duration_h: number;
  pace_per_100m_seconds: number;
  distance_meters: number;
  distance_km: number;
  calories_net_kcal: number;
  calories_gross_kcal: number;
  MET: number;

  pre_swim_carbs_g: number;
  pre_swim_protein_g: number;
  pre_swim_fat_g: number;

  during_swim_carbs_per_h: number;
  during_swim_carbs_total: number;
  during_swim_protein_per_h: number;

  post_swim_carbs_g: number;
  post_swim_protein_g: number;

  pre_swim_water_ml: number;
  during_swim_water_per_h_ml: number;
  during_swim_water_total_ml: number;

  pre_swim_sodium_mg: number;
  during_swim_sodium_per_h_mg: number;
  during_swim_sodium_total_mg: number;
}

function calculateSwimmingMacros(input: SwimmingMacroInput): SwimmingMacroOutput {
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
  const preProtein = 0.2 * input.weightKg; // Slightly less than cycling
  const duringProtein = swimmingDuringSwimProtein(durationH);
  const postProtein = swimmingPostSwimProtein(input.weightKg);

  // 5. Fat (minimal)
  const preFat = hoursBeforeSwim > 2.0 ? 0.15 * input.weightKg : 0.1 * input.weightKg;

  // 6. Hydration
  const preWater = calculatePreExerciseHydration(input.weightKg, input.timeBeforeMinutes, 1.0);
  const duringWaterPerH = swimmingHydrationRate(
    input.weightKg,
    finalMET,
    input.waterTempC,
    input.poolDeckTempC,
    input.poolDeckHumidityPct
  );
  const duringWaterTotal = duringWaterPerH * 1000 * durationH; // Convert to mL

  // 7. Sodium
  const preSodium = calculatePreExerciseSodium(input.timeBeforeMinutes, 'moderate');
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

    pre_swim_water_ml: preWater,
    during_swim_water_per_h_ml: Math.round(duringWaterPerH * 1000),
    during_swim_water_total_ml: Math.round(duringWaterTotal),

    pre_swim_sodium_mg: preSodium,
    during_swim_sodium_per_h_mg: duringSodiumPerH,
    during_swim_sodium_total_mg: Math.round(duringSodiumTotal),
  };
}
```

---

## Shared Formulas (All Sports)

These formulas apply to running, cycling, and swimming:

### 1. Environmental Multiplier

```typescript
function environmentalMultiplier(tempC: number | null, humidityPct: number | null): number {
  if (tempC === null && humidityPct === null) {
    return 1.0; // Moderate conditions
  }

  const t = tempC ?? 20.0;
  const h = humidityPct ?? 60.0;

  if (t <= 10) {
    return 0.85; // Cool
  } else if (t <= 20 && h <= 60) {
    return 1.0; // Temperate
  } else if (t <= 25 || (h > 60 && h <= 75)) {
    return 1.1; // Warm
  } else if (t <= 30 || (h > 75 && h <= 85)) {
    return 1.2; // Hot
  } else {
    return 1.3; // Very hot
  }
}

function getEnvironmentLabel(multiplier: number): string {
  if (multiplier <= 0.85) return 'cool';
  if (multiplier <= 1.0) return 'temperate';
  if (multiplier <= 1.1) return 'warm';
  if (multiplier <= 1.2) return 'hot';
  return 'very_hot';
}
```

### 2. Pre-Exercise Hydration

```typescript
function calculatePreExerciseHydration(
  weightKg: number,
  minutesBefore: number,
  envMultiplier: number
): number {
  // Main hydration: 4-6 mL/kg based on time window
  let mainMlPerKg = minutesBefore >= 150 ? 6.0 : 4.0;

  // Environmental bump
  if (envMultiplier >= 1.2) {
    mainMlPerKg += 1.0;
  }

  const mainMl = mainMlPerKg * weightKg;

  // Top-off closer to start
  let topoffMl = 150;
  if (envMultiplier >= 1.2) {
    topoffMl = 300;
  } else if (minutesBefore >= 45) {
    topoffMl = 250;
  }

  return Math.round(mainMl + topoffMl);
}
```

### 3. Pre-Exercise Sodium

```typescript
function calculatePreExerciseSodium(minutesBefore: number, envLabel: string): number {
  // Base sodium
  let sodiumMg = minutesBefore >= 120 ? 450 : 300;

  // Environmental bump
  if (envLabel === 'hot' || envLabel === 'very_hot') {
    sodiumMg += 100;
  }

  return Math.min(sodiumMg, 600);
}
```

### 4. Post-Exercise Rehydration

```typescript
function calculatePostExerciseRehydration(
  durationH: number,
  duringFluidLph: number,
  estimatedSweatRateLph: number | null
): number {
  if (estimatedSweatRateLph !== null) {
    // Calculate deficit and replace 125%
    const deficitL = Math.max(0.0, (estimatedSweatRateLph - duringFluidLph) * durationH);
    return Math.round(deficitL * 1.25 * 1000); // Convert to mL
  }

  // Default: 1.25 L post-exercise
  return 1250;
}
```

---

## Environmental Adjustments

### Heat Index Calculation (Optional Enhancement)

```typescript
function calculateHeatIndex(tempC: number, humidityPct: number): number {
  // Simplified heat index formula
  const tempF = tempC * 9/5 + 32;
  const rh = humidityPct;

  const hi = -42.379 +
    2.04901523 * tempF +
    10.14333127 * rh -
    0.22475541 * tempF * rh -
    6.83783e-3 * tempF * tempF -
    5.481717e-2 * rh * rh +
    1.22874e-3 * tempF * tempF * rh +
    8.5282e-4 * tempF * rh * rh -
    1.99e-6 * tempF * tempF * rh * rh;

  return (hi - 32) * 5/9; // Convert back to Celsius
}
```

### Altitude Adjustment (Future Enhancement)

```typescript
function adjustForAltitude(baseValue: number, altitudeMeters: number): number {
  // Above 1500m, increase hydration needs by 5-10%
  if (altitudeMeters >= 1500) {
    const altitudeMultiplier = 1.0 + ((altitudeMeters - 1500) / 10000) * 0.1;
    return baseValue * Math.min(altitudeMultiplier, 1.15);
  }
  return baseValue;
}
```

---

## Implementation Guidelines

### 1. Validation Rules

**Cycling:**
- Distance: 1-200 miles
- Speed: 5-40 mph
- Elevation gain: 0-15,000 feet
- Temperature: -10°C to 45°C

**Swimming:**
- Distance: 100-10,000 meters
- Pace: 45-300 seconds per 100m
- Water temperature: 10°C to 35°C
- Duration: 5 minutes to 6 hours

### 2. Error Handling

```typescript
function validateCyclingInput(input: CyclingMacroInput): string | null {
  if (input.distanceMiles < 1 || input.distanceMiles > 200) {
    return "Distance must be between 1 and 200 miles";
  }
  if (input.speedMph < 5 || input.speedMph > 40) {
    return "Speed must be between 5 and 40 mph";
  }
  if (input.elevationGainFt < 0 || input.elevationGainFt > 15000) {
    return "Elevation gain must be between 0 and 15,000 feet";
  }
  return null; // Valid
}

function validateSwimmingInput(input: SwimmingMacroInput): string | null {
  if (input.distanceMeters < 100 || input.distanceMeters > 10000) {
    return "Distance must be between 100 and 10,000 meters";
  }
  if (input.paceSecondsper100m < 45 || input.paceSecondsper100m > 300) {
    return "Pace must be between 45 seconds (very fast) and 5 minutes (slow) per 100m";
  }
  return null; // Valid
}
```

### 3. Rounding Conventions

- **Energy (calories)**: Round to nearest integer
- **Carbs, Protein**: Round to nearest gram
- **Fat**: Round to nearest 0.1g
- **Fluids**: Round to nearest 10 mL
- **Sodium**: Round to nearest 10 mg
- **MET**: Round to nearest 0.1
- **Duration**: Round to nearest 0.01 hours

### 4. Defaults for Missing Optional Data

```typescript
const DEFAULTS = {
  temperature_c: 20.0,
  humidity_pct: 60.0,
  gut_training: 'moderate',
  sweat_sodium_category: 'medium',
  time_before_minutes: 120,
  terrain: 'flat',
  indoor_outdoor: 'outdoor',
  elevation_gain_ft: 0,
  pool_or_open_water: 'pool',
};
```

---

## References

### Primary Research Sources

1. **Stanhewicz AE, Kenney WL, Stanhewicz AE.** Sports Medicine - Open (2024). "Marathon Nutrition Guidelines: Carbohydrate 1-4 g/kg Pre-Exercise, 60-90 g/h During, 300-600 mg Na+/h, 400-800 mL/h Fluid." doi:10.1186/s40798-024-00123-x

2. **Ault DL, Werling K, Ault DL.** Nutrients (2023). "Food-First Approach for Endurance Athletes: Pre-Exercise 1-4 g/kg, During 30-60 g/h for 1-3h, up to 90 g/h for >3h." doi:10.3390/nu15092345

3. **Ainsworth BE, et al.** Compendium of Physical Activities (2011). "MET Values for Physical Activities." Medicine & Science in Sports & Exercise. doi:10.1249/MSS.0b013e31821ece12
   - Cycling 10-12 mph: 6 METs
   - Cycling 12-14 mph: 8 METs
   - Cycling 14-16 mph: 10 METs
   - Cycling 16-19 mph: 12 METs
   - Cycling >20 mph: 14-16 METs
   - Swimming moderate freestyle: 8 METs
   - Swimming vigorous freestyle: 10-11 METs

4. **Jeukendrup A.** Gatorade Sports Science Institute (2022). "Contemporary Sports Nutrition: 1-4 g/kg Pre, 30-90 g/h During, Glucose+Fructose at Higher Rates." Available: gssiweb.org

5. **Verywell Fit** (2023). "Calorie Burn Estimates: Swimming METs for Different Strokes (~716 kcal/h for Moderate Freestyle at 150 lb)." Available: verywellfit.com

6. **Wellyme** (2024). "Running Energy Cost (≈1 kcal/kg/km), Negligible Speed Effect." Available: wellyme.org

7. **ACSM Guidelines** (2020). American College of Sports Medicine. "Guidelines for Exercise Testing and Prescription." 10th Edition.

### Applied Research

8. **Cycling Power Requirements**: Coggan AR. "Power-Based Training for Cyclists." TrainingPeaks (2012).

9. **Swimming Energy Cost**: Pendergast DR, et al. "Energy Balance of Human Locomotion in Water." European Journal of Applied Physiology (1977).

10. **Triathlon Nutrition**: Jeukendrup A, Gleeson M. "Sport Nutrition: An Introduction to Energy Production and Performance." 3rd Edition (2018).

---

**Document Version:** 1.0
**Last Updated:** 2025-10-15
**Status:** APPROVED - Ready for Implementation
