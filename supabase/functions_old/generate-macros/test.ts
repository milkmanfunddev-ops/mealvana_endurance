// Simple test to verify TypeScript calculations match Python implementation
// Run with: deno run test.ts

// Copy the algorithm functions from index.ts
type Gender = "female" | "male" | "other";
type PaceUnit = "min_per_mile" | "min_per_km";
type DistanceUnit = "mi" | "km";
type WeightUnit = "kg" | "lb";
type HeightUnit = "cm" | "in";
type GutTraining = "low" | "moderate" | "high";

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
}

const LB_TO_KG = 0.45359237;
const IN_TO_CM = 2.54;
const MI_TO_KM = 1.60934;
const MPH_TO_M_PER_MIN = 26.8224;

function toKg(weight: number, unit: WeightUnit): number {
  return unit === "kg" ? weight : weight * LB_TO_KG;
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

function metFromPaceMinPerMile(paceMinPerMile: number): number {
  const mph = 60.0 / paceMinPerMile;
  const vMPerMin = mph * MPH_TO_M_PER_MIN;
  const VO2 = 0.2 * vMPerMin + 3.5;
  return VO2 / 3.5;
}

function clamp(x: number, lo: number, hi: number): number {
  return Math.max(lo, Math.min(hi, x));
}

function gutRate(gut: GutTraining = "high"): number {
  const rates = { "low": 0.7, "moderate": 0.8, "high": 1.0 };
  return rates[gut];
}

// Test with same parameters as Python script
const testParams: MacrosRequest = {
  age: 30,
  gender: "female",
  weight: 60,
  weight_unit: "kg",
  height: 165,
  height_unit: "cm",
  run_pace: "8:00",
  run_pace_unit: "min_per_mile",
  run_distance: 10,
  run_distance_unit: "mi",
  time_before_run_min: 120.0,
  gut_training: "high"
};

// Calculate key values
const weightKg = toKg(testParams.weight, testParams.weight_unit);
const distanceMi = toMiles(testParams.run_distance, testParams.run_distance_unit || "mi");
const paceMinPerMile = parsePaceToMinPerMile(testParams.run_pace, testParams.run_pace_unit || "min_per_mile");
const durationMin = distanceMi * paceMinPerMile;
const durationH = durationMin / 60.0;
const distanceKm = distanceMi * MI_TO_KM;
const MET = metFromPaceMinPerMile(paceMinPerMile);

// Post-run calculations
const postCarbsG = clamp(Math.round(weightKg * 1.0), 30, 140);
const postProteinG = clamp(Math.round(weightKg * 0.3), 18, 45);

console.log("TypeScript Calculation Results:");
console.log(`Weight: ${weightKg} kg`);
console.log(`Distance: ${distanceMi} mi (${distanceKm.toFixed(1)} km)`);
console.log(`Pace: ${paceMinPerMile} min/mile`);
console.log(`Duration: ${durationMin.toFixed(1)} min (${durationH.toFixed(2)} h)`);
console.log(`MET: ${MET.toFixed(2)}`);
console.log("");
console.log("Post-run nutrition:");
console.log(`  Carbs: ${postCarbsG}g (expected: 60g from Python)`);
console.log(`  Protein: ${postProteinG}g (expected: 18g from Python)`);

// Expected output from Python:
// Post-run recovery nutrition:
//   Carbs: 60g
//   Protein: 18g
//   Water: 625ml
//   Sodium: 500mg