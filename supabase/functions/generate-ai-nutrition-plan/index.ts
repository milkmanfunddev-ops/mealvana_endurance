// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------------- CORS ----------------
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ---------------- Types ----------------
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
  before_run_suitable: boolean | null;
  during_run_suitable: boolean | null;
  run_portable: boolean | null;
  aid_station_available: boolean | null;
  max_servings_before: number | null;
  max_servings_during: number | null;
  product_type: string | null;
  brand_id: string | null;
  purchase_url: string | null;
  affiliate_source: string | null;
}

// ---------------- Config ----------------
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const OPENAI_API_URL = "https://api.openai.com/v1/chat/completions";
type Mode = "generic" | "branded" | "any";
const RECOMMENDATION_MODE: Mode = (Deno.env.get("RECOMMENDATION_MODE") ??
  "generic") as Mode; // default keeps current behavior

// ---------------- Helpers ----------------
function generateQuantityDisplay(food: FoodRow, customAmount?: number): string {
  const baseAmt = food.serving_amount ?? 1.0;
  const amount = customAmount ?? baseAmt;
  const amountStr =
    amount === Math.floor(amount) ? Math.floor(amount).toString() : amount.toFixed(1);

  const unit =
    amount > 1 && food.serving_unit_plural?.trim()
      ? food.serving_unit_plural
      : food.serving_unit ?? "serving";

  const parts = [amountStr, unit];
  if (food.serving_qualifier?.trim()) parts.push(food.serving_qualifier);
  parts.push((food.name || "").toLowerCase());
  return parts.join(" ");
}

function safeArr<T = string>(v: T[] | undefined | null): T[] {
  return Array.isArray(v) ? v : [];
}

function selectTop<T>(arr: T[], n: number): T[] {
  return arr.slice(0, Math.max(0, n));
}

// Simple ranking for each phase (tunable but cheap)
function rankBefore(a: FoodRow, b: FoodRow): number {
  // prefer bars/waffles/gels with lower fat for before, then carbs
  const ptScore = (f: FoodRow) =>
    ["bar", "waffle", "gel", "drink_mix"].indexOf(f.product_type || "") >= 0 ? 1 : 0;
  const fa = (a.fat_per_serving ?? 0);
  const fb = (b.fat_per_serving ?? 0);
  const c = (b.carbs_per_serving ?? 0) - (a.carbs_per_serving ?? 0);
  const pf = ptScore(b) - ptScore(a);
  return pf || (fa - fb) || c;
}

function rankDuring(a: FoodRow, b: FoodRow): number {
  // prefer portable + aid station + classic during types, then carbs
  const typeRank = (f: FoodRow) => {
    const t = f.product_type || "";
    if (["gel", "chew"].includes(t)) return 3;
    if (["drink_mix", "sports_drink"].includes(t)) return 2;
    if (["electrolyte_only", "capsule"].includes(t)) return 1;
    return 0;
  };
  const portable = Number(!!b.run_portable) - Number(!!a.run_portable);
  const aid = Number(!!b.aid_station_available) - Number(!!a.aid_station_available);
  const tr = typeRank(b) - typeRank(a);
  const carbs = (b.carbs_per_serving ?? 0) - (a.carbs_per_serving ?? 0);
  return tr || aid || portable || carbs;
}

function rankAfter(a: FoodRow, b: FoodRow): number {
  // prefer recovery_shake/bar with higher protein, then carbs
  const typeRank = (f: FoodRow) =>
    f.product_type === "recovery_shake" ? 2 : f.product_type === "bar" ? 1 : 0;
  const tr = typeRank(b) - typeRank(a);
  const protein = (b.protein_per_serving ?? 0) - (a.protein_per_serving ?? 0);
  const carbs = (b.carbs_per_serving ?? 0) - (a.carbs_per_serving ?? 0);
  return tr || protein || carbs;
}

function buildCandidate(f: FoodRow) {
  return {
    id: f.id,
    name: f.name,
    carbs: f.carbs_per_serving ?? 0,
    sodium: f.sodium_mg ?? 0,
    water: f.fluid_ml_per_serving ?? 0,
    max:
      (f.max_servings_during ?? f.max_servings_before ?? 5) > 0
        ? (f.max_servings_during ?? f.max_servings_before ?? 5)
        : 5,
    unit: f.serving_unit ?? "serving",
    amt: f.serving_amount ?? 1,
    qual: f.serving_qualifier ?? "",
  };
}

// ---------------- Server ----------------
serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (!OPENAI_API_KEY) {
      console.error("OPENAI_API_KEY is not configured in edge function secrets");
      return new Response(
        JSON.stringify({
          success: false,
          message: "AI service not configured. Please contact support.",
          fallback_to_algorithm: true,
        }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Supabase
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const requestData: NutritionPlanRequest = await req.json();

    // Basic validation
    if (!requestData.device_id || !requestData.macro_targets) {
      return new Response(
        JSON.stringify({
          success: false,
          message: "Missing required fields: device_id and macro_targets are required",
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }
    const { pre_run, during_run, post_run } = requestData.macro_targets || {};
    if (!pre_run || !during_run || !post_run) {
      return new Response(
        JSON.stringify({
          success: false,
          message:
            "Invalid macro_targets structure: pre_run, during_run, and post_run phases required",
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Pull user preferences (view)
    const { data: userPrefs } = await supabase
      .from("user_food_preferences_categorized")
      .select("*")
      .eq("device_id", requestData.device_id)
      .maybeSingle();

    const likedFoods = safeArr(userPrefs?.liked_foods) || safeArr(requestData.liked_foods);
    const willingToTryFoods =
      safeArr(userPrefs?.willing_to_try_foods) || safeArr(requestData.willing_to_try_foods);
    const dislikedFoods = new Set(safeArr(requestData.disliked_foods));

    // ---- Fetch foods with DB-side brand filter ----
    let foodsQuery = supabase
      .from("foods")
      .select(`
        id, name, image_address,
        calories_per_serving, carbs_per_serving, protein_per_serving, fat_per_serving,
        sodium_mg, fluid_ml_per_serving,
        serving_amount, serving_unit, serving_unit_plural, serving_qualifier,
        before_run_suitable, during_run_suitable, run_portable, aid_station_available,
        max_servings_before, max_servings_during,
        product_type, brand_id
      `);

    if (RECOMMENDATION_MODE === "generic") {
      foodsQuery = foodsQuery.is("brand_id", null);
    } else if (RECOMMENDATION_MODE === "branded") {
      foodsQuery = foodsQuery.not("brand_id", "is", null);
    } // 'any' => no brand filter

    const { data: allFoods, error: foodsError } = await foodsQuery;
    if (foodsError || !allFoods) {
      console.error("Error fetching foods:", foodsError);
      return new Response(
        JSON.stringify({ success: false, message: "Failed to fetch food database" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Remove disliked
    const notDisliked = (f: FoodRow) => !dislikedFoods.has(f.name);

    // Build phase pools (better signals)
    const beforePool = (allFoods as FoodRow[])
      .filter((f) => (f.before_run_suitable ?? false))
      .filter(notDisliked)
      .sort(rankBefore);

    const duringPool = (allFoods as FoodRow[])
      .filter((f) => (f.during_run_suitable ?? false) || (f.run_portable ?? false))
      .filter(notDisliked)
      .sort(rankDuring);

    const afterPool = (allFoods as FoodRow[])
      .filter((f) => {
        // Prefer explicit recovery types; otherwise protein >= 10 and not marked as before/during
        const isRecoveryType =
          f.product_type === "recovery_shake" || f.product_type === "bar";
        const isProteinRich = (f.protein_per_serving ?? 0) >= 10;
        const notBeforeOrDuring = !(f.before_run_suitable ?? false) && !(f.during_run_suitable ?? false);
        return isRecoveryType || (isProteinRich && notBeforeOrDuring);
      })
      .filter(notDisliked)
      .sort(rankAfter);

    // Preference trim (fallback to pools if empty)
    const likeSet = new Set(likedFoods);
    const trySet = new Set(willingToTryFoods);

    const prefer = (arr: FoodRow[]) => {
      const picked = arr.filter((f) => likeSet.has(f.name) || trySet.has(f.name));
      return picked.length ? picked : arr;
    };

    const beforeCandidates = selectTop(prefer(beforePool), 10).map(buildCandidate);
    const duringCandidates = selectTop(prefer(duringPool), 12).map(buildCandidate);
    const afterCandidates = selectTop(prefer(afterPool), 10).map(buildCandidate);

    // Nothing to work with?
    if (!beforeCandidates.length && !duringCandidates.length && !afterCandidates.length) {
      return new Response(
        JSON.stringify({
          success: false,
          message:
            "No eligible foods found for the selected mode and preferences. Try adjusting preferences or mode.",
        }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Compute run duration (debug)
    const durationHours =
      (requestData.distance_miles * requestData.pace_minutes_per_mile) / 60;

    // ---------------- Model Call (IDs in, same JSON shape out) ----------------
    const systemPrompt =
      `You are a sports dietitian. Build a long-run fueling plan that meets per-phase carb targets within ±10g.

CRITICAL: You MUST calculate actual carbs by multiplying each food's carbs_per_serving by the servings you select.
For example: If you select 2 servings of a food with 27g carbs, that contributes 54g total carbs.

Before selecting foods:
1. Calculate the total carbs for each phase by multiplying (food carbs × servings) for all selected items
2. Verify your totals match the targets within ±10g
3. Adjust servings if needed to hit targets

Also consider sodium and water (during-run especially). Use 0..max servings per item.
Return ONLY the requested JSON shape with IDs (we will map to names):`;

    const userPayload = {
      run: {
        distance_miles: requestData.distance_miles,
        pace_min_per_mile: requestData.pace_minutes_per_mile,
        duration_hours: Number(durationHours.toFixed(2)),
      },
      targets: requestData.macro_targets,
      candidates: {
        before: beforeCandidates,
        during: duringCandidates,
        after: afterCandidates,
      },
      output_contract: {
        // Keep your existing contract for the final API response,
        // but ask the model to use IDs internally so we can map safely.
        detailed_message: "string",
        solution: {
          // Model should return [{ id, servings }] for each phase.
          before: [{ id: "uuid", servings: "number" }],
          during: [{ id: "uuid", servings: "number" }],
          after: [{ id: "uuid", servings: "number" }],
        },
        carbs_check: {
          before_total: "number",
          during_total: "number",
          after_total: "number",
        },
      },
    };

    // Optional: log trimmed
    const promptLog = JSON.stringify(userPayload).slice(0, 1200);
    console.log("📝 USER PAYLOAD (trimmed):", promptLog + (promptLog.length >= 1200 ? "…": ""));

    const openAIResponse = await fetch(OPENAI_API_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: JSON.stringify(userPayload) },
        ],
        temperature: 0.0,
        max_completion_tokens: 2000,
        response_format: { type: "json_object" },
      }),
    });

    if (!openAIResponse.ok) {
      const errorText = await openAIResponse.text();
      console.error("OpenAI API error:", errorText);
      return new Response(
        JSON.stringify({
          success: false,
          message: "Failed to generate nutrition plan from AI",
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const aiJson = await openAIResponse.json();
    console.log("🔍 DEBUG: AI response received");
    console.log("🔍 DEBUG: Raw AI response content:", aiJson.choices[0].message.content);

    // The model returns JSON as a string in message.content
    let aiSolution: any;
    try {
      aiSolution = JSON.parse(aiJson.choices[0].message.content);
      console.log("🔍 DEBUG: Parsed AI solution:", JSON.stringify(aiSolution));
    } catch (_e) {
      console.error("❌ Failed to parse AI content. Content:", aiJson.choices[0].message.content);
      return new Response(
        JSON.stringify({ success: false, message: "Invalid AI response" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Build maps for lookup
    const foodById = new Map<string, FoodRow>((allFoods as FoodRow[]).map((f) => [f.id, f]));
    const foodByName = new Map<string, FoodRow>((allFoods as FoodRow[]).map((f) => [f.name, f]));
    console.log("🔍 DEBUG: Built food maps - foodById:", foodById.size, "foodByName:", foodByName.size);

    // Supports either {id, servings} or {food_name, servings} (back-compat)
    function normalizePhaseItems(items: any[]): { id: string; servings: number }[] {
      console.log("🔍 DEBUG: Normalizing phase items:", JSON.stringify(items));
      const result = (items || [])
        .map((it) => {
          if (it?.id) {
            console.log("🔍 DEBUG: Found ID-based item:", it.id, "servings:", it.servings);
            return { id: String(it.id), servings: Number(it.servings || 0) };
          }
          if (it?.food_name) {
            console.log("🔍 DEBUG: Found name-based item:", it.food_name, "servings:", it.servings);
            const f = foodByName.get(String(it.food_name));
            if (f) {
              console.log("🔍 DEBUG: Mapped name to ID:", it.food_name, "->", f.id);
              return { id: f.id, servings: Number(it.servings || 0) };
            } else {
              console.log("❌ DEBUG: Could not find food by name:", it.food_name);
            }
          }
          console.log("❌ DEBUG: Could not normalize item:", JSON.stringify(it));
          return null;
        })
        .filter(Boolean) as { id: string; servings: number }[];
      console.log("🔍 DEBUG: Normalized result:", JSON.stringify(result));
      return result;
    }

    const sol = aiSolution?.solution || {};
    console.log("🔍 DEBUG: AI solution object:", JSON.stringify(sol));
    const phaseIds = {
      before: normalizePhaseItems(sol.before),
      during: normalizePhaseItems(sol.during),
      after: normalizePhaseItems(sol.after),
    };
    console.log("🔍 DEBUG: Phase IDs after normalization:", JSON.stringify(phaseIds));

    function convertSolutionToNutritionPlan(phase: "before" | "during" | "after", items: { id: string; servings: number }[]) {
      console.log(`🔍 DEBUG: Converting ${phase} phase with items:`, JSON.stringify(items));
      const defaultTiming =
        phase === "before" ? "2-3 hours before" : phase === "during" ? "Throughout run" : "Within 30 minutes";
      const result = items
        .filter((it) => {
          const hasServings = it.servings > 0;
          console.log(`🔍 DEBUG: ${phase} item ${it.id} has servings > 0:`, hasServings);
          return hasServings;
        })
        .map((it) => {
          const f = foodById.get(it.id);
          console.log(`🔍 DEBUG: Looking up food by ID ${it.id}:`, f ? f.name : 'NOT FOUND');
          if (!f) {
            console.log(`❌ DEBUG: Food not found for ID: ${it.id}`);
            return null;
          }
          const servings = it.servings;
          const customAmount = servings * (f.serving_amount ?? 1);
          const planItem = {
            food_name: f.name, // <-- preserve contract
            description: generateQuantityDisplay(f, customAmount),
            image_address: f.image_address, // Include the online image URL
            timing: defaultTiming,
            servings,
            carbs_grams: (f.carbs_per_serving ?? 0) * servings,
            calories: (f.calories_per_serving ?? 0) * servings,
            protein_grams: (f.protein_per_serving ?? 0) * servings,
            fat_grams: (f.fat_per_serving ?? 0) * servings,
            sodium_mg: (f.sodium_mg ?? 0) * servings,
            fluids_ml: (f.fluid_ml_per_serving ?? 0) * servings,
          };
          console.log(`🔍 DEBUG: Created plan item for ${f.name}:`, JSON.stringify(planItem));
          return planItem;
        })
        .filter(Boolean) as any[];
      console.log(`🔍 DEBUG: Final ${phase} plan:`, JSON.stringify(result));
      return result;
    }

    const planBefore = convertSolutionToNutritionPlan("before", phaseIds.before);
    console.log("🔍 DEBUG: planBefore completed");
    const planDuring = convertSolutionToNutritionPlan("during", phaseIds.during);
    console.log("🔍 DEBUG: planDuring completed");
    const planAfter = convertSolutionToNutritionPlan("after", phaseIds.after);
    console.log("🔍 DEBUG: planAfter completed");

    // Backend totals
    const sum = (arr: any[], key: string) =>
      arr.reduce((s, it) => s + (Number(it[key]) || 0), 0);

    const aiBeforeCarbs = sum(planBefore, "carbs_grams");
    const aiDuringCarbs = sum(planDuring, "carbs_grams");
    const aiAfterCarbs = sum(planAfter, "carbs_grams");

    console.log("🚨 MACROS CHECK:", {
      AI_BEFORE_CARBS: aiBeforeCarbs,
      AI_DURING_CARBS: aiDuringCarbs,
      AI_AFTER_CARBS: aiAfterCarbs,
      EXPECTED_BEFORE: pre_run.carbs_g,
      EXPECTED_DURING: during_run.carbs_total_g,
      EXPECTED_AFTER: post_run.carbs_g,
    });

    // Build final response (UNCHANGED SHAPE)
    console.log("🔍 DEBUG: Building final response...");
    const planId = `ai-plan-${Date.now()}-${requestData.device_id.slice(-6)}`;
    console.log("🔍 DEBUG: Plan ID generated:", planId);
    
    const nutritionPlan = {
      detailed_message: aiSolution.detailed_message,
      plan: {
        before: planBefore,
        during: planDuring,
        after: planAfter,
      },
    };
    console.log("🔍 DEBUG: Nutrition plan object created:", JSON.stringify(nutritionPlan));

    // Save (best effort)
    console.log("🔍 DEBUG: Attempting to save plan to database...");
    const { error: saveError } = await supabase.from("nutrition_plans").insert({
      device_id: requestData.device_id,
      plan_id: planId,
      plan_name: "AI-Generated Nutrition Plan",
      plan_data: JSON.stringify(nutritionPlan),
      distance_miles: requestData.distance_miles,
      pace_minutes_per_mile: requestData.pace_minutes_per_mile,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    });
    if (saveError) {
      console.error("❌ Error saving plan:", saveError);
    } else {
      console.log("✅ DEBUG: Plan saved successfully");
    }

    // Return EXACT same contract your frontend expects
    console.log("🔍 DEBUG: Building final response object...");
    const response = {
      success: true,
      plan_id: planId,
      detailed_message: nutritionPlan.detailed_message,
      plan: nutritionPlan.plan,
      macro_targets: {
        pre_run: {
          carbs_g: pre_run.carbs_g,
          protein_g: pre_run.protein_g,
          fat_g: pre_run.fat_g,
          water_ml: pre_run.water_ml,
          sodium_mg: pre_run.sodium_mg,
        },
        during_run: {
          carbs_total_g: during_run.carbs_total_g,
          sodium_total_mg: during_run.sodium_total_mg,
          water_total_ml: during_run.water_total_ml,
        },
        post_run: {
          carbs_g: post_run.carbs_g,
          protein_g: post_run.protein_g,
          fat_g: post_run.fat_g,
          water_ml: post_run.water_ml,
          sodium_mg: post_run.sodium_mg,
        },
      },
    };
    console.log("🔍 DEBUG: Final response object:", JSON.stringify(response));

    console.log("🔍 DEBUG: Sending response...");
    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error: any) {
    console.error("🚨 UNEXPECTED ERROR:", error);
    return new Response(
      JSON.stringify({
        success: false,
        message: `Internal server error: ${error?.message ?? "unknown"}`,
        fallback_to_algorithm: true,
        debug_error: String(error),
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
