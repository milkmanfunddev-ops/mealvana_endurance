// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import solver from "https://esm.sh/javascript-lp-solver@0.4.24";

// ---------------- CORS ----------------
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ---------------- Types (Updated to match Flutter service) ----------------
interface NutritionPlanRequest {
  device_id: string;
  age: number;
  gender: string;
  weight_kg: number;
  height_cm: number;
  gut_training_level: string;
  distance_miles: number;
  pace_minutes_per_mile: number;
  time_before_run_hours: number;
  macro_targets: {
    pre_run: {
      carbs_g: number;
      protein_g: number;
      fat_g: number;
      water_ml: number;
      sodium_mg: number;
    };
    during_run: {
      carbs_total_g: number;
      sodium_total_mg: number;
      water_total_ml: number;
    };
    post_run: {
      carbs_g: number;
      protein_g: number;
      fat_g: number;
      water_ml: number;
      sodium_mg: number;
    };
  };
  liked_foods: string[];
  willing_to_try_foods: string[];
  disliked_foods: string[];
  sweat_rate?: string;
  tolerances?: Partial<Record<"carbs_g"|"protein_g"|"fat_g"|"sodium_mg"|"water_ml", number>>;
  step_overrides?: Record<string, number>;
}

interface FoodRow {
  id: string;
  name: string;
  image_address: string | null;
  calories_per_serving: number | null;
  carbs_per_serving: number | null;
  protein_per_serving: number | null;
  fat_per_serving: number | null;
  sodium_mg: number | null;
  fluid_ml_per_serving: number | null;
  serving_amount: number | null;
  serving_unit: string | null;
  serving_unit_plural: string | null;
  serving_qualifier: string | null;
  max_servings_before: number | null;
  max_servings_during: number | null;
  product_type: string | null;
  brand_id: string | null;
}

// ---------------- Config / knobs ----------------
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const DEFAULT_TOL = { carbs_g: 10, protein_g: 10, fat_g: 5, sodium_mg: 200, water_ml: 250 };

const LAMBDA_UNIQUE = 0.01;           // penalty per unique item
const LAMBDA_SERVINGS = 0.001;         // penalty per serving
const BONUS_LIKED_PER_SERV = 0.01;     // subtract from objective (encourage)
const BONUS_WILLTRY_PER_SERV = 0.005;

const DEFAULT_MAX = { before: 3, during: 6, after: 3 };
const DEFAULT_STEPS: Record<string, number> = {
  gel: 0.5, chew: 0.5, drink_mix: 0.25, sports_drink: 0.25,
  electrolyte_only: 0.5, capsule: 0.5, bar: 0.5, waffle: 0.5,
  real_food: 0.5, recovery_shake: 0.25,
};

// ---------------- Utils ----------------
const safe = (n: any, d=0) => (Number.isFinite(Number(n)) ? Number(n) : d);

function normalizeTargets(raw: any): Required<{carbs_g: number; protein_g: number; fat_g: number; sodium_mg: number; water_ml: number}> {
  return {
    carbs_g: safe(raw.carbs_g),
    protein_g: safe(raw.protein_g),
    fat_g: safe(raw.fat_g),
    sodium_mg: safe(raw.sodium_mg),
    water_ml: safe(raw.water_ml),
  };
}

function normalizeDuring(d: any): Required<{carbs_g: number; protein_g: number; fat_g: number; sodium_mg: number; water_ml: number}> {
  return {
    carbs_g: safe(d.carbs_g ?? d.carbs_total_g),
    sodium_mg: safe(d.sodium_mg ?? d.sodium_total_mg),
    water_ml: safe(d.water_ml ?? d.water_total_ml),
    protein_g: safe(d.protein_g ?? 0),
    fat_g: safe(d.fat_g ?? 0),
  };
}

function generateQuantityDisplay(food: FoodRow, customAmount?: number): string {
  const baseAmt = food.serving_amount ?? 1.0;
  const amount = customAmount ?? baseAmt;
  const amountStr = amount === Math.floor(amount) ? Math.floor(amount).toString() : amount.toFixed(1);

  const unit = amount > 1 && food.serving_unit_plural?.trim()
    ? food.serving_unit_plural
    : food.serving_unit ?? "serving";

  const parts = [amountStr, unit];
  if (food.serving_qualifier?.trim()) parts.push(food.serving_qualifier);
  parts.push((food.name || "").toLowerCase());
  return parts.join(" ");
}

function qtyLabel(food: FoodRow, servings: number): string {
  const customAmount = servings * (food.serving_amount ?? 1);
  return generateQuantityDisplay(food, customAmount);
}

function phaseName(p: "before"|"during"|"after") { 
  return p==="before"?"pre_run":(p==="after"?"post_run":"during_run"); 
}

// ---------------- DB helpers ----------------
async function categoryIdByName(supabase: any, name: string): Promise<number|null> {
  const { data, error } = await supabase.from("categories").select("id").eq("name", name).maybeSingle();
  if (error || !data) return null;
  return data.id as number;
}

async function foodsForPhase(
  supabase: any,
  phase: "before"|"during"|"after",
  likedSet: Set<string>, willTrySet: Set<string>, dislikedSet: Set<string>,
  stepOverrides?: Record<string, number>,
) {
  const cat = phase==="before"?"before_run":(phase==="after"?"after_run":"during_run");
  const catId = await categoryIdByName(supabase, cat);
  if (catId === null) return [];

  const { data: fc, error: fcErr } = await supabase
    .from("food_categories").select("food_id").eq("category_id", catId);
  if (fcErr || !fc || fc.length===0) return [];

  const ids = fc.map((r: any) => r.food_id);
  const { data: foods, error: foodsErr } = await supabase
    .from("foods").select(`
      id, name, image_address,
      calories_per_serving, carbs_per_serving, protein_per_serving, fat_per_serving,
      sodium_mg, fluid_ml_per_serving,
      serving_amount, serving_unit, serving_unit_plural, serving_qualifier,
      max_servings_before, max_servings_during, product_type, brand_id
    `)
    .is("brand_id", null) // Only generic foods
    .in("id", ids);

  if (foodsErr || !foods) return [];

  const dislikedLower = new Set([...dislikedSet].map(x=>x.toLowerCase()));
  const likedLower    = new Set([...likedSet].map(x=>x.toLowerCase()));
  const willTryLower  = new Set([...willTrySet].map(x=>x.toLowerCase()));

  return (foods as FoodRow[])
    .filter(f => !dislikedLower.has(f.name?.toLowerCase() ?? "") && !dislikedSet.has(f.id))
    .map((f, idx) => {
      const pt = (f.product_type ?? "").trim();
      const step = stepOverrides?.[pt] ?? DEFAULT_STEPS[pt] ?? 0.25;
      const maxServ = phase==="during"
        ? (f.max_servings_during ?? DEFAULT_MAX.during)
        : phase==="before"
          ? (f.max_servings_before ?? DEFAULT_MAX.before)
          : DEFAULT_MAX.after;
      const capSteps = Math.max(0, Math.floor(safe(maxServ)/step));
      const liked = likedLower.has(f.name?.toLowerCase() ?? "") || likedSet.has(f.id);
      const willTry = willTryLower.has(f.name?.toLowerCase() ?? "") || willTrySet.has(f.id);
      return { f, idx, step, capSteps, liked, willTry };
    });
}

// ---------------- LP model builder (unchanged) ----------------
type Targets = Required<{carbs_g: number; protein_g: number; fat_g: number; sodium_mg: number; water_ml: number}>;
type Tol = Required<{carbs_g: number; protein_g: number; fat_g: number; sodium_mg: number; water_ml: number}>;
type Phase = "before"|"during"|"after";

function buildMilpModel(
  phase: Phase,
  items: Array<{
    f: FoodRow; idx: number; step: number; capSteps: number; liked: boolean; willTry: boolean;
  }>,
  targets: Targets,
  tol: Tol,
) {
  // Constraint names (balances + per-item link)
  const C = {
    CARB: `${phase}_carb`, PROT: `${phase}_prot`, FAT: `${phase}_fat`,
    SOD: `${phase}_sod`, WATER: `${phase}_water`,
  };

  const model: any = {
    optimize: "cost",
    opType: "min",
    constraints: {
      [C.CARB]: { equal: targets.carbs_g },
      [C.PROT]: { equal: targets.protein_g },
      [C.FAT]: { equal: targets.fat_g },
      [C.SOD]: { equal: targets.sodium_mg },
      [C.WATER]: { equal: targets.water_ml },
    },
    variables: {} as Record<string, any>,
    ints: {} as Record<string, 1>,
    binaries: {} as Record<string, 1>,
  };

  // Slack vars for |residual| with cost scaled by tolerance
  const slack = [
    { name: `${phase}_c_pos`, row: C.CARB, coef: +1, cost: 1/Math.max(tol.carbs_g,1e-9) },
    { name: `${phase}_c_neg`, row: C.CARB, coef: -1, cost: 1/Math.max(tol.carbs_g,1e-9) },
    { name: `${phase}_p_pos`, row: C.PROT, coef: +1, cost: 1/Math.max(tol.protein_g,1e-9) },
    { name: `${phase}_p_neg`, row: C.PROT, coef: -1, cost: 1/Math.max(tol.protein_g,1e-9) },
    { name: `${phase}_f_pos`, row: C.FAT,  coef: +1, cost: 1/Math.max(tol.fat_g,1e-9) },
    { name: `${phase}_f_neg`, row: C.FAT,  coef: -1, cost: 1/Math.max(tol.fat_g,1e-9) },
    { name: `${phase}_s_pos`, row: C.SOD,  coef: +1, cost: 1/Math.max(tol.sodium_mg,1e-9) },
    { name: `${phase}_s_neg`, row: C.SOD,  coef: -1, cost: 1/Math.max(tol.sodium_mg,1e-9) },
    { name: `${phase}_l_pos`, row: C.WATER,coef: +1, cost: 1/Math.max(tol.water_ml,1e-9) },
    { name: `${phase}_l_neg`, row: C.WATER,coef: -1, cost: 1/Math.max(tol.water_ml,1e-9) },
  ];
  for (const s of slack) {
    model.variables[s.name] = { cost: s.cost, [s.row]: s.coef, min: 0 };
  }

  // Food variables: Xi (integer steps), Yi (binary link)
  for (const it of items) {
    const { f, idx, step, capSteps, liked, willTry } = it;
    const xi = `${phase}_x_${idx}`; // integer step count
    const yi = `${phase}_y_${idx}`; // used?

    const costServ = LAMBDA_SERVINGS * step
      - (liked ? BONUS_LIKED_PER_SERV * step : 0)
      - (willTry ? BONUS_WILLTRY_PER_SERV * step : 0);

    model.variables[xi] = {
      cost: costServ,
      [C.CARB]: step * safe(f.carbs_per_serving),
      [C.PROT]: step * safe(f.protein_per_serving),
      [C.FAT]:  step * safe(f.fat_per_serving),
      [C.SOD]:  step * safe(f.sodium_mg),
      [C.WATER]:step * safe(f.fluid_ml_per_serving),
      min: 0, max: capSteps,
    };
    model.ints[xi] = 1;

    // unique penalty variable
    const linkRow = `${phase}_link_${idx}`;
    model.constraints[linkRow] = { max: 0 }; // Xi - U*Yi <= 0
    model.variables[xi][linkRow] = 1;

    model.variables[yi] = { cost: LAMBDA_UNIQUE, [linkRow]: -capSteps, min: 0, max: 1 };
    model.binaries[yi] = 1;
  }

  return model;
}

function solveModel(model: any) {
  // Primary: MILP
  let res = solver.Solve(model);
  if (res.feasible) return res;

  // Fallback: relax integrality on Xi (allow fractional multiples of step)
  const relaxed = JSON.parse(JSON.stringify(model));
  relaxed.ints = {};
  res = solver.Solve(relaxed);
  return res;
}

// ---------------- Phase wrapper ----------------
async function optimizePhase(
  supabase: any, phase: "before"|"during"|"after",
  targets: Targets, tol: Tol,
  likedSet: Set<string>, willTrySet: Set<string>, dislikedSet: Set<string>,
  stepOverrides?: Record<string, number>,
) {
  const cands = await foodsForPhase(supabase, phase, likedSet, willTrySet, dislikedSet, stepOverrides);
  if (cands.length === 0) {
    return { items: [], totals: { carbs_g:0, protein_g:0, fat_g:0, sodium_mg:0, water_ml:0 } };
  }

  const model = buildMilpModel(phase, cands, targets, tol);
  const res = solveModel(model);

  // Map solution → servings and totals
  const items: any[] = [];
  const totals = { carbs_g:0, protein_g:0, fat_g:0, sodium_mg:0, water_ml:0 };

  for (const it of cands) {
    const xi = `${phase}_x_${it.idx}`;
    const steps = safe(res[xi], 0);
    if (steps <= 0) continue;

    const serv = +(it.step * steps).toFixed(2);
    const f = it.f;

    const carbs = safe(f.carbs_per_serving) * serv;
    const prot  = safe(f.protein_per_serving) * serv;
    const fat   = safe(f.fat_per_serving) * serv;
    const sod   = safe(f.sodium_mg) * serv;
    const water = safe(f.fluid_ml_per_serving) * serv;
    const kcal  = Math.round(safe(f.calories_per_serving) * serv);

    totals.carbs_g += carbs;
    totals.protein_g += prot;
    totals.fat_g += fat;
    totals.sodium_mg += sod;
    totals.water_ml += water;

    // Create item in Flutter service expected format
    const defaultTiming = phase === "before" ? "2-3 hours before" : 
                         phase === "during" ? "Throughout run" : "Within 30 minutes";
    const customAmount = serv * (f.serving_amount ?? 1);

    items.push({
      food_name: f.name,  // Flutter service expects food_name
      description: generateQuantityDisplay(f, customAmount),
      image_address: f.image_address,
      timing: defaultTiming,
      servings: serv,
      carbs_grams: +carbs.toFixed(2),
      protein_grams: +prot.toFixed(2),
      fat_grams: +fat.toFixed(2),
      sodium_mg: +sod.toFixed(2),
      fluids_ml: +water.toFixed(2),
      calories: kcal,
    });
  }

  // round totals nicely
  for (const k of ["carbs_g","protein_g","fat_g","sodium_mg","water_ml"] as const) {
    // @ts-ignore
    totals[k] = +totals[k].toFixed(2);
  }

  return { items, totals };
}

// ---------------- Server ----------------
serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const body: NutritionPlanRequest = await req.json();

    // Validate required fields
    if (!body.device_id || !body.macro_targets) {
      return new Response(
        JSON.stringify({
          success: false,
          message: "Missing required fields: device_id and macro_targets are required",
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { pre_run, during_run, post_run } = body.macro_targets;
    if (!pre_run || !during_run || !post_run) {
      return new Response(
        JSON.stringify({
          success: false,
          message: "Invalid macro_targets structure: pre_run, during_run, and post_run phases required",
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const preTargets = normalizeTargets(pre_run);
    const duringTargets = normalizeDuring(during_run);
    const postTargets = normalizeTargets(post_run);

    const tol: Required<{carbs_g: number; protein_g: number; fat_g: number; sodium_mg: number; water_ml: number}> = {
      carbs_g: body.tolerances?.carbs_g ?? DEFAULT_TOL.carbs_g,
      protein_g: body.tolerances?.protein_g ?? DEFAULT_TOL.protein_g,
      fat_g: body.tolerances?.fat_g ?? DEFAULT_TOL.fat_g,
      sodium_mg: body.tolerances?.sodium_mg ?? DEFAULT_TOL.sodium_mg,
      water_ml: body.tolerances?.water_ml ?? DEFAULT_TOL.water_ml,
    };

    const likedSet = new Set(body.liked_foods ?? []);
    const willTrySet = new Set(body.willing_to_try_foods ?? []);
    const dislikedSet = new Set(body.disliked_foods ?? []);

    const [before, during, after] = await Promise.all([
      optimizePhase(supabase, "before", preTargets, tol, likedSet, willTrySet, dislikedSet, body.step_overrides),
      optimizePhase(supabase, "during", duringTargets, tol, likedSet, willTrySet, dislikedSet, body.step_overrides),
      optimizePhase(supabase, "after", postTargets, tol, likedSet, willTrySet, dislikedSet, body.step_overrides),
    ]);

    // Generate plan ID and detailed message
    const planId = `lp-plan-${Date.now()}-${body.device_id.slice(-6)}`;
    const detailedMessage = `Optimized nutrition plan using linear programming. Targets: Pre-run ${preTargets.carbs_g}g carbs, During-run ${duringTargets.carbs_g}g carbs, Post-run ${postTargets.carbs_g}g carbs.`;

    // Save plan to database (best effort)
    const nutritionPlan = {
      detailed_message: detailedMessage,
      plan: {
        before: before.items,
        during: during.items,
        after: after.items,
      },
    };

    const { error: saveError } = await supabase.from("nutrition_plans").insert({
      device_id: body.device_id,
      plan_id: planId,
      plan_name: "LP-Generated Nutrition Plan",
      plan_data: JSON.stringify(nutritionPlan),
      distance_miles: body.distance_miles,
      pace_minutes_per_mile: body.pace_minutes_per_mile,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    });

    if (saveError) {
      console.error("❌ Error saving plan:", saveError);
    }

    // Return response in exact format expected by Flutter service
    const response = {
      success: true,
      plan_id: planId,
      detailed_message: detailedMessage,
      plan: {
        before: before.items,
        during: during.items,
        after: after.items,
      },
      macro_targets: {
        pre_run: {
          carbs_g: preTargets.carbs_g,
          protein_g: preTargets.protein_g,
          fat_g: preTargets.fat_g,
          water_ml: preTargets.water_ml,
          sodium_mg: preTargets.sodium_mg,
        },
        during_run: {
          carbs_total_g: duringTargets.carbs_g,
          sodium_total_mg: duringTargets.sodium_mg,
          water_total_ml: duringTargets.water_ml,
        },
        post_run: {
          carbs_g: postTargets.carbs_g,
          protein_g: postTargets.protein_g,
          fat_g: postTargets.fat_g,
          water_ml: postTargets.water_ml,
          sodium_mg: postTargets.sodium_mg,
        },
      },
    };

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (e: any) {
    console.error("LP optimization error:", e);
    return new Response(JSON.stringify({ 
      success: false, 
      error: String(e),
      fallback_to_algorithm: true,
    }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});