# SSOT — Tools (what the model may call, per conversation kind)

**Status: RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.**
**Engine:** `makeVanaTools(kind)` — prototype `server/vana/tools.ts` (24 tools), edge `_shared/vana/tools.ts`
(28: + `draftWeek`, `askPantry`, `recordDebrief`, `planWeek` — D-12). AI SDK v6 `tool({inputSchema, execute})`;
a UI tool returns a `VanaPart` (rendered by the client), a data tool returns plain data (seen by the model only).

## Tool sets

**Planning** = everything below except `planDay` / `setDaySlot` (day-grid tools are UI-only: a conversation
builds the collection, never a grid).
**General** = `askChoice · searchMeals · dayGuidance · getWeather · getWorkouts · getLoggedMeals ·
getMacroTargets · recallFacts · rememberFact · forgetFact · getSetting · getBatch · logFromPlan · getProfile ·
recallConversations` — read-mostly; **no plan-building tool** (a general chat offers "Start a meal plan").

## Inventory

| Tool | Kind | Returns | Side effects | Contract notes |
|---|---|---|---|---|
| `askChoice {question?, options[2..4] of string \| {label ≤60, detail ≤90}}` | both | `choices` | — | the only way to ask; details are the trade-offs (V-1); prototype caps at 3 strings (D-12) |
| `suggestMeals {title, query?, mealType=dinner, contexts?, batch?, kind?, maxPrepMinutes?, defaultServings=4, excludeAllergens?, requireDiet?, ingredientsOnHand?}` | planning | `meal_picker` | marks shown | SG-1…SG-4; one per turn; never followed by `askChoice` |
| `searchMeals {query?, mealType?, contexts?, batch?, kind?, limit ≤6, excludeAllergens?, requireDiet?}` | both | compact meals | — | lookups only; never a picker |
| `diagnoseStaples {}` | planning | `staples` | marks shown | suggest-only (SG-5) |
| `checkCombination {components[2..6]}` | planning | `{supported, pairs}` | — | the anti-hallucination gate (SG-6) |
| `getBatch {}` | both | `batch` | creates the draft if missing | the plan bar re-reads it |
| `updateBatch {action: add \| set_servings \| remove, source?, mealId?, planMealId?, servings?}` | planning | `batch` | plan write | `add` only for a meal the athlete named (H5, Q-AG2) |
| `swapMeal {planMealId, source, mealId}` | planning | `batch` | plan write | in place (P-7) |
| `proposeRule {day, rule, mealId?, accepted=false}` | planning | `rule` | writes the rule (unaccepted) | only with a RACE in context |
| `confirmPlan {}` | planning | `shopping_list` | confirm + archive + list + day notes | only on the word confirm (H6) |
| `shoppingList {}` | planning | `shopping_list` | rebuilds the list | — |
| `dayGuidance {date?}` | both | `day_guidance` | — | deterministic (`../planning/day-guidance.md`) |
| `logFromPlan {planMealId, mealType?}` | both | `logged` | `meal_logs` row + servings_left | P-6 |
| `rememberFact {kind ∈ preference·constraint·pattern·episode, fact ≤200, confidence=0.8}` | both | `memory_saved` | memory row | MEM-1 |
| `recallFacts {query}` · `forgetFact {id}` | both | data / `{ok}` | soft delete | — |
| `setSetting {key, value}` | planning | `memory_saved` | setting row; `batch_cooking` re-derives sessions | keys per MEM-4 (prototype: 2 keys) |
| `getSetting {key}` | both | `{key, value, default}` | — | — |
| `getWeather {place, date}` · `getProfile {}` · `getWorkouts {days≤21}` · `getLoggedMeals {days≤30}` · `getMacroTargets {from, to}` · `recallConversations {query, limit≤12}` | both | data | — | the general kind's pull-what-you-need set; `recallConversations` is an ILIKE over `vana_messages.content` on ≤ 4 words |
| `draftWeek {scope?}` (edge) | planning | `batch` | adds meals | SG-7; at most once |
| `askPantry {title?}` (edge) | planning | `pantry` | — | seeded from logs/saved/last list; nothing used until "Use these" |
| `recordDebrief {planId?, completed, planned?, skipReason?, learnings≤3}` (edge) | planning | `debrief` | `plan_debriefs` row, `debrief_done_at`, ≤3 memories | the FIRST tool call of the debrief-answer turn |
| `planWeek {}` (edge) · `planDay {date?}` · `setDaySlot {…}` | planning (planWeek) / UI-only | `week` / `day` | writes `meal_plans.days` | P-13; after confirm and only on "lay it out" |

## Rules

- **T-1 · A UI tool's output IS the transcript.** The part is persisted verbatim in `parts` and `metadata.ui_parts`;
  the client renders parts, never raw JSON.
- **T-2 · Tools are scoped to the conversation's draft** (`PlanScope {conversationId}`) — every plan write from a
  chat lands there; the Plan tab's active plan is untouched until confirm (P-2).
- **T-3 · The model sees compact meals only** (SG-10) — never allergens, never the full source string, never
  embeddings.
- **T-4 · Steps are bounded:** planning `stepCountIs(6)`, general `stepCountIs(8)` — a turn that needs more is a
  prompt bug, not a limit to raise (revisit only if the eval shows starved turns).
- **T-5 · Zod is the contract at the tool boundary.** Inputs are validated by the AI SDK; outputs by
  `schemas.ts` in the edge contract test (strict objects — an accidental extra key fails).

## Conformance

`supabase/functions/tests/vana/contract.test.ts` (part shapes over the frozen fixtures, 88/88 on 2026-09-02);
vana-eval (which tools fire on which turn: `fork_or_picker`, `wrapup_or_picker`, `shopping_list`, `milestone`).
