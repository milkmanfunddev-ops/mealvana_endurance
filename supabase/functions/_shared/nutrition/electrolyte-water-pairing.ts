/**
 * Electrolyte ↔ water pairing invariant (post-selection pass).
 *
 * Product rule (Lee, 2026-07-29): **an electrolyte mix / tablet / sodium
 * supplement must never be recommended on its own — it always goes with
 * water.**
 *
 * Why this is a separate pass rather than a solver constraint: fluid is a
 * single pooled target in every solver (LP, rule-based during, greedy
 * fallback, template solvers). Each of them satisfies "total fluid is inside
 * the band", which is *not* the same thing as "this electrolyte item has a
 * drink next to it". When the fluid target happens to already be covered by
 * other picks (whole-food water from fruit/yogurt, an earlier gel, etc.), a
 * dry electrolyte supplement (`water_ml = 0`) can be appended alone and every
 * solver considers that a valid plan. Encoding the pairing as a per-solver
 * constraint would mean four separate implementations that drift; encoding it
 * as one idempotent pass over the finished item list gives one definition and
 * one place to change it.
 *
 * Mirrored in Flutter by
 * `lib/features/nutrition_plan/application/client_plan/electrolyte_water_pairing.dart`
 * — keep the two in sync (the client fallback solver must not disagree with
 * the edge function about what a valid plan looks like).
 *
 * ── How an "electrolyte item" is identified ────────────────────────────────
 * Off DATA MODEL FLAGS, never display names:
 *   • `is_electrolyte === true`      — the `template_foods`/`foods` column
 *   • `product_type === 'supplement'` carrying sodium — matches the
 *     `isElectrolyteSupplement` definition already used by `lp-solver.ts`
 *     and `deriveTimingCategory()` in `types.ts`
 *   • `timing_category === 'electrolyte'` — the derived category, which is
 *     itself computed from the two flags above
 * An electrolyte item is **unpaired** only when it delivers essentially no
 * fluid of its own (`fluids_ml <= PLAIN_FLUID_EPSILON_ML`). A drink mix that
 * already carries its 500ml is self-satisfying and is left alone — this is
 * what keeps the pass from double-counting fluid.
 *
 * ── What satisfies the pairing ─────────────────────────────────────────────
 * Any item in the same phase that is a DRINKABLE fluid (`is_liquid`/`is_drink`)
 * delivering > `PLAIN_FLUID_EPSILON_ML`. Water content locked inside solid
 * food (a banana's 88ml) deliberately does NOT count: you cannot wash a salt
 * tablet down with a banana.
 *
 * ── Fluid ceiling ─────────────────────────────────────────────────────────
 * The pass never overshoots the phase's fluid ceiling to satisfy the pairing.
 * In order: fill from the available headroom → free headroom by trimming a
 * zero-carb fluid carrier → give up and report an honest conflict. It never
 * silently pushes the phase over `water_high_ml`.
 *
 * ── Idempotency ───────────────────────────────────────────────────────────
 * The water item this pass appends is itself a drinkable fluid carrier, so a
 * second run sees the pairing already satisfied and is a no-op. Running the
 * pass N times === running it once.
 */

import type { Food, FoodResult } from "./types.ts";
import { buildFoodResult } from "./during-utils.ts";

/** Fluid below this is treated as "carries no fluid of its own" (ml). */
export const PLAIN_FLUID_EPSILON_ML = 15;

/** How much water we want alongside an otherwise-dry electrolyte item (ml).
 * ~8oz — the conventional "take this with a glass of water" dose. */
export const DEFAULT_PAIRING_VOLUME_ML = 250;

/** Never pair with less than this, or the recommendation is meaningless. */
const MIN_PAIRING_VOLUME_ML = 100;

export type ElectrolytePairingConflictReason =
  /** A water source existed but adding any usable amount would breach the
   * phase fluid ceiling, and no fluid could be freed by trimming. */
  | "fluid_ceiling"
  /** No plain-water candidate was available in the supplied pool. */
  | "no_water_source";

export interface ElectrolytePairingConflict {
  reason: ElectrolytePairingConflictReason;
  /** The unpaired electrolyte items that triggered the pass. */
  electrolyte_food_ids: string[];
  current_fluid_ml: number;
  fluid_ceiling_ml: number | null;
  /** Millilitres of water we wanted to add but could not. */
  wanted_ml: number;
}

export interface ElectrolytePairingOptions {
  /** Phase fluid ceiling (`water_high_ml`). Omit/undefined for no ceiling. */
  fluidCeilingMl?: number | null;
  /** Water volume to pair with. Defaults to [DEFAULT_PAIRING_VOLUME_ML]. */
  pairingVolumeMl?: number;
  /** `timing` label stamped on an appended water item. */
  timing: string;
  /** Log prefix, e.g. `[PLAN-V3] Before top_up`. */
  logPrefix: string;
}

export interface ElectrolytePairingResult {
  /** The corrected item list (new array; input is never mutated). */
  foods: FoodResult[];
  /** True when a water item was appended (or an existing one grown). */
  changed: boolean;
  /** Non-null when the invariant could NOT be enforced. */
  conflict: ElectrolytePairingConflict | null;
}

// ---------------------------------------------------------------------------
// Predicates (exported — callers use these to skip work / assert in tests)
// ---------------------------------------------------------------------------

/**
 * Is this an electrolyte / sodium-supplement item, per the data model flags?
 * Deliberately never inspects display names.
 */
export function isElectrolyteItem(f: FoodResult): boolean {
  if (f.is_electrolyte === true) return true;
  if (f.timing_category === "electrolyte") return true;
  // A `supplement` carrying sodium is an electrolyte source even when the
  // `is_electrolyte` flag was never set on the row (matches lp-solver.ts).
  if (f.product_type === "supplement" && (f.sodium_mg || 0) > 0) return true;
  return false;
}

/**
 * Does this item deliver drinkable fluid? Water bound up in solid food does
 * not count — the athlete cannot take a tablet with a banana.
 */
export function deliversDrinkableFluid(f: FoodResult): boolean {
  const isDrinkable = f.is_liquid === true || f.is_drink === true;
  return isDrinkable && (f.fluids_ml || 0) > PLAIN_FLUID_EPSILON_ML;
}

/**
 * C2 (docs/ssot/spec/domain/catalog-conventions.md, RULED Xuan 2026-09-01):
 * the pairing invariant covers every DRY item that requires water to
 * consume, not only electrolyte-flagged ones — the C1 zero-fluid set
 * includes carb drink mixes (nobody chews drink mix). No `requires_water`
 * column exists; per the handback the derivation is app-side: an
 * electrolyte item, or any drink-shaped product (`drink_mix`,
 * `sports_drink`, `beverage`, or a liquid-flagged row) whose consumed state
 * is dry. Twin: `_requiresWaterWhenDry` in electrolyte_water_pairing.dart.
 */
export function requiresWaterWhenDry(f: FoodResult): boolean {
  if (isElectrolyteItem(f)) return true;
  if (f.is_liquid === true || f.is_drink === true) return true;
  return f.product_type === "drink_mix" ||
    f.product_type === "sports_drink" ||
    f.product_type === "beverage";
}

/**
 * Requires-water items that carry essentially no fluid of their own (C2 —
 * name kept from the electrolyte-only era; scope is the full dry
 * requires-water set since catalog-conventions v1).
 */
export function unpairedElectrolyteItems(foods: FoodResult[]): FoodResult[] {
  return foods.filter(
    (f) =>
      requiresWaterWhenDry(f) &&
      (f.fluids_ml || 0) <= PLAIN_FLUID_EPSILON_ML,
  );
}

/**
 * Cheap check so callers can avoid fetching a water pool when nothing is
 * wrong (mirrors the lazy `fluidSodiumDeficits` gate in `pin-backfill.ts`).
 */
export function needsWaterPairing(foods: FoodResult[]): boolean {
  if (unpairedElectrolyteItems(foods).length === 0) return false;
  return !foods.some(deliversDrinkableFluid);
}

// ---------------------------------------------------------------------------
// Internals
// ---------------------------------------------------------------------------

function totalFluidMl(foods: FoodResult[]): number {
  return foods.reduce((sum, f) => sum + (f.fluids_ml || 0), 0);
}

/** Round servings UP to the next 0.5 step. */
function ceilHalf(v: number): number {
  return Math.ceil(v * 2) / 2;
}

/** Round servings DOWN to the previous 0.5 step. */
function floorHalf(v: number): number {
  return Math.floor(v * 2) / 2;
}

/** Re-derive a FoodResult's per-serving fluid/carbs from its totals. */
function perServing(f: FoodResult): { fluid: number; carbs: number } {
  const q = Math.max(f.quantity || 1, 0.0001);
  return {
    fluid: (f.fluids_ml || 0) / q,
    carbs: (f.carbs_grams || 0) / q,
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
 * Best plain-water candidate in [pool]: fluid-bearing, no carbs, no sodium.
 * Same filter `pin-backfill.ts` uses for its fluid backfill, so both passes
 * reach for the same "water" row.
 */
function pickWaterSource(pool: Food[]): Food | undefined {
  return pool
    .filter((f) =>
      f.per_serving.water_ml > PLAIN_FLUID_EPSILON_ML &&
      f.per_serving.carbs_g <= 0 &&
      f.per_serving.sodium_mg <= 0
    )
    .sort((a, b) => b.per_serving.water_ml - a.per_serving.water_ml)[0];
}

/**
 * Build the appended water item.
 *
 * `getEssentialFoods()` hardcodes `is_liquid: false` on the legacy `foods`
 * rows (water included), so the flags are forced on here. Without this the
 * appended item would not read as a drinkable fluid and the pass would append
 * water again on the next run — i.e. this is what makes it idempotent.
 */
function buildWaterResult(
  water: Food,
  servings: number,
  timing: string,
): FoodResult {
  return {
    ...buildFoodResult(water, servings),
    timing,
    is_liquid: true,
    is_drink: true,
    timing_category: "sip_throughout",
  };
}

// ---------------------------------------------------------------------------
// The pass
// ---------------------------------------------------------------------------

/**
 * Enforce "electrolyte always goes with water" over one phase's finished
 * item list. Returns a corrected list; the input array is not mutated.
 *
 * [waterPool] is a food pool to source water from — typically the result of
 * `getEssentialFoods()` (server) or the phase's own solver pool. Pass `[]`
 * when unavailable; the pass then reports a `no_water_source` conflict rather
 * than inventing a food.
 */
export function ensureElectrolyteWaterPairing(
  foods: FoodResult[],
  waterPool: Food[],
  options: ElectrolytePairingOptions,
): ElectrolytePairingResult {
  const unpaired = unpairedElectrolyteItems(foods);
  const noop: ElectrolytePairingResult = {
    foods: [...foods],
    changed: false,
    conflict: null,
  };

  // Nothing dry to pair, or a drink is already on the plate.
  if (unpaired.length === 0) return noop;
  if (foods.some(deliversDrinkableFluid)) return noop;

  const { timing, logPrefix } = options;
  const electrolyteIds = unpaired.map((f) => f.food_id);
  const wantedMl = Math.max(
    MIN_PAIRING_VOLUME_ML,
    options.pairingVolumeMl ?? DEFAULT_PAIRING_VOLUME_ML,
  );
  const ceiling =
    options.fluidCeilingMl != null && Number.isFinite(options.fluidCeilingMl) &&
      options.fluidCeilingMl > 0
      ? options.fluidCeilingMl
      : null;

  const water = pickWaterSource(waterPool);
  if (!water) {
    console.warn(
      `${logPrefix} electrolyte pairing: ${unpaired.length} dry electrolyte ` +
        `item(s) with no drink alongside, but no plain-water source in pool ` +
        `— leaving unpaired`,
    );
    return {
      ...noop,
      conflict: {
        reason: "no_water_source",
        electrolyte_food_ids: electrolyteIds,
        current_fluid_ml: Math.round(totalFluidMl(foods)),
        fluid_ceiling_ml: ceiling,
        wanted_ml: wantedMl,
      },
    };
  }

  const perServingMl = water.per_serving.water_ml;
  const out = [...foods];

  const servingsFor = (headroomMl: number): number => {
    const wanted = ceilHalf(wantedMl / perServingMl);
    const byHeadroom = ceiling == null
      ? Number.POSITIVE_INFINITY
      : floorHalf(headroomMl / perServingMl);
    return Math.min(wanted, byHeadroom, water.max_servings);
  };

  let headroom = ceiling == null
    ? Number.POSITIVE_INFINITY
    : ceiling - totalFluidMl(out);
  let servings = servingsFor(headroom);

  // Not enough headroom: try to free some by trimming a fluid carrier that
  // is neither an electrolyte nor a carb source, so nothing else regresses.
  // (Rare in practice — an unpaired phase's fluid is usually whole-food water
  // that we refuse to trim because it carries the phase's carbs.)
  if (servings < 0.5) {
    const trimIdx = out.findIndex((f) => {
      const ps = perServing(f);
      return !isElectrolyteItem(f) && ps.fluid > 0 && ps.carbs <= 0;
    });
    if (trimIdx >= 0) {
      const item = out[trimIdx];
      const ps = perServing(item);
      const needMl = MIN_PAIRING_VOLUME_ML - headroom;
      const dropServings = Math.min(
        ceilHalf(needMl / ps.fluid),
        // Never trim an item out of existence — keep at least half a serving.
        Math.max(0, item.quantity - 0.5),
      );
      if (dropServings > 0) {
        out[trimIdx] = withQuantity(item, item.quantity - dropServings);
        console.log(
          `${logPrefix} electrolyte pairing: trimmed ${dropServings}x "` +
            `${item.display_name ?? item.food_id}" to free fluid headroom`,
        );
        headroom = ceiling == null
          ? Number.POSITIVE_INFINITY
          : ceiling - totalFluidMl(out);
        servings = servingsFor(headroom);
      }
    }
  }

  if (servings < 0.5) {
    console.warn(
      `${logPrefix} electrolyte pairing: cannot add water without breaching ` +
        `the fluid ceiling (${Math.round(totalFluidMl(foods))}ml of ` +
        `${ceiling}ml used) — ${unpaired.length} electrolyte item(s) left ` +
        `unpaired`,
    );
    return {
      foods: [...foods],
      changed: false,
      conflict: {
        reason: "fluid_ceiling",
        electrolyte_food_ids: electrolyteIds,
        current_fluid_ml: Math.round(totalFluidMl(foods)),
        fluid_ceiling_ml: ceiling,
        wanted_ml: wantedMl,
      },
    };
  }

  out.push(buildWaterResult(water, servings, timing));
  console.log(
    `${logPrefix} electrolyte pairing: added ${servings}x "` +
      `${water.display_name ?? water.name}" ` +
      `(+${Math.round(perServingMl * servings)}ml) alongside ` +
      `${unpaired.length} dry electrolyte item(s)`,
  );

  return { foods: out, changed: true, conflict: null };
}

/**
 * Wire-in convenience for phase output sites: gate → lazily load a water pool
 * → apply → return the corrected list.
 *
 * [loadWaterPool] is only awaited when the invariant is actually violated, so
 * the common case costs one array scan and zero queries (same lazy shape as
 * the `fluidSodiumDeficits` gate on the pin-backfill path).
 *
 * Conflicts are logged by [ensureElectrolyteWaterPairing] and the original
 * list is returned unchanged — a phase is never silently pushed over its
 * fluid ceiling. Callers that want to surface the conflict on the wire should
 * call [ensureElectrolyteWaterPairing] directly and read `.conflict`.
 */
export async function applyElectrolyteWaterPairing(
  foods: FoodResult[],
  options: ElectrolytePairingOptions,
  loadWaterPool: () => Promise<Food[]>,
): Promise<FoodResult[]> {
  if (!needsWaterPairing(foods)) return foods;
  const pool = await loadWaterPool();
  return ensureElectrolyteWaterPairing(foods, pool, options).foods;
}
