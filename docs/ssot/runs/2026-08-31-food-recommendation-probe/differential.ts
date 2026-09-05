// Differential: REAL server pickBestElectrolyte (imported) vs faithful port of
// client_during_phase_solver.dart _pickBestElectrolyte (transcribed from develop @ d72d43c9).
import { pickBestElectrolyte } from "/Users/sunshine/Development/mealvana_endurance/.qa-probe-develop/supabase/functions/_shared/nutrition/during-utils.ts";

// ---- Dart port (faithful transcription; gutLevel moderate => multiplier 1.0) ----
function dartPick(pool: any[], currentSodium: number, currentFluid: number, currentCarbs: number, b: any) {
  const { sodiumTarget, sodiumLower, sodiumUpper, fluidTarget, fluidUpper, carbTarget, carbUpper } = b;
  const baselineSodiumScore = sodiumTarget > 0
    ? (Math.max(0, sodiumTarget - currentSodium) + Math.max(0, currentSodium - sodiumUpper)) / sodiumTarget : 0; // NOTE: no *2 (Dart)
  const baselineFluidPenalty = fluidTarget > 0 && currentFluid > fluidUpper ? ((currentFluid - fluidUpper) / fluidTarget) * 3 : 0;
  const baselineCarbPenalty = carbTarget > 0 && currentCarbs > carbUpper ? ((currentCarbs - carbUpper) / carbTarget) * 2 : 0;
  const baselineScore = baselineSodiumScore + baselineFluidPenalty + baselineCarbPenalty;
  let best: any = null;
  for (const e of pool) {
    if (e.per_serving.sodium_mg <= 0) continue;
    const isSupp = e.product_type === 'supplement' && !e.is_liquid;
    const step = e.is_indivisible ? 1 : 0.5;
    const start = e.is_indivisible ? 1 : 0.5;
    const maxCand = e.max_servings; // gut multiplier 1.0 (moderate); NO supplement 4-cap (Dart removed it)
    for (let s = start; s <= maxCand + 1e-9; s += step) {
      const sodium = currentSodium + e.per_serving.sodium_mg * s;
      const fluid = currentFluid + e.per_serving.water_ml * s;
      const carbs = currentCarbs + e.per_serving.carbs_g * s;
      if (sodium > sodiumUpper + 1e-9) continue;
      if (fluid > fluidUpper + 1e-9) continue;
      if (carbs > carbUpper + 1e-9) continue;
      const sodiumPenalty = sodiumTarget > 0
        ? (Math.max(0, sodiumTarget - sodium) + Math.max(0, sodium - sodiumUpper) * 2) / sodiumTarget : 0;
      const fluidPenalty = fluidTarget > 0 && fluid > fluidUpper ? ((fluid - fluidUpper) / fluidTarget) * 3 : 0;
      const carbPenalty = carbTarget > 0 && carbs > carbUpper ? ((carbs - carbUpper) / carbTarget) * 1.5 : 0;
      const capsulePenalty = isSupp && s > 2 ? 0.05 * (s - 2) : 0;
      const prefBonus = (e.preference_score ?? 0) >= 2 ? -0.02 : 0;
      const score = sodiumPenalty + fluidPenalty + carbPenalty + capsulePenalty + prefBonus;
      if (best === null || score < best.score - 1e-9 ||
          (Math.abs(score - best.score) < 1e-9 && Math.abs(sodiumTarget - sodium) < Math.abs(sodiumTarget - best.sodium))) {
        best = { food: e, servings: s, score, sodium };
      }
    }
  }
  if (!best) return null;
  if (best.sodium >= sodiumLower) return best;              // Dart: unconditional floor acceptance
  return best.score < baselineScore ? best : null;
}

const capsule = (over: any = {}) => ({
  id: 'cap', name: 'electrolyte_capsule', product_type: 'supplement', is_liquid: false,
  is_indivisible: true, is_electrolyte: true, min_servings: 1, max_servings: 8,
  preference_score: 0, per_serving: { sodium_mg: 190, water_ml: 0, carbs_g: 0, protein_g: 0, fat_g: 0 }, ...over });

function run(name: string, pool: any[], cur: [number, number, number], b: any) {
  const ts = pickBestElectrolyte(pool as any, cur[0], cur[1], cur[2], b);
  const dt = dartPick(pool, cur[0], cur[1], cur[2], b);
  const fmt = (p: any) => p ? `${p.food?.name ?? p.template?.name} x${p.servings} → ${(p.sodium ?? (cur[0] + p.food.per_serving.sodium_mg * p.servings)).toFixed(0)}mg` : 'ADD NOTHING';
  const agree = JSON.stringify([ts?.servings ?? null]) === JSON.stringify([dt?.servings ?? null]);
  console.log(`${agree ? 'AGREE  ' : 'DIVERGE'} | ${name}\n         server: ${fmt(ts)}\n         dart:   ${fmt(dt)}`);
}

// F-22: cap divergence. Target needs 8 capsules; server caps at 4.
run('F-22 cap: target 1520mg, capsule 190mg x8 allowed',
  [capsule()], [0, 0, 0],
  { sodiumTarget: 1520, sodiumLower: 1368, sodiumUpper: 1672, fluidTarget: 1000, fluidUpper: 1100, carbTarget: 60, carbUpper: 66 });

// F-46: floor-rescue gate. In-range start; only score-worsening picks exist.
run('F-46 floor-rescue: in-range 2000mg (floor 1900), only worsening 30mg-capsule min3 picks',
  [capsule({ per_serving: { sodium_mg: 30, water_ml: 0, carbs_g: 0, protein_g: 0, fat_g: 0 }, min_servings: 3, max_servings: 4 })],
  [2000, 500, 40],
  { sodiumTarget: 2400, sodiumLower: 1900, sodiumUpper: 2640, fluidTarget: 1000, fluidUpper: 1100, carbTarget: 60, carbUpper: 66 });
