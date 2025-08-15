/* Fueling calculator for a single run.
   Formulas:
   - Time: t_h = distance(mi) * pace(min/mi) / 60
   - Distance: km = miles * 1.60934
   - Net kcal (running): ~1 kcal * kg * km  (cost-of-transport)
   - Gross kcal: MET * kg * h
       MET via ACSM running VO₂ (level): VO2 (mL/kg/min) = 0.2 * v + 3.5, with v in m/min
       MET = VO2 / 3.5 = (0.2*v + 3.5)/3.5
       v (m/min) = mph * 26.8224  and  mph = 60 / pace(min/mi)
   - Pre-run carbs:
       if 0.25h ≤ h < 1h: 0.5 g/kg
       if 1h ≤ h ≤ 4h:   h * 1.0 g/kg  (cap at 4 g/kg)
   - During-run carbs (for ~1–2.5 h):
       rate = 0.7–1.0 g/kg/h (gut training) AND clamp to 30–60 g/h
       total = rate * t_h
   - Optional pre protein: 0.2 g/kg
   - Optional pre fat caps: ≤0.1 g/kg if ≤2h; ≤0.2 g/kg if >2h
*/

type Gender = 'female' | 'male' | 'other';
type PaceUnit = 'min_per_mile' | 'min_per_km';
type DistanceUnit = 'mi' | 'km';
type WeightUnit = 'kg' | 'lb';
type HeightUnit = 'cm' | 'in';
type GutTraining = 'low' | 'moderate' | 'high'; // selects 0.7 / 0.8 / 1.0 g·kg⁻¹·h⁻¹

export interface FuelInput {
  age: number;                  // years (used for completeness; not needed for acute fueling)
  gender: Gender;               // not used in acute fueling; included for completeness
  weight: number;
  weightUnit: WeightUnit;
  height: number;
  heightUnit: HeightUnit;
  pace: string | number;        // "M:SS" or number (minutes); default units in paceUnit
  paceUnit?: PaceUnit;          // default "min_per_mile"
  distance: number;
  distanceUnit?: DistanceUnit;  // default "mi"
  timeBeforeRunMin: number;     // minutes available before start
  gutTraining?: GutTraining;    // default "high" (experienced endurance athlete)
}

export interface FuelOutput {
  // Core kinematics
  durationMin: number;
  durationH: number;
  speedMph: number;
  distanceMi: number;
  distanceKm: number;

  // Energy expenditure
  caloriesNetKcal: number;   // ≈ 1 * kg * km
  caloriesGrossKcal: number; // MET * kg * h, MET from ACSM VO2

  // Pre-run macros
  preRun: {
    carbsG: number;            // exact recommendation by time window rule
    carbsRule: string;
    proteinGOptional: number;  // ~0.2 g/kg
    fatGCap: number;           // ≤0.1 g/kg if ≤2h; ≤0.2 g/kg if >2h
  };

  // During-run carbs
  duringRun: {
    rateGh: number;            // recommended rate (g/h)
    totalG: number;            // total carbs = rate * duration
    massNormRateGh: number;    // r_mass = {0.7, 0.8, 1.0} * kg
    absClampRangeGh: [number, number]; // [30, 60]
    massNormTotalRangeG: [number, number]; // [0.7, 1.0]*kg*duration
  };
}

// ---------- Utilities ----------
const LB_TO_KG = 0.45359237;
const IN_TO_CM = 2.54;
const MI_TO_KM = 1.60934;
const MPH_TO_M_PER_MIN = 26.8224;

function toKg(weight: number, unit: WeightUnit): number {
  return unit === 'kg' ? weight : weight * LB_TO_KG;
}
function toCm(height: number, unit: HeightUnit): number {
  return unit === 'cm' ? height : height * IN_TO_CM;
}
function toMiles(distance: number, unit: DistanceUnit = 'mi'): number {
  return unit === 'mi' ? distance : distance / MI_TO_KM;
}
function paceToMinPerMile(pace: string | number, paceUnit: PaceUnit = 'min_per_mile'): number {
  const minutes = (v: string | number): number => {
    if (typeof v === 'number') return v;
    const parts = v.split(':').map(s => s.trim());
    if (parts.length === 1) return parseFloat(parts[0]);
    const mm = parseFloat(parts[0]);
    const ss = parseFloat(parts[1]);
    return mm + (isNaN(ss) ? 0 : ss / 60);
  };
  const p = minutes(pace);
  return paceUnit === 'min_per_mile' ? p : p * MI_TO_KM; // convert min/km → min/mi
}

// ACSM running equation (level): VO2 = 0.2*v + 3.5  with v in m/min; MET = VO2/3.5
function metFromPaceMinPerMile(paceMinPerMile: number): number {
  const mph = 60 / paceMinPerMile;
  const v_m_per_min = mph * MPH_TO_M_PER_MIN;
  const VO2 = 0.2 * v_m_per_min + 3.5; // mL/kg/min
  return VO2 / 3.5; // MET
}

function clamp(x: number, lo: number, hi: number) {
  return Math.max(lo, Math.min(hi, x));
}

function gutRate(gut: GutTraining = 'high'): number {
  // g·kg⁻¹·h⁻¹
  if (gut === 'low') return 0.7;
  if (gut === 'moderate') return 0.8;
  return 1.0; // 'high'
}

// ---------- Main ----------
export function computeRunFueling(input: FuelInput): FuelOutput {
  const {
    age, gender,
    weight, weightUnit,
    height, heightUnit,
    pace, paceUnit = 'min_per_mile',
    distance, distanceUnit = 'mi',
    timeBeforeRunMin,
    gutTraining = 'high',
  } = input;

  const weightKg = toKg(weight, weightUnit);
  const _heightCm = toCm(height, heightUnit); // not used in acute fueling but kept for completeness
  const distanceMi = toMiles(distance, distanceUnit);
  const paceMinPerMile = paceToMinPerMile(pace, paceUnit);
  const durationMin = distanceMi * paceMinPerMile;
  const durationH = durationMin / 60;
  const speedMph = 60 / paceMinPerMile;
  const distanceKm = distanceMi * MI_TO_KM;

  // Energy expenditure
  const caloriesNetKcal = weightKg * distanceKm; // ~1 kcal·kg⁻¹·km⁻¹
  const MET = metFromPaceMinPerMile(paceMinPerMile);
  const caloriesGrossKcal = MET * weightKg * durationH;

  // Pre-run carbs
  const hAvail = Math.max(0, timeBeforeRunMin / 60);
  let preCarbsG = 0;
  let preRule = '';
  if (hAvail >= 1) {
    const hClamped = Math.min(4, hAvail);
    preCarbsG = hClamped * 1.0 * weightKg;
    preRule = `${hClamped.toFixed(2)} h × 1 g/kg`;
  } else if (hAvail >= 0.25) {
    preCarbsG = 0.5 * weightKg;
    preRule = `0.5 g/kg (15–60 min window)`;
  } else {
    // <15 min: tiny top-up is all that's realistic
    preCarbsG = Math.round(0.25 * weightKg); // small nibble guideline
    preRule = `<15 min → small top-up (≈0.25 g/kg)`;
  }
  const preProteinGOpt = 0.2 * weightKg;
  const fatCap = (hAvail > 2 ? 0.2 : 0.1) * weightKg;

  // During-run carbs
  const rateMassNorm = gutRate(gutTraining) * weightKg;      // g/h from body-mass rule
  const rateAbsClamped = clamp(rateMassNorm, 30, 60);        // g/h, for ~1–2.5 h sessions
  const totalDuringG = rateAbsClamped * durationH;
  const massNormTotalMin = 0.7 * weightKg * durationH;
  const massNormTotalMax = 1.0 * weightKg * durationH;

  return {
    durationMin: +durationMin.toFixed(2),
    durationH: +durationH.toFixed(4),
    speedMph: +speedMph.toFixed(3),
    distanceMi: +distanceMi.toFixed(3),
    distanceKm: +distanceKm.toFixed(3),

    caloriesNetKcal: +caloriesNetKcal.toFixed(0),
    caloriesGrossKcal: +caloriesGrossKcal.toFixed(0),

    preRun: {
      carbsG: +preCarbsG.toFixed(0),
      carbsRule: preRule,
      proteinGOptional: +preProteinGOpt.toFixed(0),
      fatGCap: +fatCap.toFixed(1),
    },

    duringRun: {
      rateGh: +rateAbsClamped.toFixed(1),
      totalG: +totalDuringG.toFixed(0),
      massNormRateGh: +rateMassNorm.toFixed(1),
      absClampRangeGh: [30, 60],
      massNormTotalRangeG: [
        +massNormTotalMin.toFixed(0),
        +massNormTotalMax.toFixed(0),
      ],
    },
  };
}

// ---------- Example usage (your exact case) ----------
/*
const out = computeRunFueling({
  age: 43,
  gender: 'female',
  weight: 48,        // kg
  weightUnit: 'kg',
  height: 157,       // cm
  heightUnit: 'cm',
  pace: '9:15',      // min/mi
  paceUnit: 'min_per_mile',
  distance: 10,      // miles
  distanceUnit: 'mi',
  timeBeforeRunMin: 120,  // 2 hours before start
  gutTraining: 'high',    // you're an experienced endurance athlete
});

console.log(out);

Expected (approx):
{
  durationMin: 92.5,
  durationH: 1.5417,
  speedMph: 6.486,
  distanceMi: 10.000,
  distanceKm: 16.093,
  caloriesNetKcal: 772,
  caloriesGrossKcal: ~810,
  preRun: {
    carbsG: 96,            // 2 h × 1 g/kg × 48 kg
    carbsRule: "2.00 h × 1 g/kg",
    proteinGOptional: 10,  // 0.2 g/kg × 48
    fatGCap: 4.8           // ≤0.1 g/kg (≤2 h window)
  },
  duringRun: {
    rateGh: 48.0,          // 1.0 g/kg/h × 48 kg, clamped to [30,60]
    totalG: 74,            // 48 g/h × 1.5417 h
    massNormRateGh: 48.0,
    absClampRangeGh: [30, 60],
    massNormTotalRangeG: [52, 74]
  }
}
*/