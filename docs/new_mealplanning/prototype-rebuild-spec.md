# Prototype rebuild spec — Vana (2026-08-27)

Repo: `~/development/mealplanning-prototype` (`packages/web`, TanStack Start + React 19 + AI SDK v6 + AI Gateway +
Supabase). Reads the SAME dev Supabase project as the Flutter app. Design: canvas
https://claude.ai/code/artifact/c776e4cd-1e7f-4f7a-8c71-a6a2d332ec21 (page 1 walkthrough, page 2 screens),
`walkthrough.md`, `synthesis-and-recommendations.md`. Contracts: `packages/web/src/lib/vana/contracts.ts`.

## Schema (already applied to dev — `supabase/migrations/20260827090000_meal_planning_vana.sql`)
`meal_library` (1,922 rows since 2026-08-28: 1,675 `kind='assembly'` + 247 `kind='recipe'`, embeddings via `openai/text-embedding-3-small`; `+ pattern, frequency, evidence`; `search_meals(... p_kind)`; `meal_library_pairs` + `library_pair_support(text[])` for composition checks — see `20260828090000_meal_library_assemblies.sql`), `saved_meals` (+ `embedding`,
`library_meal_id`, `meal_types`, `batch`), `meal_plans`, `plan_meals`, `user_memories`, `meal_logs.source='plan'` +
`plan_meal_id`. RPCs: `search_meals(p_user_id, p_query, p_embedding, p_meal_type, p_contexts, p_batch,
p_include_saved, p_limit)` (hard allergy/diet filters from `users`, saved + library in one result set, saved boosted),
`match_library(p_embedding, p_meal_type, p_limit)`, `recall_memories(p_user_id, p_embedding, p_limit)`.
Existing tables to read: `users` (allergies, dietary_preference, gut_training_level), `activities`
(scheduled_date_time, title, activity_type, duration_minutes, intensity_level, distance_miles),
`daily_macro_targets` (target_date, carb_g, prot_g, fat_g, tdee), `events`/`public_events` (event_name, event_date,
location), `meal_logs`, `saved_meals`, `food_preferences`. Seed script: `packages/web/scripts/seed-meal-library.mjs`.

## Principles (non-negotiable)
1. Algorithms select, the model talks. Allergy/diet filtering, coverage math, servings, shopping-list aggregation
   are code. The model never emits a macro number it did not get from a tool result.
2. One agent path. Delete `server/jade/server-fns.ts` AI paths, the loose schemas, the 5-variant scaffolding,
   `meal-add-sheet.tsx`, the Vite dev-middleware endpoints, Clerk remnants. One system prompt (`server/vana/persona.ts`).
3. Context up front is small and deterministic (`AthleteContext`, ≤ ~1.5k tokens). Everything else is a tool.
4. Every Vana turn: ≤ 2 sentences before the user gets chips; ≤ 3 chips; free text always allowed; nothing
   commits until Confirm. Minimums framing; no weight language; medical refusals (keep persona.ts's hard refusals).
5. Batch cooking is a `user_memories` row `kind='setting', key='batch_cooking'` — asked once, editable in Settings
   and by Vana. When false: no sessions; meals are "make the night of".
6. Rate limit + call log on every model call (`rate-limit.ts`, `log.ts` — wire them, they exist).
7. Models via AI Gateway: chat `VANA_CHAT_MODEL` (Sonnet), cheap tool jobs `VANA_TOOL_MODEL` (Haiku),
   embeddings `VANA_EMBED_MODEL`. Env in `packages/web/.env.local` (gitignored).

## Server (`packages/web/src/server/vana/`)
- `context.ts` — `buildAthleteContext(userId)`: profile, next-7-day workouts + derived week character (port
  `lib/derive-week-character.ts`), race (nearest future event within 21 days), budgets from `daily_macro_targets`
  (race-week carbs = max of Wed–Fri targets), weather (Open-Meteo, cached per day/location; location from the
  race `location` geocoded once via Open-Meteo geocoding, else null), logged-today totals, plan summary, top
  memories (recency + `recall_memories` on the latest user message).
- `embeddings.ts` — `embedText(text)`.
- `tools.ts` — AI SDK v6 `tool({description, inputSchema, execute})`, all return `VanaPart` or plain data:
  `searchMeals`, `diagnoseStaples` (meal_logs last 30d grouped by name + saved_meals → embed → `match_library`
  → `staples` part; persist `library_meal_id` on saved_meals when score ≥ 0.82), `suggestMeals` (→ `meal_picker`),
  `getBatch`/`updateBatch` (add/remove/servings/session; recompute coverage + shopping via `grocery.ts`),
  `proposeRule` (→ `rule`), `confirmPlan`, `shoppingList`, `dayGuidance` (deterministic from budget + workouts +
  library `rest-day`/`carb-load`/`race-week` picks), `weeklyBrief` (Sonnet writes ≤2 sentences from context; the
  numbers come from `dayGuidance`/coverage), `logFromPlan`, `rememberFact`/`recallFacts`/`forgetFact`,
  `setSetting` (`batch_cooking`, `show_macros`), `getWeather`, `askChoice`.
- `route.ts` — POST `/api/vana/chat` (TanStack server route, Node runtime): auth via Supabase cookies → rate limit
  → build context → `streamText` with tools, `toUIMessageStreamResponse()` → persist messages in
  `jade_conversations`/`jade_messages` (metadata.ui_parts = the parts) → log call. Also POST `/api/vana/action`
  for `UiAction`s that don't need the model (steppers, checkboxes, log, settings, memory delete).
- `grocery.ts` — keep the existing deterministic aisle builder; extend to read `plan_meals` + `meal_library.
  ingredients_json` + saved_meals items; skip pantry staples logged ≥2× in 30d (mark `have: true`).
- `persona.ts` — rewrite for Vana: identity, the 5 principles above, the turn shape, the "diagnose-and-add first"
  opening rule, tool usage rules (never invent meals; always cite `attribution`; call `rememberFact` only for
  explicit statements or repeated behaviour), house style for meal titles (lowercase joiners, components first).

## UI (`packages/web/src/routes`, `src/components/vana`, `src/styles`)
- Routes: `/food` (tabs Plan · Meals · Formulas · Shopping — Formulas is a placeholder linking to the app), `/food/plan`
  (Food home: brief card, day card, staples, batch summary, shopping summary, Ask Vana bar), `/food/meals`
  (Mine | Library, meal-type + context chips, allergy-greyed cards, Add), `/food/meals/$id` (detail sheet:
  ingredients, tappable swaps, contexts, diets/allergens, attribution, macro disclosure, Make tonight / Add to
  batch ×N), `/food/shopping` (aisle groups, have/checked, Send to Reminders = share sheet / copy), `/vana` (full
  chat, `useChat` + `DefaultChatTransport` to `/api/vana/chat`, parts rendered by `VanaPartRenderer`),
  `/settings` (Batch cooking, Show macros, What Vana knows list with delete). Keep `/sign-in`, `/auth/callback`.
- Components (`components/vana/`): `VanaAvatar`, `BubbleUser`, `BubbleAi`, `ChoiceChips`, `BriefCard`, `DayCard`,
  `StaplesCard`, `MealCard` (states: default / selected / allergy-excluded / in-batch), `MealPicker`, `BatchBar`
  (collapsed/expanded), `BatchScreen` (sessions only when batch cooking on; steppers; inline `AdjustInput`;
  comment thread), `RuleChip`, `CoverageMeter` (macro disclosure with daily total, minimums), `ShoppingList`,
  `LogRow`, `MemoryDrawer`, `NavPill` (Calendar · Events · Food · Learn — only Food live).
- Styling: use `docs/new_mealplanning/design-system/tokens.css` + `kyle.css` when they land (copy into
  `src/styles/`); until then the CSS in the canvas `_head.html`. Exact Kyle values; dark theme; no emoji; inline SVG.
- Copy: exactly the walkthrough's strings for the scripted turns are NOT hard-coded — Vana generates — but the
  widget labels ("Yes, look", "That's right", "Add 1 meal", "Confirm", "Ate it", "Saved to Settings · Batch cooking: on")
  are the canvas's.

## Acceptance
- Signed in as the dev test user, `/food/plan` shows a real brief built from that user's activities/events.
- "Yes, look" → staples come from real `meal_logs`/`saved_meals`; picker results come from `search_meals` and
  never include an allergen the user has; adding meals persists to `meal_plans`/`plan_meals`; Confirm produces a
  real shopping list; "Ate it" writes a `meal_logs` row with `source='plan'` and decrements `servings_left`.
- Batch-cooking off → no sessions anywhere. Settings and Vana both flip it (same `user_memories` row).
- `pnpm typecheck`, `pnpm build` pass; a vitest covers `search_meals` filtering (allergy exclusion) and grocery aggregation.
