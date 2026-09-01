# 02 — The Vana contract (frozen at the end of Phase 1)

Source of truth today: `mealplanning-prototype/packages/web/src/lib/vana/contracts.ts`. Phase 1 ends by
tagging the prototype `contract-v1`; after that, changes to any type below are a versioned change
made in three places at once (prototype TS, edge-fn TS in `supabase/functions/_shared/vana/`, Dart in
`lib/features/meal_planning/domain/`).

## 1. Scalars
| TS | Dart | values |
|---|---|---|
| `MealType` | `MealType` enum | `breakfast · lunch · dinner · snack` (also `DaySlot`) |
| `MealContext` | `MealContext` enum | `everyday · pre-session · recovery · rest-day · race-week · carb-load · travel` |
| `Session` | `CookingSession?` | `cook-sun · topup-wed · fresh-fri · null` |
| `ConversationKind` | `VanaConversationKind` | `meal_planning · general` |
| `MealIconKey` | `MealIcon` enum (23) | `bowl oats chicken meat fish egg salad bread wrap pasta soup pizza drink fruit nuts yogurt potato beans tofu baked snack sweet utensils` |
| plan status | `MealPlanStatus` | `draft · confirmed · archived` |
| memory kind | `MemoryKind` | `preference · constraint · pattern · episode · setting` |
| settings keys | `VanaSetting` | `batch_cooking` (bool) · `show_macros` (bool) — rows in `user_memories` with `kind='setting'` |
| `directions_origin` | `DirectionsOrigin` | `source · alt_source · ai_generated · assembly_simple` |

## 2. Records (Dart classes are immutable, `fromJson`/`toJson`, snake_case on the wire — the JSON is
the `search_meals` / table row shape, NOT the camelCase TS shape; the TS mappers `rowToMealRef`,
`rowToPlanMeal`, `toPlan` in `routes/-server/food.ts` define the wire→object mapping and the edge
functions emit the SAME wire shape so Dart and TS parse identical JSON.)

**`MealRef`** — one `search_meals` row: `source(library|saved) id name meal_type contexts[] batch
prep_minutes kcal carbs_g protein_g fat_g allergens[] diets_ok[] swaps why attribution
attribution_short(≤40) ingredients library_meal_id score kind pattern frequency icon my_vote(-1|0|1)`.

**`PlanMeal`** — `plan_meals` row: `id plan_id source library_meal_id saved_meal_id name meal_type
session servings servings_left kcal carbs_g protein_g fat_g swaps_applied[{from,to,effect?}]
comments[{role,text,at}] position icon`.

**`MealPlan`** — `meal_plans` row + children: `id week_start status batch_cooking days{date→DayPlan}
conversation_id brief rules[PlanRule] meals[PlanMeal] shopping[ShoppingItem] day_notes{date→text}
day_notes_stale coverage{lunch_dinner_slots covered per_day{kcal carbs_g protein_g}}` (coverage is
computed server-side and sent; Dart also has `PlanCoverageService` for the local-first case).

`PlanRule {day(mon..sun) rule meal_id? accepted}` · `ShoppingItem {aisle name qty checked have
from_meal_ids[]}` · `DaySlotRef {source(plan|saved|library) id name kcal? carbs_g?}` ·
`DayPlan = Map<DaySlot, DaySlotRef?>` · `DayTarget {date kcal carbs_g protein_g fat_g session_kcal
planning_kcal lunch_dinner_kcal mode}` · `Memory {id kind key fact value confidence
last_confirmed_at}` · `ConversationSummary {id kind title summary last_message_at created_at}`.

**`MealDetail`** (what `/food/meals/:id` and cooking mode need; built by the `get_meal` action):
`MealRef` + `ingredients_json[{name qty role?}] method_steps[] directions{origin source_url source_name
verbatim} image{url license creator credit source_url} source_url servings notes(saved only)`.

**`AthleteContext`** is server-internal (built per turn in the edge fn) — Dart never sees it.

## 3. `VanaPart` — the tool→widget union (`kind` discriminant)
| kind | payload | Dart widget |
|---|---|---|
| `choices` | `{question?, options[2..3]}` | `ChoiceChips` |
| `meal_picker` | `{title, meal_type?, meals[MealRef], multi, default_servings}` | `MealPickerCarousel` + client-drawn `PickerChips` |
| `staples` | `{meals[MealRef+{times_logged,ticked}], plan_carbs_per_day?, target_carbs_per_day?, covered?, of?}` | `StaplesCard` |
| `batch` | `{plan: MealPlan}` | **not rendered inline** — updates the `PlanBar` state |
| `rule` | `{rule: PlanRule, meal?: MealRef}` | `RuleChip` |
| `shopping_list` | `{items[ShoppingItem], item_count, skipped[]}` | `ConfirmedCard` (inline) / `ShoppingListScreen` |
| `day_guidance` | `{date, label, workout?, min_carbs_g, note, suggestions[MealRef]}` | `DayCard` |
| `memory_saved` | `{memory}` | `MemorySavedRow` |
| `logged` | `{plan_meal_id, name, servings_left}` | `LoggedRow` |
| `day` | `{date, label, slots: DayPlan, filled[]}` | `DayWidget` (Plan tab only) |
| `brief` | legacy — parse, don't render | — |

Unknown kinds are dropped by the Dart parser (same forward-compat rule `AiCoachUiPart.fromJson` uses).

## 4. `UiAction` — model-free edits (`POST vana-action`)
`pick_meals{meals[{source,id}],servings?,session?,conversation_id?}` · `unpick_meal{source,id}` ·
`swap_meal{plan_meal_id,source,id}` · `remove_meal{plan_meal_id}` · `set_servings{plan_meal_id,servings}`
· `set_session{plan_meal_id,session}` · `apply_swap{plan_meal_id,from,to,effect?}` ·
`add_comment{plan_meal_id,role,text}` · `accept_rule{day,rule,meal_id?}` · `confirm_plan{date?}` ·
`toggle_shopping{name,field(checked|have),value}` · `log_from_plan{plan_meal_id,meal_type?}` ·
`set_setting{key,value}` · `delete_memory{id}` · `list_memories{}` · `set_day_slot{date?,slot,source,id,name?}`
· `clear_day_slot{date?,slot}` · `plan_day{date?}` · `new_plan{}` · `get_plan{id?}` · `list_plans{}` ·
**new for the app:** `get_home{date}` (the `/api/vana/home` payload), `get_meal{id}` (→ `MealDetail`),
`recent_meals{limit}`, `set_saved_meal_notes{saved_meal_id,notes}`, `set_meal_feedback{library_meal_id?|saved_meal_id?,vote,reason?}`
(wraps the RPC so the client has one write channel; direct RPC is also fine).

Every action returns `{parts: VanaPart[], ...extras}`; the client folds any `batch` part into the plan state.
Scope rule: payload `plan_id` → that plan; else `conversation_id` → that conversation's draft; else the
week-level active plan.

## 5. Chat wire protocol (`POST vana-chat`) — **NDJSON, the `jade-chat` envelope, extended**
Decision: keep the envelope the Dart client already parses (`ai_coach_chat_repository._streamRequest`)
instead of the AI SDK UI-message stream the prototype uses. The prototype's web client is the only
thing that changes (Phase 1 adds an NDJSON transport to it so both clients speak the same thing).

Request: `{message?, conversation_id?, kind: 'meal_planning'|'general', timezone, opener?: bool,
anchor_date?: 'YYYY-MM-DD'}`. Headers back: `x-conversation-id`, `x-vana-kind`.
Lines: `{"type":"text","delta"}` · `{"type":"ui","part":VanaPart}` · `{"type":"status","tool":name}`
(new — drives the "Finding options that fit your week…" line) · `{"type":"done","usage"}` ·
`{"type":"error","message"}`. Errors before the stream: 401, 402 `insufficientCreditsBody`, 403
`{error:'pro_required'}` (new), 429 `{error:'rate_limited', retry_after_seconds}`.

Persistence (server): user + assistant rows in `vana_messages` with `content` (first text), `parts`
(ordered AI-SDK parts incl. `tool-*` with `state:'output-available'`), `metadata {ui_parts, tool_calls,
duration_ms, opener, kind}`; `vana_conversations.last_message_at/title` touched; one `vana_calls` row
per model call (`function_name, model, input_tokens, output_tokens`). History read prefers `parts`,
falls back to `content + metadata.ui_parts` (this is what the Dart history loader parses).

Limits (planning): ≤400 output tokens, `stepCountIs(6)`, text clamped to 2 sentences per step;
general: ≤700, `stepCountIs(8)`. Rate limits: `vana.chat` 4/10 s, `vana.brief` 2/60 s, `vana.embed` 30/60 s.

## 6. Client-drawn chips (never from the model)
After every `meal_picker` in a planning conversation the client renders: primary
`I like these` / `Next: <type>` / `That's my week` (depending on coverage) · `Other options` ·
`Something else…` (focuses composer) · once the plan has ≥1 meal, filter chips `No recipe only` ·
`Different protein` · `Under 20 min`. Tapping sends the label as the next user message. Chips
disable once one is picked (except `Something else…`).

## 7. Deterministic modules the client also owns
`MealIconClassifier` (port `meal-icon.ts` — tiered regex, stored key wins if valid) ·
`slotColor` (breakfast orange `#F78B14`, lunch electrolyte-dark `#3FD4C0`, dinner `#8E6FD8`, snack
dragonfruit `#DC2597`) · `weekLabel` · `PlanCoverageService` (lunch+dinner slots 14/week, covered =
Σ servings by type capped) · cooking-mode `findDurations` (5 s–12 h window, upper bound of ranges,
≤3 per step).
