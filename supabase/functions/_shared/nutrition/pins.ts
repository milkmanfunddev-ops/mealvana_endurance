/**
 * Pin Fetcher — Formula Kit PR 2 substep 5
 *
 * Reads the user's active formula pins from `formula_pins` and returns them
 * split by template kind. Orchestrators thread these Sets into the shared
 * pre-workout, during-workout, and post-workout selectors so an in-scope pin
 * can override normal candidate selection (locked policy 2026-05-21, revised
 * 2026-05-22 — pins bypass allergen/diet/dislike/gut-training filters and the
 * [min_servings, max_servings] scale clamp). After-phase pin support shipped
 * in PR 3 substep 7 with the same bypass semantics.
 *
 * Pin scope check itself happens inside the algorithm (time_window match for
 * before; activity_type × duration_bracket overlap for during; activity_type
 * overlap only for after — post templates have no duration brackets). This
 * file just provides the candidate set.
 *
 * Used by both `generate-macros-v4` (before-phase selection happens there) and
 * `generate-nutrition-plan-v3` (during-phase selection, plus before-phase
 * fallback when the client doesn't pass pre_run_selections). Originally lived
 * in `generate-nutrition-plan-v3/pins.ts` in 5b; moved to `_shared/nutrition/`
 * in the 5b-followup once we discovered before-phase selection happens in
 * macros-v4, not plan-v3.
 *
 * Behavior contract:
 * - No device_id → returns empty sets (no pins applied; byte-identical to
 *   pre-pin behavior).
 * - No matching user row for the device_id → returns empty sets.
 * - User exists, zero non-deleted pins → returns empty sets.
 *
 * Notes:
 * - `formula_pins` is keyed by `user_id`, not `device_id`. We follow the same
 *   device_id → user_id lookup pattern used by `fetchUserFoodsForBefore`.
 * - Soft-deleted pins (`is_deleted = true`) are excluded — the partial
 *   `formula_pins_user_kind` index targets the same predicate.
 * - `template_kind = 'personal_formula'` pins are fetched + resolved here (into
 *   `personalFormulas`) and honored by the DURING and AFTER phase solvers
 *   (see `personal-formula-pins.ts`). BEFORE-phase honoring on the edge path is
 *   not wired yet — the macros-v4 before output is a structured TemplateSelection,
 *   not a flat food list — so before personal-formula pins take effect via the
 *   client fallback only for now.
 */

import type { createServiceClient } from "../supabase-client.ts";

/**
 * A pinned user-authored personal formula (template_kind = 'personal_formula').
 *
 * Unlike the system-template pins (which are just IDs into the system template
 * tables), a personal formula is self-contained: it carries its own phase,
 * scope, and components. The components array snapshots each food's per-serving
 * macros at edit time, so the solver can emit a pinned personal formula with no
 * extra food lookups. Resolved from `personal_formulas` at fetch time.
 */
export interface PersonalFormulaPin {
  id: string;
  name: string;
  phase: "before" | "during" | "after";
  /** during/after activity-type scope (storage values), or null = any. */
  activities: string[] | null;
  /** during duration-bracket scope (storage values), or null = any. */
  durations: string[] | null;
  /** before sub-phase scope (full_meal | snack | top_up), or null = any. */
  subPhase: string | null;
  /** Opaque component objects ({ food_name, quantity, *_per_serving, ... }). */
  components: Array<Record<string, unknown>>;
}

export interface UserPinSets {
  /** Pinned pre_workout_templates.id values (template_kind = 'pre_system'). */
  beforePinIds: Set<string>;
  /** Pinned during_workout_templates.id values (template_kind = 'during_system'). */
  duringPinIds: Set<string>;
  /** Pinned post_workout_templates.id values (template_kind = 'post_system').
   * Added in Formula Kit PR 3 substep 7 — same offline-first repository write
   * path as the other two kinds, just routed to the after-phase solver. */
  afterPinIds: Set<string>;
  /** Pinned user-authored personal formulas (template_kind = 'personal_formula'),
   * resolved from `personal_formulas`. Phase-mixed; consumers filter by phase.
   * Honored by the during + after solvers; before-phase honoring on the edge
   * path is not wired yet (see header note). */
  personalFormulas: PersonalFormulaPin[];
}

/** Return a fresh set of empty pin sets. Never share a single mutable
 * instance across requests — Deno keeps modules alive between invocations,
 * so a singleton with mutable `Set` fields would leak `.add()` mutations
 * across concurrent users. */
function emptyPins(): UserPinSets {
  return {
    beforePinIds: new Set(),
    duringPinIds: new Set(),
    afterPinIds: new Set(),
    personalFormulas: [],
  };
}

export async function fetchUserPinnedTemplateIds(
  supabase: ReturnType<typeof createServiceClient>,
  deviceId: string | undefined,
): Promise<UserPinSets> {
  if (!deviceId) return emptyPins();

  // device_id → user_id (same pattern as before-phase-substitution.ts)
  const { data: userData } = await supabase
    .from("users")
    .select("id")
    .eq("device_id", deviceId)
    .single();

  const userId = userData?.id;
  if (!userId) {
    console.log("[PINS] No user found for device_id, no pins applied");
    return emptyPins();
  }

  const { data: pinRows, error } = await supabase
    .from("formula_pins")
    .select("template_id, template_kind")
    .eq("user_id", userId)
    .eq("is_deleted", false);

  if (error) {
    console.warn(
      `[PINS] formula_pins query failed: ${error.message} — falling back to empty pins`,
    );
    return emptyPins();
  }

  const beforePinIds = new Set<string>();
  const duringPinIds = new Set<string>();
  const afterPinIds = new Set<string>();
  const personalFormulaIds = new Set<string>();

  for (const row of pinRows ?? []) {
    const kind = (row as { template_kind?: string }).template_kind;
    const id = (row as { template_id?: string }).template_id;
    if (!id) continue;
    if (kind === "pre_system") beforePinIds.add(id);
    else if (kind === "during_system") duringPinIds.add(id);
    else if (kind === "post_system") afterPinIds.add(id);
    else if (kind === "personal_formula") personalFormulaIds.add(id);
  }

  const personalFormulas = await resolvePersonalFormulaPins(
    supabase,
    personalFormulaIds,
  );

  console.log(
    `[PINS] Loaded pins for user: before=${beforePinIds.size}, during=${duringPinIds.size}, after=${afterPinIds.size}, personal=${personalFormulas.length}`,
  );

  return { beforePinIds, duringPinIds, afterPinIds, personalFormulas };
}

/**
 * Resolve pinned personal-formula IDs into self-contained
 * [PersonalFormulaPin] objects from `personal_formulas`. Soft-deleted rows are
 * excluded. Returns [] when there are no personal-formula pins.
 */
async function resolvePersonalFormulaPins(
  supabase: ReturnType<typeof createServiceClient>,
  ids: Set<string>,
): Promise<PersonalFormulaPin[]> {
  if (ids.size === 0) return [];

  const { data, error } = await supabase
    .from("personal_formulas")
    .select(
      "id, name, phase, activities, durations, sub_phase, components, is_deleted",
    )
    .in("id", Array.from(ids))
    .eq("is_deleted", false);

  if (error) {
    console.warn(
      `[PINS] personal_formulas query failed: ${error.message} — ignoring personal pins`,
    );
    return [];
  }

  const toStringArray = (v: unknown): string[] | null =>
    Array.isArray(v) ? v.map((e) => String(e)) : null;

  return (data ?? [])
    .map((row): PersonalFormulaPin | null => {
      const r = row as Record<string, unknown>;
      const phase = r.phase as string | undefined;
      if (phase !== "before" && phase !== "during" && phase !== "after") {
        return null; // forward-compat: skip unknown phases
      }
      return {
        id: String(r.id),
        name: (r.name as string | undefined) ?? "Your formula",
        phase,
        activities: toStringArray(r.activities),
        durations: toStringArray(r.durations),
        subPhase: (r.sub_phase as string | null) ?? null,
        components: Array.isArray(r.components)
          ? (r.components as Array<Record<string, unknown>>)
          : [],
      };
    })
    .filter((p): p is PersonalFormulaPin => p !== null);
}
