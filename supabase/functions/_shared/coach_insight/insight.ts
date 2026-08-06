/**
 * Coach-insight nutrition-state computation + prompt building for the
 * `ai-coach` edge function (`mode: "insight"`).
 *
 * Pure functions only — no I/O, no LLM call — so the derived-state math and
 * the prompt shape can be unit-tested without the network. The handler in
 * `ai-coach/index.ts` validates the request, calls these, then calls the model.
 *
 * Per the Formula Kit plan (PR 6), coach insight uses **pre-computed structured
 * context injection, not live tool calling**: every algorithmic value the model
 * needs is computed here and injected into the prompt as a structured block.
 *
 * The draft components arrive already carrying per-serving macros + a quantity
 * multiplier (the client snapshots them — see Dart `FormulaMacros`), so the
 * totals here are recomputed server-side from those snapshots rather than
 * trusting client-sent totals. Fiber and per-food digestion speed are NOT in
 * the snapshot, so V1 omits them from the derived block (would require extra DB
 * lookups); the prompt still has macros + fluid + solid:liquid + sub-phase fit.
 */

// ---------------------------------------------------------------------------
// Wire types (mirror Dart CoachInsightContext / FormulaMacros component keys)
// ---------------------------------------------------------------------------

export type InsightPhase = "before" | "during" | "after";

export interface InsightComponent {
  food_name: string;
  quantity: number;
  carbs_per_serving?: number;
  protein_per_serving?: number;
  fat_per_serving?: number;
  /** Sodium per serving (mg). */
  sodium_mg?: number;
  fluid_ml_per_serving?: number;
  calories_per_serving?: number;
}

export interface InsightContext {
  phase: InsightPhase;
  /** Before only: 'meal' | 'snack' | 'top_up'. */
  sub_phase?: string | null;
  /** During only: storage values, e.g. ['60_90', '90_plus']. */
  durations?: string[] | null;
  /** During / after: storage values, e.g. ['run', 'bike']. */
  activities?: string[] | null;
  name?: string | null;
  components: InsightComponent[];
}

// ---------------------------------------------------------------------------
// Derived nutrition state
// ---------------------------------------------------------------------------

export type SubPhaseFit = "good" | "warn" | "poor";

export interface NutritionState {
  carbsG: number;
  proteinG: number;
  fatG: number;
  sodiumMg: number;
  fluidMl: number;
  calories: number;
  /** Grams of solid macro mass (carbs+protein+fat) : 1 mL fluid. Null when no fluid. */
  solidLiquidRatio: number | null;
  /** Carbs per hour, during phase only (uses the longest selected duration bracket). */
  carbsPerHour: number | null;
  subPhaseFit: SubPhaseFit;
}

function num(v: unknown): number {
  return typeof v === "number" && Number.isFinite(v) ? v : 0;
}

function round(v: number): number {
  return Math.round(v);
}

/**
 * Lower-bound hours for a during-phase duration storage value. The brackets
 * mirror the Dart `DuringDuration` enum (`under_60`, `60_90`, `90_plus`, …).
 * Used only to express a rough carbs/hour figure in the prompt.
 */
function durationLowerBoundHours(
  durations: string[] | null | undefined,
): number | null {
  if (!durations || durations.length === 0) return null;
  let maxHours = 0;
  for (const d of durations) {
    const h = (() => {
      switch (d) {
        case "under_60":
          return 0.75;
        case "60_90":
          return 1.25;
        case "90_180":
        case "90_plus":
          return 2;
        case "over_180":
        case "180_plus":
          return 3;
        default:
          return 0;
      }
    })();
    if (h > maxHours) maxHours = h;
  }
  return maxHours > 0 ? maxHours : null;
}

/**
 * Heuristic sub-phase fit for a Before formula, based on carb load. Top-ups are
 * meant to be small and fast; meals can be large. These thresholds are coarse
 * on purpose — they only nudge the prompt; the model writes the final wording.
 */
function beforeSubPhaseFit(
  subPhase: string | null | undefined,
  carbsG: number,
): SubPhaseFit {
  switch (subPhase) {
    case "top_up":
      if (carbsG <= 35) return "good";
      if (carbsG <= 55) return "warn";
      return "poor";
    case "snack":
      if (carbsG >= 20 && carbsG <= 70) return "good";
      if (carbsG <= 90) return "warn";
      return "poor";
    case "meal":
    case "full_meal":
      if (carbsG >= 45) return "good";
      if (carbsG >= 25) return "warn";
      return "poor";
    default:
      return "good";
  }
}

/** Timing meaning carried by the Formula Kit chip, made explicit to the model. */
function beforeTimingWindow(subPhase: string | null | undefined): string {
  switch (subPhase) {
    // Windows follow the ratified 120-minute meal boundary (D-017, 2026-08-05).
    case "full_meal":
    case "meal":
      return "2-4 hours before exercise";
    case "snack":
      return "30-120 minutes before exercise";
    case "top_up":
      return "less than 30 minutes before exercise";
    default:
      return "unspecified";
  }
}

/**
 * Resolve obvious pre-workout fuel problems without paying for an LLM call.
 * These are intentionally narrow rules: ambiguous formulas still go through
 * the model, while a low-carb snack (the reported milk regression) gets a
 * reliable, actionable answer every time.
 */
export function buildDeterministicInsight(
  context: InsightContext,
  state: NutritionState,
): string | null {
  if (context.phase !== "before") return null;

  if (context.sub_phase === "snack" && state.carbsG < 20) {
    const deficit = Math.max(1, 20 - state.carbsG);
    return `This snack provides ${state.carbsG} g carbs; add at least ${deficit} g of easy-to-digest carbohydrate—water alone will not add fuel.`;
  }
  if (context.sub_phase === "top_up" && state.carbsG < 15) {
    const deficit = Math.max(1, 15 - state.carbsG);
    return `This top-up provides ${state.carbsG} g carbs; add at least ${deficit} g of quick carbohydrate for useful pre-workout fuel.`;
  }
  return null;
}

/** Compute the structured nutrition state injected into the prompt. */
export function computeNutritionState(context: InsightContext): NutritionState {
  let carbs = 0;
  let protein = 0;
  let fat = 0;
  let sodium = 0;
  let fluid = 0;
  let calories = 0;

  for (const c of context.components) {
    const q = num(c.quantity) || 1;
    carbs += num(c.carbs_per_serving) * q;
    protein += num(c.protein_per_serving) * q;
    fat += num(c.fat_per_serving) * q;
    sodium += num(c.sodium_mg) * q;
    fluid += num(c.fluid_ml_per_serving) * q;
    calories += num(c.calories_per_serving) * q;
  }

  const solidMass = carbs + protein + fat;
  const solidLiquidRatio = fluid > 0
    ? Math.round((solidMass / fluid) * 10) / 10
    : null;

  const hours = context.phase === "during"
    ? durationLowerBoundHours(context.durations)
    : null;
  const carbsPerHour = hours && hours > 0 ? round(carbs / hours) : null;

  const subPhaseFit = context.phase === "before"
    ? beforeSubPhaseFit(context.sub_phase, round(carbs))
    : "good";

  return {
    carbsG: round(carbs),
    proteinG: round(protein),
    fatG: round(fat),
    sodiumMg: round(sodium),
    fluidMl: round(fluid),
    calories: round(calories),
    solidLiquidRatio,
    carbsPerHour,
    subPhaseFit,
  };
}

// ---------------------------------------------------------------------------
// Prompt building
// ---------------------------------------------------------------------------

export const COACH_INSIGHT_SYSTEM_PROMPT =
  `You are a coach for endurance athletes using the Mealvana Endurance app.
You review a draft nutrition formula and give one short, direct piece of guidance.
Voice: athlete-to-athlete, no fluff, no wellness-influencer tone, grounded in science.
Output 15-28 words, one or two sentences. End with a period, not an exclamation point.
Never use emoji. Reference specific numbers from the structured state when relevant.

If the formula is well-balanced for its phase and sub-phase, say so plainly.
If something is off — too low sodium for the duration, too much fiber for a "top-up",
solid:liquid skewed for during-workout — name the issue and one concrete fix
("consider adding a pinch of salt to the oatmeal").

Prioritize a stated carbohydrate shortfall over generic hydration advice.
Water can support hydration but never fixes an energy or carbohydrate shortfall.
Use the timing window when judging whether a food is appropriate before exercise.

Reply with the guidance sentence only. Do not restate the numbers as a list.`;

/** Build the user message injecting the structured nutrition state. */
export function buildInsightUserMessage(
  context: InsightContext,
  state: NutritionState,
): string {
  const lines: string[] = [];
  lines.push(`PHASE: ${context.phase}`);
  if (context.phase === "before") {
    lines.push(`SUB_PHASE: ${context.sub_phase ?? "unspecified"}`);
    lines.push(`TIMING_WINDOW: ${beforeTimingWindow(context.sub_phase)}`);
  }
  if (context.phase === "during") {
    const durations = context.durations?.length
      ? context.durations.join(", ")
      : "unspecified";
    lines.push(`WORKOUT_DURATIONS: ${durations}`);
  }
  if (context.activities?.length) {
    lines.push(`ACTIVITIES: ${context.activities.join(", ")}`);
  }
  if (context.name && context.name.trim().length > 0) {
    lines.push(`NAME: ${context.name.trim()}`);
  }

  lines.push("");
  lines.push("DRAFT COMPONENTS:");
  if (context.components.length === 0) {
    lines.push("- (none)");
  } else {
    for (const c of context.components) {
      const q = num(c.quantity) || 1;
      lines.push(`- ${c.food_name}: ${q}x serving`);
    }
  }

  lines.push("");
  lines.push("COMPUTED MACROS:");
  lines.push(`  carbs:     ${state.carbsG} g`);
  lines.push(`  protein:   ${state.proteinG} g`);
  lines.push(`  fat:       ${state.fatG} g`);
  lines.push(`  sodium:    ${state.sodiumMg} mg`);
  lines.push(`  fluid:     ${state.fluidMl} mL`);
  lines.push(`  calories:  ${state.calories} kcal`);

  lines.push("");
  lines.push("DERIVED:");
  lines.push(
    `  solid_liquid_ratio:  ${
      state.solidLiquidRatio === null
        ? "n/a (no fluid)"
        : `${state.solidLiquidRatio}:1`
    }`,
  );
  if (state.carbsPerHour !== null) {
    lines.push(`  carbs_per_hour:      ${state.carbsPerHour} g/h`);
  }
  if (context.phase === "before") {
    lines.push(`  sub_phase_fit:       ${state.subPhaseFit}`);
    if (context.sub_phase === "snack") {
      lines.push("  heuristic_carb_range: 20-70 g");
    } else if (context.sub_phase === "top_up") {
      lines.push("  heuristic_carb_range: 15-35 g");
    } else if (
      context.sub_phase === "full_meal" || context.sub_phase === "meal"
    ) {
      lines.push("  heuristic_carb_floor: 45 g");
    }
  }

  lines.push("");
  lines.push("Give your guidance.");
  return lines.join("\n");
}
