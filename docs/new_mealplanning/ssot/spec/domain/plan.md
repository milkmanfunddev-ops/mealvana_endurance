# SSOT — Plan (lifecycle, ownership and edits)

**Status:** RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.
**Source:** `../intent/vana-mealplanning-chatbot.md` §4.1 (never a day grid; a collection of meals × servings).
**Code:** `meal_plans` / `plan_meals` (`20260827090000`, `20260831150000` per-conversation,
`20260902090000` RPCs, `20260903120000` lifecycle stamps); prototype `server/vana/plan.ts`, edge
`_shared/vana/plan.ts` (+ `plan-math.ts`), Dart `meal_plan_repository.dart` (local-first mirror).
**Scope:** what a plan *is*, which plan a read or write lands on, and what each edit does.

**What this file owns:** what a plan *is*, which plan a read or write lands on, and what each edit does. It owns
no arithmetic (`../planning/plan-coverage.md`, `cooking-sessions.md`, `shopping-list.md`) and no pixel.

## Definitions

- **Plan** — a **collection of meals × servings for one Sunday-start week**, grouped by cooking session when
  batch cooking is on. Never a 7 × 4 grid (research finding 3; `../intent/` §4.1).
- **Status** — `draft · confirmed · archived`.
- **Active plan** (`getPlan`) — the week's confirmed plan, else its most recently updated draft. What the Plan
  tab, the shopping tab, the home payload and the context's PLAN line show.
- **Conversation draft** — a draft owned by the Vana conversation building it (`meal_plans.conversation_id`),
  created empty on first use.
- **Day slots** — `meal_plans.days {date → {breakfast, lunch, dinner, snack → DaySlotRef}}`, an optional
  assignment layer over the collection ("dailies are an assignment layer on top", `../intent/` §1.4).

## Rules

- **P-1 · One CONFIRMED plan per athlete-week; any number of drafts.** Partial unique index
  `meal_plans_confirmed_week (user_id, week_start) where status = confirmed and not is_deleted`.
- **P-2 · The scope rule decides where a write lands.** `{planId}` → that plan; else `{conversationId}` → that
  conversation's draft (created if missing); else the week's active plan (created as a conversation-less draft
  if none). Edits keyed by `planMealId` derive the plan from the row and need no scope. Chat actions carry the
  conversation; Plan-tab actions carry nothing.
- **P-3 · Confirm is the only status transition the athlete makes, and it is explicit.** `confirm_meal_plan(plan,
  shopping)` (one transaction): every other non-archived plan of the same athlete-week is archived, this one
  becomes `confirmed`, the freshly built shopping list is stored, day notes are flagged stale. Neither "that's
  my week", "done" nor "looks good" confirms; the model calls `confirmPlan` only on the word confirm (agent
  guardrails H6). Confirm is remote-ack (the list must exist before the tab navigates).
- **P-4 · A draft starts EMPTY.** The plan bar shows "Your plan · 0 meals"; the opener's three dinners are
  options, not picks; staples are suggestions (`../selection/meal-suggestion.md` SG-5).
- **P-5 · Add merges by source id.** Adding a meal already in the plan adds servings (and `servings_left`)
  instead of a second row. Default servings 4 (`pick_meals` / picker), position = current row count, session
  from [`../planning/cooking-sessions.md`](../planning/cooking-sessions.md).
- **P-6 · Servings and "ate it" keep the eaten count.** `plan_set_servings(n)`: `servings_left = max(0,
  n − eaten)` where `eaten = servings − servings_left`; `n ≤ 0` deletes the row. `plan_log_from_plan`: one
  serving eaten → `servings_left − 1` (floored at 0) and one `meal_logs` row with `source = 'plan'`,
  `plan_meal_id`, the meal's per-serving macros and its ingredient items. The Plan tile reads "3 of 4 left".
- **P-7 · Swap is in place.** `swapMeal` keeps id, position, session and `servings`; replaces source ids, name,
  type, macros, icon; resets `swaps_applied`; appends a `vana` comment "Swapped A → B"; `servings_left` keeps the
  eaten count. Undo of a remove re-adds with the previous servings and session (`readd`).
- **P-8 · Every mutation rebuilds the shopping list and flags day notes stale** (`refreshShopping`) — add,
  servings, remove, swap, swap-ingredient, batch toggle, `set_pantry`. Never the model.
- **P-9 · Batch cooking is a plan attribute copied from the setting at insert and re-derivable.**
  `setBatchCooking(on)` rewrites every row's session (`cooking-sessions.md`); the setting memory is the
  athlete's choice, the plan row is a snapshot of it.
- **P-10 · Rules are per-day text with optional meal** (`rules[] {day, rule, mealId?, accepted}`), proposed by
  `proposeRule` (only when the context has a race — the race-eve plate) and accepted through `accept_rule` /
  an `askChoice`. A rule with the same day + text replaces itself.
- **P-11 · New plan archives the active one.** `new_plan` (edge; declared but unimplemented in the prototype —
  D-016) archives the week's active plan and starts a conversation-less draft.
- **P-12 · Rewind restores the draft to a snapshot** (edge, Phase 6). Every assistant turn stores
  `metadata.plan_snapshot = [{source, id, servings, session}]`; `rewind(messageId)` deletes that user message and
  everything after it and rebuilds the conversation draft from the previous assistant turn's snapshot (a rewind
  past the first turn empties the draft). Meals are re-added through `addMealById`, so ids change; a meal that
  no longer resolves is skipped with a warning.
- **P-13 · Day slots never generate.** `planDay` / `planWeek` assign existing plan meals first, then library
  picks by the day's context; `set_day_slot` / `clear_day_slot` are direct writes. A slot ref is
  `{source: plan | saved | library, id, name, kcal?, carbsG?}` — a pointer, never a copy of macros the athlete
  can edit.
- **P-14 · Lifecycle stamps are server-only.** `checkin_done_at`, `debrief_done_at`, `plan_debriefs` are not on
  the `MealPlan` wire and never reach Drift (`../planning/opener-selection.md`).

## `MealPlan` (wire — frozen)

`id weekStart status batchCooking days? conversationId? brief rules[] meals[] shopping[] dayNotes{} dayNotesStale?
coverage{lunchDinnerSlots covered perDay{kcal carbsG proteinG}}`; `PlanMeal`: `id planId source libraryMealId
savedMealId name mealType session servings servingsLeft kcal carbsG proteinG fatG swapsApplied[] comments[]
position icon?`. `coverage` is computed server-side on every read and sent; Dart recomputes locally only for
the optimistic path.

## Invariants (conformance must assert)

1. Never two confirmed plans for one `(user, week_start)` (P-1 — a DB constraint, assert by attempting it).
2. `servings_left ≤ servings` always; `logFromPlan` never goes below 0.
3. After `confirmPlan`, `plan.shopping` is non-empty whenever the plan has a library meal with ingredients.
4. A chat `pick_meals` with `conversationId` never touches the Plan tab's active plan of another conversation.
5. `swapMeal` leaves `position`, `session`, `servings` unchanged.
6. `rewind` to the first assistant turn leaves `meals = []`.

## Deviations

- **D-016** — `new_plan` is declared in the prototype's `UiAction` union but not implemented there; the edge
  implements it.
- **D-017** — the prototype hard-deletes `plan_meals` rows on remove; the sync plan calls for `is_deleted` soft
  deletes so removals sync (plan-tab-v2 sync table). Not yet in either twin's schema.

## Conformance

RPC behaviour: `supabase/functions/tests/vana/contract.test.ts` (fixtures `batch.json`, `confirm_plan.json`);
the Dart repository tests (`test/features/meal_planning/data/meal_plan_repository_test.dart`); Patrol plan-build
flow (pick → review → confirm → "Ate it"). No pure vectors — the lifecycle is DB state; the QA precedent is the
seam test (`conformance/README.md` §Not yet covered).
