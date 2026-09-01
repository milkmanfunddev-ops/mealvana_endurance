# Meal planning — synthesis and recommendations

_2026-08-26. Sources: 60 Notion pages (user research rounds 1–3, coach and dietitian interviews,
prototype tests, meeting notes, specs), the MealBuddy Figma (27 frames), the
`lbm54/mealplanning-prototype` repo, this repo's code and archived design corpus, and the Sage
design canvas from 2026-08-25. Every claim below points at a file in this folder._

---

## 1. The evidence, in one page

These are the findings that survive across independent sources. Ranked by how much they should
change what we build.

| # | Finding | Strength | Where |
|---|---|---|---|
| 1 | **Diagnose-and-add beats generate-from-scratch.** Users want the app to look at what they already eat and tell them what to add, at what moment. Landon, Isidoro, Madhu chose it outright; it is Rachel Mitchell's actual clinical workflow. | Strongest single finding in the program | `notion/user-research-synthesis.md` §4, §12 |
| 2 | **The shopping list is the moment of value, not the plan.** "If the app actually creates a shopping list, I'm totally sold." Nearly every round-1 participant lit up here and nowhere else. | Near-universal | `notion/user-research-synthesis.md` §4, §7 |
| 3 | **Batch cooking / cooking sessions are the plan unit.** A 7-day × 4-meal grid (28 picks, 68-item list) was tested internally and rejected as impractical. Ashley batch-cooks 2–3 dishes and eats leftovers. Team consensus 2026-05-08. | Strong; validated behaviour + rejected prototype | `notion/user-research-synthesis.md` §6 |
| 4 | **Component-first, not recipe-first.** 6 of 8 eat from a rotation of staples ("chicken, rice, seasoning… that's it"). Recipes are a "stuck/bored" discovery layer. The Lego component model in the architecture doc encodes this. | Strong | `notion/user-research-synthesis.md` §8 |
| 5 | **Rest / non-workout days are the biggest unaddressed gap.** "Today is a low-load day → eat like this" was validated; assuming users know rest-day nutrition was rejected. | Strong | `notion/user-research-synthesis.md` §3 |
| 6 | **Chat vs. buttons is segmented, not settled — and nobody used chat first.** Heavy daily-AI users pick chat; most pick buttons; Rhonda (daily AI user) picked buttons. In 6 live sessions no one opened with chat. Users skim chat messages. | Real, partially resolved | `notion/user-research-synthesis.md` §5; `notion/product-thinking-synthesis.md` §5 |
| 7 | **Macros: hidden by default, visible on demand, always with a daily total.** The "macro-free" design principle collided with testers who wanted numbers; per-meal numbers without a total confused people. | Documented contradiction | `notion/product-thinking-synthesis.md` §3 |
| 8 | **Safety shapes defaults.** Minimums not maximums; performance framing never weight; logging is situational, not a daily loop (Rachel Mitchell will not recommend it). | Three independent sources | `notion/user-research-synthesis.md` §9, §11 |
| 9 | **Ingredient-level swaps came up unprompted**, repeatedly ("salmon for chicken", "almond milk for oat"). Meal-level swap alone is not enough. | Moderate | `notion/user-research-synthesis.md` §4 |
| 10 | **Family constraints are structural for a real share of users** ("I'm not gonna cook a separate meal"). v1 is single-athlete by decision, but the constraint doesn't go away. | Moderate | `notion/user-research-synthesis.md` §3 |

Two team decisions that are already made and should be treated as fixed unless deliberately reopened:

- **Race-day fueling stays deterministic and outside the LLM.** The seam is
  `meal_planning_budget = daily_total_target − performance_nutrition_allocated`. (`notion/product-thinking-synthesis.md` §2)
- **The LLM renders language; algorithms own selection, macros, filters.** Every architecture doc since the
  first engineering design says this, and the 6/19/25 failure modes (tools mis-called, wrong params,
  missing tags) are why.

---

## 2. What each artifact gets right and wrong against that evidence

### 2a. The Figma "AI Assistant module" (MealBuddy, 27 frames) — `figma/mealbuddy-figma.md`

It is a well-drawn **questionnaire wizard inside a chat skin**: category → training schedule → goal →
diet → prep style → breakfast? → fridge contents → generate → day-by-day modal → confirm. My read:

**Keep**
- Hybrid input at every step: chips *and* free text, with the same "Edit" affordance under every past
  answer. This is the cleanest answer to "users don't know how to write meal-planning prompts."
- "Selected meals" tray pinned above the composer — a cart you fill from suggestions, then ask for a plan
  from what's in it. This is exactly the provisional-batch bar in the Sage canvas.
- Context-aware follow-ups (S20: uses forecast + training to suggest lighter weekday meals, carb-load
  Friday). Personalization only reads as personal when it is *shown*.
- Per-meal Regenerate / Remove; nothing commits without "Confirm & Add Plan."

**Drop**
- **Seven questions before any value.** That is failure mode #2 (decision fatigue moved into the chat).
  We already know training schedule, diet, allergies, and — after diagnose-and-add — what they eat. The
  wizard should collapse to at most one question.
- **Day 1…Day 6 slotting**, including inside the "Cook once, eat all week" branch, which still produces
  a different recipe set per day. Direct conflict with finding #3.
- Recipe cost + "gathering coupons" — new scope with no backend; park it (the architecture doc's
  "deal awareness" is a v2+ moat idea, not v1).
- Fridge photo → ingredient chips. Good idea, but it is the *third* input path (after saved plates and
  logged meals); not for v1.
- Two-column recipe pages with photos: recipe-first, contradicts finding #4.
- The unresolved chrome (hamburger, new-conversation, delete) called out in the file's own comments.

### 2b. `lbm54/mealplanning-prototype` — `prototype/prototype-analysis.md`

The repo contains two products. The one that **ships** (`/plan/a` + Cookbook/Shopping/You) is a
7-day × 7-slot grid backed by `localStorage`, calling a tool-less `generateObject` with a generic prompt
that tells the model to invent food names and macros. The one that is **designed** (28-tool agent, athlete
context block with a derived "week character", 30-widget registry, deterministic aisle-grouped grocery
builder from real `meal_plan_meals`) is only reachable through a dev-only Vite middleware and is dead
in a deployed build.

Against the evidence:

| Evidence | Prototype today |
|---|---|
| #1 diagnose-and-add | Generates a full week from scratch. Never reads `meal_logs` / `saved_meals`. |
| #2 shopping list is the value | Shopping tab exists but is AI-freeform from local state, unpersisted, check-state lost on refresh. The good deterministic builder is unreachable. |
| #3 cooking sessions | `PlanState` is 7 days × up to 7 fixed slots; no servings, no batch concept. |
| #4 component-first | Seed recipes are recipe cards with Unsplash photos; "Quick foods" (17 items) is the closest thing to plates and is hidden behind a tab. |
| #5 rest-day guidance | Nothing. |
| #6 buttons default, chat embedded | Actually right by accident: the grid is primary, Jade is a sheet. But the sheet has no context or tools, so it can't do the one thing chat is good for (targeted adjustment). |
| #7 macros on demand + daily total | Per-day carb/prot/fat exist on `DayPlanData` but are always empty (loader stub). |
| Persistence / offline-first | localStorage only; `meal_plans`/`meal_plan_meals` migrations never written to. Opposite of the app's Drift-first model. |
| Catalog grounding | "Skip food_id fields entirely." Macros are LLM guesses. |
| Rate limiting / logging | Built (`checkRateLimit`, `logJadeCall`), never called. |

What is worth lifting as-is: `server/jade/grocery.ts` (canonicalisation, word-boundary aisle regex,
unit-aware portion aggregation), the `ATHLETE CONTEXT` / week-character builder in `vite.config.ts`,
the strict `WeekPlanSchema` with `food_id`, the persona's hard refusals and "components-first, lowercase
plus joiners" title style, and the Kyle token discipline.

### 2c. The Sage canvas (2026-08-25) — self-critique

Built before this research was read. Scored against it:

- Right: plates as "simple food sets"; batch = plates × servings with no day slots; shopping list
  aisle-grouped with "have it" and pantry skipping; comments-in-plan; confirm-before-commit; race-week
  rules as the *only* day-pinned thing; "Log" from the plan as a light, situational action.
- Wrong or unproven: it is **chat-first**. The tab lands on Sage talking. Finding #6 says land on the
  structured surface (the batch) and embed Sage. The opener should be a briefing card, not a bubble.
- Missing: **diagnose-and-add** as the first move (it jumps to "want to build a batch?"); rest-day
  guidance; ingredient-level swap; a daily-total macro context; a visible "what Sage knows" drawer.
- Naming (resolved 08-26 → **Vana**): the Notion archive uses **MealBuddy** as the internal codename for the assistant and
  **Jade** for Lee's hybrid prototype; the app has since renamed Jade → "Mealvana AI". Sage was a
  placeholder; pick one name for the assistant across app + prototype before any more UI is drawn.

### 2d. What already exists in the app — `repo/repo-context.md`

More than the prototype assumes:

- `ai_coach` already streams NDJSON from `jade-chat`, already renders `meal_cards` and `choices` UI parts,
  already has a "Planning a day or week" section in its system prompt that pulls `getSavedMeals` /
  `getLoggedMeals` before inventing anything. A "batch" UI part is one sealed-class case away.
- `meal_logs` / `saved_meals` / `recipes` / `user_foods` / `food_preferences` (with allergen enforcement)
  / `daily_macro_targets` / `events` / `public_events` / per-activity weather / AI credits metering.
- `meal_logging`'s `kQuickAssemblies` static catalog is the seed of a plate library.
- Gaps (all real): no forward plan table, no week/multi-day view, no shopping list, no servings/leftover
  concept, no pantry, recipe ingredients are unstructured strings, no meal-timing prefs, no day-level
  weather, no regenerate-one-slot primitive.

---

## 3. Recommendations for the prototype, ranked

### R1. Flip the core loop to diagnose-and-add
First run: "Here's what you already eat" (from `meal_logs`, `saved_meals`, the 4–5 staples the user
names in one chip-question) → "Here's the gap against this week's budget" (`meal_planning_budget` per
day, rest days included) → "Add these" (2–4 plates, sized in servings). No blank-slate week. The wizard
collapses to one question ("Which of these do you actually eat?" with their own history pre-ticked).

### R2. Make the shopping list the destination
Every path ends in a list within two minutes of first open. Aisle-grouped, deduped, unit-aggregated,
"have it" toggles, pantry skipping from recently-logged staples, shareable, later exportable
(Reminders / Instacart / store pickup — the competition is meal kits, not MFP). Lift `grocery.ts`.

### R3. Cooking sessions × plates × servings as the data model
Replace `PlanState` (7 days × slots) with:
`meal_plans → cooking_sessions (cook_day) → plan_plates (plate_id, servings, per-serving totals)` plus an
optional `day_rules` table for race-week pins (Fri low-fibre, Sat AM pre-race formula). Servings decrement
on log. This is what both the research and the Sage canvas already assume; the Figma does not.

### R4. Structured surface first, assistant embedded
Land on the batch. The assistant shows up three ways: (a) a **weekly briefing card** at the top on
Sun/Mon — "long run Sunday, race Saturday, you're 120g/day behind from Wed; here's what I'd add" with
Accept / Adjust / Skip (KettleBot ritual + explicit bypass); (b) **"Adjust with …" inline** on any plate —
one line of text, the card updates (Ollie's tap-modify); (c) the **full chat** as escalation for the
AI-native segment, with the same tools. Both founders' positions are served: Xuan's "tell me what to eat"
is the briefing; Lee's control-forward is the default surface.

### R5. Wire one real agent path and delete the other two
Keep the Vite middleware's context builder + tools, deploy it as a real route (Next/TanStack server
route or a Supabase edge function alongside `jade-chat`), and delete `server-fns.ts`'s tool-less path and
the duplicated loose schemas. One system prompt, one model default. Turn on `checkRateLimit` and
`logJadeCall`. This is the single biggest gap between what the prototype claims and what it does.

### R6. Ground everything in the catalog
Strict schema with `food_id`; tools `listFoods` / `listPlates` backed by real tables; the model may
never emit a macro number it didn't get from data. This is the team's own "LLM is language, not
computation" rule, and it is what makes the "isn't this just ChatGPT?" moment answerable.

### R7. Rest-day guidance as a first-class card
"Today is a low-load day → eat like this" on the Plan tab and in the briefing. Uses the budget seam,
not the LLM. This is the biggest unaddressed gap and the cheapest one to close.

### R8. Macros: off by default, one tap away, always with the daily total
Per-plate macros under a disclosure; a per-day total bar when opened; minimums framing ("at least
300g carbs Wed–Fri"). Never a weight-loss frame even for Rhonda.

### R9. Ingredient-level swap, not just plate-level
"Swap broccoli → green beans on all 5 servings" as a first-class action on a plate, with the shopping
list re-aggregating. The comment-thread-on-a-plate pattern from the canvas is the UI for it.

### R10. Persist for real, offline-first
Supabase tables written by the server route (prototype) now; Drift mirror with `needs_upload` when it
moves into the app. Check `UploadResult`. `onConflict: 'id'`.

### R11. Cut scope explicitly
Coupons/cost, fridge photo, family/household, gamification, day-slotted grid, recipe pages with photos,
HelloFresh ordering. Write them down as "not v1" so they stop reappearing in mocks.

### R12. Logging from the plan stays light
One tap "I ate this" that decrements servings and (optionally) writes a `meal_log` with source
`plan`. No daily-loop nudging — the dietitian said no, and a servings-left pip does the job.

---

## 4. Proposed v1 loop (what a first-time user experiences)

1. Open Plan tab → briefing card: "Ironman Florida Saturday. You logged 2 meals today and eat mostly
   chicken-rice bowls and oats. I'd add a high-carb dinner Wed–Fri and keep Friday low-fibre." Buttons:
   **Show me** / **Adjust** / **Not this week**.
2. "Show me" → a single chip question ("Which of these do you actually cook?" — their staples pre-ticked,
   plus 2 library plates) → a batch appears: 3–4 plates × servings, cook day suggested, rules pinned.
3. Batch screen: plates with servings steppers, per-plate "Adjust" one-liner, macros under disclosure,
   coverage bar. Confirm.
4. Shopping list: aisle-grouped, "have it" toggles, share. (This is where they say "I'm sold.")
5. During the week: rest-day card on low-load days; "I ate this" decrements; assistant answers
   questions in-thread with the same tools.

---

## 5. Prototype repo — change checklist

- [ ] Delete `server-fns.ts` AI paths + loose schemas; promote the middleware agent to a real route
- [ ] One model default; enable rate limit + call logging
- [ ] Replace `plan-store` day×slot with sessions × plates × servings; write to Supabase
- [ ] Add `getSavedMeals` / `getLoggedMeals` / `listPlates` tools; delete invented-macro path
- [ ] Route `/shopping` through `buildGroceryListFromPlan`; persist check state; add "have it"
- [ ] Add briefing card + rest-day card; demote chat sheet to escalation; add inline "Adjust"
- [ ] Ingredient-level swap on a plate
- [ ] Remove Clerk remnants, 5-variant scaffolding, dead `meal-add-sheet`, static `/you`

---

## 6. Decisions taken 2026-08-26 (Lee)

- **Assistant name: Vana** (from Meal-*vana*; no "ai" in the name). Alternates considered: Mel, Endy.
- **Vocabulary: "meal"** for a library/user entry (the 400-meal library uses `meal_type`); "batch" for the week; "cooking session" only when batch cooking is on.
- **The plan lives under the Food tab** (Plan · Formulas · Shopping · My foods), not a separate tab.
- **The prototype repo is the path to the Flutter feature** → R5 (one real agent path) and R10 (real
  persistence) are in scope now, not later.
- Design canvas updated to v2 on these decisions + §3 recommendations:
  https://claude.ai/code/artifact/c776e4cd-1e7f-4f7a-8c71-a6a2d332ec21

## 7. The meal library (added 2026-08-26)

`mealplanning-prototype/packages/web/data/meal-library-400.json` / `meal-library-400.md` — 100 breakfasts, 100 lunches, 100 dinners, 100 snacks
selected from ~970 researched candidates, each tagged with `context` (everyday / pre-session / recovery /
rest-day / race-week / carb-load / travel), `diets_ok` + `allergens` in the app's exact enums, `batch`,
`swaps`, `approx_macros`, `source` and a one-line `why`. This is the catalog R1/R6 needed, and the UI word
is now **meal** (not plate). How it is woven into the design (canvas page 2, screens 6–7 + the library note):

- Staples matching: logged/saved meals are matched to a library row (D-001, B-001, D-003) so swaps and
  macros come for free and Vana can talk about them.
- The picker is the library filtered by context + the user's diet/allergens; each card shows the `why`
  line and the attribution ("Shalane Flanagan") — personalization the user can see (finding "shown, not implied").
- Day cards pull `rest-day` / `race-week` / `carb-load` entries and snacks; a race-week rule can *be* a
  meal (Friday = Mirinda Carfrae's race-eve plate, D-002).
- `swaps` power the ingredient-level adjust (R9); `batch` drives cooking sessions (R3).
- Food → Meals: Mine | Library, meal-type + context chips, allergy hits greyed with the swap that unhides them.
- Caveat carried from the library doc: macros are approximate and not yet catalog-grounded — R6 still applies.

## 8. Open questions for Lee

1. **The macro tension** (#7) — do we resolve it as "off by default, on demand with daily total," or
   test it again?
2. **The unresolved Lee ↔ Xuan disagreement** flagged 2026-06-17 — which parts are still live? The
   research reads as: both of you are right for different segments, and R4 is the reconciliation.
