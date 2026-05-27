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
 * - `template_kind = 'personal_template'` is reserved for PR 4 and is not
 *   threaded through the algorithm yet; we ignore those rows here. v1 pin
 *   policy is system templates only.
 */

import type { createServiceClient } from "../supabase-client.ts";

export interface UserPinSets {
  /** Pinned pre_workout_templates.id values (template_kind = 'pre_system'). */
  beforePinIds: Set<string>;
  /** Pinned during_workout_templates.id values (template_kind = 'during_system'). */
  duringPinIds: Set<string>;
  /** Pinned post_workout_templates.id values (template_kind = 'post_system').
   * Added in Formula Kit PR 3 substep 7 — same offline-first repository write
   * path as the other two kinds, just routed to the after-phase solver. */
  afterPinIds: Set<string>;
}

const EMPTY_PINS: UserPinSets = {
  beforePinIds: new Set(),
  duringPinIds: new Set(),
  afterPinIds: new Set(),
};

export async function fetchUserPinnedTemplateIds(
  supabase: ReturnType<typeof createServiceClient>,
  deviceId: string | undefined,
): Promise<UserPinSets> {
  if (!deviceId) return EMPTY_PINS;

  // device_id → user_id (same pattern as before-phase-substitution.ts)
  const { data: userData } = await supabase
    .from("users")
    .select("id")
    .eq("device_id", deviceId)
    .single();

  const userId = userData?.id;
  if (!userId) {
    console.log("[PINS] No user found for device_id, no pins applied");
    return EMPTY_PINS;
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
    return EMPTY_PINS;
  }

  const beforePinIds = new Set<string>();
  const duringPinIds = new Set<string>();
  const afterPinIds = new Set<string>();

  for (const row of pinRows ?? []) {
    const kind = (row as { template_kind?: string }).template_kind;
    const id = (row as { template_id?: string }).template_id;
    if (!id) continue;
    if (kind === "pre_system") beforePinIds.add(id);
    else if (kind === "during_system") duringPinIds.add(id);
    else if (kind === "post_system") afterPinIds.add(id);
    // 'personal_template' is reserved for PR 4 — ignored here on purpose.
  }

  console.log(
    `[PINS] Loaded pins for user: before=${beforePinIds.size}, during=${duringPinIds.size}, after=${afterPinIds.size}`,
  );

  return { beforePinIds, duringPinIds, afterPinIds };
}
