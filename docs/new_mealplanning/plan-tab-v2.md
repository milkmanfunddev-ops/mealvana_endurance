# Plan tab v2 — decisions, data, and the Drift ↔ Supabase sync strategy (2026-08-31)

Built in the prototype (`~/development/mealplanning-prototype/packages/web`) on top of the 2026-08-27/28 schema.
Supersedes the "Your day" grid, the plan-detail route and the plans-history route in `prototype-rebuild-spec.md`.

## What the Food tab is now

| Tab | What it shows |
|---|---|
| **Plan** | **Message from Vana** (one precomputed line for today) · **This week's plan** — *every* meal as a list tile: icon · name · slot chip · `×servings`. Swipe right → Swap (full catalog page), swipe left → Remove (Undo snackbar). **Edit plan** turns tiles into steppers + swap/remove buttons and shows "+ Add a meal from the catalog". **New meal plan** → Vana meal-plan chat. Confirm button appears only while the plan is a draft. No chevron, no detail route, no pips / "4 left · Cook Sun", no theme/gear icon in the header. |
| **Meals** | The catalog (1,675 assemblies + 247 recipes + the athlete's saved meals). **Semantic search** (query → `text-embedding-3-small` → `search_meals(p_embedding)`), Mine/Library, meal-type chips, No-recipe/Recipes, context chips. **Add** opens a servings sheet (stepper, default ×4) → `pick_meals`. |
| **Shopping** | unchanged. |

**Two Vanas.** The "Ask Vana anything →" link on the Plan tab's Vana card opens **general Vana** (`/vana?mode=general`): an
empty chat — **no opener, no preloaded athlete context** (system prompt = persona + name + date), no server row until the first
message (the id comes back in `x-vana-conversation` and is pushed into the URL without remounting). She answers at will and
pulls what a question needs through tools: `getProfile`, `getWorkouts`, `getMacroTargets`, `getLoggedMeals`, `getBatch`,
`dayGuidance`, `searchMeals` (vector), `getWeather`, `recallFacts` (memory embeddings), `recallConversations` (search over earlier
chats), `rememberFact`. Answers are not sentence-clamped; pre-tool narration is dropped from the transcript. No bottom
"Ask Vana anything" bar anywhere. **Meal-plan Vana** is the separate kind with the planning persona, the context block, the
opener and the plan bar. `/vana/conversations?mode=` shows one history at a time (Ask Vana · Meal plans) with "New
conversation" of that kind; Settings (batch cooking, what Vana knows) is the cog there.

Plan tab chrome (2026-08-31 pm): no swipe hint, no status tag, no servings total, no Edit button — tap a tile for a
servings/Swap/Remove sheet; buttons are **Add meal** (→ catalog) and **New meal plan** (→ meal-plan Vana).

Retired: `/food/plan/$planId`, `/food/plans`, `/food/formulas`, `/food/batch`, `DayPlanner`, `TodayCard`, `PlanCard` (+ pips).
Server actions `set_day_slot` / `clear_day_slot` / `plan_day` and `meal_plans.days` are kept for the future dashboard-sparkle
"plan my day" — no UI calls them today.

## Meal icons

`packages/web/src/lib/vana/meal-icon.ts` — a deterministic classifier (no model) over `name` → `ingredients` → `pattern`, tiered:
headline dish (jacket potato, soup/stew/curry, drink, pizza) → dish form (pasta, wrap, bread/toast, salad, oats, yogurt, baked,
snack) → protein (chicken, meat, fish, egg, tofu, beans) → starch (potato, grain **bowl**) → other (fruit, nuts, dairy, sweet, veg).
Within a tier the *earliest* match in the name wins ("Greek yogurt with granola" → yogurt, "Granola with yogurt" → oats).

23 keys: `bowl oats chicken meat fish egg salad bread wrap pasta soup pizza drink fruit nuts yogurt potato beans tofu baked snack sweet utensils`.
Over the 1,922 live rows: bread 313 · beans 154 · chicken 140 · oats 137 · soup 125 · salad 120 · drink 118 · fish 100 · … · 0 unclassified.

Persisted as `meal_library.icon`, `saved_meals.icon`, `plan_meals.icon` (copied from the source meal at add/swap) —
`supabase/migrations/20260831090000_meal_icons_day_notes.sql`, backfilled by `scripts/backfill-meal-icons.ts`. `search_meals()`
now returns `icon`. Every UI surface resolves `stored ?? classify(name)` so rows that predate the column still get one.
Glyphs: `components/vana/meal-icons.tsx` (stroke SVGs in the existing 24-grid style; `MealIcon` = the 36px circle tile).

**Flutter:** render the same key with Font Awesome inside `KyleFoodIcon` — bowl→`bowlRice`, oats→`bowlFood`, chicken→`drumstickBite`,
meat→`bacon`, fish→`fish`, egg→`egg`, salad→`leaf`, bread→`breadSlice`, wrap→`burrito`(or `hotdog`), pasta→`bowlFood`, soup→`mugHot`,
pizza→`pizzaSlice`, drink→`glassWater`, fruit→`appleWhole`, nuts→`seedling`, yogurt→`iceCream`, potato→`carrot`, beans→`seedling`,
tofu→`cube`, baked→`cookie`, snack→`cookieBite`, sweet→`candyCane`, utensils→`utensils`. Port the classifier to Dart only for
user-created meals that haven't round-tripped through the server.

## Message from Vana — precomputed, not per-visit

`meal_plans.day_notes jsonb` (`{ "2026-08-31": "Rest day — …", … }`) + `day_notes_stale` + `day_notes_at`.

* `server/vana/daynotes.ts` — **one Haiku `generateObject` call writes all 7 days** from `contextBlock(ctx)` (training, targets,
  race, weather) + the plan's meals. Numbers come from the context; the model only phrases.
* Generated **on Confirm** (fire-and-forget, so the Plan tab is instant afterwards) and **on the first Plan-tab load after an edit** —
  every mutation goes through `refreshShopping()`, which flips `day_notes_stale = true`. If a note for today already exists the
  stale one is served immediately and the rewrite runs in the background (`vana.stale: true` → client refetches after 7 s);
  only a plan with no note at all waits for the call.
* Cost: ≤ 1 Haiku call per edit-session, none per visit. Logged to `vana_calls` as `vana.daynotes`.

## Sync strategy for the Flutter app (Drift ↔ Supabase)

The prototype writes Supabase directly from the server. In the app, keep the existing offline-first pattern (CLAUDE.md,
`docs/technical/sync-architecture.md`) and split the surfaces by who owns the data:

| Data | Owner | App behaviour |
|---|---|---|
| `meal_library` (1,922 rows; **no embeddings**, ~1 MB) | server, read-only | Drift cache table (`id, name, meal_type, kind, pattern, icon, contexts, batch, prep_minutes, kcal/macros, ingredients, why, allergens, diets_ok, updated_at`). `ensureSynced()` on Meals/Plan entry pulls rows with `updated_at > last_pull`. Chips/type filters and a **local LIKE/FTS fallback** work offline. |
| Semantic search | server only (needs the embedding + `search_meals`) | An edge function `vana-search` (embed query → RPC with the user's allergy/diet filters) called on demand; when offline, fall back to the local text search and say so. Never ship embeddings to the device. |
| `meal_plans` / `plan_meals` | **shared** — the app edits, Vana edits | Drift mirror with `needs_upload`, `updated_at`, `is_deleted`. Tile edits (servings, swap, remove) are **local-first**: write Drift, `needs_upload = true`, then `uploadDirtyRecords()` upsert with `onConflict: 'id'` (partial-index rule) and **check `UploadResult`**. Add `is_deleted` to `plan_meals` (prototype hard-deletes today) so removals sync as soft deletes. Conflict rule: last-writer-wins on `updated_at`; Vana's server writes win only if newer. Pull on Plan-tab entry (`ensureSynced`) because chat writes never touch Drift. |
| `shopping`, `day_notes`, `coverage` | server-derived | Don't compute on device. After a successful upload, pull the plan row back — the server has re-aggregated the list and marked notes stale; the note regenerates on the next `/home`-equivalent fetch. Offline: show the last-pulled list/note and a "will update when online" hint; local edits to `checked`/`have` are local-first like any other column. |
| `vana_conversations` / `vana_messages` | server | Online-only (chat needs the model). Cache the last N messages per kind in Drift for read-only display offline. |

Write-consistency policy (`docs/technical/write-consistency-policy.md`) applies: these are single-user writes, so no remote-ack
gating; the only place that needs remote ack is Confirm (shopping list must exist before navigating to it).

## Files touched (prototype)

`lib/vana/meal-icon.ts` · `components/vana/meal-icons.tsx` · `components/vana/swipe-row.tsx` · `components/vana/plan.tsx` (rewrite) ·
`components/vana/meal-catalog.tsx` · `routes/food.tsx` · `routes/food.plan.tsx` (rewrite) · `routes/food.meals.tsx` ·
`routes/food.swap_.$planMealId.tsx` · `routes/vana.tsx` · `routes/vana_.conversations.tsx` · `routes/-server/food.ts` ·
`server/vana/{daynotes,plan,meals,actions,tools}.ts` · `lib/vana/{contracts,client}.ts` · `styles/vana.css` · `scripts/backfill-meal-icons.ts`.
Deleted: `routes/food.plan_.$planId.tsx`, `routes/food.plans.tsx`, `routes/food.formulas.tsx`, `routes/food.batch.tsx`.

## Meal-plan conversation v3 (2026-08-31 pm) — empty draft, dinner picker opener, on-card actions

Decisions (Lee, 2026-08-31): opener = week frame + three dinners already on screen (act, don't ask — no "Plan my week" /
"What should I eat today?" chips; "what should I eat today" lives elsewhere); **one draft plan per conversation**; staples are
suggested, never auto-added; after picks → next meal type → Review → Confirm.

**Data.** `meal_plans.conversation_id` (migration `supabase/migrations/20260831150000_meal_plans_per_conversation.sql`, applied
to dev). The old partial unique index `(user_id, week_start) WHERE status <> 'archived'` became `meal_plans_confirmed_week`:
one **confirmed** plan per athlete-week, any number of drafts. `server/vana/plan.ts`: `getPlan()` = the week's ACTIVE plan
(confirmed first, else newest draft — what the Plan tab / shopping / context show); `resolvePlan(userId, scope)` = where a write
lands (`{planId}` → that plan, `{conversationId}` → the conversation's own draft, created on first use, else the active plan).
Edits keyed by `planMealId` derive the plan from the row and need no scope. `confirmPlan(scope)` archives the week's previous
confirmed plan, then confirms this one. Chat actions (`pick_meals`, `unpick_meal`, `get_plan`, `confirm_plan`) carry
`conversationId`; Plan-tab actions carry nothing.

**Opener** (`chat.ts OPENERS.meal_planning`): `suggestMeals(dinner, "Three dinners to start")` once, then two sentences (week's
salient fact → why these fit). `ctx.plan` in a planning chat describes the conversation's draft, not the Plan tab's plan.

**Tools.** `suggestMeals` excludes meals in the draft AND every meal already shown in this conversation (`shownMealIds(messages)`
from the persisted picker/staples parts) so "Other options" never repeats; new `maxPrepMinutes`. `diagnoseStaples` no longer
adds anything — it returns a tappable staples widget (ticked = in the draft).

**Client** (`routes/vana.tsx`, `components/vana/planbar.tsx`, `widgets.tsx`):
- Planning turns render text → widget → chips. Under every picker the app draws deterministic chips (no model call decides
  them): `I like these` (adds every un-ticked option, then sends "I like these. Next: <type>") · `Other options` · `Something
  else…` (focuses the composer). Once something is in the plan the first chip becomes `Next: <first uncovered type in
  dinner → lunch → breakfast → snack>` (or `That's my week`), and filter chips appear: `No recipe only` · `Different protein` ·
  `Under 20 min` (persona rule 3 maps them to `kind`, `query`, `maxPrepMinutes`). `↻ Other options` also sits on the picker card.
- Status lines while a tool runs ("Finding options that fit your week…", "Building your shopping list…") instead of narration.
- Plan bar starts **minimized** ("Your plan · 0 meals"); auto-collapses on every new turn. Tiles (184 px) carry × (remove +
  Undo snackbar), slot chip and a `− ×n +` stepper; tap the body for the swap sheet. `Review plan` (secondary until 3 meals,
  primary after) opens the **ReviewSheet**: meals grouped by cooking session (batch on) with steppers/× → `Confirm plan · build
  shopping list` → ConfirmedCard. `Confirm` is no longer in the bar or in Vana's chips.
- Persona (`persona.ts PLANNING_PROMPT`) rewritten: one `suggestMeals` per turn, never `askChoice` after a picker, never add a
  meal unless named, never `confirmPlan` unless the athlete says confirm.

Not built (deliberately, per synthesis R11): fridge photo, coupons/deals, day grids, `Edit` under past answers, kcal pills on cards.
