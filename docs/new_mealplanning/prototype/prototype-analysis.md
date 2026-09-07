# Meal-Planning Prototype — Analysis

Source: `github.com/lbm54/mealplanning-prototype`, cloned and analyzed 2026-08-26 at
`HEAD = 1df9b3d` ("fix(shell): pin header + nav, scroll only the body").

This is a read-only analysis of a standalone prototype repo. Nothing in
`mealvana_endurance` was changed to produce this document.

---

## 1. What it is

A standalone TanStack Start web app that explores meal planning UX for Mealvana
Endurance, built by five parallel "variant" agents (Approaches A–E) and then
consolidated into a single mobile-styled flow. It talks to **the same dev
Supabase project as the Flutter app** (`vlmtsdzpnjnavdgytcmi`) for the athlete's
training/macro data, and uses an AI persona named **Jade** (Vercel AI SDK +
Vercel AI Gateway, Anthropic models) to generate meal plans.

**Stack**
- Framework: TanStack Start v1.167 + Vite v8 + Nitro, React 19, TypeScript
- Styling: Tailwind v4 + shadcn/ui + custom "Kyle" design tokens (Compadre Wide /
  Apercu / Sansita fonts, cream/blackberry/mango/electrolyte/dragonfruit palette)
- Auth: **Supabase email+password / magic-link** (the README and `.env.example`
  still describe Clerk — that's stale; see §7)
- Data: Supabase Postgres (dev project, RLS-scoped)
- AI: Vercel AI SDK v6 (`ai` package) + `@ai-sdk/gateway`, model IDs like
  `anthropic/claude-haiku-4-5` / `anthropic/claude-sonnet-4-6`
- pnpm workspace, single package `packages/web` (`@mealplanning/web`)

**How to run**: `pnpm install && pnpm dev` (port 3000). Boots with zero env vars —
AI/auth/data degrade to "not configured" stub states. `.env.local` needs
Supabase + `AI_GATEWAY_API_KEY` for full functionality; none of that was
supplied for this analysis.

**Build check (per task instructions)**: `pnpm install` (7.4s, 878 packages) and
`pnpm build` **both passed cleanly with zero env vars and zero API keys**. Vite
client bundle, SSR bundle, and Nitro server bundle all built without error. The
only anomaly was the static prerender step logging a 404 for `/` (Nitro tried to
prerender the landing route before the dev-only auth check settles) — cosmetic,
doesn't fail the build. No TypeScript/ESLint errors surfaced during the build.

---

## 2. Architecture

### 2.1 History that matters
`git log` shows the repo went through two eras:
1. **Five-variant era** (commits `f1ba557`..`9986db4`..`e2c5187`): five parallel
   UI approaches (A–E, git-worktree built) each with their own component tree,
   a rich **28-tool generative-UI agent** (`server/jade/tools.ts`), a **30-widget
   registry** (`components/shared/widgets/`), streaming chat via AI SDK
   `useChat`, and full athlete-context injection into the system prompt.
2. **Mobile-app consolidation** (commit `3fa914b`, "Consolidate 5 variants (A–E)
   into single mobile-styled flow on `/plan/a`"): variants B–E and most of A's
   generative-UI wiring were **deleted**. What ships today is a 4-tab mobile app
   (Plan / Cookbook / Shopping / You) with a much simpler, non-streaming,
   tool-less chat sheet. **The 28-tool agent and 30-widget system from era 1
   still exist in the repo tree but are dead code — nothing in the current
   screens calls them** (see §3.3, §6).

### 2.2 Routes (file-based, TanStack Router)
`/` (landing/variant picker stub) · `/plan/a` (the app — 1481 lines, the
canonical screen) · `/cookbook` (858 lines) · `/shopping` (480 lines) · `/you`
(96 lines, mostly static) · `/sign-in`, `/sign-up`, `/auth/callback` ·
`/styleguide` (Kyle design-system smoke test).

### 2.3 Server surface — three parallel, inconsistent implementations
This is the most important structural finding. There are **three different
places** that talk to the AI, each with a different system prompt, different
tool access, and different levels of user-context:

| Surface | File | Used by (prod-reachable?) | Context injected | Tools | Streaming |
|---|---|---|---|---|---|
| `jadeObjectFn`, `chatFn`, `groceryListFn` | `server/jade/server-fns.ts` (TanStack `createServerFn`) | **Yes — this is what ships.** `/plan/a` calls `jadeObjectFn` for week/day generation; `JadeChatSheet` calls `chatFn`; `/shopping` calls `groceryListFn`. | **None.** Generic `SYSTEM_PROMPT` constant, no athlete data, no tool calls. | **None.** | No (single-shot `generateText`/`generateObject`) |
| `/api/jade/{hello,chat,object}` | `vite.config.ts` inline Vite dev-middleware (~700 lines) | **Dev-server only** (`configureServer` — Nitro/Vercel never runs Vite middleware in prod). Not reachable from a deployed build. | **Yes — extensive.** Queries `users`, `activities`, `daily_macro_targets`, `food_preferences` via Supabase cookies, derives a "WEEK CHARACTER" (training load score, anchor day, rest days, avg carbs/lb) and injects it as an `ATHLETE CONTEXT` block. | Yes — wires `makeJadeTools()` (28 tools) when signed in. | Yes (`streamText().toUIMessageStreamResponse()`) |
| `server/jade/{persona,schema,tools,gateway}.ts` (barrel: `server/jade/index.ts`) | Standalone module | **Orphaned.** Only `tools.ts` (via `makeJadeTools`) and `schema.ts` (via `WeekPlanSchema`/type imports) are imported anywhere, and only by the dev-only middleware above and by `grocery.ts`. `persona.ts` (the "verbatim" surface-adapter system prompt, §3.1) and `gateway.ts` (`getDefaultModel`/`getFallbackModel`) are **never imported by any route or endpoint**. | n/a | n/a | n/a |

**Net effect**: the sophisticated, context-aware, tool-using agent design
documented in `persona.ts`/`tools.ts`/the Vite middleware is real code that
works, but it is **not what a user talking to Jade in the shipped app actually
gets**. The shipped `/plan/a` + `JadeChatSheet` path is a plain
`generateObject`/`generateText` call with a short generic prompt, no tools, and
no knowledge of the user beyond the raw chat turns typed into that session.

### 2.4 Data flow / persistence — confirmed by reading the code, not inferred
- `server/variant-a/plan-data.ts` (the loader for `/plan/a`) has this docstring
  verbatim: *"The demo runs on localStorage (lib/plan-store) — there's no live
  Supabase persistence in the prototype."* `fetchPlanPageData()` always returns
  empty `activities`/`macroTargets`/`existingPlan`/`existingMeals` and
  `hasSupabase: false`. `persistWeekPlan()` and `updateMealCell()` are no-ops
  (`return null` / `return`).
- The actual plan state lives entirely in `lib/plan-store.ts` — a module-level
  store (`useSyncExternalStore`) mirrored to `window.localStorage` under key
  `mealvana.plan.v1`. This is how the plan survives navigating between
  Plan/Cookbook/Shopping/You.
- `/shopping` (`groceryListFn` path) reads `usePlanState()` — i.e. the
  **localStorage** plan — and ships the meal titles/components straight to
  Claude via `generateObject` to produce an aisle-grouped list, with a
  deterministic client-side fallback (`buildHeuristicList`) if AI is
  unconfigured. **It never touches Supabase.**
- Separately, `server/jade/grocery.ts` (`buildGroceryListFromPlan`) is a
  **complete, well-built, deterministic** (no-AI, keyword-based) aisle
  classifier that reads real `meal_plans`/`meal_plan_meals` rows from Supabase.
  It's wired into the `buildGroceryList` tool (`tools.ts`) and a separate
  `/api/grocery-list` dev-middleware endpoint — but since nothing ever writes a
  `meal_plans` row (see above), and neither of those call sites is reachable
  from the shipped screens, **this whole (better) implementation is unreachable
  dead code** in the current build.
- **Conclusion: the two Supabase migrations that ship with this repo
  (`meal_plans`, `meal_plan_meals`, `jade_calls`) create tables that the
  running app never writes to.** Everything a user does in `/plan/a` — build a
  week, swap a meal, add a recipe — lives only in that browser's localStorage
  and is lost on a different device/browser or a cleared cache.
- `jade_calls` (the AI-observability table) has a full writer (`log.ts`
  `logJadeCall()`) and a full rate-limiter (`rate-limit.ts` `checkRateLimit()`,
  buckets: regenerate-week 30s, swap 5s, tweak/chat 10s, chat-turn 2s) — **both
  functions are defined and exported but never called anywhere in the
  codebase.** No call site logs a Jade invocation or checks a rate limit.

---

## 3. Agent design

### 3.1 System prompt — verbatim

**A. `server/jade/persona.ts` — `JADE_BASE_SYSTEM_PROMPT`** (the "designed"
prompt, orphaned — not wired into any live endpoint):

```
You are Jade, the meal-planning coach inside Mealvana Endurance — a training-aware
nutrition app for endurance athletes (runners, cyclists, swimmers, triathletes).

Your job is to build and edit weekly meal plans by composing existing foods from a
catalog into balanced ingredient assemblies. You never write recipes with cooking
steps. You never invent foods or templates. Every food you reference must come from
a prior listFoods or listTemplates tool call, and you emit food_id UUIDs that
the client resolves to display data.

You always have access to the user's profile, training schedule, and macro targets:
- Allergies (HARD): never include foods containing any allergen in user.allergies.
- Dietary preference (HARD): never include foods whose excluded_diets contains
  the user's dietary_preference value.
- Disliked foods (SOFT, weighted by preference_level): avoid these unless no
  reasonable alternative exists for the macro target.
- Liked foods (SOFT, weighted): prefer these when fit is reasonable.
- Daily macro targets from daily_macro_targets (carb_g, prot_g, fat_g): hit
  ±10% per day.
- Activities for the week from activities: structure pre/during/post slots only
  on workout days where they apply (per the rules the client passes you).
- Gut training and GI sensitivity: tune fiber and fat density on hard days.

Tone: warm, concise, encouraging. 1–2 sentences per turn unless the user asks for
detail. Athletic-savvy. First-person ("I built…", "I'd swap…"). No exclamation
points. No emoji in your prose. Never say "As an AI…" — you are Jade.

Hard refusals:
- Medical / diagnostic questions → "I can't give medical advice — that's a doctor
  or RD conversation."
- Aggressive caloric restriction (request below 1.2× RMR) → redirect to fueling.
- Eating-disorder language → static referral (NEDA helpline 1-800-931-2237) + on-mission offer.

Output format:
- For full week generation: a WeekPlan JSON matching the provided schema.
- For swap requests: an array of 3 MealAssembly alternatives.
- For chat replies (Approaches D, E): plain text, optionally followed by inline
  chips the user can tap (the client renders them; you mark them with a special
  syntax the client parses).

Style for meal titles: components-first, lowercase plus joiners. Good: "chicken +
rice + broccoli." Bad: "Sunset Citrus Glazed Chicken Bowl." Method tags are short:
"grilled · 5-min assembly."

Never address the user as "you" in coach strips — use neutral phrasing
("High-carb week — long run Saturday"). In chat (D, E) you do address the user
naturally.

Grocery / shopping lists:
- When the user asks for a grocery list, shopping list, "what to buy", or "what
  do I need this week", call buildGroceryList — it reads the user's saved
  meal_plan_meals and returns a real, deduped, aisle-grouped list. Do NOT call
  showGroceryList for this case (that one is only for hand-crafted demos).
- Pass approach_used when the surface is known (a/b/c/d/e). If the user mentions
  a specific week, pass week_start as ISO Monday date.
- After the tool returns, write one short sentence confirming the list ("Pulled
  it from your week — X items across Y aisles.") and let the widget render. If
  the meta.warning field is set, surface it to the user briefly.
```

Plus five per-surface adapters (`JADE_ADAPTERS.a` through `.e`) appended after
the base — e.g. adapter `e` (Coach): *"On first turn, OPEN with a contextual
line that names the inferred WEEK CHARACTER and the anchor day... DO NOT greet
generically with 'Want me to build this week for you?' — the user gave us the
schedule already."*

**B. `vite.config.ts` inline `SYSTEM_PROMPT`** (dev-only, but this is the
richer one that's actually wired to tools/context/streaming):

```
You are Jade, the meal-planning coach inside Mealvana Endurance — a training-aware
nutrition app for endurance athletes. Your job is to build and edit weekly meal
plans by composing simple ingredient assemblies (e.g. "grilled chicken · jasmine
rice · roasted broccoli · lemon-tahini"). You never write recipes with cooking
steps. You never invent macro numbers without grounding them in real foods. Be
warm, concise, encouraging — 1–2 short sentences per turn unless asked to
elaborate. NEVER give medical advice or diagnose; redirect medical questions to a
registered dietitian.

IMPORTANT — DATA ACCESS:
- The user's profile, training schedule, macro targets, and food preferences are
  loaded for you in an ATHLETE CONTEXT block below the prompt when they're signed
  in. ALWAYS check that block before saying you don't have access.
- If the ATHLETE CONTEXT block is present, use the exact data from it. Don't
  suggest connecting Garmin/Strava — that's already done; the data is right here.
- If you see a NOTE saying the user is NOT signed in, ask them to sign in at
  /sign-in (do NOT mention Garmin or Strava — sign-in is the only step needed).

GENERATIVE UI — TOOL USE RULES (follow exactly):
1. FIRST-TURN BEHAVIOR — DO NOT ASK FOR INFO YOU ALREADY HAVE: ... Open with a
   *contextual* greeting that names the inferred week character and the anchor
   day, then ask only ONE concrete next-step question... DO NOT call
   showCategoryPicker on first turn...
2. WORKOUT FUEL: Whenever you reference today's or a specific day's training
   session, ALSO call showWorkoutTimeline so the user sees the pre/during/post
   fuel windows inline.
3. WEEK PLANS: ... finish your text summary THEN call showMealCarousel with 3
   distinct options ... OR call showMealPlanCard if there is only one logical
   plan given the constraints.
4. INSIGHTS: Use showInsightTile proactively whenever you spot a pattern — low
   protein across multiple days, a recovery week opportunity, an approaching
   race countdown, or a macro target that won't be met.
5. WEATHER: ... call getWeather first then immediately call showWeatherCard...
6. RACE COUNTDOWN: If the user mentions an upcoming race within 21 days, call
   showRaceCountdown. If DERIVED WEEK CHARACTER says "race week", lead with
   showRaceCountdown on first turn.
7. CLARIFICATIONS: Prefer showFollowUpQuestion over plain text...
8. COMPARISONS: When the user asks "which is better" about two meals, call
   showComparisonCard.
9. GROCERIES: After confirming a plan, proactively offer to call
   showGroceryList.
10. Never call data tools ... more than once per turn for the same data — the
    ATHLETE CONTEXT block already has the most recent snapshot.
11. WHEN THE USER SAYS "PLAN MY WEEK" or similar: assume they want a plan now
    — don't ask clarifying questions, generate it using the DERIVED WEEK
    CHARACTER, then show showMealCarousel with 3 options.
```

**C. `server/jade/server-fns.ts` / `chatFn`'s system message** (the one users
actually get, in production): a single short paragraph — *"You are Jade, the
meal-planning coach inside Mealvana Endurance... Never write recipes with
cooking steps... Be warm, concise, encouraging — 1–2 short sentences per turn
unless asked to elaborate. NEVER give medical advice..."* — plus one extra
sentence for `chatFn` specifically: *"You are chatting one-on-one. Keep replies
short (1-3 sentences) and warm. When the user asks about a meal or training
detail you don't have, ask for it instead of inventing data."*

### 3.2 Model
- `server-fns.ts` (shipped path): default `anthropic/claude-haiku-4-5`,
  overridable via `JADE_MODEL` env var. (Git history: commit `41770e1` "switch
  to Haiku 4.5 for week generation" — deliberate cost/latency choice.)
- `vite.config.ts` dev middleware: default `anthropic/claude-sonnet-4-6`.
- `.env.example`: `JADE_MODEL=openai/gpt-4o`, `JADE_FALLBACK_MODEL=anthropic/claude-sonnet-4-6`.
- Three different defaults across three files — never reconciled.
- All paths go through **Vercel AI Gateway** (`@ai-sdk/gateway`) when
  `AI_GATEWAY_API_KEY` is set; falls back to direct `@ai-sdk/openai` if only
  `OPENAI_API_KEY` is set (this fallback path exists only in `gateway.ts`,
  itself orphaned — see §2.3).

### 3.3 Tools / functions (28 total, `server/jade/tools.ts`, factory
`makeJadeTools({ supabase, userId })`, AI SDK v6 `tool({description,
inputSchema, execute})`)

**Data tools** (real Supabase reads, RLS-scoped to the caller):
- `getWeather({date})` — **stubbed**, returns a hardcoded 72°F/"Partly Cloudy"
  object regardless of input; real OpenWeather integration explicitly deferred.
- `getEvents({days})` — **stubbed**, always returns `[]` ("No events table yet").
- `getUpcomingActivities({days})` — real: queries `activities` table
  (`scheduled_date_time, activity_type, title, duration_minutes,
  intensity_level, distance_miles, distance_meters, status`).
- `getMacroTargets({from, to})` — real: queries `daily_macro_targets`
  (`target_date, carb_g, prot_g, fat_g, tdee, session_kcal`).
- `getUserProfile({})` — real: queries `users` (`gender, birthday,
  height_feet, height_inches, weight_pounds, body_fat_percentage,
  dietary_preference, allergies, gut_training_level, cycling_ftp_watts,
  swimming_css_seconds_per_100m, activity_level`).

**UI-rendering tools** (pass-through `execute`; payload streams to client and
renders via `WIDGET_REGISTRY`): `showCategoryPicker`, `showMealPlanCard`,
`showMealCarousel`, `showMealAlternatives`, `showWeekHeatmap`,
`showWorkoutTimeline`, `showWeatherCard`, `showRaceCountdown`,
`showInsightTile`, `showFollowUpQuestion`, `showMacroProgressRings`,
`showHydrationTracker`, `showGroceryList` (hand-crafted demo path),
`buildGroceryList` (real Supabase path, described in §2.4),
`showPhotoUploadPrompt`, `showDayBreakdown`, `showMorningGreeting`,
`showWeekRangePicker`, `showAllergyMultiSelect`, `showMacroSlider`,
`showDayChips`, `showSlotChips`, `showYesNoChips`, `showCompactMealList`,
`showComparisonCard`, `showNutritionBreakdown`.

Each `inputSchema` is a Zod object; every field is documented with `.describe()`
strings the model reads. These tools are only ever invoked from the dev-only
`/api/jade/chat` middleware (§2.3) — not reachable in a deployed build.

### 3.4 Widget registry (`components/shared/widgets/widget-registry.tsx`)
Maps ~50 tool-name aliases (e.g. both `showMealPlanCard` and `proposeWeekPlan`)
to 30 React components. Includes an `adaptWith()` layer that translates the
tools' snake_case output shape (`avg_carbs_g`, `workout_title`) into the
widgets' camelCase/nested prop shape (`dailyAvg.carbG`,
`workoutTitle`) — a real, non-trivial adapter, well factored, but again
orphaned in the shipped app since the widget system isn't mounted anywhere
reachable from `/plan/a`.

### 3.5 Structured output schema (`server/jade/schema.ts`, Zod)
`WeekPlan { week_start, iso_week, iso_year, coach_strip (≤200 chars),
rationale?, approach_used?, days: DayPlan[7] }`. `DayPlan { date,
meals?: Record<MealSlot, MealAssembly | null>, day_note? }`. `MealAssembly {
id?, title, method_tag?, components: FoodComponent[], template_id?,
template_table?, totals: {carb_g, protein_g, fat_g, sodium_mg?} }`.
`FoodComponent { food_id: uuid, name, portion, weight_g?, carb_g, protein_g,
fat_g }`. `MealSlot` enum: `breakfast | pre_workout | during_workout |
post_workout | lunch | dinner | snack`.

This is the "designed" schema and it requires `food_id` UUIDs from a real
catalog. The **shipped** generation path (`server-fns.ts` / `vite.config.ts`
`kind: "week"|"day"`) uses a deliberately **looser, parallel schema**
(`LooseWeekPlan`/`LooseMealAssembly`, duplicated near-verbatim in both files)
that drops `food_id` entirely and lets the model invent `name`/`portion`/macro
numbers directly — the prompt literally says "Skip food_id fields entirely."
So in practice Jade never resolves against a real foods catalog; it free-hands
plausible-sounding macros for invented food names.

### 3.6 Context assembly ("what Jade knows about the user")
Only in the dev-only `/api/jade/chat` middleware (§2.3). It builds a text
block from four parallel Supabase queries (`users`, `activities` next-14-days,
`daily_macro_targets` next-14-days, `food_preferences` top-40 by
`preference_level`), then computes a heuristic **"DERIVED WEEK CHARACTER"**:
- `totalLoad = Σ duration_minutes × intensityWeight` (low/easy=1,
  moderate/mod=2, high=3, threshold=3.5, vo2max=4, race=5), for the next 7 days
- `workoutDays` / `restDays` = distinct days with ≥1 activity / 7 minus that
- `anchor` = longest single activity in the window
- `isRaceWeek` = regex match `/race|marathon|half|10k|5k|ironman|tri/i` against
  activity title/type
- `weekCharacter` ∈ `{race week, full rest, high-load training (load>1200),
  moderate training (load>600), easy / recovery}`
- `avgCarb` / `carbsPerLb` from the macro-target rows

This is genuinely well-designed context engineering — but again, it's dead
code relative to the shipped chat surface (`chatFn`), which passes **zero**
context beyond the raw message history.

### 3.7 Streaming / UI approach
- Designed: Vercel AI SDK v6 `useChat` + `DefaultChatTransport`,
  `toUIMessageStreamResponse()`, generative UI via tool-call parts rendered
  through `WIDGET_REGISTRY` — real streaming, real generative UI. Only reachable
  via the dev-only middleware.
- Shipped: `JadeChatSheet` (`components/shared/jade-chat-sheet.tsx`) calls
  `chatFn` (a `createServerFn`, single request/response, no streaming) and
  renders plain text bubbles. Docstring is explicit about why: *"Drops
  useChat/DefaultChatTransport so it works in production where the
  Vite-middleware streaming endpoint isn't deployed."* No tool calls, no
  widgets — this is a deliberate, documented regression made to get something
  working in prod, not an oversight, but it means the generative-UI showcase
  never ships.
- `ai-elements/*.tsx` (`code-block`, `conversation`, `message`, `prompt-input`,
  `suggestion`, `tool`) are the official Vercel "AI Elements" primitives,
  imported but effectively unused by the shipped screens for the same reason.

---

## 4. Data model

### 4.1 Supabase schema shipped in this repo (2 migrations, both dated
2026-05-07, explicitly targeting the **dev** project, both never applied to
data that the app actually writes — see §2.4)

**`meal_plans`**: `id uuid pk`, `user_id uuid fk auth.users`, `week_start date`
(Monday), `iso_week int`, `iso_year int`, `coach_strip text` (≤200 chars),
`rationale text?`, `generation_model text?`, `generation_input_hash text?`,
`approach_used text? check in ('a','b','c','d','e')`, `created_at`,
`updated_at`. Unique on `(user_id, week_start)`. RLS: owner CRUD + service-role
bypass.

**`meal_plan_meals`**: `id uuid pk`, `meal_plan_id uuid fk meal_plans cascade`,
`user_id uuid` (denormalized for RLS perf), `date date`, `slot text check in
(the 7 MealSlot values)`, `scheduled_time time?`, `title text?`, `method_tag
text?`, `components jsonb default '[]'` (array of `FoodComponent`),
`template_table text? check in (3 template tables)`, `template_id uuid?`,
`totals jsonb default '{}'`, `locked boolean default false`, `created_at`,
`updated_at`. Unique on `(meal_plan_id, date, slot)` — i.e. **one meal per
day+slot**, matching the client-side `DayPlanData.meals` record shape.

**`jade_calls`**: `id`, `user_id?`, `approach text?`, `surface text?`, `model
text?`, `prompt_tokens/completion_tokens/cached_tokens int?`, `duration_ms
int?`, `tool_calls jsonb?`, `status check in (ok|error|timeout|refused)`,
`error_message text?`, `created_at`. RLS: user reads own, service-role writes.
Never written to (§2.4).

### 4.2 Client-side plan model (`lib/plan-store.ts` / `day-column.tsx` /
`meal-cell.tsx`) — what actually drives the shipped screen

```
PlanState { weekStart, planId: string | null, coachStrip: string | null, days: DayPlanData[] }

DayPlanData {
  date: "YYYY-MM-DD", dayLabel: "MON".."SUN", dateLabel: "May 6",
  isToday: bool, isKeyWorkout: bool,
  activity?: { type, title?, distanceMiles?, durationMinutes?, intensityLevel? } | null,
  carbG, protG, fatG: number,   // from daily_macro_targets (when hasSupabase — currently always empty)
  meals: {
    breakfast?, pre_workout?, during_workout?, post_workout?, lunch?, dinner?, snack?: MealAssembly | null
  }
}

MealAssembly {
  id?, title, methodTag?, components: { name, portion }[],
  carbG, protG, fatG: number, recipeId?, imageUrl?
}
```

Always exactly **7 days × up to 7 fixed slots** — day+slot assignment, not a
free list or batch model. No explicit "servings" concept: a `MealAssembly` is a
single-serving assembly with absolute macro grams, not `qty × per-serving`.
Fuel-window slots (`pre_workout`/`during_workout`/`post_workout`) only appear
when a day has a qualifying activity — decided client-side by `plan-helpers.ts`
(`findKeyWorkoutDate` picks the longest/farthest activity in the week as the
"key workout day", used to badge that day in the UI).

### 4.3 Shopping list model
Two independent implementations exist (§2.4): the shipped one
(`groceryListFn`) takes an ad-hoc `{scope: "day"|"week", label?, meals: {title,
components: {name, portion?}[]}[]}` built live from `plan-store` and returns AI
- generated `{summary, aisles: [{name, items: [{name, quantity, notes?}]}]}` —
no stable IDs, nothing persisted, checked-off state is component-local React
state (lost on refresh). The unreachable-but-better one
(`buildGroceryListFromPlan`) is deterministic: canonicalizes food names
(strips "grilled"/"roasted"/color-adjectives on onions, collapses "baby
spinach"→"spinach"), classifies into 10 aisles via keyword regex tables, and
aggregates portions unit-by-unit (`"2 cups" + "1 cup"` → `"3 cups"`) with a
tested fraction-formatting helper (`0.5`→`"½"`).

### 4.4 Recipe / quick-food seed data (all static TS files, no DB)
- `lib/data/recipes.ts`: 13 curated endurance recipes (`RecipeTag` enum:
  pre/during/post-workout, race-day, high-carb, high-protein, vegetarian,
  quick, + the 4 slots; `RecipeComponent {name, portion, carbG?, protG?,
  fatG?}`), Unsplash CDN photos.
- `lib/data/quick-foods.ts`: 17 "quick foods" — ingredient combos with no
  recipe steps, for the "I'm just eating yogurt and honey" case; same
  component shape, tagged by `QuickFoodSlot[]`.
- `lib/data/mock-imports.ts`: canned recipe objects keyed by URL-domain
  heuristics (Instagram/Pinterest/blog), backs the recipe-import stub.
- `components/variant-a/mock-week-plan.ts`: one hand-authored full `WeekPlan`
  (147 lines) used as the offline fallback when AI isn't configured.

---

## 5. Screens

**`/plan/a`** — the app. Sticky header with week label + "Regenerate"/"Plan
week" button (`aria-label`: *"Regenerate week"* / *"Plan my week"*); horizontal
day-pill selector; a coach strip that either shows Jade's `coach_strip` text or
placeholder copy *"Tap to chat about your week"*; vertical meal-slot stack for
the selected day (empty slot → dashed "+"; filled slot → title/components/macro
chip). Tapping a slot opens `MealAddSheet` (empty) or `SwapMealSheet` (filled).
Tapping the coach strip / a floating Jade button opens `JadeChatSheet`. Toasts:
*"Your week is ready"* / *"Day planned"* on success, *"AI gateway not
configured — using sample plan"* on fallback to `getMockWeekPlan`. 4-tab bottom
nav (`Plan` / `Cookbook` / `Shopping` / `You`) via `MobileShell`.

**`SwapMealSheet`** (`components/shared/swap-meal-sheet.tsx`) — the live meal
picker for both "add" and "swap" on `/plan/a`, 4 tabs: **Recipes** (from
`recipes.ts`, filtered by slot), **Quick** (`quick-foods.ts`, 17 items), **AI**
(auto-fetches 3 alternatives via `jadeObjectFn({kind:"swap"})` on open, plus a
free-text "Describe what you want" box → **"Build with Jade"**; error copy
*"Jade is offline — try the Recipes or Quick foods tabs"*), **Yours**
(user-added recipes, session-only). Header reads *"Swap · {date} · {slot}"* or
*"Add to · {date} · {slot}"*. Note: `meal-add-sheet.tsx` is an **earlier,
now-dead** 3-mode add sheet with zero live import references — fully
superseded by `swap-meal-sheet.tsx`, but left in the tree.

**`/cookbook`** — recipe browser: photo grid, tag filters, a "+" FAB opening a
4-mode add flow: *"Add a recipe"* (menu) → *"Import from a link"* (subtitle
*"Instagram, Pinterest, blog, recipe site"*, hits the recipe-import stub) /
*"Describe it"* (AI, `jadeObjectFn({kind: "build_meal"})`, same offline
fallback pattern: *"AI offline — saved as a draft"*) / *"Add manually"*
(subtitle *"Grandma's spaghetti — name it, set your own macros"*, raw
carb/protein/fat number inputs).

**`/shopping`** — Today/This-week toggle, "Generate"/"Regenerate" button,
AI-grouped aisle list with checkboxes (local-only state), fallback toast *"Demo
data shown — AI not configured — falling back to a sample list"*. Confirmed to
read only from localStorage plan state (§2.4/§4.3), never Supabase.

**`/you`** — **fully static stub**: hardcoded avatar initial "L", hardcoded
stats "Weekly km 84 / Long run 32k / Race in 42d", four inert nav rows
(Training calendar / Food preferences / Reminders / Settings — no `onClick`),
footer text *"Demo build · powered by Claude"*. No real data, no interactivity.

**`/sign-in`, `/sign-up`, `/auth/callback`** — Supabase email/password +
magic-link (handles both PKCE `token_hash` and implicit `#access_token` link
formats); callback shows *"Signing you in…"* / on failure *"Couldn't sign you
in"* + a *"Try again →"* link back to `/sign-in`.

**`/styleguide`** — Kyle design-token smoke test (colors, type scale, buttons,
cards) in light + dark; has a Playwright spec (`tests/styleguide.spec.ts`).

**`/`** — landing/variant-picker stub (thin, 11 lines) — a holdover from the
five-variant era, effectively vestigial now that only variant A ships.

---

## 6. What's stubbed/fake vs real

**Real**: Supabase auth (magic-link/password), the deterministic
`buildGroceryListFromPlan` aisle classifier (unreachable but correct), the 28
Jade tools' data-reads for `activities`/`daily_macro_targets`/`users` (only
reachable in dev), the athlete-context/week-character derivation (dev-only),
the widget-registry adapter layer, the production build pipeline itself
(builds clean with zero secrets).

**Stubbed / fake, presented as if real**:
- `getWeather` — hardcoded 72°F regardless of input; `getEvents` — hardcoded `[]`.
- `.env.example` still documents an entirely different auth provider (Clerk) —
  three env vars (`VITE_CLERK_PUBLISHABLE_KEY`, `CLERK_SECRET_KEY`,
  `CLERK_WEBHOOK_SECRET`) and a whole "MANUAL_STEPS.md" Clerk-JWT-template
  section that no longer apply after commits `d21d29c`/`030a4e1` swapped to
  Supabase auth. `pnpm-workspace.yaml`'s `onlyBuiltDependencies` still lists
  `@clerk/shared` too.
- Recipe import (`/api/recipes/import`) is 100% canned data keyed by
  URL-domain string matching — no scraping, no extraction, documented as such.
- `/you` — entirely fake profile data, no logic.
- The whole `meal_plans`/`meal_plan_meals` Supabase persistence layer — tables
  exist, RLS exists, a query/write helper library exists, but the app never
  calls any of it (§2.4).
- `jade_calls` observability + rate-limiting — fully implemented, fully unused.
- `food_id: uuid` catalog grounding in the "designed" schema — the shipped
  generation path explicitly tells the model to skip it and invent food
  names/macros from scratch.
- Weekly/day-count stats in `mock-week-plan.ts` and the README's "12 endurance
  recipes" (actual count is 13) — small drift between docs and code.
- **"Locking" a meal is UI-only and never functional**: `MealAssembly`/DB rows
  carry a `locked` field and the design docs describe "locked meals are
  skipped in regen," but `plan-helpers.ts`'s `countPlanStats()` hardcodes
  `daysLocked: 0` with a comment noting the feature was never wired up.
- A meaningful amount of the codebase is **dead code left in the tree from the
  five-variant era**, beyond what's noted above: `components/variant-a/{swap-sheet,
  coach-strip,week-grid,tweak-bar,day-column-a,meal-cell-a}.tsx` (an earlier
  desktop-grid implementation, zero live imports), `components/shared/
  meal-add-sheet.tsx` (superseded by `swap-meal-sheet.tsx`), `components/shared/
  theme-toggle.tsx` and `error-state.tsx` (built, never mounted by any live
  screen), and all 6 files under `components/ai-elements/` (Vercel AI SDK
  "AI Elements" scaffolding — conversation container, message bubbles,
  prompt-input, tool-call inspector — apparently `npx ai-elements add`-ed and
  never adopted; the live chat UI is hand-rolled instead). None of this is
  reachable from a route a user visits, but all of it ships in the production
  bundle graph and adds real cognitive overhead for anyone reading the repo.

---

## 7. Strengths

- **Real, deployable build with zero secrets** — a strong bar for a prototype;
  degrades gracefully everywhere instead of crashing.
- The **generative-UI agent design** (28 tools, 30 widgets, snake↔camel adapter
  layer, week-character derivation heuristic) is genuinely sophisticated and
  well-factored *as a design artifact*, even though it isn't wired into the
  shipped screen. It's a strong reference for what a "real" agent-driven
  meal-planning UX could look like.
- The **grocery-list aisle classifier** (`grocery.ts`) is careful, tested-in-spirit
  logic: word-boundary regex matching so "pea" doesn't false-match "chickpea",
  fraction-aware portion aggregation, an explicit aisle ordering.
- Clean **day+slot data model** that maps 1:1 to a real DB shape
  (`meal_plan_meals` unique on `(plan, date, slot)`), which is exactly the
  invariant a Flutter/Drift implementation would want too.
- Design-token discipline (Kyle system: named colors, font vars, radius vars)
  used consistently across every component — this alone is portable reference
  material for Flutter theming.
- Honest in-repo self-documentation: `STATUS.md` and inline comments candidly
  flag known gaps (e.g. "the demo runs on localStorage" is stated outright in
  the loader file, not hidden).

## 8. Weaknesses and bugs

- **The core architectural claim of the design docs — a context-aware,
  tool-using, streaming agent — does not describe the shipped product.** A
  reader of `persona.ts`/`tools.ts`/the README would reasonably believe Jade
  knows the user's training schedule and macro targets; in the deployed app it
  knows only the current chat's text.
- **No real persistence.** Every plan a user builds lives in one browser's
  localStorage. Switching devices, clearing site data, or using a different
  browser loses everything. The Supabase tables built for this
  (`meal_plans`/`meal_plan_meals`) are unused.
- **Two divergent, un-reconciled implementations** of both meal generation
  (strict `WeekPlanSchema` w/ `food_id` vs. loose schema w/o) and grocery-list
  building (AI-freeform vs. deterministic-from-DB) — a maintenance hazard and a
  sign the consolidation pass didn't fully clean up after itself.
- **Model ID drift**: three different default models across `server-fns.ts`
  (`claude-haiku-4-5`), `vite.config.ts` (`claude-sonnet-4-6`), and
  `.env.example` (`gpt-4o`).
- **Stale docs**: `.env.example`, `README.md`, and `MANUAL_STEPS.md` describe a
  Clerk-based auth setup that was replaced two auth-swaps ago; a new
  contributor following the README's setup instructions would configure the
  wrong auth provider entirely.
- **No catalog grounding.** The shipped generation prompt tells the model to
  invent food names and macro grams from scratch ("Skip food_id fields
  entirely") — there's no verification against real nutrition data, so numbers
  are LLM guesses dressed as facts.
- **`getWeather`/`getEvents` are hardcoded stubs** that a naive reading of the
  tool `description` strings would not reveal are fake.
- **Dead observability and rate-limiting.** `logJadeCall`/`checkRateLimit` are
  fully built (with real bucket windows) but never called — an unauthenticated
  or malicious user could hammer the AI endpoints with no server-side backoff
  at all (the client only self-throttles via UI disabled-states).
- **Minimal automated test coverage** — exactly two test files in the whole
  repo (`jade-avatar.test.tsx`, `styleguide.spec.ts`); none of the AI
  generation, grocery aggregation, or plan-store logic is under test.
- **`/you` is entirely non-functional** — every row is a dead button, every
  stat is hardcoded, undermining any claim that the screen "shows the user's
  real data."
- **`persistWeekPlan`/`updateMealCell` in `plan-data.ts` are typed, exported,
  and called nowhere** — signature-compatible dead functions that look like
  live persistence hooks to anyone skimming imports.
- Five-variant scaffolding (`/` landing stub, `VITE_FOCUS_VARIANT` env var,
  `approach_used` columns/enums everywhere) still threads through the
  single-variant codebase as unnecessary indirection.

---

## 9. What the Flutter app (Flutter + Riverpod + Drift + Supabase,
offline-first) would need to change to adopt this design

1. **Persistence model inversion.** The prototype's "local-first, sync never"
   pattern (localStorage only) is the *opposite* of Mealvana's
   offline-first-with-sync pattern (Drift local-first writes +
   `SyncCoordinator.ensureSynced()`/`uploadDirtyRecords()`). Don't port the
   prototype's persistence approach — its `meal_plans`/`meal_plan_meals` Postgres
   schema (day+slot, JSONB `components`, `totals`) is a reasonable *shape* to
   mirror into a new Drift table pair, but it needs real upload-state tracking
   (`needs_upload`, dirty flags) the prototype never built.
2. **Pick one system prompt and one context-assembly path**, not three. The
   dev-only middleware's athlete-context block (profile + activities + macro
   targets + food_preferences + derived week-character) is the one worth
   porting — as a Dart-side context builder feeding a single edge function,
   analogous to how `connect_training_controller.dart`/`activities_repository.dart`
   already assemble training data today.
3. **Resolve against Mealvana's real foods/template catalog**, not invented
   food names. Reinstate the strict `WeekPlanSchema`'s `food_id: uuid`
   requirement and give the model `listFoods`/`listTemplates`-style tools
   backed by the actual `foods`, `pre_workout_templates`,
   `during_workout_templates`, `post_workout_templates` tables (per
   `docs/ssot`), instead of free-hand macro numbers.
4. **Move rate-limiting and call-logging from "designed but unused" to
   actually enforced**, server-side (edge function), before any AI-generation
   endpoint reaches real users — the prototype's bucket design (30s/5s/10s/2s)
   is a reasonable starting point.
5. **Decide the tool-call / generative-UI question deliberately.** Either
   invest in wiring the 28-tool + 30-widget system into a real streaming
   surface (the AI SDK v6 approach doesn't map directly to Flutter — this
   would mean designing an equivalent typed-widget-over-tool-call protocol
   for Riverpod/Flutter, e.g. a sealed class per widget type deserialized
   from a tool-call JSON payload), or scope Jade down deliberately to
   structured generation only (plan/day/swap) and skip generative chat UI —
   don't let it half-ship like this prototype did.
6. **Single day+slot meal model, `MealSlot` enum matching the existing
   pre/during/post-workout fueling-window vocabulary** — this part translates
   cleanly; Mealvana already has the same 3 workout-phase templates
   conceptually, so aligning the `MealSlot` enum (`pre_workout`,
   `during_workout`, `post_workout`, plus `breakfast`/`lunch`/`dinner`/`snack`)
   with what `docs/ssot` already defines avoids yet another divergent schema.
7. **Grocery list**: port the deterministic `buildGroceryListFromPlan`
   aisle-classification + portion-aggregation algorithm (grocery.ts) — it's
   the one piece of business logic in this repo that's correct, DB-driven, and
   worth reusing largely as-is (translated to Dart), rather than the AI-only
   `groceryListFn` path that ships today.
8. **PostgREST upsert discipline**: if/when a `meal_plans` equivalent is
   built for real, follow the existing house rule — `onConflict: 'id'`, never
   on a partial-unique-index column, and always check `UploadResult` from any
   `uploadDirtyRecords()`-style write, none of which the prototype had reason
   to think about (single Postgres write path, no offline queue).
9. **Coach-writes-for-athlete visibility rule**: if any future "coach builds a
   plan for an athlete" flow reuses this design, it must require remote
   server acknowledgment before success/navigation, per Mealvana's existing
   write-consistency policy — the prototype has no multi-user concept at all
   (single signed-in user only).
10. **Drop the stale Clerk references and the five-variant scaffolding**
    entirely rather than port them — they're not part of the design, just
    unfinished cleanup from the prototype's own history.
