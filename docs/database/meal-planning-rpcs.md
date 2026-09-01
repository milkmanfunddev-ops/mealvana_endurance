# Meal-planning RPCs (Vana)

Source: `supabase/migrations/20260902090000_meal_planning_rpcs.sql` (idempotent; applied to **dev** 2026-09-01,
not yet on prod — prod gets it in the Phase 5 runbook, `docs/implement_mealplanning/06-sync-schema-envs.md`).
Tables they touch: `meal_plans`, `plan_meals`, `meal_logs`, `meal_library`, `saved_meals`
(created by `20260827090000_meal_planning_vana.sql` and later files in the same series).

All six are `language plpgsql/sql`, **`security invoker`**, `set search_path = public`, granted to `authenticated`
and `service_role`. Authorisation is the tables' owner RLS (`user_id = auth.uid()`) — a caller can only ever reach
their own plans. They exist so that (a) the edge functions (`vana-action`, `vana-chat` tools) get a remote ack from
one transaction and (b) the Dart repositories can replay the same write when an offline-first edit is uploaded.

| Function | Args | Returns | Effect |
|---|---|---|---|
| `confirm_meal_plan` | `p_plan_id uuid, p_shopping jsonb = null` | the updated `meal_plans` row | status → `confirmed`; stores `p_shopping` when given (the edge fn builds it with `grocery.ts`); `day_notes_stale = true`; **archives every other non-archived, non-deleted plan of the same `(user_id, week_start)`** (drafts from other conversations and a previously confirmed plan) so the partial unique `meal_plans_confirmed_week` holds. |
| `plan_log_from_plan` | `p_plan_meal_id uuid, p_meal_type text = null, p_log_date date = current_date` | new `meal_logs.id` | `plan_meals.servings_left = greatest(0, −1)`; inserts a `meal_logs` row with `source = 'plan'`, `plan_meal_id`, `slot = coalesce(p_meal_type, meal_type)`, `items` from `meal_library.ingredients_json` / `saved_meals.items`, macros as stored on `plan_meals` (**per serving** — `coverageOf` multiplies by servings, so nothing is divided). Pass the athlete's local date as `p_log_date`. |
| `plan_set_servings` | `p_plan_meal_id uuid, p_servings int` | the updated `plan_meals` row, or `null` when removed | `servings ≤ 0` deletes the row; otherwise `servings_left` keeps what was already eaten (`p_servings − (servings − servings_left)`, floored at 0). Flags the plan `day_notes_stale`. Does **not** rebuild `shopping` — the edge fn does that in TS; a Dart replay should follow with the plan's next `get_plan`/`confirm`. |
| `plan_remove_meal` | `p_plan_meal_id uuid` | void | `plan_set_servings(id, 0)`. |
| `plan_toggle_shopping` | `p_plan_id uuid, p_name text, p_field text ('checked'\|'have'), p_value bool` | the updated `shopping` jsonb | Flips one item matched by name (case-insensitive) inside `meal_plans.shopping`. |
| `plan_set_day_slot` | `p_plan_id uuid, p_date date, p_slot text, p_ref jsonb = null` | that day's slots jsonb | Writes a `DaySlotRef` (`{source, id, name, kcal?, carbsG?}`) into `meal_plans.days[date][slot]`; `p_ref null` clears the slot. |

Related, from the earlier migrations: `search_meals(...)` (allergy/diet-filtered library + saved meals; `security invoker`),
`set_meal_feedback(p_library_meal_id, p_saved_meal_id, p_vote, p_reason)` (the only sanctioned write to `meal_feedback`
— its uniques are partial indexes, never PostgREST-upsert on them), `recall_memories`, `match_library`,
`library_pair_support`, `refresh_meal_library_pairs` (service role only).

## Call sites
- `supabase/functions/_shared/vana/plan.ts` — `confirmPlan()` → `confirm_meal_plan`; `logFromPlan()` → `plan_log_from_plan`.
  Other plan edits stay as RLS-scoped row updates in TS (same semantics as the RPCs; the RPCs are for Dart replays).
- `supabase/functions/_shared/vana/meals.ts` — `setMealFeedback()` → `set_meal_feedback`.
- Dart (Phase 4): `lib/features/meal_planning/data/` repositories call these directly via `supabase.rpc(...)` when
  replaying uploads; see `docs/implement_mealplanning/05-flutter-feature.md`.
