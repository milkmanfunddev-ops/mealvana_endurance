// Running-only nutrition planner (pre, during, after) — no external packages.
// Uses Supabase PostgREST via fetch. Fast, deterministic, and Edge-friendly.

type Phase = "before" | "during" | "after";

// Configuration constants for easy tuning
const SCORING_CONFIG = {
  preference: {
    like: 20,
    willing_to_try: 5,
    dislike: 0
  },
  pre: {
    carb_density_multiplier: 120,
    high_fat_penalty: 20,
    high_fat_threshold: 10,
    prep_penalty: 5
  },
  during: {
    carb_value: 2.0,
    sodium_value: 0.05,
    fluid_value: 0.02,
    aid_station_bonus: 12,
    gi_sensitive_calorie_limit: 150,
    gi_sensitive_penalty: 20
  },
  after: {
    carb_value: 1.5,
    protein_value: 2.0,
    fluid_value: 0.02,
    sodium_value: 0.05,
    high_fat_penalty: 15,
    high_fat_threshold: 15
  }
};

type Food = {
  id: string;
  name: string;
  icon_path?: string | null;        // Fixed: matches database
  description?: string | null;      // Fixed: matches database
  instructions?: string | null;     // Fixed: matches database

  // Serving meta
  serving_amount?: number | null;
  serving_unit?: string | null;
  serving_qualifier?: string | null;
  serving_unit_plural?: string | null;
  serving_size?: string | null;

  // Per-serving nutrition
  sodium_mg?: number | null;
  caffeine_mg?: number | null;
  potassium_mg?: number | null;
  fat_per_serving?: number | null;
  carbs_per_serving?: number | null;
  protein_per_serving?: number | null;
  calories_per_serving?: number | null;
  fluid_ml_per_serving?: number | null;

  // Practicality flags
  before_run_suitable: boolean;
  during_run_suitable: boolean;
  run_portable: boolean;
  requires_preparation: boolean;
  aid_station_available: boolean;

  max_servings_before?: number | null;
  max_servings_during?: number | null;
};

type Preference = "like" | "dislike" | "willing_to_try";
type PreferenceMap = Record<string, Preference>;

type Inputs = {
  deviceId?: string;
  debug?: boolean;                    // Enable debug output

  // Required
  weightKg: number;                   // 35–150
  durationMin: number;                // 15–720 (0.25–12h)

  // Optional knobs
  preWindowMin?: number;              // minutes until start; influences pre carbs 0.25–4 g/kg
  gutTraining?: "low" | "moderate" | "high";
  giSensitivity?: "normal" | "sensitive";
  tempF?: number;                     // environment for scaling hydration/sodium
  humidity?: number;                  // 0–100
  sweatRate?: "low" | "moderate" | "high";
  allowHighCarbRun?: boolean;         // allow 75–90 g/h when trained & cool
  intervalMinutes?: 20 | 30;          // fueling cadence; 30 default, 20 when pushing high carbs

  // Optional curiosity output
  paceMinPerKm?: number;              // if provided, compute ACSM estimate
};

type Targets = {
  before: { carbs_g: number; fluid_ml: number; sodium_mg?: number };
  during: {
    carbs_g_per_h: number;
    carbs_g_total: number;
    fluid_ml_per_h: number;
    sodium_mg_per_h: number;
  };
  after: {
    carbs_g: number;
    protein_g: number;
    fluid_ml: number;
    sodium_mg: number;
  };
};

type Plan = {
  before: {
    items: Array<{ name: string; servings: number; carbs_g: number }>;
    fluid_ml_sip: number;
    sodium_mg_optional?: number;
    totals?: { carbs_g: number };
  };
  during: {
    per_interval_targets: { carbs_g: number; sodium_mg: number; fluid_ml: number };
    events: Array<{ at_min: number; item: string; servings: number; carbs_g: number; sodium_mg: number; fluid_ml: number }>;
  };
  after: {
    items: Array<{ name: string; servings: number; carbs_g: number; protein_g: number; sodium_mg: number; fluid_ml: number }>;
    targets: { carbs_g: number; protein_g: number; fluid_ml: number; sodium_mg: number };
    totals: { carbs_g: number; protein_g: number; fluid_ml: number; sodium_mg: number };
  };
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_ANON_KEY")!;
const HDRS = { apikey: KEY, Authorization: `Bearer ${KEY}` };

const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), { status, headers: { "Content-Type": "application/json" } });

const clamp = (v: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, v));
const rnd = (v: number, p = 1) => Math.round(v * p) / p;

function validateInputs(inputs: Inputs): string[] {
  const errors: string[] = [];
  
  // Required fields
  if (typeof inputs.weightKg !== 'number' || inputs.weightKg < 35 || inputs.weightKg > 150) {
    errors.push('weightKg must be a number between 35-150');
  }
  
  if (typeof inputs.durationMin !== 'number' || inputs.durationMin < 15 || inputs.durationMin > 720) {
    errors.push('durationMin must be a number between 15-720 (0.25-12 hours)');
  }
  
  // Optional field validation
  if (inputs.preWindowMin !== undefined && (typeof inputs.preWindowMin !== 'number' || inputs.preWindowMin < 0)) {
    errors.push('preWindowMin must be a non-negative number');
  }
  
  if (inputs.gutTraining !== undefined && !['low', 'moderate', 'high'].includes(inputs.gutTraining)) {
    errors.push('gutTraining must be one of: low, moderate, high');
  }
  
  if (inputs.giSensitivity !== undefined && !['normal', 'sensitive'].includes(inputs.giSensitivity)) {
    errors.push('giSensitivity must be one of: normal, sensitive');
  }
  
  if (inputs.tempF !== undefined && (typeof inputs.tempF !== 'number' || inputs.tempF < -20 || inputs.tempF > 120)) {
    errors.push('tempF must be a number between -20-120');
  }
  
  if (inputs.humidity !== undefined && (typeof inputs.humidity !== 'number' || inputs.humidity < 0 || inputs.humidity > 100)) {
    errors.push('humidity must be a number between 0-100');
  }
  
  if (inputs.sweatRate !== undefined && !['low', 'moderate', 'high'].includes(inputs.sweatRate)) {
    errors.push('sweatRate must be one of: low, moderate, high');
  }
  
  if (inputs.intervalMinutes !== undefined && ![20, 30].includes(inputs.intervalMinutes)) {
    errors.push('intervalMinutes must be 20 or 30');
  }
  
  if (inputs.paceMinPerKm !== undefined && (typeof inputs.paceMinPerKm !== 'number' || inputs.paceMinPerKm <= 0)) {
    errors.push('paceMinPerKm must be a positive number');
  }
  
  return errors;
}

function envMultipliers(tempF?: number, humidity?: number, sweatRate?: Inputs["sweatRate"]) {
  let fluidMul = 1.0, sodiumMul = 1.0;
  const hot = tempF !== undefined && tempF >= 80;
  const warm = tempF !== undefined && tempF >= 70 && tempF < 80;
  const humid = humidity !== undefined && humidity >= 75;

  if (hot) { fluidMul *= 1.3; sodiumMul *= 1.5; }
  else if (warm) { fluidMul *= 1.15; sodiumMul *= 1.25; }
  if (humid) { fluidMul *= 1.1; sodiumMul *= 1.1; }

  if (sweatRate === "high") { fluidMul *= 1.2; sodiumMul *= 1.3; }
  else if (sweatRate === "low") { fluidMul *= 0.9; sodiumMul *= 0.9; }

  return { fluidMul, sodiumMul };
}

// ---- ACSM (optional info)
function acsmFromPace(weightKg: number, paceMinPerKm: number, durationH: number) {
  if (!paceMinPerKm || !isFinite(paceMinPerKm)) return null;
  // pace (min/km) -> speed (m/min): 1000 m / pace(min)
  const speed_m_min = 1000 / paceMinPerKm;
  const VO2 = 0.2 * speed_m_min + 3.5;            // mL/kg/min
  const MET = VO2 / 3.5;
  const kcal = MET * weightKg * durationH;
  return { VO2_ml_kg_min: rnd(VO2, 100), MET: rnd(MET, 100), kcal: rnd(kcal, 1) };
}

// ---- Targets per your analyses/guidelines
function calcTargets(inp: Inputs): Targets {
  const weight = clamp(inp.weightKg, 35, 150);
  const durH = clamp(inp.durationMin / 60, 0.25, 12);
  const { fluidMul, sodiumMul } = envMultipliers(inp.tempF, inp.humidity, inp.sweatRate);

  // PRE: time-window rule 0.25–4 g/kg (cap 4 g/kg)
  const tMin = typeof inp.preWindowMin === "number" ? Math.max(0, inp.preWindowMin) : 120;
  let preGkg = 2.0; // default ~2h window
  if (tMin < 15) preGkg = 0.25;
  else if (tMin < 60) preGkg = 0.5;
  else if (tMin <= 240) preGkg = Math.min(4.0, tMin / 60.0 * 1.0); // 1 g/kg per hour window
  const preCarbs = clamp(weight * preGkg, 25, 150);

  // Pre fluids: 4–6 mL/kg baseline, scale mildly with environment
  const preFluid = clamp(Math.round(weight * 5 * Math.min(fluidMul, 1.2)), 300, 700);
  // Optional small sodium if hot: ~300 mg
  const preNa = (sodiumMul > 1.1) ? 300 : undefined;

  // DURING carbs: by gut training; allow 75–90 g/h when explicitly enabled & trained & cool enough
  const gut = inp.gutTraining ?? "moderate";
  let baseRate = gut === "high" ? 60 : gut === "low" ? 40 : 50;
  if (inp.allowHighCarbRun && gut === "high" && durH >= 2.5 && (inp.tempF ?? 65) <= 75) baseRate = 75;
  const hourlyCarbs = clamp(baseRate, 30, inp.allowHighCarbRun ? 90 : 60);

  // DURING fluids 0.4–0.8 L/h scaled
  const fluidPerH = clamp(Math.round(600 * fluidMul), 400, 1000);

  // DURING sodium 300–600 mg/h (up to 1000 mg/h in heat); allow 0 if ≤ 60 min total
  const sodiumPerHBase = clamp(Math.round(450 * sodiumMul), 300, 1000);
  const sodiumPerH = inp.durationMin <= 60 ? 0 : sodiumPerHBase;

  // AFTER: ~1.0 g/kg carbs, ~0.3 g/kg protein; fluids ≈ 1.25× hourly need, sodium ~500 mg (scaled)
  const afterCarbs = clamp(Math.round(weight * 1.0), 30, 140);
  const afterProtein = clamp(rnd(weight * 0.3, 10), 18, 45);
  const afterFluids = clamp(Math.round(fluidPerH * 1.25), 500, 1200);
  const afterSodium = clamp(Math.round(500 * sodiumMul), 300, 1000);

  return {
    before: { carbs_g: preCarbs, fluid_ml: preFluid, sodium_mg: preNa },
    during: {
      carbs_g_per_h: hourlyCarbs,
      carbs_g_total: hourlyCarbs * durH,
      fluid_ml_per_h: fluidPerH,
      sodium_mg_per_h: sodiumPerH
    },
    after: { carbs_g: afterCarbs, protein_g: afterProtein, fluid_ml: afterFluids, sodium_mg: afterSodium }
  };
}

// ---- Data access (≤ 2 roundtrips, foods cached)
async function fetchFoods(): Promise<Food[]> {
  const cols = [
    "id","name","icon_path","description","instructions",      // Fixed: correct field names
    "serving_amount","serving_unit","serving_qualifier","serving_unit_plural","serving_size",
    "sodium_mg","caffeine_mg","potassium_mg","fat_per_serving","carbs_per_serving","protein_per_serving","calories_per_serving",
    "fluid_ml_per_serving",
    "before_run_suitable","during_run_suitable","run_portable","requires_preparation","aid_station_available",
    "max_servings_before","max_servings_during"
  ].join(",");
  const url = `${SUPABASE_URL}/rest/v1/foods?select=${cols}`;
  const r = await fetch(url, { headers: HDRS });
  if (!r.ok) throw new Error(`foods fetch ${r.status}: ${await r.text()}`);
  return await r.json();
}

// Get fallback foods for edge cases
function getFallbackFoods(foods: Food[]): { gel?: Food; drink?: Food; recovery?: Food } {
  const gel = foods.find(f => f.name.toLowerCase().includes('gel') && f.during_run_suitable) ?? 
              foods.find(f => f.during_run_suitable && f.carbs_per_serving && f.carbs_per_serving >= 20);
  
  const drink = foods.find(f => f.name.toLowerCase().includes('sport') && f.name.toLowerCase().includes('drink')) ??
                foods.find(f => f.during_run_suitable && f.fluid_ml_per_serving && f.fluid_ml_per_serving > 200);
  
  const recovery = foods.find(f => f.name.toLowerCase().includes('chocolate') && f.name.toLowerCase().includes('milk')) ??
                   foods.find(f => f.carbs_per_serving && f.protein_per_serving && 
                                   f.carbs_per_serving >= 20 && f.protein_per_serving >= 5);
  
  return { gel, drink, recovery };
}

async function fetchPrefs(deviceId?: string): Promise<PreferenceMap> {
  if (!deviceId) return {};
  const url = `${SUPABASE_URL}/rest/v1/food_preferences?select=food_name,preference&device_id=eq.${encodeURIComponent(deviceId)}`;
  const r = await fetch(url, { headers: HDRS });
  if (!r.ok) return {};
  const rows: { food_name: string; preference: Preference }[] = await r.json();
  const map: PreferenceMap = {};
  rows.forEach(x => (map[x.food_name] = x.preference));
  return map;
}

// Category 3 = after_run
async function fetchAfterEligibleIds(): Promise<Set<string>> {
  const url = `${SUPABASE_URL}/rest/v1/food_categories?select=food_id&category_id=eq.3`;
  const r = await fetch(url, { headers: HDRS });
  if (!r.ok) return new Set();
  const rows: { food_id: string }[] = await r.json();
  return new Set(rows.map(x => x.food_id));
}

// ---- Scoring
function scorePre(f: Food, prefs: PreferenceMap): number {
  const pref = prefs[f.name];
  if (pref === "dislike") return 0;
  const carbs = f.carbs_per_serving ?? 0;
  const kcal = f.calories_per_serving ?? Math.round(carbs * 4);
  const fat = f.fat_per_serving ?? 0;

  let s = 100;
  if (pref === "like") s += SCORING_CONFIG.preference.like;
  if (pref === "willing_to_try") s += SCORING_CONFIG.preference.willing_to_try;

  // Carb density & low fat are preferred pre-run
  const density = carbs / Math.max(kcal, 1);
  s += density * SCORING_CONFIG.pre.carb_density_multiplier;
  if (fat >= SCORING_CONFIG.pre.high_fat_threshold) s -= SCORING_CONFIG.pre.high_fat_penalty;
  if (f.requires_preparation) s -= SCORING_CONFIG.pre.prep_penalty;
  return s;
}

function scoreDuring(f: Food, prefs: PreferenceMap, t: Targets, gi: Inputs["giSensitivity"]): number {
  const pref = prefs[f.name];
  if (pref === "dislike") return 0;
  if (!f.during_run_suitable || !f.run_portable) return 0;
  if (f.requires_preparation) return 0;

  const carbs = f.carbs_per_serving ?? 0;
  const na = f.sodium_mg ?? 0;
  const fluid = f.fluid_ml_per_serving ?? 0;
  const kcal = f.calories_per_serving ?? Math.round(carbs * 4);

  let s = 100;
  if (pref === "like") s += SCORING_CONFIG.preference.like;
  if (pref === "willing_to_try") s += SCORING_CONFIG.preference.willing_to_try;

  // Value items that contribute to multiple needs
  s += Math.min(carbs, t.during.carbs_g_per_h / 2) * SCORING_CONFIG.during.carb_value;
  s += Math.min(na,    t.during.sodium_mg_per_h / 2) * SCORING_CONFIG.during.sodium_value;
  s += Math.min(fluid, t.during.fluid_ml_per_h   / 2) * SCORING_CONFIG.during.fluid_value;

  if (gi === "sensitive" && kcal >= SCORING_CONFIG.during.gi_sensitive_calorie_limit) s -= SCORING_CONFIG.during.gi_sensitive_penalty;
  if (f.aid_station_available) s += SCORING_CONFIG.during.aid_station_bonus;
  return s;
}

function scoreAfter(f: Food, prefs: PreferenceMap, t: Targets): number {
  const pref = prefs[f.name];
  if (pref === "dislike") return 0;

  const c = f.carbs_per_serving ?? 0;
  const p = f.protein_per_serving ?? 0;
  const na = f.sodium_mg ?? 0;
  const fl = f.fluid_ml_per_serving ?? 0;
  const fat = f.fat_per_serving ?? 0;

  let s = 100;
  if (pref === "like") s += SCORING_CONFIG.preference.like * 0.75; // Slightly lower for after
  if (pref === "willing_to_try") s += SCORING_CONFIG.preference.willing_to_try;

  // Prefer items that help both carbs & protein; fluids & sodium are bonuses
  s += Math.min(c, t.after.carbs_g / 2) * SCORING_CONFIG.after.carb_value;
  s += Math.min(p, t.after.protein_g / 2) * SCORING_CONFIG.after.protein_value;
  s += Math.min(fl, t.after.fluid_ml / 2) * SCORING_CONFIG.after.fluid_value;
  s += Math.min(na, t.after.sodium_mg / 2) * SCORING_CONFIG.after.sodium_value;

  if (fat >= SCORING_CONFIG.after.high_fat_threshold) s -= SCORING_CONFIG.after.high_fat_penalty;
  return s;
}

// ---- Selection / Assembly
function pickTop(
  foods: Food[],
  prefs: PreferenceMap,
  phase: Phase,
  t: Targets,
  gi: Inputs["giSensitivity"],
  afterIds?: Set<string>
) {
  let eligible: Food[];
  if (phase === "before") {
    eligible = foods.filter(f => f.before_run_suitable);
  } else if (phase === "during") {
    eligible = foods.filter(f => f.during_run_suitable && f.run_portable && !f.requires_preparation);
  } else {
    eligible = foods.filter(f => afterIds?.has(f.id));
  }

  const scored = eligible.map(f => {
    let score = 0;
    if (phase === "before") score = scorePre(f, prefs);
    else if (phase === "during") score = scoreDuring(f, prefs, t, gi);
    else score = scoreAfter(f, prefs, t);
    return { ref: f, score };
  }).filter(x => x.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, phase === "during" ? 4 : 6); // keep a small set
  return scored;
}

function buildPre(top: Array<{ ref: Food; score: number }>, targetCarbs: number, sodiumOpt?: number) {
  const items: any[] = [];
  let carbs = 0;
  for (const { ref } of top) {
    if (carbs >= targetCarbs) break;
    const per = ref.carbs_per_serving ?? 0;
    if (per <= 0) continue;
    const need = targetCarbs - carbs;
    const maxS = ref.max_servings_before ?? 4;
    const serv = clamp(Math.ceil(need / per), 1, maxS);
    items.push({ name: ref.name, servings: serv, carbs_g: rnd(serv * per) });
    carbs += serv * per;
    if (items.length >= 4) break; // keep it simple
  }
  return {
    items,
    fluid_ml_sip: targetCarbs > 0 ? undefined : 0,
    sodium_mg_optional: sodiumOpt,
    totals: { carbs_g: rnd(carbs) }
  };
}

function buildDuring(top: Array<{ ref: Food; score: number }>, t: Targets, durationMin: number, intervalMin: number, gi: Inputs["giSensitivity"], fallbackFoods: { gel?: Food; drink?: Food }) {
  const events: any[] = [];
  const intervals = Math.ceil(durationMin / intervalMin);
  const carbsPer = t.during.carbs_g_per_h * (intervalMin / 60);
  const naPer = t.during.sodium_mg_per_h * (intervalMin / 60);
  const fluidPer = t.during.fluid_ml_per_h * (intervalMin / 60);

  // GI-sensitive: limit bulky items; prioritize gels/drinks/chews
  const roster = top
    .map(x => x.ref)
    .filter(f => gi === "normal" ? true : (f.calories_per_serving ?? 0) <= SCORING_CONFIG.during.gi_sensitive_calorie_limit)
    .slice(0, 3);

  // Fallback roster if empty - use database fallbacks instead of hardcoded
  if (!roster.length) {
    const fallbackGel = fallbackFoods.gel;
    const fallbackDrink = fallbackFoods.drink;
    
    if (fallbackGel) {
      for (let i = 1; i <= intervals; i++) {
        events.push({ 
          at_min: i * intervalMin, 
          item: fallbackGel.name, 
          servings: 1, 
          carbs_g: fallbackGel.carbs_per_serving ?? 22, 
          sodium_mg: fallbackGel.sodium_mg ?? 50, 
          fluid_ml: fallbackGel.fluid_ml_per_serving ?? 0 
        });
      }
    } else if (fallbackDrink) {
      for (let i = 1; i <= intervals; i++) {
        events.push({ 
          at_min: i * intervalMin, 
          item: fallbackDrink.name, 
          servings: 1, 
          carbs_g: fallbackDrink.carbs_per_serving ?? 14, 
          sodium_mg: fallbackDrink.sodium_mg ?? 110, 
          fluid_ml: fallbackDrink.fluid_ml_per_serving ?? 240 
        });
      }
    } else {
      // Last resort: create a basic plan
      for (let i = 1; i <= intervals; i++) {
        events.push({ at_min: i * intervalMin, item: "Basic Fuel", servings: 1, carbs_g: 25, sodium_mg: 75, fluid_ml: 200 });
      }
    }
    return { events, per_interval_targets: { carbs_g: carbsPer, sodium_mg: naPer, fluid_ml: fluidPer } };
  }

  for (let i = 1; i <= intervals; i++) {
    let needC = carbsPer, needNa = naPer, needFl = fluidPer, actions = 0;

    for (const f of roster) {
      if (actions >= 2) break; // 1–2 actions per interval
      const c = f.carbs_per_serving ?? 0;
      const na = f.sodium_mg ?? 0;
      const fl = f.fluid_ml_per_serving ?? 0;
      const kcal = f.calories_per_serving ?? Math.round(c * 4);

      if (c + na + fl <= 0) continue;
      let serv = 1;
      if (needC > c * 1.5 && kcal <= 120) serv = 2;         // two small items if behind on carbs
      serv = clamp(serv, 1, f.max_servings_during ?? 6);

      const giveC = serv * c, giveNa = serv * na, giveFl = serv * fl;
      if (giveC < 5 && giveNa < 50 && giveFl < 50) continue;

      events.push({
        at_min: i * intervalMin,
        item: f.name,
        servings: serv,
        carbs_g: rnd(giveC),
        sodium_mg: Math.round(giveNa),
        fluid_ml: Math.round(giveFl)
      });
      needC = Math.max(0, needC - giveC);
      needNa = Math.max(0, needNa - giveNa);
      needFl = Math.max(0, needFl - giveFl);
      actions++;
    }

    // If short on sodium/fluid, add an aid-station drink if present
    if ((needNa > 50 || needFl > 100)) {
      const drink = roster.find(r => r.aid_station_available) ?? roster.find(r => (r.fluid_ml_per_serving ?? 0) > 0);
      if (drink) {
        const c = drink.carbs_per_serving ?? 0, na = drink.sodium_mg ?? 0, fl = drink.fluid_ml_per_serving ?? 0;
        if (na > 0 || fl > 0) {
          events.push({ at_min: i * intervalMin, item: drink.name, servings: 1, carbs_g: rnd(c), sodium_mg: Math.round(na), fluid_ml: Math.round(fl) });
        }
      }
    }
  }

  return { events, per_interval_targets: { carbs_g: carbsPer, sodium_mg: naPer, fluid_ml: fluidPer } };
}

function buildAfter(top: Array<{ ref: Food; score: number }>, t: Targets) {
  const items: Array<{ name: string; servings: number; carbs_g: number; protein_g: number; sodium_mg: number; fluid_ml: number }> = [];
  let C = 0, P = 0, Na = 0, Fl = 0;

  // Greedy: pick 2–3 best items, bias to ones that hit both carbs and protein
  const roster = top.slice(0, 3).map(x => x.ref);
  for (const f of roster) {
    if (C >= t.after.carbs_g && P >= t.after.protein_g) break;

    const c = f.carbs_per_serving ?? 0;
    const p = f.protein_per_serving ?? 0;
    const na = f.sodium_mg ?? 0;
    const fl = f.fluid_ml_per_serving ?? 0;

    if (c + p + na + fl <= 0) continue;

    // Servings: more if the item is "light" but useful (e.g., chocolate milk 8oz)
    let serv = 1;
    if (C < t.after.carbs_g - 20 && P < t.after.protein_g - 8 && (c + p) <= 35) serv = 2;

    items.push({
      name: f.name,
      servings: serv,
      carbs_g: rnd(serv * c),
      protein_g: rnd(serv * p),
      sodium_mg: Math.round(serv * na),
      fluid_ml: Math.round(serv * fl)
    });

    C += serv * c; P += serv * p; Na += serv * na; Fl += serv * fl;
    if (items.length >= 3) break;
  }

  // If still short, attempt to top-up with any remaining top items
  for (const x of top.map(ti => ti.ref)) {
    if (items.length >= 4) break;
    if (C >= t.after.carbs_g && P >= t.after.protein_g) break;
    if (roster.includes(x)) continue;

    const c = x.carbs_per_serving ?? 0;
    const p = x.protein_per_serving ?? 0;
    const na = x.sodium_mg ?? 0;
    const fl = x.fluid_ml_per_serving ?? 0;
    if (c + p + na + fl <= 0) continue;

    let serv = 1;
    items.push({
      name: x.name,
      servings: serv,
      carbs_g: rnd(serv * c),
      protein_g: rnd(serv * p),
      sodium_mg: Math.round(serv * na),
      fluid_ml: Math.round(serv * fl)
    });
    C += serv * c; P += serv * p; Na += serv * na; Fl += serv * fl;
  }

  return {
    items,
    targets: t.after,
    totals: { carbs_g: rnd(C), protein_g: rnd(P), sodium_mg: Math.round(Na), fluid_ml: Math.round(Fl) }
  };
}

// Nutritional adequacy validation
function validatePlan(plan: Plan, targets: Targets): { warnings: string[] } {
  const warnings: string[] = [];
  
  // Check during-run carb adequacy
  const actualCarbs = plan.during.events.reduce((sum, e) => sum + e.carbs_g, 0);
  const carbsShortfall = targets.during.carbs_g_total - actualCarbs;
  
  if (carbsShortfall > targets.during.carbs_g_total * 0.2) {
    warnings.push(`Carb intake ${Math.round(carbsShortfall)}g below target - consider more sports drinks`);
  }
  
  // Check hydration adequacy
  const actualFluid = plan.during.events.reduce((sum, e) => sum + e.fluid_ml, 0);
  const fluidTarget = targets.during.fluid_ml_per_h * (targets.during.carbs_g_total / targets.during.carbs_g_per_h);
  const fluidShortfall = fluidTarget - actualFluid;
  
  if (fluidShortfall > fluidTarget * 0.3) {
    warnings.push(`Fluid intake ${Math.round(fluidShortfall)}ml below target - add more drinks`);
  }
  
  // Check after-run protein
  const actualProtein = plan.after.totals.protein_g;
  if (actualProtein < targets.after.protein_g * 0.7) {
    warnings.push(`Recovery protein low - consider protein-rich options`);
  }
  
  return { warnings };
}

// Get basic fallback plan for errors
function getBasicFallbackPlan(weightKg: number, durationMin: number): Plan {
  const durationH = durationMin / 60;
  return {
    before: {
      items: [{ name: "Oatmeal (fallback)", servings: 1, carbs_g: 30 }],
      fluid_ml_sip: 400
    },
    during: {
      per_interval_targets: { carbs_g: 25, sodium_mg: 75, fluid_ml: 200 },
      events: Array.from({ length: Math.ceil(durationMin / 30) }, (_, i) => ({
        at_min: (i + 1) * 30,
        item: "Sports drink (fallback)",
        servings: 1,
        carbs_g: 14,
        sodium_mg: 110,
        fluid_ml: 240
      }))
    },
    after: {
      items: [{ 
        name: "Chocolate milk (fallback)", 
        servings: 1, 
        carbs_g: 26, 
        protein_g: 8, 
        sodium_mg: 150, 
        fluid_ml: 240 
      }],
      targets: { carbs_g: weightKg, protein_g: weightKg * 0.3, fluid_ml: 600, sodium_mg: 500 },
      totals: { carbs_g: 26, protein_g: 8, sodium_mg: 150, fluid_ml: 240 }
    }
  };
}

// ---- In-memory 5-min cache for foods & after ids
let foodsCache: { at: number; rows: Food[] } | null = null;
let afterIdsCache: { at: number; ids: Set<string> } | null = null;

async function getFoodsCached() {
  const now = Date.now();
  if (foodsCache && now - foodsCache.at < 5 * 60 * 1000) return foodsCache.rows;
  const rows = await fetchFoods();
  foodsCache = { at: now, rows };
  return rows;
}

async function getAfterIdsCached() {
  const now = Date.now();
  if (afterIdsCache && now - afterIdsCache.at < 5 * 60 * 1000) return afterIdsCache.ids;
  const ids = await fetchAfterEligibleIds();
  afterIdsCache = { at: now, ids };
  return ids;
}

// ---- HTTP handler
Deno.serve(async (req: Request) => {
  const requestStart = Date.now();
  
  try {
    if (req.method !== "POST") {
      return json({ error: "Use POST with JSON body" }, 405);
    }
    const body: Inputs = await req.json();
    
    // Enhanced input validation
    const validationErrors = validateInputs(body);
    if (validationErrors.length > 0) {
      return json({ error: "Validation failed", details: validationErrors }, 400);
    }
    
    console.log(`Nutrition request: weight=${body.weightKg}kg, duration=${body.durationMin}min, user=${body.deviceId || 'anonymous'}`);
    const gi = body.giSensitivity ?? "normal";
    const interval = body.intervalMinutes ?? (body.allowHighCarbRun ? 20 : 30);

    // Targets
    const targets = calcTargets(body);

    // Data fetch
    const [foods, prefs, afterIds] = await Promise.all([getFoodsCached(), fetchPrefs(body.deviceId), getAfterIdsCached()]);
    
    // Get fallback foods for edge cases
    const fallbackFoods = getFallbackFoods(foods);

    // Selections
    const topBefore = pickTop(foods, prefs, "before", targets, gi);
    const topDuring = pickTop(foods, prefs, "during", targets, gi);
    const topAfter  = pickTop(foods, prefs, "after",  targets, gi, afterIds);

    // Plans
    const prePlan = buildPre(topBefore, targets.before.carbs_g, targets.before.sodium_mg);
    const duringPlan = buildDuring(topDuring, targets, body.durationMin, interval, gi, fallbackFoods);
    const afterPlan = buildAfter(topAfter, targets);
    
    // Validate plan adequacy
    const plan = {
      before: { ...prePlan, fluid_ml_sip: targets.before.fluid_ml },
      during: duringPlan,
      after: afterPlan
    };
    const validation = validatePlan(plan, targets);

    // Optional ACSM
    const acsm = body.paceMinPerKm ? acsmFromPace(body.weightKg, body.paceMinPerKm, body.durationMin / 60) : null;
    const processingTime = Date.now() - requestStart;
    
    console.log(`Request completed in ${processingTime}ms`);
    
    const response: any = {
      inputs: { ...body, intervalMinutes: interval },
      targets,
      plan,
      info: acsm ?? undefined
    };
    
    // Add warnings if any
    if (validation.warnings.length > 0) {
      response.warnings = validation.warnings;
    }
    
    // Add debug information if requested
    if (body.debug) {
      response.debug = {
        processing_time_ms: processingTime,
        food_counts: {
          total_foods: foods.length,
          before_eligible: foods.filter(f => f.before_run_suitable).length,
          during_eligible: foods.filter(f => f.during_run_suitable && f.run_portable).length,
          after_eligible: afterIds.size
        },
        top_scores: {
          before: topBefore.slice(0, 3).map(x => ({ name: x.ref.name, score: Math.round(x.score) })),
          during: topDuring.slice(0, 3).map(x => ({ name: x.ref.name, score: Math.round(x.score) })),
          after: topAfter.slice(0, 3).map(x => ({ name: x.ref.name, score: Math.round(x.score) }))
        },
        fallback_foods: {
          gel: fallbackFoods.gel?.name,
          drink: fallbackFoods.drink?.name,
          recovery: fallbackFoods.recovery?.name
        }
      };
    } else {
      // Add selections for non-debug mode
      response.selections = {
        before_top_choices: topBefore.map(x => ({ name: x.ref.name, score: Math.round(x.score) })),
        during_top_choices: topDuring.map(x => ({ name: x.ref.name, score: Math.round(x.score) })),
        after_top_choices: topAfter.map(x => ({ name: x.ref.name, score: Math.round(x.score) }))
      };
    }
    
    return json(response);

  } catch (e) {
    console.error("Nutrition planner error:", e);
    
    // Try to return a basic fallback plan if we have weight and duration
    try {
      const basicInputs = await req.json();
      if (basicInputs.weightKg && basicInputs.durationMin) {
        return json({
          error: "Algorithm error - returning basic plan",
          plan: getBasicFallbackPlan(basicInputs.weightKg, basicInputs.durationMin),
          targets: calcTargets(basicInputs)
        }, 500);
      }
    } catch (e2) {
      // Ignore error parsing fallback
    }
    
    return json({ error: String(e) }, 500);
  }
});
