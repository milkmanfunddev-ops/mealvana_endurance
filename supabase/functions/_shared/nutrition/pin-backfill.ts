/**
 * Pinned-formula fluid + sodium backfill (failsafe).
 *
 * Pinned personal formulas are honored by early-returning their components
 * scaled to the phase carb target — which bypasses the solvers' hydration
 * (water) and electrolyte (sodium) fill steps entirely. A formula authored
 * around fuel (gels, chews, mix) can therefore land well under the phase's
 * fluid/sodium targets and nothing corrects it.
 *
 * This module is that correction, applied in ALL phases (before per-slot,
 * during, after) after a pinned formula renders:
 *
 *   1. Sodium first: top up an existing carb-free sodium component if the
 *      formula has one (preserves the user's own electrolyte choice), else
 *      append the best essential/electrolyte food from [backfillPool].
 *      Capped at 110% of target (matches the solver bands).
 *   2. Fluid second (so fluid carried by step 1 counts): top up an existing
 *      plain-water component if present, else append essential water.
 *      Quantities round UP in 0.5-serving steps — the plan must never come
 *      in under the fluid target because of rounding.
 *
 * Carbs are never touched: only zero-carb items are bumped/added, so the
 * carb scaling done by `personal-formula-pins.ts` is preserved exactly.
 *
 * Callers fetch the pool via `getEssentialFoods` (water + salt,
 * `foods.is_essential = true`) only when [fluidSodiumDeficits] reports a
 * shortfall, keeping the pin path lookup-free in the common case.
 *
 * Mirrored (bump-existing parts) in Flutter by
 * `client_plan_service.dart#_backfillPinnedFluidsAndSodium` — keep in sync.
 */

import type { Food, FoodResult } from "./types.ts";
import { buildFoodResult } from "./during-utils.ts";

/** Ignore deficits smaller than these — avoids churn on formulas that are
 * already effectively at target. */
const FLUID_EPSILON_ML = 25;
const SODIUM_EPSILON_MG = 20;

/** Sodium additions never push the total past this share of target. */
const SODIUM_CAP_RATIO = 1.1;

export interface FluidSodiumDeficits {
  fluidMl: number;
  sodiumMg: number;
  needsBackfill: boolean;
}

function totalsOf(foods: FoodResult[]): { fluidMl: number; sodiumMg: number } {
  let fluidMl = 0;
  let sodiumMg = 0;
  for (const f of foods) {
    fluidMl += f.fluids_ml || 0;
    sodiumMg += f.sodium_mg || 0;
  }
  return { fluidMl, sodiumMg };
}

/**
 * How far [foods] falls short of the phase fluid/sodium targets.
 * Zero/missing targets never report a deficit.
 */
export function fluidSodiumDeficits(
  foods: FoodResult[],
  targets: { water_ml: number; sodium_mg: number },
): FluidSodiumDeficits {
  const totals = totalsOf(foods);
  const fluidMl = targets.water_ml > 0
    ? Math.max(0, targets.water_ml - totals.fluidMl)
    : 0;
  const sodiumMg = targets.sodium_mg > 0
    ? Math.max(0, targets.sodium_mg - totals.sodiumMg)
    : 0;
  return {
    fluidMl,
    sodiumMg,
    needsBackfill: fluidMl > FLUID_EPSILON_ML || sodiumMg > SODIUM_EPSILON_MG,
  };
}

/** Round servings UP to the next 0.5 step (never under-deliver). */
function ceilHalf(v: number): number {
  return Math.ceil(v * 2) / 2;
}

/**
 * RULED food-recommendation §4.5 (Xuan, 2026-09-03): the sodium backfill
 * essential prefers an electrolyte capsule/tablet; a salt packet is the LAST
 * resort. Within a class, higher sodium density (mg per ml carried) still
 * wins — the pre-ruling order. Dart twin:
 * `client_plan_service.dart#_backfillPinnedFluidsAndSodium` (§8 contract).
 */
export function sortSodiumBackfillCandidates(pool: Food[]): Food[] {
  const isSaltPacket = (f: Food): boolean =>
    (f.name ?? "").toLowerCase().includes("salt") ||
    (f.display_name ?? "").toLowerCase().includes("salt");
  const density = (f: Food): number =>
    f.per_serving.sodium_mg / Math.max(1, f.per_serving.water_ml);
  return [...pool].sort((a, b) => {
    const saltRank = (isSaltPacket(a) ? 1 : 0) - (isSaltPacket(b) ? 1 : 0);
    if (saltRank !== 0) return saltRank;
    return density(b) - density(a);
  });
}

/** Re-derive a FoodResult's per-serving macros from its totals. */
function perServing(f: FoodResult): {
  carbs: number;
  sodium: number;
  fluid: number;
} {
  const q = Math.max(f.quantity || 1, 0.0001);
  return {
    carbs: (f.carbs_grams || 0) / q,
    sodium: (f.sodium_mg || 0) / q,
    fluid: (f.fluids_ml || 0) / q,
  };
}

/** Scale every total on [f] to [nextQuantity], preserving per-serving macros. */
function withQuantity(f: FoodResult, nextQuantity: number): FoodResult {
  const q = Math.max(f.quantity || 1, 0.0001);
  const k = nextQuantity / q;
  const r1 = (v: number) => Math.round(v * 10) / 10;
  return {
    ...f,
    quantity: nextQuantity,
    carbs_grams: r1((f.carbs_grams || 0) * k),
    protein_grams: r1((f.protein_grams || 0) * k),
    fat_grams: r1((f.fat_grams || 0) * k),
    sodium_mg: Math.round((f.sodium_mg || 0) * k),
    fluids_ml: Math.round((f.fluids_ml || 0) * k),
    calories: Math.round((f.calories || 0) * k),
  };
}

/**
 * Backfill [foods] up to the phase fluid/sodium targets. Returns a new array
 * (input not mutated). [backfillPool] is the essential-foods pool from
 * `getEssentialFoods` — pass [] when unavailable and only existing-component
 * top-ups will run.
 */
export function backfillPinnedFluidsAndSodium(
  foods: FoodResult[],
  targets: { water_ml: number; sodium_mg: number },
  backfillPool: Food[],
  timing: string,
  logPrefix: string,
): FoodResult[] {
  let out = [...foods];

  // ---- 1. Sodium ----
  const sodiumDeficit = fluidSodiumDeficits(out, targets).sodiumMg;
  if (sodiumDeficit > SODIUM_EPSILON_MG) {
    const sodiumCap = targets.sodium_mg * SODIUM_CAP_RATIO;

    // Prefer topping up the formula's own carb-free sodium source.
    let bestIdx = -1;
    let bestSodiumPerServing = 0;
    for (let i = 0; i < out.length; i++) {
      const ps = perServing(out[i]);
      if (ps.carbs > 0 || ps.sodium <= 0) continue;
      if (ps.sodium > bestSodiumPerServing) {
        bestSodiumPerServing = ps.sodium;
        bestIdx = i;
      }
    }

    if (bestIdx >= 0) {
      const item = out[bestIdx];
      const ps = perServing(item);
      const step = item.is_indivisible === false ? 0.5 : 1;
      const currentSodium = totalsOf(out).sodiumMg;
      const wanted = Math.ceil(sodiumDeficit / ps.sodium / step) * step;
      const maxForCap = Math.floor(
        (sodiumCap - currentSodium) / ps.sodium / step,
      ) * step;
      const additional = Math.min(wanted, Math.max(0, maxForCap));
      if (additional > 0) {
        out[bestIdx] = withQuantity(item, item.quantity + additional);
        console.log(
          `${logPrefix} sodium backfill: +${additional}x existing "` +
            `${item.display_name ?? item.food_id}" ` +
            `(+${Math.round(ps.sodium * additional)}mg)`,
        );
      }
    } else {
      // No carb-free sodium component — append from the essential pool,
      // ranked by the ruled §4.5 preference.
      const candidates = sortSodiumBackfillCandidates(
        backfillPool.filter((f) =>
          f.per_serving.sodium_mg > 0 && f.per_serving.carbs_g <= 0
        ),
      );
      const best = candidates[0];
      if (best) {
        const currentSodium = totalsOf(out).sodiumMg;
        const step = best.is_indivisible === false ? 0.5 : 1;
        const wanted = Math.ceil(
          sodiumDeficit / best.per_serving.sodium_mg / step,
        ) * step;
        const maxForCap = Math.floor(
          (sodiumCap - currentSodium) / best.per_serving.sodium_mg / step,
        ) * step;
        const servings = Math.min(
          wanted,
          Math.max(0, maxForCap),
          best.max_servings,
        );
        if (servings > 0) {
          out.push({ ...buildFoodResult(best, servings), timing });
          console.log(
            `${logPrefix} sodium backfill: adding ${servings}x "` +
              `${best.display_name ?? best.name}" ` +
              `(+${Math.round(best.per_serving.sodium_mg * servings)}mg)`,
          );
        }
      } else {
        console.log(
          `${logPrefix} sodium backfill: ${Math.round(sodiumDeficit)}mg ` +
            `short but no carb-free sodium source available`,
        );
      }
    }
  }

  // ---- 2. Fluid (after sodium, so fluid carried by electrolytes counts) ----
  const fluidDeficit = fluidSodiumDeficits(out, targets).fluidMl;
  if (fluidDeficit > FLUID_EPSILON_ML) {
    // Prefer topping up the formula's own plain-water component.
    let waterIdx = -1;
    let waterPerServing = 0;
    for (let i = 0; i < out.length; i++) {
      const ps = perServing(out[i]);
      if (ps.fluid <= 0 || ps.carbs > 0 || ps.sodium > 0) continue;
      if (ps.fluid > waterPerServing) {
        waterPerServing = ps.fluid;
        waterIdx = i;
      }
    }

    if (waterIdx >= 0) {
      const item = out[waterIdx];
      // Round UP: the user must never end up under the fluid target because
      // a quantity rounded down (e.g. 4 cups recommended where 5 fit).
      const additional = ceilHalf(fluidDeficit / waterPerServing);
      out[waterIdx] = withQuantity(item, item.quantity + additional);
      console.log(
        `${logPrefix} fluid backfill: +${additional}x existing "` +
          `${item.display_name ?? item.food_id}" ` +
          `(+${Math.round(waterPerServing * additional)}ml)`,
      );
    } else {
      const water = backfillPool
        .filter((f) =>
          f.per_serving.water_ml > 0 &&
          f.per_serving.carbs_g <= 0 &&
          f.per_serving.sodium_mg <= 0
        )
        .sort((a, b) => b.per_serving.water_ml - a.per_serving.water_ml)[0];
      if (water) {
        const servings = Math.min(
          ceilHalf(fluidDeficit / water.per_serving.water_ml),
          water.max_servings,
        );
        out.push({ ...buildFoodResult(water, servings), timing });
        console.log(
          `${logPrefix} fluid backfill: adding ${servings}x "` +
            `${water.display_name ?? water.name}" ` +
            `(+${Math.round(water.per_serving.water_ml * servings)}ml)`,
        );
      } else {
        console.log(
          `${logPrefix} fluid backfill: ${Math.round(fluidDeficit)}ml short ` +
            `but no plain-water source available`,
        );
      }
    }
  }

  return out;
}
